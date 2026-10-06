extends SceneTree
## Damage thresholds, small spawning sample and XP budget; no full fight simulation.

const Balance = preload("res://scripts/balance.gd")
const Enemy = preload("res://scripts/enemy.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func reset_mage() -> void:
	game.players[0].configure_class(0)
	game.players[0].downed = false
	game.players[0].invulnerability = 0.0

func hits_to_down(amount: float) -> int:
	reset_mage()
	var player = game.players[0]
	for hit in range(1, 10):
		player.take_damage(amount)
		if player.downed: return hit
		# Natural regeneration and existing 0.7-second protection stay enabled.
		player.advance(0.71, Vector2.ZERO)
	return 10

func xp_budget() -> void:
	# A budget estimate, not a claim about actual AI combat or collection paths.
	# 70% of spawned enemy XP collected; bosses defeated at 90/150 seconds.
	var level := 1
	var xp := 0.0
	var credit := 1.0
	var serial := 0
	var wave := Balance.FIRST_WAVE_SECONDS
	var rewards := [0, 0]
	var previous_level := 1
	var sample := Enemy.new()
	for seconds in range(1, 180):
		var boss_active: bool = (seconds >= 60 and seconds < 90) or (seconds >= 120 and seconds < 150)
		if seconds == 60: rewards[0] = Balance.xp_required(level)
		if seconds == 120: rewards[1] = Balance.xp_required(level)
		var tuning := Balance.difficulty(float(seconds))
		credit += float(tuning.spawn_rate) * (Balance.BOSS_CROWD_MULTIPLIER if boss_active else 1.0)
		var count := int(credit)
		credit -= count
		if seconds >= wave:
			wave += Balance.WAVE_INTERVAL
			count += mini(2, Balance.wave_size(seconds)) if boss_active else Balance.wave_size(seconds)
		for index in range(count):
			serial += 1
			var kind := Balance.enemy_kind(seconds, serial)
			sample.setup(Vector2.ZERO, tuning, kind == "elite", kind)
			xp += sample.xp_value * 0.7
		if seconds == 90: xp += rewards[0]
		if seconds == 150: xp += rewards[1]
		while xp >= Balance.xp_required(level):
			xp -= Balance.xp_required(level)
			level += 1
		if seconds in [60, 120, 179]:
			print("XP BUDGET at ", seconds, "s: team level ", level, "; interval upgrades ", level - previous_level)
			previous_level = level
	sample.free()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	for index in range(10): game._update_spawning(0.1)
	var outside := true
	for enemy in game.enemies: outside = outside and not Balance.ARENA.has_point(enemy.position)
	check(game.enemies.size() <= 3 and outside and Balance.MAX_ENEMIES == 56 and Balance.MAX_RANGED_ENEMIES == 6, "lower opening density keeps edge spawns and reduced crowd caps")
	var normal := Enemy.new()
	normal.setup(Vector2.ZERO, Balance.difficulty(0), false)
	var elite := Enemy.new()
	elite.setup(Vector2.ZERO, Balance.difficulty(18), true)
	var runner := Enemy.new()
	runner.setup(Vector2.ZERO, Balance.difficulty(0), false, "runner")
	check(normal.hp == 36.0 and hits_to_down(normal.damage) == 5 and hits_to_down(runner.damage) == 5 and hits_to_down(elite.damage) == 3, "initial mage dies to five ordinary/runner hits or three elite hits, including natural regeneration between hits")
	reset_mage()
	var small = game.MiniBoss.new()
	small.setup_boss(Vector2(400, 400), Balance.difficulty(60), 0)
	game.world.add_child(small)
	game._fire_enemy_pattern(small, "fan", Vector2.RIGHT, Vector2.ZERO)
	check(game.enemy_bullets.size() == 5 and hits_to_down(game.enemy_bullets[0].damage) == 2, "actual boss fan bullets kill an initial mage in two hits")
	var ranged_strong := true
	for kind in ["fan", "ring", "sweep"]:
		var ranged := Enemy.new()
		ranged.setup(Vector2.ZERO, Balance.difficulty(float(game.Barrage.TYPES[kind].unlock)), false, kind)
		game.world.add_child(ranged)
		game._fire_enemy_pattern(ranged, kind, Vector2.RIGHT, Vector2.ZERO)
		ranged_strong = ranged_strong and hits_to_down(game.enemy_bullets[-1].damage) == 5
	check(ranged_strong, "ordinary fan/ring/sweep bullets also meet the five-hit threat level")
	small.state = "charge"
	check(hits_to_down(small.contact_damage()) == 1, "clearly warned miniboss charge has lethal contact damage")
	reset_mage()
	var priest = game.ThornBoss.new()
	priest.setup_boss(Vector2(800, 400), Balance.difficulty(120), 0)
	game.world.add_child(priest)
	var points: Array[Vector2] = [Vector2(640, 400)]
	game._fire_ground_pattern(priest, "roots", points, Vector2.RIGHT, false)
	var roots: float = game.enemy_hazards[0].damage
	game._fire_ground_pattern(priest, "fault", points, Vector2.RIGHT, false)
	check(hits_to_down(roots) == 2 and hits_to_down(game.enemy_hazards[1].damage) == 1, "priest roots take two hits while long-warning faults are lethal")
	reset_mage()
	game.elapsed = 180.0
	game._spawn_final_boss()
	var final = game.mini_boss
	final.position = Vector2(640, 400)
	game.players[0].position = Vector2(715, 400)
	game.players[1].position = Vector2(350, 550)
	game._resolve_final_strike(final, "sector", final.position, final.position, Vector2.RIGHT, 132, PI * 0.36, 1.0)
	var landed: bool = game.players[0].hp == 34.0
	check(landed and hits_to_down(final.damage) == 2 and hits_to_down(final.damage * float(final.MODULES.blink.damage)) == 2, "final boss local strike delivers the tuned two-hit small-skill damage")
	reset_mage()
	final.strike_hits.clear()
	game._resolve_final_strike(final, "circle", final.position, final.position, Vector2.RIGHT, 145, 0, float(final.MODULES.slam.damage))
	var escape_time: float = float(final.MODULES.slam.windup) * 0.76 - 0.2
	check(game.players[0].downed and escape_time * game.players[0].stats.speed > 145.0 + Balance.PLAYER_RADIUS, "slam is lethal but even phase-three warning allows a starting mage to walk out after a 0.2-second reaction")
	reset_mage()
	game.players[0].stats.max_hp = 250.0
	game.players[0].hp = 250.0
	final.strike_hits.clear()
	game._resolve_final_strike(final, "circle", final.position, final.position, Vector2.RIGHT, 145, 0, float(final.MODULES.slam.damage))
	check(not game.players[0].downed and game.players[0].hp == 85.0, "lethal skills use flat damage so health upgrades still protect players")
	check(Balance.xp_required(1) == 240 and Balance.xp_required(4) == 330 and Balance.xp_required(7) == 420, "larger initial XP gate and gentle growth prevent overly frequent early choices")
	xp_budget()
	normal.free()
	elite.free()
	runner.free()
	game.free()
	print("PACING RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
## Focused ranged-enemy checks; no long match simulation.

const MainScene = preload("res://scenes/main.tscn")
const Barrage = preload("res://scripts/barrage.gd")
var game
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func clear_combat() -> void:
	for array in [game.enemies, game.enemy_bullets, game.enemy_hazards, game.projectiles]:
		for node in array:
			node.free()
		array.clear()
	for player in game.players:
		player.downed = false
		player.hp = player.stats.max_hp
		player.invulnerability = 0.0
	game.players[0].position = Vector2(570, 400)
	game.players[1].position = Vector2(710, 400)

func enemy(kind: String, seconds := 22.0):
	var node = game.Enemy.new()
	node.setup(Vector2(300, 400), game.Balance.difficulty(seconds), false, kind)
	node.ranged_attack.connect(game._fire_enemy_pattern)
	game.world.add_child(node)
	game.enemies.append(node)
	node.attack_cooldown = 0.0
	return node

func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	clear_combat()
	var unlocked := true
	for kind in Barrage.TYPES:
		var config: Dictionary = Barrage.TYPES[kind]
		unlocked = unlocked and Barrage.spawn_kind(config.unlock - 1.0, config.every) != kind and Barrage.spawn_kind(config.unlock, config.every) == kind
	check(unlocked, "all four ranged types unlock progressively")
	var fan = enemy("fan")
	fan.advance(0.01, game.players[0])
	var direction: Vector2 = fan.attack_direction
	game.players[0].position.y += 100.0
	fan.advance(0.3, game.players[0])
	check(game.enemy_bullets.is_empty() and fan.attack_direction == direction and fan.attack_windup > 0.0, "fan locks aim and waits for its warning before firing")
	fan.advance(0.4, game.players[0])
	check(game.enemy_bullets.size() == 3 and game.enemy_bullets[1].velocity.normalized().is_equal_approx(direction), "fan fires three separated lanes along the warned direction")
	clear_combat()
	fan = enemy("fan", 180.0)
	game._fire_enemy_pattern(fan, "fan", Vector2.RIGHT, Vector2.ZERO)
	check(game.enemy_bullets.size() == 5, "later fan enemies fire a wider five-lane pattern")
	clear_combat()
	var ring = enemy("ring", 50.0)
	game._fire_enemy_pattern(ring, "ring", Vector2.RIGHT, Vector2.ZERO)
	var gap := true
	for bullet in game.enemy_bullets:
		gap = gap and absf(bullet.velocity.angle()) > 0.55
	check(game.enemy_bullets.size() == 9 and gap, "ring surrounds the field but leaves the marked escape opening")
	clear_combat()
	var sweep = enemy("sweep", 95.0)
	sweep.advance(0.01, game.players[0])
	sweep.advance(0.9, game.players[0])
	var staggered: bool = game.enemy_bullets.size() == 1 and sweep.burst_left == 8
	game.players[0].position.y += 100.0
	for index in range(8):
		sweep.advance(0.161, game.players[0])
	check(staggered and game.enemy_bullets.size() == 9 and game.enemy_bullets[0].velocity.angle() < game.enemy_bullets[8].velocity.angle(), "sweep fires nine shots over time without tracking the moved target")
	clear_combat()
	fan = enemy("fan")
	game._fire_enemy_pattern(fan, "fan", Vector2.RIGHT, Vector2.ZERO)
	game._update_enemy_attacks(2.0)
	check(game.players[0].hp < game.players[0].stats.max_hp and game.players[1].hp == game.players[1].stats.max_hp and fan.hp == fan.max_hp,
		"swept hostile collision damages the first player only and leaves enemies unharmed")
	clear_combat()
	fan = enemy("fan")
	game.players[0].invulnerability = 1.0
	game._fire_enemy_pattern(fan, "fan", Vector2.RIGHT, Vector2.ZERO)
	game._update_enemy_attacks(2.0)
	check(game.players[0].hp == game.players[0].stats.max_hp and game.players[1].hp == game.players[1].stats.max_hp,
		"existing player invulnerability absorbs hostile bullets")
	clear_combat()
	var mortar = enemy("mortar", 150.0)
	game._fire_enemy_pattern(mortar, "mortar", Vector2.RIGHT, game.players[0].position)
	game._update_enemy_attacks(0.7)
	var warning_safe: bool = game.players[0].hp == game.players[0].stats.max_hp
	game._update_enemy_attacks(0.5)
	var health: float = game.players[0].hp
	game.players[0].invulnerability = 0.0
	game._update_enemy_attacks(0.1)
	check(warning_safe and health < game.players[0].stats.max_hp and game.players[0].hp == health, "mortar warning is harmless and its blast hits each player once")
	game._fire_enemy_pattern(mortar, "mortar", Vector2.RIGHT, game.players[1].position)
	game.players[1].position.y += 120.0
	game._update_enemy_attacks(1.2)
	check(game.players[1].hp == game.players[1].stats.max_hp, "leaving the fixed landing zone dodges the mortar")
	game._fire_enemy_pattern(mortar, "mortar", Vector2.RIGHT, game.players[0].position)
	var countdown: float = game.enemy_hazards[-1].warning_remaining
	game.paused = true
	game.simulate(0.5, [Vector2.ZERO, Vector2.ZERO])
	game.paused = false
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	game.simulate(0.5, [Vector2.ZERO, Vector2.ZERO])
	check(game.enemy_hazards[-1].warning_remaining == countdown, "manual and upgrade pauses freeze pending enemy attacks")
	game.choose_team_upgrade(0)
	game.choose_upgrade(0, 0)
	game.choose_upgrade(1, 0)
	clear_combat()
	fan = enemy("fan")
	fan.advance(0.01, game.players[0])
	fan.hit(9999.0)
	fan.advance(1.0, game.players[0])
	check(game.enemy_bullets.is_empty(), "killing a caster interrupts its pending volley")
	clear_combat()
	fan = enemy("fan")
	for index in range(70):
		game._fire_enemy_pattern(fan, "fan", Vector2.RIGHT, Vector2.ZERO)
	check(game.enemy_bullets.size() == game.Balance.MAX_ENEMY_BULLETS, "hostile volleys respect their separate bullet budget")
	for player in game.players: player.downed = true
	game._update_enemy_attacks(10.0)
	check(game.enemy_bullets.is_empty(), "missed bullets expire instead of accumulating")
	clear_combat()
	game.elapsed = 180.0
	for index in range(150): game._spawn_enemy(Vector2(80, 200))
	var ranged_count := 0
	for node in game.enemies:
		if Barrage.is_ranged(node.kind): ranged_count += 1
	check(ranged_count > 0 and ranged_count <= game.Balance.MAX_RANGED_ENEMIES, "actual spawning mixes ranged enemies and caps simultaneous casters")
	game.free()
	print("BARRAGE RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

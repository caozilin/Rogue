extends SceneTree
## Short isolated finale checks; skip the ten-minute survival simulation.

const FinalBoss = preload("res://scripts/final_boss.gd")
var game
var boss
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

func prepare(step: int, first: Vector2, second: Vector2) -> void:
	boss.position = Vector2(640, 400)
	boss.state = "approach"
	boss.attack_step = step
	boss.attack_cooldown = 0.0
	for player in game.players:
		player.invulnerability = 0.0
		player.shot_cooldown = 999.0
	game.players[0].position = first
	game.players[1].position = second
	boss.set_priority_target(game.players[0], true)
	boss.advance(0.001, game.players[0])

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game.elapsed = game.Balance.FINAL_BOSS_SECONDS - 10.0
	game.boss_encounters = 1
	game._spawn_mini_boss()
	var priest = game.mini_boss
	game._queue_boss_support(priest, 2)
	var points: Array[Vector2] = [Vector2(400, 400)]
	game._fire_ground_pattern(priest, "roots", points, Vector2.RIGHT, false)
	game._fire_enemy_pattern(priest, "fan", Vector2.RIGHT, Vector2.ZERO)
	game.elapsed = game.Balance.FINAL_BOSS_SECONDS - 1.0
	game._update_spawning(0.0)
	check(not game.final_battle and game.mini_boss == priest, "finale waits until its scheduled time")
	game.elapsed = game.Balance.FINAL_BOSS_SECONDS
	game._update_spawning(0.0)
	boss = game.mini_boss
	check(game.final_battle and boss is FinalBoss and game.enemies.size() == 1 and priest.dead and game.enemy_bullets.is_empty() and game.enemy_hazards.is_empty() and game.pending_boss_support.is_empty(),
		"finale replaces surviving miniboss and clears all crowd attacks and pending guards")
	game._spawn_enemy(Vector2.ZERO)
	game._spawn_mini_boss()
	game._queue_boss_support(priest, 3)
	game._update_spawning(30.0)
	check(game.enemies.size() == 1 and game.pending_boss_support.is_empty() and not game.Balance.ARENA.has_point(boss.position), "normal enemies, waves, minibosses and guards remain disabled; finale enters from an edge")
	boss.advance(0.1, game.players[0])
	check(boss.state == "enter" and game.enemy_bullets.is_empty() and game.enemy_hazards.is_empty(), "entry cannot attack or generate ranged hazards")
	for player in game.players:
		player.stats.max_hp = 1000.0
		player.hp = 1000.0
		player.stats.regen = 0.0
	# Rush accelerates, then becomes warned local slashes rather than contact damage.
	prepare(0, Vector2(1100, 400), Vector2(400, 600))
	boss.advance(0.7, game.players[0])
	var origin: Vector2 = boss.position
	boss.advance(0.1, game.players[0])
	var early: float = origin.distance_to(boss.position)
	for index in range(4): boss.advance(0.1, game.players[0])
	origin = boss.position
	boss.advance(0.1, game.players[0])
	check(boss.state == "rush" and origin.distance_to(boss.position) > early and game.players[0].hp == 1000.0, "rush visibly accelerates without damaging a distant target")
	prepare(1, Vector2(1175, 400), Vector2(350, 600))
	var close_dash: bool = boss.boss_attack == "dash" and boss.dash_endpoint.distance_to(boss.position) <= 340.0
	prepare(3, Vector2(1175, 400), Vector2(350, 600))
	check(close_dash and boss.boss_attack == "blink" and boss.blink_destination.distance_to(boss.position) <= 280.0, "distant targets still trigger capped gap-closing modules rather than an endless rush loop")
	prepare(0, Vector2(725, 400), Vector2(600, 400))
	boss.advance(0.7, game.players[0])
	boss.advance(0.01, game.players[0])
	var health: float = game.players[0].hp
	var back_health: float = game.players[1].hp
	var warned: bool = boss.state == "combo_windup" and health == 1000.0
	boss.advance(0.7, game.players[0])
	check(warned and game.players[0].hp < health and game.players[1].hp == back_health and boss.combo_left == 1, "normal rush has two warned directional slashes; a player behind the boss is safe")
	# With a large delta, swept dash collision still hits its path and never its flanks.
	prepare(1, Vector2(885, 400), Vector2(810, 530))
	var locked: Vector2 = boss.dash_endpoint
	boss.advance(0.3, game.players[0])
	game.players[0].position = Vector2(885, 530)
	game.players[1].position = Vector2(810, 400)
	health = game.players[0].hp
	back_health = game.players[1].hp
	boss.advance(0.7, game.players[0])
	boss.advance(0.65, game.players[0])
	check(boss.position == locked and boss.state == "recover" and game.players[0].hp == health and game.players[1].hp < back_health and locked.distance_to(Vector2(640, 400)) <= 340.0,
		"dash is capped at 340 pixels, keeps its warning direction and hits only the swept melee path")
	var after_hit: float = game.players[1].hp
	game.players[1].invulnerability = 0.0
	game._resolve_final_strike(boss, "dash", Vector2(640, 400), locked, Vector2.RIGHT, 47.0, 0.0, 1.2)
	check(game.players[1].hp == after_hit, "one dash cannot hit the same player twice")
	prepare(3, Vector2(820, 400), Vector2(350, 600))
	var landing: Vector2 = boss.blink_destination
	game.players[0].position = Vector2(850, 580)
	health = game.players[0].hp
	boss.advance(0.9, game.players[0])
	check(boss.position == landing and landing.distance_to(Vector2(640, 400)) <= 280.0 and boss.state == "blink_reveal" and game.players[0].hp == health and boss.attack_windup >= 0.55,
		"blink uses a fixed capped landing, deals no arrival damage and adds a fresh melee warning")
	boss.advance(0.75, game.players[0])
	check(game.players[0].hp == health and boss.state == "recover", "moving away from the blink slash remains safe")
	prepare(2, Vector2(720, 400), Vector2(380, 400))
	health = game.players[0].hp
	back_health = game.players[1].hp
	boss.advance(0.5, game.players[0])
	var harmless: bool = game.players[0].hp == health
	boss.advance(boss.attack_windup + 0.01, game.players[0])
	check(harmless and game.players[0].hp < health and game.players[1].hp == back_health and game.enemy_hazards.is_empty(), "slam is a warned 145-pixel local hit, with no outgoing shockwave")
	var hp_before: float = boss.hp
	boss.hit(100.0)
	check(is_equal_approx(hp_before - boss.hp, 125.0), "recovery grants the duo a 25% damage opening")
	prepare(2, Vector2(720, 400), Vector2(380, 400))
	var warning: float = boss.attack_windup
	boss.hit(boss.max_hp * 0.41)
	var stable: bool = boss.phase == 2 and boss.attack_phase == 1 and boss.attack_windup == warning
	boss.hit(boss.max_hp * 0.30)
	prepare(0, Vector2(725, 400), Vector2(380, 400))
	check(stable and boss.phase == 3 and boss.attack_phase == 3 and boss.combo_left == 3 and boss.windup_duration < 0.6, "60% and 30% health change future modules, preserve existing warnings and unlock triple slash")
	boss.attack_scale = 0.65
	warning = boss.attack_windup
	boss.advance(0.1, game.players[0])
	check(is_equal_approx(warning - boss.attack_windup, 0.065), "frost slows the final boss's windups")
	boss.attack_scale = 1.0
	prepare(2, Vector2(720, 400), Vector2(380, 400))
	game.players[0].position = boss.position
	health = game.players[0].hp
	game.simulate(0.05, [Vector2.ZERO, Vector2.ZERO])
	check(game.players[0].hp == health, "standing on a warning does not cause generic boss contact damage")
	warning = boss.attack_windup
	game.paused = true
	game.simulate(0.4, [Vector2.ZERO, Vector2.ZERO])
	game.paused = false
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	game.simulate(0.4, [Vector2.ZERO, Vector2.ZERO])
	check(boss.attack_windup == warning, "manual and upgrade pauses freeze the finale")
	game.choose_team_upgrade(0)
	game.choose_upgrade(0, 0)
	game.choose_upgrade(1, 0)
	game._damage_enemy(boss, boss.hp + 100, 0)
	game._update_spawning(100.0)
	check(not game.victory and not game.game_over and game.final_stage == 2 and game.mini_boss.display_name() == "天穹炮皇", "defeating melee continues into artillery without resuming regular spawns")
	game.free()
	print("FINAL BOSS RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
## Short isolated checks for the boss; no full-match simulation.

const MainScene = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game.next_wave = 1000.0
	game.elapsed = game.Balance.FIRST_BOSS_SECONDS - 1.0
	game._update_spawning(0.0)
	check(not game.boss_alive(), "boss does not appear before its scheduled time")
	game.elapsed = game.Balance.FIRST_BOSS_SECONDS
	game._update_spawning(0.0)
	var boss = game.mini_boss
	var count: int = game.enemies.size()
	game._spawn_mini_boss()
	check(game.boss_alive() and not game.Balance.ARENA.has_point(boss.position) and game.enemies.size() == count and game.next_boss == game.Balance.FIRST_BOSS_SECONDS + game.Balance.BOSS_INTERVAL,
		"one boss enters from outside an edge and schedules the next encounter")
	boss.advance(0.2, game.players[0])
	check(boss.state == "enter" and game.enemy_bullets.is_empty(), "boss cannot fire while entering from outside")
	boss.position = Vector2(-28, 400)
	game.players[0].position = Vector2(50, 400)
	for index in range(32):
		boss.advance(0.05, game.players[0])
	check(boss.state == "approach" and game.Balance.ARENA.grow(-boss.radius).has_point(boss.position),
		"boss enters fully even when its target hugs the arena edge")
	boss.position = Vector2(400, 350)
	game.players[0].position = Vector2(650, 350)
	game.players[1].position = Vector2(900, 550)
	boss.state = "approach"
	boss.attack_cooldown = 0.0
	boss.advance(0.01, game.players[0])
	game.players[0].position.y += 100.0
	var locked: Vector2 = boss.attack_direction
	boss.advance(0.3, game.players[0])
	var warned: bool = boss.state == "windup" and game.enemy_bullets.is_empty() and boss.attack_direction == locked
	boss.advance(0.6, game.players[0])
	check(warned and game.enemy_bullets.size() == 5 and boss.state == "recover", "boss warns, locks aim and fires five lanes before recovering")
	boss.advance(1.9, game.players[0])
	boss.advance(0.01, game.players[0])
	check(boss.boss_attack == "ring" and boss.state == "windup", "second attack is a separately warned ring")
	boss.advance(1.1, game.players[0])
	var gap := true
	for angle in boss.bullet_angles("ring"):
		gap = gap and absf(wrapf(angle, -PI, PI)) > 0.7
	check(game.enemy_bullets.size() == 18 and gap, "boss ring adds thirteen bullets and keeps its escape opening")
	boss.advance(1.9, game.players[0])
	game.players[0].position = Vector2(650, 350)
	boss.advance(0.01, game.players[0])
	var origin: Vector2 = boss.position
	game.players[0].position.y += 100.0
	boss.advance(0.5, game.players[0])
	var charge_warning: bool = boss.boss_attack == "charge" and boss.position == origin and boss.attack_direction.is_equal_approx(Vector2.RIGHT)
	boss.advance(0.5, game.players[0])
	boss.advance(0.2, game.players[0])
	check(charge_warning and boss.position.x > origin.x and is_equal_approx(boss.position.y, origin.y), "charge has a stationary warning and does not chase the dodging player")
	boss.hit(boss.max_hp * 0.56)
	boss.advance(0.5, game.players[0])
	boss.advance(1.9, game.players[0])
	boss.advance(0.01, game.players[0])
	check(boss.enraged and boss.attack_enraged and boss.bullet_angles("fan").size() == 7 and boss.windup_duration < 0.8,
		"half health activates denser attacks and faster timing on the next attack")
	var clock: float = game.elapsed
	var warning: float = boss.attack_windup
	game.paused = true
	game.simulate(0.4, [Vector2.ZERO, Vector2.ZERO])
	game.paused = false
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	game.simulate(0.4, [Vector2.ZERO, Vector2.ZERO])
	check(game.elapsed == clock and boss.attack_windup == warning, "manual and upgrade pauses freeze boss attacks and scheduling")
	game.choose_team_upgrade(0)
	game.choose_upgrade(0, 0)
	game.choose_upgrade(1, 0)
	game.hud.refresh()
	check(game.hud.boss_health.visible and game.hud.boss_health.max_value == boss.max_hp and game.hud.boss_health.value == boss.hp,
		"boss HUD reflects its independent health and second phase")
	var reward: int = boss.xp_value
	var kills: int = game.players[0].kills
	game.players[0].hp = game.players[0].stats.max_hp * 0.2
	game.players[1].downed = true
	game.players[1].hp = 0.0
	var other = game.EnemyBullet.new()
	other.source_id = 999999
	game.world.add_child(other)
	game.enemy_bullets.append(other)
	game._damage_enemy(boss, boss.hp + 100.0, 0)
	game._damage_enemy(boss, 100.0, 0)
	check(not game.boss_alive() and game.players[0].kills == kills + 1 and is_equal_approx(game.players[0].hp, game.players[0].stats.max_hp * 0.4)
		and game.players[1].downed and game.players[1].hp == 0.0 and game.gems[-1].value == reward,
		"boss grants one XP drop and one team heal without reviving downed players or duplicate rewards")
	check(game.enemy_bullets.size() == 1 and game.enemy_bullets[0] == other and not game.hud.boss_health.visible,
		"victory clears only this boss's bullets and hides its health bar")
	game.free()
	print("BOSS RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

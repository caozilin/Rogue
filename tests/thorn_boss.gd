extends SceneTree
## Only the new encounter and its shared integration, without a full-run simulation.
const ThornBoss = preload("res://scripts/thorn_boss.gd")

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

func clear_hazards() -> void:
	for hazard in game.enemy_hazards: hazard.free()
	game.enemy_hazards.clear()

func cast(boss, step: int) -> void:
	boss.state = "approach"
	boss.attack_step = step
	boss.attack_cooldown = 0.0
	boss.advance(0.01, game.players[0])
	boss.advance(boss.windup_duration + 0.01, game.players[0])

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game.elapsed = game.Balance.FIRST_BOSS_SECONDS
	game._spawn_mini_boss()
	var first = game.mini_boss
	check(first.display_name() == "孢冠统领", "first encounter remains the barrage boss")
	game._damage_enemy(first, first.hp + 100, 0)
	game._update_projectiles(0.0)
	game.elapsed = game.Balance.FIRST_BOSS_SECONDS + game.Balance.BOSS_INTERVAL
	game.next_wave = 1000.0
	game._update_spawning(0.0)
	var boss = game.mini_boss
	check(boss is ThornBoss and not game.Balance.ARENA.has_point(boss.position), "second encounter is the priest entering from an outside edge")
	boss.advance(0.2, game.players[0])
	check(game.pending_boss_support.is_empty() and game.enemy_hazards.is_empty() and boss.state == "enter", "no spells or guards while entering")
	boss.position = Vector2(640, 340)
	game.players[0].position = Vector2(440, 490)
	game.players[1].position = Vector2(830, 490)
	cast(boss, 0)
	check(boss.state == "recover" and game.pending_boss_support.size() == 1 and boss.guard_count() == 0, "summoning defers enemy creation until iteration has finished")
	game._flush_boss_support()
	var edge_only: bool = boss.guard_count() == 2
	for guard in boss.guards: edge_only = edge_only and not game.Balance.ARENA.has_point(guard.position)
	game._queue_boss_support(boss, 3)
	game._flush_boss_support()
	check(edge_only and boss.guard_count() == 3 and game._regular_enemy_limit() == game.Balance.MAX_ENEMIES - 3, "guards enter from edges, cap at three and have reserved mob capacity")
	var guard = boss.guards[0]
	guard.position = boss.position + Vector2(90, 0)
	var health: float = boss.hp
	boss.hit(100.0)
	var protected: bool = is_equal_approx(health - boss.hp, 65.0)
	guard.position = boss.position + Vector2(320, 0)
	health = boss.hp
	boss.hit(100.0)
	check(protected and is_equal_approx(health - boss.hp, 100.0), "nearby guards reduce damage by 35%; pulling them away breaks protection")
	guard.set_priority_target(game.players[0], true)
	var old: Vector2 = guard.position
	guard.advance(0.1, game.players[0])
	check(guard.position.distance_to(game.players[0].position) < old.distance_to(game.players[0].position), "warcry pulls guards toward the warrior instead of the boss")
	cast(boss, 1)
	check(game.enemy_hazards.size() == 5 and game.enemy_bullets.is_empty() and game.enemy_hazards[0].warning_remaining > 0 and game.enemy_hazards[-1].warning_remaining > game.enemy_hazards[0].warning_remaining,
		"fault creates five sequentially warned ground zones and no bullets")
	clear_hazards()
	boss.state = "approach"
	boss.attack_step = 2
	boss.attack_cooldown = 0.0
	boss.advance(0.01, game.players[0])
	var locked: Vector2 = game.players[0].position
	game.players[0].position += Vector2(-100, 0)
	boss.advance(1.4, game.players[0])
	check(game.enemy_hazards.size() == 2 and game.enemy_hazards[0].position == locked and game.enemy_hazards[0].active_duration == 2.4,
		"roots lock both players' positions before casting and persist for 2.4 seconds")
	var hazard = game.enemy_hazards[0]
	game.players[0].position = hazard.position
	game.players[0].invulnerability = 0.0
	health = game.players[0].hp
	game._update_enemy_attacks(0.5)
	var safe: bool = game.players[0].hp == health
	game._update_enemy_attacks(0.6)
	var hit_once: bool = game.players[0].hp < health
	health = game.players[0].hp
	game.players[0].invulnerability = 0.0
	game._update_enemy_attacks(0.1)
	check(safe and hit_once and game.players[0].hp == health, "roots are harmless during warning and hit each player only once per zone")
	var warning: float = hazard.blast_remaining
	game.paused = true
	game.simulate(0.5, [Vector2.ZERO, Vector2.ZERO])
	game.paused = false
	check(hazard.blast_remaining == warning, "pause freezes persistent ground spells")
	clear_hazards()
	boss.hit(boss.max_hp * 0.56)
	cast(boss, 1)
	var rage_fault: bool = boss.enraged and game.enemy_hazards.size() == 7 and boss.windup_duration == 1.0
	clear_hazards()
	cast(boss, 2)
	check(rage_fault and game.enemy_hazards.size() == 4, "half health expands fault to seven zones and adds a second root zone per player")
	var other = game.EnemyHazard.new()
	other.source_id = 999999
	game.world.add_child(other)
	game.enemy_hazards.append(other)
	game._damage_enemy(boss, boss.hp * 2.0 + 100, 0)
	var guards_gone := true
	for item in boss.guards: guards_gone = guards_gone and item.dead
	check(not game.boss_alive() and guards_gone and game.enemy_hazards.size() == 1 and game.enemy_hazards[0] == other and game.hud.boss_title.text == "荆棘祭司已击败！",
		"victory removes priest-owned spells and guards, preserves unrelated attacks and displays its name")
	game._update_projectiles(0.0)
	game.elapsed = game.next_boss
	game._spawn_mini_boss()
	check(not game.boss_alive() and game.boss_encounters == 2, "two scheduled minibosses do not repeat")
	game.free()
	print("THORN BOSS RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

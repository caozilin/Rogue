extends SceneTree
## Focused artillery and sequential-finale checks; no full-run simulation.

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

func snapshot(filename: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	var saved_health: Array[float] = []
	for player in game.players:
		saved_health.append(player.hp)
		player.hp = minf(player.hp, player.stats.max_hp)
		player.queue_redraw()
	game.hud.refresh()
	for enemy in game.enemies: enemy.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	print("SCREENSHOT ", filename, " result=", root.get_texture().get_image().save_png("res://artifacts/" + filename))
	for id in range(game.players.size()): game.players[id].hp = saved_health[id]

func prepare(step: int, stage: int = 1) -> void:
	game._clear_hostile_attacks()
	boss.position = Vector2(640, 350)
	boss.phase = stage
	boss.attack_scale = 1.0
	boss.movement_scale = 1.0
	boss.bombardment_remaining = 0.0
	boss.lane_remaining = 0.0
	boss.state = "approach"
	boss.attack_step = step
	game.players[0].position = Vector2(480, 515)
	game.players[1].position = Vector2(830, 530)
	for player in game.players:
		player.downed = false
		player.hp = 1000.0
		player.invulnerability = 0.0
		player.shot_cooldown = 1000.0
	boss._start_artillery(game.players[0])

func fire() -> void:
	boss.advance(boss.attack_windup + 0.01, game.players[0])

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game.elapsed = 180.0
	game._update_spawning(0.0)
	var king = game.mini_boss
	check(game.final_stage == 1 and king.display_name() == "断界武王" and game.enemies.size() == 1, "three minutes starts the melee finale alone")
	game.players[0].hp = 50.0
	game._damage_enemy(king, king.hp + 100.0, 0)
	game._update_projectiles(0.0)
	check(not game.victory and not game.game_over and not game.boss_alive() and game.final_transition_remaining == 3.0 and game.players[0].hp == 70.0, "melee kill starts a deferred three-second transition and heals living teammates 20 percent")
	game.paused = true
	game.simulate(1.0, [Vector2.ZERO, Vector2.ZERO])
	game.paused = false
	check(game.final_transition_remaining == 3.0, "pause freezes the stage transition")
	game._update_spawning(3.0)
	boss = game.mini_boss
	game._spawn_ranged_final_boss()
	game._spawn_enemy(Vector2.ZERO)
	game._spawn_mini_boss()
	check(game.final_stage == 2 and boss.display_name() == "天穹炮皇" and game.enemies.size() == 1 and not game.Balance.ARENA.has_point(boss.position), "artillery enters at the edge once; regular and miniboss spawning stay disabled")
	boss.advance(0.01, game.players[0])
	check(game.enemy_bullets.is_empty() and game.enemy_hazards.is_empty() and boss.state == "enter", "edge entry never fires on arrival")
	prepare(0)
	var warning: float = boss.attack_windup
	boss.advance(warning * 0.5, game.players[0])
	var harmless: bool = game.enemy_bullets.is_empty()
	fire()
	var gap_safe := true
	for bullet in game.enemy_bullets:
		gap_safe = gap_safe and absf(boss.attack_direction.angle_to(bullet.velocity)) > boss.ring_gap(1)
	check(harmless and game.enemy_bullets.size() == 15 and gap_safe and game.enemy_bullets[0].damage == 66.0, "warned halo has a real fixed safe gap and 66-damage bullets")
	game._update_enemy_attacks(0.7)
	await snapshot("ranged_final_halo.png")
	prepare(0, 2)
	fire()
	var first_count: int = game.enemy_bullets.size()
	boss.advance(0.66, game.players[0])
	gap_safe = true
	for bullet in game.enemy_bullets:
		gap_safe = gap_safe and absf(boss.attack_direction.angle_to(bullet.velocity)) > boss.ring_gap(2)
	check(game.enemy_bullets.size() > first_count and gap_safe and boss.state == "recover", "phase two adds a second halo while preserving the same safe gap")
	prepare(2)
	var aim: Vector2 = boss.attack_direction
	fire()
	game.players[0].position = Vector2(350, 300)
	for index in range(8): boss.advance(0.181, game.players[0])
	check(game.enemy_bullets.size() == 27 and boss.attack_direction == aim and boss.state == "recover", "crossfire sweeps nine three-bullet volleys through its locked sector")
	prepare(1)
	var locked: Array = boss.locked_points.duplicate()
	game.players[0].position = Vector2(300, 320)
	game.players[1].position = Vector2(1020, 300)
	fire()
	var mark = game.enemy_hazards[0]
	check(game.enemy_hazards.size() == 2 and mark.position == locked[0] and mark.warning_remaining == 1.35 and is_equal_approx(mark.damage, 118.8), "dual marks keep their original positions and provide a second harmless countdown")
	await snapshot("ranged_final_marks.png")
	game.players[0].position = mark.position
	game._update_enemy_attacks(1.34)
	var health: float = game.players[0].hp
	game._update_enemy_attacks(0.02)
	var after_hit: float = game.players[0].hp
	game.players[0].invulnerability = 0.0
	game._update_enemy_attacks(0.01)
	check(health == 1000.0 and is_equal_approx(health - after_hit, 118.8) and game.players[0].hp == after_hit, "bombs damage only after warning and hit a player once per circle")
	prepare(3, 3)
	fire()
	var safe: bool = game.enemy_hazards.size() == 12
	for hazard in game.enemy_hazards:
		var closest: Vector2 = hazard.position.clamp(boss.safe_lane.position, boss.safe_lane.end)
		safe = safe and hazard.position.distance_to(closest) > hazard.radius + game.Balance.PLAYER_RADIUS
		safe = safe and hazard.damage == 165.0 and hazard.warning_remaining >= 1.7
	check(safe and boss.attack_cooldown >= 3.6 and boss.status_text().contains("安全带"), "twelve staggered lethal carpet bombs leave a safe lane until the last blast ends")
	game.players[0].position = boss.safe_lane.get_center() - Vector2(170, 0)
	game.players[1].position = boss.safe_lane.get_center() + Vector2(170, 0)
	await snapshot("ranged_final_carpet.png")
	game._update_enemy_attacks(3.5)
	check(game.players[0].hp == 1000.0 and game.players[1].hp == 1000.0 and game.enemy_hazards.is_empty(), "the displayed safe lane survives the full carpet bombardment")
	prepare(1, 3)
	check(boss.locked_points.size() == 4, "phase three adds adjacent marks without following player movement")
	prepare(0)
	warning = boss.attack_windup
	boss.hp = boss.max_hp
	boss.hit(boss.max_hp * 0.41)
	var stable: bool = boss.phase == 2 and boss.attack_phase == 1 and boss.attack_windup == warning
	boss.hit(boss.max_hp * 0.3)
	check(stable and boss.phase == 3, "60 and 30 percent thresholds strengthen future casts without shortening the active warning")
	boss.attack_scale = 0.65
	boss.advance(0.1, game.players[0])
	check(is_equal_approx(warning - boss.attack_windup, 0.065), "frost slows artillery attack timers")
	boss.attack_scale = 1.0
	prepare(1)
	fire()
	var bomb_warning: float = game.enemy_hazards[0].warning_remaining
	var cooldown: float = boss.attack_cooldown
	game.paused = true
	game.simulate(0.5, [Vector2.ZERO, Vector2.ZERO])
	game.paused = false
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	game.simulate(0.5, [Vector2.ZERO, Vector2.ZERO])
	check(boss.attack_cooldown == cooldown and game.enemy_hazards[0].warning_remaining == bomb_warning, "manual and upgrade pauses freeze artillery and bomb warnings")
	while game.has_pending_upgrades():
		if game.team_choosing: game.choose_team_upgrade(0)
		for id in range(2):
			if game.players[id].choosing: game.choose_upgrade(id, 0)
	game._damage_enemy(boss, boss.hp * 2.0 + 100.0, 0)
	game._update_projectiles(0.0)
	var ended_at: float = game.elapsed
	game.simulate(1.0, [Vector2.ZERO, Vector2.ZERO])
	check(game.victory and game.game_over and game.elapsed == ended_at and game.enemies.is_empty() and game.enemy_hazards.is_empty() and game.hud.modal_title.text.contains("天穹炮皇"), "only killing artillery wins, clears its attacks and freezes the run")
	await snapshot("ranged_final_victory.png")
	game.free()
	print("RANGED FINAL BOSS RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

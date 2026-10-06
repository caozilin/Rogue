extends SceneTree
## Only new final-boss attacks, timing, defense and their rendered effects.
var game
var boss
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func prepare(index: int, artillery := false, stage := 1) -> void:
	game._clear_hostile_attacks()
	game.boss_effects.effects.clear()
	game.damage_events.clear()
	boss.position = Vector2(650, 360)
	boss.phase = stage
	boss.attack_scale = 1.0
	boss.movement_scale = 1.0
	boss.state = "approach"
	boss.attack_step = index
	boss.strike_hits.clear()
	game.players[0].position = Vector2(560, 455)
	game.players[1].position = Vector2(795, 455)
	for player in game.players:
		player.downed = false
		player.hp = 1000.0
		player.invulnerability = 0.0
		player.shot_cooldown = 100.0
		player.giant_remaining = 0.0
		player.cold_ward_protection = false
		player.blessing_remaining = 0.0
		player.blessing_shield = 0.0
	if artillery:
		boss.bombardment_remaining = 0.0
		boss.lane_remaining = 0.0
		boss._start_artillery(game.players[0])
	else: boss._start_module(game.players[0])

func step(delta: float) -> void:
	var before: Vector2 = boss.position
	game.elapsed += delta
	game.boss_effects.advance(delta)
	boss.advance(delta, game.players[0])
	game.boss_effects.observe(boss, before)

func fire() -> void:
	step(boss.attack_windup + 0.001)

func screenshot(filename: String) -> void:
	game.hud.refresh()
	game.queue_redraw()
	game.boss_effects.queue_redraw()
	boss.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	print("SCREENSHOT ", filename, " result=", root.get_texture().get_image().save_png("res://artifacts/" + filename))

func artillery() -> void:
	game._damage_enemy(boss, boss.hp + 100, 0)
	game._update_projectiles(0.0)
	game._update_spawning(3.0)
	boss = game.mini_boss

func capture() -> void:
	if "--carpet-only" in OS.get_cmdline_user_args():
		artillery()
		prepare(3, true)
		for player in game.players:
			player.hp = player.stats.max_hp
			player.invulnerability = 100.0
		fire()
		game._update_enemy_attacks(0.74)
		await screenshot("boss_artillery_carpet.png")
		return
	for index in range(game.FinalBoss.CYCLE.size()):
		prepare(index)
		for player in game.players:
			player.hp = player.stats.max_hp
			player.invulnerability = 100.0
		if boss.boss_attack == "judgment":
			step(0.25)
			await screenshot("boss_judgment_charge.png")
		fire()
		match boss.boss_attack:
			"rush":
				boss.position = game.players[0].position - Vector2(65, 0)
				step(0.016)
				fire()
			"dash": step(0.16)
			"blink": fire()
		game.boss_effects.advance(0.1)
		await screenshot("boss_melee_" + boss.boss_attack + ".png")
	artillery()
	for index in range(game.RangedFinalBoss.ARTILLERY_CYCLE.size()):
		prepare(index, true)
		for player in game.players:
			player.hp = player.stats.max_hp
			player.invulnerability = 100.0
		fire()
		if boss.boss_attack in ["mark", "carpet"]:
			game._update_enemy_attacks(0.4)
			await screenshot("boss_shell_descent_" + boss.boss_attack + ".png")
			game._update_enemy_attacks(0.34)
		elif boss.boss_attack == "storm":
			step(0.24)
			game._update_enemy_attacks(0.38)
		else: game._update_enemy_attacks(0.22)
		game.boss_effects.advance(0.04)
		await screenshot("boss_artillery_" + boss.boss_attack + ".png")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game.elapsed = 180.0
	game._update_spawning(0.0)
	boss = game.mini_boss
	if "--capture" in OS.get_cmdline_user_args():
		await capture()
		game.free()
		quit()
		return
	check(boss.damage == 99.0 and boss.speed == 245.0 and game.FinalBoss.MODULES.dash.windup == 0.45, "boss base damage increased to 99 with faster movement and half-second dash warning")
	prepare(2)
	game.players[0].position = Vector2(1140, 625)
	fire()
	check(is_equal_approx(game.players[0].hp, 831.7) and game.players[1].hp == 1000.0, "judgment follows a target moved across the arena and damages only that target")
	prepare(2)
	game.players[0].invulnerability = 1.0
	fire()
	check(game.players[0].hp == 1000.0, "judgment respects active invulnerability")
	prepare(2)
	game.players[0].giant_remaining = 4.0
	game.players[0].blessing_remaining = 10.0
	game.players[0].blessing_shield = 50.0
	fire()
	check(game.players[0].hp == 1000.0 and game.players[0].blessing_shield < 50.0, "judgment still respects giant mitigation and teammate shelter")
	prepare(2)
	boss.set_priority_target(game.players[0], true)
	game.players[0].downed = true
	boss.set_priority_target(game.players[1], false)
	fire()
	check(game.players[1].hp == 1000.0, "invalidated lock target cancels rather than silently switching players")
	prepare(1, false, 3)
	var warning: float = boss.attack_windup
	boss.advance(warning * 0.5, game.players[0])
	check(boss.state == "windup" and warning < 0.35, "phase-three dash keeps a short harmless charge before moving")
	artillery()
	prepare(4, true)
	fire()
	check(boss.boss_attack == "storm" and game.enemy_bullets.size() == 44 and boss.volley_left == 3, "storm first volley has a complete ring and two arena-edge walls")
	step(0.24)
	var x_wall := false
	var y_wall := false
	var fast := true
	for bullet in game.enemy_bullets:
		fast = fast and bullet.velocity.length() >= 339.9 and bullet.damage == boss.damage
		x_wall = x_wall or (absf(bullet.position.x - game.Balance.ARENA.position.x) < 0.01 and bullet.velocity.x > 0)
		y_wall = y_wall or (absf(bullet.position.y - game.Balance.ARENA.position.y) < 0.01 and bullet.velocity.y > 0)
	check(fast and x_wall and y_wall, "storm walls alternate both axes and bullets are substantially faster")
	prepare(4, true, 3)
	fire()
	step(2.0)
	check(game.enemy_bullets.size() <= game.Balance.MAX_ENEMY_BULLETS and boss.state == "recover", "six storm waves finish with the hostile projectile budget still bounded")
	prepare(1, true)
	fire()
	var mark = game.enemy_hazards[0]
	check(mark.warning_duration == 0.6 and mark.radius == 88.0 and mark.damage == 198.0, "marked bombardment has enlarged fast impacts with 198 damage")
	game.players[0].position = mark.position
	game._update_enemy_attacks(0.59)
	check(game.players[0].hp == 1000.0, "descending shell deals no damage before impact")
	game._update_enemy_attacks(0.03)
	var health: float = game.players[0].hp
	game.players[0].invulnerability = 0.0
	game._update_enemy_attacks(0.04)
	check(health == 802.0 and game.players[0].hp == health, "bomb impact damages exactly once while its visual explosion persists")
	prepare(3, true)
	fire()
	check(game.enemy_hazards.size() == 12 and is_equal_approx(game.enemy_hazards[0].damage, 277.2) and boss.attack_cooldown >= boss.bombardment_remaining, "carpet bombardment is stronger but finishes its explosions before the next module")
	var safe := true
	for hazard in game.enemy_hazards:
		var nearest: Vector2 = hazard.position.clamp(boss.safe_lane.position, boss.safe_lane.end)
		safe = safe and hazard.position.distance_to(nearest) > hazard.radius + 64.0
	check(safe, "displayed carpet safe strip excludes blast edges even for a rank-three giant body")
	var life: float = game.boss_effects.effects[0].life
	var countdown: float = game.enemy_hazards[0].warning_remaining
	game.paused = true
	game.simulate(0.5, [Vector2.ZERO, Vector2.ZERO])
	check(game.boss_effects.effects[0].life == life and game.enemy_hazards[0].warning_remaining == countdown, "pause freezes shell flight and all boss effect timers")
	print("BOSS INTENSITY: ", checks, " checks, ", failures, " failures")
	game.free()
	quit(1 if failures > 0 else 0)

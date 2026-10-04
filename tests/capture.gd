extends SceneTree
## Real rendering QA with screenshots (do not run headless).

var game

func _initialize() -> void:
	call_deferred("run")

func screenshot(filename: String) -> void:
	game.hud.refresh()
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/" + filename)
	print("SCREENSHOT ", filename, " result=", result)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	if "--classes-only" in OS.get_cmdline_user_args():
		await screenshot("class_selection.png")
		game.start_run()
		game.players[1].position = Vector2(650, 400)
		for at in [Vector2(735, 400), Vector2(810, 400), Vector2(570, 540)]:
			var enemy = game.Enemy.new()
			enemy.setup(at, game.Balance.difficulty(0.0), false)
			enemy.hp = 300.0
			enemy.max_hp = 300.0
			enemy.speed = 0.0
			game.world.add_child(enemy)
			game.enemies.append(enemy)
		game.activate_skill(0)
		game.activate_skill(1, Vector2.RIGHT)
		for tick in range(12):
			game.simulate(1.0 / 60.0, [Vector2.ZERO, Vector2.ZERO])
		await screenshot("active_skills.png")
		game.free()
		quit()
		return
	game.start_run()
	if "--upgrades-only" in OS.get_cmdline_user_args():
		game.add_shared_xp(game.Balance.xp_required(game.team_level))
		await screenshot("upgrades.png")
		game.choose_upgrade(1, 0)
		await screenshot("upgrades_waiting.png")
		game.free()
		quit()
		return
	game.rng.seed = 20261005
	for p in game.players:
		p.invulnerability = 9999
	for tick in range(900):
		game.simulate(1.0 / 60.0, [Vector2.ZERO, Vector2.ZERO])
		for p in game.players:
			if p.choosing:
				game.choose_upgrade(p.player_id, 0)
		if tick % 60 == 0:
			await process_frame
		if game.team_choosing:
			game.choose_team_upgrade(0)
	await screenshot("gameplay.png")
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	await screenshot("upgrades_p1.png")
	await screenshot("upgrades.png")
	while game.players[0].choosing:
		game.choose_upgrade(0, 0)
	await screenshot("upgrades_p2.png")
	for p in game.players:
		while p.choosing:
			game.choose_upgrade(p.player_id, 0)
	while game.team_choosing:
		game.choose_team_upgrade(0)
	for p in game.players:
		p.choosing = false
		p.downed = true
		p.hp = 0
	game.simulate(0.01, [Vector2.ZERO, Vector2.ZERO])
	await screenshot("game_over.png")
	game.free()
	quit()

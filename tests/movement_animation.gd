extends SceneTree
## Focused movement/stop/pause check, with an optional short rendered preview.
var game
var units: Array = []
var walked: Dictionary = {}
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var capture := "--capture-motion" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	game.spawn_credit = -1000.0
	game.next_boss = 1000.0
	game.next_wave = 1000.0
	game.players[0].position = Vector2(400, 660)
	game.players[1].position = Vector2(850, 660)
	units.append_array(game.players)
	for player in game.players:
		player.shot_cooldown = 1000.0
		player.invulnerability = 1000.0
	var kinds := ["normal", "runner", "brute", "charger", "elite", "fan", "ring", "sweep", "mortar"]
	for index in range(kinds.size()):
		var enemy = game.Enemy.new()
		var at := Vector2(95 + index * 130, 450)
		if kinds[index] == "ring": at.y = 380
		if kinds[index] == "mortar": at = Vector2(1050, 500)
		enemy.setup(at, game.Balance.difficulty(0.0), kinds[index] == "elite", kinds[index])
		enemy.attack_cooldown = 1000.0
		enemy.charge_cooldown = 1000.0
		game.world.add_child(enemy)
		game.enemies.append(enemy)
		units.append(enemy)
	var priest
	for index in range(3):
		var boss = [game.MiniBoss, game.ThornBoss, game.FinalBoss][index].new()
		boss.setup_boss(Vector2(230 + index * 420, 275), game.Balance.difficulty(0.0), 100)
		boss.attack_cooldown = 1000.0
		game.world.add_child(boss)
		game.enemies.append(boss)
		units.append(boss)
		if index == 1: priest = boss
	var guard = game.BossGuard.new()
	guard.setup_guard(Vector2(600, 480), game.Balance.difficulty(0.0), priest, 0)
	game.world.add_child(guard)
	game.enemies.append(guard)
	units.append(guard)
	for frame in range(16):
		for tick in range(4):
			game.simulate(1.0 / 60.0, [Vector2.RIGHT, Vector2.LEFT])
			for unit in units:
				if unit.motion.walk_weight > 0.01: walked[unit.get_instance_id()] = true
		game.hud.refresh()
		game.queue_redraw()
		await process_frame
		await process_frame
		if capture:
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://artifacts/movement_%02d.png" % frame) == OK, "Movement preview frame failed")
	for unit in units:
		check(walked.has(unit.get_instance_id()), "Missing locomotion: " + unit.get_script().resource_path)
		if capture: check(unit.motion.body.visible, "Animated body is missing")
	var frozen: Array = []
	for unit in units: frozen.append(Vector2(unit.motion.phase, unit.motion.idle_time))
	game.paused = true
	game.simulate(0.5, [Vector2.RIGHT, Vector2.LEFT])
	for index in range(units.size()):
		check(frozen[index] == Vector2(units[index].motion.phase, units[index].motion.idle_time), "Pause advanced a unit animation")
	game.paused = false
	var stopped_phase: float = game.players[0].motion.phase
	for tick in range(20): game.simulate(1.0 / 60.0, [Vector2.ZERO, Vector2.ZERO])
	check(is_zero_approx(game.players[0].motion.walk_weight) and game.players[0].motion.phase == stopped_phase, "Stopped player should blend back to idle")
	print("MOVEMENT ANIMATION CHECK: ", units.size(), " units, all archetypes / stop / pause; failures=", failures)
	game.free()
	quit(0 if failures == 0 else 1)

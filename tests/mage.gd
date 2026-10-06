extends SceneTree
## Short local checks for mage only. Optional --capture renders just the new UI/effects.
const MainScene = preload("res://scenes/main.tscn")
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

func press_key(code: int) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	game._unhandled_key_input(event)

func right_click() -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_RIGHT
	event.position = Vector2(900, 400)
	game._unhandled_input(event)

func clear_enemies() -> void:
	for enemy in game.enemies:
		enemy.free()
	game.enemies.clear()
	game.mage_system.fireballs.clear()

func enemy_at(at: Vector2, rank := 1, resistance := 0.0, variant := "normal"):
	var enemy = game.Enemy.new()
	enemy.setup(at, game.Balance.difficulty(0.0), false, variant)
	enemy.level = rank
	enemy.tenacity = resistance
	enemy.hp = 10000.0
	enemy.max_hp = enemy.hp
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	return enemy

func screenshot(filename: String) -> void:
	game.hud.refresh()
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	print("SCREENSHOT ", filename, " result=", root.get_texture().get_image().save_png("res://artifacts/" + filename))

func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	if "--capture" in OS.get_cmdline_user_args():
		await screenshot("mage_classes.png")
	game.start_run()
	clear_enemies()
	game.spawn_credit = -10000.0
	game.next_wave = INF
	game.next_boss = INF
	var mage = game.players[0]
	var host = game.players[1]
	mage.position = Vector2(570, 400)
	host.position = Vector2(650, 400)
	if "--bindings-only" in OS.get_cmdline_user_args():
		host.configure_class(game.Classes.MAGE)
		enemy_at(Vector2(900, 400), 5)
		right_click()
		check(host.fireball_cooldown == 15.0 and mage.fireball_cooldown == 0.0
			and game.mage_system.fireballs[0].owner == 1, "right-click casts only P2 mage's fireball")
		press_key(KEY_1)
		check(host.frost_remaining == 5.0 and mage.frost_remaining == 0.0, "top-row 1 casts only P2 frost")
		press_key(KEY_KP_2)
		check(host.is_possessed() and not mage.is_possessed(), "numpad 2 casts P2 possession")
		press_key(KEY_3)
		check(host.suppression_remaining == 4.0 and mage.suppression_remaining == 0.0, "top-row 3 casts only P2 suppression")
		host.end_possession()
		host.frost_remaining = 0.0
		host.frost_cooldown = 0.0
		host.possession_cooldown = 0.0
		host.suppression_remaining = 0.0
		host.skill_cooldown = 0.0
		press_key(KEY_KP_1)
		press_key(KEY_2)
		press_key(KEY_KP_3)
		check(host.frost_remaining == 5.0 and host.is_possessed() and host.suppression_remaining == 4.0,
			"both top-row and numpad keys support all three P2 abilities")
		host.end_possession()
		press_key(KEY_Q)
		press_key(KEY_E)
		press_key(KEY_R)
		press_key(KEY_SPACE)
		check(mage.fireball_cooldown == 15.0 and mage.frost_remaining == 5.0 and mage.is_possessed()
			and mage.suppression_remaining == 4.0, "P1 keeps Q/E/R/Space independently")
		mage.end_possession()
		host.suppression_remaining = 0.0
		host.skill_cooldown = 0.0
		host.frost_remaining = 0.0
		host.frost_cooldown = 0.0
		press_key(KEY_ENTER)
		press_key(KEY_KP_5)
		check(host.suppression_remaining == 0.0 and host.frost_remaining == 0.0, "old P2 Enter and keypad 5 combat bindings are removed")
		game.paused = true
		host.fireball_cooldown = 0.0
		press_key(KEY_1)
		press_key(KEY_KP_3)
		right_click()
		check(host.fireball_cooldown == 0.0 and host.frost_remaining == 0.0 and host.suppression_remaining == 0.0,
			"pause blocks all P2 inputs")
		game.paused = false
		game.hud.refresh()
		check(game.hud.skill_icons[1][0].binding.text == "右键" and game.hud.skill_icons[1][1].binding.text == "1"
			and game.hud.skill_icons[1][2].binding.text == "2" and game.hud.skill_icons[1][3].binding.text == "3",
			"P2 skill icons show the new bindings")
		game.free()
		print("MAGE BINDINGS RESULT: %d checks, %d failures" % [checks, failures])
		quit(0 if failures == 0 else 1)
		return
	if "--capture" in OS.get_cmdline_user_args():
		for at in [Vector2(760, 440), Vector2(830, 400), Vector2(650, 535)]:
			enemy_at(at, 3 if at.x == 830 else 1)
		game.activate_mage_skill(0, 3)
		game.activate_mage_skill(0, 2)
		game.activate_mage_skill(0, 1)
		game.activate_skill(0)
		for tick in range(24):
			game.simulate(1.0 / 60.0, [Vector2.LEFT, Vector2.RIGHT])
		await screenshot("mage_skills.png")
		game.free()
		quit()
		return
	check(mage.role == game.Classes.MAGE and game.Classes.NAMES[0] == "法师", "default P1 is mage; P2 keeps warrior")
	var close = enemy_at(Vector2(570, 460), 1)
	var high = enemy_at(Vector2(650, 400), 5)
	check(game.activate_mage_skill(0, 1) and game.mage_system.fireballs[0].direction.is_equal_approx(Vector2.RIGHT)
		and mage.fireball_cooldown == 15.0 and not game.activate_mage_skill(0, 1), "Q aims at highest level and enforces 15s cooldown")
	var hp: float = high.hp
	game.mage_system.advance(0.1)
	var first_hit: float = hp - high.hp
	hp = high.hp
	game.mage_system.advance(0.2)
	check(high.position == Vector2(650, 400) and first_hit > 0.0 and is_equal_approx(hp - high.hp, first_hit)
		and high.knockback_remaining == 0.0 and close.position == Vector2(570, 460),
		"base fireball deals repeated damage without displacement or knockback stun")
	clear_enemies()
	mage.fireball_cooldown = 0.0
	var resistant = enemy_at(Vector2(650, 400), 5, 1.0)
	game.activate_mage_skill(0, 1)
	game.mage_system.advance(0.1)
	check(resistant.position == Vector2(650, 400) and resistant.hp < resistant.max_hp
		and is_equal_approx(resistant.max_hp - resistant.hp, first_hit), "tenacity does not change base fireball damage without knockback")
	if "--fireball-only" in OS.get_cmdline_user_args():
		game.free()
		print("FIREBALL RESULT: %d checks, %d failures" % [checks, failures])
		quit(0 if failures == 0 else 1)
		return
	clear_enemies()
	var ranged = enemy_at(Vector2(650, 400), 1, 0.0, "fan")
	ranged.attack_cooldown = 3.0
	ranged.contact_cooldown = 1.0
	game.activate_mage_skill(0, 2)
	game.mage_system.advance(0.1)
	var start: Vector2 = ranged.position
	ranged.advance(0.5, mage)
	check(is_equal_approx(ranged.movement_scale, 0.6) and is_equal_approx(ranged.attack_cooldown, 2.675)
		and is_equal_approx(ranged.contact_cooldown, 0.675) and ranged.hp < ranged.max_hp
		and is_equal_approx(start.distance_to(ranged.position), ranged.speed * 0.7 * 0.5 * 0.6),
		"E damages and slows actual movement, ranged attacks, and contact attack recovery")
	mage.frost_remaining = 0.0
	game.mage_system.advance(0.01)
	check(ranged.movement_scale == 1.0 and ranged.attack_scale == 1.0, "frost ending restores enemy speed and attack rate")
	host.position = Vector2(900, 400)
	check(not game.activate_mage_skill(0, 3) and mage.possession_cooldown == 0.0, "R out of range does not consume cooldown")
	host.position = Vector2(650, 400)
	check(game.activate_mage_skill(0, 3) and mage.is_possessed() and not mage.is_targetable()
		and game.nearest_active_player(mage.position) == host and mage.visual_offset().y < -40.0,
		"R attaches above nearby teammate and enemies only select host")
	clear_enemies()
	enemy_at(Vector2(780, 400), 5)
	mage.fireball_cooldown = 0.0
	mage.frost_cooldown = 0.0
	check(game.activate_mage_skill(0, 1) and game.activate_mage_skill(0, 2) and game.activate_skill(0)
		and is_equal_approx(mage.output_damage(), float(mage.stats.damage) * 1.35)
		and is_equal_approx(game.mage_system.fireballs[0].radius, game.Mage.FIREBALL_RADIUS * 1.25),
		"Q/E/Space work while possessed with damage and range bonuses")
	var old: Vector2 = mage.position
	mage.advance(0.4, Vector2.LEFT)
	host.advance(0.4, Vector2.RIGHT)
	game.mage_system.update_links(0.4)
	check(mage.position == host.position and mage.position.x > old.x and is_equal_approx(mage.fireball_cooldown, 14.5),
		"host controls movement and mage cooldown recovers 25% faster")
	var old_hp: float = mage.hp
	mage.invulnerability = 0.0
	mage.take_damage(100.0)
	check(mage.hp == old_hp, "possessed mage cannot independently receive damage")
	var timer: float = mage.possession_remaining
	game.paused = true
	game.simulate(0.5, [Vector2.LEFT, Vector2.RIGHT])
	check(mage.possession_remaining == timer and not game.activate_mage_skill(0, 2), "pause freezes new skills and blocks casts")
	game.paused = false
	host.invulnerability = 0.0
	host.take_damage(10000.0)
	check(host.downed and mage.possession_host == null and mage.position == host.position and mage.is_targetable(),
		"host downing immediately ejects mage at host position")
	host.revive()
	mage.possession_cooldown = 0.0
	game.activate_mage_skill(0, 3)
	game.mage_system.update_links(5.0)
	check(mage.possession_host == null and host.possessed_by == null and mage.is_targetable(), "five seconds end possession cleanly")
	mage.configure_class(game.Classes.MAGE)
	host.configure_class(game.Classes.MAGE)
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_KP_1
	game._unhandled_key_input(event)
	check(host.frost_remaining == 5.0 and mage.frost_remaining == 0.0, "double mage P2 keypad skill does not trigger P1")
	game.free()
	print("MAGE RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
## Exercise real P2 card clicks with both players using the same class.
const Skills = preload("res://scripts/skill_upgrades.gd")
var game
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1

func click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.selected_classes = [0, 0]
	game.start_run()
	var p1 = game.players[0]
	var p2 = game.players[1]
	p2.skill_stats.frost_width = 1.5
	check(p1.skill_stats.frost_width == 1.0, "same-class skill stats are independent")
	p2.skill_stats.frost_width = 1.0
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	p1.offers.assign([Skills.CATALOG[0].duplicate(), Skills.CATALOG[2].duplicate(), Skills.CATALOG[3].duplicate()])
	p2.offers.assign([Skills.CATALOG[1].duplicate(), Skills.CATALOG[2].duplicate(), Skills.CATALOG[3].duplicate()])
	game.hud.refresh()
	await process_frame
	await process_frame
	await click(game.hud.choice_buttons[1][1].picture)
	print("AFTER P2 CLICK: P1 ", p1.skill_ranks, " / ", p1.skill_stats.frost_width, "; P2 ", p2.skill_ranks, " / ", p2.skill_stats.frost_width)
	check(p2.skill_stats.frost_width == 1.5 and p2.skill_ranks.get("frost_width", 0) == 1 and p2.skill_choices == 1, "P2 frost-width icon click upgrades P2")
	check(p1.skill_stats.frost_width == 1.0 and p1.skill_ranks.is_empty() and p1.choosing, "P2 selection leaves P1 skill stats and pending choice unchanged")
	check(is_equal_approx(game.mage_system.frost_radius(p1), 155.0) and is_equal_approx(game.mage_system.frost_radius(p2), 232.5), "actual field radii belong to their caster")
	game.hud.choice_buttons[0][0].pressed.emit()
	game.hud.team_buttons[0].pressed.emit()
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	game.spawn_credit = -1000.0
	game.next_wave = 1000.0
	game.next_boss = 1000.0
	p1.position = Vector2(440, 450)
	p2.position = Vector2(740, 455)
	for player in game.players:
		player.shot_cooldown = 1000.0
	check(game.activate_mage_skill(0, 2) and game.activate_mage_skill(1, 2), "both players cast their own frost")
	game.simulate(0.4, [Vector2.ZERO, Vector2.ZERO])
	var fields = game.mage_system.visuals.fields
	check(fields[0].position == p1.position and fields[1].position == p2.position
		and is_equal_approx(fields[1].scale.x / fields[0].scale.x, 1.5), "rendered P2 field has the upgraded scale and remains centered on P2")
	check("Lv.0" in game.hud.skill_icons[0][1].caption.text and "Lv.1" in game.hud.skill_icons[1][1].caption.text, "each player's frost icon reports its own rank")
	await process_frame
	await process_frame
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/frost_ownership.png") == OK, "ownership screenshot")
	# Check the common mixed-career setup too, with P1 waiting on a different skill.
	p1.configure_class(1)
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	p2.offers.assign([Skills.CATALOG[0].duplicate(), Skills.CATALOG[1].duplicate(), Skills.CATALOG[2].duplicate()])
	game.hud.refresh()
	await process_frame
	await process_frame
	await click(game.hud.choice_buttons[1][2].description)
	check(p2.skill_stats.frost_width == 2.0 and p2.skill_ranks.get("frost_width", 0) == 2 and p1.skill_ranks.is_empty() and p1.choosing, "mixed careers: P2 second-tier frost upgrades only P2 while P1 still chooses")
	game.free()
	print("SKILL OWNERSHIP: ", failures, " failures")
	quit(0 if failures == 0 else 1)

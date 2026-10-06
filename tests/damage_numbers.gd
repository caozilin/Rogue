extends SceneTree
## Only hit-number accounting, overlay visibility, scale and lifetime.
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

func clear_enemies() -> void:
	for enemy in game.enemies: enemy.queue_free()
	game.enemies.clear()
	game.damage_events.clear()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	clear_enemies()
	var font_size = game.DamageNumbers.font_size_for
	check(font_size.call(14.0) < font_size.call(66.0) and font_size.call(66.0) < font_size.call(300.0)
		and font_size.call(100000.0, true) <= 46, "larger damage produces larger text with a bounded maximum")
	check(game.damage_numbers.get_parent() == game and game.damage_numbers.z_index > game.world.z_index + 5, "numbers draw independently above units, possession and projectile effects")
	var bosses: Array = []
	var types := [game.MiniBoss, game.ThornBoss, game.FinalBoss, game.RangedFinalBoss]
	var points := [Vector2(270, 370), Vector2(1000, 370), Vector2(435, 580), Vector2(845, 580)]
	var damages := [14.0, 65.0, 300.0, 1000.0]
	for index in range(4):
		var boss = types[index].new()
		boss.setup_boss(points[index], game.Balance.difficulty(180), 0)
		boss.state = "recover" if index >= 2 else "approach"
		if index > 0: boss.combat_players = game.players
		game.world.add_child(boss)
		game.enemies.append(boss)
		bosses.append(boss)
		game._damage_enemy(boss, damages[index], index % 2, index >= 2)
	check(game.damage_events.size() == 4 and game.damage_events[2].amount == 375 and game.damage_events[3].amount == 1250,
		"all four bosses emit hit numbers using actual recovery-amplified health loss")
	if "--capture" in OS.get_cmdline_user_args():
		game.final_battle = true
		game.final_stage = 2
		game.elapsed = 180.0
		game.mini_boss = bosses[3]
		game.players[0].position = Vector2(560, 460)
		game.players[1].position = Vector2(720, 460)
		game.hud.refresh()
		game.damage_numbers.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		print("SCREENSHOT boss_damage_numbers.png result=", root.get_texture().get_image().save_png("res://artifacts/boss_damage_numbers.png"))
		game.damage_events.clear()
		game.mage_system.elements.damage(bosses[0], 90.0, 0, "ice", true, "frost")
		game.mage_system.elements.damage(bosses[1], 140.0, 0, "fire", true, "fireball")
		game._damage_enemy(bosses[2], 230.0, 0, true, "tower_judgment")
		game.mage_system.elements.attach(bosses[3], "ice")
		game.mage_system.elements.damage(bosses[3], 400.0, 0, "fire", true, "fire_explosion")
		for item in game.damage_events: item.life -= 0.08
		game.damage_numbers.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/element_damage_numbers.png") == OK,
			"capture colored ice/fire/lightning and Chinese x2 reaction pop")
	# Use live elemental entry points, not the generic highlighted flag, to identify reactions.
	var probe = game.Enemy.new()
	probe.setup(Vector2(650, 400), game.Balance.difficulty(0), false)
	probe.hp = 1000000.0
	game.world.add_child(probe)
	game.enemies.append(probe)
	var colors_ok := true
	for source in ["fireball", "fire_explosion", "fire_ground", "burn", "frost", "frost_cones", "lightning_tower", "tower_chain", "tower_tide", "tower_judgment"]:
		game._damage_enemy(probe, 10.0, 0, true, source)
		var expected := "fire" if source in ["fireball", "fire_explosion", "fire_ground", "burn"] else ("ice" if source in ["frost", "frost_cones"] else "lightning")
		colors_ok = colors_ok and game.damage_events.back().element == expected and not game.damage_events.back().reaction
	check(colors_ok and game.DamageNumbers.color_for("fire") != game.DamageNumbers.color_for("ice")
		and game.DamageNumbers.color_for("lightning") != game.DamageNumbers.color_for("ice"), "all three damage families retain distinct element colors even on highlighted hits")
	probe.element_state.clear()
	game.mage_system.elements.attach(probe, "ice")
	game.warrior_system._damage(probe, 10.0, 1, "dash")
	check(game.damage_events.back().element == "physical" and not game.damage_events.back().reaction,
		"pure physical warrior dash does not react with ice attachment")
	game.damage_events.clear()
	probe.element_state.clear()
	game.mage_system.elements.attach(probe, "ice")
	var before: float = probe.hp
	game.mage_system.elements.damage(probe, 100.0, 0, "fire", true, "fireball")
	var fire_reaction: Dictionary = game.damage_events.back()
	check(is_equal_approx(before - probe.hp, 200.0) and fire_reaction.amount == 200
		and fire_reaction.element == "fire" and fire_reaction.reaction and fire_reaction.reaction_label
		and fire_reaction.font_size > font_size.call(200.0, true), "real fire-on-ice double damage gets enlarged reaction text and caption")
	probe.element_state.ice = 0.0
	game.mage_system.elements.damage(probe, 100.0, 0, "fire", true, "fire_ground")
	check(game.damage_events.back().reaction and not game.damage_events.back().reaction_label
		and game.damage_events.back().font_size == fire_reaction.font_size, "ongoing x2 window emphasizes every hit while throttling repeated captions on the same target")
	for item in game.damage_events: item.life -= 0.4
	game.mage_system.elements.damage(probe, 100.0, 0, "fire", true, "burn")
	check(game.damage_events.back().reaction_label, "Chinese reaction caption returns after 0.35 simulation seconds")
	probe.element_state.fire_amp = 0.0
	game.mage_system.elements.damage(probe, 100.0, 0, "fire", true, "fireball")
	check(not game.damage_events.back().reaction and game.damage_events.back().amount == 100, "expired reaction window produces normal elemental damage and size")
	probe.element_state.clear()
	game.damage_events.clear()
	game.mage_system.elements.attach(probe, "fire")
	game.mage_system.elements.damage(probe, 100.0, 0, "ice", true, "frost")
	check(game.damage_events.back().element == "ice" and game.damage_events.back().reaction
		and game.damage_events.back().reaction_label and game.damage_events.back().amount == 200, "ice-on-fire also labels actual x2 reaction in ice color")
	probe.element_state.clear()
	game.players[0].skill_stats.frost_power = 2.0
	game.mage_system.elements.damage(probe, 100.0, 0, "ice", true, "frost_cones")
	check(game.damage_events.back().amount == 200 and not game.damage_events.back().reaction,
		"x2 personal ice power without a reaction does not falsely show a reaction label")
	game.players[0].skill_stats.frost_power = 1.0
	game._damage_enemy(probe, 100.0, 0, true)
	check(game.damage_events.back().critical and game.damage_events.back().element == "physical"
		and not game.damage_events.back().reaction, "physical crit/highlight remains separate from elemental reaction")
	check(font_size.call(100000.0, true, true) <= 56 and font_size.call(1.0, false, true) >= 26,
		"reaction text has a clearly larger minimum and a bounded maximum")
	clear_enemies()
	game.mini_boss = null
	game.final_battle = true
	game.final_stage = 2
	var target = game.Enemy.new()
	target.setup(Vector2(1000, 350), game.Balance.difficulty(0), false)
	target.speed = 0.0
	game.world.add_child(target)
	game.enemies.append(target)
	target.hp = 10.0
	game._damage_enemy(target, 1000.0, 0)
	var event: Dictionary = game.damage_events.back()
	game._damage_enemy(target, 1000.0, 0)
	check(event.amount == 10 and event.font_size == font_size.call(10.0) and game.damage_events.size() == 1, "overkill and dead-target repeats do not inflate number value or size")
	target.dead = false
	target.hp = 1000000.0
	game.damage_events.clear()
	for index in range(65): game._damage_enemy(target, 1.0, 0)
	game._damage_enemy(target, 999.0, 1, true)
	check(game.damage_events.size() == game.DamageNumbers.MAX_EVENTS and game.damage_events.back().amount == 999,
		"busy damage replaces oldest text rather than dropping the newest big hit")
	for player in game.players: player.shot_cooldown = 1000.0
	var life: float = game.damage_events.back().life
	game.paused = true
	game.simulate(0.2, [Vector2.ZERO, Vector2.ZERO])
	var frozen: bool = game.damage_events.back().life == life
	game.paused = false
	game.simulate(0.2, [Vector2.ZERO, Vector2.ZERO])
	var moved: bool = is_equal_approx(game.damage_events.back().life, life - 0.2)
	game.simulate(0.7, [Vector2.ZERO, Vector2.ZERO])
	check(frozen and moved and game.damage_events.is_empty(), "numbers freeze on pause, then rise and expire with simulation time")
	game.free()
	print("DAMAGE NUMBERS RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

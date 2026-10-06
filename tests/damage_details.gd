extends SceneTree
## Only source attribution and the clickable damage details panel.
const Sources = preload("res://scripts/damage_sources.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1

func enemy_at(at: Vector2):
	var enemy = game.Enemy.new()
	enemy.setup(at, game.Balance.difficulty(0.0), false)
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	enemy.speed = 0.0
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	return enemy

func clear_world() -> void:
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	for bullet in game.projectiles: bullet.free()
	game.projectiles.clear()
	game.mage_system.fireballs.clear()
	game.mage_system.cones.clear()
	game.mage_system.elements.fire_contacts.clear()
	for tower in game.mage_system.towers: tower.free()
	game.mage_system.towers.clear()
	game.damage_events.clear()

func amount(id: int, source: String) -> float:
	return float(game.damage_breakdown[id].get(source, 0.0))

func conserved() -> bool:
	for id in range(2):
		var total := 0.0
		var shares := 0.0
		for row in Sources.rows(game, id):
			total += row.amount
			shares += row.share
		if not is_equal_approx(total, game.damage_totals[id]): return false
		if game.damage_totals[id] > 0.0 and not is_equal_approx(shares, 1.0): return false
	return true

func click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame

func snapshot(filename: String) -> void:
	game.hud.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + filename) == OK, "capture " + filename)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	clear_world()
	game.spawn_credit = -1000.0
	game.next_wave = INF
	game.next_boss = INF
	var mage = game.players[0]
	var warrior = game.players[1]
	mage.position = Vector2(450, 410)
	warrior.position = Vector2(750, 410)
	check(game.damage_breakdown == [{}, {}] and Sources.rows(game, 0)[0].share == 0.0,
		"fresh source tables and zero percentages are safe")
	var first = enemy_at(Vector2(550, 410))
	var second = enemy_at(Vector2(450, 510))
	game._fire(mage)
	var sources: Array = []
	for bullet in game.projectiles:
		sources.append(bullet.damage_source)
		var target = first if bullet.damage_source == "auto" else second
		bullet.position = target.position - bullet.velocity.normalized() * 10.0
	game._update_projectiles(0.04)
	game.activate_skill(0)
	game.mage_system.towers[0].advance(0.01)
	check(sources.has("auto") and amount(0, "auto") > 0.0 and amount(0, "lightning_tower") > 0.0,
		"real normal projectiles and lightning tower keep separate source attribution")
	clear_world()
	var target = enemy_at(mage.position + Vector2(80, 0))
	mage.skill_stats.fire_growth = true
	game.activate_mage_skill(0, 1)
	game.mage_system.fireballs[0].life = 0.01
	game.mage_system._advance_fireballs(0.02)
	mage.skill_stats.frost_cones = true
	game.activate_mage_skill(0, 2)
	game.mage_system._advance_frost(0.1)
	game.mage_system._advance_cones(0.4)
	check(amount(0, "fireball") > 0.0 and amount(0, "fire_explosion") > 0.0 and amount(0, "frost") > 0.0 and amount(0, "frost_cones") > 0.0,
		"actual fireball, growth explosion, frost and cone hits reach their own rows")
	clear_world()
	target = enemy_at(warrior.position + Vector2(35, 0))
	warrior.skill_stats.dash_wave = true
	game.activate_skill(1, Vector2.RIGHT)
	game.warrior_system.hit_dash(1, warrior.position, warrior.position + Vector2(70, 0))
	game.warrior_system.advance(0.1)
	game.warrior_system.begin_giant(warrior)
	target.position = warrior.position + Vector2(20, 0)
	var starts: Array[Vector2] = [mage.position, warrior.position]
	game.warrior_system.giant_contacts(starts)
	game.warrior_system._quake(warrior)
	var victim = enemy_at(warrior.position + Vector2(100, 0))
	game.warrior_system._launch_cannon(target, warrior, Vector2.RIGHT, 120.0, 50.0, 0, {})
	target.position = victim.position
	game.warrior_system.after_enemy_move(0.1)
	check(amount(1, "dash") > 0.0 and amount(1, "slash") > 0.0 and amount(1, "giant") > 0.0 and amount(1, "quake") > 0.0 and amount(1, "cannon") > 0.0,
		"actual dash, slash, giant collision, quake and cannon hits have distinct sources")
	clear_world()
	target = enemy_at(Vector2(640, 480))
	var elements = game.mage_system.elements
	var ground_before: float = amount(0, "fire_ground")
	elements.fire_ground(target, 10.0, 0)
	elements.advance(0.2)
	elements.fire_ground(target, 20.0, 1)
	elements.advance(0.3)
	check(is_equal_approx(amount(0, "fire_ground") - ground_before, 2.0) and is_equal_approx(amount(1, "fire_ground"), 6.0),
		"a DOT tick preserves both owners when the active fire source changes")
	for index in range(4):
		elements.fire_ground(target, 20.0, 1)
		elements.advance(0.5)
	check(amount(1, "burn") > 0.0 and amount(1, "fire_ground") > 6.0, "burn and ground fire remain separate sources")
	var final = game.FinalBoss.new()
	final.setup_boss(Vector2(1000, 410), game.Balance.difficulty(180), 0)
	final.state = "recover"
	game.world.add_child(final)
	game.enemies.append(final)
	var prior: float = amount(0, "fireball")
	elements.attach(final, "ice")
	elements.damage(final, 100.0, 0, "fire", true, "fireball")
	check(is_equal_approx(amount(0, "fireball") - prior, 250.0), "reaction and Boss recovery amplification stay in the triggering skill row")
	var priest = game.ThornBoss.new()
	priest.setup_boss(Vector2(1050, 500), game.Balance.difficulty(120), 0)
	game.world.add_child(priest)
	game.enemies.append(priest)
	target.position = priest.position + Vector2(20, 0)
	priest.guards.append(target)
	prior = amount(1, "dash")
	game._damage_enemy(priest, 100.0, 1, true, "dash")
	target.hp = 7.0
	game._damage_enemy(target, 999.0, 1, true, "dash")
	game._damage_enemy(target, 999.0, 1, true, "dash")
	check(is_equal_approx(amount(1, "dash") - prior, 72.0) and conserved(), "armor and overkill use actual loss; all source rows sum to totals and 100%")
	game._damage_enemy(priest, 10000.0, 1, true, "giant")
	game.hud.refresh()
	await process_frame
	await process_frame
	await click(game.hud.damage_rows[0])
	var details = game.hud.damage_details
	var elapsed: float = game.elapsed
	var cooldown: float = mage.fireball_cooldown
	game.simulate(0.2, [Vector2.RIGHT, Vector2.LEFT])
	check(details.visible and details.player_id == 1 and game.elapsed == elapsed and mage.fireball_cooldown == cooldown,
		"clicking sorted P2 row opens P2 details and freezes battle and cooldowns")
	await click(details.tabs[0])
	check(details.player_id == 0 and details.current_rows[0].amount >= details.current_rows[1].amount,
		"P1 tab selects the correct player and sorts their own sources")
	var panel: Control = details.get_child(1)
	check(Rect2(Vector2.ZERO, Vector2(1280, 800)).encloses(panel.get_global_rect()) and panel.get_rect().end.y <= 780.0,
		"details panel and close button fit inside the viewport")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	check(not details.visible and not game.damage_inspecting and not game.paused and game.simulation_speed() == 1.0,
		"ESC closes details and restores battle without entering manual pause")
	game.paused = true
	details.open_player(1)
	details.close()
	check(game.paused and game.simulation_speed() == 0.0, "closing details preserves a preexisting manual pause")
	game.paused = false
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		clear_world()
		game.damage_totals.assign([0.0, 0.0])
		game.damage_breakdown.assign([{}, {}])
		target = enemy_at(Vector2(1020, 390))
		for entry in [["auto", 8200.0], ["fireball", 6350.4], ["frost", 3400.2], ["fire_explosion", 2700.8], ["frost_cones", 1600.5], ["suppression_extra", 950.7], ["fire_ground", 740.2], ["burn", 550.8]]:
			game._damage_enemy(target, entry[1], 0, false, entry[0])
		for entry in [["giant", 14200.4], ["dash", 6100.2], ["auto", 4500.0], ["slash", 1800.8], ["quake", 1400.4], ["cannon", 920.8], ["fire_ground", 320.0], ["burn", 190.2]]:
			game._damage_enemy(target, entry[1], 1, false, entry[0])
		game.elapsed = 120.0
		game.damage_events.clear()
		game.hud.refresh()
		await snapshot("damage_details_board.png")
		await click(game.hud.damage_rows[1])
		await snapshot("damage_details_mage.png")
		await click(details.tabs[1])
		await snapshot("damage_details_warrior.png")
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	fresh.set_physics_process(false)
	check(fresh.damage_breakdown == [{}, {}] and fresh.damage_totals == [0.0, 0.0], "new runs reset amounts and breakdown together")
	fresh.free()
	game.free()
	print("DAMAGE DETAILS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

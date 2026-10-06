extends SceneTree
## Focused checks for the changed warrior skills; no long game simulation.
const MainScene = preload("res://scenes/main.tscn")
const Skills = preload("res://scripts/skill_upgrades.gd")
var game
var warrior
var ally
var system
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

func reset() -> void:
	for pool in [game.enemies, game.projectiles, game.gems, game.enemy_bullets]:
		for node in pool: node.free()
		pool.clear()
	game.damage_events.clear()
	system.slashes.clear()
	system.cannons.clear()
	system.effects.clear()
	system.reflections.clear()
	game.mage_system.grounds.clear()
	game.mage_system.elements.fire_contacts.clear()
	warrior.configure_class(game.Classes.RAIDER)
	ally.configure_class(game.Classes.MAGE)
	for player in game.players:
		player.downed = false
		player.choosing = false
		player.pending_upgrades = 0
		player.offers.clear()
		player.invulnerability = 0.0
		player.shot_cooldown = 100.0
	warrior.position = Vector2(400, 410)
	ally.position = Vector2(900, 410)
	game.spawn_credit = -10000.0
	game.next_wave = INF
	game.next_boss = INF
	game.elapsed = 0.0
	game.paused = false
	game.game_over = false
	game.team_level = 1
	game.shared_xp = 0
	game.team_pending_upgrades = 0
	game.team_choosing = false
	game.team_offers.clear()

func enemy_at(at: Vector2):
	var enemy = game.Enemy.new()
	enemy.setup(at, game.Balance.difficulty(0.0), false)
	enemy.speed = 0.0
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	enemy.xp_value = 0
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	return enemy

func press_key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_key_input(event)

func press_q() -> void:
	press_key(KEY_Q)

func right_click(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = at
	game._unhandled_input(event)

func targeting_checks() -> void:
	press_q()
	check(warrior.dash_remaining == 0.0 and warrior.skill_cooldown == 0.0, "Q without targets does not dash or spend cooldown")
	var low = enemy_at(warrior.position + Vector2(0, 50))
	low.level = 1
	var high = enemy_at(warrior.position + Vector2(350, 0))
	high.level = 5
	var dead = enemy_at(warrior.position + Vector2(-40, 0))
	dead.level = 20
	dead.dead = true
	warrior.last_move_direction = Vector2.LEFT
	press_q()
	check(warrior.last_move_direction == Vector2.RIGHT and warrior.dash_target.x > warrior.position.x
		and ally.fireball_cooldown == 0.0, "P1 Q picks highest living rank instead of nearby lower rank or prior direction")
	reset()
	var near = enemy_at(warrior.position + Vector2(0, -90))
	near.level = 5
	var far = enemy_at(warrior.position + Vector2(250, 0))
	far.level = 5
	Skills.apply(warrior, "dash_recast")
	press_q()
	check(warrior.last_move_direction == Vector2.UP, "equal-rank targets use the fireball nearest-distance rule")
	warrior.advance(0.2, Vector2.ZERO)
	game.hud.refresh()
	check(game.hud.skill_icons[0][0].binding.text == "Q", "second-dash UI also shows Q")
	far.level = 10
	var next_direction: Vector2 = warrior.position.direction_to(far.position)
	press_q()
	check(warrior.dash_second_cast and warrior.last_move_direction.is_equal_approx(next_direction),
		"second Q selects the newest highest-rank target again")
	reset()
	enemy_at(warrior.position + Vector2(250, 0))
	game.paused = true
	press_q()
	game.paused = false
	warrior.pending_upgrades = 1
	press_q()
	check(warrior.dash_remaining == 0.0 and warrior.skill_cooldown == 0.0, "pause and upgrade choices block Q dash")
	warrior.pending_upgrades = 0
	right_click(warrior.position + Vector2(250, 0))
	check(warrior.dash_remaining == 0.0 and ally.fireball_cooldown == 15.0,
		"right-click only fires P2 mage's fireball without casting P1 dash")
	ally.configure_class(game.Classes.RAIDER)
	right_click(ally.position + Vector2(-200, 0))
	check(ally.dash_remaining > 0.0 and ally.last_move_direction == Vector2.LEFT and warrior.dash_remaining == 0.0,
		"P2 warrior keeps its mouse-directed right-click dash independently")
	game.hud.refresh()
	check(game.hud.skill_icons[0][0].binding.text == "Q" and game.hud.skill_icons[1][0].binding.text == "右键",
		"both warrior icons match their player-specific bindings")
	press_key(KEY_E)
	check(warrior.warcry_remaining == 4.0 and ally.warcry_remaining == 0.0, "E only casts P1 warrior Warcry")
	press_key(KEY_R)
	check(warrior.giant_remaining > 0.0 and ally.giant_remaining == 0.0, "R only casts P1 warrior Giant")
	press_key(KEY_SPACE)
	check(warrior.carrying == ally and ally.rescue_cooldown == 0.0, "Space only casts P1 warrior Rescue")
	press_key(KEY_KP_1)
	press_key(KEY_2)
	check(ally.warcry_remaining == 4.0 and ally.giant_remaining > 0.0
		and warrior.warcry_cooldown == 20.0 and warrior.giant_cooldown == 15.0,
		"P2 numeral and numpad skills do not retrigger P1")
	press_key(KEY_KP_3)
	check(ally.carrying == warrior and warrior.carrying == null and warrior.rescue_cooldown == 20.0,
		"P2 numpad 3 independently casts Rescue and replaces the carry link")
	game.hud.refresh()
	var keys_correct := true
	for id in range(2):
		var expected := ["Q", "E", "R", "空格"] if id == 0 else ["右键", "1", "2", "3"]
		for slot in range(4):
			keys_correct = keys_correct and game.hud.skill_icons[id][slot].binding.text == expected[slot]
	check(keys_correct, "warrior HUD uses the unified player-specific four-skill bindings")

func contacts() -> void:
	var starts: Array[Vector2] = [warrior.position, ally.position]
	system.giant_contacts(starts)

func snapshot(filename: String) -> void:
	game.hud.refresh()
	game.queue_redraw()
	system.visuals.queue_redraw()
	game.mage_system.visuals.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	print("SCREENSHOT ", filename, " result=", root.get_texture().get_image().save_png("res://artifacts/" + filename))

func capture() -> void:
	for index in range(3):
		game.add_shared_xp(game.Balance.xp_required(game.team_level))
		if index == 2: break
		game.choose_upgrade(0, 0)
		game.choose_upgrade(1, 0)
		game.choose_team_upgrade(0)
	await snapshot("warrior_major_choices.png")
	reset()
	for id in ["dash_recast", "dash_flame", "dash_wave"]: Skills.apply(warrior, id)
	Skills.apply(warrior, "dash_geometry")
	for at in [Vector2(530, 410), Vector2(680, 410), Vector2(820, 440)]: enemy_at(at)
	game.activate_skill(0, Vector2.RIGHT)
	for tick in range(15): game.simulate(1.0 / 60.0, [Vector2.ZERO, Vector2.ZERO])
	await snapshot("warrior_flame_wave.png")
	reset()
	for id in ["giant_cannon", "giant_quake", "giant_thorns", "rescue_blessing"]: Skills.apply(warrior, id)
	Skills.apply(warrior, "giant_form")
	ally.position = warrior.position + Vector2(20, 40)
	game.activate_warrior_skill(0, 3)
	for index in range(6): enemy_at(warrior.position + Vector2.from_angle(TAU * index / 6.0) * 30.0)
	for index in range(8): enemy_at(warrior.position + Vector2.from_angle(TAU * index / 8.0) * 105.0)
	game.activate_warrior_skill(0, 2)
	for tick in range(12): game.simulate(1.0 / 60.0, [Vector2.ZERO, Vector2.ZERO])
	await snapshot("warrior_cannon_quake_blessing.png")

func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	warrior = game.players[0]
	ally = game.players[1]
	system = game.warrior_system
	reset()
	if "--targeting-only" in OS.get_cmdline_user_args():
		targeting_checks()
		game.free()
		print("WARRIOR TARGETING RESULT: %d checks, %d failures" % [checks, failures])
		quit(0 if failures == 0 else 1)
		return
	if "--capture" in OS.get_cmdline_user_args():
		await capture()
		game.free()
		quit()
		return
	var schedule := true
	for index in range(18):
		game.add_shared_xp(game.Balance.xp_required(game.team_level))
		schedule = schedule and warrior.choosing and ally.choosing and game.simulation_speed() == 0.0
		for player in game.players:
			for offer in player.offers: schedule = schedule and bool(offer.get("major", false)) == (index % 3 == 2)
		game.hud.choice_buttons[0][0].pressed.emit()
		game.hud.team_buttons[0].pressed.emit()
		schedule = schedule and game.simulation_speed() == 0.0
		game.hud.choice_buttons[1][0].pressed.emit()
		schedule = schedule and game.simulation_speed() == 1.0
	check(schedule and warrior.skill_choices == 18 and not Skills.has_available(warrior.role, warrior.skill_ranks), "three mouse windows wait for both roles; majors every third choice and 18 picks exhaust warrior upgrades")
	reset()
	var tiers := true
	for rank in range(1, 4):
		for id in ["dash_geometry", "dash_refund", "giant_form", "giant_force"]: Skills.apply(warrior, id)
		tiers = tiers and is_equal_approx(warrior.skill_stats.hit_radius, 72.0 * Skills.RANGE_TIERS[rank])
		tiers = tiers and is_equal_approx(warrior.skill_stats.distance, 230.0 * Skills.DASH_DISTANCE_TIERS[rank])
		tiers = tiers and warrior.skill_stats.giant_size == Skills.GIANT_SIZE_TIERS[rank] and warrior.skill_stats.giant_duration == Skills.GIANT_TIME_TIERS[rank]
		tiers = tiers and warrior.skill_stats.giant_power == Skills.RANGE_TIERS[rank]
	check(tiers and not Skills.apply(warrior, "giant_force") and not Skills.apply(warrior, "fire_width"), "all requested small-skill tiers are total values, capped at three and isolated by class")
	reset()
	var target = enemy_at(Vector2(520, 410))
	game.activate_skill(0, Vector2.RIGHT)
	game.simulate(0.18, [Vector2.ZERO, Vector2.ZERO])
	check(is_equal_approx(warrior.position.x, 630.0) and is_equal_approx(target.hp, target.max_hp - warrior.output_damage() * 3.2) and target.knockback_remaining == 0.0, "base mouse-direction dash moves 230, damages once and has no knockback")
	for rank in range(1, 4):
		reset()
		for pick in range(rank): Skills.apply(warrior, "dash_refund")
		Skills.apply(warrior, "dash_recast")
		for index in range(16): enemy_at(Vector2(480 + index * 4, 410))
		game.activate_skill(0, Vector2.RIGHT)
		game.simulate(0.18, [Vector2.ZERO, Vector2.ZERO])
		var refund: float = 6.0 * Skills.REFUND_CAPS[rank]
		check(is_equal_approx(warrior.dash_refund_total, refund) and is_equal_approx(warrior.skill_cooldown, 6.0 - refund) and warrior.dash_recast_remaining == 2.0, "refund rank %d respects the per-cycle cap and opens a two-second second cast" % rank)
		game.activate_skill(0, Vector2.LEFT)
		game.simulate(0.18, [Vector2.ZERO, Vector2.ZERO])
		check(is_equal_approx(warrior.position.x, 400.0) and warrior.dash_cycle_hit_ids.size() == 16 and is_equal_approx(warrior.dash_refund_total, refund) and not game.activate_skill(0, Vector2.RIGHT), "second dash uses new direction, shares unique targets and refund cap, with no third cast")
	reset()
	Skills.apply(warrior, "dash_recast")
	game.activate_skill(0, Vector2.RIGHT)
	warrior.advance(0.18, Vector2.ZERO)
	warrior.advance(2.01, Vector2.ZERO)
	check(not game.activate_skill(0, Vector2.RIGHT) and warrior.skill_cooldown > 0.0, "unspent second cast expires while the original cooldown keeps recovering")
	reset()
	Skills.apply(warrior, "dash_flame")
	Skills.apply(warrior, "dash_wave")
	target = enemy_at(Vector2(980, 410))
	game.mage_system.elements.attach(target, "ice")
	game.activate_skill(0, Vector2.RIGHT)
	system.hit_dash(0, warrior.position, warrior.position + Vector2(230, 0))
	system.advance(0.55)
	check(is_equal_approx(target.hp, target.max_hp - warrior.output_damage() * 12.0) and target.knockback_remaining > 0.0, "long-range slash deals high damage, knocks back and inherits fire/ice double-damage reaction")
	var hp: float = target.hp
	system.advance(0.2)
	check(target.hp == hp and system.slashes[0].position.x > game.Balance.ARENA.end.x and game.mage_system.grounds[-1].end.x > game.Balance.ARENA.end.x and game.mage_system.grounds[-1].life == 8.0, "slash hits once and carries eight-second fire terrain beyond the screen edge")
	reset()
	target = enemy_at(warrior.position + Vector2(35, 0))
	game.activate_warrior_skill(0, 2)
	contacts()
	check(warrior.body_scale() == 2.0 and is_equal_approx(target.hp, target.max_hp - warrior.output_damage() * 2.0), "initial giant body is twice normal and collision already deals damage")
	reset()
	for pick in range(3): Skills.apply(warrior, "giant_force")
	target = enemy_at(warrior.position + Vector2(35, 0))
	game.activate_warrior_skill(0, 2)
	contacts()
	check(is_equal_approx(target.hp, target.max_hp - warrior.output_damage() * 5.0) and is_equal_approx(target.knockback_velocity.length() * 0.2, 300.0), "rank-three impact scales both collision damage and knockback by 2.5")
	reset()
	Skills.apply(warrior, "giant_cannon")
	var first = enemy_at(Vector2(438, 410))
	var second = enemy_at(Vector2(510, 410))
	var third = enemy_at(Vector2(568, 410))
	game.activate_warrior_skill(0, 2)
	contacts()
	for step in range(2):
		for enemy in game.enemies: enemy.advance(0.1, warrior)
		system.after_enemy_move(0.1)
	check(second.hp < second.max_hp and third.hp < third.max_hp and third.knockback_remaining > 0.0 and second.stagger_remaining > 0.0 and first.stagger_remaining > 0.0, "actual knocked enemies transfer damage and momentum A to B to C, with stagger on both collision participants")
	system._launch_cannon(first, warrior, Vector2.RIGHT, 120.0, 28.0, 0, {})
	var bounded: int = system.cannons.size()
	system._launch_cannon(first, warrior, Vector2.RIGHT, 120.0, 28.0, 0, {})
	check(system.cannons.size() == bounded and int(warrior.giant_chain_counts[first.get_instance_id()]) == 2, "a cannon enemy is limited to two launches per giant cast")
	first.dead = true
	warrior.giant_chain_counts.clear()
	system._launch_cannon(first, warrior, Vector2.RIGHT, 120.0, 28.0, 0, {})
	check(system.cannons[-1].source == first.get_instance_id(), "a lethal impact still launches the defeated enemy as a cannon")
	reset()
	Skills.apply(warrior, "giant_quake")
	for index in range(20): enemy_at(warrior.position + Vector2.from_angle(TAU * index / 20.0) * 25.0)
	var outside = enemy_at(warrior.position + Vector2(140, 0))
	game.activate_warrior_skill(0, 2)
	contacts()
	check(warrior.giant_quakes == 3 and outside.hp < outside.max_hp and outside.stagger_remaining > 0.0 and outside.knockback_remaining == 0.0, "six distinct impacts trigger quake, capped at three; surrounding victims take damage and stagger without scattering")
	warrior.giant_contact_cooldowns.clear()
	contacts()
	check(warrior.giant_unique_hits.size() == 20 and warrior.giant_quakes == 3, "repeated contact cannot farm distinct-target quake progress")
	reset()
	Skills.apply(warrior, "rescue_blessing")
	ally.position = Vector2(480, 410)
	warrior.stats.max_hp = 200.0
	game.activate_warrior_skill(0, 3)
	warrior.end_carry()
	check(ally.blessing_remaining == 10.0 and ally.blessing_shield == 100.0 and ally.tenacity() == 0.5, "Rescue grants ten-second shelter with half warrior max health as shield and fifty-percent tenacity")
	ally.hp = 40.0
	ally.take_damage(40.0)
	check(ally.hp == 40.0 and is_equal_approx(ally.blessing_shield, 60.0), "shelter shield absorbs damage without extra mitigation")
	ally.advance(1.0, Vector2.ZERO)
	check(is_equal_approx(ally.hp, 40.0 + float(ally.stats.max_hp) * 0.05), "shelter adds three-percent teammate-max-health healing per second to existing regeneration")
	warrior.position = ally.position
	contacts()
	check(ally.blessing_remaining == 9.0 and ally.blessing_shield == 60.0, "contact alone cannot reapply or refill Rescue shelter")
	var remain: float = ally.blessing_remaining
	game.paused = true
	game.simulate(1.0, [Vector2.RIGHT, Vector2.ZERO])
	check(ally.blessing_remaining == remain, "pause freezes warrior effects and shelter timers")
	game.paused = false
	ally.advance(9.0, Vector2.ZERO)
	check(ally.blessing_remaining == 0.0 and ally.blessing_shield == 0.0 and ally.tenacity() == 0.0, "expired shelter removes shield and protection")
	print("WARRIOR BUILDS: ", checks, " checks, ", failures, " failures")
	game.free()
	quit(1 if failures > 0 else 0)

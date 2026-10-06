extends SceneTree
## Only the new upgrade/elements/terrain/ward paths, no soak or unrelated regression.
const MainScene = preload("res://scenes/main.tscn")
const Skills = preload("res://scripts/skill_upgrades.gd")
var game
var mage
var ally
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func clear_world() -> void:
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	for bullet in game.enemy_bullets: bullet.free()
	game.enemy_bullets.clear()
	var system = game.mage_system
	system.fireballs.clear()
	system.salvos.clear()
	system.grounds.clear()
	system.cones.clear()
	system.explosions.clear()
	system.elements.fire_contacts.clear()
	mage.configure_class(game.Classes.MAGE)
	ally.configure_class(game.Classes.RAIDER)
	mage.position = Vector2(450, 410)
	ally.position = Vector2(530, 410)
	game.spawn_credit = -10000.0
	game.next_wave = INF
	game.next_boss = INF

func enemy_at(at: Vector2, elite := false):
	var enemy = game.Enemy.new()
	enemy.setup(at, game.Balance.difficulty(0.0), elite)
	enemy.speed = 0.0
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	return enemy

func snapshot(filename: String) -> void:
	game.hud.refresh()
	game.queue_redraw()
	game.mage_system.visuals.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	print("SCREENSHOT ", filename, " result=", root.get_texture().get_image().save_png("res://artifacts/" + filename))

func capture() -> void:
	for index in range(2):
		game.add_shared_xp(game.Balance.xp_required(game.team_level))
		game.hud.choice_buttons[0][0].pressed.emit()
		game.hud.choice_buttons[1][0].pressed.emit()
		game.hud.team_buttons[0].pressed.emit()
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	await snapshot("mage_major_choices.png")
	game.choose_upgrade(0, 0)
	game.choose_upgrade(1, 0)
	game.choose_team_upgrade(0)
	clear_world()
	for entry in Skills.MAJORS: Skills.apply(mage, entry.id)
	Skills.apply(mage, "fire_count")
	Skills.apply(mage, "fire_width")
	for at in [Vector2(590, 440), Vector2(650, 470), Vector2(760, 405), Vector2(800, 540)]:
		enemy_at(at)
	game.activate_mage_skill(0, 1)
	game.activate_mage_skill(0, 2)
	for tick in range(50): game.simulate(1.0 / 60.0, [Vector2.RIGHT, Vector2.ZERO])
	await snapshot("mage_element_terrain.png")
	clear_world()
	Skills.apply(mage, "fire_growth")
	for index in range(12): enemy_at(Vector2(520 + index * 4, 410))
	game.activate_mage_skill(0, 1)
	game.mage_system.advance(0.05)
	game.mage_system.fireballs[0].life = 0.01
	game.mage_system.advance(0.02)
	await snapshot("mage_growth_explosion.png")

func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	mage = game.players[0]
	ally = game.players[1]
	clear_world()
	if "--capture" in OS.get_cmdline_user_args():
		await capture()
		game.free()
		quit()
		return
	var schedule := true
	for index in range(18):
		game.add_shared_xp(game.Balance.xp_required(game.team_level))
		var majors: bool = index % 3 == 2
		for offer in mage.offers: schedule = schedule and bool(offer.get("major", false)) == majors
		schedule = schedule and mage.choosing and ally.choosing
		game.hud.choice_buttons[0][0].pressed.emit()
		schedule = schedule and game.simulation_speed() == 0.0
		game.hud.choice_buttons[1][0].pressed.emit()
		game.hud.team_buttons[0].pressed.emit()
		schedule = schedule and game.simulation_speed() == 1.0
	check(schedule and mage.skill_choices == 18 and mage.skill_ranks.size() == 10,
		"every 3rd pick offers a unique major; all three mouse windows wait, all 18 choices remain reachable")
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	game.choose_team_upgrade(0)
	check(not game.has_pending_upgrades(), "all personal upgrades capped: no empty window blocks play")
	clear_world()
	ally.configure_class(game.Classes.MAGE)
	mage.skill_choices = 2
	ally.skill_choices = 1
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	var independent := bool(mage.offers[0].get("major", false)) and not bool(ally.offers[0].get("major", false))
	game.hud.choice_buttons[0][0].pressed.emit()
	independent = independent and ally.choosing and game.simulation_speed() == 0.0
	game.hud.choice_buttons[1][0].pressed.emit()
	game.hud.team_buttons[0].pressed.emit()
	check(independent and mage.skill_choices == 3 and ally.skill_choices == 2 and game.simulation_speed() == 1.0,
		"two mages have independent ordinary/major schedules and both must finish mouse choices")
	clear_world()
	var tiers := true
	for rank in range(3):
		for id in ["fire_width", "fire_count", "frost_width", "frost_rate"]: Skills.apply(mage, id)
		tiers = tiers and is_equal_approx(float(mage.skill_stats.fire_width), [1.5, 2.0, 2.5][rank])
		tiers = tiers and int(mage.skill_stats.fire_count) == rank + 2 and int(mage.skill_stats.frost_rate) == rank + 2
	check(tiers and not Skills.apply(mage, "fire_width") and not Skills.apply(mage, "radial_evolution"),
		"range/count/rate use exact total tiers, cap at 3, and removed evolution cannot be selected")
	var initial = enemy_at(Vector2(650, 410))
	game.activate_mage_skill(0, 1)
	mage.position = Vector2(430, 490)
	initial.level = 1
	var newer = enemy_at(Vector2(430, 640))
	newer.level = 20
	game.mage_system.advance(0.3)
	check(game.mage_system.fireballs.size() == 2 and game.mage_system.fireballs[1].direction.is_equal_approx(Vector2.DOWN)
		and game.mage_system.fireballs[1].position.x == 430.0, "delayed fireball uses newest caster position and highest-level target")
	game.mage_system.advance(0.6)
	check(game.mage_system.fireballs.size() == 4 and game.mage_system.salvos.is_empty(), "four fireballs are emitted at 0.3s intervals from one cooldown")
	clear_world()
	var pulse_target = enemy_at(Vector2(530, 410))
	for rank in range(3): Skills.apply(mage, "frost_rate")
	game.activate_mage_skill(0, 2)
	var pulse_hp: float = pulse_target.hp
	game.mage_system.advance(0.5)
	check(is_equal_approx(pulse_hp - pulse_target.hp, mage.output_damage() * game.Mage.FROST_DAMAGE * 4.0),
		"quadruple frost frequency deals four full damage pulses in one base interval")
	clear_world()
	var target = enemy_at(Vector2(530, 410))
	game.activate_mage_skill(0, 1)
	game.mage_system.advance(0.05)
	check(target.position == Vector2(530, 410), "base fireball still has no knockback")
	game.mage_system.fireballs.clear()
	mage.fireball_cooldown = 0.0
	Skills.apply(mage, "fire_push")
	game.activate_mage_skill(0, 1)
	game.mage_system.advance(0.05)
	check(target.position.x > 530.0, "knockback is granted only by the new major")
	clear_world()
	target = enemy_at(Vector2(600, 410))
	var elements = game.mage_system.elements
	elements.attach(target, "ice")
	var hp: float = target.hp
	elements.damage(target, 10.0, 0, "fire")
	check(is_equal_approx(hp - target.hp, 20.0) and float(target.element_state.fire_amp) == 3.0,
		"fire hits ice attachment: 3-second double fire damage")
	hp = target.hp
	elements.damage(target, 10.0, 0, "ice")
	check(is_equal_approx(hp - target.hp, 20.0), "ice hits fire attachment: double ice damage")
	elements.advance(3.1)
	hp = target.hp
	elements.damage(target, 10.0, 0, "fire")
	check(is_equal_approx(hp - target.hp, 10.0), "element tags and double-damage windows expire")
	clear_world()
	target = enemy_at(Vector2(530, 410))
	Skills.apply(mage, "fire_ground")
	game.activate_mage_skill(0, 1)
	game.mage_system.advance(0.1)
	check(not game.mage_system.grounds.is_empty() and game.mage_system.grounds[0].element == "fire", "fireball path leaves persistent fire terrain")
	game.mage_system.fireballs.clear()
	game.mage_system.grounds.clear()
	game.mage_system._ground("fire", target.position, target.position, 50.0, mage, 5.0)
	hp = target.hp
	for tick in range(20): game.mage_system.advance(0.11)
	check(float(target.element_state.burn) > 0.0 and target.hp < hp and float(target.element_state.fire) > 0.0,
		"fire terrain attaches fire, damages over time, and continuous 2s exposure ignites burn")
	game.mage_system.grounds.clear()
	hp = target.hp
	game.mage_system.advance(0.6)
	check(target.hp < hp and float(target.element_state.exposure) == 0.0, "burn keeps damaging after leaving terrain; continuous exposure resets")
	clear_world()
	Skills.apply(mage, "fire_growth")
	for index in range(12): enemy_at(Vector2(520 + index * 4, 410))
	game.activate_mage_skill(0, 1)
	game.mage_system.advance(0.05)
	var ball: Dictionary = game.mage_system.fireballs[0]
	check(int(ball.stage) == 4 and float(ball.radius) > float(ball.base_radius), "new targets grow fireball up to 4 stages")
	hp = game.enemies[0].hp
	ball.life = 0.01
	game.mage_system.advance(0.02)
	check(game.mage_system.fireballs.is_empty() and game.mage_system.explosions.size() == 1
		and game.enemies[0].hp < hp, "growing fireball ends with damaging explosion based on final size")
	clear_world()
	Skills.apply(mage, "fire_growth")
	target = enemy_at(Vector2(530, 410), true)
	game.activate_mage_skill(0, 1)
	game.mage_system.advance(0.05)
	game.mage_system.advance(0.21)
	check(is_equal_approx(float(game.mage_system.fireballs[0].energy), 1.15), "elite repeated hits grant less growth than a new enemy")
	clear_world()
	Skills.apply(mage, "frost_cones")
	Skills.apply(mage, "frost_path")
	target = enemy_at(Vector2(540, 410))
	game.activate_mage_skill(0, 2)
	mage.position += Vector2(35, 0)
	game.mage_system.advance(0.1)
	check(game.mage_system.cones.size() == 1 and game.mage_system.grounds.size() == 1
		and game.mage_system.grounds[0].element == "ice", "frost field seeks ice cones and moving leaves ice terrain")
	hp = target.hp
	game.mage_system.advance(0.3)
	check(bool(game.mage_system.cones[0].hit) and target.hp < hp - mage.output_damage(), "falling cone causes high ice area damage")
	mage.frost_remaining = 0.0
	game.mage_system.advance(1.0)
	check(target.movement_scale == 0.6 and target.attack_scale == 0.65, "ice path continues attaching ice and slowing both rates after E ends")
	game.mage_system.advance(8.0)
	check(game.mage_system.grounds.is_empty(), "terrain expires within 8 seconds")
	clear_world()
	Skills.apply(mage, "frost_ward")
	Skills.apply(mage, "frost_width")
	game.activate_mage_skill(0, 2)
	check(is_equal_approx(game.mage_system.frost_radius(mage), game.Mage.FROST_RADIUS * float(mage.skill_stats.frost_width)) and ally.cold_ward_protection,
		"ward retains upgraded field radius and protects nearby ally")
	ally.invulnerability = 0.0
	hp = ally.hp
	ally.giant_remaining = 1.0
	ally.take_damage(40.0)
	check(is_equal_approx(hp - ally.hp, 6.0) and ally.tenacity() == 0.5, "independent 25% ward mitigation stacks with giant reduction; tenacity is 50%")
	var old: Vector2 = ally.position
	ally.knock_back(Vector2.RIGHT, 40.0)
	check(is_equal_approx(ally.position.x - old.x, 20.0), "ward tenacity halves actual knockback displacement")
	var bullet = game.EnemyBullet.new()
	bullet.position = mage.position - Vector2(game.mage_system.frost_radius(mage) + 45, 0)
	bullet.velocity = Vector2(500, 0)
	bullet.damage = 20.0
	game.world.add_child(bullet)
	game.enemy_bullets.append(bullet)
	game._update_enemy_attacks(0.5)
	check(game.enemy_bullets.is_empty() and is_equal_approx(mage.frost_shield_hp, 130.0), "ward intercepts hostile bullet at boundary and consumes shield HP")
	bullet = game.EnemyBullet.new()
	bullet.damage = 1000.0
	check(game.mage_system.intercept_bullet(mage.position, mage.position + Vector2(10, 0), bullet)
		and mage.frost_remaining == 0.0 and not ally.cold_ward_protection, "shield breaking ends the field and removes ally protection")
	bullet.free()
	game.free()
	print("MAGE BUILDS RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

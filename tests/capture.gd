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
	if "--frost-only" in OS.get_cmdline_user_args():
		game.start_run()
		for enemy in game.enemies: enemy.free()
		game.enemies.clear()
		game.spawn_credit = -1000.0
		game.next_wave = 1000.0
		game.next_boss = 1000.0
		var mage = game.players[0]
		var ally = game.players[1]
		mage.position = Vector2(480, 470)
		ally.position = Vector2(570, 505)
		for player in game.players:
			player.shot_cooldown = 1000.0
			player.invulnerability = 0.0
		for index in range(4):
			var enemy = game.Enemy.new()
			enemy.setup(Vector2(720 + index * 105, 360 + (index % 2) * 170), game.Balance.difficulty(0.0), false, ["normal", "fan", "ring", "mortar"][index])
			enemy.speed = 0.0
			enemy.attack_cooldown = 1000.0
			game.world.add_child(enemy)
			game.enemies.append(enemy)
		assert(game.activate_mage_skill(0, 2))
		game.simulate(0.82, [Vector2.ZERO, Vector2.ZERO])
		await screenshot("frost_refined.png")
		mage.frost_remaining = 0.0
		mage.frost_cooldown = 0.0
		mage.skill_stats.frost_ward = true
		assert(game.activate_mage_skill(0, 2))
		game.simulate(0.82, [Vector2.ZERO, Vector2.ZERO])
		assert(game.mage_system.ward_visuals.shells[0].visible and ally.cold_ward_protection)
		await screenshot("frost_ward.png")
		var bullet = game.EnemyBullet.new()
		bullet.damage = 25.0
		assert(game.mage_system.intercept_bullet(mage.position + Vector2(220, 0), mage.position, bullet))
		assert(is_equal_approx(mage.frost_shield_hp, 125.0))
		game.mage_system.advance(0.08)
		await screenshot("frost_ward_hit.png")
		var frozen_time: float = game.elapsed
		var frozen_life: float = game.mage_system.ward_impacts[0].life
		game.paused = true
		game.simulate(0.5, [Vector2.ZERO, Vector2.ZERO])
		assert(game.elapsed == frozen_time and game.mage_system.ward_impacts[0].life == frozen_life)
		assert(is_equal_approx(game.mage_system.ward_visuals.shells[0].material.get_shader_parameter("effect_time"), frozen_time))
		game.paused = false
		bullet.damage = 130.0
		assert(game.mage_system.intercept_bullet(mage.position + Vector2(220, 0), mage.position, bullet))
		game.mage_system.advance(0.12)
		assert(not game.mage_system.ward_visuals.shells[0].visible and not ally.cold_ward_protection and mage.frost_remaining == 0.0)
		await screenshot("frost_ward_break.png")
		game.mage_system.advance(0.5)
		assert(game.mage_system.ward_impacts.is_empty())
		print("FROST VISUAL CHECK PASS: field / ward / hit / break / pause / cleanup")
		bullet.free()
		game.free()
		quit()
		return
	if "--visibility-only" in OS.get_cmdline_user_args():
		game.start_run()
		for enemy in game.enemies: enemy.free()
		game.enemies.clear()
		game.players[0].position = Vector2(430, 440)
		game.players[1].position = Vector2(660, 460)
		for player in game.players:
			player.invulnerability = 999.0
			player.shot_cooldown = 1000.0
		var boss = game.MiniBoss.new()
		boss.setup_boss(Vector2(825, 430), game.Balance.difficulty(60.0), 100)
		boss.hp = 99999.0
		boss.max_hp = 99999.0
		boss.speed = 0.0
		boss.state = "windup"
		boss.boss_attack = "charge"
		boss.attack_windup = 99.0
		boss.attack_direction = Vector2.LEFT
		game.world.add_child(boss)
		game.enemies.append(boss)
		game.mini_boss = boss
		game.activate_mage_skill(0, 1)
		for tick in range(65):
			game.simulate(1.0 / 60.0, [Vector2.ZERO, Vector2.ZERO])
		for player in game.players:
			player.invulnerability = 0.0
			player.queue_redraw()
		await screenshot("visibility_fireball_boss.png")
		assert(not game.hud.boss_background.get_rect().intersects(game.Balance.ARENA))
		game.players[1].configure_class(game.Classes.MAGE)
		for player in game.players:
			player.skill_stats.fire_count = 4
			player.skill_stats.fire_width = 2.5
			player.fireball_cooldown = 0.0
			player.invulnerability = 999.0
		game.activate_mage_skill(0, 1)
		game.activate_mage_skill(1, 1)
		var second = game.ThornBoss.new()
		second.setup_boss(Vector2(1010, 550), game.Balance.difficulty(120.0), 100)
		second.speed = 0.0
		second.attack_cooldown = 999.0
		game.world.add_child(second)
		game.enemies.append(second)
		for tick in range(57):
			game.simulate(1.0 / 60.0, [Vector2.ZERO, Vector2.ZERO])
		for player in game.players:
			player.invulnerability = 0.0
			player.queue_redraw()
		await screenshot("visibility_fireball_overlap.png")
		assert(not game.hud.boss_background.get_rect().intersects(game.Balance.ARENA))
		assert(game.hud.other_boss_hint.visible and not game.hud.footer.visible)
		game.free()
		quit()
		return
	if "--visual-style-only" in OS.get_cmdline_user_args():
		await screenshot("realistic_class_selection.png")
		game.start_run()
		for enemy in game.enemies: enemy.free()
		game.enemies.clear()
		game.players[0].position = Vector2(420, 470)
		game.players[1].position = Vector2(755, 565)
		for player in game.players:
			player.invulnerability = 0.0
			player.shot_cooldown = 1000.0
			player.queue_redraw()
		var locations := [Vector2(1000, 450), Vector2(800, 335), Vector2(220, 340), Vector2(1040, 580), Vector2(610, 290), Vector2(350, 590)]
		var kinds := ["normal", "elite", "fan", "mortar", "sweep", "ring"]
		for index in range(locations.size()):
			var enemy = game.Enemy.new()
			enemy.setup(locations[index], game.Balance.difficulty(0.0), index == 1, kinds[index])
			enemy.hp = 9999.0
			enemy.max_hp = 9999.0
			enemy.speed = 0.0
			enemy.attack_cooldown = 1000.0
			enemy.level = 30 if index == 0 else 1
			game.world.add_child(enemy)
			game.enemies.append(enemy)
		await screenshot("realistic_gameplay.png")
		game.activate_mage_skill(0, 1)
		game.activate_mage_skill(0, 2)
		for tick in range(72):
			game.simulate(1.0 / 60.0, [Vector2.ZERO, Vector2.ZERO])
		await screenshot("realistic_spells.png")
		var frozen_time: float = game.elapsed
		var frozen_position: Vector2 = game.mage_system.fireballs[0].position
		game.paused = true
		game.simulate(0.5, [Vector2.ZERO, Vector2.ZERO])
		assert(game.elapsed == frozen_time and game.mage_system.fireballs[0].position == frozen_position, "Spell animation must freeze when paused")
		assert(is_equal_approx(game.mage_system.visuals.flames[0].material.get_shader_parameter("effect_time"), frozen_time), "Shader clock must follow simulation time")
		game.paused = false
		game.simulate(5.0, [Vector2.ZERO, Vector2.ZERO])
		assert(game.mage_system.fireballs.is_empty() and not game.mage_system.visuals.flames[0].visible and not game.mage_system.visuals.fields[0].visible, "Expired spells must release their visual pool slots")
		for enemy in game.enemies: enemy.free()
		game.enemies.clear()
		for index in range(3):
			var boss = [game.MiniBoss, game.ThornBoss, game.FinalBoss][index].new()
			boss.setup_boss(Vector2(300 + index * 340, 390), game.Balance.difficulty(90.0), 100)
			game.world.add_child(boss)
			game.enemies.append(boss)
		await screenshot("realistic_bosses.png")
		print("VISUAL CHECKS PASS: shader pause, effect cleanup, class portraits, creatures and bosses")
		game.free()
		quit()
		return
	if "--skill-ui-only" in OS.get_cmdline_user_args():
		await screenshot("class_portraits.png")
		game.start_run()
		game.players[0].position = Vector2(430, 440)
		game.players[1].position = Vector2(760, 440)
		for player in game.players:
			player.invulnerability = 0.0
			player.queue_redraw()
		await screenshot("skill_icons_ready.png")
		for player in game.players:
			player.invulnerability = 999.0
		var target = game.Enemy.new()
		target.setup(Vector2(1030, 500), game.Balance.difficulty(0.0), false)
		target.hp = 9999.0
		target.max_hp = 9999.0
		target.speed = 0.0
		game.world.add_child(target)
		game.enemies.append(target)
		game.players[0].position = Vector2(630, 440)
		game.activate_mage_skill(0, 3)
		game.simulate(0.1, [Vector2.ZERO, Vector2.ZERO])
		game.players[0].end_possession()
		game.activate_warrior_skill(1, 3)
		game.players[1].end_carry()
		game.players[0].position = Vector2(430, 440)
		game.players[1].position = Vector2(760, 440)
		game.activate_mage_skill(0, 1)
		game.activate_mage_skill(0, 2)
		game.activate_skill(0)
		game.activate_warrior_skill(1, 1)
		game.activate_warrior_skill(1, 2)
		game.activate_skill(1, Vector2.UP)
		for tick in range(150):
			game.simulate(1.0 / 30.0, [Vector2.ZERO, Vector2.ZERO])
		for player in game.players:
			player.invulnerability = 0.0
			player.queue_redraw()
		await screenshot("skill_icons_cooldown.png")
		game.free()
		quit()
		return
	if "--warrior-only" in OS.get_cmdline_user_args():
		await screenshot("warrior_classes.png")
		game.start_run()
		for enemy in game.enemies: enemy.free()
		game.enemies.clear()
		game.players[0].position = Vector2(430, 440)
		game.players[1].position = Vector2(750, 440)
		game.players[1].invulnerability = 0.0
		for player in game.players: player.shot_cooldown = 1000.0
		for index in range(2):
			var enemy = game.Enemy.new()
			enemy.setup(Vector2(800, 440) if index == 0 else Vector2(750, 505), game.Balance.difficulty(0.0), index == 1)
			enemy.speed = 0.0
			game.world.add_child(enemy)
			game.enemies.append(enemy)
		game.activate_warrior_skill(1, 1)
		game.activate_warrior_skill(1, 2)
		for tick in range(3):
			game.simulate(1.0 / 60.0, [Vector2.ZERO, Vector2.ZERO])
		await screenshot("warrior_skills.png")
		game.activate_warrior_skill(1, 3)
		game.simulate(0.1, [Vector2.LEFT, Vector2.RIGHT])
		game.activate_skill(0)
		await screenshot("warrior_rescue.png")
		game.free()
		quit()
		return
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
	if "--final-boss-only" in OS.get_cmdline_user_args():
		game.elapsed = game.Balance.FINAL_BOSS_SECONDS
		game._update_spawning(0.0)
		var king = game.mini_boss
		game.players[0].position = Vector2(850, 430)
		game.players[1].position = Vector2(450, 490)
		king.position = Vector2(640, 430)
		king.set_priority_target(game.players[0], true)
		king.state = "approach"
		king.attack_step = 1
		king.attack_cooldown = 0.0
		king.advance(0.001, game.players[0])
		king.advance(0.25, game.players[0])
		await screenshot("final_boss_dash.png")
		king.state = "approach"
		king.attack_step = 3
		king.attack_cooldown = 0.0
		king.advance(0.001, game.players[0])
		king.advance(0.3, game.players[0])
		await screenshot("final_boss_blink.png")
		king.advance(0.7, game.players[0])
		king.advance(0.2, game.players[0])
		await screenshot("final_boss_blink_slash.png")
		king.position = Vector2(640, 440)
		game.players[0].position = Vector2(740, 440)
		game.players[1].position = Vector2(440, 480)
		king.state = "approach"
		king.hit(king.max_hp * 0.72)
		king.attack_step = 2
		king.attack_cooldown = 0.0
		king.advance(0.001, game.players[0])
		king.advance(0.3, game.players[0])
		await screenshot("final_boss_slam.png")
		king.state = "approach"
		king.attack_step = 0
		king.attack_cooldown = 0.0
		king.advance(0.001, game.players[0])
		king.advance(0.5, game.players[0])
		king.advance(0.02, game.players[0])
		king.advance(0.15, game.players[0])
		await screenshot("final_boss_combo.png")
		game._damage_enemy(king, king.hp + 100, 0)
		game._update_projectiles(0.0)
		await screenshot("final_boss_transition.png")
		game._update_spawning(3.0)
		game._damage_enemy(game.mini_boss, game.mini_boss.hp + 100, 0)
		game._update_projectiles(0.0)
		await screenshot("final_boss_victory.png")
		game.free()
		quit()
		return
	if "--thorn-boss-only" in OS.get_cmdline_user_args():
		for enemy in game.enemies: enemy.free()
		game.enemies.clear()
		game.elapsed = game.Balance.FIRST_BOSS_SECONDS + game.Balance.BOSS_INTERVAL
		game.boss_encounters = 1
		game._spawn_mini_boss()
		var priest = game.mini_boss
		priest.position = Vector2(640, 335)
		game.players[0].position = Vector2(455, 495)
		game.players[1].position = Vector2(825, 495)
		game._queue_boss_support(priest, 2)
		game._flush_boss_support()
		# Fixed locations display the shield and telegraphs without playing a full run.
		for index in range(priest.guards.size()):
			priest.guards[index].position = priest.position + Vector2(-105 if index == 0 else 110, 35)
			priest.guards[index].queue_redraw()
		priest.state = "approach"
		priest.attack_step = 1
		priest.attack_cooldown = 0.0
		priest.advance(0.01, game.players[0])
		priest.advance(0.3, game.players[0])
		await screenshot("thorn_boss_shield.png")
		priest.advance(1.1, game.players[0])
		game._update_enemy_attacks(0.5)
		await screenshot("thorn_boss_fault.png")
		for hazard in game.enemy_hazards: hazard.free()
		game.enemy_hazards.clear()
		priest.hit(priest.max_hp * 0.85)
		priest.state = "approach"
		priest.attack_step = 2
		priest.attack_cooldown = 0.0
		priest.advance(0.01, game.players[0])
		priest.advance(1.1, game.players[0])
		game._update_enemy_attacks(1.1)
		await screenshot("thorn_boss_roots.png")
		game._damage_enemy(priest, priest.hp * 2.0 + 100.0, 0)
		game._update_projectiles(0.0)
		await screenshot("thorn_boss_reward.png")
		game.free()
		quit()
		return
	if "--boss-only" in OS.get_cmdline_user_args():
		for enemy in game.enemies: enemy.free()
		game.enemies.clear()
		game.elapsed = game.Balance.FIRST_BOSS_SECONDS
		game.next_wave = 100.0
		game._spawn_mini_boss()
		var boss = game.mini_boss
		boss.position = Vector2(635, 335)
		boss.state = "approach"
		boss.attack_cooldown = 0.0
		game.players[0].position = Vector2(470, 475)
		game.players[1].position = Vector2(820, 460)
		boss.advance(0.01, game.players[0])
		boss.advance(0.25, game.players[0])
		await screenshot("mini_boss_fan.png")
		boss.advance(0.6, game.players[0])
		game._update_enemy_attacks(0.45)
		boss.hit(boss.max_hp * 0.56)
		boss.advance(1.9, game.players[0])
		boss.advance(0.01, game.players[0])
		boss.advance(0.25, game.players[0])
		await screenshot("mini_boss_rage.png")
		boss.advance(0.7, game.players[0])
		game._update_enemy_attacks(0.5)
		boss.advance(1.2, game.players[0])
		boss.advance(0.01, game.players[0])
		boss.advance(0.25, game.players[0])
		await screenshot("mini_boss_charge.png")
		game._damage_enemy(boss, boss.hp + 100.0, 0)
		game._update_projectiles(0.0)
		await screenshot("mini_boss_reward.png")
		game.free()
		quit()
		return
	if "--evolutions-only" in OS.get_cmdline_user_args():
		for enemy in game.enemies: enemy.free()
		game.enemies.clear()
		for index in range(3):
			game.add_shared_xp(game.Balance.xp_required(game.team_level))
			if index < 2:
				game.choose_upgrade(0, 0)
				game.choose_upgrade(1, 0)
				game.choose_team_upgrade(0)
		await screenshot("evolution_choices.png")
		game.choose_upgrade(0, 0)
		game.choose_upgrade(1, 0)
		game.choose_team_upgrade(0)
		game.players[0].position = Vector2(420, 420)
		game.players[1].position = Vector2(720, 420)
		for at in [Vector2(800, 470), Vector2(850, 375)]:
			var enemy = game.Enemy.new()
			enemy.setup(at, game.Balance.difficulty(0.0), false)
			enemy.hp = 1000.0
			enemy.max_hp = 1000.0
			enemy.speed = 0.0
			game.world.add_child(enemy)
			game.enemies.append(enemy)
		game.activate_skill(0)
		game.activate_skill(1, Vector2.RIGHT)
		for tick in range(8):
			game.simulate(1.0 / 60.0, [Vector2.RIGHT, Vector2.ZERO])
		await screenshot("evolved_skills.png")
		game.free()
		quit()
		return
	if "--barrage-only" in OS.get_cmdline_user_args():
		for enemy in game.enemies: enemy.free()
		game.enemies.clear()
		game.elapsed = 160.0
		game.next_wave = 166.0
		game.players[0].position = Vector2(520, 420)
		game.players[1].position = Vector2(760, 420)
		var locations := [Vector2(300, 300), Vector2(920, 280), Vector2(270, 550), Vector2(1030, 580)]
		for index in range(4):
			var enemy = game.Enemy.new()
			var kind: String = ["fan", "ring", "sweep", "mortar"][index]
			enemy.setup(locations[index], game.Balance.difficulty(game.elapsed), false, kind)
			enemy.ranged_attack.connect(game._fire_enemy_pattern)
			game.world.add_child(enemy)
			game.enemies.append(enemy)
			enemy.attack_cooldown = 0.0
			enemy.advance(0.01, game.nearest_active_player(enemy.position))
			enemy.advance(0.35, game.nearest_active_player(enemy.position))
		await screenshot("barrage_warnings.png")
		for enemy in game.enemies: enemy.advance(0.65, game.nearest_active_player(enemy.position))
		game._update_enemy_attacks(0.25)
		for enemy in game.enemies: enemy.advance(0.64, game.nearest_active_player(enemy.position))
		await screenshot("barrage_patterns.png")
		game._update_enemy_attacks(0.91)
		await screenshot("barrage_mortar.png")
		game.free()
		quit()
		return
	if "--pressure-only" in OS.get_cmdline_user_args():
		await screenshot("opening_pressure.png")
		game.elapsed = 125.0
		game.next_wave = 144.0
		for index in range(4):
			var enemy = game.Enemy.new()
			var kind: String = ["runner", "brute", "charger", "elite"][index]
			enemy.setup(Vector2(330 + index * 200, 565), game.Balance.difficulty(game.elapsed), kind == "elite", kind)
			game.world.add_child(enemy)
			game.enemies.append(enemy)
			if kind == "charger":
				enemy.charge_cooldown = 0.0
				enemy.advance(0.01, game.players[1])
		await screenshot("enemy_variants.png")
		game.free()
		quit()
		return
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

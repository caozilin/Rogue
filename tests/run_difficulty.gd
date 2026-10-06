extends SceneTree
## Only lobby difficulty, free opening majors and enemy/second-life scaling.
const Main = preload("res://scenes/main.tscn")
const Skills = preload("res://scripts/skill_upgrades.gd")
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

func capture(game, name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	game.hud.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	print("SCREENSHOT ", root.get_texture().get_image().save_png("res://artifacts/" + name + ".png"))

func run() -> void:
	for level in range(3):
		var game = Main.instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		game.hud.class_menu.difficulty_buttons[level].pressed.emit()
		var tuning: Dictionary = game.Balance.RUN_DIFFICULTIES[level]
		check(game.selected_difficulty == level and game.selecting_classes, "mouse selects difficulty %d before combat" % level)
		if level == 2: await capture(game, "difficulty_menu")
		game.start_run()
		if level > 0:
			var frozen: float = game.elapsed
			game.simulate(0.5, [Vector2.RIGHT, Vector2.ZERO])
			check(game.elapsed == frozen and game.enemies.is_empty() and game.choosing_opening_majors(), "opening choices freeze combat before initial enemies spawn")
			if level == 2: await capture(game, "difficulty_opening")
			for id in range(2):
				for gift in range(level):
					var player = game.players[id]
					var valid: bool = player.offers.size() == 3
					for offer in player.offers:
						valid = valid and bool(offer.get("major", false)) and not player.skill_ranks.has(offer.id)
					check(valid, "opening offers only unowned career majors, player %d gift %d" % [id, gift])
					game.hud.choice_buttons[id][0].pressed.emit()
				if id == 0: check(game.simulation_speed() == 0.0, "first player finishing cannot resume before teammate choices")
		check(not game.has_pending_upgrades() and game.simulation_speed() == 1.0
			and game.players[0].skill_ranks.size() == level and game.players[1].skill_ranks.size() == level
			and game.players[0].skill_choices == 0 and game.players[1].skill_choices == 0
			and game.players[0].ranks.is_empty() and game.team_level == 1, "each player gets the exact free major count without consuming normal upgrades or global buffs")
		var ordinary = game.enemies[0]
		check(is_equal_approx(ordinary.hp, 36.0 * float(tuning.health))
			and is_equal_approx(ordinary.damage, 22.0 * float(tuning.damage)), "ordinary enemy health and damage match chosen difficulty")
		game._fire_enemy_pattern(ordinary, "fan", Vector2.RIGHT, Vector2.ZERO)
		check(is_equal_approx(game.enemy_bullets[0].damage, 22.0 * float(tuning.damage)), "projectiles inherit enemy multiplier exactly once")
		for upgrade in range(3):
			game.add_shared_xp(game.Balance.xp_required(game.team_level))
			if upgrade == 2:
				check(bool(game.players[0].offers[0].major) and bool(game.players[1].offers[0].major), "third normal personal upgrade still offers majors after opening gifts")
			game.choose_team_upgrade(0)
			for id in range(2): game.choose_upgrade(id, 0)
		game.elapsed = 60.0
		game._spawn_mini_boss()
		check(is_equal_approx(game.mini_boss.hp, 5000.0 * float(tuning.health))
			and is_equal_approx(game.mini_boss.damage, game.Balance.boss_damage(60.0) * float(tuning.damage)), "minibosses scale health and fixed attack damage")
		game.elapsed = 120.0
		game._spawn_mini_boss()
		var summoner = game.mini_boss
		game._queue_boss_support(summoner, 1)
		game._flush_boss_support()
		check(is_equal_approx(summoner.guards[0].hp, float(game.Balance.difficulty(120.0).health) * 1.35 * float(tuning.health))
			and is_equal_approx(summoner.guards[0].damage, 24.0 * float(tuning.damage)), "summoned guards receive the same difficulty once")
		game.elapsed = 180.0
		game._spawn_final_boss()
		check(is_equal_approx(game.mini_boss.hp, 35000.0 * float(tuning.health))
			and is_equal_approx(game.mini_boss.damage, 99.0 * float(tuning.damage)), "melee finale uses difficulty multipliers")
		game._damage_enemy(game.mini_boss, game.mini_boss.hp * 10.0, 0)
		game._update_projectiles(0.0)
		game._update_spawning(3.0)
		check(is_equal_approx(game.mini_boss.hp, 38000.0 * float(tuning.health))
			and is_equal_approx(game.mini_boss.damage, 99.0 * float(tuning.damage)), "artillery finale uses difficulty multipliers")
		game._damage_enemy(game.mini_boss, game.mini_boss.hp * 10.0, 0)
		game._update_projectiles(0.0)
		game._update_spawning(4.0)
		var milk = game.mini_boss
		check(is_equal_approx(milk.hp, 65000.0 * float(tuning.health))
			and is_equal_approx(milk.damage, 140.0 * float(tuning.damage)), "Milk Dragon first life scales correctly")
		game._damage_enemy(milk, milk.hp * 10.0, 0)
		milk.advance(game.MilkBoss.REBIRTH_TIME, null)
		check(is_equal_approx(milk.hp, 85000.0 * float(tuning.health))
			and is_equal_approx(milk.damage, 165.0 * float(tuning.damage)), "Milk Frog keeps scaled health and damage after rebirth")
		game.pending_milk_clones.append(milk)
		game._flush_milk_clones()
		var clone = game.enemies[-1]
		check(is_equal_approx(clone.hp, 1800.0 * float(tuning.health))
			and is_equal_approx(clone.damage, 32.0 * float(tuning.damage)), "Milk Frog clones use the same difficulty once")
		game.free()
		await process_frame
	var game = Main.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.select_difficulty(2)
	game.toggle_ready(0)
	game.select_difficulty(1)
	check(not game.class_ready[0], "changing difficulty cancels readiness")
	game.select_mode(true)
	game.start_run()
	check(not game.choosing_opening_majors() and game.mini_boss.hp == 95000.0
		and not Skills.has_available(game.players[0].role, game.players[0].skill_ranks), "breakthrough mode retains its independent full-build health and no redundant opening gifts")
	game.free()
	print("RUN DIFFICULTY RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

extends SceneTree
## Focused mode entry, max-build grants, three encounters and milk second-life HP.
const Main = preload("res://scenes/main.tscn")
const Skills = preload("res://scripts/skill_upgrades.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
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

func create_game():
	var game = Main.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	return game

func budget(mages: int) -> void:
	var game = create_game()
	game.select_mode(true)
	game.selected_classes = [game.Classes.MAGE if mages > 0 else game.Classes.RAIDER,
		game.Classes.MAGE if mages == 2 else game.Classes.RAIDER]
	game.start_run()
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	game.mini_boss = null
	var target = game.Enemy.new()
	target.setup(Vector2(750, 400), game.Balance.difficulty(180.0), false, "boss")
	target.hp = 100000000.0
	target.max_hp = target.hp
	target.radius = 44.0
	target.speed = 0.0
	target.damage = 0.0
	target.contact_cooldown = INF
	game.world.add_child(target)
	game.enemies.append(target)
	for frame in range(1800):
		for id in range(2):
			var player = game.players[id]
			player.position = Vector2(660 - id * 60, 400)
			player.invulnerability = 100.0
			if player.role == game.Classes.MAGE:
				game.activate_mage_skill(id, 1)
				game.activate_mage_skill(id, 2)
				game.activate_skill(id)
			else:
				game.activate_skill(id, Vector2.RIGHT)
				game.activate_warrior_skill(id, 2)
				game.activate_warrior_skill(id, 3)
		game.simulate(1.0 / 60.0, [Vector2.ZERO, Vector2.ZERO])
	var dps: float = (100000000.0 - target.hp) / 30.0
	print("FULL BUILD STATIC DPS / MAGES %d: %.1f" % [mages, dps])
	game.free()
	await process_frame

func run() -> void:
	if "--budget" in OS.get_cmdline_user_args():
		for mages in range(3): await budget(mages)
		quit()
		return
	for mages in range(3):
		var game = create_game()
		game.hud.class_menu.mode_buttons[1].pressed.emit()
		game.selected_classes = [game.Classes.MAGE if mages > 0 else game.Classes.RAIDER,
			game.Classes.MAGE if mages == 2 else game.Classes.RAIDER]
		game.hud.refresh()
		if mages == 1: await capture(game, "breakthrough_menu")
		check(game.breakthrough_mode and game.selecting_classes and game.enemies.is_empty(), "mode selection remains in the lobby without spawning combat")
		game.toggle_ready(0)
		game.toggle_ready(1)
		var maxed := true
		for player in game.players:
			maxed = maxed and not Skills.has_available(player.role, player.skill_ranks) and not Upgrades.has_available(player.ranks)
			maxed = maxed and player.hp == player.stats.max_hp and player.stats.projectiles == 4
		check(maxed and not game.has_pending_upgrades(), "all global buffs and career small/major skills are maxed for %d Mages" % mages)
		var king = game.mini_boss
		check(game.final_stage == 1 and game.elapsed == 0.0 and game.boss_encounters == 0
			and game.enemies.size() == 1 and king.get_script() == game.FinalBoss
			and king.hp == game.Balance.BREAKTHROUGH_HEALTH.melee[mages], "first encounter is the melee finale with full-build HP and no minibosses")
		if mages == 1: await capture(game, "breakthrough_battle")
		game.add_shared_xp(100000)
		game._spawn_enemy(Vector2.ZERO)
		game._spawn_mini_boss()
		check(not game.has_pending_upgrades() and game.enemies.size() == 1, "max-build challenge blocks upgrade windows and ordinary/miniboss spawning")
		game._damage_enemy(king, king.hp * 10.0, 0)
		game._update_projectiles(0.0)
		game._update_spawning(3.0)
		var cannon = game.mini_boss
		check(not game.game_over and game.final_stage == 2 and cannon.get_script() == game.RangedFinalBoss
			and cannon.hp == game.Balance.BREAKTHROUGH_HEALTH.artillery[mages], "melee defeat advances to artillery with independent full-build HP")
		game._damage_enemy(cannon, cannon.hp * 10.0, 0)
		game._update_projectiles(0.0)
		game._update_spawning(4.0)
		var milk = game.mini_boss
		check(game.final_stage == 3 and milk.get_script() == game.MilkBoss and milk.hp == game.Balance.BREAKTHROUGH_HEALTH.milk[mages], "artillery defeat advances to the third Boss, Milk Dragon")
		game._damage_enemy(milk, milk.hp * 10.0, 0)
		check(not game.game_over and milk.state == "rebirth", "first milk life does not prematurely finish the challenge")
		milk.advance(game.MilkBoss.REBIRTH_TIME, null)
		check(milk.form == 2 and milk.hp == game.Balance.BREAKTHROUGH_HEALTH.frog[mages], "Milk Frog second life preserves the challenge HP adjustment")
		game._damage_enemy(milk, milk.hp * 10.0, 0)
		check(game.game_over and game.victory, "defeating the final milk life completes the three-Boss challenge")
		game.free()
		await process_frame
	var normal = create_game()
	normal.select_mode(true)
	normal.toggle_ready(0)
	normal.hud.class_menu.mode_buttons[0].pressed.emit()
	check(not normal.breakthrough_mode and not normal.class_ready[0], "switching modes cancels readiness and can return to normal mode")
	normal.start_run()
	check(not normal.final_battle and normal.players[0].ranks.is_empty()
		and normal.players[0].skill_ranks.is_empty(), "normal mode retains its original progression start")
	normal.elapsed = normal.Balance.FINAL_BOSS_SECONDS
	normal._update_spawning(0.0)
	check(normal.mini_boss.hp == normal.Balance.BOSS_HEALTH.melee, "normal finale health remains unchanged")
	normal.free()
	print("BREAKTHROUGH RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

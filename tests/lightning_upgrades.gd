extends SceneTree
## Only the new lightning upgrades, ownership, impacts and presentation.
const Skills = preload("res://scripts/skill_upgrades.gd")
const Art = preload("res://scripts/art.gd")
var game
var fx
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1

func reset() -> void:
	for unit in game.enemies: unit.free()
	game.enemies.clear()
	for tower in game.mage_system.towers: tower.free()
	game.mage_system.towers.clear()
	fx.events.clear()
	fx.rulings.clear()
	fx.waves.clear()
	fx.tags.clear()
	fx.refresh()
	game.damage_events.clear()
	game.damage_totals.assign([0.0, 0.0])
	game.damage_breakdown.assign([{}, {}])
	for player in game.players:
		player.configure_class(0)
		player.position = Vector2(340 + player.player_id * 150, 470 + player.player_id * 110)
		player.shot_cooldown = 1000.0
		player.invulnerability = 1000.0

func enemy(at: Vector2, elite := false, boss := false):
	var unit = game.FinalBoss.new() if boss else game.Enemy.new()
	if boss: unit.setup_boss(at, game.Balance.difficulty(0), 0)
	else: unit.setup(at, game.Balance.difficulty(0), elite)
	unit.hp = 100000.0
	unit.max_hp = unit.hp
	unit.speed = 0.0
	unit.attack_cooldown = 1000.0
	game.world.add_child(unit)
	game.enemies.append(unit)
	return unit

func summon(id: int, upgrades: Array):
	for upgrade in upgrades: Skills.apply(game.players[id], upgrade)
	check(game.mage_system.activate_tower(id), "summon upgraded P%d tower" % (id + 1))
	return game.mage_system.towers.back()

func strike(tower) -> void:
	tower.shot_timer = 0.0
	tower.advance(0.0)

func snapshot(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	game.hud.refresh()
	fx.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + name + ".png") == OK, "capture " + name)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.selected_classes = [0, 0]
	game.start_run()
	game.spawn_credit = -1000.0
	game.next_wave = 1000.0
	game.next_boss = 1000.0
	fx = game.mage_system.lightning_effects
	reset()
	var p2 = game.players[1]
	for rank in range(1, 4):
		check(Skills.apply(p2, "tower_rate") and Skills.apply(p2, "tower_core")
			and is_equal_approx(p2.skill_stats.tower_rate, [1.5, 2.0, 2.5][rank - 1])
			and is_equal_approx(p2.skill_stats.tower_damage, [1.35, 1.70, 2.0][rank - 1])
			and p2.skill_stats.tower_duration == [12.0, 14.0, 16.0][rank - 1], "both minor upgrades use exact tier %d" % rank)
	check(not Skills.apply(p2, "tower_rate") and not Skills.apply(p2, "tower_core")
		and game.players[0].skill_stats.tower_rate == 1.0 and game.players[0].skill_stats.tower_damage == 1.0,
		"tiers stop at Lv3 and P2 upgrades never change P1")
	var tower = summon(1, ["tower_chain", "tower_tide", "tower_judgment"])
	check(is_equal_approx(tower.attack_interval, 0.32) and is_equal_approx(tower.damage, 13.16) and tower.life == 16.0
		and tower.chain_enabled and tower.tide_enabled and tower.judgment_enabled
		and p2.tower_recharge == 15.0 and p2.tower_release_cooldown == 2.0, "new tower inherits both minor tiers and all three majors; storage timing unchanged")
	check(not Skills.apply(p2, "tower_tide"), "major can only be selected once")
	enemy(Vector2(850, 450), false, true)
	for frame in range(270): game.simulate(1.0 / 60.0, [Vector2.ZERO, Vector2.ZERO])
	check(game.damage_breakdown[1].get("lightning_tower", 0) > 0 and game.damage_breakdown[1].get("tower_chain", 0) > 0
		and game.damage_breakdown[1].get("tower_judgment", 0) > 0 and game.damage_breakdown[1].get("tower_tide", 0) > 0,
		"all three majors coexist and deal damage after twelve-hit Boss judgment has time to complete")
	reset()
	var primary = enemy(Vector2(800, 460))
	var crowd := [enemy(Vector2(950, 490)), enemy(Vector2(1030, 400)), enemy(Vector2(1120, 510))]
	tower = summon(0, ["tower_chain"])
	strike(tower)
	check(is_equal_approx(primary.hp, 99993.42) and is_equal_approx(crowd[0].hp, 99999.013)
		and is_equal_approx(crowd[1].hp, 99999.013) and is_equal_approx(crowd[2].hp, 99999.013), "crowd receives three distinct x0.15 chain hits from 47-percent base damage; full chain does not backflow")
	await snapshot("lightning_chain")
	reset()
	var boss = enemy(Vector2(850, 450), false, true)
	tower = summon(0, ["tower_chain"])
	strike(tower)
	check(is_equal_approx(boss.hp, 99990.459) and tower.chain_marks[boss.get_instance_id()] == 1,
		"isolated Boss receives three x0.15 backflow hits but only one mark per primary attack")
	for index in range(6): strike(tower)
	check(fx.rulings.is_empty() and tower.chain_marks[boss.get_instance_id()] == 7, "seven primary attacks cannot trigger a Boss chain column early through backflow")
	strike(tower)
	var before: float = boss.hp
	check(fx.rulings.size() == 1 and not fx.rulings[0].judgment, "eight Boss chain marks queue an independent lightning column")
	fx.advance(0.22)
	check(is_equal_approx(before - boss.hp, 19.74), "Boss chain column deals x3 tower damage after warning")
	await snapshot("lightning_chain_boss")
	reset()
	primary = enemy(Vector2(790, 450))
	var nearby = enemy(Vector2(850, 490))
	var distant = enemy(Vector2(1050, 450))
	tower = summon(0, ["tower_judgment"])
	for index in range(5): strike(tower)
	check(fx.rulings.size() == 1 and tower.judgment_count == 0 and is_equal_approx(primary.hp, 99967.1), "five consecutive primary hits queue judgment without immediate impact")
	primary.position += Vector2(10, 0)
	fx.advance(0.40)
	check(is_equal_approx(primary.hp, 99967.1) and fx.rulings[0].position == primary.position, "sky warning follows the locked target for 0.65s")
	await snapshot("lightning_judgment_lock")
	fx.advance(0.25)
	check(is_equal_approx(primary.hp, 99914.46) and is_equal_approx(nearby.hp, 99986.84) and distant.hp == 100000.0, "normal judgment deals x8 single damage plus x2 local splash without hitting distant enemies")
	fx.advance(0.12)
	await snapshot("lightning_judgment_strike")
	for index in range(4): strike(tower)
	primary.position.x = 1100
	strike(tower)
	check(tower.judgment_target == nearby.get_instance_id() and tower.judgment_count == 1 and fx.rulings.is_empty(), "changing the nearest target resets consecutive judgment marks")
	reset()
	boss = enemy(Vector2(850, 450), false, true)
	tower = summon(1, ["tower_judgment"])
	for index in range(11): strike(tower)
	check(fx.rulings.is_empty(), "Boss judgment requires twelve hits rather than five")
	strike(tower)
	before = boss.hp
	fx.advance(0.65)
	check(is_equal_approx(before - boss.hp, 98.7) and is_equal_approx(game.damage_breakdown[1].get("tower_judgment", 0), 98.7),
		"Boss judgment deals x15 and credits P2's own damage category")
	reset()
	primary = enemy(Vector2(760, 430))
	var elite = enemy(Vector2(1000, 600), true)
	boss = enemy(Vector2(1100, 300), false, true)
	var offscreen = enemy(Vector2(-60, 470))
	tower = summon(0, ["tower_tide"])
	tower.shot_timer = 100.0
	tower.advance(2.49)
	check(fx.waves.is_empty(), "periodic tide waits for 2.5 seconds")
	tower.advance(0.01)
	check(fx.waves.size() == 1, "one tide starts at the 2.5-second boundary")
	fx.advance(0.35)
	await snapshot("lightning_tide")
	fx.advance(0.60)
	check(is_equal_approx(primary.hp, 99988.156) and is_equal_approx(elite.hp, 99988.156) and is_equal_approx(boss.hp, 99988.156) and offscreen.hp == 100000.0,
		"traveling tide hits normal, elite and Boss equally at x1.8, excluding off-screen enemies")
	check(primary.stagger_remaining == 0.0 and elite.stagger_remaining == 0.0 and boss.stagger_remaining == 0.0
		and primary.movement_scale == 1.0 and primary.attack_scale == 1.0,
		"tide applies damage only, with no stagger, paralysis, movement or attack slow")
	before = primary.hp
	fx.advance(0.1)
	check(primary.hp == before, "finished ring never deals repeated damage")
	strike(tower)
	check(is_equal_approx(primary.hp, before - 6.58), "regular single-target attacks remain available during tides")
	tower.shot_timer = 100.0
	tower.life = 1.01
	tower.next_tide = INF
	before = boss.hp
	var normal_before: float = primary.hp
	var elite_before: float = elite.hp
	tower.advance(0.01)
	fx.advance(0.20)
	tower.advance(1.0 / 3.0)
	fx.advance(0.20)
	tower.advance(1.0 / 3.0)
	check(tower.final_waves == 3 and fx.waves.size() == 3, "last second releases exactly three fast waves")
	fx.advance(0.12)
	await snapshot("lightning_tide_final")
	tower.advance(0.34)
	check(tower.expired and fx.waves.size() == 4 and fx.waves.back().detonation and is_equal_approx(fx.waves.back().damage, 39.48), "expiry adds x6 self-detonation after the three final waves")
	game.mage_system.advance(0.55)
	check(game.mage_system.towers.is_empty() and is_equal_approx(before - boss.hp, 86.856)
		and is_equal_approx(normal_before - primary.hp, 86.856) and is_equal_approx(elite_before - elite.hp, 86.856)
		and fx.waves.is_empty(), "three final waves and self-detonation finish after tower removal, with identical normal, elite and Boss damage")
	reset()
	tower = summon(0, ["tower_core", "tower_core", "tower_core", "tower_tide"])
	tower.shot_timer = 100.0
	tower.life = 0.01
	tower.next_tide = INF
	tower.final_waves = 3
	tower.advance(0.01)
	check(is_equal_approx(fx.waves.back().damage, 126.336), "16-second core tower detonation scales with 47-percent base, x2 core damage, x6 detonation and 16/10 lifetime")
	var wave_age: float = fx.waves[0].age
	game.paused = true
	game.simulate(1.0, [Vector2.ZERO, Vector2.ZERO])
	check(fx.waves[0].age == wave_age, "manual pause freezes pending lightning effects")
	game.paused = false
	reset()
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	game.players[0].offers.assign([Skills.CATALOG[4].duplicate(), Skills.CATALOG[5].duplicate(), Skills.CATALOG[0].duplicate()])
	game.players[1].offers.assign([Skills.MAJORS[6].duplicate(), Skills.MAJORS[7].duplicate(), Skills.MAJORS[8].duplicate()])
	game.hud.refresh()
	check(game.hud.choice_buttons[0][0].picture.texture == Art.skill_icon("tower_rate")
		and game.hud.choice_buttons[0][1].picture.texture == Art.skill_icon("tower_core")
		and "[b]×1.35[/b]" in game.hud.choice_buttons[0][1].description.text,
		"minor cards show specific icons and bold next-tier numbers")
	check(game.hud.choice_buttons[1][0].picture.texture == Art.skill_icon("tower_chain")
		and game.hud.choice_buttons[1][1].picture.texture == Art.skill_icon("tower_tide")
		and game.hud.choice_buttons[1][2].picture.texture == Art.skill_icon("tower_judgment"), "three major cards show three distinct icons")
	await snapshot("lightning_upgrade_cards")
	game.hud.choice_buttons[1][1].pressed.emit()
	check(game.players[1].skill_stats.tower_tide and not game.players[0].skill_stats.tower_tide, "actual P2 card click applies only to P2")
	game.free()
	print("LIGHTNING UPGRADES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
## Summon placement, full-screen single-target attacks and two-charge timing only.
const Upgrades = preload("res://scripts/upgrades.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1

func step(seconds: float) -> void:
	var left := seconds
	while left > 0.00001:
		var delta := minf(left, 1.0 / 60.0)
		game.simulate(delta, [Vector2.ZERO, Vector2.ZERO])
		left -= delta

func enemy(at: Vector2):
	var unit = game.Enemy.new()
	unit.setup(at, game.Balance.difficulty(0.0), false)
	unit.hp = 10000.0
	unit.max_hp = unit.hp
	unit.speed = 0.0
	unit.attack_cooldown = 1000.0
	game.world.add_child(unit)
	game.enemies.append(unit)
	return unit

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.selected_classes = [0, 0]
	game.start_run()
	for unit in game.enemies: unit.free()
	game.enemies.clear()
	game.spawn_credit = -1000.0
	game.next_wave = 1000.0
	game.next_boss = 1000.0
	for player in game.players:
		player.shot_cooldown = 1000.0
		player.invulnerability = 1000.0
	var p1 = game.players[0]
	var p2 = game.players[1]
	p1.position = Vector2(260, 470)
	p2.position = Vector2(380, 540)
	Upgrades.apply(p1, "damage")
	var nearest = enemy(Vector2(880, 425))
	var farther = enemy(Vector2(1030, 520))
	var offscreen = enemy(Vector2(-20, 470))
	check(p1.tower_charges == 2 and p2.tower_charges == 2, "each mage starts with two stored summons")
	var base_interval: float = p1.attack_interval()
	var base_speed: float = p1.movement_speed()
	var base_range: float = p1.attack_range()
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	game._unhandled_key_input(event)
	var first = game.mage_system.towers[0]
	check(p1.tower_charges == 1 and p2.tower_charges == 2 and p1.tower_recharge == 15.0 and p1.tower_release_cooldown == 2.0,
		"P1 Space spends one charge and starts separate 15s recharge / 2s release cooldown")
	check(first.position == p1.position and first.life == 10.0 and not game.activate_skill(0), "tower spawns at caster position; immediate recast is blocked")
	step(0.01)
	check(is_equal_approx(nearest.hp, 9990.13) and farther.hp == 10000.0 and offscreen.hp == 10000.0,
		"one strike hits only nearest on-screen enemy over 600px away; off-screen enemy is excluded")
	check(is_equal_approx(game.damage_breakdown[0].get("lightning_tower", 0.0), 9.87) and game.damage_totals[1] == 0.0,
		"tower inherits global damage Buff and credits its owner / damage category")
	p1.position += Vector2(95, -50)
	step(1.89)
	check(first.position == Vector2(260, 470) and not game.activate_skill(0), "summon stays fixed while caster moves; 1.9s release remains blocked")
	step(0.10)
	check(game.activate_skill(0) and p1.tower_charges == 0 and is_equal_approx(p1.tower_recharge, 13.0) and game.mage_system.towers.size() == 2,
		"second cast at 2s spends last charge without restarting recharge")
	event.physical_keycode = KEY_3
	game._unhandled_key_input(event)
	check(p2.tower_charges == 1 and game.mage_system.towers.size() == 3 and game.mage_system.towers[2].owner_id == 1,
		"P2 key 3 summons its own tower independently")
	step(0.01)
	game.hud.refresh()
	check(game.hud.skill_icons[0][3].stock.text == "0/2" and "充能" in game.hud.skill_icons[0][3].effect.text
		and game.hud.skill_icons[1][3].stock.text == "1/2", "HUD displays each player's charge count and recharge countdown")
	check(p1.attack_interval() == base_interval and p1.movement_speed() == base_speed and p1.attack_range() == base_range and p1.suppression_remaining == 0.0,
		"summoning no longer changes caster attack interval, movement speed or weapon range")
	await process_frame
	await process_frame
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/lightning_towers.png") == OK, "tower and lightning screenshot")
	check(game.hud.skill_icons[0][3].charge_bar.size.y <= 4.0, "charge progress strip stays inside the square icon")
	nearest.dead = true
	var hp_before: float = farther.hp
	first.shot_timer = 0.0
	first.advance(0.0)
	check(is_equal_approx(farther.hp, hp_before - 9.87), "tower reacquires nearest living on-screen enemy after its target dies")
	nearest.dead = false
	var frozen_life: float = first.life
	var frozen_charge: float = p1.tower_recharge
	var frozen_damage: float = game.damage_totals[0]
	game.paused = true
	game.simulate(1.0, [Vector2.ZERO, Vector2.ZERO])
	check(first.life == frozen_life and p1.tower_recharge == frozen_charge and game.damage_totals[0] == frozen_damage, "manual pause freezes towers, damage and charging")
	game.paused = false
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	game.simulate(1.0, [Vector2.ZERO, Vector2.ZERO])
	check(first.life == frozen_life and p1.tower_recharge == frozen_charge and not game.activate_skill(0), "upgrade selection freezes summon lifetime and charging and blocks casts")
	game.choose_upgrade(0, 0)
	game.choose_upgrade(1, 0)
	game.choose_team_upgrade(0)
	step(8.0 - 0.01)
	check(game.mage_system.towers.size() == 2, "first tower expires at 10s while later towers remain")
	step(2.0)
	check(game.mage_system.towers.is_empty(), "remaining towers expire at their own 10s boundary")
	var damage_after_expiry: float = game.damage_totals[0]
	step(2.9)
	check(p1.tower_charges == 0 and not game.activate_skill(0), "14.9s does not restore a charge early")
	step(0.1)
	check(p1.tower_charges == 1 and is_equal_approx(p1.tower_recharge, 15.0) and game.damage_totals[0] == damage_after_expiry,
		"first charge returns at 15s and begins next charge; expired towers stop dealing damage")
	step(15.0)
	check(p1.tower_charges == 2 and p1.tower_recharge == 0.0, "second charge returns at 30s and charging stops when full")
	game.free()
	print("LIGHTNING TOWER: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
## Only the physical dash family, path pulses, delayed finish and shared cooldown refunds.
const Skills = preload("res://scripts/skill_upgrades.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
var game
var system
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
	system.blade_trails.clear()
	system.slashes.clear()
	system.effects.clear()
	game.damage_events.clear()
	game.elapsed = 0.0
	for id in range(2):
		game.damage_breakdown[id].clear()
		game.players[id].configure_class(1)
		game.players[id].position = Vector2(400, 450 + id * 120)
		game.players[id].shot_cooldown = 1000.0
		game.players[id].invulnerability = 1000.0

func enemy(at: Vector2):
	var unit = game.Enemy.new()
	unit.setup(at, game.Balance.difficulty(0), false, "boss")
	unit.hp = 1000000.0
	unit.max_hp = unit.hp
	unit.xp_value = 0
	unit.speed = 0.0
	game.world.add_child(unit)
	game.enemies.append(unit)
	return unit

func step(seconds: float) -> void:
	var left := seconds
	while left > 0.000001:
		var delta := minf(left, 1.0 / 60.0)
		game.elapsed += delta
		system.advance(delta)
		for item in game.damage_events: item.life -= delta
		game.damage_events = game.damage_events.filter(func(item): return item.life > 0)
		game.damage_numbers.queue_redraw()
		left -= delta

func dash(id := 0, segments := 1, movement := Vector2.RIGHT) -> bool:
	var player = game.players[id]
	var start: Vector2 = player.position
	if not game.activate_skill(id, movement): return false
	player.advance(0.18, Vector2.ZERO)
	for index in range(segments):
		system.hit_dash(id, start.lerp(player.position, float(index) / segments), start.lerp(player.position, float(index + 1) / segments))
	return true

func snapshot(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless": return
	game.hud.refresh()
	system.visuals.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://artifacts/" + name + ".png") == OK, "capture " + name)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.selected_classes = [1, 1]
	game.start_run()
	game.spawn_credit = -1000
	game.next_wave = INF
	game.next_boss = INF
	system = game.warrior_system
	reset()
	var player = game.players[0]
	check(Skills.apply(player, "dash_blades") and not Skills.apply(player, "dash_flame")
		and not Skills.apply(player, "dash_blades") and not game.players[1].skill_stats.dash_blades,
		"new major replaces flame, remains unique and belongs only to its chooser")
	var target = enemy(Vector2(550, 450))
	game.mage_system.elements.attach(target, "ice")
	check(dash(0, 6) and system.blade_trails.size() == 1, "six movement segments form one actual dash trail")
	check(is_equal_approx(target.max_hp - target.hp, 17.0 * 3.2) and target.element_state.fire == 0.0,
		"dash remains physical on an ice-attached enemy and creates no fire attachment")
	step(0.01)
	var hit_hp: float = target.hp
	step(0.18)
	check(target.hp == hit_hp, "path cannot pulse again before 0.2 seconds")
	step(0.01)
	check(is_equal_approx(hit_hp - target.hp, 17.0 * 0.25), "path pulses every 0.2 seconds despite overlapping movement segments")
	await snapshot("blade_trail_cutting")
	step(1.79)
	check(is_equal_approx(game.damage_breakdown[0].get("blade_trail", 0), 17.0 * 0.25 * 10)
		and game.damage_breakdown[0].get("blade_execute", 0) == 0 and not system.blade_trails.is_empty(),
		"at 1.99 seconds there are at most ten pulses and no early execution")
	hit_hp = target.hp
	step(0.01)
	check(is_equal_approx(hit_hp - target.hp, 17.0 * 6.0) and system.blade_trails.is_empty(),
		"at two seconds remaining enemies receive one high-damage physical execution")
	await snapshot("blade_trail_execute")
	hit_hp = target.hp
	step(0.5)
	check(target.hp == hit_hp and system.effects.is_empty(), "finished trail cannot damage or execute twice; visuals expire")
	reset()
	Skills.apply(player, "dash_blades")
	target = enemy(Vector2(550, 640))
	dash()
	step(0.8)
	check(target.hp == target.max_hp, "off-path enemies take no trail damage")
	target.position.y = 450
	step(0.01)
	check(is_equal_approx(target.max_hp - target.hp, 17.0 * 0.25), "an enemy entering an existing path starts taking pulses")
	target.position.y = 640
	step(1.19)
	check(game.damage_breakdown[0].get("blade_execute", 0) == 0, "an enemy that leaves before expiry avoids the execution")
	reset()
	Skills.apply(player, "dash_blades")
	Skills.apply(player, "dash_refund")
	target = enemy(Vector2(550, 450))
	dash()
	check(is_equal_approx(player.dash_refund_total, 0.25) and is_equal_approx(player.skill_cooldown, 5.75), "body hit refunds cooldown")
	step(0.01)
	check(is_equal_approx(player.dash_refund_total, 0.5), "path pulse on the same enemy also refunds cooldown")
	reset()
	Skills.apply(player, "dash_blades")
	Skills.apply(player, "dash_refund")
	target = enemy(Vector2(550, 640))
	dash()
	step(1.99)
	target.position.y = 450
	step(0.01)
	check(is_equal_approx(player.dash_refund_total, 0.5) and game.damage_breakdown[0].get("blade_execute", 0) > 0,
		"late-entry pulse and ending execution each refund cooldown")
	reset()
	Skills.apply(player, "dash_wave")
	Skills.apply(player, "dash_refund")
	target = enemy(Vector2(980, 450))
	game.mage_system.elements.attach(target, "ice")
	dash()
	step(0.45)
	check(is_equal_approx(player.dash_refund_total, 0.25) and is_equal_approx(target.max_hp - target.hp, 17.0 * 4.5)
		and game.mage_system.grounds.is_empty(), "physical slash hits once, refunds cooldown and leaves no fire ground")
	reset()
	for rank in range(3): Skills.apply(player, "dash_refund")
	Skills.apply(player, "dash_blades")
	Skills.apply(player, "dash_recast")
	target = enemy(Vector2(550, 450))
	dash()
	step(0.2)
	check(dash(0, 1, Vector2.LEFT) and player.dash_second_cast and system.blade_trails.size() == 2, "second dash leaves its own independently timed trail")
	step(2.0)
	check(is_equal_approx(player.dash_refund_total, 3.0) and player.skill_cooldown >= 0.0
		and is_equal_approx(game.damage_breakdown[0].get("blade_trail", 0), 17.0 * 2.5 * 2)
		and is_equal_approx(game.damage_breakdown[0].get("blade_execute", 0), 17.0 * 6.0 * 2),
		"both overlapping casts each have their own pulses/execution while sharing the rank-three refund cap")
	reset()
	Skills.apply(player, "dash_blades")
	Skills.apply(player, "dash_refund")
	target = enemy(Vector2(550, 450))
	dash()
	player.skill_cooldown = 0
	player.dash_recast_remaining = 0
	player.position = Vector2(800, 450)
	dash()
	step(2.0)
	check(player.dash_refund_total == 0.0, "older path damage cannot refund a newly started dash cycle")
	reset()
	Skills.apply(player, "dash_blades")
	for rank in range(3): Skills.apply(player, "dash_refund")
	target = enemy(Vector2(550, 450))
	game.activate_skill(0, Vector2.RIGHT)
	for frame in range(144): game.simulate(1.0 / 60.0, [Vector2.ZERO, Vector2.ZERO])
	check(system.blade_trails.is_empty() and is_equal_approx(player.dash_refund_total, 3.0)
		and absf(player.skill_cooldown - 0.78) < 0.02 and is_equal_approx(target.max_hp - target.hp, 17.0 * (3.2 + 2.5 + 6.0)),
		"real simulation moves, pulses, executes, refunds and then recovers cooldown at the expected rate")
	reset()
	for rank in range(3): Skills.apply(player, "dash_geometry")
	Skills.apply(player, "dash_blades")
	Upgrades.apply(player, "damage")
	player.counterattack_remaining = 5.0
	target = enemy(Vector2(550, 450))
	dash()
	var trail: Dictionary = system.blade_trails[0]
	var base := 17.0 * 1.5 * 1.3 * 2.0
	check(is_equal_approx(trail.damage, base * 0.25) and is_equal_approx(trail.execute_damage, base * 6.0)
		and is_equal_approx(trail.radius, 72.0 * 2.5 * 0.6), "path and execution inherit global, rescue and dash multipliers once plus upgraded width")
	var life: float = trail.life
	var cd: float = player.skill_cooldown
	game.paused = true
	game.simulate(0.5, [Vector2.ZERO, Vector2.ZERO])
	check(trail.life == life and player.skill_cooldown == cd, "pause freezes path duration and cooldown")
	game.paused = false
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	game.simulate(0.5, [Vector2.ZERO, Vector2.ZERO])
	check(trail.life == life and player.skill_cooldown == cd, "upgrade selection also freezes paths and blocks delayed execution")
	game.players[1].offers.assign([Skills.WARRIOR_MAJORS[3].duplicate()])
	game.hud.refresh()
	check(game.hud.choice_buttons[1][0].picture.texture != null and "剑气残痕" in game.hud.choice_buttons[1][0].description.text,
		"major card shows the new physical path skill and an icon")
	game.choose_upgrade(1, 0)
	check(game.players[1].skill_stats.dash_blades, "P2 can select its own path skill")
	game.free()
	print("BLADE TRAILS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
## Actual physical dash/recast/slash hits and blade derivatives, without a long simulation.
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

func run() -> void:
	var game = Main.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.selected_classes = [1, 1]
	game.start_run()
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	var player = game.players[0]
	var system = game.warrior_system
	var target = game.Enemy.new()
	target.setup(Vector2(600, 400), game.Balance.difficulty(0.0), false)
	target.hp = 1000000.0
	target.max_hp = target.hp
	game.world.add_child(target)
	game.enemies.append(target)
	Skills.apply(player, "dash_recast")
	for rank in range(4):
		if rank > 0: Skills.apply(player, "dash_geometry")
		var power: float = [1.0, 1.33, 1.67, 2.0][rank]
		var base := 17.0 * power
		check(is_equal_approx(player.skill_stats.dash_power, power)
			and is_equal_approx(player.skill_stats.hit_radius, 72.0 * [1.0, 1.5, 2.0, 2.5][rank])
			and is_equal_approx(player.skill_stats.distance, 230.0 * [1.0, 1.2, 1.4, 1.6][rank]), "rank %d preserves width/distance and adds total independent dash damage" % rank)
		system.slashes.clear()
		system.blade_trails.clear()
		game.mage_system.grounds.clear()
		game.mage_system.elements.fire_contacts.clear()
		target.element_state.clear()
		target.position = Vector2(600, 400)
		player.position = Vector2(500, 400)
		player.skill_cooldown = 0.0
		player.dash_remaining = 0.0
		player.dash_recast_remaining = 0.0
		player.skill_stats.dash_wave = false
		player.skill_stats.dash_blades = false
		system.activate_dash(0, Vector2.RIGHT)
		var before: float = target.hp
		player.advance(game.Classes.DASH_DURATION, Vector2.ZERO)
		system.hit_dash(0, Vector2(500, 400), player.position)
		var first: float = before - target.hp
		player.position = Vector2(500, 400)
		system.activate_dash(0, Vector2.RIGHT)
		before = target.hp
		player.advance(game.Classes.DASH_DURATION, Vector2.ZERO)
		system.hit_dash(0, Vector2(500, 400), player.position)
		check(is_equal_approx(first, base * 3.2) and is_equal_approx(before - target.hp, base * 3.2)
			and player.dash_second_cast, "rank %d actual first and second dash each receive damage multiplier once" % rank)
		player.position = Vector2(500, 400)
		player.skill_cooldown = 0.0
		player.dash_recast_remaining = 0.0
		player.skill_stats.dash_wave = true
		player.skill_stats.dash_blades = true
		game.damage_breakdown[0].clear()
		system.activate_dash(0, Vector2.RIGHT)
		before = target.hp
		system.hit_dash(0, Vector2(500, 400), Vector2(600, 400))
		var body: float = before - target.hp
		before = target.hp
		system.advance(0.12)
		check(is_equal_approx(body, base * 3.2) and is_equal_approx(game.damage_breakdown[0].get("slash", 0), base * 4.5),
			"rank %d physical body and slash receive multiplier once" % rank)
		target.position = Vector2(560, 400)
		for tick in range(120): system.advance(1.0 / 60.0)
		check(is_equal_approx(game.damage_breakdown[0].get("blade_trail", 0), base * 2.5)
			and is_equal_approx(game.damage_breakdown[0].get("blade_execute", 0), base * 6.0)
			and game.mage_system.grounds.is_empty() and float(target.element_state.get("fire", 0)) == 0,
			"rank %d physical path pulses and execution inherit damage once, with no fire or burn" % rank)
	check(not Skills.apply(player, "dash_geometry") and game.players[1].skill_stats.dash_power == 1.0, "three-tier cap and independent teammate upgrade")
	Upgrades.apply(player, "damage")
	player.counterattack_remaining = 5.0
	player.dash_hit_ids.clear()
	target.element_state.clear()
	game.mage_system.elements.attach(target, "ice")
	var before: float = target.hp
	system.hit_dash(0, Vector2(500, 400), Vector2(600, 400))
	check(is_equal_approx(before - target.hp, 17.0 * 1.5 * 1.3 * 2.0 * 3.2),
		"global damage, rescue and dash multipliers remain independent; physical dash never melts ice")
	player.giant_remaining = 3.0
	player.position = target.position
	before = target.hp
	var starts: Array[Vector2] = [player.position, game.players[1].position]
	system.giant_contacts(starts)
	check(is_equal_approx(before - target.hp, player.output_damage() * 2.0), "dash multiplier does not strengthen Giant collision")
	check(Skills.effect_text("dash_geometry", 3).contains("×2.00"), "range upgrade card also displays the new damage tier")
	game.free()
	print("DASH POWER RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

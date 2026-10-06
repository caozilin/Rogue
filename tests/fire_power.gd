extends SceneTree
## Verify only Q's radius/power tiers and inheritance through its derived damage.
const Skills = preload("res://scripts/skill_upgrades.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
const POWERS := [1.0, 1.33, 1.67, 2.0]
const RADII := [1.0, 1.5, 2.0, 2.5]
var checks := 0
var failures := 0
var game

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.selected_classes = [0, 0]
	game.start_run()
	for unit in game.enemies: unit.free()
	game.enemies.clear()
	var system = game.mage_system
	var caster = game.players[1]
	caster.position = Vector2(500, 450)
	var target = game.Enemy.new()
	target.setup(caster.position + Vector2(100, 0), game.Balance.difficulty(0), false, "boss")
	target.hp = 1000000.0
	target.max_hp = target.hp
	game.world.add_child(target)
	game.enemies.append(target)
	Skills.apply(caster, "fire_ground")
	Skills.apply(caster, "fire_growth")
	for rank in range(4):
		if rank > 0: Skills.apply(caster, "fire_width")
		system.fireballs.clear()
		system.grounds.clear()
		system.elements.fire_contacts.clear()
		target.element_state.clear()
		game.damage_breakdown[1].clear()
		check(caster.skill_stats.fire_width == RADII[rank] and caster.skill_stats.fire_power == POWERS[rank], "Lv%d uses exact total radius and fire_power" % rank)
		check(system._spawn_fireball(caster), "spawn P2 Q at Lv%d" % rank)
		var ball: Dictionary = system.fireballs[0]
		var base: float = caster.output_damage() * POWERS[rank]
		var before: float = target.hp
		system._advance_fireballs(0.01)
		check(is_equal_approx(ball.radius, system.FIREBALL_RADIUS * RADII[rank])
			and is_equal_approx(before - target.hp, base * 0.45), "Lv%d actual body hit inherits fire_power exactly once" % rank)
		check(system.grounds.size() == 1 and is_equal_approx(system.grounds[0].dps, base * 0.18), "Lv%d Q generates strengthened fire-ground DPS" % rank)
		for tick in range(4):
			system._advance_grounds(0.5)
			system.elements.advance(0.5)
		check(is_equal_approx(target.element_state.burn_dps, base * 0.18 * 1.75)
			and is_equal_approx(game.damage_breakdown[1].get("fire_ground", 0), base * 0.18 * 2.0)
			and is_equal_approx(game.damage_breakdown[1].get("burn", 0), base * 0.18 * 1.75 * 0.5), "Lv%d actual ground and burn ticks inherit the same strengthened base" % rank)
		ball.position = target.position
		ball.stage = 4
		before = target.hp
		system._explode(ball)
		check(is_equal_approx(before - target.hp, base * 4.4), "Lv%d four-stage explosion inherits fire_power exactly once" % rank)
	check(not Skills.apply(caster, "fire_width") and game.players[0].skill_stats.fire_power == 1.0
		and caster.skill_stats.tower_damage == 1.0 and caster.skill_stats.frost_width == 1.0,
		"Lv3 cap and independent P2 upgrade; tower, frost and P1 remain at their original values")
	Upgrades.apply(caster, "damage")
	system.fireballs.clear()
	system._spawn_fireball(caster)
	var ball: Dictionary = system.fireballs[0]
	check(is_equal_approx(ball.base_damage, 14.0 * 1.5 * 2.0), "global damage and fire_power multiply once at Q creation")
	system.elements.attach(target, "ice")
	var before: float = target.hp
	system._advance_fireballs(0.01)
	check(is_equal_approx(before - target.hp, 14.0 * 1.5 * 2.0 * 0.45 * 2.0), "elemental x2 reaction remains a separate multiplier")
	check("[b]×1.33[/b]" in Skills.effect_text("fire_width", 1)
		and "[b]×1.67[/b]" in Skills.effect_text("fire_width", 2), "offer emphasizes exact next-tier fire power")
	game.hud.refresh()
	check("火系伤害 ×2.00" in game.hud.skill_icons[1][0].tooltip_text, "P2 Q tooltip shows current fire power")
	game.free()
	print("FIRE POWER: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

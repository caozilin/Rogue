extends SceneTree
## Actual field/cone hits and ice multiplier composition only.
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
	game.selected_classes = [0, 0]
	game.start_run()
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	var caster = game.players[0]
	var ally = game.players[1]
	var target = game.Enemy.new()
	target.setup(caster.position + Vector2(30, 0), game.Balance.difficulty(0.0), false)
	target.hp = 100000.0
	target.max_hp = target.hp
	game.world.add_child(target)
	game.enemies.append(target)
	Skills.apply(caster, "frost_cones")
	for rank in range(4):
		if rank > 0: Skills.apply(caster, "frost_width")
		var power: float = [1.0, 1.2, 1.4, 1.6][rank]
		var radius: float = game.Mage.FROST_RADIUS * [1.0, 1.5, 2.0, 2.5][rank]
		check(is_equal_approx(caster.skill_stats.frost_power, power)
			and is_equal_approx(game.mage_system.frost_radius(caster), radius), "rank %d keeps original range and adds its independent ice multiplier" % rank)
		caster.frost_cooldown = 0.0
		target.element_state.clear()
		game.activate_mage_skill(0, 2)
		var before: float = target.hp
		game.mage_system._advance_frost(0.01)
		check(is_equal_approx(before - target.hp, 14.0 * game.Mage.FROST_DAMAGE * power), "rank %d actual frost pulse receives ice multiplier once" % rank)
		before = target.hp
		game.mage_system._advance_cones(0.36)
		check(is_equal_approx(before - target.hp, 14.0 * game.Mage.CONE_DAMAGE * power), "rank %d actual major ice cone receives ice multiplier once" % rank)
		game.mage_system.cones.clear()
	check(not Skills.apply(caster, "frost_width") and ally.skill_stats.frost_power == 1.0, "three-rank cap and separate teammate ice stats")
	Upgrades.apply(caster, "damage")
	caster.possession_host = ally
	caster.possession_remaining = 5.0
	caster.counterattack_remaining = 5.0
	target.element_state.clear()
	game.mage_system.elements.attach(target, "fire")
	var before: float = target.hp
	game.mage_system.elements.damage(target, caster.output_damage(), 0, "ice", true, "frost")
	check(is_equal_approx(before - target.hp, 14.0 * 1.5 * 1.35 * 1.3 * 1.6 * 2.0), "global damage, possession, rescue buff, ice multiplier and reaction multiply independently")
	caster.end_possession()
	target.element_state.clear()
	before = target.hp
	game.mage_system.elements.damage(target, 10.0, 0, "ice", false)
	check(is_equal_approx(before - target.hp, 16.0), "ice damage without attachment also receives the common multiplier")
	target.element_state.clear()
	before = target.hp
	game.mage_system.elements.damage(target, 10.0, 1, "ice")
	check(is_equal_approx(before - target.hp, 10.0), "unupgraded teammate does not inherit caster ice boost")
	target.element_state.clear()
	before = target.hp
	game.mage_system.elements.damage(target, 10.0, 0, "fire")
	check(is_equal_approx(before - target.hp, 10.0), "ice multiplier never boosts fire damage")
	target.element_state.clear()
	before = target.hp
	game.mage_system.elements.attach(target, "ice")
	game.mage_system.elements.advance(0.5)
	check(target.hp == before, "existing ice attachment stays a slow without newly invented DOT")
	Skills.apply(caster, "frost_ward")
	caster.frost_cooldown = 0.0
	game.activate_mage_skill(0, 2)
	check(game.mage_system.ward_radius() == 48.0 and caster.frost_shield_hp == 100.0, "ice damage boost does not enlarge or strengthen the fixed defensive ward")
	check(Skills.effect_text("frost_width", 3).contains("冰系伤害")
		and Skills.effect_text("frost_width", 3).contains("×1.6"), "upgrade card shows both range and next ice damage tier")
	game.free()
	print("FROST POWER RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

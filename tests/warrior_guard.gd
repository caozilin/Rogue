extends SceneTree
## Only the newly added taunt tiers, passive shield and rescue effects.
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
	game.start_run()
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	game.spawn_credit = -10000.0
	game.next_wave = INF
	game.next_boss = INF
	var warrior = game.players[0]
	var ally = game.players[1]
	warrior.configure_class(game.Classes.RAIDER)
	ally.configure_class(game.Classes.MAGE)
	warrior.stats.max_hp = 200.0
	warrior.hp = 200.0
	warrior.advance(1.0, Vector2.ZERO)
	check(is_equal_approx(warrior.guard_shield, 3.0), "base shield regenerates 1.5 percent of current maximum health per second")
	warrior.advance(20.0, Vector2.ZERO)
	check(is_equal_approx(warrior.guard_shield, 30.0), "base shield caps at fifteen percent")
	warrior.invulnerability = 0.0
	warrior.take_damage(40.0)
	check(warrior.guard_shield == 0.0 and warrior.hp == 190.0, "passive shield absorbs damage before remaining damage reaches health")
	for rank in range(1, 4):
		Skills.apply(warrior, "rescue_guard")
		warrior.guard_shield = 0.0
		warrior.advance(1.0, Vector2.ZERO)
		var regen := [0.0, 5.0, 7.0, 9.0]
		var caps := [0.0, 50.0, 70.0, 90.0]
		check(is_equal_approx(warrior.guard_shield, regen[rank]), "shield rank %d regenerates at the requested rate" % rank)
		warrior.advance(20.0, Vector2.ZERO)
		check(is_equal_approx(warrior.guard_shield, caps[rank]), "shield rank %d caps at the requested amount" % rank)
	check(not Skills.apply(warrior, "rescue_guard"), "passive shield has exactly three upgrade ranks")
	warrior.stats.max_hp = 400.0
	check(is_equal_approx(warrior.guard_shield_max(), 180.0), "shield capacity follows global maximum-health upgrades")
	warrior.stats.max_hp = 200.0
	for rank in range(1, 4):
		Skills.apply(warrior, "warcry_endurance")
		warrior.warcry_cooldown = 0.0
		game.activate_warrior_skill(0, 1)
		check(warrior.warcry_remaining == float(4 + rank * 2), "taunt rank %d sets its full duration" % rank)
	Skills.apply(warrior, "warcry_dummy")
	warrior.warcry_cooldown = 0.0
	game.activate_warrior_skill(0, 1)
	check(warrior.warcry_remaining == 0.0 and game.taunt_dummies[-1].warcry_remaining == 16.0
		and game.taunt_dummies[-1].max_hp == 500.0, "unlocking the dummy after rank three retains sixteen seconds and 250 percent health")
	warrior.configure_class(game.Classes.RAIDER)
	warrior.stats.max_hp = 200.0
	warrior.hp = 200.0
	Skills.apply(warrior, "warcry_dummy")
	for rank in range(1, 4):
		Skills.apply(warrior, "warcry_endurance")
		warrior.warcry_cooldown = 0.0
		game.activate_warrior_skill(0, 1)
		var dummy = game.taunt_dummies[-1]
		check(dummy.warcry_remaining == float(10 + rank * 2) and dummy.max_hp == float(200 + rank * 100),
			"dummy rank %d applies duration and health after unlocking it first" % rank)
	for dummy in game.taunt_dummies: dummy.free()
	game.taunt_dummies.clear()
	Skills.apply(warrior, "rescue_guard")
	Skills.apply(warrior, "rescue_blessing")
	Skills.apply(warrior, "rescue_counterattack")
	warrior.guard_shield = 1.0
	Upgrades.apply(warrior, "damage")
	Upgrades.apply(ally, "damage")
	ally.stats.regen = 0.0
	ally.hp = 40.0
	check(game.activate_warrior_skill(0, 3) and ally.is_carried(), "rescue successfully carries a living teammate")
	check(warrior.guard_shield == 50.0 and ally.blessing_shield == 100.0
		and ally.blessing_remaining == 10.0 and ally.tenacity() == 0.5, "shelter fills caster passive shield and gives teammate the specified protection")
	check(warrior.counterattack_remaining == 5.0 and ally.counterattack_remaining == 5.0
		and is_equal_approx(warrior.output_damage(), float(warrior.stats.damage) * 1.3)
		and is_equal_approx(ally.output_damage(), float(ally.stats.damage) * 1.3), "both players receive a separate 1.3 multiplier on top of global damage")
	warrior.stats.crit = 0.0
	game._spawn_bullet(warrior, Vector2.RIGHT)
	check(is_equal_approx(game.projectiles[-1].damage, float(warrior.stats.damage) * 1.3), "automatic attacks inherit counterattack damage")
	check(game.mage_system.activate_tower(1)
		and is_equal_approx(game.mage_system.towers[-1].damage, float(ally.stats.damage) * 1.3), "teammate Mage skills inherit counterattack damage")
	warrior.end_carry()
	ally.invulnerability = 0.0
	ally.take_damage(40.0)
	check(ally.hp == 40.0 and ally.blessing_shield == 60.0, "shelter has no former thirty-percent damage reduction")
	ally.advance(1.0, Vector2.ZERO)
	check(is_equal_approx(ally.hp, 43.0), "shelter heals an extra three percent of teammate maximum health per second")
	ally.possession_host = warrior
	ally.possession_remaining = 1.0
	check(is_equal_approx(ally.output_damage(), float(ally.stats.damage) * 1.35 * 1.3), "counterattack multiplies independently with possession")
	ally.end_possession()
	game.paused = true
	var shield: float = warrior.guard_shield
	var duration: float = ally.counterattack_remaining
	game.simulate(1.0, [Vector2.ZERO, Vector2.ZERO])
	check(warrior.guard_shield == shield and ally.counterattack_remaining == duration, "pause freezes shield regeneration and counterattack time")
	game.paused = false
	warrior.advance(5.0, Vector2.ZERO)
	ally.advance(5.0, Vector2.ZERO)
	check(warrior.counterattack_remaining == 0.0 and ally.counterattack_remaining == 0.0
		and warrior.output_damage() == float(warrior.stats.damage), "counterattack expires without modifying permanent stats")
	warrior.rescue_cooldown = 0.0
	ally.downed = true
	ally.hp = 0.0
	game.activate_warrior_skill(0, 3)
	check(not ally.downed and game.instant_revive_used and warrior.counterattack_remaining == 5.0
		and ally.counterattack_remaining == 5.0 and ally.blessing_remaining == 10.0, "successful immediate revival grants both rescue majors")
	warrior.counterattack_remaining = 0.0
	ally.counterattack_remaining = 0.0
	ally.downed = true
	ally.hp = 0.0
	ally.blessing_remaining = 0.0
	ally.blessing_shield = 0.0
	warrior.guard_shield = 0.0
	warrior.rescue_cooldown = 0.0
	game.activate_warrior_skill(0, 3)
	check(ally.downed and ally.counterattack_remaining == 0.0 and warrior.counterattack_remaining == 0.0
		and ally.blessing_remaining == 0.0 and warrior.guard_shield == 50.0, "teleporting to an unrecoverable corpse only refreshes caster shelter shield, without counterattack")
	warrior.invulnerability = 0.0
	warrior.take_damage(10000.0)
	warrior.advance(2.0, Vector2.ZERO)
	check(warrior.downed and warrior.guard_shield == 0.0 and warrior.counterattack_remaining == 0.0, "downed players cannot accumulate passive shield and lose counterattack")
	game.free()
	print("WARRIOR GUARD RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

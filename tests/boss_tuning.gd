extends SceneTree
## Only health budgets and the three changed major-skill damage paths.
const Budget = preload("res://tools/boss_damage_budget.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func clear_targets() -> void:
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	game.mage_system.fireballs.clear()
	game.mage_system.grounds.clear()
	game.mage_system.cones.clear()
	game.warrior_system.slashes.clear()
	game.mage_system.elements.fire_contacts.clear()

func dummy():
	clear_targets()
	var enemy = game.Enemy.new()
	enemy.setup(Vector2(550, 410), game.Balance.difficulty(180), false, "boss")
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	enemy.radius = 42.0
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	return enemy

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	var health_valid := true
	for node in Budget.NODES:
		var type = {"spore": game.MiniBoss, "thorn": game.ThornBoss, "melee": game.FinalBoss, "artillery": game.RangedFinalBoss}[node.id]
		for seconds in [float(node.seconds), 600.0]:
			var boss = type.new()
			boss.setup_boss(Vector2.ZERO, game.Balance.difficulty(seconds), 0)
			health_valid = health_valid and boss.hp == game.Balance.BOSS_HEALTH[node.id] and boss.max_hp == boss.hp
			boss.free()
	check(health_valid, "four bosses use independent fixed health; late spawning does not multiply it again")
	var picks_valid := true
	var budgets_valid := true
	for node in Budget.NODES:
		for role in [game.Classes.MAGE, game.Classes.RAIDER]:
			var player = Budget.build(role, int(node.picks), "balanced")
			var majors := 0
			for entry in player.SkillUpgrades.major_pool(role):
				if player.skill_ranks.has(entry.id): majors += 1
			picks_valid = picks_valid and majors == int(node.picks / 3)
			player.free()
		var mage = Budget.build(game.Classes.MAGE, int(node.picks), "balanced")
		var warrior = Budget.build(game.Classes.RAIDER, int(node.picks), "balanced")
		var dps: float = Budget.estimate(mage, node, true).total + Budget.estimate(warrior, node, true).total
		var duration: float = game.Balance.BOSS_HEALTH[node.id] / dps
		budgets_valid = budgets_valid and duration >= 25.0 and duration <= 45.0
		mage.free()
		warrior.free()
	check(picks_valid and budgets_valid, "3/6/9 picks give 1/2/3 majors and balanced mixed teams retain 25-45 second mechanism windows")
	var target = dummy()
	var mage = game.players[0]
	mage.configure_class(game.Classes.MAGE)
	mage.position = Vector2(480, 410)
	mage.SkillUpgrades.apply(mage, "frost_cones")
	game.mage_system.elements.attach(target, "fire")
	game.activate_mage_skill(0, 2)
	game.mage_system._advance_frost(0.01)
	var hp: float = target.hp
	game.mage_system._advance_cones(0.36)
	check(is_equal_approx(hp - target.hp, mage.output_damage() * 1.8 * 2.0), "actual falling cone deals 1.8x damage and still benefits from double elemental reaction")
	hp = target.hp
	game.mage_system._advance_cones(0.01)
	check(target.hp == hp, "a cone cannot repeatedly apply its burst damage")
	var ball := {"position": target.position, "radius": 105.6, "base_damage": mage.output_damage(), "stage": 4, "owner": 0}
	game.mage_system._explode(ball)
	check(is_equal_approx(hp - target.hp, mage.output_damage() * 4.4 * 2.0), "four-stage growth explosion is 4.4x before reaction instead of 5.5x")
	target = dummy()
	var warrior = game.players[1]
	warrior.configure_class(game.Classes.RAIDER)
	warrior.position = Vector2(480, 410)
	for index in range(3): game.Upgrades.apply(warrior, "damage")
	for id in ["dash_wave", "dash_recast", "dash_flame"]: warrior.SkillUpgrades.apply(warrior, id)
	game.mage_system.elements.attach(target, "ice")
	hp = target.hp
	game.activate_skill(1, Vector2.RIGHT)
	game._damage_dash(1, warrior.position, Vector2(710, 410))
	game.warrior_system.advance(0.1)
	warrior.advance(0.19, Vector2.ZERO)
	game.activate_skill(1, Vector2.LEFT)
	game._damage_dash(1, warrior.position, Vector2(480, 410))
	game.warrior_system.advance(0.1)
	var expected: float = warrior.output_damage() * (3.2 + 4.5) * 2.0 * 2.0
	check(is_equal_approx(hp - target.hp, expected), "damage-rank-three recast plus flame plus wave uses two 3.2x dashes and two 4.5x waves, each with elemental reaction")
	hp = target.hp
	game.warrior_system.advance(0.05)
	check(target.hp == hp, "each slash wave hits the boss only once")
	clear_targets()
	var final = game.FinalBoss.new()
	final.setup_boss(Vector2(640, 410), game.Balance.difficulty(180), 0)
	final.state = "recover"
	game.world.add_child(final)
	game.enemies.append(final)
	game.mage_system.elements.attach(final, "ice")
	hp = final.hp
	game.mage_system.elements.damage(final, 100.0, 0, "fire")
	var opening: bool = is_equal_approx(hp - final.hp, 250.0)
	final.state = "approach"
	final.hit(final.max_hp * 0.41)
	var second: bool = final.phase == 2
	final.hit(final.max_hp * 0.3)
	check(opening and second and final.phase == 3, "new health retains 25-percent recovery opening, elemental synergy and 60/30-percent phase thresholds")
	game.free()
	print("BOSS TUNING RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

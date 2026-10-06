extends SceneTree
## Only verify shared damage scaling on actual skill casts; no long simulation.
const MainScene = preload("res://scenes/main.tscn")
const Upgrades = preload("res://scripts/upgrades.gd")
const SkillUpgrades = preload("res://scripts/skill_upgrades.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	var ranged = game.players[0]
	var melee = game.players[1]
	SkillUpgrades.apply(ranged, "overclock")
	SkillUpgrades.apply(melee, "rupture")
	for tier in range(1, 4):
		for node in game.enemies + game.projectiles + game.gems:
			node.free()
		game.enemies.clear()
		game.projectiles.clear()
		game.gems.clear()
		Upgrades.apply(ranged, "damage")
		Upgrades.apply(melee, "damage")
		melee.position = Vector2(710, 400)
		var target = game.Enemy.new()
		target.setup(melee.position + Vector2(60, 0), game.Balance.difficulty(0.0), false)
		target.hp = 1000.0
		target.max_hp = 1000.0
		target.speed = 0.0
		game.world.add_child(target)
		game.enemies.append(target)
		var second = game.Enemy.new()
		second.setup(ranged.position + Vector2(60, 80), game.Balance.difficulty(0.0), false)
		second.speed = 0.0
		game.world.add_child(second)
		game.enemies.append(second)
		ranged.skill_cooldown = 0.0
		ranged.suppression_remaining = 0.0
		var ranged_cast: bool = game.activate_skill(0)
		game._fire(ranged)
		check(ranged_cast and game.projectiles.size() == 2
			and is_equal_approx(game.projectiles[0].damage, 14.0 * Upgrades.MULTIPLIERS[tier])
			and is_equal_approx(game.projectiles[1].damage, 14.0 * Upgrades.MULTIPLIERS[tier] * 0.75 * 1.25),
			"tier %d shared damage scales suppression shots and multiplies personal enhancement" % tier)
		for bullet in game.projectiles:
			bullet.free()
		game.projectiles.clear()
		ranged.shot_cooldown = 1000.0
		melee.shot_cooldown = 1000.0
		melee.skill_cooldown = 0.0
		var melee_cast: bool = game.activate_skill(1, Vector2.RIGHT)
		game.simulate(0.2, [Vector2.ZERO, Vector2.ZERO])
		check(melee_cast and is_equal_approx(1000.0 - target.hp, 17.0 * Upgrades.MULTIPLIERS[tier] * 3.2 * 1.35),
			"tier %d shared damage scales swept dash damage and multiplies personal enhancement" % tier)
	game.free()
	print("SKILL DAMAGE RESULT: 6 checks, %d failures" % failures)
	quit(0 if failures == 0 else 1)

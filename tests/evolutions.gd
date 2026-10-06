extends SceneTree
## Focused evolution unlock, choice and combat checks; no long simulation.
const MainScene = preload("res://scenes/main.tscn")
const Skills = preload("res://scripts/skill_upgrades.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func target(at: Vector2):
	var node = game.Enemy.new()
	node.setup(at, game.Balance.difficulty(0.0), false)
	node.hp = 1000.0
	node.max_hp = 1000.0
	node.speed = 0.0
	game.world.add_child(node)
	game.enemies.append(node)
	return node

func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	for node in game.enemies:
		node.free()
	game.enemies.clear()
	var ranged = game.players[0]
	var melee = game.players[1]
	check(not Skills.apply(ranged, "radial_evolution"), "evolution cannot activate before three level-ups")
	for index in range(3):
		game.add_shared_xp(game.Balance.xp_required(game.team_level))
		if index < 2:
			check(not ranged.offers[0].get("evolution", false) and not melee.offers[0].get("evolution", false),
				"level-up %d still offers normal skill upgrades" % (index + 1))
			game.choose_upgrade(0, 0)
			game.choose_upgrade(1, 0)
			game.choose_team_upgrade(0)
	check(game.team_level == 4 and ranged.offers[0].id == "radial_evolution"
		and melee.offers[0].id == "ram_evolution" and ranged.offers[1].id == "keep_skill"
		and not game.hud.choice_buttons[0][2].visible, "third level-up offers optional evolution with only two visible choices")
	game.choose_upgrade(0, 0)
	game.choose_upgrade(1, 0)
	game.choose_team_upgrade(0)
	check(ranged.skill_stats.radial_enabled and melee.skill_stats.ram_enabled
		and game.simulation_speed() == 1.0 and not Skills.apply(ranged, "radial_evolution"),
		"players independently evolve once and all choices resume combat")
	if int(ranged.ranks.get("damage", 0)) == 0:
		Upgrades.apply(ranged, "damage")
	if int(melee.ranks.get("damage", 0)) == 0:
		Upgrades.apply(melee, "damage")
	var ranged_origin: Vector2 = ranged.position
	game.activate_skill(0)
	var count := 16 + 2 * (int(ranged.stats.projectiles) - 1)
	check(game.projectiles.size() == count
		and is_equal_approx(game.projectiles[0].damage, float(ranged.stats.damage) * float(ranged.skill_stats.extra_damage))
		and game.projectiles[0].velocity.normalized().is_equal_approx(Vector2.RIGHT)
		and game.projectiles[count / 2].velocity.normalized().is_equal_approx(Vector2.LEFT),
		"turret fires a full 360-degree ring without targets and inherits shared and personal damage")
	ranged.advance(1.0, Vector2.RIGHT)
	check(ranged.position == ranged_origin and ranged.movement_speed() == 0.0 and not ranged.moving,
		"turret remains anchored despite held movement")
	ranged.advance(ranged.suppression_remaining, Vector2.LEFT)
	check(ranged.position == ranged_origin and ranged.skill_cooldown == float(ranged.skill_stats.cooldown),
		"last active frame stays anchored and starts the full cooldown")
	ranged.advance(0.1, Vector2.RIGHT)
	check(ranged.position.x > ranged_origin.x, "movement returns after the turret expires")
	for bullet in game.projectiles:
		bullet.free()
	game.projectiles.clear()
	ranged.shot_cooldown = 1000.0
	melee.shot_cooldown = 1000.0
	melee.position = Vector2(500, 400)
	var hit = target(Vector2(580, 460))
	var outside = target(Vector2(580, 480))
	var ahead = target(Vector2(1050, 400))
	game.activate_skill(1, Vector2.RIGHT)
	game.simulate(0.1, [Vector2.RIGHT, Vector2.ZERO])
	var hit_hp: float = hit.hp
	check(is_equal_approx(1000.0 - hit.hp, float(melee.stats.damage) * float(melee.skill_stats.damage))
		and hit.knockback_remaining > 0.0 and hit.position.x > 580.0
		and outside.hp == 1000.0 and ahead.hp == 1000.0 and game.skill_effects[-1].has("points"),
		"rectangular swept charge hits its wide edge, knocks back and excludes distant enemies")
	game.simulate(0.1, [Vector2.ZERO, Vector2.ZERO])
	check(is_equal_approx(hit.hp, hit_hp) and is_equal_approx(hit.position.x, 680.0)
		and not game.activate_skill(1), "charge hits once, pushes 100 pixels and cannot return or recast")
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	check(not ranged.offers[0].get("evolution", false) and not melee.offers[0].get("evolution", false),
		"subsequent level-ups return to normal skill enhancements")
	var keeper = game.Player.new()
	keeper.configure_class(0)
	keeper.level = 4
	check(Skills.apply(keeper, "keep_skill") and keeper.evolution_decided
		and not keeper.skill_stats.radial_enabled and is_equal_approx(keeper.skill_stats.extra_damage, 0.75 * 1.15),
		"declining evolution keeps the original skill and grants its small damage bonus")
	keeper.free()
	var queued = game.Player.new()
	queued.configure_class(1)
	queued.level = 4
	queued.pending_upgrades = 3
	queued.begin_choice()
	queued.choose(0)
	queued.begin_choice()
	queued.choose(0)
	queued.begin_choice()
	check(queued.offers[0].id == "ram_evolution", "multiple queued level-ups unlock evolution on the third choice")
	queued.free()
	game.free()
	print("EVOLUTION RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

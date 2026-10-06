extends SceneTree
## Short checks for the new selection and active skills; no long simulation.

const MainScene = preload("res://scenes/main.tscn")
var game
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_key_input(event)

func right_click(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = game.get_global_transform_with_canvas() * at
	game._unhandled_input(event)

func enemy(at: Vector2, health := 300.0):
	var node = game.Enemy.new()
	node.setup(at, game.Balance.difficulty(0.0), false)
	node.hp = health
	node.max_hp = health
	node.speed = 0.0
	game.world.add_child(node)
	game.enemies.append(node)
	return node

func clear_combat() -> void:
	for node in game.enemies + game.projectiles + game.gems:
		node.free()
	game.enemies.clear()
	game.projectiles.clear()
	game.gems.clear()

func step(seconds: float) -> void:
	for tick in range(int(round(seconds * 60.0))):
		game.simulate(1.0 / 60.0, [Vector2.ZERO, Vector2.ZERO])

func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.simulate(1.0, [Vector2.RIGHT, Vector2.LEFT])
	check(game.selecting_classes and game.elapsed == 0.0 and game.players[0].role == 0 and game.players[1].role == 1,
		"selection freezes the world, with Gunner P1 and Raider P2 defaults")
	key(KEY_7)
	check(game.players[0].stats == game.players[1].stats and game.selected_classes == [0, 0],
		"P2 keyboard selection allows matching careers and identical starting stats")
	key(KEY_8)
	key(KEY_SPACE)
	check(game.selecting_classes and game.class_ready[0], "one ready player waits for the other")
	key(KEY_ENTER)
	check(not game.selecting_classes and game.simulation_speed() == 1.0 and game.players[0].suppression_remaining == 0.0,
		"both skill keys ready and start the run without casting a skill")
	var gunner = game.players[0]
	var raider = game.players[1]
	var base: Dictionary = gunner.stats.duplicate(true)
	key(KEY_SPACE)
	check(gunner.suppression_remaining == 4.0 and gunner.skill_cooldown == 10.0
		and is_equal_approx(gunner.attack_interval(), float(base.interval) / 2.2)
		and is_equal_approx(gunner.attack_range(), float(base.range) * 1.35)
		and is_equal_approx(gunner.movement_speed(), float(base.speed) * 0.85)
		and not game.activate_skill(0), "suppression applies temporary modifiers and blocks recasting")
	enemy(gunner.position + Vector2(0, 180))
	enemy(gunner.position + Vector2(180, 0))
	game._fire(gunner)
	check(game.projectiles.size() == 2 and not game.projectiles[0].velocity.normalized().is_equal_approx(game.projectiles[1].velocity.normalized()),
		"suppression adds a shot aimed at a different nearby target")
	gunner.advance(4.05, Vector2.ZERO)
	check(gunner.suppression_remaining == 0.0 and gunner.stats == base
		and is_equal_approx(gunner.attack_interval(), float(base.interval)) and is_equal_approx(gunner.skill_cooldown, 9.95),
		"suppression expires without changing base stats and starts the full cooldown")
	clear_combat()
	gunner.shot_cooldown = 1000.0
	raider.shot_cooldown = 1000.0
	raider.position = Vector2(600, 400)
	raider.invulnerability = 0.0
	var wide_target = enemy(Vector2(660, 480))
	var route_target = enemy(Vector2(830, 400))
	var outside = enemy(Vector2(700, 500))
	var single_origin: Vector2 = raider.position
	var single_hp: float = raider.hp
	var dash_damage: float = float(raider.stats.damage) * float(raider.skill_stats.damage)
	key(KEY_ENTER)
	check(raider.dash_remaining == 0.0, "Raider no longer casts using the old keyboard skill key")
	game.paused = true
	right_click(raider.position + Vector2(500, 0))
	check(raider.dash_remaining == 0.0 and raider.skill_cooldown == 0.0, "right-click dash remains blocked while paused")
	game.paused = false
	right_click(raider.position)
	check(raider.dash_remaining == 0.0 and raider.skill_cooldown == 0.0, "clicking exactly on the Raider does not spend the skill cooldown")
	raider.last_move_direction = Vector2.LEFT
	right_click(raider.position + Vector2(500, 0))
	check(raider.last_move_direction == Vector2.RIGHT and raider.dash_target.x > raider.position.x
		and gunner.suppression_remaining == 0.0, "right mouse button dashes toward the cursor, ignoring previous movement and the Gunner")
	check(raider.dash_remaining > 0.0 and raider.return_remaining == 0.0
		and not game.activate_skill(1, Vector2.LEFT), "default Raider casts only one dash and rejects an immediate second press")
	raider.take_damage(999.0)
	step(0.1)
	check(raider.hp >= single_hp and is_equal_approx(wide_target.hp, 300.0 - dash_damage)
		and route_target.hp == 300.0 and outside.hp == 300.0,
		"dash protects the player and damages only the already swept, widened route")
	check(raider.skill_cooldown == 6.0, "single dash holds the full cooldown until movement ends")
	step(0.1)
	check(raider.position.is_equal_approx(single_origin + Vector2(230, 0))
		and is_equal_approx(wide_target.hp, 300.0 - dash_damage)
		and is_equal_approx(route_target.hp, 300.0 - dash_damage) and outside.hp == 300.0
		and game.marked_count(1) == 0, "full dash hits each route enemy once, includes the final segment and creates no return marks")
	key(KEY_ENTER)
	check(raider.position.is_equal_approx(single_origin + Vector2(230, 0))
		and is_equal_approx(raider.skill_cooldown, 5.98), "second press neither returns nor recasts during cooldown")
	step(0.15)
	single_hp = raider.hp
	raider.take_damage(1.0)
	check(is_equal_approx(raider.hp, single_hp - 1.0), "dash invulnerability expires after its short protection window")
	clear_combat()
	# Legacy mode remains available explicitly; it is not a default upgrade.
	raider.skill_stats.return_enabled = true
	raider.skill_cooldown = 0.0
	raider.position = Vector2(600, 400)
	raider.invulnerability = 0.0
	var origin: Vector2 = raider.position
	var target = enemy(Vector2(660, 400))
	var second = enemy(Vector2(790, 400))
	game.activate_skill(1, Vector2.RIGHT)
	var health: float = raider.hp
	raider.take_damage(999.0)
	step(0.2)
	check(raider.hp >= health and raider.position.is_equal_approx(origin + Vector2(230, 0))
		and target.marks.has(1) and second.marks.has(1), "dash is invulnerable and marks the entire swept route")
	var before: float = target.hp
	right_click(raider.position + Vector2(500, 0))
	check(raider.position == origin and is_equal_approx(before - target.hp, float(raider.stats.damage) * 3.2)
		and raider.skill_cooldown == 6.0 and game.marked_count(1) == 0 and raider.invulnerability >= 0.2,
		"second press returns, detonates once, clears marks and begins cooldown")
	check(not game.activate_skill(1), "return cannot be spammed during cooldown")
	raider.skill_cooldown = 0.0
	game.activate_skill(1, Vector2.RIGHT)
	before = target.hp
	step(1.25)
	check(raider.return_remaining == 0.0 and raider.position != origin and target.hp == before
		and raider.skill_cooldown > 5.8 and game.marked_count(1) == 0,
		"skipping return keeps the new position, clears marks without damage and starts cooldown")
	gunner.skill_cooldown = 0.0
	game.activate_skill(0)
	game.add_shared_xp(game.Balance.xp_required(1))
	var active_time: float = gunner.suppression_remaining
	var cooldown: float = raider.skill_cooldown
	game.simulate(1.0, [Vector2.RIGHT, Vector2.ZERO])
	game.choose_upgrade(0, 0)
	check(gunner.suppression_remaining == active_time and raider.skill_cooldown == cooldown
		and game.simulation_speed() == 0.0 and not game.activate_skill(1),
		"shared level-up freezes skill timers and waits for both independent Buff picks")
	game.choose_upgrade(1, 0)
	game.choose_team_upgrade(0)
	check(game.simulation_speed() == 1.0, "both Buff choices resume combat")
	# Two Raiders must not erase or detonate each other's marks.
	gunner.configure_class(1)
	gunner.skill_stats.return_enabled = true
	gunner.return_origin = gunner.position
	gunner.return_remaining = 1.0
	target.marks = {0: true, 1: true}
	before = target.hp
	game.activate_skill(0)
	check(target.marks.has(1) and not target.marks.has(0)
		and is_equal_approx(before - target.hp, float(gunner.stats.damage) * 3.2),
		"matching Raiders own independent enemy marks")
	clear_combat()
	gunner.skill_cooldown = 0.0
	game.activate_skill(0, Vector2.RIGHT)
	var fragile = enemy(gunner.position + Vector2(60, 0), 1.0)
	# Route collision was verified above; isolate detonation from automatic gunfire.
	game._mark_dash(0, gunner.position, gunner.position + Vector2(100, 0))
	var kills: int = gunner.kills
	var returned: bool = game.activate_skill(0)
	check(returned and fragile.dead and gunner.kills == kills + 1 and game.gems.size() == 1,
		"detonation kills grant exactly one kill and XP drop")
	game.free()
	print("SKILLS RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

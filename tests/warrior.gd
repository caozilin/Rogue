extends SceneTree
## Short checks specific to Warcry and Giant. No full combat simulation.
const MainScene = preload("res://scenes/main.tscn")
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

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_key_input(event)

func enemy(at: Vector2, kind := "normal"):
	var node = game.Enemy.new()
	node.setup(at, game.Balance.difficulty(0.0), kind == "elite", kind)
	node.hp = 1000.0
	node.max_hp = 1000.0
	node.speed = 0.0
	game.world.add_child(node)
	game.enemies.append(node)
	return node

func boss(at: Vector2):
	var node = game.MiniBoss.new()
	node.setup_boss(at, game.Balance.difficulty(0.0), 1)
	game.world.add_child(node)
	game.enemies.append(node)
	return node

func clear_enemies() -> void:
	for node in game.enemies:
		node.free()
	game.enemies.clear()

func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	clear_enemies()
	var ranged = game.players[0]
	var warrior = game.players[1]
	ranged.position = Vector2(350, 400)
	warrior.position = Vector2(1000, 400)
	ranged.shot_cooldown = 1000.0
	warrior.shot_cooldown = 1000.0
	var ordinary = enemy(Vector2(100, 200))
	var elite = enemy(Vector2(200, 200), "elite")
	var caster = enemy(Vector2(380, 240), "mortar")
	var leader = boss(Vector2(440, 250))
	caster.attack_windup = 1.0
	leader.state = "windup"
	leader.attack_windup = 1.0
	check(game.priority_enemy_target(ordinary.position) == ranged, "normal aggro picks the closer player")
	key(KEY_1)
	check(warrior.warcry_remaining == 4.0 and warrior.warcry_cooldown == 20.0
		and ranged.warcry_remaining == 0.0 and not game.activate_warrior_skill(1, 1),
		"key 1 casts Warcry on the warrior with four-second duration and twenty-second cooldown")
	var all_taunted := true
	for node in [ordinary, elite, caster, leader]:
		all_taunted = all_taunted and game.priority_enemy_target(node.position) == warrior
		all_taunted = all_taunted and node.priority_target_id == warrior.get_instance_id()
	check(all_taunted and caster.attack_landing == warrior.position
		and leader.attack_direction.is_equal_approx(leader.position.direction_to(warrior.position)),
		"map-wide taunt affects normal, elite, ranged and Boss enemies and redirects queued attacks")
	var arrival = enemy(Vector2(40, 130))
	check(game.priority_enemy_target(arrival.position) == warrior, "new arrivals also prefer the taunting warrior")
	warrior.advance(4.0, Vector2.ZERO)
	game.simulate(0.01, [Vector2.ZERO, Vector2.ZERO])
	check(warrior.warcry_remaining == 0.0 and is_equal_approx(warrior.warcry_cooldown, 15.99)
		and game.priority_enemy_target(caster.position) == ranged and caster.priority_target_id == -1,
		"taunt ends at four seconds, restores aggro and counts cooldown from release")
	clear_enemies()
	warrior.position = Vector2(500, 400)
	Upgrades.apply(warrior, "speed")
	var global_speed: float = warrior.stats.speed
	key(KEY_2)
	check(warrior.giant_remaining == 4.0 and warrior.giant_cooldown == 15.0
		and not game.activate_warrior_skill(1, 2) and ranged.giant_remaining == 0.0,
		"key 2 casts Giant independently and does not affect the ranged player")
	check(is_equal_approx(warrior.movement_speed(), float(warrior.base_stats.speed) * 2.5)
		and warrior.stats.speed == global_speed and warrior.body_scale() == 3.0 and warrior.collision_radius() == 48.0,
		"Giant adds 100 percent to the global speed bonus and triples actual body and collision size")
	warrior.invulnerability = 0.0
	warrior.hp = 100.0
	warrior.take_damage(100.0)
	check(is_equal_approx(warrior.hp, 80.0), "Giant reduces incoming damage by eighty percent")
	warrior.invulnerability = 0.0
	var bullet = game.EnemyBullet.new()
	bullet.position = warrior.position + Vector2(-50, 40)
	bullet.velocity = Vector2(100, 0)
	bullet.damage = 50.0
	game.world.add_child(bullet)
	game.enemy_bullets.append(bullet)
	game._update_enemy_attacks(1.0)
	check(is_equal_approx(warrior.hp, 70.0) and game.enemy_bullets.is_empty(),
		"enemy shots use the larger hitbox and share the same damage reduction")
	warrior.invulnerability = 0.0
	var hazard = game.EnemyHazard.new()
	hazard.position = warrior.position + Vector2(100, 0)
	hazard.warning_remaining = 0.0
	hazard.damage = 50.0
	game.world.add_child(hazard)
	game.enemy_hazards.append(hazard)
	game._update_enemy_attacks(0.0)
	check(is_equal_approx(warrior.hp, 60.0), "area damage also uses Giant's hitbox and reduction")
	ordinary = enemy(warrior.position + Vector2(60, 0))
	elite = enemy(warrior.position + Vector2(0, 65), "elite")
	leader = boss(warrior.position + Vector2(-70, 0))
	var ordinary_origin: Vector2 = ordinary.position
	var elite_origin: Vector2 = elite.position
	var contact_starts: Array[Vector2] = [ranged.position, warrior.position]
	game._update_giant_contacts(contact_starts)
	ordinary.advance(0.2, warrior)
	elite.advance(0.2, warrior)
	check(is_equal_approx(ordinary.position.distance_to(ordinary_origin), 120.0)
		and is_equal_approx(elite.position.distance_to(elite_origin), 18.0)
		and leader.knockback_remaining == 0.0 and leader.tenacity == 1.0,
		"contact knockback pushes small enemies far, elites only a little and leaves Bosses unaffected")
	Upgrades.apply(warrior, "speed")
	check(is_equal_approx(warrior.movement_speed(), float(warrior.base_stats.speed) * 3.0),
		"global speed upgrades still add correctly while Giant is active")
	warrior.advance(4.0, Vector2.ZERO)
	check(warrior.giant_remaining == 0.0 and warrior.giant_cooldown == 11.0
		and warrior.body_scale() == 1.0 and warrior.movement_speed() == float(warrior.stats.speed),
		"Giant expires at four seconds and restores normal speed and size without editing Buff stats")
	clear_enemies()
	warrior.warcry_cooldown = 0.0
	warrior.giant_cooldown = 0.0
	game.paused = true
	key(KEY_1)
	key(KEY_2)
	check(warrior.warcry_remaining == 0.0 and warrior.giant_remaining == 0.0, "pause blocks both new skills")
	game.paused = false
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	key(KEY_1)
	key(KEY_2)
	key(KEY_4)
	key(KEY_7)
	check(game.team_pending_upgrades == 1 and ranged.pending_upgrades == 1 and warrior.pending_upgrades == 1
		and warrior.warcry_remaining == 0.0 and warrior.giant_remaining == 0.0,
		"numeric keys neither select Buffs nor cast skills during upgrade pause")
	game.hud.choice_buttons[0][0].pressed.emit()
	game.hud.choice_buttons[1][0].pressed.emit()
	game.hud.team_buttons[0].pressed.emit()
	check(game.simulation_speed() == 1.0, "mouse card choices resume combat normally")
	key(KEY_1)
	key(KEY_2)
	warrior.invulnerability = 0.0
	warrior.take_damage(10000.0)
	check(warrior.downed and warrior.warcry_remaining == 0.0 and warrior.giant_remaining == 0.0
		and warrior.body_scale() == 1.0 and warrior.warcry_cooldown == 20.0 and warrior.giant_cooldown == 15.0
		and game.priority_enemy_target(ranged.position) == ranged,
		"death clears taunt and Giant immediately while preserving their cooldowns")
	game.free()
	print("WARRIOR RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

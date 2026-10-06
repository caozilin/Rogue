extends SceneTree
## Only Rescue/carrying, the shared revival limit and numpad bindings.
const MainScene = preload("res://scenes/main.tscn")
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

func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	for enemy in game.enemies:
		enemy.free()
	game.enemies.clear()
	var ally = game.players[0]
	var warrior = game.players[1]
	ally.position = Vector2(400, 400)
	warrior.position = Vector2(800, 400)
	ally.shot_cooldown = 1000.0
	warrior.shot_cooldown = 1000.0
	key(KEY_KP_1)
	key(KEY_KP_2)
	check(warrior.warcry_remaining == 4.0 and warrior.giant_remaining == 4.0,
		"numpad 1 and 2 activate Warcry and Giant")
	game.activate_skill(1, Vector2.RIGHT)
	game.activate_skill(0)
	key(KEY_KP_3)
	check(warrior.position == ally.position and warrior.dash_remaining == 0.0
		and warrior.rescue_cooldown == 20.0 and warrior.carry_remaining == 3.0
		and ally.is_carried() and not game.instant_revive_used,
		"numpad 3 teleports to the living ally, stops the old dash and carries for three seconds")
	check(ally.suppression_remaining == 4.0, "rescue does not interrupt the ally's existing skill")
	ally.last_move_direction = Vector2.UP
	game.simulate(0.1, [Vector2.LEFT, Vector2.RIGHT])
	check(warrior.position.x > 400.0 and ally.position == warrior.position
		and ally.last_move_direction == Vector2.UP,
		"only the ally's position follows the warrior; its aim remains independent")
	ally.suppression_remaining = 0.0
	ally.skill_cooldown = 0.0
	key(KEY_SPACE)
	check(ally.suppression_remaining == 4.0 and ally.attack_interval() < float(ally.stats.interval),
		"a carried gunner can activate its own combat skill normally")
	var target = game.Enemy.new()
	target.setup(warrior.position + Vector2(150, 0), game.Balance.difficulty(0.0), false)
	game.world.add_child(target)
	game.enemies.append(target)
	game._fire(ally)
	check(game.projectiles.size() == 1, "the carried ally can still attack automatically")
	ally.skill_stats.radial_enabled = true
	ally.suppression_remaining = 0.0
	ally.skill_cooldown = 0.0
	check(game.activate_skill(0) and game.projectiles.size() == 17,
		"a carried gunner can activate the full 360-degree barrage")
	game.enemies.clear()
	target.free()
	for bullet in game.projectiles:
		bullet.free()
	game.projectiles.clear()
	ally.skill_stats.radial_enabled = false
	var ally_hp: float = ally.hp
	var warrior_hp: float = warrior.hp
	warrior.invulnerability = 0.0
	ally.invulnerability = 0.0
	ally.take_damage(50.0)
	check(ally.hp == ally_hp and is_equal_approx(warrior.hp, warrior_hp - 10.0),
		"ally damage transfers exactly once and uses the warrior's eighty-percent reduction")
	warrior.invulnerability = 0.0
	ally.invulnerability = 1.0
	warrior_hp = warrior.hp
	ally.take_damage(50.0)
	check(warrior.hp == warrior_hp and ally.hp == ally_hp,
		"the carried ally's own invulnerability still prevents damage")
	var carry_time: float = warrior.carry_remaining
	game.paused = true
	game.simulate(1.0, [Vector2.LEFT, Vector2.RIGHT])
	key(KEY_KP_3)
	check(warrior.carry_remaining == carry_time and ally.position == warrior.position,
		"pause freezes carrying and blocks rescue recasting")
	game.paused = false
	warrior.advance(3.0, Vector2.ZERO)
	ally.advance(3.0, Vector2.ZERO)
	game._update_carries()
	var release_at: Vector2 = ally.position
	ally.advance(0.1, Vector2.UP)
	check(not ally.is_carried() and warrior.carrying == null and ally.position.y < release_at.y
		and ally.suppression_remaining > 0.0 and not game.activate_warrior_skill(1, 3),
		"after three seconds movement returns, the ally's active skill continues and rescue remains on cooldown")
	ally.suppression_remaining = 0.0
	warrior.advance(warrior.rescue_cooldown, Vector2.ZERO)
	ally.invulnerability = 0.0
	ally.take_damage(10000.0)
	var corpse: Vector2 = ally.position
	warrior.position = Vector2(900, 600)
	key(KEY_3)
	check(warrior.position == corpse and not ally.downed and is_equal_approx(ally.hp, float(ally.stats.max_hp) * 0.5)
		and ally.invulnerability == 3.0 and game.instant_revive_used and warrior.carry_remaining == 0.0,
		"top-row 3 teleports to a corpse and spends the team's one immediate revival")
	# Swap which warrior performs the next rescue: the revival limit belongs to the team.
	ally.configure_class(game.Classes.RAIDER)
	warrior.position = Vector2(700, 300)
	warrior.invulnerability = 0.0
	warrior.take_damage(10000.0)
	key(KEY_SPACE)
	check(ally.position == warrior.position and warrior.downed and ally.rescue_cooldown == 20.0,
		"the other warrior can still teleport to a corpse but cannot spend a second immediate revival")
	game._update_revives(3.0)
	check(not warrior.downed and game.instant_revive_used, "normal proximity revival still works after the instant revival is used")
	ally.rescue_cooldown = 0.0
	key(KEY_SPACE)
	check(warrior.is_carried() and ally.carrying == warrior, "a warrior teammate can also be carried without reciprocal carrying")
	check(game.activate_warrior_skill(1, 1) and game.activate_warrior_skill(1, 2)
		and warrior.is_carried() and warrior.warcry_remaining == 4.0 and warrior.giant_remaining == 4.0,
		"a carried warrior can use Warcry and Giant")
	warrior.giant_remaining = 0.0
	var dash_enemy = game.Enemy.new()
	dash_enemy.setup(ally.position + Vector2(40, 0), game.Balance.difficulty(0.0), false)
	dash_enemy.hp = 10000.0
	dash_enemy.speed = 0.0
	game.world.add_child(dash_enemy)
	game.enemies.append(dash_enemy)
	check(game.activate_skill(1, Vector2.RIGHT), "a carried warrior can cast its dash")
	game.simulate(0.1, [Vector2.UP, Vector2.RIGHT])
	check(warrior.position == ally.position and dash_enemy.hp < 10000.0,
		"carried dash deals damage at the bound position without independent displacement")
	game.enemies.erase(dash_enemy)
	dash_enemy.free()
	warrior.rescue_cooldown = 0.0
	check(game.activate_warrior_skill(1, 3) and warrior.carrying == ally and ally.is_carried()
		and not warrior.is_carried() and ally.carrying == null,
		"a carried warrior can rescue and replace the carry link without a cycle")
	warrior.invulnerability = 0.0
	warrior.take_damage(10000.0)
	check(warrior.downed and not ally.is_carried() and warrior.carrying == null and warrior.rescue_cooldown == 20.0,
		"carrier death releases the living teammate immediately and keeps rescue on cooldown")
	game.free()
	print("RESCUE RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

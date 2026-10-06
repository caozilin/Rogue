extends SceneTree
## Only rescue-to-possession transfer and its release paths.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1

func run() -> void:
	for mage_id in range(2):
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		game.selected_classes = [0, 1] if mage_id == 0 else [1, 0]
		game.start_run()
		for enemy in game.enemies: enemy.free()
		game.enemies.clear()
		var mage = game.players[mage_id]
		var warrior = game.players[1 - mage_id]
		mage.position = Vector2(500, 410)
		warrior.position = Vector2(800, 410)
		var rescued: bool = game.activate_warrior_skill(1 - mage_id, 3)
		mage.possession_cooldown = 1.0
		var blocked: bool = not game.activate_mage_skill(mage_id, 3)
		check(rescued and blocked and mage.is_carried() and warrior.carrying == mage and warrior.carry_remaining == 3.0,
			"P%d: failed cast keeps the rescue link intact" % (mage_id + 1))
		mage.possession_cooldown = 0.0
		game.paused = true
		check(not game.activate_mage_skill(mage_id, 3) and mage.is_carried(), "P%d: pause still blocks possession without releasing rescue" % (mage_id + 1))
		game.paused = false
		var event := InputEventKey.new()
		event.physical_keycode = KEY_R if mage_id == 0 else KEY_2
		event.pressed = true
		game._unhandled_key_input(event)
		check(mage.is_possessed() and mage.possession_host == warrior and warrior.possessed_by == mage
			and mage.carried_by == null and warrior.carrying == null and warrior.carry_remaining == 0.0
			and mage.possession_remaining == 5.0 and mage.possession_cooldown == 25.0
			and warrior.rescue_cooldown == 20.0 and is_equal_approx(mage.output_damage(), float(mage.stats.damage) * 1.35),
			"P%d: real skill key transfers rescue into normal five-second possession and buffs" % (mage_id + 1))
		warrior.position += Vector2(100, 30)
		game._update_carries()
		game.mage_system.update_links(3.1)
		check(mage.position == warrior.position and mage.is_possessed() and not mage.is_targetable(),
			"P%d: follows the warrior beyond the old rescue duration" % (mage_id + 1))
		if mage_id == 0:
			game.mage_system.update_links(2.0)
		else:
			warrior.invulnerability = 0.0
			warrior.take_damage(10000.0)
		check(not mage.is_possessed() and not mage.is_carried() and mage.possession_host == null
			and warrior.possessed_by == null and mage.z_index == 0 and mage.is_targetable(),
			"P%d: expiry or host death releases the mage without a stale carry link" % (mage_id + 1))
		game.free()
	print("RESCUE POSSESSION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
## Actual health loss, ownership and the small top-center HUD only.
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

func enemy_at(at: Vector2):
	var enemy = game.Enemy.new()
	enemy.setup(at, game.Balance.difficulty(0), false)
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	return enemy

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.damage_totals == [0.0, 0.0] and not game.hud.damage_board.visible, "new runs have zero totals and no board over class selection")
	game.start_run()
	var enemy = enemy_at(Vector2(640, 410))
	game._damage_enemy(enemy, 10.0, 0)
	game._damage_enemy(enemy, 1000.0, 1)
	game._damage_enemy(enemy, 1000.0, 0)
	check(game.damage_totals == [10.0, 26.0], "kill credit counts remaining health only; dead targets cannot add damage")
	var priest = game.ThornBoss.new()
	priest.setup_boss(Vector2(820, 410), game.Balance.difficulty(120), 0)
	game.world.add_child(priest)
	game.enemies.append(priest)
	var guard = enemy_at(Vector2(820, 440))
	priest.guards.append(guard)
	game._damage_enemy(priest, 100.0, 0)
	check(game.damage_totals[0] == 75.0, "guard armor counts the actual 65 health lost instead of 100 raw damage")
	var final = game.FinalBoss.new()
	final.setup_boss(Vector2(420, 410), game.Balance.difficulty(180), 0)
	final.state = "recover"
	game.world.add_child(final)
	game.enemies.append(final)
	game.mage_system.elements.attach(final, "ice")
	game.mage_system.elements.damage(final, 100.0, 1, "fire")
	check(game.damage_totals[1] == 276.0, "element reaction and recovery opening count the full actual 250 damage for the attacker")
	var dot = enemy_at(Vector2(640, 530))
	game.mage_system.elements.fire_ground(dot, 10.0, 0)
	game.mage_system.elements.advance(0.5)
	check(game.damage_totals[0] == 80.0, "periodic fire damage belongs to its original owner")
	game.hud.refresh()
	var board: Rect2 = game.hud.damage_board.get_global_rect()
	var clear_layout: bool = board.position.x > 474.0 and board.end.x < 806.0 and board.position.y >= game.hud.time_label.get_rect().end.y and board.end.y <= 192.0
	check(game.hud.damage_rows[0].text.contains("P2") and game.hud.damage_rows[1].text.contains("P1") and clear_layout, "leaderboard sorts by total and fits between both docks below the clock")
	var target = enemy_at(Vector2(1000, 530))
	target.hp = 2000000.0
	target.max_hp = target.hp
	game._damage_enemy(target, 1234291.89, 1)
	game.hud.refresh()
	check(is_equal_approx(game.damage_totals[1], 1234567.89) and game.hud.damage_rows[0].text.contains("1,234,567"), "totals keep fractional damage while the compact HUD groups whole units")
	if "--capture" in OS.get_cmdline_user_args():
		for old in game.enemies: old.queue_free()
		game.enemies.clear()
		game.damage_events.clear()
		for at in [Vector2(1000, 370), Vector2(270, 440), Vector2(790, 550)]: enemy_at(at)
		game.players[0].position = Vector2(570, 440)
		game.players[1].position = Vector2(710, 440)
		game.hud.refresh()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		print("SCREENSHOT damage_board.png result=", root.get_texture().get_image().save_png("res://artifacts/damage_board.png"))
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	game.hud.refresh()
	check(not game.hud.damage_board.visible and game.damage_totals[1] > 1234567.0, "upgrade cards hide the board without clearing its totals")
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	fresh.set_physics_process(false)
	check(fresh.damage_totals == [0.0, 0.0], "a fresh game resets both cumulative counters")
	fresh.free()
	game.free()
	print("DAMAGE BOARD RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

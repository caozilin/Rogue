extends SceneTree
## Only fixed encounter timing and end-of-battle behavior.

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

func snapshot(filename: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	game.hud.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/" + filename)
	print("SCREENSHOT ", filename, " result=", result)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game.next_wave = 1000.0
	game.elapsed = 59.0
	game._update_spawning(0.0)
	check(not game.boss_alive(), "no miniboss before 60 seconds")
	game.elapsed = 60.0
	game._update_spawning(0.0)
	var first = game.mini_boss
	check(first.display_name() == "孢冠统领" and game.boss_encounters == 1 and game.next_boss == 120.0, "first miniboss appears at 60 seconds and fixes the next deadline at 120")
	game.elapsed = 119.0
	game._update_spawning(0.0)
	check(game.mini_boss == first and game.boss_encounters == 1, "second miniboss does not appear early")
	game.elapsed = 120.0
	game._update_spawning(0.0)
	var second = game.mini_boss
	first.position = Vector2(450, 390)
	second.position = Vector2(825, 400)
	first.queue_redraw()
	second.queue_redraw()
	game._spawn_mini_boss()
	game.hud.refresh()
	check(second.display_name() == "荆棘祭司" and not first.dead and game.boss_encounters == 2 and game.hud.other_boss_hint.visible, "second miniboss appears at 120 even if the first survives; both are shown and duplicates are blocked")
	await snapshot("boss_schedule_dual.png")
	game._damage_enemy(second, second.hp * 2.0 + 100.0, 0)
	game._update_projectiles(0.0)
	game.elapsed = 179.0
	game._update_spawning(0.0)
	check(game.mini_boss == first and not game.final_battle and game.boss_encounters == 2, "remaining miniboss keeps its HUD and no third miniboss is scheduled")
	game.elapsed = 180.0
	game._update_spawning(0.0)
	var final = game.mini_boss
	game._spawn_enemy(Vector2.ZERO)
	game._spawn_mini_boss()
	check(game.final_battle and final.display_name() == "断界武王" and first.dead and game.enemies.size() == 1, "final boss takes over at 180 seconds, retires remaining enemies and blocks all spawns")
	game._damage_enemy(final, final.hp + 100.0, 0)
	game._update_projectiles(0.0)
	check(not game.game_over and game.final_transition_remaining == 3.0, "melee victory starts the artillery transition")
	game._update_spawning(3.0)
	game._damage_enemy(game.mini_boss, game.mini_boss.hp + 100.0, 0)
	game._update_projectiles(0.0)
	var ended_at: float = game.elapsed
	game.simulate(1.0, [Vector2.ZERO, Vector2.ZERO])
	check(game.victory and game.game_over and game.elapsed == ended_at and game.enemies.is_empty() and game.hud.modal_title.text.begins_with("终局胜利"), "killing the final boss ends combat immediately with victory and frozen time")
	await snapshot("boss_schedule_victory.png")
	game.free()
	print("BOSS SCHEDULE RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

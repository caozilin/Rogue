extends SceneTree
## Only opening pressure, wave spawning and the new enemy behaviors.

const MainScene = preload("res://scenes/main.tscn")
const Balance = preload("res://scripts/balance.gd")
const Enemy = preload("res://scripts/enemy.gd")
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

func all_on_edges(game) -> bool:
	for enemy in game.enemies:
		if Balance.ARENA.has_point(enemy.position):
			return false
	return true

func finish() -> void:
	print("PRESSURE RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.enemies.is_empty(), "class selection stays safe before the battle starts")
	game.start_run()
	check(game.enemies.size() == 1 and all_on_edges(game), "battle starts with one edge spawn and no nearby ring")
	game.start_run()
	check(game.enemies.size() == 1, "starting again does not duplicate spawns")
	for index in range(10):
		game._update_spawning(0.1)
	var runners := 0
	for enemy in game.enemies:
		if enemy.kind == "runner": runners += 1
	check(game.enemies.size() <= 3 and all_on_edges(game), "lower-density opening stream only spawns outside arena edges")
	var before_wave: int = game.enemies.size()
	game.elapsed = Balance.FIRST_WAVE_SECONDS
	game._update_spawning(0.0)
	check(game.enemies.size() == before_wave + Balance.wave_size(game.elapsed) and game.next_wave == Balance.FIRST_WAVE_SECONDS + Balance.WAVE_INTERVAL and all_on_edges(game), "smaller two-sided wave spawns at arena edges and schedules the next")
	game._update_spawning(0.0)
	check(game.enemies.size() == before_wave + Balance.wave_size(game.elapsed), "a wave only spawns once")
	if "--edges-only" in OS.get_cmdline_user_args():
		game.free()
		finish()
		return
	var growing := true
	for seconds in [60.0, 120.0, 180.0]:
		var before := Balance.difficulty(seconds - 60.0)
		var after := Balance.difficulty(seconds)
		for stat in ["health", "speed", "damage", "spawn_rate"]:
			growing = growing and float(after[stat]) > float(before[stat])
	check(growing and Balance.wave_size(600.0) > Balance.wave_size(12.0), "enemy stats, spawn rate and wave size continue growing")
	var kinds: Array[String] = []
	for seconds in [0.0, 60.0, 120.0]:
		kinds.clear()
		for serial in range(1, 181):
			var kind := Balance.enemy_kind(seconds, serial)
			if not kinds.has(kind): kinds.append(kind)
		check(kinds.size() == (2 if seconds == 0.0 else (6 if seconds == 60.0 else 8)), "enemy variety increases at %.0f seconds" % seconds)
	var charger := Enemy.new()
	charger.setup(Vector2(100, 400), Balance.difficulty(120.0), false, "charger")
	var target := Node2D.new()
	target.position = Vector2(300, 400)
	charger.charge_cooldown = 0.0
	charger.advance(0.01, target)
	var origin := charger.position
	target.position = Vector2(300, 600)
	charger.advance(0.35, target)
	check(charger.position == origin and charger.charge_windup > 0.0 and charger.charge_direction == Vector2.RIGHT,
		"charger stops and locks its warning direction before charging")
	charger.advance(0.4, target)
	charger.advance(0.2, target)
	check(charger.position.x > origin.x and is_equal_approx(charger.position.y, origin.y), "charger keeps the warned direction so the player can dodge sideways")
	game.paused = true
	var wave_time: float = game.next_wave
	var elapsed: float = game.elapsed
	game.simulate(1.0, [Vector2.ZERO, Vector2.ZERO])
	check(game.next_wave == wave_time and game.elapsed == elapsed, "pause freezes combat time and wave countdown")
	charger.free()
	target.free()
	game.free()
	finish()

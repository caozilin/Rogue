extends SceneTree
## Human-like movement and card selection ONLY: normal health, damage and XP.
## A deterministic balance sanity check, not a substitute for human playtesting.

const MainScene = preload("res://scenes/main.tscn")
const Balance = preload("res://scripts/balance.gd")

var game
var directions := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP,
	Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
	Vector2(-1, -1).normalized(), Vector2(1, -1).normalized(), Vector2.ZERO]
var last_moves := [Vector2.ZERO, Vector2.ZERO]
var selections: Array[int] = [0, 0]

func _initialize() -> void:
	call_deferred("run")

func decide(player) -> Vector2:
	if not player.is_active():
		return Vector2.ZERO
	var target: Vector2 = Vector2(640, 407)
	var closest_gem := INF
	for gem in game.gems:
		var distance: float = player.position.distance_to(gem.position)
		if distance < closest_gem:
			closest_gem = distance
			target = gem.position
	var ally = game.players[1 - player.player_id]
	if ally.downed:
		target = ally.position
	var best := INF
	var result := Vector2.ZERO
	for direction in directions:
		var predicted: Vector2 = player.position + direction * float(player.stats.speed) * 0.32
		var safe: Vector2 = predicted.clamp(Balance.ARENA.position + Vector2.ONE * 40,
			Balance.ARENA.end - Vector2.ONE * 40)
		var score: float = predicted.distance_to(safe) * 12.0 + predicted.distance_to(target) * 0.12
		for enemy in game.enemies:
			var future: Vector2 = enemy.position.move_toward(player.position, enemy.speed * 0.32)
			var distance: float = predicted.distance_to(future) - enemy.radius
			if distance < 110:
				score += pow(maxf(0.0, 110.0 - distance), 2) * 0.13
		# Rescue bots stop in range rather than walk over the body indefinitely.
		if ally.downed and predicted.distance_to(target) < 55:
			score -= 30
			if direction == Vector2.ZERO:
				score -= 8
		score += direction.distance_to(last_moves[player.player_id]) * 2.0
		if score < best:
			best = score
			result = direction
	return result

func select(player) -> void:
	var priority := {"damage": 10, "haste": 9, "pierce": 6, "multishot": 7,
		"crit": 6, "vitality": 3, "regen": 3, "speed": 4, "range": 1,
		"overclock": 10, "sustain": 8, "mobile_sight": 7, "rupture": 10, "long_raid": 8, "evasion": 7}
	if player.player_id == 1:
		priority.multishot = 10
		priority.pierce = 9
	if player.hp < player.stats.max_hp * 0.5:
		priority.vitality = 15
	var best := -1
	var pick := 0
	for index in range(3):
		var score: int = priority[player.offers[index].id]
		if score > best:
			best = score
			pick = index
	if game.choose_upgrade(player.player_id, pick):
		selections[player.player_id] += 1

func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game.rng.seed = 62518
	for id in range(2):
		game.players[id].rng.seed = 319 + id * 199
	for tick in range(90005):
		if game.team_choosing:
			game.choose_team_upgrade(0)
		for player in game.players:
			if player.choosing:
				select(player)
		if tick % 5 == 0:
			for id in range(2):
				last_moves[id] = decide(game.players[id])
		game.simulate(1.0 / 30.0, last_moves)
		if tick % 60 == 0:
			await process_frame
		if tick % 1800 == 0 or game.game_over:
			print("PLAY time=%.1f P1 lv=%d hp=%.1f kills=%d P2 lv=%d hp=%.1f kills=%d enemies=%d" % [
				game.elapsed, game.players[0].level, game.players[0].hp, game.players[0].kills,
				game.players[1].level, game.players[1].hp, game.players[1].kills, game.enemies.size()])
		if game.game_over or game.elapsed >= 600.01:
			break
	var passed: bool = game.elapsed >= 600.0 and not game.game_over
	print("NORMAL HEALTH BALANCE CHECK: ", "PASS" if passed else "FAILED", " time=", game.elapsed)
	print("BUFF CHOICES: P1=%d P2=%d total=%d" % [selections[0], selections[1], selections[0] + selections[1]])
	game.free()
	quit(0 if passed else 1)

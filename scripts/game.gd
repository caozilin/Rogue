extends Node2D
## One simulation owner keeps ordering explicit and makes headless tests possible.
## Nodes draw themselves; no physics bodies or resource imports are required.

const Balance = preload("res://scripts/balance.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Gem = preload("res://scripts/xp_gem.gd")
const HUD = preload("res://scripts/hud.gd")
const Classes = preload("res://scripts/classes.gd")
const Upgrades = preload("res://scripts/upgrades.gd")

var players: Array = []
var enemies: Array = []
var projectiles: Array = []
var gems: Array = []
var world: Node2D
var hud: CanvasLayer
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var spawn_credit := 0.0
var spawn_serial := 0
var next_wave := Balance.FIRST_WAVE_SECONDS
var paused := false
var game_over := false
var milestone := false
var hud_clock := 0.0
var damage_events: Array[Dictionary] = []
var shared_xp := 0
var team_level := 1
var selecting_classes := true
var selected_classes := [Classes.GUNNER, Classes.RAIDER]
var class_ready := [false, false]
var skill_effects: Array[Dictionary] = []
var team_pending_upgrades := 0
var team_choosing := false
var team_offers: Array[Dictionary] = []

func _ready() -> void:
	rng.randomize()
	_setup_input()
	world = Node2D.new()
	add_child(world)
	for id in range(2):
		var player := Player.new()
		player.setup(id, Vector2(570 + id * 140, 400))
		player.experience_gained.connect(add_shared_xp)
		world.add_child(player)
		players.append(player)
		player.configure_class(selected_classes[id])
	hud = HUD.new()
	hud.game = self
	add_child(hud)
	hud.refresh()
	queue_redraw()

func _setup_input() -> void:
	var bindings := {"p1_left": KEY_A, "p1_right": KEY_D, "p1_up": KEY_W,
		"p1_down": KEY_S, "p2_left": KEY_LEFT, "p2_right": KEY_RIGHT,
		"p2_up": KEY_UP, "p2_down": KEY_DOWN}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if selecting_classes:
		if key == KEY_1 or key == KEY_2:
			select_class(0, 0 if key == KEY_1 else 1)
		elif key in [KEY_7, KEY_KP_7, KEY_8, KEY_KP_8]:
			select_class(1, 0 if key in [KEY_7, KEY_KP_7] else 1)
		elif key == KEY_SPACE:
			toggle_ready(0)
		elif key in [KEY_ENTER, KEY_KP_ENTER]:
			toggle_ready(1)
	elif key == KEY_ESCAPE and not game_over:
		paused = not paused
		hud.refresh()
	elif key == KEY_R and game_over:
		restart()
	elif not paused and not game_over:
		if key == KEY_SPACE:
			activate_skill(0, Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down"))
		elif key in [KEY_ENTER, KEY_KP_ENTER]:
			activate_skill(1, Input.get_vector("p2_left", "p2_right", "p2_up", "p2_down"))
		var p1_keys := [KEY_1, KEY_2, KEY_3]
		var p2_keys := [KEY_7, KEY_8, KEY_9]
		var keypad_keys := [KEY_KP_7, KEY_KP_8, KEY_KP_9]
		var team_keys := [KEY_4, KEY_5, KEY_6]
		if team_keys.has(key):
			choose_team_upgrade(team_keys.find(key))
		elif p1_keys.has(key):
			choose_upgrade(0, p1_keys.find(key))
		elif p2_keys.has(key):
			choose_upgrade(1, p2_keys.find(key))
		elif keypad_keys.has(key):
			choose_upgrade(1, keypad_keys.find(key))
	get_viewport().set_input_as_handled()

func select_class(id: int, role: int) -> void:
	if not selecting_classes or id not in [0, 1] or role not in [Classes.GUNNER, Classes.RAIDER]:
		return
	selected_classes[id] = role
	class_ready[id] = false
	players[id].configure_class(role)
	hud.refresh()

func toggle_ready(id: int) -> void:
	if not selecting_classes:
		return
	class_ready[id] = not class_ready[id]
	if class_ready[0] and class_ready[1]:
		start_run()
	else:
		hud.refresh()

func start_run() -> void:
	if not selecting_classes:
		return
	for id in range(2):
		players[id].configure_class(selected_classes[id])
	selecting_classes = false
	# Start within weapon range, with room to react before enemies make contact.
	for index in range(Balance.OPENING_ENEMIES):
		var angle := TAU * float(index) / float(Balance.OPENING_ENEMIES)
		var at := Vector2(640, 400) + Vector2(cos(angle) * 285.0, sin(angle) * 220.0)
		_spawn_enemy(at)
	hud.refresh()

func activate_skill(id: int, movement := Vector2.ZERO) -> bool:
	if simulation_speed() == 0.0 or id not in [0, 1]:
		return false
	var player = players[id]
	if not player.is_active():
		return false
	if player.role == Classes.RAIDER and player.return_remaining > 0.0:
		player.position = player.return_origin
		player.invulnerability = maxf(player.invulnerability, float(player.skill_stats.return_invulnerability))
		player.end_raid()
		for enemy in enemies:
			if not enemy.dead and enemy.marks.has(id):
				skill_effects.append({"position": enemy.position, "color": Balance.PLAYER_COLORS[id], "life": 0.35})
				_damage_enemy(enemy, float(player.stats.damage) * float(player.skill_stats.damage), id, true)
		_clear_marks(id)
	elif player.skill_cooldown > 0.0 or player.suppression_remaining > 0.0:
		return false
	elif player.role == Classes.GUNNER:
		player.suppression_remaining = float(player.skill_stats.duration)
		# Store the full cooldown now; Player only counts it down after suppression.
		player.skill_cooldown = float(player.skill_stats.cooldown)
		# Begin the boosted volley immediately, even in the middle of a base cooldown.
		player.shot_cooldown = 0.0
	else:
		var direction: Vector2 = movement.normalized() if movement.length_squared() > 0.0 else player.last_move_direction
		player.last_move_direction = direction
		player.return_origin = player.position
		player.dash_target = (player.position + direction * float(player.skill_stats.distance)).clamp(
			Balance.ARENA.position + Vector2.ONE * 18.0, Balance.ARENA.end - Vector2.ONE * 18.0)
		player.dash_remaining = Classes.DASH_DURATION
		player.return_remaining = float(player.skill_stats.return_window)
		player.invulnerability = maxf(player.invulnerability, float(player.skill_stats.dash_invulnerability))
	player.queue_redraw()
	hud.refresh()
	return true

func _clear_marks(id: int) -> void:
	for enemy in enemies:
		if enemy.marks.erase(id):
			enemy.queue_redraw()

func marked_count(id: int) -> int:
	var count := 0
	for enemy in enemies:
		if not enemy.dead and enemy.marks.has(id):
			count += 1
	return count

func _mark_dash(id: int, start: Vector2, end: Vector2) -> void:
	for enemy in enemies:
		if enemy.dead:
			continue
		var nearest := Geometry2D.get_closest_point_to_segment(enemy.position, start, end)
		if nearest.distance_squared_to(enemy.position) <= pow(enemy.radius + Balance.PLAYER_RADIUS + 6.0, 2):
			enemy.marks[id] = true
			enemy.queue_redraw()

func add_shared_xp(amount: int) -> void:
	if selecting_classes or game_over or amount <= 0:
		return
	shared_xp += amount
	while shared_xp >= Balance.xp_required(team_level):
		shared_xp -= Balance.xp_required(team_level)
		team_level += 1
		team_pending_upgrades += 1
		for player in players:
			player.pending_upgrades += 1
	for player in players:
		player.xp = shared_xp
		player.level = team_level
	_begin_pending_choices()
	if hud != null:
		hud.refresh()

func _begin_pending_choices() -> void:
	if game_over:
		return
	if team_pending_upgrades > 0 and not team_choosing:
		team_choosing = true
		team_offers = Upgrades.roll(rng, players[0].stats, players[1].stats)
	for player in players:
		if player.pending_upgrades > 0 and not player.choosing:
			player.begin_choice()

func has_pending_upgrades() -> bool:
	if team_pending_upgrades > 0:
		return true
	for player in players:
		if player.pending_upgrades > 0:
			return true
	return false

func choose_team_upgrade(index: int) -> bool:
	if selecting_classes or paused or game_over or not team_choosing or index < 0 or index >= team_offers.size():
		return false
	for player in players:
		Upgrades.apply(player, str(team_offers[index].id))
	team_pending_upgrades -= 1
	team_offers.clear()
	team_choosing = false
	_begin_pending_choices()
	hud.refresh()
	return true

func choose_upgrade(id: int, index: int) -> bool:
	if selecting_classes or paused or game_over or id < 0 or id >= players.size():
		return false
	if not players[id].choose(index):
		return false
	# Each player advances their own choices without waiting for the other.
	_begin_pending_choices()
	hud.refresh()
	return true

func restart() -> void:
	get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	if not paused and not game_over:
		var movement := [Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down"),
			Input.get_vector("p2_left", "p2_right", "p2_up", "p2_down")]
		simulate(delta, movement)
	hud_clock += delta
	if hud_clock >= 0.1:
		hud_clock = 0.0
		hud.refresh()
	queue_redraw()

func simulation_speed() -> float:
	if selecting_classes or paused or game_over or has_pending_upgrades():
		return 0.0
	return 1.0

func simulate(delta: float, movement: Array) -> void:
	if simulation_speed() == 0.0:
		return
	elapsed += delta
	milestone = elapsed >= 600.0
	for id in range(2):
		var start: Vector2 = players[id].position
		var dashing: bool = players[id].dash_remaining > 0.0
		players[id].advance(delta, movement[id])
		if dashing and players[id].return_remaining > 0.0:
			_mark_dash(id, start, players[id].position)
		if players[id].return_remaining <= 0.0 or players[id].downed:
			_clear_marks(id)
	_update_revives(delta)
	_update_spawning(delta)
	for enemy in enemies:
		var target = nearest_active_player(enemy.position)
		enemy.advance(delta, target)
		if target != null and enemy.position.distance_squared_to(target.position) < pow(enemy.radius + Balance.PLAYER_RADIUS, 2):
			target.take_damage(enemy.damage)
			# Slight recoil prevents perfect stacking on a player.
			enemy.position += target.position.direction_to(enemy.position) * 720.0 * delta
	if players[0].downed and players[1].downed:
		game_over = true
		hud.refresh()
		return
	for player in players:
		if player.is_active() and player.shot_cooldown <= 0.0:
			_fire(player)
	_update_projectiles(delta)
	_update_gems(delta)
	for event in damage_events:
		event.life -= delta
	damage_events = damage_events.filter(func(event): return event.life > 0.0)
	for effect in skill_effects:
		effect.life -= delta
	skill_effects = skill_effects.filter(func(effect): return effect.life > 0.0)

func nearest_active_player(at: Vector2):
	var target = null
	var best := INF
	for player in players:
		if not player.is_active():
			continue
		var distance: float = at.distance_squared_to(player.position)
		if distance < best:
			best = distance
			target = player
	return target

func _update_revives(delta: float) -> void:
	for player in players:
		if not player.downed:
			continue
		var ally = players[1 - player.player_id]
		if ally.is_active() and ally.position.distance_to(player.position) <= Balance.REVIVE_RADIUS:
			player.revive_progress += delta
			if player.revive_progress >= Balance.REVIVE_SECONDS:
				player.revive()
		else:
			player.revive_progress = maxf(0.0, player.revive_progress - delta * 2.0)

func _update_spawning(delta: float) -> void:
	var tuning := Balance.difficulty(elapsed)
	spawn_credit = minf(3.0, spawn_credit + float(tuning.spawn_rate) * delta)
	while spawn_credit >= 1.0 and enemies.size() < Balance.MAX_ENEMIES:
		spawn_credit -= 1.0
		var spawn := Vector2.ZERO
		for attempt in range(12):
			match rng.randi_range(0, 3):
				0: spawn = Vector2(Balance.ARENA.position.x - 26, rng.randf_range(112, 702))
				1: spawn = Vector2(Balance.ARENA.end.x + 26, rng.randf_range(112, 702))
				2: spawn = Vector2(rng.randf_range(32, 1248), Balance.ARENA.position.y - 26)
				3: spawn = Vector2(rng.randf_range(32, 1248), Balance.ARENA.end.y + 26)
			var safe := true
			for player in players:
				if not player.downed and spawn.distance_to(player.position) < 160.0:
					safe = false
			if safe:
				break
		_spawn_enemy(spawn)
	if elapsed >= next_wave:
		next_wave += Balance.WAVE_INTERVAL
		# Two opposing groups create a squeeze, leaving the other two sides open.
		var horizontal := rng.randf() < 0.5
		var center := rng.randf_range(280.0, 1000.0) if horizontal else rng.randf_range(240.0, 570.0)
		for index in range(Balance.wave_size(elapsed)):
			var offset := (float(index / 2) - float(Balance.wave_size(elapsed)) / 4.0) * 38.0
			var spawn: Vector2
			if horizontal:
				spawn = Vector2(clampf(center + offset, 60.0, 1220.0), 86.0 if index % 2 == 0 else 728.0)
			else:
				spawn = Vector2(6.0 if index % 2 == 0 else 1274.0, clampf(center + offset, 140.0, 675.0))
			_spawn_enemy(spawn)

func _spawn_enemy(at: Vector2) -> void:
	if enemies.size() >= Balance.MAX_ENEMIES:
		return
	spawn_serial += 1
	var kind := Balance.enemy_kind(elapsed, spawn_serial)
	var enemy := Enemy.new()
	enemy.setup(at, Balance.difficulty(elapsed), kind == "elite", kind)
	world.add_child(enemy)
	enemies.append(enemy)

func _fire(player) -> void:
	var target = null
	var best: float = player.attack_range() * player.attack_range()
	for enemy in enemies:
		if enemy.dead:
			continue
		var distance: float = player.position.distance_squared_to(enemy.position)
		if distance < best:
			best = distance
			target = enemy
	if target == null:
		return
	player.shot_cooldown = player.attack_interval()
	var direction: Vector2 = player.position.direction_to(target.position)
	player.facing = direction
	var count: int = int(player.stats.projectiles)
	for index in range(count):
		if projectiles.size() >= Balance.MAX_PROJECTILES:
			break
		# Center first, then alternate right/left so every volley has an aimed shot.
		var angle := ceilf(float(index) / 2.0) * 0.11
		if index % 2 == 0:
			angle = -angle
		_spawn_bullet(player, direction.rotated(angle))
	if player.suppression_remaining > 0.0:
		var extra_target = null
		var extra_best: float = player.attack_range() * player.attack_range()
		for enemy in enemies:
			if enemy.dead or enemy == target:
				continue
			var distance: float = player.position.distance_squared_to(enemy.position)
			if distance < extra_best:
				extra_best = distance
				extra_target = enemy
		if extra_target != null:
			_spawn_bullet(player, player.position.direction_to(extra_target.position), float(player.skill_stats.extra_damage))

func _spawn_bullet(player, direction: Vector2, multiplier := 1.0) -> void:
	if projectiles.size() >= Balance.MAX_PROJECTILES:
		return
	var bullet := Projectile.new()
	bullet.owner_id = player.player_id
	bullet.position = player.position + direction * 22.0
	bullet.velocity = direction * float(player.stats.projectile_speed)
	bullet.critical = player.rng.randf() < float(player.stats.crit)
	bullet.damage = float(player.stats.damage) * multiplier * (float(player.stats.crit_multiplier) if bullet.critical else 1.0)
	bullet.remaining_distance = player.attack_range()
	bullet.hits_left = 1 + int(player.stats.pierce)
	world.add_child(bullet)
	projectiles.append(bullet)

func _damage_enemy(enemy, amount: float, owner_id: int, highlighted := false) -> void:
	if enemy.dead:
		return
	if damage_events.size() < 60:
		damage_events.append({"position": enemy.position, "amount": int(amount), "critical": highlighted, "life": 0.55})
	if enemy.hit(amount):
		players[owner_id].kills += 1
		_drop_gem(enemy.position, enemy.xp_value)

func _update_projectiles(delta: float) -> void:
	for bullet in projectiles:
		var start: Vector2 = bullet.position
		var step: Vector2 = bullet.velocity * delta
		if step.length() > bullet.remaining_distance:
			step = step.normalized() * bullet.remaining_distance
		var end := start + step
		var collisions: Array[Dictionary] = []
		for enemy in enemies:
			if enemy.dead or bullet.hit_ids.has(enemy.get_instance_id()):
				continue
			var nearest := Geometry2D.get_closest_point_to_segment(enemy.position, start, end)
			if nearest.distance_squared_to(enemy.position) <= pow(enemy.radius + 4.5, 2):
				collisions.append({"enemy": enemy, "distance": start.distance_squared_to(nearest)})
		collisions.sort_custom(func(a, b): return a.distance < b.distance)
		for collision in collisions:
			var enemy = collision.enemy
			if enemy.dead:
				continue
			bullet.hit_ids[enemy.get_instance_id()] = true
			bullet.hits_left -= 1
			_damage_enemy(enemy, bullet.damage, bullet.owner_id, bullet.critical)
			if bullet.hits_left <= 0:
				bullet.expired = true
				break
		bullet.position = end
		bullet.remaining_distance -= step.length()
		if bullet.remaining_distance <= 0.0:
			bullet.expired = true
	for index in range(projectiles.size() - 1, -1, -1):
		if projectiles[index].expired:
			projectiles[index].queue_free()
			projectiles.remove_at(index)
	for index in range(enemies.size() - 1, -1, -1):
		if enemies[index].dead:
			enemies[index].queue_free()
			enemies.remove_at(index)

func _drop_gem(at: Vector2, amount: int) -> void:
	# At the object budget, merge value rather than discarding XP.
	if gems.size() >= Balance.MAX_GEMS:
		var nearest = gems[0]
		for gem in gems:
			if at.distance_squared_to(gem.position) < at.distance_squared_to(nearest.position):
				nearest = gem
		nearest.value += amount
		nearest.queue_redraw()
		return
	var gem := Gem.new()
	gem.position = at
	gem.value = amount
	world.add_child(gem)
	gems.append(gem)

func _update_gems(delta: float) -> void:
	for gem in gems:
		var collector = null
		var best := INF
		for player in players:
			if not player.is_active():
				continue
			var distance: float = gem.position.distance_to(player.position)
			if distance < Balance.PICKUP_RADIUS and distance < best:
				best = distance
				collector = player
		if collector == null:
			continue
		gem.position = gem.position.move_toward(collector.position, 370.0 * delta)
		if gem.position.distance_to(collector.position) <= 23.0:
			add_shared_xp(gem.value)
			gem.collected = true
	for index in range(gems.size() - 1, -1, -1):
		if gems[index].collected:
			gems[index].queue_free()
			gems.remove_at(index)

func _draw() -> void:
	draw_rect(Balance.ARENA, Color("101c29"))
	# Low-contrast stonework stays behind combat silhouettes and has no collision.
	for row in range(15):
		for column in range(25):
			var at := Vector2(32 + column * 50, 112 + row * 40)
			var width := minf(48.0, Balance.ARENA.end.x - at.x - 2.0)
			var height := minf(38.0, Balance.ARENA.end.y - at.y - 2.0)
			if width <= 0 or height <= 0:
				continue
			var variation := (row * 7 + column * 13) % 5
			var shade := Color("152330") if variation < 2 else Color("13202d")
			draw_rect(Rect2(at + Vector2.ONE, Vector2(width, height)), shade)
			if variation == 1:
				draw_line(at + Vector2(5, 4), at + Vector2(width - 3, 4), Color("1c2c37"), 1)
			if variation == 3:
				draw_line(at + Vector2(12, 13), at + Vector2(18, 19), Color("0d1824"), 1)
				draw_line(at + Vector2(18, 19), at + Vector2(16, 29), Color("0d1824"), 1)
	draw_rect(Balance.ARENA, Color("3c515c"), false, 3.0)
	draw_arc(Vector2(640, 407), 100, 0, TAU, 64, Color(0.3, 0.5, 0.55, 0.09), 2.0, true)
	draw_arc(Vector2(640, 407), 85, 0, TAU, 64, Color(0.3, 0.5, 0.55, 0.07), 1.0, true)
	for index in range(8):
		var angle := float(index) * TAU / 8.0
		var at := Vector2(640, 407) + Vector2.from_angle(angle) * 93.0
		draw_line(at - Vector2(2, 3), at + Vector2(2, 3), Color(0.3, 0.6, 0.6, 0.12), 2.0)
	for player in players:
		if player.return_remaining > 0.0:
			var color: Color = Balance.PLAYER_COLORS[player.player_id]
			draw_line(player.return_origin, player.position, Color(color, 0.3), 2.0, true)
			draw_arc(player.return_origin, 23.0, 0, TAU, 48, Color(color, 0.8), 2.0, true)
			draw_arc(player.return_origin, 28.0, -PI / 2.0, -PI / 2.0 + TAU * player.return_remaining / float(player.skill_stats.return_window), 48, color, 3.0, true)
		if player.downed:
			draw_arc(player.position, Balance.REVIVE_RADIUS, 0, TAU, 64, Color(0.53, 0.96, 0.7, 0.22), 2.0, true)
	for effect in skill_effects:
		var color: Color = effect.color
		color.a = effect.life / 0.35
		draw_arc(effect.position, 18.0 + (0.35 - effect.life) * 120.0, 0, TAU, 32, color, 4.0, true)
	for event in damage_events:
		var color := Color("fff0a1") if event.critical else Color("dcecff")
		color.a = event.life / 0.55
		draw_string(ThemeDB.fallback_font, event.position + Vector2(-8, -25 - (0.55 - event.life) * 35),
			str(event.amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 18 if event.critical else 14, color)

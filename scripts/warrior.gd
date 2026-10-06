extends Node2D
## Combat ownership stays here; visuals and all cooldowns use simulation time.
const Classes = preload("res://scripts/classes.gd")
const Art = preload("res://scripts/art.gd")
const Visuals = preload("res://scripts/warrior_visuals.gd")
const RECAST_WINDOW := 2.0
const SLASH_DAMAGE := 4.5
const SLASH_SPEED := 1150.0
const SLASH_KNOCKBACK := 100.0
const MAX_SLASHES := 8
const BLADE_LIFE := 2.0
const BLADE_TICK := 0.2
const BLADE_DAMAGE := 0.25
const BLADE_EXECUTE_DAMAGE := 6.0
const BLADE_MAX_HITS := 10
const MAX_BLADE_TRAILS := 8
const MAX_CANNONS := 32
const CANNON_DEPTH := 4
const CANNON_LIMIT := 2
const CANNON_TIME := 0.2
const QUAKE_TARGETS := 6
const QUAKE_LIMIT := 3
const QUAKE_DAMAGE := 3.5
const THORNS_MULTIPLIER := 3.0
var game
var slashes: Array[Dictionary] = []
var blade_trails: Array[Dictionary] = []
var dash_cast_ids: Array[int] = [0, 0]
var dash_cycle_ids: Array[int] = [0, 0]
var cannons: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var reflections: Array[Dictionary] = []
var visuals: Node2D

func _ready() -> void:
	visuals = Visuals.new()
	visuals.system = self
	add_child(visuals)

func dash_damage_base(player) -> float:
	return player.output_damage() * float(player.skill_stats.dash_power)

func effect(kind: String, data: Dictionary, lifetime := 0.5) -> void:
	# One continuous ribbon per dash keeps frame-by-frame sparks from stacking.
	if kind == "dash":
		for index in range(effects.size() - 1, -1, -1):
			var previous: Dictionary = effects[index]
			if previous.kind == kind and previous.owner == data.owner and previous.second == data.second and previous.end.distance_to(data.start) < 1.0:
				previous.end = data.end
				previous.life = lifetime
				visuals.queue_redraw()
				return
	if effects.size() >= 96: effects.pop_front()
	data.kind = kind
	data.life = lifetime
	data.duration = lifetime
	effects.append(data)
	visuals.queue_redraw()

func activate_dash(id: int, movement: Vector2) -> bool:
	var player = game.players[id]
	if not player.is_active() or player.dash_remaining > 0.0:
		return false
	var second: bool = player.dash_recast_remaining > 0.0
	if not second and player.skill_cooldown > 0.0:
		return false
	var direction: Vector2 = movement.normalized() if movement.length_squared() > 0.0 else player.last_move_direction
	if not second:
		dash_cycle_ids[id] += 1
		player.dash_cycle_hit_ids.clear()
		player.dash_refund_total = 0.0
		player.skill_cooldown = float(player.skill_stats.cooldown)
		player.dash_recast_armed = bool(player.skill_stats.dash_recast)
	else:
		player.dash_recast_armed = false
	player.dash_second_cast = second
	dash_cast_ids[id] += 1
	player.dash_recast_remaining = 0.0
	player.last_move_direction = direction
	player.return_origin = player.position
	var margin: float = player.collision_radius() + 2.0
	player.dash_target = (player.position + direction * float(player.skill_stats.distance)).clamp(
		game.Balance.ARENA.position + Vector2.ONE * margin, game.Balance.ARENA.end - Vector2.ONE * margin)
	player.dash_remaining = Classes.DASH_DURATION
	player.dash_hit_ids.clear()
	player.invulnerability = maxf(player.invulnerability, float(player.skill_stats.dash_invulnerability))
	if bool(player.skill_stats.dash_wave) and slashes.size() < MAX_SLASHES:
		var damage_base := dash_damage_base(player)
		slashes.append({"position": player.position, "direction": direction, "owner": id,
			"radius": float(player.skill_stats.hit_radius) * 0.85, "damage": damage_base * SLASH_DAMAGE,
			"cycle": dash_cycle_ids[id], "life": 2.0, "hits": {}})
	if bool(player.skill_stats.dash_recast):
		effect("recast", {"position": player.position, "radius": 65.0, "second": second}, 0.55)
	player.queue_redraw()
	game.hud.refresh()
	return true

func _damage(enemy, amount: float, owner: int, source := "dash", cycle := -1, highlighted := true) -> void:
	var before: float = maxf(0.0, enemy.hp)
	game._damage_enemy(enemy, amount, owner, highlighted, source)
	var actual: float = maxf(0.0, before - maxf(0.0, enemy.hp))
	_refund_dash_hit(owner, dash_cycle_ids[owner] if cycle < 0 else cycle, actual, enemy.position)

func _refund_dash_hit(owner: int, cycle: int, actual: float, at: Vector2) -> void:
	if actual <= 0.0 or cycle != dash_cycle_ids[owner]: return
	var player = game.players[owner]
	if player.role != Classes.RAIDER: return
	var cap: float = float(player.skill_stats.cooldown) * float(player.skill_stats.refund_cap)
	var refund := minf(float(player.skill_stats.refund_seconds), maxf(0.0, cap - player.dash_refund_total))
	refund = minf(refund, player.skill_cooldown)
	if refund <= 0.00001: return
	player.dash_refund_total += refund
	player.skill_cooldown = maxf(0.0, player.skill_cooldown - refund)
	effect("refund", {"position": at, "amount": refund}, 0.4)

func _inside_blade_trail(trail: Dictionary, enemy) -> bool:
	for index in range(1, trail.points.size()):
		var nearest := Geometry2D.get_closest_point_to_segment(enemy.position, trail.points[index - 1], trail.points[index])
		if nearest.distance_squared_to(enemy.position) <= pow(enemy.radius + float(trail.radius), 2): return true
	return false

func _execute_blade_trail(trail: Dictionary) -> void:
	effect("blade_finish", {"points": trail.points, "radius": trail.radius, "owner": trail.owner}, 0.4)
	for enemy in game.enemies:
		if not enemy.dead and _inside_blade_trail(trail, enemy):
			_damage(enemy, float(trail.execute_damage), int(trail.owner), "blade_execute", int(trail.cycle))

func _add_blade_trail(player, start: Vector2, end: Vector2) -> void:
	if start.distance_squared_to(end) <= 0.01: return
	for trail in blade_trails:
		if trail.owner == player.player_id and trail.cast == dash_cast_ids[player.player_id]:
			trail.points.append(end)
			trail.life = BLADE_LIFE
			return
	if blade_trails.size() >= MAX_BLADE_TRAILS: return
	blade_trails.append({"owner": player.player_id, "cast": dash_cast_ids[player.player_id],
		"cycle": dash_cycle_ids[player.player_id],
		"points": PackedVector2Array([start, end]), "radius": float(player.skill_stats.hit_radius) * 0.6,
		"damage": dash_damage_base(player) * BLADE_DAMAGE, "execute_damage": dash_damage_base(player) * BLADE_EXECUTE_DAMAGE,
		"life": BLADE_LIFE, "timers": {}, "hits": {}})

func _advance_blade_trails(delta: float) -> void:
	for trail in blade_trails:
		var active_delta := minf(delta, trail.life)
		for id in trail.timers:
			trail.timers[id] = float(trail.timers[id]) - active_delta
		for enemy in game.enemies:
			var id: int = enemy.get_instance_id()
			if enemy.dead or int(trail.hits.get(id, 0)) >= BLADE_MAX_HITS: continue
			if not _inside_blade_trail(trail, enemy):
				if trail.timers.has(id): trail.timers[id] = maxf(0.0, trail.timers[id])
				continue
			# One ledger per complete dash: intersecting segments never multiply the tick budget.
			if not trail.timers.has(id): trail.timers[id] = -active_delta
			while float(trail.timers[id]) <= 0.00001 and int(trail.hits.get(id, 0)) < BLADE_MAX_HITS and not enemy.dead:
				trail.hits[id] = int(trail.hits.get(id, 0)) + 1
				trail.timers[id] += BLADE_TICK
				_damage(enemy, float(trail.damage), int(trail.owner), "blade_trail", int(trail.cycle), false)
		trail.life = maxf(0.0, float(trail.life) - delta)
		if trail.life <= 0.00001: _execute_blade_trail(trail)
	blade_trails = blade_trails.filter(func(trail): return trail.life > 0.00001)

func queue_reflection(raw: float, source_id: int, player) -> void:
	if raw <= 0.0 or player.role != Classes.RAIDER or player.giant_remaining <= 0.0:
		return
	if bool(player.skill_stats.giant_refund):
		var refund := minf(0.5, 3.0 - player.giant_refund_total)
		refund = minf(refund, player.giant_cooldown)
		if refund > 0.0:
			player.giant_refund_total += refund
			player.giant_cooldown = maxf(0.0, player.giant_cooldown - refund)
			effect("refund", {"position": player.position, "amount": refund}, 0.4)
	if source_id == 0 or not bool(player.skill_stats.giant_thorns): return
	reflections.append({"source": source_id, "owner": player.player_id,
		"damage": raw * THORNS_MULTIPLIER * player.output_damage() / float(player.base_stats.damage),
		"position": player.position})

func flush_reflections() -> void:
	# Resolve after hostile iteration: killing a Boss may clear its attack arrays.
	var pending := reflections
	reflections = []
	for item in pending:
		var attacker = instance_from_id(int(item.source))
		if not is_instance_valid(attacker) or not attacker is Node2D or attacker.dead:
			continue
		effect("thorns", {"position": item.position, "end": attacker.position, "radius": 65.0}, 0.35)
		game._damage_enemy(attacker, float(item.damage), int(item.owner), true, "thorns")

func grant_rescue_blessing(player, ally) -> void:
	if not bool(player.skill_stats.rescue_blessing): return
	player.guard_shield = player.guard_shield_max()
	if not ally.is_active(): return
	ally.blessing_remaining = 10.0
	ally.blessing_shield_max = float(player.stats.max_hp) * 0.5
	ally.blessing_shield = maxf(ally.blessing_shield, ally.blessing_shield_max)
	effect("blessing", {"position": ally.position, "radius": 85.0}, 0.9)

func grant_rescue_counterattack(player, ally) -> void:
	if not bool(player.skill_stats.rescue_counterattack) or not ally.is_active(): return
	for member in [player, ally]:
		member.counterattack_remaining = 5.0
		member.queue_redraw()

func hit_dash(id: int, start: Vector2, end: Vector2) -> void:
	var player = game.players[id]
	var radius := float(player.skill_stats.hit_radius)
	effect("dash", {"start": start, "end": end, "radius": radius,
		"owner": id, "second": player.dash_second_cast}, 0.2)
	if bool(player.skill_stats.dash_blades): _add_blade_trail(player, start, end)
	for enemy in game.enemies:
		var enemy_id: int = enemy.get_instance_id()
		if enemy.dead or player.dash_hit_ids.has(enemy_id): continue
		var nearest := Geometry2D.get_closest_point_to_segment(enemy.position, start, end)
		if nearest.distance_squared_to(enemy.position) > pow(enemy.radius + radius, 2): continue
		player.dash_hit_ids[enemy_id] = true
		_damage(enemy, dash_damage_base(player) * float(player.skill_stats.damage), id)

func begin_giant(player) -> void:
	player.giant_remaining = float(player.skill_stats.giant_duration)
	player.giant_cooldown = Classes.GIANT_COOLDOWN
	player.giant_contact_cooldowns.clear()
	player.giant_unique_hits.clear()
	player.giant_chain_counts.clear()
	player.giant_quakes = 0
	player.giant_cast_serial += 1
	player.giant_refund_total = 0.0
	effect("giant", {"position": player.position, "radius": 60.0 * player.body_scale()}, 0.6)

func _stagger(enemy, seconds: float) -> void:
	if not enemy.dead and enemy.kind != "boss":
		enemy.stagger_remaining = maxf(enemy.stagger_remaining, seconds * (1.0 - enemy.tenacity))
		enemy.queue_redraw()

func _launch_cannon(enemy, player, direction: Vector2, distance: float, damage: float, depth: int, visited: Dictionary) -> void:
	var enemy_id: int = enemy.get_instance_id()
	var uses := int(player.giant_chain_counts.get(enemy_id, 0))
	var travel := distance * (1.0 - clampf(enemy.tenacity, 0.0, 1.0))
	if depth >= CANNON_DEPTH or uses >= CANNON_LIMIT or travel <= 0.0 or cannons.size() >= MAX_CANNONS: return
	player.giant_chain_counts[enemy_id] = uses + 1
	var path := visited.duplicate()
	path[enemy_id] = true
	var velocity := direction.normalized() * travel / CANNON_TIME
	if not enemy.dead:
		enemy.knockback_remaining = CANNON_TIME
		enemy.knockback_velocity = velocity
	cannons.append({"enemy": enemy, "source": enemy_id, "position": enemy.position, "velocity": velocity,
		"radius": enemy.radius, "owner": player.player_id, "cast": player.giant_cast_serial,
		"life": CANNON_TIME, "damage": damage * 0.7, "distance": distance * 0.65,
		"depth": depth, "visited": path, "texture": Art.sprite("elite" if enemy.elite else "enemy")})
	effect("cannon", {"position": enemy.position, "radius": enemy.radius + 24.0}, 0.3)

func _quake(player) -> void:
	var radius: float = 130.0 + 35.0 * player.body_scale()
	effect("quake", {"position": player.position, "radius": radius}, 0.7)
	for enemy in game.enemies:
		if enemy.dead or enemy.position.distance_to(player.position) > radius + enemy.radius: continue
		game._damage_enemy(enemy, player.output_damage() * QUAKE_DAMAGE * float(player.skill_stats.giant_power), player.player_id, true, "quake")
		_stagger(enemy, 0.35)

func giant_contacts(starts: Array[Vector2]) -> void:
	for id in range(game.players.size()):
		var player = game.players[id]
		if player.role != Classes.RAIDER or not player.is_active() or player.giant_remaining <= 0.0: continue
		for enemy in game.enemies:
			var enemy_id: int = enemy.get_instance_id()
			if enemy.dead or player.giant_contact_cooldowns.has(enemy_id): continue
			var nearest := Geometry2D.get_closest_point_to_segment(enemy.position, starts[id], player.position)
			if nearest.distance_squared_to(enemy.position) > pow(enemy.radius + player.collision_radius(), 2): continue
			var direction: Vector2 = nearest.direction_to(enemy.position)
			if direction == Vector2.ZERO: direction = player.last_move_direction
			var power := float(player.skill_stats.giant_power)
			var damage: float = player.output_damage() * Classes.GIANT_DAMAGE * power
			var distance: float = Classes.GIANT_KNOCKBACK * power
			game._damage_enemy(enemy, damage, id, true, "giant")
			enemy.contact_knockback(direction, distance)
			player.giant_contact_cooldowns[enemy_id] = 0.5
			effect("impact", {"position": enemy.position, "radius": enemy.radius + 30.0}, 0.25)
			if bool(player.skill_stats.giant_cannon): _launch_cannon(enemy, player, direction, distance, damage, 0, {})
			if not player.giant_unique_hits.has(enemy_id):
				player.giant_unique_hits[enemy_id] = true
				if bool(player.skill_stats.giant_quake) and player.giant_quakes < QUAKE_LIMIT and player.giant_unique_hits.size() / QUAKE_TARGETS > player.giant_quakes:
					player.giant_quakes += 1
					_quake(player)

func advance(delta: float) -> void:
	for item in effects: item.life -= delta
	effects = effects.filter(func(item): return item.life > 0.0)
	_advance_blade_trails(delta)
	for slash in slashes:
		var start: Vector2 = slash.position
		slash.position += slash.direction * SLASH_SPEED * minf(delta, float(slash.life))
		slash.life -= delta
		for enemy in game.enemies:
			var id: int = enemy.get_instance_id()
			if enemy.dead or slash.hits.has(id): continue
			var nearest := Geometry2D.get_closest_point_to_segment(enemy.position, start, slash.position)
			if nearest.distance_squared_to(enemy.position) > pow(enemy.radius + float(slash.radius), 2): continue
			slash.hits[id] = true
			_damage(enemy, float(slash.damage), int(slash.owner), "slash", int(slash.cycle))
			enemy.contact_knockback(slash.direction, SLASH_KNOCKBACK)
			effect("impact", {"position": enemy.position, "radius": 45.0}, 0.25)
		slash.life = 0.0 if not game.Balance.ARENA.grow(220.0).has_point(slash.position) else slash.life
	slashes = slashes.filter(func(item): return item.life > 0.0)
	visuals.queue_redraw()

func after_enemy_move(delta: float) -> void:
	var active := cannons
	cannons = []
	for shot in active:
		var player = game.players[int(shot.owner)]
		if not player.is_active() or player.giant_remaining <= 0.0 or player.giant_cast_serial != int(shot.cast): continue
		var start: Vector2 = shot.position
		var source = shot.enemy
		var live: bool = is_instance_valid(source) and not source.dead
		var end: Vector2 = source.position if live else start + shot.velocity * minf(delta, float(shot.life))
		shot.life -= delta
		shot.position = end
		var victim = null
		var best := INF
		for enemy in game.enemies:
			var id: int = enemy.get_instance_id()
			if enemy.dead or shot.visited.has(id) or int(player.giant_chain_counts.get(id, 0)) >= CANNON_LIMIT: continue
			var nearest := Geometry2D.get_closest_point_to_segment(enemy.position, start, end)
			if nearest.distance_squared_to(enemy.position) > pow(float(shot.radius) + enemy.radius, 2): continue
			var distance: float = start.distance_squared_to(nearest)
			if distance < best:
				best = distance
				victim = enemy
		if victim != null:
			game._damage_enemy(victim, float(shot.damage), int(shot.owner), true, "cannon")
			_stagger(victim, 0.14)
			if live:
				source.knockback_remaining = 0.0
				source.knockback_velocity = Vector2.ZERO
				_stagger(source, 0.14)
			var direction: Vector2 = shot.velocity.normalized()
			victim.contact_knockback(direction, float(shot.distance))
			_launch_cannon(victim, player, direction, float(shot.distance), float(shot.damage), int(shot.depth) + 1, shot.visited)
			effect("cannon", {"position": victim.position, "radius": victim.radius + 35.0}, 0.35)
		elif float(shot.life) > 0.0 and cannons.size() < MAX_CANNONS:
			cannons.append(shot)
	visuals.queue_redraw()

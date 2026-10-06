extends Node2D
## One simulation owns salvos, terrain, attachments, wards and all effect lifetimes.
const Classes = preload("res://scripts/classes.gd")
const Balance = preload("res://scripts/balance.gd")
const Visuals = preload("res://scripts/mage_visuals.gd")
const WardVisual = preload("res://scripts/frost_ward_visual.gd")
const Elements = preload("res://scripts/elements.gd")
const Tower = preload("res://scripts/lightning_tower.gd")
const LightningEffects = preload("res://scripts/lightning_effects.gd")
const FIREBALL_COOLDOWN := 15.0
const FIREBALL_SPEED := 155.0
const FIREBALL_RADIUS := 132.0 * 0.8
const FIREBALL_LIFE := 4.5
const FIREBALL_TICK := 0.20
const FIREBALL_DAMAGE := 0.45
const FIREBALL_PUSH := 0.0
const UPGRADED_PUSH := 42.0
const SALVO_DELAY := 0.3
const GROWTH_ENERGY := 3.0
const GROWTH_STAGES := 4
const FROST_COOLDOWN := 15.0
const FROST_DURATION := 5.0
const FROST_RADIUS := 155.0
const WARD_RADIUS := Balance.PLAYER_RADIUS * 2.0 * 1.5 # 1.5 normal collision-body widths: 48 px.
const WARD_DURATION := 10.0
const MAX_TOWERS := 8
const FROST_TICK := 0.5
const FROST_DAMAGE := 0.35
const FROST_MOVEMENT := 0.60
const FROST_ATTACK := 0.65
const CONE_INTERVAL := 0.7
const CONE_RADIUS := 36.0
const CONE_DAMAGE := 1.8
const GROWTH_EXPLOSION_DAMAGE := 2.0
const GROUND_LIFE := 8.0
const GROUND_INTERVAL := 0.3
const POSSESSION_RANGE := FROST_RADIUS * 2.0
const POSSESSION_DURATION := 5.0
const POSSESSION_COOLDOWN := 25.0
const MAX_FIREBALLS := 8
const MAX_GROUNDS := 160
const MAX_CONES := 24
var game
var fireballs: Array[Dictionary] = []
var salvos: Array[Dictionary] = []
var grounds: Array[Dictionary] = []
var cones: Array[Dictionary] = []
var explosions: Array[Dictionary] = []
var visuals: Node2D
var ward_visuals: Node2D
var ward_impacts: Array[Dictionary] = []
var elements = Elements.new()
var towers: Array[Node2D] = []
var lightning_effects: Node2D

func _ready() -> void:
	elements.game = game
	visuals = Visuals.new()
	visuals.system = self
	add_child(visuals)
	ward_visuals = WardVisual.new()
	ward_visuals.system = self
	add_child(ward_visuals)
	lightning_effects = LightningEffects.new()
	lightning_effects.game = game
	add_child(lightning_effects)

func highest_enemy(player):
	var target = null
	var distance := INF
	for enemy in game.enemies:
		if enemy.dead:
			continue
		var next: float = player.position.distance_squared_to(enemy.position)
		if target == null or enemy.level > target.level or (enemy.level == target.level and next < distance):
			target = enemy
			distance = next
	return target

func frost_radius(player) -> float:
	return FROST_RADIUS * float(player.skill_stats.frost_width) * player.skill_range_multiplier()

func ward_radius() -> float:
	return WARD_RADIUS

func activate_tower(id: int) -> bool:
	if game.simulation_speed() == 0.0 or id < 0 or id >= game.players.size():
		return false
	var player = game.players[id]
	if player.role != Classes.MAGE or not player.is_active() or player.tower_charges <= 0 or player.tower_release_cooldown > 0.00001 or towers.size() >= MAX_TOWERS:
		return false
	var tower := Tower.new()
	tower.game = game
	tower.effects = lightning_effects
	tower.owner_id = id
	tower.position = player.position
	tower.damage = player.output_damage() * Classes.TOWER_BASE_DAMAGE * float(player.skill_stats.tower_damage)
	tower.attack_interval = Tower.ATTACK_INTERVAL / float(player.skill_stats.tower_rate)
	tower.total_duration = float(player.skill_stats.tower_duration)
	tower.life = tower.total_duration
	tower.chain_enabled = bool(player.skill_stats.tower_chain)
	tower.tide_enabled = bool(player.skill_stats.tower_tide)
	tower.judgment_enabled = bool(player.skill_stats.tower_judgment)
	game.world.add_child(tower)
	towers.append(tower)
	if player.tower_charges == Classes.TOWER_MAX_CHARGES:
		player.tower_recharge = Classes.TOWER_RECHARGE
	player.tower_charges -= 1
	player.tower_release_cooldown = Classes.TOWER_RELEASE_COOLDOWN
	game.hud.refresh()
	return true

func tower_remaining(id: int) -> float:
	var longest := 0.0
	for tower in towers:
		if tower.owner_id == id and not tower.expired:
			longest = maxf(longest, tower.life)
	return longest

func _spawn_fireball(player) -> bool:
	if not player.is_active() or fireballs.size() >= MAX_FIREBALLS:
		return false
	var target = highest_enemy(player)
	if target == null:
		return false
	var origin: Vector2 = player.position + player.visual_offset()
	var direction: Vector2 = origin.direction_to(target.position)
	if direction == Vector2.ZERO:
		direction = player.facing
	var radius: float = FIREBALL_RADIUS * float(player.skill_stats.fire_width) * player.skill_range_multiplier()
	# Snapshot Q's strengthened base once: body, ground, burn and growth explosion inherit it.
	var fire_base: float = player.output_damage() * float(player.skill_stats.fire_power)
	fireballs.append({"position": origin + direction * 30.0, "direction": direction, "owner": player.player_id,
		"damage": fire_base * FIREBALL_DAMAGE, "base_damage": fire_base,
		"radius": radius, "base_radius": radius, "life": FIREBALL_LIFE * player.skill_range_multiplier(),
		"timers": {}, "pushed": {}, "hit_ids": {}, "energy": 0.0, "stage": 0,
		"push": UPGRADED_PUSH if bool(player.skill_stats.fire_push) else FIREBALL_PUSH,
		"growth": bool(player.skill_stats.fire_growth), "ground": bool(player.skill_stats.fire_ground),
		"trail_tick": 0.0, "trail_start": origin + direction * 30.0})
	return true

func activate(id: int, slot: int) -> bool:
	if game.simulation_speed() == 0.0 or id < 0 or id >= game.players.size():
		return false
	var player = game.players[id]
	if player.role != Classes.MAGE or not player.is_active():
		return false
	if slot == 1:
		if player.fireball_cooldown > 0.0 or not _spawn_fireball(player):
			return false
		var extra := int(player.skill_stats.fire_count) - 1
		if extra > 0:
			salvos.append({"owner": id, "left": extra, "timer": SALVO_DELAY})
		player.fireball_cooldown = FIREBALL_COOLDOWN
	elif slot == 2:
		if player.frost_cooldown > 0.0:
			return false
		player.frost_remaining = FROST_DURATION
		player.frost_tick = 0.0
		player.frost_cone_tick = 0.0
		player.frost_path_tick = 0.0
		player.frost_path_position = player.position
		player.frost_shield_max = float(player.stats.max_hp) if bool(player.skill_stats.frost_ward) else 0.0
		player.frost_shield_hp = player.frost_shield_max
		player.frost_ward_remaining = WARD_DURATION if bool(player.skill_stats.frost_ward) else 0.0
		player.frost_cooldown = FROST_COOLDOWN
		refresh_wards()
	elif slot == 3:
		var ally = game.players[1 - id]
		var switching_from_rescue: bool = player.is_carried() and player.carried_by == ally and ally.carrying == player
		if player.possession_cooldown > 0.0 or player.is_possessed() or player.possessed_by != null or (player.is_carried() and not switching_from_rescue) or player.carrying != null:
			return false
		if not ally.is_active() or ally.is_possessed() or ally.is_carried() or (ally.carrying != null and not switching_from_rescue) or ally.possessed_by != null:
			return false
		if player.position.distance_to(ally.position) > POSSESSION_RANGE:
			return false
		# Transfer the existing rescue link only after the cast has passed all checks.
		if switching_from_rescue:
			player.end_carry()
		player.possession_host = ally
		ally.possessed_by = player
		player.possession_remaining = POSSESSION_DURATION
		player.possession_cooldown = POSSESSION_COOLDOWN
		player.position = ally.position
		player.z_index = 5
	else:
		return false
	player.queue_redraw()
	visuals.refresh()
	ward_visuals.refresh()
	game.hud.refresh()
	return true

func update_links(delta: float) -> void:
	for player in game.players:
		if player.possession_host == null:
			continue
		if not player.is_active() or not is_instance_valid(player.possession_host) or not player.possession_host.is_active():
			player.end_possession()
			continue
		player.position = player.possession_host.position
		player.moving = player.possession_host.moving
		player.possession_remaining = maxf(0.0, player.possession_remaining - delta)
		if player.possession_remaining <= 0.0:
			player.end_possession()
		player.queue_redraw()

func refresh_wards() -> void:
	for ally in game.players:
		ally.cold_ward_protection = false
	for player in game.players:
		if not player.is_active() or player.frost_ward_remaining <= 0.0 or player.frost_shield_hp <= 0.0:
			continue
		var radius := ward_radius()
		for ally in game.players:
			if ally.is_active() and ally.position.distance_squared_to(player.position) <= radius * radius:
				ally.cold_ward_protection = true

func intercept_bullet(start: Vector2, end: Vector2, bullet) -> bool:
	var shield = null
	var best := INF
	var step := end - start
	var length_squared := step.length_squared()
	for player in game.players:
		if not player.is_active() or player.frost_ward_remaining <= 0.0 or player.frost_shield_hp <= 0.0:
			continue
		var offset: Vector2 = start - player.position
		var radius: float = ward_radius() + bullet.radius
		var t := INF
		var c := offset.length_squared() - radius * radius
		if c <= 0.0:
			t = 0.0
		elif length_squared > 0.0:
			var b := offset.dot(step)
			var discriminant := b * b - length_squared * c
			if discriminant >= 0.0:
				t = (-b - sqrt(discriminant)) / length_squared
		if t >= 0.0 and t <= 1.0 and t < best:
			shield = player
			best = t
	if shield == null:
		return false
	shield.frost_shield_hp = maxf(0.0, shield.frost_shield_hp - bullet.damage)
	if ward_impacts.size() >= 24:
		ward_impacts.pop_front()
	ward_impacts.append({"owner": shield.player_id, "center": shield.position,
		"radius": ward_radius(),
		"angle": (start + step * best - shield.position).angle(), "life": 0.45,
		"broken": shield.frost_shield_hp <= 0.0})
	if shield.frost_shield_hp <= 0.0:
		shield.frost_ward_remaining = 0.0
		refresh_wards()
	visuals.refresh()
	ward_visuals.refresh()
	return true

func _ground(element: String, start: Vector2, end: Vector2, radius: float, player, dps := 0.0) -> void:
	if grounds.size() >= MAX_GROUNDS:
		grounds.pop_front()
	grounds.append({"element": element, "start": start, "end": end, "radius": radius,
		"life": GROUND_LIFE, "owner": player.player_id, "dps": dps})

func _advance_salvos(delta: float) -> void:
	for salvo in salvos:
		var player = game.players[int(salvo.owner)]
		if not player.is_active():
			salvo.left = 0
			continue
		salvo.timer -= delta
		while int(salvo.left) > 0 and float(salvo.timer) <= 0.00001:
			_spawn_fireball(player)
			salvo.left -= 1
			salvo.timer += SALVO_DELAY
	salvos = salvos.filter(func(salvo): return salvo.left > 0)

func _advance_frost(delta: float) -> void:
	for player in game.players:
		if player.role != Classes.MAGE or not player.is_active() or player.frost_remaining <= 0.0:
			continue
		var active_delta: float = minf(delta, player.frost_remaining)
		var radius := frost_radius(player)
		player.frost_tick -= active_delta
		var pulses := 0
		while player.frost_tick < 0.0:
			pulses += 1
			player.frost_tick += FROST_TICK / float(player.skill_stats.frost_rate)
		var targets: Array = []
		for enemy in game.enemies:
			if enemy.dead or player.position.distance_squared_to(enemy.position) > pow(radius + enemy.radius, 2):
				continue
			targets.append(enemy)
			elements.attach(enemy, "ice")
			enemy.movement_scale = minf(enemy.movement_scale, FROST_MOVEMENT)
			enemy.attack_scale = minf(enemy.attack_scale, FROST_ATTACK)
			if pulses > 0:
				elements.damage(enemy, player.output_damage() * FROST_DAMAGE * pulses, player.player_id, "ice", true, "frost")
		if bool(player.skill_stats.frost_cones):
			player.frost_cone_tick -= active_delta
			while player.frost_cone_tick <= 0.0:
				if not targets.is_empty() and cones.size() < MAX_CONES:
					var target = targets[player.rng.randi_range(0, targets.size() - 1)]
					cones.append({"position": target.position, "radius": CONE_RADIUS * player.skill_range_multiplier(),
						"owner": player.player_id, "damage": player.output_damage() * CONE_DAMAGE, "wait": 0.35, "life": 0.6, "hit": false})
				player.frost_cone_tick += CONE_INTERVAL
		if bool(player.skill_stats.frost_path):
			player.frost_path_tick -= active_delta
			if player.frost_path_tick <= 0.0 and player.position.distance_to(player.frost_path_position) >= 18.0:
				_ground("ice", player.frost_path_position, player.position, radius, player)
				player.frost_path_position = player.position
				player.frost_path_tick = GROUND_INTERVAL
		player.frost_remaining = maxf(0.0, player.frost_remaining - delta)

func _explode(ball: Dictionary) -> void:
	var radius: float = float(ball.radius) * 1.25
	var amount: float = float(ball.base_damage) * GROWTH_EXPLOSION_DAMAGE * (1.0 + int(ball.stage) * 0.3)
	if explosions.size() >= 16:
		explosions.pop_front()
	explosions.append({"position": ball.position, "radius": radius, "life": 0.4})
	for enemy in game.enemies:
		if not enemy.dead and enemy.position.distance_squared_to(ball.position) <= pow(radius + enemy.radius, 2):
			elements.damage(enemy, amount, int(ball.owner), "fire", true, "fire_explosion")

func _advance_fireballs(delta: float) -> void:
	for ball in fireballs:
		var start: Vector2 = ball.position
		ball.position += ball.direction * FIREBALL_SPEED * minf(delta, float(ball.life))
		ball.life -= delta
		for enemy_id in ball.timers.keys():
			ball.timers[enemy_id] = maxf(0.0, float(ball.timers[enemy_id]) - delta)
		for enemy in game.enemies:
			if enemy.dead:
				continue
			var enemy_id: int = enemy.get_instance_id()
			if float(ball.timers.get(enemy_id, 0.0)) > 0.0:
				continue
			var nearest := Geometry2D.get_closest_point_to_segment(enemy.position, start, ball.position)
			if nearest.distance_squared_to(enemy.position) > pow(float(ball.radius) + enemy.radius, 2):
				continue
			var push: float = float(ball.push) * (1.0 - clampf(enemy.tenacity, 0.0, 1.0))
			var before: Vector2 = enemy.position
			enemy.position += ball.direction * push
			var cumulative: float = float(ball.pushed.get(enemy_id, 0.0)) + before.distance_to(enemy.position)
			ball.pushed[enemy_id] = cumulative
			ball.timers[enemy_id] = FIREBALL_TICK
			var stage: int = ball.stage # This hit uses the previous stage; energy strengthens subsequent hits.
			elements.damage(enemy, float(ball.damage) * (1.0 + stage * 0.2) * (1.0 + minf(2.0, cumulative / 120.0)), int(ball.owner), "fire", true, "fireball")
			if bool(ball.growth):
				if not ball.hit_ids.has(enemy_id):
					ball.hit_ids[enemy_id] = true
					ball.energy += 1.0
				elif enemy.elite or enemy.kind == "boss":
					ball.energy += 0.15
				ball.stage = mini(GROWTH_STAGES, int(float(ball.energy) / GROWTH_ENERGY))
				ball.radius = float(ball.base_radius) * (1.0 + int(ball.stage) * 0.18)
			if push > 0.0:
				enemy.knockback_remaining = maxf(enemy.knockback_remaining, 0.08)
				enemy.knockback_velocity = Vector2.ZERO
		if bool(ball.ground):
			ball.trail_tick -= delta
			if float(ball.trail_tick) <= 0.0 or float(ball.life) <= 0.0:
				_ground("fire", ball.trail_start, ball.position, float(ball.radius) * 0.6,
					game.players[int(ball.owner)], float(ball.base_damage) * 0.18)
				ball.trail_start = ball.position
				ball.trail_tick = GROUND_INTERVAL
		if float(ball.life) <= 0.0 and bool(ball.growth):
			_explode(ball)
	fireballs = fireballs.filter(func(ball): return ball.life > 0.0)

func _advance_grounds(delta: float) -> void:
	for ground in grounds:
		ground.life -= delta
		for enemy in game.enemies:
			if enemy.dead:
				continue
			var nearest := Geometry2D.get_closest_point_to_segment(enemy.position, ground.start, ground.end)
			if enemy.position.distance_squared_to(nearest) > pow(float(ground.radius) + enemy.radius, 2):
				continue
			if ground.element == "fire":
				elements.fire_ground(enemy, float(ground.dps), int(ground.owner))
			else:
				elements.attach(enemy, "ice")
	grounds = grounds.filter(func(ground): return ground.life > 0.0)

func _advance_cones(delta: float) -> void:
	for cone in cones:
		cone.wait -= delta
		cone.life -= delta
		if float(cone.wait) <= 0.0 and not bool(cone.hit):
			cone.hit = true
			for enemy in game.enemies:
				if not enemy.dead and enemy.position.distance_squared_to(cone.position) <= pow(float(cone.radius) + enemy.radius, 2):
					elements.damage(enemy, float(cone.damage), int(cone.owner), "ice", true, "frost_cones")
	cones = cones.filter(func(cone): return cone.life > 0.0)

func advance(delta: float) -> void:
	for player in game.players:
		player.frost_ward_remaining = maxf(0.0, player.frost_ward_remaining - delta)
		if player.frost_ward_remaining <= 0.0 or not player.is_active():
			player.frost_shield_hp = 0.0
	lightning_effects.advance(delta)
	for tower in towers:
		tower.advance(delta)
	for index in range(towers.size() - 1, -1, -1):
		if towers[index].expired:
			towers[index].queue_free()
			towers.remove_at(index)
	for hit in ward_impacts:
		hit.life -= delta
	ward_impacts = ward_impacts.filter(func(hit): return hit.life > 0.0)
	for enemy in game.enemies:
		enemy.movement_scale = 1.0
		enemy.attack_scale = 1.0
	for effect in explosions:
		effect.life -= delta
	explosions = explosions.filter(func(effect): return effect.life > 0.0)
	_advance_salvos(delta)
	_advance_frost(delta)
	_advance_fireballs(delta)
	_advance_grounds(delta)
	_advance_cones(delta)
	elements.advance(delta)
	refresh_wards()
	visuals.refresh()
	ward_visuals.refresh()
	lightning_effects.refresh()

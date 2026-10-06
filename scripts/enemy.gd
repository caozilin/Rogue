extends Node2D

const Art = preload("res://scripts/art.gd")
const Balance = preload("res://scripts/balance.gd")
const Barrage = preload("res://scripts/barrage.gd")
const Motion = preload("res://scripts/unit_motion.gd")

signal ranged_attack(source, pattern: String, direction: Vector2, landing: Vector2)

var hp := 20.0
var max_hp := 20.0
var speed := 64.0
var damage := 9.0
var xp_value := 6
var radius := 13.0
var elite := false
var dead := false
var knockback_remaining := 0.0
var stagger_remaining := 0.0
var knockback_velocity := Vector2.ZERO
var tenacity := 0.0 # 0: full contact knockback; 1: immune.
var priority_target_id := -1
var hit_flash := 0.0
var gait := 0.0
var marks: Dictionary = {} # Player IDs, independent even when both choose Raider.
var kind := "normal"
var level := 1 # Spawn minute + archetype rank; used by mage auto-aim.
var movement_scale := 1.0
var attack_scale := 1.0
var element_state: Dictionary = {}
var contact_cooldown := 0.0
var charge_cooldown := 1.5
var charge_windup := 0.0
var charge_remaining := 0.0
var charge_direction := Vector2.ZERO
var ranged_config: Dictionary = {}
var attack_cooldown := 1.0
var attack_windup := 0.0
var attack_direction := Vector2.RIGHT
var attack_landing := Vector2.ZERO
var burst_left := 0
var burst_index := 0
var burst_timer := 0.0
var pattern_seconds := 0.0
var motion := Motion.new()

func _ready() -> void:
	motion.attach(self)

func setup(spawn: Vector2, tuning: Dictionary, is_elite: bool, variant := "normal") -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	position = spawn
	gait = spawn.x * 0.01
	motion.reset(gait)
	elite = is_elite
	kind = "elite" if elite else variant
	level = 1 + int(float(tuning.get("seconds", 0.0)) / 60.0)
	level += 10 if kind == "boss" else (4 if elite else (2 if kind == "brute" or Barrage.is_ranged(kind) else (1 if kind == "charger" else 0)))
	tenacity = 1.0 if variant == "boss" else (0.85 if elite else (0.4 if variant == "brute" else (0.2 if variant == "charger" else 0.0)))
	hp = float(tuning.health) * (3.0 if elite else 1.0)
	speed = float(tuning.speed) * (0.8 if elite else 1.0)
	damage = float(tuning.get("elite_damage", float(tuning.damage) * 1.65)) if elite else float(tuning.damage)
	xp_value = int(tuning.xp) * (4 if elite else 1)
	radius = 22.0 if elite else 13.0
	match kind:
		"runner":
			hp *= 0.65
			speed *= 1.45
			radius = 10.0
		"brute":
			hp *= 2.6
			speed *= 0.72
			damage *= 1.4
			xp_value *= 2
			radius = 20.0
		"charger":
			hp *= 1.35
			speed *= 1.05
			xp_value *= 2
			radius = 14.0
	if Barrage.is_ranged(kind):
		ranged_config = Barrage.TYPES[kind]
		hp *= float(ranged_config.health)
		speed *= float(ranged_config.speed)
		radius = float(ranged_config.radius)
		xp_value *= 2
		# Stagger arrivals so a group never all fires on its first frame.
		attack_cooldown = 0.8 + fposmod(spawn.x * 0.013 + spawn.y * 0.017, 1.5)
		pattern_seconds = float(tuning.get("seconds", 0.0))
	max_hp = hp

func advance(delta: float, target: Node2D) -> void:
	if dead:
		return
	contact_cooldown = maxf(0.0, contact_cooldown - delta * attack_scale)
	stagger_remaining = maxf(0.0, stagger_remaining - delta)
	if knockback_remaining > 0.0:
		position += knockback_velocity * minf(delta, knockback_remaining)
		knockback_remaining = maxf(0.0, knockback_remaining - delta)
		hit_flash = maxf(0.0, hit_flash - delta)
		queue_redraw()
		return
	if stagger_remaining > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		queue_redraw()
		return
	if not ranged_config.is_empty():
		_advance_ranged(delta, target)
		hit_flash = maxf(0.0, hit_flash - delta)
		queue_redraw()
		return
	if kind == "charger" and charge_remaining > 0.0:
		position += charge_direction * minf(500.0, speed * 2.8) * minf(delta * movement_scale, charge_remaining)
		charge_remaining = maxf(0.0, charge_remaining - delta * movement_scale)
		gait += delta * 16.0
	elif kind == "charger" and charge_windup > 0.0:
		# Direction is fixed throughout the visible windup, so sidestepping works.
		charge_windup = maxf(0.0, charge_windup - delta * attack_scale)
		if charge_windup == 0.0:
			charge_remaining = 0.55
			charge_cooldown = 3.5
	elif target != null:
		position += position.direction_to(target.position) * speed * delta * movement_scale
		gait += delta * 8.0
		if kind == "charger":
			charge_cooldown = maxf(0.0, charge_cooldown - delta * attack_scale)
			if charge_cooldown == 0.0 and position.distance_to(target.position) < 420.0:
				charge_direction = position.direction_to(target.position)
				charge_windup = 0.7
	hit_flash = maxf(0.0, hit_flash - delta)
	queue_redraw()

func _advance_ranged(delta: float, target: Node2D) -> void:
	var movement_delta := delta * movement_scale
	delta *= attack_scale
	if target == null:
		attack_windup = 0.0
		burst_left = 0
		return
	if burst_left > 0:
		_advance_burst(delta)
		return
	if attack_windup > 0.0:
		attack_windup = maxf(0.0, attack_windup - delta)
		if attack_windup == 0.0:
			attack_cooldown = float(ranged_config.cooldown)
			if kind == "sweep":
				burst_left = 9
				burst_index = 0
				burst_timer = 0.0
				_advance_burst(0.0)
			else:
				ranged_attack.emit(self, kind, attack_direction, attack_landing)
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var distance := position.distance_to(target.position)
	var direction := position.direction_to(target.position)
	var preferred := float(ranged_config.distance)
	if distance > preferred + 35.0:
		position += direction * speed * movement_delta
	elif distance < preferred - 45.0:
		position -= direction * speed * 0.7 * movement_delta
	elif kind in ["fan", "sweep"]:
		position += direction.orthogonal() * speed * 0.25 * movement_delta
	gait += delta * 5.0
	if attack_cooldown == 0.0 and distance <= float(ranged_config.range) and Balance.ARENA.grow(-22.0).has_point(position):
		attack_direction = position.direction_to(target.position)
		attack_landing = target.position
		attack_windup = float(ranged_config.windup)

func _advance_burst(delta: float) -> void:
	burst_timer -= delta
	while burst_left > 0 and burst_timer <= 0.0:
		var angle := -0.85 + 1.7 * float(burst_index) / 8.0
		ranged_attack.emit(self, kind, attack_direction.rotated(angle), attack_landing)
		burst_index += 1
		burst_left -= 1
		burst_timer += 0.16

func set_priority_target(target: Node2D, forced: bool) -> void:
	var target_id := int(target.get_instance_id()) if forced and target != null else -1
	if priority_target_id == target_id:
		return
	priority_target_id = target_id
	if target == null or dead:
		return
	# Retarget queued attacks at taunt transitions, while fired shots keep their trajectory.
	if charge_windup > 0.0:
		charge_direction = position.direction_to(target.position)
	if attack_windup > 0.0 or burst_left > 0:
		attack_direction = position.direction_to(target.position)
		attack_landing = target.position
	queue_redraw()

func contact_knockback(direction: Vector2, distance: float) -> void:
	distance *= 1.0 - clampf(tenacity, 0.0, 1.0)
	if not dead and distance > 0.0:
		knock_back(direction, distance)

func knock_back(direction: Vector2, distance: float) -> void:
	knockback_remaining = 0.2
	knockback_velocity = direction.normalized() * distance / knockback_remaining

func hit(amount: float) -> bool:
	hp -= amount
	hit_flash = 0.08
	if hp <= 0.0:
		dead = true
	return dead

func contact_damage() -> float:
	return damage

func _draw() -> void:
	var color := Color("ff7597") if not elite else Color("c194ff")
	match kind:
		"runner": color = Color("65e8c5")
		"brute": color = Color("ffba65")
		"charger": color = Color("ff584f")
	if not ranged_config.is_empty():
		color = ranged_config.color
	if hit_flash > 0.0:
		color = Color("ffffff")
	draw_circle(Vector2.ZERO, radius + 5.0, Color(color, 0.08))
	if movement_scale < 1.0:
		draw_arc(Vector2.ZERO, radius + 8.0, 0, TAU, 24, Color("83cbff"), 2.0, true)
	if not element_state.is_empty():
		if float(element_state.fire) > 0.0:
			draw_circle(Vector2(-9, -radius - 14), 4.0, Color("ff8a38"))
		if float(element_state.ice) > 0.0:
			draw_circle(Vector2(9, -radius - 14), 4.0, Color("8ee0ff"))
		if float(element_state.burn) > 0.0:
			draw_arc(Vector2.ZERO, radius + 12.0, 0, TAU, 24, Color("ff793e"), 2.0, true)
	var texture := Art.sprite(kind if not ranged_config.is_empty() else ("elite" if elite else "enemy"))
	if not ranged_config.is_empty() and texture != null:
		Art.shadow(self, Vector2(8, 13), Vector2(radius * 3.0, radius * 1.2), 0.72)
		var size := radius * 3.7
		motion.render(texture, Rect2(-size / 2.0, -size * 0.77, size, size), Color(1.4, 1.4, 1.4) if hit_flash > 0.0 else Color.WHITE, 2 if kind == "sweep" else 1)
		_draw_ranged_warning(color)
	elif not ranged_config.is_empty():
		_draw_ranged_body(color)
		_draw_ranged_warning(color)
	elif texture != null:
		Art.shadow(self, Vector2(8, radius * 0.6), Vector2(radius * 3.4, radius * 1.3), 0.72)
		var size := 92.0 if elite else (86.0 if kind == "brute" else (52.0 if kind == "runner" else 64.0))
		var tint := Color(1.5, 1.5, 1.5) if hit_flash > 0.0 else Color.WHITE
		if kind in ["runner", "brute", "charger"] and hit_flash <= 0.0:
			tint = Color.WHITE.lerp(color, 0.45)
		motion.render(texture, Rect2(-size / 2.0, -size * 0.73, size, size), tint, 1)
	elif elite:
		var points := PackedVector2Array([Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius), Vector2(-radius, 0)])
		draw_colored_polygon(points, color)
	else:
		draw_rect(Rect2(-radius, -radius, radius * 2, radius * 2), color)
	if texture == null:
		motion.hide()
		draw_circle(Vector2(-4, -2), 2.0, Color("401e36"))
		draw_circle(Vector2(4, -2), 2.0, Color("401e36"))
	if kind in ["runner", "brute", "charger"]:
		draw_arc(Vector2.ZERO, radius + 12.0, 0, TAU, 32, Color(color, 0.8), 1.5, true)
	if charge_windup > 0.0:
		draw_arc(Vector2.ZERO, radius + 11.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - charge_windup / 0.7), 32, Color("ffe486"), 3.0, true)
		draw_line(charge_direction * 18.0, charge_direction * 100.0, Color(1.0, 0.8, 0.3, 0.7), 4.0, true)
	elif charge_remaining > 0.0:
		draw_line(-charge_direction * 35.0, Vector2.ZERO, Color(1.0, 0.3, 0.2, 0.6), 6.0, true)
	if hp < max_hp:
		draw_rect(Rect2(-radius, -radius - 8, radius * 2, 3), Color("27334d"))
		draw_rect(Rect2(-radius, -radius - 8, radius * 2 * maxf(hp, 0.0) / max_hp, 3), color)
	for id in marks:
		var mark_color: Color = preload("res://scripts/balance.gd").PLAYER_COLORS[id]
		draw_arc(Vector2.ZERO, radius + 7.0 + float(id) * 4.0, 0, TAU, 32, mark_color, 2.0, true)
		draw_circle(Vector2(-4 + int(id) * 8, -radius - 15), 3.0, mark_color)

func _draw_ranged_body(color: Color) -> void:
	draw_circle(Vector2(0, 13), radius, Color(0, 0, 0, 0.3))
	match kind:
		"fan":
			var cap := PackedVector2Array([Vector2(-26, 4), Vector2(-17, -18), Vector2(0, -27), Vector2(17, -18), Vector2(26, 4)])
			draw_colored_polygon(cap, color.darkened(0.15))
			for angle in [-0.36, 0.0, 0.36]:
				var tip := attack_direction.rotated(angle) * 28.0
				draw_line(attack_direction.rotated(angle) * 12.0, tip, Color("321f32"), 8.0, true)
				draw_circle(tip, 4.0, color)
		"ring":
			for index in range(8):
				var petal := Vector2.from_angle(TAU * float(index) / 8.0 + gait * 0.07) * 23.0
				draw_circle(petal, 8.0, color.darkened(0.2))
				draw_circle(petal, 3.0, color.lightened(0.35))
		"sweep":
			for side in [-1.0, 1.0]:
				var wing := PackedVector2Array([Vector2(side * 8, -8), Vector2(side * 35, -21), Vector2(side * 29, 14), Vector2(side * 9, 8)])
				draw_colored_polygon(wing, Color(color, 0.7))
			var barrel := attack_direction.rotated(-0.85 + 1.7 * float(burst_index) / 8.0) if burst_left > 0 else attack_direction
			draw_line(barrel * 10.0, barrel * 34.0, color, 8.0, true)
		"mortar":
			draw_line(Vector2(-21, 18), Vector2(-16, -5), color.darkened(0.35), 8.0, true)
			draw_line(Vector2(21, 18), Vector2(16, -5), color.darkened(0.35), 8.0, true)
			draw_rect(Rect2(-13, -30, 26, 27), color.darkened(0.2))
			draw_arc(Vector2(0, -29), 13, 0, TAU, 24, color, 4.0, true)
	draw_circle(Vector2.ZERO, radius, Color("35283d"))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, color, 3.0, true)
	draw_circle(Vector2(-5, -3), 3.0, Color("fff0de"))
	draw_circle(Vector2(5, -3), 3.0, Color("fff0de"))
	draw_string(ThemeDB.fallback_font, Vector2(-36, -40), str(ranged_config.name), HORIZONTAL_ALIGNMENT_CENTER, 72, 12, color)

func _draw_ranged_warning(color: Color) -> void:
	if attack_windup <= 0.0 and burst_left <= 0:
		return
	var progress := 1.0 - attack_windup / float(ranged_config.windup)
	draw_arc(Vector2.ZERO, radius + 9.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 40, color.lightened(0.3), 3.0, true)
	var angle := attack_direction.angle()
	match kind:
		"fan":
			for offset in Barrage.fan_angles(pattern_seconds):
				var direction := attack_direction.rotated(offset)
				draw_line(direction * 34.0, direction * 130.0, Color(color, 0.5), 2.0, true)
		"ring":
			draw_arc(Vector2.ZERO, 65.0, angle + 0.55, angle + TAU - 0.55, 40, Color(color, 0.5), 3.0, true)
			draw_arc(Vector2.ZERO, 65.0, angle - 0.55, angle + 0.55, 16, Color("9cf0ab"), 3.0, true)
		"sweep":
			draw_arc(Vector2.ZERO, 110.0, angle - 0.85, angle + 0.85, 32, Color(color, 0.45), 3.0, true)
			for offset in [-0.85, 0.85]:
				draw_line(attack_direction.rotated(offset) * 34.0, attack_direction.rotated(offset) * 110.0, Color(color, 0.5), 2.0, true)
		"mortar":
			draw_line(Vector2.ZERO, (attack_landing - position).limit_length(90.0), Color(color, 0.6), 2.0, true)

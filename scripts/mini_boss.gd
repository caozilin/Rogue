extends "res://scripts/enemy.gd"
## One readable attack at a time; no attacks until fully inside the arena.

const BOSS_NAME := "孢冠统领"
var state := "enter"
var boss_attack := "fan"
var attack_step := 0
var enraged := false
var attack_enraged := false
var windup_duration := 0.8
var charge_speed := 350.0
var rage_flash := 0.0

func display_name() -> String:
	return BOSS_NAME

func setup_boss(spawn: Vector2, tuning: Dictionary, reward: int) -> void:
	super.setup(spawn, tuning, false, "boss")
	hp = Balance.BOSS_HEALTH.spore
	max_hp = hp
	speed = minf(100.0, float(tuning.speed) * 0.7)
	damage = Balance.boss_damage(float(tuning.seconds))
	radius = 34.0
	xp_value = reward
	pattern_seconds = float(tuning.seconds)
	attack_cooldown = 1.0

func advance(delta: float, target: Node2D) -> void:
	if dead:
		return
	if knockback_remaining > 0.0:
		super.advance(delta, target)
		return
	contact_cooldown = maxf(0.0, contact_cooldown - delta * attack_scale)
	hit_flash = maxf(0.0, hit_flash - delta)
	rage_flash = maxf(0.0, rage_flash - delta)
	gait += delta * 5.0
	if target == null:
		queue_redraw()
		return
	var movement_delta := delta * movement_scale
	delta *= attack_scale
	match state:
		"enter":
			var inner_arena := Balance.ARENA.grow(-radius - 12.0)
			var entrance := target.position.clamp(inner_arena.position + Vector2.ONE, inner_arena.end - Vector2.ONE)
			position += position.direction_to(entrance) * speed * movement_delta
			if inner_arena.has_point(position):
				state = "approach"
		"windup":
			attack_windup = maxf(0.0, attack_windup - delta)
			if attack_windup == 0.0:
				if boss_attack == "charge":
					state = "charge"
					charge_remaining = 0.75 if attack_enraged else 0.65
					charge_speed = 410.0 if attack_enraged else 350.0
				else:
					ranged_attack.emit(self, boss_attack, attack_direction, target.position)
					_finish_attack()
		"charge":
			var next_position := position + attack_direction * charge_speed * minf(movement_delta, charge_remaining)
			var blocked := not Balance.ARENA.grow(-radius).has_point(next_position)
			position = next_position.clamp(Balance.ARENA.position + Vector2.ONE * radius, Balance.ARENA.end - Vector2.ONE * radius)
			charge_remaining = 0.0 if blocked else maxf(0.0, charge_remaining - movement_delta)
			if charge_remaining == 0.0:
				_finish_attack()
		"recover":
			attack_cooldown = maxf(0.0, attack_cooldown - delta)
			if attack_cooldown == 0.0:
				state = "approach"
		"approach":
			attack_cooldown = maxf(0.0, attack_cooldown - delta)
			var distance := position.distance_to(target.position)
			if distance > 270.0:
				position += position.direction_to(target.position) * speed * movement_delta
			elif distance < 155.0:
				position -= position.direction_to(target.position) * speed * 0.4 * movement_delta
			position = position.clamp(Balance.ARENA.position + Vector2.ONE * (radius + 12.0), Balance.ARENA.end - Vector2.ONE * (radius + 12.0))
			if attack_cooldown == 0.0 and distance <= 450.0:
				boss_attack = ["fan", "ring", "charge"][attack_step % 3]
				attack_enraged = enraged
				attack_direction = position.direction_to(target.position)
				var normal: float = {"fan": 0.8, "ring": 1.0, "charge": 0.9}[boss_attack]
				windup_duration = normal * (0.85 if attack_enraged else 1.0)
				attack_windup = windup_duration
				state = "windup"
	queue_redraw()

func _finish_attack() -> void:
	attack_step += 1
	state = "recover"
	attack_cooldown = 1.1 if attack_enraged else 1.8

func contact_damage() -> float:
	return damage * (2.0 if state == "charge" else 1.0)

func bullet_angles(pattern: String) -> Array[float]:
	var angles: Array[float] = []
	if pattern == "fan":
		var count := 7 if attack_enraged else 5
		var spacing := 0.22 if attack_enraged else 0.24
		for index in range(count):
			angles.append((float(index) - float(count - 1) * 0.5) * spacing)
	else:
		var count := 20 if attack_enraged else 16
		for index in range(count):
			var angle := TAU * float(index) / float(count)
			if absf(wrapf(angle, -PI, PI)) > 0.7:
				angles.append(angle)
	return angles

func knock_back(direction: Vector2, distance: float) -> void:
	super.knock_back(direction, distance * 0.2)

func hit(amount: float) -> bool:
	var killed := super.hit(amount)
	if not killed and not enraged and hp <= max_hp * 0.5:
		enraged = true
		rage_flash = 1.2
	return killed

func status_text() -> String:
	if state == "enter":
		return "边缘入场中 · 尚未开火"
	if state == "recover":
		return "攻击后摇 · 趁机输出"
	if state == "windup" or state == "charge":
		return {"fan": "扇形弹幕 · 横向走位", "ring": "环形弹幕 · 找绿色缺口", "charge": "锁定冲锋 · 致命伤害 · 侧移避开红色路径"}[boss_attack]
	return "狂怒：弹幕增密，攻击加快" if enraged else "扇射 → 环射 → 冲锋 · 半血进入狂怒"

func _draw() -> void:
	var color := Color("ff745c") if enraged else Color("ffc975")
	if hit_flash > 0.0:
		color = Color.WHITE
	Art.shadow(self, Vector2(16, 23), Vector2(140, 50), 0.8)
	draw_circle(Vector2.ZERO, 51.0, Color(color, 0.1))
	var texture := Art.sprite("spore_boss")
	if texture != null:
		motion.render(texture, Rect2(-75, -110, 150, 150), Color.WHITE.lerp(color, 0.12), 1)
	else:
		draw_circle(Vector2.ZERO, radius, color.darkened(0.3))
		draw_circle(Vector2(-10, -5), 4, Color.WHITE)
		draw_circle(Vector2(10, -5), 4, Color.WHITE)
	draw_set_transform(Vector2(0, 18), 0.0, Vector2(1, 0.42))
	draw_arc(Vector2.ZERO, 45.0, 0, TAU, 48, Color(color, 0.6), 1.8, true)
	draw_set_transform(Vector2.ZERO)
	if rage_flash > 0.0:
		draw_arc(Vector2.ZERO, 55.0 + (1.2 - rage_flash) * 32.0, 0, TAU, 48, Color(color, rage_flash / 1.2), 4.0, true)
	if state == "windup":
		draw_arc(Vector2.ZERO, 53.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - attack_windup / windup_duration), 48, color.lightened(0.3), 4.0, true)
		match boss_attack:
			"fan":
				for offset in bullet_angles("fan"):
					var direction := attack_direction.rotated(offset)
					draw_line(direction * 56.0, direction * 170.0, Color(color, 0.65), 2.0, true)
			"ring":
				var angle := attack_direction.angle()
				draw_arc(Vector2.ZERO, 104.0, angle + 0.7, angle + TAU - 0.7, 48, Color("f675d5"), 3.0, true)
				draw_arc(Vector2.ZERO, 104.0, angle - 0.35, angle + 0.35, 20, Color("9cf0ab"), 5.0, true)
			"charge":
				var reach := 307.5 if attack_enraged else 227.5
				var side := attack_direction.orthogonal() * radius
				var path := PackedVector2Array([side, side + attack_direction * reach, -side + attack_direction * reach, -side])
				draw_colored_polygon(path, Color(1.0, 0.25, 0.25, 0.13))
				draw_line(side, side + attack_direction * reach, Color("ff745c"), 2.0, true)
				draw_line(-side, -side + attack_direction * reach, Color("ff745c"), 2.0, true)
				draw_line(attack_direction * 54.0, attack_direction * reach, Color("ffba70"), 3.0, true)
	elif state == "charge":
		draw_line(-attack_direction * 85.0, Vector2.ZERO, Color(color, 0.45), 12.0, true)
	for id in marks:
		draw_arc(Vector2.ZERO, 58.0 + float(id) * 5.0, 0, TAU, 48, Balance.PLAYER_COLORS[id], 2.0, true)

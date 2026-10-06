extends "res://scripts/mini_boss.gd"
## Summoner/ground-control boss, sharing only entry, rage threshold and rewards.

signal ground_attack(source, spell: String, points: Array[Vector2], direction: Vector2, enhanced: bool)
signal summon_guards(source, count: int)
var combat_players: Array = []
var guards: Array = []
var ground_points: Array[Vector2] = []

func display_name() -> String:
	return "荆棘祭司"

func setup_boss(spawn: Vector2, tuning: Dictionary, reward: int) -> void:
	super.setup_boss(spawn, tuning, reward)
	hp = Balance.BOSS_HEALTH.thorn
	max_hp = hp
	speed *= 0.8
	boss_attack = "summon"

func active_guards() -> int:
	var count := 0
	for guard in guards:
		if is_instance_valid(guard) and not guard.dead and guard.position.distance_to(position) <= 260.0:
			count += 1
	return count

func guard_count() -> int:
	var count := 0
	for guard in guards:
		if is_instance_valid(guard) and not guard.dead:
			count += 1
	return count

func hit(amount: float) -> bool:
	return super.hit(amount * (0.65 if active_guards() > 0 else 1.0))

func set_priority_target(target: Node2D, forced: bool) -> void:
	var previous := priority_target_id
	super.set_priority_target(target, forced)
	if previous != priority_target_id and target != null and state == "windup" and boss_attack == "fault":
		ground_points.assign([target.position])

func advance(delta: float, target: Node2D) -> void:
	if dead or state == "enter" or knockback_remaining > 0.0:
		super.advance(delta, target)
		return
	contact_cooldown = maxf(0.0, contact_cooldown - delta * attack_scale)
	var movement_delta := delta * movement_scale
	delta *= attack_scale
	hit_flash = maxf(0.0, hit_flash - delta)
	rage_flash = maxf(0.0, rage_flash - delta)
	gait += delta * 4.0
	if target == null:
		return
	if state == "windup":
		attack_windup = maxf(0.0, attack_windup - delta)
		if attack_windup == 0.0:
			if boss_attack == "summon":
				summon_guards.emit(self, 3 if attack_enraged else 2)
			else:
				ground_attack.emit(self, boss_attack, ground_points, attack_direction, attack_enraged)
			attack_step += 1
			state = "recover"
			attack_cooldown = 1.8 if attack_enraged else 2.5
	elif state == "recover":
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
		if attack_cooldown == 0.0:
			state = "approach"
	else:
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
		var distance := position.distance_to(target.position)
		if distance > 350.0:
			position += position.direction_to(target.position) * speed * movement_delta
		elif distance < 235.0:
			position -= position.direction_to(target.position) * speed * 0.5 * movement_delta
		position = position.clamp(Balance.ARENA.position + Vector2.ONE * 46.0, Balance.ARENA.end - Vector2.ONE * 46.0)
		if attack_cooldown == 0.0 and distance <= 600.0:
			boss_attack = ["summon", "fault", "roots"][attack_step % 3]
			attack_enraged = enraged
			attack_direction = position.direction_to(target.position)
			ground_points.clear()
			if boss_attack == "roots":
				for player in combat_players:
					if player.is_targetable(): ground_points.append(player.position)
				if ground_points.is_empty(): ground_points.append(target.position)
			else:
				ground_points.append(target.position)
			windup_duration = 1.0 if attack_enraged else 1.3
			attack_windup = windup_duration
			state = "windup"
	queue_redraw()

func status_text() -> String:
	if state == "enter": return "边缘入场中 · 尚未施法"
	var shield := "护卫减伤 35% · 先拆护卫" if active_guards() > 0 else "护盾已破 · 可以输出"
	if state == "recover": return "施法后摇 · %s" % shield
	if state == "windup":
		return {"summon": "护卫正在从边缘赶来", "fault": "地裂封路 · 致命伤害 · 提前跨过预警带", "roots": "荆棘锁定落点 · 离开绿色圆圈"}[boss_attack]
	return shield

func _draw() -> void:
	var color := Color("bef06d") if not enraged else Color("e9ed64")
	if hit_flash > 0.0: color = Color.WHITE
	Art.shadow(self, Vector2(15, 24), Vector2(135, 46), 0.8)
	var texture := Art.sprite("thorn_boss")
	if texture != null:
		motion.render(texture, Rect2(-76, -113, 152, 152), Color.WHITE.lerp(color, 0.12), 3)
	if active_guards() > 0:
		draw_arc(Vector2.ZERO, 57.0, 0, TAU, 48, Color("7df1ac"), 3.0, true)
		for guard in guards:
			if is_instance_valid(guard) and not guard.dead and guard.position.distance_to(position) <= 260.0:
				draw_line(Vector2.ZERO, guard.position - position, Color(0.4, 1.0, 0.65, 0.4), 2.0, true)
	if state == "windup":
		draw_arc(Vector2.ZERO, 49.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - attack_windup / windup_duration), 40, color, 4.0, true)
		if boss_attack == "fault" and not ground_points.is_empty():
			var side := attack_direction.orthogonal()
			var span := 270.0 if attack_enraged else 180.0
			var center := ground_points[0] - position
			draw_line(center - side * span, center + side * span, Color(color, 0.6), 7.0, true)
		elif boss_attack == "roots":
			for point in ground_points:
				draw_arc(point - position, 72.0, 0, TAU, 40, Color(color, 0.65), 2.0, true)
				if attack_enraged:
					draw_arc(point + attack_direction.orthogonal() * 115.0 - position, 72.0, 0, TAU, 40, Color(color, 0.65), 2.0, true)

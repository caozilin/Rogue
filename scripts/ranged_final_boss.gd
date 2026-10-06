extends "res://scripts/final_boss.gd"
## Fast artillery finale, including a full-arena storm without a fixed safe lane.

signal artillery_volley(source, module: String, direction: Vector2, index: int, stage: int)
signal artillery_bombardment(source, module: String, points: Array[Vector2], stage: int)

const ARTILLERY_MODULES := {
	"halo": {"name": "天穹环幕", "windup": 0.65, "recover": 1.35},
	"crossfire": {"name": "交叉扫射", "windup": 0.55, "recover": 1.25},
	"mark": {"name": "双人定点轰炸", "windup": 0.6, "recover": 1.35},
	"carpet": {"name": "分区毁灭轰炸", "windup": 0.8, "recover": 1.6},
	"storm": {"name": "灭世星雨", "windup": 0.75, "recover": 1.8}
}
const ARTILLERY_CYCLE := ["halo", "mark", "crossfire", "carpet", "storm"]
const BOMB_WARNING := 0.6
const BOMB_STAGGER := 0.08
const BOMB_BLAST := 0.65

var locked_points: Array[Vector2] = []
var volley_left := 0
var volley_index := 0
var volley_timer := 0.0
var safe_lane := Rect2()
var lane_remaining := 0.0
var bombardment_remaining := 0.0

func display_name() -> String:
	return "天穹炮皇"

func phase_name() -> String:
	return ["巡天 · 第一阶段", "过载 · 第二阶段", "毁灭 · 第三阶段"][phase - 1]

func setup_boss(spawn: Vector2, tuning: Dictionary, reward: int) -> void:
	super.setup_boss(spawn, tuning, reward)
	hp = Balance.BOSS_HEALTH.artillery
	max_hp = hp
	speed = 125.0
	radius = 44.0
	boss_attack = "halo"
	attack_cooldown = 0.8

func ring_gap(stage: int) -> float:
	return 0.42 - (stage - 1) * 0.045

func volley_angles(module: String, index: int, stage: int) -> Array[float]:
	var angles: Array[float] = []
	if module in ["halo", "storm"]:
		var count := 28 + (stage - 1) * 4
		for slot in range(count):
			var angle := wrapf(TAU * slot / float(count) + index * 0.13, -PI, PI)
			if module == "storm" or absf(angle) > ring_gap(stage): angles.append(angle)
	else:
		var count := 9 + (stage - 1) * 2
		var sweep := lerpf(-0.85, 0.85, index / float(count - 1))
		if stage > 1: sweep *= -1.0
		for offset in [-0.19, -0.095, 0.0, 0.095, 0.19]: angles.append(sweep + offset)
	return angles

func _lock_bombardment() -> void:
	locked_points.clear()
	if boss_attack == "mark":
		for player in combat_players:
			if not player.is_targetable(): continue
			locked_points.append(player.position)
			if attack_phase == 3:
				locked_points.append(player.position + attack_direction.orthogonal() * 125.0)
	else:
		var band_height := Balance.ARENA.size.y / 3.0
		var safe_band := int(attack_step / ARTILLERY_CYCLE.size()) % 3
		# Larger explosions encroach on band edges; show only the truly safe core.
		# A 60px inset also accommodates the warrior's maximum giant collision body.
		safe_lane = Rect2(Balance.ARENA.position + Vector2(0, safe_band * band_height + 60.0), Vector2(Balance.ARENA.size.x, band_height - 120.0))
		for row in range(3):
			if row == safe_band: continue
			for column in range(6):
				locked_points.append(Balance.ARENA.position + Vector2((column + 0.5) * Balance.ARENA.size.x / 6.0, (row + 0.5) * band_height))
		lane_remaining = windup_duration + BOMB_WARNING + 11 * BOMB_STAGGER + BOMB_BLAST
	for index in range(locked_points.size()):
		var margin := 64.0 if boss_attack == "mark" else 72.0
		locked_points[index] = locked_points[index].clamp(Balance.ARENA.position + Vector2.ONE * margin, Balance.ARENA.end - Vector2.ONE * margin)

func _start_artillery(target: Node2D) -> void:
	var chosen = target
	if priority_target_id == -1 and attack_step % 2 == 1:
		for player in combat_players:
			if player.is_targetable() and position.distance_to(player.position) > position.distance_to(chosen.position): chosen = player
	boss_attack = ARTILLERY_CYCLE[attack_step % ARTILLERY_CYCLE.size()]
	attack_phase = phase
	attack_direction = position.direction_to(chosen.position)
	if attack_direction == Vector2.ZERO: attack_direction = Vector2.RIGHT
	windup_duration = float(ARTILLERY_MODULES[boss_attack].windup) * (1.0 - 0.10 * (attack_phase - 1))
	attack_windup = windup_duration
	if boss_attack in ["mark", "carpet"]: _lock_bombardment()
	state = "windup"

func _finish_module() -> void:
	state = "recover"
	attack_step += 1
	attack_cooldown = float(ARTILLERY_MODULES[boss_attack].recover) * (1.0 - 0.08 * (attack_phase - 1))
	if boss_attack in ["mark", "carpet"]: attack_cooldown = maxf(attack_cooldown, bombardment_remaining)

func _advance_salvo(delta: float) -> void:
	volley_timer -= delta
	while volley_left > 0 and volley_timer <= 0.0:
		artillery_volley.emit(self, boss_attack, attack_direction, volley_index, attack_phase)
		volley_index += 1
		volley_left -= 1
		volley_timer += {"halo": 0.35, "crossfire": 0.105, "storm": 0.23}[boss_attack]
	if volley_left == 0: _finish_module()

func advance(delta: float, target: Node2D) -> void:
	if dead: return
	hit_flash = maxf(0.0, hit_flash - delta)
	transition_flash = maxf(0.0, transition_flash - delta)
	lane_remaining = maxf(0.0, lane_remaining - delta)
	bombardment_remaining = maxf(0.0, bombardment_remaining - delta)
	gait += delta * 3.0
	if target == null:
		queue_redraw()
		return
	var movement_delta := delta * movement_scale
	var attack_delta := delta * attack_scale
	match state:
		"enter":
			position = position.move_toward(_inside_arena(target.position), speed * movement_delta)
			if Balance.ARENA.grow(-radius - 8.0).has_point(position): state = "approach"
		"approach":
			var distance := position.distance_to(target.position)
			if distance > 420.0:
				position = _inside_arena(position.move_toward(target.position, speed * movement_delta))
			elif distance < 220.0:
				position = _inside_arena(position - position.direction_to(target.position) * speed * 0.7 * movement_delta)
			attack_cooldown = maxf(0.0, attack_cooldown - attack_delta)
			if attack_cooldown == 0.0: _start_artillery(target)
		"windup":
			attack_windup = maxf(0.0, attack_windup - attack_delta)
			if attack_windup == 0.0:
				if boss_attack in ["mark", "carpet"]:
					bombardment_remaining = BOMB_WARNING + BOMB_BLAST + ((locked_points.size() - 1) * BOMB_STAGGER if boss_attack == "carpet" else 0.0)
					artillery_bombardment.emit(self, boss_attack, locked_points, attack_phase)
					_finish_module()
				else:
					state = "salvo"
					volley_index = 0
					volley_timer = 0.0
					volley_left = (2 if attack_phase == 1 else 3) if boss_attack == "halo" else (3 + attack_phase if boss_attack == "storm" else 9 + (attack_phase - 1) * 2)
					_advance_salvo(0.0)
		"salvo": _advance_salvo(attack_delta)
		"recover":
			attack_cooldown = maxf(0.0, attack_cooldown - attack_delta)
			if attack_cooldown == 0.0: state = "approach"
	queue_redraw()

func status_text() -> String:
	if state == "enter": return "最终决战 · 边缘入场中 · 不召唤杂兵"
	if bombardment_remaining > 0.0:
		return "分区毁灭轰炸 · 致命重击 · 进入绿色安全带" if boss_attack == "carpet" else "双人定点轰炸 · 致命落点已锁定 · 离开红圈"
	if state == "recover": return "炮组冷却 · 受到伤害增加 25% · 抓住空档集火"
	return {"halo": "天穹环幕 · 高速多重环 · 缺口变窄", "crossfire": "交叉扫射 · 五重高速火线 · 立即侧移", "mark": "双人定点轰炸 · 快速坠落 · 立即离开", "carpet": "分区毁灭轰炸 · 连续爆破 · 进入绿色安全带", "storm": "灭世星雨 · 全场交错弹幕 · 无固定安全带 · 灵活穿缝或开启防御"}[boss_attack]

func _draw() -> void:
	var color: Color = [Color("8dcff7"), Color("dcb0ff"), Color("ff8c70")][phase - 1]
	if hit_flash > 0.0: color = Color.WHITE
	if lane_remaining > 0.0 and boss_attack == "carpet":
		var lane := Rect2(safe_lane.position - position, safe_lane.size)
		draw_rect(lane, Color(0.3, 1.0, 0.65, 0.07))
		draw_rect(lane, Color("8ef1b5"), false, 2.5)
	if state == "windup":
		if boss_attack == "halo":
			var angle := attack_direction.angle()
			var gap := ring_gap(attack_phase)
			draw_arc(Vector2.ZERO, 106, angle + gap, angle + TAU - gap, 64, color, 2.5, true)
			draw_arc(Vector2.ZERO, 106, angle - gap, angle + gap, 24, Color("8ef1b5"), 5, true)
		elif boss_attack == "crossfire":
			for offset in [-0.99, 0.99]:
				var aim := attack_direction.rotated(offset)
				draw_line(aim * 60, aim * 260, Color(color, 0.65), 2, true)
		elif boss_attack in ["mark", "carpet"]:
			for point in locked_points:
				draw_arc(point - position, 64 if boss_attack == "mark" else 72, 0, TAU, 40, Color(1, 0.5, 0.35, 0.7), 2, true)
	Art.shadow(self, Vector2(12, 24), Vector2(164, 56), 0.8)
	var texture := Art.sprite("mortar")
	if texture != null: motion.render(texture, Rect2(-94, -128, 188, 188), Color.WHITE.lerp(color, 0.12), 1)
	# Twin cannon pods and an orbital core give the artillery silhouette its identity.
	for side in [-1, 1]:
		var mount := Vector2(side * 70, -27)
		draw_circle(mount, 23, Color("263548"))
		draw_arc(mount, 23, 0, TAU, 32, color, 3, true)
		draw_line(mount, mount + attack_direction * 42, Color("5b6c87"), 17, true)
		draw_circle(mount + attack_direction * 42, 8, color)
	draw_arc(Vector2(0, -58), 63, 0, TAU, 48, Color(color, 0.7), 3, true)
	for index in range(6):
		var at := Vector2(0, -58) + Vector2.from_angle(TAU * index / 6.0 + gait * 0.08) * 63
		draw_circle(at, 5, color)
	if state == "windup":
		draw_arc(Vector2.ZERO, 62, -PI / 2, -PI / 2 + TAU * (1.0 - attack_windup / windup_duration), 48, color, 4, true)
	for id in marks: draw_arc(Vector2.ZERO, 67 + float(id) * 5, 0, TAU, 48, Balance.PLAYER_COLORS[id], 2, true)

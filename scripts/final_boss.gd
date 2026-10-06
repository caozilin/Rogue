extends "res://scripts/enemy.gd"
## Fast melee modules; judgment follows a chosen player and requires defense.

signal melee_strike(source, shape: String, origin: Vector2, endpoint: Vector2, direction: Vector2, reach: float, half_angle: float, multiplier: float)

const MODULES := {
	"rush": {"name": "疾行连斩", "windup": 0.35, "recover": 1.0, "reach": 155.0, "damage": 1.15},
	"dash": {"name": "断界突进", "windup": 0.45, "recover": 1.15, "reach": 470.0, "damage": 1.8},
	"blink": {"name": "瞬步背斩", "windup": 0.4, "recover": 1.05, "reach": 150.0, "damage": 1.4},
	"slam": {"name": "震地重击", "windup": 0.75, "recover": 1.45, "reach": 190.0, "damage": 3.0},
	"judgment": {"name": "裁决锁魂斩", "windup": 0.65, "recover": 1.65, "reach": 180.0, "damage": 1.7}
}
const CYCLE := ["rush", "dash", "judgment", "slam", "blink"]
const BLINK_LIMIT := 430.0

var state := "enter"
var boss_attack := "rush"
var phase := 1
var attack_phase := 1 # Snapshot the phase to keep an existing warning intact.
var enraged := false
var combat_players: Array = []
var duel_target = null
var attack_step := 0
var windup_duration := 1.0
var rush_remaining := 0.0
var rush_elapsed := 0.0
var combo_left := 0
var combo_index := 0
var dash_endpoint := Vector2.ZERO
var blink_destination := Vector2.ZERO
var strike_hits: Dictionary = {}
var effect_remaining := 0.0
var effect_shape := ""
var effect_origin := Vector2.ZERO
var effect_direction := Vector2.RIGHT
var effect_reach := 0.0
var transition_flash := 0.0

func display_name() -> String:
	return "断界武王"

func phase_name() -> String:
	return ["铁刃 · 第一阶段", "疾锋 · 第二阶段", "绝境 · 第三阶段"][phase - 1]

func setup_boss(spawn: Vector2, tuning: Dictionary, reward: int) -> void:
	super.setup(spawn, tuning, false, "boss")
	hp = Balance.BOSS_HEALTH.melee
	max_hp = hp
	speed = 245.0
	damage = Balance.boss_damage(float(tuning.seconds))
	radius = 42.0
	xp_value = reward
	attack_cooldown = 0.7
	pattern_seconds = float(tuning.seconds)

func hit(amount: float) -> bool:
	var killed := super.hit(amount * (1.25 if state == "recover" else 1.0))
	var next_phase := 3 if hp <= max_hp * 0.3 else (2 if hp <= max_hp * 0.6 else 1)
	if not killed and next_phase > phase:
		phase = next_phase
		enraged = phase > 1
		transition_flash = 1.0
	return killed

func knock_back(_direction: Vector2, _distance: float) -> void:
	pass # Heavy melee boss; slows and taunts remain useful.

func set_priority_target(target: Node2D, forced: bool) -> void:
	var previous := priority_target_id
	super.set_priority_target(target, forced)
	if target == null or previous == priority_target_id: return
	# Ending a taunt or losing a target must not silently transfer a pending lock.
	if boss_attack == "judgment" and state == "windup" and not forced: return
	duel_target = target
	# A newly cast taunt redirects queued movement, with the new warning shown immediately.
	if state == "windup" and boss_attack == "dash": _lock_dash(target)
	if state == "windup" and boss_attack == "blink": _lock_blink(target)

func _inside_arena(point: Vector2) -> Vector2:
	return point.clamp(Balance.ARENA.position + Vector2.ONE * (radius + 8.0), Balance.ARENA.end - Vector2.ONE * (radius + 8.0))

func _lock_dash(target: Node2D) -> void:
	attack_direction = position.direction_to(target.position)
	if attack_direction == Vector2.ZERO: attack_direction = Vector2.RIGHT
	var distance := minf(float(MODULES.dash.reach), position.distance_to(target.position) + 65.0)
	dash_endpoint = _inside_arena(position + attack_direction * distance)

func _lock_blink(target: Node2D) -> void:
	var direction := position.direction_to(target.position)
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	# Predicted flank, clamped to both the movement limit and arena boundary.
	var desired: Vector2 = target.position + direction * 65.0
	blink_destination = _inside_arena(position + (desired - position).limit_length(BLINK_LIMIT))
	attack_direction = blink_destination.direction_to(target.position)
	if attack_direction == Vector2.ZERO: attack_direction = -direction

func _start_module(target: Node2D) -> void:
	var chosen = target
	# Alternate attention between the duo unless warcry forces a target.
	if priority_target_id == -1 and attack_step % 2 == 1:
		for player in combat_players:
			if player.is_targetable() and position.distance_to(player.position) > position.distance_to(chosen.position): chosen = player
	boss_attack = CYCLE[attack_step % CYCLE.size()]
	duel_target = chosen
	var distance := position.distance_to(chosen.position)
	if boss_attack == "slam" and distance > 230.0:
		boss_attack = "rush"
	attack_phase = phase
	combo_left = 3 if attack_phase == 3 else 2
	combo_index = 0
	attack_direction = position.direction_to(chosen.position)
	if attack_direction == Vector2.ZERO: attack_direction = Vector2.RIGHT
	if boss_attack == "dash": _lock_dash(chosen)
	if boss_attack == "blink": _lock_blink(chosen)
	windup_duration = float(MODULES[boss_attack].windup) * (1.0 - 0.12 * (attack_phase - 1))
	attack_windup = windup_duration
	strike_hits.clear()
	state = "windup"

func _prepare_slash(target: Node2D) -> void:
	attack_direction = position.direction_to(target.position)
	if attack_direction == Vector2.ZERO: attack_direction = Vector2.RIGHT
	windup_duration = 0.36 - (attack_phase - 1) * 0.04
	attack_windup = windup_duration
	strike_hits.clear()
	state = "combo_windup"

func _strike(shape: String, reach: float, multiplier: float) -> void:
	strike_hits.clear()
	melee_strike.emit(self, shape, position, position, attack_direction, reach, PI * 0.36, multiplier)
	effect_origin = position
	effect_direction = attack_direction
	effect_reach = reach
	effect_shape = shape
	effect_remaining = 0.25

func _finish_module() -> void:
	state = "recover"
	attack_step += 1
	attack_cooldown = float(MODULES[boss_attack].recover) * (1.0 - 0.08 * (attack_phase - 1))

func advance(delta: float, target: Node2D) -> void:
	if dead: return
	hit_flash = maxf(0.0, hit_flash - delta)
	effect_remaining = maxf(0.0, effect_remaining - delta)
	transition_flash = maxf(0.0, transition_flash - delta)
	gait += delta * 5.0
	if target == null:
		queue_redraw()
		return
	if priority_target_id == -1 and state not in ["enter", "approach", "recover"] and is_instance_valid(duel_target) and duel_target.is_targetable():
		target = duel_target
	var movement_delta := delta * movement_scale
	var attack_delta := delta * attack_scale
	match state:
		"enter":
			var entrance := _inside_arena(target.position)
			position = position.move_toward(entrance, speed * movement_delta)
			if Balance.ARENA.grow(-radius - 8.0).has_point(position): state = "approach"
		"approach":
			attack_cooldown = maxf(0.0, attack_cooldown - attack_delta)
			if position.distance_to(target.position) > 110.0:
				position = _inside_arena(position.move_toward(target.position, speed * movement_delta))
			if attack_cooldown == 0.0: _start_module(target)
		"windup":
			attack_windup = maxf(0.0, attack_windup - attack_delta)
			if attack_windup == 0.0:
				match boss_attack:
					"rush":
						state = "rush"
						rush_remaining = 2.8
						rush_elapsed = 0.0
					"dash":
						state = "dash"
						strike_hits.clear()
					"blink":
						position = blink_destination
						# Materialize first, then give a fresh, stationary melee warning.
						state = "blink_reveal"
						windup_duration = 0.28 - (attack_phase - 1) * 0.03
						attack_windup = windup_duration
					"slam":
						_strike("circle", float(MODULES.slam.reach), float(MODULES.slam.damage))
						_finish_module()
					"judgment":
						# Resolve against the original target's latest position, never a stale marker.
						if is_instance_valid(duel_target) and duel_target.is_targetable():
							position = _inside_arena(duel_target.position - attack_direction * 75.0)
							attack_direction = position.direction_to(duel_target.position)
							_strike("lock", float(MODULES.judgment.reach), float(MODULES.judgment.damage))
						_finish_module()
		"rush":
			rush_remaining = maxf(0.0, rush_remaining - attack_delta)
			rush_elapsed += attack_delta
			var run_speed := minf(610.0 + (attack_phase - 1) * 55.0, 350.0 + rush_elapsed * 330.0)
			position = _inside_arena(position.move_toward(target.position, run_speed * movement_delta))
			attack_direction = position.direction_to(target.position)
			if position.distance_to(target.position) <= 110.0: _prepare_slash(target)
			elif rush_remaining == 0.0: _finish_module()
		"combo_windup":
			attack_windup = maxf(0.0, attack_windup - attack_delta)
			if attack_windup == 0.0:
				_strike("sector", float(MODULES.rush.reach), float(MODULES.rush.damage))
				combo_left -= 1
				combo_index += 1
				if combo_left > 0:
					state = "combo_gap"
					attack_cooldown = 0.12
				else: _finish_module()
		"combo_gap":
			attack_cooldown = maxf(0.0, attack_cooldown - attack_delta)
			if attack_cooldown == 0.0: _prepare_slash(target)
		"dash":
			var start := position
			position = position.move_toward(dash_endpoint, (1050.0 + (attack_phase - 1) * 110.0) * movement_delta)
			melee_strike.emit(self, "dash", start, position, attack_direction, radius + 5.0, 0.0, float(MODULES.dash.damage))
			if position.is_equal_approx(dash_endpoint): _finish_module()
		"blink_reveal":
			attack_windup = maxf(0.0, attack_windup - attack_delta)
			if attack_windup == 0.0:
				_strike("sector", float(MODULES.blink.reach), float(MODULES.blink.damage))
				_finish_module()
		"recover":
			attack_cooldown = maxf(0.0, attack_cooldown - attack_delta)
			if attack_cooldown == 0.0: state = "approach"
	queue_redraw()

func status_text() -> String:
	if state == "enter": return "终局决斗 · 杂兵已退场 · 边缘入场中"
	if state == "recover": return "破绽窗口 · 受到伤害增加 25% · 集火！"
	if state in ["combo_windup", "combo_gap"]: return "疾行连斩 · 第 %d 斩预警 · 绕到背后" % (combo_index + 1)
	if state == "blink_reveal": return "瞬移落地 · 已锁定斩击方向 · 侧移或绕后"
	if state == "rush": return "加速追击中 · 保留闪避，近身后才挥刀"
	return {"rush": "疾行连斩 · 高速贴身连斩", "dash": "断界突进 · 高速贯穿 · 立即侧移", "blink": "瞬步背斩 · 落地快速出刀", "slam": "震地重击 · 致命重击 · 立即离开", "judgment": "裁决锁魂斩 · 无法靠走位甩脱 · 用无敌、护盾或减伤承受"}[boss_attack]

func _sector_points(origin: Vector2, direction: Vector2, reach: float) -> PackedVector2Array:
	var points := PackedVector2Array([origin])
	for index in range(25):
		points.append(origin + direction.rotated(-PI * 0.36 + PI * 0.72 * index / 24.0) * reach)
	return points

func _draw_sector(origin: Vector2, direction: Vector2, reach: float, color: Color) -> void:
	draw_colored_polygon(_sector_points(origin, direction, reach), Color(color, 0.16))
	draw_arc(origin, reach, direction.angle() - PI * 0.36, direction.angle() + PI * 0.36, 32, color, 3.0, true)
	for side in [-1, 1]: draw_line(origin, origin + direction.rotated(PI * 0.36 * side) * reach, color, 2.0, true)

func _draw() -> void:
	var color: Color = [Color("f5c177"), Color("73d9ef"), Color("ff746b")][phase - 1]
	if hit_flash > 0.0: color = Color.WHITE
	# Attack warnings are drawn beneath the armored silhouette.
	if state == "windup":
		if boss_attack == "dash":
			var end := dash_endpoint - position
			var side := attack_direction.orthogonal() * (radius + 5.0)
			draw_colored_polygon(PackedVector2Array([side, end + side, end - side, -side]), Color(1, 0.35, 0.3, 0.16))
			draw_line(side, end + side, Color("ff9b75"), 3, true)
			draw_line(-side, end - side, Color("ff9b75"), 3, true)
		elif boss_attack == "blink":
			var landing := blink_destination - position
			draw_circle(landing, 45.0, Color(0.7, 0.45, 1.0, 0.18))
			draw_arc(landing, 45.0, 0, TAU, 40, Color("d5a4ff"), 3, true)
			draw_line(landing - Vector2(12, 0), landing + Vector2(12, 0), Color("d5a4ff"), 3, true)
			draw_line(landing - Vector2(0, 12), landing + Vector2(0, 12), Color("d5a4ff"), 3, true)
		elif boss_attack == "slam":
			draw_circle(Vector2.ZERO, float(MODULES.slam.reach), Color(1, 0.3, 0.25, 0.12))
			draw_arc(Vector2.ZERO, float(MODULES.slam.reach), 0, TAU, 64, Color("ff8771"), 4, true)
	if state in ["combo_windup", "blink_reveal"]:
		_draw_sector(Vector2.ZERO, attack_direction, float(MODULES[boss_attack].reach), Color("ffb98b"))
	# Executed attacks are drawn by BossEffects as animated blades and shock waves.
	if state == "dash" or state == "rush":
		draw_line(-attack_direction * 105.0, Vector2.ZERO, Color(color, 0.3), 18, true)
	Art.shadow(self, Vector2(18, 27), Vector2(164, 56), 0.85)
	var texture := Art.sprite("final_boss")
	if texture != null:
		motion.render(texture, Rect2(-95, -140, 190, 190), Color.WHITE.lerp(color, 0.10), 0)
	if state in ["windup", "combo_windup", "blink_reveal"]:
		draw_arc(Vector2.ZERO, 61.0, -PI / 2, -PI / 2 + TAU * (1.0 - attack_windup / windup_duration), 48, color, 4, true)
	if transition_flash > 0.0:
		draw_arc(Vector2.ZERO, 65.0 + (1.0 - transition_flash) * 35.0, 0, TAU, 48, Color(color, transition_flash), 4, true)
	for id in marks: draw_arc(Vector2.ZERO, 64.0 + float(id) * 5.0, 0, TAU, 48, Balance.PLAYER_COLORS[id], 2, true)

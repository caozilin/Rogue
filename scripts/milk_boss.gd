extends "res://scripts/final_boss.gd"
## Third finale: one boss instance, two finite health bars, no reward on first defeat.
const Visuals = preload("res://scripts/milk_visuals.gd")
const DRAGON_CYCLE := ["belly", "cream", "disco", "royal"]
const FROG_CYCLE := ["hop", "tongue", "bubble", "lotus"]
const DRAGON_SMALL := ["milk_claw", "mini_spit", "short_bump"]
const FROG_SMALL := ["frog_sweep", "bubble_spit", "little_hop"]
const MAJOR_INTERVAL := 12.0
const MILK_MODULES := {
	"belly": {"name": "肚皮霸体 · 三连弹撞", "windup": 0.42, "recover": 0.85},
	"cream": {"name": "奶油吐息 · 摇头喷射", "windup": 0.55, "recover": 1.0},
	"disco": {"name": "骚包银河 · 金奶流星", "windup": 0.5, "recover": 1.1},
	"royal": {"name": "本龙登场 · 双人奶爆", "windup": 0.65, "recover": 1.25},
	"hop": {"name": "奶蛙三连 · 蛙跳砸场", "windup": 0.30, "recover": 0.7},
	"tongue": {"name": "舔屏追魂 · 双人舌鞭", "windup": 0.4, "recover": 1.15},
	"bubble": {"name": "蛙王泡泡 · 全屏蹦迪", "windup": 0.48, "recover": 0.9},
	"lotus": {"name": "荷塘天罚 · 奶蛙核爆", "windup": 0.6, "recover": 1.25},
	"milk_claw": {"name": "奶爪拍击", "windup": 0.28, "recover": 0.7},
	"mini_spit": {"name": "奶滴连射", "windup": 0.24, "recover": 0.85},
	"short_bump": {"name": "短距顶撞", "windup": 0.26, "recover": 0.9},
	"frog_sweep": {"name": "蛙掌横扫", "windup": 0.24, "recover": 0.75},
	"bubble_spit": {"name": "三连泡泡", "windup": 0.22, "recover": 0.8},
	"little_hop": {"name": "轻跃踩踏", "windup": 0.28, "recover": 0.9}
}
const FIRST_HP := 65000.0
const SECOND_HP := 85000.0
const REBIRTH_TIME := 2.4
signal milk_volley(source, pattern: String, direction: Vector2, index: int)
signal milk_bombs(source, points: Array[Vector2], lotus: bool)
signal rebirth_started(source)
signal clones_requested(source)
signal skill_announced(title: String, detail: String, body: int, pose: String)
signal rage_announced(title: String, detail: String, body: int, pose: String)
var major_remaining := MAJOR_INTERVAL
var major_step := 0
var rage_followup := false
var presentation: Node2D
var clones_summoned := false
var expression := "idle"
var form := 1
var second_life_hp := SECOND_HP
var rebirth_remaining := 0.0
var visual_system: Node2D
var leap_origin := Vector2.ZERO
var leap_remaining := 0.0
var leaps_left := 0
var barrage_left := 0
var barrage_index := 0
var barrage_timer := 0.0
var beam_left := 0
var beam_timer := 0.0
var aim_origin := Vector2.RIGHT
var locked_milk_points: Array[Vector2] = []
var spin := 0.0

func _ready() -> void:
	super._ready()
	visual_system = Visuals.new()
	visual_system.boss = self
	add_child(visual_system)

func is_milk_boss() -> bool:
	return true

func display_name() -> String:
	return "不灭奶龙 · 宇宙奶霸" if form == 1 else "暴走奶蛙 · 荷塘主宰"

func phase_name() -> String:
	if state == "rebirth": return "第一命击破 · 奶蛙 %.1fs 后重生" % rebirth_remaining
	return "第 %d / 2 条命 · %s" % [form, ["嚣张", "暴走", "极限蹦迪"][phase - 1]]

func setup_boss(spawn: Vector2, tuning: Dictionary, reward: int) -> void:
	super.setup_boss(spawn, tuning, reward)
	hp = FIRST_HP
	max_hp = hp
	damage = 140.0
	speed = 290.0
	radius = 48.0
	level = 25
	boss_attack = "belly"
	attack_cooldown = 0.75

func hit(amount: float) -> bool:
	if dead or state == "rebirth": return false
	var factor := 1.5 if state == "recover" else (0.5 if state == "leap" else 0.7)
	hp = maxf(0.0, hp - amount * factor)
	hit_flash = 0.1
	if hp <= 0.0:
		if form == 1:
			state = "rebirth"
			expression = "laugh"
			skill_announced.emit("第一命击破 · 奶蛙重生！", "别急着庆祝 · 第二条命即将满血降临", 2, "laugh")
			rebirth_remaining = REBIRTH_TIME
			leap_remaining = 0.0
			visual_system.effects.clear()
			visual_system.effect("rebirth", {"position": position, "radius": 250.0}, REBIRTH_TIME)
			rebirth_started.emit(self)
			queue_redraw()
			return false
		dead = true
		return true
	var next_phase := 3 if hp <= max_hp * 0.3 else (2 if hp <= max_hp * 0.6 else 1)
	if next_phase > phase:
		phase = next_phase
		enraged = true
		major_remaining = 0.0
		rage_followup = true # One immediate major after entering rage, not a permanent bypass.
		rage_announced.emit("%s狂暴 · %s！" % ["奶龙" if form == 1 else "奶蛙", "极限蹦迪" if phase == 3 else "暴走觉醒"], "阶段切换 · 下一个大招立即就绪",form,"laugh")
		visual_system.effect("crown", {"position": position, "radius": 160.0}, 0.7)
	if form == 2 and hp <= max_hp * 0.5 and not clones_summoned:
		clones_summoned = true
		expression = "laugh"
		clones_requested.emit(self)
		skill_announced.emit("奶蛙复制军团 · 全员登场！", "50% 血量召唤 4 个弱化分身 · 优先清理", 2, "laugh")
		visual_system.effect("lily", {"position":position,"radius":260.0}, 1.0)
	return false

func set_priority_target(target: Node2D, forced: bool) -> void:
	# The shared enemy API supplies priority_target_id; milk attacks own their targeting.
	priority_target_id = int(target.get_instance_id()) if forced and target != null else -1
	if forced and target != null and state == "windup" and boss_attack != "tongue": duel_target = target

func _finish_milk() -> void:
	state = "recover"
	attack_step += 1
	attack_cooldown = float(MILK_MODULES[boss_attack].recover) * (1.0 - 0.09 * (attack_phase - 1))

func _start_milk(target: Node2D, module := "") -> void:
	var cycle: Array = DRAGON_CYCLE if form == 1 else FROG_CYCLE
	var small: Array = DRAGON_SMALL if form == 1 else FROG_SMALL
	var can_present: bool = presentation == null or presentation.interval_remaining <= 0.0 or rage_followup
	boss_attack = module if not module.is_empty() else (cycle[major_step % cycle.size()] if major_remaining == 0.0 and can_present else small[attack_step % small.size()])
	var major := boss_attack in cycle
	if major:
		major_remaining = MAJOR_INTERVAL
		major_step += 1
	attack_phase = phase
	duel_target = target
	attack_direction = position.direction_to(target.position)
	if attack_direction == Vector2.ZERO: attack_direction = Vector2.RIGHT
	aim_origin = attack_direction
	windup_duration = float(MILK_MODULES[boss_attack].windup) * (1.0 - 0.10 * (attack_phase - 1))
	attack_windup = windup_duration
	locked_milk_points.clear()
	for player in combat_players:
		if player.is_targetable(): locked_milk_points.append(player.position)
	if boss_attack == "lotus":
		locked_milk_points.append(Balance.ARENA.get_center())
	state = "windup"
	expression = "tongue" if boss_attack in ["cream", "tongue", "mini_spit", "bubble_spit"] else ("laugh" if boss_attack in ["disco", "royal", "bubble", "lotus"] else "idle")
	if major:
		if rage_followup:
			rage_announced.emit(str(MILK_MODULES[boss_attack].name),status_text().split(" · ")[-1],form,expression)
			rage_followup = false
		else:
			skill_announced.emit(str(MILK_MODULES[boss_attack].name),status_text().split(" · ")[-1],form,expression)
	visual_system.effect("charge", {"position": position, "radius": 90.0 if major else 48.0}, windup_duration)

func _prepare_bump(target: Node2D) -> void:
	attack_direction = position.direction_to(target.position)
	if attack_direction == Vector2.ZERO: attack_direction = Vector2.RIGHT
	dash_endpoint = _inside_arena(position + attack_direction * minf(220.0 if boss_attack == "short_bump" else 430.0, position.distance_to(target.position) + 95.0))
	strike_hits.clear()
	state = "bump"
	visual_system.effect("crown", {"position": position, "radius": 95.0}, 0.35)

func _prepare_leap(target: Node2D) -> void:
	leap_origin = position
	dash_endpoint = _inside_arena(position+(target.position-position).limit_length(260.0)) if boss_attack == "little_hop" else _inside_arena(target.position)
	leap_remaining = 0.32
	state = "leap"
	visual_system.effect("lily", {"position": dash_endpoint, "radius": 95.0 if boss_attack == "little_hop" else 155.0}, 0.32)

func _execute_milk(target: Node2D) -> void:
	match boss_attack:
		"milk_claw", "frog_sweep":
			attack_direction = position.direction_to(target.position)
			if attack_direction == Vector2.ZERO: attack_direction = Vector2.RIGHT
			var reach := 125.0 if boss_attack == "milk_claw" else 150.0
			strike_hits.clear()
			melee_strike.emit(self,"sector",position,position,attack_direction,reach,1.0,0.55 if form == 1 else 0.5)
			visual_system.effect("swipe",{"position":position,"direction":attack_direction,"radius":reach},0.35)
			_finish_milk()
		"mini_spit", "bubble_spit":
			var aim := position.direction_to(target.position)
			if aim == Vector2.ZERO: aim = Vector2.RIGHT
			milk_volley.emit(self,boss_attack,aim,0)
			visual_system.effect("nova",{"position":position,"radius":65.0},0.3)
			_finish_milk()
		"belly", "short_bump":
			leaps_left = 1 if boss_attack == "short_bump" else 3
			_prepare_bump(target)
		"hop", "little_hop":
			leaps_left = 1 if boss_attack == "little_hop" else 3
			_prepare_leap(target)
		"cream":
			state = "beam"
			beam_left = 12 + attack_phase * 2
			beam_timer = 0.0
		"disco", "bubble":
			state = "barrage"
			barrage_left = 3 + attack_phase
			barrage_index = 0
			barrage_timer = 0.0
		"royal", "lotus":
			milk_bombs.emit(self, locked_milk_points, boss_attack == "lotus")
			visual_system.effect("crown", {"position": position, "radius": 170.0}, 0.65)
			_finish_milk()
		"tongue":
			for player in combat_players:
				if not player.is_targetable(): continue
				duel_target = player
				strike_hits.clear()
				melee_strike.emit(self, "lock", position, player.position, position.direction_to(player.position), 0.0, 0.0, 1.15)
				visual_system.effect("tongue", {"position": position + Vector2(10, -135), "end": player.position, "radius": 30.0}, 0.6)
			_finish_milk()

func advance(delta: float, target: Node2D) -> void:
	if dead: return
	major_remaining = maxf(0.0,major_remaining-delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	spin += delta
	visual_system.advance(delta)
	if state == "rebirth":
		rebirth_remaining = maxf(0.0, rebirth_remaining - delta)
		if rebirth_remaining == 0.0:
			form = 2
			hp = second_life_hp
			max_hp = hp
			damage = 165.0
			speed = 355.0
			phase = 1
			enraged = false
			attack_step = 0
			major_step = 0
			major_remaining = MAJOR_INTERVAL
			rage_followup = false
			state = "recover"
			expression = "idle"
			attack_cooldown = 0.65
			visual_system.effect("lily", {"position": position, "radius": 240.0}, 0.9)
		queue_redraw()
		return
	if target == null: return
	var movement_delta := delta * movement_scale
	var attack_delta := delta * attack_scale
	match state:
		"enter":
			position = position.move_toward(_inside_arena(target.position), speed * movement_delta)
			if Balance.ARENA.grow(-radius - 8).has_point(position): state = "approach"
		"approach":
			position = _inside_arena(position.move_toward(target.position, speed * movement_delta))
			attack_cooldown = maxf(0.0, attack_cooldown - attack_delta)
			if attack_cooldown == 0.0: _start_milk(target)
		"windup":
			attack_windup = maxf(0.0, attack_windup - attack_delta)
			if attack_windup == 0.0: _execute_milk(target)
		"bump":
			var before := position
			position = position.move_toward(dash_endpoint, (1000.0 if boss_attack == "short_bump" else 1400.0 + attack_phase * 90.0) * movement_delta)
			melee_strike.emit(self, "dash", before, position, attack_direction, radius + 14.0, 0.0, 0.75 if boss_attack == "short_bump" else 1.3)
			visual_system.effect("trail", {"position": before, "end": position, "radius": 40.0 if boss_attack == "short_bump" else 65.0}, 0.32)
			if position.is_equal_approx(dash_endpoint):
				leaps_left -= 1
				if leaps_left <= 0: _finish_milk()
				else:
					state = "bump_gap"
					attack_cooldown = 0.18
		"bump_gap":
			attack_cooldown = maxf(0.0, attack_cooldown - attack_delta)
			if attack_cooldown == 0.0: _prepare_bump(target)
		"leap":
			leap_remaining = maxf(0.0, leap_remaining - attack_delta)
			position = leap_origin.lerp(dash_endpoint, 1.0 - leap_remaining / 0.32)
			if leap_remaining == 0.0:
				strike_hits.clear()
				melee_strike.emit(self, "circle", position, position, Vector2.RIGHT, 95.0 if boss_attack == "little_hop" else 155.0, 0.0, 0.7 if boss_attack == "little_hop" else 1.55)
				visual_system.effect("splash", {"position": position, "radius": 130.0 if boss_attack == "little_hop" else 190.0}, 0.75)
				leaps_left -= 1
				if leaps_left <= 0: _finish_milk()
				else:
					state = "hop_gap"
					attack_cooldown = 0.16
		"hop_gap":
			attack_cooldown = maxf(0.0, attack_cooldown - attack_delta)
			if attack_cooldown == 0.0: _prepare_leap(target)
		"beam":
			beam_timer -= attack_delta
			while beam_left > 0 and beam_timer <= 0.0:
				attack_direction = aim_origin.rotated(sin((14 + attack_phase * 2 - beam_left) * 0.32) * 0.65)
				var mouth := position + Vector2(15, -125)
				var end := mouth + attack_direction * 1600.0
				strike_hits.clear()
				melee_strike.emit(self, "dash", mouth, end, attack_direction, 28.0, 0.0, 0.6)
				visual_system.effect("beam", {"position": mouth, "end": end, "radius": 28.0}, 0.22)
				beam_left -= 1
				beam_timer += 0.12
			if beam_left <= 0: _finish_milk()
		"barrage":
			barrage_timer -= attack_delta
			while barrage_left > 0 and barrage_timer <= 0.0:
				milk_volley.emit(self, boss_attack, aim_origin, barrage_index)
				visual_system.effect("nova", {"position": position, "radius": 200.0}, 0.55)
				barrage_index += 1
				barrage_left -= 1
				barrage_timer += 0.22
			if barrage_left <= 0: _finish_milk()
		"recover":
			attack_cooldown = maxf(0.0, attack_cooldown - attack_delta)
			if attack_cooldown == 0.0:
				state = "approach"
				expression = "idle"
	queue_redraw()

func status_text() -> String:
	if state == "rebirth": return "别急着庆祝！奶龙破壳，奶蛙即将满血复活 · 重生期间无敌"
	if state == "enter": return "隐藏终局 · 两条命 · 近战追杀 + 全场远程压制"
	if state == "recover": return "骚包收招 · 受到伤害增加 50% · 趁机集火！"
	var major: bool = boss_attack in DRAGON_CYCLE or boss_attack in FROG_CYCLE
	return str(MILK_MODULES[boss_attack].name) + (" · 双人锁头，准备防御" if boss_attack == "tongue" else (" · 高伤连击，保留无敌与护盾" if major else " · 常规攻击，直接释放"))

func _draw() -> void:
	Art.shadow(self, Vector2(5, 18), Vector2(175, 63), 0.85)
	var texture := Art.milk_character(form, expression)
	var jump := sin((1.0 - leap_remaining / 0.32) * PI) * 125.0 if state == "leap" else 0.0
	var bounce := sin(spin * (15.0 if expression == "laugh" else 6.0)) * (7.0 if expression == "laugh" else 4.0)
	var size := Vector2(220, 230) if form == 1 else Vector2(245, 220)
	var scale := 0.8 + sin((1.0 - rebirth_remaining / REBIRTH_TIME) * PI) * 0.25 if state == "rebirth" else 1.0
	if texture != null:
		motion.render(texture, Rect2(Vector2(-size.x / 2, -size.y * 0.85), size), Color(1.2, 1.15, 0.9) if hit_flash > 0.0 else Color.WHITE, 1, Vector2(0, -jump + bounce), scale)
	else:
		draw_circle(Vector2(0, -55 - jump), 72.0, Color("ffd859"))
	if visual_system != null: visual_system.refresh()

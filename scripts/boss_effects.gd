extends Node2D
## Bounded combat effects driven only by simulation time; no extra damage here.
const Art = preload("res://scripts/art.gd")
const FinalBoss = preload("res://scripts/final_boss.gd")
const RangedBoss = preload("res://scripts/ranged_final_boss.gd")
const ENERGY_SHADER = preload("res://assets/effects/boss_energy.gdshader")
var game
var effects: Array[Dictionary] = []
var surfaces: Array[Sprite2D] = []

func _ready() -> void:
	z_index = 5
	for index in range(24):
		var sprite := Sprite2D.new()
		sprite.texture = Art.white()
		var material := ShaderMaterial.new()
		material.shader = ENERGY_SHADER
		sprite.material = material
		sprite.visible = false
		add_child(sprite)
		surfaces.append(sprite)

func refresh() -> void:
	var index := 0
	for item in effects:
		if item.kind not in ["slash", "slam", "lock"] or index >= surfaces.size(): continue
		var sprite := surfaces[index]
		sprite.visible = true
		sprite.position = item.position
		sprite.rotation = item.direction.angle() if item.kind == "slash" else 0.0
		sprite.scale = Vector2.ONE * float(item.radius) * 2.8 / 32.0
		sprite.material.set_shader_parameter("mode", 0 if item.kind == "slash" else (1 if item.kind == "slam" else 2))
		sprite.material.set_shader_parameter("progress", 1.0 - float(item.life) / float(item.duration))
		sprite.material.set_shader_parameter("effect_time", game.elapsed)
		sprite.material.set_shader_parameter("tint", Color("ff4275") if item.kind == "lock" else item.color)
		index += 1
	for extra in range(index, surfaces.size()): surfaces[extra].visible = false

func emit_effect(kind: String, data: Dictionary, duration := 0.45) -> void:
	if effects.size() >= 100: effects.pop_front()
	data.kind = kind
	data.life = duration
	data.duration = duration
	effects.append(data)
	refresh()
	queue_redraw()

func advance(delta: float) -> void:
	for item in effects: item.life -= delta
	effects = effects.filter(func(item): return item.life > 0.0)
	refresh()
	queue_redraw()

func observe(boss, before: Vector2) -> void:
	if boss.has_method("is_milk_boss"): return
	if not boss is FinalBoss or boss.dead: return
	if boss.boss_attack in ["blink", "judgment"] and boss.state in ["blink_reveal", "recover"] and before.distance_to(boss.position) > 80.0:
		var color := Color("da9bff") if boss.boss_attack == "blink" else Color("ff749a")
		for at in [before, boss.position]: emit_effect("rift", {"position": at, "color": color}, 0.45)
	if boss.state in ["rush", "dash"] and before.distance_to(boss.position) > 2.0:
		emit_effect("trail", {"position": before, "end": boss.position, "color": Color("a6e7ff"), "radius": boss.radius}, 0.22)

func _glow(at: Vector2, radius: float, color: Color, alpha: float) -> void:
	draw_texture_rect(Art.glow(), Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, Color(color, alpha))

func _sparks(at: Vector2, radius: float, progress: float, color: Color, count := 20) -> void:
	for index in range(count):
		var direction := Vector2.from_angle(index * 2.399)
		var length := radius * (0.45 + fposmod(index * 0.37, 0.55))
		var tip := at + direction * length * progress
		draw_line(tip - direction * 15.0, tip, Color(color, 1.0 - progress), 2.0, true)
		_glow(tip, 10.0, color, (1.0 - progress) * 0.3)

func _blade(at: Vector2, direction: Vector2, radius: float, progress: float, color: Color) -> void:
	# An actual sweeping sword arc, with a broad luminous wake and narrow cutting edge.
	var head := direction.angle() - 1.35 + minf(1.0, progress * 2.8) * 2.7
	for layer in range(3):
		var points := PackedVector2Array()
		for index in range(25):
			var angle := head - 1.05 + index / 24.0 * 1.05
			points.append(at + Vector2.from_angle(angle) * radius * (1.0 - layer * 0.06))
		draw_polyline(points, Color(color, (1.0 - progress) * (0.20 if layer == 0 else 0.8)), 19.0 if layer == 0 else 4.0, true)
	var tip := at + Vector2.from_angle(head) * radius
	draw_line(at + Vector2.from_angle(head) * 30.0, tip, Color(1.0, 0.96, 0.85, 1.0 - progress), 3.0, true)
	_glow(tip, 45.0, color, (1.0 - progress) * 0.6)

func _draw() -> void:
	if game == null: return
	var time: float = game.elapsed
	var boss = game.mini_boss
	if is_instance_valid(boss) and boss is FinalBoss and not boss.dead and not boss.has_method("is_milk_boss"):
		var at: Vector2 = boss.position + Vector2(0, -45)
		var ranged: bool = boss is RangedBoss
		var color := Color("c3a3ff") if ranged else Color("ffc28e")
		if boss.state in ["windup", "combo_windup", "blink_reveal"]:
			var charge := 1.0 - float(boss.attack_windup) / float(boss.windup_duration)
			_glow(at, 80.0 + charge * 35, color, 0.12 + charge * 0.18)
			for index in range(16):
				var phase := fposmod(index * 0.618 + time * 1.5, 1.0)
				var direction := Vector2.from_angle(index * 2.399 + time)
				var tip := at + direction * (80.0 * (1.0 - phase) + 10.0)
				draw_line(tip + direction * 10.0, tip, Color(color, phase * 0.85), 2.0, true)
			if ranged:
				for side in [-1, 1]:
					var muzzle: Vector2 = boss.position + Vector2(side * 70, -27) + boss.attack_direction * 42
					_glow(muzzle, 25.0 + charge * 22.0, color, 0.4)
					for orbit in range(3):
						draw_arc(muzzle, 16.0 + orbit * 7.0, time * 6.0 + orbit, time * 6.0 + orbit + PI * 1.3, 24, Color(color, 0.5), 2.0, true)
			else:
				var aim: Vector2 = boss.attack_direction.rotated(-1.3 + charge * 0.4)
				var grip := at + aim * 35.0
				var tip := at + aim * (100.0 + charge * 30.0)
				draw_line(grip, tip, Color(color, 0.2), 18.0, true)
				draw_line(grip, tip, Color("ffe9c3"), 5.0, true)
				_glow(tip, 28.0 + charge * 18.0, color, 0.5)
			if boss.boss_attack == "judgment" and is_instance_valid(boss.duel_target) and boss.duel_target.is_targetable():
				var mark: Vector2 = boss.duel_target.position + Vector2(0, -16)
				_glow(mark, 70.0, Color("ff3a72"), 0.24)
				draw_line(at, mark, Color(1.0, 0.25, 0.4, 0.45), 2.0, true)
				for index in range(4):
					var direction := Vector2.from_angle(time * 5 + index * PI / 2)
					draw_line(mark + direction * (65.0 - charge * 30.0), mark + direction * 20, Color("ff7495"), 4, true)
			if boss.boss_attack == "storm":
				for index in range(24):
					var tip: Vector2 = game.Balance.ARENA.position + Vector2(index / 23.0 * game.Balance.ARENA.size.x, 6.0)
					_glow(tip, 24.0, Color("dcb5ff"), 0.45)
					draw_line(tip, tip + Vector2(0, 18 + charge * 26), Color("dfa7ff"), 3.0, true)
		if boss.transition_flash > 0.0:
			_sparks(at, 160, 1.0 - boss.transition_flash, Color("ff9370"))
		if boss.state == "dash":
			_blade(boss.position, boss.attack_direction, 100.0, fposmod(time * 3.0, 0.65), Color("a6eeff"))
	for item in effects:
		var progress := 1.0 - float(item.life) / float(item.duration)
		var fade := 1.0 - progress
		var at: Vector2 = item.position
		var color: Color = item.get("color", Color("ffcc86"))
		match str(item.kind):
			"rift":
				_glow(at + Vector2(0, -40), 95.0, color, fade * 0.45)
				for index in range(5):
					var x := (index - 2) * 8.0
					draw_line(at + Vector2(x, 18), at + Vector2(x * 0.4, -140.0 * sin(progress * PI)), Color(color, fade * 0.8), 3.0, true)
				_sparks(at, 90.0, progress, color, 18)
			"slash":
				_blade(at, item.direction, float(item.radius), progress, color)
				_sparks(at + item.direction * 50.0, float(item.radius) * 0.8, progress, color, 10)
			"lock":
				_glow(at, 150.0, Color("ff4275"), fade * 0.55)
				for side in [-1, 1]:
					var direction := Vector2(1, side * 0.8).normalized()
					var reach := 170.0 * minf(1.0, progress * 5.0)
					draw_line(at - direction * reach, at + direction * reach, Color(1.0, 0.15, 0.35, fade * 0.3), 24.0, true)
					draw_line(at - direction * reach, at + direction * reach, Color(1.0, 0.9, 0.95, fade), 4.0, true)
				_blade(at, Vector2.RIGHT, 115.0, progress, Color("ff517b"))
				_sparks(at, 190.0, progress, Color("ff9bba"), 26)
			"slam":
				var radius: float = item.radius
				_glow(at, radius, color, fade * 0.4)
				for layer in range(3):
					draw_arc(at, radius * clampf(progress * 2.0 - layer * 0.15, 0.05, 1.1), 0, TAU, 64, Color(color, fade * 0.85), 7.0 - layer * 2.0, true)
				for index in range(12):
					var aim := Vector2.from_angle(index * TAU / 12.0)
					var cracks := PackedVector2Array([at + aim * 15, at + aim.rotated(0.12) * radius * 0.4, at + aim.rotated(-0.06) * radius * 0.65, at + aim * radius * minf(1.0, progress * 3.0)])
					draw_polyline(cracks, Color("fff1ce", fade), 3.0, true)
				_sparks(at, radius * 1.3, progress, color, 30)
			"trail":
				draw_line(at, item.end, Color(color, fade * 0.35), float(item.radius) * 1.3, true)
				for offset in [-20.0, 0.0, 20.0]:
					var direction: Vector2 = at.direction_to(item.end)
					draw_line(at + direction.orthogonal() * offset, item.end + direction.orthogonal() * offset, Color(color, fade * 0.7), 2.0, true)
			"volley":
				_glow(at + Vector2(0, -25), 115.0, color, fade * 0.3)
				_sparks(at, 125.0, progress, color, 24)
				if item.module in ["halo", "storm"]:
					draw_arc(at, 40.0 + progress * 150.0, 0, TAU, 64, Color(color, fade), 4.0, true)
				else:
					for side in [-1, 1]:
						var muzzle := at + Vector2(side * 70, -27)
						draw_line(muzzle, muzzle + item.direction * (65 + progress * 90), Color(color, fade * 0.8), 6.0, true)
			"launch":
				for index in range(6):
					var base := at + Vector2((index - 2.5) * 18, -30)
					var tip := base + Vector2(sin(index) * progress * 70, -progress * 190)
					draw_line(tip + Vector2(0, 55), tip, Color(color, fade * 0.65), 4, true)
					_glow(tip, 22.0, color, fade * 0.5)

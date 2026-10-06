extends Node2D
## Every effect is visual only, bounded and driven by the gameplay clock.
const Art = preload("res://scripts/art.gd")
const SHADER = preload("res://assets/effects/milk.gdshader")
var boss
var effects: Array[Dictionary] = []
var surfaces: Array[Sprite2D] = []

func _ready() -> void:
	z_index = 6
	for index in range(16):
		var sprite := Sprite2D.new()
		sprite.texture = Art.white()
		var material := ShaderMaterial.new()
		material.shader = SHADER
		sprite.material = material
		sprite.hide()
		add_child(sprite)
		surfaces.append(sprite)

func effect(kind: String, data: Dictionary, duration := 0.5) -> void:
	if effects.size() >= 80: effects.pop_front()
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

func refresh() -> void:
	var used := 0
	for item in effects:
		if item.kind not in ["beam", "splash", "nova", "lily", "rebirth"] or used >= surfaces.size(): continue
		var sprite := surfaces[used]
		sprite.show()
		sprite.position = item.position - boss.position
		var size := Vector2.ONE * float(item.radius) * 2.8
		sprite.rotation = 0.0
		if item.kind == "beam":
			var end: Vector2 = item.end
			sprite.position += (end - item.position) * 0.5
			sprite.rotation = (end - item.position).angle()
			size = Vector2((end - item.position).length(), float(item.radius) * 4.0)
		sprite.scale = size / 32.0
		sprite.material.set_shader_parameter("mode", 0 if item.kind == "beam" else (1 if item.kind == "lily" else 2))
		sprite.material.set_shader_parameter("progress", 1.0 - float(item.life) / float(item.duration))
		sprite.material.set_shader_parameter("effect_time", boss.spin)
		sprite.material.set_shader_parameter("tint", Color("a5ff90") if boss.form == 2 else Color("ffcf57"))
		used += 1
	for extra in range(used, surfaces.size()): surfaces[extra].hide()

func star(at: Vector2, radius: float, color: Color, angle := 0.0) -> void:
	var points := PackedVector2Array()
	for index in range(10): points.append(at + Vector2.from_angle(angle + index * PI / 5.0) * radius * (1.0 if index % 2 == 0 else 0.42))
	draw_colored_polygon(points, color)

func _draw() -> void:
	if boss.dead: return
	var color := Color("ffd75a") if boss.form == 1 else Color("96ff94")
	# Rotating stage lights and a floating, bouncing crown make the boss conspicuous.
	for index in range(8):
		var at := Vector2.from_angle(boss.spin * 1.8 + index * TAU / 8.0) * Vector2(100, 38) + Vector2(0, 12)
		star(at, 7.0, Color(color, 0.7), boss.spin)
	var crown := Vector2(0, -190 + sin(boss.spin * 4.0) * 7.0)
	draw_texture_rect(Art.glow(), Rect2(crown - Vector2(60, 35), Vector2(120, 70)), false, Color(color, 0.6))
	draw_colored_polygon(PackedVector2Array([crown+Vector2(-26,12),crown+Vector2(-31,-14),crown+Vector2(-13,-2),crown+Vector2(0,-24),crown+Vector2(13,-2),crown+Vector2(31,-14),crown+Vector2(26,12)]), Color("ffdb6a"))
	for item in effects:
		var at: Vector2 = item.position - boss.position
		var p := clampf(1.0 - float(item.life) / float(item.duration), 0.0, 1.0)
		var fade := 1.0 - p
		var radius: float = item.radius
		match item.kind:
			"swipe":
				var angle: float = item.direction.angle()
				for layer in range(3):
					draw_arc(at,radius-layer*9,angle-1.0,angle+1.0,32,Color(color,fade*(1-layer*0.2)),5-layer,true)
				for side in [-1,1]: star(at+Vector2.from_angle(angle+side)*radius,12*fade,Color("fff7ce",fade),boss.spin)
			"tongue":
				var end: Vector2 = item.end - boss.position
				var line := PackedVector2Array()
				for index in range(24):
					var u := index / 23.0
					line.append(at.lerp(end, u * minf(1.0, p * 8.0)) + (end-at).normalized().orthogonal() * sin(u*PI*3-boss.spin*12)*sin(u*PI)*12)
				draw_polyline(line, Color("77344e"), 34 * fade + 4, true)
				draw_polyline(line, Color("ff789e"), 26 * fade + 3, true)
				draw_polyline(line, Color("ffd1dc"), 7 * fade + 1, true)
				star(end, 38 * fade, Color("fff1b9"), boss.spin)
			"trail":
				draw_line(at, item.end-boss.position, Color(color, fade * 0.3), radius, true)
				star(at, 23 * fade, Color("fff4c5"), boss.spin)
			"charge", "crown":
				var r := radius * (1.0 - p * 0.6) if item.kind == "charge" else radius * (0.3+p)
				draw_arc(at, r, 0, TAU, 64, Color(color, fade), 3, true)
				for index in range(8): star(at+Vector2.from_angle(index*TAU/8+boss.spin)*r, 10*fade+3, Color("ff96c9"), boss.spin)
			"rebirth":
				for index in range(16):
					var dir := Vector2.from_angle(index*TAU/16+boss.spin*1.3)
					draw_line(at+dir*50, at+dir*radius*(0.5+p), Color(color, sin(p*PI)*0.7), 8, true)
				draw_arc(at, 110+sin(p*PI)*70, 0, TAU, 64, Color("fff7cc"), 5, true)
			"lily", "splash", "nova":
				for index in range(12):
					var direction := Vector2.from_angle(index*TAU/12+boss.spin*0.3)
					var particle := at+direction*radius*(0.3+p)
					if boss.form == 2:
						draw_set_transform(particle, direction.angle(), Vector2(2.1, 0.65))
						draw_circle(Vector2.ZERO, 14*fade+2, Color("ffa2dd", fade))
						draw_set_transform(Vector2.ZERO)
					else: star(particle, 18*fade+2, Color("fff0ba", fade), boss.spin)
				draw_arc(at, radius*clampf(p*2.0,0.05,1.05), 0, TAU, 72, Color(color,fade), 5*fade+1, true)

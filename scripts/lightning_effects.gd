extends Node2D
## Pending impacts and traveling rings outlive their tower; only simulation advances them.
const Art = preload("res://scripts/art.gd")
const WAVE_SHADER = preload("res://assets/effects/lightning_wave.gdshader")
const MAX_VISUALS := 128
var game
var events: Array[Dictionary] = []
var rulings: Array[Dictionary] = []
var waves: Array[Dictionary] = []
var tags: Dictionary = {}
var wave_sprites: Array[Sprite2D] = []

func _ready() -> void:
	z_index = 3
	for index in range(32):
		var sprite := Sprite2D.new()
		sprite.texture = Art.white()
		var material := ShaderMaterial.new()
		material.shader = WAVE_SHADER
		sprite.material = material
		sprite.visible = false
		add_child(sprite)
		wave_sprites.append(sprite)

func on_screen(enemy) -> bool:
	return not enemy.dead and game.get_viewport_rect().has_point(game.get_global_transform_with_canvas() * enemy.position)

func effect(kind: String, data: Dictionary, duration: float) -> void:
	if events.size() >= MAX_VISUALS:
		events.pop_front()
	data.kind = kind
	data.life = duration
	data.duration = duration
	events.append(data)

func tag(target, count: int, total: int, judgment := false) -> void:
	var key := str(target.get_instance_id()) + ("j" if judgment else "c")
	if tags.size() >= 96 and not tags.has(key):
		tags.erase(tags.keys()[0])
	tags[key] = {"ref": weakref(target), "count": count, "total": total, "judgment": judgment, "life": 1.2}

func ruling(target, damage: float, owner: int, judgment: bool, splash := 0.0) -> void:
	rulings.append({"ref": weakref(target), "position": target.position, "damage": damage,
		"owner": owner, "judgment": judgment, "splash": splash,
		"wait": 0.65 if judgment else 0.22, "duration": 0.65 if judgment else 0.22})

func wave(center: Vector2, damage: float, owner: int, final_wave := false, detonation := false) -> void:
	var extent := 1.0
	var rect: Rect2 = game.get_viewport_rect()
	var inverse: Transform2D = game.get_global_transform_with_canvas().affine_inverse()
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		extent = maxf(extent, center.distance_to(inverse * corner) + 35.0)
	waves.append({"position": center, "damage": damage, "owner": owner, "final": final_wave,
		"detonation": detonation, "extent": extent, "age": 0.0, "duration": 0.55 if final_wave else 0.95, "radius": 0.0, "hit": {}})
	effect("charge", {"position": center, "final": final_wave}, 0.45)
	if detonation:
		effect("detonation", {"position": center}, 0.7)

func advance(delta: float) -> void:
	for event in events:
		event.life -= delta
	events = events.filter(func(event): return event.life > 0.0)
	for key in tags.keys():
		tags[key].life -= delta
		var target = tags[key].ref.get_ref()
		if tags[key].life <= 0.0 or target == null or target.dead:
			tags.erase(key)
	for pending in rulings:
		var target = pending.ref.get_ref()
		if target == null or target.dead:
			pending.wait = -1.0
			continue
		pending.position = target.position
		pending.wait -= delta
		if pending.wait <= 0.00001:
			game._damage_enemy(target, pending.damage, pending.owner, true, "tower_judgment" if pending.judgment else "tower_chain")
			effect("judgment" if pending.judgment else "column", {"position": pending.position}, 0.7 if pending.judgment else 0.45)
			if pending.judgment:
				for nearby in game.enemies:
					if nearby != target and not nearby.dead and nearby.position.distance_squared_to(pending.position) <= pow(110.0 + nearby.radius, 2):
						game._damage_enemy(nearby, pending.splash, pending.owner, false, "tower_judgment")
			pending.wait = -1.0
	rulings = rulings.filter(func(pending): return pending.wait >= 0.0)
	for ring in waves:
		var previous: float = ring.radius
		ring.age += delta
		ring.radius = minf(1.0, ring.age / ring.duration) * ring.extent
		for enemy in game.enemies:
			var id: int = enemy.get_instance_id()
			if not on_screen(enemy) or ring.hit.has(id):
				continue
			var distance: float = enemy.position.distance_to(ring.position)
			if distance + enemy.radius < previous or distance - enemy.radius > ring.radius:
				continue
			ring.hit[id] = true
			game._damage_enemy(enemy, ring.damage, ring.owner, ring.detonation, "tower_tide")
			if not enemy.dead:
				effect("shock", {"ref": weakref(enemy), "position": enemy.position}, 0.35)
	waves = waves.filter(func(ring): return ring.age < ring.duration)
	refresh()

func refresh() -> void:
	for index in range(wave_sprites.size()):
		var sprite := wave_sprites[index]
		sprite.visible = index < waves.size()
		if not sprite.visible:
			continue
		var ring := waves[index]
		sprite.position = ring.position
		sprite.scale = Vector2.ONE * float(ring.extent) * 2.0 / 32.0
		sprite.material.set_shader_parameter("radius", float(ring.radius) / float(ring.extent))
		sprite.material.set_shader_parameter("extent", ring.extent)
		sprite.material.set_shader_parameter("effect_time", game.elapsed)
		sprite.material.set_shader_parameter("strength", minf(1.0, (1.0 - float(ring.age) / float(ring.duration)) * 5.0))
		sprite.material.set_shader_parameter("final_wave", 1.0 if ring.final else 0.0)
	queue_redraw()

func _bolt(start: Vector2, end: Vector2, color: Color, width: float, seed: float) -> void:
	var points := PackedVector2Array([start])
	var normal := start.direction_to(end).orthogonal()
	for index in range(1, 13):
		var along := float(index) / 13.0
		points.append(start.lerp(end, along) + normal * sin(seed + index * 8.3 + game.elapsed * 43.0) * 12.0 * sin(along * PI))
	points.append(end)
	draw_polyline(points, Color(color, color.a * 0.2), width * 4.0, true)
	draw_polyline(points, color, width, true)
	draw_polyline(points, Color(0.9, 0.99, 1.0, color.a), maxf(1.0, width * 0.35), true)

func _glyph(center: Vector2, radius: float, color: Color, rotation: float, sides := 6) -> void:
	var points := PackedVector2Array()
	for index in range(sides + 1):
		points.append(center + Vector2.from_angle(rotation + TAU * float(index) / sides) * radius * Vector2(1, 0.40))
	draw_polyline(points, color, 1.8, true)
	draw_set_transform(center, 0, Vector2(1, 0.4))
	draw_arc(Vector2.ZERO, radius * 1.2, 0, TAU, 64, color, 1.7, true)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	for ring in waves:
		var fade := minf(1.0, (1.0 - float(ring.age) / float(ring.duration)) * 5.0)
		for index in range(28):
			var angle: float = float(index) * TAU / 28.0 + game.elapsed * 0.10
			var at: Vector2 = ring.position + Vector2.from_angle(angle) * float(ring.radius)
			var height := 20.0 + 24.0 * absf(sin(index * 7.1 + game.elapsed * 13.0))
			_bolt(at, at - Vector2(3, height), Color(0.60, 0.62, 1.0, fade * 0.65), 1.4, index)
			draw_circle(at, 2.0, Color(0.87, 0.94, 1.0, fade * 0.8))
	for mark in tags.values():
		var target = mark.ref.get_ref()
		if target == null or target.dead:
			continue
		var at: Vector2 = target.position + Vector2(0, -target.radius * 2.8 - (22 if mark.judgment else 0))
		var color := Color("ffd98a") if mark.judgment else Color("7be7ff")
		_glyph(at, 15, Color(color, minf(1.0, mark.life * 4.0)), game.elapsed * (0.9 if mark.judgment else -1.0), 5 if mark.judgment else 6)
		draw_string_outline(ThemeDB.fallback_font, at + Vector2(-18, -10), "%d/%d" % [mark.count, mark.total], HORIZONTAL_ALIGNMENT_CENTER, 36, 12, 3, Color("11192e"))
		draw_string(ThemeDB.fallback_font, at + Vector2(-18, -10), "%d/%d" % [mark.count, mark.total], HORIZONTAL_ALIGNMENT_CENTER, 36, 12, color)
	for pending in rulings:
		var at: Vector2 = pending.position
		var progress := 1.0 - float(pending.wait) / float(pending.duration)
		if pending.judgment:
			var sky := at + Vector2(0, -175)
			_glyph(sky, 62.0 + progress * 15.0, Color(1.0, 0.82, 0.44, 0.85), game.elapsed * 1.1, 5)
			_glyph(sky, 42, Color(0.76, 0.52, 1.0, 0.70), -game.elapsed * 1.7, 3)
			draw_line(sky, at, Color(0.84, 0.65, 1.0, progress * 0.4), 1.5, true)
			Art.shadow(self, at, Vector2(90, 30), 0.3)
			_glyph(at, 32, Color(1.0, 0.80, 0.40, 0.75), -game.elapsed)
			for index in range(12):
				var angle: float = index * TAU / 12.0 + game.elapsed
				var mote := sky + Vector2.from_angle(angle) * (85.0 * (1.0 - progress) + 8.0)
				draw_circle(mote, 2.5, Color(1.0, 0.87, 0.62, 0.8))
			draw_texture_rect(Art.glow(), Rect2(sky - Vector2(35, 35), Vector2(70, 70)), false, Color(0.82, 0.65, 1.0, progress * 0.5))
		else:
			_glyph(at + Vector2(0, -65), 30.0 + progress * 12.0, Color(0.43, 0.87, 1.0, 0.8), game.elapsed * 3.0)
	for event in events:
		var fade: float = event.life / event.duration
		var age := 1.0 - fade
		match event.kind:
			"chain":
				_bolt(event.start, event.end, Color(0.45, 0.87, 1.0, fade), 2.5, float(event.get("seed", 0)))
				for branch in range(2):
					var start: Vector2 = event.start.lerp(event.end, 0.45 + branch * 0.25)
					var end: Vector2 = start + (event.end - event.start) * 0.15 + Vector2(-12, -28 if branch == 0 else 28)
					_bolt(start, end, Color(0.37, 0.70, 1.0, fade * 0.6), 1.0, branch + 7)
			"column", "judgment":
				var at: Vector2 = event.position
				var judgment: bool = event.kind == "judgment"
				var color := Color(1.0, 0.82, 0.48, fade) if judgment else Color(0.35, 0.76, 1.0, fade)
				var sky := at + Vector2(0, -maxf(210.0, at.y + 40.0))
				_bolt(sky, at, color, 14.0 if judgment else 8.0, 3)
				_bolt(sky + Vector2(30, 0), at, Color(0.62, 0.40, 1.0, fade * 0.6), 3.0, 2)
				if judgment:
					draw_colored_polygon(PackedVector2Array([at + Vector2(-13, -190), at + Vector2(0, 18), at + Vector2(13, -190)]), Color(1.0, 0.98, 0.85, fade * 0.85))
					_glyph(at + Vector2(0, -175), 75, Color(color, fade * 0.7), game.elapsed)
					draw_arc(at, 110.0 * age, 0, TAU, 72, Color(color, fade * 0.8), 5.0 * fade + 1.0, true)
					draw_arc(at, 85.0 * age, 0, TAU, 64, Color(0.71, 0.45, 1.0, fade * 0.8), 2, true)
				else:
					_glyph(at, 32.0 + age * 35.0, Color(color, fade * 0.7), game.elapsed)
				draw_texture_rect(Art.glow(), Rect2(at - Vector2(65, 45), Vector2(130, 90)), false, Color(color, fade * 0.40))
				for index in range(10):
					var direction := Vector2.from_angle(index * TAU / 10.0)
					var tip: Vector2 = at + direction * (20 + age * 75)
					draw_line(tip, tip + direction * 10, Color(color, fade), 2.0, true)
			"charge", "detonation":
				var at: Vector2 = event.position
				_glyph(at, (110.0 if event.kind == "detonation" else 65.0) * (0.5 + age), Color(0.70, 0.44, 1.0, fade * 0.8), -game.elapsed * 1.3)
				if event.kind == "detonation":
					_bolt(at + Vector2(0, -260), at, Color(0.70, 0.64, 1.0, fade), 14, 5)
					draw_texture_rect(Art.glow(), Rect2(at - Vector2(130, 130), Vector2(260, 260)), false, Color(0.65, 0.60, 1.0, fade * 0.3))
			"shock":
				var target = event.ref.get_ref()
				if target != null and not target.dead:
					_bolt(target.position + Vector2(-17, -30), target.position + Vector2(17, 5), Color(0.63, 0.46, 1.0, fade), 1.5, 4)

extends Node2D
## Distinct major cues: spectral recast, silver blade scars, crescent wave, cannon streaks,
## golden winged shelter and expanding quake/crack rings. No wall-clock animation.
const Art = preload("res://scripts/art.gd")
var system

func _ready() -> void:
	z_index = 4

func _glow(at: Vector2, radius: float, color: Color, strength: float) -> void:
	draw_texture_rect(Art.glow(), Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, Color(color, strength))

func _burst(at: Vector2, radius: float, progress: float, color: Color, spokes := 12) -> void:
	var fade := 1.0 - progress
	_glow(at, radius * 0.6, color, fade * 0.24)
	draw_arc(at, radius * (0.2 + progress * 0.8), 0, TAU, 64, Color(color, fade), 3.0, true)
	for index in range(spokes):
		var direction := Vector2.from_angle(TAU * index / float(spokes) + progress * 0.3)
		draw_line(at + direction * radius * progress * 0.55, at + direction * radius * progress, Color(color, fade * 0.8), 2.0, true)

func _draw() -> void:
	if system == null: return
	var time: float = system.game.elapsed
	for trail in system.blade_trails:
		var fade := minf(1.0, float(trail.life) / 0.16)
		var points: PackedVector2Array = trail.points
		var radius: float = trail.radius
		var owner_color: Color = system.game.Balance.PLAYER_COLORS[int(trail.owner)]
		draw_polyline(points, Color(0.75, 0.82, 0.93, fade * 0.08), radius * 2.0, true)
		draw_polyline(points, Color(0.94, 0.97, 1.0, fade * 0.35), 3, true)
		for segment in range(1, points.size()):
			var start := points[segment - 1]
			var end := points[segment]
			var direction := start.direction_to(end)
			var side := direction.orthogonal()
			for sign_side in [-1.0, 1.0]:
				draw_line(start + side * radius * sign_side, end + side * radius * sign_side, Color(owner_color, fade * 0.3), 1, true)
			var pieces := maxi(1, ceili(start.distance_to(end) / 35.0))
			for index in range(pieces):
				var phase := fposmod(time * 5.0 + (segment + index) * 0.43 + trail.owner * 0.3, 1.0)
				var at := start.lerp(end, (index + 0.5) / pieces) + side * sin(time * 33.0 + index * 2.1) * radius * 0.18
				var arc := PackedVector2Array()
				for step in range(9):
					var u := float(step) / 4.0 - 1.0
					arc.append(at + side * u * radius * 0.8 + direction * radius * 0.28 * (1.0 - u * u))
				draw_polyline(arc, Color(0.75, 0.86, 1.0, fade * (1.0 - phase) * 0.25), 9, true)
				draw_polyline(arc, Color(0.95, 0.98, 1.0, fade * (1.0 - phase)), 2, true)
				draw_line(at - direction * 16, at + direction * 16, Color(1, 1, 1, fade * (1.0 - phase) * 0.7), 1.3, true)
	for item in system.effects:
		var progress := 1.0 - float(item.life) / float(item.duration)
		var fade := 1.0 - progress
		match str(item.kind):
			"blade_finish":
				var points: PackedVector2Array = item.points
				var radius: float = item.radius
				draw_polyline(points, Color(0.93, 0.97, 1.0, fade * 0.22), radius * 2.4, true)
				draw_polyline(points, Color(1.0, 0.97, 0.85, fade), 7, true)
				for index in range(1, points.size()):
					var start := points[index - 1]
					var end := points[index]
					var direction := start.direction_to(end)
					var side := direction.orthogonal()
					var center := (start + end) * 0.5
					var span := radius * (0.5 + progress * 0.7)
					for sign_side in [-1.0, 1.0]:
						draw_line(center - side * span - direction * span * sign_side, center + side * span + direction * span * sign_side, Color(1.0, 0.98, 0.90, fade), 4, true)
					_glow(center, radius * 1.3, Color("eef5ff"), fade * 0.3)
				var center := points[points.size() / 2]
				draw_string_outline(ThemeDB.fallback_font, center + Vector2(-25, -radius - 58), "处决", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 4, Color(0.06, 0.08, 0.1, fade))
				draw_string(ThemeDB.fallback_font, center + Vector2(-25, -radius - 58), "处决", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.94, 0.73, fade))
			"dash":
				var start: Vector2 = item.start
				var end: Vector2 = item.end
				var direction := start.direction_to(end)
				var color := Color("b7edff") if bool(item.second) else Color("d2d8e8")
				var radius: float = item.radius
				draw_line(start, end, Color(color, fade * 0.08), radius * 2.0, true)
				draw_line(start, end, Color(color, fade * 0.7), 5.0, true)
			"recast":
				var color := Color("dbb8ff") if bool(item.second) else Color("75dfff")
				_burst(item.position, float(item.radius), progress, color, 8)
				draw_arc(item.position, float(item.radius) * (0.3 + progress * 0.4), 0, TAU, 48, Color(color, fade), 4.0, true)
			"refund":
				draw_string(ThemeDB.fallback_font, item.position + Vector2(-12, -35 - progress * 25), "-%.2fs" % float(item.amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.4, 1.0, 0.85, fade))
			"giant", "impact":
				_burst(item.position, float(item.radius), progress, Color("ffe39c"))
			"thorns":
				_burst(item.position, float(item.radius), progress, Color("ff897d"), 12)
				draw_line(item.position, item.end, Color(1.0, 0.45, 0.3, fade), 2.0, true)
			"cannon":
				_burst(item.position, float(item.radius), progress, Color("a6deff"), 10)
				_glow(item.position, float(item.radius), Color("c7f0ff"), fade * 0.3)
			"quake":
				var at: Vector2 = item.position
				var radius: float = item.radius
				_burst(at, radius, progress, Color("ffd475"), 16)
				draw_arc(at, radius * progress * 0.65, 0, TAU, 64, Color(1.0, 0.55, 0.2, fade * 0.8), 7.0, true)
				for index in range(12):
					var direction := Vector2.from_angle(TAU * index / 12.0)
					var path := PackedVector2Array([at + direction * 30.0, at + direction.rotated(0.08) * radius * 0.35,
						at + direction.rotated(-0.05) * radius * 0.65, at + direction * radius * minf(1.0, progress * 2.0)])
					draw_polyline(path, Color(1.0, 0.8, 0.5, fade * 0.8), 2.0, true)
			"blessing":
				_burst(item.position, float(item.radius), progress, Color("ffefa1"), 18)
				for side in [-1.0, 1.0]:
					for feather in range(5):
						var base: Vector2 = item.position + Vector2(side * (22 + feather * 9), -18 - feather * 7)
						draw_line(base, base + Vector2(side * (25.0 + progress * 20.0), -20.0), Color(1, 0.94, 0.7, fade), 4.0, true)
	for player in system.game.players:
		if not player.is_active(): continue
		if player.giant_remaining > 0.0 and bool(player.skill_stats.get("giant_thorns", false)):
			var radius: float = player.collision_radius() + 12.0
			var center: Vector2 = player.position + player.visual_offset()
			draw_arc(center, radius, 0, TAU, 48, Color("ff9d7a"), 2.0, true)
			for index in range(12):
				var direction := Vector2.from_angle(TAU * index / 12.0 + time * 0.3)
				draw_line(center + direction * radius, center + direction * (radius + 9.0), Color("ffe0b0"), 2.0, true)
		if player.dash_recast_remaining > 0.0:
			var center: Vector2 = player.position + Vector2(0, -18)
			_glow(center, 48.0, Color("8cdcfa"), 0.15)
			draw_arc(center, 43.0, -PI / 2.0, -PI / 2.0 + TAU * player.dash_recast_remaining / 2.0, 40, Color("b8edff"), 3.0, true)
			for index in range(6):
				var at := center + Vector2.from_angle(time * 2.0 + TAU * index / 6.0) * 43.0
				draw_circle(at, 3.0, Color("dcefff"))
		if player.blessing_remaining > 0.0:
			var center: Vector2 = player.position + player.visual_offset() + Vector2(0, -20)
			var pulse := 0.65 + sin(time * 4.0) * 0.12
			_glow(center, 55.0, Color("ffe59e"), 0.14)
			var outline := PackedVector2Array()
			for index in range(7): outline.append(center + Vector2.from_angle(-PI / 2.0 + TAU * (index % 6) / 6.0) * 39.0)
			draw_polyline(outline, Color(1.0, 0.92, 0.55, pulse), 2.5, true)
			draw_string(ThemeDB.fallback_font, center + Vector2(-22, -50), "%.0f / %.0fs" % [player.blessing_shield, player.blessing_remaining], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffe5a0"))
		if player.giant_remaining > 0.0 and bool(player.skill_stats.get("giant_quake", false)):
			var count: int = player.giant_unique_hits.size() % system.QUAKE_TARGETS
			for index in range(system.QUAKE_TARGETS):
				var at: Vector2 = player.position + Vector2.from_angle(TAU * index / 6.0 + time * 0.3) * (player.collision_radius() + 14.0)
				draw_circle(at, 4.0, Color("ffe2a0") if index < count else Color(0.55, 0.45, 0.3, 0.45))
	for shot in system.cannons:
		var at: Vector2 = shot.position
		var direction: Vector2 = shot.velocity.normalized()
		var radius: float = shot.radius
		draw_line(at - direction * 65.0, at, Color(0.55, 0.85, 1.0, 0.3), radius * 1.7, true)
		draw_line(at - direction * 50.0, at, Color("dcf5ff"), 3.0, true)
		_glow(at, radius + 20.0, Color("a5e6ff"), 0.35)
		if not is_instance_valid(shot.enemy) or shot.enemy.dead:
			if shot.texture != null:
				draw_texture_rect(shot.texture, Rect2(at - Vector2.ONE * radius * 1.8, Vector2.ONE * radius * 3.6), false, Color(0.75, 0.9, 1.0, 0.75))
			else: draw_circle(at, radius, Color("a9dfff"))
	for slash in system.slashes:
		var at: Vector2 = slash.position
		var direction: Vector2 = slash.direction
		var side := direction.orthogonal()
		var radius: float = slash.radius
		var color := Color("ccefff")
		_glow(at, radius * 1.4, color, 0.35)
		var arc := PackedVector2Array()
		for index in range(25):
			var u := float(index) / 24.0 * 2.0 - 1.0
			arc.append(at + side * radius * u + direction * radius * 0.45 * (1.0 - u * u))
		draw_polyline(arc, Color(color, 0.2), 24.0, true)
		draw_polyline(arc, color, 8.0, true)
		draw_polyline(arc, Color("ffffff"), 2.0, true)
		for index in range(8):
			var offset := sin(time * 7.0 + index * 2.1) * radius
			var tail := at + side * offset - direction * (18.0 + fposmod(index * 17.0 + time * 200.0, 70.0))
			draw_line(tail, tail + direction * 20.0, Color(color, 0.7), 2.0, true)

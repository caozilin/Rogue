extends Node2D
## Foreground shell is deliberately translucent so units and attack warnings stay readable.
const Art = preload("res://scripts/art.gd")
const SHADER = preload("res://assets/effects/frost_ward.gdshader")
var system
var shells: Array[Sprite2D] = []
var panel: StyleBoxFlat

func _ready() -> void:
	z_index = 1
	panel = StyleBoxFlat.new()
	panel.bg_color = Color(0.025, 0.09, 0.14, 0.92)
	panel.border_color = Color(0.40, 0.80, 0.93, 0.65)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(5)
	for index in range(2):
		var shell := Sprite2D.new()
		shell.texture = Art.white()
		shell.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var surface := ShaderMaterial.new()
		surface.shader = SHADER
		shell.material = surface
		shell.visible = false
		add_child(shell)
		shells.append(shell)

func refresh() -> void:
	for index in range(shells.size()):
		var shell := shells[index]
		shell.visible = index < system.game.players.size()
		if not shell.visible:
			continue
		var player = system.game.players[index]
		shell.visible = player.is_active() and player.frost_ward_remaining > 0.0 and player.frost_shield_hp > 0.0
		if not shell.visible:
			continue
		var radius: float = system.ward_radius()
		shell.position = player.position - Vector2(0, radius * 0.26)
		shell.scale = Vector2(radius * 2.30, radius * 2.00) / 32.0
		shell.material.set_shader_parameter("effect_time", system.game.elapsed)
		shell.material.set_shader_parameter("strength", minf(1.0, player.frost_ward_remaining * 3.0))
		shell.material.set_shader_parameter("integrity", player.frost_shield_hp / maxf(1.0, player.frost_shield_max))
		var flash := 0.0
		var angle := 0.0
		for hit in system.ward_impacts:
			if int(hit.owner) == index and not bool(hit.broken):
				flash = float(hit.life) / 0.45
				angle = float(hit.angle)
		shell.material.set_shader_parameter("impact", flash)
		shell.material.set_shader_parameter("impact_angle", angle)
	queue_redraw()

func _draw() -> void:
	if system == null:
		return
	for player in system.game.players:
		if not player.is_active():
			continue
		if player.frost_remaining > 0.0:
			var label_at: Vector2 = player.position + player.visual_offset() + Vector2(-76, 49) * player.body_scale()
			var owner_color: Color = system.game.Balance.PLAYER_COLORS[player.player_id]
			var text := "P%d 冰霜 Lv.%d · 半径 %.0f" % [player.player_id + 1, int(player.skill_ranks.get("frost_width", 0)), system.frost_radius(player)]
			draw_string_outline(ThemeDB.fallback_font, label_at, text, HORIZONTAL_ALIGNMENT_CENTER, 152, 12, 4, Color("08141e"))
			draw_string(ThemeDB.fallback_font, label_at, text, HORIZONTAL_ALIGNMENT_CENTER, 152, 12, owner_color)
		if player.cold_ward_protection:
			var at: Vector2 = player.position + player.visual_offset() + Vector2(23, -58) * player.body_scale()
			var crest := PackedVector2Array([at + Vector2(-6, -5), at + Vector2(0, -8), at + Vector2(6, -5), at + Vector2(5, 3), at + Vector2(0, 8), at + Vector2(-5, 3), at + Vector2(-6, -5)])
			draw_colored_polygon(crest, Color(0.06, 0.28, 0.40, 0.85))
			draw_polyline(crest, Color("b2f4ff"), 1.4, true)
			draw_line(at + Vector2(0, -3), at + Vector2(0, 3), Color("e0fcff"), 1.5, true)
			draw_line(at + Vector2(-3, 0), at + Vector2(3, 0), Color("e0fcff"), 1.5, true)
		if player.frost_ward_remaining <= 0.0 or player.frost_shield_hp <= 0.0:
			continue
		var ratio: float = clampf(player.frost_shield_hp / maxf(1.0, player.frost_shield_max), 0.0, 1.0)
		var radius: float = system.ward_radius()
		var fade: float = minf(1.0, player.frost_ward_remaining * 3.0)
		# Curved meridians connect the canopy to its projected base.
		for index in range(7):
			var azimuth := PI * float(index) / 6.0
			var points := PackedVector2Array()
			for step in range(25):
				var latitude := PI * 0.5 * float(step) / 24.0
				points.append(player.position + Vector2(cos(azimuth) * sin(latitude),
					sin(azimuth) * sin(latitude) * 0.5 - cos(latitude) * 0.95) * radius)
			draw_polyline(points, Color(0.56, 0.90, 1.0, (0.12 + ratio * 0.07) * fade), 1.0, true)
		var at: Vector2 = player.position + Vector2(-64, -radius * 1.45)
		var arena: Rect2 = system.game.Balance.ARENA
		at.x = clampf(at.x, arena.position.x + 6, arena.end.x - 134)
		at.y = maxf(at.y, arena.position.y + 112)
		draw_style_box(panel, Rect2(at - Vector2(6, 21), Vector2(140, 37)))
		var text := "守护罩 %d/%d · %.0fs" % [ceili(player.frost_shield_hp), roundi(player.frost_shield_max), player.frost_ward_remaining]
		draw_string(ThemeDB.fallback_font, at - Vector2(0, 5), text, HORIZONTAL_ALIGNMENT_CENTER, 128, 13, Color("c9f7ff"))
		draw_rect(Rect2(at, Vector2(128, 6)), Color("183d50"))
		draw_rect(Rect2(at, Vector2(128 * ratio, 6)), Color("94e9ff") if ratio > 0.3 else Color("ffe1ac"))
	for hit in system.ward_impacts:
		var fade: float = float(hit.life) / 0.45
		var angle: float = hit.angle
		var center: Vector2 = hit.center
		var radius: float = hit.radius
		if bool(hit.broken):
			draw_arc(center, radius * (1.0 + (1.0 - fade) * 0.13), 0, TAU, 80, Color(0.7, 0.94, 1.0, fade * 0.75), 2.0, true)
			for index in range(18):
				var dir := Vector2.from_angle(TAU * float(index) / 18.0)
				var at: Vector2 = center + dir * radius * (1.0 + (1.0 - fade) * 0.23)
				var tip := at + dir * (5.0 + fade * 9.0)
				draw_colored_polygon(PackedVector2Array([at - dir.orthogonal() * 3.0, tip, at + dir.orthogonal() * 3.0]), Color(0.7, 0.95, 1.0, fade * 0.8))
		else:
			draw_arc(center, radius, angle - 0.23, angle + 0.23, 20, Color(0.85, 1.0, 1.0, fade), 4.0, true)
			var at := center + Vector2.from_angle(angle) * radius
			draw_texture_rect(Art.glow(), Rect2(at - Vector2(26, 26), Vector2(52, 52)), false, Color(0.5, 0.88, 1.0, fade * 0.65))
			for index in range(6):
				var dir := Vector2.from_angle(angle + float(index) * 0.8 - 2.0)
				var point := at + dir * (1.0 - fade) * 36.0
				draw_line(point, point + dir * 5.0, Color(0.8, 0.96, 1.0, fade), 1.5, true)

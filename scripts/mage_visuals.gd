extends Node2D
## Bounded visual pools; every animation uses simulation time, including shaders.
const Art = preload("res://scripts/art.gd")
const FIRE_SHADER = preload("res://assets/effects/fire.gdshader")
const FROST_SHADER = preload("res://assets/effects/frost.gdshader")
const HEAT_SHADER = preload("res://assets/effects/heat.gdshader")

var system
var flames: Array[Sprite2D] = []
var heat: Array[Sprite2D] = []
var fields: Array[Sprite2D] = []

func _ready() -> void:
	z_index = -2
	for index in range(system.MAX_FIREBALLS):
		# Keep fire below units and enemy warnings; only the visuals change.
		heat.append(_sprite(HEAT_SHADER, 0))
		flames.append(_sprite(FIRE_SHADER, 1))
	for index in range(2):
		fields.append(_sprite(FROST_SHADER, 0))

func _sprite(shader: Shader, depth: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = Art.white()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var surface := ShaderMaterial.new()
	surface.shader = shader
	sprite.material = surface
	sprite.z_index = depth
	sprite.visible = false
	add_child(sprite)
	return sprite

func refresh() -> void:
	var time: float = system.game.elapsed
	for index in range(flames.size()):
		var present: bool = index < system.fireballs.size()
		flames[index].visible = present
		heat[index].visible = present
		if not present:
			continue
		var ball: Dictionary = system.fireballs[index]
		var radius: float = ball.radius
		flames[index].position = ball.position - ball.direction * radius * 0.56 + Vector2(0, -16)
		flames[index].rotation = ball.direction.angle()
		flames[index].scale = Vector2(radius * 4.0, radius * 3.0) / 32.0
		flames[index].material.set_shader_parameter("effect_time", time)
		flames[index].material.set_shader_parameter("seed", float(index) * 3.7)
		heat[index].position = ball.position
		heat[index].scale = Vector2.ONE * radius * 3.0 / 32.0
		heat[index].material.set_shader_parameter("effect_time", time)
	for index in range(fields.size()):
		if index >= system.game.players.size():
			fields[index].visible = false
			continue
		var player = system.game.players[index]
		fields[index].visible = player.is_active() and player.frost_remaining > 0.0
		if not fields[index].visible:
			continue
		var radius: float = system.frost_radius(player)
		fields[index].position = player.position
		fields[index].scale = Vector2.ONE * radius * 2.25 / 32.0
		fields[index].material.set_shader_parameter("effect_time", time)
		fields[index].material.set_shader_parameter("strength", minf(1.0, player.frost_remaining * 3.0))
		fields[index].material.set_shader_parameter("effect_age", system.FROST_DURATION - player.frost_remaining)
		fields[index].material.set_shader_parameter("pulse_interval", system.FROST_TICK / float(player.skill_stats.frost_rate))
		# The independent fixed-size shell renders protection, not the enlarged field.
		fields[index].material.set_shader_parameter("ward", 0.0)
	queue_redraw()

func _draw() -> void:
	if system == null:
		return
	var time: float = system.game.elapsed
	for ground in system.grounds:
		var color := Color("ff7a2c") if ground.element == "fire" else Color("7bd5ff")
		var fade := minf(1.0, float(ground.life) / 1.5)
		draw_line(ground.start, ground.end, Color(color, 0.06 * fade), float(ground.radius) * 2.0, true)
		draw_circle(ground.end, float(ground.radius), Color(color, 0.045 * fade))
		var center: Vector2 = (ground.start + ground.end) * 0.5
		for index in range(3):
			var at := center + Vector2.from_angle(float(index) * 2.4 + time * 0.25) * float(ground.radius) * 0.45
			if ground.element == "fire":
				draw_line(at + Vector2(0, 5), at + Vector2(sin(time * 4.0 + index) * 4.0, -10), Color(color, 0.55 * fade), 3.0, true)
			else:
				draw_line(at - Vector2(5, 0), at + Vector2(5, 0), Color(color, 0.5 * fade), 1.5, true)
				draw_line(at - Vector2(0, 5), at + Vector2(0, 5), Color(color, 0.5 * fade), 1.5, true)
	for player in system.game.players:
		if not player.is_active() or player.frost_remaining <= 0.0:
			continue
		var radius: float = system.frost_radius(player)
		var fade: float = minf(1.0, player.frost_remaining * 3.0)
		var owner_color: Color = system.game.Balance.PLAYER_COLORS[player.player_id]
		# Sparse ownership accents distinguish overlapping same-class fields.
		for marker in range(4):
			var start := TAU * float(marker) / 4.0 + 0.08
			draw_arc(player.position, radius, start, start + 0.28, 12, Color(owner_color, fade * 0.85), 2.0, true)
		for index in range(18):
			var angle := TAU * float(index) / 18.0 + 0.1
			var at: Vector2 = player.position + Vector2.from_angle(angle) * radius * (0.86 + fposmod(float(index) * 0.31, 0.12))
			var height := 10.0 + fposmod(float(index) * 7.3, 20.0)
			var width := 3.0 + fposmod(float(index) * 1.7, 4.0)
			var tilt := sin(time * 1.3 + float(index)) * 2.0
			Art.shadow(self, at + Vector2(4, 3), Vector2(22, 10), 0.36 * fade)
			var tip := at + Vector2(tilt, -height)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-width, 2), tip, at + Vector2(1, 5)]), Color(0.24, 0.52, 0.69, 0.68 * fade))
			draw_colored_polygon(PackedVector2Array([at + Vector2(1, 5), tip, at + Vector2(width, 0)]), Color(0.74, 0.93, 1.0, 0.72 * fade))
			draw_line(at + Vector2(1, 4), tip, Color(0.9, 1.0, 1.0, 0.84 * fade), 1.0, true)
			var glint := (0.4 + sin(time * 2.5 + float(index)) * 0.3) * fade
			draw_texture_rect(Art.glow(), Rect2(tip - Vector2(10, 10), Vector2(20, 20)), false, Color(0.43, 0.83, 1.0, glint))
		for index in range(44):
			var phase := fposmod(float(index) * 0.618 + time * 0.22, 1.0)
			var angle := float(index) * 2.4 + time * 0.2
			var at: Vector2 = player.position + Vector2.from_angle(angle) * radius * sqrt(fposmod(float(index) * 0.37, 1.0))
			at += Vector2(sin(phase * TAU + float(index)) * 12, -phase * 45)
			var alpha := sin(phase * PI) * 0.6 * fade
			draw_line(at, at + Vector2(2, -3), Color(0.77, 0.92, 1.0, alpha), 1.4, true)
	for ball in system.fireballs:
		var radius: float = ball.radius
		var light_extent := Vector2(radius * 3.4, radius * 1.8)
		draw_texture_rect(Art.glow(), Rect2(ball.position - light_extent * 0.5, light_extent), false, Color(1, 0.24, 0.015, 0.42))
		for index in range(28):
			var phase := fposmod(time * 0.85 + float(index) * 0.618, 1.0)
			var side := sin(float(index) * 9.73) * radius * (0.2 + phase * 0.65)
			var at: Vector2 = ball.position - ball.direction * radius * phase * 2.6 + ball.direction.orthogonal() * side
			at.y -= phase * 27.0 + 16.0
			var color := Color(1, 0.64 + phase * 0.24, 0.22, (1.0 - phase) * 0.8)
			draw_line(at, at + ball.direction * (4.0 + phase * 8), color, 1.0 + (1.0 - phase) * 1.5, true)
	for cone in system.cones:
		var at: Vector2 = cone.position
		if not bool(cone.hit):
			draw_arc(at, float(cone.radius), 0, TAU, 24, Color("a0dfff"), 1.8, true)
			var tip := at + Vector2(0, -maxf(0.0, float(cone.wait)) * 180.0)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, -22), tip, tip + Vector2(9, -22)]), Color("bcecff"))
		else:
			draw_circle(at, float(cone.radius), Color(0.5, 0.85, 1.0, 0.25))
	for effect in system.explosions:
		var fade: float = float(effect.life) / 0.4
		draw_circle(effect.position, float(effect.radius) * (1.0 - fade * 0.25), Color(1.0, 0.4, 0.1, 0.15 * fade))
		draw_arc(effect.position, float(effect.radius) * (1.0 - fade * 0.25), 0, TAU, 64, Color(1.0, 0.75, 0.2, fade), 5.0, true)

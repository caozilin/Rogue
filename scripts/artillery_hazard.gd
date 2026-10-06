extends "res://scripts/enemy_hazard.gd"
## Shell descent, impact flash, fire column, shock wave and debris; one damage hit.
const Art = preload("res://scripts/art.gd")
const BLAST_SHADER = preload("res://assets/effects/boss_blast.gdshader")

var order := 1
var heavy := false
const EFFECT_DURATION := 0.65
var blast_sprite: Sprite2D

func _ready() -> void:
	blast_sprite = Sprite2D.new()
	blast_sprite.texture = Art.white()
	var material := ShaderMaterial.new()
	material.shader = BLAST_SHADER
	material.set_shader_parameter("seed", float(order) * 3.7)
	blast_sprite.material = material
	blast_sprite.position = Vector2(0, -radius * 0.35)
	blast_sprite.scale = Vector2.ONE * radius * 3.0 / 32.0
	blast_sprite.visible = false
	add_child(blast_sprite)

func advance(delta: float) -> void:
	super.advance(delta)
	blast_sprite.visible = warning_remaining <= 0.0 and not expired
	blast_sprite.material.set_shader_parameter("progress", 1.0 - blast_remaining / EFFECT_DURATION)

func _glow(at: Vector2, size: Vector2, color: Color, alpha: float) -> void:
	draw_texture_rect(Art.glow(), Rect2(at - size * 0.5, size), false, Color(color, alpha))

func _draw() -> void:
	var color := Color("ff836e") if heavy else Color("ffc17a")
	if warning_remaining > 0.0:
		var progress := 1.0 - warning_remaining / warning_duration
		draw_circle(Vector2.ZERO, radius, Color(color, 0.1))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, color, 2.5, true)
		draw_arc(Vector2.ZERO, radius + 4, -PI / 2, -PI / 2 + TAU * progress, 48, Color("ffe5c2"), 4, true)
		draw_line(Vector2(-16, 0), Vector2(16, 0), color, 2, true)
		draw_line(Vector2(0, -16), Vector2(0, 16), color, 2, true)
		draw_string(ThemeDB.fallback_font, Vector2(-5, -22), str(order), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
		# A visible shell descends along an oblique arc before the actual impact.
		var fall := clampf((progress - 0.25) / 0.75, 0.0, 1.0)
		var shell := Vector2((1.0 - fall) * 80.0, -pow(1.0 - fall, 0.8) * 230.0)
		var aim := Vector2(-0.33, 1.0).normalized()
		_glow(shell, Vector2(60, 90), color, 0.48)
		draw_line(shell - aim * 90, shell, Color(color, 0.16), 19.0, true)
		draw_line(shell - aim * 70, shell, Color(color, 0.8), 6.0, true)
		draw_circle(shell, 6.0 if not heavy else 9.0, Color("fff0c9"))
		for index in range(5):
			var at := shell - aim * (index * 14.0) + aim.orthogonal() * sin(progress * 25 + index) * 7
			draw_circle(at, 2.0, Color(1.0, 0.7, 0.35, (1.0 - index / 5.0) * 0.7))
	else:
		var fade := clampf(blast_remaining / EFFECT_DURATION, 0.0, 1.0)
		var progress := 1.0 - fade
		_glow(Vector2.ZERO, Vector2.ONE * radius * 3.2, color, fade * 0.6)
		_glow(Vector2(0, -35 - progress * 40), Vector2(radius * 1.3, 200.0), Color("ff9a41"), fade * 0.65)
		if progress < 0.2:
			_glow(Vector2.ZERO, Vector2.ONE * radius * 1.8, Color("fff4db"), (1.0 - progress / 0.2) * 0.9)
		for layer in range(3):
			var ring := radius * clampf(progress * 2.0 - layer * 0.15, 0.03, 1.12)
			draw_arc(Vector2.ZERO, ring, 0, TAU, 56, Color(color, fade * 0.75), 5.0 - layer, true)
		# Rising lobes and wisps form an explosion cloud rather than a filled damage circle.
		for index in range(10):
			var phase := fposmod(index * 0.618, 1.0)
			var at := Vector2(sin(index * 2.4) * radius * 0.48 * progress, -progress * (30 + phase * 85))
			var size := Vector2(40 + progress * 20, 60 + progress * 35) * (0.8 + phase * 0.4)
			_glow(at, size, Color("ff702c"), fade * 0.27)
			var tip := at + Vector2(sin(index + progress * 7) * 10, -25)
			draw_line(at, tip, Color(1.0, 0.81, 0.45, fade * 0.55), 4.0, true)
		for index in range(22):
			var aim := Vector2.from_angle(index * 2.399)
			var at := aim * radius * (0.3 + progress * 1.0) + Vector2(0, -sin(progress * PI) * (12 + index % 5 * 7))
			draw_line(at - aim * 12, at, Color(1.0, 0.84, 0.52, fade), 2.5, true)
			_glow(at, Vector2.ONE * 14, color, fade * 0.45)

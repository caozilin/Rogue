extends Node2D
## A separate overlay above units and effects, but below the HUD canvas.
const LIFETIME := 0.8
const MAX_EVENTS := 60
var game

static func font_size_for(amount: float, critical := false) -> int:
	var size := clampi(roundi(14.0 + 8.0 * log(1.0 + maxf(0.0, amount) / 10.0)), 16, 44)
	return mini(46, size + (2 if critical else 0))

func _ready() -> void:
	z_index = 10

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for event in game.damage_events:
		var age: float = LIFETIME - float(event.life)
		var alpha := clampf(float(event.life) / 0.3, 0.0, 1.0)
		var size: int = event.font_size
		var caption := str(event.amount)
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at: Vector2 = event.position + Vector2(-width / 2.0, -age * 45.0)
		var color := Color("fff0a1") if event.critical else Color("f1f6ff")
		color.a = alpha
		draw_string_outline(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.025, 0.04, 0.07, alpha))
		draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

extends Node2D
## A separate overlay above units and effects, but below the HUD canvas.
const LIFETIME := 0.8
const MAX_EVENTS := 60
const ELEMENT_COLORS := {"ice": Color("72ddff"), "fire": Color("ff984a"), "lightning": Color("ca9bff")}
const REACTION_LABEL := "融化"
var game
var reaction_font: SystemFont

static func font_size_for(amount: float, critical := false, reaction := false) -> int:
	var size := clampi(roundi(14.0 + 8.0 * log(1.0 + maxf(0.0, amount) / 10.0)), 16, 44)
	size = mini(46, size + (2 if critical else 0))
	return clampi(roundi(size * 1.3), 26, 56) if reaction else size

static func element_for_source(source: String) -> String:
	if source in ["fireball", "fire_explosion", "fire_ground", "burn"]: return "fire"
	if source in ["frost", "frost_cones"]: return "ice"
	if source in ["lightning_tower", "tower_chain", "tower_tide", "tower_judgment"]: return "lightning"
	return "physical"

static func color_for(element: String, critical := false) -> Color:
	return ELEMENT_COLORS.get(element, Color("fff0a1") if critical else Color("f1f6ff"))

func _ready() -> void:
	z_index = 10
	reaction_font = SystemFont.new()
	reaction_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	reaction_font.font_weight = 700

func _draw() -> void:
	for event in game.damage_events:
		var reacting: bool = event.get("reaction", false)
		var font: Font = reaction_font if reacting else ThemeDB.fallback_font
		var age: float = LIFETIME - float(event.life)
		var alpha := clampf(float(event.life) / 0.3, 0.0, 1.0)
		var size: int = event.font_size
		if reacting:
			# Explicit simulation age keeps the reaction pop frozen during pause/selection.
			size = roundi(size * (1.0 + 0.16 * sin(clampf(age / 0.18, 0, 1) * PI)))
		var caption := str(event.amount)
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at: Vector2 = event.position + Vector2(-width / 2.0, -age * 45.0)
		var color := color_for(str(event.get("element", "physical")), event.critical)
		color.a = alpha
		if reacting:
			draw_string_outline(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(color, alpha * 0.28))
		draw_string_outline(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5 if reacting else 3, Color(0.025, 0.04, 0.07, alpha))
		draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		if reacting and event.get("reaction_label", true):
			var label_size := 17
			var label_width := reaction_font.get_string_size(REACTION_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
			var label_at := at + Vector2(width + 10, -4)
			if label_at.x + label_width > get_viewport_rect().end.x - 12:
				label_at.x = at.x - label_width - 10
			draw_rect(Rect2(label_at + Vector2(-5, -20), Vector2(label_width + 10, 27)), Color(0.12, 0.07, 0.16, alpha * 0.85))
			draw_line(label_at + Vector2(-5, 6), label_at + Vector2(label_width + 5, 6), Color(color, alpha * 0.8), 2, true)
			draw_string_outline(reaction_font, label_at, REACTION_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, 3, Color(0.05, 0.03, 0.07, alpha))
			draw_string(reaction_font, label_at, REACTION_LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color(1.0, 0.89, 0.55, alpha))

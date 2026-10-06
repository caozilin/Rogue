extends Node2D
## Mortar landing marker: harmless countdown, then a short one-hit blast.

const WARNING_TIME := 1.15
const BLAST_TIME := 0.3
var warning_remaining := WARNING_TIME
var warning_duration := WARNING_TIME
var blast_remaining := BLAST_TIME
var radius := 62.0
var damage := 14.0
var hit_players: Dictionary = {}
var expired := false
var source_id := 0

func advance(delta: float) -> void:
	var blast_delta := maxf(0.0, delta - warning_remaining)
	warning_remaining = maxf(0.0, warning_remaining - delta)
	if warning_remaining == 0.0:
		blast_remaining = maxf(0.0, blast_remaining - blast_delta)
		expired = blast_remaining == 0.0
	queue_redraw()

func _draw() -> void:
	if warning_remaining > 0.0:
		var progress := 1.0 - warning_remaining / warning_duration
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.55, 0.16, 0.12))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color("ffdb70"), 2.0, true)
		draw_arc(Vector2.ZERO, radius + 5.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, Color("ff8255"), 4.0, true)
		draw_line(Vector2(-12, 0), Vector2(12, 0), Color("ffdb70"), 2.0, true)
		draw_line(Vector2(0, -12), Vector2(0, 12), Color("ffdb70"), 2.0, true)
	else:
		var fade := blast_remaining / BLAST_TIME
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.38, 0.12, fade * 0.5))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(1.0, 0.85, 0.4, fade), 5.0, true)

extends "res://scripts/enemy_hazard.gd"
## Distinct green ground spells; harmless windup, one hit per player per zone.

var spell := "fault"
var active_duration := 0.45

func _draw() -> void:
	var color := Color("bbef75") if spell == "fault" else Color("72eaa2")
	if warning_remaining > 0.0:
		var progress := clampf(1.0 - warning_remaining / warning_duration, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(color, 0.1))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(color, 0.85), 2.0, true)
		draw_arc(Vector2.ZERO, radius + 4, -PI / 2.0, -PI / 2.0 + TAU * progress, 40, color, 4.0, true)
		for index in range(4):
			var direction := Vector2.from_angle(PI * float(index) / 2.0)
			draw_line(direction * 8.0, direction * 18.0, Color(color, 0.8), 2.0, true)
	else:
		var alpha := minf(1.0, blast_remaining / active_duration * 2.0)
		draw_circle(Vector2.ZERO, radius, Color(color, 0.16 * alpha))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(color, alpha), 3.0, true)
		for index in range(6):
			var angle := TAU * float(index) / 6.0
			var tip := Vector2.from_angle(angle) * radius * 0.78
			var base := Vector2.from_angle(angle) * radius * 0.3
			var side := Vector2.from_angle(angle).orthogonal() * 9.0
			draw_colored_polygon(PackedVector2Array([base + side, tip, base - side]), Color(color, alpha * 0.8))

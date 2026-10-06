extends Node2D
## Stationary, damageable lure; simulation time owns its upgraded lifetime.
var hp := 100.0
var max_hp := 100.0
var warcry_remaining := 10.0
var warcry_order := 0
var player_id := -1
var invulnerability := 0.0
var giant_remaining := 0.0
var owner_id := 0

func is_active() -> bool:
	return hp > 0.0 and warcry_remaining > 0.0

func is_targetable() -> bool:
	return is_active()

func collision_radius() -> float:
	return 22.0

func knock_back(_direction: Vector2, _distance: float) -> void:
	pass

func take_damage(amount: float, _source_id := 0) -> void:
	if not is_active(): return
	hp = maxf(0.0, hp - amount)
	queue_redraw()

func advance(delta: float) -> void:
	warcry_remaining = maxf(0.0, warcry_remaining - delta)
	queue_redraw()

func _draw() -> void:
	if not is_active(): return
	var color := Color("ffb06d")
	draw_circle(Vector2.ZERO, 22.0, Color(0.2, 0.1, 0.07, 0.8))
	draw_arc(Vector2.ZERO, 32.0, 0, TAU, 48, Color(color, 0.65), 2.0, true)
	draw_rect(Rect2(-12, -33, 24, 43), Color("875736"))
	draw_line(Vector2(-5, -30), Vector2(-3, 9), Color("b48453"), 2.0)
	draw_line(Vector2(5, -29), Vector2(7, 8), Color("4f3626"), 2.0)
	draw_ellipse_top()
	draw_line(Vector2(-24, 24), Vector2(24, 24), Color("352d28"), 5.0)
	draw_line(Vector2(-24, 24), Vector2(-24 + 48 * hp / max_hp, 24), Color("87f5b4"), 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(-18, -46), "%.1fs" % warcry_remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)

func draw_ellipse_top() -> void:
	draw_set_transform(Vector2(0, -33), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 12, Color("bd9864"))
	draw_arc(Vector2.ZERO, 7, 0, TAU, 24, Color("785234"), 1.5)
	draw_set_transform(Vector2.ZERO)

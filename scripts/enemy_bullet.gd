extends Node2D
const Art = preload("res://scripts/art.gd")
## Hostile bullets have their own budget, collision and readable silhouettes.

var velocity := Vector2.ZERO
var damage := 7.0
var radius := 6.0
var remaining_distance := 760.0
var color := Color("ff866e")
var pattern := "fan"
var expired := false
var source_id := 0
var boss_visual := false
var homing_target = null
var homing_remaining := 0.0
var turn_rate := 1.25

func steer(delta: float) -> void:
	var active := minf(delta, homing_remaining)
	homing_remaining = maxf(0.0, homing_remaining - delta)
	if active <= 0 or not is_instance_valid(homing_target) or not homing_target.is_targetable(): return
	var desired := position.direction_to(homing_target.position)
	velocity = velocity.rotated(clampf(velocity.angle_to(desired), -turn_rate*active, turn_rate*active))

func _draw() -> void:
	if pattern == "milk_bubble":
		draw_texture_rect(Art.glow(),Rect2(-Vector2.ONE*23,Vector2.ONE*46),false,Color(color,0.45))
		draw_circle(Vector2.ZERO,radius,Color(color,0.35))
		draw_arc(Vector2.ZERO,radius,0,TAU,24,color,2,true)
		draw_arc(Vector2.ZERO,radius-3,-PI,0,12,Color("ffd3ec"),1.5,true)
		draw_circle(Vector2(-radius*0.3,-radius*0.4),2.5,Color("f5fff1"))
		return
	if pattern == "milk_star":
		var points := PackedVector2Array()
		for index in range(10): points.append(Vector2.from_angle(velocity.angle()+index*PI/5)*radius*(1.0 if index%2==0 else 0.45))
		draw_texture_rect(Art.glow(),Rect2(-Vector2.ONE*22,Vector2.ONE*44),false,Color(color,0.6))
		draw_line(-velocity.normalized()*28,Vector2.ZERO,Color(color,0.3),7,true)
		draw_colored_polygon(points,color)
		draw_circle(Vector2.ZERO,2.5,Color("fff9da"))
		return
	if boss_visual:
		var aim := velocity.normalized()
		draw_texture_rect(Art.glow(), Rect2(-Vector2.ONE * 22, Vector2.ONE * 44), false, Color(color, 0.5))
		draw_line(-aim * 42.0, Vector2.ZERO, Color(color, 0.18), 11.0, true)
		draw_line(-aim * 30.0, Vector2.ZERO, Color(color, 0.75), 3.0, true)
	draw_line(-velocity.normalized() * 13.0, Vector2.ZERO, Color(color, 0.35), 5.0, true)
	draw_circle(Vector2.ZERO, radius + 2.0, Color("251521"))
	if pattern == "ring":
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius - 2.0, 0, TAU, 16, Color("fff0de"), 1.5, true)
	else:
		var points := PackedVector2Array([Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius), Vector2(-radius, 0)])
		draw_colored_polygon(points, color)
		draw_circle(Vector2.ZERO, 2.0, Color("fff0de"))

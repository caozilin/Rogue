extends Node2D
## Swept collision is handled by Game: fast projectiles cannot tunnel through enemies.

var owner_id := 0
var damage_source := "auto"
var velocity := Vector2.ZERO
var damage := 14.0
var remaining_distance := 480.0
var hits_left := 1
var hit_ids: Dictionary = {}
var critical := false
var expired := false

func _ready() -> void:
	z_index = 2

func _draw() -> void:
	var color: Color = preload("res://scripts/balance.gd").PLAYER_COLORS[owner_id]
	if critical:
		color = Color("fff3aa")
	draw_line(-velocity.normalized() * 10.0, Vector2.ZERO, Color(color, 0.4), 4.0, true)
	draw_circle(Vector2.ZERO, 4.5 if not critical else 6.0, color)

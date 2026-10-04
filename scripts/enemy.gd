extends Node2D

const Art = preload("res://scripts/art.gd")

var hp := 20.0
var max_hp := 20.0
var speed := 64.0
var damage := 9.0
var xp_value := 6
var radius := 13.0
var elite := false
var dead := false
var hit_flash := 0.0
var gait := 0.0
var marks: Dictionary = {} # Player IDs, independent even when both choose Raider.

func setup(spawn: Vector2, tuning: Dictionary, is_elite: bool) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	position = spawn
	gait = spawn.x * 0.01
	elite = is_elite
	hp = float(tuning.health) * (3.0 if elite else 1.0)
	max_hp = hp
	speed = float(tuning.speed) * (0.8 if elite else 1.0)
	damage = float(tuning.damage) * (1.35 if elite else 1.0)
	xp_value = int(tuning.xp) * (4 if elite else 1)
	radius = 22.0 if elite else 13.0

func advance(delta: float, target: Node2D) -> void:
	if target != null:
		position += position.direction_to(target.position) * speed * delta
		gait += delta * 8.0
	hit_flash = maxf(0.0, hit_flash - delta)
	queue_redraw()

func hit(amount: float) -> bool:
	hp -= amount
	hit_flash = 0.08
	if hp <= 0.0:
		dead = true
	return dead

func _draw() -> void:
	var color := Color("ff7597") if not elite else Color("c194ff")
	if hit_flash > 0.0:
		color = Color("ffffff")
	draw_circle(Vector2.ZERO, radius + 5.0, Color(color, 0.08))
	var texture := Art.sprite("elite" if elite else "enemy")
	if texture != null:
		draw_circle(Vector2(0, radius * 0.6), radius * 0.8, Color(0, 0, 0, 0.24))
		var size := 84.0 if elite else 54.0
		var tint := Color(1.5, 1.5, 1.5) if hit_flash > 0.0 else Color.WHITE
		draw_texture_rect(texture, Rect2(-size / 2.0, -size / 2.0 - 5.0 + sin(gait) * 1.2, size, size), false, tint)
	elif elite:
		var points := PackedVector2Array([Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius), Vector2(-radius, 0)])
		draw_colored_polygon(points, color)
	else:
		draw_rect(Rect2(-radius, -radius, radius * 2, radius * 2), color)
	if texture == null:
		draw_circle(Vector2(-4, -2), 2.0, Color("401e36"))
		draw_circle(Vector2(4, -2), 2.0, Color("401e36"))
	if hp < max_hp:
		draw_rect(Rect2(-radius, -radius - 8, radius * 2, 3), Color("27334d"))
		draw_rect(Rect2(-radius, -radius - 8, radius * 2 * maxf(hp, 0.0) / max_hp, 3), color)
	for id in marks:
		var mark_color: Color = preload("res://scripts/balance.gd").PLAYER_COLORS[id]
		draw_arc(Vector2.ZERO, radius + 7.0 + float(id) * 4.0, 0, TAU, 32, mark_color, 2.0, true)
		draw_circle(Vector2(-4 + int(id) * 8, -radius - 15), 3.0, mark_color)

extends Node2D
## Separate floor layer keeps ground spells and loot above the courtyard.
const Balance = preload("res://scripts/balance.gd")
const Art = preload("res://scripts/art.gd")

func _ready() -> void:
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	var texture := Art.floor_texture()
	if texture != null:
		draw_texture_rect(texture, Balance.ARENA, false, Color("cad2db"))
	else:
		draw_rect(Balance.ARENA, Color("28313a"))
	draw_rect(Rect2(Balance.ARENA.position + Vector2(0, -5), Vector2(Balance.ARENA.size.x, 6)), Color("5e6770"))
	draw_rect(Rect2(Balance.ARENA.position + Vector2(0, Balance.ARENA.size.y), Vector2(Balance.ARENA.size.x, 10)), Color("151a22"))
	draw_rect(Balance.ARENA, Color("67737d"), false, 1.0)

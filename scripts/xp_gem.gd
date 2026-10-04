extends Node2D

const Art = preload("res://scripts/art.gd")

var value := 6
var collected := false

func _draw() -> void:
	var radius := 4.5 + minf(4.5, float(value) / 30.0)
	draw_circle(Vector2.ZERO, radius + 3, Color(0.33, 0.96, 0.68, 0.08))
	var texture := Art.sprite("gem")
	if texture != null:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var size := radius * 4.0
		draw_texture_rect(texture, Rect2(-size / 2.0, -size / 2.0, size, size), false)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -radius), Vector2(radius, 0),
			Vector2(0, radius), Vector2(-radius, 0)]), Color("87f5b4"))

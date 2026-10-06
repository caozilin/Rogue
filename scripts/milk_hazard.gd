extends "res://scripts/enemy_hazard.gd"
const Art = preload("res://scripts/art.gd")
const SHADER = preload("res://assets/effects/milk.gdshader")
var lotus := false
var sprite: Sprite2D
var clock := 0.0

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Art.white()
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("mode", 1 if lotus else 2)
	material.set_shader_parameter("tint", Color("a5ff90") if lotus else Color("ffcc60"))
	sprite.material = material
	sprite.scale = Vector2.ONE * radius * 2.8 / 32.0
	sprite.hide()
	add_child(sprite)

func advance(delta: float) -> void:
	super.advance(delta)
	clock += delta
	sprite.visible = warning_remaining == 0.0 and not expired
	sprite.material.set_shader_parameter("progress", 1.0 - blast_remaining / 0.75)
	sprite.material.set_shader_parameter("effect_time", clock)

func _draw() -> void:
	var color := Color("a5ff90") if lotus else Color("ffdc7a")
	var p := 1.0 - warning_remaining / warning_duration if warning_remaining > 0 else 1.0 - blast_remaining / 0.75
	var fade := 1.0 if warning_remaining > 0 else 1.0-p
	for index in range(10):
		var dir := Vector2.from_angle(index*TAU/10+clock)
		draw_set_transform(dir*radius*(0.45 if warning_remaining > 0 else p), dir.angle(), Vector2(2.4,0.7))
		draw_circle(Vector2.ZERO, 18*fade, Color("ffaad7",fade*0.8))
		draw_set_transform(Vector2.ZERO)
	if warning_remaining > 0:
		draw_arc(Vector2.ZERO,radius,0,TAU,64,color,3,true)
		draw_arc(Vector2.ZERO,radius+5,-PI/2,-PI/2+TAU*p,64,Color("fff9de"),5,true)
		var drop := Vector2(0,-210*(1-p))
		draw_texture_rect(Art.glow(),Rect2(drop-Vector2(40,60),Vector2(80,120)),false,Color(color,0.7))
		draw_set_transform(drop,0,Vector2(0.8,1.3))
		draw_circle(Vector2.ZERO,17,color)
		draw_circle(Vector2(-4,-5),5,Color("fffbe3"))
		draw_set_transform(Vector2.ZERO)
	else:
		draw_arc(Vector2.ZERO,radius*minf(1.15,p*2+0.2),0,TAU,64,Color(color,fade),6*fade+1,true)

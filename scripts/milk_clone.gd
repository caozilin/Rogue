extends "res://scripts/enemy.gd"
## Weak, finite copies: ordinary damageable enemies, not extra boss lives.
var master
var shot_timer := 1.7
var pose := "idle"
var pose_remaining := 0.0

func setup_clone(at: Vector2, owner_boss) -> void:
	master = owner_boss
	setup(at, {"health":1800.0,"speed":240.0,"damage":32.0,"xp":0}, false)
	radius = 26.0
	level = 20
	tenacity = 0.35
	shot_timer += fposmod(at.x*0.02,1.3)

func advance(delta: float, target: Node2D) -> void:
	if not is_instance_valid(master) or master.dead:
		dead = true
		return
	super.advance(delta,target)
	if dead or stagger_remaining > 0.0 or knockback_remaining > 0.0: return
	pose_remaining = maxf(0,pose_remaining-delta)
	if pose_remaining == 0: pose = "idle"
	shot_timer -= delta*attack_scale
	if target != null and shot_timer <= 0:
		shot_timer = 2.3
		pose = "tongue"
		pose_remaining = 0.5
		ranged_attack.emit(self,"milk_clone",position.direction_to(target.position),target.position)

func _draw() -> void:
	Art.shadow(self,Vector2(0,12),Vector2(90,34),0.6)
	var texture := Art.milk_character(2,pose)
	if texture != null: motion.render(texture,Rect2(-58,-100,116,126),Color("fff0bd") if hit_flash > 0 else Color(0.88,1,0.88),1)
	draw_arc(Vector2(0,12),32,0,TAU,24,Color("a0ff93"),2,true)
	draw_line(Vector2(-24,-111),Vector2(24,-111),Color("233b35"),4)
	draw_line(Vector2(-24,-111),Vector2(-24+48*hp/max_hp,-111),Color("a5ff90"),3)

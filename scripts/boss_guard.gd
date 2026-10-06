extends "res://scripts/enemy.gd"
## Guards walk in from edges and regroup near their summoner; taunts can pull them away.

var anchor = null
var orbit_angle := 0.0

func setup_guard(spawn: Vector2, tuning: Dictionary, owner, slot: int) -> void:
	super.setup(spawn, tuning, false, "ward_guard")
	anchor = owner
	orbit_angle = TAU * float(slot) / 3.0
	hp *= 1.35
	max_hp = hp
	speed *= 1.25
	radius = 16.0
	xp_value *= 2
	tenacity = 0.35

func advance(delta: float, target: Node2D) -> void:
	if dead:
		return
	if not is_instance_valid(anchor) or anchor.dead:
		dead = true
		return
	if knockback_remaining > 0.0 or stagger_remaining > 0.0 or priority_target_id != -1:
		super.advance(delta, target)
		return
	var goal: Vector2 = anchor.position + Vector2.from_angle(orbit_angle + gait * 0.025) * 95.0
	contact_cooldown = maxf(0.0, contact_cooldown - delta * attack_scale)
	if position.distance_to(anchor.position) < 180.0 and target != null and target.position.distance_to(anchor.position) < 230.0:
		goal = target.position
	if position.distance_to(goal) > 14.0:
		position += position.direction_to(goal) * speed * delta * movement_scale
	gait += delta * 6.0
	hit_flash = maxf(0.0, hit_flash - delta)
	queue_redraw()

func _draw() -> void:
	var color := Color("8ee8a0") if hit_flash == 0.0 else Color.WHITE
	Art.shadow(self, Vector2(8, 10), Vector2(60, 24), 0.72)
	var texture := Art.sprite("elite")
	if texture != null:
		motion.render(texture, Rect2(-37, -55, 74, 74), Color.WHITE.lerp(color, 0.22), 1)
	if hp < max_hp:
		draw_rect(Rect2(-18, -25, 36, 3), Color("27334d"))
		draw_rect(Rect2(-18, -25, 36 * maxf(0.0, hp) / max_hp, 3), color)

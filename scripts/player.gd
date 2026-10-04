extends Node2D

const Balance = preload("res://scripts/balance.gd")
const Art = preload("res://scripts/art.gd")
const Classes = preload("res://scripts/classes.gd")
const SkillUpgrades = preload("res://scripts/skill_upgrades.gd")

signal experience_gained(amount: int)

var player_id := 0
var stats: Dictionary = Balance.starting_stats()
var hp := 100.0
var xp := 0 # Mirrored from the shared team pool for display only.
var level := 1 # Mirrored team level; upgrades and stats remain individual.
var kills := 0
var ranks: Dictionary = {}
var pending_upgrades := 0
var offers: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var downed := false
var choosing := false
var revive_progress := 0.0
var invulnerability := 2.0
var shot_cooldown := 0.0
var facing := Vector2.RIGHT
var walk_phase := 0.0
var moving := false
var role := Classes.GUNNER
var skill_cooldown := 0.0
var suppression_remaining := 0.0
var dash_remaining := 0.0
var dash_target := Vector2.ZERO
var return_origin := Vector2.ZERO
var return_remaining := 0.0
var last_move_direction := Vector2.RIGHT
var skill_stats: Dictionary = SkillUpgrades.starting_stats(Classes.GUNNER)
var skill_ranks: Dictionary = {}

func setup(id: int, spawn: Vector2) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_id = id
	position = spawn
	rng.randomize()
	# Even if constructed in the same microsecond, the choice streams differ.
	rng.seed = rng.seed ^ (id + 1) * 7919

func configure_class(selected_role: int) -> void:
	role = selected_role
	stats = Classes.starting_stats(role)
	skill_stats = SkillUpgrades.starting_stats(role)
	skill_ranks.clear()
	hp = float(stats.max_hp)
	skill_cooldown = 0.0
	suppression_remaining = 0.0
	dash_remaining = 0.0
	return_remaining = 0.0
	queue_redraw()

func attack_interval() -> float:
	return float(stats.interval) / (float(skill_stats.attack_rate) if suppression_remaining > 0.0 else 1.0)

func attack_range() -> float:
	return float(stats.range) * (float(skill_stats.range) if suppression_remaining > 0.0 else 1.0)

func movement_speed() -> float:
	return float(stats.speed) * (float(skill_stats.move_speed) if suppression_remaining > 0.0 else 1.0)

func end_raid() -> void:
	return_remaining = 0.0
	dash_remaining = 0.0
	skill_cooldown = float(skill_stats.cooldown)

func is_active() -> bool:
	return not downed

func advance(delta: float, movement: Vector2) -> void:
	invulnerability = maxf(0.0, invulnerability - delta)
	var cooldown_delta := delta
	if suppression_remaining > 0.0:
		# Suppression's cooldown starts after its active time, not during it.
		# Only time past the end of the effect counts on a crossing frame.
		cooldown_delta = maxf(0.0, delta - suppression_remaining)
		suppression_remaining = maxf(0.0, suppression_remaining - delta)
	skill_cooldown = maxf(0.0, skill_cooldown - cooldown_delta)
	if return_remaining > 0.0:
		return_remaining = maxf(0.0, return_remaining - delta)
		if return_remaining <= 0.0:
			end_raid()
	moving = is_active() and movement.length_squared() > 0.0
	if moving:
		walk_phase += delta * 12.0
	if is_active():
		if movement.length_squared() > 0.0:
			facing = movement.normalized()
			last_move_direction = facing
		if dash_remaining > 0.0:
			position = position.move_toward(dash_target, float(skill_stats.distance) / Classes.DASH_DURATION * delta)
			dash_remaining = maxf(0.0, dash_remaining - delta)
		else:
			position += movement.limit_length() * movement_speed() * delta
		position = position.clamp(Balance.ARENA.position + Vector2.ONE * 18.0,
			Balance.ARENA.end - Vector2.ONE * 18.0)
		hp = minf(float(stats.max_hp), hp + float(stats.regen) * delta)
		shot_cooldown = maxf(0.0, shot_cooldown - delta)
	queue_redraw()

func take_damage(amount: float) -> void:
	if not is_active() or invulnerability > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	invulnerability = 0.7
	if hp <= 0.0:
		downed = true
		suppression_remaining = 0.0
		if return_remaining > 0.0:
			end_raid()
		# Suspend the panel without losing its offers or pending upgrade.
		choosing = false
		revive_progress = 0.0
	queue_redraw()

func add_xp(amount: int) -> void:
	experience_gained.emit(amount)

func begin_choice() -> void:
	choosing = true
	if offers.is_empty():
		offers = SkillUpgrades.roll(rng, role)
	queue_redraw()

func choose(index: int) -> bool:
	if not choosing or index < 0 or index >= offers.size():
		return false
	SkillUpgrades.apply(self, str(offers[index].id))
	pending_upgrades -= 1
	offers.clear()
	choosing = false
	queue_redraw()
	return true

func revive() -> void:
	downed = false
	hp = float(stats.max_hp) * 0.5
	revive_progress = 0.0
	invulnerability = 3.0
	queue_redraw()

func _draw() -> void:
	var color: Color = Balance.PLAYER_COLORS[player_id]
	var texture := Art.sprite("hero")
	if downed:
		if texture != null:
			draw_texture_rect(texture, Rect2(-31, -30, 62, 62), false, Color(0.5, 0.5, 0.65, 0.45))
		draw_circle(Vector2.ZERO, 18.0, Color(color, 0.12))
		draw_line(Vector2(-9, -9), Vector2(9, 9), color, 4.0, true)
		draw_line(Vector2(-9, 9), Vector2(9, -9), color, 4.0, true)
		draw_arc(Vector2.ZERO, 25.0, -PI / 2.0,
			-PI / 2.0 + TAU * revive_progress / Balance.REVIVE_SECONDS, 32, Color("87f5b4"), 4.0, true)
		return
	draw_circle(Vector2.ZERO, 24.0, Color(color, 0.09))
	var opacity := 0.65 if invulnerability > 0.0 else 1.0
	if texture != null:
		draw_circle(Vector2(0, 14), 16.0, Color(0.0, 0.0, 0.0, 0.28))
		draw_arc(Vector2(0, 12), 21.0, 0, TAU, 32, color, 2.0, true)
		var bob := sin(walk_phase) * 2.0 if moving else 0.0
		draw_texture_rect(texture, Rect2(-34, -42 + bob, 68, 68), false, Color(1, 1, 1, opacity))
		# Reuse the hero atlas; class accessories and player markers distinguish roles.
		draw_string(ThemeDB.fallback_font, Vector2(-9, -33), "P%d" % (player_id + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
		draw_circle(facing * 23.0 + Vector2(0, 3), 3.5, color)
	else:
		draw_circle(Vector2.ZERO, Balance.PLAYER_RADIUS, Color(color, opacity))
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 32, Color("eaf5ff"), 1.5, true)
		draw_line(facing * 11.0, facing * 25.0, Color("eaf5ff"), 5.0, true)
	if choosing or invulnerability > 0.0:
		draw_arc(Vector2.ZERO, 29.0, 0, TAU, 48, Color(color, 0.55), 2.0, true)
	if suppression_remaining > 0.0:
		draw_arc(Vector2.ZERO, 36.0, 0, TAU, 48, Color("ffe8a1"), 3.0, true)
	if dash_remaining > 0.0:
		draw_line(-last_move_direction * 46.0, -last_move_direction * 12.0, Color(color, 0.65), 6.0, true)
	if role == Classes.RAIDER:
		draw_line(Vector2(20, -8), Vector2(27, -19), color, 3.0, true)
	else:
		draw_line(Vector2(-23, -12), Vector2(-23, -22), color, 2.0, true)
		draw_line(Vector2(-28, -17), Vector2(-18, -17), color, 2.0, true)
	# One dot for P1, two dots for P2, readable without color alone.
	if texture == null:
		for i in range(player_id + 1):
			draw_circle(Vector2(-player_id * 3.0 + i * 6.0, -4), 2.0, Color("122032"))
	draw_rect(Rect2(-20, 34, 40, 4), Color("26384a"))
	draw_rect(Rect2(-20, 34, 40 * hp / float(stats.max_hp), 4), color)

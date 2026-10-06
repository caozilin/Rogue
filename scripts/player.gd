extends Node2D

const Balance = preload("res://scripts/balance.gd")
const Art = preload("res://scripts/art.gd")
const Classes = preload("res://scripts/classes.gd")
const SkillUpgrades = preload("res://scripts/skill_upgrades.gd")
const Motion = preload("res://scripts/unit_motion.gd")

signal experience_gained(amount: int)
signal damage_received(amount: float, source_id: int)
signal fell

var player_id := 0
var stats: Dictionary = Balance.starting_stats()
var base_stats: Dictionary = Balance.starting_stats()
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
var tower_charges := Classes.TOWER_MAX_CHARGES
var tower_recharge := 0.0
var tower_release_cooldown := 0.0
var dash_remaining := 0.0
var dash_target := Vector2.ZERO
var dash_hit_ids: Dictionary = {} # Each enemy takes damage once per cast, independently per player.
var dash_cycle_hit_ids: Dictionary = {}
var dash_refund_total := 0.0
var dash_recast_remaining := 0.0
var dash_recast_armed := false
var dash_second_cast := false
var return_origin := Vector2.ZERO
var return_remaining := 0.0
var last_move_direction := Vector2.RIGHT
var skill_stats: Dictionary = SkillUpgrades.starting_stats(Classes.GUNNER)
var skill_ranks: Dictionary = {}
var skill_choices := 0
var warcry_remaining := 0.0
var warcry_cooldown := 0.0
var warcry_order := 0
var giant_remaining := 0.0
var giant_cooldown := 0.0
var giant_contact_cooldowns: Dictionary = {}
var giant_unique_hits: Dictionary = {}
var giant_chain_counts: Dictionary = {}
var giant_quakes := 0
var giant_cast_serial := 0
var giant_refund_total := 0.0
var blessing_remaining := 0.0
var blessing_shield := 0.0
var blessing_shield_max := 0.0
var guard_shield := 0.0
var counterattack_remaining := 0.0
var rescue_cooldown := 0.0
var carry_remaining := 0.0
var carrying = null
var carried_by = null
var fireball_cooldown := 0.0
var frost_cooldown := 0.0
var frost_remaining := 0.0
var frost_tick := 0.0
var frost_cone_tick := 0.0
var frost_path_tick := 0.0
var frost_path_position := Vector2.ZERO
var frost_shield_hp := 0.0
var cold_ward_protection := false
var possession_cooldown := 0.0
var possession_remaining := 0.0
var possession_host = null
var possessed_by = null
var motion := Motion.new()

func _ready() -> void:
	motion.attach(self)

func setup(id: int, spawn: Vector2) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	player_id = id
	position = spawn
	rng.randomize()
	# Even if constructed in the same microsecond, the choice streams differ.
	rng.seed = rng.seed ^ (id + 1) * 7919

func configure_class(selected_role: int) -> void:
	end_possession()
	end_carry()
	role = selected_role
	motion.reset(float(player_id) * 1.7)
	stats = Classes.starting_stats(role)
	base_stats = stats.duplicate(true)
	ranks.clear()
	skill_stats = SkillUpgrades.starting_stats(role)
	skill_ranks.clear()
	skill_choices = 0
	warcry_remaining = 0.0
	warcry_cooldown = 0.0
	warcry_order = 0
	giant_remaining = 0.0
	giant_cooldown = 0.0
	giant_contact_cooldowns.clear()
	giant_unique_hits.clear()
	giant_chain_counts.clear()
	giant_quakes = 0
	giant_cast_serial = 0
	giant_refund_total = 0.0
	blessing_remaining = 0.0
	blessing_shield = 0.0
	blessing_shield_max = 0.0
	guard_shield = 0.0
	counterattack_remaining = 0.0
	rescue_cooldown = 0.0
	fireball_cooldown = 0.0
	frost_cooldown = 0.0
	frost_remaining = 0.0
	frost_tick = 0.0
	frost_cone_tick = 0.0
	frost_path_tick = 0.0
	frost_shield_hp = 0.0
	cold_ward_protection = false
	possession_cooldown = 0.0
	hp = float(stats.max_hp)
	skill_cooldown = 0.0
	suppression_remaining = 0.0
	tower_charges = Classes.TOWER_MAX_CHARGES
	tower_recharge = 0.0
	tower_release_cooldown = 0.0
	dash_remaining = 0.0
	dash_hit_ids.clear()
	dash_cycle_hit_ids.clear()
	dash_refund_total = 0.0
	dash_recast_remaining = 0.0
	dash_recast_armed = false
	dash_second_cast = false
	return_remaining = 0.0
	queue_redraw()

func attack_interval() -> float:
	return float(stats.interval) / (float(skill_stats.attack_rate) if suppression_remaining > 0.0 else 1.0)

func attack_range() -> float:
	return float(stats.range) * (float(skill_stats.range) if suppression_remaining > 0.0 else 1.0) * skill_range_multiplier()

func movement_speed() -> float:
	var speed := float(stats.speed)
	if giant_remaining > 0.0:
		speed += float(base_stats.speed) * Classes.GIANT_SPEED_BONUS
	return speed * (float(skill_stats.move_speed) if suppression_remaining > 0.0 else 1.0)

func body_scale() -> float:
	return float(skill_stats.get("giant_size", Classes.GIANT_SIZE)) if giant_remaining > 0.0 and is_active() else 1.0

func collision_radius() -> float:
	return Balance.PLAYER_RADIUS * body_scale()

func is_carried() -> bool:
	return carried_by != null and is_instance_valid(carried_by) and carried_by.is_active() and carried_by.carry_remaining > 0.0

func visual_offset() -> Vector2:
	if is_possessed():
		return Vector2(0, -54) * possession_host.body_scale()
	return Vector2(18, -28) * carried_by.body_scale() if is_carried() else Vector2.ZERO

func is_possessed() -> bool:
	return possession_host != null and is_instance_valid(possession_host) and possession_host.is_active() and possession_remaining > 0.0

func is_targetable() -> bool:
	return is_active() and not is_possessed()

func output_damage() -> float:
	return float(stats.damage) * (1.35 if is_possessed() else 1.0) * (1.3 if counterattack_remaining > 0.0 else 1.0)

func guard_shield_max() -> float:
	return float(stats.max_hp) * float(skill_stats.guard_cap) if role == Classes.RAIDER else 0.0

func skill_range_multiplier() -> float:
	return 1.25 if is_possessed() else 1.0

func cooldown_recovery() -> float:
	return 1.25 if is_possessed() else 1.0

func end_possession() -> void:
	if possession_host != null and is_instance_valid(possession_host):
		position = possession_host.position
		possession_host.possessed_by = null
		possession_host.queue_redraw()
		invulnerability = maxf(invulnerability, 0.4)
	possession_host = null
	possession_remaining = 0.0
	if possessed_by != null and is_instance_valid(possessed_by):
		var mage = possessed_by
		possessed_by = null
		mage.end_possession()
	z_index = 0
	queue_redraw()

func end_carry() -> void:
	if carrying != null and is_instance_valid(carrying):
		carrying.position = position
		carrying.carried_by = null
		carrying.z_index = 0
		carrying.queue_redraw()
	carrying = null
	carry_remaining = 0.0
	if carried_by != null and is_instance_valid(carried_by):
		carried_by.carrying = null
		carried_by.carry_remaining = 0.0
		carried_by.queue_redraw()
	carried_by = null
	z_index = 0

func skill_name() -> String:
	return Classes.SKILL_NAMES[role]

func skill_binding() -> String:
	if role == Classes.RAIDER:
		return "Q" if player_id == 0 else "鼠标右键"
	return "空格" if player_id == 0 else "3"

func end_raid() -> void:
	return_remaining = 0.0
	dash_remaining = 0.0
	dash_recast_remaining = 0.0
	dash_recast_armed = false
	skill_cooldown = maxf(0.0, float(skill_stats.cooldown) - dash_refund_total)

func is_active() -> bool:
	return not downed

func advance(delta: float, movement: Vector2) -> void:
	if is_carried() or is_possessed():
		movement = Vector2.ZERO
	var recovery_delta := delta + (minf(delta, possession_remaining) * 0.25 if is_possessed() else 0.0)
	tower_release_cooldown = maxf(0.0, tower_release_cooldown - delta)
	if role == Classes.MAGE and tower_charges < Classes.TOWER_MAX_CHARGES:
		tower_recharge -= recovery_delta
		while tower_recharge <= 0.00001 and tower_charges < Classes.TOWER_MAX_CHARGES:
			tower_charges += 1
			tower_recharge += Classes.TOWER_RECHARGE
		if tower_charges == Classes.TOWER_MAX_CHARGES:
			tower_recharge = 0.0
	dash_recast_remaining = maxf(0.0, dash_recast_remaining - delta)
	var blessing_delta := minf(delta, blessing_remaining)
	counterattack_remaining = maxf(0.0, counterattack_remaining - delta)
	fireball_cooldown = maxf(0.0, fireball_cooldown - recovery_delta)
	frost_cooldown = maxf(0.0, frost_cooldown - recovery_delta)
	possession_cooldown = maxf(0.0, possession_cooldown - recovery_delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	rescue_cooldown = maxf(0.0, rescue_cooldown - delta)
	warcry_remaining = maxf(0.0, warcry_remaining - delta)
	warcry_cooldown = maxf(0.0, warcry_cooldown - delta)
	giant_cooldown = maxf(0.0, giant_cooldown - delta)
	for enemy_id in giant_contact_cooldowns.keys():
		giant_contact_cooldowns[enemy_id] -= delta
		if giant_contact_cooldowns[enemy_id] <= 0.0:
			giant_contact_cooldowns.erase(enemy_id)
	var movement_delta := delta
	var cooldown_delta := delta
	if suppression_remaining > 0.0:
		# Suppression's cooldown starts after its active time, not during it.
		# Only time past the end of the effect counts on a crossing frame.
		cooldown_delta = maxf(0.0, delta - suppression_remaining)
		suppression_remaining = maxf(0.0, suppression_remaining - delta)
	elif dash_remaining > 0.0 and not bool(skill_stats.get("return_enabled", false)):
		# Single dash starts the full cooldown after movement finishes.
		cooldown_delta = maxf(0.0, delta - dash_remaining)
	skill_cooldown = maxf(0.0, skill_cooldown - cooldown_delta * cooldown_recovery())
	if return_remaining > 0.0:
		return_remaining = maxf(0.0, return_remaining - delta)
		if return_remaining <= 0.0:
			end_raid()
	moving = is_active() and movement_delta > 0.0 and movement.length_squared() > 0.0
	if moving:
		walk_phase += delta * 12.0
	if is_active():
		if movement.length_squared() > 0.0:
			facing = movement.normalized()
			last_move_direction = facing
		if dash_remaining > 0.0:
			if not is_carried():
				position = position.move_toward(dash_target, float(skill_stats.distance) / Classes.DASH_DURATION * minf(delta, dash_remaining))
			dash_remaining = maxf(0.0, dash_remaining - delta)
			if dash_remaining <= 0.0 and dash_recast_armed:
				dash_recast_remaining = 2.0
				dash_recast_armed = false
		else:
			var travel := movement_speed() * movement_delta
			if giant_remaining > 0.0:
				# Crossing frames receive bonus speed only for the remaining active time.
				travel -= float(base_stats.speed) * Classes.GIANT_SPEED_BONUS * maxf(0.0, movement_delta - giant_remaining)
			position += movement.limit_length() * travel
		if not is_carried():
			var margin := collision_radius() + 2.0
			position = position.clamp(Balance.ARENA.position + Vector2.ONE * margin,
				Balance.ARENA.end - Vector2.ONE * margin)
		hp = minf(float(stats.max_hp), hp + float(stats.max_hp) * float(stats.regen) * delta)
		hp = minf(float(stats.max_hp), hp + float(stats.max_hp) * 0.03 * blessing_delta)
		if role == Classes.RAIDER:
			guard_shield = minf(guard_shield_max(), guard_shield + float(stats.max_hp) * float(skill_stats.guard_regen) * delta)
		shot_cooldown = maxf(0.0, shot_cooldown - delta)
	giant_remaining = maxf(0.0, giant_remaining - delta)
	carry_remaining = maxf(0.0, carry_remaining - delta)
	blessing_remaining = maxf(0.0, blessing_remaining - delta)
	if blessing_remaining <= 0.0:
		blessing_shield = 0.0
	queue_redraw()

func tenacity() -> float:
	return 0.5 if cold_ward_protection or blessing_remaining > 0.0 else 0.0

func knock_back(direction: Vector2, distance: float) -> void:
	if not is_targetable() or is_carried():
		return
	position += direction.normalized() * distance * (1.0 - tenacity())
	var margin := collision_radius() + 2.0
	position = position.clamp(Balance.ARENA.position + Vector2.ONE * margin, Balance.ARENA.end - Vector2.ONE * margin)

func take_damage(amount: float, source_id := 0) -> void:
	if not is_active() or invulnerability > 0.0 or is_possessed():
		return
	if is_carried():
		# Redirect raw damage once; only the carrier's protection applies.
		carried_by.take_damage(amount, source_id)
		return
	# Notify before shield absorption or any mitigation; raw damage is preserved.
	damage_received.emit(amount, source_id)
	var reduction := Classes.GIANT_DAMAGE_REDUCTION if giant_remaining > 0.0 else 0.0
	var received := amount * (1.0 - reduction) * (0.75 if cold_ward_protection else 1.0)
	var absorbed := minf(blessing_shield, received)
	blessing_shield -= absorbed
	received -= absorbed
	# Temporary shelter absorbs first, preserving the regenerating personal shield.
	absorbed = minf(guard_shield, received)
	guard_shield -= absorbed
	hp = maxf(0.0, hp - received + absorbed)
	invulnerability = 0.7
	if hp <= 0.0:
		downed = true
		end_possession()
		end_carry()
		frost_remaining = 0.0
		frost_shield_hp = 0.0
		cold_ward_protection = false
		suppression_remaining = 0.0
		warcry_remaining = 0.0
		giant_remaining = 0.0
		giant_contact_cooldowns.clear()
		blessing_remaining = 0.0
		blessing_shield = 0.0
		guard_shield = 0.0
		counterattack_remaining = 0.0
		dash_recast_remaining = 0.0
		dash_recast_armed = false
		dash_remaining = 0.0
		dash_hit_ids.clear()
		if return_remaining > 0.0:
			end_raid()
		# Suspend the panel without losing its offers or pending upgrade.
		choosing = false
		revive_progress = 0.0
		fell.emit()
	queue_redraw()

func add_xp(amount: int) -> void:
	experience_gained.emit(amount)

func begin_choice() -> void:
	if offers.is_empty():
		offers = SkillUpgrades.roll(rng, role, skill_ranks, skill_choices)
	choosing = not offers.is_empty()
	if not choosing:
		pending_upgrades = 0 # All skill entries capped: no empty choice may block combat.
	queue_redraw()

func choose(index: int) -> bool:
	if not choosing or index < 0 or index >= offers.size():
		return false
	if not SkillUpgrades.apply(self, str(offers[index].id)):
		return false
	pending_upgrades -= 1
	skill_choices += 1
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
	var texture := Art.character(role)
	if downed:
		motion.hide()
		if texture != null:
			draw_texture_rect(texture, Rect2(-40, -60, 80, 80), false, Color(0.5, 0.5, 0.65, 0.45))
		draw_circle(Vector2.ZERO, 18.0, Color(color, 0.12))
		draw_line(Vector2(-9, -9), Vector2(9, 9), color, 4.0, true)
		draw_line(Vector2(-9, 9), Vector2(9, -9), color, 4.0, true)
		draw_arc(Vector2.ZERO, 25.0, -PI / 2.0,
			-PI / 2.0 + TAU * revive_progress / Balance.REVIVE_SECONDS, 32, Color("87f5b4"), 4.0, true)
		return
	draw_set_transform(visual_offset(), 0.0, Vector2.ONE * body_scale())
	draw_circle(Vector2.ZERO, 24.0, Color(color, 0.09))
	var opacity := 0.65 if invulnerability > 0.0 else 1.0
	if texture != null:
		Art.shadow(self, Vector2(10, 12), Vector2(68, 27), 0.7)
		draw_set_transform(visual_offset() + Vector2(0, 10) * body_scale(), 0.0, Vector2(body_scale(), body_scale() * 0.45))
		draw_arc(Vector2.ZERO, 24.0, 0, TAU, 48, Color(color, 0.64), 1.6, true)
		draw_set_transform(visual_offset(), 0.0, Vector2.ONE * body_scale())
		motion.render(texture, Rect2(-48, -73, 96, 96), Color(1, 1, 1, opacity),
			3 if role == Classes.MAGE else 0, visual_offset(), body_scale())
		draw_string(ThemeDB.fallback_font, Vector2(-9, -72), "P%d" % (player_id + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
		draw_circle(facing * 23.0 + Vector2(0, 3), 3.5, color)
	else:
		motion.hide()
		draw_circle(Vector2.ZERO, Balance.PLAYER_RADIUS, Color(color, opacity))
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 32, Color("eaf5ff"), 1.5, true)
		draw_line(facing * 11.0, facing * 25.0, Color("eaf5ff"), 5.0, true)
	if choosing or invulnerability > 0.0:
		draw_arc(Vector2.ZERO, 29.0, 0, TAU, 48, Color(color, 0.55), 2.0, true)
	if warcry_remaining > 0.0:
		draw_arc(Vector2.ZERO, 32.0, 0, TAU, 48, Color("ff665f"), 3.0, true)
	if giant_remaining > 0.0:
		draw_arc(Vector2.ZERO, 27.0, 0, TAU, 48, Color("ffe08a"), 2.0, true)
	if suppression_remaining > 0.0:
		draw_arc(Vector2.ZERO, 36.0, 0, TAU, 48, Color("ffe8a1"), 3.0, true)
	if dash_remaining > 0.0:
		draw_line(-last_move_direction * 46.0, -last_move_direction * 12.0, Color(color, 0.65), 6.0, true)
	if is_possessed():
		draw_arc(Vector2.ZERO, 34.0, 0, TAU, 48, Color("bb91ff"), 3.0, true)
	if counterattack_remaining > 0.0:
		draw_arc(Vector2.ZERO, 38.0, -PI / 2.0, -PI / 2.0 + TAU * counterattack_remaining / 5.0, 48, Color("ffad66"), 2.0, true)
	# One dot for P1, two dots for P2, readable without color alone.
	if texture == null:
		for i in range(player_id + 1):
			draw_circle(Vector2(-player_id * 3.0 + i * 6.0, -4), 2.0, Color("122032"))
	draw_set_transform(Vector2.ZERO)
	var bar_y := 34.0 * body_scale()
	draw_rect(Rect2(visual_offset() + Vector2(-20, bar_y), Vector2(40, 4)), Color("26384a"))
	draw_rect(Rect2(visual_offset() + Vector2(-20, bar_y), Vector2(40 * hp / float(stats.max_hp), 4)), color)
	if guard_shield > 0.0:
		draw_rect(Rect2(visual_offset() + Vector2(-20, bar_y + 6), Vector2(40, 3)), Color("26384a"))
		draw_rect(Rect2(visual_offset() + Vector2(-20, bar_y + 6), Vector2(40 * guard_shield / guard_shield_max(), 3)), Color("8cdbff"))

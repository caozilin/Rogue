extends Node2D
## One simulation owner keeps ordering explicit and makes headless tests possible.
## Nodes draw themselves; no physics bodies or resource imports are required.

const Balance = preload("res://scripts/balance.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Gem = preload("res://scripts/xp_gem.gd")
const HUD = preload("res://scripts/hud.gd")
const Classes = preload("res://scripts/classes.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
const SkillUpgrades = preload("res://scripts/skill_upgrades.gd")
const Barrage = preload("res://scripts/barrage.gd")
const EnemyBullet = preload("res://scripts/enemy_bullet.gd")
const EnemyHazard = preload("res://scripts/enemy_hazard.gd")
const MiniBoss = preload("res://scripts/mini_boss.gd")
const ThornBoss = preload("res://scripts/thorn_boss.gd")
const BossGuard = preload("res://scripts/boss_guard.gd")
const ThornHazard = preload("res://scripts/thorn_hazard.gd")
const FinalBoss = preload("res://scripts/final_boss.gd")
const RangedFinalBoss = preload("res://scripts/ranged_final_boss.gd")
const MilkBoss = preload("res://scripts/milk_boss.gd")
const MilkHazard = preload("res://scripts/milk_hazard.gd")
const MilkClone = preload("res://scripts/milk_clone.gd")
const MilkAnnouncement = preload("res://scripts/milk_announcement.gd")
const ArtilleryHazard = preload("res://scripts/artillery_hazard.gd")
const BossEffects = preload("res://scripts/boss_effects.gd")
const Mage = preload("res://scripts/mage.gd")
const Warrior = preload("res://scripts/warrior.gd")
const Arena = preload("res://scripts/arena.gd")
const DamageNumbers = preload("res://scripts/damage_numbers.gd")
const DamageSources = preload("res://scripts/damage_sources.gd")

var players: Array = []
var enemies: Array = []
var projectiles: Array = []
var enemy_bullets: Array = []
var enemy_hazards: Array = []
var gems: Array = []
var world: Node2D
var mage_system: Node2D
var warrior_system: Node2D
var boss_effects: Node2D
var hud: CanvasLayer
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var spawn_credit := 0.0
var spawn_serial := 0
var next_wave := Balance.FIRST_WAVE_SECONDS
var next_boss := Balance.FIRST_BOSS_SECONDS
var mini_boss = null
var boss_encounters := 0
var pending_boss_support: Array[Dictionary] = []
var boss_victory_name := ""
var boss_notice := ""
var boss_notice_remaining := 0.0
var paused := false
var game_over := false
var final_battle := false
var final_stage := 0
var final_transition_remaining := 0.0
var milk_rebirth_cleanup := false
var pending_milk_clones: Array = []
var milk_announcement: Node2D
var victory := false
var milestone := false
var hud_clock := 0.0
var damage_events: Array[Dictionary] = []
var damage_numbers: Node2D
var damage_serial := 0
var damage_totals: Array[float] = [0.0, 0.0]
var damage_breakdown: Array[Dictionary] = [{}, {}]
var damage_inspecting := false
var shared_xp := 0
var team_level := 1
var selecting_classes := true
var breakthrough_mode := false
var selected_difficulty := 0
var opening_major_pending := [0, 0]
var selected_classes := [Classes.GUNNER, Classes.RAIDER]
var class_ready := [false, false]
var skill_effects: Array[Dictionary] = []
var team_pending_upgrades := 0
var team_choosing := false
var team_offers: Array[Dictionary] = []
var warcry_serial := 0
var instant_revive_used := false # One immediate rescue revival shared by the whole run.
var team_revive_used := false # Separate automatic second chance when both players fall.
var team_revive_notice_remaining := 0.0
const TauntDummy = preload("res://scripts/taunt_dummy.gd")
var taunt_dummies: Array = []

func damageable_targets() -> Array:
	var targets: Array = players.duplicate()
	for dummy in taunt_dummies:
		if dummy.is_active(): targets.append(dummy)
	return targets

func _ready() -> void:
	rng.randomize()
	_setup_input()
	add_child(Arena.new())
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	damage_numbers = DamageNumbers.new()
	damage_numbers.game = self
	add_child(damage_numbers)
	mage_system = Mage.new()
	mage_system.game = self
	world.add_child(mage_system)
	warrior_system = Warrior.new()
	warrior_system.game = self
	world.add_child(warrior_system)
	boss_effects = BossEffects.new()
	boss_effects.game = self
	world.add_child(boss_effects)
	for id in range(2):
		var player := Player.new()
		player.setup(id, Vector2(570 + id * 140, 400))
		player.experience_gained.connect(add_shared_xp)
		player.fell.connect(mage_system.refresh_wards)
		player.damage_received.connect(warrior_system.queue_reflection.bind(player))
		world.add_child(player)
		players.append(player)
		player.configure_class(selected_classes[id])
	hud = HUD.new()
	hud.game = self
	add_child(hud)
	var announcement_layer := CanvasLayer.new()
	announcement_layer.layer = 9
	add_child(announcement_layer)
	milk_announcement = MilkAnnouncement.new()
	announcement_layer.add_child(milk_announcement)
	hud.refresh()
	queue_redraw()

func _setup_input() -> void:
	var bindings := {"p1_left": KEY_A, "p1_right": KEY_D, "p1_up": KEY_W,
		"p1_down": KEY_S, "p2_left": KEY_LEFT, "p2_right": KEY_RIGHT,
		"p2_up": KEY_UP, "p2_down": KEY_DOWN}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action, event)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return
	if simulation_speed() == 0.0:
		return
	# Mouse events are in viewport coordinates; account for the canvas transform.
	var target: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	var activated := false
	if players[1].role == Classes.MAGE:
		activated = activate_mage_skill(1, 1)
	elif players[1].role == Classes.RAIDER:
		var direction: Vector2 = target - players[1].position
		if direction.length_squared() > 0.0001:
			activated = activate_skill(1, direction)
	if activated:
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if damage_inspecting:
		if key == KEY_ESCAPE: hud.damage_details.close()
		get_viewport().set_input_as_handled()
		return
	if selecting_classes:
		if key == KEY_1 or key == KEY_2:
			select_class(0, 0 if key == KEY_1 else 1)
		elif key in [KEY_7, KEY_KP_7, KEY_8, KEY_KP_8]:
			select_class(1, 0 if key in [KEY_7, KEY_KP_7] else 1)
		elif key == KEY_SPACE:
			toggle_ready(0)
		elif key in [KEY_ENTER, KEY_KP_ENTER]:
			toggle_ready(1)
	elif key == KEY_ESCAPE and not game_over:
		paused = not paused
		hud.refresh()
	elif key == KEY_R and game_over:
		restart()
	elif not paused and not game_over:
		var mage_keys := {KEY_Q: 1, KEY_E: 2, KEY_R: 3}
		if mage_keys.has(key):
			if players[0].role == Classes.RAIDER:
				if key == KEY_Q:
					# Share fireball targeting, including rank priority and distance ties.
					var target = mage_system.highest_enemy(players[0])
					if target != null:
						var direction: Vector2 = players[0].position.direction_to(target.position)
						if direction == Vector2.ZERO:
							direction = players[0].facing
						activate_skill(0, direction)
				else:
					activate_warrior_skill(0, int(mage_keys[key]) - 1)
			else:
				activate_mage_skill(0, int(mage_keys[key]))
			get_viewport().set_input_as_handled()
			return
		var warrior_keys := {KEY_1: 1, KEY_KP_1: 1, KEY_2: 2, KEY_KP_2: 2, KEY_3: 3, KEY_KP_3: 3}
		if warrior_keys.has(key):
			if players[1].role == Classes.MAGE:
				var slot: int = warrior_keys[key]
				if slot == 3:
					activate_skill(1)
				else:
					activate_mage_skill(1, slot + 1)
			else:
				activate_warrior_skill(1, int(warrior_keys[key]))
			get_viewport().set_input_as_handled()
			return
		if key == KEY_SPACE:
			if players[0].role == Classes.MAGE:
				activate_skill(0)
			else:
				activate_warrior_skill(0, 3)
	get_viewport().set_input_as_handled()

func select_class(id: int, role: int) -> void:
	if not selecting_classes or id not in [0, 1] or role not in [Classes.GUNNER, Classes.RAIDER]:
		return
	selected_classes[id] = role
	class_ready[id] = false
	players[id].configure_class(role)
	hud.refresh()

func toggle_ready(id: int) -> void:
	if not selecting_classes:
		return
	class_ready[id] = not class_ready[id]
	if class_ready[0] and class_ready[1]:
		start_run()
	else:
		hud.refresh()

func select_mode(enabled: bool) -> void:
	if not selecting_classes: return
	breakthrough_mode = enabled
	class_ready = [false, false]
	hud.refresh()

func select_difficulty(index: int) -> void:
	if not selecting_classes or breakthrough_mode or index < 0 or index >= Balance.RUN_DIFFICULTIES.size(): return
	selected_difficulty = index
	class_ready = [false, false]
	hud.refresh()

func run_difficulty() -> Dictionary:
	return Balance.RUN_DIFFICULTIES[0 if breakthrough_mode else selected_difficulty]

func choosing_opening_majors() -> bool:
	return opening_major_pending[0] > 0 or opening_major_pending[1] > 0

func _apply_enemy_difficulty(enemy) -> void:
	var tuning := run_difficulty()
	enemy.max_hp *= float(tuning.health)
	enemy.hp = enemy.max_hp
	enemy.damage *= float(tuning.damage)
	if enemy is MilkBoss:
		enemy.second_life_hp *= float(tuning.health)
		enemy.second_life_damage *= float(tuning.damage)

func start_run() -> void:
	if not selecting_classes:
		return
	for id in range(2):
		players[id].configure_class(selected_classes[id])
	selecting_classes = false
	if breakthrough_mode:
		for player in players:
			for entry in Upgrades.CATALOG:
				for rank in range(Upgrades.MAX_RANK): Upgrades.apply(player, entry.id)
			for entry in SkillUpgrades.ordinary_pool(player.role):
				for rank in range(SkillUpgrades.MAX_RANK):
					if SkillUpgrades.apply(player, entry.id): player.skill_choices += 1
			for entry in SkillUpgrades.major_pool(player.role):
				if SkillUpgrades.apply(player, entry.id): player.skill_choices += 1
			if player.role == Classes.RAIDER: player.guard_shield = player.guard_shield_max()
		_spawn_final_boss()
	else:
		# Begin the normal edge stream immediately, without a nearby opening group.
		spawn_credit = 1.0
		var opening_count := int(run_difficulty().starting_majors)
		opening_major_pending = [opening_count, opening_count]
		if choosing_opening_majors(): _begin_pending_choices()
		else: _update_spawning(0.0)
	hud.refresh()

func activate_skill(id: int, movement := Vector2.ZERO) -> bool:
	if simulation_speed() == 0.0 or id not in [0, 1]:
		return false
	var player = players[id]
	if not player.is_active():
		return false
	if player.role == Classes.RAIDER:
		return warrior_system.activate_dash(id, movement)
	return mage_system.activate_tower(id)

func activate_mage_skill(id: int, slot: int) -> bool:
	return mage_system.activate(id, slot)

func activate_warrior_skill(id: int, slot: int) -> bool:
	if simulation_speed() == 0.0 or id < 0 or id >= players.size():
		return false
	var player = players[id]
	if player.role != Classes.RAIDER or not player.is_active():
		return false
	if slot == 1:
		if player.warcry_cooldown > 0.0:
			return false
		player.warcry_remaining = float(player.skill_stats.warcry_duration)
		player.warcry_cooldown = Classes.WARCRY_COOLDOWN
		warcry_serial += 1
		player.warcry_order = warcry_serial
		var taunt_target = player
		if bool(player.skill_stats.warcry_dummy):
			player.warcry_remaining = 0.0
			var dummy = TauntDummy.new()
			dummy.position = player.position
			dummy.max_hp = float(player.stats.max_hp) * float(player.skill_stats.dummy_hp)
			dummy.hp = dummy.max_hp
			dummy.warcry_remaining = float(player.skill_stats.dummy_duration)
			dummy.warcry_order = warcry_serial
			dummy.owner_id = id
			dummy.player_id = -1 - warcry_serial
			world.add_child(dummy)
			taunt_dummies.append(dummy)
			taunt_target = dummy
		for enemy in enemies:
			enemy.set_priority_target(taunt_target, true)
		skill_effects.append({"position": player.position, "color": Color("ff665f"), "life": 0.35})
	elif slot == 2:
		if player.giant_cooldown > 0.0 or player.giant_remaining > 0.0:
			return false
		warrior_system.begin_giant(player)
		var margin: float = player.collision_radius() + 2.0
		if not player.is_carried():
			player.position = player.position.clamp(Balance.ARENA.position + Vector2.ONE * margin,
				Balance.ARENA.end - Vector2.ONE * margin)
	elif slot == 3:
		if player.rescue_cooldown > 0.0:
			return false
		var ally = players[1 - id]
		# Keep possession and rescue links separate; never create a linked cycle.
		if player.possessed_by != null or ally.is_possessed():
			return false
		# A carried warrior may rescue too: replace the link instead of making a cycle.
		player.end_carry()
		if player.dash_remaining > 0.0 or player.return_remaining > 0.0:
			player.end_raid()
		_clear_marks(id)
		player.position = ally.position
		player.rescue_cooldown = Classes.RESCUE_COOLDOWN
		player.invulnerability = maxf(player.invulnerability, 1.0)
		if ally.downed:
			if not instant_revive_used:
				instant_revive_used = true
				ally.revive()
		else:
			player.carrying = ally
			player.carry_remaining = Classes.RESCUE_DURATION
			ally.carried_by = player
			ally.z_index = 2
			ally.queue_redraw()
		warrior_system.grant_rescue_blessing(player, ally)
		warrior_system.grant_rescue_counterattack(player, ally)
		skill_effects.append({"position": player.position, "color": Color("87f5b4"), "life": 0.35})
	else:
		return false
	player.queue_redraw()
	hud.refresh()
	return true

func _clear_marks(id: int) -> void:
	for enemy in enemies:
		if enemy.marks.erase(id):
			enemy.queue_redraw()

func marked_count(id: int) -> int:
	var count := 0
	for enemy in enemies:
		if not enemy.dead and enemy.marks.has(id):
			count += 1
	return count

func _mark_dash(id: int, start: Vector2, end: Vector2) -> void:
	for enemy in enemies:
		if enemy.dead:
			continue
		var nearest := Geometry2D.get_closest_point_to_segment(enemy.position, start, end)
		if nearest.distance_squared_to(enemy.position) <= pow(enemy.radius + Balance.PLAYER_RADIUS + 6.0, 2):
			enemy.marks[id] = true
			enemy.queue_redraw()

func _damage_dash(id: int, start: Vector2, end: Vector2) -> void:
	warrior_system.hit_dash(id, start, end)

func add_shared_xp(amount: int) -> void:
	if selecting_classes or breakthrough_mode or game_over or amount <= 0:
		return
	shared_xp += amount
	while shared_xp >= Balance.xp_required(team_level):
		shared_xp -= Balance.xp_required(team_level)
		team_level += 1
		team_pending_upgrades += 1
		for player in players:
			player.pending_upgrades += 1
	for player in players:
		player.xp = shared_xp
		player.level = team_level
	_begin_pending_choices()
	if hud != null:
		hud.refresh()

func _begin_pending_choices() -> void:
	if game_over:
		return
	if team_pending_upgrades > 0 and not team_choosing:
		team_offers = Upgrades.roll(rng, players[0].ranks)
		team_choosing = not team_offers.is_empty()
		if not team_choosing:
			team_pending_upgrades = 0 # All team entries capped: skip an empty window.
	for player in players:
		if opening_major_pending[player.player_id] > 0:
			if not player.choosing:
				player.offers = SkillUpgrades.roll(player.rng, player.role, player.skill_ranks, 2)
				player.choosing = not player.offers.is_empty()
			continue
		if player.pending_upgrades > 0 and not player.choosing:
			player.begin_choice()

func has_pending_upgrades() -> bool:
	if choosing_opening_majors(): return true
	if team_pending_upgrades > 0:
		return true
	for player in players:
		if player.pending_upgrades > 0:
			return true
	return false

func choose_team_upgrade(index: int) -> bool:
	if selecting_classes or paused or game_over or not team_choosing or index < 0 or index >= team_offers.size():
		return false
	if not Upgrades.available(str(team_offers[index].id), players[0].ranks):
		return false
	for player in players:
		Upgrades.apply(player, str(team_offers[index].id))
	team_pending_upgrades -= 1
	team_offers.clear()
	team_choosing = false
	_begin_pending_choices()
	hud.refresh()
	return true

func choose_upgrade(id: int, index: int) -> bool:
	if selecting_classes or paused or game_over or id < 0 or id >= players.size():
		return false
	var player = players[id]
	if opening_major_pending[id] > 0:
		if not player.choosing or index < 0 or index >= player.offers.size(): return false
		if not SkillUpgrades.apply(player, str(player.offers[index].id)): return false
		opening_major_pending[id] -= 1
		player.offers.clear()
		player.choosing = false
		# Opening gifts do not consume the every-third-upgrade major schedule.
		if not choosing_opening_majors(): _update_spawning(0.0)
	elif not player.choose(index):
		return false
	# Each player advances their own choices without waiting for the other.
	_begin_pending_choices()
	hud.refresh()
	return true

func restart() -> void:
	get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	if not paused and not game_over:
		var movement := [Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down"),
			Input.get_vector("p2_left", "p2_right", "p2_up", "p2_down")]
		simulate(delta, movement)
	hud_clock += delta
	if hud_clock >= 0.1:
		hud_clock = 0.0
		hud.refresh()
	queue_redraw()

func simulation_speed() -> float:
	if selecting_classes or paused or damage_inspecting or game_over or has_pending_upgrades():
		return 0.0
	if milk_announcement != null and milk_announcement.is_active(): return 0.0
	return 1.0

func _advance_milk_cut_in(delta: float) -> void:
	# Presentation uses real time. Actors, projectiles, HP and cooldowns stay frozen.
	# Only existing background visual effects drift at 12% speed, never causing damage.
	milk_announcement.advance(delta)
	boss_effects.advance(delta*0.12)
	if is_instance_valid(mini_boss) and mini_boss is MilkBoss:
		mini_boss.spin += delta*0.12
		mini_boss.visual_system.advance(delta*0.12)
		mini_boss.queue_redraw()

func resolve_team_defeat() -> void:
	if not players[0].downed or not players[1].downed or victory: return
	if not team_revive_used:
		team_revive_used = true
		team_revive_notice_remaining = 5.0
		for player in players:
			player.revive()
			player.hp = float(player.stats.max_hp)
			warrior_system.effect("blessing", {"position": player.position, "radius": 85.0}, 0.9)
		_begin_pending_choices()
	else:
		game_over = true
	hud.refresh()

func simulate(delta: float, movement: Array) -> void:
	if milk_announcement.is_active() and not selecting_classes and not paused and not damage_inspecting and not game_over and not has_pending_upgrades():
		_advance_milk_cut_in(delta)
		return
	if simulation_speed() == 0.0:
		return
	if milk_rebirth_cleanup:
		for bullet in projectiles: bullet.queue_free()
		projectiles.clear()
		milk_rebirth_cleanup = false
	elapsed += delta
	milk_announcement.tick_interval(delta)
	for dummy in taunt_dummies: dummy.advance(delta)
	for index in range(taunt_dummies.size() - 1, -1, -1):
		if not taunt_dummies[index].is_active():
			taunt_dummies[index].queue_free()
			taunt_dummies.remove_at(index)
	team_revive_notice_remaining = maxf(0.0, team_revive_notice_remaining - delta)
	boss_effects.advance(delta)
	boss_notice_remaining = maxf(0.0, boss_notice_remaining - delta)
	milestone = elapsed >= Balance.FINAL_BOSS_SECONDS
	var player_starts: Array[Vector2] = []
	var player_dashing: Array[bool] = []
	for id in range(2):
		var start: Vector2 = players[id].position
		player_starts.append(start)
		player_dashing.append(players[id].dash_remaining > 0.0)
		players[id].advance(delta, movement[id])
	_update_carries()
	mage_system.update_links(delta)
	for id in range(players.size()):
		var player = players[id]
		if player.is_active():
			player.motion.advance(delta, player.position - player_starts[id], 78.0,
				player_dashing[id], player.is_carried() or player.is_possessed())
	for id in range(2):
		# Resolve damage against actual movement after the carried position is synced.
		if player_dashing[id] and players[id].is_active():
			if bool(players[id].skill_stats.get("return_enabled", false)):
				if players[id].return_remaining > 0.0:
					_mark_dash(id, player_starts[id], players[id].position)
			else:
				_damage_dash(id, player_starts[id], players[id].position)
		if players[id].dash_remaining <= 0.0:
			players[id].dash_hit_ids.clear()
		if players[id].return_remaining <= 0.0 or players[id].downed:
			_clear_marks(id)
	_update_revives(delta)
	if game_over: return
	_update_spawning(delta)
	if milk_announcement.is_active(): return
	_update_giant_contacts(player_starts)
	warrior_system.advance(delta)
	mage_system.advance(delta)
	if game_over: return
	if milk_announcement.is_active(): return
	for enemy in enemies:
		if enemy.dead:
			continue
		var target = priority_enemy_target(enemy.position)
		if enemy is FinalBoss or enemy is ThornBoss:
			enemy.combat_players = [target] if target is TauntDummy else players
		enemy.set_priority_target(target, target != null and target.warcry_remaining > 0.0)
		var animation_start: Vector2 = enemy.position
		enemy.advance(delta, target)
		boss_effects.observe(enemy, animation_start)
		var stride: float = clampf(enemy.radius * 3.0, 32.0, 115.0)
		enemy.motion.advance(delta, enemy.position - animation_start, stride, enemy.knockback_remaining > 0.0)
		if milk_announcement.is_active(): break
		if not enemy is FinalBoss and target != null and enemy.position.distance_squared_to(target.position) < pow(enemy.radius + target.collision_radius(), 2):
			if enemy.stagger_remaining <= 0.0 and enemy.knockback_remaining <= 0.0 and enemy.contact_cooldown <= 0.0 and target.invulnerability <= 0.0:
				target.take_damage(enemy.contact_damage(), enemy.get_instance_id())
				enemy.contact_cooldown = 0.7
			# Slight recoil prevents perfect stacking on a player.
			if target.giant_remaining <= 0.0:
				enemy.position += target.position.direction_to(enemy.position) * 720.0 * delta
	if milk_announcement.is_active(): return
	warrior_system.after_enemy_move(delta)
	warrior_system.flush_reflections()
	if game_over: return
	if players[0].downed and players[1].downed:
		resolve_team_defeat()
		return
	_flush_boss_support()
	_flush_milk_clones()
	for player in players:
		if player.is_active() and player.shot_cooldown <= 0.0:
			_fire(player)
	_update_projectiles(delta)
	if game_over: return
	if milk_announcement.is_active(): return
	_update_enemy_attacks(delta)
	warrior_system.flush_reflections()
	if game_over: return
	if players[0].downed and players[1].downed:
		resolve_team_defeat()
		return
	_update_gems(delta)
	for event in damage_events:
		event.life -= delta
	damage_events = damage_events.filter(func(event): return event.life > 0.0)
	damage_numbers.queue_redraw()
	for effect in skill_effects:
		effect.life -= delta
	skill_effects = skill_effects.filter(func(effect): return effect.life > 0.0)

func _update_carries() -> void:
	for player in players:
		if player.carrying == null:
			continue
		if not is_instance_valid(player.carrying) or not player.is_active() or not player.carrying.is_active() or player.carry_remaining <= 0.0:
			player.end_carry()
			continue
		player.carrying.position = player.position
		player.carrying.moving = player.moving
		player.carrying.queue_redraw()

func _update_giant_contacts(player_starts: Array[Vector2]) -> void:
	warrior_system.giant_contacts(player_starts)

func priority_enemy_target(at: Vector2):
	var taunter = null
	for player in damageable_targets():
		if player.is_active() and player.warcry_remaining > 0.0:
			if taunter == null or player.warcry_order > taunter.warcry_order:
				taunter = player
	return taunter if taunter != null else nearest_active_player(at)

func nearest_active_player(at: Vector2):
	var target = null
	var best := INF
	for player in players:
		if not player.is_targetable():
			continue
		var distance: float = at.distance_squared_to(player.position)
		if distance < best:
			best = distance
			target = player
	return target

func _update_revives(delta: float) -> void:
	for player in players:
		if not player.downed:
			continue
		var ally = players[1 - player.player_id]
		if ally.is_active() and ally.position.distance_to(player.position) <= Balance.REVIVE_RADIUS:
			player.revive_progress += delta
			if player.revive_progress >= Balance.REVIVE_SECONDS:
				player.revive()
		else:
			player.revive_progress = maxf(0.0, player.revive_progress - delta * 2.0)

func _update_spawning(delta: float) -> void:
	if elapsed >= Balance.FINAL_BOSS_SECONDS and not final_battle:
		_spawn_final_boss()
	if final_battle:
		if final_stage in [1, 2] and final_transition_remaining > 0.0:
			final_transition_remaining = maxf(0.0, final_transition_remaining - delta)
			if final_transition_remaining == 0.0:
				if final_stage == 1: _spawn_ranged_final_boss()
				else: _spawn_milk_final_boss()
		return
	if elapsed >= next_boss and boss_encounters < 2:
		_spawn_mini_boss()
	var tuning := Balance.difficulty(elapsed)
	var crowd_multiplier := Balance.BOSS_CROWD_MULTIPLIER if boss_alive() else 1.0
	spawn_credit = minf(3.0, spawn_credit + float(tuning.spawn_rate) * crowd_multiplier * delta)
	var regular_limit := _regular_enemy_limit()
	while spawn_credit >= 1.0 and enemies.size() < regular_limit:
		spawn_credit -= 1.0
		var spawn := Vector2.ZERO
		for attempt in range(12):
			match rng.randi_range(0, 3):
				0: spawn = Vector2(Balance.ARENA.position.x - 26, rng.randf_range(112, 702))
				1: spawn = Vector2(Balance.ARENA.end.x + 26, rng.randf_range(112, 702))
				2: spawn = Vector2(rng.randf_range(32, 1248), Balance.ARENA.position.y - 26)
				3: spawn = Vector2(rng.randf_range(32, 1248), Balance.ARENA.end.y + 26)
			var safe := true
			for player in players:
				if not player.downed and spawn.distance_to(player.position) < 160.0:
					safe = false
			if safe:
				break
		_spawn_enemy(spawn)
	if elapsed >= next_wave:
		next_wave += Balance.WAVE_INTERVAL
		# Two opposing groups create a squeeze, leaving the other two sides open.
		var horizontal := rng.randf() < 0.5
		var center := rng.randf_range(280.0, 1000.0) if horizontal else rng.randf_range(240.0, 570.0)
		var wave_count := mini(2, Balance.wave_size(elapsed)) if boss_alive() else Balance.wave_size(elapsed)
		for index in range(wave_count):
			var offset := (float(index / 2) - float(wave_count) / 4.0) * 38.0
			var spawn: Vector2
			if horizontal:
				spawn = Vector2(clampf(center + offset, 60.0, 1220.0), 86.0 if index % 2 == 0 else 728.0)
			else:
				spawn = Vector2(6.0 if index % 2 == 0 else 1274.0, clampf(center + offset, 140.0, 675.0))
			_spawn_enemy(spawn)

func _spawn_enemy(at: Vector2) -> void:
	if final_battle or enemies.size() >= _regular_enemy_limit():
		return
	spawn_serial += 1
	var kind := Balance.enemy_kind(elapsed, spawn_serial)
	if Barrage.is_ranged(kind):
		var ranged_count := 0
		for existing in enemies:
			if not existing.dead and Barrage.is_ranged(existing.kind):
				ranged_count += 1
		if ranged_count >= Balance.MAX_RANGED_ENEMIES:
			kind = "normal"
	var enemy := Enemy.new()
	enemy.setup(at, Balance.difficulty(elapsed), kind == "elite", kind)
	_apply_enemy_difficulty(enemy)
	enemy.ranged_attack.connect(_fire_enemy_pattern)
	world.add_child(enemy)
	enemies.append(enemy)

func boss_alive() -> bool:
	return is_instance_valid(mini_boss) and not mini_boss.dead

func _regular_enemy_limit() -> int:
	for enemy in enemies:
		if not enemy.dead and enemy is ThornBoss: return Balance.MAX_ENEMIES - 3
	return Balance.MAX_ENEMIES - 1 if boss_encounters < 2 else Balance.MAX_ENEMIES

func _boss_edge_position() -> Vector2:
	match rng.randi_range(0, 3):
		0: return Vector2(Balance.ARENA.position.x - 60, rng.randf_range(220, 590))
		1: return Vector2(Balance.ARENA.end.x + 60, rng.randf_range(220, 590))
		2: return Vector2(rng.randf_range(220, 1060), Balance.ARENA.position.y - 60)
	return Vector2(rng.randf_range(220, 1060), Balance.ARENA.end.y + 60)

func _spawn_mini_boss() -> void:
	if final_battle or selecting_classes or game_over or boss_encounters >= 2 or elapsed < next_boss:
		return
	# Scheduled bosses have priority over a full ordinary-enemy budget.
	if enemies.size() >= Balance.MAX_ENEMIES:
		for index in range(enemies.size() - 1, -1, -1):
			if enemies[index].kind != "boss":
				enemies[index].dead = true
				enemies[index].queue_free()
				enemies.remove_at(index)
				break
	mini_boss = MiniBoss.new() if boss_encounters == 0 else ThornBoss.new()
	if mini_boss is ThornBoss:
		mini_boss.combat_players = players
		mini_boss.ground_attack.connect(_fire_ground_pattern)
		mini_boss.summon_guards.connect(_queue_boss_support)
	mini_boss.setup_boss(_boss_edge_position(), Balance.difficulty(elapsed), Balance.xp_required(team_level))
	_apply_enemy_difficulty(mini_boss)
	mini_boss.ranged_attack.connect(_fire_enemy_pattern)
	world.add_child(mini_boss)
	enemies.append(mini_boss)
	boss_encounters += 1
	next_boss = Balance.FIRST_BOSS_SECONDS + boss_encounters * Balance.BOSS_INTERVAL
	hud.refresh()

func _spawn_final_boss() -> void:
	if final_battle or selecting_classes or game_over: return
	final_battle = true
	final_stage = 1
	# End the crowd encounter completely, including surviving minibosses and pending guards.
	for enemy in enemies:
		enemy.dead = true
		enemy.queue_free()
	enemies.clear()
	_clear_hostile_attacks()
	for bullet in projectiles: bullet.queue_free()
	projectiles.clear()
	pending_boss_support.clear()
	spawn_credit = 0.0
	boss_notice_remaining = 0.0
	mini_boss = FinalBoss.new()
	mini_boss.combat_players = players
	mini_boss.setup_boss(_boss_edge_position(), Balance.difficulty(Balance.FINAL_BOSS_SECONDS), 0)
	_apply_breakthrough_health(mini_boss, "melee")
	_apply_enemy_difficulty(mini_boss)
	mini_boss.melee_strike.connect(_resolve_final_strike)
	world.add_child(mini_boss)
	enemies.append(mini_boss)
	hud.refresh()

func _clear_hostile_attacks() -> void:
	for bullet in enemy_bullets: bullet.queue_free()
	enemy_bullets.clear()
	for hazard in enemy_hazards: hazard.queue_free()
	enemy_hazards.clear()

func _spawn_ranged_final_boss() -> void:
	if not final_battle or final_stage != 1 or boss_alive() or game_over: return
	final_stage = 2
	boss_notice_remaining = 0.0
	mini_boss = RangedFinalBoss.new()
	mini_boss.combat_players = players
	mini_boss.setup_boss(_boss_edge_position(), Balance.difficulty(Balance.FINAL_BOSS_SECONDS), 0)
	_apply_breakthrough_health(mini_boss, "artillery")
	_apply_enemy_difficulty(mini_boss)
	mini_boss.artillery_volley.connect(_fire_artillery_volley)
	mini_boss.artillery_bombardment.connect(_fire_artillery_bombardment)
	world.add_child(mini_boss)
	enemies.append(mini_boss)
	hud.refresh()

func _spawn_milk_final_boss() -> void:
	if not final_battle or final_stage != 2 or boss_alive() or game_over: return
	final_stage = 3
	boss_notice_remaining = 0.0
	mini_boss = MilkBoss.new()
	mini_boss.presentation = milk_announcement
	mini_boss.combat_players = players
	mini_boss.setup_boss(_boss_edge_position(), Balance.difficulty(elapsed), 0)
	_apply_breakthrough_health(mini_boss, "milk")
	_apply_enemy_difficulty(mini_boss)
	mini_boss.melee_strike.connect(_resolve_final_strike)
	mini_boss.milk_volley.connect(_fire_milk_volley)
	mini_boss.milk_bombs.connect(_fire_milk_bombs)
	mini_boss.rebirth_started.connect(_on_milk_rebirth)
	mini_boss.clones_requested.connect(func(source): pending_milk_clones.append(source))
	mini_boss.skill_announced.connect(milk_announcement.announce)
	mini_boss.rage_announced.connect(milk_announcement.announce.bind(true))
	world.add_child(mini_boss)
	enemies.append(mini_boss)
	milk_announcement.announce("不灭奶龙 · 宇宙奶霸登场！", "第三终局 · 近远兼修 · 奶龙倒下后奶蛙满血复活",1,"laugh")
	hud.refresh()

func _apply_breakthrough_health(boss, stage: String) -> void:
	if not breakthrough_mode: return
	var mages := 0
	for player in players:
		if player.role == Classes.MAGE: mages += 1
	boss.max_hp = float(Balance.BREAKTHROUGH_HEALTH[stage][mages])
	boss.hp = boss.max_hp
	if boss is MilkBoss:
		boss.second_life_hp = float(Balance.BREAKTHROUGH_HEALTH.frog[mages])

func _on_milk_rebirth(_source) -> void:
	_clear_hostile_attacks()
	# Friendly projectiles may be inside their damage loop. Clear next simulation frame.
	milk_rebirth_cleanup = true

func _flush_milk_clones() -> void:
	for source in pending_milk_clones:
		if not is_instance_valid(source) or source.dead or source != mini_boss: continue
		for slot in range(4):
			if enemies.size() >= Balance.MAX_ENEMIES: break
			var clone := MilkClone.new()
			var spawn: Vector2 = source._inside_arena(source.position+Vector2.from_angle(slot*TAU/4)*150)
			clone.setup_clone(spawn,source)
			_apply_enemy_difficulty(clone)
			clone.ranged_attack.connect(_fire_milk_clone)
			world.add_child(clone)
			enemies.append(clone)
	pending_milk_clones.clear()

func _add_milk_bullet(source, at: Vector2, velocity: Vector2, pattern: String, amount: float, target = null) -> void:
	if enemy_bullets.size() >= Balance.MAX_ENEMY_BULLETS: enemy_bullets.pop_front().queue_free()
	var bullet := EnemyBullet.new()
	bullet.position = at
	bullet.velocity = velocity
	bullet.damage = amount
	bullet.remaining_distance = 1650.0
	bullet.radius = 9.0 if pattern == "milk_bubble" else 8.0
	bullet.pattern = pattern
	bullet.color = Color("a4ffc3") if pattern == "milk_bubble" else Color("ffd066")
	bullet.boss_visual = true
	bullet.source_id = source.get_instance_id()
	bullet.homing_target = target
	bullet.homing_remaining = 1.1 if target != null else 0.0
	bullet.z_index = 3
	world.add_child(bullet)
	enemy_bullets.append(bullet)

func _fire_milk_clone(source, _pattern: String, direction: Vector2, _landing: Vector2) -> void:
	if source.dead or simulation_speed() == 0.0: return
	for offset in [-0.13,0.0,0.13]:
		_add_milk_bullet(source,source.position+direction*30,direction.rotated(offset)*270,"milk_bubble",source.damage*0.8)

func _fire_milk_volley(source, pattern: String, direction: Vector2, index: int) -> void:
	if source.dead or source != mini_boss or simulation_speed() == 0.0: return
	if pattern in ["mini_spit", "bubble_spit"]:
		var count := 5 if pattern == "mini_spit" else 3
		for slot in range(count):
			var aim := direction.rotated((slot-(count-1)*0.5)*0.13)
			_add_milk_bullet(source,source.position+aim*60,aim*(400 if pattern == "mini_spit" else 340),"milk_star" if pattern == "mini_spit" else "milk_bubble",source.damage*(0.45 if pattern == "mini_spit" else 0.35))
		return
	var frog := pattern == "bubble"
	var count: int = (36 if frog else 32)+source.attack_phase*4
	for slot in range(count):
		var aim := direction.rotated(slot*TAU/count+index*0.13)
		_add_milk_bullet(source,source.position+aim*60,aim*(380+source.attack_phase*30),"milk_bubble" if frog else "milk_star",source.damage*(0.65 if frog else 0.75))
	if frog:
		for edge in range(2):
			for slot in range(8):
				var u := (slot+0.5+(0.2 if index%2 else -0.2))/8.0
				var vertical := index%2 == 0
				var at := Balance.ARENA.position+(Vector2(u*Balance.ARENA.size.x,edge*Balance.ARENA.size.y) if vertical else Vector2(edge*Balance.ARENA.size.x,u*Balance.ARENA.size.y))
				var velocity := (Vector2.DOWN if vertical else Vector2.RIGHT)*(1 if edge==0 else -1)*350
				_add_milk_bullet(source,at,velocity,"milk_bubble",source.damage*0.65)
		for player in players:
			if not player.is_targetable(): continue
			var aim: Vector2 = source.position.direction_to(player.position)
			_add_milk_bullet(source,source.position+aim*60,aim*330,"milk_bubble",source.damage*0.75,player)

func _fire_milk_bombs(source, points: Array[Vector2], lotus: bool) -> void:
	if source.dead or source != mini_boss or simulation_speed() == 0.0: return
	for at in points:
		if enemy_hazards.size() >= Balance.MAX_ENEMY_HAZARDS: break
		var hazard := MilkHazard.new()
		hazard.lotus = lotus
		hazard.position = at
		hazard.radius = 165.0 if lotus else 105.0
		hazard.damage = source.damage*(1.9 if lotus else 1.75)
		hazard.warning_duration = 0.42 if lotus else 0.5
		hazard.warning_remaining = hazard.warning_duration
		hazard.blast_remaining = 0.75
		hazard.source_id = source.get_instance_id()
		hazard.z_index = 3
		world.add_child(hazard)
		enemy_hazards.append(hazard)

func _fire_artillery_volley(source, module: String, direction: Vector2, index: int, stage: int) -> void:
	if source.dead or source != mini_boss or simulation_speed() == 0.0: return
	boss_effects.emit_effect("volley", {"position": source.position, "module": module, "direction": direction,
		"color": Color("d6a1ff") if module in ["halo", "storm"] else Color("ffb974")}, 0.3)
	for angle in source.volley_angles(module, index, stage):
		if enemy_bullets.size() >= Balance.MAX_ENEMY_BULLETS:
			if module == "storm": enemy_bullets.pop_front().queue_free()
			else: break
		var bullet := EnemyBullet.new()
		var aim := direction.rotated(angle)
		bullet.position = source.position + aim * (source.radius + 12.0)
		bullet.velocity = aim * ((285.0 if module == "halo" else (340.0 if module == "storm" else 360.0)) + (stage - 1) * 40.0)
		bullet.damage = source.damage
		bullet.remaining_distance = 1300.0
		bullet.color = Color("d9adff") if module in ["halo", "storm"] else Color("ffc17a")
		bullet.pattern = "ring" if module in ["halo", "storm"] else "fan"
		bullet.boss_visual = true
		bullet.source_id = source.get_instance_id()
		bullet.z_index = 3
		world.add_child(bullet)
		enemy_bullets.append(bullet)
	if module == "storm":
		# Alternating horizontal/vertical walls cross the boss's rotating radial waves.
		for edge in range(2):
			for slot in range(8):
				if enemy_bullets.size() >= Balance.MAX_ENEMY_BULLETS: enemy_bullets.pop_front().queue_free()
				var bullet := EnemyBullet.new()
				var u := (slot + 0.5 + (0.28 if index % 2 else -0.28)) / 8.0
				var vertical := index % 2 == 0
				bullet.position = Balance.ARENA.position + (Vector2(u * Balance.ARENA.size.x, edge * Balance.ARENA.size.y) if vertical else Vector2(edge * Balance.ARENA.size.x, u * Balance.ARENA.size.y))
				bullet.velocity = (Vector2.DOWN if vertical else Vector2.RIGHT) * (1.0 if edge == 0 else -1.0) * (320.0 + stage * 35.0)
				bullet.damage = source.damage
				bullet.remaining_distance = 1450.0
				bullet.radius = 7.0
				bullet.color = Color("ff7fae")
				bullet.boss_visual = true
				bullet.source_id = source.get_instance_id()
				bullet.z_index = 3
				world.add_child(bullet)
				enemy_bullets.append(bullet)

func _fire_artillery_bombardment(source, module: String, points: Array[Vector2], _stage: int) -> void:
	if source.dead or source != mini_boss or simulation_speed() == 0.0: return
	boss_effects.emit_effect("launch", {"position": source.position, "color": Color("ffce89")}, 0.55)
	for index in range(points.size()):
		if enemy_hazards.size() >= Balance.MAX_ENEMY_HAZARDS: break
		var hazard := ArtilleryHazard.new()
		hazard.heavy = module == "carpet"
		hazard.order = index + 1
		hazard.radius = 92.0 if hazard.heavy else 88.0
		hazard.position = points[index]
		hazard.warning_duration = RangedFinalBoss.BOMB_WARNING + (index * RangedFinalBoss.BOMB_STAGGER if hazard.heavy else 0.0)
		hazard.warning_remaining = hazard.warning_duration
		hazard.blast_remaining = RangedFinalBoss.BOMB_BLAST
		hazard.damage = source.damage * (2.8 if hazard.heavy else 2.0)
		hazard.source_id = source.get_instance_id()
		hazard.z_index = 2
		world.add_child(hazard)
		enemy_hazards.append(hazard)

func _resolve_final_strike(source, shape: String, origin: Vector2, endpoint: Vector2, direction: Vector2, reach: float, half_angle: float, multiplier: float) -> void:
	if source.dead or simulation_speed() == 0.0: return
	if shape != "dash" and not source.has_method("is_milk_boss"):
		var position: Vector2 = source.duel_target.position if shape == "lock" and is_instance_valid(source.duel_target) else origin
		boss_effects.emit_effect("lock" if shape == "lock" else ("slam" if shape == "circle" else "slash"),
			{"position": position, "direction": direction, "radius": reach,
			"color": Color("d6acff") if source.boss_attack == "blink" else Color("ffcf8e")}, 0.6 if shape in ["circle", "lock"] else 0.4)
	for player in damageable_targets():
		if not player.is_targetable() or source.strike_hits.has(player.player_id): continue
		var body: float = player.collision_radius()
		var connects := false
		if shape == "lock":
			connects = player == source.duel_target
		elif shape == "dash":
			connects = Geometry2D.get_closest_point_to_segment(player.position, origin, endpoint).distance_to(player.position) <= reach + body
		elif shape == "circle":
			connects = origin.distance_to(player.position) <= reach + body
		else:
			var offset: Vector2 = player.position - origin
			var angle: float = absf(direction.angle_to(offset))
			connects = offset.length() <= reach + body and angle <= half_angle
			# Also cover the player's body touching either edge of the slash wedge.
			for side in [-1, 1]:
				var edge := origin + direction.rotated(half_angle * side) * reach
				connects = connects or Geometry2D.get_closest_point_to_segment(player.position, origin, edge).distance_to(player.position) <= body
		if connects:
			source.strike_hits[player.player_id] = true
			player.take_damage(source.damage * multiplier, source.get_instance_id())

func _queue_boss_support(source, count: int) -> void:
	if final_battle: return
	pending_boss_support.append({"source": source, "count": count})

func _flush_boss_support() -> void:
	# Signals arrive during enemy iteration; create new enemies only afterwards.
	for request in pending_boss_support:
		var source = request.source
		if not is_instance_valid(source) or source.dead or simulation_speed() == 0.0:
			continue
		var count := mini(int(request.count), 3 - source.guard_count())
		for slot in range(count):
			if enemies.size() >= Balance.MAX_ENEMIES: break
			var guard := BossGuard.new()
			guard.setup_guard(_boss_edge_position(), Balance.difficulty(elapsed), source, source.guard_count())
			_apply_enemy_difficulty(guard)
			world.add_child(guard)
			enemies.append(guard)
			source.guards.append(guard)
	pending_boss_support.clear()

func _fire_ground_pattern(source, spell: String, points: Array[Vector2], direction: Vector2, enhanced: bool) -> void:
	if final_battle or source.dead or simulation_speed() == 0.0 or points.is_empty(): return
	var positions: Array[Vector2] = []
	if spell == "fault":
		var count := 7 if enhanced else 5
		for index in range(count):
			positions.append(points[0] + direction.orthogonal() * (index - (count - 1) / 2.0) * 90.0)
	else:
		for point in points:
			positions.append(point)
			if enhanced: positions.append(point + direction.orthogonal() * 115.0)
	for index in range(positions.size()):
		if enemy_hazards.size() >= Balance.MAX_ENEMY_HAZARDS: break
		var hazard := ThornHazard.new()
		hazard.spell = spell
		hazard.radius = 42.0 if spell == "fault" else 72.0
		hazard.position = positions[index].clamp(Balance.ARENA.position + Vector2.ONE * hazard.radius, Balance.ARENA.end - Vector2.ONE * hazard.radius)
		hazard.warning_duration = (0.95 if enhanced else 1.05) + (index * 0.12 if spell == "fault" else 0.0)
		hazard.warning_remaining = hazard.warning_duration
		hazard.active_duration = 0.45 if spell == "fault" else 2.4
		hazard.blast_remaining = hazard.active_duration
		hazard.damage = source.damage * (2.0 if spell == "fault" else 1.0)
		hazard.source_id = source.get_instance_id()
		world.add_child(hazard)
		world.move_child(hazard, 0)
		enemy_hazards.append(hazard)

func _reward_boss(boss) -> void:
	if boss is MilkBoss:
		boss.hide()
		_clear_hostile_attacks()
		pending_milk_clones.clear()
		for enemy in enemies:
			if enemy is MilkClone: enemy.dead = true
		victory = true
		game_over = true
		boss_victory_name = boss.display_name()
		mini_boss = null
		hud.refresh()
		return
	if boss is RangedFinalBoss:
		boss.hide()
		_clear_hostile_attacks()
		boss_victory_name = boss.display_name()
		mini_boss = null
		final_transition_remaining = 4.0
		for player in players:
			if not player.downed: player.hp = minf(player.stats.max_hp, player.hp + player.stats.max_hp*0.2)
		boss_notice = "存活队友恢复 20% 生命 · 4 秒后不灭奶龙登场！"
		boss_notice_remaining = 4.0
		hud.refresh()
		return
	if boss is FinalBoss:
		boss.hide()
		_clear_hostile_attacks()
		boss_victory_name = boss.display_name()
		mini_boss = null
		# Spawn on the next simulation frames, outside the current damage iteration.
		final_transition_remaining = 3.0
		for player in players:
			if not player.downed: player.hp = minf(player.stats.max_hp, player.hp + player.stats.max_hp * 0.2)
		boss_notice = "存活队友恢复 20% 生命 · 3 秒后天穹炮皇入场"
		boss_notice_remaining = 3.0
		hud.refresh()
		return
	var source_id: int = boss.get_instance_id()
	for index in range(enemy_bullets.size() - 1, -1, -1):
		if enemy_bullets[index].source_id == source_id:
			enemy_bullets[index].queue_free()
			enemy_bullets.remove_at(index)
	for index in range(enemy_hazards.size() - 1, -1, -1):
		if enemy_hazards[index].source_id == source_id:
			enemy_hazards[index].queue_free()
			enemy_hazards.remove_at(index)
	if boss is ThornBoss:
		for guard in boss.guards:
			if is_instance_valid(guard): guard.dead = true
	boss_victory_name = boss.display_name()
	for player in players:
		if not player.downed:
			player.hp = minf(player.stats.max_hp, player.hp + player.stats.max_hp * 0.2)
	mini_boss = null
	for enemy in enemies:
		if not enemy.dead and enemy.kind == "boss": mini_boss = enemy
	boss_notice = "经验奖励已掉落 · 存活队友恢复 20% 生命"
	boss_notice_remaining = 4.0
	hud.refresh()

func _fire_enemy_pattern(source, pattern: String, direction: Vector2, landing: Vector2) -> void:
	if final_battle or source.dead or simulation_speed() == 0.0:
		return
	var config: Dictionary = Barrage.TYPES[pattern]
	var amount: float = source.damage * float(config.damage)
	if source.kind == "boss": amount = source.damage
	if pattern == "mortar":
		if enemy_hazards.size() >= Balance.MAX_ENEMY_HAZARDS:
			return
		var hazard := EnemyHazard.new()
		hazard.position = landing.clamp(Balance.ARENA.position, Balance.ARENA.end)
		hazard.damage = amount
		hazard.source_id = source.get_instance_id()
		world.add_child(hazard)
		world.move_child(hazard, 0)
		enemy_hazards.append(hazard)
		return
	var angles: Array[float] = [0.0]
	if pattern == "fan":
		angles = Barrage.fan_angles(source.pattern_seconds)
	elif pattern == "ring":
		angles = Barrage.ring_angles(source.pattern_seconds)
	if source.kind == "boss":
		angles = source.bullet_angles(pattern)
	var bullet_speed := minf(280.0, float(config.bullet_speed) + source.pattern_seconds * 0.04)
	for angle in angles:
		if enemy_bullets.size() >= Balance.MAX_ENEMY_BULLETS:
			break
		var bullet := EnemyBullet.new()
		var aim := direction.rotated(angle)
		bullet.position = source.position + aim * (source.radius + 12.0)
		bullet.velocity = aim * bullet_speed
		bullet.damage = amount
		bullet.color = config.color
		bullet.pattern = pattern
		bullet.source_id = source.get_instance_id()
		bullet.z_index = 3
		world.add_child(bullet)
		enemy_bullets.append(bullet)

func _update_enemy_attacks(delta: float) -> void:
	for bullet in enemy_bullets:
		bullet.steer(delta)
		var start: Vector2 = bullet.position
		var step: Vector2 = bullet.velocity * delta
		var reaches_limit: bool = step.length() >= bullet.remaining_distance
		if reaches_limit:
			step = step.normalized() * bullet.remaining_distance
		var end := start + step
		var victim = null
		var best := INF
		if mage_system.intercept_bullet(start, end, bullet):
			bullet.expired = true
			bullet.position = end
			continue
		for player in damageable_targets():
			if not player.is_targetable():
				continue
			var nearest := Geometry2D.get_closest_point_to_segment(player.position, start, end)
			if nearest.distance_squared_to(player.position) <= pow(player.collision_radius() + bullet.radius, 2):
				var distance: float = start.distance_squared_to(nearest)
				if distance < best:
					victim = player
					best = distance
		if victim != null:
			victim.take_damage(bullet.damage, bullet.source_id)
			bullet.expired = true
		bullet.position = end
		bullet.remaining_distance -= step.length()
		bullet.expired = bullet.expired or reaches_limit or not Balance.ARENA.grow(10.0).has_point(end)
		bullet.queue_redraw()
	for hazard in enemy_hazards:
		hazard.advance(delta)
		if hazard.warning_remaining > 0.0:
			continue
		for player in damageable_targets():
			if player.is_targetable() and not hazard.hit_players.has(player.player_id) and hazard.position.distance_squared_to(player.position) <= pow(hazard.radius + player.collision_radius(), 2):
				player.take_damage(hazard.damage, hazard.source_id)
				hazard.hit_players[player.player_id] = true
	for index in range(enemy_bullets.size() - 1, -1, -1):
		if enemy_bullets[index].expired:
			enemy_bullets[index].queue_free()
			enemy_bullets.remove_at(index)
	for index in range(enemy_hazards.size() - 1, -1, -1):
		if enemy_hazards[index].expired:
			enemy_hazards[index].queue_free()
			enemy_hazards.remove_at(index)

func _fire(player) -> void:
	var target = null
	var best: float = player.attack_range() * player.attack_range()
	for enemy in enemies:
		if enemy.dead:
			continue
		var distance: float = player.position.distance_squared_to(enemy.position)
		if distance < best:
			best = distance
			target = enemy
	if target == null:
		return
	player.shot_cooldown = player.attack_interval()
	var direction: Vector2 = player.position.direction_to(target.position)
	player.facing = direction
	var count: int = int(player.stats.projectiles)
	for index in range(count):
		if projectiles.size() >= Balance.MAX_PROJECTILES:
			break
		# Center first, then alternate right/left so every volley has an aimed shot.
		var angle := ceilf(float(index) / 2.0) * 0.11
		if index % 2 == 0:
			angle = -angle
		_spawn_bullet(player, direction.rotated(angle))

func _spawn_bullet(player, direction: Vector2, multiplier := 1.0, source := "auto") -> void:
	if projectiles.size() >= Balance.MAX_PROJECTILES:
		return
	var bullet := Projectile.new()
	bullet.owner_id = player.player_id
	bullet.damage_source = source
	bullet.position = player.position + player.visual_offset() + direction * (player.collision_radius() + 6.0)
	bullet.velocity = direction * float(player.stats.projectile_speed)
	bullet.critical = player.rng.randf() < float(player.stats.crit)
	bullet.damage = player.output_damage() * multiplier * (float(player.stats.crit_multiplier) if bullet.critical else 1.0)
	bullet.remaining_distance = player.attack_range()
	bullet.hits_left = 1 + int(player.stats.pierce)
	world.add_child(bullet)
	projectiles.append(bullet)

func _damage_enemy(enemy, amount: float, owner_id: int, highlighted := false, source := "auto", element := "", reaction := false) -> void:
	if enemy.dead:
		return
	var health_before: float = maxf(0.0, enemy.hp)
	var killed: bool = enemy.hit(amount)
	# Reading the actual loss includes armor and vulnerability, but excludes overkill.
	var actual_damage: float = clampf(health_before - maxf(0.0, enemy.hp), 0.0, health_before)
	damage_totals[owner_id] += actual_damage
	if actual_damage > 0.0:
		var category: String = source if DamageSources.NAMES.has(source) else "other"
		damage_breakdown[owner_id][category] = float(damage_breakdown[owner_id].get(category, 0.0)) + actual_damage
	if actual_damage > 0.0:
		if damage_events.size() >= DamageNumbers.MAX_EVENTS: damage_events.pop_front()
		var reacting: bool = reaction and element in ["fire", "ice"]
		var reaction_label := reacting
		if reacting:
			# Dense pulses still emphasize every reaction; limit repeated captions on one target.
			for previous in damage_events:
				if previous.get("enemy_id", 0) == enemy.get_instance_id() and previous.get("reaction_label", false) and float(previous.life) > DamageNumbers.LIFETIME - 0.35:
					reaction_label = false
					break
		var font_size := DamageNumbers.font_size_for(actual_damage, highlighted, reacting)
		var offset := Vector2((damage_serial % 5 - 2) * (20.0 + font_size * 0.4), -maxf(34.0, enemy.radius * 2.3) - (damage_serial % 3) * 9.0)
		damage_serial += 1
		damage_events.append({"position": enemy.position + offset, "amount": maxi(1, roundi(actual_damage)),
			"critical": highlighted, "font_size": font_size, "life": DamageNumbers.LIFETIME,
			"element": element if not element.is_empty() else DamageNumbers.element_for_source(source),
			"reaction": reacting, "reaction_label": reaction_label, "enemy_id": enemy.get_instance_id()})
		damage_numbers.queue_redraw()
	if killed:
		players[owner_id].kills += 1
		if enemy.xp_value > 0: _drop_gem(enemy.position, enemy.xp_value)
		if enemy.kind == "boss":
			_reward_boss(enemy)

func _update_projectiles(delta: float) -> void:
	for bullet in projectiles:
		var start: Vector2 = bullet.position
		var step: Vector2 = bullet.velocity * delta
		if step.length() > bullet.remaining_distance:
			step = step.normalized() * bullet.remaining_distance
		var end := start + step
		var collisions: Array[Dictionary] = []
		for enemy in enemies:
			if enemy.dead or bullet.hit_ids.has(enemy.get_instance_id()):
				continue
			var nearest := Geometry2D.get_closest_point_to_segment(enemy.position, start, end)
			if nearest.distance_squared_to(enemy.position) <= pow(enemy.radius + 4.5, 2):
				collisions.append({"enemy": enemy, "distance": start.distance_squared_to(nearest)})
		collisions.sort_custom(func(a, b): return a.distance < b.distance)
		for collision in collisions:
			var enemy = collision.enemy
			if enemy.dead:
				continue
			bullet.hit_ids[enemy.get_instance_id()] = true
			bullet.hits_left -= 1
			_damage_enemy(enemy, bullet.damage, bullet.owner_id, bullet.critical, bullet.damage_source)
			if bullet.hits_left <= 0:
				bullet.expired = true
				break
		bullet.position = end
		bullet.remaining_distance -= step.length()
		if bullet.remaining_distance <= 0.0:
			bullet.expired = true
	for index in range(projectiles.size() - 1, -1, -1):
		if projectiles[index].expired:
			projectiles[index].queue_free()
			projectiles.remove_at(index)
	for index in range(enemies.size() - 1, -1, -1):
		if enemies[index].dead:
			enemies[index].queue_free()
			enemies.remove_at(index)

func _drop_gem(at: Vector2, amount: int) -> void:
	# At the object budget, merge value rather than discarding XP.
	if gems.size() >= Balance.MAX_GEMS:
		var nearest = gems[0]
		for gem in gems:
			if at.distance_squared_to(gem.position) < at.distance_squared_to(nearest.position):
				nearest = gem
		nearest.value += amount
		nearest.queue_redraw()
		return
	var gem := Gem.new()
	gem.position = at
	gem.value = amount
	world.add_child(gem)
	gems.append(gem)

func _update_gems(delta: float) -> void:
	for gem in gems:
		var collector = null
		var best := INF
		for player in players:
			if not player.is_active():
				continue
			var distance: float = gem.position.distance_to(player.position)
			if distance < Balance.PICKUP_RADIUS and distance < best:
				best = distance
				collector = player
		if collector == null:
			continue
		gem.position = gem.position.move_toward(collector.position, 370.0 * delta)
		if gem.position.distance_to(collector.position) <= 23.0:
			add_shared_xp(gem.value)
			gem.collected = true
	for index in range(gems.size() - 1, -1, -1):
		if gems[index].collected:
			gems[index].queue_free()
			gems.remove_at(index)

func _draw() -> void:
	for player in players:
		if player.return_remaining > 0.0:
			var color: Color = Balance.PLAYER_COLORS[player.player_id]
			draw_line(player.return_origin, player.position, Color(color, 0.3), 2.0, true)
			draw_arc(player.return_origin, 23.0, 0, TAU, 48, Color(color, 0.8), 2.0, true)
			draw_arc(player.return_origin, 28.0, -PI / 2.0, -PI / 2.0 + TAU * player.return_remaining / float(player.skill_stats.return_window), 48, color, 3.0, true)
		if player.downed:
			draw_arc(player.position, Balance.REVIVE_RADIUS, 0, TAU, 64, Color(0.53, 0.96, 0.7, 0.22), 2.0, true)
	for effect in skill_effects:
		var color: Color = effect.color
		color.a = effect.life / 0.35
		if effect.has("points"):
			draw_colored_polygon(effect.points, Color(color, color.a * 0.16))
			var outline: PackedVector2Array = effect.points.duplicate()
			outline.append(outline[0])
			draw_polyline(outline, Color(color, color.a * 0.7), 2.0, true)
		elif effect.has("start"):
			draw_line(effect.start, effect.end, Color(color, color.a * 0.12), effect.radius * 2.0, true)
			draw_line(effect.start, effect.end, Color(color, color.a * 0.65), 5.0, true)
		else:
			draw_arc(effect.position, 18.0 + (0.35 - effect.life) * 120.0, 0, TAU, 32, color, 4.0, true)

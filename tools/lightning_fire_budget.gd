extends SceneTree
## Focused single-Boss output calculation through current gameplay code. No balance mutations.
const Skills = preload("res://scripts/skill_upgrades.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
const LIGHTNING := ["lightning_tower", "tower_chain", "tower_tide", "tower_judgment"]
const FIRE := ["fireball", "fire_explosion", "fire_ground", "burn"]
var game
var target
var rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func reset(build: Array, distance: float, reaction: bool) -> void:
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	var system = game.mage_system
	for tower in system.towers: tower.free()
	system.towers.clear()
	system.fireballs.clear()
	system.salvos.clear()
	system.grounds.clear()
	system.explosions.clear()
	system.elements.fire_contacts.clear()
	system.lightning_effects.events.clear()
	system.lightning_effects.rulings.clear()
	system.lightning_effects.waves.clear()
	system.lightning_effects.tags.clear()
	game.elapsed = 0.0
	game.damage_totals.assign([0.0, 0.0])
	game.damage_breakdown.assign([{}, {}])
	game.damage_events.clear()
	for player in game.players:
		player.configure_class(0)
		player.position = Vector2(330, 450 + 120 * player.player_id)
		player.shot_cooldown = 100000.0
	for rank in range(3): Upgrades.apply(game.players[0], "damage")
	for upgrade in build: assert(Skills.apply(game.players[0], upgrade))
	target = game.Enemy.new()
	target.setup(Vector2(330 + distance, 450), game.Balance.difficulty(180), false, "boss")
	target.radius = 42.0
	target.hp = 1000000000.0
	target.max_hp = target.hp
	target.speed = 0.0
	target.xp_value = 0
	game.world.add_child(target)
	game.enemies.append(target)
	if reaction: system.elements.attach(target, "ice")

func source_total(focus: String) -> float:
	var sum := 0.0
	for category in LIGHTNING if focus == "lightning" else FIRE:
		sum += float(game.damage_breakdown[0].get(category, 0.0))
	return sum

func measure(build: Array, focus: String, reaction: bool, duration: float, repeat_casts: bool, distance := 350.0, movement := "static") -> Dictionary:
	reset(build, distance, reaction)
	var player = game.players[0]
	var casts := 0
	var window_start := 0.0
	var first20 := 0.0
	var normalized_parts := {}
	for frame in range(roundi(duration * 60)):
		var time := float(frame) / 60.0
		if movement == "moving":
			# Prescribed movement isolates spell tracking/overlap from Boss AI and player survival.
			target.position = Vector2(330 + distance + sin(time * TAU / 5.0) * 100.0, 450 + sin(time * TAU / 4.0) * 100.0)
		if reaction: game.mage_system.elements.attach(target, "ice")
		if frame == 1800: window_start = source_total(focus)
		if frame == 1200: first20 = source_total(focus)
		if (repeat_casts or casts == 0):
			if focus == "lightning":
				if player.tower_charges > 0 and player.tower_release_cooldown <= 0.00001:
					if game.mage_system.activate_tower(0): casts += 1
			elif player.fireball_cooldown <= 0.00001:
				if game.mage_system.activate(0, 1): casts += 1
		player.advance(1.0 / 60.0, Vector2.ZERO)
		game.elapsed += 1.0 / 60.0
		game.mage_system.advance(1.0 / 60.0)
		# Damage-number presentation is irrelevant to the numerical budget.
		game.damage_events.clear()
	for key in game.damage_breakdown[0]: normalized_parts[key] = snappedf(game.damage_breakdown[0][key] / 35.0, 0.001)
	return {"build": build, "focus": focus, "reaction": reaction, "distance": distance, "movement": movement,
		"casts": casts, "single_damage": snappedf(source_total(focus), 0.01), "single_units": snappedf(source_total(focus) / 35.0, 0.001),
		"steady_dps": snappedf((source_total(focus) - window_start) / 30.0, 0.01) if repeat_casts else 0.0,
		"first20_damage": snappedf(first20, 0.01) if repeat_casts else 0.0, "parts_units": normalized_parts}

func candidates(picks: int, focus: String) -> Array[Array]:
	var result: Array[Array] = []
	var majors := ["tower_chain", "tower_tide", "tower_judgment"] if focus == "lightning" else ["fire_push", "fire_ground", "fire_growth"]
	var minor_a := "tower_rate" if focus == "lightning" else "fire_width"
	var minor_b := "tower_core" if focus == "lightning" else "fire_count"
	var major_count := picks / 3
	var minor_count := picks - major_count
	for rank_a in range(4):
		var rank_b := minor_count - rank_a
		if rank_b < 0 or rank_b > 3: continue
		for mask in range(8):
			var selected: Array = []
			for index in range(3):
				if mask & (1 << index): selected.append(majors[index])
			if selected.size() != major_count: continue
			var build: Array = []
			for rank in range(rank_a): build.append(minor_a)
			for rank in range(rank_b): build.append(minor_b)
			build.append_array(selected)
			result.append(build)
	return result

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.selected_classes = [0, 0]
	game.start_run()
	var winners := {}
	for picks in [3, 6, 9]:
		for focus in ["lightning", "fire"]:
			var best: Dictionary = {}
			for build in candidates(picks, focus):
				var row := measure(build, focus, focus == "fire", 20.0, false)
				row.picks = picks
				rows.append(row)
				if best.is_empty() or row.single_damage > best.single_damage: best = row
			winners["%d_%s" % [picks, focus]] = best.build
			for reaction in [false, true] if focus == "fire" else [false]:
				var steady := measure(best.build, focus, reaction, 60.0, true)
				steady.picks = picks
				steady.mode = "steady"
				rows.append(steady)
				print(JSON.stringify(steady))
	# Geometric sensitivity: one fully upgraded release; fire receives permanent x2 as a ceiling.
	for movement in ["static", "moving"]:
		for distance in [200.0, 350.0, 500.0]:
			for focus in ["lightning", "fire"]:
				var row := measure(winners["9_" + focus], focus, focus == "fire", 20.0, false, distance, movement)
				row.picks = 9
				row.mode = "geometry"
				rows.append(row)
				print(JSON.stringify(row))
	# Isolate the dominant major at the full minor tiers.
	var minor_max := ["tower_rate", "tower_rate", "tower_rate", "tower_core", "tower_core", "tower_core"]
	for additions in [[], ["tower_chain"], ["tower_tide"], ["tower_judgment"], ["tower_chain", "tower_tide", "tower_judgment"]]:
		var row := measure(minor_max + additions, "lightning", false, 20.0, false)
		row.mode = "ablation"
		rows.append(row)
		print(JSON.stringify(row))
	# AoE-versus-judgment identity at early and intermediate tiers.
	for minor_build in [[], ["tower_rate", "tower_core"], ["tower_core", "tower_core", "tower_core"]]:
		for major in ["tower_tide", "tower_judgment"]:
			var row := measure(minor_build + [major], "lightning", false, 20.0, false)
			row.mode = "early_major"
			rows.append(row)
			print(JSON.stringify(row))
	var file := FileAccess.open("res://artifacts/lightning_fire_budget.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"damage": 35, "boss_radius": 42, "window": "30-60s", "rows": rows}, "\t"))
	game.free()
	quit()

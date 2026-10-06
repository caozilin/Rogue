extends Node2D
## Fixed summons; the game simulation owns targeting, lifetime and all animation.
const Art = preload("res://scripts/art.gd")
const Classes = preload("res://scripts/classes.gd")
const ATTACK_INTERVAL := 0.8
const CHAIN_RADIUS := 260.0
const CHAIN_DAMAGE := 0.15
const TIDE_INTERVAL := 2.5
const TIDE_DAMAGE := 1.8
const TIDE_FINAL_DAMAGE := 2.4
const TIDE_DETONATION_DAMAGE := 6.0
var game
var effects
var owner_id := 0
var damage := 14.0 * Classes.TOWER_BASE_DAMAGE
var life := Classes.TOWER_DURATION
var total_duration := Classes.TOWER_DURATION
var attack_interval := ATTACK_INTERVAL
var chain_enabled := false
var tide_enabled := false
var judgment_enabled := false
var chain_marks: Dictionary = {}
var judgment_target := 0
var judgment_count := 0
var next_tide := TIDE_INTERVAL
var final_waves := 0
var shot_timer := 0.0
var beam_life := 0.0
var beam_end := Vector2.ZERO
var bolts: Node2D
var expired := false

func _ready() -> void:
	z_index = -1 # Keep the caster visible when standing at the summon position.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bolts = Node2D.new()
	bolts.z_index = 5
	bolts.draw.connect(_draw_bolt)
	add_child(bolts)

func advance(delta: float) -> void:
	if expired:
		return
	var active_delta := minf(delta, life)
	beam_life = maxf(0.0, beam_life - delta)
	shot_timer -= active_delta
	while shot_timer <= 0.00001:
		var target = null
		var best := INF
		for enemy in game.enemies:
			if not effects.on_screen(enemy):
				continue
			var distance: float = position.distance_squared_to(enemy.position)
			if distance <= best:
				best = distance
				target = enemy
		if target == null:
			shot_timer = 0.0
			break
		beam_end = target.position - Vector2(0, target.radius)
		beam_life = 0.18
		game._damage_enemy(target, damage, owner_id, false, "lightning_tower")
		if judgment_enabled:
			_judgment(target)
		if chain_enabled:
			_chain(target)
		shot_timer += attack_interval
	life = maxf(0.0, life - delta)
	expired = life <= 0.00001
	if tide_enabled:
		var age := total_duration - life
		while next_tide < total_duration - 1.0 and next_tide <= age + 0.00001:
			effects.wave(position, damage * TIDE_DAMAGE, owner_id)
			next_tide += TIDE_INTERVAL
		while final_waves < 3 and age + 0.00001 >= total_duration - 1.0 + float(final_waves) / 3.0:
			effects.wave(position, damage * TIDE_FINAL_DAMAGE, owner_id, true)
			final_waves += 1
		if expired:
			effects.wave(position, damage * TIDE_DETONATION_DAMAGE * total_duration / 10.0, owner_id, true, true)
	queue_redraw()
	bolts.queue_redraw()

func _judgment(target) -> void:
	if target.dead:
		judgment_target = 0
		judgment_count = 0
		return
	var id: int = target.get_instance_id()
	if judgment_target != id:
		judgment_target = id
		judgment_count = 0
	judgment_count += 1
	var threshold := 12 if target.kind == "boss" else (6 if target.elite else 5)
	effects.tag(target, judgment_count, threshold, true)
	if judgment_count >= threshold:
		var power := 15.0 if target.kind == "boss" else (10.0 if target.elite else 8.0)
		effects.ruling(target, damage * power, owner_id, true, damage * 2.0)
		judgment_count = 0

func _chain(primary) -> void:
	var from: Vector2 = primary.position - Vector2(0, primary.radius)
	var visited := {primary.get_instance_id(): true}
	var marked: Dictionary = {} # Backflow keeps three hits, but one primary attack gives at most one mark per target.
	for index in range(3):
		var target = null
		var best := CHAIN_RADIUS * CHAIN_RADIUS
		for enemy in game.enemies:
			if not effects.on_screen(enemy) or visited.has(enemy.get_instance_id()):
				continue
			var distance: float = (enemy.position - Vector2(0, enemy.radius)).distance_squared_to(from)
			if distance <= best:
				best = distance
				target = enemy
		if target == null:
			if primary.dead:
				break
			target = primary
			from = primary.position + Vector2((index - 1) * 25.0, -170.0 - index * 20.0)
		var end: Vector2 = target.position - Vector2(0, target.radius)
		effects.effect("chain", {"start": from, "end": end, "seed": float(index)}, 0.28)
		game._damage_enemy(target, damage * CHAIN_DAMAGE, owner_id, false, "tower_chain")
		visited[target.get_instance_id()] = true
		from = end
		if not target.dead and not marked.has(target.get_instance_id()):
			var id: int = target.get_instance_id()
			marked[id] = true
			var count := int(chain_marks.get(id, 0)) + 1
			var threshold := 8 if target.kind == "boss" else (6 if target.elite else 4)
			effects.tag(target, count, threshold)
			if count >= threshold:
				var power := 3.0 if target.kind == "boss" else (2.5 if target.elite else 2.0)
				effects.ruling(target, damage * power, owner_id, false)
				count = 0
			chain_marks[id] = count

func _draw() -> void:
	var fade := minf(1.0, life * 3.0)
	var color: Color = game.Balance.PLAYER_COLORS[owner_id]
	Art.shadow(self, Vector2(7, 8), Vector2(64, 27), fade * 0.7)
	draw_arc(Vector2(0, 6), 21, 0, TAU, 40, Color(color, fade * 0.8), 1.5, true)
	var texture := Art.asset("lightning_tower", "art")
	if texture != null:
		draw_texture_rect(texture, Rect2(-38, -105, 76, 114), false, Color(1, 1, 1, fade))
	var glow := 0.5 + sin(game.elapsed * 5.0 + owner_id) * 0.12
	if tide_enabled:
		var until_tide := next_tide - (total_duration - life)
		if life <= 1.4 or until_tide < 0.5:
			glow += 0.25
			for index in range(6):
				var angle: float = float(index) * TAU / 6.0 + game.elapsed * 2.0
				var at := Vector2.from_angle(angle) * 32.0
				draw_line(at, at * 0.65 + Vector2(0, -15), Color(0.64, 0.47, 1.0, fade * 0.8), 2, true)
	draw_texture_rect(Art.glow(), Rect2(-24, -99, 48, 48), false, Color(0.36, 0.73, 1.0, glow * fade))
	draw_circle(Vector2(0, -75), 5.0, Color(0.8, 0.98, 1.0, fade))
	var label := "P%d 雷楞塔 %.1fs" % [owner_id + 1, life]
	draw_string_outline(ThemeDB.fallback_font, Vector2(-60, 26), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, 3, Color("0c1825"))
	draw_string(ThemeDB.fallback_font, Vector2(-60, 26), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, color)

func _draw_bolt() -> void:
	if beam_life <= 0.0:
		return
	var start := Vector2(0, -75)
	var end := beam_end - position
	var normal := (end - start).normalized().orthogonal()
	var points := PackedVector2Array([start])
	for index in range(1, 10):
		var along := float(index) / 10.0
		points.append(start.lerp(end, along) + normal * sin(float(index) * 8.7 + game.elapsed * 60.0) * 10.0 * sin(along * PI))
	points.append(end)
	var fade := beam_life / 0.18
	bolts.draw_polyline(points, Color(0.24, 0.59, 1.0, fade * 0.36), 6.0, true)
	bolts.draw_polyline(points, Color(0.63, 0.89, 1.0, fade), 2.4, true)
	bolts.draw_polyline(points, Color(0.93, 1.0, 1.0, fade), 1.0, true)
	bolts.draw_texture_rect(Art.glow(), Rect2(end - Vector2(18, 18), Vector2(36, 36)), false, Color(0.50, 0.80, 1.0, fade * 0.75))

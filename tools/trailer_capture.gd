extends SceneTree
## Deterministic Movie Maker director. Uses the real game simulation and skills.
## Only this script stages builds, enemies and cast times; normal play is untouched.
const Skills = preload("res://scripts/skill_upgrades.gd")
const Overlay = preload("res://tools/trailer_overlay.gd")
var game
var boss = null
var overlay
var shots: Array[Dictionary] = []
var shot_index := -1
var shot_time := 0.0
var total_time := 0.0
var total_duration := 0.0
var frame_count := 0
var events: Dictionary = {}
var rng := RandomNumberGenerator.new()
var preview := false

func add_shot(kind: String, duration: float, title: String, detail: String, module := "") -> void:
	shots.append({"kind": kind, "duration": duration, "title": title, "detail": detail, "module": module})
	total_duration += duration

func _initialize() -> void:
	preview = "--preview" in OS.get_cmdline_user_args()
	rng.seed = 20261005
	add_shot("intro", 3.0, "双人幸存者 / 战斗宣传片", "两位玩家，同屏迎战。")
	add_shot("duo", 3.0, "一起冲进怪潮", "法师 × 战士  /  共享经验，独立构筑")
	add_shot("fire", 5.8, "法师 / 吞能炎星", "四重火球 · 吸收成长 · 炎浪击退 · 烈焰之路")
	add_shot("frost", 4.0, "法师 / 庇护寒域", "冰锥雨 · 冰径 · 减速与挡弹")
	add_shot("lightning", 6.0, "法师 / 雷神裁决", "天雷链狱 · 雷霆潮汐 · 天空法阵与巨雷")
	add_shot("possession", 4.5, "双人合体 / 附身突袭", "战士掌控走位，法师持续输出。")
	add_shot("dash", 3.5, "战士 / 炎刃破空", "二段突袭 · 炎刃附魔 · 穿屏斩击")
	add_shot("giant", 5.0, "战士 / 人肉炮弹", "巨大化撞击 · 连锁撞飞 · 震地余波 · 荆棘反甲")
	add_shot("rescue", 3.5, "双人配合 / 庇护救援", "瞬移救援 · 队友护盾 · 并肩反攻 · 嘲讽木桩")
	var king_names := ["疾行连斩", "断界突进", "裁决锁魂斩", "震地重击", "瞬步背斩"]
	for i in range(5): add_shot("king", 2.2, "01 / 断界武王", king_names[i] + "  /  高速近战，步步紧逼", str(i))
	var artillery_names := ["环形齐射", "追踪轰炸", "交叉火网", "地毯轰炸", "全场弹幕"]
	for i in range(5): add_shot("artillery", 2.4, "02 / 轰界炮皇", artillery_names[i] + "  /  密集弹幕，极限走位", str(i))
	var dragon_names := ["肚皮霸体 · 三连弹撞", "奶油吐息 · 摇头喷射", "骚包银河 · 金奶流星", "本龙登场 · 双人奶爆"]
	for i in range(4): add_shot("dragon", 2.8, "03 / 不灭奶龙", dragon_names[i], str(i))
	add_shot("rebirth", 3.3, "第一条命击破 / 奶蛙重生", "别急着庆祝。真正的终局才刚开始。")
	var frog_names := ["奶蛙三连 · 蛙跳砸场", "舔屏追魂 · 双人舌鞭", "蛙王泡泡 · 全屏蹦迪", "荷塘天罚 · 奶蛙核爆"]
	for i in range(4): add_shot("frog", 2.8, "第二条命 / 暴走奶蛙", frog_names[i], str(i))
	add_shot("clones", 4.0, "50% 血量 / 复制军团", "四个弱化分身参战，火力再次升级。")
	add_shot("finale", 4.0, "同屏开火 / 联手破局", "冰、火、雷与重装战士，一起打穿终局。")
	add_shot("outro", 3.0, "双人幸存者 / Twin Survivors", "本地双人割草肉鸽 Demo")
	call_deferred("start")

func start() -> void:
	root.size = Vector2i(1280, 800)
	var layer := CanvasLayer.new()
	layer.layer = 20
	root.add_child(layer)
	overlay = Overlay.new()
	overlay.director = self
	layer.add_child(overlay)
	next_shot()
	var manifest := FileAccess.open("res://artifacts/promo/shots.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify(shots, "\t"))
	print("TRAILER START: ", shots.size(), " shots / ", total_duration, " seconds")

func tier(player, id: String, rank := 3) -> void:
	for i in range(rank): Skills.apply(player, id)

func full_build() -> void:
	for entry in Skills.CATALOG: tier(game.players[0], entry.id)
	for entry in Skills.MAJORS: tier(game.players[0], entry.id, 1)
	for entry in Skills.WARRIOR_CATALOG: tier(game.players[1], entry.id)
	for entry in Skills.WARRIOR_MAJORS: tier(game.players[1], entry.id, 1)

func enemy(at: Vector2, health := 170.0, elite := false, variant := "normal"):
	var unit = game.Enemy.new()
	unit.setup(at, game.Balance.difficulty(120), elite, variant)
	unit.hp = health
	unit.max_hp = health
	unit.ranged_attack.connect(game._fire_enemy_pattern)
	game.world.add_child(unit)
	game.enemies.append(unit)
	return unit

func crowd(count: int, center := Vector2(760, 420), spread := Vector2(400, 250), hp := 170.0) -> void:
	for i in range(count):
		var pos: Vector2 = center + Vector2(rng.randf_range(-spread.x, spread.x), rng.randf_range(-spread.y, spread.y))
		pos = pos.clamp(Vector2(80, 155), Vector2(1200, 675))
		var variant := "normal" if i % 5 != 0 else "runner"
		if i % 17 == 0: variant = "fan"
		enemy(pos, hp, i % 13 == 0, variant)

func setup_boss(kind: String, module: int) -> void:
	game.players[0].position = Vector2(525, 510)
	game.players[1].position = Vector2(805, 500)
	if kind == "king": game._spawn_final_boss()
	elif kind == "artillery":
		game.final_battle = true
		game.final_stage = 1
		game._spawn_ranged_final_boss()
	else:
		game.final_battle = true
		game.final_stage = 2
		game._spawn_milk_final_boss()
		game.milk_announcement.remaining = 0
		game.milk_announcement.interval_remaining = 1000
		game.milk_announcement.hide()
	boss = game.mini_boss
	boss.position = Vector2(650, 350)
	boss.state = "approach"
	boss.attack_step = module
	boss.phase = 2
	boss.hp = boss.max_hp * 0.55
	boss.combat_players = game.players
	if kind == "king":
		if module in [0, 3]: boss.position = Vector2(580, 440)
		boss._start_module(game.players[0])
	elif kind == "artillery": boss._start_artillery(game.players[0])
	else:
		boss.phase = 1
		boss.hp = boss.max_hp * 0.8
		if kind in ["frog", "clones", "finale"]:
			boss.form = 2
			boss.hp = boss.SECOND_HP
			boss.max_hp = boss.hp
			boss.damage = 165
		var cycle: Array = boss.FROG_CYCLE if boss.form == 2 else boss.DRAGON_CYCLE
		# Retain two actual transparent cut-ins, separated by montage time.
		if module == 1 and kind in ["dragon", "frog"]:
			game.milk_announcement.interval_remaining = 0
			game.milk_announcement.show()
		boss._start_milk(game.players[0], cycle[module])

func next_shot() -> void:
	if game != null: game.queue_free()
	boss = null
	shot_index += 1
	if shot_index >= shots.size():
		print("TRAILER COMPLETE / frames=", frame_count)
		quit()
		return
	shot_time = 0
	events.clear()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process_unhandled_input(false)
	game.set_process_unhandled_key_input(false)
	game.start_run()
	game.hud.hide()
	game.rng.seed = 104729 + shot_index
	game.team_level = 100000 # Collect real XP without interrupting the movie with choices.
	game.spawn_credit = -100000
	game.next_wave = INF
	game.next_boss = INF
	game.elapsed = 100
	for player in game.players:
		player.rng.seed = 7919 + player.player_id
		player.stats.max_hp = 250
		player.hp = 250
		player.stats.damage = 35
		player.stats.projectiles = 3
		player.stats.pierce = 3
		player.stats.interval = 0.4
		player.invulnerability = 100 # Recording protection; not applied in normal play.
	game.players[0].position = Vector2(380, 420)
	game.players[1].position = Vector2(590, 490)
	var shot: Dictionary = shots[shot_index]
	var kind: String = shot.kind
	if kind in ["king", "artillery", "dragon", "frog", "rebirth", "clones", "finale"]:
		setup_boss(kind, int(shot.module) if not shot.module.is_empty() else 0)
	else: crowd(85)
	if kind in ["intro", "duo", "possession", "finale", "outro"]: full_build()
	if kind == "fire":
		game.players[0].position = Vector2(285, 420)
		tier(game.players[0], "fire_width", 1)
		tier(game.players[0], "fire_count")
		for id in ["fire_push", "fire_ground", "fire_growth"]: tier(game.players[0], id, 1)
		for i in range(18): enemy(Vector2(530 + i * 24, 400 + (i % 3 - 1) * 45), 260)
		enemy(Vector2(1090, 420), 2400, true)
	elif kind == "frost":
		tier(game.players[0], "frost_width", 1)
		tier(game.players[0], "frost_rate")
		for id in ["frost_cones", "frost_path", "frost_ward"]: tier(game.players[0], id, 1)
		game.players[0].position = Vector2(525, 440)
	elif kind == "lightning":
		for id in ["tower_rate", "tower_core"]: tier(game.players[0], id)
		for id in ["tower_chain", "tower_tide", "tower_judgment"]: tier(game.players[0], id, 1)
		game.players[0].position = Vector2(565, 445)
		var target = enemy(Vector2(700, 405), 8000, true)
		target.speed = 0
		game.activate_skill(0)
		# Start the take late enough to show the actual end-of-life triple tide.
		game.mage_system.towers[0].life = 5.6
	elif kind in ["dash", "giant", "rescue"]:
		for entry in Skills.WARRIOR_CATALOG: tier(game.players[1], entry.id)
		for entry in Skills.WARRIOR_MAJORS: tier(game.players[1], entry.id, 1)
		game.players[1].position = Vector2(405, 420)
		if kind == "giant":
			game.players[1].stats.max_hp = 1000
			game.players[1].hp = 1000
			game.players[1].invulnerability = 0 # Actual contacts drive reflected damage VFX.
			crowd(45, Vector2(530, 420), Vector2(190, 100), 180)
			game.players[0].position = Vector2(435, 450)
		elif kind == "rescue":
			game.players[0].position = Vector2(780, 430)
			game.players[0].hp = 80
	if kind == "rebirth":
		game.milk_announcement.interval_remaining = 1000
		boss.hit(1000000)
	if kind == "clones":
		boss.hit(boss.max_hp * 0.8)
		game._flush_milk_clones()
	print("SHOT ", shot_index + 1, " / ", kind, " / ", shot.title, " / ", shot.detail)

func once(key: String, at: float) -> bool:
	if shot_time < at or events.has(key): return false
	events[key] = true
	return true

func direction_to(player, destination: Vector2) -> Vector2:
	return (destination - player.position).normalized() if player.position.distance_to(destination) > 12 else Vector2.ZERO

func choreograph(kind: String) -> Array:
	var p1 = game.players[0]
	var p2 = game.players[1]
	var move: Array = [Vector2.ZERO, Vector2.ZERO]
	if kind in ["intro", "duo", "outro", "finale"]:
		move = [direction_to(p1, Vector2(540 + sin(shot_time * 1.2) * 160, 430 + cos(shot_time) * 100)), direction_to(p2, Vector2(705 + cos(shot_time) * 200, 430 + sin(shot_time * 1.4) * 120))]
		if once("fire", 0.3): game.activate_mage_skill(0, 1)
		if once("ice", 0.8): game.activate_mage_skill(0, 2)
		if once("tower", 0.1): game.activate_skill(0)
		if once("giant", 0.45): game.activate_warrior_skill(1, 2)
		if once("dash", 1.4): game.activate_skill(1, Vector2.RIGHT)
		if once("dash2", 2.4): game.activate_skill(1, Vector2.LEFT)
	elif kind == "fire":
		move[0] = Vector2.UP if shot_time < 1 else Vector2.DOWN * 0.25
		move[1] = direction_to(p2, Vector2(680, 600))
		if once("cast", 0.15): game.activate_mage_skill(0, 1)
	elif kind == "frost":
		move[0] = direction_to(p1, Vector2(740, 430 + sin(shot_time * 1.8) * 95))
		move[1] = direction_to(p2, p1.position + Vector2(110, 35))
		if once("cast", 0.15): game.activate_mage_skill(0, 2)
	elif kind == "lightning":
		move = [direction_to(p1, Vector2(440, 500)), direction_to(p2, Vector2(870, 550))]
	elif kind == "possession":
		move[1] = direction_to(p2, Vector2(660 + sin(shot_time * 2) * 240, 430 + cos(shot_time * 1.5) * 140))
		if once("attach", 0.15): game.activate_mage_skill(0, 3)
		if once("fire", 0.55): game.activate_mage_skill(0, 1)
		if once("tower", 0.7): game.activate_skill(0)
		if once("dash", 1.2): game.activate_skill(1, Vector2.RIGHT)
		if once("ice", 1.8): game.activate_mage_skill(0, 2)
	elif kind == "dash":
		move[1] = Vector2.RIGHT * 0.4
		if once("dash", 0.2): game.activate_skill(1, Vector2.RIGHT)
		if once("dash2", 1.1): game.activate_skill(1, Vector2(-1, -0.22).normalized())
	elif kind == "giant":
		move[1] = direction_to(p2, Vector2(830, 420 + sin(shot_time) * 90))
		if once("cast", 0.1): game.activate_warrior_skill(1, 2)
	elif kind == "rescue":
		if once("rescue", 0.25): game.activate_warrior_skill(1, 3)
		if once("warcry", 1.0): game.activate_warrior_skill(1, 1)
		move[1] = direction_to(p2, Vector2(610, 370))
	elif kind not in ["rebirth"]:
		move[0] = direction_to(p1, Vector2(450 + sin(shot_time * 2.0) * 150, 500 + cos(shot_time * 1.7) * 110))
		move[1] = direction_to(p2, Vector2(820 + cos(shot_time * 2.0) * 160, 430 + sin(shot_time * 1.5) * 130))
		if once("dash", 1.4): game.activate_skill(1, Vector2(-0.7, -0.3).normalized())
		if kind == "clones" and once("tower", 0.5): game.activate_skill(0)
	return move

func _process(_delta: float) -> bool:
	if game == null or shot_index < 0: return false
	var kind: String = shots[shot_index].kind
	for substep in range(2):
		game.simulate(1.0 / 60, choreograph(kind))
		shot_time += 1.0 / 60
		total_time += 1.0 / 60
	frame_count += 1
	var zoom := 1.015
	if kind == "king": zoom = 1.23 + minf(0.05, shot_time * 0.025)
	if kind in ["dragon", "frog", "rebirth"]: zoom = 1.12 + minf(0.04, shot_time * 0.015)
	var strength := 1.2
	if kind in ["giant", "king", "artillery", "rebirth"]: strength = 2.5
	game.scale = Vector2.ONE * zoom
	game.position = Vector2(640, 400) * (1 - zoom) + Vector2(sin(shot_time * 53), cos(shot_time * 61)) * strength
	game.hud.hide()
	overlay.queue_redraw()
	if preview and total_time >= 8:
		print("PREVIEW COMPLETE")
		quit()
	elif shot_time + 0.00001 >= float(shots[shot_index].duration): next_shot()
	return false

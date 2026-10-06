extends SceneTree
## Only the new small attacks, presentation spacing and brief rage exception.
const Boss = preload("res://scripts/milk_boss.gd")
var game
var boss
var checks := 0
var failures := 0
var wall := 0.0
var presentations: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)

func record(label: String, exception: bool) -> void:
	presentations.append({"time":wall,"label":label,"exception":exception})

func prepare(form: int) -> void:
	game._clear_hostile_attacks()
	game.milk_announcement.remaining = 0
	game.milk_announcement.interval_remaining = 0
	game.milk_announcement.hide()
	boss.form = form
	boss.max_hp = Boss.FIRST_HP if form == 1 else Boss.SECOND_HP
	boss.hp = boss.max_hp
	boss.damage = 140.0 if form == 1 else 165.0
	boss.phase = 1
	boss.state = "approach"
	boss.attack_step = 0
	boss.major_step = 0
	boss.major_remaining = Boss.MAJOR_INTERVAL
	boss.rage_followup = false
	boss.attack_cooldown = 0
	boss.position = Vector2(645,410)
	for id in range(2):
		var player = game.players[id]
		player.position = Vector2(560+id*240,490)
		player.stats.max_hp = 10000
		player.stats.regen = 0
		player.hp = 10000
		player.downed = false
		player.invulnerability = 0
		player.shot_cooldown = 1000

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game.elapsed = 180
	for enemy in game.enemies: enemy.queue_free()
	game.enemies.clear()
	game.final_battle = true
	game.final_stage = 2
	game._spawn_milk_final_boss()
	boss = game.mini_boss
	game.simulate(0.81,[Vector2.ZERO,Vector2.ZERO])
	game.milk_announcement.started.connect(record)
	for form in [1,2]:
		var small: Array = Boss.DRAGON_SMALL if form == 1 else Boss.FROG_SMALL
		for module in small:
			prepare(form)
			game.milk_announcement.interval_remaining = 10
			boss._start_milk(game.players[0],module)
			var unlocked: bool = not game.milk_announcement.is_active() and game.simulation_speed() == 1
			boss.advance(boss.attack_windup+0.001,game.players[0])
			if module in ["short_bump","little_hop"]: boss.advance(0.5,game.players[0])
			var connected: bool = game.players[0].hp < 10000
			if module in ["mini_spit","bubble_spit"]:
				connected = game.enemy_bullets.size() == (5 if form == 1 else 3)
				for bullet in game.enemy_bullets: connected = connected and bullet.damage < boss.damage
			check(unlocked and connected and boss.state == "recover","small skill releases real damage/shots without cut-in: "+module)
	# The global gate also applies to rebirth / clone notices and never queues them.
	prepare(1)
	var first: bool = game.milk_announcement.announce("A","",1,"idle")
	game.milk_announcement.advance(0.8)
	var blocked: bool = not game.milk_announcement.announce("B","",1,"idle")
	game.milk_announcement.tick_interval(9.19)
	blocked = blocked and not game.milk_announcement.announce("C","",1,"idle")
	game.milk_announcement.tick_interval(0.02)
	check(first and blocked and game.milk_announcement.announce("D","",1,"idle"),"global cut-in gate rejects every normal request before ten seconds")
	prepare(1)
	game.milk_announcement.announce("阶段提示","",1,"idle")
	game.milk_announcement.advance(0.8)
	boss.major_remaining = 0
	boss._start_milk(game.players[0])
	var held: bool = boss.boss_attack in Boss.DRAGON_SMALL and boss.major_step == 0 and not game.milk_announcement.is_active()
	game.milk_announcement.tick_interval(9.21)
	boss._start_milk(game.players[0])
	check(held and boss.boss_attack in Boss.DRAGON_CYCLE and game.milk_announcement.is_active(),"a notice postpones the next major rather than releasing an unannounced ultimate")
	for form in [1,2]:
		prepare(form)
		presentations.clear()
		for player in game.players: player.invulnerability = 100
		var small_seen: Dictionary = {}
		for frame in range(32*60):
			wall += 1.0/60.0
			game.simulate(1.0/60.0,[Vector2.ZERO,Vector2.ZERO])
			if boss.state == "windup" and boss.boss_attack in (Boss.DRAGON_SMALL if form == 1 else Boss.FROG_SMALL): small_seen[boss.boss_attack] = true
		var spaced := true
		for index in range(1,presentations.size()):
			spaced = spaced and not presentations[index].exception and presentations[index].time-presentations[index-1].time >= 10
		check(presentations.size() >= 2 and spaced and small_seen.size() == 3,"actual form %d combat alternates small attacks with majors spaced at least ten seconds"%form)
	prepare(2)
	boss.major_remaining = 0
	boss._start_milk(game.players[0])
	game.simulate(0.81,[Vector2.ZERO,Vector2.ZERO])
	boss.state = "approach"
	boss.hp = boss.max_hp*0.61
	game._damage_enemy(boss,boss.max_hp*0.04,0)
	check(boss.phase == 2 and boss.rage_followup and presentations[-1].exception and game.milk_announcement.is_active(),"entering rage can announce inside the normal ten-second interval")
	game.simulate(0.81,[Vector2.ZERO,Vector2.ZERO])
	boss._start_milk(game.players[0])
	check(presentations[-1].exception and not boss.rage_followup and boss.major_remaining == 12,"rage permits one immediate major then consumes its exception")
	game.simulate(0.81,[Vector2.ZERO,Vector2.ZERO])
	boss._start_milk(game.players[0])
	check(not game.milk_announcement.is_active() and boss.boss_attack in Boss.FROG_SMALL and not game.milk_announcement.announce("普通播报","",2,"idle"),"remaining in rage does not bypass spacing for subsequent small attacks or notices")
	var remaining: float = boss.major_remaining
	var interval: float = game.milk_announcement.interval_remaining
	game.paused = true
	game.simulate(3,[Vector2.ZERO,Vector2.ZERO])
	check(boss.major_remaining == remaining and game.milk_announcement.interval_remaining == interval,"pause freezes both major and presentation interval timers")
	print("MILK PACING: ",checks," checks, ",failures," failures")
	game.free()
	quit(1 if failures > 0 else 0)

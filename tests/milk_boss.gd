extends SceneTree
const MilkBoss = preload("res://scripts/milk_boss.gd")
const MilkClone = preload("res://scripts/milk_clone.gd")
## Necessary checks for the new boss only; no full-run regression.
var game
var boss
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error(label)

func prepare(form: int, index: int) -> void:
	game._clear_hostile_attacks()
	game.damage_events.clear()
	boss.visual_system.effects.clear()
	boss.form = form
	boss.state = "approach"
	boss.position = Vector2(645,410)
	boss.phase = 1
	boss.attack_step = index
	boss.strike_hits.clear()
	boss.damage = 140.0 if form == 1 else 165.0
	for id in range(2):
		var player = game.players[id]
		player.position = Vector2(560+id*240,490)
		player.downed = false
		player.hp = 10000
		player.stats.max_hp = 10000
		player.invulnerability = 0.0
		player.shot_cooldown = 100
	game.milk_announcement.interval_remaining = 0.0
	var modules: Array = MilkBoss.DRAGON_CYCLE if form == 1 else MilkBoss.FROG_CYCLE
	boss._start_milk(game.players[0],modules[index])

func step(delta: float) -> void:
	game.elapsed += delta
	boss.advance(delta,game.players[0])

func fire() -> void:
	game.simulate(game.milk_announcement.remaining+0.001,[Vector2.ZERO,Vector2.ZERO])
	step(boss.attack_windup+0.001)

func screen(name: String) -> void:
	game.hud.refresh()
	game.queue_redraw()
	boss.queue_redraw()
	boss.visual_system.refresh()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	print("CAPTURE ",name," ",root.get_texture().get_image().save_png("res://artifacts/"+name+".png"))

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game.elapsed = 180
	game._update_spawning(0)
	game._damage_enemy(game.mini_boss,1000000,0)
	game._update_projectiles(0)
	game._update_spawning(3)
	game._damage_enemy(game.mini_boss,1000000,0)
	game._update_projectiles(0)
	check(not game.game_over and game.final_stage == 2 and game.final_transition_remaining == 4,"artillery defeat leads to third boss rather than victory")
	game._update_spawning(4)
	boss = game.mini_boss
	check(boss is MilkBoss and game.final_stage == 3 and boss.hp == 65000,"third finale spawns milk dragon with finite first health bar")
	game.simulate(0.81,[Vector2.RIGHT,Vector2.LEFT])
	for player in game.players: player.invulnerability = 100
	for frame in range(30): game.simulate(1.0/60.0,[Vector2.ZERO,Vector2.ZERO])
	check(game.simulation_speed() == 1 and boss.form == 1,"new boss runs through the real simulation owner")
	var capture := "--capture" in OS.get_cmdline_user_args()
	if "--cutin-only" in OS.get_cmdline_user_args():
		for form in [1,2]:
			prepare(form,1)
			game.simulate(0.16,[Vector2.RIGHT,Vector2.LEFT])
			await screen("milk_precast_%d"%form)
			fire()
			step(0.12 if form == 2 else 0.02)
			await screen("milk_cream" if form == 1 else "milk_tongue")
		prepare(2,2)
		game.simulate(0.16,[Vector2.ZERO,Vector2.ZERO])
		await screen("milk_precast_laugh")
		game.free()
		quit()
		return
	prepare(1,1)
	var hostile = game.EnemyBullet.new()
	hostile.position = game.players[0].position
	hostile.velocity = Vector2.RIGHT*500
	hostile.damage = 100
	game.world.add_child(hostile)
	game.enemy_bullets.append(hostile)
	var clock: float = game.elapsed
	var cooldown: float = game.players[0].shot_cooldown
	game.simulate(0.2,[Vector2.RIGHT,Vector2.LEFT])
	check(hostile.position == game.players[0].position and game.players[0].hp == 10000 and game.elapsed == clock and game.players[0].shot_cooldown == cooldown,"cut-in freezes overlapping hostile shots, cooldowns and battle clock")
	check(not game.activate_mage_skill(0,0) and not game.activate_skill(1,Vector2.RIGHT),"both players cannot cast during full-screen announcement")
	for form in [1,2]:
		for index in range(4):
			prepare(form,index)
			check(game.milk_announcement.remaining > 0 and game.simulation_speed() == 0,"pre-cast announcement locks action: %d/%d"%[form,index])
			var start: Vector2 = game.players[0].position
			var health: float = game.players[0].hp
			var windup: float = boss.attack_windup
			game.simulate(0.16,[Vector2.RIGHT,Vector2.LEFT])
			check(game.players[0].position == start and game.players[0].hp == health and boss.attack_windup == windup,"cut-in prevents movement, damage and early skill release: %d/%d"%[form,index])
			if capture and index == 1: await screen("milk_precast_%d"%form)
			fire()
			match boss.boss_attack:
				"belly": step(0.08)
				"cream": step(0.02)
				"disco", "bubble": step(0.48)
				"hop": step(0.32)
				"royal", "lotus": game._update_enemy_attacks(0.55)
			if capture:
				if boss.boss_attack == "tongue": step(0.12)
				if boss.boss_attack in ["disco","bubble"]: game._update_enemy_attacks(0.35)
				await screen("milk_"+boss.boss_attack)
	check(game.enemy_bullets.size() <= game.Balance.MAX_ENEMY_BULLETS,"dense waves obey hostile bullet budget")
	prepare(2,1)
	game.players[0].invulnerability = 1.0
	fire()
	check(game.players[0].hp == 10000 and is_equal_approx(game.players[1].hp,9810.25),"tongue lock attacks both targets and respects invulnerability")
	prepare(1,3)
	fire()
	var hazard = game.enemy_hazards[0]
	game._update_enemy_attacks(0.51)
	var after: float = game.players[0].hp
	game.players[0].invulnerability = 0
	game._update_enemy_attacks(0.04)
	check(after == 9755 and game.players[0].hp == after and hazard.hit_players.has(0),"milk bomb applies exactly one hit during animated explosion")
	prepare(1,0)
	game.simulate(0.81,[Vector2.ZERO,Vector2.ZERO])
	var kills: int = game.players[0].kills
	game._damage_enemy(boss,1000000,0)
	check(not boss.dead and boss.state == "rebirth" and not game.victory and game.players[0].kills == kills,"first defeat starts rebirth without kill reward or victory")
	game._damage_enemy(boss,1000000,0)
	game.paused = true
	game.simulate(1,[Vector2.ZERO,Vector2.ZERO])
	check(boss.rebirth_remaining == 2.4,"pause freezes rebirth and invulnerable first corpse")
	game.paused = false
	game.simulate(0.81,[Vector2.ZERO,Vector2.ZERO])
	step(2.4)
	check(boss.form == 2 and boss.hp == 85000 and boss.max_hp == 85000,"rebirth restores second form full health")
	if capture:
		await screen("milk_rebirth")
	game._damage_enemy(boss,30000,0) # Recovery vulnerability: 45k removes slightly over half.
	game.simulate(0.81,[Vector2.ZERO,Vector2.ZERO])
	game._flush_milk_clones()
	var copies := 0
	for enemy in game.enemies:
		if enemy is MilkClone:
			copies += 1
			check(enemy.hp == 1800 and enemy.damage == 32,"clone has reduced health and damage")
	check(copies == 4 and boss.clones_summoned,"half-health summons exactly four copies")
	game._damage_enemy(boss,1,0)
	check(game.pending_milk_clones.is_empty(),"half-health summon cannot repeat")
	if capture:
		await screen("milk_clones")
	for enemy in game.enemies:
		if enemy is MilkClone: enemy.advance(4,game.players[0])
	check(game.enemy_bullets.size() == 12,"all four clones can release weak three-bubble shots")
	game._damage_enemy(boss,1000000,0)
	check(game.victory and game.game_over and game.enemy_bullets.is_empty(),"second defeat wins and clears remaining hostile attacks")
	var alive := false
	for enemy in game.enemies:
		if enemy is MilkClone and not enemy.dead: alive = true
	check(not alive,"boss defeat removes surviving copies")
	print("MILK BOSS: ",checks," checks, ",failures," failures")
	game.free()
	quit(1 if failures > 0 else 0)

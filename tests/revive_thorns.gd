extends SceneTree
## Focused checks for removed speed Buff, rescue shield, reflection and team revival.
const Main = preload("res://scenes/main.tscn")
const Skills = preload("res://scripts/skill_upgrades.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
var game
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func run() -> void:
	game = Main.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	game.spawn_credit = -10000.0
	game.next_wave = INF
	game.next_boss = INF
	var warrior = game.players[0]
	var ally = game.players[1]
	warrior.configure_class(game.Classes.RAIDER)
	ally.configure_class(game.Classes.MAGE)
	warrior.position = Vector2(400, 400)
	ally.position = Vector2(1000, 600)
	var speed: float = warrior.stats.speed
	Skills.apply(warrior, "giant_refund")
	game.activate_warrior_skill(0, 2)
	warrior.invulnerability = 0.0
	warrior.take_damage(1.0)
	check(warrior.giant_cooldown == 11.5 and warrior.giant_refund_total == 0.5, "Giant effective hit refunds half a second")
	warrior.take_damage(1.0)
	check(warrior.giant_refund_total == 0.5, "invulnerability-blocked hits cannot farm cooldown refund")
	for index in range(10):
		warrior.invulnerability = 0.0
		warrior.take_damage(1.0)
	check(warrior.giant_refund_total == 3.0 and warrior.giant_cooldown == 9.0, "refund is capped at three seconds per Giant cast")
	warrior.giant_remaining = 0.0
	warrior.invulnerability = 0.0
	warrior.take_damage(1.0)
	check(warrior.giant_cooldown == 9.0, "damage outside Giant does not reduce its cooldown")
	warrior.giant_cooldown = 0.0
	game.activate_warrior_skill(0, 2)
	check(warrior.giant_refund_total == 0.0 and warrior.giant_cooldown == 12.0, "a new Giant cast resets the refund budget")
	warrior.giant_cooldown = 0.2
	warrior.invulnerability = 0.0
	warrior.take_damage(1.0)
	check(warrior.giant_cooldown == 0.0 and is_equal_approx(warrior.giant_refund_total, 0.2), "refund never makes cooldown negative")
	warrior.configure_class(game.Classes.RAIDER)
	check(Upgrades.definition("speed").is_empty() and not Upgrades.apply(warrior, "speed")
		and warrior.stats.speed == speed and Upgrades.CATALOG.size() == 5, "speed Buff is removed and cannot alter base movement")
	var removed := true
	for iteration in range(12):
		for offer in Upgrades.roll(warrior.rng): removed = removed and offer.id != "speed"
	check(removed, "speed never appears in shared Buff choices")
	check(Skills.apply(warrior, "giant_thorns") and Skills.apply(warrior, "rescue_blessing")
		and not Skills.apply(warrior, "giant_blessing"), "reflection belongs to Giant and shelter is a separate Rescue major")
	warrior.stats.max_hp = 200.0
	warrior.hp = 200.0
	game.activate_warrior_skill(0, 2)
	ally.position = warrior.position
	var starts: Array[Vector2] = [warrior.position, ally.position]
	game.warrior_system.giant_contacts(starts)
	check(ally.blessing_remaining == 0.0, "Giant no longer grants a teammate shield")
	warrior.invulnerability = 0.0
	game.activate_warrior_skill(0, 3)
	check(warrior.invulnerability == 1.0, "base Rescue grants one second of invulnerability")
	check(ally.blessing_remaining == 10.0 and ally.blessing_shield == 100.0 and ally.tenacity() == 0.5,
		"Rescue grants ten-second shelter using half the warrior's maximum health")
	warrior.end_carry()
	ally.invulnerability = 0.0
	ally.hp = 40.0
	ally.take_damage(40.0)
	check(ally.hp == 40.0 and is_equal_approx(ally.blessing_shield, 60.0), "Rescue shelter absorbs damage without its former extra mitigation")
	ally.invulnerability = 0.0
	ally.take_damage(10000.0)
	warrior.rescue_cooldown = 0.0
	game.activate_warrior_skill(0, 3)
	check(not ally.downed and game.instant_revive_used and ally.blessing_shield == 100.0,
		"Rescue shelter also applies after the once-per-run instant revival")
	ally.position = Vector2(1000, 600)
	var attacker = game.Enemy.new()
	attacker.setup(Vector2(700, 400), game.Balance.difficulty(0.0), false)
	attacker.hp = 100000.0
	attacker.max_hp = attacker.hp
	attacker.xp_value = 0
	game.world.add_child(attacker)
	game.enemies.append(attacker)
	warrior.invulnerability = 0.0
	warrior.giant_remaining = 4.0
	warrior.cold_ward_protection = true
	warrior.blessing_remaining = 10.0
	warrior.blessing_shield = 500.0
	var hp: float = warrior.hp
	warrior.take_damage(100.0, attacker.get_instance_id())
	game.warrior_system.flush_reflections()
	check(warrior.hp == hp and is_equal_approx(attacker.hp, 99700.0)
		and is_equal_approx(warrior.blessing_shield, 460.0), "full absorption and Giant mitigation still reflect three times raw incoming damage")
	Upgrades.apply(warrior, "damage")
	warrior.invulnerability = 0.0
	warrior.take_damage(100.0, attacker.get_instance_id())
	game.warrior_system.flush_reflections()
	check(is_equal_approx(attacker.hp, 99250.0), "reflection inherits global skill damage without scaling from reduced HP loss")
	var bullet = game.EnemyBullet.new()
	bullet.position = warrior.position
	bullet.damage = 60.0
	bullet.source_id = attacker.get_instance_id()
	game.world.add_child(bullet)
	game.enemy_bullets.append(bullet)
	warrior.invulnerability = 0.0
	game._update_enemy_attacks(0.01)
	game.warrior_system.flush_reflections()
	check(is_equal_approx(attacker.hp, 98980.0), "hostile projectile reflection returns raw shot damage to its shooter")
	var hazard = game.EnemyHazard.new()
	hazard.position = warrior.position
	hazard.warning_remaining = 0.0
	hazard.damage = 120.0
	hazard.source_id = attacker.get_instance_id()
	game.world.add_child(hazard)
	game.enemy_hazards.append(hazard)
	warrior.invulnerability = 0.0
	game._update_enemy_attacks(0.01)
	game.warrior_system.flush_reflections()
	check(is_equal_approx(attacker.hp, 98440.0), "ground attacks reflect their original damage to their source")
	var boss = game.FinalBoss.new()
	boss.setup_boss(Vector2(800, 500), game.Balance.difficulty(180.0), 0)
	boss.hp = 100000.0
	boss.max_hp = boss.hp
	boss.damage = 200.0
	boss.state = "windup"
	game.world.add_child(boss)
	game.enemies.append(boss)
	warrior.invulnerability = 0.0
	game._resolve_final_strike(boss, "circle", warrior.position, warrior.position, Vector2.RIGHT, 40.0, PI, 2.0)
	game.warrior_system.flush_reflections()
	check(is_equal_approx(boss.hp, 98200.0), "Boss skill multiplier is part of the raw damage reflected before defense")
	warrior.giant_remaining = 0.0
	warrior.invulnerability = 0.0
	warrior.take_damage(10.0, attacker.get_instance_id())
	game.warrior_system.flush_reflections()
	check(is_equal_approx(attacker.hp, 98440.0), "reflection ends when Giant expires")
	check(game.damage_breakdown[0].has("thorns"), "reflected damage is credited to the warrior as its own source")
	for pool in [game.enemy_hazards, game.enemy_bullets]:
		for node in pool: node.free()
		pool.clear()
	Skills.apply(warrior, "warcry_dummy")
	warrior.warcry_cooldown = 0.0
	warrior.giant_remaining = 0.0
	game.activate_warrior_skill(0, 1)
	var dummy = game.taunt_dummies[0]
	var origin: Vector2 = dummy.position
	check(warrior.warcry_remaining == 0.0 and dummy.hp == 200.0 and dummy.warcry_remaining == 10.0
		and game.priority_enemy_target(Vector2(1200, 600)) == dummy,
		"upgraded Warcry only taunts with a stationary ten-second full-max-health wooden dummy")
	warrior.position += Vector2(150, 0)
	ally.position = Vector2(1000, 600)
	game.paused = true
	game.simulate(1.0, [Vector2.RIGHT, Vector2.ZERO])
	check(dummy.position == origin and dummy.warcry_remaining == 10.0, "dummy stays at cast position and freezes during pause")
	game.paused = false
	var dummy_bullet = game.EnemyBullet.new()
	dummy_bullet.position = dummy.position
	dummy_bullet.damage = 25.0
	game.world.add_child(dummy_bullet)
	game.enemy_bullets.append(dummy_bullet)
	game._update_enemy_attacks(0.01)
	check(dummy.hp == 175.0, "hostile bullets damage the dummy instead of passing through it")
	dummy.take_damage(200.0)
	check(game.priority_enemy_target(origin) != dummy and warrior.warcry_remaining == 0.0, "destroyed dummy ends taunt without giving taunt to its owner")
	warrior.warcry_cooldown = 0.0
	game.activate_warrior_skill(0, 1)
	var expiry_dummy = game.taunt_dummies[-1]
	expiry_dummy.advance(10.0)
	check(not expiry_dummy.is_active() and game.priority_enemy_target(origin) != expiry_dummy, "dummy taunt expires at ten seconds")
	warrior.warcry_cooldown = 0.0
	game.activate_warrior_skill(0, 1)
	var boss_dummy = game.taunt_dummies[-1]
	boss.strike_hits.clear()
	boss.duel_target = boss_dummy
	game._resolve_final_strike(boss, "lock", boss_dummy.position, boss_dummy.position, Vector2.RIGHT, 40.0, PI, 1.0)
	check(boss_dummy.hp < boss_dummy.max_hp, "Boss locked attacks can damage the dummy")
	if "--capture" in OS.get_cmdline_user_args():
		warrior.warcry_cooldown = 0.0
		game.activate_warrior_skill(0, 1)
		warrior.giant_remaining = 4.0
		game.warrior_system.grant_rescue_blessing(warrior, ally)
		game.hud.refresh()
		game.warrior_system.visuals.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		print("SCREENSHOT ", root.get_texture().get_image().save_png("res://artifacts/warrior_dummy_thorns.png"))
	for lure in game.taunt_dummies: lure.free()
	game.taunt_dummies.clear()
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	for pool in [game.enemy_hazards, game.enemy_bullets]:
		for node in pool: node.free()
		pool.clear()
	warrior.configure_class(game.Classes.RAIDER)
	ally.configure_class(game.Classes.MAGE)
	game.shared_xp = 12
	for player in game.players:
		player.invulnerability = 0.0
		player.take_damage(10000.0)
	game.paused = true
	game.simulate(0.1, [Vector2.ZERO, Vector2.ZERO])
	check(not game.team_revive_used and warrior.downed and ally.downed, "pause does not consume the team resurrection")
	game.paused = false
	game.simulate(0.01, [Vector2.ZERO, Vector2.ZERO])
	check(not game.game_over and game.team_revive_used and not warrior.downed and not ally.downed
		and warrior.hp == warrior.stats.max_hp and ally.hp == ally.stats.max_hp
		and warrior.invulnerability == 3.0 and ally.invulnerability == 3.0
		and game.instant_revive_used and game.shared_xp == 12, "first double defeat restores full health and protection independently of Rescue, preserving XP")
	for player in game.players:
		player.invulnerability = 0.0
		player.take_damage(10000.0)
	game.simulate(0.01, [Vector2.ZERO, Vector2.ZERO])
	check(game.game_over and warrior.downed and ally.downed, "second double defeat ends the run without a second team resurrection")
	game.free()
	print("REVIVE/THORNS RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

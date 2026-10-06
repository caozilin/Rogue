extends SceneTree
## Fixed ward bounds/lifetime and Giant mitigation/cooldown changes only.
const Skills = preload("res://scripts/skill_upgrades.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1

func run() -> void:
	for ward_first in [false, true]:
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.set_physics_process(false)
		game.selected_classes = [1, 0]
		game.start_run()
		for enemy in game.enemies: enemy.free()
		game.enemies.clear()
		var mage = game.players[1]
		var ally = game.players[0]
		mage.position = Vector2(650, 445)
		ally.position = mage.position - Vector2(40, 0)
		if ward_first:
			Skills.apply(mage, "frost_ward")
		for rank in range(1, 4):
			Skills.apply(mage, "frost_width")
			var expected: float = game.Mage.FROST_RADIUS * Skills.RANGE_TIERS[rank]
			var before: float = game.mage_system.frost_radius(mage)
			if not ward_first and rank == 1:
				Skills.apply(mage, "frost_ward")
			mage.frost_remaining = 0.0
			mage.frost_cooldown = 0.0
			var activated: bool = game.activate_mage_skill(1, 2)
			game.mage_system.advance(0.35)
			var shell = game.mage_system.ward_visuals.shells[1]
			var bullet = game.EnemyBullet.new()
			bullet.damage = 25.0
			var ward_radius: float = game.Mage.WARD_RADIUS
			var missed: bool = not game.mage_system.intercept_bullet(mage.position + Vector2(100, 0), mage.position + Vector2(80, 0), bullet)
			var intercepted: bool = game.mage_system.intercept_bullet(mage.position + Vector2(ward_radius + 60, 0), mage.position + Vector2(ward_radius - 14, 0), bullet)
			check(activated and is_equal_approx(before, expected) and is_equal_approx(game.mage_system.frost_radius(mage), expected)
				and ally.cold_ward_protection and shell.visible and is_equal_approx(shell.scale.x, ward_radius * 2.30 / 32.0)
				and missed and intercepted and mage.frost_shield_hp == 75.0 and is_equal_approx(game.mage_system.ward_impacts.back().radius, ward_radius),
				"%s then range tier %d: field remains %.1f, shell/interception stay fixed at 48; former outer area no longer consumes shield" % ["ward" if ward_first else "range", rank, expected])
			bullet.free()
			if not ward_first and rank == 1 and "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
				game.hud.refresh()
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png("res://artifacts/frost_ward_range.png") == OK, "fixed small ward inside expanded field screenshot")
		var radius_before: float = game.mage_system.frost_radius(mage)
		check(game.activate_mage_skill(1, 3) and is_equal_approx(game.mage_system.frost_radius(mage), radius_before * 1.25)
			and game.mage_system.ward_radius() == 48.0, "possession expands the field but never the ward")
		mage.end_possession()
		var bullet = game.EnemyBullet.new()
		bullet.damage = 1000.0
		check(game.mage_system.intercept_bullet(mage.position, mage.position, bullet) and mage.frost_remaining > 0.0 and mage.frost_ward_remaining == 0.0
			and not ally.cold_ward_protection and not game.mage_system.ward_visuals.shells[1].visible
			and is_equal_approx(game.mage_system.ward_impacts.back().radius, 48.0), "breaking ward clears its protection but preserves the frost field")
		bullet.free()
		mage.frost_cooldown = 0.0
		game.activate_mage_skill(1, 2)
		var hp_before: float = mage.hp
		mage.invulnerability = 0.0
		mage.take_damage(20.0)
		check(is_equal_approx(mage.hp, hp_before - 20.0) and mage.frost_shield_hp == 100.0
			and mage.tenacity() == 0.0, "ward provides no melee mitigation, personal shield absorption or tenacity")
		game.mage_system.advance(5.0)
		check(mage.frost_remaining == 0.0 and is_equal_approx(mage.frost_ward_remaining, 5.0)
			and game.mage_system.ward_visuals.shells[1].visible, "ward survives the frost field and independently lasts ten seconds")
		game.paused = true
		game.simulate(1.0, [Vector2.ZERO, Vector2.ZERO])
		check(mage.frost_ward_remaining == 5.0, "pause freezes independent ward timer")
		game.paused = false
		game.mage_system.advance(5.0)
		check(mage.frost_ward_remaining == 0.0 and mage.frost_shield_hp == 0.0
			and not game.mage_system.ward_visuals.shells[1].visible, "ward expires at ten seconds and clears shield HP")
		for rank in range(4):
			if rank > 0: Skills.apply(ally, "giant_form")
			ally.giant_cooldown = 0.0
			game.activate_warrior_skill(0, 2)
			var duration: float = 3.0 + rank * 0.5
			ally.advance(duration - 0.1, Vector2.ZERO)
			check(is_equal_approx(ally.giant_remaining, 0.1) and ally.giant_cooldown == 12.0, "Giant rank %d lasts %.1fs and cooldown stays frozen while active" % [rank, duration])
			ally.advance(0.35, Vector2.ZERO)
			check(ally.giant_remaining == 0.0 and is_equal_approx(ally.giant_cooldown, 11.75), "Giant crossing frame counts only time after expiry")
		ally.giant_cooldown = 0.0
		game.activate_warrior_skill(0, 2)
		ally.hp = float(ally.stats.max_hp)
		ally.guard_shield = 0.0
		ally.invulnerability = 0.0
		ally.take_damage(100.0)
		check(is_equal_approx(ally.hp, float(ally.stats.max_hp) - 40.0), "Giant mitigates exactly sixty percent")
		Skills.apply(ally, "giant_refund")
		for hit in range(6):
			ally.invulnerability = 0.0
			ally.take_damage(1.0)
		check(ally.giant_cooldown == 9.0 and ally.giant_refund_total == 3.0, "original half-second refund and three-second cap remain effective on the future cooldown")
		game.free()
	print("FROST WARD RANGE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

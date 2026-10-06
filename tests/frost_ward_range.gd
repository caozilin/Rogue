extends SceneTree
## Only ward/range upgrade order, matching visuals and defensive boundaries.
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
		ally.position = mage.position - Vector2(200, 0)
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
			# Both endpoints stay outside the old 155 radius, crossing the new edge.
			var intercepted: bool = game.mage_system.intercept_bullet(mage.position + Vector2(expected + 60, 0), mage.position + Vector2(expected - 14, 0), bullet)
			check(activated and is_equal_approx(before, expected) and is_equal_approx(game.mage_system.frost_radius(mage), expected)
				and ally.cold_ward_protection and shell.visible and is_equal_approx(shell.scale.x, expected * 2.30 / 32.0)
				and intercepted and mage.frost_shield_hp == 125.0 and is_equal_approx(game.mage_system.ward_impacts.back().radius, expected),
				"%s then range tier %d: field, shell, ally protection and interception retain %.1f radius" % ["ward" if ward_first else "range", rank, expected])
			bullet.free()
			if not ward_first and rank == 1 and "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
				game.hud.refresh()
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png("res://artifacts/frost_ward_range.png") == OK, "expanded ward screenshot")
		var radius_before: float = game.mage_system.frost_radius(mage)
		check(game.activate_mage_skill(1, 3) and is_equal_approx(game.mage_system.frost_radius(mage), radius_before * 1.25), "ward also preserves possession range bonus")
		mage.end_possession()
		var bullet = game.EnemyBullet.new()
		bullet.damage = 1000.0
		check(game.mage_system.intercept_bullet(mage.position, mage.position, bullet) and mage.frost_remaining == 0.0
			and not ally.cold_ward_protection and not game.mage_system.ward_visuals.shells[1].visible
			and is_equal_approx(game.mage_system.ward_impacts.back().radius, radius_before), "breaking enlarged ward clears protection and keeps correct shatter radius")
		bullet.free()
		game.free()
	print("FROST WARD RANGE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

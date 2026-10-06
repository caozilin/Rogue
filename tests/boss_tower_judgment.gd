extends SceneTree
## Only Boss judgment threshold, actual damage and ownership.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.selected_classes = [0, 0]
	game.start_run()
	for enemy in game.enemies: enemy.free()
	game.enemies.clear()
	var boss = game.FinalBoss.new()
	boss.setup_boss(Vector2(700, 410), game.Balance.difficulty(180), 0)
	boss.hp = 100000.0
	boss.max_hp = boss.hp
	boss.state = "approach"
	game.world.add_child(boss)
	game.enemies.append(boss)
	game.players[1].skill_stats.tower_judgment = true
	game.mage_system.activate_tower(1)
	var tower = game.mage_system.towers.back()
	var fx = game.mage_system.lightning_effects
	for index in range(11):
		tower.shot_timer = 0.0
		tower.advance(0.0)
	check(fx.rulings.is_empty() and tower.judgment_count == 11 and fx.tags[str(boss.get_instance_id()) + "j"].total == 12,
		"eleven main strikes show 11/12 marks without triggering Boss judgment")
	tower.shot_timer = 0.0
	tower.advance(0.0)
	check(fx.rulings.size() == 1 and tower.judgment_count == 0 and fx.rulings[0].damage == tower.damage * 8.0,
		"twelfth strike queues x8 judgment and resets marks")
	var hp_before: float = boss.hp
	fx.advance(0.64)
	check(boss.hp == hp_before, "judgment retains its 0.65-second warning")
	fx.advance(0.02)
	check(is_equal_approx(hp_before - boss.hp, tower.damage * 8.0)
		and is_equal_approx(game.damage_breakdown[1].get("tower_judgment", 0.0), tower.damage * 8.0)
		and not game.damage_breakdown[0].has("tower_judgment"), "actual x8 impact credits the caster's judgment source")
	game.free()
	print("BOSS TOWER JUDGMENT: 4 checks, %d failures" % failures)
	quit(0 if failures == 0 else 1)

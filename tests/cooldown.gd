extends SceneTree
## Focused regression for suppression cooldown, without a long combat run.
const MainScene = preload("res://scenes/main.tscn")
const SkillUpgrades = preload("res://scripts/skill_upgrades.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	var player = game.players[0]
	game.activate_skill(0)
	player.advance(3.0, Vector2.ZERO)
	check(is_equal_approx(player.suppression_remaining, 1.0) and player.skill_cooldown == 10.0
		and not game.activate_skill(0), "active suppression does not consume cooldown or allow recast")
	player.advance(1.0, Vector2.ZERO)
	check(player.suppression_remaining == 0.0 and player.skill_cooldown == 10.0,
		"four seconds of suppression are followed by the full ten-second cooldown")
	player.advance(9.9, Vector2.ZERO)
	check(not game.activate_skill(0), "skill remains unavailable before all ten cooldown seconds pass")
	player.advance(0.1, Vector2.ZERO)
	check(game.activate_skill(0), "skill can cast again at fourteen seconds total")
	player.advance(4.25, Vector2.ZERO)
	check(is_equal_approx(player.skill_cooldown, 9.75), "crossing frame only counts time after suppression ends")
	player.configure_class(0)
	SkillUpgrades.apply(player, "sustain")
	game.activate_skill(0)
	player.advance(float(player.skill_stats.duration), Vector2.ZERO)
	check(is_equal_approx(player.skill_cooldown, 9.7), "upgraded duration also precedes the full upgraded cooldown")
	game.paused = true
	game.simulate(2.0, [Vector2.ZERO, Vector2.ZERO])
	check(is_equal_approx(player.skill_cooldown, 9.7), "pause freezes the new cooldown")
	game.paused = false
	player.configure_class(0)
	game.activate_skill(0)
	player.advance(1.0, Vector2.ZERO)
	player.invulnerability = 0.0
	player.take_damage(10000.0)
	check(player.downed and player.suppression_remaining == 0.0 and player.skill_cooldown == 10.0,
		"death interrupts suppression without skipping its full cooldown")
	game.free()
	print("COOLDOWN RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

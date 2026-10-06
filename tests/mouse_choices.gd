extends SceneTree
## Only the current input change: numeric shortcuts removed, UI callbacks retained.
const MainScene = preload("res://scenes/main.tscn")
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
	game.add_shared_xp(game.Balance.xp_required(1))
	var team_offers: Array = game.team_offers.duplicate(true)
	var p1_offers: Array = game.players[0].offers.duplicate(true)
	var p2_offers: Array = game.players[1].offers.duplicate(true)
	for code in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,
		KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = true
		game._unhandled_key_input(event)
	check(game.team_offers == team_offers and game.players[0].offers == p1_offers
		and game.players[1].offers == p2_offers and game.team_pending_upgrades == 1
		and game.players[0].pending_upgrades == 1 and game.players[1].pending_upgrades == 1,
		"number row and keypad cannot select any of the three upgrades")
	var clean := true
	for button in game.hud.team_buttons + game.hud.choice_buttons[0] + game.hud.choice_buttons[1]:
		clean = clean and not button.text.begins_with("[")
	check(clean and game.hud.footer.text.contains("鼠标左键"), "Buff cards and footer no longer advertise numeric shortcuts")
	game.hud.team_buttons[0].pressed.emit()
	check(game.team_pending_upgrades == 0 and game.simulation_speed() == 0.0, "team mouse button applies Buff and waits for personal choices")
	game.hud.choice_buttons[0][0].pressed.emit()
	check(game.players[0].pending_upgrades == 0 and game.players[1].pending_upgrades == 1
		and game.simulation_speed() == 0.0, "P1 mouse button only completes P1 choice")
	game.hud.choice_buttons[1][0].pressed.emit()
	check(game.simulation_speed() == 1.0 and not game.has_pending_upgrades(), "P2 mouse button finishes the choices and resumes combat")
	game.free()
	print("MOUSE CHOICES RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

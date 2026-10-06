extends SceneTree
## Only the merged vitality tiers, offer presentation and selection flow.
const Upgrades = preload("res://scripts/upgrades.gd")
const Skills = preload("res://scripts/skill_upgrades.gd")
const Player = preload("res://scripts/player.gd")
var game
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func snapshot(name: String) -> void:
	await process_frame
	await process_frame
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://artifacts/" + name) == OK, "save " + name)

func run() -> void:
	check(Upgrades.CATALOG.size() == 6 and Upgrades.definition("regen").is_empty(), "one combined vitality entry, no separate regeneration offer")
	for role in range(2):
		var player := Player.new()
		player.configure_class(role)
		for rank in range(1, 4):
			player.hp = 1.0
			check(Upgrades.apply(player, "vitality") and is_equal_approx(player.stats.max_hp, float(player.base_stats.max_hp) * (1.0 + rank * 0.5))
				and is_equal_approx(player.stats.regen, 0.02 + rank * 0.01) and is_equal_approx(player.hp, player.stats.max_hp), "both vitality attributes stack at tier %d for role %d" % [rank, role])
			player.hp = 1.0
			player.advance(1.0, Vector2.ZERO)
			check(is_equal_approx(player.hp, 1.0 + player.stats.max_hp * player.stats.regen), "actual healing uses both combined attributes")
		check(not Upgrades.apply(player, "vitality"), "combined vitality stops at three tiers")
		player.free()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	game.team_offers.assign([Upgrades.definition("vitality").duplicate(), Upgrades.definition("damage").duplicate(), Upgrades.definition("haste").duplicate()])
	for id in range(2):
		var player = game.players[id]
		var pool := Skills.ordinary_pool(player.role)
		player.offers.assign([pool[0].duplicate(), pool[1].duplicate(), pool[2].duplicate()])
		player.skill_ranks[pool[0].id] = 1
	game.hud.refresh()
	await snapshot("upgrade_cards.png")
	for card in game.hud.team_buttons + game.hud.choice_buttons[0] + game.hud.choice_buttons[1]:
		check(card.picture.texture != null and "[b]" in card.description.text, "all cards have an icon and bold level/effect")
	check("×2.0[/b]" in game.hud.choice_buttons[0][0].description.text, "tier-two effect is emphasized rather than the whole tier list")
	# Click the icon itself; its presentation children must not eat the click.
	var at: Vector2 = game.hud.team_buttons[0].picture.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
	check(not game.team_choosing and game.players[0].ranks.get("vitality", 0) == 1 and game.players[1].ranks.get("vitality", 0) == 1
		and is_equal_approx(game.players[0].stats.regen, 0.03) and is_equal_approx(game.players[1].stats.regen, 0.03), "clicking combined Buff icon grants both stats to both players")
	game.hud.choice_buttons[0][0].pressed.emit()
	game.hud.choice_buttons[1][0].pressed.emit()
	check(not game.has_pending_upgrades(), "all three selections resume play")
	for player in game.players:
		player.skill_choices = 2
		player.offers.clear()
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	for player in game.players:
		var pool := Skills.major_pool(player.role)
		player.offers.assign([pool[0].duplicate(), pool[1].duplicate(), pool[2].duplicate()])
	game.hud.refresh()
	await snapshot("upgrade_cards_major.png")
	check("解锁大技能" in game.hud.choice_buttons[0][0].description.text and game.hud.choice_buttons[1][0].picture.texture != null, "both careers show major icons and emphasized unlock effects")
	game.free()
	print("UPGRADE CARDS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

extends SceneTree
## Minimal current upgrade-flow checks. No long simulation.
const MainScene = preload("res://scenes/main.tscn")
const Upgrades = preload("res://scripts/upgrades.gd")
const SkillUpgrades = preload("res://scripts/skill_upgrades.gd")
var failures := 0
var checks := 0
var game

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_key_input(event)

func option(player, id: String) -> int:
	for i in range(player.offers.size()):
		if player.offers[i].id == id:
			return i
	return -1

func run() -> void:
	game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	game._drop_gem(game.players[1].position, 6)
	game._update_gems(0.1)
	check(game.shared_xp == 6 and game.players[0].xp == 6 and game.players[1].xp == 6, "either player contributes to one shared XP pool")
	game.add_shared_xp(game.Balance.xp_required(1) - 6)
	check(game.team_pending_upgrades == 1 and game.players[0].pending_upgrades == 1 and game.players[1].pending_upgrades == 1, "each team level grants one team Buff and one skill choice per player")
	check(game.hud.team_panel.visible and game.hud.choice_panels[0].visible and game.hud.choice_panels[1].visible
		and game.hud.team_panel.position.y + game.hud.team_panel.size.y < game.hud.choice_panels[0].position.y
		and game.hud.choice_panels[0].position.x + game.hud.choice_panels[0].size.x < game.hud.choice_panels[1].position.x,
		"three windows appear with team above and personal choices below, without overlap")
	var p1 = game.players[0]
	var p2 = game.players[1]
	var base1: Dictionary = p1.stats.duplicate(true)
	var base2: Dictionary = p2.stats.duplicate(true)
	var other_skill: Dictionary = p2.skill_stats.duplicate(true)
	key(KEY_1 + option(p1, "overclock"))
	check(is_equal_approx(p1.skill_stats.attack_rate, 2.2 * 1.18) and p2.skill_stats == other_skill and p1.stats == base1
		and not p1.choosing and game.hud.choice_panels[0].visible and game.simulation_speed() == 0,
		"P1 keyboard skill choice changes only P1 skill and keeps the waiting window")
	game.team_offers[0] = Upgrades.CATALOG[0].duplicate()
	key(KEY_4)
	check(is_equal_approx(p1.stats.damage, float(base1.damage) * 1.45) and is_equal_approx(p2.stats.damage, float(base2.damage) * 1.45)
		and p1.ranks == p2.ranks and game.team_pending_upgrades == 0 and game.simulation_speed() == 0,
		"one shared Buff affects both players, but combat waits for P2")
	var clock: float = game.elapsed
	game.simulate(1.0, [Vector2.RIGHT, Vector2.LEFT])
	key(KEY_7 + option(p2, "rupture"))
	check(game.elapsed == clock and is_equal_approx(p2.skill_stats.damage, 3.2 * 1.35)
		and game.simulation_speed() == 1 and not game.hud.team_panel.visible,
		"P2 keyboard choice completes all three selections and resumes combat")
	game.activate_skill(0)
	check(is_equal_approx(p1.attack_interval(), float(p1.stats.interval) / (2.2 * 1.18))
		and is_equal_approx(p1.skill_stats.extra_damage, 0.75 * 1.25), "Gunner attack uses upgraded suppression modifiers")
	game.activate_skill(1, Vector2.RIGHT)
	var enemy = game.Enemy.new()
	enemy.setup(p2.position + Vector2(60, 0), game.Balance.difficulty(0.0), false)
	enemy.hp = 200
	enemy.max_hp = 200
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	game._mark_dash(1, p2.position, p2.position + Vector2(100, 0))
	game.activate_skill(1)
	check(is_equal_approx(200.0 - enemy.hp, float(p2.stats.damage) * 3.2 * 1.35), "Raider detonation uses both shared damage and individual skill enhancement")
	game.add_shared_xp(game.Balance.xp_required(game.team_level) + game.Balance.xp_required(game.team_level + 1))
	game.paused = true
	check(not game.choose_team_upgrade(0) and not game.choose_upgrade(0, 0), "ESC pause blocks all three choices")
	game.paused = false
	game.choose_upgrade(0, 0)
	game.choose_upgrade(0, 0)
	game.choose_upgrade(1, 0)
	game.choose_upgrade(1, 0)
	check(game.simulation_speed() == 0 and game.team_pending_upgrades == 2, "multiple levels retain both team choices after personal choices finish")
	game.choose_team_upgrade(0)
	game.choose_team_upgrade(0)
	check(game.simulation_speed() == 1 and not game.has_pending_upgrades(), "multiple levels finish without losing any choice")
	p2.downed = true
	p2.hp = 0
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	game.team_offers[0] = Upgrades.CATALOG[6].duplicate()
	game.choose_team_upgrade(0)
	game.choose_upgrade(0, 0)
	game.choose_upgrade(1, 0)
	check(p2.downed and p2.hp == 0 and game.simulation_speed() == 1, "downed player can upgrade; shared healing does not auto-revive")
	var both_valid := true
	for role in range(2):
		var player = game.Player.new()
		player.configure_class(role)
		var before: Dictionary = player.skill_stats.duplicate(true)
		var basic: Dictionary = player.stats.duplicate(true)
		for offer in SkillUpgrades.CATALOG[role]:
			SkillUpgrades.apply(player, offer.id)
		both_valid = both_valid and player.skill_stats != before and player.stats == basic and player.skill_ranks.size() == 3
		if role == 0:
			both_valid = both_valid and player.skill_stats.duration > 4.0 and player.skill_stats.cooldown < 10.0 and player.skill_stats.range > 1.35
		else:
			both_valid = both_valid and player.skill_stats.distance > 230.0 and player.skill_stats.return_window > 1.2 and player.skill_stats.dash_invulnerability > 0.28 and player.skill_stats.cooldown < 6.0
		player.free()
	check(both_valid, "each career has three effective personal enhancement directions")
	game.free()
	print("MINIMAL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

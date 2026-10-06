extends SceneTree
## Focused three-tier Buff and percentage-healing check; no long combat simulation.
const Player = preload("res://scripts/player.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
const SkillUpgrades = preload("res://scripts/skill_upgrades.gd")
const MainScene = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0

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
	var ranged := Player.new()
	var melee := Player.new()
	ranged.configure_class(0)
	melee.configure_class(1)
	check(is_equal_approx(melee.stats.speed, 196.0) and is_equal_approx(ranged.stats.speed, 156.8)
		and ranged.stats.crit == 0.0 and melee.stats.crit == 0.0 and ranged.stats.regen == 0.02,
		"starting speeds are 196 and 156.8, crit is zero and regeneration is 2 percent")
	var expected := [
		{"damage": 21.0, "interval": 0.62 / 1.5, "projectiles": 2, "pierce": 1, "speed": 156.8, "max_hp": 150.0, "regen": 0.03},
		{"damage": 28.0, "interval": 0.31, "projectiles": 3, "pierce": 2, "speed": 156.8, "max_hp": 200.0, "regen": 0.04},
		{"damage": 35.0, "interval": 0.248, "projectiles": 4, "pierce": 3, "speed": 156.8, "max_hp": 250.0, "regen": 0.05}
	]
	for tier in range(3):
		ranged.hp = 1.0
		for offer in Upgrades.CATALOG:
			Upgrades.apply(ranged, offer.id)
		var valid := is_equal_approx(ranged.hp, float(expected[tier].max_hp))
		for attribute in expected[tier]:
			valid = valid and is_equal_approx(float(ranged.stats[attribute]), float(expected[tier][attribute]))
		check(valid, "all five Buffs reach exact total tier %d values; base movement is unchanged" % (tier + 1))
	var before: Dictionary = ranged.stats.duplicate(true)
	var blocked := true
	for offer in Upgrades.CATALOG:
		blocked = blocked and not Upgrades.apply(ranged, offer.id) and ranged.ranks[offer.id] == 3
	check(blocked and ranged.stats == before and Upgrades.roll(ranged.rng, ranged.ranks).is_empty(),
		"fourth selections are blocked and maxed Buffs leave the pool")
	ranged.hp = 100.0
	ranged.advance(1.0, Vector2.ZERO)
	check(is_equal_approx(ranged.hp, 112.5), "tier-three regeneration heals 5 percent of 250 HP each second")
	melee.hp = 10.0
	Upgrades.apply(melee, "vitality")
	var interval: float = melee.stats.interval
	var speed_blocked := not Upgrades.apply(melee, "speed")
	melee.hp = 20.0
	melee.advance(1.0, Vector2.ZERO)
	check(is_equal_approx(melee.hp, 24.95) and melee.stats.interval == interval and speed_blocked,
		"merged vitality heals 3 percent of 165 HP; removed speed Buff cannot apply")
	melee.downed = true
	melee.hp = 0.0
	Upgrades.apply(melee, "vitality")
	melee.advance(1.0, Vector2.ZERO)
	check(melee.downed and melee.hp == 0.0, "vitality and percent regeneration do not revive a downed player")
	var skills_capped := true
	for role in range(2):
		var player := Player.new()
		player.configure_class(role)
		for offer in SkillUpgrades.CATALOG[role]:
			for repeat in range(3):
				skills_capped = skills_capped and SkillUpgrades.apply(player, offer.id)
			skills_capped = skills_capped and not SkillUpgrades.apply(player, offer.id)
		skills_capped = skills_capped and SkillUpgrades.roll(player.rng, role, player.skill_ranks).is_empty()
		player.free()
	check(skills_capped, "each personal skill entry also caps at three selections")
	var removed := true
	for offer in Upgrades.CATALOG:
		removed = removed and offer.id not in ["range", "crit", "regen", "speed"]
	check(removed and Upgrades.CATALOG.size() == 5, "range, crit, separate regeneration and speed upgrades removed")
	var game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	for node in game.enemies:
		node.free()
	game.enemies.clear()
	for repeat in range(3):
		Upgrades.apply(game.players[0], "pierce")
	for index in range(5):
		var enemy = game.Enemy.new()
		enemy.setup(game.players[0].position + Vector2(50 * (index + 1), 0), game.Balance.difficulty(0.0), false)
		enemy.hp = 10.0
		enemy.max_hp = 10.0
		game.world.add_child(enemy)
		game.enemies.append(enemy)
	game._spawn_bullet(game.players[0], Vector2.RIGHT)
	game._update_projectiles(0.5)
	check(game.players[0].kills == 4 and game.enemies.size() == 1 and game.projectiles.is_empty(),
		"one tier-three projectile hits four monsters total and leaves the fifth unharmed")
	for player in game.players:
		for offer in Upgrades.CATALOG:
			player.ranks[offer.id] = 2 if offer.id == "damage" else 3
		for offer in SkillUpgrades.CATALOG[player.role]:
			player.skill_ranks[offer.id] = 3
	game.add_shared_xp(game.Balance.xp_required(1))
	check(game.team_offers.size() == 1 and game.hud.team_buttons[0].visible and not game.hud.team_buttons[1].visible
		and game.players[0].pending_upgrades == 0 and game.players[1].pending_upgrades == 0
		and not game.choose_team_upgrade(1), "one remaining Buff displays safely while capped skill windows skip choices")
	game.choose_team_upgrade(0)
	game.add_shared_xp(game.Balance.xp_required(game.team_level))
	check(game.simulation_speed() == 1.0 and not game.has_pending_upgrades() and not game.hud.team_panel.visible,
		"future levels do not freeze or open empty panels when all entries are maxed")
	game.free()
	ranged.free()
	melee.free()
	print("TIERS RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

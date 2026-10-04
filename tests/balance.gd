extends SceneTree
## Verify growth, useful secondary effects and safe limits independently of combat RNG.

const Player = preload("res://scripts/player.gd")
const Balance = preload("res://scripts/balance.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
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
		push_error("TEST FAILED: " + message)

func run() -> void:
	for level in [1, 5, 10, 20]:
		var previous := int(12.0 + 8.0 * pow(float(level - 1), 1.12))
		check(Balance.xp_required(level) >= previous * 3, "XP costs substantially higher at level %d" % level)
	var primary := {"damage": "damage", "haste": "interval", "multishot": "projectile_power",
		"range": "range", "pierce": "pierce_power", "crit": "crit",
		"vitality": "max_hp", "speed": "speed", "regen": "regen"}
	for id in primary:
		var player := Player.new()
		var key: String = primary[id]
		var base: float = float(player.stats[key])
		Upgrades.apply(player, id)
		var first: float = float(player.stats[key])
		Upgrades.apply(player, id)
		var second: float = float(player.stats[key])
		check(not is_equal_approx(first, base) and is_equal_approx(first / base, second / first),
			"%s repeats by multiplication rather than fixed addition" % id)
		player.free()
	var player := Player.new()
	var shots: Array[int] = [1]
	for index in range(5):
		Upgrades.apply(player, "multishot")
		shots.append(player.stats.projectiles)
	check(shots == [1, 2, 3, 5, 8, 12], "projectile count follows exponential capacity with rounding")
	player.free()
	player = Player.new()
	var piercing: Array[int] = [0]
	for index in range(4):
		Upgrades.apply(player, "pierce")
		piercing.append(player.stats.pierce)
	check(piercing == [0, 1, 2, 4, 8], "zero-start penetration grows via exponential hit capacity")
	player.free()
	player = Player.new()
	Upgrades.apply(player, "range")
	check(player.stats.projectile_speed > 570 and player.stats.damage > 14 and player.stats.range > 480,
		"range also improves projectile speed and damage")
	Upgrades.apply(player, "speed")
	check(player.stats.interval < 0.62 and player.stats.speed > 225, "movement upgrade also improves attack rate")
	var regen: float = player.stats.regen
	player.hp = 10
	Upgrades.apply(player, "vitality")
	check(player.stats.max_hp > 100 and player.hp > 10, "vitality multiplies HP and immediately heals")
	var health: float = player.hp
	Upgrades.apply(player, "regen")
	check(player.hp > health and player.stats.regen > regen, "regeneration improves sustain and immediately heals")
	for index in range(30):
		for offer in Upgrades.CATALOG:
			if Upgrades.available(offer.id, player.stats):
				Upgrades.apply(player, offer.id)
	check(player.stats.interval >= Balance.UPGRADE_LIMITS.interval and player.stats.projectiles <= 12
		and player.stats.pierce <= 8 and player.stats.crit <= 1.0 and player.stats.speed <= 420
		and player.stats.range <= 1200 and player.stats.regen <= 15,
		"exponential growth respects combat and performance limits")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var offers := Upgrades.roll(rng, player.stats)
	var ids: Array[String] = []
	for offer in offers:
		ids.append(offer.id)
	check(offers.size() == 3 and ids.has("damage") and ids.has("crit") and ids.has("vitality"),
		"capped utilities leave three useful repeatable choices")
	var critical_damage: float = player.stats.crit_multiplier
	Upgrades.apply(player, "crit")
	check(player.stats.crit == 1.0 and player.stats.crit_multiplier > critical_damage,
		"critical damage keeps growing after chance reaches 100 percent")
	player.free()
	var game = MainScene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	Upgrades.apply(game.players[0], "range")
	var enemy = game.Enemy.new()
	enemy.setup(game.players[0].position + Vector2(200, 0), Balance.difficulty(0), false)
	game.world.add_child(enemy)
	game.enemies.append(enemy)
	game._fire(game.players[0])
	check(not game.projectiles.is_empty() and is_equal_approx(game.projectiles[0].velocity.length(), game.players[0].stats.projectile_speed),
		"projectile speed upgrade is used by actual combat")
	game.free()
	print("BALANCE RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

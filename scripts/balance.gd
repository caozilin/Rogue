extends RefCounted
## All basic tuning lives here. No art, plugins, autoloads or external dependencies.

const Barrage = preload("res://scripts/barrage.gd")

const ARENA := Rect2(32, 112, 1216, 590)
const PLAYER_RADIUS := 16.0
const REVIVE_RADIUS := 66.0
const REVIVE_SECONDS := 3.0
const PICKUP_RADIUS := 115.0
const MAX_ENEMIES := 56
const MAX_PROJECTILES := 320
const MAX_GEMS := 220
const MAX_RANGED_ENEMIES := 6
const MAX_ENEMY_BULLETS := 180
const MAX_ENEMY_HAZARDS := 12
const FIRST_WAVE_SECONDS := 16.0
const WAVE_INTERVAL := 30.0
const FIRST_BOSS_SECONDS := 60.0
const BOSS_INTERVAL := 60.0
const BOSS_HEALTH := {"spore": 5000.0, "thorn": 13000.0, "melee": 35000.0, "artillery": 38000.0}
# Full-build challenge health, indexed by the number of Mages (0 / 1 / 2).
const BREAKTHROUGH_HEALTH := {
	"melee": [60000.0, 95000.0, 120000.0],
	"artillery": [65000.0, 105000.0, 135000.0],
	"milk": [65000.0, 100000.0, 130000.0],
	"frog": [80000.0, 125000.0, 160000.0]
}
const BOSS_CROWD_MULTIPLIER := 0.6
const FINAL_BOSS_SECONDS := 180.0
const MELEE_BASE_SPEED := 245.0 * 0.8
const RANGED_BASE_SPEED := MELEE_BASE_SPEED * 0.8
const UPGRADE_LIMITS := {"interval": 0.10, "projectiles": 4, "range": 1200.0,
	"pierce": 3, "crit": 0.0, "speed": MELEE_BASE_SPEED * 2.5, "regen": 0.05}
const PLAYER_COLORS := [Color("54d9ee"), Color("ffbb66")]

static func starting_stats() -> Dictionary:
	return {"max_hp": 100.0, "speed": RANGED_BASE_SPEED, "damage": 14.0,
		"interval": 0.62, "projectiles": 1, "range": 480.0,
		"pierce": 0, "crit": 0.0, "crit_multiplier": 2.0,
		"regen": 0.02, "projectile_speed": 570.0} # Regen is a fraction of max HP per second.

static func xp_required(level: int) -> int:
	# About three upgrades per minute at normal kill/collection efficiency.
	# Gentle growth offsets the extra rewards from later enemy types and minibosses.
	return 240 + 30 * (level - 1)

static func boss_damage(seconds: float) -> float:
	return 90.0 + seconds / 20.0

static func difficulty(seconds: float) -> Dictionary:
	return {"health": 36.0 * (1.0 + seconds / 95.0),
		"speed": minf(175.0, 112.0 + seconds * 0.12),
		"damage": 22.0 + seconds / 60.0,
		"elite_damage": 36.0 + seconds / 30.0,
		"spawn_rate": minf(3.0, 1.8 + seconds / 180.0),
		"xp": 8, "seconds": seconds}

static func enemy_kind(seconds: float, serial: int) -> String:
	var ranged := Barrage.spawn_kind(seconds, serial)
	if not ranged.is_empty():
		return ranged
	var elite_every := maxi(10, 18 - int(seconds / 60.0))
	if seconds >= 18.0 and serial % elite_every == 0:
		return "elite"
	if seconds >= 120.0 and serial % 7 == 0:
		return "charger"
	if seconds >= 60.0 and serial % 9 == 0:
		return "brute"
	if serial % (4 if seconds >= 90.0 else 5) == 0:
		return "runner"
	return "normal"

static func wave_size(seconds: float) -> int:
	return mini(5, 3 + int(seconds / 70.0))

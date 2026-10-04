extends RefCounted
## All basic tuning lives here. No art, plugins, autoloads or external dependencies.

const ARENA := Rect2(32, 112, 1216, 590)
const PLAYER_RADIUS := 16.0
const REVIVE_RADIUS := 66.0
const REVIVE_SECONDS := 3.0
const PICKUP_RADIUS := 115.0
const MAX_ENEMIES := 160
const MAX_PROJECTILES := 320
const MAX_GEMS := 220
const UPGRADE_LIMITS := {"interval": 0.10, "projectiles": 12, "range": 1200.0,
	"pierce": 8, "crit": 1.0, "speed": 420.0, "regen": 15.0}
const PLAYER_COLORS := [Color("54d9ee"), Color("ffbb66")]

static func starting_stats() -> Dictionary:
	return {"max_hp": 100.0, "speed": 225.0, "damage": 14.0,
		"interval": 0.62, "projectiles": 1, "range": 480.0,
		"pierce": 0, "crit": 0.05, "crit_multiplier": 2.0,
		"regen": 0.6, "projectile_speed": 570.0,
		"projectile_power": 1.0, "pierce_power": 1.0}

static func xp_required(level: int) -> int:
	# Both players feed one pool, so double the former individual threshold
	# to preserve the reduced upgrade frequency. One level grants BOTH a choice.
	return int(96.0 + 64.0 * pow(float(level - 1), 1.35))

static func difficulty(seconds: float) -> Dictionary:
	return {"health": 20.0 * (1.0 + seconds / 95.0),
		"speed": minf(145.0, 64.0 + seconds * 0.115),
		"damage": 9.0 + seconds / 50.0,
		"spawn_rate": minf(8.0, 1.5 + seconds / 85.0),
		"xp": 6 + int(seconds / 120.0)}

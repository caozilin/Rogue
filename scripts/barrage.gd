extends RefCounted
## Ranged family: all tuning and unlock times live in one place.

const TYPES := {
	"fan": {"name": "散射孢子", "unlock": 22.0, "every": 11, "health": 0.9,
		"speed": 0.85, "radius": 15.0, "distance": 260.0, "range": 470.0,
		"cooldown": 2.8, "windup": 0.65, "bullet_speed": 190.0, "damage": 1.0, "color": Color("ff866e")},
	"ring": {"name": "环射花妖", "unlock": 50.0, "every": 17, "health": 1.5,
		"speed": 0.65, "radius": 19.0, "distance": 200.0, "range": 420.0,
		"cooldown": 4.2, "windup": 0.95, "bullet_speed": 155.0, "damage": 1.0, "color": Color("f675d5")},
	"sweep": {"name": "扫射蜂卫", "unlock": 95.0, "every": 19, "health": 1.25,
		"speed": 0.8, "radius": 16.0, "distance": 290.0, "range": 510.0,
		"cooldown": 3.8, "windup": 0.85, "bullet_speed": 210.0, "damage": 1.0, "color": Color("ff596e")},
	"mortar": {"name": "落点炮手", "unlock": 150.0, "every": 23, "health": 1.8,
		"speed": 0.55, "radius": 20.0, "distance": 350.0, "range": 650.0,
		"cooldown": 4.8, "windup": 0.8, "bullet_speed": 0.0, "damage": 2.0, "color": Color("ffdb70")},
}

static func is_ranged(kind: String) -> bool:
	return TYPES.has(kind)

static func spawn_kind(seconds: float, serial: int) -> String:
	# Check late types first so their multiples cannot be swallowed by early types.
	for kind in ["mortar", "sweep", "ring", "fan"]:
		var config: Dictionary = TYPES[kind]
		if seconds >= float(config.unlock) and serial % int(config.every) == 0:
			return kind
	return ""

static func fan_angles(seconds: float) -> Array[float]:
	var angles: Array[float] = [-0.36, 0.0, 0.36]
	if seconds >= 180.0:
		angles = [-0.48, -0.24, 0.0, 0.24, 0.48]
	return angles

static func ring_angles(seconds: float) -> Array[float]:
	var count := 16 if seconds >= 240.0 else 12
	var angles: Array[float] = []
	# A visible opening faces the locked target direction, even in the late pattern.
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		if absf(wrapf(angle, -PI, PI)) <= 0.55:
			continue
		angles.append(angle)
	return angles

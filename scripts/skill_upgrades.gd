extends RefCounted
## Three repeatable directions per career. Utility caps prevent permanent invulnerability;
## damage still grows after caps, so each card remains useful.

const Classes = preload("res://scripts/classes.gd")
const CATALOG := [
	[
		{"id": "overclock", "title": "火力超频", "detail": "压制攻速 ×1.18 / 额外弹伤害 ×1.25", "note": "压制攻速倍率上限 4.4；额外弹伤害持续叠加"},
		{"id": "sustain", "title": "持久压制", "detail": "持续时间 ×1.16 / 冷却 ×0.97 / 额外弹伤害 ×1.10", "note": "持续时间上限 7 秒；结束后冷却至少 8 秒"},
		{"id": "mobile_sight", "title": "机动瞄准", "detail": "压制射程 ×1.16 / 移速修正 ×1.06 / 额外弹伤害 ×1.12", "note": "射程倍率上限 2.2；移速修正最多恢复到正常速度"}
	],
	[
		{"id": "rupture", "title": "裂解标记", "detail": "返程引爆伤害 ×1.35", "note": "只强化标记引爆，连续选择按倍率叠乘"},
		{"id": "long_raid", "title": "长距折返", "detail": "突进距离 ×1.18 / 返回窗口 ×1.12 / 引爆伤害 ×1.10", "note": "距离上限 420；返回窗口上限 2.2 秒"},
		{"id": "evasion", "title": "闪避节奏", "detail": "无敌时间 ×1.16 / 冷却 ×0.94 / 引爆伤害 ×1.10", "note": "突进/返回无敌上限 0.55/0.40 秒；冷却至少 3.8 秒"}
	]
]

static func starting_stats(role: int) -> Dictionary:
	if role == Classes.GUNNER:
		return {"duration": Classes.SUPPRESSION_DURATION, "cooldown": Classes.SUPPRESSION_COOLDOWN,
			"attack_rate": Classes.SUPPRESSION_ATTACK_RATE, "range": Classes.SUPPRESSION_RANGE,
			"move_speed": Classes.SUPPRESSION_MOVE_SPEED, "extra_damage": Classes.EXTRA_SHOT_DAMAGE}
	return {"distance": Classes.DASH_DISTANCE, "return_window": Classes.RETURN_WINDOW,
		"dash_invulnerability": Classes.DASH_INVULNERABILITY, "return_invulnerability": Classes.RETURN_INVULNERABILITY,
		"cooldown": Classes.RAID_COOLDOWN, "damage": Classes.DETONATION_DAMAGE}

static func roll(rng: RandomNumberGenerator, role: int) -> Array[Dictionary]:
	var pool: Array = CATALOG[role].duplicate(true)
	var result: Array[Dictionary] = []
	while not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		result.append(pool[index])
		pool.remove_at(index)
	return result

static func apply(player, id: String) -> void:
	var s: Dictionary = player.skill_stats
	match id:
		"overclock":
			s.attack_rate = minf(4.4, s.attack_rate * 1.18)
			s.extra_damage *= 1.25
		"sustain":
			s.duration = minf(7.0, s.duration * 1.16)
			s.cooldown = maxf(8.0, s.cooldown * 0.97)
			s.extra_damage *= 1.10
		"mobile_sight":
			s.range = minf(2.2, s.range * 1.16)
			s.move_speed = minf(1.0, s.move_speed * 1.06)
			s.extra_damage *= 1.12
		"rupture": s.damage *= 1.35
		"long_raid":
			s.distance = minf(420.0, s.distance * 1.18)
			s.return_window = minf(2.2, s.return_window * 1.12)
			s.damage *= 1.10
		"evasion":
			s.dash_invulnerability = minf(0.55, s.dash_invulnerability * 1.16)
			s.return_invulnerability = minf(0.40, s.return_invulnerability * 1.16)
			s.cooldown = maxf(3.8, s.cooldown * 0.94)
			s.damage *= 1.10
	player.skill_ranks[id] = int(player.skill_ranks.get(id, 0)) + 1

extends RefCounted
## Repeatable team Buffs. The same selected effect applies to both players.

const Balance = preload("res://scripts/balance.gd")

const CATALOG := [
	{"id": "damage", "title": "重型弹头", "detail": "伤害 ×1.45", "note": "连续选择按 1.45 的幂增长"},
	{"id": "haste", "title": "快速供弹", "detail": "攻速 ×1.40（间隔 ÷1.40）", "note": "与伤害相乘，增加射击和暴击机会"},
	{"id": "multishot", "title": "散射弹仓", "detail": "射弹容量 ×1.65", "note": "1→2→3→5→8→12 发；实际数量向上取整"},
	{"id": "range", "title": "远程瞄准", "detail": "射程 ×1.28 / 弹速 ×1.15 / 伤害 ×1.12", "note": "更远、更快，也能直接增加输出"},
	{"id": "pierce", "title": "贯穿弹头", "detail": "命中容量 ×1.70", "note": "额外穿透 0→1→2→4→8 人，向上取整"},
	{"id": "crit", "title": "精准射击", "detail": "暴击率 ×2.50 / 暴击伤害 ×1.20", "note": "5%→12.5%→31.25%→78.125%→100%"},
	{"id": "vitality", "title": "生命强化", "detail": "生命上限 ×1.40 / 恢复新上限的 40%", "note": "血量越高，本次扩容和恢复越明显"},
	{"id": "speed", "title": "轻盈步伐", "detail": "移速 ×1.16 / 攻速 ×1.08", "note": "增强走位，同时改善输出"},
	{"id": "regen", "title": "持续恢复", "detail": "恢复速度 ×2.50 / 恢复生命上限的 12%", "note": "每秒 0.6→1.5→3.75→9.375→15，立即治疗"},
]

static func available(id: String, s: Dictionary) -> bool:
	match id:
		"haste": return float(s.interval) > float(Balance.UPGRADE_LIMITS.interval) + 0.00001
		"multishot": return int(s.projectiles) < int(Balance.UPGRADE_LIMITS.projectiles)
		"range": return float(s.range) < float(Balance.UPGRADE_LIMITS.range)
		"pierce": return int(s.pierce) < int(Balance.UPGRADE_LIMITS.pierce)
		"speed": return float(s.speed) < float(Balance.UPGRADE_LIMITS.speed)
		"regen": return float(s.regen) < float(Balance.UPGRADE_LIMITS.regen)
	return true

static func roll(rng: RandomNumberGenerator, stats: Dictionary, ally_stats: Dictionary = {}) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for item in CATALOG:
		# Keep capped upgrades out of future rolls.
		if not available(str(item.id), stats) and (ally_stats.is_empty() or not available(str(item.id), ally_stats)):
			continue
		var option: Dictionary = item.duplicate()
		if item.id == "crit" and float(stats.crit) >= 1.0 and (ally_stats.is_empty() or float(ally_stats.crit) >= 1.0):
			option.detail = "暴击伤害 ×1.20（暴击率已满）"
			option.note = "暴击率已到 100%，暴击伤害继续指数增长"
		pool.append(option)
	var result: Array[Dictionary] = []
	# Damage, vitality and critical damage always remain meaningful and repeatable.
	for index in range(3):
		var pick := rng.randi_range(0, pool.size() - 1)
		result.append(pool[pick].duplicate())
		pool.remove_at(pick)
	return result

static func apply(player, id: String) -> void:
	var s: Dictionary = player.stats
	match id:
		"damage": s.damage *= 1.45
		"haste": s.interval = maxf(Balance.UPGRADE_LIMITS.interval, s.interval / 1.40)
		"multishot":
			s.projectile_power = minf(Balance.UPGRADE_LIMITS.projectiles, s.projectile_power * 1.65)
			s.projectiles = mini(Balance.UPGRADE_LIMITS.projectiles, int(ceil(s.projectile_power - 0.000001)))
		"range":
			s.range = minf(Balance.UPGRADE_LIMITS.range, s.range * 1.28)
			s.projectile_speed *= 1.15
			s.damage *= 1.12
		"pierce":
			s.pierce_power = minf(Balance.UPGRADE_LIMITS.pierce + 1, s.pierce_power * 1.70)
			s.pierce = mini(Balance.UPGRADE_LIMITS.pierce, int(ceil(s.pierce_power - 0.000001)) - 1)
		"crit":
			s.crit = minf(Balance.UPGRADE_LIMITS.crit, s.crit * 2.50)
			s.crit_multiplier *= 1.20
		"vitality":
			s.max_hp *= 1.40
			if not player.downed:
				player.hp = minf(s.max_hp, player.hp + s.max_hp * 0.40)
		"speed":
			s.speed = minf(Balance.UPGRADE_LIMITS.speed, s.speed * 1.16)
			s.interval = maxf(Balance.UPGRADE_LIMITS.interval, s.interval / 1.08)
		"regen":
			s.regen = minf(Balance.UPGRADE_LIMITS.regen, s.regen * 2.50)
			if not player.downed:
				player.hp = minf(s.max_hp, player.hp + s.max_hp * 0.12)
	player.ranks[id] = int(player.ranks.get(id, 0)) + 1

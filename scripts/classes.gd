extends RefCounted
## Roles and active skill tuning. Buffs modify base stats, skills only add temporary modifiers.

const GUNNER := 0
const RAIDER := 1
const NAMES := ["压制射手", "折返游侠"]
const SKILL_NAMES := ["火力压制", "折返突袭"]
const SUPPRESSION_DURATION := 4.0
const SUPPRESSION_COOLDOWN := 10.0
const SUPPRESSION_ATTACK_RATE := 2.2
const SUPPRESSION_RANGE := 1.35
const SUPPRESSION_MOVE_SPEED := 0.85
const EXTRA_SHOT_DAMAGE := 0.75
const DASH_DISTANCE := 230.0
const DASH_DURATION := 0.18
const DASH_INVULNERABILITY := 0.28
const RETURN_WINDOW := 1.2
const RETURN_INVULNERABILITY := 0.20
const RAID_COOLDOWN := 6.0
const DETONATION_DAMAGE := 3.2

static func starting_stats(role: int) -> Dictionary:
	var stats := preload("res://scripts/balance.gd").starting_stats()
	if role == RAIDER:
		stats.max_hp = 110.0
		stats.speed = 245.0
		stats.damage = 17.0
		stats.interval = 0.57
		stats.range = 255.0
	return stats

static func description(role: int) -> String:
	if role == GUNNER:
		return "中远程 · 操作简单\n火力压制：持续 4 秒，攻速 ×2.2、射程 ×1.35\n额外射击另一名目标，移速 ×0.85；结束后冷却 10 秒"
	return "中近程 · 高操作上限\n折返突袭：沿移动方向突进 230，短暂无敌并标记\n1.2 秒内再按返回，引爆标记（伤害 ×3.2）；冷却 6 秒"

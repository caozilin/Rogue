extends RefCounted
## Roles and active skill tuning. Buffs modify base stats, skills only add temporary modifiers.

const MAGE := 0
const GUNNER := MAGE # Compatibility for existing suppression upgrades and tests.
const RAIDER := 1
const NAMES := ["法师", "战士"]
const SKILL_NAMES := ["雷楞塔", "突进斩"]
const TOWER_DURATION := 10.0
const TOWER_RECHARGE := 15.0
const TOWER_RELEASE_COOLDOWN := 2.0
const TOWER_MAX_CHARGES := 2
const SUPPRESSION_DURATION := 4.0
const SUPPRESSION_COOLDOWN := 10.0
const SUPPRESSION_ATTACK_RATE := 2.2
const SUPPRESSION_RANGE := 1.35
const SUPPRESSION_MOVE_SPEED := 0.85
const EXTRA_SHOT_DAMAGE := 0.75
const DASH_DISTANCE := 230.0
const DASH_DURATION := 0.18
const DASH_INVULNERABILITY := 0.28
const DASH_HIT_RADIUS := 72.0 # 144 px wide swept capsule, plus enemy radius.
const RETURN_WINDOW := 1.2
const RETURN_INVULNERABILITY := 0.20
const RAID_COOLDOWN := 6.0
const DETONATION_DAMAGE := 3.2
const WARCRY_DURATION := 4.0
const WARCRY_COOLDOWN := 20.0
const GIANT_DURATION := 4.0
const GIANT_COOLDOWN := 15.0
const GIANT_SPEED_BONUS := 1.0 # Added to the global speed multiplier.
const GIANT_SIZE := 2.0
const GIANT_DAMAGE := 2.0
const GIANT_DAMAGE_REDUCTION := 0.8
const GIANT_KNOCKBACK := 120.0
const RESCUE_DURATION := 3.0
const RESCUE_COOLDOWN := 20.0

static func starting_stats(role: int) -> Dictionary:
	var stats := preload("res://scripts/balance.gd").starting_stats()
	if role == RAIDER:
		stats.max_hp = 110.0
		stats.speed = preload("res://scripts/balance.gd").MELEE_BASE_SPEED
		stats.damage = 17.0
		stats.interval = 0.57
		stats.range = 255.0
	return stats

static func description(role: int) -> String:
	if role == GUNNER:
		return "[Q] 大火球：优先最高等级，多段伤害，CD 15秒\n[E] 冰霜领域：减速、减攻速，持续 5秒，CD 15秒\n[R] 附身：310范围内附到队友头顶，持续 5秒\n伤害 +35%、范围 +25%、CD恢复 +25%\n[空格] 雷楞塔：原地召唤，持续 10秒，全屏索敌\n默认电击最近单体；储存 2次，充能 15秒，释放间隔 2秒"
	return "右键朝鼠标突进 230，无敌 0.28 秒\n突进伤害 ×3.2，初始无击退，冷却 6 秒\n[1] 战吼：全图嘲讽 4 秒，冷却 20 秒\n[2] 巨大化撞击：体型 ×2、减伤 80%\n撞击伤害 ×2 并击退；持续 4 秒，CD 15 秒\n[3] 救援：携带队友；强化冲刺与撞击可选"

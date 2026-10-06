extends RefCounted
## Team Buffs have three total tiers relative to each career's starting stats.
const MAX_RANK := 3
const MULTIPLIERS := [1.0, 1.5, 2.0, 2.5]
const COUNTS := [1, 2, 3, 4]
const REGEN_RATES := [0.02, 0.03, 0.04, 0.05]
const CATALOG := [
	{"id": "damage", "title": "重型弹头", "detail": "普攻/技能伤害：基础 ×1.5 / ×2 / ×2.5", "note": "同时提升普攻、突进和雷楞塔伤害；与个人技能强化相乘，最多三级"},
	{"id": "haste", "title": "快速供弹", "detail": "攻速：基础 ×1.5 / ×2 / ×2.5", "note": "攻击间隔等于职业初始间隔除以本级倍率"},
	{"id": "multishot", "title": "散射弹仓", "detail": "每轮射弹：2 / 3 / 4 发", "note": "直接设置数量，不再使用小数容量"},
	{"id": "pierce", "title": "贯穿弹头", "detail": "每颗子弹最多命中：2 / 3 / 4 个怪物", "note": "初始命中 1 个怪物，强化后总命中数为 2、3、4"},
	{"id": "vitality", "title": "生命恢复", "detail": "生命上限 ×1.5 / ×2 / ×2.5；每秒回血 3% / 4% / 5%", "note": "每级同时增加基础生命上限 50% 和每秒回血 1 个百分点，数值累加；存活玩家立即满血，倒地玩家仍需复活"},
]

static func definition(id: String) -> Dictionary:
	for item in CATALOG:
		if item.id == id:
			return item
	return {}

static func available(id: String, ranks: Dictionary) -> bool:
	return not definition(id).is_empty() and int(ranks.get(id, 0)) < MAX_RANK

static func has_available(ranks: Dictionary) -> bool:
	for item in CATALOG:
		if available(item.id, ranks):
			return true
	return false

static func roll(rng: RandomNumberGenerator, ranks: Dictionary = {}) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for item in CATALOG:
		if not available(item.id, ranks):
			continue
		var option: Dictionary = item.duplicate()
		var current := int(ranks.get(item.id, 0))
		var next := current + 1
		match item.id:
			"damage", "haste", "vitality":
				var attribute: String = {"damage": "普攻/技能伤害", "haste": "攻速", "vitality": "生命上限"}[item.id]
				option.detail = "%s：基础 ×%.1f → ×%.1f" % [attribute, MULTIPLIERS[current], MULTIPLIERS[next]]
				if item.id == "vitality":
					option.detail += "\n每秒回血：%.0f%% → %.0f%%，立即满血" % [REGEN_RATES[current] * 100, REGEN_RATES[next] * 100]
			"multishot": option.detail = "每轮射弹：%d → %d 发" % [COUNTS[current], COUNTS[next]]
			"pierce": option.detail = "每弹最多命中：%d → %d 个怪物" % [COUNTS[current], COUNTS[next]]
		pool.append(option)
	var result: Array[Dictionary] = []
	while not pool.is_empty() and result.size() < 3:
		var pick := rng.randi_range(0, pool.size() - 1)
		result.append(pool[pick])
		pool.remove_at(pick)
	return result

static func apply(player, id: String) -> bool:
	if not available(id, player.ranks):
		return false
	var rank := int(player.ranks.get(id, 0)) + 1
	var s: Dictionary = player.stats
	var base: Dictionary = player.base_stats
	match id:
		"damage": s.damage = float(base.damage) * MULTIPLIERS[rank]
		"haste": s.interval = float(base.interval) / MULTIPLIERS[rank]
		"multishot": s.projectiles = COUNTS[rank]
		"pierce": s.pierce = COUNTS[rank] - 1 # Projectile stores extra hits, UI uses total hits.
		"vitality":
			s.max_hp = float(base.max_hp) * MULTIPLIERS[rank]
			s.regen = REGEN_RATES[rank]
			if not player.downed:
				player.hp = float(s.max_hp)
	player.ranks[id] = rank
	return true

static func effect_text(id: String, rank: int) -> String:
	var before: float = MULTIPLIERS[rank - 1]
	var after: float = MULTIPLIERS[rank]
	match id:
		"damage", "haste":
			var attribute: String = {"damage": "伤害", "haste": "攻速"}[id]
			return "%s：×%.1f → [b]×%.1f[/b]" % [attribute, before, after]
		"vitality":
			return "生命：×%.1f → [b]×%.1f[/b]\n每秒回血：%.0f%% → [b]%.0f%%[/b] · 立即满血" % [before, after, REGEN_RATES[rank - 1] * 100, REGEN_RATES[rank] * 100]
		"multishot": return "每轮射弹：%d → [b]%d 发[/b]" % [COUNTS[rank - 1], COUNTS[rank]]
		"pierce": return "每弹命中：%d → [b]%d 个怪物[/b]" % [COUNTS[rank - 1], COUNTS[rank]]
	return ""

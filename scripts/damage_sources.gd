extends RefCounted
const NAMES := {"auto": "普攻", "lightning_tower": "雷楞塔", "tower_chain": "天雷链狱", "tower_tide": "雷霆潮汐", "tower_judgment": "雷神裁决", "fireball": "大火球",
	"fire_explosion": "吞能炎星 · 爆炸", "frost": "冰霜领域", "frost_cones": "冰锥雨",
	"dash": "突进斩", "slash": "破空斩", "giant": "巨大化撞击", "cannon": "人肉炮弹",
	"quake": "震地余波", "thorns": "荆棘反甲", "fire_ground": "火区持续伤害", "burn": "灼烧", "other": "其他"}
const MAGE := ["auto", "lightning_tower", "tower_chain", "tower_tide", "tower_judgment", "fireball", "fire_explosion", "frost", "frost_cones", "fire_ground", "burn"]
const WARRIOR := ["auto", "dash", "slash", "giant", "cannon", "quake", "thorns", "fire_ground", "burn"]

static func rows(game, owner: int) -> Array[Dictionary]:
	var ids: Array = (MAGE if game.players[owner].role == 0 else WARRIOR).duplicate()
	for id in game.damage_breakdown[owner]:
		if not ids.has(id): ids.append(id)
	var result: Array[Dictionary] = []
	var total: float = game.damage_totals[owner]
	for id in ids:
		var amount := float(game.damage_breakdown[owner].get(id, 0.0))
		result.append({"id": id, "name": NAMES.get(id, "其他"), "amount": amount,
			"share": amount / total if total > 0.0 else 0.0, "order": result.size()})
	result.sort_custom(func(a, b): return a.amount > b.amount if a.amount != b.amount else a.order < b.order)
	return result

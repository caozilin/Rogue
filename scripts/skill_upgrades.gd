extends RefCounted
## Ordinary tiers are total multipliers; every third personal pick is a unique major.
const Classes = preload("res://scripts/classes.gd")
const MAX_RANK := 3
const MAJOR_EVERY := 3
const RANGE_TIERS := [1.0, 1.5, 2.0, 2.5]
const COUNT_TIERS := [1, 2, 3, 4]
const TOWER_RATE_TIERS := [1.0, 1.5, 2.0, 2.5]
const TOWER_DAMAGE_TIERS := [1.0, 1.35, 1.70, 2.0]
const TOWER_TIME_TIERS := [10.0, 12.0, 14.0, 16.0]
const DASH_DISTANCE_TIERS := [1.0, 1.2, 1.4, 1.6]
const REFUND_SECONDS := [0.0, 0.25, 0.35, 0.45]
const REFUND_CAPS := [0.0, 0.30, 0.40, 0.50]
const GIANT_SIZE_TIERS := [2.0, 2.7, 3.4, 4.0]
const GIANT_TIME_TIERS := [4.0, 4.5, 5.0, 5.5]
const WARCRY_TIME_TIERS := [4.0, 6.0, 8.0, 10.0]
const DUMMY_TIME_TIERS := [10.0, 12.0, 14.0, 16.0]
const DUMMY_HP_TIERS := [1.0, 1.5, 2.0, 2.5]
const GUARD_REGEN_TIERS := [0.015, 0.025, 0.035, 0.045]
const GUARD_CAP_TIERS := [0.15, 0.25, 0.35, 0.45]
const WARRIOR_CATALOG := [
	{"id": "dash_geometry", "title": "冲刺 · 宽幅长驱", "detail": "宽度 ×1.5 / 2 / 2.5，距离 ×1.2 / 1.4 / 1.6", "note": "相对基础数值的三个总档位；初始冲刺无击退"},
	{"id": "dash_refund", "title": "冲刺 · 穿阵回流", "detail": "每个敌人返还 0.25 / 0.35 / 0.45 秒，最多 30 / 40 / 50% CD", "note": "两次冲刺共用去重计数和返还上限，斩击波不参与返还"},
	{"id": "giant_form", "title": "撞击 · 巨躯延展", "detail": "体型 ×2.7 / 3.4 / 4，持续 4.5 / 5 / 5.5 秒", "note": "初始体型 ×2、持续 4 秒；体型与碰撞半径同步变化"},
	{"id": "giant_force", "title": "撞击 · 重装动能", "detail": "撞击伤害与击退距离升至基础 ×1.5 / 2 / 2.5", "note": "总倍率逐级替换，保留敌人韧性；初始撞击已带伤害"},
	{"id": "warcry_endurance", "title": "嘲讽 · 余威悠长", "detail": "自身嘲讽持续 6 / 8 / 10 秒；木桩持续 12 / 14 / 16 秒，生命为自身上限 150 / 200 / 250%", "note": "未获得木桩时强化自身嘲讽；获得木桩后同档强化其寿命与生命，选择顺序不影响效果"},
	{"id": "rescue_guard", "title": "传送守护 · 护盾积蓄", "detail": "每秒获得自身最大生命 2.5 / 3.5 / 4.5% 护盾，上限 25 / 35 / 45%", "note": "初始每秒 1.5%，上限 15%；持续恢复自身护盾，倒地停止，暂停冻结，升级不直接补满"}
]
const WARRIOR_MAJORS := [
	{"id": "giant_refund", "title": "撞击大技能 · 受击回流", "detail": "巨化期间每次有效受击减少巨化冷却 0.5 秒，单次最多 3 秒", "note": "每次巨化重新计数；无敌挡住的攻击不计，护盾吸收的有效受击计入；只减少技能 2 冷却", "major": true},
	{"id": "warcry_dummy", "title": "战吼大技能 1 · 嘲讽木桩", "detail": "原地留下持续 10 秒的木桩，血量为自身最大生命 100%", "note": "自身不再获得嘲讽；全地图敌人优先攻击木桩，被击毁或到期后恢复索敌", "major": true},
	{"id": "dash_recast", "title": "冲刺大技能 · 二段突袭", "detail": "第一次冲刺结束后 2 秒内可再次朝鼠标冲刺", "note": "最多追加一次；共用本次冷却和穿敌返还上限", "major": true},
	{"id": "dash_flame", "title": "冲刺大技能 · 炎刃附魔", "detail": "冲刺伤害变为火属性，路径留下 8 秒火区", "note": "可触发火冰反应；斩击波也继承火附魔与火区", "major": true},
	{"id": "dash_wave", "title": "冲刺大技能 · 破空斩", "detail": "沿冲刺方向发出穿屏斩击，伤害 ×4.5 并击退", "note": "命中每个敌人一次，击退 100；可被炎刃附魔，但不返还冲刺冷却", "major": true},
	{"id": "giant_cannon", "title": "撞击大技能 · 人肉炮弹", "detail": "撞飞敌人可继续撞伤、击退其他敌人并使双方短暂硬直", "note": "最多传递 4 层，伤害继承 70%、击退继承 65%；每名敌人每次巨大化最多传递 2 次", "major": true},
	{"id": "giant_thorns", "title": "撞击大技能 · 荆棘反甲", "detail": "巨化期间反弹敌方原始伤害 ×3，返还给攻击者", "note": "取护盾、防御和减伤前的敌方伤害，继承全队伤害加成；无敌未受击不反弹", "major": true},
	{"id": "giant_quake", "title": "撞击大技能 · 震地余波", "detail": "每撞击 6 个不同敌人触发范围震地，造成高伤和短暂失衡", "note": "每次巨大化最多 3 次；伤害为基础 ×3.5 并继承撞击伤害强化，不强击退", "major": true},
	{"id": "rescue_blessing", "title": "救援大技能 1 · 庇护救援", "detail": "抵达后队友获得 10 秒庇护：50% 韧性、护盾与回血；补满自身被动护盾", "note": "队友护盾为战士最大生命 50%，每秒额外回复队友最大生命 3%；复活队友后也生效，无额外减伤", "major": true},
	{"id": "rescue_counterattack", "title": "救援大技能 3 · 并肩反攻", "detail": "成功携带活队友或立即复活队友后，双方伤害 ×1.3，持续 5 秒", "note": "独立伤害乘区，与全局伤害、附身增益相乘；重复触发刷新时间，不叠加倍率；仅瞬移到尸体不触发", "major": true}
]
const CATALOG := [
	{"id": "fire_width", "title": "火球 · 扩大火势", "detail": "火球宽度升至基础的 1.5 / 2 / 2.5 倍", "note": "总倍率分三档，显示与命中范围同步扩大"},
	{"id": "fire_count", "title": "火球 · 连续施法", "detail": "每次 Q 升至 2 / 3 / 4 重火球，间隔 0.3 秒", "note": "后续火球按法师最新位置与最高等级目标重新发射"},
	{"id": "frost_width", "title": "冰霜 · 扩展领域", "detail": "领域半径升至基础的 1.5 / 2 / 2.5 倍", "note": "同时扩大领域、庇护寒域的护罩与友方保护范围"},
	{"id": "frost_rate", "title": "冰霜 · 急速脉冲", "detail": "领域伤害频率升至 2 / 3 / 4 倍", "note": "每段伤害不变；伤害间隔从 0.5 秒降至 0.25 / 0.167 / 0.125 秒"},
	{"id": "tower_rate", "title": "雷塔 · 高频线圈", "detail": "攻击频率 ×1.5 / ×2 / ×2.5", "note": "相对基础 0.8 秒间隔的总倍率；连锁与裁决也随主雷击变快"},
	{"id": "tower_core", "title": "雷塔 · 增幅核心", "detail": "伤害 ×1.35 / ×1.70 / ×2，持续 12 / 14 / 16 秒", "note": "强化新召唤塔的单次雷击、衍生雷击与总寿命；雷霆潮汐自爆也按寿命增加伤害"}
]
const MAJORS := [
	{"id": "fire_push", "title": "火球大技能 · 炎浪击退", "detail": "火球每段击退 42，并按累计实际击退距离增伤", "note": "韧性越高击退越少，Boss 仍免疫击退；增伤最多 +200%", "major": true},
	{"id": "fire_ground", "title": "火球大技能 · 烈焰之路", "detail": "沿路径留下 8 秒火区，附火持续伤害；连续停留 2 秒触发灼烧", "note": "火附着 3 秒；灼烧持续 4 秒，可与基础火伤叠加", "major": true},
	{"id": "fire_growth", "title": "火球大技能 · 吞能炎星", "detail": "吸收新敌人能量，最多膨胀 4 阶，消失时按最终体积爆炸", "note": "爆炸伤害 ×2，成长每阶 +30%；每 3 能量一阶，体积 +18%、多段伤害 +20%/阶；精英/Boss 重复命中仅 +0.15 能量", "major": true},
	{"id": "frost_cones", "title": "冰霜大技能 · 冰锥雨", "detail": "每 0.7 秒寻敌落下冰锥，命中小范围造成 1.8 倍基础伤害", "note": "领域内寻敌；冰锥有 0.35 秒下落提示，范围半径 36", "major": true},
	{"id": "frost_path", "title": "冰霜大技能 · 冰径", "detail": "领域随移动留下 8 秒冰面，附冰并持续减少敌人双速", "note": "冰附着持续 3 秒，移速 -40%、攻速 -35%；站立不重复铺冰", "major": true},
	{"id": "frost_ward", "title": "冰霜大技能 · 庇护寒域", "detail": "友方独立减伤 25%、韧性 50%，领域挡弹并有血量", "note": "继承冰霜范围强化与附身范围增益；护盾血量为法师最大生命的 150%，破盾结束领域", "major": true},
	{"id": "tower_chain", "title": "雷塔大技能 1 · 天雷链狱", "detail": "每击追加最多 3 次连锁，缺少目标时回灌原目标", "note": "连锁/回灌每段 ×0.05，半径 260；每次主攻击对同一目标最多叠 1 层雷纹。4 / 6 / 8 层落雷柱，伤害 ×1 / ×1.25 / ×1.5（普通 / 精英 / Boss）", "major": true},
	{"id": "tower_tide", "title": "雷塔大技能 2 · 雷霆潮汐", "detail": "每 2.5 秒雷环扫屏并电击硬直；末秒三连环后自爆", "note": "常规环 ×0.6、末秒三环各 ×0.8；自爆 ×2 ×塔寿命/10，对所有敌人按同一倍率结算。普通麻痹 0.55 秒，精英 0.18 秒，Boss 免控", "major": true},
	{"id": "tower_judgment", "title": "雷塔大技能 3 · 雷神裁决", "detail": "连续锁定积累印记，天空法阵汇聚巨雷，命中后扩散冲击环", "note": "普通 / 精英 / Boss 连击 5 / 6 / 8 次触发；预警 0.65 秒，单体伤害 ×8 / ×10 / ×12，半径 110 雷环伤害 ×2", "major": true}
]

static func starting_stats(role: int) -> Dictionary:
	if role == Classes.MAGE:
		return {"duration": Classes.TOWER_DURATION, "cooldown": Classes.TOWER_RELEASE_COOLDOWN,
			"attack_rate": 1.0, "range": 1.0, "move_speed": 1.0, "extra_damage": 0.0,
			"fire_width": 1.0, "fire_count": 1, "frost_width": 1.0, "frost_rate": 1.0,
			"fire_push": false, "fire_ground": false, "fire_growth": false,
			"frost_cones": false, "frost_path": false, "frost_ward": false,
			"tower_rate": 1.0, "tower_damage": 1.0, "tower_duration": 10.0,
			"tower_chain": false, "tower_tide": false, "tower_judgment": false}
	return {"distance": Classes.DASH_DISTANCE, "return_window": Classes.RETURN_WINDOW,
		"dash_invulnerability": Classes.DASH_INVULNERABILITY, "return_invulnerability": Classes.RETURN_INVULNERABILITY,
		"cooldown": Classes.RAID_COOLDOWN, "damage": Classes.DETONATION_DAMAGE,
		"hit_radius": Classes.DASH_HIT_RADIUS, "return_enabled": false,
		"refund_seconds": 0.0, "refund_cap": 0.0, "giant_size": Classes.GIANT_SIZE,
		"giant_duration": Classes.GIANT_DURATION, "giant_power": 1.0,
		"warcry_duration": WARCRY_TIME_TIERS[0], "dummy_duration": DUMMY_TIME_TIERS[0], "dummy_hp": DUMMY_HP_TIERS[0],
		"guard_regen": GUARD_REGEN_TIERS[0], "guard_cap": GUARD_CAP_TIERS[0], "rescue_counterattack": false,
		"dash_recast": false, "dash_flame": false, "dash_wave": false,
		"giant_cannon": false, "giant_thorns": false, "giant_quake": false, "giant_refund": false, "rescue_blessing": false, "warcry_dummy": false}

static func ordinary_pool(role: int) -> Array:
	return CATALOG if role == Classes.MAGE else WARRIOR_CATALOG

static func major_pool(role: int) -> Array:
	return MAJORS if role == Classes.MAGE else WARRIOR_MAJORS

static func is_major_turn(choices: int) -> bool:
	return (choices + 1) % MAJOR_EVERY == 0

static func has_available(role: int, ranks: Dictionary) -> bool:
	for entry in ordinary_pool(role):
		if int(ranks.get(entry.id, 0)) < MAX_RANK:
			return true
	for entry in major_pool(role):
		if not ranks.has(entry.id):
			return true
	return false

static func roll(rng: RandomNumberGenerator, role: int, ranks: Dictionary = {}, choices := 0) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for entry in (major_pool(role) if is_major_turn(choices) else ordinary_pool(role)):
		if int(ranks.get(entry.id, 0)) < (1 if bool(entry.get("major", false)) else MAX_RANK):
			pool.append(entry.duplicate(true))
	# If a category is exhausted, the remaining valid choices must still be reachable.
	if pool.is_empty():
		for entry in (ordinary_pool(role) if is_major_turn(choices) else major_pool(role)):
			if int(ranks.get(entry.id, 0)) < (1 if bool(entry.get("major", false)) else MAX_RANK):
				pool.append(entry.duplicate(true))
	var offers: Array[Dictionary] = []
	while not pool.is_empty() and offers.size() < 3:
		var index := rng.randi_range(0, pool.size() - 1)
		offers.append(pool[index])
		pool.remove_at(index)
	return offers

static func apply(player, id: String) -> bool:
	for entry in major_pool(player.role):
		if entry.id == id:
			if player.skill_ranks.has(id):
				return false
			player.skill_stats[id] = true
			player.skill_ranks[id] = 1
			return true
	var rank := int(player.skill_ranks.get(id, 0))
	if rank >= MAX_RANK:
		return false
	var valid := false
	for entry in ordinary_pool(player.role):
		valid = valid or entry.id == id
	if not valid:
		return false
	match id:
		"fire_width", "frost_width":
			player.skill_stats[id] = RANGE_TIERS[rank + 1]
		"fire_count":
			player.skill_stats[id] = COUNT_TIERS[rank + 1]
		"frost_rate":
			player.skill_stats[id] = float(COUNT_TIERS[rank + 1])
		"tower_rate":
			player.skill_stats.tower_rate = TOWER_RATE_TIERS[rank + 1]
		"tower_core":
			player.skill_stats.tower_damage = TOWER_DAMAGE_TIERS[rank + 1]
			player.skill_stats.tower_duration = TOWER_TIME_TIERS[rank + 1]
		"dash_geometry":
			player.skill_stats.hit_radius = Classes.DASH_HIT_RADIUS * float(RANGE_TIERS[rank + 1])
			player.skill_stats.distance = Classes.DASH_DISTANCE * float(DASH_DISTANCE_TIERS[rank + 1])
		"dash_refund":
			player.skill_stats.refund_seconds = REFUND_SECONDS[rank + 1]
			player.skill_stats.refund_cap = REFUND_CAPS[rank + 1]
		"giant_form":
			player.skill_stats.giant_size = GIANT_SIZE_TIERS[rank + 1]
			player.skill_stats.giant_duration = GIANT_TIME_TIERS[rank + 1]
		"giant_force":
			player.skill_stats.giant_power = RANGE_TIERS[rank + 1]
		"warcry_endurance":
			player.skill_stats.warcry_duration = WARCRY_TIME_TIERS[rank + 1]
			player.skill_stats.dummy_duration = DUMMY_TIME_TIERS[rank + 1]
			player.skill_stats.dummy_hp = DUMMY_HP_TIERS[rank + 1]
		"rescue_guard":
			player.skill_stats.guard_regen = GUARD_REGEN_TIERS[rank + 1]
			player.skill_stats.guard_cap = GUARD_CAP_TIERS[rank + 1]
		_:
			return false
	player.skill_ranks[id] = rank + 1
	return true

static func effect_text(id: String, rank: int) -> String:
	var previous := rank - 1
	match id:
		"warcry_endurance": return "自身：%.0fs → [b]%.0fs[/b] · 木桩：%.0fs → [b]%.0fs[/b]\n木桩生命：%.0f%% → [b]%.0f%%[/b]" % [WARCRY_TIME_TIERS[previous], WARCRY_TIME_TIERS[rank], DUMMY_TIME_TIERS[previous], DUMMY_TIME_TIERS[rank], DUMMY_HP_TIERS[previous] * 100, DUMMY_HP_TIERS[rank] * 100]
		"rescue_guard": return "每秒护盾：%.1f%% → [b]%.1f%%[/b] · 上限：%.0f%% → [b]%.0f%%[/b]" % [GUARD_REGEN_TIERS[previous] * 100, GUARD_REGEN_TIERS[rank] * 100, GUARD_CAP_TIERS[previous] * 100, GUARD_CAP_TIERS[rank] * 100]
		"tower_rate": return "攻击频率：×%.1f → [b]×%.1f[/b]" % [TOWER_RATE_TIERS[previous], TOWER_RATE_TIERS[rank]]
		"tower_core": return "伤害：×%.2f → [b]×%.2f[/b] · 存在：%.0fs → [b]%.0fs[/b]" % [TOWER_DAMAGE_TIERS[previous], TOWER_DAMAGE_TIERS[rank], TOWER_TIME_TIERS[previous], TOWER_TIME_TIERS[rank]]
		"fire_width", "frost_width", "giant_force":
			var label: String = {"fire_width": "火球宽度", "frost_width": "领域半径", "giant_force": "撞击伤害与击退"}[id]
			return "%s：×%.1f → [b]×%.1f[/b]" % [label, RANGE_TIERS[previous], RANGE_TIERS[rank]]
		"fire_count": return "连续火球：%d → [b]%d 重[/b]" % [COUNT_TIERS[previous], COUNT_TIERS[rank]]
		"frost_rate": return "伤害频率：×%d → [b]×%d[/b]" % [COUNT_TIERS[previous], COUNT_TIERS[rank]]
		"dash_geometry": return "宽度：×%.1f → [b]×%.1f[/b] · 距离：×%.1f → [b]×%.1f[/b]" % [RANGE_TIERS[previous], RANGE_TIERS[rank], DASH_DISTANCE_TIERS[previous], DASH_DISTANCE_TIERS[rank]]
		"dash_refund": return "每敌返还：%.2fs → [b]%.2fs[/b] · 上限：%.0f%% → [b]%.0f%%[/b]" % [REFUND_SECONDS[previous], REFUND_SECONDS[rank], REFUND_CAPS[previous] * 100, REFUND_CAPS[rank] * 100]
		"giant_form": return "体型：×%.1f → [b]×%.1f[/b] · 持续：%.1fs → [b]%.1fs[/b]" % [GIANT_SIZE_TIERS[previous], GIANT_SIZE_TIERS[rank], GIANT_TIME_TIERS[previous], GIANT_TIME_TIERS[rank]]
	return ""

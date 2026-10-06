extends SceneTree
## An explicit sustained-DPS estimate, not a bot fight or a measured human clear time.
const Balance = preload("res://scripts/balance.gd")
const Classes = preload("res://scripts/classes.gd")
const Player = preload("res://scripts/player.gd")
const Skills = preload("res://scripts/skill_upgrades.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
const Mage = preload("res://scripts/mage.gd")
const Warrior = preload("res://scripts/warrior.gd")
const LEGACY_HP := {"spore": 36.0 * (1.0 + 60.0 / 95.0) * 32.0, "thorn": 36.0 * (1.0 + 120.0 / 95.0) * 32.0 * 0.85,
	"melee": 36.0 * (1.0 + 180.0 / 95.0) * 64.0, "artillery": 36.0 * (1.0 + 180.0 / 95.0) * 64.0 * 0.9}
const TEAM_PLANS := {
	"balanced": ["damage", "haste", "vitality", "multishot", "speed", "damage", "haste", "vitality", "multishot"],
	"offense": ["damage", "haste", "multishot", "damage", "haste", "multishot", "damage", "haste", "multishot"],
	"survival": ["vitality", "speed", "damage", "vitality", "haste", "speed", "multishot", "damage", "vitality"]
}
const MAGE_PLANS := {
	"balanced": ["fire_count", "frost_width", "fire_ground", "frost_rate", "fire_width", "frost_cones", "fire_count", "frost_rate", "frost_ward"],
	"offense": ["frost_rate", "frost_width", "frost_cones", "fire_count", "fire_width", "fire_ground", "fire_count", "frost_rate", "fire_growth"],
	"survival": ["frost_width", "fire_count", "frost_ward", "fire_width", "fire_count", "frost_path", "frost_rate", "fire_width", "fire_growth"]
}
const WARRIOR_PLANS := {
	"balanced": ["dash_geometry", "giant_force", "dash_recast", "dash_refund", "giant_form", "dash_flame", "giant_force", "giant_form", "dash_wave"],
	"offense": ["giant_force", "giant_form", "dash_wave", "giant_force", "giant_form", "dash_recast", "dash_geometry", "dash_refund", "dash_flame"],
	"survival": ["dash_geometry", "giant_form", "giant_blessing", "dash_refund", "giant_form", "giant_cannon", "dash_geometry", "giant_force", "giant_quake"]
}
const NODES := [
	{"id": "spore", "name": "孢冠统领", "seconds": 60, "picks": 3, "radius": 34.0, "mage_distance": 260.0, "auto_uptime": 0.68, "frost_uptime": 0.65, "skill_hit": 0.8, "incoming": 1.0, "target": 30.0},
	{"id": "thorn", "name": "荆棘祭司", "seconds": 120, "picks": 6, "radius": 34.0, "mage_distance": 260.0, "auto_uptime": 0.72, "frost_uptime": 0.7, "skill_hit": 0.85, "incoming": 0.825, "target": 35.0},
	{"id": "melee", "name": "断界武王", "seconds": 180, "picks": 9, "radius": 42.0, "mage_distance": 280.0, "auto_uptime": 0.7, "frost_uptime": 0.55, "skill_hit": 0.72, "incoming": 1.12, "target": 40.0},
	{"id": "artillery", "name": "天穹炮皇", "seconds": 180, "picks": 9, "radius": 44.0, "mage_distance": 330.0, "auto_uptime": 0.8, "frost_uptime": 0.45, "skill_hit": 0.8, "incoming": 1.18, "target": 40.0}
]

static func build(role: int, picks: int, plan: String):
	var player := Player.new()
	player.configure_class(role)
	for index in range(picks):
		assert(Upgrades.apply(player, TEAM_PLANS[plan][index]), "Invalid shared budget pick")
		assert(Skills.apply(player, (MAGE_PLANS if role == Classes.MAGE else WARRIOR_PLANS)[plan][index]), "Invalid personal budget pick")
	return player

static func aimed_bullets(player, node: Dictionary) -> int:
	var distance: float = node.mage_distance if player.role == Classes.MAGE else 190.0
	var hits := 0
	for index in range(int(player.stats.projectiles)):
		var angle := ceilf(index / 2.0) * 0.11
		if absf(sin(angle)) * distance <= float(node.radius) + 4.5: hits += 1
	return hits

static func estimate(player, node: Dictionary, element_partner: bool) -> Dictionary:
	var damage := float(player.stats.damage)
	var uptime := float(node.auto_uptime)
	if player.role == Classes.RAIDER: uptime *= 0.8 if node.id == "artillery" else 0.9
	var auto := damage / float(player.stats.interval) * aimed_bullets(player, node) * uptime
	var skill := 0.0
	if player.role == Classes.MAGE:
		# Four seconds of suppression per fourteen seconds; its extra target is not the boss.
		auto *= 1.0 + (Classes.SUPPRESSION_ATTACK_RATE - 1.0) * Classes.SUPPRESSION_DURATION / (Classes.SUPPRESSION_DURATION + Classes.SUPPRESSION_COOLDOWN)
		var reaction := 1.7 # Timed Q/E creates double-damage windows, not permanent double damage.
		var fire_radius: float = Mage.FIREBALL_RADIUS * float(player.skill_stats.fire_width)
		var overlap := minf(Mage.FIREBALL_LIFE, 2.0 * (fire_radius + float(node.radius)) / (Mage.FIREBALL_SPEED + (55.0 if node.id == "melee" else 25.0)))
		var fire_hits := ceilf(overlap / Mage.FIREBALL_TICK)
		var fire := fire_hits * Mage.FIREBALL_DAMAGE * float(player.skill_stats.fire_count) * reaction * float(node.skill_hit)
		var frost_uptime := float(node.frost_uptime)
		if float(player.skill_stats.frost_width) > 1.0 and not bool(player.skill_stats.frost_ward): frost_uptime = minf(0.95, frost_uptime + 0.2)
		var frost := Mage.FROST_DURATION / Mage.FROST_TICK * Mage.FROST_DAMAGE * float(player.skill_stats.frost_rate) * reaction * frost_uptime
		var cones := 0.0
		if bool(player.skill_stats.frost_cones): cones = ceilf(Mage.FROST_DURATION / Mage.CONE_INTERVAL) * Mage.CONE_DAMAGE * reaction * frost_uptime * 0.85
		var explosion := 0.0
		if bool(player.skill_stats.fire_growth):
			# A lone boss cannot feed enough new targets for four-stage growth.
			explosion = Mage.GROWTH_EXPLOSION_DAMAGE * float(player.skill_stats.fire_count) * reaction * 0.35
		skill = damage * (fire + frost + cones + explosion) / Mage.FIREBALL_COOLDOWN
		if bool(player.skill_stats.fire_ground): skill += damage * 0.18 * 2.75 * reaction * 0.4
		# Possession's 35% output bonus occupies about a fifth of the fight.
		auto *= 1.07
		skill *= 1.07 * 1.05
	else:
		var casts := 2.0 if bool(player.skill_stats.dash_recast) else 1.0
		var reaction := 1.7 if bool(player.skill_stats.dash_flame) and element_partner else 1.0
		var cooldown := Classes.RAID_COOLDOWN - float(player.skill_stats.refund_seconds)
		skill = damage * float(player.skill_stats.damage) * casts / cooldown * float(node.skill_hit) * reaction
		if bool(player.skill_stats.dash_wave): skill += damage * Warrior.SLASH_DAMAGE * casts / cooldown * 0.8 * reaction
		skill += damage * Classes.GIANT_DAMAGE * float(player.skill_stats.giant_power) * ceilf(float(player.skill_stats.giant_duration) / 0.5) / Classes.GIANT_COOLDOWN * (0.55 if node.id == "artillery" else 0.65)
		if bool(player.skill_stats.dash_flame): skill += damage * 0.18 * 2.75 * reaction * 0.3
		# Cannon chains and quake require other enemies: zero direct contribution in solo finales.
	return {"auto": auto, "skill": skill, "total": (auto + skill) * float(node.incoming)}

func _initialize() -> void:
	var rows: Array[Dictionary] = []
	for node in NODES:
		for plan in ["survival", "balanced", "offense"]:
			var mage = build(Classes.MAGE, int(node.picks), plan)
			var warrior = build(Classes.RAIDER, int(node.picks), plan)
			var m := estimate(mage, node, true)
			var w := estimate(warrior, node, true)
			var solo_w := estimate(warrior, node, false)
			var old_hp: float = LEGACY_HP[node.id]
			var health: float = Balance.BOSS_HEALTH[node.id]
			var row := {"boss": node.name, "node": node.id, "picks": node.picks, "majors": int(node.picks / 3), "plan": plan,
				"mage_auto": snappedf(m.auto, 0.1), "mage_skill": snappedf(m.skill, 0.1), "warrior_auto": snappedf(w.auto, 0.1), "warrior_skill": snappedf(w.skill, 0.1),
				"mixed_dps": snappedf(m.total + w.total, 0.1), "mages_dps": snappedf(m.total * 2.0, 0.1), "warriors_dps": snappedf(solo_w.total * 2.0, 0.1),
				"old_hp": snappedf(old_hp, 1.0), "old_mixed_seconds": snappedf(old_hp / (m.total + w.total), 0.1),
				"health": health, "mixed_seconds": snappedf(health / (m.total + w.total), 0.1), "mages_seconds": snappedf(health / (m.total * 2.0), 0.1), "warriors_seconds": snappedf(health / (solo_w.total * 2.0), 0.1),
				"suggested_hp": snappedf((m.total + w.total) * float(node.target), 100.0)}
			rows.append(row)
			print(JSON.stringify(row))
			mage.free()
			warrior.free()
	var file := FileAccess.open("res://artifacts/boss_damage_budget.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	quit()

extends RefCounted
## Element tags live on enemies; all damage uses the game's existing kill/reward path.
const ATTACHMENT_SECONDS := 3.0
const REACTION_SECONDS := 3.0
const BURN_SECONDS := 4.0
const BURN_EXPOSURE := 2.0
const DOT_TICK := 0.5
var game
var fire_contacts: Dictionary = {}

func state(enemy) -> Dictionary:
	if enemy.element_state.is_empty():
		enemy.element_state = {"fire": 0.0, "ice": 0.0, "fire_amp": 0.0, "ice_amp": 0.0,
			"fire_dps": 0.0, "fire_owner": 0, "burn": 0.0, "burn_dps": 0.0, "burn_owner": 0,
			"exposure": 0.0, "tick": DOT_TICK, "dot_pending": {}}
	return enemy.element_state

func attach(enemy, element: String) -> void:
	var s := state(enemy)
	s[element] = ATTACHMENT_SECONDS

func damage(enemy, amount: float, owner: int, element: String, attach_tag := true, source := "other") -> void:
	if enemy.dead:
		return
	var s := state(enemy)
	var opposite := "ice" if element == "fire" else "fire"
	if float(s[opposite]) > 0.0:
		s[element + "_amp"] = REACTION_SECONDS
	if attach_tag:
		attach(enemy, element)
	var reacting := float(s[element + "_amp"]) > 0.0
	var multiplier := 2.0 if reacting else 1.0
	# Apply the owner's ice multiplier once at the shared elemental damage entry.
	# Tags themselves have no damage; future ice DOT routed here inherits this too.
	if element == "ice" and owner >= 0 and owner < game.players.size():
		multiplier *= float(game.players[owner].skill_stats.get("frost_power", 1.0))
	game._damage_enemy(enemy, amount * multiplier, owner, reacting, source, element, reacting)

func fire_ground(enemy, dps: float, owner: int) -> void:
	var s := state(enemy)
	var expired := float(s.fire) <= 0.0
	attach(enemy, "fire")
	if dps >= float(s.fire_dps) or expired:
		s.fire_dps = dps
		s.fire_owner = owner
	# Overlapping patches do not multiply exposure or attached fire damage.
	var id: int = enemy.get_instance_id()
	if not fire_contacts.has(id) or dps > float(fire_contacts[id].dps):
		fire_contacts[id] = {"dps": dps, "owner": owner}

func _pending(s: Dictionary, owner: int, source: String, amount: float) -> void:
	if amount <= 0.0: return
	var key := "%d:%s" % [owner, source]
	if not s.dot_pending.has(key): s.dot_pending[key] = {"owner": owner, "source": source, "amount": 0.0}
	s.dot_pending[key].amount += amount

func advance(delta: float) -> void:
	for enemy in game.enemies:
		if enemy.dead or enemy.element_state.is_empty():
			continue
		var s: Dictionary = enemy.element_state
		for key in ["fire_amp", "ice_amp"]:
			s[key] = maxf(0.0, float(s[key]) - delta)
		var id: int = enemy.get_instance_id()
		if fire_contacts.has(id):
			s.exposure += delta
			if float(s.exposure) >= BURN_EXPOSURE:
				s.burn = BURN_SECONDS
				s.burn_dps = float(fire_contacts[id].dps) * 1.75
				s.burn_owner = int(fire_contacts[id].owner)
		else:
			s.exposure = 0.0
		_pending(s, int(s.fire_owner), "fire_ground", minf(delta, float(s.fire)) * float(s.fire_dps))
		_pending(s, int(s.burn_owner), "burn", minf(delta, float(s.burn)) * float(s.burn_dps))
		s.tick -= delta
		if float(s.tick) <= 0.0:
			for pending in s.dot_pending.values():
				damage(enemy, float(pending.amount), int(pending.owner), "fire", false, str(pending.source))
			s.dot_pending.clear()
			s.tick = DOT_TICK
		if float(s.ice) > 0.0:
			enemy.movement_scale = minf(enemy.movement_scale, 0.60)
			enemy.attack_scale = minf(enemy.attack_scale, 0.65)
		for key in ["fire", "ice", "burn"]:
			s[key] = maxf(0.0, float(s[key]) - delta)
		if float(s.fire) <= 0.0:
			s.fire_dps = 0.0
		enemy.queue_redraw()
	fire_contacts.clear()

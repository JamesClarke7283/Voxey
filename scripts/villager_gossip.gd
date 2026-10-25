class_name VillagerGossip
extends RefCounted

# Mineclonia mobs_mc/villager.lua, villager_zombie.lua and iron_golem.lua.
# GPL-3.0-or-later; original GDScript using the installed source as reference.
# weight, cap, daily decay, transfer decay
const TYPES = {"major_negative":[-5,100,10,10],"minor_negative":[-1,100,20,20],"minor_positive":[1,25,1,5],"major_positive":[1,20,0,20],"trading":[1,20,2,20]}
static func initialize(person: Dictionary) -> void:
	if int(person.get("gossip_version",0)) == 1: return
	var memories: Dictionary = {}
	if person.get("gossips") is Dictionary:
		for player in person.gossips:
			if not person.gossips[player] is Dictionary: continue
			var values: Dictionary = {}
			for kind in person.gossips[player]:
				if TYPES.has(kind): values[kind] = clampi(int(person.gossips[player][kind]),0,int(TYPES[kind][1]))
			memories[str(player)] = values
	else:
		# The old signed total cannot recover the original memories. Preserve
		# its initial standing within the source's representable range.
		for player in person.get("reputations",{}):
			var total: int = clampi(int(person.reputations[player]),-600,65); var values: Dictionary = {}
			if total > 0:
				values.trading = mini(20,total); total -= values.trading
				if total > 0: values.minor_positive = mini(25,total); total -= values.minor_positive
				if total > 0: values.major_positive = total
			elif total < 0:
				total = -total; values.major_negative = mini(100,total/5); total -= values.major_negative*5
				if total > 0: values.minor_negative = total
			memories[str(player)] = values
	person.gossips = memories; person.gossip_version = 1
	person.gossip_decay_at = float(person.get("gossip_decay_at",0)); person.gossip_received_at = float(person.get("gossip_received_at",0))
	person.reputations = {}
	for player in memories: refresh(person,player)
static func refresh(person: Dictionary, player: String) -> int:
	var total: int = 0
	for kind in person.gossips.get(player,{}): total += int(person.gossips[player][kind])*int(TYPES[kind][0])
	if not person.get("reputations") is Dictionary: person.reputations = {}
	person.reputations[player] = total
	return total
static func reputation(person: Dictionary, player: String) -> int:
	initialize(person); return refresh(person,player)
static func record(person: Dictionary, player: String, kind: String, amount: int) -> void:
	initialize(person)
	if not TYPES.has(kind): return
	if not person.gossips.has(player): person.gossips[player] = {}
	person.gossips[player][kind] = clampi(int(person.gossips[player].get(kind,0))+amount,0,int(TYPES[kind][1]))
	refresh(person,player)
static func copy(receiver: Dictionary, sender: Dictionary) -> void:
	initialize(receiver); initialize(sender)
	for player in sender.gossips:
		if not receiver.gossips.has(player): receiver.gossips[player] = {}
		for kind in sender.gossips[player]:
			var value: int = maxi(int(sender.gossips[player][kind])-int(TYPES[kind][3]),0)
			receiver.gossips[player][kind] = mini(maxi(value,int(receiver.gossips[player].get(kind,0))),int(TYPES[kind][1]))
		refresh(receiver,player)
static func decay_one(person: Dictionary) -> void:
	initialize(person)
	for player in person.gossips:
		for kind in person.gossips[player].keys():
			var value: int = int(person.gossips[player][kind])-int(TYPES[kind][2])
			if value > 1: person.gossips[player][kind] = value
			else: person.gossips[player].erase(kind)
		refresh(person,player)
static func step(person: Dictionary, clock: float) -> void:
	initialize(person)
	if person.gossip_decay_at == 0: person.gossip_decay_at = clock
	elif clock-float(person.gossip_decay_at) >= 1200:
		decay_one(person); person.gossip_decay_at = clock
static func transfer(receiver: Dictionary, sender: Dictionary, clock: float) -> bool:
	initialize(receiver); initialize(sender)
	if clock-float(receiver.gossip_received_at) < 60: return false
	receiver.gossip_received_at = clock; copy(receiver,sender); return true
static func converse(a: VillageMob, b: VillageMob) -> void:
	transfer(a.game.villages.record(b.person_key),a.game.villages.record(a.person_key),VillagerSocial.clock(a.game))
	VillageGolems.maybe_summon(a.game,a,false)
static func murder(game: Node3D, victim: VillageMob, player: String) -> void:
	record(game.villages.record(victim.person_key),player,"major_negative",25)
	for other in game.creatures.get_children():
		if not other is VillageMob or other == victim or other.kind != "villager" or other.is_queued_for_deletion() or other.health <= 0: continue
		if victim.position.distance_to(other.position) <= 16 and victim._sees(other.center()): record(game.villages.record(other.person_key),player,"major_negative",25)
static func prices(costs: Array, demand: int, multiplier: float, standing: int, hero: bool, limits: Array) -> Array:
	if costs.is_empty(): return []
	var difference: int = floori(-standing*multiplier)
	if hero:
		var first: int = clampi(floori(float(costs[0])+maxf(0,floorf(float(costs[0])*demand)*multiplier)+difference),1,int(limits[0]))
		difference -= maxi(1,floori((0.3+1.0/16.0)*first))
	var result: Array = []
	for i in costs.size(): result.append(clampi(floori(float(costs[i])+maxf(0,floorf(float(costs[i])*demand)*multiplier)+difference),1,int(limits[i])))
	return result

extends SceneTree
var failures: int = 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures <= 15: push_error(message)
func person(memories: Dictionary) -> Dictionary:
	var result: Dictionary = {"gossips":memories.duplicate(true)}
	VillagerGossip.initialize(result); return result
func same(actual: Dictionary, source: Dictionary) -> bool:
	# Lua encodes an empty table as null; GDScript keeps an empty dictionary.
	var expected: Dictionary = source.gossips if source.gossips is Dictionary else {}
	if actual.gossips.size() != expected.size(): return false
	for player in expected:
		var entries: Dictionary = expected[player] if expected[player] is Dictionary else {}
		if not actual.gossips.has(player) or actual.gossips[player].size() != entries.size(): return false
		for kind in entries:
			if int(actual.gossips[player].get(kind,-999)) != int(entries[kind]): return false
	for player in source.reputations:
		if int(actual.reputations.get(player,-999)) != int(source.reputations[player]): return false
	return true
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/villager_gossip_reference.json"))
	for row in data.record:
		# Direct callback fixtures include over-cap pre-existing values.
		var p: Dictionary = person({"player":{}}); p.gossips.player[row.kind] = int(row.initial)
		VillagerGossip.record(p,"player",row.kind,int(row.amount))
		check(same(p,row.after),"Record differs: "+str(row))
	for row in data.copy:
		var sender: Dictionary = person({"player":{}}); sender.gossips.player[row.kind] = int(row.sent)
		var receiver: Dictionary = person({"player":{},"other":{"trading":3}}); receiver.gossips.player[row.kind] = int(row.received)
		VillagerGossip.copy(receiver,sender); check(same(receiver,row.after),"Copy differs: "+str(row))
	for row in data.decay:
		var p: Dictionary = person({"player":{}}); p.gossips.player[row.kind] = int(row.initial)
		VillagerGossip.decay_one(p); check(same(p,row.after),"Decay differs: "+str(row))
	for row in data.clock:
		var p: Dictionary = person({"player":{"major_negative":100,"minor_positive":25,"trading":20}}); p.gossip_decay_at = row.last
		VillagerGossip.step(p,row.now); check(same(p,row.after) and p.gossip_decay_at == row.stamp,"Decay clock differs: "+str(row))
	for row in data.conversation:
		var a: Dictionary = person({"player":{"major_negative":25,"minor_positive":25,"major_positive":20,"trading":20}})
		var b: Dictionary = person({"player":{"minor_negative":20}}); b.gossip_received_at = row.last
		VillagerGossip.transfer(b,a,row.now); check(same(b,row.after) and b.gossip_received_at == row.stamp and row.summons == 1,"Conversation differs: "+str(row))
	for row in data.prices:
		var actual: Array = VillagerGossip.prices(row.costs,int(row.demand),row.multiplier,int(row.standing),row.hero,row.limits)
		var equal: bool = actual.size() == row.after.size()
		for i in actual.size(): equal = equal and actual[i] == int(row.after[i])
		check(equal,"Price differs: "+str(row)+" actual="+str(actual))
	print("VILLAGER GOSSIP SOURCE: %d record, %d copy, %d decay, %d clocks, %d conversation, %d price cases; %d failures"%[data.record.size(),data.copy.size(),data.decay.size(),data.clock.size(),data.conversation.size(),data.prices.size(),failures])
	quit(1 if failures else 0)

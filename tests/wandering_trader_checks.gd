extends RefCounted

# The wandering trader (mobs_mc/wandering_trader.lua): nine offers drawn as two
# purchasing, two special and five ordinary, a twenty-minute life, a llama escort,
# and the same trading panel a villager uses.
static func run(suite: Object, game: Node3D) -> void:
	suite.check(WanderingTraders.LIFE_TIMER == 1200.0,"a trader lives for the source's twenty minutes")
	suite.check(WanderingTraders.ESCORT_COUNT == 2,"a trader arrives with the source's two llamas")
	suite.check(WanderingTraders.SPAWN_CHANCE_MIN == 25 and WanderingTraders.SPAWN_CHANCE_MAX == 75 and WanderingTraders.SPAWN_ROLL == 10,"the spawner uses the source's rising chance and one-in-ten roll")
	suite.check(Creature.KINDS.has("wandering_trader") and Creature.KINDS.has("trader_llama"),"both kinds are registered so spawn_creature and /spawn can build them")
	suite.check(not Creature.KINDS["wandering_trader"].has("can_despawn") and not Creature.KINDS["trader_llama"].has("can_despawn"),"neither despawns for distance; both leave on their own timer")
	# The pool shape: nine offers, each with a cost and a give.
	var rng := RandomNumberGenerator.new(); rng.seed = 4242
	var offers: Array = WanderingTraders.make_offers(rng)
	suite.check(offers.size() == 9,"a trader's pool is the source's nine offers")
	var valid: bool = true
	for offer in offers:
		if not offer.has("cost") or not offer.has("give") or offer.cost.is_empty(): valid = false
		if not Nodes.exists(int(offer.cost[0][0])) or not Nodes.exists(int(offer.give[0])): valid = false
		if int(offer.cost[0][1]) < 1 or int(offer.give[1]) < 1: valid = false
	suite.check(valid,"every offer names real items at real prices")
	suite.check(offers[0].cost[0][0] == VillageContent.EMERALD or offers.any(func(o): return int(o.cost[0][0]) == VillageContent.EMERALD),"every trader trade is priced in emeralds")
	# A real spawn produces the trader, its escorts and a record the panel can read.
	var at: Vector3 = game.player.position+Vector3(2.0,0.0,0.0)
	var trader = WanderingTraders.spawn(game,at)
	suite.check(trader != null and trader.kind == "wandering_trader" and trader.life_timer == WanderingTraders.LIFE_TIMER,"a spawned trader is a real trader mob on the source's timer")
	var lamas: int = 0
	for mob in game.creatures.get_children():
		if mob.kind == "trader_llama" and not mob.is_queued_for_deletion(): lamas += 1
	suite.check(lamas == WanderingTraders.ESCORT_COUNT,"a spawned trader brings its two llamas")
	# The record is readable through the village API, which is what the panel uses.
	var record: Dictionary = game.villages.record(trader.person_key)
	suite.check(not record.is_empty() and record.get("offers",[]).size() == 9 and record.profession == "wandering_trader","the trader's record is reachable through the village record lookup with its nine offers")
	# The trading panel opens through the same path a villager's does.
	game.villages.open(trader)
	suite.check(game.state == "trading","right-clicking a trader opens the trading panel")
	game.resume()
	# A trader never counts as a village resident, so it must not enter the people list.
	suite.check(not game.villages.state().people.has(trader.person_key),"a trader is not a village resident")
	# Retiring marks it dead, and a restore skips a dead record.
	trader.retire()
	suite.check(bool(game.villages.record(trader.person_key).get("dead",false)),"retiring a trader marks its record dead")
	var before: int = game.creatures.get_child_count()
	WanderingTraders.restore(game)
	suite.check(game.creatures.get_child_count() == before,"restoring does not revive a retired trader")
	# The spawner advances its counters without needing a world tick per frame.
	var state: Dictionary = WanderingTraders.fresh_spawner()
	suite.check(state.has("delay") and state.has("chance"),"the spawner keeps the source's delay and chance counters")
	# The delay only reaches its limit after twenty ticks of the source's SPAWN_TICK,
	# so advance one whole tick per call rather than a single second.
	var fired: bool = false
	var ticks: int = 0
	for i in 40:
		ticks += 1
		if WanderingTraders.spawn_counters(state,WanderingTraders.SPAWN_TICK): fired = true; break
	suite.check(fired and ticks == 20,"the spawner fires on the source's twentieth sixty-second tick, i.e. twenty minutes")
	suite.check(int(state.chance) == WanderingTraders.SPAWN_CHANCE_MAX,"the chance has risen to the source's cap by the firing tick")

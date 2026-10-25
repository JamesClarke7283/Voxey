class_name VillagerTrading
extends RefCounted

# Mineclonia mobs_mc/villager.lua: trade_from_table, activate_trades,
# on_transaction, level_up and check_restock. GPL-3.0-or-later.
static var enchanting: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/villager_trade_enchanting.json"))
static func initialize(person: Dictionary, seed_value: int = 1) -> void:
	if int(person.get("trade_version",0)) == 1: return
	person.trade_version = 1; person.trade_rng = seed_value&0xffffffff
	person.levelup_in = float(person.get("levelup_in",0))
	person.restock_time = float(person.get("restock_time",-1)); person.restock_day = int(person.get("restock_day",-1))
	person.restocks = int(person.get("restocks",2))
	# Existing saves rolled every tier in advance. Retain those exact future
	# offers until unlocked while presenting only the source's active tiers.
	var active: Array = []; var future: Array = []
	for offer in person.get("offers",[]):
		if int(offer.tier) <= int(person.level): active.append(offer)
		else: future.append(offer)
	person.offers = active; person.future_offers = future
static func generate(template: Dictionary, rng: EnchantRolls) -> Dictionary:
	var offer: Dictionary = template.duplicate(true); offer.cost = []
	for cost in template.cost: offer.cost.append([int(cost[0]),rng.integer(int(cost[1]),int(cost[2]))])
	offer.give = [int(template.give[0]),rng.integer(int(template.give[1]),int(template.give[2]))]
	offer.uses = 0; offer.demand = 0; offer.data = {}; offer.reward_xp = true
	if bool(template.get("enchanted",false)):
		var id: int = int(offer.give[0])
		if Enchanting.book(id):
			var choices: Array = enchanting.book_candidates
			if not choices.is_empty():
				var name: String = choices[rng.integer(1,choices.size())-1]
				offer.data = {"enchantments":{name:rng.integer(1,int(Enchanting.source.definitions[name].max_level))}}
		else:
			var power: int = rng.integer(5,19)
			var profile: Dictionary = enchanting.profiles.get(str(id),{})
			var enchanted: Dictionary = Enchanting.generate_reliable({"id":id,"count":int(offer.give[1])},power,rng,false,false,profile)
			if not enchanted.is_empty(): offer.data = {"enchantments":enchanted.enchantments}
	return offer
static func activate(person: Dictionary, tier: int) -> void:
	initialize(person)
	var retained: Array = []
	for offer in person.get("future_offers",[]):
		if int(offer.tier) == tier: retained.append(offer)
	if not retained.is_empty():
		person.offers.append_array(retained)
		person.future_offers = person.future_offers.filter(func(offer): return int(offer.tier) != tier)
		return
	var rng := EnchantRolls.new(int(person.trade_rng))
	for template in VillageTrades.DATA.get(person.profession,[]):
		if int(template.tier) == tier: person.offers.append(generate(template,rng))
	person.trade_rng = rng.state
static func transaction(person: Dictionary, xp: int) -> bool:
	initialize(person); person.xp = int(person.xp)+xp
	if int(person.level) < 5 and int(person.xp) >= int(VillageContent.LEVELS[int(person.level)]):
		person.levelup_in = 2.0; return true
	return false
static func advance(person: Dictionary, delta: float) -> bool:
	initialize(person)
	if float(person.levelup_in) <= 0: return false
	person.levelup_in = float(person.levelup_in)-delta
	if float(person.levelup_in) > 0 or int(person.level) >= 5: return false
	person.level = int(person.level)+1
	activate(person,int(person.level)); return true
static func tick(mob: VillageMob, delta: float) -> bool:
	var person: Dictionary = mob.game.villages.record(mob.person_key)
	if not advance(person,delta): return false
	PotionEffects.apply(mob,"regeneration",10,1)
	mob.rebuild(); return true
static func update_open(game: Node3D, delta: float) -> void:
	for mob in game.creatures.get_children():
		if mob is VillageMob and mob.kind == "villager" and mob.person_key == game.villages.trading_key and not mob.is_queued_for_deletion():
			if tick(mob,delta):
				game.villages.refresh_prices(game.villages.record(mob.person_key)); game.hud.show_trading(mob.person_key)
			PotionEffects.update(mob,delta)
			return
static func restock(person: Dictionary, clock: float, day: int) -> void:
	initialize(person)
	if (int(person.restock_day) != -1 and day > int(person.restock_day)) or (float(person.restock_time) != -1 and clock-float(person.restock_time) >= 600):
		for offer in person.offers:
			for unused in int(person.restocks):
				offer.demand = int(offer.demand)+int(offer.uses)*2-int(offer.stock); offer.uses = 0
		person.restocks = 2; person.restock_day = day; person.restock_time = clock
		return
	if float(person.restock_time) == -1: person.restock_time = clock
	if int(person.restocks) != 2 and not (int(person.restocks) > 0 and clock-float(person.restock_time) > 120): return
	if not person.offers.any(func(offer): return int(offer.uses) > 0): return
	for offer in person.offers:
		offer.demand = int(offer.demand)+int(offer.uses)*2-int(offer.stock); offer.uses = 0
	person.restocks = int(person.restocks)-1; person.restock_day = day; person.restock_time = clock

class_name VillageLife
extends RefCounted

var game: Node3D
var timer: float = 0.0
var trading_key: String = ""
var price_context: Dictionary = {}
var alarm: float = 0.0

func _init(owner_game: Node3D) -> void:
	game = owner_game

func state() -> Dictionary:
	if not game.world.adventure_state.has("village_life"):
		game.world.adventure_state["village_life"] = {"people":{},"clock":0.0,"manual":0}
	return game.world.adventure_state.village_life

func record(key: String) -> Dictionary:
	# A wandering trader is not a village resident, so its record lives in the trader
	# module's own store. Falling through here is what makes the existing trading
	# panel, its cost display and its transaction all work unchanged.
	var trader: Dictionary = WanderingTraders.stored(game,key)
	if not trader.is_empty(): return trader
	return state().people.get(key,{})

func make_record(key: String, profession: String, p: Vector3, workplace: Vector3i, home: Vector3i, center: Vector3i) -> Dictionary:
	# `slept_at` and `saw_golem_at` are the source's `_last_slept_gmt` and
	# `_last_golem_gmt`, which gate a villager's request for an iron golem
	# (`villager.lua`:3423-3429). `golem_timer` is its own five-second check timer.
	var result: Dictionary = {"key":key,"profession":profession,"xp":0,"level":1,"offers":[],"position":[p.x,p.y,p.z],"job":[workplace.x,workplace.y,workplace.z],"bed":[home.x,home.y,home.z],"center":[center.x,center.y,center.z],"health":20.0,"dead":false,"reputation":0,"reputations":{},"restocks":2,"restock_time":-1.0,"restock_day":-1,"food_level":0,"age":0.0,"slept_at":0.0,"saw_golem_at":0.0,"golem_timer":0.0}
	VillagerTrading.initialize(result,(str(game.world.generator.world_seed)+key).hash())
	VillagerTrading.activate(result,1)
	var previous: Dictionary = state().people.get(key,{})
	result.reputations = previous.get("reputations",{}).duplicate(true)
	if previous.get("gossips") is Dictionary: result.gossips = previous.gossips.duplicate(true)
	result.gossip_decay_at = previous.get("gossip_decay_at",0); result.gossip_received_at = previous.get("gossip_received_at",0)
	VillagerGossip.initialize(result)
	result.food_level = int(state().people.get(key,{}).get("food_level",state().people.get(key,{}).get("food",0)))
	result.inventory = VillagerInventory.clean(state().people.get(key,{}).get("inventory",[]))
	result.custom_name = str(state().people.get(key,{}).get("custom_name",""))
	state().people[key] = result
	return result

func manual(mob: VillageMob) -> void:
	var s: Dictionary = state(); s.manual += 1
	var key: String = "settler:%d"%int(s.manual)
	var p := Vector3i(mob.position.floor())
	var r: Dictionary = make_record(key,"unemployed",mob.position,p,p,p)
	if mob.kind == "iron_golem": r.profession = "golem"; r.health = 100.0
	mob.bind(r)

static func vec(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

func update(delta: float) -> void:
	state().clock += delta
	alarm = maxf(0,alarm-delta)
	# `villager.lua`: `_last_slept_gmt` is set when a villager uses a bed, and it is
	# what lets one ask for an iron golem. Voxey does not track individual bed use, so
	# the whole village is stamped when it passes a night — the same information, from
	# the day cycle the rest of this module already reads.
	if state().get("day",0) != game.day_number():
		state()["day"] = game.day_number()
		VillageGolems.mark_slept(game,"")
	timer -= delta
	if timer > 0: return
	timer = 0.5
	var village: Dictionary = VillageGenerator.nearest(game.world.generator,game.player.position)
	if game.dimension == "overworld" and Vector3(village.center).distance_to(game.player.position) < 95:
		for i in VillageGenerator.HOMES.size():
			var key: String = village.key+"/"+str(i)
			if not state().people.has(key):
				var job: Vector3i = VillageGenerator.job(village,i)
				make_record(key,VillageContent.PROFESSIONS[i],Vector3(job)+Vector3(1.5,0,0.5),job,VillageGenerator.bed(village,i),village.center)
		var key: String = village.key+"/golem"
		if not state().people.has(key):
			var r: Dictionary = make_record(key,"golem",Vector3(village.center)+Vector3(5.5,1,3.5),village.center,village.center,village.center)
			r.health = 100.0
	var live: Dictionary = {}
	for mob in game.creatures.get_children():
		if mob is VillageMob and not mob.is_queued_for_deletion(): live[mob.person_key] = mob; mob.store_record()
	for key in state().people.keys():
		var person: Dictionary = record(key)
		if person.dead: continue
		if not str(person.get("jockey_vehicle","")).is_empty() and not live.has(key): continue
		var pos: Vector3 = vec(person.position)
		if live.has(key):
			if pos.distance_to(game.player.position) > 95 or not game.world.loaded_at(pos):
				if Boats.is_passenger(live[key]) or MobJockeys.vehicle(live[key]) != null: continue
				game.leads.hibernate(live[key]); live[key].queue_free(); continue
			if person.profession != "golem":
				VillagerGossip.step(person,float(state().clock))
				# `villager.lua`: a villager that has slept recently and has not seen a
				# golem lately asks every five seconds while panicking. Calm requests
				# require a social conversation (VillagerGossip.converse).
				VillageGolems.step(game,live[key],VillageGolems.hostile_near(game,live[key].position),0.5)
				work(person,live[key],0.5)
		elif pos.distance_to(game.player.position) < 70 and game.world.loaded_at(pos):
			var mob := VillageMob.new(); mob.game = game; mob.kind = "iron_golem" if person.profession == "golem" else "villager"
			mob.person_key = key; mob.position = pos; game.creatures.add_child(mob); mob.bind(person)

func work(person: Dictionary, mob: VillageMob, delta: float) -> void:
	var was_young: bool = person.get("age",0.0) > 0
	person.age = maxf(0,person.get("age",0.0)-delta)
	if was_young and person.age <= 0: mob.rebuild()
	if person.age > 0: return
	if person.profession == "unemployed":
		for x in range(-5,6):
			for z in range(-5,6):
				var p := Vector3i(mob.position.floor())+Vector3i(x,0,z)
				var index: int = VillageContent.JOBS.find(GrindstoneRepair.base(Stonecutting.base(game.world.node_at(p))))
				if index < 0: continue
				var claimed: bool = false
				for other in state().people.values():
					if not other.dead and other.profession != "unemployed" and Vector3i(vec(other.job)) == p: claimed = true; break
				if claimed: continue
				var replacement: Dictionary = make_record(person.key,VillageContent.PROFESSIONS[index],mob.position,p,Vector3i(vec(person.bed)),Vector3i(vec(person.center)))
				mob.bind(replacement); return
		return
	var profession_index: int = VillageContent.PROFESSIONS.find(person.profession)
	if profession_index < 0: return
	var job: Vector3i = Vector3i(vec(person.job))
	if not game.world.loaded_at(Vector3(job)) or Vector3(job).distance_to(mob.position) > 48 or GrindstoneRepair.base(Stonecutting.base(game.world.node_at(job))) != VillageContent.JOBS[profession_index]:
		var replacement: Vector3i = find_work(mob,profession_index)
		if replacement != Vector3i(0,-999,0): person.job = [replacement.x,replacement.y,replacement.z]; job = replacement
	if not game.world.loaded_at(Vector3(job)): return
	if GrindstoneRepair.base(Stonecutting.base(game.world.node_at(job))) != VillageContent.JOBS[profession_index]:
		if person.xp == 0: person.profession = "unemployed"; person.offers = []; mob.rebuild()
		return
	var daytime: float = fposmod(game.day_time,1.0)
	if person.profession == "farmer": return # Its physics activity dispatcher owns work and field actions.
	if daytime < 0.23 or daytime > 0.65 or mob.position.distance_to(Vector3(job)+Vector3.ONE*0.5) > 3: return
	restock(person,float(state().clock),game.day_number())

func restock(person: Dictionary, clock: float, day: int) -> void:
	VillagerTrading.restock(person,clock,day)

func costs(person: Dictionary, offer: Dictionary) -> Array:
	var standing: int = 0 if person.profession == "wandering_trader" else reputation(person); var hero: bool = PotionEffects.level(game.player,"hero_of_village") > 0
	if person.profession == "wandering_trader": standing = 0; hero = false
	elif game.state == "trading" and price_context.get("key","") == person.key and price_context.get("player","") == game.player_id:
		standing = price_context.standing; hero = price_context.hero
	var amounts: Array = []; var limits: Array = []
	for cost in offer.cost: amounts.append(int(cost[1])); limits.append(Nodes.max_stack(cost[0]))
	var calculated: Array = VillagerGossip.prices(amounts,int(offer.demand),float(offer.multiplier),standing,hero,limits)
	var result: Array = []
	for i in offer.cost.size(): result.append([int(offer.cost[i][0]),int(calculated[i])])
	return result

func transaction(person: Dictionary, offer: Dictionary, commit: bool = false) -> String:
	if person.dead or person.get("age",0.0) > 0: return "This villager cannot trade."
	if offer.tier > person.level: return "Reach "+VillageContent.RANKS[int(offer.tier)-1]+" to unlock."
	if offer.uses >= offer.stock: return "Sold out. Let the villager work to restock."
	# Test payment and output together. Paying can free a slot in an otherwise full bag.
	var trial := Inventory.new(); trial.slots = game.inventory.slots.duplicate(true)
	for cost in costs(person,offer):
		if not trial.remove_item(cost[0],cost[1]): return "You need more "+Nodes.title(cost[0]).to_lower()+"."
	if trial.add_item(offer.give[0],offer.give[1],0,offer.data) > 0: return "Make room in your inventory first."
	if commit:
		# `mobs_mc/villager.lua`:402 throws the trade's experience at the villager, so
		# the orb has to land where the trade happened. The resident is looked up by
		# its person key because this path only carries the record.
		var at: Vector3 = game.player.position+Vector3.UP
		for other in game.creatures.get_children():
			if other is VillageMob and not other.is_queued_for_deletion() and other.person_key == person.key: at = other.center(); break
		game.inventory.slots = trial.slots
		offer.uses += 1
		var promotion_pending: bool = false
		if person.profession != "wandering_trader":
			promotion_pending = VillagerTrading.transaction(person,int(offer.xp))
			VillagerGossip.record(person,game.player_id,"trading",2)
		if person.profession != "wandering_trader" and bool(offer.get("reward_xp",true)): XpOrbs.throw_xp(game,at,randi_range(4,6))
		if promotion_pending: XpOrbs.throw_xp(game,at,5)
		game.inventory.changed.emit(); game.sound("pickup")
	return ""

func refresh_prices(person: Dictionary) -> void:
	price_context = {"key":person.key,"player":game.player_id,"standing":0 if person.profession == "wandering_trader" else reputation(person),"hero":person.profession != "wandering_trader" and PotionEffects.level(game.player,"hero_of_village") > 0}

func open(mob: VillageMob) -> void:
	# A wandering trader uses the same panel, but is never unemployed and is never a
	# child, so only the profession and age gates apply to a villager.
	var trader: bool = mob.kind == "wandering_trader"
	if mob.kind != "villager" and not trader: return
	var person: Dictionary = record(mob.person_key)
	if person.is_empty(): return
	if not trader: VillagerTrading.initialize(person,(str(game.world.generator.world_seed)+person.key).hash())
	if not trader and (person.profession == "unemployed" or person.get("age",0.0) > 0):
		game.toast("A child is still growing." if person.get("age",0.0) > 0 else "Place an unclaimed job block nearby to give this villager a profession."); return
	trading_key = mob.person_key
	refresh_prices(person)
	game.hud.return_cursor(); game.state = "trading"; game.world.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.hud.show_trading(trading_key)

func trade(key: String, index: int, all_available: bool = false) -> void:
	var person: Dictionary = record(key)
	if game.state != "trading" or key != trading_key or person.is_empty() or person.dead or vec(person.position).distance_to(game.player.position) > 6: return
	if index < 0 or index >= person.offers.size(): return
	var amount: int = 0; var reason: String = ""
	for attempt in (64 if all_available else 1):
		reason = transaction(person,person.offers[index],true)
		if not reason.is_empty(): break
		amount += 1
		refresh_prices(person)
	game.toast("Traded %d time(s)."%amount if amount > 0 else reason)
	if amount > 0: game.achievements.award("what_a_deal")
	game.hud.show_trading(key,index)

func snapshot() -> void:
	for mob in game.creatures.get_children():
		if mob is VillageMob and not mob.is_queued_for_deletion(): mob.store_record()

func ring_bell(p: Vector3i) -> void:
	VillagePois.claim_bell(game,p)
	alarm = 12.0
	game.sound("pickup"); game.puff(Vector3(p)+Vector3.UP,Color("ebcc72"),20)
	game.toast("The village bell rings. Villagers seek shelter.")

func feed(mob: VillageMob) -> bool:
	var person: Dictionary = record(mob.person_key); var held: Dictionary = game.inventory.held()
	if int(held.id) not in VillagerInventory.FOOD or person.is_empty(): return false
	var item: Dictionary = held.duplicate(true); item.count = 1
	var items: Array = VillagerInventory.slots(person)
	if not VillagerInventory.space(items,item): game.toast("This villager's inventory is full."); return true
	VillagerInventory.add(items,item)
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.puff(mob.center(),Color("e99d9c"),8)
	return true

func reputation(person: Dictionary) -> int:
	return VillagerGossip.reputation(person,game.player_id)

func find_work(mob: VillageMob, profession_index: int) -> Vector3i:
	var base := Vector3i(mob.position.floor())
	for x in range(-8,9):
		for z in range(-8,9):
			var p: Vector3i = base+Vector3i(x,0,z)
			if GrindstoneRepair.base(Stonecutting.base(game.world.node_at(p))) != VillageContent.JOBS[profession_index]: continue
			var claimed: bool = false
			for r in state().people.values():
				if r.key != mob.person_key and not r.dead and r.profession != "unemployed" and Vector3i(vec(r.job)) == p: claimed = true; break
			if not claimed: return p
	return Vector3i(0,-999,0)

func relocate(mob: VillageMob) -> void:
	var r: Dictionary = record(mob.person_key)
	if r.is_empty() or mob.position.distance_to(vec(r.center)) < 40: return
	var base := Vector3i(mob.position.floor())
	r.center = [base.x,base.y-1,base.z]; r.job = [base.x,base.y,base.z]; r.bed = [base.x,base.y,base.z]
	for x in range(-8,9):
		for z in range(-8,9):
			var p: Vector3i = base+Vector3i(x,0,z)
			if not VillageContent.is_bed(game.world.node_at(p)) or game.world.node_at(p) != VillageContent.bed_foot(game.world.node_at(p)): continue
			var claimed: bool = false
			for other in state().people.values():
				if other.key != r.key and not other.dead and Vector3i(vec(other.bed)) == p: claimed = true; break
			if not claimed: r.bed = [p.x,p.y,p.z]; return

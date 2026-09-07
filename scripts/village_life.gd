class_name VillageLife
extends RefCounted

var game: Node3D
var timer: float = 0.0
var trading_key: String = ""
var alarm: float = 0.0

func _init(owner_game: Node3D) -> void:
	game = owner_game

func state() -> Dictionary:
	if not game.world.adventure_state.has("village_life"):
		game.world.adventure_state["village_life"] = {"people":{},"clock":0.0,"manual":0}
	return game.world.adventure_state.village_life

func record(key: String) -> Dictionary:
	return state().people.get(key,{})

func make_record(key: String, profession: String, p: Vector3, workplace: Vector3i, home: Vector3i, center: Vector3i) -> Dictionary:
	var result: Dictionary = {"key":key,"profession":profession,"xp":0,"level":1,"offers":[],"position":[p.x,p.y,p.z],"job":[workplace.x,workplace.y,workplace.z],"bed":[home.x,home.y,home.z],"center":[center.x,center.y,center.z],"health":20.0,"dead":false,"reputation":0,"reputations":{},"restocks":2,"restock_time":-1.0,"restock_day":game.day_number(),"food":0,"age":0.0,"breed_time":0.0}
	var rng := RandomNumberGenerator.new(); rng.seed = (str(game.world.generator.world_seed)+key).hash()
	for template in VillageTrades.DATA.get(profession,[]):
		var offer: Dictionary = template.duplicate(true)
		offer["cost"] = []
		for cost in template.cost: offer.cost.append([int(cost[0]),rng.randi_range(cost[1],cost[2])])
		offer["give"] = [int(template.give[0]),rng.randi_range(template.give[1],template.give[2])]
		offer["uses"] = 0; offer["demand"] = 0; offer["data"] = {}
		if template.get("enchanted",false):
			var id: int = offer.give[0]
			if id == VillageContent.ENCHANTED_BOOK: offer.data = Enchantments.random_book(rng)
			else:
				var choices: Array = Enchantments.choices(id)
				if not choices.is_empty():
					var enchant: String = choices[rng.randi_range(0,choices.size()-1)]
					offer.data = {"enchantments":{enchant:rng.randi_range(1,Enchantments.DATA[enchant].max)}}
		result.offers.append(offer)
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
	if game.dimension != "overworld": return
	state().clock += delta
	alarm = maxf(0,alarm-delta)
	timer -= delta
	if timer > 0: return
	timer = 0.5
	var village: Dictionary = VillageGenerator.nearest(game.world.generator,game.player.position)
	if Vector3(village.center).distance_to(game.player.position) < 95:
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
		var pos: Vector3 = vec(person.position)
		if live.has(key):
			if pos.distance_to(game.player.position) > 95 or not game.world.loaded_at(pos): live[key].queue_free(); continue
			if person.profession != "golem":
				work(person,live[key],0.5)
		elif pos.distance_to(game.player.position) < 70 and game.world.loaded_at(pos):
			var mob := VillageMob.new(); mob.game = game; mob.kind = "iron_golem" if person.profession == "golem" else "villager"
			mob.person_key = key; mob.position = pos; game.creatures.add_child(mob); mob.bind(person)

func work(person: Dictionary, mob: VillageMob, delta: float) -> void:
	var was_young: bool = person.get("age",0.0) > 0
	person.age = maxf(0,person.get("age",0.0)-delta)
	if was_young and person.age <= 0: mob.rebuild()
	person.breed_time = maxf(0,person.get("breed_time",0.0)-delta)
	if person.age > 0: return
	if person.profession == "farmer" and int(state().clock)%8 == 0: harvest_near(mob)
	if person.profession == "unemployed":
		for x in range(-5,6):
			for z in range(-5,6):
				var p := Vector3i(mob.position.floor())+Vector3i(x,0,z)
				var index: int = VillageContent.JOBS.find(game.world.node_at(p))
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
	if not game.world.loaded_at(Vector3(job)) or Vector3(job).distance_to(mob.position) > 48 or game.world.node_at(job) != VillageContent.JOBS[profession_index]:
		var replacement: Vector3i = find_work(mob,profession_index)
		if replacement != Vector3i(0,-999,0): person.job = [replacement.x,replacement.y,replacement.z]; job = replacement
	if not game.world.loaded_at(Vector3(job)): return
	if game.world.node_at(job) != VillageContent.JOBS[profession_index]:
		if person.xp == 0: person.profession = "unemployed"; person.offers = []; mob.rebuild()
		return
	var daytime: float = fposmod(game.day_time,1.0)
	if daytime < 0.23 or daytime > 0.65 or mob.position.distance_to(Vector3(job)+Vector3.ONE*0.5) > 3: return
	restock(person,float(state().clock),game.day_number())

func restock(person: Dictionary, clock: float, day: int) -> void:
	if day > int(person.restock_day) or (float(person.restock_time) >= 0 and clock-float(person.restock_time) >= 600):
		for offer in person.offers:
			if offer.tier > person.level: continue
			for unused in int(person.restocks):
				offer.demand += int(offer.uses)*2-int(offer.stock); offer.uses = 0
		person.restocks = 2; person.restock_day = day; person.restock_time = clock
	if int(person.restocks) <= 0: return
	if int(person.restocks) < 2 and clock-float(person.restock_time) <= 120: return
	var used: bool = false
	for offer in person.offers:
		if offer.tier <= person.level and offer.uses > 0: used = true
	if not used: return
	for offer in person.offers:
		if offer.tier > person.level: continue
		offer.demand += int(offer.uses)*2-int(offer.stock); offer.uses = 0
	person.restocks -= 1; person.restock_time = clock; person.restock_day = day

func costs(person: Dictionary, offer: Dictionary) -> Array:
	var result: Array = []
	for cost in offer.cost:
		var n: int = clampi(int(cost[1])+int(maxf(0,floorf(float(cost[1])*float(offer.demand))*float(offer.multiplier)))+floori(-float(reputation(person))*float(offer.multiplier)),1,Nodes.max_stack(cost[0]))
		if PotionEffects.level(game.player,"hero_of_village") > 0: n = maxi(1,n-maxi(1,floori(float(cost[1])*0.3)))
		result.append([int(cost[0]),n])
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
		var previous_level: int = person.level
		game.inventory.slots = trial.slots
		offer.uses += 1; person.xp += offer.xp
		if not person.has("reputations"): person.reputations = {}
		person.reputations[game.player_id] = mini(25,reputation(person)+2)
		game.experience += randi_range(4,6)
		while int(person.level) < 5 and int(person.xp) >= VillageContent.LEVELS[int(person.level)]:
			person.level += 1; game.experience += 5; person.health = minf(20,person.health+4)
		if int(person.level) > previous_level:
			for mob in game.creatures.get_children():
				if mob is VillageMob and mob.person_key == person.key and not mob.is_queued_for_deletion(): mob.health = person.health; mob.rebuild()
		game.inventory.changed.emit(); game.sound("pickup")
	return ""

func open(mob: VillageMob) -> void:
	if mob.kind != "villager": return
	var person: Dictionary = record(mob.person_key)
	if person.is_empty() or person.profession == "unemployed" or person.get("age",0.0) > 0:
		game.toast("A child is still growing." if person.get("age",0.0) > 0 else "Place an unclaimed job block nearby to give this villager a profession."); return
	trading_key = mob.person_key
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
	game.toast("Traded %d time(s)."%amount if amount > 0 else reason)
	game.hud.show_trading(key,index)

func snapshot() -> void:
	for mob in game.creatures.get_children():
		if mob is VillageMob and not mob.is_queued_for_deletion(): mob.store_record()

func ring_bell(p: Vector3i) -> void:
	alarm = 12.0
	game.sound("pickup"); game.puff(Vector3(p)+Vector3.UP,Color("ebcc72"),20)
	game.toast("The village bell rings. Villagers seek shelter.")

func feed(mob: VillageMob) -> bool:
	var person: Dictionary = record(mob.person_key)
	var held: int = game.inventory.held().id
	if held not in [Nodes.BREAD,VillageContent.CARROT,VillageContent.POTATO,VillageContent.BEETROOT] or person.is_empty(): return false
	person.food += 4 if held == Nodes.BREAD else 1
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.puff(mob.center(),Color("e99d9c"),8)
	if person.food >= 12 and person.breed_time <= 0:
		for other in state().people.values():
			if other.key == person.key or other.dead or other.profession == "golem" or other.food < 12 or other.breed_time > 0 or vec(other.position).distance_to(mob.position) > 8: continue
			var free_bed := Vector3i.ZERO; var found: bool = false
			var base := Vector3i(mob.position.floor())
			for x in range(-12,13):
				for z in range(-12,13):
					var bed_pos := base+Vector3i(x,0,z)
					if not VillageContent.is_bed(game.world.node_at(bed_pos)) or game.world.node_at(bed_pos) != VillageContent.bed_foot(game.world.node_at(bed_pos)): continue
					if game.world.node_at(bed_pos+Vector3i.UP) != Nodes.AIR: continue
					var claimed: bool = false
					for r in state().people.values():
						if not r.dead and Vector3i(vec(r.bed)) == bed_pos: claimed = true; break
					if not claimed: free_bed = bed_pos; found = true; break
				if found: break
			if not found: game.toast("The village needs a spare bed for a child."); return true
			state().manual += 1
			var child: Dictionary = make_record("child:%d"%int(state().manual),"unemployed",mob.position+Vector3.RIGHT,base,free_bed,Vector3i(vec(person.center)))
			child.age = 1200.0; person.food -= 12; other.food -= 12; person.breed_time = 300.0; other.breed_time = 300.0
			game.toast("A baby villager joins the village!"); break
	return true

func reputation(person: Dictionary) -> int:
	return int(person.get("reputations",{}).get(game.player_id,0))

func find_work(mob: VillageMob, profession_index: int) -> Vector3i:
	var base := Vector3i(mob.position.floor())
	for x in range(-8,9):
		for z in range(-8,9):
			var p: Vector3i = base+Vector3i(x,0,z)
			if game.world.node_at(p) != VillageContent.JOBS[profession_index]: continue
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

func harvest_near(mob: VillageMob) -> void:
	var p: Vector3i = Vector3i(mob.position.floor())+Vector3i(randi_range(-2,2),0,randi_range(-2,2))
	var id: int = game.world.node_at(p)
	if id == Nodes.RIPE_WHEAT:
		game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.GRAIN,1); game.world.set_node(p,Nodes.WHEAT)
	elif VillageContent.shape(id) == "crop" and VillageContent.DATA[id].stage == 3 and VillageContent.crop_seed(id) != 0:
		for drop in VillageContent.crop_drops(id):
			var count: int = drop[1]-(1 if drop[0] == VillageContent.crop_seed(id) else 0)
			if count > 0: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,drop[0],count)
		game.world.set_node(p,id-3)

class_name VillagerSocial
extends RefCounted

static func initial() -> Dictionary:
	return {"mode":"","partner":null,"birth":null,"wait":0.0,"seek":0.0,"check":0.0,"nav_goal":null}
static func clock(game: Node3D) -> float: return float(game.villages.state().clock)
static func beds(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("villager_beds"): world.set_meta("villager_beds",{})
	return world.get_meta("villager_beds")
static func bed_changed(world: VoxelWorld, p: Vector3i) -> void:
	var id: int = world.node_at(p)
	if VillageContent.is_bed(id) and id == VillageContent.bed_foot(id): beds(world)[p] = true
	else: beds(world).erase(p)
static func bed_unload(world: VoxelWorld, column: Vector2i) -> void:
	var cells: Dictionary = beds(world)
	for p in cells.keys():
		if Vector2i(p.x >> 4,p.z >> 4) == column: cells.erase(p)
static func free_beds(game: Node3D, origin: Vector3) -> Array:
	var taken: Dictionary = {}
	for person in game.villages.state().people.values():
		if not person.get("dead",false) and person.get("bed") is Array: taken[Vector3i(VillageLife.vec(person.bed))] = true
	var result: Array = []
	for p in beds(game.world):
		var offset: Vector3 = (Vector3(p)+Vector3(0.5,0,0.5)-origin).abs()
		if taken.has(p) or offset.x > 48 or offset.y > 32 or offset.z > 48 or not game.world.loaded_at(Vector3(p)): continue
		var id: int = game.world.node_at(p)
		if VillageContent.is_bed(id) and id == VillageContent.bed_foot(id): result.append(p)
	result.sort_custom(func(a,b): return origin.distance_squared_to(Vector3(a)+Vector3(0.5,0,0.5)) < origin.distance_squared_to(Vector3(b)+Vector3(0.5,0,0.5)))
	return result.slice(0,5)
static func valid(mob: Variant) -> bool:
	return is_instance_valid(mob) and mob is VillageMob and not mob.is_queued_for_deletion() and mob.kind == "villager" and mob.health > 0
static func reset(mob: VillageMob) -> void:
	if not is_instance_valid(mob): return
	var partner: Variant = mob.social.get("partner")
	mob.social = initial(); mob.route.clear()
	if is_instance_valid(partner) and partner.social.get("partner") == mob:
		partner.social = initial(); partner.route.clear()
static func pair(a: VillageMob, b: VillageMob, mode: String, duration: float) -> bool:
	if not valid(a) or not valid(b) or a == b: return false
	if a.social.get("partner") != null or b.social.get("partner") != null: return false
	a.social = initial(); b.social = initial()
	a.social.mode = mode; b.social.mode = mode; a.social.partner = b; b.social.partner = a
	if mode == "breed": a.social.birth = duration
	else: a.social.wait = duration; b.social.wait = duration; a.social.shared = false; b.social.shared = false
	a.farmer_fields = {}; b.farmer_fields = {}; a.farmer_work = {}; b.farmer_work = {}
	a.route.clear(); b.route.clear(); a.path_timer = 0; b.path_timer = 0
	return true
static func emit_share(a: VillageMob, b: VillageMob) -> void:
	VillagerGossip.converse(a,b)
	var from: Dictionary = a.game.villages.record(a.person_key); var to: Dictionary = a.game.villages.record(b.person_key)
	for item in VillagerFood.shared_stacks(from,to):
		var drop: ItemDrop = a.game.spawn_drop(a.position+Vector3.UP*1.14,item.id,item.count,int(item.get("wear",0)),item.get("data",{}))
		drop.velocity = (b.position-a.position).normalized()*4
		drop.set_meta("villager_donor",a.get_instance_id()); drop.set_meta("villager_thrown",clock(a.game))
static func birth(a: VillageMob, b: VillageMob) -> VillageMob:
	var first: Dictionary = a.game.villages.record(a.person_key); var second: Dictionary = a.game.villages.record(b.person_key)
	VillagerFood.eat(first); VillagerFood.eat(second); VillagerFood.digest(first); VillagerFood.digest(second)
	var homes: Array = free_beds(a.game,a.position)
	if homes.is_empty():
		a.game.puff(a.center(),Color("8b8883"),5); a.game.puff(b.center(),Color("8b8883"),5)
		return null
	var child: VillageMob = a.game.spawn_creature("villager",a.position)
	if child == null: return null
	var record: Dictionary = a.game.villages.record(child.person_key); var bed: Vector3i = homes[0]
	record.bed = [bed.x,bed.y,bed.z]; record.age = 1200.0; record.center = first.center.duplicate(); record.food_level = 0
	child.bind(record); a.game.puff(child.center(),Color("ff91bd"),8)
	return child
static func courtship(timer_value: Variant, delta: float, reciprocal: bool, distance: float, navigation: bool) -> Dictionary:
	if not reciprocal: return {"active":false,"finish":false,"approach":false,"timer":null}
	var remaining: Variant = null if timer_value == null else float(timer_value)-delta
	if distance > 2.5:
		return {"active":navigation,"finish":false,"approach":navigation,"timer":remaining if navigation else null}
	var finish: bool = remaining != null and remaining <= 0
	return {"active":not finish,"finish":finish,"approach":false,"timer":null if finish else remaining}

static func step(mob: VillageMob, delta: float, eligible: bool) -> Vector3:
	if mob.social.is_empty(): mob.social = initial()
	var state: Dictionary = mob.social; state.seek -= delta; state.check -= delta
	if not eligible:
		if state.mode != "": reset(mob)
		return Vector3.INF
	var partner: Variant = state.partner
	if state.mode != "":
		if not valid(partner) or partner.social.get("partner") != mob or partner.social.get("mode","") != state.mode:
			reset(mob); return Vector3.INF
		var gap: float = mob.position.distance_to(partner.position)
		if state.mode == "breed":
			var navigation: bool = true
			if gap > 2.5 and (mob.path_timer <= 0 or mob.route.is_empty()):
				mob.path_timer = 2; mob.route = mob.path_to(partner.position); navigation = not mob.route.is_empty()
			var next: Dictionary = courtship(state.birth,delta,true,gap,navigation)
			state.birth = next.timer
			if next.finish: birth(mob,partner); reset(mob); return Vector3.INF
			if not next.active: reset(mob); return Vector3.INF
			if next.approach: return partner.position
			mob.route.clear()
			if state.birth != null and FarmerWork.rng_for(mob.game.world).integer(1,45) == 1:
				mob.game.puff(mob.center(),Color("ff91bd"),5); mob.game.puff(partner.center(),Color("ff91bd"),5)
		else:
			if not state.get("shared",false):
				if gap >= 3:
					if mob.path_timer <= 0 or mob.route.is_empty():
						mob.path_timer = 2; mob.route = mob.path_to(partner.position)
						if mob.route.is_empty(): reset(mob); return Vector3.INF
					return partner.position
				emit_share(mob,partner); state.shared = true; mob.route.clear()
			state.wait -= delta
			if state.wait <= 0: reset(mob); return Vector3.INF
		mob.model.rotation.y = lerp_angle(mob.model.rotation.y,atan2(mob.position.x-partner.position.x,mob.position.z-partner.position.z),delta*3)
		return mob.position
	var phase: float = fposmod(mob.game.day_time,1.0)
	var idle: bool = phase >= 0.2 and phase < 0.23 or phase >= 0.65 and phase <= 0.72
	var person: Dictionary = mob.game.villages.record(mob.person_key); var rng: EnchantRolls = FarmerWork.rng_for(mob.game.world)
	if idle and person.get("age",0) <= 0 and rng.integer(1,120) == 1 and state.check <= 0:
		state.check = 1.0
		if VillagerFood.possible(person,mob.sleeping):
			var mates: Array = []
			for other in mob.game.creatures.get_children():
				if not other is VillageMob or other == mob or not valid(other) or other.social.get("partner") != null or mob.position.distance_to(other.position) > 8: continue
				if VillagerFood.possible(mob.game.villages.record(other.person_key),other.sleeping) and mob._sees(other.center()): mates.append(other)
			if not mates.is_empty():
				var mate: VillageMob = mates[rng.integer(0,mates.size()-1)]
				if pair(mob,mate,"breed",rng.integer(275,325)/20.0): return mate.position
	if phase >= 0.55 and state.seek <= 0:
		state.seek = 0.05
		if rng.integer(1,120) == 1:
			var others: Array = []
			for other in mob.game.creatures.get_children():
				if other is VillageMob and other != mob and valid(other) and other.social.get("partner") == null and mob.position.distance_to(other.position) <= 16 and mob._sees(other.center()): others.append(other)
			if not others.is_empty():
				var other: VillageMob = others[rng.integer(0,others.size()-1)]
				if pair(mob,other,"share",rng.integer(40,80)/20.0): return other.position
	return Vector3.INF

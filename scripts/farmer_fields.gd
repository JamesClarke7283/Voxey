class_name FarmerFields
extends RefCounted

const TASKS = ["pace","move","farm","fertilize","visit","work"]
const WEIGHTS = [2,5,2,4,5,7]
const SEEDS = [Nodes.SEEDS,VillageContent.POTATO,VillageContent.CARROT,VillageContent.BEETROOT_SEEDS]

static func initial() -> Dictionary:
	return {"mode":"","order":[],"timers":{},"farm":false,"targets":[],"target":null,"fertilize":false,"fert_target":null,"nav_goal":null}
static func shuffle(items: Array, rng: EnchantRolls) -> void:
	for i in range(items.size()-1,0,-1):
		var j: int = rng.integer(0,i); var value: Variant = items[i]; items[i] = items[j]; items[j] = value
static func dispatch(rng: EnchantRolls) -> Array:
	var candidates: Array = []
	for i in TASKS.size(): candidates.append([-pow(rng.integer(0,2147483647)/2147483647.0,WEIGHTS[i]),TASKS[i]])
	candidates.sort_custom(func(a,b): return a[0] < b[0])
	return candidates.map(func(a): return a[1])

# Activity transitions mirror villager:farm. World/navigation calls are supplied
# separately so the actual Lua transitions can be compared without a pathfinder.
static func farm_step(state: Dictionary, delta: float, allowed: bool, sense: Callable, navigate: Callable, act: Callable) -> bool:
	if state.get("farm",false):
		state.elapsed = float(state.get("elapsed",0))+delta
		state.cooldown = float(state.get("cooldown",0))-delta
		if state.get("target") == null:
			if state.elapsed > 10:
				state.farm = false; state.target = null; return false
			if state.cooldown > 0: return true
			if state.targets.is_empty():
				var next: Array = sense.call()
				if next.is_empty(): return true
				state.targets = next
			var target: Variant = state.targets.pop_back(); state.cooldown = 0.0
			var nav: Dictionary = navigate.call(target,false)
			if nav.active: state.target = target; return true
			return false
		var nav: Dictionary = navigate.call(state.target,true)
		if nav.active: return true
		if nav.distance < 1.75: act.call(state.target)
		state.target = null; state.cooldown = 1.0
		return true
	if allowed:
		var targets: Array = sense.call()
		if not targets.is_empty():
			state.farm = true; state.targets = targets; state.target = null; state.elapsed = 0.0; state.cooldown = 0.0
			return true
	return false

static func fertilize_step(state: Dictionary, delta: float, allowed: bool, sense: Callable, navigate: Callable, act: Callable) -> bool:
	if state.get("fertilize",false):
		state.fert_elapsed = float(state.get("fert_elapsed",0))+delta
		state.fert_cooldown = float(state.get("fert_cooldown",0))-delta
		if state.fert_elapsed >= 4:
			state.fertilize = false; state.fert_target = null; return false
		var target: Variant = state.get("fert_target")
		if target == null:
			if state.fert_cooldown > 0: return true
			target = sense.call(); state.fert_cooldown = 1.0
			if target == null: return true
			if not navigate.call(target,false).active: return true
			state.fert_target = target
		var nav: Dictionary = navigate.call(target,true)
		if nav.active: return true
		if nav.distance <= 1.5: act.call(target)
		state.fert_target = null
		return true
	if allowed:
		var target: Variant = sense.call()
		if target != null and navigate.call(target,false).active:
			state.fertilize = true; state.fert_target = target; state.fert_elapsed = 0.0; state.fert_cooldown = 1.0
			return true
	return false

static func take_seed(items: Array) -> Dictionary:
	for i in items.size():
		var item: Dictionary = items[i]
		if int(item.get("id",0)) not in SEEDS or int(item.get("count",0)) <= 0: continue
		var seed: Dictionary = item.duplicate(true); seed.count = 1; item.count -= 1
		if item.count <= 0: items[i] = VillagerInventory.empty()
		return seed
	return {}
static func filter_fields(world: VoxelWorld, candidates: Array) -> Array:
	var result: Array = []
	for pos in candidates:
		if not Farmland.is_soil(world.node_at(pos)): continue
		var id: int = world.node_at(pos+Vector3i.UP)
		if id == Nodes.AIR or CropFarming.mature(id):
			result.append(pos)
			if result.size() == 5: break
	return result
static func soil_near(mob: VillageMob, harvestable: bool) -> Array:
	var origin := Vector3i(mob.position.floor()); var result: Array = []
	var radius: int = 2 if harvestable else 4
	for point in Farmland.runtime(mob.game.world).cells:
		var d: Vector3i = point-origin
		if absi(d.x) <= radius and absi(d.z) <= radius and d.y >= -2 and d.y <= (0 if harvestable else 2) and mob.game.world.loaded_at(Vector3(point)): result.append(point)
	shuffle(result,FarmerWork.rng_for(mob.game.world))
	return filter_fields(mob.game.world,result) if harvestable else result
static func immature(mob: VillageMob) -> Variant:
	var origin := Vector3i(mob.position.floor()); var result: Array = []
	for point in CropFarming.runtime(mob.game.world).cells:
		var d: Vector3i = point-origin; var id: int = mob.game.world.node_at(point)
		if absi(d.x) <= 2 and absi(d.z) <= 2 and absi(d.y) <= 1 and CropFarming.is_crop(id) and not CropFarming.mature(id): result.append(point)
	shuffle(result,FarmerWork.rng_for(mob.game.world))
	return result[0] if not result.is_empty() else null
static func farm_action(mob: VillageMob, soil: Vector3i) -> void:
	var world: VoxelWorld = mob.game.world; var above: Vector3i = soil+Vector3i.UP; var id: int = world.node_at(above)
	if not world.loaded_at(Vector3(above)): return
	if CropFarming.mature(id):
		var result: Dictionary = Harvesting.harvest(id,{"id":0})
		var drops: Array = result.drops if result.get("handled",false) else CropFarming.harvest(id)
		if world.set_node(above,Nodes.AIR):
			for drop in drops: mob.game.spawn_drop(Vector3(above)+Vector3(0.5,0.2,0.5),drop[0],drop[1])
			mob.game.sound_at("dig",Vector3(above),0.65)
	elif id == Nodes.AIR:
		var items: Array = VillagerInventory.slots(mob.game.villages.record(mob.person_key)); var seed: Dictionary = take_seed(items)
		if seed.is_empty(): return
		if Farmland.is_soil(world.node_at(soil)) and world.set_node(above,CropFarming.first(int(seed.id))): mob.game.sound_at("place",Vector3(above),0.65)
		else: VillagerInventory.add(items,seed)
static func fertilize_action(mob: VillageMob, crop: Vector3i) -> void:
	var world: VoxelWorld = mob.game.world
	if not world.loaded_at(Vector3(crop)) or not CropFarming.is_crop(world.node_at(crop)): return
	var items: Array = VillagerInventory.slots(mob.game.villages.record(mob.person_key))
	for i in items.size():
		if int(items[i].get("id",0)) != Nodes.BONE_MEAL or int(items[i].get("count",0)) <= 0: continue
		# NPCs test the callback for true. Unlike player use, a nil/no-growth
		# beetroot result does not consume their bone meal.
		var result: Dictionary = CropFarming.bone_meal(world,crop,FarmerWork.rng_for(world).native)
		if result.grew:
			items[i].count -= 1
			if items[i].count <= 0: items[i] = VillagerInventory.empty()
			mob.game.puff(Vector3(crop)+Vector3.ONE*0.5,Color("8dbb56"),5)
		return

static func navigate(mob: VillageMob, target: Vector3i, continuing: bool, soil: bool = false) -> Dictionary:
	var state: Dictionary = mob.farmer_fields
	var point: Vector3 = Vector3(target)+Vector3(0.5,1.0 if soil else 0.0,0.5)
	var distance: float = mob.position.distance_to(point)
	if not continuing:
		state.nav_goal = point; state.nav_best = INF; state.nav_stall = 0.0
		mob.destination = point; mob.path_timer = 2; mob.route = mob.path_to(point)
		return {"active":not mob.route.is_empty() or distance <= 1.5,"distance":distance}
	if distance < float(state.get("nav_best",INF))-0.03: state.nav_best = distance; state.nav_stall = 0.0
	else: state.nav_stall = float(state.get("nav_stall",0))+float(state.get("delta",0))
	var active: bool = distance > 1.0 and not mob.route.is_empty() and state.nav_stall < 2.0
	if not active: state.nav_goal = null; mob.route.clear()
	return {"active":active,"distance":distance}
static func timer(state: Dictionary, key: String, interval: float) -> bool:
	if float(state.timers.get(key,0)) > 0: return false
	state.timers[key] = interval; return true
static func task(mob: VillageMob, name: String, job: Vector3i) -> bool:
	var state: Dictionary = mob.farmer_fields; var delta: float = state.delta
	var sense: Callable = func(): return soil_near(mob,true)
	if name == "farm": return farm_step(state,delta,true,sense,func(p,c): return navigate(mob,p,c,true),func(p): farm_action(mob,p))
	if name == "fertilize":
		var has_meal: bool = VillagerInventory.count(VillagerInventory.slots(mob.game.villages.record(mob.person_key)),Nodes.BONE_MEAL) > 0
		var allowed: bool = false
		if not state.get("fertilize",false): allowed = timer(state,"fertilize",1.0) and has_meal
		return fertilize_step(state,delta,allowed,func(): return immature(mob),func(p,c): return navigate(mob,p,c),func(p): fertilize_action(mob,p))
	if name == "work":
		var active: bool = FarmerWork.tick(mob,job,delta,true,true)
		if active: state.nav_goal = null; mob.route.clear()
		return active
	if name in ["pace","move","visit"]:
		var key: String = name+"_target"
		if state.get(key) != null:
			if navigate(mob,state[key],true).active: return true
			state[key] = null; return false
		var target: Variant = null
		if name == "visit":
			var offset: Vector3 = (Vector3(job)+Vector3(0.5,0,0.5)-mob.position).abs()
			if offset.x+offset.y+offset.z <= 25 and offset.length() >= 1.73: target = job
		elif name == "move" and timer(state,"move",5.0):
			var soils: Array = soil_near(mob,false)
			if not soils.is_empty(): target = soils[FarmerWork.rng_for(mob.game.world).integer(0,soils.size()-1)]+Vector3i.UP
		elif name == "pace" and mob.position.distance_to(Vector3(job)) < 6 and timer(state,"pace",9.0):
			var rng: EnchantRolls = FarmerWork.rng_for(mob.game.world); var origin := Vector3i(mob.position.floor())
			for i in 10:
				var candidate: Vector3i = origin+Vector3i(rng.integer(-8,8),rng.integer(-6,6),rng.integer(-8,8))
				if mob.game.world.loaded_at(Vector3(candidate)) and Nodes.solid(mob.game.world.node_at(candidate+Vector3i.DOWN)) and not mob.game.world.intersects(Vector3(candidate)+Vector3(0.5,0,0.5),mob.width,mob.height): target = candidate; break
		if target != null and navigate(mob,target,false).active: state[key] = target; return true
	return false

static func task_active(mob: VillageMob, name: String) -> bool:
	if name == "farm": return mob.farmer_fields.get("farm",false)
	if name == "fertilize": return mob.farmer_fields.get("fertilize",false)
	if name == "work": return float(mob.farmer_work.get("remaining",0)) > 0
	return mob.farmer_fields.get(name+"_target") != null

static func step(mob: VillageMob, delta: float, eligible: bool) -> Vector3:
	if mob.farmer_fields.is_empty(): mob.farmer_fields = initial()
	var state: Dictionary = mob.farmer_fields; state.delta = delta
	for key in state.timers: state.timers[key] -= delta
	mob.farmer_work.check = float(mob.farmer_work.get("check",0))-delta
	if not eligible:
		if state.mode != "": mob.route.clear()
		mob.farmer_fields = initial(); mob.farmer_work.remaining = 0.0; return Vector3.INF
	var job := Vector3i(VillageLife.vec(mob.game.villages.record(mob.person_key).job))
	var engaged: bool = state.mode != ""
	if engaged:
		if not task(mob,state.mode,job): state.mode = ""; state.nav_goal = null; mob.route.clear(); return Vector3.INF
	else:
		if state.order.is_empty(): state.order = dispatch(FarmerWork.rng_for(mob.game.world))
		for name in state.order:
			state.nav_goal = null
			var was_active: bool = task_active(mob,name)
			if task(mob,name,job):
				engaged = true
				if not was_active:
					state.mode = name; state.order = dispatch(FarmerWork.rng_for(mob.game.world))
				break
	if not engaged: return Vector3.INF
	return state.nav_goal if state.nav_goal != null else mob.position

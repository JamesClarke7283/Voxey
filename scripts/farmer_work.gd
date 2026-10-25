class_name FarmerWork
extends RefCounted

static func compost(items: Array, station: Dictionary, rng: EnchantRolls) -> int:
	var budget: int = 20; var wheat: int = 0; var beetroot: int = 0; var output: int = 0
	for i in items.size():
		if budget <= 0: break
		var slot: Dictionary = items[i]; var amount: int = 0
		if slot.get("id",0) == Nodes.SEEDS:
			wheat += int(slot.count); amount = mini(int(slot.count),maxi(0,mini(wheat-10,budget)))
		elif slot.get("id",0) == VillageContent.BEETROOT_SEEDS:
			beetroot += int(slot.count); amount = mini(int(slot.count),maxi(0,mini(beetroot-10,budget)))
		budget -= amount
		for n in amount:
			var result: Dictionary = Composters.apply(station,slot.id,rng.integer(1,100),true)
			output += int(result.bone_meal)
			if result.accepted: slot.count -= 1
		if slot.get("count",0) == 0: items[i] = VillagerInventory.empty()
	return output
static func bread(items: Array) -> int:
	if VillagerInventory.count(items,Nodes.BREAD) >= 37: return 0
	var pieces: int = mini(3,VillagerInventory.count(items,Nodes.GRAIN)/3)
	if pieces <= 0: return 0
	var taken: int = VillagerInventory.take(items,Nodes.GRAIN,pieces*3)
	return VillagerInventory.add(items,{"id":Nodes.BREAD,"count":taken/3,"wear":0})
static func rng_for(world: VoxelWorld) -> EnchantRolls:
	if not world.has_meta("farmer_work_rng"):
		var random := RandomNumberGenerator.new(); random.seed = world.seed_value+443271
		world.set_meta("farmer_work_rng",EnchantRolls.new(1,random))
	return world.get_meta("farmer_work_rng")
static func use(mob: VillageMob, job: Vector3i) -> void:
	var game: Node3D = mob.game; var person: Dictionary = game.villages.record(mob.person_key)
	var items: Array = VillagerInventory.slots(person)
	var meal: int = compost(items,game.world.get_station(job,"composter"),rng_for(game.world))
	for n in meal: game.spawn_drop(Vector3(job)+Vector3(0.5,0.5,0.5),Nodes.BONE_MEAL)
	var overflow: int = bread(items)
	if overflow > 0: game.spawn_drop(mob.position,Nodes.BREAD,overflow)
	game.villages.restock(person,float(game.villages.state().clock),game.day_number())
	game.survival.refresh_displays()
static func tick(mob: VillageMob, job: Vector3i, delta: float, eligible: bool, elapsed: bool = false) -> bool:
	var state: Dictionary = mob.farmer_work
	if not elapsed: state.check = float(state.get("check",0))-delta
	var distance: float = mob.position.distance_to(Vector3(job)+Vector3(0.5,0,0.5))
	if float(state.get("remaining",0)) > 0:
		state.remaining -= delta
		if not eligible or distance >= 1.73: state.remaining = 0
		return state.remaining > 0
	if not eligible: return false
	var rng: EnchantRolls = rng_for(mob.game.world)
	if rng.integer(1,2) != 1 or state.check > 0: return false
	state.check = 15.0
	if distance >= 1.73: return false
	use(mob,job); state.remaining = 10+rng.integer(0,10)
	return true

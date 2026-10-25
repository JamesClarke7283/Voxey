extends RefCounted
static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var old_pos: Vector3 = game.player.position; var old_time: float = game.day_time; var old_mode: String = game.gamemode
	var people: Dictionary = game.villages.state().people.duplicate(true)
	for mob in game.creatures.get_children(): mob.free()
	for drop in game.drops.get_children(): drop.free()
	game.villages.state().people = {}; game.gamemode = "creative"; game.day_time = 0.35
	for x in range(4,23):
		for z in range(4,18):
			for y in range(1999,2004): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 1999 else Nodes.AIR)
	var job := Vector3i(8,2000,8); var soil := Vector3i(10,1999,8); var crop: Vector3i = soil+Vector3i.UP
	game.world.set_node(job,VillageContent.COMPOSTER); game.world.set_node(soil,Farmland.WET)
	var farmer: VillageMob = game.spawn_creature("villager",Vector3(9.5,2000,8.5)); farmer.set_physics_process(false)
	var person: Dictionary = game.villages.record(farmer.person_key); person.profession = "farmer"; person.job = [job.x,job.y,job.z]; farmer.bind(person)
	var items: Array = VillagerInventory.slots(person)
	game.player.position = Vector3(20,2000,12)
	game.world.set_node(crop,Nodes.RIPE_WHEAT)
	FarmerFields.farm_action(farmer,soil)
	t.check(game.world.node_at(crop) == Nodes.AIR,"harvesting a mature field removes the crop without automatically replanting it")
	t.check(game.drops.get_children().any(func(d): return d.item_id == Nodes.GRAIN) and game.drops.get_children().any(func(d): return d.item_id == Nodes.SEEDS),"a farmer's harvest creates the source wheat and seed pickups")
	FarmerFields.farm_action(farmer,soil)
	t.check(game.world.node_at(crop) == Nodes.AIR,"an empty field stays empty when its farmer has no seed")
	VillagerInventory.add(items,{"id":VillageContent.POTATO,"count":2,"wear":0,"data":{"custom_name":"Seed potato"}})
	FarmerFields.farm_action(farmer,soil)
	t.check(game.world.node_at(crop) == CropFarming.first(VillageContent.POTATO) and VillagerInventory.count(items,VillageContent.POTATO) == 1,"planting selects a carried crop item and consumes exactly one")
	game.world.set_node(crop,Nodes.AIR); game.world.set_node(soil,Nodes.DIRT)
	FarmerFields.farm_action(farmer,soil)
	t.check(game.world.node_at(crop) == Nodes.AIR and VillagerInventory.count(items,VillageContent.POTATO) == 1,"a seed is returned if the soil disappears before planting")
	game.world.set_node(soil,Farmland.WET); game.world.set_node(crop,Nodes.STONE)
	FarmerFields.farm_action(farmer,soil)
	t.check(game.world.node_at(crop) == Nodes.STONE and VillagerInventory.count(items,VillageContent.POTATO) == 1,"an occupied field is left untouched and consumes no seed")
	game.world.set_node(crop,Nodes.WHEAT); VillagerInventory.add(items,{"id":Nodes.BONE_MEAL,"count":3,"wear":0})
	FarmerFields.fertilize_action(farmer,crop)
	t.check(CropFarming.stage(game.world.node_at(crop)) > 1 and VillagerInventory.count(items,Nodes.BONE_MEAL) == 2,"a farmer uses carried bone meal to advance an immature crop")
	game.world.set_node(crop,CropFarming.first(VillageContent.BEETROOT_SEEDS))
	var random: RandomNumberGenerator = FarmerWork.rng_for(game.world).native
	var empty_seed: int = 0
	for seed in range(1,1000):
		random.seed = seed
		if random.randi_range(1,100) > 75: empty_seed = seed; break
	random.seed = empty_seed; FarmerFields.fertilize_action(farmer,crop)
	t.check(game.world.node_at(crop) == CropFarming.first(VillageContent.BEETROOT_SEEDS) and VillagerInventory.count(items,Nodes.BONE_MEAL) == 2,"a beetroot callback with no growth does not consume the farmer's bone meal")
	game.world.set_node(crop,Nodes.RIPE_WHEAT); FarmerFields.fertilize_action(farmer,crop)
	t.check(VillagerInventory.count(items,Nodes.BONE_MEAL) == 2,"a mature crop does not spend the farmer's bone meal")
	# Sensors use the source box limits and cap the next harvest batch at five.
	var candidates: Array = []
	for x in range(9,16):
		var p := Vector3i(x,1999,11); candidates.append(p); game.world.set_node(p,Farmland.DRY); game.world.set_node(p+Vector3i.UP,Nodes.AIR)
	t.check(FarmerFields.filter_fields(game.world,candidates).size() == 5,"a harvestable-field sensor returns at most five valid plots")
	game.world.set_node(candidates[0]+Vector3i.UP,Nodes.WHEAT)
	t.check(candidates[0] not in FarmerFields.filter_fields(game.world,candidates),"the harvest sensor excludes immature crops")
	farmer.position = Vector3(10.5,2000,8.5)
	var near: Array = FarmerFields.soil_near(farmer,true)
	t.check(near.all(func(p): return abs(p.x-10) <= 2 and abs(p.z-8) <= 2 and p.y >= 1998 and p.y <= 2000),"the harvest sensor stays inside the source horizontal and vertical search limits")
	# Run the actual mob loop: a grown crop is harvested, its items age and are
	# picked up, then a later action consumes a seed to plant a new crop.
	for p in candidates: game.world.set_node(p+Vector3i.UP,Nodes.STONE)
	for drop in game.drops.get_children(): drop.free()
	person.inventory = VillagerInventory.clean([]); items = person.inventory
	game.world.set_node(crop,Nodes.RIPE_WHEAT); farmer.position = Vector3(9.5,2000,8.5)
	farmer.farmer_fields = FarmerFields.initial(); farmer.farmer_fields.order = ["farm"]; farmer.farmer_work = {}
	game.state = "playing"
	for i in 130:
		for drop in game.drops.get_children():
			if not drop.is_queued_for_deletion(): drop.age += 0.05
		farmer._physics_process(0.05)
	t.check(game.world.node_at(crop) == Nodes.WHEAT and VillagerInventory.count(items,Nodes.GRAIN) >= 1,"the real farmer loop harvests, collects the crop, and later replants using its own seed")
	t.check(farmer.farmer_fields.get("elapsed",0) < 10 and farmer.farmer_fields.get("farm",false),"the farmer retains its field activity while the ten-second bout is active")
	var before: int = game.world.node_at(crop); game.day_time = 0.85; farmer._physics_process(0.1)
	t.check(farmer.farmer_fields.mode == "" and game.world.node_at(crop) == before,"nighttime stops field work without removing an unfinished crop")
	game.day_time = 0.35; person.age = 100; farmer._physics_process(0.1)
	t.check(farmer.farmer_fields.mode == "","young villagers do not start adult field work")
	person.age = 0
	t.check(not person.has("farmer_fields"),"field navigation and activity timers are transient rather than saved in the villager record")
	for mob in game.creatures.get_children(): mob.free()
	for drop in game.drops.get_children(): drop.free()
	for x in range(4,23):
		for z in range(4,18):
			for y in range(1999,2004): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.villages.state().people = people; game.player.position = old_pos; game.day_time = old_time; game.gamemode = old_mode
	game.pause(); game.set_process(false); game.world.set_process(false)

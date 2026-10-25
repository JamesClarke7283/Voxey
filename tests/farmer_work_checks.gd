extends RefCounted
static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var old_pos: Vector3 = game.player.position; var old_time: float = game.day_time; var old_mode: String = game.gamemode
	var old_people: Dictionary = game.villages.state().people.duplicate(true)
	for mob in game.creatures.get_children(): mob.free()
	game.villages.state().people = {}; game.day_time = 0.35; game.gamemode = "survival"
	for x in range(4,23):
		for z in range(4,16):
			for y in range(1999,2003): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 1999 else Nodes.AIR)
	var pos := Vector3i(8,2000,8); game.world.set_node(pos,VillageContent.COMPOSTER)
	game.player.position = Vector3(20,2000,12)
	var farmer: VillageMob = game.spawn_creature("villager",Vector3(10,2000,8.5)); farmer.set_physics_process(false)
	var person: Dictionary = game.villages.record(farmer.person_key)
	person.profession = "farmer"; person.job = [8,2000,8]; farmer.bind(person)
	var slots: Array = VillagerInventory.slots(person)
	t.check(slots.size() == 8 and slots.all(func(s): return s.id == 0),"old and new villager records receive eight empty inventory slots")
	var drop: ItemDrop = game.spawn_drop(farmer.position,Nodes.SEEDS,40); drop.age = 0.99; drop.set_process(false)
	VillagerInventory.pickup(farmer)
	t.check(VillagerInventory.count(slots,Nodes.SEEDS) == 0,"farmers do not take dropped items before the source's one-second age gate")
	drop.age = 1; VillagerInventory.pickup(farmer)
	t.check(drop.is_queued_for_deletion() and VillagerInventory.count(slots,Nodes.SEEDS) == 40,"a farmer picks up a nearby aged seed stack into its private inventory")
	var outsider: VillageMob = game.spawn_creature("villager",Vector3(18,2000,8)); outsider.set_physics_process(false)
	var unused: ItemDrop = game.spawn_drop(outsider.position,Nodes.SEEDS,5); unused.age = 2; unused.set_process(false)
	VillagerInventory.pickup(outsider)
	t.check(not unused.is_queued_for_deletion(),"unemployed villagers leave farming-only seeds on the ground")
	var food: ItemDrop = game.spawn_drop(outsider.position,Nodes.BREAD,3,0,{"custom_name":"Seed loaf"}); food.age = 2; food.set_process(false)
	VillagerInventory.pickup(outsider)
	var other_slots: Array = VillagerInventory.slots(game.villages.record(outsider.person_key))
	t.check(food.is_queued_for_deletion() and other_slots[0].data.custom_name == "Seed loaf","ordinary villagers collect food and preserve stack metadata")
	var full: Array = VillagerInventory.clean([])
	for i in 8: full[i] = {"id":Nodes.STONE,"count":64,"wear":0}
	full[0] = {"id":Nodes.SEEDS,"count":54,"wear":0}; full[1] = {"id":Nodes.SEEDS,"count":54,"wear":0}
	t.check(not VillagerInventory.space(full,{"id":Nodes.SEEDS,"count":20,"wear":0}),"pickup requires the whole incoming stack to fit one slot, as in the source")
	var station: Dictionary = game.world.get_station(pos,"composter"); station.compost = 7; station.maturation = 0.2
	VillagerInventory.add(slots,{"id":VillageContent.BEETROOT_SEEDS,"count":40,"wear":0})
	var output: int = FarmerWork.compost(slots,station,EnchantRolls.new(5))
	t.check(VillagerInventory.count(slots,Nodes.SEEDS) == 20 and VillagerInventory.count(slots,VillageContent.BEETROOT_SEEDS) == 40,"one work visit composts at most twenty seeds in inventory order")
	t.check(output >= 1,"farmer input can immediately empty a full composter before consuming the next seed")
	FarmerWork.compost(slots,station,EnchantRolls.new(7)); FarmerWork.compost(slots,station,EnchantRolls.new(9))
	t.check(VillagerInventory.count(slots,Nodes.SEEDS) == 10 and VillagerInventory.count(slots,VillageContent.BEETROOT_SEEDS) == 10,"repeated work keeps ten seeds of each compostable crop")
	person.inventory = VillagerInventory.clean([]); slots = person.inventory
	VillagerInventory.add(slots,{"id":Nodes.GRAIN,"count":12,"wear":0}); VillagerInventory.add(slots,{"id":Nodes.SEEDS,"count":40,"wear":0})
	station.compost = 0; farmer.position = Vector3(pos)+Vector3(1.5,0,0.5); farmer.farmer_work = {}
	game.state = "playing"; farmer.farmer_fields = FarmerFields.initial(); farmer.farmer_fields.order = ["work"]
	for i in 200:
		farmer._physics_process(0.05)
		if farmer.farmer_work.get("remaining",0) > 0: break
	t.check(VillagerInventory.count(slots,Nodes.BREAD) == 3 and VillagerInventory.count(slots,Nodes.GRAIN) == 3,"the live workplace task crafts at most three bread from nine wheat")
	t.check(VillagerInventory.count(slots,Nodes.SEEDS) == 20 and farmer.farmer_work.get("remaining",0) >= 10,"the live workplace task composts once, then stays busy for ten to twenty seconds")
	var work_left: int = VillagerInventory.count(slots,Nodes.SEEDS)
	farmer._physics_process(0.05)
	t.check(VillagerInventory.count(slots,Nodes.SEEDS) == work_left,"an active workstation visit does not repeatedly compost its inventory")
	farmer.position += Vector3.RIGHT*5; FarmerWork.tick(farmer,pos,0.5,true)
	t.check(farmer.farmer_work.get("remaining",0) <= 0,"moving away from the workstation ends the work activity")
	# Source nodeboxes leave a hollow mouth and have a rising bottom.
	station.compost = 0
	t.check(not game.world.intersects(Vector3(pos)+Vector3(0.5,0.1,0.5),0.2,0.5),"an empty composter has a hollow collision volume")
	t.check(game.world.intersects(Vector3(pos)+Vector3(0.03,0.1,0.5),0.02,0.5),"a composter's narrow wooden wall remains solid")
	station.compost = 7; station.maturation = 0.2; station.compost_version = 2
	t.check(game.world.intersects(Vector3(pos)+Vector3(0.5,0.1,0.5),0.2,0.5),"full compost raises the collision floor with the visible fill level")
	Composters.column_loaded(game.world,Vector2i(0,0))
	t.check(station.maturation == 1.0,"loading a column restarts a full composter's source maturation timer")
	var legacy: Dictionary = {"compost":7}; Composters.restore_state(legacy)
	t.check(Composters.level(legacy) == 8,"old immediately-ready level-seven saves migrate to the ready state")
	t.check(Nodes.fuel_time(VillageContent.COMPOSTER) == 15 and Fire.flammable(VillageContent.COMPOSTER),"composters retain the source wood fuel time and flammability")
	var inv := Inventory.new(); var oak: int = BuildingShapes.slab_for(Nodes.PLANKS); var spruce: int = BuildingShapes.slab_for(WoodTypes.planks_id(1))
	inv.add_item(oak,3); inv.add_item(spruce,4)
	t.check(inv.craft(inv.recipe_index(VillageContent.COMPOSTER),"table"),"mixed wooden slab species satisfy the existing group-based composter recipe")
	var snapshot: Array = slots.duplicate(true); var key: String = farmer.person_key
	farmer.position = Vector3(pos)+Vector3(1.5,0,0.5); farmer.store_record(); station.maturation = 0.2
	game.save_game(); var saved: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	var freeze: Callable = func(node):
		if node is Creature: node.ready.connect(func(): node.set_physics_process(false),CONNECT_ONE_SHOT)
	game.creatures.child_entered_tree.connect(freeze); game.load_world_data(saved); game.villages.timer = 100; game.set_process(true); game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.creatures.child_entered_tree.disconnect(freeze); game.pause(); game.set_process(false); game.world.set_process(false)
	var restored: Dictionary = game.villages.record(key)
	t.check(VillagerInventory.clean(restored.get("inventory",[])) == snapshot,"an actual world save and reload preserves the villager's complete private inventory")
	var restored_station: Dictionary = game.world.get_station(pos,"composter")
	t.check(Composters.level(restored_station) == 7 and restored_station.get("maturation",0) > 0.7,"world reload restarts rather than resumes the source composter maturation delay")
	Composters.step(restored_station,1)
	t.check(Composters.level(restored_station) == 8,"a reloaded full composter becomes ready after its new one-second delay")
	var infected: Creature = game.spawn_creature("zombie_villager",Vector3(pos),"",{"baby":false,"jockey":false}); infected.set_physics_process(false)
	ZombieVillagers.infect(game,infected,restored)
	t.check(not infected.get_meta("incarnation").has("inventory"),"infection omits the private inventory from the source's preserved villager identity")
	for mob in game.creatures.get_children(): mob.free()
	for x in range(4,23):
		for z in range(4,16):
			for y in range(1999,2003): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.villages.timer = 0; game.villages.state().people = old_people; game.player.position = old_pos; game.day_time = old_time; game.gamemode = old_mode

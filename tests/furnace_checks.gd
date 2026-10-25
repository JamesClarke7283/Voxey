extends RefCounted

static func empty() -> Dictionary: return {"id":0,"count":0,"wear":0}
static func fresh(world: VoxelWorld, p: Vector3i, device: int, input: int = 0, count: int = 1, fuel: int = Nodes.COAL) -> Dictionary:
	world.set_node(p,device); world.stations.erase(VoxelWorld.station_key(p))
	var station: Dictionary = world.get_station(p,"furnace")
	station.slots = [{"id":input,"count":count if input else 0,"wear":0},{"id":fuel,"count":1 if fuel else 0,"wear":0},empty()]
	return station

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var inventory: Array = game.inventory.slots.duplicate(true); var xp: float = game.experience
	var player_at: Vector3 = game.player.position
	var old_selected: int = game.inventory.selected
	var old_time: float = game.day_time
	var old_stations: Dictionary = game.world.stations; var old_growth: Dictionary = game.world.growth
	var world: VoxelWorld = game.world; world.stations = {}; world.growth = {}
	var p := Vector3i(8,1700,8); game.player.position = Vector3(8,1700,12)
	for x in range(6,11):
		for z in range(6,11):
			world.set_node(Vector3i(x,1699,z),Nodes.STONE)
	var rows: Array = [[Nodes.FURNACE,Nodes.IRON_ORE,Nodes.IRON,10],[VillageContent.BLAST_FURNACE,RawOres.RAW_IRON,Nodes.IRON,5],[VillageContent.SMOKER,VillageContent.RAW_BEEF,VillageContent.COOKED_BEEF,5],[VillageContent.BLAST_FURNACE,Nodes.COAL_ORE,Nodes.COAL,5],[VillageContent.BLAST_FURNACE,MobArmor.COPPER_HELMET,RawOres.COPPER_NUGGET,5],[Nodes.FURNACE,Nodes.STONE,Masonry.SMOOTH_STONE,10],[Nodes.FURNACE,Nodes.SANDSTONE,Masonry.SMOOTH_SANDSTONE,10],[VillageContent.BLAST_FURNACE,1113,Nodes.GOLD_NUGGET,5]]
	for row in rows:
		var station: Dictionary = fresh(world,p,row[0],row[1])
		for i in int(row[3])-1: world._simulate()
		t.check(station.slots[2].id == 0 and station.slots[0].id == row[1],"registered furnace duration before completion: "+str(row))
		world._simulate()
		t.check(station.slots[2].id == row[2] and station.slots[2].count == 1 and station.slots[0].id == 0 and station.xp == 1,"registered furnace result and XP: "+str(row))
		t.check(Pasture.emission(world,p) == 13 and FurnaceRules.burning(station),"active normal/fast furnace emits source light: "+str(row[0]))
	for device in [VillageContent.BLAST_FURNACE,VillageContent.SMOKER]:
		var invalid: Dictionary = fresh(world,p,device,Nodes.SAND)
		for i in 12: world._simulate()
		t.check(invalid.slots[0].id == Nodes.SAND and invalid.slots[1].count == 1 and invalid.slots[2].id == 0,"device groups reject ineligible cooking without spending fuel: "+str(device))
	var timed: Dictionary = fresh(world,p,Nodes.FURNACE,Nodes.IRON_ORE)
	timed.last_gametime = 100.0; game.day_time = 101.0/1200.0; world._simulate(true)
	game.day_time = 106.0/1200.0; world._simulate(true)
	t.check(is_equal_approx(timed.progress,6.0) and is_equal_approx(timed.burn,75.0),"the real furnace tick follows elapsed game time across a clock jump")
	var station: Dictionary = fresh(world,p,Nodes.FURNACE,Nodes.IRON_ORE,2)
	for i in 4: world._simulate()
	station.slots[2] = {"id":Nodes.DIRT,"count":1,"wear":0}; world._simulate()
	t.check(station.progress == 4 and station.burn == 76,"occupied output pauses progress while the coal keeps burning")
	station.slots[2] = empty(); world._simulate()
	t.check(station.progress == 5,"clearing output resumes existing progress")
	station.slots[0] = {"id":Nodes.SAND,"count":1,"wear":0}; world._simulate()
	t.check(station.progress == 1 and station.src_item == "mcl_core:sand","changing source item resets progress before cooking the new item")
	game.open_inventory("furnace",p); game.hud.cursor = {"id":Nodes.DIRT,"count":3,"wear":0}
	var before_time: float = game.day_time; game._process(0.5)
	t.check(is_equal_approx(game.day_time,before_time+0.5/1200.0),"the game clock advances while a furnace screen is open")
	game.hud._populate_recipes()
	t.check(game.hud.recipe_list.get_children().all(func(button): return FurnaceRules.cookable(int(button.get_meta("furnace_input",0)),Nodes.FURNACE)),"the furnace recipe guide contains cooking inputs for this device")
	game.hud._furnace_tab(true)
	t.check(game.hud.recipe_list.get_children().all(func(button): return Nodes.fuel_time(int(button.get_meta("furnace_input",0))) > 0),"the fuel tab contains registered fuels")
	game.hud._furnace_tab(false)
	game.hud._slot_click(0,true,false)
	t.check(station.slots[0].id == Nodes.DIRT and station.slots[0].count == 3 and game.hud.cursor.id == Nodes.SAND,"manual source insertion accepts ordinary non-cookable items")
	game.hud.cursor = empty(); station = fresh(world,p,Nodes.FURNACE); game.hud.station_data = station
	game.hud.cursor = {"id":Nodes.BUCKET,"count":3,"wear":0}; game.hud._slot_click(1,true,false)
	t.check(station.slots[1].id == Nodes.COAL and game.hud.cursor.count == 3,"an occupied fuel slot rejects an empty bucket")
	station.slots[1] = empty(); game.hud._slot_click(1,true,false)
	t.check(station.slots[1].id == Nodes.BUCKET and station.slots[1].count == 1 and game.hud.cursor.count == 2,"manual fuel insertion accepts one empty bucket for sponge drying")
	game.hud.cursor = empty(); station = fresh(world,p,Nodes.FURNACE,Sponges.WET,1,Nodes.LAVA_BUCKET); game.hud.station_data = station
	for i in 10: world._simulate()
	t.check(station.slots[2].id == Sponges.SPONGE and station.slots[1].id == Nodes.WATER_BUCKET,"lava fuel returns its bucket and a wet sponge fills it")
	station.slots[2] = {"id":Nodes.IRON,"count":2,"wear":0}; station.xp = 7
	var before: float = game.experience; game.hud._slot_click(2,true,true)
	t.check(game.experience == before+7 and not station.has("xp") and game.hud.cursor.count == 1,"taking part of the output pays the whole stored source XP once")
	game.hud.cursor = empty(); game.inventory.restore([])
	game.inventory.selected = 0
	game.inventory.slots[0] = {"id":CopperTools.FIRST,"count":1,"wear":0,"data":{"enchantments":{"Mending":1}}}
	Durability.set_normalized(game.inventory.slots[0],20000)
	station.slots[2] = {"id":Nodes.IRON,"count":1,"wear":0}; station.xp = 2; before = game.experience
	game.hud._slot_click(2,true,false)
	t.check(game.experience == before and Durability.normalized(game.inventory.slots[0]) < 20000,"furnace XP repairs worn Mending equipment while its inventory is open")
	game.hud.cursor = empty(); game.inventory.restore([]); game.inventory.slots[0] = {"id":Nodes.LOG,"count":3,"wear":0}
	station = fresh(world,p,Nodes.FURNACE,Nodes.COBBLE,64,0); game.hud.station_data = station; game.hud.shift_mode = true
	game.hud._slot_click(0,false,false); game.hud.shift_mode = false
	t.check(station.slots[1].id == Nodes.LOG and station.slots[1].count == 3 and game.inventory.slots[0].id == 0,"quick move routes burnable cooking material to fuel when source is full")
	game.hud.cursor = empty(); game.pause()
	# Top hoppers accept any item and ignore whether output is occupied.
	var hopper := p+Vector3i.UP; world.set_node(hopper,Nodes.HOPPER); world.circuits.configure(hopper,Vector3i.DOWN)
	station = fresh(world,p,Nodes.FURNACE,0,0,0); station.slots[2] = {"id":Nodes.IRON,"count":64,"wear":0}
	var hopper_slots: Array = world.circuits.container(hopper); hopper_slots[0] = {"id":Nodes.DIRT,"count":1,"wear":0}
	t.check(world.circuits.hopper(hopper) and station.slots[0].id == Nodes.DIRT,"top hopper can insert a non-cookable item even when output is full")
	world.set_node(hopper,Nodes.AIR)
	station = fresh(world,p,VillageContent.BLAST_FURNACE,RawOres.RAW_IRON,2)
	world._simulate(); world._simulate()
	var saved_progress: float = station.progress; var saved_burn: float = station.burn
	game.save_game(); var saved: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	game.load_world_data(saved); game.set_process(true); game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false); world = game.world
	station = world.get_station(p,"furnace")
	t.check(station.device == VillageContent.BLAST_FURNACE and is_equal_approx(station.progress,saved_progress) and is_equal_approx(station.burn,saved_burn),"world reload preserves cooking progress, fuel and device type")
	for i in 3: world._simulate()
	t.check(station.slots[2].id == Nodes.IRON and station.slots[2].count == 1 and station.slots[0].count == 1,"a reloaded blast furnace finishes its partly cooked item at the source time")
	var recipe: Dictionary = game.inventory.recipes[game.inventory.recipe_index(VillageContent.BLAST_FURNACE)]
	t.check(recipe.ingredients.get(Masonry.SMOOTH_STONE,0) == 3 and not recipe.ingredients.has(Nodes.STONE),"blast furnace crafting uses three actual smooth-stone blocks")
	game.inventory.slots = inventory; game.inventory.selected = old_selected; game.experience = xp; game.player.position = player_at; game.day_time = old_time; world.stations = old_stations; world.growth = old_growth
	for x in range(6,11):
		for z in range(6,11): world.set_node(Vector3i(x,1699,z),Nodes.AIR)
	world.set_node(p,Nodes.AIR)

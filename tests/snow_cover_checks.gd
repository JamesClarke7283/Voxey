extends RefCounted

static func drop_count(game: Node3D, id: int) -> int:
	var count: int = 0
	for item in game.drops.get_children():
		if not item.is_queued_for_deletion() and item.item_id == id: count += item.amount
	return count

static func held(game: Node3D, id: int, amount: int = 16, enchantments: Dictionary = {}) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":amount,"wear":0,"data":{"enchantments":enchantments}}

static func click(game: Node3D, aim: Vector3) -> void:
	game.player.camera.look_at(aim); game.player.use_cooldown = 0; game.player.use_latched = false
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = down
		event.position = game.get_viewport().get_visible_rect().size*0.5; event.global_position = event.position
		Input.parse_input_event(event); Input.flush_buffered_events(); game.player._process(0.016)

static func seed_for(value: int) -> int:
	var rng := RandomNumberGenerator.new()
	for i in 10000:
		rng.seed = i
		if rng.randi_range(1,SnowCover.MELT_CHANCE) == value: return i
	return -1

static func placement_checks(suite: SceneTree, game: Node3D, p: Vector3i) -> void:
	# Exercise the live use dispatch; these handlers occur before or beside the
	# ordinary-block placement path and must use snow's replacement support.
	for entry in [[Nodes.TORCH,Nodes.TORCH,Nodes.STONE],[Nodes.WATER_BUCKET,Nodes.WATER,Nodes.STONE],[Nodes.LAVA_BUCKET,Nodes.LAVA,Nodes.STONE],[VillageContent.COD_BUCKET,Nodes.WATER,Nodes.STONE],[Nodes.SAPLING,Nodes.SAPLING,Nodes.GRASS],[Nodes.RED_MUSHROOM,Nodes.RED_MUSHROOM,Nodes.DIRT],[Nodes.SEEDS,Nodes.WHEAT,Nodes.FARMLAND],[VillageContent.CARROT,VillageContent.CROPS[VillageContent.CARROT],Nodes.FARMLAND]]:
		game.world.set_node(p,Nodes.AIR); game.world.set_node(p+Vector3i.UP,Nodes.AIR); game.world.set_node(p+Vector3i.UP*2,Nodes.AIR)
		game.world.set_node(p+Vector3i.DOWN,entry[2]); game.world.set_node(p,SnowCover.BASE)
		held(game,entry[0],3); click(game,Vector3(p)+Vector3(0.5,0.12,0.5))
		suite.check(game.world.node_at(p) == entry[1] and game.world.node_at(p+Vector3i.UP) == Nodes.AIR and game.inventory.count_item(entry[0]) == 2,"live "+Nodes.title(entry[0])+" placement replaces snow using the actual support block")
	# Placement checks must not turn into right-clicking a hidden workstation.
	game.world.set_node(p,Nodes.AIR); game.world.set_node(p+Vector3i.DOWN,Nodes.CHEST); game.world.set_node(p,SnowCover.BASE)
	held(game,Nodes.TORCH,3); click(game,Vector3(p)+Vector3(0.5,0.12,0.5))
	suite.check(game.state == "playing" and game.world.node_at(p) == Nodes.TORCH and game.world.node_at(p+Vector3i.DOWN) == Nodes.CHEST,"snow replacement does not open the chest hidden underneath")
	game.world.set_node(p,Nodes.AIR); game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	for door in [VillageContent.WOODEN_DOOR,Nodes.IRON_DOOR]:
		game.world.set_node(p,SnowCover.BASE); held(game,door,3)
		click(game,Vector3(p)+Vector3(0.5,0.12,0.5))
		var lower: int = game.world.node_at(p)
		suite.check(Doors.is_door(lower) and Doors.item(lower) == door and not Doors.upper(lower) and Doors.matching_pair(game.world,p,lower) and game.world.node_at(p+Vector3i.UP*2) == Nodes.AIR and game.inventory.count_item(door) == 2,"live "+Nodes.title(door)+" replaces snow without a floating lower half")
		game.world.set_node(p+Vector3i.UP,Nodes.AIR); game.world.set_node(p,Nodes.AIR)
	var colored_bed: int = 0
	for id in VillageContent.DATA:
		if VillageContent.is_bed(id) and VillageContent.bed_foot(id) == id and id not in [Nodes.BED_FOOT,Nodes.BED_HEAD]: colored_bed = id; break
	for bed in [Nodes.BED_FOOT,colored_bed]:
		var head: Vector3i = p+Vector3i.FORWARD
		game.world.set_node(head+Vector3i.DOWN,Nodes.STONE)
		game.world.set_node(p,SnowCover.BASE); game.world.set_node(head,SnowCover.BASE+1)
		held(game,bed,3); click(game,Vector3(p)+Vector3(0.5,0.12,0.5))
		var expected_head: int = Nodes.BED_HEAD if bed == Nodes.BED_FOOT else VillageContent.bed_head(bed)
		suite.check(game.world.node_at(p) == bed and game.world.node_at(head) == expected_head and game.inventory.count_item(bed) == 2,"live "+Nodes.title(bed)+" replaces snow in both bed cells")
		game.world.set_node(p,Nodes.AIR); game.world.set_node(head,Nodes.AIR)

static func run(suite: SceneTree, game: Node3D) -> void:
	game._clear_entities(); await suite.process_frame
	game.state = "playing"; game.gamemode = "survival"; game.daylight = 1
	game.player.set_process(false); game.player.set_physics_process(false)
	game.world.active = false; game.world.set_process(false); game.player.eating.clear()
	for x in range(2,15):
		for z in range(2,15):
			for y in range(499,506): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 499 else Nodes.AIR)
	game.player.position = Vector3(8.5,500.01,12.5); game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO; game.player.camera.position.y = 1.62
	var p := Vector3i(8,500,8)
	suite.check(Nodes.exists(SnowCover.BASE) and Nodes.all_ids().has(SnowCover.BASE) and not Nodes.all_ids().has(SnowCover.BASE+1),"top snow has one usable inventory item and hidden layer states")
	suite.check(Nodes.max_stack(SnowCover.BASE) == 64 and Nodes.placeable(SnowCover.BASE),"top snow is a stackable placeable building item")
	for layer in range(1,9):
		var id: int = SnowCover.BASE+layer-1
		game.world.set_node(p,id)
		suite.check(Nodes.solid(id) == (layer > 1) and SnowCover.boxes(id).size() == (1 if layer > 1 else 0),"snow layer "+str(layer)+" uses source walkability")
		var ray: Dictionary = game.world.raycast(Vector3(p)+Vector3(0.5,2,0.5),Vector3.DOWN,3)
		suite.check(not ray.is_empty() and ray.pos == p and absf(ray.point.y-(p.y+layer/8.0)) < 0.001,"snow layer "+str(layer)+" selects its actual top surface")
		var intersects: bool = game.world.intersects(Vector3(p)+Vector3(0.5,0.01,0.5),0.1,0.08)
		suite.check(intersects == (layer > 1) and not game.world.intersects(Vector3(p)+Vector3(0.5,layer/8.0+0.01,0.5),0.1,0.08),"snow layer "+str(layer)+" has matching partial-height collision")
		var out: Array = BlockMesher._empty(); SnowCover.mesh(out,Vector3.ZERO,id)
		var highest: float = 0
		for vertex in out[0]: highest = maxf(highest,vertex.y)
		suite.check(not out[0].is_empty() and is_equal_approx(highest,layer/8.0) and not SnowCover.icon_faces(id).is_empty(),"snow layer "+str(layer)+" renders original snow texture at the correct height")
	game.world.set_node(p,Nodes.AIR); held(game,SnowCover.BASE,16)
	for layer in range(1,9):
		click(game,Vector3(p)+Vector3(0.5,(layer-1)/8.0-0.01,0.5))
		suite.check(game.world.node_at(p) == SnowCover.BASE+layer-1 and game.inventory.count_item(SnowCover.BASE) == 16-layer,"live snow placement stacks to layer "+str(layer)+" and consumes one item")
	click(game,Vector3(p)+Vector3(0.5,0.99,0.5))
	suite.check(game.world.node_at(p+Vector3i.UP) == SnowCover.BASE and game.inventory.count_item(SnowCover.BASE) == 7,"placing onto eight layers starts a new snow layer above")
	game.gamemode = "creative"; click(game,Vector3(p)+Vector3(0.5,1.1,0.5))
	suite.check(game.world.node_at(p+Vector3i.UP) == SnowCover.BASE+1 and game.inventory.count_item(SnowCover.BASE) == 7,"creative snow stacking preserves the held count")
	game.gamemode = "survival"
	# Ordinary blocks replace buildable-to snow rather than floating on its edge.
	held(game,Nodes.COBBLE,3); click(game,Vector3(p)+Vector3(0.5,1.24,0.5))
	suite.check(game.world.node_at(p+Vector3i.UP) == Nodes.COBBLE and game.inventory.count_item(Nodes.COBBLE) == 2,"ordinary block placement replaces targeted top snow")
	game.world.set_node(p+Vector3i.UP,Nodes.AIR); game.world.set_node(p,Nodes.AIR)
	game.world.set_node(p,SnowCover.BASE)
	var slab: int = BuildingShapes.slab_for(Nodes.PLANKS)
	held(game,slab,3); click(game,Vector3(p)+Vector3(0.5,0.12,0.5))
	suite.check(game.world.node_at(p) == slab and game.world.node_at(p+Vector3i.UP) == Nodes.AIR and game.inventory.count_item(slab) == 2,"live slab placement replaces the snow layer at the same voxel")
	game.world.set_node(p,Nodes.AIR)
	placement_checks(suite,game,p)
	# Source snow can rest only on full solid support, not partial tops.
	var low := Vector3i(5,500,8)
	game.world.set_node(low+Vector3i.DOWN,BuildingShapes.slab_for(Nodes.PLANKS))
	held(game,SnowCover.BASE,3)
	SnowCover.try_place(game,{"pos":low+Vector3i.DOWN,"id":BuildingShapes.slab_for(Nodes.PLANKS),"normal":Vector3i.UP})
	suite.check(game.world.node_at(low) == Nodes.AIR and game.inventory.count_item(SnowCover.BASE) == 3,"partial slab support refuses snow without consuming it")
	game.world.set_node(low+Vector3i.DOWN,Nodes.STONE)
	game.world.set_node(low,SnowCover.BASE+2)
	var before: int = drop_count(game,Nodes.SNOWBALL)
	game.world.set_node(low+Vector3i.DOWN,Nodes.AIR)
	suite.check(game.world.node_at(low) == Nodes.AIR and drop_count(game,Nodes.SNOWBALL)-before == 4,"losing support removes snow and drops the source layer-count snowballs")
	game.world.set_node(low+Vector3i.DOWN,Nodes.STONE)
	# Actual mining callbacks, including tools and Silk Touch, close acquisition.
	for layer in range(1,9):
		var id: int = SnowCover.BASE+layer-1
		game.world.set_node(p,id); held(game,Nodes.TOOLS+2,1)
		before = drop_count(game,Nodes.SNOWBALL); game.break_node(p,id,Nodes.TOOLS+2)
		suite.check(game.world.node_at(p) == Nodes.AIR and drop_count(game,Nodes.SNOWBALL)-before == layer+1,"shoveling snow layer "+str(layer)+" yields "+str(layer+1)+" snowballs")
		game.world.set_node(p,id); held(game,Nodes.TOOLS+2,1,{"Silk Touch":1})
		before = drop_count(game,SnowCover.BASE); game.break_node(p,id,Nodes.TOOLS+2)
		suite.check(game.world.node_at(p) == Nodes.AIR and drop_count(game,SnowCover.BASE)-before == layer,"Silk Touch recovers "+str(layer)+" single-layer snow items")
	game.world.set_node(p,SnowCover.BASE); held(game,0,0)
	before = drop_count(game,Nodes.SNOWBALL); game.break_node(p,SnowCover.BASE,0)
	suite.check(game.world.node_at(p) == Nodes.AIR and drop_count(game,Nodes.SNOWBALL) == before,"breaking top snow without a shovel yields no useful drop")
	game.world.set_node(p,Nodes.SNOW_BLOCK); held(game,Nodes.TOOLS+2,1)
	before = drop_count(game,Nodes.SNOWBALL); game.break_node(p,Nodes.SNOW_BLOCK,Nodes.TOOLS+2)
	suite.check(drop_count(game,Nodes.SNOWBALL)-before == 4,"a full snow block yields the source four snowballs")
	game.world.set_node(p,Nodes.SNOW_BLOCK); held(game,Nodes.TOOLS+2,1,{"Silk Touch":1})
	before = drop_count(game,Nodes.SNOW_BLOCK); game.break_node(p,Nodes.SNOW_BLOCK,Nodes.TOOLS+2)
	suite.check(drop_count(game,Nodes.SNOW_BLOCK)-before == 1,"Silk Touch preserves a full snow block")
	game.world.set_node(p,Nodes.SNOW_BLOCK); held(game,0,0)
	before = drop_count(game,Nodes.SNOWBALL); game.break_node(p,Nodes.SNOW_BLOCK,0)
	suite.check(game.world.node_at(p) == Nodes.AIR and drop_count(game,Nodes.SNOWBALL) == before,"full snow blocks also require a shovel for useful drops")
	var recipes: Array = game.inventory.recipes.filter(func(recipe): return recipe.id == SnowCover.BASE)
	suite.check(recipes.size() == 1 and recipes[0].count == 6 and recipes[0].pattern == [Nodes.SNOW_BLOCK,Nodes.SNOW_BLOCK,Nodes.SNOW_BLOCK],"three horizontal snow blocks craft six top-snow items")
	# Skylight never melts snow; use only the source artificial-light threshold.
	game.world.set_node(p,SnowCover.BASE)
	suite.check(Pasture.light(game.world,p) >= 12 and Pasture.block_light(game.world,p) < 12 and not SnowCover.melt(game.world,p),"direct sunlight does not melt top snow")
	game.world.set_node(p+Vector3i.RIGHT*3,Nodes.TORCH)
	suite.check(Pasture.block_light(game.world,p) == 11 and not SnowCover.melt(game.world,p),"artificial light eleven is below the snow-melting threshold")
	game.world.set_node(p+Vector3i.RIGHT*3,Nodes.AIR); game.world.set_node(p+Vector3i.RIGHT*2,Nodes.TORCH)
	suite.check(Pasture.block_light(game.world,p) == 12 and SnowCover.melt(game.world,p) and game.world.node_at(p) == Nodes.AIR,"artificial light twelve melts a single top-snow layer without drops")
	for layer in range(2,9):
		game.world.set_node(p,SnowCover.BASE+layer-1)
		suite.check(not SnowCover.melt(game.world,p),"installed source melting ABM excludes thicker snow layer "+str(layer))
	game.world.set_node(p,SnowCover.BASE)
	var data: Dictionary = SnowCover.state(game.world)
	data.cells = {p:true}; data.clock = 0; data.scans.clear(); data.rng.seed = seed_for(1)
	SnowCover.update(game.world,15.99)
	suite.check(game.world.node_at(p) == SnowCover.BASE,"snow melting waits for the source sixteen-second interval")
	SnowCover.update(game.world,0.02)
	suite.check(game.world.node_at(p) == Nodes.AIR,"the source one-in-eight scheduled melt removes a sufficiently lit snow layer")
	game.world.set_node(p,SnowCover.BASE); data.cells = {p:true}; data.clock = 0; data.scans.clear(); data.rng.seed = seed_for(2)
	SnowCover.update(game.world,100)
	suite.check(game.world.node_at(p) == SnowCover.BASE and data.clock == 0,"snow ABMs do not catch up missed intervals or bypass a failed chance roll")
	game.world.set_node(p+Vector3i.RIGHT*2,Nodes.AIR)
	# Water can wash snow away, leaving usable drops via the normal fluid loop.
	before = drop_count(game,Nodes.SNOWBALL)
	game.world.set_node(p+Vector3i.RIGHT,Nodes.WATER); game.world.fluids.settle(p,Nodes.WATER)
	suite.check(Fluids.water(game.world.node_at(p)) and drop_count(game,Nodes.SNOWBALL)-before == 2,"flowing water washes away a snow layer and releases two snowballs")
	game.world.set_node(p+Vector3i.RIGHT,Nodes.AIR); game.world.set_node(p,Nodes.AIR)
	var piston := Vector3i(3,500,4)
	game.world.set_node(piston,Nodes.PISTON); game.world.circuits.configure(piston,Vector3i.RIGHT)
	game.world.set_node(piston+Vector3i.RIGHT,SnowCover.BASE+2)
	before = drop_count(game,Nodes.SNOWBALL)
	var extended: bool = game.world.circuits.piston(piston,true)
	suite.check(extended and game.world.node_at(piston+Vector3i.RIGHT) == Nodes.PISTON_HEAD and game.world.node_at(piston+Vector3i.RIGHT*2) == Nodes.AIR and drop_count(game,Nodes.SNOWBALL)-before == 4,"a piston destroys top snow for its source drops instead of pushing it")
	game.world.circuits.piston(piston,false); game.world.set_node(piston,Nodes.AIR)
	# Scheduling a whole snowy landscape must continue over bounded updates.
	var pending: Dictionary = {"cells":[],"cursor":0}
	for i in 1000: pending.cells.append(Vector3i(4+i%10,530+i/100,4+(i/10)%10))
	data.scans = [pending]; data.clock = 0
	SnowCover.update(game.world,0)
	suite.check(pending.cursor > 0 and pending.cursor <= 128 and not data.scans.is_empty(),"large snow-melting candidate scans retain a bounded continuation")
	for i in 16: SnowCover.update(game.world,0)
	suite.check(pending.cursor == 1000 and data.scans.is_empty(),"bounded snow scans finish every candidate without dropping work")
	# Generate a real cold column: natural snow provides survival ammunition
	# without changing the existing snowy-dirt terrain adaptation beneath it.
	var cold := Vector2i(999999,999999)
	for z in range(-32,33):
		for x in range(-32,33):
			if game.world.generator.biome(x*32,z*32) == "Frostpine highlands" and game.world.generator.terrain_height(x*32,z*32) > TerrainGenerator.SEA+1:
				cold = Vector2i(x*2,z*2); break
		if cold.x != 999999: break
	suite.check(cold.x != 999999,"the survival seed contains cold terrain suitable for natural top snow")
	if cold.x != 999999:
		var started: int = Time.get_ticks_usec()
		var generated: Dictionary = game.world.generator.generate_column(cold,{})
		var snow: Array = generated.special.keys().filter(func(at): return generated.special[at] == SnowCover.BASE)
		print("SNOW COLD COLUMN GENERATION MS: ",(Time.get_ticks_usec()-started)/1000.0," (snow candidates: ",snow.size(),")")
		suite.check(not snow.is_empty(),"normal terrain workers generate and index natural single-layer top snow")
		if not snow.is_empty():
			game.world._apply_column(generated)
			var natural: Vector3i = snow[0]
			var ground: int = game.world.node_at(natural+Vector3i.DOWN)
			held(game,Nodes.TOOLS+2,1); before = drop_count(game,Nodes.SNOWBALL)
			game.break_node(natural,SnowCover.BASE,Nodes.TOOLS+2)
			suite.check(drop_count(game,Nodes.SNOWBALL)-before == 2 and game.world.node_at(natural+Vector3i.DOWN) == ground,"shoveling naturally generated top snow supplies two snowballs while preserving its ground")
			# Old saves can have mined ground before top snow was introduced.
			# Regeneration must reconcile that edit before validating new support.
			var legacy_edits: Dictionary = {natural+Vector3i.DOWN:Nodes.AIR}
			game.world._unload(cold)
			game.world.edits.erase(natural); game.world.edits[natural+Vector3i.DOWN] = Nodes.AIR
			game.world._apply_column(game.world.generator.generate_column(cold,legacy_edits))
			suite.check(game.world.node_at(natural) == Nodes.AIR and not SnowCover.state(game.world).cells.has(natural),"loading a prior mined-ground edit removes newly generated unsupported snow")
	# Save state is encoded by the voxel ID, including thicker layers.
	game.world.set_node(p,SnowCover.BASE+5)
	var single := Vector3i(10,500,8); game.world.set_node(single,SnowCover.BASE)
	suite.check(game.save_game("user://snow_check.json"),"world containing stacked snow saves successfully")
	var saved: Dictionary = game.read_save("user://snow_check.json")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await suite.process_frame
	game.pause(); game.set_process(false); game.world.active = false; game.world.set_process(false)
	suite.check(game.world.node_at(p) == SnowCover.BASE+5 and game.world.node_at(single) == SnowCover.BASE,"actual reload restores snow layer heights exactly")
	suite.check(SnowCover.state(game.world).cells.has(single) and not SnowCover.state(game.world).cells.has(p),"reload rebuilds only the source single-layer melting index")
	var column := Vector2i(floori(single.x/16.0),floori(single.z/16.0))
	SnowCover.unload(game.world,column)
	suite.check(not SnowCover.state(game.world).cells.has(single) and not SnowCover.state(game.world).columns.has(column),"column unload removes snow runtime membership without stale entries")
	SnowCover.registered(game.world,single,SnowCover.BASE)
	data = SnowCover.state(game.world); data.clock = 7; data.scans.append({"cells":[single],"cursor":0})
	SnowCover.reset(game.world)
	suite.check(SnowCover.state(game.world).cells.is_empty() and SnowCover.state(game.world).scans.is_empty() and SnowCover.state(game.world).clock == 0,"reusing a world clears snow simulation clocks, queues and indexes")
	SnowCover.registered(game.world,single,SnowCover.BASE)
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://snow_check.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	game.pause()

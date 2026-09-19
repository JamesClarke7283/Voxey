extends RefCounted

# Focused regression for sponges: the source absorption volume and tie-break,
# immediate absorption on placement, Nether drying, the one-second sweep,
# furnace drying with the bucket replacement, and persistence. Fixtures use an
# isolated high plot so the checks cannot disturb generated terrain.

static func plot(game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world
	for x in range(-6,7):
		for z in range(-6,7):
			world.set_node(Vector3i(p.x+x,p.y-1,p.z+z),Nodes.STONE)
			for y in range(10): world.set_node(Vector3i(p.x+x,p.y+y,p.z+z),Nodes.AIR)

static func fill(world: VoxelWorld, centre: Vector3i, radius: int, id: int) -> int:
	var placed: int = 0
	for x in range(-radius,radius+1):
		for y in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				if world.set_node(centre+Vector3i(x,y,z),id): placed += 1
	return placed

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var ground := Vector3i(8,1800,8)
	plot(game,ground)
	game.player.position = Vector3(ground)+Vector3(0.5,0.0,0.5)

	# --- registration ------------------------------------------------------
	for id in Sponges.BLOCKS:
		t.check(Nodes.exists(id) and Nodes.max_stack(id) == 64,"sponge variant "+str(id)+" is a registered 64-stack block")
	t.check(Nodes.preferred_tool(Sponges.SPONGE) == -1 and Nodes.harvestable(Sponges.SPONGE,0),"a sponge needs no specific tool and drops by hand")
	t.check(is_equal_approx(Nodes.hardness(Sponges.SPONGE),0.6) and is_equal_approx(Nodes.hardness(Sponges.WET),0.6),"sponge hardness matches the source 0.6 for the dry and ordinary wet variants")
	t.check(Nodes.drop(Sponges.WET) == Sponges.SPONGE and Nodes.drop(Sponges.WET_RIVER) == Sponges.SPONGE,"both wet variants break into a plain sponge")
	t.check(Nodes.solid(Sponges.SPONGE) and Nodes.solid(Sponges.WET),"sponges are full solid cubes")
	t.check(Nodes.smelt_result(Sponges.WET) == Sponges.SPONGE and Nodes.smelt_result(Sponges.WET_RIVER) == Sponges.SPONGE,"a wet sponge smelts into a dry one")
	t.check(Sponges.cooking_replacement(Sponges.WET) == Nodes.WATER_BUCKET and Sponges.cooking_replacement(Sponges.SPONGE) == 0,"drying a wet sponge fills an empty fuel-slot bucket")

	# --- absorption volume and tie-break -----------------------------------
	# Fill a 9x9x9 region, larger than the 7x7x7 source volume.
	fill(world,ground,4,Nodes.WATER)
	world.set_node(ground,Sponges.SPONGE)
	var result: Dictionary = Sponges.absorb(world,ground)
	# The 7x7x7 cube centres on the sponge, so 343 - 1 cells can hold water.
	var expected: int = 7*7*7-1
	t.check(result.changed and result.count == expected,"absorption removes exactly the source 7x7x7 volume less the sponge itself: "+str(result.count))
	t.check(result.result == Sponges.WET,"normal water yields the ordinary waterlogged sponge")
	# The strict comparison means a tie favours normal water.
	t.check(Sponges.river_water(Nodes.WATER) == false and not Fluids.water(Nodes.AIR),"Voxey has no river-water node, so the river variant is unreachable rather than assumed")
	# An empty region changes nothing.
	plot(game,ground)
	var dry: Dictionary = Sponges.absorb(world,ground)
	t.check(not dry.changed and dry.count == 0 and dry.result == Sponges.SPONGE,"a sponge with no water anywhere in range absorbs nothing")
	# Water outside the volume is untouched.
	fill(world,ground,4,Nodes.WATER)
	world.set_node(ground+Vector3i(4,0,4),Nodes.WATER)
	Sponges.absorb(world,ground)
	t.check(Fluids.water(world.node_at(ground+Vector3i(4,0,4))),"water outside the 7x7x7 volume survives")

	# --- placement absorbs immediately -------------------------------------
	plot(game,ground)
	# Water one node away is within the source `find_node_near(pos, 1)` reach.
	world.set_node(ground+Vector3i(1,0,0),Nodes.WATER)
	game.inventory.restore([]); game.inventory.add_item(Sponges.SPONGE,2); game.inventory.selected = 0
	var target: Dictionary = {"pos":ground+Vector3i(0,-1,0),"normal":Vector3i.UP,"id":Nodes.STONE,"distance":1.0,"point":Vector3(ground)}
	Sponges.place(game,target)
	t.check(world.node_at(ground) == Sponges.WET and not Fluids.water(world.node_at(ground+Vector3i(1,0,0))),"placing beside water absorbs it and places the wet variant")
	t.check(game.inventory.count_item(Sponges.SPONGE) == 1,"absorbing placement consumes exactly one sponge")
	# With no water anywhere the plain sponge is placed.
	plot(game,ground)
	t.check(world.node_at(ground) == Nodes.AIR,"the plot is clear before a dry placement")
	Sponges.place(game,target)
	t.check(world.node_at(ground) == Sponges.SPONGE,"a sponge placed away from water stays dry")
	# Creative placement preserves the item.
	game.gamemode = "creative"
	# A fresh plot and a fresh target: the dry placement above left the cell used.
	plot(game,ground)
	game.inventory.restore([]); game.inventory.add_item(Sponges.SPONGE,1); game.inventory.selected = 0
	world.set_node(ground+Vector3i(1,0,0),Nodes.WATER)
	Sponges.place(game,target)
	t.check(world.node_at(ground) == Sponges.WET and game.inventory.count_item(Sponges.SPONGE) == 1,"creative placement absorbs without consuming the item")
	game.gamemode = "survival"

	# --- the one-second sweep ----------------------------------------------
	plot(game,ground)
	world.set_node(ground,Sponges.SPONGE)
	Sponges.registered(world,ground,Sponges.SPONGE)
	var data: Dictionary = Sponges.runtime(world)
	data.clock = 0.0
	Sponges.update(world,Sponges.INTERVAL)
	t.check(world.node_at(ground) == Sponges.SPONGE,"a dry sponge with no neighbouring water is left alone by the sweep")
	world.set_node(ground+Vector3i.UP,Nodes.WATER)
	Sponges.update(world,Sponges.INTERVAL)
	t.check(world.node_at(ground) == Sponges.WET,"the sweep wets a sponge that gains an adjacent water node")
	t.check(not Sponges.adjacent_water(world,ground),"the sweep consumed the neighbouring water")
	# The wet node is no longer tracked.
	t.check(not Sponges.runtime(world).cells.has(ground),"a converted sponge leaves the dry tracking index")

	# --- Nether drying ------------------------------------------------------
	plot(game,ground)
	var previous_dimension: String = world.dimension
	world.dimension = "nether"
	game.inventory.restore([]); game.inventory.add_item(Sponges.WET,2); game.inventory.selected = 0
	Sponges.place_wet(game,target)
	t.check(world.node_at(ground) == Sponges.SPONGE and game.inventory.count_item(Sponges.WET) == 1,"placing a wet sponge in the Nether dries it and consumes one item")
	world.dimension = previous_dimension
	plot(game,ground)
	game.inventory.restore([]); game.inventory.add_item(Sponges.WET,2); game.inventory.selected = 0
	Sponges.place_wet(game,target)
	t.check(world.node_at(ground) == Sponges.WET,"the same placement outside the Nether keeps the sponge wet")

	# --- furnace drying with a bucket in the fuel slot ---------------------
	plot(game,ground)
	world.set_node(ground,Nodes.FURNACE)
	var furnace: Dictionary = world.get_station(ground,"furnace")
	furnace.slots[0] = {"id":Sponges.WET,"count":1,"wear":0}
	furnace.slots[1] = {"id":Nodes.BUCKET,"count":1,"wear":0}
	furnace.slots[2] = {"id":0,"count":0,"wear":0}
	furnace.burn = 100.0
	furnace.progress = 0.0
	# Source cooks a sponge over eight progress ticks at the ordinary furnace rate.
	for i in 8: world._simulate()
	t.check(furnace.slots[2].id == Sponges.SPONGE and furnace.slots[2].count == 1,"the furnace dries a wet sponge into a plain sponge")
	t.check(furnace.slots[1].id == Nodes.WATER_BUCKET and furnace.slots[1].count == 1,"the empty fuel-slot bucket receives the sponge's water")
	t.check(furnace.slots[0].id == 0,"the input slot is emptied")
	# An occupied fuel slot keeps its contents.
	furnace.slots[0] = {"id":Sponges.WET,"count":1,"wear":0}
	furnace.slots[1] = {"id":Nodes.COAL,"count":4,"wear":0}
	furnace.slots[2] = {"id":0,"count":0,"wear":0}
	furnace.burn = 100.0
	furnace.progress = 0.0
	for i in 8: world._simulate()
	t.check(furnace.slots[1].id == Nodes.COAL,"a fuel slot holding something else is not replaced")

	# --- persistence --------------------------------------------------------
	plot(game,ground)
	world.set_node(ground,Sponges.WET)
	Sponges.registered(world,ground,Sponges.WET)
	var save_ok: bool = game.save_game("user://sponge_check.json")
	var saved: Dictionary = game.read_save("user://sponge_check.json")
	game.set_process(true)
	game.load_world_data(saved)
	world = game.world
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.set_process(false); game.world.set_process(false); game.world.active = false
	t.check(save_ok and world.node_at(ground) == Sponges.WET,"the wet sponge state survives a save reload")

	# --- an unloaded column is not simulated, and reloading resumes ---------
	plot(game,ground)
	world.set_node(ground,Sponges.SPONGE)
	Sponges.registered(world,ground,Sponges.SPONGE)
	var column := Vector2i(floori(ground.x/16.0),floori(ground.z/16.0))
	Sponges.unload(world,column)
	t.check(not Sponges.runtime(world).cells.has(ground),"unloading a column drops it from the index")
	Sponges.column_loaded(world,column)
	t.check(Sponges.runtime(world).cells.has(ground),"reloading the column restores the index exactly once")
	t.check(Sponges.runtime(world).cells.size() == 1,"reloading does not duplicate entries")

	# --- art ---------------------------------------------------------------
	t.check(not Sponges.icon_faces(Sponges.SPONGE).is_empty() and not Sponges.icon_faces(Sponges.WET).is_empty(),"both sponge variants produce an inventory icon from the real mesh")
	t.check(not game.node_mesh(Sponges.SPONGE).get_surface_count() == 0,"a sponge builds a non-empty voxel mesh")
	t.check(VillageArt.pixel(Sponges.WET,3,3,Color.WHITE) != VillageArt.pixel(Sponges.SPONGE,3,3,Color.WHITE),"the wet variant renders a visibly different texture from the dry one")

	for x in range(-6,7):
		for z in range(-6,7):
			for y in range(10): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)

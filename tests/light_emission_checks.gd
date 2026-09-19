extends RefCounted

# Exercise the worker fast path as well as ordinary set_node indexing. The
# column stays resident so this does not alter the lifecycle suite's world.
static func rebuild_candidates(suite: SceneTree, world: VoxelWorld, lamp: Vector3i) -> void:
	var data: Dictionary = Pasture.state(world)
	var column := Vector2i(floori(lamp.x/16.0),floori(lamp.z/16.0))
	var candidates: Dictionary = {}
	for p in data.cell_columns.get(column,{}): candidates[p] = world.node_at(p)
	for block in data.light_columns.get(column,{}):
		for p in data.light_blocks[block]: candidates[p] = world.node_at(p)
	candidates[lamp] = world.node_at(lamp)
	var saved_edits: Dictionary = {}
	for p in [lamp,lamp+Vector3i.UP]:
		if world.edits.has(p): saved_edits[p] = world.edits[p]
		world.edits.erase(p)
	Pasture.column_unloaded(world,column)
	suite.check(not data.lights.has(lamp) and not data.light_columns.has(column),"column unload removes all emitter memberships")
	Pasture.column_loaded(world,column,candidates)
	for p in saved_edits: world.edits[p] = saved_edits[p]
	suite.check(data.lights.has(lamp),"worker candidates retain inactive "+Nodes.title(world.node_at(lamp))+" for later state changes")

static func run(suite: SceneTree, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var old_daylight: float = game.daylight
	var old_position: Vector3 = game.player.position
	var player_process: bool = game.player.is_processing()
	var player_physics: bool = game.player.is_physics_processing()
	game.player.set_process(false); game.player.set_physics_process(false)
	game.daylight = 0.05
	var p := Vector3i(8,508,8); var lamp: Vector3i = p+Vector3i.RIGHT
	game.player.position = Vector3(p)+Vector3(0.5,2.0,0.5)
	var station_key: String = world.station_key(lamp)
	var had_station: bool = world.stations.has(station_key)
	var previous_station: Dictionary = world.stations.get(station_key,{}).duplicate(true)
	var previous_nodes: Dictionary = {}; var previous_edits: Dictionary = {}
	for cell in [p,lamp,lamp+Vector3i.UP]:
		previous_nodes[cell] = world.node_at(cell)
		if world.edits.has(cell): previous_edits[cell] = world.edits[cell]
		world.set_node(cell,Nodes.AIR)
	world.stations.erase(station_key)
	suite.check(Pasture.light(world,p) == 2,"nighttime light fixture starts without nearby artificial emission")
	for pair in [[Bastions.CRYING_OBSIDIAN,10],[Nodes.NETHER_PORTAL,11],[Nodes.END_PORTAL,14]]:
		var id: int = pair[0]; var power: int = pair[1]
		world.set_node(lamp,id)
		suite.check(Pasture.TRACKED.has(id) and Pasture.state(world).lights.has(lamp),Nodes.title(id)+" is indexed from a real block edit")
		suite.check(Pasture.emission(world,lamp) == power and Pasture.light(world,p) == power-1,Nodes.title(id)+" supplies source-level light to adjacent air")
		world.set_node(lamp,Nodes.AIR)
		suite.check(not Pasture.state(world).lights.has(lamp) and Pasture.light(world,p) == 2,"removing "+Nodes.title(id)+" immediately removes its light")
	for id in [Nodes.FURNACE,VillageContent.SMOKER,VillageContent.BLAST_FURNACE]:
		world.stations.erase(station_key); world.set_node(lamp,id)
		suite.check(Pasture.state(world).lights.has(lamp) and Pasture.emission(world,lamp) == 0 and not world.stations.has(station_key),"cold "+Nodes.title(id)+" is indexed without creating station metadata")
		rebuild_candidates(suite,world,lamp)
		var furnace: Dictionary = world.get_station(lamp,"furnace")
		furnace.burn = 10.0
		suite.check(world.node_at(lamp) == id and Pasture.emission(world,lamp) == 13 and Pasture.light(world,p) == 12,"burning "+Nodes.title(id)+" lights its surroundings without a block-ID change")
		world.stations[station_key] = JSON.parse_string(JSON.stringify(furnace))
		suite.check(Pasture.emission(world,lamp) == 13 and Pasture.light(world,p) == 12,"JSON-restored "+Nodes.title(id)+" retains its burning light")
		world.stations[station_key].burn = 0.0
		suite.check(Pasture.emission(world,lamp) == 0 and Pasture.light(world,p) == 2,"exhausted "+Nodes.title(id)+" stops emitting immediately without a block-ID change")
		world.set_node(lamp,Nodes.AIR); world.stations.erase(station_key)
	world.set_node(lamp,VillageContent.CAULDRON)
	var cauldron: Dictionary = Cauldrons.station(world,lamp)
	suite.check(Pasture.state(world).lights.has(lamp) and Pasture.emission(world,lamp) == 0,"empty cauldron stays indexed for later filling")
	rebuild_candidates(suite,world,lamp)
	for amount in [1,3]:
		Cauldrons.set_contents(cauldron,amount,"lava")
		suite.check(world.node_at(lamp) == VillageContent.CAULDRON and Pasture.emission(world,lamp) == 14 and Pasture.light(world,p) == 13,"lava cauldron level "+str(amount)+" lights adjacent air without a block-ID change")
	world.stations[station_key] = JSON.parse_string(JSON.stringify(cauldron))
	cauldron = world.stations[station_key]
	suite.check(Pasture.emission(world,lamp) == 14 and Pasture.light(world,p) == 13,"JSON-restored lava cauldron retains its emitted light")
	Cauldrons.set_contents(cauldron,3,"water")
	suite.check(Pasture.emission(world,lamp) == 0 and Pasture.light(world,p) == 2,"water-filled cauldron supplies no artificial light")
	Cauldrons.set_contents(cauldron,3,"lava"); Cauldrons.set_contents(cauldron,0)
	suite.check(Pasture.emission(world,lamp) == 0 and Pasture.light(world,p) == 2,"draining lava immediately removes cauldron light without a block-ID change")
	world.set_node(lamp,Nodes.REDSTONE_LAMP)
	world.circuits.state(lamp).powered = false
	suite.check(Pasture.state(world).lights.has(lamp) and Pasture.light(world,p) == 2,"unpowered redstone lamp stays indexed without emitting")
	rebuild_candidates(suite,world,lamp)
	world.circuits.state(lamp).powered = true
	suite.check(Pasture.emission(world,lamp) == 14 and Pasture.light(world,p) == 13,"redstone lamp power is sampled live after worker index restoration")
	world.circuits.state(lamp).powered = false
	suite.check(Pasture.emission(world,lamp) == 0 and Pasture.light(world,p) == 2,"switching a redstone lamp off does not leave cached block light")
	world.set_node(lamp,Nodes.AIR)
	suite.check(not Pasture.state(world).lights.has(lamp) and not Pasture.nearby_lights(world,p).has(lamp),"final emitter removal clears both global and spatial light indexes")
	for cell in previous_nodes:
		world.set_node(cell,previous_nodes[cell])
		if previous_edits.has(cell): world.edits[cell] = previous_edits[cell]
		else: world.edits.erase(cell)
	if had_station: world.stations[station_key] = previous_station
	else: world.stations.erase(station_key)
	game.daylight = old_daylight; game.player.position = old_position
	game.player.set_process(player_process); game.player.set_physics_process(player_physics)

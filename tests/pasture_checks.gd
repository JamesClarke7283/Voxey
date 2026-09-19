extends RefCounted

static func winning_seed(chance: int) -> int:
	var rng := RandomNumberGenerator.new()
	for candidate in range(20000):
		rng.seed = candidate
		if rng.randi_range(1,chance) == 1: return candidate
	return -1

static func run(suite: SceneTree, game: Node3D) -> void:
	game.pause(); game.world.active = false; game.world.set_process(false); game.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = Vector3(8.5,476.01,10.5); game.daylight = 1.0
	var world: VoxelWorld = game.world
	for x in range(4,15):
		for z in range(4,15):
			for y in range(472,481): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	var p := Vector3i(8,475,8); var source: Vector3i = p+Vector3i.RIGHT
	world.set_node(p,Nodes.DIRT)
	suite.check(Pasture.state(world).cells.has(p),"new exposed dirt enters the pasture simulation index")
	suite.check(not Pasture.spread(world,p),"isolated dirt cannot create grass without an existing nearby source")
	world.set_node(source,Nodes.GRASS)
	suite.check(Pasture.light(world,p+Vector3i.UP) >= 9 and Pasture.spread(world,p) and Pasture.is_grass(world.node_at(p)),"daylit grass spreads onto nearby exposed dirt")
	world.set_node(source,Nodes.AIR)
	for offset in [Vector3i(-1,-1,-1),Vector3i(1,3,1),Vector3i(2,0,0),Vector3i(0,4,0),Vector3i(0,-2,0)]:
		world.set_node(p,Nodes.DIRT); world.set_node(p+offset,Nodes.GRASS)
		var expected: bool = offset.x <= 1 and offset.y >= -1 and offset.y <= 3
		suite.check(Pasture.spread(world,p) == expected,"grass source search honors source 3×5×3 range at "+str(offset))
		world.set_node(p+offset,Nodes.AIR)
	world.set_node(source,Nodes.GRASS)
	for cover in [Nodes.STONE,Nodes.WATER,Nodes.LAVA]:
		world.set_node(p,Nodes.DIRT); world.set_node(p+Vector3i.UP,cover)
		suite.check(not Pasture.spread(world,p) and world.node_at(p) == Nodes.DIRT,"grass cannot spread directly beneath "+Nodes.title(cover))
	world.set_node(p+Vector3i.UP,Nodes.GLASS)
	suite.check(Pasture.spread(world,p),"transparent glass above dirt permits grass spread")
	world.set_node(p+Vector3i.UP,Nodes.AIR); world.set_node(p,Nodes.DIRT)
	world.set_node(source+Vector3i.UP,Nodes.STONE)
	suite.check(not Pasture.spread(world,p),"an opaque cover on the source prevents it from providing enough light for spread")
	world.set_node(source+Vector3i.UP,Nodes.AIR); game.daylight = 0.0
	suite.check(not Pasture.spread(world,p),"unlit nighttime pasture cannot spread without sufficient source light")
	var torch_pos: Vector3i = p+Vector3i(-1,1,0)
	world.set_node(torch_pos+Vector3i.DOWN,Nodes.STONE); world.set_node(torch_pos,Nodes.TORCH)
	suite.check(Pasture.light(world,p+Vector3i.UP) == 13 and Pasture.spread(world,p),"nearby torch block light enables night-time grass spread")
	world.set_node(torch_pos,Nodes.AIR)
	suite.check(not Pasture.state(world).lights.has(torch_pos),"removing a light removes its pasture light index entry")
	suite.check(not Pasture.decay(world,p),"open grass does not decay merely because it is night")
	for cover in [Nodes.STONE,Nodes.WATER]:
		world.set_node(p,Nodes.GRASS); world.set_node(p+Vector3i.UP,cover)
		suite.check(Pasture.decay(world,p) and world.node_at(p) == Nodes.DIRT,"covered grass decays to dirt below "+Nodes.title(cover))
	world.set_node(p,Nodes.GRASS); world.set_node(p+Vector3i.UP,Nodes.GLASS)
	suite.check(not Pasture.decay(world,p),"transparent glass does not kill grass")
	world.set_node(p+Vector3i.UP,Nodes.AIR); game.daylight = 1.0
	var data: Dictionary = Pasture.state(world)
	var candidates: Dictionary = data.cells.duplicate(); candidates.merge(data.lights)
	data.cells.clear(); data.cells[p] = true; data.jobs.clear(); data.cursor = 0; data.scans.clear()
	world.set_node(p,Nodes.DIRT); data.spread_clock = 29.9; data.decay_clock = 0; data.rng.seed = winning_seed(20)
	Pasture.update(world,0.05)
	suite.check(world.node_at(p) == Nodes.DIRT,"pasture waits for its thirty-second spread interval")
	Pasture.update(world,0.06)
	suite.check(Pasture.is_grass(world.node_at(p)),"a successful one-in-twenty scheduled spread attempt regrows pasture")
	world.set_node(p+Vector3i.UP,Nodes.STONE); data.cells.clear(); data.cells[p] = true
	data.spread_clock = 0; data.decay_clock = 7.9; data.rng.seed = winning_seed(50)
	Pasture.update(world,0.05)
	suite.check(Pasture.is_grass(world.node_at(p)),"covered grass waits for its eight-second decay interval")
	Pasture.update(world,0.06)
	suite.check(world.node_at(p) == Nodes.DIRT,"a successful one-in-fifty scheduled decay attempt removes covered grass")
	world.set_node(p+Vector3i.UP,Nodes.AIR); world.set_node(source,Nodes.AIR); data.cells.clear(); data.cells[p] = true
	data.spread_clock = 0; data.decay_clock = 0; data.rng.seed = 487
	var expected_rng := RandomNumberGenerator.new(); expected_rng.seed = 487; expected_rng.randi_range(1,20)
	Pasture.update(world,600)
	suite.check(data.rng.state == expected_rng.state and data.spread_clock == 0,"long elapsed intervals schedule only one attempt instead of catching up unloaded time")
	# Reindexing a streamed column is bounded and does not duplicate positions.
	var column := Vector2i(0,0); candidates[p] = true
	for cell in candidates.keys():
		var coord: Vector3i = VoxelWorld.block_coord(cell)
		if coord.x != column.x or coord.z != column.y: candidates.erase(cell)
		else: candidates[cell] = world.node_at(cell)
	var start: int = Time.get_ticks_usec()
	Pasture.column_loaded(world,column,candidates)
	var indexed: int = data.cells.size(); Pasture.column_loaded(world,column,candidates)
	print("PASTURE COLUMN INDEX MS: ",(Time.get_ticks_usec()-start)/2000.0," (column candidates: ",candidates.size(),")")
	suite.check(data.cells.size() == indexed and data.cells.has(p),"column restoration reindexes pasture without duplicate cells")
	Pasture.column_unloaded(world,column)
	suite.check(not data.cells.has(p),"unloading a column removes its active pasture index")
	suite.check(not data.cell_columns.has(column) and not data.light_columns.has(column) and data.lights.keys().all(func(pos): return floori(pos.x/16.0) != column.x or floori(pos.z/16.0) != column.y),"column unload clears all of its soil and light memberships without stale entries")
	Pasture.column_loaded(world,column,candidates)
	# A large ABM snapshot must be spread over frames even when nodes are cheap.
	var scan_positions: Array = []
	for i in 1000: scan_positions.append(Vector3i(4+i%10,472+(i/100),4+(i/10)%10))
	var pending_scan: Dictionary = {"cells":scan_positions,"cursor":0,"spread":false,"decay":false}
	data.scans = [pending_scan]; data.spread_clock = 0; data.decay_clock = 0
	Pasture.update(world,0)
	suite.check(pending_scan.cursor > 0 and pending_scan.cursor <= 256 and not data.scans.is_empty(),"large pasture candidate scans do bounded work and retain their continuation")
	for i in 16: Pasture.update(world,0)
	suite.check(data.scans.is_empty() and pending_scan.cursor == 1000,"bounded pasture scans finish every candidate without dropping work")
	# Daylight is absent here, and a full wall prevents a torch lighting grass.
	game.daylight = 0.0
	var distant_torch := Vector3i(5,476,8)
	world.set_node(distant_torch+Vector3i.DOWN,Nodes.STONE); world.set_node(distant_torch,Nodes.TORCH)
	for z in range(1,16):
		for y in range(474,490): world.set_node(Vector3i(7,y,z),Nodes.STONE)
	start = Time.get_ticks_usec(); var blocked_light: int = Pasture.light(world,p+Vector3i.UP)
	print("PASTURE BLOCKED LIGHT MS: ",(Time.get_ticks_usec()-start)/1000.0)
	suite.check(blocked_light < 9,"opaque walls stop nearby artificial light from enabling pasture spread")
	world.set_node(distant_torch,Nodes.AIR)
	for z in range(1,16):
		for y in range(474,490): world.set_node(Vector3i(7,y,z),Nodes.AIR)
	game.daylight = 1.0
	for x in range(-7,24):
		for z in range(-7,24): world.set_node(Vector3i(x,478,z),Nodes.STONE)
	start = Time.get_ticks_usec(); var roof_light: int = Pasture.light(world,p+Vector3i.UP)
	print("PASTURE COVERED SKY LIGHT MS: ",(Time.get_ticks_usec()-start)/1000.0)
	suite.check(roof_light < 9,"a broad roof prevents sufficient skylight reaching the pasture")
	for x in range(-7,24):
		for z in range(-7,24): world.set_node(Vector3i(x,478,z),Nodes.AIR)
	world.set_node(source,Nodes.GRASS); world.set_node(p,Nodes.DIRT)
	Pasture.spread(world,p); data.spread_clock = 22; data.decay_clock = 7
	suite.check(game.save_game("user://pasture_check.json"),"regrown pasture saves as normal world block edits")
	var saved: Dictionary = game.read_save("user://pasture_check.json")
	start = Time.get_ticks_usec(); game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await suite.process_frame
	print("PASTURE REAL WORLD LOAD MS: ",(Time.get_ticks_usec()-start)/1000.0)
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	suite.check(Pasture.is_grass(game.world.node_at(p)) and Pasture.state(game.world).cells.has(p),"actual reload restores the grass block and rebuilds its active pasture index")
	suite.check(Pasture.state(game.world).spread_clock < 1 and Pasture.state(game.world).decay_clock < 1,"world reuse clears pasture clocks, queues and indexes from the previous load")
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://pasture_check.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

extends RefCounted

const Y = 1900
const Helper = preload("res://tests/fruit_crop_checks.gd")

static func fresh(world: VoxelWorld, p: Vector3i, id: int = Farmland.DRY) -> void:
	world.set_node(p+Vector3i.UP,Nodes.AIR); world.set_node(p,Nodes.AIR); world.set_node(p,id)

static func freeze(game: Node3D) -> void:
	game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)

static func run(t: SceneTree, game: Node3D) -> void:
	game._clear_entities(); await t.process_frame
	game.state = "playing"; game.gamemode = "survival"; freeze(game)
	var world: VoxelWorld = game.world
	var old_weather: Variant = world.adventure_state.get("weather"); world.adventure_state.weather = "clear"
	var old_time: float = game.day_time; game.day_time = 0.5
	for x in range(1,23):
		for z in range(1,16):
			for y in range(Y-1,Y+6): world.set_node(Vector3i(x,y,z),Nodes.DIRT if y == Y-1 else Nodes.AIR)
	var p := Vector3i(8,Y,8)
	game.player.position = Vector3(8.5,Y+0.01,12.5); game.player.velocity = Vector3.ZERO
	for id in [Farmland.DRY,Farmland.WET]:
		fresh(world,p,id)
		t.check(Nodes.exists(id) and Nodes.solid(id) and is_equal_approx(Nodes.hardness(id),0.6) and Nodes.preferred_tool(id) == 2 and Nodes.drop(id) == Nodes.DIRT,"source farmland material has shovel preference,0.6 hardness and dirt drop: "+str(id))
		var hit: Dictionary = world.raycast(Vector3(p)+Vector3(0.5,2,0.5),Vector3.DOWN,3)
		t.check(not hit.is_empty() and hit.pos == p and is_equal_approx(hit.point.y,p.y+Farmland.HEIGHT),"real raycast targets15/16 farmland top: "+str(id))
		t.check(not world.intersects(Vector3(p)+Vector3(0.5,0.95,0.5),0.1,0.04) and world.intersects(Vector3(p)+Vector3(0.5,0.9,0.5),0.1,0.04),"body collision uses the lowered farmland surface: "+str(id))
		var mesh: Array = BlockMesher._empty(); Farmland.mesh(mesh,Vector3.ZERO,id)
		var max_y: float = 0
		for vertex in mesh[0]: max_y = maxf(max_y,vertex.y)
		t.check(not mesh[0].is_empty() and is_equal_approx(max_y,Farmland.HEIGHT) and not Farmland.icon_faces(id).is_empty(),"farmland mesh and item icon use the same15/16 geometry: "+str(id))
		t.check(Nodes.tile(id,0) == Nodes.tile(Nodes.DIRT,0) and Nodes.tile(id,3) == Nodes.tile(Nodes.DIRT,3),"farmland sides and underside retain source dirt texture: "+str(id))
		Helper.held(game,Nodes.TOOLS+2,1,{"enchantments":{"Silk Touch":1}})
		var before: int = Helper.drops(game,Nodes.DIRT); game.break_node(p,id,Nodes.TOOLS+2)
		t.check(Helper.drops(game,Nodes.DIRT) == before+1,"Silk Touch digging still returns dirt from farmland: "+str(id))
	# Real player use, including source's absence of a clicked-face restriction.
	for id in [Nodes.GRASS,Nodes.DIRT,VillageContent.SWAMP_GRASS,VillageContent.PATH]:
		fresh(world,p,id); Helper.held(game,Nodes.TOOLS+4)
		game.player.target = {"pos":p,"id":id,"normal":Vector3i.BACK,"distance":4.0}; game.player.use()
		t.check(world.node_at(p) == Farmland.DRY and game.inventory.held().wear > 0,"actual hoe use tills supported source soil from its side and wears tool: "+str(id))
	for cover in [FoodFeatures.POPPY,SnowCover.BASE,Nodes.WATER,Nodes.STONE]:
		fresh(world,p,Nodes.DIRT); world.set_node(p+Vector3i.UP,cover); Helper.held(game,Nodes.TOOLS+4)
		Farmland.use(game,{"pos":p,"id":Nodes.DIRT,"normal":Vector3i.UP})
		t.check(world.node_at(p) == Nodes.DIRT and world.node_at(p+Vector3i.UP) == cover and game.inventory.held().wear == 0,"hoe requires literal air above without deleting cover or wearing: "+str(cover))
	fresh(world,p,Nodes.DIRT); Helper.held(game,Nodes.TOOLS+4); game.gamemode = "creative"
	Farmland.use(game,{"pos":p,"id":Nodes.DIRT,"normal":Vector3i.DOWN})
	t.check(world.node_at(p) == Farmland.DRY and game.inventory.held().wear == 0,"creative hoe use preserves durability and source allows underside use")
	game.gamemode = "survival"
	# Exact source water volume: corners included, one below not included.
	for offset in [Vector3i(4,0,4),Vector3i(-4,1,-4),Vector3i(5,0,0),Vector3i(0,-1,4),Vector3i(0,2,4)]:
		fresh(world,p); var at: Vector3i = p+offset; world.set_node(at,Nodes.WATER)
		var allowed: bool = absi(offset.x) <= 4 and offset.y >= 0 and offset.y <= 1
		Farmland.advance(world,p)
		t.check((world.node_at(p) == Farmland.WET) == allowed,"source water search boundary "+str(offset))
		world.set_node(at,Nodes.AIR)
	fresh(world,p); world.set_node(p+Vector3i(4,0,0),Fluids.WATER_FLOW+3); Farmland.advance(world,p)
	t.check(world.node_at(p) == Farmland.WET and Farmland.state(world,p).wet == 7,"flowing water hydrates soil and initializes source moisture7")
	world.set_node(p+Vector3i(4,0,0),Nodes.AIR)
	for wet in range(6,-1,-1):
		Farmland.advance(world,p)
		t.check(world.node_at(p) == Farmland.DRY and Farmland.state(world,p).wet == wet and not Farmland.hydrated(world.node_at(p)),"source drying changes visible soil on first tick and retains moisture countdown "+str(wet))
	Farmland.advance(world,p); t.check(world.node_at(p) == Nodes.DIRT,"zero moisture becomes dirt on the next selected ABM action")
	fresh(world,p,Farmland.WET); Farmland.state(world,p).wet = 2; world.set_node(p+Vector3i.RIGHT,Nodes.WATER); Farmland.advance(world,p)
	t.check(Farmland.state(world,p).wet == 2,"source already-wet soil near water leaves existing metadata unchanged")
	world.set_node(p,Farmland.DRY); Farmland.advance(world,p)
	t.check(world.node_at(p) == Farmland.WET and Farmland.state(world,p).wet == 7,"rehydrating a dry node restores moisture7 even if its old metadata remained positive")
	world.set_node(p+Vector3i.RIGHT,Nodes.AIR)
	for plant in [Nodes.WHEAT,Nodes.RIPE_WHEAT,CropFarming.STAGES[1][4],CropFarming.STAGES[2][4],CropFarming.STAGES[3][1],FruitCrops.PUMPKIN_STEM,FruitCrops.MELON_STEM,FoodFeatures.POPPY,WoodTypes.sapling_id(2)]:
		fresh(world,p); world.set_node(p+Vector3i.UP,plant); Farmland.advance(world,p)
		t.check(world.node_at(p) == Farmland.DRY,"source plant group retains unhydrated farmland: "+str(plant))
	# Solid group concerns regular full collision, not opacity or walkability.
	for entry in [[Nodes.STONE,true],[Nodes.GLASS,true],[Nodes.PISTON_HEAD,false],[VillageContent.PATH,false],[Nodes.CHEST,false],[Nodes.HOPPER,false],[Beehives.HONEY_BLOCK,false],[VillageContent.BED_BLUE,false],[VillageContent.CAULDRON,false],[BuildingShapes.slab_for(Nodes.PLANKS),false]]:
		fresh(world,p,Farmland.WET); world.set_node(p+Vector3i.UP,int(entry[0])); Farmland.advance(world,p)
		t.check((world.node_at(p) == Nodes.DIRT) == entry[1],"source solid-above dirtification matches full shape: "+str(entry[0]))
	fresh(world,p,Farmland.WET); world.set_node(p+Vector3i.UP,Farmland.DRY); Farmland.placed(world,p+Vector3i.UP)
	t.check(world.node_at(p) == Nodes.DIRT,"actual source dirtifier placement immediately converts lower farmland despite partial geometry")
	fresh(world,p,Farmland.WET); world.set_node(p+Vector3i.UP,Nodes.STONE)
	t.check(world.node_at(p) == Farmland.WET,"generic world set_node leaves solid-above conversion to the source ABM")
	Farmland.placed(world,p+Vector3i.UP); t.check(world.node_at(p) == Nodes.DIRT,"player placement hook dirtifies farmland immediately under solid blocks")
	# Rain uses global weather plus source outdoor test, without hydration.
	for id in [Farmland.DRY,Farmland.WET]:
		fresh(world,p,id); world.adventure_state.weather = "rain"; game.day_time = 0.9
		var wet: int = Farmland.state(world,p).wet; Farmland.advance(world,p)
		t.check(world.node_at(p) == id and Farmland.state(world,p).wet == wet,"night rain prevents decay without hydrating dry farmland: "+str(id))
		world.set_node(p+Vector3i.UP*3,Nodes.GLASS); Farmland.advance(world,p)
		t.check(world.node_at(p) == id and Farmland.state(world,p).wet == wet,"source outdoor function intentionally admits rain preservation under glass: "+str(id))
		world.set_node(p+Vector3i.UP*3,Nodes.STONE); Farmland.advance(world,p)
		t.check(world.node_at(p) == (Farmland.DRY if id == Farmland.WET else Nodes.DIRT),"opaque roof prevents source rain protection: "+str(id))
		world.set_node(p+Vector3i.UP*3,Nodes.AIR)
	world.adventure_state.weather = "clear"; game.day_time = 0.5
	# Scheduler is reproducible, once per interval, and bounded across a field.
	Farmland.reset(world); fresh(world,p,Farmland.WET)
	var chosen: int = -1; var rng := RandomNumberGenerator.new()
	for trial in 100:
		rng.seed = trial
		if rng.randi_range(1,4) == 1: chosen = trial; break
	Farmland.runtime(world).rng.seed = chosen; Farmland.update(world,14.99)
	t.check(world.node_at(p) == Farmland.WET and Farmland.state(world,p).remaining > 0,"soil waits a full source15-second interval")
	Farmland.update(world,0.02)
	t.check(world.node_at(p) == Farmland.DRY and Farmland.state(world,p).wet == 6,"source one-in-four roll runs exactly one moisture step after15seconds")
	fresh(world,p,Farmland.WET)
	for trial in 100:
		rng.seed = trial
		if rng.randi_range(1,4) != 1: chosen = trial; break
	Farmland.runtime(world).rng.seed = chosen; Farmland.update(world,15)
	t.check(world.node_at(p) == Farmland.WET and Farmland.state(world,p).wet == 7,"failed source one-in-four roll leaves soil unchanged and starts another interval")
	game.pause(); var remaining: float = Farmland.state(world,p).remaining; Farmland.update(world,1000)
	t.check(Farmland.state(world,p).remaining == remaining,"paused game does not advance soil timers")
	game.state = "playing"; Farmland.update(world,NAN); Farmland.update(world,-1)
	t.check(Farmland.state(world,p).remaining == remaining,"invalid delta cannot corrupt saved farmland time")
	Farmland.unload(world,Vector2i.ZERO); Farmland.update(world,1000)
	t.check(not Farmland.runtime(world).cells.has(p) and Farmland.state(world,p).remaining == remaining,"unloaded runtime leaves soil and saved timer unchanged")
	Farmland.registered(world,p,world.node_at(p)); Farmland.update(world,1)
	t.check(Farmland.state(world,p).remaining == remaining-1,"registering a saved soil resumes its existing timer")
	fresh(world,p)
	world.block_states[VoxelWorld.station_key(p)].farmland = {"wet":"bad","remaining":INF}
	t.check(Farmland.state(world,p).wet == 0 and Farmland.state(world,p).remaining == 15,"malformed saved moisture and time are sanitized without promoting dry soil")
	Farmland.reset(world)
	for x in range(1,15):
		for z in range(1,15):
			var q := Vector3i(x,Y+3,z); fresh(world,q,Farmland.WET); Farmland.state(world,q).remaining = 0
	Farmland.update(world,0.001)
	t.check(Farmland.runtime(world).actions == Farmland.ACTION_BUDGET and not Farmland.runtime(world).jobs.is_empty(),"large simultaneously due field bounds water scanning to8 selected soil actions per frame")
	var queued: int = Farmland.runtime(world).jobs.size(); Farmland.update(world,0.001)
	t.check(Farmland.runtime(world).jobs.size() == maxi(0,queued-Farmland.ACTION_BUDGET),"pending soil is not repeatedly enqueued while work drains")
	for x in range(1,15):
		for z in range(1,15): world.set_node(Vector3i(x,Y+3,z),Nodes.AIR)
	await lifecycle(t,game,p)
	world = game.world
	for x in range(1,23):
		for z in range(1,16):
			for y in range(Y-1,Y+6): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	if old_weather == null: world.adventure_state.erase("weather")
	else: world.adventure_state.weather = old_weather
	game.day_time = old_time; game.pause(); freeze(game)

static func lifecycle(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world
	var edge := Vector3i(14,Y,8); fresh(world,edge,Farmland.WET); Farmland.state(world,edge).wet = 4
	world._unload(Vector2i(1,0)); Farmland.advance(world,edge)
	t.check(world.node_at(edge) == Farmland.WET and Farmland.state(world,edge).wet == 4,"unknown cells anywhere in the9x2x9 volume prevent moisture loss")
	world.set_node(edge+Vector3i.LEFT,Nodes.WATER); world.set_node(edge,Farmland.DRY); Farmland.advance(world,edge)
	t.check(world.node_at(edge) == Farmland.WET,"known nearby water hydrates even while another part of the source volume is unloaded")
	world.set_node(edge+Vector3i.LEFT,Nodes.AIR)
	world._apply_column(world.generator.generate_column(Vector2i(1,0),world.edits.duplicate()))
	# Real piston transaction must carry positive dry moisture and fractional time.
	var base: Vector3i = p+Vector3i(-3,0,0); var source: Vector3i = base+Vector3i.RIGHT; var dest: Vector3i = source+Vector3i.RIGHT
	fresh(world,source); world.set_node(dest,Nodes.AIR); Farmland.state(world,source).wet = 3; Farmland.state(world,source).remaining = 4.25
	world.set_node(base,Nodes.PISTON); world.circuits.configure(base,Vector3i.RIGHT)
	t.check(world.circuits.piston(base,true) and world.node_at(dest) == Farmland.DRY and Farmland.state(world,dest).wet == 3 and is_equal_approx(Farmland.state(world,dest).remaining,4.25),"actual piston push carries moisture and remaining time instead of constructing new dry soil")
	t.check(Farmland.runtime(world).cells.has(dest) and not Farmland.runtime(world).cells.has(source),"piston updates soil runtime identity to its destination")
	fresh(world,p+Vector3i.RIGHT*3,Farmland.WET)
	fresh(world,p); Farmland.state(world,p).wet = 5; Farmland.state(world,p).remaining = 8.75
	game.player.position = Vector3(8.5,Y+0.01,12.5)
	t.check(game.save_game("user://farmland-check.json"),"real save stores positive dry moisture and fractional timer")
	var saved: Dictionary = game.read_save("user://farmland-check.json"); game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await t.process_frame
	game.pause(); freeze(game); world = game.world
	t.check(world.node_at(p) == Farmland.DRY and Farmland.state(world,p).wet == 5 and Farmland.state(world,p).remaining > 8.5 and Farmland.state(world,p).remaining <= 8.75,"actual JSON reload retains dry node, moisture counter and fractional countdown")
	t.check(Farmland.runtime(world).cells.has(p),"saved edited farmland registers as a loaded soil after reload")
	t.check(world.node_at(p+Vector3i.RIGHT*3) == Farmland.WET and Farmland.state(world,p+Vector3i.RIGHT*3).wet == 7,"actual JSON reload also preserves wet node identity and full moisture")
	var before: Dictionary = Farmland.state(world,p).duplicate(true); world._unload(Vector2i.ZERO)
	t.check(not Farmland.runtime(world).cells.has(p),"actual column unload removes soil from active simulation")
	world._apply_column(world.generator.generate_column(Vector2i.ZERO,world.edits.duplicate()))
	t.check(Farmland.runtime(world).cells.has(p) and Farmland.state(world,p) == before,"column streaming preserves saved soil moisture and remaining timer without offline catch-up")
	world.set_node(p,Nodes.AIR)
	t.check(not Farmland.runtime(world).cells.has(p) and not world.block_states.get(VoxelWorld.station_key(p),{}).has("farmland"),"removing soil clears stale moisture and pending runtime state")
	world.set_node(p,Farmland.DRY)
	t.check(Farmland.state(world,p).wet == 0,"newly tilled soil at an old coordinate does not inherit removed moisture")

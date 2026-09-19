extends RefCounted

static func held(game: Node3D, id: int, enchantments: Dictionary = {}, count: int = 1) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0,"data":{"enchantments":enchantments}}

static func drops(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func raw_node(result: Dictionary, p: Vector3i) -> int:
	for block in result.blocks:
		if int(block.y) == floori(p.y/16.0): return int(block.data[VoxelWorld.local_index(p)])
	return Nodes.AIR

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game.gamemode = "survival"
	game.player.position = Vector3(2.5,1800,2.5)
	for container in [game.creatures,game.drops,game.entities]:
		for child in container.get_children(): child.queue_free()
	await t.process_frame
	var world: VoxelWorld = game.world
	var p := Vector3i(8,1800,8)
	for x in range(2,15):
		for z in range(2,15):
			world.set_node(Vector3i(x,1799,z),Nodes.STONE)
			for y in range(1800,1807): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	var inv := Inventory.new()
	for id in Amethyst.BLOCKS+[Amethyst.SHARD]:
		t.check(Nodes.exists(id) and Nodes.max_stack(id) == 64,"source amethyst material is registered: "+str(id))
	for id in [Amethyst.BLOCK,Amethyst.TINTED_GLASS]:
		var index: int = inv.recipe_index(id)
		var recipe: Dictionary = inv.recipes[index]
		inv.restore([])
		for ingredient in recipe.pattern:
			if ingredient != 0: inv.add_item(ingredient,1)
		t.check(inv.fill_grid(index,recipe.station) and inv.take_grid_result(recipe.station).get("id",0) == id,"amethyst recipe guide produces "+Nodes.title(id))
	for i in 9: inv.grid[i] = {"id":0,"count":0,"wear":0}
	for i in [0,1,3,4]: inv.grid[i] = {"id":Amethyst.SHARD,"count":1,"wear":0}
	t.check(inv.take_grid_result("hand").get("id",0) == Amethyst.BLOCK,"four harvested shards craft an amethyst block in the natural2x2 hand grid")
	for i in 9: inv.grid[i] = {"id":0,"count":0,"wear":0}
	for i in [1,3,5,7]: inv.grid[i] = {"id":Amethyst.SHARD,"count":1,"wear":0}
	inv.grid[4] = {"id":Nodes.GLASS,"count":1,"wear":0}
	var result: Dictionary = inv.take_grid_result("table")
	t.check(result.get("id",0) == Amethyst.TINTED_GLASS and result.get("count",0) == 2,"four shards around glass craft two tinted glass in the actual table grid")
	t.check(Nodes.smelt_result(Nodes.BASALT) == Amethyst.SMOOTH_BASALT,"basalt has its source smooth-basalt furnace recipe")
	t.check(NoteBlocks.instrument(Amethyst.TINTED_GLASS) == "hit" and NoteBlocks.instrument(Amethyst.SMOOTH_BASALT) == "bass_drum" and NoteBlocks.instrument(Amethyst.BLOCK) == "piano" and NoteBlocks.instrument(Amethyst.CALCITE) == "piano","new materials retain their source note-block groups without assigning stone to all minerals")
	for id in Amethyst.STAGES:
		var valid: bool = not Amethyst.icon_faces(id).is_empty()
		for face in Amethyst.icon_faces(id):
			var area: float = 0.0
			for i in face.points.size(): area += face.points[i].cross(face.points[(i+1)%face.points.size()])
			valid = valid and absf(area) > 0.00001 and Geometry2D.triangulate_polygon(face.points).size() == (face.points.size()-2)*3 and face.uv.size() == face.points.size()
		t.check(valid,"crystal inventory polygons have nonzero area, matching UVs and valid triangulation "+str(id))
	# The same six attachment directions govern placed and naturally grown crystals.
	for normal in Amethyst.SUPPORTS:
		world.set_node(p,Amethyst.BUDDING)
		var at: Vector3i = p+normal; world.set_node(at,Nodes.AIR)
		t.check(Amethyst.spawn_bud(world,p,normal) and Amethyst.support(world.node_at(at)) == -normal,"budding amethyst creates a small bud facing "+str(normal))
		for rank in 4:
			var id: int = world.node_at(at)
			var box: AABB = Amethyst.boxes(id)[0]
			var ray: Dictionary = world.raycast(Vector3(at)+box.get_center()+Vector3(normal),-Vector3(normal),2)
			t.check(Amethyst.stage(id) == rank and Amethyst.support(id) == -normal and Amethyst.light_level(id) == [1,2,4,5][rank] and world.collision_boxes(at).size() == 1 and not ray.is_empty() and ray.pos == at,"oriented growth stage has source light, collision and small selection shape "+str(id))
			var art: Array = BlockMesher._empty(); Amethyst.mesh(art,Vector3.ZERO,id)
			t.check(not art[0].is_empty() and not Amethyst.icon_faces(id).is_empty(),"all crystal orientations have original batched meshes and shaped item icons "+str(id))
			var buffer := PackedInt32Array(); buffer.resize(18*18*18); buffer[1+18+324] = id
			var built: Array = BlockMesher.build(buffer)
			t.check(not built[0].is_empty() and built[0][Mesh.ARRAY_VERTEX].size() == art[0].size(),"normal terrain meshing uses crystal geometry without adding a cube "+str(id))
			if rank < 3: t.check(Amethyst.grow_bud(world,at),"budding support advances the next amethyst stage "+str(id))
		t.check(not Amethyst.grow_bud(world,at),"mature cluster stops growing "+str(normal))
		var before: int = drops(game,Amethyst.SHARD); world.set_node(p,Nodes.AIR)
		t.check(world.node_at(at) == Nodes.AIR and drops(game,Amethyst.SHARD) == before+2,"removing support drops source environmental two shards on "+str(normal))
		world.set_node(at,Nodes.AIR)
	# Growth only uses its actual backing budding block, including under water.
	world.set_node(p,Amethyst.BUDDING); world.set_node(p+Vector3i.UP,Nodes.WATER)
	t.check(Amethyst.spawn_bud(world,p,Vector3i.UP) and world.node_at(p+Vector3i.UP) == Amethyst.SMALL,"budding blocks replace source water with a small crystal without inventing waterlogging")
	world.set_node(p,Nodes.STONE)
	t.check(world.node_at(p+Vector3i.UP) == Amethyst.SMALL and not Amethyst.grow_bud(world,p+Vector3i.UP),"a bud supported by ordinary stone stays attached but cannot advance")
	world.set_node(p+Vector3i.UP,Nodes.AIR); world.set_node(p,Amethyst.BUDDING); world.set_node(p+Vector3i.RIGHT,Nodes.GLASS)
	t.check(not Amethyst.spawn_bud(world,p,Vector3i.RIGHT) and world.node_at(p+Vector3i.RIGHT) == Nodes.GLASS,"bud creation does not overwrite a player building block")
	world.set_node(p+Vector3i.RIGHT,Nodes.AIR); world.set_node(p,Nodes.STONE)
	for normal in Amethyst.SUPPORTS:
		var at: Vector3i = p+normal; world.set_node(at,Nodes.AIR)
		held(game,Amethyst.MEDIUM); game.player.target = {"pos":p,"id":Nodes.STONE,"normal":normal,"distance":3}; game.player.use()
		t.check(Amethyst.item(world.node_at(at)) == Amethyst.MEDIUM and Amethyst.support(world.node_at(at)) == -normal and game.inventory.held().count == 0,"actual survival placement orients a Silk-obtainable crystal toward "+str(normal))
		world.set_node(at,Nodes.AIR)
	world.set_node(p,Nodes.AIR)
	world.set_node(p+Vector3i.DOWN,Nodes.STONE); world.set_node(p,Amethyst.SMALL)
	t.check(not world.intersects(Vector3(p)+Vector3(0.5,0.4,0.5)) and world.intersects(Vector3(p)+Vector3(0.5,0.1,0.5)),"real actor collision permits the empty space above a small bud but rejects its actual crystal box")
	world.set_node(p,Nodes.AIR)
	# Player harvesting uses autogroup before the source drop table.
	var pick: int = Nodes.TOOLS+5
	for id in Amethyst.BLOCKS:
		world.set_node(p+Vector3i.DOWN,Nodes.STONE)
		world.set_node(p,id); held(game,pick)
		var target: int = Amethyst.SHARD if id == Amethyst.CLUSTER else id
		var expected: int = 4 if id == Amethyst.CLUSTER else (0 if id in [Amethyst.SMALL,Amethyst.MEDIUM,Amethyst.LARGE,Amethyst.BUDDING] else 1)
		var before: int = drops(game,target); game.break_node(p,id,pick)
		t.check(world.node_at(p) == Nodes.AIR and drops(game,target) == before+expected,"actual pickaxe mining follows source amethyst drops "+str(id))
	for id in Amethyst.STAGES:
		world.set_node(p,id); held(game,pick,{"Silk Touch":1}); var before: int = drops(game,id); game.break_node(p,id,pick)
		t.check(drops(game,id) == before+1,"Silk Touch collects its exact bud or cluster stage "+str(id))
	world.set_node(p,Amethyst.BUDDING); held(game,pick,{"Silk Touch":1}); var budding_before: int = drops(game,Amethyst.BUDDING); game.break_node(p,Amethyst.BUDDING,pick)
	t.check(drops(game,Amethyst.BUDDING) == budding_before,"budding amethyst cannot be collected even with Silk Touch")
	for enchant in [{},{"Fortune":3}]:
		world.set_node(p,Amethyst.CLUSTER); held(game,pick,enchant); var before: int = drops(game,Amethyst.SHARD); game.break_node(p,Amethyst.CLUSTER,pick)
		t.check(drops(game,Amethyst.SHARD) == before+4,"source cluster gives four pickaxe shards with enchantments "+str(enchant))
	world.set_node(p,Amethyst.CLUSTER); held(game,Nodes.AIR); var hand_before: int = drops(game,Amethyst.SHARD); game.break_node(p,Amethyst.CLUSTER,Nodes.AIR)
	t.check(drops(game,Amethyst.SHARD) == hand_before,"source player harvestability blocks a bare-hand cluster drop")
	world.set_node(p,Amethyst.TINTED_GLASS); held(game,Nodes.AIR); var glass_before: int = drops(game,Amethyst.TINTED_GLASS); game.break_node(p,Amethyst.TINTED_GLASS,Nodes.AIR)
	t.check(drops(game,Amethyst.TINTED_GLASS) == glass_before+1,"tinted glass drops itself without Silk Touch or a tool")
	for transparent_id in [Amethyst.TINTED_GLASS,Beehives.HONEY_BLOCK]:
		game.player._make_hand(transparent_id)
		var hand_models: Array = game.player.hand.get_children().filter(func(child): return child is MeshInstance3D and not child.is_queued_for_deletion())
		t.check(hand_models.size() == 1 and hand_models[0].mesh.get_surface_count() == 1 and hand_models[0].material_override == world.water_material,"actual held translucent material has a visible mesh and its non-scissored material "+str(transparent_id))
		var dropped: ItemDrop = game.spawn_drop(Vector3(p)+Vector3.UP*3,transparent_id,1)
		t.check(dropped.mesh_instance.mesh.get_surface_count() == 1 and dropped.mesh_instance.material_override == world.water_material,"actual dropped translucent material retains the visible mesh and blend shader "+str(transparent_id))
		var tile: int = Nodes.tile(transparent_id,0)
		var uniform_name: String = "tinted_glass_tile" if transparent_id == Amethyst.TINTED_GLASS else "honey_tile"
		t.check(world.water_material.get_shader_parameter(uniform_name) == Vector2(tile%8,tile/8),"translucent miniature uses its stationary atlas classification "+str(transparent_id))
		dropped.queue_free()
	game.player._make_hand(Nodes.AIR)
	# Exercise circuit movement, not just the module's destroy helper.
	var piston: Vector3i = p+Vector3i(0,0,3)
	for id in [Amethyst.BUDDING,Amethyst.SMALL,Amethyst.CLUSTER]:
		world.set_node(piston,Nodes.PISTON); world.circuits.configure(piston,Vector3i.RIGHT)
		world.set_node(piston+Vector3i.RIGHT+Vector3i.DOWN,Nodes.STONE)
		world.set_node(piston+Vector3i.RIGHT,id); world.set_node(piston+Vector3i.RIGHT*2,Nodes.AIR)
		var before: int = drops(game,Amethyst.SHARD)
		t.check(world.circuits.piston(piston,true) and world.node_at(piston+Vector3i.RIGHT) == Nodes.PISTON_HEAD and world.node_at(piston+Vector3i.RIGHT*2) == Nodes.AIR and drops(game,Amethyst.SHARD) == before+(2 if id == Amethyst.CLUSTER else 0),"real piston destroys the source amethyst state with environmental drops "+str(id))
		world.circuits.piston(piston,false); world.set_node(piston,Nodes.AIR)
	world.set_node(piston,Nodes.STICKY_PISTON); world.circuits.configure(piston,Vector3i.RIGHT); world.circuits.piston(piston,true)
	world.set_node(piston+Vector3i.RIGHT*2+Vector3i.DOWN,Nodes.STONE); world.set_node(piston+Vector3i.RIGHT*2,Amethyst.CLUSTER)
	t.check(world.circuits.piston(piston,false) and world.node_at(piston+Vector3i.RIGHT) == Nodes.AIR and world.node_at(piston+Vector3i.RIGHT*2) == Amethyst.CLUSTER,"sticky piston leaves the unsticky amethyst crystal at its original support")
	for x in 3: world.set_node(piston+Vector3i.RIGHT*x,Nodes.AIR)
	world.set_node(piston,Nodes.PISTON); world.circuits.configure(piston,Vector3i.RIGHT)
	world.set_node(piston+Vector3i.RIGHT,Nodes.STONE); world.set_node(piston+Vector3i.RIGHT+Vector3i.UP,Amethyst.CLUSTER)
	var atomic_before: int = drops(game,Amethyst.SHARD)
	t.check(world.circuits.piston(piston,true) and world.node_at(piston+Vector3i.RIGHT+Vector3i.UP) == Amethyst.CLUSTER and drops(game,Amethyst.SHARD) == atomic_before,"atomic piston movement preserves a neighboring crystal when its backing stone is replaced by the piston head")
	t.check(world.circuits.piston(piston,false) and world.node_at(piston+Vector3i.RIGHT+Vector3i.UP) == Nodes.AIR and drops(game,Amethyst.SHARD) == atomic_before+2,"final piston support removal drops the unsupported cluster exactly once")
	for x in 3: world.set_node(piston+Vector3i.RIGHT*x,Nodes.AIR)
	# The real light solver sees a visually transparent tinted-glass roof as opaque.
	var light_pos: Vector3i = p+Vector3i.UP
	for x in range(-15,16):
		for z in range(-15,16): world.set_node(light_pos+Vector3i(x,2,z),Amethyst.TINTED_GLASS)
	game.daylight = 1.0
	t.check(Nodes.transparent(Amethyst.TINTED_GLASS) and RedstoneSensors.light_filter(Amethyst.TINTED_GLASS) == -1 and RedstoneSensors.natural_light(world,light_pos) == 0,"tinted glass blocks actual skylight while remaining visually transparent")
	for x in range(-15,16):
		for z in range(-15,16): world.set_node(light_pos+Vector3i(x,2,z),Nodes.AIR)
	world.set_node(p,Nodes.STONE); world.set_node(light_pos,Amethyst.CLUSTER)
	t.check(Pasture.emission(world,light_pos) == 5 and Pasture.block_light(world,light_pos+Vector3i.RIGHT,1) == 4,"grown crystal light participates in the existing gameplay block-light solver")
	world.set_node(p,Nodes.AIR)
	# One loaded ABM cycle, chance and runtime budget are separate from growth stages.
	Amethyst.reset(world); world.adventure_state.amethyst_elapsed = 0.0
	world.set_node(p,Amethyst.BUDDING); game.state = "playing"
	Amethyst.update(world,67.9)
	t.check(is_equal_approx(world.adventure_state.amethyst_elapsed,67.9) and world.node_at(p+Vector3i.UP) == Nodes.AIR,"amethyst does not grow before the source68-second interval")
	Amethyst.update(world,0.1)
	t.check(is_zero_approx(world.adventure_state.amethyst_elapsed),"source68-second cycle consumes one growth chance rather than a guaranteed stage")
	game.pause(); var elapsed: float = world.adventure_state.amethyst_elapsed; Amethyst.update(world,999)
	t.check(world.adventure_state.amethyst_elapsed == elapsed,"paused gameplay does not advance amethyst growth")
	# Natural acquisition is checked through normal terrain generation, not placement.
	var gen := TerrainGenerator.new(8675309)
	var started: int = Time.get_ticks_usec(); var geode: Dictionary = AmethystGeodes.candidate(gen,Vector2i(-8,6)); var cold: int = Time.get_ticks_usec()-started
	t.check(not geode.is_empty() and geode.origin == Vector3i(-121,-68,105),"real survival seed generates a natural amethyst geode")
	if geode.is_empty(): return
	var counts: Dictionary = {}
	for id in geode.voxels.values(): counts[Amethyst.item(id)] = int(counts.get(Amethyst.item(id),0))+1
	t.check(counts.has(Amethyst.BLOCK) and counts.has(Amethyst.BUDDING) and counts.has(Amethyst.CALCITE) and counts.has(Amethyst.SMOOTH_BASALT) and counts.has(Amethyst.CLUSTER) and counts.has(Nodes.AIR),"natural geode includes its hollow chamber, three source shell layers, budding blocks and harvestable clusters")
	var repeated := TerrainGenerator.new(8675309)
	t.check(AmethystGeodes.candidate(repeated,Vector2i(-8,6)) == geode,"geode shape and decoration do not depend on column request or cache order")
	var coords: Dictionary = {}; var crystal := Vector3i.ZERO
	for point in geode.voxels:
		coords[Vector2i(floori(point.x/16.0),floori(point.z/16.0))] = true
		if Amethyst.item(int(geode.voxels[point])) == Amethyst.CLUSTER: crystal = point
	for coord in coords:
		world._apply_column(gen.generate_column(coord,{},false))
	t.check(world.node_at(crystal) == geode.voxels[crystal] and world.loaded_at(Vector3(crystal)),"normal worker generation installs an obtainable crystal across geode column boundaries")
	held(game,pick); var natural_before: int = drops(game,Amethyst.SHARD); game.break_node(crystal,world.node_at(crystal),pick)
	t.check(drops(game,Amethyst.SHARD) == natural_before+4,"mining a naturally generated cluster produces the shards needed for survival recipes")
	var crystal_column := Vector2i(floori(crystal.x/16.0),floori(crystal.z/16.0))
	var edited: Dictionary = gen.generate_column(crystal_column,{crystal:Nodes.PLANKS},true)
	t.check(raw_node(edited,crystal) == Nodes.PLANKS,"player edits retain priority over regenerated geode geometry")
	var invalid: Dictionary = AmethystGeodes.plan(gen,Vector3i.ZERO,42,func(_at): return Nodes.BEDROCK)
	t.check(invalid.is_empty(),"source invalid-block threshold rejects geodes in bedrock")
	var preserved := Vector3i(3,-54,3)
	var protected_plan: Dictionary = AmethystGeodes.plan(gen,Vector3i(0,-60,0),42,func(at): return Nodes.CHEST if at == preserved else Nodes.STONE)
	t.check(not protected_plan.voxels.has(preserved),"geode carving never replaces a protected chest")
	t.check(AmethystGeodes.candidate(TerrainGenerator.new(8675309,"nether"),Vector2i.ZERO).is_empty(),"natural geodes are restricted to the Overworld")
	print("AMETHYST PROFILE cold_plan_us=",cold," cells=",geode.voxels.size()," columns=",coords.size())
	# Growth orientation and fractional ABM time survive real save/load.
	world.set_node(p,Amethyst.BUDDING); world.set_node(p+Vector3i.RIGHT,Amethyst.oriented(Amethyst.LARGE,Vector3i.RIGHT)); world.adventure_state.amethyst_elapsed = 23.75
	game.player.position = Vector3(8.5,1800.01,12.5)
	t.check(game.save_game("user://amethyst-check.json"),"amethyst growth fixture saves")
	var saved: Dictionary = game.read_save("user://amethyst-check.json"); game.set_process(true); game.load_world_data(saved); world = game.world
	t.check(is_equal_approx(float(world.adventure_state.get("amethyst_elapsed",0)),23.75),"loading restores fractional amethyst time before gameplay resumes")
	while game.state == "loading": await t.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false; world = game.world
	var restored_time: float = float(world.adventure_state.get("amethyst_elapsed",0))
	t.check(world.node_at(p+Vector3i.RIGHT) == Amethyst.oriented(Amethyst.LARGE,Vector3i.RIGHT) and restored_time >= 23.75 and restored_time < 24.0,"real save/load preserves crystal stage, wall orientation and growth time plus the resumed frame")
	world._unload(Vector2i.ZERO)
	t.check(not Amethyst.runtime(world).cells.has(p),"unloaded columns leave the active growth index")
	world._apply_column(world.generator.generate_column(Vector2i.ZERO,world.edits.duplicate()))
	t.check(Amethyst.runtime(world).cells.has(p) and Amethyst.grow_bud(world,p+Vector3i.RIGHT),"streaming restores a saved budding block and continues its attached crystal growth")
	var boundary := Vector3i(16,1800,8); var backing: Vector3i = boundary+Vector3i.LEFT
	world.set_node(backing,Amethyst.BUDDING); world.set_node(boundary,Amethyst.oriented(Amethyst.CLUSTER,Vector3i.RIGHT))
	world._unload(Vector2i.ZERO); Amethyst.validate_support(world,boundary)
	t.check(world.node_at(boundary) == Amethyst.oriented(Amethyst.CLUSTER,Vector3i.RIGHT),"an existing wall crystal survives while its backing column is unloaded")
	t.check(not Amethyst.supported(world,boundary,world.node_at(boundary),true),"new crystal placement requires known loaded backing support")
	world.edits[backing] = Nodes.AIR
	var boundary_before: int = drops(game,Amethyst.SHARD)
	world._apply_column(world.generator.generate_column(Vector2i.ZERO,world.edits.duplicate()))
	t.check(world.node_at(boundary) == Nodes.AIR and drops(game,Amethyst.SHARD) == boundary_before+2,"returning support column applies saved removal before dropping its neighboring crystal once")
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://amethyst-check.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

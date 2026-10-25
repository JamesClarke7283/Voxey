extends RefCounted

const PLOT_Y = 2200

static func held(game: Node3D, id: int, count: int = 1, data: Dictionary = {}) -> void:
	game.inventory.restore([])
	game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0,"data":data}
	game.player.eating.clear()
	game.player.use_cooldown = 0
	game.player.use_latched = false

static func mouse(game: Node3D, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = down
	event.position = game.get_viewport().get_visible_rect().size*0.5
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	game.player._process(0.016)

static func click(game: Node3D, at: Vector3) -> void:
	game.player.camera.look_at(at)
	game.player.use_cooldown = 0
	game.player.use_latched = false
	mouse(game,true)
	mouse(game,false)

static func drops(game: Node3D) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == CocoaCrops.BEANS: count += drop.amount
	return count

static func fresh(world: VoxelWorld, p: Vector3i, id: int, facing: int = 0) -> void:
	world.set_node(p,Nodes.AIR)
	world.set_node(p,id)
	if CocoaCrops.is_cocoa(id): CocoaCrops.set_facedir(world,p,facing)

static func same_box(a: AABB, b: AABB) -> bool:
	return a.position.is_equal_approx(b.position) and a.size.is_equal_approx(b.size)
static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	world._apply_column(world.generator.generate_column(Vector2i(floori(p.x/16.0),floori(p.z/16.0)),world.edits))
	return world.loaded_at(Vector3(p))

static func run(t: SceneTree, game: Node3D) -> void:
	game.state = "playing"
	game.gamemode = "survival"
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.world.active = false
	game.world.set_process(false)
	var world: VoxelWorld = game.world
	var p := Vector3i(8,PLOT_Y,8)
	t.check(ensure(game,p),"cocoa plot column is loaded")
	for x in range(3,13):
		for z in range(3,13):
			for y in range(PLOT_Y-1,PLOT_Y+3): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	var log_at: Vector3i = p+Vector3i.BACK
	world.set_node(log_at,CocoaCrops.JUNGLE_LOG)

	t.check(CocoaCrops.STAGES == [687,698,688] and CocoaCrops.BEANS == 816,"saved cocoa IDs remain stage1=687 stage2=698 stage3=688 and beans=816")
	for id in CocoaCrops.STAGES:
		t.check(Nodes.exists(id) and VillageContent.shape(id) == "cocoa" and Nodes.harvestable(id,0) and Nodes.transparent(id) and not Nodes.plant(id),"registry retains shaped non-plant cocoa stage "+str(id))
		t.check(is_equal_approx(Nodes.hardness(id),0.2) and not Nodes.placeable(id),"source hardness and hidden pod registration for "+str(id))
		var art: Array = BlockMesher._empty()
		CocoaCrops.mesh(art,Vector3.ZERO,id,0)
		t.check(not art[0].is_empty(),"owned procedural mesh exists for "+Nodes.title(id))
	var expected_boxes: Array = [
		AABB(Vector3(0.375,0.4375,0.6875),Vector3(0.25,0.3125,0.25)),
		AABB(Vector3(0.3125,0.3125,0.5625),Vector3(0.375,0.4375,0.375)),
		AABB(Vector3(0.25,0.1875,0.4375),Vector3(0.5,0.5625,0.5)),
	]
	for index in 3:
		t.check(same_box(CocoaCrops.boxes(CocoaCrops.STAGES[index])[0],expected_boxes[index]),"exact source selection/collision box for cocoa stage "+str(index+1))
	t.check(same_box(CocoaCrops.boxes(CocoaCrops.STAGE_1,1)[0],AABB(Vector3(0.6875,0.4375,0.375),Vector3(0.25,0.3125,0.25))),"facedir one rotates source box toward positive X")
	t.check(same_box(CocoaCrops.boxes(CocoaCrops.STAGE_3,2)[0],AABB(Vector3(0.25,0.1875,0.0625),Vector3(0.5,0.5625,0.5))),"facedir two rotates source box toward negative Z")
	for facing in 4:
		var support: Vector3i = CocoaCrops.support_direction(facing)
		t.check(CocoaCrops.facedir_for(support) == facing,"Luanti facedir round trip for horizontal support "+str(facing))
	t.check(CocoaCrops.facedir_for(Vector3i.UP) == -1,"vertical placement has no horizontal cocoa facedir")

	# Actual mouse placement: side of a normal jungle log, in survival.
	game.player.position = Vector3(8.5,PLOT_Y+0.01,5.5)
	game.player.rotation = Vector3.ZERO
	game.player.camera.position.y = 1.62
	held(game,CocoaCrops.BEANS,4)
	click(game,Vector3(log_at)+Vector3.ONE*0.5)
	t.check(world.node_at(p) == CocoaCrops.STAGE_1 and game.inventory.count_item(CocoaCrops.BEANS) == 3 and CocoaCrops.facedir(world,p) == 0,"actual survival use plants on jungle-log side and consumes one bean")
	var hit: Dictionary = world.raycast(Vector3(p)+Vector3(0.5,2.0,0.8),Vector3.DOWN,3.0)
	t.check(hit.get("pos",Vector3i.ZERO) == p and is_equal_approx(float(hit.get("point",Vector3.ZERO).y),p.y+0.75),"actual raycast selects the exact stage1 box top")
	t.check(world.collision_boxes(p) == CocoaCrops.world_boxes(world,p),"actual collision dispatcher uses the same facedir source box")
	fresh(world,p,CocoaCrops.STAGE_1)
	held(game,Nodes.BONE_MEAL,10)
	click(game,Vector3(p)+Vector3(0.5,0.60,0.80))
	t.check(world.node_at(p) == CocoaCrops.STAGE_2 and game.inventory.count_item(Nodes.BONE_MEAL) == 10,"source stage1 bone meal grows to stage2 but false callback does not consume")
	click(game,Vector3(p)+Vector3(0.5,0.55,0.75))
	t.check(world.node_at(p) == CocoaCrops.STAGE_3 and game.inventory.count_item(Nodes.BONE_MEAL) == 9,"source stage2 bone meal grows to stage3 and true callback consumes once")
	click(game,Vector3(p)+Vector3(0.5,0.55,0.75))
	t.check(world.node_at(p) == CocoaCrops.STAGE_3 and game.inventory.count_item(Nodes.BONE_MEAL) == 9,"mature cocoa neither grows nor consumes bone meal")

	# Placement rejects every nearby substitute while accepting axis variants of
	# the exact normal jungle-log node. Four orientations survive both growths.
	t.check(CocoaCrops.normal_jungle_log(6096) and CocoaCrops.normal_jungle_log(6104) and CocoaCrops.normal_jungle_log(6105),"normal jungle logs retain eligibility in all three axis variants")
	t.check(not CocoaCrops.normal_jungle_log(6100) and not CocoaCrops.normal_jungle_log(6101) and not CocoaCrops.normal_jungle_log(Nodes.LOG),"stripped logs, bark wood and other species cannot plant cocoa")
	for facing in 4:
		world.set_node(p,Nodes.AIR)
		world.set_node(log_at,Nodes.AIR)
		var direction: Vector3i = CocoaCrops.support_direction(facing)
		var support: Vector3i = p+direction
		world.set_node(support,CocoaCrops.JUNGLE_LOG)
		t.check(CocoaCrops.place(world,support,-direction) and CocoaCrops.facedir(world,p) == facing,"side-only placement stores facedir "+str(facing))
		var first_return: bool = CocoaCrops.grow(world,p)
		t.check(not first_return and world.node_at(p) == CocoaCrops.STAGE_2 and CocoaCrops.facedir(world,p) == facing,"stage1 source return quirk and metadata survive first growth "+str(facing))
		t.check(CocoaCrops.grow(world,p) and world.node_at(p) == CocoaCrops.STAGE_3 and CocoaCrops.facedir(world,p) == facing,"stage2 source return and metadata survive second growth "+str(facing))
		t.check(CocoaCrops.world_boxes(world,p) == CocoaCrops.boxes(CocoaCrops.STAGE_3,facing),"world geometry reads saved facedir "+str(facing))
		world.set_node(support,Nodes.AIR)
		world.set_node(p,Nodes.AIR)
	world.set_node(log_at,CocoaCrops.JUNGLE_LOG)
	t.check(not CocoaCrops.place(world,log_at,Vector3i.UP) and world.node_at(log_at+Vector3i.UP) == Nodes.AIR,"top-face placement is rejected")
	world.set_node(log_at,Nodes.STONE)
	t.check(not CocoaCrops.place(world,log_at,Vector3i.FORWARD) and world.node_at(p) == Nodes.AIR,"ordinary solid stone supports existing pods but cannot plant a new one")
	world.set_node(log_at,CocoaCrops.JUNGLE_LOG)

	# The source attachment check is broader than the planting check.
	world.set_node(log_at,Nodes.STONE)
	fresh(world,p,CocoaCrops.STAGE_2)
	CocoaCrops.refresh(world,p)
	t.check(world.node_at(p) == CocoaCrops.STAGE_2 and CocoaCrops.supported(world,p),"existing pod remains attached to a regular solid support")
	var before: int = drops(game)
	world.set_node(log_at,Nodes.AIR)
	t.check(world.node_at(p) == Nodes.AIR and drops(game) == before+1 and not CocoaCrops.runtime(world).cells.has(p),"support removal drops stage2's single bean and unindexes the pod")
	# Reconcile a worker cell after its edited support vanished.
	world.blocks[VoxelWorld.block_coord(p)].data[VoxelWorld.local_index(p)] = CocoaCrops.STAGE_1
	CocoaCrops.set_facedir(world,p,0)
	CocoaCrops.registered(world,p,true)
	before = drops(game)
	CocoaCrops.column_loaded(world,Vector2i.ZERO)
	t.check(world.node_at(p) == Nodes.AIR and drops(game) == before+1 and not CocoaCrops.runtime(world).pending.has(p),"column reconciliation removes unsupported cocoa and cancels its load roll")
	world.set_node(log_at,CocoaCrops.JUNGLE_LOG)

	# Fixed ordinary drops are independent of tools and enchantments.
	for id in CocoaCrops.STAGES:
		fresh(world,p,id)
		t.check(CocoaCrops.harvest(id) == [[CocoaCrops.BEANS,3 if id == CocoaCrops.STAGE_3 else 1]],"ordinary harvest table for "+Nodes.title(id))
		held(game,Nodes.TOOLS+16,1,{"enchantments":{"Fortune":3}})
		before = drops(game)
		game.break_node(p,id,Nodes.TOOLS+16)
		t.check(world.node_at(p) == Nodes.AIR and drops(game)-before == (3 if id == CocoaCrops.STAGE_3 else 1),"actual Fortune mining preserves fixed cocoa drop for "+Nodes.title(id))
	world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	world.set_node(p+Vector3i.RIGHT+Vector3i.DOWN,Nodes.STONE)
	fresh(world,p,CocoaCrops.STAGE_3)
	before = drops(game)
	world.set_node(p+Vector3i.RIGHT,Nodes.WATER)
	world.fluids.settle(p,Nodes.WATER)
	t.check(Fluids.water(world.node_at(p)) and drops(game) == before+3,"actual water flow washes away mature cocoa with three beans")
	world.set_node(p+Vector3i.RIGHT,Nodes.AIR)
	world.set_node(p,Nodes.AIR)
	fresh(world,p,CocoaCrops.STAGE_3)
	before = drops(game)
	world.set_node(p+Vector3i.RIGHT,Nodes.LAVA)
	world.fluids.settle(p,Nodes.LAVA)
	t.check(Fluids.lava(world.node_at(p)) and drops(game) == before,"actual lava flow destroys mature cocoa without drops")
	world.set_node(p+Vector3i.RIGHT,Nodes.AIR)
	world.set_node(p,Nodes.AIR)

	# Fifty-second ticks use one-in-twenty rolls in stable coordinate order.
	CocoaCrops.reset(world)
	fresh(world,p,CocoaCrops.STAGE_1)
	CocoaCrops.runtime(world).rng.seed = 481516
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 481516
	CocoaCrops.update(world,49.0)
	t.check(world.node_at(p) == CocoaCrops.STAGE_1,"no cocoa roll occurs before fifty active seconds")
	CocoaCrops.update(world,1.0)
	var expected_roll: int = expected_rng.randi_range(1,20)
	t.check(world.node_at(p) == (CocoaCrops.STAGE_2 if expected_roll == 1 else CocoaCrops.STAGE_1),"first scheduled cocoa tick uses exact one-in-twenty roll")
	var attempts: int = 1
	while not CocoaCrops.mature(world.node_at(p)) and attempts < 100:
		CocoaCrops.update(world,CocoaCrops.INTERVAL)
		expected_rng.randi_range(1,20)
		attempts += 1
	t.check(CocoaCrops.mature(world.node_at(p)) and not world.growth.has(p),"scheduled source ladder matures without legacy simplified growth timers")
	for x in range(3,13):
		var at := Vector3i(x,PLOT_Y,3)
		world.set_node(at+Vector3i.BACK,CocoaCrops.JUNGLE_LOG)
		fresh(world,at,CocoaCrops.STAGE_1)
		CocoaCrops.queue_growth(world,at)
	CocoaCrops.update(world,0)
	t.check(CocoaCrops.runtime(world).jobs.size() == 2,"cocoa scheduler processes at most eight queued actions per update")
	for x in range(3,13): world.set_node(Vector3i(x,PLOT_Y,3),Nodes.AIR)
	CocoaCrops.reset(world)
	fresh(world,p,CocoaCrops.STAGE_1)
	CocoaCrops.queue_growth(world,p)
	fresh(world,p,CocoaCrops.STAGE_1)
	CocoaCrops.update(world,0)
	t.check(world.node_at(p) == CocoaCrops.STAGE_1,"removed and replanted cocoa cannot inherit a stale growth job")
	CocoaCrops.reset(world)
	CocoaCrops.registered(world,p,true)
	CocoaCrops.registered(world,p,true)
	t.check(CocoaCrops.runtime(world).jobs.size() == 1,"repeated load registration queues only one ABM-style catch-up roll")
	CocoaCrops.unload(world,Vector2i.ZERO)
	t.check(CocoaCrops.runtime(world).jobs.is_empty() and not CocoaCrops.runtime(world).cells.has(p) and CocoaCrops.facedir(world,p) == 0,"column unload discards active work without deleting saved facedir")

	# Direct piston contact digs; adhesive side contact does not drag cocoa.
	game.gamemode = "creative"
	var base: Vector3i = p+Vector3i.LEFT
	world.set_node(base,Nodes.PISTON)
	world.circuits.configure(base,Vector3i.RIGHT)
	fresh(world,p,CocoaCrops.STAGE_3)
	before = drops(game)
	var pushed: bool = world.circuits.piston(base,true)
	t.check(pushed and world.node_at(p) == Nodes.PISTON_HEAD and drops(game) == before+3,"direct piston contact harvests mature cocoa in creative automation")
	world.circuits.piston(base,false)
	world.set_node(base,Nodes.AIR)
	t.check(PistonPush.diggable(CocoaCrops.STAGE_2) and PistonPush.unsticky(CocoaCrops.STAGE_2),"shared piston dispatcher sees dig_by_piston and unsticky")
	base = Vector3i(4,PLOT_Y,4)
	var crop: Vector3i = base+Vector3i.RIGHT+Vector3i.BACK
	world.set_node(crop+Vector3i.BACK,CocoaCrops.JUNGLE_LOG)
	world.set_node(base,Nodes.PISTON)
	world.circuits.configure(base,Vector3i.RIGHT)
	world.set_node(base+Vector3i.RIGHT,Beehives.HONEY_BLOCK)
	world.set_node(base+Vector3i.RIGHT*2,Nodes.AIR)
	fresh(world,crop,CocoaCrops.STAGE_2)
	before = drops(game)
	pushed = world.circuits.piston(base,true)
	t.check(pushed and world.node_at(crop) == CocoaCrops.STAGE_2 and drops(game) == before,"adhesive side contact leaves unsticky cocoa attached and undropped")
	world.circuits.piston(base,false)
	for x in range(3,8):
		for z in range(3,8): world.set_node(Vector3i(x,PLOT_Y,z),Nodes.AIR)
	game.gamemode = "survival"

	# Existing survival sources and uses remain real; no creative-only bean shortcut.
	t.check(BonusChest.should_offer("survival") and Composters.chance(CocoaCrops.BEANS) == 65,"existing survival acquisition and source65percent compostability remain available")
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = 8181
	var acquired: bool = false
	for index in 20:
		for stack in BonusChest.roll(loot_rng):
			if stack.id == CocoaCrops.BEANS and int(stack.count) in range(1,3): acquired = true
	t.check(acquired,"actual survival bonus-loot table still yields one or two cocoa beans")
	for index in 9: game.inventory.grid[index] = {"id":CocoaCrops.BEANS if index == 0 else 0,"count":1 if index == 0 else 0,"wear":0}
	t.check(game.inventory.take_grid_result("table").get("id",0) == VillageContent.DYE_BROWN,"existing bean-to-brown-dye crafting remains available")
	for index in 9: game.inventory.grid[index] = {"id":[Nodes.GRAIN,CocoaCrops.BEANS,Nodes.GRAIN][index] if index < 3 else 0,"count":1 if index < 3 else 0,"wear":0}
	var cookies: Dictionary = game.inventory.take_grid_result("table")
	t.check(cookies.get("id",0) == VillageContent.COOKIE and cookies.get("count",0) == 8,"existing shaped cookie recipe still consumes cocoa beans")
	var icon := Image.create(16,16,false,Image.FORMAT_RGBA8)
	CocoaCrops.draw(icon,CocoaCrops.BEANS)
	var painted: bool = false
	for y in 16:
		for x in 16:
			if icon.get_pixel(x,y).a > 0: painted = true
	t.check(painted,"owned bean inventory art is non-empty")

	var voxels := PackedInt32Array(); voxels.resize(18*18*18); voxels.fill(Nodes.AIR)
	var center: int = 1+18+324; voxels[center] = CocoaCrops.STAGE_3
	var built: Array = BlockMesher.build(voxels,true,null,PackedInt32Array(),{0:1})
	var expected_mesh: Array = BlockMesher._empty(); CocoaCrops.mesh(expected_mesh,Vector3.ZERO,CocoaCrops.STAGE_3,1)
	t.check(not built[0].is_empty() and built[0][0] == expected_mesh[0],"worker mesh dispatch consumes the saved facedir instead of default-facing geometry")
	fresh(world,p,CocoaCrops.STAGE_3,1)
	var snapshot: Dictionary = CocoaCrops.facing_snapshot(world,Vector2i.ZERO)
	t.check(snapshot.get(VoxelWorld.block_coord(p),{}).get(VoxelWorld.local_index(p),-1) == 1,"column remesh snapshots include the pod's saved direction")
	await persistence(t,game,p)
	# Leave no high-altitude fixture shading later ordered suites.
	for x in range(3,13):
		for z in range(3,13):
			for y in range(PLOT_Y-1,PLOT_Y+3): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.state = "playing"

static func persistence(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world
	world.set_node(p+Vector3i.RIGHT,CocoaCrops.JUNGLE_LOG)
	fresh(world,p,CocoaCrops.STAGE_3,1)
	held(game,CocoaCrops.BEANS,2)
	game.save_game("user://cocoa-crop-check.json")
	var saved: Dictionary = game.read_save("user://cocoa-crop-check.json")
	var key: String = VoxelWorld.station_key(p)
	t.check(saved.get("block_states",{}).get(key,{}).get(CocoaCrops.FACING_KEY,-1) == 1,"actual save serializes cocoa facedir in block-state metadata")
	game.set_process(true)
	world.set_process(true)
	game.load_world_data(saved)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	world = game.world
	t.check(ensure(game,p),"cocoa plot column is loaded after reload")
	game.pause()
	game.set_process(false)
	world.set_process(false)
	world.active = false
	game.player.set_process(false)
	game.player.set_physics_process(false)
	t.check(game.state != "loading" and world.node_at(p) == CocoaCrops.STAGE_3 and CocoaCrops.facedir(world,p) == 1 and game.inventory.count_item(CocoaCrops.BEANS) == 2,"actual save/load preserves mature ID, facedir and survival beans")
	t.check(CocoaCrops.supported(world,p) and world.node_at(p+Vector3i.RIGHT) == CocoaCrops.JUNGLE_LOG,"restored facedir still resolves the original supporting log")
	CocoaCrops.reset(world)
	t.check(not world.has_meta("cocoa_crops"),"dimension/reset clears only cocoa runtime indexes")
	for path in ["user://cocoa-crop-check.json","user://cocoa-crop-check.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

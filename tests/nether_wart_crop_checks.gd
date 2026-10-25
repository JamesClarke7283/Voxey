extends RefCounted

const PLOT_Y = 2400

static func held(game: Node3D, id: int, count: int = 1, data: Dictionary = {}) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0,"data":data}
	game.player.eating.clear(); game.player.use_cooldown = 0; game.player.use_latched = false

static func mouse(game: Node3D, down: bool) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = down
	event.position = game.get_viewport().get_visible_rect().size*0.5; event.global_position = event.position
	Input.parse_input_event(event); Input.flush_buffered_events(); game.player._process(0.016)

static func click(game: Node3D, at: Vector3) -> void:
	game.player.camera.look_at(at); game.player.use_cooldown = 0; game.player.use_latched = false
	mouse(game,true); mouse(game,false)

static func drops(game: Node3D, id: int = NetherWartCrops.ITEM) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == id: count += drop.amount
	return count

static func fresh(world: VoxelWorld, p: Vector3i, id: int) -> void:
	world.set_node(p,Nodes.AIR); world.set_node(p,id)

static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	world._apply_column(world.generator.generate_column(Vector2i(floori(p.x/16.0),floori(p.z/16.0)),world.edits))
	return world.loaded_at(Vector3(p))
static func run(t: SceneTree, game: Node3D) -> void:
	game._clear_entities(); await t.process_frame
	game.state = "playing"; game.gamemode = "survival"; game.daylight = 1; game.day_time = 0.3
	game.player.set_process(false); game.player.set_physics_process(false); game.world.active = false; game.world.set_process(false)
	var world: VoxelWorld = game.world
	for x in range(1,16):
		for z in range(1,16):
			for y in range(PLOT_Y-1,PLOT_Y+7): world.set_node(Vector3i(x,y,z),Nodes.SOUL_SAND if y == PLOT_Y-1 else Nodes.AIR)
	var p := Vector3i(8,PLOT_Y,8)
	t.check(ensure(game,p),"wart plot column is loaded")
	game.player.position = Vector3(8.5,PLOT_Y+0.01,12.5); game.player.rotation = Vector3.ZERO; game.player.camera.position.y = 1.62
	t.check(NetherWartCrops.STAGES == [563,564,565,566] and NetherWartCrops.ITEM == 774 and NetherWartCrops.INTERVAL == 35.0 and NetherWartCrops.CHANCE == 11,"saved wart IDs and source35second one-in-11 ABM constants")
	t.check(NetherWartCrops.SOIL == [Nodes.SOUL_SAND] and NetherWartCrops.soil(Nodes.SOUL_SAND) and not NetherWartCrops.soil(Campfires.SOUL_SOIL),"the complete source soil_nether_wart registration is soul sand only")
	held(game,NetherWartCrops.ITEM,4); game.player.hunger = 10
	click(game,Vector3(p)+Vector3(0.5,-0.04,0.5))
	t.check(world.node_at(p) == 563 and game.inventory.count_item(NetherWartCrops.ITEM) == 3 and game.player.hunger == 10 and game.player.eating.is_empty(),"actual hungry survival mouse use plants stage1 once on soul sand")
	world.set_node(p,Nodes.AIR); game.gamemode = "creative"; click(game,Vector3(p)+Vector3(0.5,-0.04,0.5))
	t.check(world.node_at(p) == 563 and game.inventory.count_item(NetherWartCrops.ITEM) == 3,"creative planting preserves the wart item")
	game.gamemode = "survival"; world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.DOWN,Campfires.SOUL_SOIL)
	click(game,Vector3(p)+Vector3(0.5,-0.04,0.5))
	t.check(world.node_at(p) == Nodes.AIR and game.inventory.count_item(NetherWartCrops.ITEM) == 3,"actual use refuses soul soil because it lacks the source wart-soil group")
	world.set_node(p+Vector3i.DOWN,Nodes.SOUL_SAND)
	for replaceable in [Nodes.AIR,SnowCover.BASE,Nodes.WATER,Nodes.FLOWER]:
		t.check(NetherWartCrops.buildable_to(replaceable),"source buildable_to placement accepts replacement ID "+str(replaceable))
	t.check(not NetherWartCrops.buildable_to(Nodes.STONE),"source placement cannot replace an ordinary solid")
	var heights: Array = [0.375,0.65,0.65,0.95]
	for index in 4:
		var id: int = NetherWartCrops.STAGES[index]; world.set_node(p,id)
		var selected: Dictionary = world.raycast(Vector3(p)+Vector3(0.5,2,0.5),Vector3.DOWN,3)
		var art: Array = BlockMesher._empty(); NetherWartCrops.mesh(art,Vector3.ZERO,id)
		var boxes: Array = NetherWartCrops.boxes(id)
		t.check(Nodes.exists(id) and not Nodes.solid(id) and world.collision_boxes(p).is_empty() and boxes.size() == 1 and boxes[0].position == Vector3.ZERO and absf(boxes[0].size.y-heights[index]) < 0.0001 and selected.get("pos",Vector3i.ZERO) == p and absf(selected.get("point",Vector3.ZERO).y-(p.y+heights[index])) < 0.001 and not art[0].is_empty(),"registry, exact selection, noncollision and original mesh for "+Nodes.title(id))
		if not NetherWartCrops.mature(id):
			t.check(NetherWartCrops.harvest(id,{"id":Nodes.TOOLS+16,"data":{"enchantments":{"Fortune":3,"Silk Touch":1}}},EnchantRolls.new(91)) == [[NetherWartCrops.ITEM,1]],"immature wart drops one item regardless of Fortune or Silk Touch")
	var identical: bool = true
	for y in 16:
		for x in 16:
			if NetherWartCrops.pixel(564,x,y,Color.WHITE) != NetherWartCrops.pixel(565,x,y,Color.WHITE): identical = false
	t.check(identical,"source stages2and3 share the same plant texture")
	var icon: Image = ItemArt.texture(NetherWartCrops.ITEM).get_image()
	t.check(icon != null and icon.get_width() == 16 and Composters.chance(NetherWartCrops.ITEM) == 30,"original wart inventory art and existing30percent compost acquisition path")
	fresh(world,p,563); held(game,Nodes.BONE_MEAL,10); click(game,Vector3(p)+Vector3(0.5,0.06,0.5))
	t.check(world.node_at(p) == 563 and game.inventory.count_item(Nodes.BONE_MEAL) == 10 and not NetherWartCrops.bone_meal(world,p).grew,"actual bone meal neither grows wart nor consumes an item because the source has no callback")
	# Growth is dimension- and light-independent, including the direct source step.
	for dimension in ["overworld","nether","end"]:
		world.dimension = dimension; fresh(world,p,563)
		t.check(NetherWartCrops.grow(world,p) and world.node_at(p) == 564,"one source growth step works in "+dimension)
	world.dimension = "overworld"
	for x in range(6,11):
		for z in range(6,11): world.set_node(Vector3i(x,PLOT_Y+5,z),Nodes.STONE)
	game.daylight = 0.0
	fresh(world,p,565)
	t.check(Pasture.light(world,p,14) == 0 and NetherWartCrops.grow(world,p) and NetherWartCrops.mature(world.node_at(p)),"covered darkness neither blocks nor slows wart growth")
	for x in range(6,11):
		for z in range(6,11): world.set_node(Vector3i(x,PLOT_Y+5,z),Nodes.AIR)
	game.daylight = 1.0
	NetherWartCrops.reset(world); fresh(world,p,563); world.growth[p] = 29.0; NetherWartCrops.registered(world,p,true)
	t.check(not world.growth.has(p),"load registration retires the simplified30second timer")
	NetherWartCrops.runtime(world).rng.seed = 9021
	for i in 500:
		NetherWartCrops.update(world,NetherWartCrops.INTERVAL)
		if NetherWartCrops.mature(world.node_at(p)): break
	t.check(world.node_at(p) == 566 and not world.growth.has(p),"loaded source scheduling matures through every stage without the generic timer")
	fresh(world,p,566); var mature_clock: float = NetherWartCrops.runtime(world).clock
	for i in 20: NetherWartCrops.update(world,NetherWartCrops.INTERVAL)
	t.check(world.node_at(p) == 566 and NetherWartCrops.runtime(world).clock == mature_clock,"mature wart has no further ABM growth")
	await probabilities(t,game,p)
	await environment_checks(t,game,p)
	await persistence(t,game,p)

static func probabilities(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 4077
	var ordinary: Dictionary = {}; var enchanted: Dictionary = {}
	for i in 12000:
		var result: Array = NetherWartCrops.harvest(566,{},EnchantRolls.new(1,rng)); var amount: int = 0
		for entry in result: amount += int(entry[1])
		ordinary[amount] = int(ordinary.get(amount,0))+1
		result = NetherWartCrops.harvest(566,{"id":Nodes.TOOLS+16,"data":{"enchantments":{"Fortune":3}}},EnchantRolls.new(1,rng)); amount = result[0][1]
		enchanted[amount] = int(enchanted.get(amount,0))+1
	t.check(ordinary.size() == 3 and ordinary.get(2,0) in range(4900,5701) and ordinary.get(3,0) in range(2300,3051) and ordinary.get(4,0) in range(3700,4301),"ordinary mature drops follow ordered2thenrarity3twoorone source stacks")
	t.check(enchanted.size() == 6 and enchanted.keys().all(func(amount): return amount >= 2 and amount <= 7 and enchanted[amount] > 1200 and enchanted[amount] < 2800),"FortuneIII replaces the ordinary table with uniform2through7 and no cap")
	for slot in [{"id":Nodes.TOOLS+16,"data":{"enchantments":{"Silk Touch":1}}},{"id":791,"data":{"enchantments":{"Fortune":3}}}]:
		var plain_rng := RandomNumberGenerator.new(); plain_rng.seed = 157
		var source_drop: Array = NetherWartCrops.harvest(566,{},EnchantRolls.new(1,plain_rng)); plain_rng.seed = 157
		t.check(NetherWartCrops.harvest(566,slot,EnchantRolls.new(1,plain_rng)) == source_drop,"Silk Touch alone and enchanted books preserve ordinary registered wart drops")
	game.world.set_node(p+Vector3i.DOWN,Nodes.SOUL_SAND); fresh(game.world,p,566); held(game,Nodes.TOOLS+16,1,{"enchantments":{"Fortune":3}})
	var before: int = drops(game); game.break_node(p,566,Nodes.TOOLS+16)
	t.check(game.world.node_at(p) == Nodes.AIR and drops(game)-before in range(2,8),"actual enchanted survival mining uses the source Fortune replacement")
	await game.get_tree().process_frame

static func environment_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world; world.set_node(p+Vector3i.DOWN,Nodes.SOUL_SAND); fresh(world,p,563)
	var before: int = drops(game); world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	t.check(world.node_at(p) == Nodes.AIR and drops(game) == before+1 and not NetherWartCrops.runtime(world).cells.has(p),"attached-node support loss uproots once with ordinary drops and forgets runtime state")
	world.set_node(p+Vector3i.DOWN,Nodes.SOUL_SAND); fresh(world,p,563); before = drops(game); world.set_node(p+Vector3i.RIGHT,Nodes.WATER); world.fluids.settle(p,Nodes.WATER)
	t.check(Fluids.water(world.node_at(p)) and drops(game) == before+1,"actual water flow digs wart with its ordinary drop")
	world.set_node(p+Vector3i.RIGHT,Nodes.AIR); world.set_node(p,Nodes.AIR); fresh(world,p,566); before = drops(game); world.set_node(p+Vector3i.RIGHT,Nodes.LAVA); world.fluids.settle(p,Nodes.LAVA)
	t.check(Fluids.lava(world.node_at(p)) and drops(game) == before,"actual lava flow destroys mature wart without drops")
	world.set_node(p+Vector3i.RIGHT,Nodes.AIR); world.set_node(p,Nodes.AIR)
	# Adhesive side contact must leave every wart stage alone; direct contact digs.
	var base: Vector3i = p-Vector3i.RIGHT*3; var crop: Vector3i = base+Vector3i.RIGHT+Vector3i.BACK
	world.set_node(base,Nodes.PISTON); world.circuits.configure(base,Vector3i.RIGHT)
	world.set_node(base+Vector3i.RIGHT+Vector3i.DOWN,Nodes.AIR); world.set_node(crop+Vector3i.DOWN,Nodes.SOUL_SAND)
	world.set_node(base+Vector3i.RIGHT,Beehives.HONEY_BLOCK); world.set_node(base+Vector3i.RIGHT*2,Nodes.AIR)
	fresh(world,crop,565); before = drops(game); game.gamemode = "creative"
	var moved: bool = world.circuits.piston(base,true)
	t.check(moved and world.node_at(crop) == 565 and drops(game) == before,"real adhesive piston observes source unsticky on side contact")
	world.circuits.piston(base,false); world.set_node(base+Vector3i.RIGHT*2,Nodes.AIR); world.set_node(crop,Nodes.AIR)
	world.set_node(base+Vector3i.RIGHT+Vector3i.DOWN,Nodes.SOUL_SAND); world.set_node(base+Vector3i.RIGHT,566); before = drops(game)
	var pushed: bool = world.circuits.piston(base,true)
	t.check(pushed and world.node_at(base+Vector3i.RIGHT) == Nodes.PISTON_HEAD and drops(game)-before in range(2,5),"direct piston contact digs mature wart with its ordinary table even in creative automation")
	world.circuits.piston(base,false); world.set_node(base,Nodes.AIR); game.gamemode = "survival"
	# Reconcile a worker snapshot whose edited support disappeared before arrival.
	world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	world.blocks[VoxelWorld.block_coord(p)].data[VoxelWorld.local_index(p)] = 563
	NetherWartCrops.registered(world,p,true); before = drops(game); NetherWartCrops.column_loaded(world,Vector2i(0,0))
	t.check(world.node_at(p) == Nodes.AIR and drops(game) == before+1,"loaded-column edit reconciliation removes unsupported worker wart exactly once")
	world.set_node(p+Vector3i.DOWN,Nodes.SOUL_SAND)
	t.check(WorldStructures.fortress_node(Vector3i(55,28,64)) == Nodes.SOUL_SAND and WorldStructures.fortress_node(Vector3i(55,29,64)) == 563,"survival fortress generation provides source stage-one wart over soul sand")

static func persistence(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world; fresh(world,p,565); held(game,NetherWartCrops.ITEM,17)
	game.player.position = Vector3(8.5,PLOT_Y,12.5)
	game.save_game("user://nether-wart-check.json"); var saved: Dictionary = game.read_save("user://nether-wart-check.json")
	game.set_process(true); world.set_process(true); game.load_world_data(saved)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	world = game.world
	t.check(ensure(game,p),"wart plot column is loaded after reload")
	game.pause(); game.set_process(false); world.set_process(false); world.active = false; game.player.set_process(false); game.player.set_physics_process(false)
	t.check(game.state != "loading" and world.node_at(p) == 565 and game.inventory.count_item(NetherWartCrops.ITEM) == 17 and NetherWartCrops.runtime(world).cells.has(p),"actual save/load preserves saved stage and inventory and registers the loaded crop")
	NetherWartCrops.unload(world,Vector2i(0,0))
	t.check(not NetherWartCrops.runtime(world).cells.has(p) and world.node_at(p) == 565,"column unload drops runtime indexes without deleting saved wart")
	NetherWartCrops.registered(world,p,true); NetherWartCrops.registered(world,p,true)
	t.check(NetherWartCrops.runtime(world).cells.has(p) and NetherWartCrops.runtime(world).columns[Vector2i(0,0)].size() == 1,"repeated loaded-column registration remains idempotent")
	NetherWartCrops.reset(world)
	t.check(not world.has_meta("nether_wart_crops"),"dimension/reset clears all wart runtime indexes")
	for x in range(1,16):
		for z in range(1,16):
			for y in range(PLOT_Y+6,PLOT_Y-2,-1): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.state = "playing"; game.player.set_process(false); game.player.set_physics_process(false)

extends RefCounted

# Focused source-parity checks for Decor's flowerpot half. The expected table is
# deliberately independent of Decor.POTTABLE so a broadened or misspelled source
# registration cannot make the checks agree with the implementation by accident.
const EXPECTED = {
	"mcl_flowers:poppy":5610,"mcl_flowers:dandelion":5611,"mcl_flowers:oxeye_daisy":5612,
	"mcl_flowers:tulip_orange":11400,"mcl_flowers:tulip_pink":11401,"mcl_flowers:tulip_red":11402,
	"mcl_flowers:tulip_white":11403,"mcl_flowers:allium":11404,"mcl_flowers:azure_bluet":11405,
	"mcl_flowers:blue_orchid":11406,"mcl_flowers:wither_rose":11407,"mcl_flowers:lily_of_the_valley":11408,
	"mcl_flowers:cornflower":11409,"mcl_flowers:fern":11410,
	"mcl_core:deadbush":13601,"mcl_mushrooms:mushroom_red":57,"mcl_mushrooms:mushroom_brown":58,
	"mcl_core:cactus":14,"mcl_bamboo:bamboo_small":1174,
	"mcl_trees:sapling_oak":23,"mcl_trees:sapling_spruce":6034,"mcl_trees:sapling_birch":6066,
	"mcl_trees:sapling_jungle":6098,"mcl_trees:sapling_acacia":6130,"mcl_trees:sapling_dark_oak":6162,
	"mcl_trees:sapling_cherry":13003,"mcl_trees:sapling_pale_oak":13067,"mcl_mangrove:propagule":13035,
	"mcl_lush_caves:azalea":11472,"mcl_lush_caves:azalea_flowering":11473,
	"mcl_crimson:crimson_fungus":11511,"mcl_crimson:warped_fungus":11512,
	"mcl_crimson:crimson_roots":11513,"mcl_crimson:warped_roots":11514,
	"mcl_flowers:eyeblossom":11528,"mcl_flowers:eyeblossom_open":11529,
}

static func held(game: Node3D, id: int, count: int = 1) -> void:
	game.inventory.restore([])
	if id != 0: game.inventory.add_item(id,count)
	game.inventory.selected = 0

static func target(at: Vector3i) -> Dictionary:
	return {"pos":at,"normal":Vector3i.UP,"id":Decor.POT,"distance":1.0,"point":Vector3(at)+Vector3.ONE*0.5}

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.queue_free()

static func drop_count(game: Node3D, id: int) -> int:
	var result: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: result += drop.amount
	return result

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var at := Vector3i(40,1900,40)
	if not world.loaded_at(Vector3(at)): world._apply_column(world.generator.generate_column(Vector2i(floori(at.x/16.0),floori(at.z/16.0)),world.edits))
	t.check(world.loaded_at(Vector3(at)),"flowerpot plot column is loaded")
	for x in range(-3,4):
		for z in range(-3,4):
			world.set_node(at+Vector3i(x,-1,z),Nodes.STONE)
			for y in range(5): world.set_node(at+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(at)+Vector3(0.5,0,-4.5)
	world.set_node(at,Decor.POT)

	# Exactly the 36 source itemstrings, including the eight newly available ids.
	t.check(Decor.POTTABLE.size() == 36 and EXPECTED.size() == 36,"the flowerpot whitelist has exactly 36 source entries")
	for source in EXPECTED:
		var id: int = EXPECTED[source]
		t.check(Decor.accepts(id) and Decor.POTTABLE.get(id,"") == source,"pot accepts exactly "+source)
	t.check(not Decor.accepts(Nodes.VINE),"ordinary vine is not in the source flowerpot whitelist")
	t.check(not Decor.accepts(13099) and not Decor.accepts(13131),"legacy crimson and warped saplings are not source pot entries")
	t.check(not Decor.accepts(FoodFeatures.TALL_GRASS) and not Decor.accepts(FlowersExtra.BUSH),"plant and flower-like groups cannot broaden the exact whitelist")

	# Exercise the real interaction path for every accepted entry, not merely the
	# predicate: insertion consumes one, the same plant is a survival no-op, and
	# an empty hand retrieves the stored item.
	var interactions_ok: bool = true
	for id in EXPECTED.values():
		world.set_node(at,Decor.POT); Decor.set_contents(world,at,0)
		held(game,id,2)
		var inserted: bool = Decor.use(game,target(at))
		var stored: bool = Decor.contents(world,at) == id and game.inventory.count_item(id) == 1
		var same: bool = Decor.use(game,target(at))
		var unchanged: bool = Decor.contents(world,at) == id and game.inventory.count_item(id) == 1
		held(game,0)
		var removed: bool = Decor.use(game,target(at))
		if not (inserted and stored and same and unchanged and removed and Decor.contents(world,at) == 0 and game.inventory.count_item(id) == 1): interactions_ok = false
		if not (inserted and stored and same and unchanged and removed and Decor.contents(world,at) == 0 and game.inventory.count_item(id) == 1): print("POT interaction ",id," inserted=",inserted," stored=",stored," same=",same," unchanged=",unchanged," removed=",removed," contents=",Decor.contents(world,at)," count=",game.inventory.count_item(id)," pot=",world.node_at(at))
	t.check(interactions_ok,"all 36 accepted plants insert, preserve the same-plant no-op and remove through real use")
	for rejected in [Nodes.VINE,13099,13131]:
		Decor.set_contents(world,at,0); held(game,rejected)
		var used: bool = Decor.use(game,target(at))
		t.check(not used and Decor.contents(world,at) == 0 and game.inventory.count_item(rejected) == 1,"rejected item "+str(rejected)+" neither enters nor is consumed")

	# Empty-pot placement now owns the attached-node support gate.
	world.set_node(at,Nodes.AIR); held(game,Decor.POT,2)
	Decor.try_place(game,{"pos":at+Vector3i.DOWN,"normal":Vector3i.UP,"id":Nodes.STONE})
	t.check(world.node_at(at) == Decor.POT and game.inventory.count_item(Decor.POT) == 1,"a flowerpot places on its attached support and consumes one item; pot="+str(world.node_at(at))+" count="+str(game.inventory.count_item(Decor.POT)))
	held(game,FoodFeatures.POPPY); Decor.use(game,target(at))
	clear_drops(game)
	world.set_node(at+Vector3i.DOWN,Nodes.AIR)
	t.check(world.node_at(at) == Nodes.AIR,"losing the block beneath an occupied pot removes the pot; actual="+str(world.node_at(at)))
	t.check(drop_count(game,Decor.POT) == 1 and drop_count(game,FoodFeatures.POPPY) == 1,"support loss drops both the pot and its actual plant; pot="+str(drop_count(game,Decor.POT))+" plant="+str(drop_count(game,FoodFeatures.POPPY)))
	var unsupported: Vector3i = at+Vector3i.RIGHT
	world.set_node(unsupported+Vector3i.DOWN,Nodes.AIR); world.set_node(unsupported,Nodes.AIR)
	held(game,Decor.POT)
	Decor.try_place(game,{"pos":unsupported+Vector3i.DOWN,"normal":Vector3i.UP,"id":Nodes.AIR})
	t.check(world.node_at(unsupported) == Nodes.AIR and game.inventory.count_item(Decor.POT) == 1,"placement over missing support is refused without consuming the pot")

	# Ordinary breaking retains the same two drops independently of support loss.
	world.set_node(at+Vector3i.DOWN,Nodes.STONE); world.set_node(at,Decor.POT)
	Decor.set_contents(world,at,FlowersExtra.FERN); clear_drops(game)
	Decor.break_node(game,at,Decor.POT,0)
	t.check(world.node_at(at) == Nodes.AIR and drop_count(game,Decor.POT) == 1 and drop_count(game,FlowersExtra.FERN) == 1,"breaking an occupied pot drops its pot and fern")
	clear_drops(game)

	# Potted eyeblossoms use their own saved plant state and the source's 2 s,
	# chance-2 ABMs in both directions. A fixed world seed makes the update rolls
	# reproducible; the loop bounds are not timing requirements.
	t.check(Decor.EYEBLOSSOM_INTERVAL == 2.0 and Decor.EYEBLOSSOM_CHANCE == 2,"potted eyeblossoms retain source ABM interval and chance")
	world.set_node(at,Decor.POT)
	var roll_rng := RandomNumberGenerator.new(); roll_rng.seed = 7331
	var successful_rolls: int = 0
	for attempt in 24:
		Decor.set_contents(world,at,PaleOak.EYEBLOSSOM)
		if Decor.eyeblossom_step(world,at,0.9,roll_rng): successful_rolls += 1
	t.check(successful_rolls > 0 and successful_rolls < 24,"the potted ABM chance gate produces both deferred and successful source rolls; successes="+str(successful_rolls)+" pot="+str(world.node_at(at))+" plant="+str(Decor.contents(world,at)))
	Decor.set_contents(world,at,PaleOak.EYEBLOSSOM)
	for attempt in 8: Decor.eyeblossom_step(world,at,0.5,roll_rng)
	t.check(Decor.contents(world,at) == PaleOak.EYEBLOSSOM,"a closed potted eyeblossom never opens during the source day window")
	world.set_node(at,Decor.POT); Decor.reset(world); Decor.set_contents(world,at,PaleOak.EYEBLOSSOM)
	var saved_day: float = game.day_time
	game.day_time = 0.9
	Decor.update(game,1.99)
	t.check(Decor.contents(world,at) == PaleOak.EYEBLOSSOM and float(Decor._runtime(world).clock) > 1.9,"no potted eyeblossom roll occurs before the two-second interval; plant="+str(Decor.contents(world,at))+" clock="+str(Decor._runtime(world).clock))
	for attempt in 64:
		Decor.update(game,Decor.EYEBLOSSOM_INTERVAL)
		if Decor.contents(world,at) == PaleOak.EYEBLOSSOM_OPEN: break
	t.check(Decor.contents(world,at) == PaleOak.EYEBLOSSOM_OPEN and int(world.block_states[VoxelWorld.station_key(at)].pot_plant) == PaleOak.EYEBLOSSOM_OPEN,"night opens the saved potted eyeblossom metadata; actual="+str(Decor.contents(world,at)))
	game.day_time = 0.5
	for attempt in 64:
		Decor.update(game,Decor.EYEBLOSSOM_INTERVAL)
		if Decor.contents(world,at) == PaleOak.EYEBLOSSOM: break
	t.check(Decor.contents(world,at) == PaleOak.EYEBLOSSOM and int(world.block_states[VoxelWorld.station_key(at)].pot_plant) == PaleOak.EYEBLOSSOM,"day closes the saved potted eyeblossom metadata")
	game.day_time = saved_day

	# Rendering consumes a detached snapshot of the saved plant. The body remains
	# present, while the occupied snapshot adds geometry carrying the actual
	# plant's atlas cell rather than the pot texture or a stale hard-coded plant.
	Decor.set_contents(world,at,PaleOak.EYEBLOSSOM_OPEN)
	var snapshot: Dictionary = Decor.pot_snapshot(world,at)
	var body: Array = BlockMesher._empty(); Decor.pot_body_mesh(body,Vector3.ZERO)
	var rendered: Array = BlockMesher._empty(); Decor.pot_snapshot_mesh(rendered,Vector3.ZERO,snapshot)
	t.check(snapshot.get("pot",0) == Decor.POT and snapshot.get("plant",0) == PaleOak.EYEBLOSSOM_OPEN,"the render snapshot contains the pot identity and actual saved plant")
	t.check(not body[0].is_empty() and rendered[0].size() > body[0].size(),"snapshot rendering draws the pot body plus its plant")
	var tile: int = Nodes.tile(PaleOak.EYEBLOSSOM_OPEN,0)
	var atlas_cell := Vector2(tile%8,tile/8)
	t.check(rendered[3].has(atlas_cell),"the plant geometry uses the actual open eyeblossom atlas tile")
	var direct: Array = BlockMesher._empty(); Decor.saved_pot_mesh(direct,Vector3(at),world)
	t.check(direct[0].size() == rendered[0].size(),"the main-thread saved-pot API renders the same body and plant as the snapshot")
	var other: Vector3i = at+Vector3i.RIGHT
	world.set_node(other+Vector3i.DOWN,Nodes.STONE); world.set_node(other,Decor.POT); Decor.set_contents(world,other,Bamboo.BAMBOO_ITEM)
	var column := Vector2i(floori(at.x/16.0),floori(at.z/16.0))
	var plants: Dictionary = Decor.plant_snapshot(world,column)
	var block: Vector3i = VoxelWorld.block_coord(at)
	t.check(plants.has(block) and int(plants[block].get(VoxelWorld.local_index(at),0)) == PaleOak.EYEBLOSSOM_OPEN and int(plants[block].get(VoxelWorld.local_index(other),0)) == Bamboo.BAMBOO_ITEM,"the worker column snapshot carries each local cell's own saved plant; actual="+str(plants))

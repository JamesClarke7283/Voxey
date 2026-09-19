extends RefCounted

static func clear_grid(inv: Inventory) -> void:
	for i in 9: inv.grid[i] = {"id":0,"count":0,"wear":0}

static func held(game: Node3D, id: int, count: int = 1, enchants: Dictionary = {}) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0,"data":{"enchantments":enchants}}

static func drop_count(game: Node3D, id: int) -> int:
	var result: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: result += drop.amount
	return result

static func planted(world: VoxelWorld, p: Vector3i, kind: int, giant: bool = false) -> Array:
	var points: Array = [p,p+Vector3i.RIGHT,p+Vector3i.BACK,p+Vector3i(1,0,1)] if giant else [p]
	for point in points:
		world.set_node(point+Vector3i.DOWN,Nodes.DIRT); world.set_node(point,WoodTypes.sapling_id(kind))
	return points

static func clear_tree(world: VoxelWorld, p: Vector3i, plan: Dictionary) -> void:
	for offset in plan.blocks: world.set_node(p+offset,Nodes.AIR)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.active = false; game.world.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var inv := Inventory.new()
	t.check(WoodTypes.LOGS[0] == 6 and WoodTypes.LEAVES[0] == 7 and WoodTypes.SAPLINGS[0] == 23 and WoodTypes.PLANKS[0] == 8,"existing oak resource IDs remain compatible with saved inventories and terrain")
	var atlas_size: Vector2i = Art.atlas_texture.get_size()
	var textures_fit: bool = atlas_size.x == 128 and atlas_size.y%16 == 0
	for block_id in [Nodes.LOG,Nodes.LEAVES,Nodes.SAPLING,Nodes.PLANKS]+WoodTypes.blocks():
		for face in 6:
			var tile: int = Nodes.tile(block_id,face)
			var uv_end: Vector2 = Vector2(tile%8*16+16,tile/8*16+16)/Vector2(atlas_size)
			textures_fit = textures_fit and tile >= 0 and uv_end.x <= 1.0 and uv_end.y <= 1.0
	t.check(textures_fit,"all species textures fit the expanded atlas with UV coordinates inside its bounds")
	t.check(WoodTypes.SCHEMATICS.size() == 38,"all38 source tree schematics are present as attributed immutable data")
	for kind in 6:
		var label: String = WoodTypes.NAMES[kind]
		var log_id: int = WoodTypes.log_id(kind); var leaves: int = WoodTypes.leaves_id(kind); var sap: int = WoodTypes.sapling_id(kind); var planks: int = WoodTypes.planks_id(kind)
		var base: int = WoodTypes.base(kind)
		t.check(Nodes.exists(log_id) and Nodes.exists(leaves) and Nodes.exists(sap) and Nodes.exists(planks) and Nodes.placeable(sap) and Nodes.plant(sap) and not Nodes.solid(sap),label+" resources are registered and saplings render as passable plants")
		t.check(Nodes.transparent(leaves) and Nodes.solid(leaves) and RedstoneSensors.light_filter(leaves) == 1 and not Pasture.opaque(leaves),label+" leaves collide but transmit attenuated sunlight")
		t.check(Nodes.fuel_time(log_id) == 15 and Nodes.fuel_time(planks) == 15 and Nodes.fuel_time(sap) == 5 and Nodes.smelt_result(log_id) == Nodes.CHARCOAL and Fire.flammable(leaves) and Composters.chance(sap) == 30,label+" has source fuel, charcoal, fire and compost behavior")
		for input in [log_id,base+4,base+5,base+6]:
			clear_grid(inv); inv.grid[4] = {"id":input,"count":1,"wear":0}
			var output: Dictionary = inv.take_grid_result("table")
			t.check(output.get("id") == planks and output.get("count") == 4 and inv.grid[4].count == 0,label+" log or bark variant "+str(input)+" crafts four matching planks")
		for pair in [[log_id,base+5],[base+4,base+6]]:
			clear_grid(inv)
			for index in [0,1,3,4]: inv.grid[index] = {"id":pair[0],"count":1,"wear":0}
			var output: Dictionary = inv.take_grid_result("hand")
			t.check(output.get("id") == pair[1] and output.get("count") == 3,label+" four logs craft three bark blocks in a natural2x2 hand grid")
		inv.restore([]); clear_grid(inv); inv.add_item(log_id,1)
		t.check(inv.fill_grid(inv.recipe_index(planks),"hand") and inv.take_grid_result("hand").get("count") == 4,label+" plank recipe is usable from the guide")
		var oriented: int = WoodTypes.oriented(log_id,Vector3i.RIGHT)
		t.check(WoodTypes.axis(oriented) == 0 and Nodes.drop(oriented) == log_id and not Nodes.all_ids().has(oriented) and Nodes.tile(oriented,0) != Nodes.tile(oriented,2),label+" horizontal trunks expose end grain and drop the canonical inventory log")
		t.check(Nodes.tile(base+5,0) == Nodes.tile(base+5,2) and Nodes.tile(base+6,0) == Nodes.tile(base+6,2),label+" bark blocks cover every face with matching bark")
		var p := Vector3i(8,170+kind*36,8)
		world.set_node(p,oriented); held(game,Nodes.TOOLS+1)
		game.player.target = {"pos":p,"id":oriented,"normal":Vector3i.UP,"distance":3}
		game.player.use()
		t.check(world.node_at(p) == base+10 and game.inventory.held().wear == 1,label+" actual axe use strips the log, preserves its axis and wears the axe once")
		world.set_node(p,base+5); game.player.target.id = base+5; game.player.use()
		t.check(world.node_at(p) == base+6 and game.inventory.held().wear == 2,label+" bark wood strips into stripped bark wood")
		world.set_node(p,Nodes.AIR)
		var giant: bool = kind == 5
		var seeds: Array = planted(world,p,kind,giant)
		var plan: Dictionary = WoodTypes.tree_plan(kind,9182,giant)
		t.check(WoodTypes.grow(world,p,9182),label+" sapling grows the source tree shape in a clear loaded area")
		var mismatch: int = 0
		for offset in plan.blocks:
			if world.node_at(p+offset) != plan.blocks[offset]: mismatch += 1
		t.check(mismatch == 0 and seeds.all(func(point): return WoodTypes.is_log(world.node_at(point))) and not world.growth.has(p),label+" growth installs the complete source plan and consumes only its saplings")
		clear_tree(world,p,plan)
		# The actual break path must not interpret an empty leaf drop as a block.
		world.set_node(p,leaves); held(game,Nodes.SHEARS)
		var before: int = drop_count(game,leaves); game.break_node(p,leaves,Nodes.SHEARS)
		t.check(drop_count(game,leaves) == before+1,label+" shears recover one exact leaf block through real harvesting")
		world.set_node(p,leaves); held(game,Nodes.TOOLS+14,1,{"Silk Touch":1})
		before = drop_count(game,leaves); game.break_node(p,leaves,Nodes.TOOLS+14)
		t.check(drop_count(game,leaves) == before+1,label+" Silk Touch also preserves the exact leaf species")
		var rng := RandomNumberGenerator.new(); rng.seed = 92278
		var saplings: int = 0; var apples: int = 0; var sticks: int = 0; var empty: int = 0; var valid: bool = true
		for sample in 12000:
			var result: Array = WoodTypes.harvest(leaves,{},rng)
			if result.is_empty(): empty += 1; continue
			valid = valid and result.size() == 1 and result[0][0] in [sap,Nodes.APPLE,Nodes.STICK]
			if result[0][0] == sap: saplings += 1
			elif result[0][0] == Nodes.APPLE: apples += 1
			else: sticks += 1
		t.check(valid and empty > 10500 and sticks in range(370,590) and saplings in (range(220,380) if kind == 3 else range(450,710)),label+" leaf drops remain sparse, ordered, species-correct and source-probability saplings")
		t.check((apples in range(25,90)) if kind in [0,5] else apples == 0,label+" apple eligibility matches the source")
	# Exercise generic placement hooks, beyond direct world/helper calls.
	var placement := Vector3i(8,410,8)
	game.player.position = Vector3(8,410,12); world.set_node(placement,Nodes.STONE)
	held(game,WoodTypes.log_id(4)); game.player.target = {"pos":placement,"id":Nodes.STONE,"normal":Vector3i.RIGHT,"distance":3}; game.player.use()
	t.check(world.node_at(placement+Vector3i.RIGHT) == WoodTypes.base(4)+8 and game.inventory.held().count == 0,"real placement orients an acacia log to the clicked face and consumes one canonical item")
	world.set_node(placement+Vector3i.RIGHT,Nodes.AIR)
	held(game,WoodTypes.leaves_id(4)); game.player.use()
	t.check(WoodTypes.persistent(world,placement+Vector3i.RIGHT),"real leaf placement records persistent metadata immediately")
	world.set_node(placement+Vector3i.RIGHT,Nodes.AIR)
	for trunk in [Nodes.LOG,WoodTypes.log_id(3),WoodTypes.base(3)+4,WoodTypes.base(3)+5,WoodTypes.base(3)+8]:
		world.set_node(placement,trunk); held(game,VillageContent.COCOA_BEANS)
		game.player.target = {"pos":placement,"id":trunk,"normal":Vector3i.RIGHT,"distance":3}; game.player.use()
		var eligible: bool = trunk in [WoodTypes.log_id(3),WoodTypes.base(3)+8]
		t.check((world.node_at(placement+Vector3i.RIGHT) == VillageContent.COCOA_POD) == eligible and game.inventory.held().count == (0 if eligible else 1),"cocoa planting accepts only source normal jungle trunks, checked variant "+str(trunk))
		world.set_node(placement+Vector3i.RIGHT,Nodes.AIR)
	world.set_node(placement,WoodTypes.log_id(3)); held(game,VillageContent.COCOA_BEANS)
	game.player.target = {"pos":placement,"id":WoodTypes.log_id(3),"normal":Vector3i.DOWN,"distance":3}; game.player.use()
	t.check(world.node_at(placement+Vector3i.DOWN) == Nodes.AIR and game.inventory.held().count == 1,"cocoa cannot be planted underneath a jungle trunk")
	world.set_node(placement,Nodes.AIR)
	var previous_step: int = game.journal_step
	game.journal_step = 0; held(game,WoodTypes.log_id(1)); game.progress("gather")
	t.check(game.journal_step == 1,"gathering a non-oak log advances the survival journal")
	held(game,WoodTypes.planks_id(2)); game.progress("craft")
	t.check(game.journal_step == 2,"crafting non-oak planks advances the survival journal")
	game.journal_step = previous_step
	for kind in 6:
		t.check(is_equal_approx(ExplorationMaps.map_color(WoodTypes.leaves_id(kind)).a,181.0/255.0) and is_equal_approx(ExplorationMaps.map_color(WoodTypes.sapling_id(kind)).a,138.0/255.0),WoodTypes.NAMES[kind]+" map symbols retain source leaf and sapling coverage")
	# The combined suite leaves a boat pool at Y468..470. A source giant
	# jungle reaches30 cells, so this growth fixture needs its own altitude.
	var p := Vector3i(8,1000,8)
	planted(world,p,5)
	t.check(not WoodTypes.grow(world,p,12) and world.node_at(p) == WoodTypes.sapling_id(5),"a single dark oak sapling waits for a full2x2 square")
	world.set_node(p,Nodes.AIR)
	for kind in [1,3]:
		planted(world,p,kind,true)
		var plan: Dictionary = WoodTypes.tree_plan(kind,8291,true)
		var chest: Vector3i = p+Vector3i(2,5,2)
		world.set_node(chest,Nodes.CHEST); var storage: Dictionary = world.get_station(chest,"chest"); storage.slots[0] = {"id":Nodes.DIAMOND,"count":7,"wear":0}
		t.check(not WoodTypes.grow(world,p,8291) and world.node_at(p) == WoodTypes.sapling_id(kind) and world.node_at(chest) == Nodes.CHEST and storage.slots[0].count == 7,"giant "+WoodTypes.NAMES[kind]+" clearance rejects a chest without consuming saplings or cargo")
		world.set_node(chest,Nodes.AIR); world.stations.erase(VoxelWorld.station_key(chest))
		var snow_point: Vector3i = p+Vector3i(2,0,2)
		world.set_node(snow_point+Vector3i.DOWN,Nodes.DIRT); world.set_node(snow_point,SnowCover.BASE)
		t.check(WoodTypes.grow(world,p,8291) and plan.height >= 20 and WoodTypes.is_log(world.node_at(p+Vector3i(1,0,1))),"matching2x2 "+WoodTypes.NAMES[kind]+" saplings grow a full giant source tree through buildable snow cover")
		clear_tree(world,p,plan)
		world.set_node(snow_point,Nodes.AIR)
	# Even an obstruction in a single tree's canopy must survive unchanged.
	planted(world,p,2)
	var plan: Dictionary = WoodTypes.tree_plan(2,500)
	var obstruction: Vector3i = Vector3i.ZERO
	for offset in plan.blocks:
		if offset.y > 2 and offset.x != 0: obstruction = offset; break
	world.set_node(p+obstruction,Nodes.PLANKS)
	t.check(not WoodTypes.grow(world,p,500) and world.node_at(p+obstruction) == Nodes.PLANKS and world.node_at(p) == WoodTypes.sapling_id(2),"single-tree canopy validation preserves a player building and its sapling")
	world.set_node(p+obstruction,Nodes.AIR)
	var missing := Vector2i(0,0); world.columns.erase(missing)
	t.check(not WoodTypes.grow(world,p,500),"growth cannot partly write a shape across an unloaded column")
	world.columns[missing] = true
	world.growth[p] = 34; WoodTypes.sapling_tick(world,p,0)
	t.check(world.node_at(p) == WoodTypes.sapling_id(2) and world.growth[p] == 34,"saplings wait for the source35-second growth interval")
	world.growth[p] = 35; WoodTypes.sapling_tick(world,p,1)
	t.check(world.node_at(p) == WoodTypes.sapling_id(2) and world.growth[p] == 0,"a failed one-in-five growth tick resets the timer without consuming the sapling")
	# A dark enclosure is a real light check, not a height or time shortcut.
	for x in range(-8,9):
		for z in range(-8,9): world.set_node(p+Vector3i(x,1,z),Nodes.STONE)
	world.growth[p] = 35; var sap_before: int = drop_count(game,WoodTypes.sapling_id(2)); WoodTypes.sapling_tick(world,p,0)
	t.check(world.node_at(p) == Nodes.AIR and drop_count(game,WoodTypes.sapling_id(2)) == sap_before+1,"a persistently dark sapling uproots and drops its matching item")
	for x in range(-8,9):
		for z in range(-8,9): world.set_node(p+Vector3i(x,1,z),Nodes.AIR)
	planted(world,p,5); held(game,Nodes.BONE_MEAL,2); game.player.target = {"pos":p,"id":WoodTypes.sapling_id(5),"normal":Vector3i.UP,"distance":3}; game.player.use()
	t.check(game.inventory.held().count == 1 and world.node_at(p) == WoodTypes.sapling_id(5),"bone meal is consumed on an attempted tree growth even when a dark oak lacks companions")
	world.set_node(p,Nodes.AIR)
	# Connected distance, persistent placement and streaming boundaries.
	p = Vector3i(4,488,8); world.set_node(p,WoodTypes.log_id(3))
	for i in range(1,8): world.set_node(p+Vector3i.RIGHT*i,WoodTypes.leaves_id(2))
	t.check(WoodTypes.support(world,p+Vector3i.RIGHT*6) == 1 and WoodTypes.support(world,p+Vector3i.RIGHT*7) == 0,"leaf support follows connected paths at source distance six across species")
	WoodTypes.mark_placed(world,p+Vector3i.RIGHT*7); world.set_node(p,Nodes.AIR)
	t.check(WoodTypes.support(world,p+Vector3i.RIGHT*7) == 1 and WoodTypes.support(world,p+Vector3i.RIGHT) == 1,"player-placed leaves remain persistent and carry source distance-zero support")
	world.set_node(p+Vector3i.RIGHT*7,Nodes.AIR)
	WoodTypes.check_leaf(world,p+Vector3i.RIGHT,true)
	t.check(world.node_at(p+Vector3i.RIGHT) == Nodes.AIR,"an unsupported natural leaf decays through the real node-change path")
	for i in range(2,7): world.set_node(p+Vector3i.RIGHT*i,Nodes.AIR)
	var persistent_leaf := Vector3i(8,499,8); world.set_node(persistent_leaf,WoodTypes.leaves_id(4)); WoodTypes.mark_placed(world,persistent_leaf)
	var orphan := Vector3i(10,499,8); world.set_node(orphan,WoodTypes.leaves_id(3)); WoodTypes.check_leaf(world,orphan)
	t.check(bool(world.block_states.get(VoxelWorld.station_key(orphan),{}).get("wood_orphan",false)),"orphan status is serialized alongside placed-leaf persistence")
	var edge := Vector3i(15,490,8); world.set_node(edge,WoodTypes.leaves_id(1)); world.columns.erase(Vector2i(1,0))
	WoodTypes.check_leaf(world,edge,true)
	t.check(world.node_at(edge) == WoodTypes.leaves_id(1) and WoodTypes.runtime(world).retry.has(edge),"unknown neighbor columns postpone decay until support can be resolved")
	world.columns[Vector2i(1,0)] = true; WoodTypes.check_leaf(world,edge,true)
	t.check(world.node_at(edge) == Nodes.AIR,"resolving a loaded unsupported canopy permits decay")
	var planted_sap := Vector3i(12,499,8); planted(world,planted_sap,1); world.growth[planted_sap] = 22.5
	t.check(game.save_game("user://wood_check.json"),"species trees, leaf persistence and sapling clocks save successfully")
	var saved: Dictionary = game.read_save("user://wood_check.json")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await t.process_frame
	game.pause(); game.set_process(false); game.world.active = false; game.world.set_process(false)
	world = game.world
	t.check(world.node_at(persistent_leaf) == WoodTypes.leaves_id(4) and WoodTypes.persistent(world,persistent_leaf) and WoodTypes.runtime(world).leaves.has(persistent_leaf),"real reload preserves player leaves and rebuilds runtime leaf indexes")
	t.check(world.node_at(planted_sap) == WoodTypes.sapling_id(1) and is_equal_approx(world.growth.get(planted_sap,0),22.5),"real reload preserves species saplings and their partial growth interval")
	WoodTypes.check_leaf(world,persistent_leaf,true)
	t.check(world.node_at(persistent_leaf) == WoodTypes.leaves_id(4),"persisted player leaves survive subsequent decay checks")
	WoodTypes.unload(world,Vector2i(0,0))
	t.check(not WoodTypes.runtime(world).leaves.has(persistent_leaf) and not WoodTypes.runtime(world).columns.has(Vector2i(0,0)),"column unloading removes leaf runtime memberships")
	WoodTypes.scan(world,persistent_leaf,world.node_at(persistent_leaf))
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://wood_check.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var legacy := VoxelWorld.new()
	legacy.edits[Vector3i(1,10,1)] = Nodes.LEAVES
	legacy.edits[Vector3i(9000,10,9000)] = Nodes.LEAVES
	WoodTypes.restore_legacy(legacy)
	t.check(WoodTypes.persistent(legacy,Vector3i(1,10,1)) and WoodTypes.persistent(legacy,Vector3i(9000,10,9000)) and not legacy.has_meta("wood_runtime"),"legacy edited oak leaves in loaded and distant columns migrate without indexing unloaded terrain")
	legacy.edits[Vector3i(2,10,1)] = Nodes.LEAVES; WoodTypes.restore_legacy(legacy)
	t.check(not WoodTypes.persistent(legacy,Vector3i(2,10,1)),"the migration runs once so later natural growth still decays")
	legacy.free()
	await natural_checks(t,world.generator)

static func natural_checks(t: SceneTree, generator: TerrainGenerator) -> void:
	var found: Dictionary = {}
	for z in range(-1800,1800,3):
		for x in range(-1800,1800,3):
			var tree: Dictionary = WoodTypes.natural_tree(generator,x,z)
			if tree.is_empty() or found.has(tree.species): continue
			found[tree.species] = tree
			if found.size() == 6: break
		if found.size() == 6: break
	t.check(found.size() == 6,"all six classic species have natural acquisition in existing Overworld biomes")
	for kind in found:
		var tree: Dictionary = found[kind]; var p: Vector3i = tree.origin
		var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
		var result: Dictionary = generator.generate_column(column,{})
		var count: int = 0; var leaf_registered: bool = false
		for block in result.blocks:
			for id in block.data:
				if WoodTypes.is_log(id) and WoodTypes.species(id) == kind: count += 1
		for id in result.special.values():
			if id == WoodTypes.leaves_id(kind): leaf_registered = true
		t.check(count > 0 and leaf_registered,WoodTypes.NAMES[kind]+" actual generated columns contain harvestable trunks and indexed natural leaves")
		await t.process_frame
	t.check(WoodTypes.natural_tree(TerrainGenerator.new(generator.world_seed,"nether"),0,0).is_empty() and WoodTypes.natural_species(TerrainGenerator.new(generator.world_seed,"end"),0,0) == -1,"classic trees stay in the Overworld")

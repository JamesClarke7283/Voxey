extends RefCounted

# Focused azalea/rooted-dirt regression. The tree checks compare the real world
# against the decoded azalea1 plan, rather than accepting a generic oak tree.
const Helper = preload("res://tests/fruit_crop_checks.gd")
const Y = 1900

static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	world._apply_column(world.generator.generate_column(Vector2i(floori(p.x/16.0),floori(p.z/16.0)),world.edits))
	return world.loaded_at(Vector3(p))

static func clear(world: VoxelWorld) -> void:
	for x in 16:
		for z in 16:
			for y in range(Y-8,Y+12): world.set_node(Vector3i(x,y,z),Nodes.AIR)

static func target(p: Vector3i, id: int, normal: Vector3i = Vector3i.UP) -> Dictionary:
	return {"pos":p,"id":id,"normal":normal,"distance":2.0}

static func successful_seed() -> int:
	var rng := RandomNumberGenerator.new()
	for trial in 1000:
		rng.seed = trial
		if rng.randf() <= AzaleaTrees.GROWTH_CHANCE: return trial
	return -1

static func failed_seed() -> int:
	var rng := RandomNumberGenerator.new()
	for trial in 1000:
		rng.seed = trial
		if rng.randf() > AzaleaTrees.GROWTH_CHANCE: return trial
	return -1

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.state = "playing"; game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var p := Vector3i(8,Y,8)
	game.player.position = Vector3(p)+Vector3(0.5,0.01,0.5)
	t.check(ensure(game,p),"azalea test column is loaded")
	clear(world)

	# Registry, soil and the two explicit flower-pot entries.
	for id in [LushCaveExtra.AZALEA,LushCaveExtra.AZALEA_FLOWERING]:
		t.check(LushCaveExtra.pottable(id) and Decor.accepts(id),"azalea %d is accepted by the real flower-pot whitelist" % id)
		t.check(LushCaveExtra.azalea_soil(LushCaveExtra.COARSE_DIRT) and LushCaveExtra.azalea_soil(LushCaveExtra.PALE_MOSS),"current coarse dirt and pale moss are valid azalea soil")
	t.check(not LushCaveExtra.azalea_soil(Nodes.STONE),"stone is not soil_flower")
	t.check(LushCaveExtra.compostability(LushCaveExtra.AZALEA) == 65 and LushCaveExtra.compostability(LushCaveExtra.AZALEA_FLOWERING) == 85,"both azalea compost percentages survive")
	t.check(LushCaveExtra.dripleaf_soil(LushCaveExtra.COARSE_DIRT),"coarse dirt also remains valid dripleaf soil")

	# Real placement: the support predicate runs before the item is consumed.
	world.set_node(p,Nodes.DIRT); world.set_node(p+Vector3i.UP,Nodes.AIR)
	Helper.held(game,LushCaveExtra.AZALEA)
	game.player.target = target(p,Nodes.DIRT)
	game.player.use()
	t.check(world.node_at(p+Vector3i.UP) == LushCaveExtra.AZALEA and game.inventory.held().count == 0,"player placement puts an azalea on source soil and consumes it")
	world.set_node(p,Nodes.STONE); world.set_node(p+Vector3i.UP,Nodes.AIR)
	Helper.held(game,LushCaveExtra.AZALEA)
	game.player.target = target(p,Nodes.STONE)
	game.player.use()
	t.check(world.node_at(p+Vector3i.UP) == Nodes.AIR and game.inventory.held().count == 1,"player placement rejects an azalea above stone")

	# Pot insertion and removal use Decor's actual saved contents and inventory.
	world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	world.set_node(p,Decor.POT)
	Helper.held(game,LushCaveExtra.AZALEA_FLOWERING)
	game.player.target = target(p,Decor.POT)
	game.player.use()
	t.check(Decor.contents(world,p) == LushCaveExtra.AZALEA_FLOWERING and game.inventory.held().count == 0,"flowering azalea enters a real flower pot")
	Helper.held(game,0,0)
	game.player.target = target(p,Decor.POT)
	game.player.use()
	t.check(Decor.contents(world,p) == 0,"removing the pot plant clears its saved contents")
	t.check(game.inventory.count_item(LushCaveExtra.AZALEA_FLOWERING) == 1,"removing the pot plant returns the same flowering form")

	# Rooted dirt bone meal, including the occupied-below failure.
	world.set_node(p,LushCaveExtra.ROOTED_DIRT); world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	Helper.held(game,Nodes.BONE_MEAL,2)
	game.player.target = target(p,LushCaveExtra.ROOTED_DIRT)
	game.player.use()
	t.check(world.node_at(p+Vector3i.DOWN) == LushCaves.HANGING_ROOTS and game.inventory.held().count == 1,"actual bone-meal use creates hanging roots below rooted dirt")
	world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	Helper.held(game,Nodes.BONE_MEAL,2)
	game.player.target = target(p,LushCaveExtra.ROOTED_DIRT)
	game.player.use()
	t.check(world.node_at(p+Vector3i.DOWN) == Nodes.STONE and game.inventory.held().count == 2,"occupied space prevents root growth and bone-meal consumption")

	# Hoe cultivation is dirt, not farmland; only success collects the root.
	world.set_node(p,LushCaveExtra.ROOTED_DIRT); world.set_node(p+Vector3i.UP,Nodes.AIR); world.set_node(p+Vector3i.DOWN,LushCaves.HANGING_ROOTS)
	var before_roots: int = Helper.drops(game,LushCaves.HANGING_ROOTS)
	Helper.held(game,Nodes.TOOLS+4)
	game.player.target = target(p,LushCaveExtra.ROOTED_DIRT,Vector3i.BACK)
	game.player.use()
	t.check(world.node_at(p) == Nodes.DIRT and world.node_at(p) != Farmland.DRY,"rooted dirt hoe callback cultivates ordinary dirt")
	t.check(world.node_at(p+Vector3i.DOWN) == Nodes.AIR and Helper.drops(game,LushCaves.HANGING_ROOTS) == before_roots+1 and game.inventory.held().wear > 0,"successful hoeing removes and drops the root and wears the hoe")
	world.set_node(p,LushCaveExtra.ROOTED_DIRT); world.set_node(p+Vector3i.UP,Nodes.STONE); world.set_node(p+Vector3i.DOWN,LushCaves.HANGING_ROOTS)
	Helper.held(game,Nodes.TOOLS+4)
	game.player.target = target(p,LushCaveExtra.ROOTED_DIRT)
	game.player.use()
	t.check(world.node_at(p) == LushCaveExtra.ROOTED_DIRT and world.node_at(p+Vector3i.DOWN) == LushCaves.HANGING_ROOTS and game.inventory.held().wear == 0,"covered rooted dirt neither converts nor collects its root")
	world.set_node(p+Vector3i.UP,Nodes.AIR)

	# The source also puts bottle_dirt and path creation on rooted dirt.
	Helper.held(game,VillageContent.WATER_BOTTLE)
	game.player.target = target(p,LushCaveExtra.ROOTED_DIRT)
	game.player.use()
	t.check(world.node_at(p) == VillageContent.MUD and game.inventory.count_item(VillageContent.GLASS_BOTTLE) == 1,"water bottle converts rooted dirt to mud and returns the bottle")
	world.set_node(p,LushCaveExtra.ROOTED_DIRT)
	Helper.held(game,Nodes.TOOLS+2)
	game.player.target = target(p,LushCaveExtra.ROOTED_DIRT)
	game.player.use()
	t.check(world.node_at(p) == VillageContent.PATH,"shovel uses rooted dirt's path_creation_possible group")

	# The shipped plan is exact: five oak logs and both foliage forms.
	var plan: Dictionary = AzaleaTrees.tree_plan(0)
	var ordinary: int = 0; var flowering: int = 0; var logs: int = 0
	for id in plan.blocks.values():
		ordinary += int(id == LushCaveExtra.AZALEA_LEAVES)
		flowering += int(id == LushCaveExtra.AZALEA_LEAVES_FLOWERING)
		logs += int(AzaleaTrees.is_log(id))
	t.check(plan.blocks.size() == 43 and ordinary == 31 and flowering == 7 and logs == 5,"azalea1.mts decodes to 43 nodes, including seven flowering leaves")
	t.check(plan.blocks.get(Vector3i.ZERO,0) == Nodes.LOG and plan.blocks.get(Vector3i(0,3,-1),0) == 6009,"the centered trunk and source branch orientation are preserved")

	# Failed growth is atomic; successful growth converts the support and places
	# every node from the rotated plan. Both input forms use this same plan.
	var bush := Vector3i(8,Y,8)
	world.set_node(bush+Vector3i.DOWN,Nodes.DIRT); world.set_node(bush,LushCaveExtra.AZALEA)
	var failed := RandomNumberGenerator.new(); failed.seed = failed_seed()
	t.check(not AzaleaTrees.grow(world,bush,failed) and world.node_at(bush) == LushCaveExtra.AZALEA and world.node_at(bush+Vector3i.DOWN) == Nodes.DIRT,"a failed 45 percent roll leaves bush and support unchanged")
	Helper.held(game,Nodes.BONE_MEAL,2)
	failed = RandomNumberGenerator.new(); failed.seed = failed_seed()
	t.check(LushCaveExtra.use(game,target(bush,LushCaveExtra.AZALEA),failed) and game.inventory.held().count == 1 and world.node_at(bush) == LushCaveExtra.AZALEA,"failed azalea callback returns nil, consuming bone meal without changing the bush")
	world.set_node(bush+Vector3i.UP*3,Nodes.STONE)
	var blocked := RandomNumberGenerator.new(); blocked.seed = successful_seed()
	t.check(not AzaleaTrees.grow(world,bush,blocked) and world.node_at(bush) == LushCaveExtra.AZALEA,"check_growth_simple blocks a solid center-column node")
	world.set_node(bush+Vector3i.UP*3,Nodes.AIR); world.set_node(bush,LushCaveExtra.AZALEA_FLOWERING)
	var seed: int = successful_seed()
	var expected_rng := RandomNumberGenerator.new(); expected_rng.seed = seed; expected_rng.randf()
	var expected: Dictionary = AzaleaTrees.tree_plan(expected_rng.randi_range(0,3))
	var grown_rng := RandomNumberGenerator.new(); grown_rng.seed = seed
	t.check(AzaleaTrees.grow(world,bush,grown_rng),"flowering azalea grows under a successful bone-meal roll")
	t.check(world.node_at(bush+Vector3i.DOWN) == LushCaveExtra.ROOTED_DIRT,"successful growth converts the support to rooted dirt")
	var exact: bool = true; var world_flowering: int = 0
	for offset in expected.blocks:
		if world.node_at(bush+offset) != int(expected.blocks[offset]): exact = false
		if world.node_at(bush+offset) == LushCaveExtra.AZALEA_LEAVES_FLOWERING: world_flowering += 1
	t.check(exact and world_flowering == 7,"world growth matches the rotated schematic and retains its flowering leaves")

	# Leaf drops retain shears behavior and can return either azalea form.
	for id in [LushCaveExtra.AZALEA_LEAVES,LushCaveExtra.AZALEA_LEAVES_FLOWERING]:
		t.check(LushCaveExtra.leaf_drops(id,{"id":Nodes.SHEARS}) == [[id,1]],"shears recover azalea leaf %d" % id)
	var drop_seed: int = -1; var probe := RandomNumberGenerator.new()
	for trial in 10000:
		probe.seed = trial
		if probe.randi_range(1,50) != 1 and probe.randi_range(1,50) != 1 and probe.randi_range(1,20) == 1:
			drop_seed = trial; break
	probe.seed = drop_seed
	t.check(LushCaveExtra.leaf_drops(LushCaveExtra.AZALEA_LEAVES,{"id":0},probe) == [[LushCaveExtra.AZALEA_FLOWERING,1]],"ordinary leaf drops include the flowering azalea entry")

	# Moss from a real wandering trade can produce both azaleas through the
	# source's moss-vegetation table. No azalea trade is invented.
	var moss_rows: Array = WanderingTraders.ORDINARY.filter(func(row): return int(row.give[0]) == LushCaves.MOSS)
	var rooted_rows: Array = WanderingTraders.ORDINARY.filter(func(row): return int(row.give[0]) == LushCaveExtra.ROOTED_DIRT)
	t.check(moss_rows.size() == 1 and moss_rows[0].give == [LushCaves.MOSS,2,2] and moss_rows[0].stock == 5,"the actual trader pool sells two moss for one emerald")
	t.check(rooted_rows.size() == 1 and rooted_rows[0].give == [LushCaveExtra.ROOTED_DIRT,2,2] and rooted_rows[0].stock == 5,"the actual trader pool sells two rooted dirt")
	var trader: Dictionary = {}; var moss_offer: Dictionary = {}; var trade_rng := RandomNumberGenerator.new()
	for trial in 500:
		trade_rng.seed = trial
		var candidate: Dictionary = WanderingTraders.make_record("azalea-test",Vector3(p),trade_rng)
		for offer in candidate.offers:
			if int(offer.give[0]) == LushCaves.MOSS: trader = candidate; moss_offer = offer; break
		if not moss_offer.is_empty(): break
	Helper.held(game,VillageContent.EMERALD,4)
	t.check(not moss_offer.is_empty() and game.villages.transaction(trader,moss_offer,true).is_empty() and game.inventory.count_item(LushCaves.MOSS) == 2,"a real wandering transaction supplies the moss needed for azalea acquisition")
	var vegetation_seed: int = -1
	for trial in 1000:
		probe.seed = trial
		if probe.randf() < 0.6 and AzaleaTrees.moss_vegetation(probe) == LushCaveExtra.AZALEA_FLOWERING:
			vegetation_seed = trial; break
	var moss_spot := Vector3i(5,Y,5)
	world.set_node(moss_spot,Nodes.DIRT); world.set_node(moss_spot+Vector3i.UP,Nodes.AIR)
	probe.seed = vegetation_seed
	t.check(AzaleaTrees.moss_cell(world,moss_spot,probe) and world.node_at(moss_spot) == LushCaves.MOSS and world.node_at(moss_spot+Vector3i.UP) == LushCaveExtra.AZALEA_FLOWERING,"moss vegetation grows a flowering azalea on the converted moss")
	var spread := Vector3i(8,Y,5)
	for dx in range(-1,2):
		for dz in range(-1,2):
			world.set_node(spread+Vector3i(dx,0,dz),Nodes.DIRT)
			world.set_node(spread+Vector3i(dx,1,dz),Nodes.AIR)
	world.set_node(spread,LushCaves.MOSS)
	Helper.held(game,Nodes.BONE_MEAL,2)
	game.player.target = target(spread,LushCaves.MOSS)
	game.player.use()
	var spread_moss: int = 0
	for dx in range(-1,2):
		for dz in range(-1,2): spread_moss += int(world.node_at(spread+Vector3i(dx,0,dz)) == LushCaves.MOSS)
	t.check(spread_moss > 1 and game.inventory.held().count == 1,"actual moss bone meal spreads moss and consumes one item")


	# Existing small-dripleaf two-cell behavior is not displaced by azalea hooks.
	world.set_node(p,Nodes.DIRT); world.set_node(p+Vector3i.UP,Nodes.AIR); world.set_node(p+Vector3i.UP*2,Nodes.AIR)
	world.set_node(p+Vector3i.UP,LushCaveExtra.DRIPLEAF_SMALL)
	LushCaveExtra.placed(world,p+Vector3i.UP,LushCaveExtra.DRIPLEAF_SMALL)
	t.check(world.node_at(p+Vector3i.UP) == LushCaveExtra.DRIPLEAF_SMALL_STEM and world.node_at(p+Vector3i.UP*2) == LushCaveExtra.DRIPLEAF_SMALL,"small dripleaf still places its stem and upper leaf")

	# Natural rooted generation is callable, but these checks do not assert that
	# TerrainGenerator has a lush-cave biome dispatcher (it does not yet).
	t.check(AzaleaTrees.natural_soil(Nodes.SAND) and not AzaleaTrees.natural_soil(Nodes.CLAY),"natural azalea soil follows the levelgen list rather than placement soil")
	t.check(AzaleaTrees.root_replaceable(Nodes.STONE) and not AzaleaTrees.root_replaceable(Nodes.DIRT),"root replacement keeps the source's no-dirt quirk")
	clear(world)
	world.set_node(p+Vector3i.DOWN,Nodes.STONE); world.set_node(p,Nodes.AIR); world.set_node(p+Vector3i.UP,Nodes.DIRT)
	for dx in range(-2,3):
		for dz in range(-2,3):
			if dx == 0 and dz == 0: continue
			world.set_node(p+Vector3i(dx,0,dz),Nodes.STONE); world.set_node(p+Vector3i(dx,1,dz),Nodes.STONE)
	var natural_rng := RandomNumberGenerator.new(); natural_rng.seed = 9
	t.check(AzaleaTrees.generate_rooted(world,p,natural_rng),"rooted azalea generation finds the valid higher root column")
	var rooted: int = 0
	for dx in range(-2,3):
		for dz in range(-2,3):
			for dy in 2: rooted += int(world.node_at(p+Vector3i(dx,dy,dz)) == LushCaveExtra.ROOTED_DIRT)
	t.check(rooted > 0 and AzaleaTrees.is_log(world.node_at(p+Vector3i.UP*2)),"natural generation places the tree and real rooted-dirt attempts")

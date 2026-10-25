extends RefCounted

const Y = 3250

static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	world._apply_column(world.generator.generate_column(Vector2i(floori(p.x/16.0),floori(p.z/16.0)),world.edits))
	return world.loaded_at(Vector3(p))

static func clear_box(world: VoxelWorld, low: Vector3i, high: Vector3i) -> void:
	for x in range(low.x,high.x+1):
		for z in range(low.z,high.z+1):
			for y in range(low.y,high.y+1): world.set_node(Vector3i(x,y,z),Nodes.AIR)

static func fresh(world: VoxelWorld, p: Vector3i, id: int) -> void:
	world.set_node(p+Vector3i.UP,Nodes.AIR); world.set_node(p,Nodes.AIR); world.set_node(p,id)

static func held(game: Node3D, id: int, silk: bool = false) -> void:
	game.inventory.restore([])
	var slot := {"id":id,"count":1,"wear":0}
	if silk: slot["data"] = {"enchantments":{"Silk Touch":1}}
	game.inventory.slots[0] = slot; game.inventory.selected = 0

static func use(game: Node3D, p: Vector3i, id: int, normal: Vector3i = Vector3i.UP) -> void:
	game.player.target = {"pos":p,"id":id,"normal":normal,"distance":2.0}
	game.player.use()

static func winning_roll(low: int, high: int, wanted: int) -> int:
	var rng := RandomNumberGenerator.new()
	for candidate in range(20000):
		rng.seed = candidate
		if rng.randi_range(low,high) == wanted: return candidate
	return -1

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.state = "playing"; game.gamemode = "survival"; game.daylight = 1.0
	var world: VoxelWorld = game.world; var p := Vector3i(8,Y,8); var source: Vector3i = p+Vector3i.RIGHT
	game.player.position = Vector3(p)+Vector3(0.5,0.01,0.5)
	t.check(ensure(game,p),"soil-variant test column is loaded")
	clear_box(world,p+Vector3i(-8,-8,-8),p+Vector3i(8,48,8))

	# Registry data and actual source-backed mining/drop paths.
	var expected := {
		SoilVariants.PODZOL:[0.5,"mcl_core:podzol"],SoilVariants.SNOWY_PODZOL:[0.5,"mcl_core:podzol_snow"],
		SoilVariants.MYCELIUM:[0.6,"mcl_core:mycelium"],SoilVariants.SNOWY_MYCELIUM:[0.6,"mcl_core:mycelium_snow"],
	}
	for id in expected:
		t.check(VillageContent.DATA.has(id) and Nodes.exists(id) and VillageContent.BLOCKS.has(id),"soil ID %d is registered without remapping saves"%id)
		t.check(is_equal_approx(Nodes.hardness(id),expected[id][0]) and Nodes.preferred_tool(id) == 2 and Nodes.drop(id) == Nodes.DIRT,"soil ID %d retains source hardness, shovel and ordinary dirt drop"%id)
		t.check(MiningNodes.node_name(id) == expected[id][1],"soil ID %d binds its exact source node"%id)
		held(game,Nodes.TOOLS+2,true)
		var silk: Dictionary = Harvesting.harvest(id,game.inventory.held())
		var wanted: int = SoilVariants.snowless(id) if SoilVariants.snowless(id) != 0 else id
		t.check(silk.get("handled",false) and silk.get("drops",[]) == [[wanted,1]],"Silk Touch returns the clear soil item for %d"%id)
	for id in [SoilVariants.SNOWY_PODZOL,SoilVariants.SNOWY_MYCELIUM,Nodes.SNOW]:
		t.check(SoilVariants.hidden(id) and not Nodes.placeable(id),"snowy soil %d is hidden from inventory acquisition"%id)
	t.check(FarmingRules.group(SoilVariants.MYCELIUM,"spreading_dirt_type") == 1 and FarmingRules.group(SoilVariants.SNOWY_MYCELIUM,"spreading_dirt_type") == 0,"only clear mycelium carries the spreading group")
	t.check(FarmingRules.group(SoilVariants.PODZOL,"spreading_dirt_type") == 0,"podzol never joins the spread source group")
	for id in expected:
		t.check(FarmingRules.group(id,"cultivatable") == 0 and FarmingRules.group(id,"converts_to_mud") == 0 and not MudBottles.host(id),"soil %d has no hoe or mud conversion"%id)
	t.check(SoilVariants.PODZOL_OFFER.cost == [[VillageContent.EMERALD,3,3]] and SoilVariants.PODZOL_OFFER.give == [SoilVariants.PODZOL,3,3] and SoilVariants.PODZOL_OFFER.stock == 6,"podzol trade costs three emeralds, gives three podzol and has six uses")
	t.check(WanderingTraders.SPECIAL.has(SoilVariants.PODZOL_OFFER),"the real wandering-trader special pool contains the podzol offer")

	# All three clear/snowy pairs, including construction, stacking and removal.
	for pair in [[Nodes.GRASS,Nodes.SNOW],[SoilVariants.PODZOL,SoilVariants.SNOWY_PODZOL],[SoilVariants.MYCELIUM,SoilVariants.SNOWY_MYCELIUM]]:
		fresh(world,p,pair[0]); world.set_node(p+Vector3i.UP,SnowCover.BASE)
		t.check(world.node_at(p) == pair[1],"top snow snows clear soil %d"%pair[0])
		world.set_node(p+Vector3i.UP,SnowCover.BASE+1)
		t.check(world.node_at(p) == pair[1],"stacking snow preserves snowy soil %d"%pair[1])
		world.set_node(p+Vector3i.UP,Nodes.AIR)
		t.check(world.node_at(p) == pair[0],"removing snow clears snowy soil %d"%pair[1])
		world.set_node(p+Vector3i.UP,SnowCover.BASE); world.set_node(p,pair[0])
		t.check(world.node_at(p) == pair[1],"constructing clear soil below snow applies its snowy state")
		world.set_node(p+Vector3i.UP,Nodes.SNOW_BLOCK)
		t.check(world.node_at(p) == pair[1],"a full snow block is also a snow cover")
		world.set_node(p+Vector3i.UP,Nodes.AIR)
		t.check(world.node_at(p) == pair[0],"removing a full snow block restores clear soil")
	# Melting uses the same authoritative removal hook and excludes skylight.
	fresh(world,p,SoilVariants.MYCELIUM); world.set_node(p+Vector3i.UP,SnowCover.BASE)
	var torch: Vector3i = p+Vector3i(1,1,0); world.set_node(torch,Nodes.TORCH); game.daylight = 0.0
	t.check(SnowCover.melt(world,p+Vector3i.UP) and world.node_at(p) == SoilVariants.MYCELIUM,"artificial-light snow melting reveals clear mycelium")
	world.set_node(torch,Nodes.AIR); game.daylight = 1.0

	# Mycelium's source volume and both light gates.
	fresh(world,p,Nodes.DIRT); world.set_node(source,SoilVariants.MYCELIUM)
	t.check(Pasture.state(world).cells.has(source),"clear mycelium enters the real pasture simulation index")
	t.check(SoilVariants.spread(world,p) and world.node_at(p) == SoilVariants.MYCELIUM,"daylit mycelium spreads to exposed dirt")
	world.set_node(source,Nodes.AIR)
	for offset in [Vector3i(-1,-1,-1),Vector3i(1,3,1),Vector3i(2,0,0),Vector3i(0,4,0),Vector3i(0,-2,0)]:
		fresh(world,p,Nodes.DIRT); world.set_node(p+offset,SoilVariants.MYCELIUM)
		var expected_spread: bool = absi(offset.x) <= 1 and absi(offset.z) <= 1 and offset.y >= -1 and offset.y <= 3
		t.check(SoilVariants.spread(world,p) == expected_spread,"mycelium source search honors 3×5×3 at "+str(offset))
		world.set_node(p+offset,Nodes.AIR)
	world.set_node(source,SoilVariants.MYCELIUM)
	for cover in [Nodes.STONE,Nodes.WATER,Nodes.LAVA]:
		fresh(world,p,Nodes.DIRT); world.set_node(p+Vector3i.UP,cover)
		t.check(not SoilVariants.spread(world,p) and world.node_at(p) == Nodes.DIRT,"mycelium cannot spread beneath a liquid or opaque cover")
	fresh(world,p,Nodes.DIRT); world.set_node(source+Vector3i.UP,Nodes.STONE)
	t.check(not SoilVariants.spread(world,p),"a dark covered mycelium source cannot spread")
	world.set_node(source+Vector3i.UP,Nodes.AIR); game.daylight = 0.0
	t.check(not SoilVariants.spread(world,p),"mycelium requires target light four and source light nine")
	game.daylight = 1.0
	# Pasture makes one mixed source draw, then preserves the selected source type.
	fresh(world,p,Nodes.DIRT); world.set_node(source,Nodes.AIR)
	world.set_node(p+Vector3i.LEFT,Nodes.GRASS); world.set_node(p+Vector3i.RIGHT,SoilVariants.MYCELIUM)
	Pasture.state(world).rng.seed = winning_roll(0,1,1)
	t.check(Pasture.spread(world,p) and world.node_at(p) == SoilVariants.MYCELIUM,"mixed pasture spread preserves the randomly selected mycelium source")
	world.set_node(p+Vector3i.LEFT,Nodes.AIR)
	# non_mycelium_plant is dug; mushrooms are intentionally compatible.
	fresh(world,p,Nodes.DIRT); world.set_node(source,SoilVariants.MYCELIUM); world.set_node(p+Vector3i.UP,FlowersExtra.ALLIUM)
	held(game,0); var drops_before: int = game.drops.get_child_count()
	t.check(SoilVariants.spread(world,p) and world.node_at(p+Vector3i.UP) == Nodes.AIR and game.drops.get_child_count() > drops_before,"mycelium spread digs a non-mycelium plant through the real break path")
	fresh(world,p,Nodes.DIRT); world.set_node(p+Vector3i.UP,Nodes.RED_MUSHROOM)
	t.check(SoilVariants.spread(world,p) and world.node_at(p+Vector3i.UP) == Nodes.RED_MUSHROOM,"mycelium spread does not uproot a compatible mushroom")
	for non_source in [SoilVariants.PODZOL,SoilVariants.SNOWY_PODZOL,SoilVariants.SNOWY_MYCELIUM]:
		fresh(world,p,Nodes.DIRT); world.set_node(source,non_source)
		t.check(not SoilVariants.spread(world,p) and not Pasture.spread(world,p) and world.node_at(p) == Nodes.DIRT,"soil %d never acts as a spread source"%non_source)
	# Covered decay is immediate only through its scheduled chance, never at night alone.
	fresh(world,p,SoilVariants.MYCELIUM); world.set_node(source,Nodes.AIR)
	t.check(not SoilVariants.decay(world,p),"open mycelium does not decay merely from time")
	world.set_node(p+Vector3i.UP,Nodes.STONE)
	t.check(SoilVariants.decay(world,p) and world.node_at(p) == Nodes.DIRT,"covered mycelium decays to dirt")
	world.set_node(p+Vector3i.UP,Nodes.AIR)
	fresh(world,p,SoilVariants.MYCELIUM); world.set_node(p+Vector3i.UP,VillageContent.PATH)
	t.check(SoilVariants.decay(world,p) and world.node_at(p) == Nodes.DIRT,"a source dirtifier cover also decays mycelium")
	# Real 30 s/chance 20 and 8 s/chance 50 Pasture clocks.
	var data: Dictionary = Pasture.state(world)
	fresh(world,p,Nodes.DIRT); world.set_node(source,SoilVariants.MYCELIUM)
	data.cells.clear(); data.cells[p] = true; data.jobs.clear(); data.scans.clear(); data.cursor = 0
	data.spread_clock = 29.9; data.decay_clock = 0; data.rng.seed = winning_roll(1,20,1)
	Pasture.update(world,0.05)
	t.check(world.node_at(p) == Nodes.DIRT,"mycelium waits for the thirty-second spread interval")
	Pasture.update(world,0.06)
	t.check(world.node_at(p) == SoilVariants.MYCELIUM,"a successful one-in-twenty scheduled attempt spreads mycelium")
	world.set_node(p+Vector3i.UP,Nodes.STONE); data.cells.clear(); data.cells[p] = true; data.jobs.clear(); data.scans.clear(); data.cursor = 0
	data.spread_clock = 0; data.decay_clock = 7.9; data.rng.seed = winning_roll(1,50,1)
	Pasture.update(world,0.05)
	t.check(world.node_at(p) == SoilVariants.MYCELIUM,"covered mycelium waits for the eight-second decay interval")
	Pasture.update(world,0.06)
	t.check(world.node_at(p) == Nodes.DIRT,"a successful one-in-fifty scheduled attempt decays mycelium")
	world.set_node(p+Vector3i.UP,Nodes.AIR); world.set_node(source,Nodes.AIR); fresh(world,p,Nodes.DIRT)
	data.cells.clear(); data.cells[p] = true; data.jobs.clear(); data.scans.clear(); data.cursor = 0
	data.spread_clock = 0; data.decay_clock = 0; data.rng.seed = 487
	var expected_rng := RandomNumberGenerator.new(); expected_rng.seed = 487; expected_rng.randi_range(1,20)
	Pasture.update(world,600)
	t.check(data.rng.state == expected_rng.state and data.spread_clock == 0 and data.decay_clock == 0,"mycelium scheduling never catches up unloaded intervals")

	# Shovel paths, rejected bottom/covered uses, and no hoe/mud shortcuts.
	for id in [SoilVariants.PODZOL,SoilVariants.SNOWY_PODZOL,SoilVariants.MYCELIUM,SoilVariants.SNOWY_MYCELIUM,Nodes.SNOW]:
		fresh(world,p,id); held(game,Nodes.TOOLS+2); use(game,p,id)
		t.check(world.node_at(p) == VillageContent.PATH and game.inventory.held().wear > 0,"shovel makes a dirt path from soil %d"%id)
	fresh(world,p,SoilVariants.PODZOL); held(game,Nodes.TOOLS+2); use(game,p,SoilVariants.PODZOL,Vector3i.DOWN)
	t.check(world.node_at(p) == SoilVariants.PODZOL and game.inventory.held().wear == 0,"bottom-face shovel use does not make a path")
	world.set_node(p+Vector3i.UP,Nodes.STONE); use(game,p,SoilVariants.PODZOL)
	t.check(world.node_at(p) == SoilVariants.PODZOL and game.inventory.held().wear == 0,"covered soil does not become a path")
	for id in expected:
		fresh(world,p,id); held(game,Nodes.TOOLS+4); use(game,p,id)
		t.check(world.node_at(p) == id and game.inventory.held().wear == 0,"hoe leaves podzol/mycelium state %d unchanged"%id)
		held(game,VillageContent.WATER_BOTTLE); use(game,p,id)
		t.check(world.node_at(p) == id,"water bottle does not turn soil %d into mud"%id)

	# Exact giant-spruce post-growth selection: nearest eligible dirt first.
	clear_box(world,p+Vector3i(-7,-7,-7),p+Vector3i(7,7,7))
	var near: Vector3i = p+Vector3i.DOWN; var middle: Vector3i = p+Vector3i(2,0,0); var far: Vector3i = p+Vector3i(-6,-6,-6)
	world.set_node(near,Nodes.DIRT); world.set_node(middle,DryTerrain.COARSE_DIRT); world.set_node(far,Nodes.DIRT)
	var covered: Vector3i = p+Vector3i(0,0,2); world.set_node(covered,Nodes.DIRT); world.set_node(covered+Vector3i.UP,Nodes.STONE)
	var rng := RandomNumberGenerator.new(); rng.seed = winning_roll(2,3,2)
	t.check(SoilVariants.after_giant_spruce(world,p,rng) == 2 and world.node_at(near) == SoilVariants.PODZOL and world.node_at(middle) == SoilVariants.PODZOL and world.node_at(far) == Nodes.DIRT,"giant spruce converts the random count from distance-sorted group:dirt under air")
	t.check(world.node_at(covered) == Nodes.DIRT,"giant spruce excludes dirt without air directly above")
	clear_box(world,p+Vector3i(-7,-7,-7),p+Vector3i(7,7,7)); world.set_node(near,Nodes.DIRT)
	t.check(SoilVariants.after_giant_spruce(world,p,rng) == 1 and world.node_at(near) == SoilVariants.PODZOL,"a single eligible giant-spruce candidate always converts")
	# Exercise the real successful 2x2 spruce growth callback after plan placement.
	clear_box(world,p+Vector3i(-8,-2,-8),p+Vector3i(8,42,8))
	for x in range(-7,8):
		for z in range(-7,8): world.set_node(p+Vector3i(x,-1,z),Nodes.DIRT)
	var spruce: int = WoodTypes.sapling_id(1)
	for offset in [Vector3i.ZERO,Vector3i.RIGHT,Vector3i.BACK,Vector3i(1,0,1)]: world.set_node(p+offset,spruce)
	t.check(WoodTypes.grow(world,p,9182),"a real 2x2 spruce grows for the after-growth hook")
	var podzol_count: int = 0
	for x in range(-7,8):
		for z in range(-7,8): podzol_count += int(world.node_at(p+Vector3i(x,-1,z)) == SoilVariants.PODZOL)
	t.check(podzol_count >= 2,"successful giant spruce growth converts at least two eligible dirt cells to podzol")

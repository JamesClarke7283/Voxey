extends RefCounted

# Copper lanterns, chains and bars (mcl_copper/nodes.lua): the three decorative
# copper families, which are members of the same oxidation engine as the blocks.
static func run(suite: Object, game: Node3D) -> void:
	suite.check(CopperDecor.LANTERN_FLOOR == 11530 and CopperDecor.BARS+CopperDecor.STAGES-1 == 11545,"the copper decor holds its allocated ids")
	suite.check(CopperDecor.BLOCKS.size() == 16,"sixteen copper decor nodes are registered")
	var all_ok: bool = true
	for id in CopperDecor.BLOCKS:
		if not Nodes.exists(id) or Nodes.tile(id,0) == 0 or not Nodes.placeable(id): all_ok = false
	suite.check(all_ok,"every copper decor node exists, is placeable and has its own tile")
	# Only the plain stage is in the catalog; the oxidized ones are derived.
	suite.check(Nodes.all_ids().has(CopperDecor.LANTERN_FLOOR) and not Nodes.all_ids().has(CopperDecor.LANTERN_FLOOR+1),"only the plain stage appears in the catalog")
	# Each family is four stages, and the engine sees them.
	var seen: int = 0
	for id in CopperDecor.BLOCKS:
		if Copper.in_chain(id): seen += 1
	suite.check(seen == 16,"every copper decor node is a member of the shared oxidation engine")
	suite.check(CopperDecor.chain_stage(CopperDecor.LANTERN_FLOOR) == 0 and CopperDecor.chain_stage(CopperDecor.LANTERN_FLOOR+2) == 2,"each decor node reports its own oxidation stage")
	suite.check(Copper.stage(CopperDecor.LANTERN_FLOOR) == 0 and Copper.stage(CopperDecor.BAR_STAGES[2]) == 2,"the copper engine resolves the decor stages through the shared chain table")
	suite.check(CopperDecor.oxidized(CopperDecor.LANTERN_FLOOR) == CopperDecor.LANTERN_FLOOR+1 and CopperDecor.oxidized(CopperDecor.BAR_STAGES[3]) == 0,"a decor node advances one stage and stops at the end of its chain")
	# The lantern is a light source in both placements; the chain and bars are not.
	suite.check(CopperDecor.light_level(CopperDecor.LANTERN_FLOOR) == 14 and CopperDecor.light_level(CopperDecor.CHAIN_STAGES[0]) == 0,"a copper lantern is a light source and a chain is not")
	# A lantern placed on a ceiling becomes the ceiling form.
	suite.check(CopperDecor.oriented(CopperDecor.LANTERN_FLOOR,Vector3i.DOWN) == CopperDecor.LANTERN_CEILING and CopperDecor.oriented(CopperDecor.LANTERN_FLOOR,Vector3i.UP) == CopperDecor.LANTERN_FLOOR,"a lantern aimed at a ceiling becomes the ceiling form and otherwise the floor form")
	suite.check(CopperDecor.oriented(CopperDecor.CHAIN_STAGES[0],Vector3i.DOWN) == CopperDecor.CHAIN_STAGES[0],"a chain has no placement variant")
	# Shapes: the chain is thin, the bars are a pane, the lantern is a small form.
	suite.check(not Nodes.solid(CopperDecor.CHAIN_STAGES[0]) and Nodes.transparent(CopperDecor.CHAIN_STAGES[0]),"a copper chain is a thin column, not a cube")
	suite.check(VillageContent.shape(CopperDecor.BAR_STAGES[0]) == "pane","the copper bars use the pane shape")
	# Recipes.
	var inv := Inventory.new()
	inv.add_item(RawOres.COPPER_NUGGET,2); inv.add_item(Nodes.COPPER,1)
	var chain: int = inv.recipe_index(CopperDecor.CHAIN_STAGES[0])
	suite.check(chain >= 0 and inv.craft(chain,"hand") and inv.count_item(CopperDecor.CHAIN_STAGES[0]) == 4,"a copper nugget, a copper ingot and a nugget make four chains")
	inv = Inventory.new(); inv.add_item(Nodes.COPPER,6)
	var bars: int = inv.recipe_index(CopperDecor.BAR_STAGES[0])
	suite.check(bars >= 0 and inv.craft(bars,"table") and inv.count_item(CopperDecor.BAR_STAGES[0]) == 16,"six copper ingots make sixteen copper bars")
	# Waxing and scraping run through the shared engine, so a waxed lantern stops.
	var world: VoxelWorld = game.world
	var at: Vector3i = Vector3i(4,game.world.generator.terrain_height(4,4)+22,4)
	for x in range(-2,3):
		for y in range(-1,5):
			for z in range(-2,3): world.set_node(at+Vector3i(x,y,z),Nodes.AIR)
	world.set_node(at,CopperDecor.LANTERN_FLOOR)
	suite.check(Copper.waxed(world,at) == false,"a placed copper lantern starts unwaxed")
	Copper.set_waxed(world,at,true)
	suite.check(Copper.waxed(world,at),"a copper lantern can be waxed, which freezes its oxidation")
	suite.check(Copper.stage(CopperDecor.LANTERN_FLOOR) == 0 and Copper.stage(CopperDecor.LANTERN_CEILING) == 0,"both lantern placements are the first stage of their own chain")

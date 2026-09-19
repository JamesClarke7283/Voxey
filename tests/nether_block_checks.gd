extends RefCounted

# Nether materials (mcl_nether, mcl_blackstone): red nether bricks, the cracked and
# chiseled nether brick variants, the nether wart block, the quartz variants,
# polished basalt and soul fire.
static func run(suite: Object, game: Node3D) -> void:
	suite.check(NetherBlocks.RED_NETHER_BRICKS == 11200 and NetherBlocks.SOUL_FIRE == 11209,"nether materials occupy the allocated block")
	var blocks: Array = [NetherBlocks.RED_NETHER_BRICKS,NetherBlocks.CHISELED_NETHER_BRICKS,NetherBlocks.CRACKED_NETHER_BRICKS,
		NetherBlocks.NETHER_WART_BLOCK,NetherBlocks.CHISELED_QUARTZ,NetherBlocks.SMOOTH_QUARTZ,
		NetherBlocks.QUARTZ_BRICK,NetherBlocks.POLISHED_BASALT,NetherBlocks.CRACKED_BLACKSTONE_BRICKS]
	var all_ok: bool = true
	for id in blocks:
		if not Nodes.exists(id) or not Nodes.placeable(id): all_ok = false
		if Nodes.tile(id,0) == 0: all_ok = false
		# The source gives the nether wart block `handy`/`hoey` rather than a stone
		# group, so its preferred tool is the hoe; every other material is stone.
		if Nodes.preferred_tool(id) != (4 if id == NetherBlocks.NETHER_WART_BLOCK else 0): all_ok = false
	suite.check(all_ok,"every new nether material is an obtainable block with its own tile and the source's preferred tool")
	# Soul fire is a flame: not solid, not an item, and not placeable.
	suite.check(NetherBlocks.is_soul_fire(NetherBlocks.SOUL_FIRE) and not Nodes.solid(NetherBlocks.SOUL_FIRE),"soul fire is a flame rather than a block")
	suite.check(not Nodes.placeable(NetherBlocks.SOUL_FIRE) and Nodes.drop(NetherBlocks.SOUL_FIRE) == Nodes.AIR,"soul fire is never an item")
	suite.check(Nodes.plant(NetherBlocks.SOUL_FIRE) and Nodes.transparent(NetherBlocks.SOUL_FIRE),"soul fire is drawn as a plant-shaped transparent flame")
	# The source's `eternal_after_destruct`: fire above a soul block becomes soul fire.
	suite.check(NetherBlocks.soul_block(Nodes.SOUL_SAND) and NetherBlocks.soul_block(Campfires.SOUL_SOIL),"soul sand and soul soil are the source's soul blocks")
	suite.check(NetherBlocks.flame_for(Nodes.SOUL_SAND) == NetherBlocks.SOUL_FIRE and NetherBlocks.flame_for(Nodes.NETHERRACK) == 0,"igniting above a soul block yields soul fire, and above netherrack keeps the ordinary eternal fire")
	var p: Vector3i = Vector3i(6,game.world.generator.terrain_height(6,6)+3,6)
	for d in [Vector3i.ZERO,Vector3i.UP]:
		game.world.set_node(p+d,Nodes.AIR)
	game.world.set_node(p+Vector3i.DOWN,Nodes.SOUL_SAND)
	suite.check(Fire.ignite(game.world,p) and game.world.node_at(p) == NetherBlocks.SOUL_FIRE,"a real ignite over soul sand places soul fire")
	# Smelting chains that target existing ids.
	suite.check(Nodes.smelt_result(Nodes.NETHER_BRICKS) == NetherBlocks.CRACKED_NETHER_BRICKS,"nether bricks smelt into cracked nether bricks")
	suite.check(Nodes.smelt_result(Bastions.BRICKS) == NetherBlocks.CRACKED_BLACKSTONE_BRICKS,"polished blackstone bricks smelt into their cracked form")
	suite.check(Nodes.smelt_result(VillageContent.QUARTZ_BLOCK) == NetherBlocks.SMOOTH_QUARTZ,"a quartz block smelts into smooth quartz")
	# Recipes.
	var inv := Inventory.new()
	inv.add_item(VillageContent.NETHER_WART_ITEM,2); inv.add_item(Nodes.NETHER_BRICK_ITEM,2)
	var red: int = inv.recipe_index(NetherBlocks.RED_NETHER_BRICKS)
	suite.check(red >= 0 and inv.can_craft(inv.recipes[red],"table") and inv.craft(red,"table") and inv.count_item(NetherBlocks.RED_NETHER_BRICKS) == 1,"nether wart and nether bricks make red nether bricks")
	inv = Inventory.new()
	var slab: int = BuildingShapes.slab_for(Nodes.NETHER_BRICKS)
	inv.add_item(slab,2)
	var chiseled: int = inv.recipe_index(NetherBlocks.CHISELED_NETHER_BRICKS)
	suite.check(slab != 0 and chiseled >= 0 and inv.craft(chiseled,"table") and inv.count_item(NetherBlocks.CHISELED_NETHER_BRICKS) == 1,"two nether brick slabs make chiseled nether bricks")
	inv = Inventory.new(); inv.add_item(VillageContent.NETHER_WART_ITEM,9)
	var wart_block: int = inv.recipe_index(NetherBlocks.NETHER_WART_BLOCK)
	suite.check(wart_block >= 0 and inv.craft(wart_block,"table") and inv.count_item(NetherBlocks.NETHER_WART_BLOCK) == 1,"nine nether wart make a nether wart block")
	inv = Inventory.new(); inv.add_item(Nodes.BASALT,4)
	var basalt: int = inv.recipe_index(NetherBlocks.POLISHED_BASALT)
	suite.check(basalt >= 0 and inv.craft(basalt,"table") and inv.count_item(NetherBlocks.POLISHED_BASALT) == 4,"four basalt make four polished basalt")
	inv = Inventory.new(); inv.add_item(VillageContent.QUARTZ_BLOCK,4)
	var bricks: int = inv.recipe_index(NetherBlocks.QUARTZ_BRICK)
	suite.check(bricks >= 0 and inv.craft(bricks,"table") and inv.count_item(NetherBlocks.QUARTZ_BRICK) == 4,"four quartz blocks make four quartz bricks")
	# The new materials join the shared shape and barrier families.
	suite.check(BuildingShapes.slab_for(NetherBlocks.RED_NETHER_BRICKS) != 0 and BuildingShapes.stair_for(NetherBlocks.QUARTZ_BRICK) != 0,"new nether materials have slabs and stairs")
	suite.check(Barriers.WALL_MATERIALS.has(NetherBlocks.RED_NETHER_BRICKS) and Barriers.WALL_MATERIALS.has(NetherBlocks.NETHER_WART_BLOCK),"new nether materials have walls")
	# Art: soul fire is transparent where the flame is not, and opaque elsewhere.
	var flame: bool = false; var clear: bool = false
	for x in 16:
		for y in 16:
			var c: Color = NetherBlocks.pixel(NetherBlocks.SOUL_FIRE,x,y,Color(0.5,0.5,0.5))
			if c.a > 0.0: flame = true
			else: clear = true
	suite.check(flame and clear,"soul fire draws a flame silhouette over transparent pixels")

extends RefCounted

# The pale oak family (mcl_pale_oak): resin, hanging moss, pale moss and the
# eyeblossom, which opens at night.
static func run(suite: Object, game: Node3D) -> void:
	suite.check(PaleOak.RESIN_CLUMP == 11519 and PaleOak.EYEBLOSSOM_OPEN == 11529,"the pale-oak content holds its allocated ids")
	suite.check(Nodes.exists(PaleOak.RESIN_BLOCK) and Nodes.exists(PaleOak.RESIN_BRICK_BLOCK) and Nodes.exists(PaleOak.CHISELED_RESIN_BRICK),"the resin blocks exist")
	suite.check(not Nodes.placeable(PaleOak.RESIN_CLUMP) and not Nodes.placeable(PaleOak.RESIN_BRICK) and Nodes.placeable(PaleOak.RESIN_BLOCK),"the two resin forms are items and the block is placeable")
	suite.check(Nodes.tile(PaleOak.RESIN_BLOCK,0) != 0 and Nodes.tile(PaleOak.PALE_MOSS,0) != 0,"the new blocks have their own atlas tiles")
	# Recipes and the smelting chain.
	var inv := Inventory.new()
	inv.add_item(PaleOak.RESIN_CLUMP,9)
	var block: int = inv.recipe_index(PaleOak.RESIN_BLOCK)
	suite.check(block >= 0 and inv.craft(block,"table") and inv.count_item(PaleOak.RESIN_BLOCK) == 1,"nine resin clumps make a block of resin")
	inv = Inventory.new(); inv.add_item(PaleOak.RESIN_BLOCK,1)
	var back: int = inv.recipe_index(PaleOak.RESIN_CLUMP)
	suite.check(back >= 0 and inv.craft(back,"hand") and inv.count_item(PaleOak.RESIN_CLUMP) == 9,"a block of resin unpacks into nine clumps")
	suite.check(Nodes.smelt_result(PaleOak.RESIN_CLUMP) == PaleOak.RESIN_BRICK,"a resin clump smelts into a resin brick")
	suite.check(Anvils.repair_material(PaleOak.RESIN_BLOCK) == 0 and ArmorTrims.is_material(PaleOak.RESIN_BRICK),"resin is a trim material")
	inv = Inventory.new(); inv.add_item(PaleOak.RESIN_BRICK,4)
	var bricks: int = inv.recipe_index(PaleOak.RESIN_BRICK_BLOCK)
	suite.check(bricks >= 0 and inv.craft(bricks,"hand") and inv.count_item(PaleOak.RESIN_BRICK_BLOCK) == 1,"four resin bricks make a resin brick block")
	inv = Inventory.new(); inv.add_item(PaleOak.PALE_MOSS,2)
	var carpet: int = inv.recipe_index(PaleOak.PALE_MOSS_CARPET)
	suite.check(carpet >= 0 and inv.craft(carpet,"hand") and inv.count_item(PaleOak.PALE_MOSS_CARPET) == 3,"two pale moss make three carpets, as the source registers")
	# Hanging moss grows downward, at most eight long, and only into air.
	var world: VoxelWorld = game.world
	var at: Vector3i = Vector3i(4,game.world.generator.terrain_height(4,4)+20,4)
	for x in range(-3,4):
		for y in range(-2,12):
			for z in range(-3,4): world.set_node(at+Vector3i(x,y,z),Nodes.AIR)
	world.set_node(at,PaleOak.PALE_MOSS)
	world.set_node(at+Vector3i.DOWN,PaleOak.HANGING_MOSS_TIP)
	suite.check(PaleOak.tower(world,at+Vector3i.DOWN).length == 1,"a lone tip is a tower of one")
	var grown: int = 0
	while PaleOak.grow_hanging_moss(world,at+Vector3i.DOWN) and grown < 12: grown += 1
	suite.check(grown == PaleOak.MOSS_MAX_LENGTH-1,"hanging moss grows to the source's maximum length of eight and then stops")
	suite.check(PaleOak.is_hanging_moss(world.node_at(at+Vector3i.DOWN-Vector3i.UP*(PaleOak.MOSS_MAX_LENGTH-1))),"the strand ends at its length")
	suite.check(world.node_at(at+Vector3i.DOWN) == PaleOak.HANGING_MOSS,"the first cell stops being a tip once it has a strand below")
	suite.check(not PaleOak.grow_hanging_moss(world,at+Vector3i.DOWN),"a strand at its maximum length refuses further growth")
	# Pale moss spreads onto convertible blocks by bone meal.
	var spot: Vector3i = at+Vector3i(2,6,0)
	for y in range(-6,8): world.set_node(spot+Vector3i.UP*y,Nodes.AIR)
	for dx in range(-3,4):
		for dz in range(-3,4): world.set_node(spot+Vector3i(dx,-1,dz),Nodes.STONE); world.set_node(spot+Vector3i(dx,0,dz),Nodes.AIR)
	world.set_node(spot,PaleOak.PALE_MOSS)
	var rng := RandomNumberGenerator.new(); rng.seed = 4
	suite.check(PaleOak.bone_meal_moss(world,spot,rng),"bone meal spreads pale moss onto stone")
	var converted: int = 0
	for dx in range(-3,4):
		for dz in range(-3,4):
			if world.node_at(spot+Vector3i(dx,-1,dz)) == PaleOak.PALE_MOSS: converted += 1
	suite.check(converted >= 2,"the spread converts more than the source block itself")
	suite.check(PaleOak.converts_to_moss(Nodes.STONE) and PaleOak.converts_to_moss(Nodes.GRASS) and not PaleOak.converts_to_moss(Nodes.BEDROCK),"only the source's convertible blocks accept pale moss")
	# The eyeblossom opens at night on the source's two-second clock.
	suite.check(PaleOak.is_night(0.1) and PaleOak.is_night(0.9) and not PaleOak.is_night(0.5),"the eyeblossom's night test is the source's time-of-day window")
	var flower: Vector3i = at+Vector3i(0,9,0)
	world.set_node(flower,Nodes.GRASS)
	world.set_node(flower+Vector3i.UP,PaleOak.EYEBLOSSOM)
	PaleOak.registered(world,flower+Vector3i.UP)
	var saved_day: float = game.day_time
	game.day_time = 0.1
	PaleOak.update(game,2.5)
	suite.check(world.node_at(flower+Vector3i.UP) == PaleOak.EYEBLOSSOM_OPEN,"a closed eyeblossom opens at night")
	game.day_time = saved_day
	suite.check(PaleOak.drop_id(PaleOak.HANGING_MOSS) == 0,"a hanging moss strand drops nothing by hand")

extends RefCounted

# The crimson/warped nether plants (mcl_crimson): fungi, roots, sprouts, vines and
# the warped wart block, plus the huge-fungus growth.
static func run(suite: Object, game: Node3D) -> void:
	suite.check(CrimsonPlants.CRIMSON_FUNGUS == 11511 and CrimsonPlants.WARPED_WART_BLOCK == 11518,"the nether plants hold their allocated ids")
	var all_ok: bool = true
	for i in CrimsonPlants.COUNT:
		var id: int = CrimsonPlants.CRIMSON_FUNGUS+i
		if not Nodes.exists(id) or Nodes.tile(id,0) == 0: all_ok = false
	suite.check(all_ok,"every nether plant exists with its own atlas tile")
	suite.check(Nodes.placeable(CrimsonPlants.CRIMSON_FUNGUS) and Nodes.placeable(CrimsonPlants.WARPED_WART_BLOCK),"both a plant and the wart block are placeable")
	suite.check(CrimsonPlants.light_level(CrimsonPlants.CRIMSON_FUNGUS) == 1 and CrimsonPlants.light_level(CrimsonPlants.WARPED_WART_BLOCK) == 0,"a fungus carries the source's light level of one and the wart block none")
	# `Pasture.emission` takes a cell, so place the fungus before asking it.
	var lit_at: Vector3i = Vector3i(4,game.world.generator.terrain_height(4,4)+30,4)
	game.world.set_node(lit_at+Vector3i.DOWN,Nodes.CRIMSON_NYLIUM)
	game.world.set_node(lit_at,CrimsonPlants.CRIMSON_FUNGUS)
	suite.check(Pasture.emission(game.world,lit_at) == 1,"a placed fungus emits the source's light level of one")
	suite.check(Nodes.plant(CrimsonPlants.CRIMSON_FUNGUS),"a fungus is drawn as a plant, not a cube")
	game.world.set_node(lit_at,Nodes.AIR)
	# A fungus only survives on its own nylium.
	suite.check(CrimsonPlants.soil(CrimsonPlants.CRIMSON_FUNGUS) == "crimson" and CrimsonPlants.soil(CrimsonPlants.WARPED_FUNGUS) == "warped","each fungus names its own soil")
	var world: VoxelWorld = game.world
	var at: Vector3i = Vector3i(4,game.world.generator.terrain_height(4,4)+3,4)
	for x in range(-4,5):
		for y in range(-1,4):
			for z in range(-4,5): world.set_node(at+Vector3i(x,y,z),Nodes.AIR)
	world.set_node(at+Vector3i.DOWN,Nodes.CRIMSON_NYLIUM)
	suite.check(CrimsonPlants.placement_ok(world,at,CrimsonPlants.CRIMSON_FUNGUS),"a crimson fungus is allowed on crimson nylium")
	suite.check(not CrimsonPlants.placement_ok(world,at,CrimsonPlants.WARPED_FUNGUS),"a warped fungus is refused on crimson nylium")
	# Roots and vines drop only to shears; the fungi and the wart block drop themselves.
	var hand: Dictionary = {"id":Nodes.TOOLS,"count":1,"wear":0}
	var shears: Dictionary = {"id":Nodes.SHEARS,"count":1,"wear":0}
	suite.check(CrimsonPlants.harvest(CrimsonPlants.CRIMSON_ROOTS,hand).is_empty() and CrimsonPlants.harvest(CrimsonPlants.CRIMSON_ROOTS,shears) == [[CrimsonPlants.CRIMSON_ROOTS,1]],"a crimson root yields nothing by hand and itself to shears")
	suite.check(CrimsonPlants.harvest(CrimsonPlants.TWISTING_VINES,shears) == [[CrimsonPlants.TWISTING_VINES,1]],"a twisting vine yields itself to shears")
	suite.check(CrimsonPlants.harvest(CrimsonPlants.WARPED_WART_BLOCK,hand) == [[CrimsonPlants.WARPED_WART_BLOCK,1]],"the warped wart block drops itself by hand")
	# Vines grow one to three blocks downward.
	var top: Vector3i = at+Vector3i.UP*2
	world.set_node(top,CrimsonPlants.TWISTING_VINES)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var grown: int = CrimsonPlants.grow(world,top,CrimsonPlants.TWISTING_VINES,rng)
	suite.check(grown >= 1 and grown <= 3,"a vine grows between one and three blocks")
	suite.check(world.node_at(top+Vector3i.DOWN) == CrimsonPlants.TWISTING_VINES,"the vine grows downward from where it was placed")
	# The huge fungus: a stem of three to five with a wart-block cap. This uses its
	# own cleared column, since the vine case above built into `at`.
	var spot: Vector3i = at+Vector3i(6,0,0)
	for y in range(-1,9): world.set_node(spot+Vector3i.UP*y,Nodes.AIR)
	world.set_node(spot+Vector3i.DOWN,Nodes.CRIMSON_NYLIUM)
	world.set_node(spot,CrimsonPlants.CRIMSON_FUNGUS)
	var huge_rng := RandomNumberGenerator.new(); huge_rng.seed = 9
	suite.check(CrimsonPlants.bone_meal_fungus(world,spot,huge_rng),"bone meal grows a huge fungus on its own soil")
	var stems: int = 0
	for y in range(1,8):
		if world.node_at(spot+Vector3i.UP*y) == Nodes.CRIMSON_STEM: stems += 1
	suite.check(stems >= CrimsonPlants.STEM_MIN and stems <= CrimsonPlants.STEM_MIN+CrimsonPlants.STEM_SPAN,"the huge stem is three to five blocks tall")
	var cap: int = 0
	for dx in range(-CrimsonPlants.CAP_RADIUS,CrimsonPlants.CAP_RADIUS+1):
		for dz in range(-CrimsonPlants.CAP_RADIUS,CrimsonPlants.CAP_RADIUS+1):
			var id: int = world.node_at(spot+Vector3i(dx,stems,dz))
			if id == NetherBlocks.NETHER_WART_BLOCK or id == Nodes.SHROOMLIGHT: cap += 1
	suite.check(cap > 0,"the huge fungus carries a wart-block cap")
	# The 40% roll both fires and fails across draws.
	var fires: bool = false; var fails: bool = false
	for i in 60:
		for y in range(0,9): world.set_node(spot+Vector3i.UP*y,Nodes.AIR)
		world.set_node(spot+Vector3i.DOWN,Nodes.CRIMSON_NYLIUM)
		world.set_node(spot,CrimsonPlants.CRIMSON_FUNGUS)
		var roll_rng := RandomNumberGenerator.new(); roll_rng.seed = i
		if CrimsonPlants.bone_meal_fungus(world,spot,roll_rng): fires = true
		else: fails = true
	suite.check(fires and fails,"the fungus growth respects the source's forty-percent roll")
	# A blocked column refuses the growth outright.
	for y in range(0,9): world.set_node(spot+Vector3i.UP*y,Nodes.AIR)
	world.set_node(spot+Vector3i.DOWN,Nodes.CRIMSON_NYLIUM)
	world.set_node(spot,CrimsonPlants.CRIMSON_FUNGUS)
	world.set_node(spot+Vector3i.UP*2,Nodes.CRIMSON_STEM)
	suite.check(not CrimsonPlants.grow_huge(world,spot,CrimsonPlants.CRIMSON_FUNGUS,RandomNumberGenerator.new()),"a blocked column refuses the huge growth rather than growing a partial fungus")

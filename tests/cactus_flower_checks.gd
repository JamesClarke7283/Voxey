extends RefCounted

# Focused regression for the cactus flower. `mcl_core.grow_cactus` grows a sand-set
# cactus to four tall and lets its top sprout a flower on `random() < 0.25` (height
# three or more) or `0.1` below, only when the flower's cell and all four sides are
# air. The flower yields one pink dye.

static func plot(game: Node3D, base: Vector3i) -> void:
	for x in range(-2,3):
		for z in range(-2,3):
			for y in range(0,7): game.world.set_node(base+Vector3i(x,y,z),Nodes.AIR)
			game.world.set_node(base+Vector3i(x,-1,z),Nodes.SAND)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)

	t.check(CactusFlower.ID == 701 and Nodes.exists(701) and Nodes.placeable(701),"the cactus flower is registered and placeable")
	t.check(CactusFlower.MAX_HEIGHT == 4,"the source caps a cactus at four tall")
	t.check(is_equal_approx(CactusFlower.FLOWER_CHANCE_TALL,0.25) and is_equal_approx(CactusFlower.FLOWER_CHANCE_SHORT,0.1),"the source flower chances are used")

	# The dye recipe is one pink per flower.
	var inv := Inventory.new()
	var found: bool = false
	for recipe in inv.recipes:
		if int(recipe.id) == VillageContent.DYE_PINK and int(recipe.count) == 1 and recipe.ingredients.get(701,0) == 1: found = true
	t.check(found,"a cactus flower crafts into one pink dye")

	# A column grows upward toward its four-block cap: from a two-tall column, some
	# seed either adds a cactus or (10% of the time) flowers the top.
	var base := Vector3i(8,1800,8)
	plot(game,base)
	for y in 2: game.world.set_node(base+Vector3i(0,y,0),Nodes.CACTUS)
	t.check(CactusFlower.column_height(game.world,base) == 2,"a two-tall column measures two")
	var grew: bool = false
	for i in 40:
		var rng := RandomNumberGenerator.new(); rng.seed = i
		CactusFlower.grow(game.world,base,rng)
		if CactusFlower.column_height(game.world,base) >= 3: grew = true; break
	t.check(grew,"a cactus column grows upward")
	# It never grows past four.
	for i in 60:
		var rng2 := RandomNumberGenerator.new(); rng2.seed = 500+i
		CactusFlower.grow(game.world,base,rng2)
	t.check(CactusFlower.column_height(game.world,base) <= 4,"a cactus never grows past the source's four-block cap")

	# A tall column flowers when its sides and top are clear.
	plot(game,base)
	for y in 3: game.world.set_node(base+Vector3i(0,y,0),Nodes.CACTUS)
	game.world.set_node(base+Vector3i(0,3,0),Nodes.CACTUS)
	var flowered: bool = false
	for i in 60:
		var rng := RandomNumberGenerator.new(); rng.seed = 1000+i
		if CactusFlower.grow(game.world,base,rng) and game.world.node_at(base+Vector3i(0,4,0)) == CactusFlower.ID:
			flowered = true; break
	t.check(flowered,"a full-height cactus can sprout a flower on top")

	# A blocked side prevents the flower, which is the source's clearance test.
	plot(game,base)
	for y in 4: game.world.set_node(base+Vector3i(0,y,0),Nodes.CACTUS)
	game.world.set_node(base+Vector3i(1,4,0),Nodes.STONE)
	var blocked_flower: bool = false
	for i in 60:
		var rng := RandomNumberGenerator.new(); rng.seed = 2000+i
		CactusFlower.grow(game.world,base,rng)
		if game.world.node_at(base+Vector3i(0,4,0)) == CactusFlower.ID: blocked_flower = true; break
	t.check(not blocked_flower,"a blocked side cell prevents the flower")
	t.check(not CactusFlower.side_clear(game.world,base+Vector3i(0,4,0)),"the clearance test sees the blocked side")

	# Cactus needs sand, which the source's `sand` group requires.
	plot(game,base)
	game.world.set_node(base-Vector3i.UP,Nodes.STONE)
	game.world.set_node(base,Nodes.CACTUS)
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 5
	t.check(not CactusFlower.grow(game.world,base,rng2),"a cactus on stone does not grow")

	# The flower node is plant-shaped and non-solid.
	t.check(VillageContent.shape(701) == "plant" and not Nodes.solid(701),"the flower is a non-solid plant")

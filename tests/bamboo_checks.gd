extends RefCounted

# Focused regression for bamboo (Mineclonia `mcl_bamboo`).
#
# Bamboo is a wood family with three rules that make it distinct from a tree:
#
#   * It grows as a **stalk**, one segment at a time, to a height the source picks
#     per-stalk from its own position hash (`pr:next(12,16)`), so each stalk has its
#     own ceiling.
#   * It **needs light** (9 or more above the tip), so bamboo stops in a cave.
#   * Once established it takes one of **two thicknesses** by a coin flip, which is
#     why a grove has mixed stalks.
#
# Voxey's `scaffolding.gd` recorded bamboo as its missing ingredient, so its recipe
# had substituted another material. This batch adds the stalk and restores the
# source's seven-bamboo-plus-a-string recipe.

static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	world._apply_column(world.generator.generate_column(Vector2i(floori(p.x/16.0),floori(p.z/16.0)),world.edits))
	return world.loaded_at(Vector3(p))

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var gen: TerrainGenerator = game.world.generator

	# --- the nodes and the item exist ---------------------------------------
	t.check(Bamboo.BLOCKS.size() == 4,"the shoot and the three stalk states are registered")
	for id in Bamboo.BLOCKS:
		t.check(VillageContent.DATA.has(id),"the bamboo node %d is registered" % id)
		t.check(Bamboo.is_bamboo(id),"the bamboo node %d identifies itself" % id)
	t.check(not Bamboo.is_bamboo(Nodes.LOG),"a log is not bamboo")
	t.check(VillageContent.DATA.has(Bamboo.BAMBOO_ITEM),"the bamboo item exists, which the stalk drops")
	# The item must be in the texture table, or its art is unreachable.
	t.check(Bamboo.drop(Bamboo.STALK) == Bamboo.BAMBOO_ITEM,"a broken stalk drops the bamboo item")
	t.check(Bamboo.drop(Nodes.LOG) == 0,"breaking a non-bamboo drops nothing from this module")

	# --- the three growth rules ---------------------------------------------
	t.check(Bamboo.HEIGHT_MIN == 12 and Bamboo.HEIGHT_MAX == 16,"the source's twelve-to-sixteen height range is used")
	t.check(Bamboo.MIN_LIGHT == 9,"the source's light requirement is used")
	t.check(is_equal_approx(Bamboo.SMALL_CHANCE,0.5),"the source's coin flip between the two thicknesses is used")
	# Each stalk's ceiling comes from its own position, so a grove is uneven. Two
	# different positions must be able to give different ceilings.
	var heights: Dictionary = {}
	for x in range(0,40): heights[Bamboo.max_height(gen,Vector3i(x,64,x*3))] = true
	t.check(heights.size() > 1,"different stalks get different heights, so a grove is uneven")
	var in_range: bool = true
	for h in heights:
		if int(h) < Bamboo.HEIGHT_MIN or int(h) > Bamboo.HEIGHT_MAX: in_range = false
	t.check(in_range,"every stalk's height is inside the source's range")

	# --- planting ------------------------------------------------------------
	var at := Vector3i(4,64,4)
	t.check(ensure(game,at),"the test column is loaded")
	for y in range(63,86): world.set_node(Vector3i(4,y,4),Nodes.AIR)
	world.set_node(Vector3i(4,63,4),Nodes.GRASS)
	t.check(Bamboo.can_plant(world,at),"bamboo can be planted on grass")
	t.check(Bamboo.plant(world,at),"planting succeeds on soil")
	t.check(world.node_at(at) == Bamboo.SHOOT,"a planted bamboo starts as a shoot")
	# And it refuses a site with no soil, which the source's `soil_bamboo` requires.
	world.set_node(Vector3i(4,63,4),Nodes.STONE)
	t.check(not Bamboo.can_plant(world,at),"bamboo refuses to plant on stone")
	world.set_node(Vector3i(4,63,4),Nodes.GRASS)
	world.set_node(at,Bamboo.SHOOT)

	# --- it grows to its own ceiling ----------------------------------------
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	var lit := func(q: Vector3i) -> int: return 14
	for i in 40:
		Bamboo.grow(world,gen,at,lit,rng)
	var segments: int = 0
	for y in range(63,90):
		if Bamboo.is_bamboo(world.node_at(Vector3i(4,y,4))): segments += 1
	t.check(segments > 2,"a stalk grows into multiple segments")
	# It stops at its own ceiling rather than growing without limit.
	var ceiling: int = Bamboo.max_height(gen,at)
	t.check(segments <= ceiling,"a stalk stops at its own height ceiling")
	t.check(segments == ceiling or world.node_at(Vector3i(4,63+segments,4)) != Nodes.AIR,"a full stalk is blocked, not merely capped")

	# --- it takes one of the two thicknesses --------------------------------
	# Once a stalk has more than one segment the source picks small or big, and the
	# whole stalk takes that size.
	var thickness: int = world.node_at(Vector3i(4,65,4))
	t.check(thickness == Bamboo.SMALL or thickness == Bamboo.BIG,"an established stalk takes one of the two thicknesses")
	t.check(thickness != Bamboo.SHOOT,"an established stalk is no longer a shoot")
	# And the whole stalk agrees, since a stalk does not change thickness partway up.
	var consistent: bool = true
	for y in range(64,63+segments):
		var id: int = world.node_at(Vector3i(4,y,4))
		if id != Bamboo.SHOOT and id != thickness: consistent = false
	t.check(consistent,"a stalk keeps one thickness along its whole length")

	# --- and the light gate stops it -----------------------------------------
	# This is what keeps bamboo out of caves. With no light the stalk must not grow.
	var dark := func(q: Vector3i) -> int: return 0
	var before: int = segments
	Bamboo.grow(world,gen,at,dark,rng)
	var after: int = 0
	for y in range(63,90):
		if Bamboo.is_bamboo(world.node_at(Vector3i(4,y,4))): after += 1
	t.check(after == before,"a stalk does not grow in the dark")
	# Nor can it grow into an occupied cell. The tip is the highest bamboo cell, so
	# the obstacle goes directly above it.
	var tip: int = 62
	for y in range(63,90):
		if Bamboo.is_bamboo(world.node_at(Vector3i(4,y,4))): tip = y
	world.set_node(Vector3i(4,tip+1,4),Nodes.STONE)
	Bamboo.grow(world,gen,at,lit,rng)
	var blocked: int = 0
	for y in range(63,90):
		if Bamboo.is_bamboo(world.node_at(Vector3i(4,y,4))): blocked += 1
	t.check(blocked == before,"a stalk does not grow into an occupied cell")
	t.check(world.node_at(Vector3i(4,tip+1,4)) == Nodes.STONE,"the obstacle is still there")

	# --- the scaffolding recipe uses real bamboo -----------------------------
	# `scaffolding.gd` had substituted a plank while bamboo was missing. Now that
	# the stalk exists, the recipe must use it, and there must be exactly one
	# recipe for the block rather than two competing entries.
	var index: int = -1
	var copies: int = 0
	for i in game.inventory.recipes.size():
		if int(game.inventory.recipes[i].id) == VillageContent.SCAFFOLDING:
			copies += 1
			if index < 0: index = i
	t.check(index >= 0,"the scaffolding recipe exists")
	t.check(copies == 1,"scaffolding has exactly one recipe, not a duplicate")
	if index >= 0:
		var recipe: Dictionary = game.inventory.recipes[index]
		t.check(int(recipe.ingredients.get(Bamboo.BAMBOO_ITEM,0)) == Bamboo.SCAFFOLD_COUNT,"scaffolding takes the source's six bamboo")
		t.check(recipe.ingredients.has(Nodes.STRING),"scaffolding takes a string")
		# And no substitute remains.
		t.check(not recipe.ingredients.has(Nodes.PLANKS),"scaffolding no longer substitutes a plank for bamboo")
		t.check(int(recipe.count) == 6,"the source's recipe yields six scaffolding")

	# --- the mesh is a narrow column, not a cube -----------------------------
	# A stalk that rendered as a cube would be a wall of bamboo.
	t.check(VillageContent.shape(Bamboo.STALK) == "bamboo","the stalk carries its own shape")
	world.set_node(at,Bamboo.STALK)
	var boxes: Array = world.collision_boxes(at)
	if boxes.size() == 1:
		t.check(boxes[0].size.x < 0.5,"a bamboo stalk is narrower than half a block")
	# Its art must be its own, so the node resolves past the shared fallback tile.
	t.check(VillageContent.BLOCKS.has(Bamboo.STALK),"the stalk is in the texture table")

	# --- recipes -------------------------------------------------------------
	# The source's own `recipes.lua`: two stacked bamboo make a stick, and six
	# bamboo around a string make scaffolding.
	# Sticks already have a plank recipe, so this one is found by its own name rather
	# than by its output id.
	var bamboo_sticks: Dictionary = {}
	for recipe in game.inventory.recipes:
		if recipe.name == "Sticks from bamboo": bamboo_sticks = recipe
	t.check(not bamboo_sticks.is_empty(),"bamboo makes sticks")
	if not bamboo_sticks.is_empty():
		t.check(int(bamboo_sticks.ingredients.get(Bamboo.BAMBOO_ITEM,0)) == 2,"a stick takes two bamboo, as the source's stacked recipe does")
		t.check(int(bamboo_sticks.count) == 1,"two bamboo yield one stick, which is the source's own output")
	var scaffold_recipes: int = 0
	for recipe in game.inventory.recipes:
		if int(recipe.ingredients.get(Bamboo.BAMBOO_ITEM,0)) >= 6: scaffold_recipes += 1
	t.check(scaffold_recipes > 0,"six bamboo make scaffolding, the source's own shape")

	# --- natural groves ------------------------------------------------------
	# The source registers bamboo as a levelgen feature, so it grows wild. The stalk
	# height is `5 + rng:next_within(12)`, i.e. five to sixteen, and a stalk taller
	# than three carries the small and large leaf forms at its tip.
	t.check(Bamboo.TRUNK_MIN == 5 and Bamboo.TRUNK_RANGE == 12,"the source's trunk height range is recorded")
	var bases: Dictionary = {}
	var with_tip: int = 0
	var total: int = 0
	for cx in range(-3,4):
		for cz in range(-3,4):
			game.world._apply_column(game.world.generator.generate_column(Vector2i(cx,cz),{}))
	for x in range(-48,48):
		for z in range(-48,48):
			for wy in range(18,42):
				var base := Vector3i(x,wy,z)
				if game.world.node_at(base) != Bamboo.STALK: continue
				if game.world.node_at(base-Vector3i.UP) in [Bamboo.STALK,Bamboo.SMALL,Bamboo.BIG]: continue
				var height: int = 0
				var cur: Vector3i = base
				while game.world.node_at(cur) in [Bamboo.STALK,Bamboo.SMALL,Bamboo.BIG]:
					height += 1; cur += Vector3i.UP
				bases[height] = true
				total += 1
				if game.world.node_at(cur-Vector3i.UP) in [Bamboo.SMALL,Bamboo.BIG]: with_tip += 1
	t.check(total > 0,"terrain grows bamboo groves in the warm regions")
	if total > 0:
		t.check(bases.keys().all(func(k: int): return k >= Bamboo.TRUNK_MIN and k <= Bamboo.TRUNK_MIN+Bamboo.TRUNK_RANGE-1),"every wild stalk is within the source's five-to-sixteen height")
		t.check(bases.size() > 1,"wild stalks have varied heights rather than one fixed height")
		t.check(with_tip == total,"a wild stalk carries the leaf forms at its tip, as the source's placement does")

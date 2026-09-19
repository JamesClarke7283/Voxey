extends RefCounted

# Focused regression for the lush cave set (Mineclonia `mcl_lush_caves`).
#
# Lush caves are the source's *lit* cave biome, and the light comes from cave vines
# carrying **glow berries**:
#
#   * An unlit vine hangs from a ceiling and is climbable.
#   * Its **lit** form emits light 14, which is what makes a lush cave visible
#     without a torch.
#   * **Bone meal** ripens a vine's *tip*, so berries grow where they can be reached.
#   * **Right-clicking** a lit vine picks a berry and reverts the vine, so the vine
#     survives and can fruit again.
#   * A glow berry is food worth two points, and moss makes mossy cobblestone and
#     mossy stone bricks — two recipes Voxey could not offer before, because the
#     moss did not exist.

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

	# --- the nodes exist ----------------------------------------------------
	for id in LushCaves.BLOCKS:
		t.check(VillageContent.DATA.has(id),"the lush cave block %d is registered" % id)
	t.check(VillageContent.DATA.has(LushCaves.GLOW_BERRY),"the glow berry is registered")
	t.check(LushCaves.is_vine(LushCaves.CAVE_VINES),"the unlit vine identifies itself")
	t.check(LushCaves.is_lit_vine(LushCaves.CAVE_VINES_LIT),"the lit vine identifies itself")
	t.check(not LushCaves.is_vine(Nodes.VINE),"an ordinary vine is not a cave vine")

	# --- a vine renders, and does not block movement -------------------------
	# Three separate lists decide this, and all three originally omitted `"vine"`:
	# `Nodes.plant` (so the plant mesher draws it), `VillageContent.special` (so it
	# is not treated as a shape with no mesh builder) and `Nodes.solid` (so it does
	# not block movement). Each omission has a different symptom — the first two
	# leave it invisible, the last makes a hanging strand a wall.
	for id in LushCaves.BLOCKS:
		t.check(Art.build_node_mesh(id).get_surface_count() > 0,"lush cave block %d renders geometry rather than nothing" % id)
	t.check(Nodes.plant(LushCaves.CAVE_VINES),"a cave vine is a plant, so the plant mesher draws it")
	t.check(not VillageContent.special(LushCaves.CAVE_VINES),"a cave vine is not an unmeshed special shape")
	t.check(not Nodes.solid(LushCaves.CAVE_VINES) and Nodes.transparent(LushCaves.CAVE_VINES),"a cave vine is neither solid nor opaque, so it never blocks movement or sight")
	t.check(Nodes.tile(LushCaves.CAVE_VINES,0) != 136,"a cave vine has its own atlas tile rather than the fallback")
	# And it is climbable, which is the source's `climbable = true`.
	world.set_node(Vector3i(4,68,4),LushCaves.CAVE_VINES)
	t.check(LushCaves.climbable(world,Vector3i(4,68,4)),"a placed cave vine is climbable")
	world.set_node(Vector3i(4,68,4),LushCaves.CAVE_VINES_LIT)
	t.check(LushCaves.climbable(world,Vector3i(4,68,4)),"a lit cave vine is climbable too")
	world.set_node(Vector3i(4,68,4),Nodes.STONE)
	t.check(not LushCaves.climbable(world,Vector3i(4,68,4)),"ordinary stone is not climbable")

	# --- the lit vine is the light source -----------------------------------
	# This is why the block matters: a lush cave is visible because its vines glow.
	t.check(LushCaves.LIT_LIGHT == 14,"the source's light level of fourteen is used")
	t.check(LushCaves.light_level(LushCaves.CAVE_VINES_LIT) == 14,"a lit vine reports the source's light")
	t.check(LushCaves.light_level(LushCaves.CAVE_VINES) == 0,"an unlit vine reports no light")
	# And the light really reaches the emitter, which is a separate consumer.
	var at := Vector3i(4,64,4)
	t.check(ensure(game,at),"the test column is loaded")
	for y in range(62,70): world.set_node(Vector3i(4,y,4),Nodes.AIR)
	world.set_node(Vector3i(4,69,4),Nodes.STONE)
	world.set_node(Vector3i(4,68,4),LushCaves.CAVE_VINES_LIT)
	t.check(Pasture.emission(world,Vector3i(4,68,4)) == LushCaves.LIT_LIGHT,"a placed lit vine emits its light")
	world.set_node(Vector3i(4,68,4),LushCaves.CAVE_VINES)
	t.check(Pasture.emission(world,Vector3i(4,68,4)) == 0,"a placed unlit vine emits nothing")

	# --- a vine hangs from a ceiling -----------------------------------------
	# The support is the cell *directly* above the vine, so the ceiling goes at 68
	# and the vine would sit at 67.
	world.set_node(Vector3i(4,68,4),Nodes.STONE)
	t.check(LushCaves.supported(world,Vector3i(4,67,4)),"a vine hangs below solid ground")
	world.set_node(Vector3i(4,68,4),Nodes.AIR)
	t.check(not LushCaves.supported(world,Vector3i(4,67,4)),"a vine needs something to hang from")
	# Another vine also counts as support, which is how a vine tower hangs.
	world.set_node(Vector3i(4,68,4),LushCaves.CAVE_VINES)
	t.check(LushCaves.supported(world,Vector3i(4,67,4)),"a vine hangs from another vine")

	# --- bone meal ripens the tip -------------------------------------------
	# The source ripens the *tip* rather than the whole vine, so berries grow where
	# they can be reached.
	world.set_node(Vector3i(4,69,4),Nodes.STONE)
	var tower: Array = [68,67,66]
	for y in tower: world.set_node(Vector3i(4,y,4),LushCaves.CAVE_VINES)
	t.check(LushCaves.vine_tip(world,Vector3i(4,68,4)).y == 66,"a vine's tip is its lowest cell")
	t.check(LushCaves.vine_top(world,Vector3i(4,66,4)).y == 68,"a vine's top is its highest cell")
	t.check(LushCaves.ripen(world,Vector3i(4,68,4)),"bone meal ripens the vine")
	t.check(world.node_at(Vector3i(4,66,4)) == LushCaves.CAVE_VINES_LIT,"the tip becomes lit")
	t.check(world.node_at(Vector3i(4,68,4)) == LushCaves.CAVE_VINES,"the rest of the vine stays unlit")
	# A vine that is already lit cannot be ripened again.
	t.check(not LushCaves.ripen(world,Vector3i(4,66,4)),"an already-lit tip does not ripen twice")

	# --- harvesting a berry reverts the vine ---------------------------------
	# The source does this on right-click, so the vine survives and can fruit again.
	t.check(LushCaves.harvest(world,Vector3i(4,66,4)),"a berry is harvested from a lit vine")
	t.check(world.node_at(Vector3i(4,66,4)) == LushCaves.CAVE_VINES,"the harvested vine reverts to unlit")
	t.check(Pasture.emission(world,Vector3i(4,66,4)) == 0,"the reverted vine stops glowing")
	t.check(not LushCaves.harvest(world,Vector3i(4,66,4)),"an unlit vine yields no berry")

	# --- the glow berry is food ----------------------------------------------
	# The source gives it two food points, so it is edible rather than only a light
	# source's drop.
	t.check(Nodes.food(LushCaves.GLOW_BERRY) == LushCaves.BERRY_FOOD,"the glow berry restores the source's two food points")
	t.check(LushCaves.BERRY_COMPOST == 50,"the source's compostability is recorded")

	# --- moss makes the mossy blocks -----------------------------------------
	# The source's own recipes, which Voxey could not offer before moss existed.
	var cobble_index: int = game.inventory.recipe_index(Nodes.MOSSY_COBBLE)
	t.check(cobble_index >= 0,"mossy cobblestone has a recipe")
	if cobble_index >= 0:
		var recipe: Dictionary = game.inventory.recipes[cobble_index]
		t.check(recipe.ingredients.has(LushCaves.MOSS),"mossy cobblestone takes moss")
		t.check(recipe.ingredients.has(Nodes.COBBLE),"mossy cobblestone takes cobblestone")
	# And mossy stone bricks, whose id is written literally in the module to avoid a
	# dependency cycle through the content table.
	var bricks_index: int = game.inventory.recipe_index(1161)
	t.check(bricks_index >= 0,"mossy stone bricks have a recipe")
	if bricks_index >= 0:
		var recipe: Dictionary = game.inventory.recipes[bricks_index]
		t.check(recipe.ingredients.has(LushCaves.MOSS),"mossy stone bricks take moss")

	# --- the vines are art, not blank ----------------------------------------
	# A node without art renders as a missing texture.
	for id in [LushCaves.CAVE_VINES,LushCaves.CAVE_VINES_LIT,LushCaves.MOSS,LushCaves.HANGING_ROOTS]:
		var lit: int = 0
		for x in 16:
			for y in 16:
				if VillageArt.pixel(id,x,y,Color(0.5,0.5,0.5)).a > 0: lit += 1
		t.check(lit > 0,"the lush cave block %d builds non-transparent art" % id)
	# A vine is a thin strand, so much of its tile is transparent.
	var vine_opaque: int = 0
	for x in 16:
		for y in 16:
			if VillageArt.pixel(LushCaves.CAVE_VINES,x,y,Color(0.5,0.5,0.5)).a > 0: vine_opaque += 1
	t.check(vine_opaque < 128,"a vine is a thin strand rather than a full tile")

extends RefCounted

# Focused regression for soul lanterns and chains (Mineclonia `mcl_lanterns`).
#
# The copper family's own notes recorded that its **lanterns and chains** were
# absent because they belong to `mcl_lanterns` rather than to `mcl_copper`. This
# covers the iron and soul variants plus chains; the copper-coloured lanterns need
# the oxidation chains re-registered for lantern nodes and remain open.

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

	# --- both nodes exist ---------------------------------------------------
	t.check(VillageContent.DATA.has(VillageContent.SOUL_LANTERN),"the soul lantern is a registered node")
	t.check(VillageContent.DATA.has(VillageContent.CHAIN),"the chain is a registered node")
	t.check(VillageContent.DATA[VillageContent.SOUL_LANTERN].name == "Soul lantern","the soul lantern carries the source's name")
	t.check(VillageContent.DATA[VillageContent.CHAIN].name == "Chain","the chain carries the source's name")
	t.check(Lanterns.is_soul_lantern(VillageContent.SOUL_LANTERN),"the soul lantern identifies itself")
	t.check(Lanterns.is_chain(VillageContent.CHAIN),"the chain identifies itself")
	t.check(not Lanterns.is_soul_lantern(VillageContent.LANTERN),"an iron lantern is not a soul lantern")
	# The source gives a soul lantern its own dimmer light level.
	t.check(Lanterns.SOUL_LIGHT == 10,"the source's soul lantern light of ten is used")

	# --- the soul lantern really emits light --------------------------------
	# The data's light field and the emission function are separate: a node can
	# claim a light level and still emit nothing if the emitter does not know it.
	# That is the bug this check exists to catch.
	var at := Vector3i(6,64,6)
	t.check(ensure(game,at),"the test column is loaded")
	world.set_node(at,VillageContent.SOUL_LANTERN)
	t.check(world.node_at(at) == VillageContent.SOUL_LANTERN,"the soul lantern is placed")
	t.check(Pasture.emission(world,at) == Lanterns.SOUL_LIGHT,"a placed soul lantern really emits its light")
	# It is dimmer than an iron lantern, which the source's own levels give.
	world.set_node(at,VillageContent.LANTERN)
	t.check(Pasture.emission(world,at) > Lanterns.SOUL_LIGHT,"an iron lantern is brighter than a soul one")
	t.check(Pasture.emission(world,at) == 14,"the iron lantern emits the source's full level")

	# --- the source's recipes -----------------------------------------------
	# A soul lantern is the iron-nugget ring around a soul torch; a chain is
	# nugget-ingot-nugget down a column.
	var soul_index: int = game.inventory.recipe_index(VillageContent.SOUL_LANTERN)
	t.check(soul_index >= 0,"the soul lantern has a recipe")
	if soul_index >= 0:
		var recipe: Dictionary = game.inventory.recipes[soul_index]
		t.check(recipe.ingredients.has(Nodes.SOUL_TORCH),"the soul lantern recipe takes a soul torch, not an ordinary one")
		t.check(int(recipe.ingredients.get(Nodes.IRON_NUGGET,0)) == 8,"the soul lantern takes the source's eight iron nuggets")
	var chain_index: int = game.inventory.recipe_index(VillageContent.CHAIN)
	t.check(chain_index >= 0,"the chain has a recipe")
	if chain_index >= 0:
		var chain_recipe: Dictionary = game.inventory.recipes[chain_index]
		t.check(chain_recipe.ingredients.has(Nodes.IRON),"the chain takes an iron ingot")
		t.check(int(chain_recipe.ingredients.get(Nodes.IRON_NUGGET,0)) == 2,"the chain takes the source's two nuggets")

	# --- a lantern is made from whichever torch ------------------------------
	# The source's `register_lantern` is called once per lantern kind, and the
	# torch decides the kind.
	t.check(Lanterns.from_torch(Nodes.SOUL_TORCH) == VillageContent.SOUL_LANTERN,"a soul torch makes a soul lantern")
	t.check(Lanterns.from_torch(Nodes.TORCH) == VillageContent.LANTERN,"an ordinary torch makes an iron lantern")

	# --- what hangs from a chain --------------------------------------------
	# The source lets a chain hold another chain or a lantern, which is what makes
	# a hanging lantern reachable.
	t.check(Lanterns.hangs_from_chain(VillageContent.CHAIN),"a chain hangs from a chain")
	t.check(Lanterns.hangs_from_chain(VillageContent.LANTERN),"a lantern hangs from a chain")
	t.check(Lanterns.hangs_from_chain(VillageContent.SOUL_LANTERN),"a soul lantern hangs from a chain")
	t.check(not Lanterns.hangs_from_chain(Nodes.STONE),"an ordinary block does not hang from a chain")

	# --- both build art ------------------------------------------------------
	# A node without art would render as a missing texture.
	for id in [VillageContent.SOUL_LANTERN,VillageContent.CHAIN]:
		var lit: int = 0
		for x in 16:
			for y in 16:
				if VillageArt.pixel(id,x,y,Color(0.5,0.5,0.5)).a > 0: lit += 1
		t.check(lit > 0,"the node %d builds non-transparent art" % id)
	# Both nodes belong in the generated-texture table, so the atlas paints them
	# through `VillageArt.pixel` and their art is their own rather than a shared
	# fallback. `Nodes.tile` returns 136 for any node outside that table, so an
	# absent node would share one generic tile with every other such node.
	t.check(VillageContent.BLOCKS.has(VillageContent.SOUL_LANTERN),"the soul lantern is in the texture table")
	t.check(VillageContent.BLOCKS.has(VillageContent.CHAIN),"the chain is in the texture table")
	var shared_tile: int = Nodes.tile(Nodes.BOOKSHELF,0)  # A node with its own id-based tile.
	for id in [VillageContent.SOUL_LANTERN,VillageContent.CHAIN]:
		var tile: int = Nodes.tile(id,0)
		t.check(tile >= 137,"the node %d gets its own atlas tile rather than the generic fallback" % id)

	# The chain's mesh must be a narrow column rather than a full cube, or it would
	# render as a solid block despite its transparent texture.
	t.check(VillageContent.shape(VillageContent.CHAIN) == "chain","the chain carries its own shape")
	t.check(VillageContent.special(VillageContent.CHAIN),"the chain is routed to the special mesh path")

	# The table the atlas walks must contain every node whose art is reached
	# through it. An id dropped from this table makes the node render with the
	# shared fallback tile instead of its own art, which is silent: nothing errors
	# and the node still appears, just in the wrong texture. Sixteen ids were lost
	# this way once already, including masonry, the bastion blocks and fire.
	for id in [1150,1151,1152,1153,1154,1155,1156,1157,1100,1101,1102,1103,1104,1105,1117,1118]:
		t.check(VillageContent.BLOCKS.has(id),"the node %d keeps its texture-table entry" % id)
	# And every node this batch added must be there too.
	for id in [Magma.ID,Masonry.CRACKED_BRICKS,Masonry.MOSSY_BRICKS,Masonry.CHISELED_BRICKS,MonsterEggs.STONE,MonsterEggs.COBBLE,MonsterEggs.BRICKS,TrappedChests.ID]:
		t.check(VillageContent.BLOCKS.has(id),"the node %d is in the texture table" % id)
	# A node must resolve to its own atlas tile rather than the shared fallback.
	# Table-wide uniqueness is not asserted, because several modules deliberately
	# share a texture across variants (beehive states, dense materials), so a
	# duplicate tile is legitimate for them.
	var fallback: int = 136
	for id in [Magma.ID,Masonry.CRACKED_BRICKS,Masonry.MOSSY_BRICKS,Masonry.CHISELED_BRICKS,
			MonsterEggs.STONE,MonsterEggs.BRICKS,TrappedChests.ID,
			VillageContent.SOUL_LANTERN,VillageContent.CHAIN]:
		t.check(Nodes.tile(id,0) != fallback,"the node %d resolves past the shared fallback tile" % id)

	# A chain's collision must be a narrow column too, not a full cube. A thin
	# decorative block that blocks movement like stone would be an invisible wall.
	world.set_node(at,VillageContent.CHAIN)
	var boxes: Array = world.collision_boxes(at)
	t.check(boxes.size() == 1,"the chain has one collision box")
	if boxes.size() == 1:
		var box: AABB = boxes[0]
		t.check(box.size.x < 0.5 and box.size.z < 0.5,"the chain's collision is narrower than half a block")
		t.check(is_equal_approx(box.size.x,Lanterns.CHAIN_WIDTH*2),"the chain uses the source's sixteenth-of-a-block width")
	# Compare against a full block, so the difference is explicit.
	world.set_node(at,Nodes.STONE)
	var stone_box: Array = world.collision_boxes(at)
	t.check(stone_box.size() == 1 and is_equal_approx(stone_box[0].size.x,1.0),"an ordinary block still fills its cell")
	world.set_node(at,VillageContent.CHAIN)

	# A chain is a narrow column, so most of its tile is transparent.
	var chain_opaque: int = 0
	for x in 16:
		for y in 16:
			if VillageArt.pixel(VillageContent.CHAIN,x,y,Color(0.5,0.5,0.5)).a > 0: chain_opaque += 1
	t.check(chain_opaque < 256,"a chain is a narrow column rather than a solid block")

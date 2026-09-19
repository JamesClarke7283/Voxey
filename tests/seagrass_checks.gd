extends RefCounted

# Focused regression for seagrass, which the reference registers as rooted nodes
# carrying their own surface block. Placement needs a water source above a
# supported surface, the node itself drops nothing, only shears yield the item,
# and digging one restores the surface block underneath.

static func drops_of(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.queue_free()

# A flooded plot: a supported surface under a column of water.
static func plot(world: VoxelWorld, ground: Vector3i, surface_id: int) -> void:
	for x in range(-6,7):
		for z in range(-6,7):
			world.set_node(Vector3i(ground.x+x,ground.y-1,ground.z+z),surface_id)
			for y in range(5): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.WATER)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var ground := Vector3i(8,1800,8)
	plot(world,ground,Nodes.DIRT)
	clear_drops(game)

	# --- registry ----------------------------------------------------------
	t.check(Seagrass.SURFACES.size() == 6,"the six surfaces Voxey has are registered")
	t.check(Seagrass.SURFACES.has(Nodes.DIRT) and Seagrass.SURFACES.has(Nodes.SAND) and Seagrass.SURFACES.has(Nodes.GRAVEL),"dirt, sand and gravel are supported surfaces")
	t.check(Seagrass.SURFACES.has(VillageContent.PRISMARINE) and Seagrass.SURFACES.has(VillageContent.PRISMARINE_BRICK) and Seagrass.SURFACES.has(VillageContent.PRISMARINE_DARK),"all three prismarine variants are supported surfaces")
	t.check(not Seagrass.SURFACES.has(Nodes.STONE) and not Seagrass.SURFACES.has(Nodes.GRASS),"stone and grass are not seagrass surfaces")
	var registered: int = 0
	for i in 6:
		if Seagrass.is_seagrass(VillageContent.SEAGRASS_FIRST+i): registered += 1
	t.check(registered == 6,"one seagrass node per surface is registered")
	t.check(not Seagrass.is_seagrass(VillageContent.SEAGRASS),"the seagrass item itself is not a node")
	t.check(Seagrass.title(VillageContent.SEAGRASS_FIRST) == "Seagrass","the seagrass node is titled as the source titles it")
	# Each node resolves back to its own surface.
	for s in 6:
		var node: int = VillageContent.SEAGRASS_FIRST+s
		t.check(Seagrass.surface(node) == Seagrass.SURFACES[s],"seagrass node %d resolves its surface"%s)
		t.check(Seagrass.for_surface(Seagrass.SURFACES[s]) == node,"the surface resolves back to its seagrass node")
	t.check(Seagrass.for_surface(Nodes.STONE) == 0,"an unsupported surface has no seagrass node")

	# --- placement rules ---------------------------------------------------
	# Seagrass needs a water source above a supported surface.
	t.check(Seagrass.can_place(world,ground),"seagrass can be placed on dirt under water")
	world.set_node(ground+Vector3i.UP,Nodes.AIR)
	t.check(not Seagrass.can_place(world,ground),"seagrass cannot be placed out of water")
	world.set_node(ground+Vector3i.UP,Nodes.WATER)
	world.set_node(ground-Vector3i.UP,Nodes.STONE)
	t.check(not Seagrass.can_place(world,ground),"seagrass cannot be placed on an unsupported surface")
	# Flowing water is not a source, which the source distinguishes.
	plot(world,ground,Nodes.DIRT)
	var flowing: int = Nodes.WATER+1
	t.check(not Fluids.source(flowing),"a flowing water id is not a source")
	world.set_node(ground+Vector3i.UP,flowing)
	t.check(not Seagrass.can_place(world,ground),"flowing water does not satisfy the source's water-source rule")
	plot(world,ground,Nodes.DIRT)

	# Placing swaps in the matching node.
	game.inventory.restore([]); game.inventory.add_item(VillageContent.SEAGRASS,4); game.inventory.selected = 0
	var target: Dictionary = {"pos":ground-Vector3i.UP,"normal":Vector3i.UP,"id":Nodes.DIRT,"distance":1.0,"point":Vector3(ground)}
	Seagrass.place(game,target,VillageContent.SEAGRASS)
	t.check(world.node_at(ground) == Seagrass.for_surface(Nodes.DIRT),"placing seagrass on dirt creates the dirt seagrass node")
	t.check(game.inventory.count_item(VillageContent.SEAGRASS) == 3,"placing seagrass consumes one item")
	# The right node is chosen per surface.
	for surface_id in [Nodes.SAND,Nodes.GRAVEL,VillageContent.PRISMARINE]:
		plot(world,ground,surface_id)
		Seagrass.place(game,{"pos":ground-Vector3i.UP,"normal":Vector3i.UP,"id":surface_id,"distance":1.0,"point":Vector3(ground)},VillageContent.SEAGRASS)
		t.check(world.node_at(ground) == Seagrass.for_surface(surface_id),"placing on surface %d creates that surface's seagrass node"%surface_id)

	# --- drops -------------------------------------------------------------
	# The node itself drops nothing, exactly as the source's empty drop says.
	t.check(Nodes.drop(Seagrass.for_surface(Nodes.DIRT)) == 0,"a seagrass node drops nothing on its own")
	plot(world,ground,Nodes.DIRT)
	world.set_node(ground,Seagrass.for_surface(Nodes.DIRT))
	clear_drops(game)
	game.break_node(ground,world.node_at(ground),0)
	t.check(world.node_at(ground) == Nodes.DIRT,"digging seagrass restores its surface block")
	t.check(drops_of(game,VillageContent.SEAGRASS) == 0,"digging seagrass by hand yields no seagrass item")
	# Shears do yield the item.
	plot(world,ground,Nodes.DIRT)
	world.set_node(ground,Seagrass.for_surface(Nodes.DIRT))
	clear_drops(game)
	game.break_node(ground,world.node_at(ground),Nodes.SHEARS)
	t.check(drops_of(game,VillageContent.SEAGRASS) == 1,"shears yield one seagrass item")
	t.check(world.node_at(ground) == Nodes.DIRT,"shearing seagrass still restores its surface block")
	clear_drops(game)

	# --- art and mesh ------------------------------------------------------
	var art := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Seagrass.draw(art,Seagrass.for_surface(Nodes.DIRT))
	var painted: int = 0
	for y in 16:
		for x in 16:
			if art.get_pixel(x,y).a > 0.0: painted += 1
	t.check(painted > 0,"seagrass draws a non-empty icon")
	var coord := Vector3i(ground.x/16,ground.y/16,ground.z/16)
	plot(world,ground,Nodes.DIRT)
	var before: int = chunk_verts(world,coord)
	world.set_node(ground,Seagrass.for_surface(Nodes.DIRT))
	t.check(chunk_verts(world,coord) > before,"the chunk mesher emits geometry for seagrass")

	for x in range(-6,7):
		for z in range(-6,7):
			for y in range(5): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)

static func chunk_verts(world: VoxelWorld, coord: Vector3i) -> int:
	var built: Array = BlockMesher.build(world._snapshot(coord),true)
	if built[0] is Array and built[0].size() > Mesh.ARRAY_VERTEX:
		return (built[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return 0

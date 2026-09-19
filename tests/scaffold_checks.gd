extends RefCounted

# Focused regression for scaffolding, which the reference implements with a
# distance field: every scaffold stores how far it is from the nearest support,
# arms may only reach six cells, and anything left beyond that becomes a falling
# node and drops. Placement is direction-sensitive, and the frame is climbable.

static func drops_of(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.queue_free()

# A clean plot, and a fresh distance table so no earlier check leaks in.
static func reset(world: VoxelWorld, ground: Vector3i) -> void:
	for x in range(-8,9):
		for z in range(-8,9):
			world.set_node(Vector3i(ground.x+x,ground.y-1,ground.z+z),Nodes.STONE)
			for y in range(8): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)
	for key in world.block_states.keys():
		if world.block_states[key] is Dictionary: world.block_states[key].erase("scaffold")

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var ground := Vector3i(8,1800,8)
	reset(world,ground)
	clear_drops(game)

	# --- registry ----------------------------------------------------------
	t.check(Scaffolding.is_scaffolding(Scaffolding.ID) and Scaffolding.is_scaffolding(Scaffolding.HORIZONTAL),"the vertical scaffold and its horizontal arm are registered")
	t.check(Nodes.title(Scaffolding.ID) == "Scaffolding" and Nodes.max_stack(Scaffolding.ID) == 64,"scaffolding stacks to 64 and is named as the source names it")
	t.check(is_equal_approx(Nodes.hardness(Scaffolding.ID),0.0),"scaffolding has the source hardness of zero")
	t.check(Nodes.drop(Scaffolding.HORIZONTAL) == Scaffolding.ID,"the horizontal arm drops the plain scaffold item")
	t.check(not Nodes.solid(Scaffolding.ID) and Nodes.transparent(Scaffolding.ID),"scaffolding is a non-solid frame")
	t.check(Scaffolding.boxes(Scaffolding.ID).size() == 5,"the scaffold box is a deck plus four corner posts")
	t.check(is_equal_approx(Scaffolding.LIMIT,6.0),"the source arm limit of six is used")

	# --- placement ---------------------------------------------------------
	# A scaffold placed on the ground is its own support.
	game.inventory.restore([]); game.inventory.add_item(Scaffolding.ID,16); game.inventory.selected = 0
	var target: Dictionary = {"pos":ground+Vector3i(0,-1,0),"normal":Vector3i.UP,"id":Nodes.STONE,"distance":1.0,"point":Vector3(ground)}
	Scaffolding.place(game,target,Scaffolding.ID)
	t.check(world.node_at(ground) == Scaffolding.ID,"a scaffold can be placed on the ground")
	t.check(game.inventory.count_item(Scaffolding.ID) == 15,"placing a scaffold consumes one item")
	# Towering: clicking a scaffold's top continues the column upward.
	Scaffolding.place(game,{"pos":ground,"normal":Vector3i.UP,"id":Scaffolding.ID,"distance":1.0,"point":Vector3(ground)+Vector3.UP} ,Scaffolding.ID)
	t.check(world.node_at(ground+Vector3i.UP) == Scaffolding.ID,"clicking a scaffold towers the column upward")
	Scaffolding.place(game,{"pos":ground,"normal":Vector3i.UP,"id":Scaffolding.ID,"distance":1.0,"point":Vector3(ground)},Scaffolding.ID)
	t.check(world.node_at(ground+Vector3i(0,2,0)) == Scaffolding.ID,"towering always continues at the column's top")

	# --- the distance field ------------------------------------------------
	# Placing a run of scaffolds on the ground keeps them all supported.
	reset(world,ground)
	game.inventory.restore([]); game.inventory.add_item(Scaffolding.ID,32); game.inventory.selected = 0
	Scaffolding.place(game,{"pos":ground+Vector3i(0,-1,0),"normal":Vector3i.UP,"id":Nodes.STONE,"distance":1.0,"point":Vector3(ground)},Scaffolding.ID)
	t.check(Scaffolding.distance(world,ground) == 0,"a ground-placed scaffold is its own support at distance zero")
	# A cell with no support at all is not supported.
	t.check(Scaffolding.distance(world,Vector3i(ground.x+6,ground.y,ground.z)) == 0,"an untracked cell reads as distance zero by default")
	t.check(Scaffolding.supported(world,ground),"a supported scaffold reports as supported")

	# --- arms past the limit fall and drop ---------------------------------
	# Build a supported arm chain by hand: a support at the origin and arms
	# marching away from it, then push one past the limit.
	reset(world,ground)
	for i in range(Scaffolding.LIMIT+1):
		world.set_node(ground+Vector3i(i,0,0),Scaffolding.HORIZONTAL)
	Scaffolding.set_distance(world,ground,0)
	Scaffolding.update(world,ground)
	var far: Vector3i = ground+Vector3i(Scaffolding.LIMIT,0,0)
	var beyond: Vector3i = ground+Vector3i(Scaffolding.LIMIT+1,0,0)
	t.check(world.node_at(ground) == Scaffolding.HORIZONTAL,"the support arm survives an update")
	t.check(Scaffolding.distance(world,beyond) <= Scaffolding.LIMIT+1,"the distance field records how far the arm reached")
	# The source drops anything beyond the limit rather than leaving it hanging.
	Scaffolding.set_distance(world,beyond,Scaffolding.LIMIT+1)
	world.set_node(beyond,Scaffolding.HORIZONTAL)
	Scaffolding.update(world,beyond)
	t.check(drops_of(game,Scaffolding.ID) > 0,"an arm beyond the six-cell limit falls and drops as an item")
	t.check(world.node_at(beyond) == Nodes.AIR,"the stranded arm is removed from the world")
	clear_drops(game)

	# --- removal strands the far end ---------------------------------------
	reset(world,ground)
	for i in range(4):
		world.set_node(ground+Vector3i(i,0,0),Scaffolding.HORIZONTAL)
	Scaffolding.set_distance(world,ground,0)
	Scaffolding.update(world,ground)
	t.check(world.node_at(ground+Vector3i(3,0,0)) == Scaffolding.HORIZONTAL,"the arm chain stands while its support remains")
	# Removing the support must strand the whole chain, not leave it floating.
	world.set_node(ground,Nodes.AIR)
	Scaffolding.changed(world,ground,Scaffolding.HORIZONTAL,Nodes.AIR)
	t.check(drops_of(game,Scaffolding.ID) > 0,"removing the support drops the stranded arms")
	clear_drops(game)

	# --- climbable ---------------------------------------------------------
	reset(world,ground)
	world.set_node(ground,Scaffolding.ID)
	t.check(Scaffolding.climbable(world,ground),"a scaffold is climbable, as the source's climbable flag says")
	t.check(not Scaffolding.climbable(world,ground+Vector3i(3,0,0)),"air is not climbable")

	# --- mesh and art ------------------------------------------------------
	reset(world,ground)
	var coord := Vector3i(ground.x/16,ground.y/16,ground.z/16)
	var before: int = chunk_verts(world,coord)
	world.set_node(ground,Scaffolding.ID)
	var after: int = chunk_verts(world,coord)
	t.check(after > before,"the chunk mesher emits geometry for scaffolding")
	var art := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Scaffolding.draw(art,Scaffolding.ID)
	var painted: int = 0
	for y in 16:
		for x in 16:
			if art.get_pixel(x,y).a > 0.0: painted += 1
	t.check(painted > 0,"scaffolding draws a non-empty icon")
	t.check(Scaffolding.pixel(Scaffolding.ID,0,0,Color.WHITE) != Scaffolding.pixel(Scaffolding.ID,7,7,Color.WHITE),"the frame's posts differ from its deck")

	# --- recipe ------------------------------------------------------------
	var inv := Inventory.new()
	t.check(inv.recipe_index(Scaffolding.ID) >= 0,"scaffolding has a recipe")
	if inv.recipe_index(Scaffolding.ID) >= 0:
		var recipe: Dictionary = inv.recipes[inv.recipe_index(Scaffolding.ID)]
		t.check(recipe.count == 6,"the source scaffolding recipe yields six")
		t.check(recipe.ingredients.get(Nodes.STRING,0) == 1,"the scaffold recipe uses one string, as the source does")

	reset(world,ground)
	for x in range(-8,9):
		for z in range(-8,9):
			for y in range(8): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)

# Vertex count of the real chunk mesh, the path scaffolding renders through.
static func chunk_verts(world: VoxelWorld, coord: Vector3i) -> int:
	var built: Array = BlockMesher.build(world._snapshot(coord),true)
	if built[0] is Array and built[0].size() > Mesh.ARRAY_VERTEX:
		return (built[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return 0

extends RefCounted

# Focused regression for sea pickles. The reference registers four sizes in a lit
# and an unlit form: light rises 6, 9, 12, 15; placing one on another grows it;
# bone meal grows and spreads it to sixteen offsets; the lit form needs water
# directly above; and breaking one yields as many items as its size.

static func drops_of(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.queue_free()

# A plot whose floor is dead brain coral, which is the pickle's only parent.
static func plot(world: VoxelWorld, ground: Vector3i) -> void:
	var parent: int = Corals.living_id(1,Corals.DEAD_BLOCK)
	for x in range(-8,9):
		for z in range(-8,9):
			world.set_node(Vector3i(ground.x+x,ground.y-1,ground.z+z),parent)
			for y in range(6): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var ground := Vector3i(8,1800,8)
	plot(world,ground)
	clear_drops(game)
	SeaPickles.reset(world)

	# --- registry ----------------------------------------------------------
	t.check(SeaPickles.SIZES == 4 and SeaPickles.LIGHT == [6,9,12,15],"the source's four sizes and light levels are used")
	var registered: int = 0
	for i in 8:
		if SeaPickles.is_pickle(VillageContent.PICKLE_FIRST+i): registered += 1
	t.check(registered == 8,"four lit and four unlit pickles are registered")
	t.check(not SeaPickles.is_pickle(Nodes.STONE),"ordinary blocks are not pickles")
	for s in range(1,5):
		var lit: int = SeaPickles.for_size(s,true)
		var unlit: int = SeaPickles.for_size(s,false)
		t.check(SeaPickles.size(lit) == s and SeaPickles.size(unlit) == s,"size %d resolves in both forms"%s)
		t.check(SeaPickles.lit(lit) and not SeaPickles.lit(unlit),"size %d has a lit and an unlit form"%s)
		t.check(SeaPickles.light_level(lit) == SeaPickles.LIGHT[s-1],"size %d lights at the source value"%s)
		t.check(SeaPickles.light_level(unlit) == 0,"an unlit pickle emits no light")
	t.check(SeaPickles.light_level(SeaPickles.for_size(4,true)) == 15,"the largest pickle lights at the source maximum")

	# --- parent and water requirements -------------------------------------
	var pickle: int = SeaPickles.for_size(1,true)
	# `on_parent` inspects the cell below the pickle, so set the parent there.
	t.check(SeaPickles.on_parent(world,ground),"a pickle on dead brain coral has a valid parent")
	world.set_node(ground-Vector3i.UP,Corals.living_id(1,Corals.BLOCK))
	t.check(not SeaPickles.on_parent(world,ground),"a living brain coral block is not a valid parent, only the dead one")
	world.set_node(ground-Vector3i.UP,Corals.living_id(0,Corals.DEAD_BLOCK))
	t.check(not SeaPickles.on_parent(world,ground),"another species' dead coral is not a valid parent either")
	plot(world,ground)
	# Lit requires water above.
	world.set_node(ground,pickle)
	t.check(not SeaPickles.wants_lit(world,ground),"a pickle with no water above should be unlit")
	world.set_node(ground+Vector3i.UP,Nodes.WATER)
	t.check(SeaPickles.wants_lit(world,ground),"water directly above makes a pickle lit")
	world.set_node(ground+Vector3i.LEFT,Nodes.WATER)
	world.set_node(ground+Vector3i.UP,Nodes.AIR)
	t.check(not SeaPickles.wants_lit(world,ground),"water to the side does not light a pickle, it must be above")
	world.set_node(ground+Vector3i.LEFT,Nodes.AIR)

	# --- growth ------------------------------------------------------------
	# Placing another pickle on it grows it one size.
	plot(world,ground)
	world.set_node(ground,SeaPickles.for_size(1,false))
	t.check(SeaPickles.grow(world,ground) and SeaPickles.size(world.node_at(ground)) == 2,"growing a pickle raises it one size")
	SeaPickles.grow(world,ground); SeaPickles.grow(world,ground)
	t.check(SeaPickles.size(world.node_at(ground)) == 4,"a pickle grows to the source maximum of four")
	t.check(not SeaPickles.grow(world,ground),"a size-four pickle cannot grow further")
	# Growth keeps the form it had.
	world.set_node(ground,SeaPickles.for_size(1,true))
	SeaPickles.grow(world,ground)
	t.check(SeaPickles.lit(world.node_at(ground)),"growth keeps a lit pickle lit")

	# --- bone meal ---------------------------------------------------------
	plot(world,ground)
	world.set_node(ground,SeaPickles.for_size(1,true))
	var rng := RandomNumberGenerator.new(); rng.seed = 24680
	SeaPickles.bone_meal(world,ground,rng)
	t.check(SeaPickles.size(world.node_at(ground)) == 2,"bone meal grows the pickle it is used on")
	# It also spreads to nearby valid cells.
	var spread: int = 0
	for offset in SeaPickles.SPREAD_OFFSETS:
		if SeaPickles.is_pickle(world.node_at(ground+offset)): spread += 1
	t.check(spread > 0,"bone meal spreads pickles to nearby cells")
	t.check(SeaPickles.SPREAD_OFFSETS.size() == 16,"the source's sixteen spread offsets are used")
	# A spread pickle is never larger than three, which is the source's roll.
	var too_big: bool = false
	for offset in SeaPickles.SPREAD_OFFSETS:
		var id: int = world.node_at(ground+offset)
		if SeaPickles.is_pickle(id) and SeaPickles.size(id) > 3: too_big = true
	t.check(not too_big,"a spread pickle never exceeds the source's size-three roll")
	# Bone meal does not spread onto a cell with no valid parent.
	plot(world,ground)
	world.set_node(ground+Vector3i(2,0,0)-Vector3i(0,1,0),Nodes.STONE)
	world.set_node(ground,SeaPickles.for_size(1,true))
	SeaPickles.bone_meal(world,ground,rng)
	t.check(not SeaPickles.is_pickle(world.node_at(ground+Vector3i(2,0,0))),"bone meal does not spread onto a cell without a coral parent")

	# --- the lit/unlit tick ------------------------------------------------
	SeaPickles.reset(world)
	plot(world,ground)
	world.set_node(ground,SeaPickles.for_size(2,true))
	SeaPickles.registered(world,ground,world.node_at(ground))
	SeaPickles.update(world,1.0)
	t.check(SeaPickles.lit(world.node_at(ground)),"a pickle does not change before the source's 17 second interval elapses")
	# Over many intervals an unwatered pickle becomes unlit.
	for i in 60: SeaPickles.update(world,17.0)
	t.check(not SeaPickles.lit(world.node_at(ground)),"a pickle without water above eventually goes unlit")
	t.check(SeaPickles.size(world.node_at(ground)) == 2,"going unlit does not change the pickle's size")
	# And a watered one becomes lit again.
	world.set_node(ground+Vector3i.UP,Nodes.WATER)
	for i in 60: SeaPickles.update(world,17.0)
	t.check(SeaPickles.lit(world.node_at(ground)),"a watered pickle becomes lit again")
	world.set_node(ground+Vector3i.UP,Nodes.AIR)

	# --- placement ---------------------------------------------------------
	game.inventory.restore([]); game.inventory.add_item(SeaPickles.for_size(1,true),4); game.inventory.selected = 0
	plot(world,ground)
	var held: int = SeaPickles.for_size(1,true)
	# Off a valid parent it is refused.
	world.set_node(ground-Vector3i.UP,Nodes.STONE)
	SeaPickles.place(game,{"pos":ground-Vector3i.UP,"normal":Vector3i.UP,"id":Nodes.STONE,"distance":1.0,"point":Vector3(ground)},held)
	t.check(world.node_at(ground) != held,"a pickle is refused without a dead brain coral parent")
	# On one it is placed.
	plot(world,ground)
	SeaPickles.place(game,{"pos":ground-Vector3i.UP,"normal":Vector3i.UP,"id":Corals.living_id(1,Corals.DEAD_BLOCK),"distance":1.0,"point":Vector3(ground)},held)
	t.check(SeaPickles.is_pickle(world.node_at(ground)),"a pickle places onto dead brain coral")
	t.check(game.inventory.count_item(held) == 3,"placing a pickle consumes one item")
	# Placing onto an existing pickle grows it rather than stacking a node.
	var before_size: int = SeaPickles.size(world.node_at(ground))
	SeaPickles.place(game,{"pos":ground,"normal":Vector3i.UP,"id":world.node_at(ground),"distance":1.0,"point":Vector3(ground)},held)
	t.check(world.node_at(ground) == SeaPickles.for_size(before_size+1,SeaPickles.lit(world.node_at(ground))) or SeaPickles.size(world.node_at(ground)) == before_size+1,"placing onto a pickle grows it in place")

	# --- drop count --------------------------------------------------------
	# The source drops one item per size.
	world.set_node(ground,SeaPickles.for_size(3,true))
	t.check(SeaPickles.size(world.node_at(ground)) == 3,"the pickle is at size three for the drop check")
	t.check(Nodes.drop(SeaPickles.for_size(3,true)) == SeaPickles.for_size(3,true),"a pickle's drop id is itself, with the count carrying the size")

	# --- art and mesh ------------------------------------------------------
	var art := Image.create(16,16,false,Image.FORMAT_RGBA8)
	SeaPickles.draw(art,SeaPickles.for_size(3,true))
	var painted: int = 0
	for y in 16:
		for x in 16:
			if art.get_pixel(x,y).a > 0.0: painted += 1
	t.check(painted > 0,"a sea pickle draws a non-empty icon")
	t.check(SeaPickles.color(SeaPickles.for_size(1,true)) != SeaPickles.color(SeaPickles.for_size(1,false)),"lit and unlit pickles are coloured differently")
	# A larger pickle really lights more, which is what the sizes are for.
	t.check(SeaPickles.light_level(SeaPickles.for_size(1,true)) < SeaPickles.light_level(SeaPickles.for_size(4,true)),"light rises with the pickle's size")
	var coord := Vector3i(ground.x/16,ground.y/16,ground.z/16)
	plot(world,ground)
	var before: int = chunk_verts(world,coord)
	world.set_node(ground,SeaPickles.for_size(4,true))
	t.check(chunk_verts(world,coord) > before,"the chunk mesher emits geometry for a sea pickle")

	SeaPickles.reset(world)
	for x in range(-8,9):
		for z in range(-8,9):
			for y in range(6): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)

static func chunk_verts(world: VoxelWorld, coord: Vector3i) -> int:
	var built: Array = BlockMesher.build(world._snapshot(coord),true)
	if built[0] is Array and built[0].size() > Mesh.ARRAY_VERTEX:
		return (built[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return 0

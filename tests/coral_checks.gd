extends RefCounted

# Focused regression for coral, which the reference gives five species in six
# forms each and one defining behaviour: it dies without water. A plant or fan
# needs a water source above it; a coral block survives while any of its six
# neighbours is water. Death swaps the node to its dead form, which is also the
# living node's own drop.

static func drops_of(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.queue_free()

# A dry plot with stone below, so coral can be placed and then left to die.
static func plot(world: VoxelWorld, ground: Vector3i) -> void:
	for x in range(-6,7):
		for z in range(-6,7):
			world.set_node(Vector3i(ground.x+x,ground.y-1,ground.z+z),Nodes.STONE)
			for y in range(6): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var ground := Vector3i(8,1800,8)
	plot(world,ground)
	clear_drops(game)
	Corals.reset(world)

	# --- registry ----------------------------------------------------------
	t.check(Corals.SPECIES.size() == 5 and Corals.STRIDE == 6,"the source's five species and six forms are used")
	var registered: int = 0
	for i in 30:
		if Corals.is_coral(VillageContent.CORAL_FIRST+i): registered += 1
	t.check(registered == 30,"thirty coral nodes are registered")
	t.check(not Corals.is_coral(Nodes.STONE) and not Corals.is_coral(VillageContent.PRISMARINE),"ordinary blocks are not coral")
	# Every species resolves its own forms and title.
	for s in 5:
		var block: int = Corals.living_id(s,Corals.BLOCK)
		var dead_block: int = Corals.living_id(s,Corals.DEAD_BLOCK)
		t.check(Corals.species(block) == s and Corals.form(block) == Corals.BLOCK,"species %d resolves from its block"%s)
		t.check(Corals.is_block(block) and not Corals.dead(block) and Corals.dead(dead_block),"species %d has a living and a dead block"%s)
		t.check(Corals.title(block).ends_with("Coral Block") and not Corals.title(block).begins_with("Dead"),"species %d's block is titled without the dead prefix"%s)
		t.check(Corals.title(dead_block).begins_with("Dead "),"species %d's dead block is titled as dead"%s)
	# Plants and fans are distinguishable and each has a dead form.
	t.check(Corals.is_plant(Corals.living_id(0,Corals.PLANT)) and not Corals.is_plant(Corals.living_id(0,Corals.FAN)),"plants and fans are distinct forms")
	t.check(Corals.is_fan(Corals.living_id(0,Corals.FAN)),"the fan form is recognised")
	for form in [Corals.BLOCK,Corals.PLANT,Corals.FAN]:
		var live: int = Corals.living_id(2,form)
		t.check(Corals.dead_form(live) != live and Corals.dead(Corals.dead_form(live)),"living form %d has a distinct dead form"%form)
	# A dead node is its own dead form, so death is idempotent.
	t.check(Corals.dead_form(Corals.living_id(1,Corals.DEAD_BLOCK)) == Corals.living_id(1,Corals.DEAD_BLOCK),"a dead block is already its own dead form")

	# --- survival: a block lives while any neighbour is water ---------------
	var block: int = Corals.living_id(0,Corals.BLOCK)
	world.set_node(ground,block)
	t.check(not Corals.survives(world,ground,block),"a coral block with no water anywhere dies")
	world.set_node(ground+Vector3i.DOWN,Nodes.WATER)
	t.check(Corals.survives(world,ground,block),"a coral block survives with water below it")
	world.set_node(ground+Vector3i.DOWN,Nodes.STONE)
	world.set_node(ground+Vector3i.LEFT,Nodes.WATER)
	t.check(Corals.survives(world,ground,block),"water on any one side keeps a coral block alive")
	world.set_node(ground+Vector3i.LEFT,Nodes.STONE)
	t.check(not Corals.survives(world,ground,block),"the coral block dies again once the water is gone")
	# A dead block never has a survival requirement.
	t.check(Corals.survives(world,ground,Corals.living_id(0,Corals.DEAD_BLOCK)),"a dead coral block does not die again")

	# --- survival: a plant or fan needs water above -------------------------
	var plant: int = Corals.living_id(0,Corals.PLANT)
	world.set_node(ground,plant)
	t.check(not Corals.survives(world,ground,plant),"a coral plant with no water above dies even beside water")
	world.set_node(ground+Vector3i.LEFT,Nodes.WATER)
	t.check(not Corals.survives(world,ground,plant),"water to the side does not save a plant, which needs it above")
	world.set_node(ground+Vector3i.LEFT,Nodes.STONE)
	world.set_node(ground+Vector3i.UP,Nodes.WATER)
	t.check(Corals.survives(world,ground,plant),"water directly above keeps a coral plant alive")
	t.check(Corals.survives(world,ground,Corals.living_id(0,Corals.DEAD_PLANT)),"a dead plant does not die again")
	world.set_node(ground+Vector3i.UP,Nodes.AIR)

	# --- death applies on the source's own cadence -------------------------
	# The source uses a 17 second interval with a 1-in-5 chance, so dying is not
	# instantaneous; the tick must not fire before its interval elapses.
	Corals.reset(world)
	world.set_node(ground,block)
	Corals.registered(world,ground,block)
	Corals.update(world,1.0)
	t.check(world.node_at(ground) == block,"coral does not die before the source's 17 second interval elapses")
	# Over many intervals the plant dies, since it has no water above.
	Corals.reset(world)
	world.set_node(ground,plant)
	Corals.registered(world,ground,plant)
	for i in 40: Corals.update(world,17.0)
	t.check(world.node_at(ground) == Corals.dead_form(plant),"a coral plant without water eventually becomes its dead form")
	t.check(int(world.node_at(ground)) != plant,"the living plant is really gone")
	# And a coral with water survives the same number of intervals.
	Corals.reset(world)
	world.set_node(ground,block)
	world.set_node(ground+Vector3i.DOWN,Nodes.WATER)
	Corals.registered(world,ground,block)
	for i in 40: Corals.update(world,17.0)
	t.check(world.node_at(ground) == block,"a coral block with water survives the same intervals")
	world.set_node(ground+Vector3i.DOWN,Nodes.STONE)

	# --- placement ---------------------------------------------------------
	# A plant only goes on a matching species' coral block.
	game.inventory.restore([]); game.inventory.add_item(plant,4); game.inventory.selected = 0
	plot(world,ground)
	var target: Dictionary = {"pos":ground+Vector3i(0,-1,0),"normal":Vector3i.UP,"id":Nodes.STONE,"distance":1.0,"point":Vector3(ground)}
	Corals.place(game,target,plant)
	t.check(world.node_at(ground) != plant,"a plant is refused without a coral block beneath it")
	# With the matching block beneath it, the plant is placed.
	world.set_node(ground,Corals.living_id(0,Corals.BLOCK))
	Corals.place(game,{"pos":ground,"normal":Vector3i.UP,"id":Corals.living_id(0,Corals.BLOCK),"distance":1.0,"point":Vector3(ground)},plant)
	t.check(world.node_at(ground+Vector3i.UP) == plant,"a plant places onto its matching species' coral block")
	# A different species' block refuses it, which is the source's species rule.
	plot(world,ground)
	world.set_node(ground,Corals.living_id(1,Corals.BLOCK))
	Corals.place(game,{"pos":ground,"normal":Vector3i.UP,"id":Corals.living_id(1,Corals.BLOCK),"distance":1.0,"point":Vector3(ground)},plant)
	t.check(world.node_at(ground+Vector3i.UP) != plant,"a plant is refused on a different species' coral block")

	# --- drops and art -----------------------------------------------------
	# The living block's drop is its dead form, which is the source's own drop.
	t.check(Nodes.drop(Corals.living_id(0,Corals.BLOCK)) == Corals.living_id(0,Corals.DEAD_BLOCK),"a living coral block drops its dead form without Silk Touch")
	t.check(Nodes.drop(Corals.living_id(0,Corals.PLANT)) == Corals.living_id(0,Corals.DEAD_PLANT),"a living coral plant drops its dead form")
	t.check(Nodes.drop(Corals.living_id(0,Corals.FAN)) == Corals.living_id(0,Corals.DEAD_FAN),"a living coral fan drops its dead form")
	t.check(Nodes.drop(Corals.living_id(0,Corals.DEAD_BLOCK)) == Corals.living_id(0,Corals.DEAD_BLOCK),"a dead coral block drops itself")
	var art := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Corals.draw(art,Corals.living_id(1,Corals.PLANT))
	var painted: int = 0
	for y in 16:
		for x in 16:
			if art.get_pixel(x,y).a > 0.0: painted += 1
	t.check(painted > 0,"coral draws a non-empty icon")
	t.check(Corals.color(Corals.living_id(0,Corals.BLOCK)) != Corals.color(Corals.living_id(1,Corals.BLOCK)),"each species has its own colour")
	t.check(Corals.color(Corals.living_id(0,Corals.DEAD_BLOCK)) != Corals.color(Corals.living_id(0,Corals.BLOCK)),"dead coral is coloured differently from living coral")
	# Real chunk geometry, which is what makes coral visible.
	var coord := Vector3i(ground.x/16,ground.y/16,ground.z/16)
	plot(world,ground)
	var before: int = chunk_verts(world,coord)
	world.set_node(ground,Corals.living_id(0,Corals.PLANT))
	t.check(chunk_verts(world,coord) > before,"the chunk mesher emits geometry for a coral plant")

	Corals.reset(world)
	for x in range(-6,7):
		for z in range(-6,7):
			for y in range(6): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)

static func chunk_verts(world: VoxelWorld, coord: Vector3i) -> int:
	var built: Array = BlockMesher.build(world._snapshot(coord),true)
	if built[0] is Array and built[0].size() > Mesh.ARRAY_VERTEX:
		return (built[0][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return 0

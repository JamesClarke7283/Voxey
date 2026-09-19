extends RefCounted

# Focused regression for kelp growth. The reference stores a whole stalk's height
# in one node, caps its age at 25 (after which it stops growing), grows on a
# per-tick probability derived from Minecraft's 2.16 growths per day, detaches
# and drops the overgrown part when it stops being submerged, and drops one item
# per unit of height when dug.

static func drops_of(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.queue_free()

# A flooded column over a supported surface.
static func plot(world: VoxelWorld, ground: Vector3i, surface_id: int) -> void:
	for x in range(-6,7):
		for z in range(-6,7):
			world.set_node(Vector3i(ground.x+x,ground.y-1,ground.z+z),surface_id)
			for y in range(24): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.WATER)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var ground := Vector3i(8,1800,8)
	plot(world,ground,Nodes.DIRT)
	clear_drops(game)
	Kelp.reset(world)

	# --- the source's constants --------------------------------------------
	t.check(Kelp.MIN_AGE == 0 and Kelp.MAX_AGE == 25,"the source's age range of 0 to 25 is used")
	t.check(is_equal_approx(Kelp.TICK,0.2),"kelp ticks at the source's 0.2 seconds")
	t.check(is_equal_approx(float(Kelp.GROW_NUMERATOR)/float(Kelp.GROW_DENOMINATOR),216.0*0.2/(100.0*1200.0)),"the growth probability matches the source's own derivation")
	t.check(Kelp.is_kelp(VillageContent.KELP_PLANT) and not Kelp.is_kelp(VillageContent.KELP),"the kelp plant is the kelp node while the kelp item is not")
	# Growth stops at the maximum age, which is the source's rule.
	t.check(Kelp.growable(0) and Kelp.growable(24),"kelp grows while its age is below the maximum")
	t.check(not Kelp.growable(25) and not Kelp.growable(30),"kelp stops growing at and beyond the maximum age")
	# Height is capped at the source's sixteenth stem.
	t.check(Kelp.next_height(1) == 2 and Kelp.next_height(15) == 16 and Kelp.next_height(16) == 16,"height rises one step and caps at sixteen")

	# --- placement ---------------------------------------------------------
	# Kelp is placed into a water cell over a supported surface.
	t.check(Kelp.can_place(world,ground),"kelp can be placed in water on dirt")
	world.set_node(ground,Nodes.AIR)
	t.check(not Kelp.can_place(world,ground),"kelp cannot be placed where the water has been removed")
	world.set_node(ground,Nodes.WATER)
	world.set_node(ground-Vector3i.UP,Nodes.STONE)
	t.check(not Kelp.can_place(world,ground),"kelp cannot be placed on an unsupported surface")
	# A real placement sets a height and an age.
	plot(world,ground,Nodes.DIRT)
	game.inventory.restore([]); game.inventory.add_item(VillageContent.KELP,8); game.inventory.selected = 0
	Kelp.place(game,{"pos":ground-Vector3i.UP,"normal":Vector3i.UP,"id":Nodes.DIRT,"distance":1.0,"point":Vector3(ground)},VillageContent.KELP)
	t.check(world.node_at(ground) == VillageContent.KELP_PLANT,"placing kelp creates the kelp node")
	t.check(game.inventory.count_item(VillageContent.KELP) == 7,"placing kelp consumes one item")
	t.check(Kelp.height(world,ground) == 1,"freshly placed kelp is one tall")
	t.check(Kelp.age(world,ground) >= 0 and Kelp.age(world,ground) < Kelp.MAX_AGE,"freshly placed kelp has an age inside the source range")

	# --- growth ------------------------------------------------------------
	# Over many ticks a young stalk grows taller.
	Kelp.reset(world)
	plot(world,ground,Nodes.DIRT)
	world.set_node(ground,VillageContent.KELP_PLANT)
	Kelp.set_height(world,ground,1)
	Kelp.set_age(world,ground,0)
	Kelp.registered(world,ground,VillageContent.KELP_PLANT)
	for i in 4000: Kelp.update(world,0.2)
	t.check(Kelp.height(world,ground) > 1,"kelp grows taller over many ticks")
	t.check(Kelp.age(world,ground) > 0,"kelp's age advances as it grows")
	# A stalk at the maximum age never grows further.
	Kelp.reset(world)
	Kelp.set_height(world,ground,1)
	Kelp.set_age(world,ground,Kelp.MAX_AGE)
	Kelp.registered(world,ground,VillageContent.KELP_PLANT)
	for i in 4000: Kelp.update(world,0.2)
	t.check(Kelp.height(world,ground) == 1,"kelp at the maximum age stops growing entirely")
	# A stalk already at full height stops at sixteen.
	Kelp.reset(world)
	Kelp.set_height(world,ground,16)
	Kelp.set_age(world,ground,0)
	Kelp.registered(world,ground,VillageContent.KELP_PLANT)
	for i in 4000: Kelp.update(world,0.2)
	t.check(Kelp.height(world,ground) == 16,"kelp never grows beyond the source's sixteenth stem")

	# --- drowning ----------------------------------------------------------
	# A stalk whose water is removed drops its overgrown part.
	Kelp.reset(world)
	plot(world,ground,Nodes.DIRT)
	world.set_node(ground,VillageContent.KELP_PLANT)
	Kelp.set_height(world,ground,4)
	Kelp.set_age(world,ground,0)
	Kelp.registered(world,ground,VillageContent.KELP_PLANT)
	t.check(Kelp.submerged(world,ground),"a stalk in water reports as submerged")
	world.set_node(ground+Vector3i(0,3,0),Nodes.AIR)
	t.check(not Kelp.submerged(world,ground),"a stalk with a missing water cell is not submerged")
	clear_drops(game)
	for i in 5: Kelp.update(world,0.2)
	t.check(world.node_at(ground+Vector3i(0,3,0)) != VillageContent.KELP_PLANT,"the overgrown part of a dried-out stalk is removed")
	t.check(Kelp.age(world,ground) < Kelp.MAX_AGE,"a drowned stalk's age is rerolled, as the source does")

	# --- digging -----------------------------------------------------------
	# One item per unit of height.
	Kelp.reset(world)
	plot(world,ground,Nodes.DIRT)
	world.set_node(ground,VillageContent.KELP_PLANT)
	Kelp.set_height(world,ground,5)
	clear_drops(game)
	game.break_node(ground,VillageContent.KELP_PLANT,0)
	t.check(drops_of(game,VillageContent.KELP) == 5,"digging kelp drops one item per unit of height")
	t.check(world.node_at(ground) == Nodes.DIRT,"digging kelp restores the surface block it grew from")
	clear_drops(game)
	# A one-tall stalk drops exactly one.
	plot(world,ground,Nodes.DIRT)
	world.set_node(ground,VillageContent.KELP_PLANT)
	Kelp.set_height(world,ground,1)
	game.break_node(ground,VillageContent.KELP_PLANT,0)
	t.check(drops_of(game,VillageContent.KELP) == 1,"a one-tall stalk drops one item")
	clear_drops(game)

	Kelp.reset(world)
	for x in range(-6,7):
		for z in range(-6,7):
			for y in range(24): world.set_node(Vector3i(ground.x+x,ground.y+y,ground.z+z),Nodes.AIR)

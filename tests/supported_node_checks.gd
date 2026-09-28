extends RefCounted

# The `supported_node` group: `CORE/mcl_attached/init.lua`:92-98. A carpet rests on
# whatever draws as a real block below it and drops when that becomes air.

static func run(suite: Object, game: Node3D) -> void:
	var base := Vector3i(8,2400,8)
	for x in range(-2,3):
		for z in range(-2,3):
			for y in range(base.y-2,base.y+4): game.world.set_node(Vector3i(base.x+x,y,base.z+z),Nodes.AIR)
			game.world.set_node(Vector3i(base.x+x,base.y-1,base.z+z),Nodes.STONE)

	# --- the group's members --------------------------------------------------
	suite.check(SupportedNodes.is_supported(VillageContent.CARPET_WHITE),"a carpet is a `supported_node`")
	suite.check(SupportedNodes.is_supported(LushCaves.MOSS_CARPET),"and so is a moss carpet")
	suite.check(not SupportedNodes.is_supported(Nodes.STONE) and not SupportedNodes.is_supported(Nodes.AIR),"a solid block is not")
	suite.check(not SupportedNodes.is_supported(Nodes.TORCH),"nor is a torch, which the source marks `attached_node` instead")

	# --- the support test -----------------------------------------------------
	# The source tests the node below for the `airlike` **drawtype**, which is a
	# rendering property and not a solidity one: a carpet rests on a flower, a water
	# cell or another carpet just as well as on stone.
	suite.check(not SupportedNodes.airlike(Nodes.STONE) and SupportedNodes.airlike(Nodes.AIR),"air is the `airlike` node")
	suite.check(not SupportedNodes.airlike(VillageContent.CARPET_WHITE),"a carpet draws, so it is not airlike")
	suite.check(not SupportedNodes.airlike(Nodes.WATER) and not SupportedNodes.airlike(Nodes.TORCH),"and neither water nor a torch is")
	var carpet := base
	game.world.set_node(base+Vector3i.DOWN,Nodes.STONE)
	game.world.set_node(carpet,VillageContent.CARPET_WHITE)
	suite.check(SupportedNodes.supported(game.world,carpet),"a carpet on stone is supported")

	# --- the drop -------------------------------------------------------------
	# Removing the block beneath must drop the carpet, which is the gap this closed.
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion(): drop.queue_free()
	game.world.set_node(base+Vector3i.DOWN,Nodes.AIR)
	suite.check(game.world.node_at(carpet) == Nodes.AIR,"removing the block beneath a carpet drops it rather than leaving it hanging")
	var dropped: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == VillageContent.CARPET_WHITE: dropped += int(drop.amount)
	suite.check(dropped == 1,"and the carpet itself is what drops")
	# The drop happens through `VoxelWorld`'s edit path, not a manual call, so this
	# also proves the wiring rather than the helper alone.
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion(): drop.queue_free()
	# Support first, then the carpet: the other order drops it on placement.
	game.world.set_node(base+Vector3i.DOWN,Nodes.STONE)
	game.world.set_node(carpet,VillageContent.CARPET_WHITE)
	suite.check(game.world.node_at(carpet) == VillageContent.CARPET_WHITE,"a fresh carpet is placed and supported")
	game.world.set_node(carpet+Vector3i.DOWN,Nodes.AIR)
	suite.check(game.world.node_at(carpet) == Nodes.AIR,"and stripping its support through the world's own edit drops it")

	# --- what does *not* drop -------------------------------------------------
	# The subtlety that matters: the test is the drawtype, not solidity. A carpet on
	# a non-solid-but-drawn node is supported and must stay.
	for kind in [Nodes.WATER,Nodes.TORCH,Nodes.GLASS,Nodes.SNOW]:
		for drop in game.drops.get_children():
			if drop is ItemDrop and not drop.is_queued_for_deletion(): drop.queue_free()
		game.world.set_node(base+Vector3i.DOWN,kind)
		game.world.set_node(carpet,VillageContent.CARPET_WHITE)
		suite.check(game.world.node_at(carpet) == VillageContent.CARPET_WHITE,"a carpet is supported by a drawn node below it, not only a solid one")
	# An unloaded support must not drop a saved carpet.
	game.world.set_node(base+Vector3i.DOWN,Nodes.STONE)
	game.world.set_node(carpet,VillageContent.CARPET_WHITE)
	suite.check(SupportedNodes.supported(game.world,carpet),"the loaded case is supported")
	# --- the one above --------------------------------------------------------
	# Removing a block is checked on this cell and the one above, since the cell above
	# is what may have lost its support by this edit.
	var above := carpet+Vector3i.UP
	for x in range(-1,2):
		for z in range(-1,2):
			for y in range(above.y,above.y+2): game.world.set_node(Vector3i(above.x+x,y,above.z+z),Nodes.AIR)
	game.world.set_node(carpet,Nodes.STONE)
	game.world.set_node(above,VillageContent.CARPET_WHITE)
	game.world.set_node(carpet,Nodes.AIR)
	suite.check(game.world.node_at(above) == Nodes.AIR,"the carpet directly above a removed block drops too, since the check covers that cell")

	# --- cleanup --------------------------------------------------------------
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion(): drop.queue_free()
	for x in range(-3,4):
		for z in range(-3,4):
			for y in range(base.y-2,base.y+5): game.world.set_node(Vector3i(base.x+x,y,base.z+z),Nodes.AIR)
	game.inventory.restore([])

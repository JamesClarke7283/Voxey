class_name SupportedNodes
extends RefCounted

# Mineclonia `CORE/mcl_attached/init.lua`:92-98 — the `supported_node` group.
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference.
#
# The source's `core.check_single_for_falling` override:
#
#     if core.get_item_group(node.name, "supported_node") ~= 0 then
#         local supporting_node = core.get_node(vector.offset(pos, 0, -1, 0))
#         local def = core.registered_nodes[supporting_node.name]
#         if def and def.drawtype == "airlike" then
#             mcl_attached.drop_attached_node(pos)
#
# Two things matter and both are easy to get wrong:
#
#  * The test is on the **node below**, and on its `drawtype` being `airlike`. In
#    Luanti `airlike` is a *rendering* property shared by exactly the nodes that draw
#    nothing: air itself, the invisible realm barrier, the mapmaker's light blocks,
#    the void node, and the `top` half of a double plant. It is **not** "not solid" —
#    a carpet, a flower, a lily pad, a torch and a snow layer all draw something, so
#    a carpet resting on any of them is supported and stays. The group's own comment
#    says the same: "Nodes in group `supported_node` can be placed on any node that
#    does not have the `airlike` drawtype."
#  * An unloaded support must not drop a saved node, so the load check comes first.
#
# A dropped node is `mcl_attached.drop_attached_node`: the node is removed and its
# own drops are scattered within a quarter block of the cell.
#
# Voxey already drops flowers, tall grass and signs when their support goes; the
# carpet family was the gap, and a carpet left hanging was reachable in ordinary play
# — removing the block beneath one left it floating. `VillageContent.shape(id) ==
# "carpet"` is the group's members: `mcl_wool/init.lua`:60 (every coloured carpet),
# `mcl_pale_oak/plants.lua`:233 (pale moss carpet), `mcl_lush_caves/nodes.lua`:96
# (moss carpet) and `mcl_core`'s lily pad, which is registered with the `carpet`
# shape.

# The `airlike` nodes Voxey has: `Nodes.AIR` is the only one registered. The
# source's other airlike nodes — the realm barrier, the light blocks and the void —
# are not in Voxey, so there is nothing else to name here, and a saved cell whose
# support is genuinely empty is `AIR`.
static func airlike(id: int) -> bool:
	return id == Nodes.AIR

static func is_supported(id: int) -> bool:
	return VillageContent.shape(id) == "carpet"

# The source's support test: the node below is not airlike.
static func supported(world: VoxelWorld, p: Vector3i) -> bool:
	var below: Vector3i = p+Vector3i.DOWN
	if not world.loaded_at(Vector3(below)): return true
	return not airlike(world.node_at(below))

# `drop_attached_node`: remove the node and scatter its drops, which the source
# offsets by up to a quarter block in each direction. Returns whether it dropped.
static func drop(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if not is_supported(id) or not world.set_node(p,Nodes.AIR): return false
	var game: Node = world.get_parent()
	if game != null and game.has_method("spawn_drop"):
		game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,id)
	return true

# The per-cell validation `VoxelWorld` calls on every edit, beside the other
# modules' `changed`. It checks this cell and the one above, since removing a block
# is exactly what strips the support from a carpet that was resting on it.
static func changed(world: VoxelWorld, p: Vector3i) -> void:
	if PistonPush.defer_support(world,p): return
	for at in [p,p+Vector3i.UP]:
		if not supported(world,at): drop(world,at)

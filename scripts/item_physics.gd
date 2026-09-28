class_name ItemPhysics
extends RefCounted

# Mineclonia ENTITIES/mcl_item_entity/init.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# The source's dropped-item entity does four things Voxey's `ItemDrop` did not:
#
#   * **Stack merging** (`merge_with`, :596-651). An item resting on a floor
#     merges any identical, identically-worn, non-full item within 0.8 into one
#     stack, moving itself to the midpoint and resetting its own age so the
#     combined stack gets a fresh lifetime.
#   * **Cactus destruction** (:748-757). A collision with a cactus removes the
#     item outright.
#   * **Water behaviour** (:715-732, :863-885). An item that comes to rest with
#     liquid in its own cell and air above *floats*; otherwise liquid in its cell
#     pushes it along the flow (`flowlib.quick_flow`, scaled by 1.2) with a small
#     downward acceleration.
#   * **Push out of solid nodes** (:758-830). An item inside a walkable opaque
#     node is ejected through the nearest free horizontal side, or upward when
#     none of the four is free.
#
# The source's offhand-first pickup (`core.item_pickup`, :289-305) is the fifth
# rule and lives in `pickup_target` here.

# `core.objects_inside_radius(p, 0.8)` — the merge radius.
const MERGE_RADIUS = 0.8
# `flowlib`'s flowing speed: the source's `local f = 1.2`.
const FLOW_SPEED = 1.2
# The push-out launches at `vector.multiply(shootdir, 3)`.
const PUSH_SPEED = 3.0
# `item_drop_settings.magnet_time` bounds how long an item keeps chasing a
# collector before its magnet is declared dead.
const MAGNET_TIME = 1.5

# --- merging ------------------------------------------------------------------

# `merge_with`: same item, same metadata, same wear and room for the total.
static func mergeable(one: ItemDrop, other: ItemDrop) -> bool:
	if one == other or one.is_queued_for_deletion() or other.is_queued_for_deletion(): return false
	if one.item_id != other.item_id or one.wear != other.wear: return false
	if one.data != other.data: return false
	var total: int = one.amount+other.amount
	return total <= Nodes.max_stack(one.item_id)

# The merge body: the survivor moves to the midpoint, resets its age and absorbs
# the other's count; the other is removed. Returns whether a merge happened.
static func merge(one: ItemDrop, other: ItemDrop) -> bool:
	if not mergeable(one,other): return false
	var first: Vector3 = one.position
	var second: Vector3 = other.position
	var midpoint: Vector3 = second+(first-second)/2.0
	midpoint.y = maxf(first.y,second.y)+0.1
	one.position = midpoint
	one.age = 0.0
	one.amount += other.amount
	other.queue_free()
	return true

# The resting-cell scan: `objects_inside_radius` over a radius of 0.8 for a
# mergeable peer. `drops` is the parent node every `ItemDrop` lives under.
static func try_merge(drop: ItemDrop) -> bool:
	for other in drop.game.drops.get_children():
		if not other is ItemDrop: continue
		if drop.position.distance_to(other.position) > MERGE_RADIUS: continue
		if merge(drop,other): return true
	return false

# --- environment --------------------------------------------------------------

# A cactus in the item's own cell destroys it, as the source's collision check
# does. Returns whether the item must be removed.
static func cactus(world: VoxelWorld, at: Vector3) -> bool:
	return world.loaded_at(at) and world.node_at(Vector3i(at.floor())) == Nodes.CACTUS

# The source's float test: liquid in the item's cell and no liquid in the cell
# 0.1 above it, with the item more or less stationary. The source reads those
# cells with `get_node`, which *rounds*, so an item resting at the centre of its
# cell samples the cell above; Voxey uses the item's own floor cell and its
# neighbour above, which is the same pair of cells without depending on whether
# the resting offset happens to round up or down.
static func floats(world: VoxelWorld, at: Vector3, velocity: Vector3) -> bool:
	var cell := Vector3i(at.floor())
	if not Fluids.liquid(world.node_at(cell)): return false
	if Fluids.liquid(world.node_at(cell+Vector3i.UP)): return false
	return absf(velocity.x) < 0.3 and absf(velocity.y) < 0.3 and absf(velocity.z) < 0.3

# The flow direction at a cell, which stands in for `flowlib.quick_flow`: the
# neighbour with the lowest liquid level that is not higher than this one.
static func flow_direction(world: VoxelWorld, p: Vector3i) -> Vector3:
	var here: int = Fluids.level(world.node_at(p))
	var best: Vector3i = Vector3i.ZERO
	var best_level: int = here
	for side in Fluids.HORIZONTAL:
		var at: Vector3i = p+side
		var id: int = world.node_at(at)
		if not Fluids.water(id): continue
		var level: int = Fluids.level(id)
		if level > here or level <= best_level and not best == Vector3i.ZERO: continue
		if level == 1 and here == 0: continue
		best = side; best_level = level
	if best == Vector3i.ZERO and world.fluids.can_fall(p,Nodes.WATER): return Vector3.DOWN
	return Vector3(best)

# The push-out side order: `cxcz` puts the closest axis first, then the other
# direction on that axis, then the two sides of the other axis. The first free
# (non-walkable) side wins, and with none free the item shoots upward.
#
# The source's `cxcz` is transcribed exactly, including its own ordering rule: for
# a coordinate below the cell centre it offers the **positive** side first
# (`mcl_item_entity/init.lua`:784-795).
static func push_direction(world: VoxelWorld, at: Vector3) -> Vector3i:
	var local: Vector3 = at-Vector3(at.floor())
	var cx: float = local.x-0.5
	var cz: float = local.z-0.5
	var order: Array = []
	if absf(cx) < absf(cz):
		order.append_array(_cxcz(cx,0)); order.append_array(_cxcz(cz,2))
	else:
		order.append_array(_cxcz(cz,2)); order.append_array(_cxcz(cx,0))
	var cell := Vector3i(at.floor())
	for side in order:
		if not world.loaded_at(Vector3(cell+side)): continue
		if not Nodes.solid(world.node_at(cell+side)): return side
	return Vector3i.UP

# `cxcz`: the two sides of one axis in the source's order.
static func _cxcz(value: float, axis: int) -> Array:
	var first := Vector3i.ZERO; var second := Vector3i.ZERO
	first[axis] = 1 if value < 0 else -1
	second[axis] = -first[axis]
	return [first,second]

# Whether the item is inside a solid opaque node and must be ejected.
static func stuck(world: VoxelWorld, at: Vector3) -> bool:
	var cell := Vector3i(at.floor())
	if not world.loaded_at(at): return false
	return RedstoneSensors.light_filter(world.node_at(cell)) < 0 and Nodes.solid(world.node_at(cell))

# The whole environment step for one item: cactus destruction first, then the
# float/flow/push resolution. Returns true when the item was removed.
static func step(drop: ItemDrop, delta: float) -> bool:
	var world: VoxelWorld = drop.game.world
	if cactus(world,drop.position):
		drop.queue_free(); return true
	if floats(world,drop.position,drop.velocity):
		drop.velocity = Vector3.ZERO
		return false
	if Fluids.water(world.node_at(Vector3i(drop.position.floor()))):
		var flow: Vector3 = flow_direction(world,Vector3i(drop.position.floor()))
		if flow != Vector3.ZERO:
			drop.velocity.x = flow.x*FLOW_SPEED
			drop.velocity.z = flow.z*FLOW_SPEED
			drop.velocity.y = -0.22
			return false
	if stuck(world,drop.position):
		drop.velocity = Vector3(push_direction(world,drop.position))*PUSH_SPEED
	return false

# --- pickup -------------------------------------------------------------------

# How many of this drop the offhand can still take, so a full backpack does not
# block a pickup the second hand could accept.
static func offhand_room(game: Node3D, drop: ItemDrop) -> int:
	var hand: Dictionary = game.player.offhand_slot
	var stack_max: int = Nodes.max_stack(drop.item_id)
	if int(hand.get("id",0)) == 0: return stack_max
	if int(hand.id) != drop.item_id or int(hand.get("wear",0)) != drop.wear: return 0
	if hand.get("data",{}) != drop.data: return 0
	return maxi(0,stack_max-int(hand.count))

# The source fills the **offhand** first (`core.item_pickup`, :289-305), which is
# why a torch picked up while a shield is held lands in the second hand. Returns
# the count that did not fit in the offhand, for the main inventory to take.
static func fill_offhand(game: Node3D, drop: ItemDrop) -> int:
	var hand: Dictionary = game.player.offhand_slot
	if int(hand.get("id",0)) != 0:
		# A non-empty offhand accepts only a stack of the identical item that has
		# room, which is `inv:add_item`'s own merge rule.
		if int(hand.id) != drop.item_id or int(hand.get("wear",0)) != drop.wear: return drop.amount
		if hand.get("data",{}) != drop.data: return drop.amount
		var room: int = maxi(0,Nodes.max_stack(drop.item_id)-int(hand.count))
		if room <= 0: return drop.amount
		var moved: int = mini(room,drop.amount)
		hand.count = int(hand.count)+moved
		return drop.amount-moved
	hand.clear()
	hand["id"] = drop.item_id
	hand["count"] = mini(Nodes.max_stack(drop.item_id),drop.amount)
	hand["wear"] = drop.wear
	Inventory.copy_data(hand,{"id":drop.item_id,"data":drop.data})
	game.inventory.changed.emit()
	return drop.amount-int(hand.count)

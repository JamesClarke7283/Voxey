class_name Torches
extends RefCounted

# Direction names describe the supporting wall. IDs preserve the attachment in
# save files and worker mesh snapshots, even when there are several walls nearby.
const WALLS = [1119,1120,1121,1122]
const SUPPORTS = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
static func is_torch(id: int) -> bool: return id == Nodes.TORCH or id in WALLS
static func support(id: int) -> Vector3i:
	return SUPPORTS[WALLS.find(id)] if id in WALLS else Vector3i.DOWN
static func placed(normal: Vector3i) -> int:
	if normal == Vector3i.UP: return Nodes.TORCH
	var index: int = SUPPORTS.find(-normal)
	return WALLS[index] if index >= 0 else 0
static func flame_position(p: Vector3i, id: int) -> Vector3:
	return Vector3(p)+Vector3(0.5,0.82,0.5)+(Vector3(support(id))*0.1 if id in WALLS else Vector3.ZERO)

static func support_changed(world: VoxelWorld, p: Vector3i) -> void:
	var current: int = world.node_at(p)
	if not BuildingShapes.is_shape(current) and Nodes.solid(current): return
	for side in VoxelWorld.SIDES:
		var q: Vector3i = p+side
		var id: int = world.node_at(q)
		if not is_torch(id) or q+support(id) != p or BuildingShapes.supports(world,p,-support(id)): continue
		world.set_node(q,Nodes.AIR)
		var game: Node = world.get_parent()
		if game != null and game.has_method("spawn_drop"):
			game.spawn_drop(Vector3(q)+Vector3.ONE*0.5,Nodes.TORCH,1)

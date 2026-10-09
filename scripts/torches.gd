class_name Torches
extends RefCounted

# Direction names describe the supporting wall. IDs preserve the attachment in
# save files and worker mesh snapshots, even when there are several walls nearby.
const WALLS = [1119,1120,1121,1122]
# `mcl_copper/nodes.lua`:288-303 registers a **copper torch** through the same
# `mcl_torches.register_torch` the default torch uses (light 14, floor + wall).
# Voxey's default floor torch is `Nodes.TORCH`; the copper family gets its own floor
# id and four wall ids beside it, and its flame tile is authored in GIMP.
const COPPER = 1297
const COPPER_WALLS = [1298,1299,1302,1303]
# The copper torch's flame tile in the atlas, drawn in GIMP
# (`assets/textures/tiles/tile_copper_torch.png` -> `Art` tile 1303). It is
# registered in `VillageContent.BLOCKS`, so its index is
# `137 + find(VillageContent.COPPER_TORCH_TILE)`.
const COPPER_TILE_MARKER = 1303
static func copper_tile() -> int: return 137+VillageContent.BLOCKS.find(COPPER)
const SUPPORTS = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]

static func is_copper(id: int) -> bool: return id == COPPER or id in COPPER_WALLS
static func is_torch(id: int) -> bool: return id == Nodes.TORCH or id in WALLS or is_copper(id)
static func base(id: int) -> int: return COPPER if is_copper(id) else Nodes.TORCH
static func wall_set(id: int) -> Array: return COPPER_WALLS if is_copper(id) else WALLS
static func support(id: int) -> Vector3i:
	var walls: Array = wall_set(id)
	return SUPPORTS[walls.find(id)] if id in walls else Vector3i.DOWN
# The item an in-world torch represents; a copper torch drops and matches copper.
static func item(id: int) -> int: return COPPER if is_copper(id) else Nodes.TORCH
static func placed(normal: Vector3i) -> int: return placed_for(Nodes.TORCH,normal)
# Family-aware placement: pass the held item so a copper torch places copper.
static func placed_for(held: int, normal: Vector3i) -> int:
	var family: int = COPPER if held == COPPER else Nodes.TORCH
	if normal == Vector3i.UP: return family
	var index: int = SUPPORTS.find(-normal)
	if index < 0: return 0
	return (COPPER_WALLS if family == COPPER else WALLS)[index]
static func flame_position(p: Vector3i, id: int) -> Vector3:
	var walls: Array = wall_set(id)
	return Vector3(p)+Vector3(0.5,0.82,0.5)+(Vector3(support(id))*0.1 if id in walls else Vector3.ZERO)

static func support_changed(world: VoxelWorld, p: Vector3i) -> void:
	if PistonPush.defer_support(world,p): return
	var current: int = world.node_at(p)
	if not BuildingShapes.is_shape(current) and Nodes.solid(current): return
	for side in VoxelWorld.SIDES:
		var q: Vector3i = p+side
		var id: int = world.node_at(q)
		if not is_torch(id) or q+support(id) != p or BuildingShapes.supports(world,p,-support(id)): continue
		world.set_node(q,Nodes.AIR)
		var game: Node = world.get_parent()
		if game != null and game.has_method("spawn_drop"):
			game.spawn_drop(Vector3(q)+Vector3.ONE*0.5,item(id),1)

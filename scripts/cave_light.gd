class_name CaveLight
extends RefCounted

# Surface cover is handled by ordinary sun shadows. Fade the cave environment
# only well below the terrain, and preserve daylight near real outdoor openings.
static func shelter(world: VoxelWorld, feet: Vector3) -> float:
	var p := Vector3i(feet.floor())
	var depth: float = world.generator.terrain_height(p.x,p.z)-feet.y
	if depth <= 8 or world.open_sky(p): return 0
	var amount: float = clampf((depth-8.0)/12.0,0,1)
	for direction in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK,Vector3i(-1,0,-1),Vector3i(-1,0,1),Vector3i(1,0,-1),Vector3i(1,0,1)]:
		for step in 8:
			var q: Vector3i = p+direction*(step+1)
			if not world.loaded_at(Vector3(q)) or Nodes.solid(world.node_at(q+Vector3i.UP)): break
			if world.open_sky(q):
				amount = minf(amount,clampf((Vector2(direction.x,direction.z).length()*(step+1)-2.0)/10.0,0,1))
				break
	return amount

class_name VillagePois
extends RefCounted

static func section(pos: Vector3i) -> Vector3i:
	return Vector3i(floori(pos.x/16.0),floori(pos.y/16.0),floori(pos.z/16.0))
static func heat_from_sections(pos: Vector3i, centers: Array) -> int:
	var target: Vector3i = section(pos); var heat: int = 0
	for source in centers:
		var d: Vector3i = target-Vector3i(source)
		heat = maxi(heat,6-maxi(absi(d.x),maxi(absi(d.y),absi(d.z))))
	return maxi(0,heat)

static func points(game: Node3D) -> Array:
	var result: Array = []; var seen: Dictionary = {}; var world: VoxelWorld = game.world
	for person in game.villages.state().people.values():
		if person.get("dead",false) or person.get("profession","") == "golem": continue
		for key in ["bed","job"]:
			if not person.get(key) is Array: continue
			var at := Vector3i(VillageLife.vec(person[key])); var id: int = world.node_at(at)
			var index: int = VillageContent.PROFESSIONS.find(str(person.get("profession","")))
			var job: bool = index >= 0 and GrindstoneRepair.base(Stonecutting.base(id)) == VillageContent.JOBS[index]
			var allowed: bool = not world.loaded_at(Vector3(at)) or (VillageContent.is_bed(id) if key == "bed" else job)
			if allowed and not seen.has(at): seen[at] = true; result.append(at)
	for point in game.world.adventure_state.get("village_bells",[]):
		var at := Vector3i(VillageLife.vec(point))
		if (not world.loaded_at(Vector3(at)) or world.node_at(at) == VillageContent.BELL) and not seen.has(at): seen[at] = true; result.append(at)
	return result
static func heat(game: Node3D, pos: Vector3i) -> int:
	var centers: Array = []
	for point in points(game):
		var cell: Vector3i = section(point)
		if cell not in centers: centers.append(cell)
	return heat_from_sections(pos,centers)
static func nearest(pos: Vector3i, points_list: Array, visited: Array, radius: float = 10) -> Variant:
	var best: Variant = null; var distance: float = radius*radius
	for point in points_list:
		if point in visited: continue
		var gap: float = Vector3(pos).distance_squared_to(Vector3(point))
		if gap <= radius*radius and (best == null or gap < distance): best = point; distance = gap
	return best
static func claim_bell(game: Node3D, at: Vector3i) -> void:
	var nearby: bool = false
	for person in game.villages.state().people.values():
		if not person.get("dead",false) and Vector3(at).distance_to(VillageLife.vec(person.position)) <= 32: nearby = true; break
	if not nearby: return
	var bells: Array = game.world.adventure_state.get("village_bells",[])
	var value: Array = [at.x,at.y,at.z]
	if value not in bells: bells.append(value)
	game.world.adventure_state.village_bells = bells

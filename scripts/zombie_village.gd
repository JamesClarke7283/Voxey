class_name ZombieVillage
extends RefCounted

static func pick(origin: Vector3i, samples: Array, centers: Array, points: Array, visited: Array) -> Variant:
	var heated: bool = false
	for offset in samples:
		if VillagePois.heat_from_sections(origin+Vector3i(offset),centers) >= 1: heated = true
	return VillagePois.nearest(origin,points,visited) if heated else null

static func passable(mob: Creature, cell: Vector3i) -> bool:
	var world: VoxelWorld = mob.game.world; var pos := Vector3(cell)+Vector3(0.5,0,0.5)
	if not world.intersects(pos,mob.width,mob.height): return true
	if mob.game.difficulty != 2 or not mob.zombie_traits.get("break_doors",false): return false
	var body := AABB(pos-Vector3(mob.width,-0.002,mob.width),Vector3(mob.width*2,mob.height-0.004,mob.width*2))
	var low := Vector3i(body.position.floor()); var high := Vector3i(body.end.floor())
	for y in range(low.y-1,high.y+1):
		for z in range(low.z,high.z+1):
			for x in range(low.x,high.x+1):
				var at := Vector3i(x,y,z); var id: int = world.node_at(at)
				if not Nodes.solid(id) or Doors.wooden(id) and not Doors.opened(id): continue
				for box in world.collision_boxes(at):
					if body.intersects(AABB(Vector3(at)+box.position,box.size)): return false
	return true

static func path(mob: Creature, goal: Vector3i) -> Array:
	var world: VoxelWorld = mob.game.world; var start := Vector3i(mob.position.floor())
	var queue: Array = [start]; var parents: Dictionary = {start:start}; var best: Vector3i = start
	var distance: float = Vector3(start).distance_squared_to(Vector3(goal)); var cursor: int = 0
	while cursor < queue.size() and cursor < 600:
		var point: Vector3i = queue[cursor]; cursor += 1
		var gap: float = Vector3(point).distance_squared_to(Vector3(goal))
		if gap < distance: best = point; distance = gap
		if gap <= 1: break
		for side in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
			for height in [0,1,-1]:
				var next: Vector3i = point+side+Vector3i.UP*height
				if parents.has(next) or Vector3(start).distance_to(Vector3(next)) > 24 or not world.loaded_at(Vector3(next)): continue
				if not Nodes.solid(world.node_at(next+Vector3i.DOWN)): continue
				if not passable(mob,next): continue
				parents[next] = point; queue.append(next); break
	var route: Array = []
	while best != start: route.push_front(Vector3(best)+Vector3(0.5,0,0.5)); best = parents[best]
	return route

static func step(mob: Creature, delta: float, combat: bool) -> Vector3:
	if mob.kind not in ["zombie","husk","zombie_villager"] or combat: return Vector3.INF
	var state: Dictionary = mob.zombie_village
	if state.is_empty(): state.merge({"visited":[],"timer":0.0,"route":[],"active":false})
	if state.active:
		if mob.position.distance_to(Vector3(state.goal)+Vector3(0.5,0,0.5)) <= 1 or state.route.is_empty():
			state.visited.append(state.goal); state.active = false; return Vector3.INF
		if ZombieDoors.breaking(mob):
			state.stalled = 0.0; state.best = INF
			return ((Vector3(state.route[0])-mob.position)*Vector3(1,0,1)).normalized()
		var remaining: float = mob.position.distance_to(state.route[0])
		if remaining < 0.35:
			state.route.pop_front(); state.stalled = 0.0; state.best = INF
		elif remaining < state.get("best",INF)-0.05:
			state.best = remaining; state.stalled = 0.0
		else: state.stalled = state.get("stalled",0.0)+delta
		if state.get("stalled",0.0) > 1:
			if state.get("retried",false): state.route.clear()
			else: state.route = path(mob,state.goal); state.retried = true
			state.stalled = 0.0; state.best = INF
		if state.route.is_empty(): return Vector3.ZERO
		return ((Vector3(state.route[0])-mob.position)*Vector3(1,0,1)).normalized()
	state.timer -= delta
	if state.timer > 0: return Vector3.INF
	state.timer = 1.0
	if mob.game.dimension == "overworld" and mob.game.daylight >= 0.5: return Vector3.INF
	var origin := Vector3i(mob.position.floor()); var points: Array = VillagePois.points(mob.game); var centers: Array = []
	for point in points:
		var cell: Vector3i = VillagePois.section(point)
		if cell not in centers: centers.append(cell)
	if VillagePois.heat_from_sections(origin,centers) < 3: return Vector3.INF
	var rng: EnchantRolls = ZombieTraits.rng_for(mob.game.world); var samples: Array = []
	for i in 10: samples.append(Vector3i(rng.integer(-15,15),rng.integer(-7,7),rng.integer(-15,15)))
	var goal: Variant = pick(origin,samples,centers,points,state.visited)
	if goal == null: return Vector3.INF
	state.goal = goal; state.route = path(mob,goal); state.active = true; state.best = INF; state.stalled = 0.0; state.retried = false
	return Vector3.ZERO

class_name ArrowFlight
extends RefCounted

const FLIGHT_LIFETIME = 120.0
const STUCK_LIFETIME = 60.0
const ATTACHED_LIFETIME = 30.0
const RECHECK = 0.25
const PICKUP_RANGE = 2.0
const DRAG_TICK = 0.05
const DRAG_RATE = 0.99
const LIQUID_RATE = 0.74

static func drag(velocity: Vector3, lifetime: float, clock: float) -> Dictionary:
	while lifetime >= clock+DRAG_TICK:
		velocity *= DRAG_RATE
		clock += DRAG_TICK
	return {"velocity":velocity,"clock":clock}

static func box_hit(origin: Vector3, motion: Vector3, box: AABB) -> Dictionary:
	var enter: float = 0; var leave: float = 1
	var normal := Vector3i.ZERO
	for axis in 3:
		if absf(motion[axis]) < 0.0000001:
			if origin[axis] < box.position[axis] or origin[axis] > box.end[axis]: return {}
			continue
		var a: float = (box.position[axis]-origin[axis])/motion[axis]
		var b: float = (box.end[axis]-origin[axis])/motion[axis]
		if minf(a,b) > enter:
			enter = minf(a,b); normal = Vector3i.ZERO; normal[axis] = -1 if motion[axis] > 0 else 1
		leave = minf(leave,maxf(a,b))
		if enter > leave: return {}
	return {"t":enter,"point":origin+motion*enter,"normal":normal}

static func cells(origin: Vector3, end: Vector3) -> Array:
	var result: Array = []
	var motion: Vector3 = end-origin
	var cell := Vector3i(origin.floor()); var last := Vector3i(end.floor())
	var step_dir := Vector3i(signi(int(signf(motion.x))),signi(int(signf(motion.y))),signi(int(signf(motion.z))))
	var delta := Vector3(INF,INF,INF); var next := Vector3(INF,INF,INF)
	for axis in 3:
		if absf(motion[axis]) < 0.0000001: continue
		delta[axis] = absf(1/motion[axis])
		next[axis] = (cell[axis]+(1 if step_dir[axis] > 0 else 0)-origin[axis])/motion[axis]
	for i in 1024:
		result.append(cell)
		if cell == last: break
		var axis: int = 0 if next.x < next.y else 1
		if next.z < next[axis]: axis = 2
		if next[axis] > 1: break
		cell[axis] += step_dir[axis]; next[axis] += delta[axis]
	return result

static func nodes(world: VoxelWorld, origin: Vector3, end: Vector3) -> Array:
	var result: Array = []; var checked: Dictionary = {}
	var motion: Vector3 = end-origin
	for cell in cells(origin,end):
		# Thin faces and fences extending into the next cell need a swept volume.
		for x in range(-1,2):
			for y in range(-1,2):
				for z in range(-1,2):
					var p: Vector3i = cell+Vector3i(x,y,z)
					if checked.has(p): continue
					checked[p] = true
					var id: int = world.node_at(p)
					var solid: bool = Nodes.solid(id) or Candles.is_candle(id)
					if not solid and not Fluids.liquid(id) and not Fire.is_fire(id): continue
					var boxes: Array = world.collision_boxes(p) if solid else [AABB(Vector3.ZERO,Vector3(1,Fluids.height(id) if Fluids.liquid(id) else 1.0,1))]
					var closest: Dictionary = {}
					for local_box in boxes:
						var box := AABB(Vector3(p)+local_box.position,local_box.size)
						if solid: box = box.grow(0.01)
						var hit: Dictionary = box_hit(origin,motion,box)
						if not hit.is_empty() and (closest.is_empty() or hit.t < closest.t): closest = hit
					if not closest.is_empty():
						closest.merge({"kind":"node","pos":p,"id":id,"solid":solid}); result.append(closest)
	result.sort_custom(func(a,b): return a.t < b.t)
	return result

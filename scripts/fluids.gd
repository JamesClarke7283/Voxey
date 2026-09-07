class_name Fluids
extends RefCounted

# Source nodes retain their saved IDs. Hidden IDs store flow distance/falling
# state directly, so saving and worker snapshots preserve the fluid geometry.
const WATER_FLOW = 3000
const LAVA_FLOW = 3020
const SIDES = [Vector3i.DOWN,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK,Vector3i.UP]
const HORIZONTAL = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
var world: VoxelWorld
var elapsed: float = 0
var queues: Array = [[],[]]
var pending: Array = [{},{}]
var heads: Array = [0,0]

func _init(owner_world: VoxelWorld) -> void: world = owner_world
static func flowing(id: int) -> bool: return id in range(WATER_FLOW,WATER_FLOW+8) or id in range(LAVA_FLOW,LAVA_FLOW+8)
static func water(id: int) -> bool: return id == Nodes.WATER or id >= WATER_FLOW and id < WATER_FLOW+8
static func lava(id: int) -> bool: return id == Nodes.LAVA or id >= LAVA_FLOW and id < LAVA_FLOW+8
static func liquid(id: int) -> bool: return water(id) or lava(id)
static func source(id: int) -> bool: return id in [Nodes.WATER,Nodes.LAVA]
static func base(id: int) -> int: return Nodes.WATER if water(id) else (Nodes.LAVA if lava(id) else 0)
static func falling(id: int) -> bool: return id in [WATER_FLOW+7,LAVA_FLOW+7]
static func level(id: int) -> int: return 0 if source(id) or falling(id) else (id-(WATER_FLOW if water(id) else LAVA_FLOW)+1)
static func flow_id(kind: int, distance: int, fall: bool = false) -> int: return (WATER_FLOW if kind == Nodes.WATER else LAVA_FLOW)+(7 if fall else distance-1)
static func height(id: int) -> float: return 1.0 if source(id) or falling(id) else (8.0-level(id))/8.0
static func replaceable(id: int) -> bool:
	return id == Nodes.AIR or Nodes.plant(id) or Torches.is_torch(id) or id in Nodes.SMALL_CIRCUITS and id != Nodes.IRON_DOOR_OPEN

func schedule(p: Vector3i, kind: int) -> void:
	if kind == 0 or p.y <= world.generator.min_y() or p.y >= world.generator.max_y() or not world.loaded_at(Vector3(p)): return
	var index: int = 0 if kind == Nodes.WATER else 1
	if pending[index].has(p): return
	pending[index][p] = true
	queues[index].append([p,elapsed+(0.2 if index == 0 else 1.0)])

func changed(p: Vector3i, old_id: int, new_id: int) -> void:
	var kinds: Array = []
	for id in [old_id,new_id]:
		if liquid(id) and not kinds.has(base(id)): kinds.append(base(id))
	for side in SIDES:
		var neighbor: int = world.node_at(p+side)
		if liquid(neighbor) and not kinds.has(base(neighbor)): kinds.append(base(neighbor))
	for kind in kinds:
		schedule(p,kind)
		for side in SIDES: schedule(p+side,kind)

func activate(p: Vector3i) -> void:
	var id: int = world.node_at(p)
	if liquid(id): changed(p,id,id)

func update(delta: float) -> void:
	elapsed += delta
	var start: int = Time.get_ticks_usec()
	var count: int = 0
	for index in 2:
		while heads[index] < queues[index].size():
			var entry: Array = queues[index][heads[index]]
			if float(entry[1]) > elapsed: break
			heads[index] += 1; pending[index].erase(entry[0])
			if world.loaded_at(Vector3(entry[0])): settle(entry[0],Nodes.WATER if index == 0 else Nodes.LAVA)
			count += 1
			if count >= 96 or Time.get_ticks_usec()-start >= 2500: break
		if heads[index] > 1024 or heads[index] == queues[index].size():
			queues[index] = queues[index].slice(heads[index]); heads[index] = 0
		if count >= 96 or Time.get_ticks_usec()-start >= 2500: break

func can_fall(p: Vector3i, kind: int) -> bool:
	var below: int = world.node_at(p+Vector3i.DOWN)
	return replaceable(below) or flowing(below) and base(below) == kind

func wanted(p: Vector3i, kind: int) -> int:
	var current: int = world.node_at(p)
	if source(current): return current
	if current != Nodes.AIR and base(current) != kind and not replaceable(current): return current
	if world.dimension == "nether" and kind == Nodes.WATER: return Nodes.AIR if water(current) else current
	if base(world.node_at(p+Vector3i.UP)) == kind: return flow_id(kind,0,true)
	var nearest: int = 99; var sources: int = 0
	for side in HORIZONTAL:
		var neighbor: int = world.node_at(p+side)
		if base(neighbor) != kind: continue
		if source(neighbor): sources += 1
		if not can_fall(p+side,kind): nearest = mini(nearest,level(neighbor)+1)
	if kind == Nodes.WATER and sources >= 2 and (Nodes.solid(world.node_at(p+Vector3i.DOWN)) or world.node_at(p+Vector3i.DOWN) == Nodes.WATER): return Nodes.WATER
	var distance: int = 7 if kind == Nodes.WATER or world.dimension == "nether" else 3
	if nearest <= distance: return flow_id(kind,nearest)
	return Nodes.AIR

func settle(p: Vector3i, kind: int) -> void:
	var before: int = world.node_at(p)
	if liquid(before): world.react_fluid(p)
	if world.node_at(p) != before: return
	var after: int = wanted(p,kind)
	if before == after: return
	if replaceable(before) and before != Nodes.AIR and not Fire.is_fire(before):
		var drop: int = Nodes.drop(before)
		if drop != 0: world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,drop,1)
	world.set_node(p,after)

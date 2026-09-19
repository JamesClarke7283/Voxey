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
var next_kind: int = 0
var waiting_columns: Dictionary = {}
var activations: Array[Vector3i] = []
var activation_head: int = 0

func _init(owner_world: VoxelWorld) -> void: world = owner_world
static func flowing(id: int) -> bool: return id >= WATER_FLOW and id < WATER_FLOW+8 or id >= LAVA_FLOW and id < LAVA_FLOW+8
static func water(id: int) -> bool: return id == Nodes.WATER or id >= WATER_FLOW and id < WATER_FLOW+8
static func lava(id: int) -> bool: return id == Nodes.LAVA or id >= LAVA_FLOW and id < LAVA_FLOW+8
static func liquid(id: int) -> bool: return water(id) or lava(id)
static func source(id: int) -> bool: return id in [Nodes.WATER,Nodes.LAVA]
static func base(id: int) -> int: return Nodes.WATER if water(id) else (Nodes.LAVA if lava(id) else 0)
static func falling(id: int) -> bool: return id in [WATER_FLOW+7,LAVA_FLOW+7]
static func level(id: int) -> int: return 0 if source(id) or falling(id) else (id-(WATER_FLOW if water(id) else LAVA_FLOW)+1)
static func flow_id(kind: int, distance: int, fall: bool = false) -> int: return (WATER_FLOW if kind == Nodes.WATER else LAVA_FLOW)+(7 if fall else distance-1)
static func height(id: int) -> float: return 1.0 if source(id) or falling(id) else (8.0-level(id))/8.0
static func contains(owner_world: VoxelWorld, point: Vector3, kind: int) -> bool:
	var p := Vector3i(point.floor())
	var id: int = owner_world.node_at(p)
	# Kelp occupies a waterlogged cell. Swimmers must not lose their stroke or
	# start breathing air when crossing the plant inside a submerged column.
	if kind == Nodes.WATER and id == VillageContent.KELP_PLANT: return true
	return base(id) == kind and (base(owner_world.node_at(p+Vector3i.UP)) == kind or point.y-p.y < height(id))
static func replaceable(id: int) -> bool:
	# Kelp already occupies submerged cells. Treating it as a land plant would
	# uproot whole oceans as soon as their source water activates.
	if id == VillageContent.KELP_PLANT: return false
	if RedstoneInputs.is_plate(id): return false
	return RedstoneInputs.is_button(id) or SnowCover.is_snow(id) or id == Nodes.AIR or Fire.is_fire(id) or Nodes.plant(id) or Torches.is_torch(id) or id in Nodes.SMALL_CIRCUITS and id != Nodes.IRON_DOOR_OPEN

func schedule(p: Vector3i, kind: int) -> void:
	if kind == 0 or not WorldBounds.horizontal(p) or p.y <= world.generator.min_y() or p.y >= world.generator.max_y(): return
	if not world.loaded_at(Vector3(p)):
		wait_for_column(p,p,kind)
		return
	var index: int = 0 if kind == Nodes.WATER else 1
	if pending[index].has(p): return
	pending[index][p] = true
	queues[index].append([p,elapsed+(0.2 if index == 0 else 1.0)])

func wait_for_column(missing: Vector3i, p: Vector3i, kind: int) -> void:
	var column := Vector2i(floori(missing.x/16.0),floori(missing.z/16.0))
	if not waiting_columns.has(column): waiting_columns[column] = {}
	waiting_columns[column][p] = int(waiting_columns[column].get(p,0)) | (1 if kind == Nodes.WATER else 2)

func column_loaded(column: Vector2i) -> void:
	var waiting: Dictionary = waiting_columns.get(column,{})
	waiting_columns.erase(column)
	for p in waiting:
		if waiting[p]&1: schedule(p,Nodes.WATER)
		if waiting[p]&2: schedule(p,Nodes.LAVA)

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
	# Loading a lava cave can expose hundreds of cells. Defer neighbor queries
	# to the same frame budget as simulation instead of stalling column uploads.
	activations.append(p)

func update(delta: float) -> void:
	elapsed += delta
	var start: int = Time.get_ticks_usec()
	var count: int = 0
	while activation_head < activations.size() and Time.get_ticks_usec()-start < 700:
		var p: Vector3i = activations[activation_head]; activation_head += 1
		var id: int = world.node_at(p)
		if liquid(id):
			schedule(p,base(id))
			for side in SIDES: schedule(p+side,base(id))
	if activation_head > 1024 or activation_head == activations.size():
		activations = activations.slice(activation_head); activation_head = 0
	var first: int = next_kind
	next_kind = 1-next_kind
	for turn in 2:
		var index: int = (first+turn)%2
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
	# Pause at unloaded boundaries; resume when the missing source column arrives.
	for side in HORIZONTAL:
		if not world.loaded_at(Vector3(p+side)) and WorldBounds.horizontal(p+side):
			wait_for_column(p+side,p,kind)
			return current
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
	return Nodes.AIR if base(current) == kind else current

func settle(p: Vector3i, kind: int) -> void:
	var before: int = world.node_at(p)
	if liquid(before): world.react_fluid(p)
	if world.node_at(p) != before: return
	var after: int = wanted(p,kind)
	if before == after: return
	if SnowCover.is_snow(before): SnowCover.drop(world,p,before)
	elif CropFarming.is_crop(before):
		if kind == Nodes.WATER:
			for entry in CropFarming.harvest(before): world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
	elif FruitCrops.is_stem(before):
		if kind == Nodes.WATER:
			for entry in FruitCrops.harvest(before): world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
	elif replaceable(before) and before != Nodes.AIR and not Fire.is_fire(before):
		var drop: int = Nodes.drop(before)
		if drop != 0: world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,drop,1)
	world.set_node(p,after)

static func mesh(out: Array, p: Vector3, id: int, data: Variant, cell: Vector3i) -> void:
	var index: int = cell.x+cell.z*18+cell.y*324
	var h: float = 1.0 if base(data[index+324]) == base(id) else height(id)
	for face in 6:
		var normal: Vector3i = BuildingShapes.SIDES[face]
		var offset: int = normal.x+normal.z*18+normal.y*324
		var neighbor: int = data[index+offset]
		var same: bool = base(neighbor) == base(id)
		if normal.y != 0:
			if same or not Nodes.transparent(neighbor): continue
			if source(id): continue # Flat source faces use greedy meshing.
			_face(out,p,Vector3(normal),h,0,id)
			continue
		var low: float = 0
		if same:
			low = 1.0 if base(data[index+offset+324]) == base(id) else height(neighbor)
			if low >= h: continue
		elif not Nodes.transparent(neighbor): continue
		if source(id) and not same: continue
		_face(out,p,Vector3(normal),h,low,id)

static func _face(out: Array, p: Vector3, normal: Vector3, high: float, low: float, id: int) -> void:
	var right: Vector3 = Vector3.FORWARD if normal.x > 0 else (Vector3.BACK if normal.x < 0 else (Vector3.LEFT if normal.z < 0 else Vector3.RIGHT))
	var up: Vector3 = normal.cross(right)
	var center := Vector3(0.5,(high+low)*0.5,0.5)
	var points: Array = []; var uv: Array = []
	for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var point: Vector3 = center+normal*0.5+right*corner.x*0.5+up*corner.y*0.5
		if normal.y == 0: point.y = high if point.y > center.y else low
		else: point.y = high if normal.y > 0 else 0
		points.append(p+point); uv.append(Vector2(corner.x*0.5+0.5,corner.y*0.5+0.5))
	var shade: float = 1.0 if normal.y > 0 else (0.6 if normal.y < 0 else 0.82)
	BlockMesher._quad(out,points,uv,normal,Nodes.tile(base(id),0),Color(shade,shade,shade,0.5 if flowing(id) else 1.0),true)

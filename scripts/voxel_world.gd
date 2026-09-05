class_name VoxelWorld
extends Node3D

signal column_loaded
const SIZE = 16
var seed_value: int = 8675309
var generator: TerrainGenerator
var blocks: Dictionary = {}
var columns: Dictionary = {}
var edits: Dictionary = {}
var stations: Dictionary = {}
var growth: Dictionary = {}
var pending: Dictionary = {}
var jobs: Array = []
var remesh_jobs: Array = []
var dirty: Dictionary = {}
var desired: Vector2i = Vector2i(999999,999999)
var radius: int = 4
var target: Vector3 = Vector3(8,30,8)
var material: ShaderMaterial
var water_material: ShaderMaterial
var tick: float = 0.0
var active: bool = true
var last_mesh_ms: float = 0.0

func configure(seed_number: int, atlas: Texture2D) -> void:
	seed_value = seed_number
	generator = TerrainGenerator.new(seed_value)
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/terrain.gdshader")
	material.set_shader_parameter("atlas",atlas)
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://shaders/water.gdshader")
	water_material.set_shader_parameter("atlas",atlas)

func _process(delta: float) -> void:
	if generator == null: return
	var center := Vector2i(floori(target.x/16.0),floori(target.z/16.0))
	if center != desired:
		desired = center
		for c in columns.keys():
			if maxi(absi(c.x-center.x),absi(c.y-center.y)) > radius + 1: _unload(c)
	var started: int = Time.get_ticks_usec()
	for job in jobs.duplicate():
		if not WorkerThreadPool.is_task_completed(job.task): continue
		WorkerThreadPool.wait_for_task_completion(job.task)
		jobs.erase(job)
		pending.erase(job.coord)
		if maxi(absi(job.coord.x-center.x), absi(job.coord.y-center.y)) <= radius+1:
			_apply_column(job.result)
		if Time.get_ticks_usec() - started > 5000: break
	for job in remesh_jobs.duplicate():
		if not WorkerThreadPool.is_task_completed(job.task): continue
		WorkerThreadPool.wait_for_task_completion(job.task)
		remesh_jobs.erase(job)
		if blocks.has(job.coord): _apply_mesh(job.coord,job.result)
		if Time.get_ticks_usec() - started > 7000: break
	while remesh_jobs.size() < 2 and not dirty.is_empty():
		var coord: Vector3i = dirty.keys()[0]
		dirty.erase(coord)
		if not blocks.has(coord): continue
		var already: bool = false
		for job in remesh_jobs:
			if job.coord == coord: already = true
		if already: dirty[coord] = true; break
		var snapshot: PackedByteArray = _snapshot(coord)
		var job: Dictionary = {"coord":coord, "result":[]}
		job.task = WorkerThreadPool.add_task(func(): job.result = BlockMesher.build(snapshot))
		remesh_jobs.append(job)
	if jobs.size() < 2:
		var nearest := Vector2i(999999,999999)
		var best: int = 999999
		for z in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				var c: Vector2i = center + Vector2i(x,z)
				if columns.has(c) or pending.has(c): continue
				var dist: int = x*x+z*z
				if dist < best: best = dist; nearest = c
		if best < 999999: _queue_column(nearest)
	if active:
		tick += delta
		if tick >= 1.0:
			tick = 0.0
			_simulate()

func _queue_column(coord: Vector2i) -> void:
	var local_edits: Dictionary = {}
	for p in edits:
		if p.x >= coord.x*16-1 and p.x <= coord.x*16+16 and p.z >= coord.y*16-1 and p.z <= coord.y*16+16: local_edits[p] = edits[p]
	var gen := TerrainGenerator.new(seed_value)
	var job: Dictionary = {"coord":coord,"result":{}}
	job.task = WorkerThreadPool.add_task(func(): job.result = gen.generate_column(coord,local_edits),false,"Generate map blocks")
	jobs.append(job)
	pending[coord] = true

func _apply_column(result: Dictionary) -> void:
	var c: Vector2i = result.coord
	columns[c] = true
	for y in 4:
		var coord := Vector3i(c.x,y,c.y)
		var root := Node3D.new()
		root.name = "MapBlock_%d_%d_%d" % [c.x,y,c.y]
		root.position = Vector3(coord * SIZE)
		add_child(root)
		var entry: Dictionary = result.blocks[y]
		blocks[coord] = {"data":entry.data,"root":root,"meshes":[]}
		_apply_mesh(coord,entry.surfaces)
	# Reconcile edits made while the worker was running, including border halos.
	for p in edits:
		if p.x >= c.x*16-1 and p.x <= c.x*16+16 and p.z >= c.y*16-1 and p.z <= c.y*16+16:
			var b: Vector3i = block_coord(p)
			if blocks.has(b):
				blocks[b].data[local_index(p)] = edits[p]
				_mark_dirty(p)
	column_loaded.emit()

func _apply_mesh(coord: Vector3i, surfaces: Array) -> void:
	var entry: Dictionary = blocks[coord]
	for mesh_node in entry.meshes: mesh_node.queue_free()
	entry.meshes.clear()
	for i in 2:
		if surfaces[i].is_empty(): continue
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surfaces[i])
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material if i == 0 else water_material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if i == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		entry.root.add_child(instance)
		entry.meshes.append(instance)
	# Collision uses voxel AABB queries in the player controller. No costly
	# concave physics shape rebuilds are needed when a node changes.

func _unload(c: Vector2i) -> void:
	columns.erase(c)
	for y in 4:
		var b := Vector3i(c.x,y,c.y)
		if blocks.has(b): blocks[b].root.queue_free(); blocks.erase(b)
		dirty.erase(b)

static func block_coord(p: Vector3i) -> Vector3i:
	return Vector3i(floori(p.x/16.0),floori(p.y/16.0),floori(p.z/16.0))

static func local_index(p: Vector3i) -> int:
	return posmod(p.x,16) + posmod(p.z,16)*16 + posmod(p.y,16)*256

func node_at(p: Vector3i) -> int:
	if p.y < 0: return Nodes.BEDROCK
	if p.y >= 64: return Nodes.AIR
	var b: Vector3i = block_coord(p)
	if blocks.has(b): return blocks[b].data[local_index(p)]
	# Treat unloaded terrain as solid for movement; streaming never drops a player.
	return Nodes.BEDROCK

func area_ready(p: Vector3) -> bool:
	var center := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	for z in range(-1,2):
		for x in range(-1,2):
			if not columns.has(center+Vector2i(x,z)): return false
	return true

func loaded_at(p: Vector3) -> bool:
	return columns.has(Vector2i(floori(p.x/16.0),floori(p.z/16.0)))

func set_node(p: Vector3i, id: int) -> bool:
	var b: Vector3i = block_coord(p)
	if p.y <= 0 or p.y >= 64 or not blocks.has(b): return false
	blocks[b].data[local_index(p)] = id
	edits[p] = id
	if id == Nodes.WHEAT or id == Nodes.SAPLING: growth[p] = 0.0
	else: growth.erase(p)
	_mark_dirty(p)
	return true

func _mark_dirty(p: Vector3i) -> void:
	dirty[block_coord(p)] = true
	for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]:
		if block_coord(p+d) != block_coord(p): dirty[block_coord(p+d)] = true

func _snapshot(coord: Vector3i) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(5832)
	for y in 18:
		for z in 18:
			for x in 18:
				var p: Vector3i = coord*16+Vector3i(x-1,y-1,z-1)
				var id: int = node_at(p)
				# Keep the outer streaming wall invisible.
				if p.y > 0 and id == Nodes.BEDROCK and not blocks.has(block_coord(p)): id = Nodes.AIR
				data[x+z*18+y*324] = id
	return data

func intersects(pos: Vector3, half_width: float = 0.29, height: float = 1.8) -> bool:
	var lo := Vector3i(floori(pos.x-half_width),floori(pos.y+0.002),floori(pos.z-half_width))
	var hi := Vector3i(floori(pos.x+half_width),floori(pos.y+height-0.002),floori(pos.z+half_width))
	for y in range(lo.y,hi.y+1):
		for z in range(lo.z,hi.z+1):
			for x in range(lo.x,hi.x+1):
				if Nodes.solid(node_at(Vector3i(x,y,z))): return true
	return false

# Amanatides-Woo voxel traversal: precise targeting without per-node colliders.
func raycast(origin: Vector3, direction: Vector3, reach: float = 5.0) -> Dictionary:
	var cell := Vector3i(origin.floor())
	var step_dir := Vector3i(signi(int(signf(direction.x))),signi(int(signf(direction.y))),signi(int(signf(direction.z))))
	var t_delta := Vector3(INF,INF,INF)
	var t_max := Vector3(INF,INF,INF)
	for axis in 3:
		if absf(direction[axis]) < 0.00001: continue
		t_delta[axis] = absf(1.0 / direction[axis])
		t_max[axis] = ((cell[axis]+(1 if step_dir[axis]>0 else 0))-origin[axis])/direction[axis]
	var normal := Vector3i.ZERO
	var distance: float = 0.0
	for iteration in 128:
		var id: int = node_at(cell)
		if id != Nodes.AIR and id != Nodes.WATER:
			return {"pos":cell,"normal":normal,"id":id,"distance":distance}
		var axis: int = 0 if t_max.x < t_max.y else 1
		if t_max.z < t_max[axis]: axis = 2
		distance = t_max[axis]
		if distance > reach: break
		cell[axis] += step_dir[axis]
		t_max[axis] += t_delta[axis]
		normal = Vector3i.ZERO
		normal[axis] = -step_dir[axis]
	return {}

func _simulate() -> void:
	for p in growth.keys():
		if not loaded_at(Vector3(p)): continue
		growth[p] += 1.0
		var id: int = node_at(p)
		if id == Nodes.WHEAT and growth[p] > 90:
			set_node(p,Nodes.RIPE_WHEAT)
		elif id == Nodes.SAPLING and growth[p] > 120:
			grow_tree(p)
	for key in stations:
		var s: Dictionary = stations[key]
		if s.get("kind","") != "furnace": continue
		var input: Dictionary = s.slots[0]
		var fuel: Dictionary = s.slots[1]
		var output: Dictionary = s.slots[2]
		var recipe: int = {Nodes.IRON_ORE:Nodes.IRON,Nodes.GOLD_ORE:Nodes.GOLD,Nodes.COPPER_ORE:Nodes.COPPER,Nodes.SAND:Nodes.GLASS,Nodes.COBBLE:Nodes.STONE,Nodes.RAW_MEAT:Nodes.COOKED_MEAT,Nodes.LOG:Nodes.COAL,Nodes.CLAY_BALL:Nodes.BRICK_ITEM}.get(input.id,0)
		if s.burn > 0: s.burn -= 1
		if recipe == 0 or (output.id != 0 and output.id != recipe) or output.count >= 64: s.progress = 0.0; continue
		if s.burn <= 0:
			var burn: int = {Nodes.COAL:80,Nodes.LOG:15,Nodes.PLANKS:15,Nodes.STICK:5}.get(fuel.id,0)
			if burn == 0: continue
			s.burn = burn
			fuel.count -= 1
			if fuel.count <= 0: fuel.id = 0
		s.progress += 1.0
		if s.progress >= 8:
			s.progress = 0.0
			input.count -= 1
			if input.count <= 0: input.id = 0
			output.id = recipe
			output.count += 1

func grow_tree(p: Vector3i) -> void:
	for y in range(2,6):
		for x in range(-2,3):
			for z in range(-2,3):
				if abs(x)+abs(z)>3: continue
				var q: Vector3i = p+Vector3i(x,y,z)
				if node_at(q) == Nodes.AIR: set_node(q,Nodes.LEAVES)
	for y in 5: set_node(p+Vector3i(0,y,0),Nodes.LOG)
	growth.erase(p)

const CHEST_SIDES = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]

static func station_key(p: Vector3i) -> String:
	return "%d,%d,%d" % [p.x,p.y,p.z]

static func _new_station(kind: String, count: int) -> Dictionary:
	var slots: Array = []
	for i in count: slots.append({"id":0,"count":0,"wear":0})
	return {"kind":kind,"slots":slots,"burn":0.0,"progress":0.0}

func chest_neighbours(p: Vector3i) -> Array:
	var found: Array = []
	for d in CHEST_SIDES:
		if node_at(p+d) == Nodes.CHEST: found.append(p+d)
	return found

# Two chests form one large chest when each is the other's only chest neighbour.
# Returns the partner position, or p itself for a single chest.
func chest_partner(p: Vector3i) -> Vector3i:
	var mine: Array = chest_neighbours(p)
	if mine.size() != 1: return p
	var other: Vector3i = mine[0]
	if chest_neighbours(other).size() != 1: return p
	return other

# Placement rules keep every pair stable: a chest never touches two chests, and
# never attaches to a chest that already has a partner.
func chest_placement_problem(p: Vector3i) -> String:
	var around: Array = chest_neighbours(p)
	if around.size() > 1: return "A chest can only join one neighbouring chest."
	if around.size() == 1 and not chest_neighbours(around[0]).is_empty(): return "That chest is already part of a large chest."
	return ""

static func chest_primary(a: Vector3i, b: Vector3i) -> Vector3i:
	if a.x != b.x: return a if a.x < b.x else b
	return a if a.z < b.z else b

static func pair_key(a: Vector3i, b: Vector3i) -> String:
	var primary: Vector3i = chest_primary(a,b)
	return station_key(primary)+"+"+station_key(b if primary == a else a)

func get_station(p: Vector3i, kind: String) -> Dictionary:
	if kind == "chest":
		var partner: Vector3i = chest_partner(p)
		if partner != p: return _double_chest(p,partner)
	var key: String = station_key(p)
	if not stations.has(key): stations[key] = _new_station(kind,3 if kind == "furnace" else 27)
	return stations[key]

func _double_chest(a: Vector3i, b: Vector3i) -> Dictionary:
	var key: String = pair_key(a,b)
	if not stations.has(key):
		var primary: Vector3i = chest_primary(a,b)
		var station: Dictionary = _new_station("chest",54)
		# Each half keeps the contents it held as a single chest.
		for half in 2:
			var single_key: String = station_key(primary if half == 0 else (b if primary == a else a))
			if not stations.has(single_key): continue
			var old: Array = stations[single_key].slots
			for i in mini(27,old.size()): station.slots[half*27+i] = old[i]
			stations.erase(single_key)
		stations[key] = station
	return stations[key]

# Removes the station at p and returns the items it held. Breaking one half of a
# large chest leaves the partner as a single chest with its own 27 slots.
func detach_station(p: Vector3i, partner: Vector3i = Vector3i(99999,99999,99999)) -> Array:
	var items: Array = []
	var key: String = station_key(p)
	if stations.has(key):
		items.append_array(stations[key].slots)
		stations.erase(key)
	if partner != p and partner != Vector3i(99999,99999,99999):
		var shared: String = pair_key(p,partner)
		if stations.has(shared):
			var slots: Array = stations[shared].slots
			var mine: int = 0 if chest_primary(p,partner) == p else 27
			items.append_array(slots.slice(mine,mine+27))
			var remaining: Dictionary = _new_station("chest",27)
			remaining.slots = slots.slice(27-mine,54-mine)
			stations.erase(shared)
			stations[station_key(partner)] = remaining
	var kept: Array = []
	for slot in items:
		if int(slot.id) != 0: kept.append(slot)
	return kept

func _exit_tree() -> void:
	for job in jobs: WorkerThreadPool.wait_for_task_completion(job.task)
	for job in remesh_jobs: WorkerThreadPool.wait_for_task_completion(job.task)

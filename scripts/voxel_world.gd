class_name VoxelWorld
extends Node3D

signal column_loaded
const SIZE = 16
var dimension: String = "overworld"
var seed_value: int = 8675309
var generator: TerrainGenerator
var blocks: Dictionary = {}
var hazards: Dictionary = {}
var columns: Dictionary = {}
var edits: Dictionary = {}
var stations: Dictionary = {}
var growth: Dictionary = {}
var block_states: Dictionary = {}
var adventure_state: Dictionary = {}
var circuits: RedstoneCircuit
var fluids: Fluids
var pending: Dictionary = {}
var jobs: Array = []
var remesh_jobs: Array = []
var dirty: Dictionary = {}
var desired: Vector2i = Vector2i(999999,999999)
var generation_queue: Array = []
var radius: int = 4:
	set(value):
		if value != radius:
			radius = value; desired = Vector2i(999999,999999)
var target: Vector3 = Vector3(8,30,8)
var material: ShaderMaterial
var water_material: ShaderMaterial
var sky_revision: int = 0
var tick: float = 0.0
var active: bool = true
var last_mesh_ms: float = 0.0

func configure(seed_number: int, atlas: Texture2D, dimension_name: String = "overworld") -> void:
	dimension = dimension_name
	seed_value = seed_number
	generator = TerrainGenerator.new(seed_value,dimension)
	circuits = RedstoneCircuit.new(self)
	fluids = Fluids.new(self)
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
		generation_queue.clear()
		for z in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				var c: Vector2i = center+Vector2i(x,z)
				if WorldBounds.horizontal(Vector3i(c.x*16,0,c.y*16)) and not columns.has(c): generation_queue.append(c)
		# Pop the nearest request from the end. The queue changes only when the
		# player crosses a column boundary or changes view distance.
		generation_queue.sort_custom(func(a: Vector2i,b: Vector2i): return a.distance_squared_to(center) > b.distance_squared_to(center))
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
		var snapshot: PackedInt32Array = _snapshot(coord)
		var job: Dictionary = {"coord":coord, "result":[]}
		job.task = WorkerThreadPool.add_task(func(): job.result = BlockMesher.build(snapshot,true))
		remesh_jobs.append(job)
	while jobs.size() < 2 and not generation_queue.is_empty():
		var nearest: Vector2i = generation_queue.pop_back()
		if not columns.has(nearest) and not pending.has(nearest): _queue_column(nearest)
	if active:
		fluids.update(delta)
		if get_parent() != null and get_parent().has_method("playing") and get_parent().playing(): circuits.update(delta)
		tick += delta
		if tick >= 1.0:
			tick = 0.0
			_simulate()

func _queue_column(coord: Vector2i) -> void:
	var local_edits: Dictionary = {}
	for p in edits:
		if p.x >= coord.x*16-1 and p.x <= coord.x*16+16 and p.z >= coord.y*16-1 and p.z <= coord.y*16+16: local_edits[p] = edits[p]
	var gen := TerrainGenerator.new(seed_value,dimension)
	var job: Dictionary = {"coord":coord,"result":{}}
	job.task = WorkerThreadPool.add_task(func(): job.result = gen.generate_column(coord,local_edits),false,"Generate map blocks")
	jobs.append(job)
	pending[coord] = true

func _apply_column(result: Dictionary) -> void:
	sky_revision += 1
	var c: Vector2i = result.coord
	columns[c] = true
	for entry in result.blocks:
		var coord := Vector3i(c.x,int(entry.y),c.y)
		var root := Node3D.new()
		root.name = "MapBlock_%d_%d_%d" % [c.x,coord.y,c.y]
		root.position = Vector3(coord * SIZE)
		add_child(root)
		blocks[coord] = {"data":entry.data,"root":root,"meshes":[]}
		_apply_mesh(coord,entry.surfaces)
	# Reconcile edits made while the worker was running, including border halos.
	for p in edits:
		if p.x >= c.x*16-1 and p.x <= c.x*16+16 and p.z >= c.y*16-1 and p.z <= c.y*16+16:
			var b: Vector3i = block_coord(p)
			if not blocks.has(b) and b.x == c.x and b.z == c.y and p.y >= generator.terrain_ceiling() and p.y < generator.max_y(): _create_air_block(b)
			if blocks.has(b) and blocks[b].data[local_index(p)] != edits[p]:
				blocks[b].data[local_index(p)] = edits[p]
				_mark_dirty(p)
	for p in result.get("special",{}):
		var id: int = node_at(p)
		if id in Nodes.CIRCUIT_NODES: circuits.register(p,id)
		if id == Nodes.CHEST and not edits.has(p): _structure_loot(p)
		if Fire.is_fire(id): Fire.track(self,p)
	for p in result.get("reactive",{}):
		react_fluid(p)
		Fire.track(self,p)
	for p in result.get("flowing",{}): fluids.activate(p)
	# Changes made after the worker snapshot must also update simulation indexes.
	for p in edits:
		if p.x < c.x*16-1 or p.x > c.x*16+16 or p.z < c.y*16-1 or p.z > c.y*16+16: continue
		if not loaded_at(Vector3(p)): continue
		var id: int = node_at(p)
		if id in Nodes.CIRCUIT_NODES: circuits.register(p,id)
		if Fire.is_fire(id) or Fluids.lava(id): Fire.track(self,p)
		if Fluids.liquid(id): react_fluid(p); fluids.activate(p)
		if Fire.flammable(id):
			for side in SIDES: Fire.track(self,p+side)
	fluids.column_loaded(c)
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
	sky_revision += 1
	columns.erase(c)
	for p in hazards.keys():
		if block_coord(p).x == c.x and block_coord(p).z == c.y: hazards.erase(p)
	circuits.unload(c)
	for b in blocks.keys():
		if b.x == c.x and b.z == c.y:
			blocks[b].root.queue_free(); blocks.erase(b); dirty.erase(b)

static func block_coord(p: Vector3i) -> Vector3i:
	return Vector3i(floori(p.x/16.0),floori(p.y/16.0),floori(p.z/16.0))

static func local_index(p: Vector3i) -> int:
	return posmod(p.x,16) + posmod(p.z,16)*16 + posmod(p.y,16)*256

func node_at(p: Vector3i) -> int:
	if not WorldBounds.horizontal(p): return Nodes.BEDROCK
	if p.y < generator.min_y(): return Nodes.AIR if dimension == "end" else Nodes.BEDROCK
	if p.y >= generator.max_y(): return Nodes.BEDROCK
	var b: Vector3i = block_coord(p)
	if blocks.has(b): return blocks[b].data[local_index(p)]
	if p.y >= generator.terrain_ceiling() and loaded_at(Vector3(p)): return Nodes.AIR
	# Treat unloaded terrain as solid for movement; streaming never drops a player.
	return Nodes.BEDROCK

func area_ready(p: Vector3) -> bool:
	var center := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	for z in range(-1,2):
		for x in range(-1,2):
			var c: Vector2i = center+Vector2i(x,z)
			if WorldBounds.horizontal(Vector3i(c.x*16,0,c.y*16)) and not columns.has(c): return false
	return true

func loaded_at(p: Vector3) -> bool:
	return columns.has(Vector2i(floori(p.x/16.0),floori(p.z/16.0)))

func set_node(p: Vector3i, id: int) -> bool:
	var b: Vector3i = block_coord(p)
	if not WorldBounds.horizontal(p) or p.y <= generator.min_y() or p.y >= generator.max_y(): return false
	if not blocks.has(b):
		if p.y < generator.terrain_ceiling() or not loaded_at(Vector3(p)): return false
		_create_air_block(b)
	var old_id: int = blocks[b].data[local_index(p)]
	if Nodes.solid(old_id) != Nodes.solid(id): sky_revision += 1
	blocks[b].data[local_index(p)] = id
	Fire.track(self,p)
	if Fire.flammable(id) or Fire.flammable(old_id):
		for side in Fire.SIDES: Fire.track(self,p+side)
	circuits.changed(p,old_id,id)
	edits[p] = id
	if id in [Nodes.WHEAT,Nodes.SAPLING,Nodes.SUGAR_CANE] or VillageContent.shape(id) == "crop" and VillageContent.DATA[id].stage < 3: growth[p] = 0.0
	else: growth.erase(p)
	_mark_dirty(p)
	if BuildingShapes.stair(old_id) or BuildingShapes.stair(id):
		for dx in range(-1,2):
			for dz in range(-1,2):
				var neighbor: Vector3i = p+Vector3i(dx,0,dz)
				dirty[block_coord(neighbor)] = true
				Torches.support_changed(self,neighbor)
				circuits.support_changed(neighbor)
	if Fluids.liquid(id): react_fluid(p)
	if id != Nodes.NETHER_PORTAL: validate_portals_near(p)
	Torches.support_changed(self,p)
	circuits.support_changed(p)
	fluids.changed(p,old_id,node_at(p))
	var game: Node = get_parent()
	if game != null and game.has_method("remove_torch"):
		if Torches.is_torch(old_id): game.remove_torch(p)
		if Torches.is_torch(id): game.add_torch(p)
	return true

func _create_air_block(coord: Vector3i) -> void:
	var root := Node3D.new(); root.name = "SkyBlock_%d_%d_%d"%[coord.x,coord.y,coord.z]
	root.position = Vector3(coord*16); add_child(root)
	var data := PackedInt32Array(); data.resize(4096)
	blocks[coord] = {"data":data,"root":root,"meshes":[]}

func _mark_dirty(p: Vector3i) -> void:
	dirty[block_coord(p)] = true
	for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]:
		if block_coord(p+d) != block_coord(p): dirty[block_coord(p+d)] = true

func _snapshot(coord: Vector3i) -> PackedInt32Array:
	var data := PackedInt32Array()
	data.resize(5832)
	# Resolve the 27 blocks once, then copy contiguous rows. Missing neighbors
	# remain invisible, while the bottom world boundary still occludes faces.
	for dy in range(-1,2):
		var y0: int = 0 if dy < 0 else (1 if dy == 0 else 17)
		var y1: int = 17 if dy == 0 else y0+1
		for dz in range(-1,2):
			var z0: int = 0 if dz < 0 else (1 if dz == 0 else 17)
			var z1: int = 17 if dz == 0 else z0+1
			for dx in range(-1,2):
				var x0: int = 0 if dx < 0 else (1 if dx == 0 else 17)
				var x1: int = 17 if dx == 0 else x0+1
				var b: Vector3i = coord+Vector3i(dx,dy,dz)
				var source: PackedInt32Array = blocks[b].data if blocks.has(b) else PackedInt32Array()
				for y in range(y0,y1):
					for z in range(z0,z1):
						var dst: int = z*18+y*324
						var src: int = ((z+15)%16)*16+((y+15)%16)*256
						if source.is_empty():
							var wy: int = coord.y*16+y-1
							if wy <= generator.min_y() and dimension != "end":
								for x in range(x0,x1): data[dst+x] = Nodes.BEDROCK
						else:
							for x in range(x0,x1): data[dst+x] = source[src+(x+15)%16]
	return data

func intersects(pos: Vector3, half_width: float = 0.29, height: float = 1.8) -> bool:
	var lo := Vector3i(floori(pos.x-half_width),floori(pos.y+0.002),floori(pos.z-half_width))
	var hi := Vector3i(floori(pos.x+half_width),floori(pos.y+height-0.002),floori(pos.z+half_width))
	for y in range(lo.y,hi.y+1):
		for z in range(lo.z,hi.z+1):
			for x in range(lo.x,hi.x+1):
				var p := Vector3i(x,y,z)
				var id: int = node_at(p)
				if not Nodes.solid(id): continue
				if not BuildingShapes.is_shape(id): return true
				var body := AABB(pos-Vector3(half_width,-0.002,half_width),Vector3(half_width*2,height-0.004,half_width*2))
				for box in BuildingShapes.boxes(BuildingShapes.world_mask(self,p)):
					if body.intersects(AABB(Vector3(p)+box.position,box.size)): return true
	return false

# Amanatides-Woo voxel traversal: precise targeting without per-node colliders.
func raycast(origin: Vector3, direction: Vector3, reach: float = 5.0, liquids: bool = false) -> Dictionary:
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
		if id != Nodes.AIR and id not in [Nodes.NETHER_PORTAL,Nodes.END_PORTAL] and (liquids or not Fluids.liquid(id)):
			if BuildingShapes.is_shape(id) or Fluids.flowing(id):
				var hit: Dictionary = shape_hit(cell,origin,direction,reach)
				if not hit.is_empty(): return hit
			else: return {"pos":cell,"normal":normal,"id":id,"distance":distance,"point":origin+direction*distance}
		var axis: int = 0 if t_max.x < t_max.y else 1
		if t_max.z < t_max[axis]: axis = 2
		distance = t_max[axis]
		if distance > reach: break
		cell[axis] += step_dir[axis]
		t_max[axis] += t_delta[axis]
		normal = Vector3i.ZERO
		normal[axis] = -step_dir[axis]
	return {}

func shape_hit(p: Vector3i, origin: Vector3, direction: Vector3, reach: float) -> Dictionary:
	var nearest: Dictionary = {}
	var closest: float = reach+0.00001
	var id: int = node_at(p)
	var boxes: Array = [AABB(Vector3.ZERO,Vector3(1,1.0 if Fluids.base(node_at(p+Vector3i.UP)) == Fluids.base(id) else Fluids.height(id),1))] if Fluids.flowing(id) else BuildingShapes.boxes(BuildingShapes.world_mask(self,p))
	for box in boxes:
		var low: Vector3 = Vector3(p)+box.position
		var high: Vector3 = low+box.size
		var enter: float = 0; var leave: float = reach
		var normal := Vector3i.ZERO
		var valid: bool = true
		for axis in 3:
			if absf(direction[axis]) < 0.000001:
				if origin[axis] < low[axis] or origin[axis] > high[axis]: valid = false; break
				continue
			var a: float = (low[axis]-origin[axis])/direction[axis]
			var b: float = (high[axis]-origin[axis])/direction[axis]
			var near: float = minf(a,b)
			if near > enter:
				enter = near; normal = Vector3i.ZERO; normal[axis] = -1 if direction[axis] > 0 else 1
			leave = minf(leave,maxf(a,b))
			if enter > leave: valid = false; break
		if valid and enter < closest:
			closest = enter
			nearest = {"pos":p,"normal":normal,"id":node_at(p),"distance":enter,"point":origin+direction*enter}
	return nearest

func _simulate() -> void:
	Fire.update(self)
	for p in growth.keys():
		if not loaded_at(Vector3(p)): continue
		growth[p] += 1.0
		var id: int = node_at(p)
		if VillageContent.shape(id) == "crop" and growth[p] >= 30:
			if VillageContent.DATA[id].stage < 3: set_node(p,id+1)
		elif id == Nodes.WHEAT and growth[p] > 90:
			set_node(p,Nodes.RIPE_WHEAT)
		elif id == Nodes.SAPLING and growth[p] > 120:
			grow_tree(p)
		elif id == Nodes.SUGAR_CANE and growth[p] > 60:
			growth[p] = 0.0
			var bottom: Vector3i = p
			while node_at(bottom+Vector3i.DOWN) == Nodes.SUGAR_CANE: bottom += Vector3i.DOWN
			if p.y-bottom.y < 2 and node_at(p+Vector3i.UP) == Nodes.AIR and can_plant_cane(bottom):
				set_node(p+Vector3i.UP,Nodes.SUGAR_CANE)
	for key in stations:
		var s: Dictionary = stations[key]
		if s.get("kind","") == "brewing": Brewing.step(s,1.0); continue
		if s.get("kind","") != "furnace": continue
		var input: Dictionary = s.slots[0]
		var fuel: Dictionary = s.slots[1]
		var output: Dictionary = s.slots[2]
		var recipe: int = Nodes.smelt_result(input.id)
		if s.get("device",0) in [VillageContent.SMOKER,VillageContent.CAMPFIRE] and Nodes.food(recipe) <= 0: recipe = 0
		if s.get("device",0) == VillageContent.BLAST_FURNACE and recipe not in [Nodes.IRON,Nodes.GOLD,Nodes.COPPER,VillageContent.EMERALD]: recipe = 0
		if s.burn > 0: s.burn -= 1
		if recipe == 0 or (output.id != 0 and output.id != recipe) or output.count >= 64: s.progress = 0.0; continue
		if s.burn <= 0:
			var burn: float = Nodes.fuel_time(fuel.id)
			if burn == 0: continue
			s.burn = burn
			if fuel.id == Nodes.LAVA_BUCKET:
				fuel.id = Nodes.BUCKET; fuel.count = 1; fuel.wear = 0
			else:
				fuel.count -= 1
				if fuel.count <= 0: fuel.id = 0
		s.progress += 2.0 if s.get("device",0) in [VillageContent.SMOKER,VillageContent.BLAST_FURNACE] else 1.0
		if s.progress >= 8:
			s.progress = 0.0
			input.count -= 1
			if input.count <= 0: input.id = 0
			output.id = recipe
			output.count += 1

func can_plant_cane(p: Vector3i) -> bool:
	var soil: Vector3i = p+Vector3i.DOWN
	if node_at(soil) == Nodes.SUGAR_CANE: return true
	if node_at(soil) not in [Nodes.DIRT,Nodes.GRASS,Nodes.SAND]: return false
	for side in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		if Fluids.water(node_at(soil+side)): return true
	return false

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
	if kind == "chest" and node_at(p) == Nodes.CHEST:
		var partner: Vector3i = chest_partner(p)
		if partner != p: return _double_chest(p,partner)
	var key: String = station_key(p)
	if not stations.has(key): stations[key] = _new_station(kind,5 if kind == "brewing" else (3 if kind == "furnace" else (5 if node_at(p) == Nodes.HOPPER else (9 if node_at(p) in [Nodes.DISPENSER,Nodes.DROPPER] else (54 if node_at(p) == VillageContent.RECOVERY_CHEST else 27)))))
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

const SIDES = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]

func react_fluid(p: Vector3i) -> void:
	var id: int = node_at(p)
	if Fluids.lava(id):
		for d in SIDES:
			if Fluids.water(node_at(p+d)):
				if id == Nodes.LAVA: set_node(p,Nodes.OBSIDIAN)
				elif d == Vector3i.DOWN: set_node(p+d,Nodes.STONE)
				else: set_node(p,Nodes.COBBLE)
				return
	elif Fluids.water(id):
		for d in SIDES:
			if Fluids.lava(node_at(p+d)): react_fluid(p+d)

# A standard 4 x 5 frame, with optional corners and a 2 x 3 opening.
func portal_frame(base: Vector3i, axis: Vector3i) -> bool:
	for x in range(-1,3):
		for y in range(-1,4):
			if x in [-1,2] and y in [-1,3]: continue
			var id: int = node_at(base+axis*x+Vector3i.UP*y)
			if x in [-1,2] or y in [-1,3]:
				if id != Nodes.OBSIDIAN: return false
			elif id not in [Nodes.AIR,Nodes.NETHER_PORTAL]: return false
	return true

func ignite_portal(near: Vector3i) -> bool:
	if dimension == "end": return false
	for axis in [Vector3i.RIGHT,Vector3i.BACK]:
		for dx in range(-2,2):
			for dy in range(-3,2):
				var base: Vector3i = near+axis*dx+Vector3i.UP*dy
				if not portal_frame(base,axis): continue
				for x in 2:
					for y in 3: set_node(base+axis*x+Vector3i.UP*y,Nodes.NETHER_PORTAL)
				return true
	return false

func validate_portals_near(p: Vector3i) -> void:
	for d in SIDES:
		var start: Vector3i = p+d
		if node_at(start) != Nodes.NETHER_PORTAL: continue
		var connected: Array = [start]
		var i: int = 0
		while i < connected.size() and connected.size() < 64:
			var cell: Vector3i = connected[i]; i += 1
			for step in SIDES:
				if node_at(cell+step) == Nodes.NETHER_PORTAL and not connected.has(cell+step): connected.append(cell+step)
		var valid: bool = false
		for cell in connected:
			for axis in [Vector3i.RIGHT,Vector3i.BACK]:
				if portal_frame(cell,axis): valid = true
		if not valid:
			# Batch clear prevents recursive validation of a half-removed portal.
			for cell in connected:
				blocks[block_coord(cell)].data[local_index(cell)] = Nodes.AIR
				edits[cell] = Nodes.AIR
				_mark_dirty(cell)

# Find a dry floor near the requested height without teleporting cave mobs to
# the surface. Empty space must fit a standing player or humanoid creature.
func cave_spawn(near: Vector3, vertical_reach: int = 12) -> Vector3:
	var x: int = floori(near.x)
	var z: int = floori(near.z)
	if not loaded_at(near): return Vector3.INF
	for distance in vertical_reach+1:
		for direction in [-1,1]:
			var y: int = floori(near.y)+distance*direction
			if y <= generator.min_y() or y >= generator.max_y()-2: continue
			var feet := Vector3i(x,y,z)
			var support: int = node_at(feet+Vector3i.DOWN)
			if not Nodes.solid(support) or support in [Nodes.LOG,Nodes.LEAVES]: continue
			if node_at(feet) != Nodes.AIR or node_at(feet+Vector3i.UP) != Nodes.AIR: continue
			var pos := Vector3(x+0.5,y+0.01,z+0.5)
			if not intersects(pos): return pos
	return Vector3.INF

func _structure_loot(p: Vector3i) -> void:
	var key: String = station_key(p)
	if stations.has(key): return
	var station: Dictionary = get_station(p,"chest")
	if dimension == "nether" and not Bastions.at(generator,p).is_empty():
		Bastions.fill(station,generator.hash_at(p.x,p.y,p.z)); return
	var loot: Array = [[Nodes.PAPER,8],[Nodes.BOOK,3],[Nodes.IRON,4],[Nodes.ENDER_PEARL,1],[Nodes.BREAD,4]]
	if dimension == "overworld" and p.y > 0:
		loot = [[VillageContent.EMERALD,2+generator.hash_at(p.x,90,p.z)%4],[Nodes.BREAD,3],[VillageContent.CARROT,4],[VillageContent.POTATO,4],[VillageContent.BEETROOT_SEEDS,3],[Nodes.APPLE,2],[VillageContent.COCOA_BEANS,2]]
	if dimension == "nether": loot = [[Nodes.GOLD,5],[Nodes.DIAMOND,1],[Nodes.NETHER_BRICKS,16],[Nodes.SADDLE,1],[Nodes.FLINT_AND_STEEL,1],[VillageContent.NETHER_WART_ITEM,8]]
	if dimension == "end": loot = [[Nodes.ELYTRA,1],[Nodes.DIAMOND,5],[Nodes.GOLD,8],[Nodes.ENDER_PEARL,4],[Nodes.END_ROD,16],[Nodes.GOLDEN_APPLE,2]]
	for i in loot.size(): station.slots[i] = {"id":loot[i][0],"count":loot[i][1],"wear":0}
	if dimension != "overworld" or p.y < 0:
		var rng := RandomNumberGenerator.new(); rng.seed = generator.hash_at(p.x,p.y,p.z)
		station.slots[loot.size()] = {"id":VillageContent.ENCHANTED_BOOK,"count":1,"wear":0,"data":Enchantments.random_book(rng)}
		if dimension == "overworld":
			station.slots[loot.size()+1] = {"id":VillageContent.HEAVY_CORE,"count":1,"wear":0}
			station.slots[loot.size()+2] = {"id":PotionCatalog.find("luck"),"count":1,"wear":0}
		if dimension == "nether": station.slots[loot.size()+1] = {"id":PotionCatalog.find("withering"),"count":1,"wear":0}

func open_sky(p: Vector3i) -> bool:
	if dimension != "overworld": return false
	for y in range(p.y+2,mini(generator.terrain_ceiling(),generator.max_y())):
		if Nodes.solid(node_at(Vector3i(p.x,y,p.z))): return false
	for point in edits:
		if point.x == p.x and point.z == p.z and point.y > p.y+1 and Nodes.solid(edits[point]): return false
	return true

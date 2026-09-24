class_name VoxelWorld
extends Node3D

signal column_loaded
const SIZE = 16
var dimension: String = "overworld"
var seed_value: int = 8675309
var generator: TerrainGenerator
# Idle generators for worker jobs. Each job owns one at a time, so structure and
# ore caches carry over between columns without being shared across threads.
var generator_pool: Array = []
var blocks: Dictionary = {}
# Map block coordinates per column, so unloading never scans every block.
var column_blocks: Dictionary = {}
var hazards: Dictionary = {}
var columns: Dictionary = {}
var edits: Dictionary = {}
# Edited positions grouped by column, so streaming and sky checks never walk
# every edit in the world. Writes that go straight to `edits` (save loading,
# structure repair, tests) are caught by a size check, and a removed key is
# caught when its column is read; either rebuilds the index from `edits`.
var edit_columns: Dictionary = {}
var edit_count: int = 0
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
# Vertical view range. Depth fog is opaque at `radius` columns, so a map block
# more than `radius` levels above or below the camera can never be seen. Such
# blocks keep their nodes but no mesh; they are meshed, nearest first, when the
# player's level brings them into range.
var unmeshed: Dictionary = {}
var mesh_queue: Array = []
var mesh_level: int = 999999
var mesh_radius: int = -1
# Blocks meshed before a neighbouring column had loaded. Their borders assumed
# air there, so they are meshed again when that column arrives.
var partial: Dictionary = {}
var desired: Vector2i = Vector2i(999999,999999)
var generation_queue: Array = []
# Terrain jobs run at high priority because the worker pool gives low-priority
# tasks only 30% of its threads, which is a single thread on a four-core CPU.
# The cap leaves one core for the main thread and one for block remeshes.
static var generation_slots: int = clampi(OS.get_processor_count()-2,1,6)
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
	Jukeboxes.reset(self)
	Dungeons.reset(self)
	Copper.reset(self)
	Copper.register_families()
	Weather.reset(self)
	Conduits.reset(self)
	Corals.reset(self)
	SeaPickles.reset(self)
	Kelp.reset(self)
	Beacons.reset(self)
	Sponges.reset(self)
	Concrete.reset(self)
	EndMud.reset(self)
	LushCaveExtra.reset(self)
	PaleOak.reset(self)
	ZombieSiege.reset(self)
	Archaeology.reset(self)
	if has_meta("piston_support"): remove_meta("piston_support")
	Farmland.reset(self)
	CropFarming.reset(self)
	FruitCrops.reset(self)
	Amethyst.reset(self)
	Beehives.reset(self)
	dimension = dimension_name
	seed_value = seed_number
	Pasture.reset(self)
	SnowCover.reset(self)
	if has_meta("wood_runtime"): remove_meta("wood_runtime")
	generator = TerrainGenerator.new(seed_value,dimension)
	generator_pool.clear()
	circuits = RedstoneCircuit.new(self)
	fluids = Fluids.new(self)
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/terrain.gdshader")
	material.set_shader_parameter("atlas",atlas)
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://shaders/water.gdshader")
	water_material.set_shader_parameter("atlas",atlas)
	for entry in [["honey_tile",Beehives.HONEY_BLOCK],["tinted_glass_tile",Amethyst.TINTED_GLASS]]:
		var tile: int = Nodes.tile(entry[1],0)
		water_material.set_shader_parameter(entry[0],Vector2(tile%8,tile/8))

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
	var level: int = floori(target.y/16.0)
	if level != mesh_level or radius != mesh_radius:
		mesh_level = level; mesh_radius = radius
		_refresh_vertical_meshes()
	var started: int = Time.get_ticks_usec()
	for job in jobs.duplicate():
		if not WorkerThreadPool.is_task_completed(job.task): continue
		WorkerThreadPool.wait_for_task_completion(job.task)
		jobs.erase(job)
		pending.erase(job.coord)
		NodeInfo.learn(job.info)
		if job.gen.world_seed == seed_value and job.gen.dimension == dimension: generator_pool.append(job.gen)
		if maxi(absi(job.coord.x-center.x), absi(job.coord.y-center.y)) <= radius+1:
			_apply_column(job.result)
		if Time.get_ticks_usec() - started > 5000: break
	for job in remesh_jobs.duplicate():
		if not WorkerThreadPool.is_task_completed(job.task): continue
		WorkerThreadPool.wait_for_task_completion(job.task)
		remesh_jobs.erase(job)
		NodeInfo.learn(job.info)
		if blocks.has(job.coord): _apply_mesh(job.coord,job.result)
		if Time.get_ticks_usec() - started > 7000: break
	var remesh_slots: int = maxi(2,generation_slots)
	while remesh_jobs.size() < remesh_slots and not dirty.is_empty():
		var coord: Vector3i = dirty.keys()[0]
		dirty.erase(coord)
		if not blocks.has(coord): continue
		# Out of range, the block is meshed from its current nodes on arrival.
		if unmeshed.has(coord) and not in_mesh_range(coord.y): continue
		if _remeshing(coord): dirty[coord] = true; break
		if partial.has(coord) and _neighbors_loaded(Vector2i(coord.x,coord.z)): partial.erase(coord)
		_start_remesh(coord)
	# Blocks entering the vertical range come after the player's own edits, and
	# may also use generation slots that are standing idle.
	var queue_slots: int = remesh_slots+maxi(0,generation_slots-jobs.size())
	while remesh_jobs.size() < queue_slots and not mesh_queue.is_empty():
		var coord: Vector3i = mesh_queue.pop_back()
		if not unmeshed.has(coord) or not blocks.has(coord) or not in_mesh_range(coord.y) or _remeshing(coord): continue
		if not _neighbors_loaded(Vector2i(coord.x,coord.z)): partial[coord] = true
		_start_remesh(coord)
	while jobs.size() < generation_slots and not generation_queue.is_empty():
		var nearest: Vector2i = generation_queue.pop_back()
		if not columns.has(nearest) and not pending.has(nearest): _queue_column(nearest)
	if active:
		fluids.update(delta)
		Campfires.update(self,delta)
		Cauldrons.update(self,delta)
		Pasture.update(self,delta)
		SnowCover.update(self,delta)
		WoodTypes.update(self,delta)
		Farmland.update(self,delta)
		CropFarming.update(self,delta)
		FruitCrops.update(self,delta)
		Amethyst.update(self,delta)
		Beehives.update(self,delta)
		Copper.update(self,delta)
		Weather.update(self,delta)
		Sponges.update(self,delta)
		Dripping.update(self,delta)
		Archaeology.update(self,delta)
		if get_parent() != null and get_parent().rails != null: get_parent().rails.update(delta)
		Conduits.update(self,delta)
		Corals.update(self,delta)
		SeaPickles.update(self,delta)
		Concrete.update(self,delta)
		EndMud.update(self,delta)
		LushCaveExtra.update(self,delta)
		var siege_owner: Node = get_parent()
		if siege_owner != null and siege_owner.has_method("toast"): ZombieSiege.update(siege_owner,delta)
		if siege_owner != null and siege_owner.has_method("toast"): PaleOak.update(siege_owner,delta)
		Kelp.update(self,delta)
		Beacons.update(self,delta)
		for key in stations:
			var station: Dictionary = stations[key]
			if station.get("kind","") != "composter": continue
			var xyz: PackedStringArray = key.split(",")
			if xyz.size() == 3 and loaded_at(Vector3(float(xyz[0]),float(xyz[1]),float(xyz[2]))): Composters.step(station,delta)
		if get_parent() != null and get_parent().has_method("playing") and get_parent().playing(): circuits.update(delta)
		tick += delta
		if tick >= 1.0:
			tick = 0.0
			_simulate()

func record_edit(p: Vector3i, id: int) -> void:
	if not edits.has(p) and edit_count == edits.size():
		var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
		if not edit_columns.has(column): edit_columns[column] = []
		edit_columns[column].append(p)
		edit_count += 1
	edits[p] = id

func column_edits(column: Vector2i) -> Array:
	if edit_count != edits.size(): _reindex_edits()
	var found: Array = edit_columns.get(column,[])
	for p in found:
		if not edits.has(p):
			_reindex_edits()
			return edit_columns.get(column,[])
	return found

func _reindex_edits() -> void:
	edit_columns.clear()
	for p in edits:
		var key := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
		if not edit_columns.has(key): edit_columns[key] = []
		edit_columns[key].append(p)
	edit_count = edits.size()

# Every edit in the loaded columns, without visiting unloaded ones.
func loaded_edits() -> Array:
	var found: Array = []
	for column in columns: found.append_array(column_edits(column))
	return found

# Edits inside a column and its one-node border.
func edits_near(column: Vector2i) -> Array:
	var found: Array = []
	for dz in range(-1,2):
		for dx in range(-1,2):
			for p in column_edits(column+Vector2i(dx,dz)):
				if p.x >= column.x*16-1 and p.x <= column.x*16+16 and p.z >= column.y*16-1 and p.z <= column.y*16+16: found.append(p)
	return found

func _remeshing(coord: Vector3i) -> bool:
	for job in remesh_jobs:
		if job.coord == coord: return true
	return false

func _start_remesh(coord: Vector3i) -> void:
	var snapshot: PackedInt32Array = _snapshot(coord)
	var info: NodeInfo.View = NodeInfo.view()
	var job: Dictionary = {"coord":coord, "result":[], "info":info}
	# Player edits jump ahead of terrain generation in the worker pool.
	job.task = WorkerThreadPool.add_task(func(): job.result = BlockMesher.build(snapshot,true,info),true,"Remesh map block")
	remesh_jobs.append(job)

func in_mesh_range(level: int) -> bool:
	return absi(level-mesh_level) <= radius

# A neighbour that is still due to generate would supply the block's border.
# Beyond the view radius it never loads; the faces toward it point away from the
# player and are back-face culled.
func _neighbors_loaded(column: Vector2i) -> bool:
	for dz in range(-1,2):
		for dx in range(-1,2):
			var c: Vector2i = column+Vector2i(dx,dz)
			if columns.has(c) or not WorldBounds.horizontal(Vector3i(c.x*16,0,c.y*16)): continue
			if maxi(absi(c.x-desired.x),absi(c.y-desired.y)) <= radius: return false
	return true

# Frees meshes well outside the vertical range (one level of hysteresis keeps a
# player on a boundary from churning) and queues blocks that entered it.
func _refresh_vertical_meshes() -> void:
	mesh_queue.clear()
	for coord in blocks:
		var gap: int = absi(coord.y-mesh_level)
		if gap > radius+1 and not blocks[coord].meshes.is_empty():
			for mesh_node in blocks[coord].meshes: mesh_node.queue_free()
			blocks[coord].meshes.clear()
			unmeshed[coord] = true
		elif gap <= radius and unmeshed.has(coord): mesh_queue.append(coord)
	_sort_mesh_queue()

func _sort_mesh_queue() -> void:
	var eye := Vector3(target.x/16.0-0.5,target.y/16.0-0.5,target.z/16.0-0.5)
	mesh_queue.sort_custom(func(a: Vector3i,b: Vector3i): return Vector3(a).distance_squared_to(eye) > Vector3(b).distance_squared_to(eye))

func _queue_column(coord: Vector2i) -> void:
	var local_edits: Dictionary = {}
	for p in edits_near(coord): local_edits[p] = edits[p]
	var gen: TerrainGenerator = generator_pool.pop_back() if not generator_pool.is_empty() else TerrainGenerator.new(seed_value,dimension)
	var info: NodeInfo.View = NodeInfo.view()
	var job: Dictionary = {"coord":coord,"result":{},"info":info,"gen":gen}
	var levels := Vector2i(mesh_level-radius,mesh_level+radius) if mesh_level != 999999 else TerrainGenerator.ALL_LEVELS
	job.task = WorkerThreadPool.add_task(func():
		job.result = gen.generate_column(coord,local_edits,false,info,levels)
		job.result["edit_snapshot"] = local_edits,true,"Generate map blocks")
	jobs.append(job)
	pending[coord] = true

# The load-time registrations a node id needs, classified once per id. Only the
# main thread applies columns, so the memo needs no locking.
const HOOK_CIRCUIT = 1
const HOOK_LEGACY_DOOR = 1 << 1
const HOOK_INPUT = 1 << 2
const HOOK_AMETHYST = 1 << 3
const HOOK_POWDER = 1 << 4
const HOOK_CHORUS = 1 << 5
const HOOK_HIVE = 1 << 6
const HOOK_SOIL = 1 << 7
const HOOK_CROP = 1 << 8
const HOOK_STEM = 1 << 9
const HOOK_SAPLING = 1 << 10
const HOOK_SNOW = 1 << 11
const HOOK_FOOD = 1 << 12
const HOOK_SUSPICIOUS = 1 << 13
const HOOK_FIRE = 1 << 14
const HOOK_CAMPFIRE = 1 << 15
const HOOK_SIGN = 1 << 16
const HOOK_CONDUIT = 1 << 17
const HOOK_CORAL = 1 << 18
const HOOK_PICKLE = 1 << 19
const HOOK_KELP = 1 << 20
const HOOK_BEACON = 1 << 21
const HOOK_LEAVES = 1 << 22
# Registrations the worker's `special` index does not cover; an edit carrying
# one is always registered when its column loads.
const UNINDEXED_HOOKS = HOOK_LEGACY_DOOR|HOOK_POWDER|HOOK_CHORUS|HOOK_CONDUIT|HOOK_CORAL|HOOK_PICKLE|HOOK_KELP|HOOK_BEACON
static var hook_memo: Dictionary = {}

static func load_hooks(id: int) -> int:
	var hooks: int = hook_memo.get(id,-1)
	if hooks >= 0: return hooks
	hooks = 0
	if RedstoneCircuit.circuit_node(id): hooks |= HOOK_CIRCUIT
	if Doors.legacy(id): hooks |= HOOK_LEGACY_DOOR
	if RedstoneInputs.is_device(id): hooks |= HOOK_INPUT
	if Amethyst.tracked(id): hooks |= HOOK_AMETHYST
	if Concrete.is_powder(id): hooks |= HOOK_POWDER
	if EndMud.is_chorus_part(id): hooks |= HOOK_CHORUS
	if Beehives.is_hive(id): hooks |= HOOK_HIVE
	if Farmland.is_soil(id): hooks |= HOOK_SOIL
	if CropFarming.is_crop(id): hooks |= HOOK_CROP
	if FruitCrops.is_stem(id): hooks |= HOOK_STEM
	if WoodTypes.is_sapling(id): hooks |= HOOK_SAPLING
	if SnowCover.is_snow(id): hooks |= HOOK_SNOW
	if FoodFeatures.is_cake(id) or FoodFeatures.flower(id) or FoodFeatures.is_tall_grass(id): hooks |= HOOK_FOOD
	if Archaeology.is_suspicious(id): hooks |= HOOK_SUSPICIOUS
	if Fire.is_fire(id): hooks |= HOOK_FIRE
	if Campfires.is_campfire(id): hooks |= HOOK_CAMPFIRE
	if Signs.is_sign(id): hooks |= HOOK_SIGN
	if Conduits.is_conduit(id): hooks |= HOOK_CONDUIT
	if Corals.is_coral(id): hooks |= HOOK_CORAL
	if SeaPickles.is_pickle(id): hooks |= HOOK_PICKLE
	if Kelp.is_kelp(id): hooks |= HOOK_KELP
	if Beacons.is_beacon(id): hooks |= HOOK_BEACON
	if WoodTypes.is_leaves(id): hooks |= HOOK_LEAVES
	hook_memo[id] = hooks
	return hooks

func _apply_column(result: Dictionary) -> void:
	WoodTypes.restore_legacy(self)
	sky_revision += 1
	var c: Vector2i = result.coord
	var snow_updates: Dictionary = {}
	var food_updates: Dictionary = {}
	var legacy_doors: Dictionary = {}
	var input_updates: Dictionary = {}
	var sign_updates: Dictionary = {}
	var fruit_updates: Dictionary = {}
	columns[c] = true
	for entry in result.blocks:
		var coord := Vector3i(c.x,int(entry.y),c.y)
		var root := Node3D.new()
		root.name = "MapBlock_%d_%d_%d" % [c.x,coord.y,c.y]
		root.position = Vector3(coord * SIZE)
		add_child(root)
		blocks[coord] = {"data":entry.data,"root":root,"meshes":[]}
		_index_block(coord)
		if entry.has("surfaces"): _apply_mesh(coord,entry.surfaces)
		else: unmeshed[coord] = true
	# Blocks the worker left unmeshed may have entered range since it started,
	# and neighbours meshed without this column need their borders again.
	var waiting: bool = false
	for coord in column_blocks.get(c,[]):
		if unmeshed.has(coord) and in_mesh_range(coord.y): mesh_queue.append(coord); waiting = true
	if waiting: _sort_mesh_queue()
	for coord in partial:
		if absi(coord.x-c.x) <= 1 and absi(coord.z-c.y) <= 1: dirty[coord] = true
	# Reconcile edits made while the worker was running, including border halos.
	var nearby_edits: Array = edits_near(c)
	for p in nearby_edits:
		var b: Vector3i = block_coord(p)
		if not blocks.has(b) and b.x == c.x and b.z == c.y and p.y >= generator.terrain_ceiling() and p.y < generator.max_y(): _create_air_block(b)
		if blocks.has(b) and blocks[b].data[local_index(p)] != edits[p]:
			blocks[b].data[local_index(p)] = edits[p]
			_mark_dirty(p)
	var carts: Dictionary = result.get("corridors",{}).get("carts",{})
	# Generated leaves and plants are supported as generated. Only an edit within
	# reach can change that: leaf support is searched within six nodes, a plant
	# rests on the node below. Mark the 8-node cells within seven nodes of such
	# edits, from this and adjacent columns and the special cells' height band.
	var special: Dictionary = result.get("special",{})
	var edit_zone: Dictionary = {}
	var low_y: int = 2147483647
	var high_y: int = -2147483647
	for p in special:
		low_y = mini(low_y,p.y); high_y = maxi(high_y,p.y)
	for dz in range(-1,2):
		for dx in range(-1,2):
			for q in column_edits(c+Vector2i(dx,dz)):
				if q.x < c.x*16-7 or q.x > c.x*16+22 or q.z < c.y*16-7 or q.z > c.y*16+22 or q.y < low_y-7 or q.y > high_y+7: continue
				for zz in range((q.z-7) >> 3,((q.z+7) >> 3)+1):
					for yy in range((q.y-7) >> 3,((q.y+7) >> 3)+1):
						for xx in range((q.x-7) >> 3,((q.x+7) >> 3)+1): edit_zone[Vector3i(xx,yy,zz)] = true
	for p in special:
		var id: int = node_at(p)
		var hooks: int = load_hooks(id)
		if hooks & HOOK_CIRCUIT: circuits.register(p,id)
		if hooks & HOOK_LEGACY_DOOR: legacy_doors[p] = true
		if hooks & HOOK_INPUT: input_updates[p] = true
		SnowCover.registered(self,p,id)
		var touched: bool = not edit_zone.is_empty() and edit_zone.has(Vector3i(p.x >> 3,p.y >> 3,p.z >> 3))
		if hooks & HOOK_LEAVES: WoodTypes.scan(self,p,id,touched)
		if hooks & HOOK_AMETHYST: Amethyst.registered(self,p,id)
		# Powder cells are swept for water contact, so a saved column must be
		# tracked again on load.
		if hooks & HOOK_POWDER: Concrete.placed_powder(self,p,id)
		if hooks & HOOK_CHORUS: EndMud.registered(self,p)
		if hooks & HOOK_HIVE: Beehives.registered(self,p)
		if hooks & HOOK_SOIL: Farmland.registered(self,p,id)
		if hooks & HOOK_CROP: CropFarming.registered(self,p,true)
		if hooks & HOOK_STEM: FruitCrops.registered(self,p,true); fruit_updates[p] = true
		if hooks & HOOK_SAPLING and not growth.has(p): growth[p] = 0.0
		if id == Dungeons.SPAWNER:
			# Corridor spawners carry their own mob; dungeon spawners fall back to
			# the dungeon table.
			var corridors: Dictionary = result.get("corridors",{})
			Dungeons.registered(self,p,str(corridors.get("spawners",{}).get(p,result.get("dungeons",{}).get("spawners",{}).get(p,"zombie"))))
		if hooks & HOOK_SNOW: snow_updates[p] = true
		if hooks & HOOK_FOOD and touched: food_updates[p] = true
		if id == Nodes.CHEST and not edits.has(p):
			if result.get("wrecks",{}).get("buried",{}).has(p): _structure_loot(p,-1,false,true)
			elif result.get("wrecks",{}).get("chests",{}).has(p): _structure_loot(p,-1,false,false,true)
			elif result.get("temples",{}).get("chests",{}).has(p): _structure_loot(p,-1,false,false,false,true)
			elif result.get("portals",{}).get("chests",{}).has(p): _structure_loot(p,-1,false,false,false,false,true)
			elif result.get("jungles",{}).get("chests",{}).has(p): _structure_loot(p,-1,false,false,false,false,false,true)
			elif result.get("outposts",{}).get("chests",{}).has(p): _structure_loot(p,-1,false,false,false,false,false,false,true)
			elif result.get("igloos",{}).get("chests",{}).has(p): _structure_loot(p,-1,false,false,false,false,false,false,false,true)
			elif result.get("monuments",{}).get("chests",{}).has(p): _structure_loot(p,-1,false,false,false,false,false,false,false,false,true)
			elif result.get("cabins",{}).get("chests",{}).has(p): _structure_loot(p,-1,false,false,false,false,false,false,false,false,false,true)
			elif result.get("treasure",{}).get("chests",{}).has(p): _structure_loot(p,-1,false,true)
			elif result.get("corridors",{}).get("chests",{}).has(p): _structure_loot(p,-1,true)
			else: _structure_loot(p,int(result.get("dungeons",{}).get("chests",{}).get(p,-1)))
		# A suspicious node's loot is drawn from the table of the structure that
		# placed it. The source tags each node with the structure's name and reads
		# that structure's own table, which is where the sherds live; without the
		# tag every node would draw from the generic sand or gravel list and the
		# sherds would be unreachable in survival.
		if hooks & HOOK_SUSPICIOUS:
			# Three structures place suspicious nodes, each with its own table.
			var placed_by: String = String(result.get("ruins",{}).get("suspicious",{}).get(p,
				String(result.get("temples",{}).get("suspicious",{}).get(p,""))))
			if not placed_by.is_empty(): Archaeology.set_structure(self,p,placed_by)
		# A mineshaft's loot is carried by a chest minecart standing on a rail, as
		# the source constructs it. The cart service owns it like any other cart.
		if not carts.is_empty() and carts.has(p):
			var cart: MinecartEntity = get_parent().rails.spawn(Rails.CHEST_CART,Vector3(p)+Vector3(0.5,0.06,0.5))
			if cart != null:
				var cart_station: Dictionary = _new_station("chest",27)
				Corridors.fill_chest(cart_station,int(carts[p]))
				var cart_record: Dictionary = get_parent().rails.records().get(cart.key,{})
				cart_record["cargo"] = cart_station.slots
				get_parent().rails.records()[cart.key] = cart_record
		if hooks & HOOK_FIRE: Fire.track(self,p)
		if hooks & HOOK_CAMPFIRE: Campfires.station(self,p)
		if hooks & HOOK_SIGN: Signs.station(self,p); sign_updates[p] = true
		if id == VillageContent.CAULDRON: Cauldrons.station(self,p)
		if hooks & HOOK_CONDUIT: Conduits.registered(self,p)
		if hooks & HOOK_CORAL: Corals.registered(self,p,id)
		if hooks & HOOK_PICKLE: SeaPickles.registered(self,p,id)
		if hooks & HOOK_KELP: Kelp.registered(self,p,id)
		if hooks & HOOK_BEACON: Beacons.registered(self,p,id)
	# A structure's own residents spawn once, at the marker block it reports. The
	# markers are ordinary blocks (a chest or a cauldron), so they are not in the
	# `special` index and must be read from each structure's own map.
	for p in result.get("outposts",{}).get("party",{}):
		if edits.has(p) or not loaded_at(Vector3(p)): continue
		for member in result.outposts.party[p]:
			var kind: String = String(member[0])
			var spot: Array = member[1]
			if spot.size() == 3:
				get_parent().spawn_creature(kind,Vector3(float(spot[0])+0.5,float(spot[1])+0.1,float(spot[2])+0.5))
	for p in result.get("igloos",{}).get("residents",{}):
		if edits.has(p) or not loaded_at(Vector3(p)): continue
		for kind in ["villager","zombie_villager"]:
			var spot: Array = result.igloos.residents[p].get(kind,[])
			if spot.size() == 3:
				get_parent().spawn_creature(kind,Vector3(float(spot[0])+0.5,float(spot[1])+0.1,float(spot[2])+0.5))
	for p in result.get("cabins",{}).get("garrison",{}):
		if edits.has(p) or not loaded_at(Vector3(p)): continue
		for member in result.cabins.garrison[p]:
			var kind: String = String(member[0])
			var spot: Array = member[1]
			if spot.size() == 3:
				get_parent().spawn_creature(kind,Vector3(float(spot[0])+0.5,float(spot[1])+0.1,float(spot[2])+0.5))
	for p in result.get("monuments",{}).get("garrison",{}):
		if edits.has(p) or not loaded_at(Vector3(p)): continue
		for member in result.monuments.garrison[p]:
			var kind: String = String(member[0])
			var spot: Array = member[1]
			if spot.size() == 3:
				get_parent().spawn_creature(kind,Vector3(float(spot[0])+0.5,float(spot[1])+0.1,float(spot[2])+0.5))
	for p in result.get("witches",{}).get("residents",{}):
		if edits.has(p) or not loaded_at(Vector3(p)): continue
		for kind in ["witch","cat"]:
			var spot: Array = result.witches.residents[p].get(kind,[])
			if spot.size() == 3:
				get_parent().spawn_creature(kind,Vector3(float(spot[0])+0.5,float(spot[1])+0.1,float(spot[2])+0.5))
	for p in result.get("reactive",{}):
		react_fluid(p)
		Fire.track(self,p)
	for p in result.get("flowing",{}): fluids.activate(p)
	# Bulk pasture membership first; the loop below re-tracks edited cells.
	Pasture.column_generated(self,c,result.get("pasture_cells",{}),result.get("pasture_lights",{}))
	# Changes made after the worker snapshot must also update simulation indexes.
	var corridor_spawners: Dictionary = result.get("corridors",{}).get("spawners",{})
	var dungeon_spawners: Dictionary = result.get("dungeons",{}).get("spawners",{})
	# The worker generated this column with the edits it was given, so its
	# indexes (special cells, pasture, fluids, fire) already include those that
	# are unchanged since. Only newer edits and unindexed registrations remain.
	var worker_edits: Dictionary = result.get("edit_snapshot",{})
	var indexed: bool = result.has("edit_snapshot")
	for p in nearby_edits:
		if not loaded_at(Vector3(p)): continue
		if indexed and worker_edits.get(p,-1) == edits[p] and load_hooks(edits[p]) & UNINDEXED_HOOKS == 0 and not carts.has(p): continue
		Pasture.changed(self,p)
		var id: int = node_at(p)
		var hooks: int = load_hooks(id)
		var bits: int = NodeInfo.of(id)
		if hooks & HOOK_CIRCUIT: circuits.register(p,id)
		if hooks & HOOK_LEGACY_DOOR: legacy_doors[p] = true
		if hooks & HOOK_INPUT: input_updates[p] = true
		SnowCover.registered(self,p,id)
		if hooks & HOOK_LEAVES: WoodTypes.scan(self,p,id)
		if hooks & HOOK_AMETHYST: Amethyst.registered(self,p,id)
		# Powder cells are swept for water contact, so a saved column must be
		# tracked again on load.
		if hooks & HOOK_POWDER: Concrete.placed_powder(self,p,id)
		if hooks & HOOK_CHORUS: EndMud.registered(self,p)
		if hooks & HOOK_HIVE: Beehives.registered(self,p)
		if hooks & HOOK_SOIL: Farmland.registered(self,p,id)
		if hooks & HOOK_CROP: CropFarming.registered(self,p,true)
		if hooks & HOOK_STEM: FruitCrops.registered(self,p,true); fruit_updates[p] = true
		if hooks & HOOK_SAPLING and not growth.has(p): growth[p] = 0.0
		if id == Dungeons.SPAWNER:
			# Corridor spawners carry their own mob; dungeon spawners fall back to
			# the dungeon table.
			Dungeons.registered(self,p,str(corridor_spawners.get(p,dungeon_spawners.get(p,"zombie"))))
		# An edited position is never unlooted structure storage (`edits.has(p)`),
		# so the structure chest branch of the generated-node loop cannot apply.
		# A suspicious node's loot is drawn from the table of the structure that
		# placed it. The source tags each node with the structure's name and reads
		# that structure's own table, which is where the sherds live; without the
		# tag every node would draw from the generic sand or gravel list and the
		# sherds would be unreachable in survival.
		if hooks & HOOK_SUSPICIOUS:
			# Three structures place suspicious nodes, each with its own table.
			var placed_by: String = String(result.get("ruins",{}).get("suspicious",{}).get(p,
				String(result.get("temples",{}).get("suspicious",{}).get(p,""))))
			if not placed_by.is_empty(): Archaeology.set_structure(self,p,placed_by)
		# A mineshaft's loot is carried by a chest minecart standing on a rail, as
		# the source constructs it. The cart service owns it like any other cart.
		if not carts.is_empty() and carts.has(p):
			var cart: MinecartEntity = get_parent().rails.spawn(Rails.CHEST_CART,Vector3(p)+Vector3(0.5,0.06,0.5))
			if cart != null:
				var cart_station: Dictionary = _new_station("chest",27)
				Corridors.fill_chest(cart_station,int(carts[p]))
				var cart_record: Dictionary = get_parent().rails.records().get(cart.key,{})
				cart_record["cargo"] = cart_station.slots
				get_parent().rails.records()[cart.key] = cart_record
		var above: int = load_hooks(node_at(p+Vector3i.UP))
		if (hooks|above) & HOOK_SNOW: snow_updates[p] = true
		if (hooks|above) & HOOK_FOOD: food_updates[p] = true
		if hooks & HOOK_FIRE or bits & NodeInfo.BASE_LAVA: Fire.track(self,p)
		if hooks & HOOK_CAMPFIRE: Campfires.station(self,p)
		if hooks & HOOK_SIGN: Signs.station(self,p); sign_updates[p] = true
		if id == VillageContent.CAULDRON: Cauldrons.station(self,p)
		if hooks & HOOK_CONDUIT: Conduits.registered(self,p)
		if hooks & HOOK_CORAL: Corals.registered(self,p,id)
		if hooks & HOOK_PICKLE: SeaPickles.registered(self,p,id)
		if hooks & HOOK_KELP: Kelp.registered(self,p,id)
		if hooks & HOOK_BEACON: Beacons.registered(self,p,id)
		if bits & (NodeInfo.BASE_WATER|NodeInfo.BASE_LAVA): react_fluid(p); fluids.activate(p)
		if bits & NodeInfo.FUEL:
			for side in SIDES: Fire.track(self,p+side)
	# Validate after reconciling all edits. Removing support can write new edits,
	# so it must run outside the dictionary iteration above.
	for p in snow_updates: SnowCover.changed(self,p)
	for p in sign_updates: Signs.validate_support(self,p)
	for p in food_updates: FoodFeatures.changed(self,p)
	for p in fruit_updates: FruitCrops.refresh(self,p)
	Farmland.column_loaded(self,c)
	CropFarming.column_loaded(self,c)
	Amethyst.column_loaded(self,c)
	Copper.column_loaded(self,c)
	Sponges.column_loaded(self,c)
	for p in legacy_doors: Doors.migrate_at(self,p)
	for p in input_updates: RedstoneInputs.migrate_at(self,p)
	for p in input_updates: RedstoneInputs.support_changed(self,p)
	# A previously unloaded support column can invalidate a boundary attachment.
	for p in circuits.tracked.keys():
		var input_id: int = node_at(p)
		if not RedstoneInputs.is_device(input_id): continue
		var support_cell: Vector3i = p+RedstoneInputs.support(input_id)
		if Vector2i(floori(support_cell.x/16.0),floori(support_cell.z/16.0)) == c: RedstoneInputs.support_changed(self,p)
	fluids.column_loaded(c)
	column_loaded.emit()

func _apply_mesh(coord: Vector3i, surfaces: Array) -> void:
	unmeshed.erase(coord)
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
	Pasture.column_unloaded(self,c)
	SnowCover.unload(self,c)
	WoodTypes.unload(self,c)
	Jukeboxes.unload(self,c)
	Dungeons.unload(self,c)
	Farmland.unload(self,c)
	CropFarming.unload(self,c)
	FruitCrops.unload(self,c)
	Amethyst.unload(self,c)
	Beehives.unload(self,c)
	Copper.unload(self,c)
	Sponges.unload(self,c)
	Concrete.unload(self,c)
	EndMud.unload(self,c)
	LushCaveExtra.unload(self,c)
	PaleOak.unload(self,c)
	sky_revision += 1
	columns.erase(c)
	for p in hazards.keys():
		if block_coord(p).x == c.x and block_coord(p).z == c.y: hazards.erase(p)
	circuits.unload(c)
	for b in column_blocks.get(c,[]):
		if not blocks.has(b): continue
		blocks[b].root.queue_free(); blocks.erase(b); dirty.erase(b); unmeshed.erase(b); partial.erase(b)
	column_blocks.erase(c)

func _index_block(coord: Vector3i) -> void:
	var column := Vector2i(coord.x,coord.z)
	if not column_blocks.has(column): column_blocks[column] = []
	column_blocks[column].append(coord)

static func block_coord(p: Vector3i) -> Vector3i:
	return Vector3i(floori(p.x/16.0),floori(p.y/16.0),floori(p.z/16.0))

static func local_index(p: Vector3i) -> int:
	return posmod(p.x,16) + posmod(p.z,16)*16 + posmod(p.y,16)*256

# The hottest lookup in the game: collision, AI, light and fluids all use it.
# Shifts and masks are exact floor division and modulo by 16 for negatives too.
func node_at(p: Vector3i) -> int:
	if p.x < WorldBounds.MIN_XZ or p.x > WorldBounds.MAX_XZ or p.z < WorldBounds.MIN_XZ or p.z > WorldBounds.MAX_XZ: return Nodes.BEDROCK
	if p.y < generator.floor_y: return Nodes.AIR if dimension == "end" else Nodes.BEDROCK
	if p.y >= generator.top_y: return Nodes.BEDROCK
	var block: Variant = blocks.get(Vector3i(p.x >> 4,p.y >> 4,p.z >> 4))
	if block != null: return block.data[(p.x & 15)+(p.z & 15)*16+(p.y & 15)*256]
	if p.y >= generator.ceiling_y and columns.has(Vector2i(p.x >> 4,p.z >> 4)): return Nodes.AIR
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
	if old_id != id and old_id in [VillageContent.COMPOSTER,VillageContent.CAULDRON]: stations.erase(station_key(p))
	if old_id != id: sky_revision += 1
	blocks[b].data[local_index(p)] = id
	Campfires.changed(self,p,old_id,id)
	Dripping.changed(self,p,old_id,id)
	Dungeons.changed(self,p,old_id,id)
	WoodTypes.changed(self,p,old_id,id)
	Scaffolding.changed(self,p,old_id,id)
	Pasture.changed(self,p)
	if id == VillageContent.CAULDRON: Cauldrons.station(self,p)
	Fire.track(self,p)
	if Fire.flammable(id) or Fire.flammable(old_id):
		for side in Fire.SIDES: Fire.track(self,p+side)
	circuits.changed(p,old_id,id)
	record_edit(p,id)
	if id == Nodes.SUGAR_CANE or WoodTypes.is_sapling(id) or not CropFarming.is_crop(id) and VillageContent.shape(id) == "crop" and VillageContent.DATA[id].stage < 3: growth[p] = 0.0
	else: growth.erase(p)
	_mark_dirty(p)
	if Barriers.is_wall(node_at(p+Vector3i.DOWN)): _mark_dirty(p+Vector3i.DOWN)
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
	SnowCover.changed(self,p)
	FoodFeatures.changed(self,p)
	Signs.changed(self,p,old_id,id)
	Jukeboxes.changed(self,p,old_id,id)
	Farmland.changed(self,p,old_id,id)
	CropFarming.changed(self,p,old_id,id)
	FruitCrops.changed(self,p,old_id,id)
	Amethyst.changed(self,p,old_id,id)
	Concrete.changed(self,p,old_id,id)
	EndMud.changed(self,p,old_id,id)
	PaleOak.changed(self,p,old_id,id)
	Beehives.changed(self,p,old_id,id)
	Copper.changed(self,p,old_id,id)
	Copper.support_changed(self,p)
	Rails.support_changed(self,p)
	Sponges.changed(self,p,old_id,id)
	Decor.changed(self,p,old_id,id)
	return true

func _create_air_block(coord: Vector3i) -> void:
	var root := Node3D.new(); root.name = "SkyBlock_%d_%d_%d"%[coord.x,coord.y,coord.z]
	root.position = Vector3(coord*16); add_child(root)
	var data := PackedInt32Array(); data.resize(4096)
	blocks[coord] = {"data":data,"root":root,"meshes":[]}
	_index_block(coord)

func _mark_dirty(p: Vector3i) -> void:
	dirty[block_coord(p)] = true
	for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]:
		if block_coord(p+d) != block_coord(p): dirty[block_coord(p+d)] = true

func _snapshot(coord: Vector3i) -> PackedInt32Array:
	# Resolve the 27 blocks once. Missing neighbours remain invisible (air),
	# while the bottom world boundary still occludes faces.
	var near: Array = []
	near.resize(27)
	for dy in range(-1,2):
		for dz in range(-1,2):
			for dx in range(-1,2):
				var b: Vector3i = coord+Vector3i(dx,dy,dz)
				near[(dx+1)+(dz+1)*3+(dy+1)*9] = blocks[b].data if blocks.has(b) else PackedInt32Array()
	var air_row := PackedInt32Array()
	air_row.resize(16)
	var rock_row := PackedInt32Array()
	rock_row.resize(16)
	rock_row.fill(Nodes.BEDROCK)
	# Each padded row is a left halo node, sixteen contiguous nodes of the middle
	# block and a right halo node.
	var data := PackedInt32Array()
	for y in 18:
		var dy: int = -1 if y == 0 else (1 if y == 17 else 0)
		var below_world: bool = coord.y*16+y-1 <= generator.min_y() and dimension != "end"
		var fill: int = Nodes.BEDROCK if below_world else Nodes.AIR
		var fill_row: PackedInt32Array = rock_row if below_world else air_row
		for z in 18:
			var dz: int = -1 if z == 0 else (1 if z == 17 else 0)
			var row: int = ((z+15)%16)*16+((y+15)%16)*256
			var slot: int = (dz+1)*3+(dy+1)*9
			var left: PackedInt32Array = near[slot]
			var middle: PackedInt32Array = near[slot+1]
			var right: PackedInt32Array = near[slot+2]
			data.append(fill if left.is_empty() else left[row+15])
			data.append_array(fill_row if middle.is_empty() else middle.slice(row,row+16))
			data.append(fill if right.is_empty() else right[row])
	return data

func collision_boxes(p: Vector3i) -> Array:
	var id: int = node_at(p)
	if Candles.is_candle(id): return Candles.boxes(id)
	if Candles.is_cake(id): return Candles.boxes(Candles.FIRST)
	if Farmland.is_soil(id): return Farmland.boxes(id)
	if Amethyst.is_crystal(id): return Amethyst.boxes(id)
	if Copper.is_rod(id): return Copper.boxes(id)
	if SnowCover.is_snow(id): return SnowCover.boxes(id)
	if FoodFeatures.is_cake(id): return FoodFeatures.boxes(id)
	if Doors.is_door(id): return Doors.boxes(id)
	if Trapdoors.is_trapdoor(id): return Trapdoors.boxes(id)
	if Barriers.is_barrier(id): return Barriers.world_boxes(self,p,true)
	if id == VillageContent.CAULDRON: return Cauldrons.boxes()
	# A chain is a sixteenth of a block wide, so it must not block movement like a
	# full cube. Without this it would be an invisible wall down the middle of a tile.
	if Lanterns.is_chain(id): return [AABB(Vector3(0.5-Lanterns.CHAIN_WIDTH,0,0.5-Lanterns.CHAIN_WIDTH),Vector3(Lanterns.CHAIN_WIDTH*2,1.0,Lanterns.CHAIN_WIDTH*2))]
	# A bamboo stalk is a narrow column, so it must not block movement as a cube.
	if Bamboo.is_bamboo(id): return [AABB(Vector3(0.5-Bamboo.STALK_WIDTH,0,0.5-Bamboo.STALK_WIDTH),Vector3(Bamboo.STALK_WIDTH*2,1.0,Bamboo.STALK_WIDTH*2))]
	if RedstoneSensors.is_detector(id): return RedstoneSensors.boxes(id)
	if Campfires.is_campfire(id): return Campfires.boxes(id)
	if BuildingShapes.is_shape(id): return BuildingShapes.boxes(BuildingShapes.world_mask(self,p))
	return [AABB(Vector3.ZERO,Vector3.ONE)] if Nodes.solid(id) else []

func intersects(pos: Vector3, half_width: float = 0.29, height: float = 1.8) -> bool:
	var lo := Vector3i(floori(pos.x-half_width),floori(pos.y+0.002),floori(pos.z-half_width))
	var hi := Vector3i(floori(pos.x+half_width),floori(pos.y+height-0.002),floori(pos.z+half_width))
	var body := AABB(pos-Vector3(half_width,-0.002,half_width),Vector3(half_width*2,height-0.004,half_width*2))
	# Read the shared trait table directly; a miss falls back to NodeInfo.
	var traits: PackedInt32Array = NodeInfo.traits if NodeInfo.cached() else PackedInt32Array()
	var known: int = traits.size()
	# Inside the world's bounds, read each map block's nodes directly; a body
	# almost always spans one or two blocks. Elsewhere node_at decides.
	var direct: bool = lo.x >= WorldBounds.MIN_XZ and hi.x <= WorldBounds.MAX_XZ and lo.z >= WorldBounds.MIN_XZ and hi.z <= WorldBounds.MAX_XZ and lo.y-1 >= generator.floor_y and hi.y < generator.top_y
	var block_key := Vector3i(2147483647,0,0)
	var block_data := PackedInt32Array()
	# Fences/walls extend into the cell above; include that lower cell even when
	# the actor's feet have left it. Ordinary cubes do not need the extra scan.
	for y in range(lo.y-1,hi.y+1):
		for z in range(lo.z,hi.z+1):
			for x in range(lo.x,hi.x+1):
				var id: int
				if direct:
					var key := Vector3i(x >> 4,y >> 4,z >> 4)
					if key != block_key:
						block_key = key
						var block: Variant = blocks.get(key)
						block_data = block.data if block != null else PackedInt32Array()
					id = block_data[(x & 15)+(z & 15)*16+(y & 15)*256] if not block_data.is_empty() else node_at(Vector3i(x,y,z))
				else: id = node_at(Vector3i(x,y,z))
				var bits: int = traits[id] if id >= 0 and id < known else 0
				if bits == 0: bits = NodeInfo.of(id)
				if bits & NodeInfo.SOLID == 0: continue
				if bits & NodeInfo.BOX:
					# Only fences and walls reach up from the cell below the feet.
					if y < lo.y: continue
					if body.position.x < x+1 and body.end.x > x and body.position.y < y+1 and body.end.y > y and body.position.z < z+1 and body.end.z > z: return true
					continue
				if y < lo.y and not Barriers.is_barrier(id): continue
				var p := Vector3i(x,y,z)
				for box in collision_boxes(p):
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
			if RedstoneInputs.is_device(id) or BuildingShapes.is_shape(id) or Fluids.flowing(id) or Campfires.is_campfire(id) or Barriers.is_barrier(id) or RedstoneSensors.is_detector(id) or Trapdoors.is_trapdoor(id) or SnowCover.is_snow(id) or Doors.is_door(id) or FoodFeatures.is_cake(id) or Signs.is_sign(id) or CropFarming.is_crop(id) or Farmland.is_soil(id) or FruitCrops.is_stem(id) or Amethyst.is_crystal(id):
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
	if Campfires.is_campfire(id): boxes = Campfires.boxes(id)
	if Barriers.is_barrier(id): boxes = Barriers.world_boxes(self,p,false,true)
	if RedstoneSensors.is_detector(id): boxes = RedstoneSensors.boxes(id)
	if Amethyst.is_crystal(id): boxes = Amethyst.boxes(id)
	elif Copper.is_rod(id): boxes = Copper.boxes(id)
	elif CropFarming.is_crop(id): boxes = CropFarming.boxes(id)
	elif Farmland.is_soil(id): boxes = Farmland.boxes(id)
	elif FruitCrops.is_stem(id): boxes = FruitCrops.boxes(id)
	elif FoodFeatures.is_cake(id): boxes = FoodFeatures.boxes(id)
	elif Doors.is_door(id): boxes = Doors.boxes(id)
	elif Trapdoors.is_trapdoor(id): boxes = Trapdoors.boxes(id)
	if SnowCover.is_snow(id): boxes = SnowCover.boxes(id,false)
	if id == VillageContent.GLASS_PANE or GlassColors.is_stained_pane(id):
		boxes = [AABB(Vector3(0.5-PANE_HALF_WIDTH,0.0,0.5-PANE_HALF_WIDTH),Vector3(PANE_HALF_WIDTH*2,1.0,PANE_HALF_WIDTH*2))]
	if Candles.is_candle(id): boxes = Candles.boxes(id)
	if Candles.is_cake(id): boxes = Candles.boxes(Candles.FIRST)
	if Signs.is_sign(id): boxes = Signs.boxes(id)
	if RedstoneInputs.is_device(id): boxes = RedstoneInputs.boxes(id,circuits.state(p))
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
		if CropFarming.is_crop(id): growth.erase(p); continue # Retire legacy crop timers after loading old saves.
		if VillageContent.shape(id) == "crop" and growth[p] >= 30:
			if VillageContent.DATA[id].stage < 3: set_node(p,id+1)
		elif WoodTypes.is_sapling(id):
			WoodTypes.sapling_tick(self,p)
		elif Bamboo.is_bamboo(id) and growth[p] > 90:
			growth[p] = 0.0
			# A stalk grows one segment per tick, up to its own height, and only when
			# the light above it is enough.
			var bamboo_rng := RandomNumberGenerator.new()
			bamboo_rng.seed = generator.hash_at(p.x,p.y,p.z)
			Bamboo.grow(self,generator,p,func(q: Vector3i) -> int: return Pasture.light(self,q,14),bamboo_rng)
		elif id == Nodes.SUGAR_CANE and growth[p] > 60:
			growth[p] = 0.0
			var bottom: Vector3i = p
			while node_at(bottom+Vector3i.DOWN) == Nodes.SUGAR_CANE: bottom += Vector3i.DOWN
			if p.y-bottom.y < 2 and node_at(p+Vector3i.UP) == Nodes.AIR and can_plant_cane(bottom):
				set_node(p+Vector3i.UP,Nodes.SUGAR_CANE)
	for key in stations:
		var s: Dictionary = stations[key]
		if s.get("kind","") == "brewing":
			if Brewing.step(s,1.0):
				var owner: Node = get_parent()
				if owner != null and owner.has_method("toast"): owner.achievements.award("local_brewery")
			continue
		if s.get("kind","") != "furnace": continue
		var input: Dictionary = s.slots[0]
		var fuel: Dictionary = s.slots[1]
		var output: Dictionary = s.slots[2]
		var recipe: int = Nodes.smelt_result(input.id)
		if Campfires.is_campfire(int(s.get("device",0))): continue
		if s.get("device",0) == VillageContent.SMOKER and Nodes.food(recipe) <= 0: recipe = 0
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
			# Source `_mcl_cooking_replacements`: drying a wet sponge pours its
			# water into an empty bucket sitting in the fuel slot.
			var replacement: int = Sponges.cooking_replacement(input.id) if fuel.id == Nodes.BUCKET and fuel.count == 1 else 0
			input.count -= 1
			if replacement != 0:
				fuel.id = replacement
				fuel.wear = 0
			if input.count <= 0: input.id = 0
			output.id = recipe
			output.count += 1
			# `delicious_fish`: the source's award for cooking a fish.
			if recipe in [VillageContent.COOKED_COD,VillageContent.COOKED_SALMON]:
				var fish_owner: Node = get_parent()
				if fish_owner != null and fish_owner.has_method("toast"): fish_owner.achievements.award("delicious_fish")

func can_plant_cane(p: Vector3i) -> bool:
	var soil: Vector3i = p+Vector3i.DOWN
	if node_at(soil) == Nodes.SUGAR_CANE: return true
	if node_at(soil) not in [Nodes.DIRT,Nodes.GRASS,Nodes.SAND]: return false
	for side in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		if Fluids.water(node_at(soil+side)): return true
	return false

func grow_tree(p: Vector3i) -> void:
	WoodTypes.grow(self,p)

# A pane's half width, from the source's `pane_nodebox` (-1/16 .. 1/16).
const PANE_HALF_WIDTH = 0.0625

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
	if Campfires.is_campfire(node_at(p)): return Campfires.station(self,p)
	if PortableStorage.is_shulker(node_at(p)): return PortableStorage.station(self,p)
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
			if stations[single_key].get("dungeon_loot",false): station.dungeon_loot = true; station.label = stations[single_key].label
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
				record_edit(cell,Nodes.AIR)
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
			if not Nodes.solid(support) or WoodTypes.is_log(support) or WoodTypes.is_leaves(support): continue
			if node_at(feet) != Nodes.AIR or node_at(feet+Vector3i.UP) != Nodes.AIR: continue
			var pos := Vector3(x+0.5,y+0.01,z+0.5)
			if not intersects(pos): return pos
	return Vector3.INF

func _structure_loot(p: Vector3i, dungeon_seed: int = -1, corridor: bool = false, treasure: bool = false, wreck: bool = false, temple: bool = false, portal: bool = false, jungle: bool = false, outpost: bool = false, igloo: bool = false, monument: bool = false, cabin: bool = false) -> void:
	var initialized: Dictionary = _structure_loot_ledger()
	var key: String = station_key(p)
	if initialized.has(key): return
	if stations.has(key): initialized[key] = true; return
	var partner: Vector3i = chest_partner(p)
	var shared: String = pair_key(p,partner) if partner != p else ""
	if not shared.is_empty() and stations.has(shared):
		# A legacy pair predating per-half markers is already player storage,
		# including an empty/fully looted pair. Never infer emptiness as new loot.
		if not initialized.has(station_key(partner)):
			initialized[key] = true; initialized[station_key(partner)] = true; return
		var offset: int = 0 if chest_primary(p,partner) == p else 27
		for slot in stations[shared].slots.slice(offset,offset+27):
			if int(slot.get("count",0)) > 0: initialized[key] = true; return
	# Every generated half rolls its own source27-slot inventory before any
	# merging. A54-slot container must never be filled wholesale a second time.
	var station: Dictionary = _new_station("chest",27)
	if treasure:
		BuriedTreasure.fill(station,generator.hash_at(p.x,20141,p.z)); _store_structure_loot(p,station,shared); return
	if corridor:
		Corridors.fill_chest(station,generator.hash_at(p.x,20137,p.z)); _store_structure_loot(p,station,shared); return
	if wreck:
		Shipwrecks.fill_chest(station,generator.hash_at(p.x,20161,p.z)); _store_structure_loot(p,station,shared); return
	if temple:
		DesertTemples.fill_chest(station,generator.hash_at(p.x,20183,p.z)); _store_structure_loot(p,station,shared); return
	if portal:
		RuinedPortals.fill_chest(station,generator.hash_at(p.x,20191,p.z)); _store_structure_loot(p,station,shared); return
	if jungle:
		JungleTemples.fill_chest(station,generator.hash_at(p.x,20203,p.z)); _store_structure_loot(p,station,shared); return
	if outpost:
		PillagerOutposts.fill_chest(station,generator.hash_at(p.x,20221,p.z)); _store_structure_loot(p,station,shared); return
	if igloo:
		Igloos.fill_chest(station,generator.hash_at(p.x,20237,p.z)); _store_structure_loot(p,station,shared); return
	if monument:
		OceanTemples.fill_chest(station,generator.hash_at(p.x,20263,p.z)); _store_structure_loot(p,station,shared); return
	if cabin:
		WoodlandCabins.fill_chest(station,generator.hash_at(p.x,20277,p.z)); _store_structure_loot(p,station,shared); return
	if dungeon_seed >= 0:
		Dungeons.fill(station,dungeon_seed); _store_structure_loot(p,station,shared); return
	if dimension == "nether" and not Bastions.at(generator,p).is_empty():
		Bastions.fill(station,generator.hash_at(p.x,p.y,p.z)); _store_structure_loot(p,station,shared); return
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
		if dimension == "overworld":
			for record in Jukeboxes.stronghold_records(rng):
				for index in station.slots.size():
					if int(station.slots[index].count) <= 0: station.slots[index] = record; break

	_store_structure_loot(p,station,shared)

func _structure_loot_ledger() -> Dictionary:
	if not adventure_state.get("structure_loot",null) is Dictionary:
		var initialized: Dictionary = {}
		# Migration protects every existing single or double chest, even empty
		# ones, before generation can rediscover their natural positions.
		for key in stations:
			if stations[key].get("kind","") != "chest": continue
			for half in str(key).split("+"): initialized[half] = true
		adventure_state.structure_loot = initialized
	return adventure_state.structure_loot

func _store_structure_loot(p: Vector3i, station: Dictionary, shared: String) -> void:
	_structure_loot_ledger()[station_key(p)] = true
	if not shared.is_empty() and stations.has(shared):
		var partner: Vector3i = chest_partner(p)
		var offset: int = 0 if chest_primary(p,partner) == p else 27
		for i in 27: stations[shared].slots[offset+i] = station.slots[i]
		if station.get("dungeon_loot",false): stations[shared].dungeon_loot = true; stations[shared].label = station.label
	else: stations[station_key(p)] = station

func open_sky(p: Vector3i) -> bool:
	if dimension != "overworld": return false
	for y in range(p.y+2,mini(generator.terrain_ceiling(),generator.max_y())):
		if Nodes.solid(node_at(Vector3i(p.x,y,p.z))): return false
	for point in column_edits(Vector2i(floori(p.x/16.0),floori(p.z/16.0))):
		if point.x == p.x and point.z == p.z and point.y > p.y+1 and Nodes.solid(edits[point]): return false
	return true

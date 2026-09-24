class_name Pasture
extends RefCounted

# Mineclonia mcl_core/functions.lua grass ABMs: loaded simulation, no catch-up.
const SPREAD_INTERVAL = 30.0
const SPREAD_CHANCE = 20
const DECAY_INTERVAL = 8.0
const DECAY_CHANCE = 50
const TRACKED = {Nodes.GRASS:true,Nodes.DIRT:true,VillageContent.SWAMP_GRASS:true,Nodes.TORCH:true,1119:true,1120:true,1121:true,1122:true,Nodes.GLOWSTONE:true,Nodes.SHROOMLIGHT:true,VillageContent.LANTERN:true,Nodes.END_ROD:true,Nodes.SOUL_TORCH:true,Nodes.REDSTONE_LAMP:true,Nodes.REDSTONE_TORCH:true,Nodes.LAVA:true,Fire.FLAME:true,Fire.ETERNAL:true,Campfires.LIT:true,Campfires.UNLIT:true,Campfires.SOUL_LIT:true,Campfires.SOUL_UNLIT:true,Bastions.CRYING_OBSIDIAN:true,Nodes.NETHER_PORTAL:true,Nodes.END_PORTAL:true,Nodes.FURNACE:true,VillageContent.SMOKER:true,VillageContent.BLAST_FURNACE:true,VillageContent.CAULDRON:true,9540:true,9541:true,9542:true,9543:true,9544:true,9545:true,9546:true,9547:true,9554:true,9555:true,9556:true,9557:true}
const STATEFUL_LIGHTS = [Nodes.REDSTONE_LAMP,Nodes.REDSTONE_TORCH,Nodes.FURNACE,VillageContent.SMOKER,VillageContent.BLAST_FURNACE,VillageContent.CAULDRON,9544,9545,9546,9547,9554,9555,9556,9557]
const SIDES = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]

static func is_grass(id: int) -> bool: return id in [Nodes.GRASS,VillageContent.SWAMP_GRASS]

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("pasture"): world.remove_meta("pasture")

static func state(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("pasture"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value
		world.set_meta("pasture",{"cells":{},"cell_columns":{},"lights":{},"light_blocks":{},"light_columns":{},"spread_clock":0.0,"decay_clock":0.0,"jobs":[],"cursor":0,"scans":[],"rng":rng})
	return world.get_meta("pasture")

static func opaque(id: int) -> bool:
	if Fluids.liquid(id): return false
	return RedstoneSensors.light_filter(id) < 0

static func covered(world: VoxelWorld, p: Vector3i) -> bool:
	return NodeInfo.of(world.node_at(p+Vector3i.UP)) & NodeInfo.COVER != 0

# Light from a node id alone. A few lights also depend on live state; they
# report STATEFUL and are resolved by `emission`. Memoized on the main thread.
const STATEFUL = -1
static var emission_memo: Dictionary = {}

static func emission(world: VoxelWorld, p: Vector3i) -> int:
	var id: int = world.node_at(p)
	var level: int = id_emission(id)
	if level != STATEFUL: return level
	if id == Nodes.REDSTONE_LAMP: return 14 if world.circuits.state(p).get("powered",false) else 0
	if id == Nodes.REDSTONE_TORCH: return int(world.circuits.state(p).get("out",0))/2
	if id in [Nodes.FURNACE,VillageContent.SMOKER,VillageContent.BLAST_FURNACE]:
		return 13 if float(world.stations.get(world.station_key(p),{}).get("burn",0.0)) > 0 else 0
	return 14 if Cauldrons.liquid(world.stations.get(world.station_key(p),{})) == "lava" else 0

static func id_emission(id: int) -> int:
	if not NodeInfo.cached(): return _id_emission(id)
	var known: Variant = emission_memo.get(id)
	if known != null: return known
	var level: int = _id_emission(id)
	emission_memo[id] = level
	return level

static func _id_emission(id: int) -> int:
	if FruitCrops.lit(id): return 14
	if Amethyst.is_crystal(id): return Amethyst.light_level(id)
	if Copper.is_bulb(id): return Copper.light_level(id)
	if Copper.rod_powered_light(id): return 14
	if Torches.is_torch(id): return 14
	if Beacons.is_beacon(id) or Beacons.is_beam(id): return 15
	if SeaPickles.is_pickle(id): return SeaPickles.light_level(id)
	if id == VillageContent.CONDUIT or id == VillageContent.SEA_LANTERN: return 15
	if id in [Nodes.GLOWSTONE,Nodes.SHROOMLIGHT,VillageContent.LANTERN] or Fluids.lava(id) or Fire.is_fire(id): return 14
	if id == Nodes.END_ROD: return 14
	if id == Nodes.SOUL_TORCH: return 10
	# A soul lantern is lit at the source's own dimmer level, and would otherwise
	# emit nothing despite being a light source.
	if Lanterns.is_soul_lantern(id): return Lanterns.SOUL_LIGHT
	# A lit candle stack is `light_source = 3 * n`, so the count is the light.
	if Candles.is_lit(id): return Candles.light_level(id)
	# A soul flame carries the source's `light_source = 10`.
	if NetherBlocks.light_level(id) > 0: return NetherBlocks.light_level(id)
	if CrimsonPlants.light_level(id) > 0: return CrimsonPlants.light_level(id)
	if CopperDecor.light_level(id) > 0: return CopperDecor.light_level(id)
	# A firefly bush is the source's `light_source = 2`.
	if FlowersExtra.light_level(id) > 0: return FlowersExtra.light_level(id)
	if Sculk.light_level(id) > 0: return Sculk.light_level(id)
	# A lit cave vine is a light source, which is what makes a lush cave visible.
	if LushCaves.is_lit_vine(id): return LushCaves.LIT_LIGHT
	if id == Bastions.CRYING_OBSIDIAN: return 10
	if id == Nodes.NETHER_PORTAL: return 11
	if id == Nodes.END_PORTAL: return 14
	if Campfires.is_campfire(id): return Campfires.light_level(id)
	if id in [Nodes.REDSTONE_LAMP,Nodes.REDSTONE_TORCH,Nodes.FURNACE,VillageContent.SMOKER,VillageContent.BLAST_FURNACE,VillageContent.CAULDRON]: return STATEFUL
	return 0

static func track(world: VoxelWorld, p: Vector3i) -> void:
	var data: Dictionary = state(world)
	if not world.loaded_at(Vector3(p)):
		remove_cell(data,p); remove_light(data,p); return
	var id: int = world.node_at(p)
	if is_grass(id) or id == Nodes.DIRT and not covered(world,p): add_cell(data,p)
	elif data.cells.has(p): remove_cell(data,p)
	# Retain switchable nodes while off/empty; sample their live metadata.
	if id in STATEFUL_LIGHTS or emission(world,p) > 0:
		add_light(data,p)
	elif data.lights.has(p): remove_light(data,p)

static func add_cell(data: Dictionary, p: Vector3i) -> void:
	data.cells[p] = true
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not data.cell_columns.has(column): data.cell_columns[column] = {}
	data.cell_columns[column][p] = true

static func remove_cell(data: Dictionary, p: Vector3i) -> void:
	data.cells.erase(p)
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if data.cell_columns.has(column):
		data.cell_columns[column].erase(p)
		if data.cell_columns[column].is_empty(): data.cell_columns.erase(column)

static func add_light(data: Dictionary, p: Vector3i) -> void:
	data.lights[p] = true
	var block: Vector3i = VoxelWorld.block_coord(p)
	if not data.light_blocks.has(block): data.light_blocks[block] = {}
	data.light_blocks[block][p] = true
	var column := Vector2i(block.x,block.z)
	if not data.light_columns.has(column): data.light_columns[column] = {}
	data.light_columns[column][block] = true

static func remove_light(data: Dictionary, p: Vector3i) -> void:
	data.lights.erase(p)
	var block: Vector3i = VoxelWorld.block_coord(p)
	if data.light_blocks.has(block):
		data.light_blocks[block].erase(p)
		if data.light_blocks[block].is_empty():
			data.light_blocks.erase(block)
			var column := Vector2i(block.x,block.z)
			if data.light_columns.has(column):
				data.light_columns[column].erase(block)
				if data.light_columns[column].is_empty(): data.light_columns.erase(column)

static func nearby_lights(world: VoxelWorld, p: Vector3i) -> Array:
	var data: Dictionary = state(world); var found: Array = []
	var center: Vector3i = VoxelWorld.block_coord(p)
	for y in range(-1,2):
		for z in range(-1,2):
			for x in range(-1,2):
				var block: Vector3i = center+Vector3i(x,y,z)
				if data.light_blocks.has(block): found.append_array(data.light_blocks[block].keys())
	return found

static func changed(world: VoxelWorld, p: Vector3i) -> void:
	track(world,p); track(world,p+Vector3i.DOWN)

static func column_loaded(world: VoxelWorld, column: Vector2i, candidates: Dictionary = {}) -> void:
	# Worker candidates are already exposed and in this column. Recheck only
	# edits that may have changed since that snapshot; terrain needs no lookup.
	var data: Dictionary = state(world)
	for p in candidates:
		var block: Vector3i = VoxelWorld.block_coord(p)
		if block.x != column.x or block.z != column.y: continue
		var id: int = int(candidates[p])
		if world.edits.has(p) or world.edits.has(p+Vector3i.UP): track(world,p); continue
		if is_grass(id) or id == Nodes.DIRT: add_cell(data,p)
		elif id not in [Campfires.UNLIT,Campfires.SOUL_UNLIT]: add_light(data,p)

# The worker's pre-split membership for a freshly generated column, merged
# whole. The caller re-tracks cells touched by later edits afterwards.
static func column_generated(world: VoxelWorld, column: Vector2i, cells: Dictionary, lights: Dictionary) -> void:
	var data: Dictionary = state(world)
	if not cells.is_empty():
		data.cells.merge(cells)
		if data.cell_columns.has(column): data.cell_columns[column].merge(cells)
		else: data.cell_columns[column] = cells
	if lights.is_empty(): return
	if not data.light_columns.has(column): data.light_columns[column] = {}
	for block in lights:
		data.lights.merge(lights[block])
		if data.light_blocks.has(block): data.light_blocks[block].merge(lights[block])
		else: data.light_blocks[block] = lights[block]
		data.light_columns[column][block] = true

static func column_unloaded(world: VoxelWorld, column: Vector2i) -> void:
	var data: Dictionary = state(world)
	# A streaming edge can unload a whole row at once. Touch only membership
	# belonging to this column, never every loaded grass/light position.
	for p in data.cell_columns.get(column,{}): data.cells.erase(p)
	data.cell_columns.erase(column)
	for block in data.light_columns.get(column,{}):
		for p in data.light_blocks.get(block,{}): data.lights.erase(p)
		data.light_blocks.erase(block)
	data.light_columns.erase(column)

static func taxi(a: Vector3i, b: Vector3i) -> int:
	var gap: Vector3i = (a-b).abs()
	return gap.x+gap.y+gap.z

static func clear_light_path(world: VoxelWorld, a: Vector3i, b: Vector3i) -> bool:
	for axes in [[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]:
		var current: Vector3i = a; var clear: bool = true
		for axis in axes:
			while current[axis] != b[axis]:
				current[axis] += signi(b[axis]-current[axis])
				if current != b and RedstoneSensors.light_filter(world.node_at(current)) < 0: clear = false; break
			if not clear: break
		if clear: return true
	return false

static func block_light(world: VoxelWorld, p: Vector3i, required: int = 14) -> int:
	return light(world,p,required,false)

static func light(world: VoxelWorld, p: Vector3i, required: int = 14, include_sky: bool = true) -> int:
	if not world.loaded_at(Vector3(p)) or opaque(world.node_at(p)): return 0
	var best: int = RedstoneSensors.natural_light(world,p) if include_sky else 0
	if best >= required: return best
	var lamps: Dictionary = {}
	for lamp in nearby_lights(world,p):
		if 14-taxi(lamp,p) <= best: continue
		var power: int = emission(world,lamp)
		if power-taxi(lamp,p) <= best: continue
		if clear_light_path(world,p,lamp):
			best = maxi(best,power-taxi(lamp,p))
			if best >= required: return best
		else: lamps[lamp] = power
	if lamps.is_empty(): return best
	# Propagate block light along transparent voxel paths, including corners.
	var queue: Array = [p]; var distances: Dictionary = {p:0}; var cursor: int = 0
	while cursor < queue.size():
		var q: Vector3i = queue[cursor]; cursor += 1
		var distance: int = distances[q]
		if 14-distance <= best: break
		best = maxi(best,emission(world,q)-distance)
		if best >= required: return best
		for side in SIDES:
			var next: Vector3i = q+side
			if distances.has(next) or not world.loaded_at(Vector3(next)): continue
			var useful: bool = false
			for lamp in lamps:
				if int(lamps[lamp])-distance-1-taxi(lamp,next) > best: useful = true; break
			if not useful: continue
			var cost: int = RedstoneSensors.light_filter(world.node_at(next))
			if cost < 0:
				best = maxi(best,emission(world,next)-distance-1)
				continue
			distances[next] = distance+1; queue.append(next)
	return clampi(best,0,14)

static func sources(world: VoxelWorld, p: Vector3i) -> Array:
	var found: Array = []
	for y in range(-1,4):
		for z in range(-1,2):
			for x in range(-1,2):
				var q: Vector3i = p+Vector3i(x,y,z)
				if world.loaded_at(Vector3(q)) and is_grass(world.node_at(q)): found.append(q)
	return found

static func spread(world: VoxelWorld, p: Vector3i) -> bool:
	if not world.loaded_at(Vector3(p)) or world.node_at(p) != Nodes.DIRT or covered(world,p): return false
	var nearby: Array = sources(world,p)
	if nearby.is_empty() or light(world,p+Vector3i.UP,4) < 4: return false
	var rng: RandomNumberGenerator = state(world).rng
	var source: Vector3i = nearby[rng.randi_range(0,nearby.size()-1)]
	if light(world,source+Vector3i.UP,9) < 9: return false
	var grass: int = VillageContent.SWAMP_GRASS if "swamp" in world.generator.biome(p.x,p.z) else Nodes.GRASS
	return world.set_node(p,grass)

static func decay(world: VoxelWorld, p: Vector3i) -> bool:
	if not world.loaded_at(Vector3(p)) or not is_grass(world.node_at(p)) or not covered(world,p): return false
	return world.set_node(p,Nodes.DIRT)

static func update(world: VoxelWorld, delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	var data: Dictionary = state(world)
	data.spread_clock += delta; data.decay_clock += delta
	var spreading: bool = data.spread_clock >= SPREAD_INTERVAL
	var decaying: bool = data.decay_clock >= DECAY_INTERVAL
	if spreading: data.spread_clock = 0.0
	if decaying: data.decay_clock = 0.0
	if spreading or decaying:
		data.scans.append({"cells":data.cells.keys(),"cursor":0,"spread":spreading,"decay":decaying})
	# Scheduling itself used to walk the entire loaded surface in one frame.
	# Preserve every per-cell chance while processing the scan over frames.
	var rng: RandomNumberGenerator = data.rng
	for i in 256:
		if data.scans.is_empty() or i > 0 and Time.get_ticks_usec()-started >= 1500: break
		var scan: Dictionary = data.scans[0]
		if scan.cursor >= scan.cells.size(): data.scans.pop_front(); continue
		var p: Vector3i = scan.cells[scan.cursor]; scan.cursor += 1
		if not world.loaded_at(Vector3(p)): continue
		var id: int = world.node_at(p)
		if scan.spread and id == Nodes.DIRT and rng.randi_range(1,SPREAD_CHANCE) == 1: data.jobs.append({"p":p,"spread":true})
		elif scan.decay and is_grass(id) and covered(world,p) and rng.randi_range(1,DECAY_CHANCE) == 1: data.jobs.append({"p":p,"spread":false})
	# Include candidate scans in the budget; expensive light jobs remain few.
	for i in 4:
		if Time.get_ticks_usec()-started >= 3000: break
		if data.cursor >= data.jobs.size(): data.jobs.clear(); data.cursor = 0; break
		var job: Dictionary = data.jobs[data.cursor]; data.cursor += 1
		if job.spread: spread(world,job.p)
		else: decay(world,job.p)

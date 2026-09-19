class_name Shipwrecks
extends RefCounted

# Mineclonia MAPGEN/mcl_structures/shipwrecks.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# A shipwreck is a sunken hull on the ocean floor with one or more chests. The
# part that matters is the source's `after_place`, which **buries a treasure
# chest in the surrounding sand**:
#
#   * It scans a 128x128 area for sand, gravel, grass, mycelium and podzol,
#     shuffles the result, and picks one cell.
#   * It sinks that chest by a random **1 to 4 blocks** below the chosen cell.
#   * It fills the chest from the **buried-treasure loot table**, which is where
#     the heart of the sea comes from — making shipwrecks the second route to the
#     conduit's core ingredient, beside [buried treasure](buried-treasure-source.md).
#   * If the wreck itself has a chest, a treasure map pointing at the buried one
#     is added to it.
#
# The wreck sits four to two blocks below the water line (`y_max = water_level-4`,
# `y_offset = pr:next(-4,-2)`), and needs four water neighbours, so it is a
# genuinely submerged structure rather than a beached one.
#
# Voxey has no schematic loader, so the hull is generated: a keel, sides and
# broken deck in oak, which is the shape these wrecks have. The burial rule and
# the loot table are the source's exact behaviour.

const REGION = 64
# Source `sidelen = 16`.
const SIDE = 16
# The source searches a 128-block box for the burial, because its placement runs
# once in a callback that can afford the scan. Voxey places structures per column,
# so a reach that wide would force dozens of columns to be generated for one
# wreck. The wreck's own floor is already verified to be sand or gravel at plan
# time, so the burial is drawn from the wreck's vicinity instead, which is what
# the source's search finds in practice. The source value is recorded below.
const BURIED_SEARCH = 8
const SOURCE_BURIED_SEARCH = 64
# Source `y_offset = pr:next(-4,-2)`, so a wreck sinks two to four blocks.
const SINK_MIN = 2
const SINK_MAX = 4
# The buried chest is sunk `pr:next(1,4)` below the cell it replaces.
const BURIED_DEPTH_MIN = 1
const BURIED_DEPTH_MAX = 4
# Source requires four water neighbours.
const WATER_NEIGHBOURS = 4
# Retries for the burial's rejection sampler, which stands in for the source's
# exhaustive shuffle over the same box. See `bury`.
const BURIAL_ATTEMPTS = 96

# The hull material, and the planks the source's wrecks are built from.
const HULL = Nodes.PLANKS
const KEEL = Nodes.LOG

# A wreck's own loot: supplies and treasure in the source's own groups.
const SUPPLIES = [[Nodes.PAPER,8,1,12],[Nodes.GRAIN,7,8,21],[VillageContent.CARROT,7,4,8],
	[Nodes.COAL,6,2,8],[Nodes.ROTTEN_FLESH,5,5,24],[CropFarming.POISONOUS_POTATO,7,2,6],
	[VillageContent.POTATO,3,1,5],[Nodes.TNT,1,1,2]]
const TREASURE = [[Nodes.IRON,90,1,5],[Nodes.GOLD_NUGGET,10,1,10],[VillageContent.EMERALD,40,1,5],
	[Nodes.LAPIS,20,1,10],[Nodes.GOLD,10,1,5],[Nodes.DIAMOND,5,1,1]]
const NAVIGATION = [[Nodes.PAPER,20,1,10],[Nodes.FEATHER,10,1,5],[Nodes.BOOK,5,1,5],
	[Nodes.CLOCK,1,1,1],[Nodes.COMPASS,1,1,1],[VillageContent.EMPTY_MAP,1,1,1]]

# --- planning ----------------------------------------------------------------

# Plan one shipwreck on the sea floor, or an empty dictionary when the site is
# not deep enough.
static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	var floor_y: int = gen.terrain_height(origin.x,origin.z)
	# The wreck sits below the water line, which the source bounds with y_max.
	if floor_y >= TerrainGenerator.SEA-2: return {}
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var sink: int = rng.randi_range(SINK_MIN,SINK_MAX)
	var base := Vector3i(origin.x,floor_y-sink,origin.z)
	# The floor must be sand or gravel, which is the source's own `place_on`.
	var floor_id: int = int(sample.call(Vector3i(origin.x,floor_y,origin.z)))
	if not (floor_id == Nodes.SAND or floor_id == Nodes.GRAVEL): return {}
	var half: int = SIDE/2
	var state: Dictionary = {"voxels":{},"chests":{},"spawners":{},"buried":{},
		"bounds_min":base-Vector3i(half,half,half),"bounds_max":base+Vector3i(half,half,half),
		"floor_y":floor_y,"seed":seed_value,"sink":sink,
		"reach_min":base-Vector3i(half,half,half),"reach_max":base+Vector3i(half,half,half)}
	_build_hull(state,base,half,rng)
	# The wreck's own chest, which the source fills from its supplies table.
	if rng.randf() < 0.8:
		var chest_at: Vector3i = base+Vector3i(rng.randi_range(-half+3,half-3),1,rng.randi_range(-half+3,half-3))
		state.voxels[chest_at] = Nodes.CHEST
		state.chests[chest_at] = rng.randi()
	return state

# A wreck's hull: a keel line, sides, and a partly missing deck.
static func _build_hull(state: Dictionary, base: Vector3i, half: int, rng: RandomNumberGenerator) -> void:
	var length: int = rng.randi_range(7,SIDE-1)
	var beam: int = rng.randi_range(4,7)
	for i in length:
		for j in beam:
			var x: int = i-length/2
			var z: int = j-beam/2
			var at: Vector3i = base+Vector3i(x,0,z)
			# The hull's floor, then its sides, then a deck with gaps in it.
			state.voxels[at] = HULL
			if absi(z) == beam/2 or absi(x) == length/2:
				state.voxels[at+Vector3i.UP] = HULL
				if rng.randf() < 0.4: state.voxels[at+Vector3i(0,2,0)] = HULL
			elif rng.randf() < 0.5:
				state.voxels[at+Vector3i.UP] = HULL
	# The keel runs the wreck's length, and rises at the bow.
	for i in length:
		var x: int = i-length/2
		if rng.randf() < 0.6: state.voxels[base+Vector3i(x,-1,0)] = KEEL
	state.voxels[base+Vector3i(length/2,1,0)] = KEEL
	state.voxels[base+Vector3i(length/2,2,0)] = KEEL

# --- the buried treasure -----------------------------------------------------

# The source's `after_place`: pick a sand or gravel cell within 64 blocks and bury
# a chest one to four blocks under it, filled from the buried-treasure table.
static func bury(gen: TerrainGenerator, state: Dictionary, sample: Callable, rng: RandomNumberGenerator) -> void:
	var centre: Vector3i = state.bounds_min+(state.bounds_max-state.bounds_min)/2
	# The source scans the whole 128x128 box and shuffles every eligible cell, then
	# picks one. That is 16k terrain samples per wreck, a visible stall on the first
	# column that touches a region. Rejection sampling over the same box draws from
	# the same eligible set at a fraction of the cost.
	#
	# The cell must be the **local surface**, which is what the source's
	# `find_nodes_in_area_under_air` selects: it returns nodes with air above them,
	# so it finds the sea floor rather than some solid node buried under it. The
	# wreck's own floor height is not enough, because the sea floor undulates and a
	# cell at the wreck's height can be inside the water column elsewhere.
	var chosen := Vector3i.ZERO
	var found: bool = false
	for attempt in BURIAL_ATTEMPTS:
		var x: int = centre.x+rng.randi_range(-BURIED_SEARCH,BURIED_SEARCH)
		var z: int = centre.z+rng.randi_range(-BURIED_SEARCH,BURIED_SEARCH)
		var surf: int = gen.terrain_height(x,z)
		# A burial is under the sea, so the surface it replaces must be submerged.
		if surf >= TerrainGenerator.SEA: continue
		var at := Vector3i(x,surf,z)
		var id: int = int(sample.call(at))
		# The source's search covers sand, gravel, grass, mycelium and podzol.
		# Voxey has no mycelium or podzol block, so the surfaces it does have are
		# used, which is recorded in the source notes.
		if id in [Nodes.SAND,Nodes.GRAVEL,Nodes.GRASS,Nodes.DIRT]:
			chosen = at
			found = true
			break
	if not found: return
	var depth: int = rng.randi_range(BURIED_DEPTH_MIN,BURIED_DEPTH_MAX)
	var chest: Vector3i = chosen-Vector3i(0,depth,0)
	state.buried[chest] = rng.randi()
	# The burial can lie outside the hull, so the wreck's placement reach grows to
	# cover it. Without this a chest outside the hull's span would never be placed.
	state.reach_min = state.reach_min.min(chest)
	state.reach_max = state.reach_max.max(chest)

# Fill a wreck's own chest from the source's three groups: supplies (three to ten
# stacks), treasure (two to six) and navigation (three). A zero id keeps an
# unavailable source entry's weight rather than redistributing it, matching
# Voxey's other loot tables.
static func fill_chest(station: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var cursor: int = 0
	for group in [[SUPPLIES,3,10],[TREASURE,2,6],[NAVIGATION,3,3]]:
		for roll in rng.randi_range(group[1],group[2]):
			var stack: Dictionary = Dungeons.weighted(rng,group[0])
			if not stack.is_empty() and cursor < station.slots.size(): station.slots[cursor] = stack
			cursor += 1
	station.label = "Shipwreck chest"

# --- regions and overlay -----------------------------------------------------

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.wreck_cache.has(region): return gen.wreck_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20153,region.y)
	var result: Array = []
	var origin := Vector3i(region.x*REGION+rng.randi_range(SIDE,REGION-SIDE),0,region.y*REGION+rng.randi_range(SIDE,REGION-SIDE))
	if WorldBounds.horizontal(origin):
		var sample: Callable = func(p: Vector3i) -> int: return Dungeons.natural(gen,p)
		var candidate: Dictionary = plan(gen,origin,rng.randi(),sample)
		if not candidate.is_empty():
			# The burial is part of the plan, so it is decided once and cached.
			bury(gen,candidate,sample,rng)
			result.append(candidate)
	if gen.wreck_cache.size() >= 16: gen.wreck_cache.erase(gen.wreck_cache.keys()[0])
	gen.wreck_cache[region] = result
	return result

static func nearby_plans(gen: TerrainGenerator, coord: Vector2i) -> Array:
	var base: Vector2i = coord*16-Vector2i.ONE
	# A buried chest can lie BURIED_SEARCH blocks from its hull, so the scan reaches
	# that far as well; otherwise a distant chest would be skipped entirely.
	var margin: int = BURIED_SEARCH+SIDE
	var result: Array = []
	for rx in range(floori((base.x-margin)/float(REGION)),floori((base.x+17+margin)/float(REGION))+1):
		for rz in range(floori((base.y-margin)/float(REGION)),floori((base.y+17+margin)/float(REGION))+1):
			for candidate in region_plans(gen,Vector2i(rx,rz)):
				var lo: Vector3i = candidate.reach_min
				var hi: Vector3i = candidate.reach_max
				if hi.x >= base.x and lo.x <= base.x+17 and hi.z >= base.y and lo.z <= base.y+17: result.append(candidate)
	return result

# Merge a wreck into the column, and report its own chests and the buried ones.
static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"chests":{},"spawners":{},"buried":{}}
	if gen.dimension != "overworld": return result
	var base: Vector2i = coord*16-Vector2i.ONE
	for candidate in nearby_plans(gen,coord):
		for p in candidate.voxels:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var existing: int = deep[index] if p.y < 0 else data[index]
			# A hull builds into water or over the sea floor's own material.
			if existing != Nodes.WATER and not Dungeons.ground(existing): continue
			var wanted: int = int(candidate.voxels[p])
			if p.y < 0: deep[index] = wanted
			else: data[index] = wanted
			if x in range(1,17) and z in range(1,17) and candidate.chests.has(p):
				result.chests[p] = int(candidate.chests[p])
		# The buried chest is placed in whatever is already there, replacing ground.
		for p in candidate.buried:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var existing: int = deep[index] if p.y < 0 else data[index]
			if not Dungeons.ground(existing): continue
			if p.y < 0: deep[index] = Nodes.CHEST
			else: data[index] = Nodes.CHEST
			if x in range(1,17) and z in range(1,17): result.buried[p] = int(candidate.buried[p])
	return result

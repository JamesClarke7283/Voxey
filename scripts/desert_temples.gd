class_name DesertTemples
extends RefCounted

# Mineclonia MAPGEN/mcl_structures/desert_temple.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# A desert temple is a sandstone pyramid with a hidden vault under its floor. The
# source's `after_place` does three things, and the second is what matters:
#
#   1. It removes leftover cacti that sit on sandstone inside the footprint.
#   2. It converts up to **250** of the temple's own sand and sandstone cells into
#      **suspicious sand**, tagged with the structure's name. That is the desert
#      temple's own archaeology table, and it is where two of the source's sherds
#      come from — the skull sherd among the four Voxey registers.
#   3. It removes up to five of the temple's stone pressure plates at fifty
#      percent each, which is what makes the TNT trap partly missing.
#
# The chest holds the source's own table: bones, rotten flesh, spider eyes,
# leather, gold and iron, horse armour, emeralds, an enchanted golden apple and
# the dune armour trim, with four rolls of sand and monster parts.
#
# Voxey has no schematic loader, so the pyramid is generated: a stepped
# sandstone shell over a floor plate, with a central pit down to the vault. The
# conversion rule, the plate removal and the loot table are the source's exact
# behaviour.

const REGION = 48
# Source `sidelen = 18`, so the footprint is eighteen blocks across.
const SIDE = 18
# Source `y_offset = -12`: the pyramid's base sinks twelve blocks.
const DROP = 12
# Source converts at most 250 floor cells.
const SUSPICIOUS_CAP = 250
# Source removes at most five pressure plates.
const PLATES_REMOVED = 5
# Source removes a plate when `pr:next(1,100) >= 50`.
const PLATE_REMOVE_CHANCE = 50

const SHELL = Nodes.SANDSTONE
const ACCENT = Nodes.SANDSTONE_BRICK
# The vault under the floor, and the trap's material.
const VAULT = Nodes.SANDSTONE_BRICK
const PLATE = Nodes.PRESSURE_PLATE

# Source `loot`: bone, rotten flesh, spider eye, book, leather, golden apple,
# gold, iron, emerald, empty, horse armours, diamond, enchanted golden apple and
# the dune trim. A zero id keeps an unavailable entry's weight.
const TREASURE = [[Nodes.BONE,25,4,6],[Nodes.ROTTEN_FLESH,25,3,7],[VillageContent.SPIDER_EYE,25,1,3],
	[Nodes.BOOK,20,1,1],[Nodes.LEATHER,20,1,5],[Nodes.GOLDEN_APPLE,20,1,1],
	[Nodes.GOLD,15,2,7],[Nodes.IRON,15,1,5],[VillageContent.EMERALD,15,1,3],
	[0,15,1,1],[0,15,1,1],[0,15,1,1],[0,10,1,1],[0,5,1,1],
	[Nodes.DIAMOND,5,1,3],[0,2,1,1],[0,20,2,2]]
const REMAINS = [[Nodes.BONE,10,1,8],[Nodes.ROTTEN_FLESH,10,1,8],[Nodes.GUNPOWDER,10,1,8],
	[Nodes.SAND,10,1,8],[Nodes.STRING,10,1,8]]

# --- planning ----------------------------------------------------------------

# Plan a desert temple, or an empty dictionary where the ground is not sand.
static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	var floor_y: int = gen.terrain_height(origin.x,origin.z)
	# The source places on sand and sinks twelve blocks into it.
	if int(sample.call(Vector3i(origin.x,floor_y,origin.z))) != Nodes.SAND: return {}
	var base := Vector3i(origin.x,floor_y-DROP,origin.z)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var half: int = SIDE/2
	var state: Dictionary = {"voxels":{},"chests":{},"spawners":{},"plates":{},"floor":{},
		"bounds_min":base-Vector3i(half,0,half),"bounds_max":base+Vector3i(half,12,half),
		"floor_y":floor_y,"seed":seed_value}
	_build_pyramid(state,base,half,rng)
	# The vault's chest, which the source fills from its own table.
	var chest_at: Vector3i = base+Vector3i(0,-1,0)
	state.voxels[chest_at] = Nodes.CHEST
	state.chests[chest_at] = rng.randi()
	# The floor cells the source will convert, and the plates it may remove.
	for x in range(-half+1,half):
		for z in range(-half+1,half):
			var at: Vector3i = base+Vector3i(x,0,z)
			state.floor[at] = true
	# The source places stone plates inside the pyramid, then removes some.
	for i in 4:
		var at: Vector3i = base+Vector3i(rng.randi_range(-half+3,half-3),3,rng.randi_range(-half+3,half-3))
		state.voxels[at] = PLATE
		state.plates[at] = true
	return state

# A stepped sandstone pyramid over a floor, with a shaft to the vault.
static func _build_pyramid(state: Dictionary, base: Vector3i, half: int, rng: RandomNumberGenerator) -> void:
	# The shell steps in one block per level, as the source's pyramid does.
	for level in 9:
		var extent: int = half-level
		if extent < 1: break
		for x in range(-extent,extent):
			for z in range(-extent,extent):
				var edge: bool = absi(x) == extent-1 or absi(z) == extent-1
				var at: Vector3i = base+Vector3i(x,3+level,z)
				if edge: state.voxels[at] = ACCENT if (level%3) == 0 else SHELL
				# A hollow centre, so the shaft runs up through the pyramid.
	# The floor plate, and the vault walls under it.
	for x in range(-half+1,half):
		for z in range(-half+1,half):
			var edge: bool = absi(x) == half-1 or absi(z) == half-1
			state.voxels[base+Vector3i(x,0,z)] = VAULT if edge else SHELL
			# The shaft: the source's pyramid has a pit down to the vault.
			if absi(x) <= 1 and absi(z) <= 1: state.voxels.erase(base+Vector3i(x,0,z))
	for y in range(-4,0):
		for x in range(-3,4):
			for z in range(-3,4):
				var edge: bool = absi(x) == 3 or absi(z) == 3 or y == -4
				if edge: state.voxels[base+Vector3i(x,y,z)] = VAULT

# --- the after-place callback ------------------------------------------------

# The source's `temple_placement_callback`: convert up to 250 floor cells to
# suspicious sand, and remove up to five of the stone plates at fifty percent.
static func after_place(gen: TerrainGenerator, state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var suspicious: Dictionary = {}
	var cells: Array = state.floor.keys()
	if cells.is_empty(): return suspicious
	# The plan's own generator, not the global one, keeps the choice identical in
	# every column that overlaps the temple and on every load.
	for i in range(cells.size()-1,0,-1):
		var j: int = rng.randi_range(0,i)
		var swap: Vector3i = cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	var count: int = rng.randi_range(1,mini(SUSPICIOUS_CAP,cells.size()))
	for i in count:
		suspicious[cells[i]] = "desert_temple"
	# The plates the source removes, at fifty percent each up to five.
	var removed: int = 0
	for at in state.plates.keys():
		if removed >= PLATES_REMOVED: break
		if rng.randi_range(1,100) >= PLATE_REMOVE_CHANCE:
			# The source removes the plate node, so it must leave both the block map
			# and the plate set or the trap would still carry it.
			state.voxels.erase(at)
			state.plates.erase(at)
			removed += 1
	return suspicious

# --- regions and overlay -----------------------------------------------------

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.temple_cache.has(region): return gen.temple_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20177,region.y)
	var result: Array = []
	var origin := Vector3i(region.x*REGION+rng.randi_range(SIDE,REGION-SIDE),0,region.y*REGION+rng.randi_range(SIDE,REGION-SIDE))
	if WorldBounds.horizontal(origin):
		var sample: Callable = func(p: Vector3i) -> int: return Dungeons.natural(gen,p)
		var candidate: Dictionary = plan(gen,origin,rng.randi(),sample)
		if not candidate.is_empty():
			# The conversion is part of the plan, so it is decided once and cached.
			candidate.suspicious = after_place(gen,candidate,rng)
			result.append(candidate)
	if gen.temple_cache.size() >= 16: gen.temple_cache.erase(gen.temple_cache.keys()[0])
	gen.temple_cache[region] = result
	return result

static func nearby_plans(gen: TerrainGenerator, coord: Vector2i) -> Array:
	var base: Vector2i = coord*16-Vector2i.ONE
	var result: Array = []
	for rx in range(floori((base.x-SIDE)/float(REGION)),floori((base.x+17+SIDE)/float(REGION))+1):
		for rz in range(floori((base.y-SIDE)/float(REGION)),floori((base.y+17+SIDE)/float(REGION))+1):
			for candidate in region_plans(gen,Vector2i(rx,rz)):
				var lo: Vector3i = candidate.bounds_min
				var hi: Vector3i = candidate.bounds_max
				if hi.x >= base.x and lo.x <= base.x+17 and hi.z >= base.y and lo.z <= base.y+17: result.append(candidate)
	return result

# Merge a temple into the column, and report its chest and suspicious cells.
static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"chests":{},"spawners":{},"suspicious":{}}
	if gen.dimension != "overworld": return result
	var base: Vector2i = coord*16-Vector2i.ONE
	for candidate in nearby_plans(gen,coord):
		for p in candidate.voxels:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var existing: int = deep[index] if p.y < 0 else data[index]
			# The temple builds into sand, sandstone, natural ground or air.
			if not (existing == Nodes.SAND or existing == Nodes.SANDSTONE or existing == Nodes.AIR or Dungeons.ground(existing)): continue
			var wanted: int = int(candidate.voxels[p])
			if p.y < 0: deep[index] = wanted
			else: data[index] = wanted
			if x in range(1,17) and z in range(1,17) and candidate.chests.has(p):
				result.chests[p] = int(candidate.chests[p])
		# The suspicious cells the callback chose.
		for p in candidate.suspicious:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var id: int = Archaeology.SUSPICIOUS_SAND
			if p.y < 0: deep[index] = id
			else: data[index] = id
			result.suspicious[p] = "desert_temple"
	return result

# --- loot --------------------------------------------------------------------

# Fill a temple chest from the source's own table.
static func fill_chest(station: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var cursor: int = 0
	for group in [[TREASURE,2,4],[REMAINS,4,4]]:
		for roll in rng.randi_range(group[1],group[2]):
			var stack: Dictionary = Dungeons.weighted(rng,group[0])
			if not stack.is_empty() and cursor < station.slots.size(): station.slots[cursor] = stack
			cursor += 1
	station.label = "Desert temple chest"

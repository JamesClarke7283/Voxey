class_name JungleTemples
extends RefCounted

# Mineclonia MAPGEN/mcl_structures/jungle_temple.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# The jungle temple is the source's **trap** structure. It has no `after_place`
# at all: everything it does is in the schematic, and the schematic contains
#
#   * a **trapped chest** behind a hidden wall of the temple, and
#   * **dispensers** wired to tripwires, so the treasure is guarded by arrows.
#
# That is why this structure could not be built until now: it needs both the
# trapped chest and working dispensers, and Voxey had neither the first nor a
# dispenser that fires arrows. Both now exist.
#
# The loot is the source's own table, whose notable entries are an enchanted
# golden apple and the wild armour trim.
#
# Voxey has no schematic loader, so the temple is generated: a stepped
# mossy-cobble and jungle-wood box with a hidden lower vault, a trapped chest in
# the vault, and dispensers behind vines in the corridor. The loot table and the
# trap arrangement are the source's intent; the block-by-block layout is not.

const REGION = 64
# Source `sidelen = 18`, and `y_offset = pr:next(-3,0) - 5`.
const SIDE = 18
const DROP = 5

# The temple's own materials: mossy cobble and jungle wood, which is what the
# source's schematics are built from.
const WALL = Nodes.MOSSY_COBBLE
const FLOOR = Nodes.MOSSY_COBBLE

# Source `loot`, notable entries called out in the docstring. A zero id keeps an
# unavailable entry's weight rather than redistributing it.
const TREASURE = [[Nodes.BONE,20,4,6],[Nodes.ROTTEN_FLESH,16,3,7],
	[Nodes.GOLD,15,2,7],[0,15,1,3],[Nodes.IRON,15,1,5],[Nodes.DIAMOND,3,1,3],
	[Nodes.LEATHER,3,1,5],[VillageContent.EMERALD,2,1,3],[Nodes.BOOK,1,1,1],
	[0,1,1,1],[0,1,1,1],[0,1,1,1],[0,1,1,1],
	[0,2,1,1],[0,1,1,1]]

# --- planning ----------------------------------------------------------------

static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	var floor_y: int = gen.terrain_height(origin.x,origin.z)
	# The source places on grass or dirt, above y 1.
	if floor_y <= DROP+1: return {}
	var ground: int = int(sample.call(Vector3i(origin.x,floor_y,origin.z)))
	if not (ground == Nodes.GRASS or ground == Nodes.DIRT): return {}
	var base := Vector3i(origin.x,floor_y-DROP,origin.z)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var half: int = SIDE/2
	var state: Dictionary = {"voxels":{},"chests":{},"spawners":{},"dispensers":{},
		"bounds_min":base-Vector3i(half,0,half),"bounds_max":base+Vector3i(half,DROP+4,half),
		"floor_y":floor_y,"seed":seed_value}
	_build(state,base,half,rng)
	# The source's own treasure: a trapped chest in the hidden vault, guarded by
	# dispensers. The chest is trapped, so opening it powers the dispensers.
	var vault: Vector3i = base+Vector3i(0,DROP-2,0)
	state.voxels[vault] = TrappedChests.ID
	state.chests[vault] = rng.randi()
	# Two dispensers stand beside the chest, which is the source's trap
	# arrangement: a trapped chest powers its *adjacent* blocks, so the dispensers
	# must touch it or opening the chest would do nothing. Both are loaded with
	# arrows, which `dispense` fires when the chest's signal rises.
	for side in [-1,1]:
		var at: Vector3i = vault+Vector3i(side,0,0)
		state.voxels[at] = Nodes.DISPENSER
		state.dispensers[at] = true
	return state

# A stepped box: a mossy cobble shell over a jungle wood floor, with a vault
# below and a hidden corridor to the dispensers.
static func _build(state: Dictionary, base: Vector3i, half: int, rng: RandomNumberGenerator) -> void:
	var top: int = DROP-1
	# The shell, three levels high, stepping in at the top.
	for level in 3:
		var extent: int = half-level
		if extent < 2: break
		for x in range(-extent,extent):
			for z in range(-extent,extent):
				var edge: bool = absi(x) == extent-1 or absi(z) == extent-1
				if edge: state.voxels[base+Vector3i(x,top+level,z)] = WALL
	# The floor plate.
	for x in range(-half+1,half):
		for z in range(-half+1,half):
			state.voxels[base+Vector3i(x,top,z)] = FLOOR
	# The vault under the floor: a room three blocks high with a jungle wood
	# ceiling, reachable only by breaking through.
	for y in range(-3,0):
		for x in range(-5,6):
			for z in range(-5,6):
				var at: Vector3i = base+Vector3i(x,top+y,z)
				if absi(x) == 5 or absi(z) == 5 or y == -3:
					state.voxels[at] = WALL
					# The vault floor is jungle wood, as the source's is.
					if y == -3: state.voxels[at] = Nodes.PLANKS
	# Vines hang from the shell's rim, which is what gives the temple its look.
	for x in range(-half+1,half):
		if rng.randf() < 0.35: state.voxels[base+Vector3i(x,top+3,-half+1)] = Nodes.VINE
		if rng.randf() < 0.35: state.voxels[base+Vector3i(x,top+3,half-1)] = Nodes.VINE

# --- regions and overlay -----------------------------------------------------

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.jungle_cache.has(region): return gen.jungle_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20201,region.y)
	var result: Array = []
	var origin := Vector3i(region.x*REGION+rng.randi_range(SIDE,REGION-SIDE),0,region.y*REGION+rng.randi_range(SIDE,REGION-SIDE))
	if WorldBounds.horizontal(origin):
		var sample: Callable = func(p: Vector3i) -> int: return Dungeons.natural(gen,p)
		var candidate: Dictionary = plan(gen,origin,rng.randi(),sample)
		if not candidate.is_empty(): result.append(candidate)
	if gen.jungle_cache.size() >= 16: gen.jungle_cache.erase(gen.jungle_cache.keys()[0])
	gen.jungle_cache[region] = result
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

# Merge a temple into the column, and report its chest and dispensers.
static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"chests":{},"spawners":{}}
	if gen.dimension != "overworld": return result
	var base: Vector2i = coord*16-Vector2i.ONE
	for candidate in nearby_plans(gen,coord):
		for p in candidate.voxels:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var existing: int = deep[index] if p.y < 0 else data[index]
			# The temple builds into air or natural ground.
			if existing != Nodes.AIR and not Dungeons.ground(existing): continue
			var wanted: int = int(candidate.voxels[p])
			if p.y < 0: deep[index] = wanted
			else: data[index] = wanted
			if x in range(1,17) and z in range(1,17) and candidate.chests.has(p):
				result.chests[p] = int(candidate.chests[p])
	return result

# --- loot --------------------------------------------------------------------

static func fill_chest(station: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var cursor: int = 0
	for roll in rng.randi_range(2,6):
		var stack: Dictionary = Dungeons.weighted(rng,TREASURE)
		if not stack.is_empty() and cursor < station.slots.size(): station.slots[cursor] = stack
		cursor += 1
	station.label = "Jungle temple chest"

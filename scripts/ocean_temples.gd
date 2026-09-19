class_name OceanTemples
extends RefCounted

# Mineclonia MAPGEN/mcl_structures/ocean_temple, which lives in
# `mods/MAPGEN/mcl_structures/shipwrecks.lua`. GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# The ocean temple — the ocean monument — is the **reason guardians exist**. The
# source places it as a large prismarine structure on the sea floor and then:
#
#   * Spawns **five guardians** and **one elder guardian** in it, on dark
#     prismarine slabs.
#   * Runs `construct_nodes` for the `group:wall` blocks, so its walls settle.
#
# The elder is the important one: **the elder guardian's wet sponge is the only
# natural source of sponges**, and the elder's mining fatigue is what makes the
# monument a real obstacle. Voxey already had the guardian drops, so this
# structure is what gives them a home.
#
# The chest holds the source's own table, whose notable entries are a fishing rod
# and a block of gold.
#
# Voxey has no schematic loader, so the monument is generated: a stepped
# prismarine mass with a hollow interior, sea lanterns, and dark prismarine for
# the guardian spawn surface. The garrison counts and the loot are the source's
# exact behaviour.

const REGION = 96
# Source `sidelen = 32`.
const SIDE = 32
# Source `y_offset = pr:next(-2,0)`: the monument sits two to zero blocks down.
const SINK_MIN = 0
const SINK_MAX = 2
# Source spawns this garrison.
const GUARDIANS = 5
const ELDERS = 1
# Source requires four water neighbours, so the site must be properly submerged.
const WATER_NEIGHBOURS = 4

const SHELL = Conduits.PRISMARINE
const ACCENT = Conduits.PRISMARINE_BRICK
const DARK = Conduits.PRISMARINE_DARK
const LANTERN = Conduits.SEA_LANTERN

# Source `loot`: a fishing rod and a block of gold are the notable entries.
const SUPPLIES = [[VillageContent.XP_BOTTLE,10,1,1],[Nodes.PAPER,8,1,12],
	[VillageContent.RAW_COD,5,8,21],[VillageContent.RAW_SALMON,7,4,8],[Nodes.TNT,1,1,2]]
const TREASURE = [[Nodes.IRON,10,1,5],[Nodes.GOLD_BLOCK,1,1,2],
	[VillageContent.XP_BOTTLE,5,1,1],[Nodes.DIAMOND,5,1,1],[VillageContent.FISHING_ROD,1,1,1]]
const NAVIGATION = [[Nodes.BOOK,1,1,5],[Nodes.CLOCK,1,1,1],[Nodes.COMPASS,1,1,1],
	[VillageContent.EMPTY_MAP,1,1,1]]

# --- planning ----------------------------------------------------------------

static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	var floor_y: int = gen.terrain_height(origin.x,origin.z)
	# The source's `y_max = water_level-4`: a monument is well submerged.
	if floor_y >= TerrainGenerator.SEA-4: return {}
	var ground: int = int(sample.call(Vector3i(origin.x,floor_y,origin.z)))
	# Source `place_on` is sand or gravel.
	if not (ground == Nodes.SAND or ground == Nodes.GRAVEL): return {}
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var sink: int = rng.randi_range(SINK_MIN,SINK_MAX)
	var base := Vector3i(origin.x,floor_y-sink,origin.z)
	var half: int = SIDE/2
	var state: Dictionary = {"voxels":{},"chests":{},"spawners":{},"garrison":{},"spawn_surface":{},
		"bounds_min":base-Vector3i(half,4,half),"bounds_max":base+Vector3i(half,SIDE+2,half),
		"floor_y":floor_y,"seed":seed_value,"sink":sink}
	_build(state,base,half,rng)
	# The monument's chest, which the source fills from its own table.
	var chest_at: Vector3i = base+Vector3i(0,1,0)
	state.voxels[chest_at] = Nodes.CHEST
	state.chests[chest_at] = rng.randi()
	return state

# A stepped prismarine mass with a hollow, lantern-lit interior, and dark
# prismarine laid as the guardian spawn surface.
static func _build(state: Dictionary, base: Vector3i, half: int, rng: RandomNumberGenerator) -> void:
	var height: int = rng.randi_range(12,18)
	# The mass steps in as it rises, which is the monument's shape.
	for level in height:
		var extent: int = half-level/2
		if extent < 2: break
		for x in range(-extent,extent+1):
			for z in range(-extent,extent+1):
				var edge: bool = absi(x) == extent or absi(z) == extent
				var at: Vector3i = base+Vector3i(x,level,z)
				if level == 0: state.voxels[at] = SHELL
				elif not edge: continue
				# The shell is prismarine with dark accents and lanterns inset, so the
				# monument glows from inside as the source's does.
				if (level%5) == 0 and absi(x) < extent-1 and absi(z) < extent-1: state.voxels[at] = LANTERN
				elif (x+z+level)%7 == 0: state.voxels[at] = DARK
				elif (level%3) == 0: state.voxels[at] = ACCENT
				else: state.voxels[at] = SHELL
	# The interior: a hollow at the monument's base where the garrison swims.
	for x in range(-half+3,half-2):
		for z in range(-half+3,half-2):
			for y in range(1,5):
				state.voxels.erase(base+Vector3i(x,y,z))
	# The dark prismarine spawn surface, which is what the source's guardian
	# spawners stand on.
	for x in range(-half+4,half-3):
		for z in range(-half+4,half-3):
			state.voxels[base+Vector3i(x,0,z)] = DARK
			state.spawn_surface[base+Vector3i(x,0,z)] = true

# --- the garrison ------------------------------------------------------------

# The source's party: five guardians and one elder, on the monument's dark
# prismarine. The elder is what makes the monument dangerous and what supplies
# the world's only sponges.
static func garrison_spawns(state: Dictionary, rng: RandomNumberGenerator) -> Array:
	var centre: Vector3i = (state.bounds_min+state.bounds_max)/2
	var result: Array = []
	var surface: Array = state.spawn_surface.keys()
	if surface.is_empty(): return result
	for i in GUARDIANS:
		var at: Vector3i = surface[rng.randi_range(0,surface.size()-1)]
		result.append(["guardian",[at.x,at.y+1,at.z]])
	for i in ELDERS:
		# The elder stands apart, at the monument's centre, as the source's own
		# single-elder placement does.
		result.append(["guardian_elder",[centre.x,state.bounds_min.y+2,centre.z]])
	return result

# --- regions and overlay -----------------------------------------------------

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.ocean_temple_cache.has(region): return gen.ocean_temple_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20261,region.y)
	var result: Array = []
	var origin := Vector3i(region.x*REGION+rng.randi_range(SIDE,REGION-SIDE),0,region.y*REGION+rng.randi_range(SIDE,REGION-SIDE))
	if WorldBounds.horizontal(origin):
		var sample: Callable = func(p: Vector3i) -> int: return Dungeons.natural(gen,p)
		var candidate: Dictionary = plan(gen,origin,rng.randi(),sample)
		if not candidate.is_empty():
			candidate.garrison = garrison_spawns(candidate,rng)
			result.append(candidate)
	if gen.ocean_temple_cache.size() >= 8: gen.ocean_temple_cache.erase(gen.ocean_temple_cache.keys()[0])
	gen.ocean_temple_cache[region] = result
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

# Merge a monument into the column, and report its chest and garrison.
static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"chests":{},"spawners":{},"garrison":{}}
	if gen.dimension != "overworld": return result
	var base: Vector2i = coord*16-Vector2i.ONE
	for candidate in nearby_plans(gen,coord):
		for p in candidate.voxels:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var existing: int = deep[index] if p.y < 0 else data[index]
			# A monument is built into water over the sea floor.
			if existing != Nodes.AIR and existing != Nodes.WATER and not Dungeons.ground(existing): continue
			var wanted: int = int(candidate.voxels[p])
			if p.y < 0: deep[index] = wanted
			else: data[index] = wanted
			if x in range(1,17) and z in range(1,17) and candidate.chests.has(p):
				result.chests[p] = int(candidate.chests[p])
			# The garrison spawns once, at the chest that marks the monument.
			if x in range(1,17) and z in range(1,17) and candidate.chests.has(p):
				result.garrison[p] = candidate.garrison
	return result

# --- loot --------------------------------------------------------------------

static func fill_chest(station: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var cursor: int = 0
	for group in [[SUPPLIES,3,10],[TREASURE,2,6],[NAVIGATION,4,4]]:
		for roll in rng.randi_range(int(group[1]),int(group[2])):
			var stack: Dictionary = Dungeons.weighted(rng,group[0])
			if not stack.is_empty() and cursor < station.slots.size(): station.slots[cursor] = stack
			cursor += 1
	station.label = "Ocean monument chest"

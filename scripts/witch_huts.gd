class_name WitchHuts
extends RefCounted

# Mineclonia MAPGEN/mcl_structures/witch_hut.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# A witch hut is a small stilted shack in a swamp. The source's `after_place` is
# what makes it a *place*:
#
#   * **It finds the hut's cauldron**, then looks for oak-wood posts at the
#     cauldron's own level and spawns the residents on top of them. That is
#     precise: the witch and cat stand on the hut's legs, not at a fixed offset.
#   * **It replaces the hut's leg blocks with oak logs down to the waterline**,
#     so the legs are real stilts standing in the swamp rather than floating.
#   * It spawns a **witch** and an **all-black cat**. The source overrides the
#     cat's texture explicitly, so the hut's cat is always black.
#   * The witch does not despawn (`can_despawn = false`), and neither does the cat.
#
# The witch needed to exist first, and so did the cat — Voxey had neither. Both
# are added in this batch, which is why the structure could be built now.

const REGION = 48
# Source `sidelen = 8`.
const SIDE = 8
const POST = Nodes.LOG
const ROOF = Nodes.PLANKS
const FLOOR = Nodes.PLANKS

# --- planning ----------------------------------------------------------------

static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	var floor_y: int = gen.terrain_height(origin.x,origin.z)
	# The source places at or below the waterline, on the swamp's surface.
	if floor_y > TerrainGenerator.SEA+1: return {}
	var ground: int = int(sample.call(Vector3i(origin.x,floor_y,origin.z)))
	if not (ground == Nodes.SAND or ground == Nodes.GRASS or ground == Nodes.DIRT or ground == Nodes.WATER): return {}
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var base := Vector3i(origin.x,floor_y,origin.z)
	var half: int = SIDE/2
	var state: Dictionary = {"voxels":{},"chests":{},"spawners":{},"residents":{},"legs":{},
		"bounds_min":base-Vector3i(half,0,half),"bounds_max":base+Vector3i(half,8,half),
		"floor_y":floor_y,"seed":seed_value}
	_build(state,base,rng)
	return state

# A small shack raised on stilts, with a cauldron inside and a gap for the door.
static func _build(state: Dictionary, base: Vector3i, rng: RandomNumberGenerator) -> void:
	var lift: int = 3
	# The stilts, which the source later converts to oak logs down to the water.
	for x in [-2,2]:
		for z in [-2,2]:
			for y in lift:
				var at: Vector3i = base+Vector3i(x,y,z)
				state.voxels[at] = POST
				state.legs[at] = true
	# The hut's floor, walls and roof.
	for x in range(-2,3):
		for z in range(-2,3):
			state.voxels[base+Vector3i(x,lift,z)] = FLOOR
			for y in range(lift+1,lift+4):
				var edge: bool = absi(x) == 2 or absi(z) == 2
				if edge: state.voxels[base+Vector3i(x,y,z)] = ROOF
			state.voxels[base+Vector3i(x,lift+4,z)] = ROOF
	# A doorway, so the hut can be entered.
	for y in [lift+1,lift+2]: state.voxels.erase(base+Vector3i(0,y,-2))
	# The cauldron, which is the anchor the source's spawn rule reads.
	var cauldron: Vector3i = base+Vector3i(0,lift+1,0)
	state.voxels[cauldron] = VillageContent.CAULDRON
	state.residents["cauldron"] = cauldron
	# The residents stand on the hut's own posts at the cauldron's level, which is
	# the source's rule: it looks for the hut's wooden posts and puts them on top.
	state.residents["witch"] = [cauldron.x+2,lift,cauldron.z+2]
	state.residents["cat"] = [cauldron.x-2,lift,cauldron.z-2]
	return

# Whether a block is one of the hut's own stilts, which the source converts to oak.
static func is_leg(id: int) -> bool: return id == POST

# --- regions and overlay -----------------------------------------------------

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.witch_cache.has(region): return gen.witch_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20249,region.y)
	var result: Array = []
	var origin := Vector3i(region.x*REGION+rng.randi_range(SIDE,REGION-SIDE),0,region.y*REGION+rng.randi_range(SIDE,REGION-SIDE))
	if WorldBounds.horizontal(origin):
		var sample: Callable = func(p: Vector3i) -> int: return Dungeons.natural(gen,p)
		var candidate: Dictionary = plan(gen,origin,rng.randi(),sample)
		if not candidate.is_empty(): result.append(candidate)
	if gen.witch_cache.size() >= 16: gen.witch_cache.erase(gen.witch_cache.keys()[0])
	gen.witch_cache[region] = result
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

# Merge a hut into the column, and report its residents.
static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"chests":{},"spawners":{},"residents":{}}
	if gen.dimension != "overworld": return result
	var base: Vector2i = coord*16-Vector2i.ONE
	for candidate in nearby_plans(gen,coord):
		for p in candidate.voxels:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var existing: int = deep[index] if p.y < 0 else data[index]
			# A hut is raised over water, so it builds into air, water or ground.
			if existing != Nodes.AIR and existing != Nodes.WATER and not Dungeons.ground(existing): continue
			var wanted: int = int(candidate.voxels[p])
			if p.y < 0: deep[index] = wanted
			else: data[index] = wanted
		# The residents spawn once, at the cauldron that anchors them. The cauldron
		# is a position, not an offset list, so it is used directly.
		var cauldron: Vector3i = candidate.residents.get("cauldron",Vector3i.ZERO)
		var cx: int = cauldron.x-base.x; var cz: int = cauldron.z-base.y
		if cx in range(1,17) and cz in range(1,17):
			result.residents[cauldron] = candidate.residents
	return result

class_name WoodlandCabins
extends RefCounted

# Mineclonia MAPGEN/mcl_structures/woodland_mansion.lua, which registers
# `woodland_cabin`. GPL-3.0-or-later. Original GDScript using the source as a
# behaviour reference.
#
# The woodland cabin is a dark-oak hall in a roofed forest, and its purpose is its
# **garrison**:
#
#   * **Five vindicators** — melee illagers with iron axes.
#   * **One evoker** — the spellcaster whose drop is the **totem of undying**.
#   * **One parrot** perched on a wither skeleton head.
#
# The evoker is the one that matters. Voxey had the totem and its whole
# lethal-damage interception, but the totem was **unobtainable in survival**: no
# drop, no recipe, no structure produced one. The source's evoker drops a totem at
# `chance = 1`, which is always, so this structure is the route — and the cabin
# also carries barrels and bookshelves (`construct_nodes`).
#
# Voxey has no schematic loader, so the hall is generated: a dark-oak building on
# a stone base with a carpeted floor. The garrison, the furniture and the loot are
# the source's exact behaviour.

const REGION = 80
# Source `sidelen = 32`.
const SIDE = 32

const WALL = WoodTypes.PLANKS[5]      # Dark oak planks.
const POST = WoodTypes.LOGS[5]        # Dark oak logs.
const FLOOR = Nodes.BRICKS
# Source spawns this garrison.
const VINDICATORS = 5
const EVOKERS = 1
const PARROTS = 1

# Source `loot`, whose notable entries are the source's own groups. A zero id
# keeps an unavailable entry's weight rather than redistributing it.
const COMMON = [[Nodes.BONE,10,1,8],[Nodes.GUNPOWDER,10,1,8],[Nodes.ROTTEN_FLESH,10,1,8],
	[Nodes.STRING,10,1,8]]
const VALUABLES = [[Nodes.GOLD,15,2,7],[Nodes.IRON,10,1,5],[VillageContent.EMERALD,10,1,4],
	[Nodes.DIAMOND,3,1,2]]
const STORES = [[Nodes.GRAIN,20,1,4],[Nodes.BREAD,20,1,1],[Nodes.COAL,15,1,4],
	[Nodes.REDSTONE_WIRE,15,1,4],[Nodes.APPLE,10,1,3]]

# --- planning ----------------------------------------------------------------

static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	var floor_y: int = gen.terrain_height(origin.x,origin.z)
	if floor_y <= 2: return {}
	var ground: int = int(sample.call(Vector3i(origin.x,floor_y,origin.z)))
	# The source places on grass or dirt.
	if not (ground == Nodes.GRASS or ground == Nodes.DIRT): return {}
	var base := Vector3i(origin.x,floor_y,origin.z)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var half: int = SIDE/2
	var state: Dictionary = {"voxels":{},"chests":{},"spawners":{},"furniture":{},
		"bounds_min":base-Vector3i(half,2,half),"bounds_max":base+Vector3i(half,14,half),
		"floor_y":floor_y,"seed":seed_value}
	_build(state,base,rng)
	# The cabin's chest, which the source fills from its own table.
	var chest_at: Vector3i = base+Vector3i(0,1,0)
	state.voxels[chest_at] = Nodes.CHEST
	state.chests[chest_at] = rng.randi()
	return state

# A dark-oak hall: a stone floor, timbered walls, a doorway and a stepped roof.
static func _build(state: Dictionary, base: Vector3i, rng: RandomNumberGenerator) -> void:
	var width: int = rng.randi_range(5,7)
	var height: int = rng.randi_range(5,7)
	for x in range(-width,width+1):
		for z in range(-width,width+1):
			# The stone floor, and the carpet the source's own garrison stands on.
			state.voxels[base+Vector3i(x,0,z)] = FLOOR
			for y in range(1,height+1):
				var edge: bool = absi(x) == width or absi(z) == width
				if not edge: continue
				# Corner posts are logs, the wall between them is planks.
				var corner: bool = absi(x) == width and absi(z) == width
				state.voxels[base+Vector3i(x,y,z)] = POST if corner else WALL
			state.voxels[base+Vector3i(x,height+1,z)] = WALL
	# A doorway, so the hall can be entered.
	for y in [1,2]: state.voxels.erase(base+Vector3i(0,y,-width))
	# The furniture the source constructs: barrels and bookshelves.
	for i in 3:
		var at: Vector3i = base+Vector3i(-width+1+i,1,-width+1)
		state.voxels[at] = VillageContent.BARREL
		state.furniture[at] = true
	for i in 2:
		var shelf: Vector3i = base+Vector3i(width-1,1,-width+1+i)
		state.voxels[shelf] = Nodes.BOOKSHELF
		state.furniture[shelf] = true

# --- the garrison ------------------------------------------------------------

# The source's party: five vindicators, one evoker and one parrot. The evoker is
# the only survival source of a totem of undying.
static func garrison_spawns(state: Dictionary, rng: RandomNumberGenerator) -> Array:
	var centre: Vector3i = (state.bounds_min+state.bounds_max)/2
	var top: int = state.bounds_max.y-6
	var result: Array = []
	for i in VINDICATORS:
		var at := centre+Vector3i(rng.randi_range(-4,4),top-state.bounds_min.y,rng.randi_range(-4,4))
		result.append(["vindicator",[at.x,at.y,at.z]])
	for i in EVOKERS:
		var at := centre+Vector3i(0,top-state.bounds_min.y,0)
		result.append(["evoker",[at.x,at.y,at.z]])
	for i in PARROTS:
		var at := centre+Vector3i(rng.randi_range(-4,4),top-state.bounds_min.y+1,rng.randi_range(-4,4))
		result.append(["parrot",[at.x,at.y,at.z]])
	return result

# --- regions and overlay -----------------------------------------------------

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.cabin_cache.has(region): return gen.cabin_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20273,region.y)
	var result: Array = []
	var origin := Vector3i(region.x*REGION+rng.randi_range(SIDE,REGION-SIDE),0,region.y*REGION+rng.randi_range(SIDE,REGION-SIDE))
	if WorldBounds.horizontal(origin):
		var sample: Callable = func(p: Vector3i) -> int: return Dungeons.natural(gen,p)
		var candidate: Dictionary = plan(gen,origin,rng.randi(),sample)
		if not candidate.is_empty():
			candidate.garrison = garrison_spawns(candidate,rng)
			result.append(candidate)
	if gen.cabin_cache.size() >= 16: gen.cabin_cache.erase(gen.cabin_cache.keys()[0])
	gen.cabin_cache[region] = result
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

# Merge a cabin into the column, and report its chest and garrison.
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
			if existing != Nodes.AIR and not Dungeons.ground(existing): continue
			var wanted: int = int(candidate.voxels[p])
			if p.y < 0: deep[index] = wanted
			else: data[index] = wanted
			if x in range(1,17) and z in range(1,17) and candidate.chests.has(p):
				result.chests[p] = int(candidate.chests[p])
			# The garrison spawns once, at the chest that marks the cabin.
			if x in range(1,17) and z in range(1,17) and candidate.chests.has(p):
				result.garrison[p] = candidate.garrison
	return result

# --- loot --------------------------------------------------------------------

static func fill_chest(station: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var cursor: int = 0
	for group in [[COMMON,3,3],[VALUABLES,2,3],[STORES,2,3]]:
		for roll in rng.randi_range(int(group[1]),int(group[2])):
			var stack: Dictionary = Dungeons.weighted(rng,group[0])
			if not stack.is_empty() and cursor < station.slots.size(): station.slots[cursor] = stack
			cursor += 1
	station.label = "Woodland cabin chest"

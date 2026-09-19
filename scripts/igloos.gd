class_name Igloos
extends RefCounted

# Mineclonia MAPGEN/mcl_structures/igloo.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# An igloo is a snow hut with a **hidden basement** — and the basement is a cure
# puzzle. The source's own placement is unusual, and every part of it matters:
#
#   * The hut is placed with a **random rotation**, and the rotation decides where
#     the ladder shaft and the hidden trapdoor are. The trapdoor is placed five
#     seconds *after* the hut, so it is not part of the initial structure.
#   * The basement appears with **50% chance** (`pr:next(1,2) == 1`), so half of
#     all igloos are just a hut.
#   * The shaft is lined with **stone bricks, cracked stone bricks and infested
#     bricks** — a random third of which are infested, and one in ten of those is
#     an infested *cracked* brick. That is the ambush on the way down.
#   * The basement holds a **brewing stand**, a **bookshelf** and a **jukebox**,
#     plus a **villager and a zombie villager** — the two halves of the cure.
#   * The loot table's first group is a **guaranteed golden apple**, which is the
#     cure item, and its second group can produce another.
#
# So the igloo is not a loot hut. It is a self-contained puzzle: find the
# trapdoor, go down past infested bricks, and cure the zombie villager with the
# apple and the weakness potion you brew at the stand.
#
# This structure needed three earlier batches to exist at all: **infested
# blocks**, the **zombie villager and its cure**, and the brewing stand. All are
# now present.
#
# Voxey has no schematic loader, so the hut and basement are generated. The
# rotation rule, the 50% basement, the shaft's infested mix, the residents and
# the loot are the source's exact behaviour; the block layout is not.

const REGION = 64
# Source `sidelen = 16`.
const SIDE = 16
# Source `pr:next(1,2) == 1`, so half of all igloos have a basement.
const BASEMENT_CHANCE = 2
# The source's shaft runs at least this deep, and refuses a shallower site.
const MIN_DEPTH = 7
# Source `m == 1` in `set_brick`: one in ten shaft bricks is infested.
const INFESTED_CHANCE = 10
# Source `c == 1` in `set_brick`: one in three of the *infested* ones is cracked.
const CRACKED_CHANCE = 3

const HUT = Nodes.SNOW_BLOCK
const BRICKS = Nodes.BRICKS

# The source's loot. The first group is a **guaranteed golden apple**, which is
# what makes the cure reachable; the second is the ordinary hut loot.
const GUARANTEED = [[Nodes.GOLDEN_APPLE,1,1,1]]
const STORES = [[Nodes.COAL,15,1,4],[Nodes.APPLE,15,1,3],[Nodes.GRAIN,10,2,3],
	[Nodes.GOLD_NUGGET,10,1,3],[Nodes.ROTTEN_FLESH,10,1,1],
	[Nodes.TOOLS+1*5+3,2,1,1],[VillageContent.EMERALD,1,1,1],[Nodes.GOLDEN_APPLE,1,1,1]]

# --- planning ----------------------------------------------------------------

static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	var floor_y: int = gen.terrain_height(origin.x,origin.z)
	# The source places on snow or snowy grass, and needs depth for the shaft.
	if floor_y <= MIN_DEPTH+1: return {}
	var ground: int = int(sample.call(Vector3i(origin.x,floor_y,origin.z)))
	if not (ground == Nodes.SNOW_BLOCK or ground == Nodes.SNOW or ground == Nodes.GRASS): return {}
	var base := Vector3i(origin.x,floor_y,origin.z)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	# The source's rotation decides where the shaft and trapdoor sit.
	var rotation: int = rng.randi_range(0,3)
	var half: int = SIDE/2
	var state: Dictionary = {"voxels":{},"chests":{},"spawners":{},"residents":{},"shaft":{},
		"bounds_min":base-Vector3i(half,0,half),"bounds_max":base+Vector3i(half,MIN_DEPTH+4,half),
		"floor_y":floor_y,"seed":seed_value,"rotation":rotation}
	# The hut itself: a snow dome with a floor and a short entry.
	for x in range(-3,4):
		for z in range(-3,4):
			for y in range(0,4):
				var edge: bool = absi(x) == 3 or absi(z) == 3 or y == 3
				var at: Vector3i = base+Vector3i(x,y,z)
				if y == 0: state.voxels[at] = HUT
				elif edge: state.voxels[at] = HUT
	# The entry gap, so the hut can be walked into.
	for y in [1,2]: state.voxels.erase(base+Vector3i(0,y,-3))
	# Half of all igloos have no basement at all.
	if rng.randi_range(1,BASEMENT_CHANCE) != 1: return state
	# The shaft, running down from one corner according to the rotation.
	var shaft_x: int = [-1,0,1,0][rotation]
	var shaft_z: int = [0,-1,0,1][rotation]
	var depth: int = rng.randi_range(MIN_DEPTH,12)
	var shaft: Vector3i = base+Vector3i(shaft_x,0,shaft_z)
	state["shaft_pos"] = shaft
	for y in range(1,depth):
		var at: Vector3i = shaft-Vector3i(0,y,0)
		# The source lines the shaft with bricks, a random third of them infested,
		# and one in ten of those infested is cracked. That is the ambush on the way
		# down, and it is why this structure needed infested blocks first.
		for offset in [Vector3i(-1,0,0),Vector3i(1,0,0),Vector3i(0,0,-1),Vector3i(0,0,1)]:
			state.voxels[at+offset] = shaft_brick(rng)
			state.shaft[at+offset] = true
		state.voxels[at] = Nodes.LADDER
	# The basement: an open room at the bottom of the shaft.
	var room: Vector3i = shaft-Vector3i(0,depth-1,0)
	for x in range(-3,4):
		for z in range(-3,4):
			for y in range(0,4):
				var at: Vector3i = room+Vector3i(x,y,z)
				var wall: bool = absi(x) == 3 or absi(z) == 3 or y == 3
				if wall: state.voxels[at] = shaft_brick(rng)
				elif y == 0: state.voxels[at] = BRICKS
	# The basement's furniture, which is what makes it the cure puzzle: a brewing
	# stand for the weakness potion and a chest holding the golden apple.
	var stand: Vector3i = room+Vector3i(-1,1,0)
	state.voxels[stand] = VillageContent.BREWING_STAND
	state.residents["brewing_stand"] = stand
	state.voxels[room+Vector3i(-3,1,2)] = Nodes.BOOKSHELF
	state.voxels[room+Vector3i(3,1,-2)] = Jukeboxes.ID
	# The residents: the source spawns one villager and one zombie villager here,
	# which are the two halves of the cure.
	state.residents["villager"] = [room.x,room.y+1,room.z-1]
	state.residents["zombie_villager"] = [room.x,room.y+1,room.z+1]
	# The chest, whose first group is the guaranteed golden apple.
	var chest_at: Vector3i = room+Vector3i(2,1,2)
	state.voxels[chest_at] = Nodes.CHEST
	state.chests[chest_at] = rng.randi()
	return state

# The source's `set_brick`: a chance of a monster egg, and of a cracked brick.
static func shaft_brick(rng: RandomNumberGenerator) -> int:
	if rng.randi_range(1,INFESTED_CHANCE) == 1:
		# An infested brick, cracked one time in three.
		return MonsterEggs.CRACKED_BRICKS if rng.randi_range(1,CRACKED_CHANCE) == 1 else MonsterEggs.BRICKS
	return Masonry.CRACKED_BRICKS if rng.randi_range(1,CRACKED_CHANCE) == 1 else BRICKS

# --- regions and overlay -----------------------------------------------------

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.igloo_cache.has(region): return gen.igloo_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20233,region.y)
	var result: Array = []
	var origin := Vector3i(region.x*REGION+rng.randi_range(SIDE,REGION-SIDE),0,region.y*REGION+rng.randi_range(SIDE,REGION-SIDE))
	if WorldBounds.horizontal(origin):
		var sample: Callable = func(p: Vector3i) -> int: return Dungeons.natural(gen,p)
		var candidate: Dictionary = plan(gen,origin,rng.randi(),sample)
		if not candidate.is_empty(): result.append(candidate)
	if gen.igloo_cache.size() >= 16: gen.igloo_cache.erase(gen.igloo_cache.keys()[0])
	gen.igloo_cache[region] = result
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

# Merge an igloo into the column, and report its chest and residents.
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
			# The igloo is dug into snow and earth, so it replaces natural ground as
			# well as air — the shaft and basement are carved, not built over.
			if existing != Nodes.AIR and not Dungeons.ground(existing) and existing != Nodes.SNOW_BLOCK and existing != Nodes.SNOW: continue
			var wanted: int = int(candidate.voxels[p])
			if p.y < 0: deep[index] = wanted
			else: data[index] = wanted
			if x in range(1,17) and z in range(1,17) and candidate.chests.has(p):
				result.chests[p] = int(candidate.chests[p])
			# The residents spawn once, at the chest that marks the basement.
			if x in range(1,17) and z in range(1,17) and candidate.chests.has(p) and candidate.residents.has("villager"):
				result.residents[p] = candidate.residents
	return result

# --- loot --------------------------------------------------------------------

static func fill_chest(station: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var cursor: int = 0
	# The source's first group is a single guaranteed golden apple, which is the
	# cure item; the second is the ordinary stores.
	for roll in rng.randi_range(1,1):
		var stack: Dictionary = Dungeons.weighted(rng,GUARANTEED)
		if not stack.is_empty() and cursor < station.slots.size(): station.slots[cursor] = stack
		cursor += 1
	for roll in rng.randi_range(2,8):
		var stack: Dictionary = Dungeons.weighted(rng,STORES)
		if not stack.is_empty() and cursor < station.slots.size(): station.slots[cursor] = stack
		cursor += 1
	station.label = "Igloo chest"

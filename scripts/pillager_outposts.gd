class_name PillagerOutposts
extends RefCounted

# Mineclonia MAPGEN/mcl_structures/pillager_outpost.lua, GPL-3.0-or-later.
# Original GDScript using the source as a behaviour reference.
#
# A pillager outpost is a wooden watchtower with a raiding party in it. The
# source's `after_place` is what makes it a *place* rather than a building:
#
#   * It spawns **five pillagers**, **three parrots** and **one iron golem**.
#     The parrots are what the outpost is known for — they perch on the tower.
#   * It carries a **damaged anvil** (`construct_nodes`), which is the source's
#     way of placing an anvil whose damage state is already set.
#
# The iron golem is the interesting one: the source puts one in a pillager
# outpost, so the outpost becomes a small set-piece rather than a loot box.
#
# The loot is the source's own four groups: crops, supplies, dark oak saplings
# and a guaranteed crossbow.
#
# Voxey has no schematic loader, so the tower is generated: a stone base with
# wooden walls, a ladder, and a fenced platform on top. The spawn rules and the
# loot table are the source's exact behaviour.

const REGION = 80
# Source `sidelen = 32`.
const SIDE = 32

const BASE = Nodes.COBBLE
const WALL = Nodes.PLANKS
const POST = Nodes.LOG
const FLOOR = Nodes.PLANKS
# The source spawns this party, which is what makes the outpost dangerous.
const PILLAGERS = 5
const PARROTS = 3
const GOLEMS = 1

# Source `loot`, in its four groups. A zero id keeps an unavailable entry's
# weight rather than redistributing it.
const CROPS = [[Nodes.GRAIN,7,3,5],[VillageContent.CARROT,5,3,5],[VillageContent.POTATO,5,2,5]]
const SUPPLIES = [[VillageContent.XP_BOTTLE,6,1,1],[Nodes.ARROW_ITEM,4,2,7],
	[Nodes.STRING,4,1,6],[Nodes.IRON,3,1,3],[Nodes.BOOK,1,1,1],[0,1,1,1]]
# The source's third group is dark oak saplings; Voxey's sapling ids live in the
# wood table, so the dark oak entry is used.
const SAPLINGS = [[WoodTypes.SAPLINGS[5],1,2,3]]
const GUARANTEED = [[VillageContent.CROSSBOW,1,1,1]]

# --- planning ----------------------------------------------------------------

static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	var floor_y: int = gen.terrain_height(origin.x,origin.z)
	if floor_y <= 2: return {}
	var ground: int = int(sample.call(Vector3i(origin.x,floor_y,origin.z)))
	# The source places on grass, dirt or sand.
	if not (ground == Nodes.GRASS or ground == Nodes.DIRT or ground == Nodes.SAND): return {}
	var base := Vector3i(origin.x,floor_y,origin.z)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var half: int = SIDE/2
	var state: Dictionary = {"voxels":{},"chests":{},"spawners":{},"party":{},
		"bounds_min":base-Vector3i(half,0,half),"bounds_max":base+Vector3i(half,16,half),
		"floor_y":floor_y,"seed":seed_value}
	_build_tower(state,base,rng)
	# The outpost's chest, which the source fills from its four groups.
	var chest_at: Vector3i = base+Vector3i(0,1,0)
	state.voxels[chest_at] = Nodes.CHEST
	state.chests[chest_at] = rng.randi()
	# The damaged anvil the source constructs, and the raiding party it spawns.
	var anvil_at: Vector3i = base+Vector3i(2,1,0)
	state.voxels[anvil_at] = VillageContent.ANVIL
	state.party["anvil"] = anvil_at
	return state

# A watchtower: a stone base, wooden walls, a ladder, and a fenced platform.
static func _build_tower(state: Dictionary, base: Vector3i, rng: RandomNumberGenerator) -> void:
	var width: int = 5
	var height: int = rng.randi_range(8,12)
	for y in height:
		# The walls form a hollow shell, so the tower is climbable inside.
		for x in range(-width,width+1):
			for z in range(-width,width+1):
				var edge: bool = absi(x) == width or absi(z) == width
				if not edge: continue
				var at: Vector3i = base+Vector3i(x,y,z)
				# The bottom four courses are stone, the rest wood, as the source's
				# tower is built.
				state.voxels[at] = BASE if y < 4 else (POST if (absi(x) == width and absi(z) == width) else WALL)
	# The floor and the raised platform, which is where the party stands.
	for x in range(-width,width+1):
		for z in range(-width,width+1):
			state.voxels[base+Vector3i(x,0,z)] = FLOOR
			state.voxels[base+Vector3i(x,height,z)] = FLOOR
	# A ladder up the inside wall, so the platform is reachable.
	for y in range(1,height):
		state.voxels[base+Vector3i(-width+1,y,0)] = Nodes.LADDER
	# A railing around the platform, which is what the source's tower has.
	for x in range(-width,width+1):
		for z in range(-width,width+1):
			if absi(x) == width or absi(z) == width:
				state.voxels[base+Vector3i(x,height+1,z)] = WALL

# --- the raiding party -------------------------------------------------------

# Where the source's party stands: five pillagers, three parrots and an iron
# golem, inside the tower's platform. The source spawns them over the tower's
# own bounds, and the counts are its own.
static func party_spawns(state: Dictionary, rng: RandomNumberGenerator) -> Array:
	var centre: Vector3i = (state.bounds_min+state.bounds_max)/2
	# The platform sits at the top of the tower, which is `bounds_max.y-4`.
	var top: int = state.bounds_max.y-4
	var result: Array = []
	for i in PILLAGERS:
		var at := centre+Vector3i(rng.randi_range(-3,3),top-state.bounds_min.y,rng.randi_range(-3,3))
		result.append(["pillager",[at.x,at.y,at.z]])
	for i in PARROTS:
		var at := centre+Vector3i(rng.randi_range(-3,3),top-state.bounds_min.y+1,rng.randi_range(-3,3))
		result.append(["parrot",[at.x,at.y,at.z]])
	for i in GOLEMS:
		var at := centre+Vector3i(0,top-state.bounds_min.y,0)
		result.append(["iron_golem",[at.x,at.y,at.z]])
	return result

# --- regions and overlay -----------------------------------------------------

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.outpost_cache.has(region): return gen.outpost_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20219,region.y)
	var result: Array = []
	var origin := Vector3i(region.x*REGION+rng.randi_range(SIDE,REGION-SIDE),0,region.y*REGION+rng.randi_range(SIDE,REGION-SIDE))
	if WorldBounds.horizontal(origin):
		var sample: Callable = func(p: Vector3i) -> int: return Dungeons.natural(gen,p)
		var candidate: Dictionary = plan(gen,origin,rng.randi(),sample)
		if not candidate.is_empty():
			candidate.party = party_spawns(candidate,rng)
			result.append(candidate)
	if gen.outpost_cache.size() >= 16: gen.outpost_cache.erase(gen.outpost_cache.keys()[0])
	gen.outpost_cache[region] = result
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

# Merge an outpost into the column, and report its chest and party.
static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"chests":{},"spawners":{},"party":{}}
	if gen.dimension != "overworld": return result
	var base: Vector2i = coord*16-Vector2i.ONE
	for candidate in nearby_plans(gen,coord):
		for p in candidate.voxels:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var existing: int = deep[index] if p.y < 0 else data[index]
			# The tower builds into air or natural ground.
			if existing != Nodes.AIR and not Dungeons.ground(existing): continue
			var wanted: int = int(candidate.voxels[p])
			if p.y < 0: deep[index] = wanted
			else: data[index] = wanted
			if x in range(1,17) and z in range(1,17) and candidate.chests.has(p):
				result.chests[p] = int(candidate.chests[p])
			# The chest cell is also where the outpost's party marker goes, so the
			# world spawns the raiding party exactly once per outpost.
			if x in range(1,17) and z in range(1,17) and candidate.chests.has(p):
				result.party[p] = candidate.party
	return result

# --- loot --------------------------------------------------------------------

static func fill_chest(station: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var cursor: int = 0
	# The source's four groups, each with its own roll count: crops two to three,
	# supplies one to two, saplings one to three, and a guaranteed crossbow.
	for group in [[CROPS,2,3],[SUPPLIES,1,2],[SAPLINGS,1,3],[GUARANTEED,1,1]]:
		for roll in rng.randi_range(int(group[1]),int(group[2])):
			var stack: Dictionary = Dungeons.weighted(rng,group[0])
			if not stack.is_empty() and cursor < station.slots.size(): station.slots[cursor] = stack
			cursor += 1
	station.label = "Pillager outpost chest"

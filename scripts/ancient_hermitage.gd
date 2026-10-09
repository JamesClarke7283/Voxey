class_name AncientHermitage
extends RefCounted

# Mineclonia MAPGEN/mcl_structures/ancient_hermitage.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# The hermitage is a small deep-dark ruin, and it is the **only** place the source's
# `echo shard` drops: `recovery_compass.gd` already registers the recovery compass's
# recipe — eight shards around a compass — and records that the shard had no
# acquisition route because this structure did not exist. It is also the only
# structure whose chest is the `mcl_sculk:catalyst` source, which is what the death
# spread needs before it can convert anything.
#
# The source:
#
#   * places only on `mcl_deepslate:deepslate` or `mcl_sculk:sculk`,
#   * only in the `DeepDark` biome,
#   * between `mg_overworld_min + 12` and `mg_overworld_min + 72`, i.e. deep below
#     anything Voxey's surface generator places (Voxey's overworld floor is -128, so
#     that is y -116 to y -56),
#   * with `make_foundation = true` and `solid_ground = true`,
#   * at `chunk_probability = 1`, which the source calls "high prob since placement
#     underground is relatively unlikely", and
#   * with one chest drawn from its own table, in which the catalyst has weight two,
#     the echo shard weight three for one to three, and the silence and ward armour
#     trims weight one each.
#
# Four schematics stand in for one; Voxey has no schematic loader, so the ruin is
# generated: a deepslate-brick floor and pillar shell with a sculk-touched lower
# course, the source's candles on the floor and its chest at the centre.

const REGION = 64
# Source `sidelen = 32`.
const SIDE = 32
# Source `y_max = mg_overworld_min + 72` and `y_min = mg_overworld_min + 12`, with
# Voxey's overworld floor at -128.
const Y_MIN = -128+12
const Y_MAX = -128+72

const WALL = Nodes.DEEPSLATE_BRICKS
const FLOOR = Nodes.DEEPSLATE
const SOUL = Nodes.SOUL_TORCH

# Source `loot` for the single `mcl_chests:chest_small`, in the source's own order.
# A zero id keeps an unavailable entry's weight rather than redistributing it.
#   coal 6-15/7, bone 1-15/5, soul torch 1-15/5, book 3-10/5, regeneration/5,
#   an enchanted book/5, amethyst shard 1-15/3, glow berry 1-15/3, sculk 4-10/3,
#   echo shard 1-3/3, candle 1-4/3, xp bottle 1-3/3, iron leggings/1, ward trim/1,
#   silence trim/1, catalyst 1-2/2, compass/2, disc 2/2, disc 2/2, name tag 1-3/2,
#   leather 1-5/2, diamond hoe/2, diamond horse armour/2, enchanted golden apple/1.
const LOOT = [[Nodes.COAL,7,6,15],[Nodes.BONE,5,1,15],[Nodes.SOUL_TORCH,5,1,15],
	[Nodes.BOOK,5,3,10],[0,5,1,1],[VillageContent.ENCHANTED_BOOK,5,1,1],
	[Amethyst.SHARD,3,1,15],[LushCaves.GLOW_BERRY,3,1,15],[Sculk.SCULK,3,4,10],
	[Sculk.ECHO_SHARD,3,1,3],[VillageContent.RED_CANDLE,3,1,4],[VillageContent.XP_BOTTLE,3,1,3],
	[Nodes.ARMOR_BASE+6,1,1,1],[ArmorTrims.FIRST+5,1,1,1],[ArmorTrims.FIRST+11,1,1,1],
	[Sculk.CATALYST,2,1,2],[Nodes.COMPASS,2,1,1],[Jukeboxes.DISC_13+1,2,1,1],[Jukeboxes.DISC_13+3,2,1,1],
	[Fishing.NAME_TAG,2,1,3],[Nodes.LEATHER,2,1,5],[Nodes.TOOLS+3*5+4,2,1,1],
	[Equines.DIAMOND_ARMOR,2,1,1],[Nodes.GOLDEN_APPLE,1,1,1]]
# Source `stacks_min = stacks_max = 3`.
const STACKS_MIN = 3
const STACKS_MAX = 3

# `mg_overworld_min + 12 <= y <= mg_overworld_min + 72`, and the source's own
# `place_on` set, which Voxey spells with the deepslate and sculk nodes it has.
static func depth_allowed(y: int) -> bool:
	return y >= Y_MIN and y <= Y_MAX

static func ground_allowed(id: int) -> bool:
	return id == Nodes.DEEPSLATE or id == Nodes.COBBLED_DEEPSLATE or id == Sculk.SCULK or id == Sculk.VEIN

# The source's `biomes = { "DeepDark" }`. Voxey's overworld has no deep-dark biome; the
# ruin carries its own dark, so the acceptance rule is the depth and the deepslate
# ground, which is the condition the source's biome test stands in for.
static func can_place_at(gen: TerrainGenerator, origin: Vector3i, sample: Callable = Callable()) -> bool:
	if not sample.is_valid(): sample = func(p: Vector3i) -> int: return Dungeons.natural(gen,p)
	if not depth_allowed(origin.y): return false
	return ground_allowed(int(sample.call(origin)))

# --- planning ----------------------------------------------------------------

# Plan a hermitage, or an empty dictionary where the ground is not deepslate.
static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not can_place_at(gen,origin,sample): return {}
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var half: int = SIDE/2
	# `make_foundation = true`: the shell is bedded one course below the ruin.
	var base := Vector3i(origin.x,origin.y,origin.z)
	var state: Dictionary = {"voxels":{},"chests":{},"spawners":{},
		"bounds_min":base-Vector3i(half-5,1,half-5),"bounds_max":base+Vector3i(half-5,5,half-5),
		"seed":seed_value}
	_build(state,base,half,rng)
	var chest_at: Vector3i = base+Vector3i(rng.randi_range(-4,4),1,rng.randi_range(-4,4))
	state.voxels[chest_at] = Nodes.CHEST
	state.chests[chest_at] = rng.randi()
	return state

# A roofless deepslate-brick hall: the source's `ancient_hermitage` ruin is a broken
# shell, so this lays a floor, a low wall with gaps, and a ring of pillars.
static func _build(state: Dictionary, base: Vector3i, half: int, rng: RandomNumberGenerator) -> void:
	var extent: int = mini(half-5,9)
	# The floor, with the source's sculk patches on the lower course.
	for x in range(-extent,extent+1):
		for z in range(-extent,extent+1):
			var at: Vector3i = base+Vector3i(x,0,z)
			# The wall line is a full course; the interior is floored.
			var edge: bool = absi(x) == extent or absi(z) == extent
			state.voxels[at] = WALL if edge else FLOOR
			if rng.randi_range(1,6) == 1: state.voxels[at] = Sculk.SCULK
	# The wall, three courses high, with the source's collapsed gaps.
	for level in range(1,4):
		for x in range(-extent,extent+1):
			for z in range(-extent,extent+1):
				var edge: bool = absi(x) == extent or absi(z) == extent
				if not edge: continue
				# A gap every so often: the ruin is broken, not a box.
				if rng.randi_range(1,5) == 1: continue
				state.voxels[base+Vector3i(x,level,z)] = WALL
	# Corner pillars, which stand taller than the wall.
	for sx in [-extent,extent]:
		for sz in [-extent,extent]:
			for level in range(4,6):
				if rng.randi_range(1,4) == 1: continue
				state.voxels[base+Vector3i(sx,level,sz)] = WALL
	# The source's soul torches, standing on the floor.
	for i in 4:
		var at: Vector3i = base+Vector3i(rng.randi_range(-extent+1,extent-1),1,rng.randi_range(-extent+1,extent-1))
		state.voxels[at] = SOUL

# --- regions and overlay -----------------------------------------------------

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.hermitage_cache.has(region): return gen.hermitage_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20311,region.y)
	var result: Array = []
	var origin := Vector3i(region.x*REGION+rng.randi_range(SIDE,REGION-SIDE),rng.randi_range(Y_MIN,Y_MAX),region.y*REGION+rng.randi_range(SIDE,REGION-SIDE))
	if WorldBounds.horizontal(origin):
		var sample: Callable = func(p: Vector3i) -> int: return Dungeons.natural(gen,p)
		var candidate: Dictionary = plan(gen,origin,rng.randi(),sample)
		if not candidate.is_empty(): result.append(candidate)
	if gen.hermitage_cache.size() >= 16: gen.hermitage_cache.erase(gen.hermitage_cache.keys()[0])
	gen.hermitage_cache[region] = result
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

# Merge a hermitage into the column, and report its chest. The ruin sits below y 0, so
# every cell of it lands in the deep buffer.
static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"chests":{},"spawners":{}}
	if gen.dimension != "overworld": return result
	var base: Vector2i = coord*16-Vector2i.ONE
	for candidate in nearby_plans(gen,coord):
		for p in candidate.voxels:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			if p.y < gen.min_y() or p.y >= 0: continue
			var index: int = x+z*18+(p.y-gen.min_y())*324
			var existing: int = deep[index]
			# The source's `solid_ground`: the ruin builds into solid rock, the two
			# placed-on nodes, or air.
			if not (existing == Nodes.STONE or existing == Nodes.AIR or existing == Nodes.DEEPSLATE or ground_allowed(existing)): continue
			deep[index] = int(candidate.voxels[p])
			if candidate.chests.has(p): result.chests[p] = int(candidate.chests[p])
	return result

# --- loot --------------------------------------------------------------------

# Fill a hermitage chest from the source's own table: one stack, three rolls, each
# drawn by weight.
static func fill_chest(station: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var cursor: int = 0
	for roll in rng.randi_range(STACKS_MIN,STACKS_MAX):
		var stack: Dictionary = Dungeons.weighted(rng,LOOT)
		if not stack.is_empty() and cursor < station.slots.size(): station.slots[cursor] = stack
		cursor += 1
	station.label = "Ancient hermitage chest"

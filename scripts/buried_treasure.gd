class_name BuriedTreasure
extends RefCounted

# Mineclonia MAPGEN/mcl_levelgen/buried_treasure.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# A buried treasure is a single chest, found below a beach and sunk to the first
# "chest surface" block beneath the terrain height. Its placement rule is small
# and entirely reproduced here:
#
#   * start from the surface height at the structure cell,
#   * walk **downward** until the block is andesite, diorite, granite, sandstone
#     or stone — that is the chest's support,
#   * place the chest in the air/water cell directly above it,
#   * then seal the chest's six neighbours, using the replaced surface material
#     where a neighbour is water, and guaranteeing a stable node below.
#
# The loot table gives the structure its purpose: the **heart of the sea** is the
# guaranteed first stack, with prismarine crystals, diamonds, emeralds and a
# leather chestplate or iron sword alongside. This is the reference's only route
# to a heart of the sea, so implementing it is what makes the conduit craftable
# in survival rather than creative-only.
#
# Like the mineshaft planner, this follows Voxey's pure plan/overlay split so it
# can run off-thread.

const REGION = 64
# Source places one attempt per `R(0.01, ...)` spread, i.e. roughly one per 100
# chunks, and insists on a beach.
const BEACH_DEPTH_MIN = 2
const BEACH_DEPTH_MAX = 5

# The blocks the chest may rest on, from `is_chest_surface`.
static func chest_surface(id: int) -> bool:
	return id in [VillageContent.ANDESITE,VillageContent.DIORITE,VillageContent.GRANITE,Nodes.SANDSTONE,Nodes.STONE]

# `ersatz_is_beach`: the four cells ten blocks out must all be at or below sea
# level, and the site must sit one to four blocks above it. Voxey has no biome
# map, so this geometric test is what stands in for the beach requirement — and
# it is the same test the source itself uses when ersatz generation is on, which
# is the mode Voxey targets elsewhere for the same reason.
static func beach(gen: TerrainGenerator, x: int, z: int, y: int) -> bool:
	var sea: int = TerrainGenerator.SEA
	var lowest: int = mini(mini(gen.terrain_height(x+10,z+10),gen.terrain_height(x-10,z-10)),mini(gen.terrain_height(x+10,z-10),gen.terrain_height(x-10,z+10)))
	return lowest < sea and y-sea > 1 and y-sea <= BEACH_DEPTH_MAX

# Plan one buried treasure at a cell, or an empty dictionary when the site is not
# a beach or no chest surface exists below.
static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	var x: int = origin.x
	var z: int = origin.z
	var surface: int = gen.terrain_height(x,z)
	if not beach(gen,x,z,surface): return {}
	var low: int = gen.min_y()
	var chest: Vector3i = Vector3i(0,2147483647,0)
	var replacement: int = Nodes.SAND
	var support: int = Nodes.SANDSTONE
	while surface > low:
		var below: int = int(sample.call(Vector3i(x,surface-1,z)))
		var here: int = int(sample.call(Vector3i(x,surface,z)))
		replacement = here
		if replacement == Nodes.AIR or Fluids.liquid(replacement): replacement = Nodes.SAND
		if chest_surface(below):
			chest = Vector3i(x,surface,z)
			support = below
			break
		surface -= 1
	if chest.y == 2147483647: return {}
	return {"chest":chest,"replacement":replacement,"support":support,
		"chests":{chest:seed_value},"spawners":{},"bounds_min":chest,"bounds_max":chest}

# --- regions and overlay -----------------------------------------------------

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.treasure_cache.has(region): return gen.treasure_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20141,region.y)
	var result: Array = []
	if rng.randf() < 0.06:
		var origin := Vector3i(region.x*REGION+rng.randi_range(8,REGION-8),0,region.y*REGION+rng.randi_range(8,REGION-8))
		if WorldBounds.horizontal(origin):
			var candidate: Dictionary = plan(gen,origin,rng.randi())
			if not candidate.is_empty(): result.append(candidate)
	if gen.treasure_cache.size() >= 16: gen.treasure_cache.erase(gen.treasure_cache.keys()[0])
	gen.treasure_cache[region] = result
	return result

static func nearby_plans(gen: TerrainGenerator, coord: Vector2i) -> Array:
	var base: Vector2i = coord*16-Vector2i.ONE
	var result: Array = []
	for rx in range(floori((base.x-8)/float(REGION)),floori((base.x+17)/float(REGION))+1):
		for rz in range(floori((base.y-8)/float(REGION)),floori((base.y+17)/float(REGION))+1):
			for candidate in region_plans(gen,Vector2i(rx,rz)):
				var p: Vector3i = candidate.bounds_min
				if p.x >= base.x and p.x <= base.x+17 and p.z >= base.y and p.z <= base.y+17: result.append(candidate)
	return result

# Merge each treasure chest into its column, reporting the chest so the world can
# fill it from this structure's own loot table.
static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"chests":{},"spawners":{}}
	if gen.dimension != "overworld": return result
	var base: Vector2i = coord*16-Vector2i.ONE
	for candidate in nearby_plans(gen,coord):
		var chest: Vector3i = candidate.chest
		# The source's `set_block` for the chest is unconditional, so it is
		# written even over the generated surface.
		if _write(gen,data,deep,base,chest,Nodes.CHEST):
			result.chests[chest] = int(candidate.chests.get(chest,0))
		# Then seal each neighbour that the live map holds as air or water, which
		# is the source's own `is_water_or_air` test.
		for side in [Vector3i(-1,0,0),Vector3i(1,0,0),Vector3i(0,0,-1),Vector3i(0,0,1),Vector3i(0,-1,0),Vector3i(0,1,0)]:
			var at: Vector3i = chest+side
			var here: int = _read(gen,data,deep,base,at)
			if here != Nodes.AIR and not Fluids.liquid(here): continue
			var below_open: bool = _read(gen,data,deep,base,at+Vector3i.DOWN) == Nodes.AIR or Fluids.liquid(_read(gen,data,deep,base,at+Vector3i.DOWN))
			var fill: int = int(candidate.support) if side.y != 1 and below_open else int(candidate.replacement)
			_write(gen,data,deep,base,at,fill)
	return result

static func _index(gen: TerrainGenerator, base: Vector2i, p: Vector3i) -> int:
	return p.x-base.x+(p.z-base.y)*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324

static func _inside(base: Vector2i, p: Vector3i) -> bool:
	var x: int = p.x-base.x; var z: int = p.z-base.y
	return x >= 0 and x < 18 and z >= 0 and z < 18

static func _read(gen: TerrainGenerator, data: PackedInt32Array, deep: PackedInt32Array, base: Vector2i, p: Vector3i) -> int:
	if not _inside(base,p): return Nodes.AIR
	if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): return Nodes.AIR
	return deep[_index(gen,base,p)] if p.y < 0 else data[_index(gen,base,p)]

static func _write(gen: TerrainGenerator, data: PackedInt32Array, deep: PackedInt32Array, base: Vector2i, p: Vector3i, id: int) -> bool:
	if not _inside(base,p): return false
	if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): return false
	var index: int = _index(gen,base,p)
	if p.y < 0: deep[index] = id
	else: data[index] = id
	return true

# Source `mcl_levelgen:buried_treasure` loot: the heart of the sea is guaranteed
# as the first stack, then a materials group and an optional equipment group.
static func fill(station: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	if not station.slots.is_empty(): station.slots[0] = {"id":VillageContent.HEART_OF_THE_SEA,"count":1,"wear":0}
	var cursor: int = 1
	for group in [[MATERIALS,1,4],[EQUIPMENT,0,1]]:
		for roll in rng.randi_range(group[1],group[2]):
			var stack: Dictionary = Dungeons.weighted(rng,group[0])
			if not stack.is_empty() and cursor < station.slots.size(): station.slots[cursor] = stack
			cursor += 1
	station.label = "Buried treasure"

# item, weight, minimum, maximum. Zero ids keep unavailable source entries'
# weight rather than redistributing it, matching Voxey's other loot tables.
const MATERIALS = [[VillageContent.EMERALD,5,4,8],[VillageContent.PRISMARINE_CRYSTALS,5,1,5],[Nodes.DIAMOND,5,1,2]]
# Voxey has no leather chestplate item, so its entry keeps its source weight as
# a zero id rather than being dropped, which would silently shift the odds.
const EQUIPMENT = [[0,1,1,1],[Nodes.TOOLS+13,1,1,1]]

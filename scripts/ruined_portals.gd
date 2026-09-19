class_name RuinedPortals
extends RefCounted

# Mineclonia MAPGEN/mcl_structures/ruined_portal.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# A ruined portal is a broken Nether portal frame standing on the surface. The
# source's `after_place` is what makes it interesting: it does not place a clean
# frame, it **degrades** one, and each degradation rule is an independent random
# chance applied to a different material:
#
# | Material | Chance | Becomes |
# |---|---|---|
# | Gold block | 30% | Air — the frame's gold is partly looted |
# | Lava | 20% | Magma |
# | Netherrack | 7% | Magma |
# | Obsidian | 15% | Crying obsidian |
# | Obsidian | 10% | Air |
# | Stone bricks | 50% | Cracked stone bricks |
#
# The obsidian has **two** rolls, so a frame block can become crying obsidian, or
# vanish, or both rules can pass and the block is gone. That ordering is the
# source's and is reproduced.
#
# This is also the surface source of **crying obsidian**, which the source uses
# for respawn anchors, and of loose **obsidian** — the material a player needs to
# build their own Nether portal.
#
# Voxey has no schematic loader, so the frame is generated: a rectangular
# obsidian frame on a stone brick base. The degradation rules, and the loot, are
# the source's exact behaviour.

const REGION = 56
# Source `sidelen = 10`, and `y_offset = -5`.
const SIDE = 10
const DROP = 5

# Source degradation chances, as percentages.
const GOLD_TO_AIR = 30
const LAVA_TO_MAGMA = 20
const RACK_TO_MAGMA = 7
const OBBY_TO_CRYING = 15
const OBBY_TO_AIR = 10
const BRICK_TO_CRACKED = 50

const FRAME = Nodes.OBSIDIAN
const BASE = Nodes.BRICKS
const GOLD = Nodes.GOLD_BLOCK
const LAVA = Nodes.LAVA
const RACK = Nodes.NETHERRACK

# Source `loot`: gold tools and armour, a fire charge, flint and steel, a clock,
# a bell, horse armours and an enchanted golden apple. A zero id keeps an
# unavailable entry's weight rather than redistributing it.
const TREASURE = [[Nodes.GOLD,15,2,8],[Nodes.GOLDEN_APPLE,5,1,1],[Nodes.FLINT_AND_STEEL,5,1,1],
	[0,10,1,1],[0,10,1,1],[0,8,1,1],[0,8,1,1],[0,5,1,1],[Nodes.CLOCK,3,1,1],
	[0,2,1,1],[0,2,1,1],[0,2,1,1],[0,1,1,1],[0,1,1,1]]
const SUPPLIES = [[Nodes.GOLD_NUGGET,15,2,8],[Nodes.COAL,10,1,8],[Nodes.OBSIDIAN,5,1,3],
	[Nodes.CLOCK,3,1,1],[Nodes.IRON,8,1,4],[Nodes.GOLD,8,1,3]]

# --- planning ----------------------------------------------------------------

# Plan a ruined portal, or an empty dictionary where the ground cannot hold one.
static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	var floor_y: int = gen.terrain_height(origin.x,origin.z)
	# The source places on grass, dirt, sand or snow, above y 1.
	if floor_y <= 1: return {}
	var base := Vector3i(origin.x,floor_y-DROP,origin.z)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var state: Dictionary = {"voxels":{},"materials":{},"chests":{},"spawners":{},
		"bounds_min":base-Vector3i(SIDE/2,0,SIDE/2),"bounds_max":base+Vector3i(SIDE/2,DROP+4,SIDE/2),
		"floor_y":floor_y,"seed":seed_value}
	_build_frame(state,base,rng)
	# The chest under the frame, which the source fills from its own table.
	var chest_at: Vector3i = base+Vector3i(0,DROP-1,0)
	state.voxels[chest_at] = Nodes.CHEST
	state.materials[chest_at] = "chest"
	state.chests[chest_at] = rng.randi()
	return state

# A portal frame of obsidian on a stone brick base, which is the shape the
# source's own schematics share.
static func _build_frame(state: Dictionary, base: Vector3i, rng: RandomNumberGenerator) -> void:
	var width: int = rng.randi_range(3,4)
	var height: int = rng.randi_range(4,5)
	var top: int = base.y+DROP-2
	# The stone brick base the frame stands on.
	for x in range(-width-1,width+2):
		for z in range(-2,3):
			state.voxels[Vector3i(base.x+x,base.y+3,base.z+z)] = BASE
			state.materials[Vector3i(base.x+x,base.y+3,base.z+z)] = "brick"
	# The frame itself: two uprights, a lintel, and the interior left open.
	for y in range(top,top+height):
		for x in [-width-1,width+1]:
			state.voxels[Vector3i(base.x+x,y,base.z)] = FRAME
			state.materials[Vector3i(base.x+x,y,base.z)] = "obsidian"
	for x in range(-width-1,width+2):
		state.voxels[Vector3i(base.x+x,top+height,base.z)] = FRAME
		state.materials[Vector3i(base.x+x,top+height,base.z)] = "obsidian"
	# Gold blocks decorate the frame, and a lava pool sits beside it.
	for x in [-width-2,width+2]:
		state.voxels[Vector3i(base.x+x,top,base.z)] = GOLD
		state.materials[Vector3i(base.x+x,top,base.z)] = "gold"
	for x in range(-width-1,width+2):
		var at := Vector3i(base.x+x,top+3,base.z+2)
		state.voxels[at] = LAVA
		state.materials[at] = "lava"
		var rack := Vector3i(base.x+x,top+3,base.z-2)
		state.voxels[rack] = RACK
		state.materials[rack] = "rack"

# --- the after-place callback ------------------------------------------------

# The source's `after_place`: each material degrades by its own independent roll.
static func after_place(state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var degraded: Dictionary = {}
	for p in state.voxels.keys():
		var kind: String = String(state.materials.get(p,""))
		match kind:
			"gold":
				if _passes(rng,GOLD_TO_AIR): degraded[p] = Nodes.AIR
			"lava":
				if _passes(rng,LAVA_TO_MAGMA): degraded[p] = Magma.ID
			"rack":
				if _passes(rng,RACK_TO_MAGMA): degraded[p] = Magma.ID
			"obsidian":
				# Two independent rolls, in the source's own order. If the first
				# passes the block becomes crying obsidian; the second may then
				# remove it, which is why both rules are applied in sequence.
				if _passes(rng,OBBY_TO_CRYING): degraded[p] = Bastions.CRYING_OBSIDIAN
				if _passes(rng,OBBY_TO_AIR): degraded[p] = Nodes.AIR
			"brick":
				if _passes(rng,BRICK_TO_CRACKED): degraded[p] = Masonry.CRACKED_BRICKS
	return degraded

static func _passes(rng: RandomNumberGenerator, percent: int) -> bool:
	return rng.randi_range(1,100) < percent

# --- regions and overlay -----------------------------------------------------

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.ruin_portal_cache.has(region): return gen.ruin_portal_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20189,region.y)
	var result: Array = []
	var origin := Vector3i(region.x*REGION+rng.randi_range(SIDE,REGION-SIDE),0,region.y*REGION+rng.randi_range(SIDE,REGION-SIDE))
	if WorldBounds.horizontal(origin):
		var sample: Callable = func(p: Vector3i) -> int: return Dungeons.natural(gen,p)
		var candidate: Dictionary = plan(gen,origin,rng.randi(),sample)
		if not candidate.is_empty():
			# The degradation is part of the plan, so it is decided once and cached.
			candidate.degraded = after_place(candidate,rng)
			result.append(candidate)
	if gen.ruin_portal_cache.size() >= 16: gen.ruin_portal_cache.erase(gen.ruin_portal_cache.keys()[0])
	gen.ruin_portal_cache[region] = result
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

# Merge a ruined portal into the column, and report its chest.
static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"chests":{},"spawners":{}}
	if gen.dimension != "overworld": return result
	var base: Vector2i = coord*16-Vector2i.ONE
	for candidate in nearby_plans(gen,coord):
		for p in candidate.voxels:
			var wanted: int = int(candidate.degraded.get(p,candidate.voxels[p]))
			if wanted == Nodes.AIR and not candidate.degraded.has(p): continue
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var existing: int = deep[index] if p.y < 0 else data[index]
			# The frame builds into air or natural ground, never into water.
			if existing != Nodes.AIR and not Dungeons.ground(existing): continue
			if wanted == Nodes.AIR:
				if p.y < 0: deep[index] = Nodes.AIR
				else: data[index] = Nodes.AIR
			elif p.y < 0: deep[index] = wanted
			else: data[index] = wanted
			if x in range(1,17) and z in range(1,17) and candidate.chests.has(p):
				result.chests[p] = int(candidate.chests[p])
	return result

# --- loot --------------------------------------------------------------------

static func fill_chest(station: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var cursor: int = 0
	for group in [[SUPPLIES,2,4],[TREASURE,4,8]]:
		for roll in rng.randi_range(group[1],group[2]):
			var stack: Dictionary = Dungeons.weighted(rng,group[0])
			if not stack.is_empty() and cursor < station.slots.size(): station.slots[cursor] = stack
			cursor += 1
	station.label = "Ruined portal chest"

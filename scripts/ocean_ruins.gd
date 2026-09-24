class_name OceanRuins
extends RefCounted

# Mineclonia MAPGEN/mcl_structures/ocean_ruins.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# An ocean ruin is a small sunken structure on the sea floor. The source places
# one of a set of schematic files, then does two things that matter more than the
# layout itself:
#
#   * **It converts some of the surrounding floor into suspicious sand or
#     gravel.** `place_sus_nodes` finds the ruin's own floor material within a
#     bounded box, shuffles it, and converts up to 250 cells — which is the only
#     natural source of archaeological material in the reference. That is what
#     closes Voxey's "no structure places suspicious nodes" gap.
#   * **Warm ruins are warm because they carry coral.** The source distinguishes
#     cold ruins (gravel floors) from warm ones (sand floors), and the warm
#     variant is where coral and sea pickles appear. That closes the coral and
#     sea-pickle generation gaps.
#
# Voxey has no schematic loader, so the layout is generated: a floor plate of the
# ruin's material with a broken wall ring and scattered rubble, which is the
# source's own shape for these ruins. The two rules above — the floor material
# and the suspicious-node conversion — are the source's exact behaviour.

const REGION = 64
# Source `sidelen = 10`, so a ruin spans ten blocks either way.
const SIDE = 10
# Source `chunk_probability = 10`, i.e. one attempt per ten chunks.
const ATTEMPTS = 1
# The source's `y_max = -2` bounds where it attempts a placement in its own
# layered world. Voxey's sea floor sits at a different height, so the requirement
# used instead is the one the source actually tests: submerged, over solid ground.
const SOURCE_Y_MAX = -2

# The cold variant's floor materials, which the source lists in `place_on`.
const COLD_FLOOR = "gravel"
const WARM_FLOOR = "sand"

static func is_ruin(kind: String) -> bool: return kind == "cold" or kind == "warm"

# The ruin's material, which decides whether it is a cold or a warm ruin.
static func floor_material(warm: bool) -> int:
	return Nodes.SAND if warm else Nodes.GRAVEL

# The suspicious node that replaces the floor material, as `place_sus_nodes` does.
static func suspicious_for(warm: bool) -> int:
	return Archaeology.SUSPICIOUS_SAND if warm else Archaeology.SUSPICIOUS_GRAVEL

# --- planning ----------------------------------------------------------------

# Plan one ocean ruin on the sea floor, or an empty dictionary when the site is
# not submerged.
static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	# The source requires the ruin's cell to be under water with solid ground, so
	# the site is found by sinking from the sea surface to the floor.
	var floor_y: int = gen.terrain_height(origin.x,origin.z)
	if floor_y >= TerrainGenerator.SEA: return {}
	# A ruin sits just below the floor, which is the source's `y_offset = -1`.
	var base := Vector3i(origin.x,floor_y-1,origin.z)
	# A ruin needs water above its floor and ground below it, which is the real
	# requirement the source's `spawn_by` water check and `solid_ground` express.
	# The floor must be solid ground, and the site must be below the sea. Natural
	# terrain does not carry the water column, so the submersion test is the
	# terrain height against sea level, which is what `floor_y >= SEA` above does.
	if not Dungeons.ground(Dungeons.natural(gen,base)): return {}
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	# Warm ruins are the ones that carry coral, so the split decides the content.
	var warm: bool = rng.randf() < 0.5
	var material: int = floor_material(warm)
	var half: int = SIDE/2
	var state: Dictionary = {"warm":warm,"seed":seed_value,"voxels":{},"chests":{},"spawners":{},
		"bounds_min":base-Vector3i(half,half,half),"bounds_max":base+Vector3i(half,half,half),"material":material}
	# A solid floor plate, then a broken ring of wall above it.
	for x in range(-half,half+1):
		for z in range(-half,half+1):
			var at: Vector3i = base+Vector3i(x,0,z)
			# The source places onto sand, gravel, dirt, clay and stone; anything
			# that is not ground stays untouched.
			if not Dungeons.ground(int(sample.call(at))): continue
			state.voxels[at] = material
			# Rubble and the wall ring, thinned out so the ruin reads as broken.
			var edge: bool = absi(x) == half or absi(z) == half
			if edge and rng.randf() < 0.55:
				for h in rng.randi_range(1,3):
					var wall: Vector3i = at+Vector3i(0,h,0)
					if not Dungeons.ground(int(sample.call(wall))) and int(sample.call(wall)) != Nodes.WATER: break
					state.voxels[wall] = Nodes.STONE if warm else Nodes.GRAVEL
			elif not edge and rng.randf() < 0.12:
				state.voxels[at+Vector3i(0,1,0)] = material
	# Warm ruins carry the coral that makes the biome distinctive, which is the
	# reason the source splits the two variants at all.
	if warm: _coral_and_pickles(state,base,half,rng)
	# A single chest, as the source's own loot table provides.
	if rng.randf() < 0.7:
		var chest_at: Vector3i = base+Vector3i(rng.randi_range(-half+2,half-2),1,rng.randi_range(-half+2,half-2))
		state.voxels[chest_at] = Nodes.CHEST
		state.chests[chest_at] = rng.randi()
	return state

# The warm variant's coral: a few blocks with their plants, and sea pickles on
# the dead brain coral, which is exactly what those blocks grow on.
static func _coral_and_pickles(state: Dictionary, base: Vector3i, half: int, rng: RandomNumberGenerator) -> void:
	var species: int = rng.randi_range(0,Corals.SPECIES.size()-1)
	var coral_block: int = Corals.living_id(species,Corals.BLOCK)
	for i in rng.randi_range(3,7):
		var at: Vector3i = base+Vector3i(rng.randi_range(-half+1,half-1),1,rng.randi_range(-half+1,half-1))
		state.voxels[at] = coral_block
		if rng.randf() < 0.5:
			state.voxels[at+Vector3i.UP] = Corals.living_id(species,Corals.PLANT)
	# A sea pickle needs dead brain coral under it, so it replaces one of them.
	var pickle_at: Vector3i = base+Vector3i(rng.randi_range(-half+1,half-1),1,rng.randi_range(-half+1,half-1))
	state.voxels[pickle_at] = Corals.living_id(1,Corals.DEAD_BLOCK)
	state.voxels[pickle_at+Vector3i.UP] = SeaPickles.for_size(rng.randi_range(1,4),true)
	state.spawners = {}

# --- regions and overlay -----------------------------------------------------

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.ruin_cache.has(region): return gen.ruin_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20149,region.y)
	var result: Array = []
	for i in ATTEMPTS:
		var origin := Vector3i(region.x*REGION+rng.randi_range(SIDE,REGION-SIDE),0,region.y*REGION+rng.randi_range(SIDE,REGION-SIDE))
		if not WorldBounds.horizontal(origin): continue
		var candidate: Dictionary = plan(gen,origin,rng.randi())
		if not candidate.is_empty(): result.append(candidate)
	if gen.ruin_cache.size() >= 16: gen.ruin_cache.erase(gen.ruin_cache.keys()[0])
	gen.ruin_cache[region] = result
	return result

static func nearby_plans(gen: TerrainGenerator, coord: Vector2i) -> Array:
	var base: Vector2i = coord*16-Vector2i.ONE
	var result: Array = []
	for rx in range(floori((base.x-16)/float(REGION)),floori((base.x+17)/float(REGION))+1):
		for rz in range(floori((base.y-16)/float(REGION)),floori((base.y+17)/float(REGION))+1):
			for candidate in region_plans(gen,Vector2i(rx,rz)):
				var lo: Vector3i = candidate.bounds_min
				var hi: Vector3i = candidate.bounds_max
				if hi.x >= base.x and lo.x <= base.x+17 and hi.z >= base.y and lo.z <= base.y+17: result.append(candidate)
	return result

# Merge a ruin into the column, and record the suspicious cells so the world can
# seed each one's loot. The source marks them with the structure's own name.
static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"chests":{},"spawners":{},"suspicious":{}}
	if gen.dimension != "overworld": return result
	var base: Vector2i = coord*16-Vector2i.ONE
	for candidate in nearby_plans(gen,coord):
		var rng := RandomNumberGenerator.new(); rng.seed = int(candidate.seed)
		var suspicious_id: int = suspicious_for(bool(candidate.warm))
		for p in candidate.voxels:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var existing: int = deep[index] if p.y < 0 else data[index]
			# A ruin only builds into water or natural ground.
			if existing != Nodes.WATER and not Dungeons.ground(existing): continue
			var wanted: int = int(candidate.voxels[p])
			if p.y < 0: deep[index] = wanted
			else: data[index] = wanted
			if x in range(1,17) and z in range(1,17) and candidate.chests.has(p):
				result.chests[p] = int(candidate.chests[p])
		# `place_sus_nodes`: convert some of the ruin's own floor material, up to
		# the source's 250 cell cap.
		var floor_cells: Array = []
		for p in candidate.voxels:
			if int(candidate.voxels[p]) != int(candidate.material): continue
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 1 or x > 16 or z < 1 or z > 16: continue
			floor_cells.append(p)
		if floor_cells.is_empty(): continue
		# The ruin's own generator, not the global one, keeps the choice identical
		# on every load.
		for i in range(floor_cells.size()-1,0,-1):
			var j: int = rng.randi_range(0,i)
			var swap: Vector3i = floor_cells[i]
			floor_cells[i] = floor_cells[j]
			floor_cells[j] = swap
		var count: int = mini(floor_cells.size(),rng.randi_range(1,mini(250,floor_cells.size())))
		for i in count:
			var p: Vector3i = floor_cells[i]
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if p.y < TerrainGenerator.OVERWORLD_MIN or p.y >= gen.terrain_ceiling(): continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			if p.y < 0: deep[index] = suspicious_id
			else: data[index] = suspicious_id
			# The names match the source's own loot tables: warm ruins carry the
			# angler sherd and the cold ruins the blade and explorer, so the variant
			# decides which table the node draws from.
			result.suspicious[p] = "ocean_ruins_warm" if bool(candidate.warm) else "ocean_ruins_cold"
	return result

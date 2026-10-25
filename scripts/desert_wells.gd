class_name DesertWells
extends RefCounted

# mcl_levelgen/default_features.lua: desert_well_place and its placed feature.
const RARITY = 1000
const HALF_SIZE = 2
const SALT = 0x57454c4c # Native seed namespace, not a Mineclonia placement salt.
const SIDES = [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.BACK,Vector3i.FORWARD]

static func candidate(gen: TerrainGenerator, column: Vector2i) -> Dictionary:
	if gen.dimension != "overworld": return {}
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(column.x,SALT,column.y)
	if rng.randi_range(1,RARITY) != 1: return {}
	var x: int = column.x*16+rng.randi_range(0,15)
	var z: int = column.y*16+rng.randi_range(0,15)
	if not WorldBounds.horizontal(Vector3i(x,0,z)): return {}
	if gen.biome(x,z) != "Desert": return {}
	return {"origin":Vector3i(x,gen.terrain_height(x,z)+1,z),"seed":rng.randi()}

static func plan(gen: TerrainGenerator, position: Vector3i, seed_value: int, sample: Callable = Callable(), directions: Vector2i = Vector2i(-1,-1)) -> Dictionary:
	if gen.dimension != "overworld": return {}
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	var ground: Vector3i = position
	while ground.y >= gen.min_y() and not Nodes.solid(int(sample.call(ground))): ground.y -= 1
	if ground.y-2 <= gen.min_y() or ground.y+4 >= gen.terrain_ceiling(): return {}
	var slab: int = BuildingShapes.slab_for(Nodes.SANDSTONE)
	for x in range(-2,3):
		for z in range(-2,3):
			for y in range(-2,1):
				var id: int = int(sample.call(ground+Vector3i(x,y,z)))
				# Source permits air at surface level but needs both lower layers.
				if id == slab or id == Nodes.AIR and y != 0: return {}
	var result: Dictionary = {"origin":ground,"voxels":{},"states":{},"seed":seed_value}
	for x in range(-2,3):
		for z in range(-2,3):
			for y in range(-2,1): result.voxels[ground+Vector3i(x,y,z)] = Nodes.SANDSTONE
			if absi(x) == 2 or absi(z) == 2:
				result.voxels[ground+Vector3i(x,1,z)] = slab if x == 0 or z == 0 else Nodes.SANDSTONE
	for side in [Vector3i.ZERO]+SIDES:
		result.voxels[ground+side] = Nodes.WATER
		result.voxels[ground+side+Vector3i.DOWN] = Nodes.SAND
	for x in [-1,1]:
		for z in [-1,1]:
			for y in range(1,4): result.voxels[ground+Vector3i(x,y,z)] = Nodes.SANDSTONE
	for x in range(-1,2):
		for z in range(-1,2): result.voxels[ground+Vector3i(x,4,z)] = Nodes.SANDSTONE if x == 0 and z == 0 else slab
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var first: int = rng.randi_range(0,3); var second: int = rng.randi_range(0,3)
	if directions.x >= 0: first = directions.x; second = directions.y
	for i in 2:
		var p: Vector3i = ground+SIDES[first if i == 0 else second]+Vector3i.DOWN*(i+1)
		result.voxels[p] = Archaeology.SUSPICIOUS_SAND
		result.states[p] = {"structure":"desert_well","archaeology_seed":rng.randi()&0x7fffffff}
	return result

static func generated(gen: TerrainGenerator, column: Vector2i) -> Dictionary:
	if gen.well_cache.has(column): return gen.well_cache[column]
	var candidate_data: Dictionary = candidate(gen,column)
	var result: Dictionary = {} if candidate_data.is_empty() else plan(gen,candidate_data.origin,candidate_data.seed)
	if gen.well_cache.size() >= 32: gen.well_cache.erase(gen.well_cache.keys()[0])
	gen.well_cache[column] = result
	return result

static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"states":{}}
	if gen.dimension != "overworld": return result
	var low: Vector2i = coord*16-Vector2i.ONE
	for x in range(coord.x-1,coord.x+2):
		for z in range(coord.y-1,coord.y+2):
			var well: Dictionary = generated(gen,Vector2i(x,z))
			for p in well.get("voxels",{}):
				var lx: int = p.x-low.x; var lz: int = p.z-low.y
				if lx < 0 or lx >= 18 or lz < 0 or lz >= 18: continue
				if p.y < 0: deep[lx+lz*18+(p.y-gen.min_y())*324] = well.voxels[p]
				else: data[lx+lz*18+p.y*324] = well.voxels[p]
				if well.states.has(p): result.states[p] = well.states[p]
	return result

static func install(world: VoxelWorld, result: Dictionary) -> void:
	for p in result.get("wells",{}).get("states",{}):
		if Vector2i(p.x >> 4,p.z >> 4) != result.coord or world.edits.has(p) or world.node_at(p) != Archaeology.SUSPICIOUS_SAND: continue
		# Larger structure overlays run later and own any archaeology they replace.
		if result.get("ruins",{}).get("suspicious",{}).has(p) or result.get("temples",{}).get("suspicious",{}).has(p): continue
		var key: String = VoxelWorld.station_key(p)
		if not world.block_states.has(key): world.block_states[key] = result.wells.states[p].duplicate(true)

static func nearest(gen: TerrainGenerator, origin: Vector3) -> Vector3i:
	var center := Vector2i(floori(origin.x/16.0),floori(origin.z/16.0))
	var found := Vector3i.ZERO; var distance: float = INF
	for ring in 161:
		var perimeter: Array = [center] if ring == 0 else []
		if ring > 0:
			for offset in range(-ring,ring+1):
				perimeter.append(center+Vector2i(-ring,offset)); perimeter.append(center+Vector2i(ring,offset))
			for offset in range(-ring+1,ring):
				perimeter.append(center+Vector2i(offset,-ring)); perimeter.append(center+Vector2i(offset,ring))
		for column in perimeter:
			var info: Dictionary = candidate(gen,column)
			if info.is_empty(): continue
			var gap: float = Vector2(info.origin.x-origin.x,info.origin.z-origin.z).length_squared()
			if gap >= distance: continue
			var well: Dictionary = generated(gen,column)
			if well.is_empty(): continue
			distance = gap; found = well.origin
		if distance < pow(maxi(0,ring-1)*16.0,2): break
	return found

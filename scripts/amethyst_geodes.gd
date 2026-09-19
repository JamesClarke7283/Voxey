class_name AmethystGeodes
extends RefCounted

# Distance fields, layers, crack and decoration probabilities from the supplied
# mcl_amethyst/lg_register.lua. Voxey's seeded RNG/noise and terrain are adapters.
const EXTENT = 16
const SIDES = [Vector3i.UP,Vector3i.DOWN,Vector3i.RIGHT,Vector3i.LEFT,Vector3i.BACK,Vector3i.FORWARD]

static func replaceable(id: int) -> bool:
	return id == Nodes.AIR or Dungeons.ground(id) or Fluids.liquid(id) or id in [Amethyst.BLOCK,Amethyst.BUDDING,Amethyst.CALCITE,Amethyst.SMOOTH_BASALT] or Amethyst.is_crystal(id)

static func invalid(id: int) -> bool:
	return id == Nodes.AIR or Fluids.liquid(id) or id == Nodes.BEDROCK or DenseMaterials.is_ice(id)

static func protected_area(gen: TerrainGenerator, origin: Vector3i) -> bool:
	var low: Vector3i = origin-Vector3i.ONE*17; var high: Vector3i = origin+Vector3i.ONE*17
	# Village flattening reaches from its computed underground pad up to sky.
	if Dungeons.touches_village(gen,Vector3i(low.x,high.y-5,low.z),Vector2i(33,33)): return true
	var stronghold: Vector3i = WorldStructures.stronghold(gen.world_seed,Vector2i(floori(origin.x/512.0),floori(origin.z/512.0)))
	if AABB(Vector3(low),Vector3.ONE*35).intersects(AABB(Vector3(stronghold-Vector3i(24,0,11)),Vector3(35,10,23))): return true
	for rx in range(floori((low.x-8)/32.0),floori(high.x/32.0)+1):
		for rz in range(floori((low.z-8)/32.0),floori(high.z/32.0)+1):
			for dungeon in Dungeons.region_plans(gen,Vector2i(rx,rz)):
				if AABB(Vector3(low),Vector3.ONE*35).intersects(AABB(Vector3(dungeon.origin),Vector3(dungeon.size.x+2,6,dungeon.size.y+2))): return true
	return false

static func plan(gen: TerrainGenerator, origin: Vector3i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return Dungeons.natural(gen,p)
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var points: Array = []; var cracks: Array = []
	var count: int = rng.randi_range(3,4); var cracked: bool = rng.randf() < 0.95; var malus: int = 0
	for i in count:
		var point: Vector3i = origin+Vector3i(rng.randi_range(4,6),rng.randi_range(4,6),rng.randi_range(4,6))
		if invalid(int(sample.call(point))):
			malus += 1
			if malus > 1: return {}
		points.append([Vector3(point),rng.randi_range(1,2)])
	if cracked:
		var face: int = rng.randi_range(0,3); var offset: int = count*2+1
		match face:
			0: cracks = [Vector3(origin.x+offset,origin.y+7,origin.z),Vector3(origin.x+offset,origin.y+5,0),Vector3(origin.x+offset,origin.y+1,0)]
			1: cracks = [Vector3(origin.x,origin.y+7,origin.z+offset),Vector3(origin.x,origin.y+5,origin.z+offset),Vector3(origin.x,origin.y+1,origin.z+offset)]
			2: cracks = [Vector3(origin.x+offset,origin.y+7,origin.z+offset),Vector3(origin.x+offset,origin.y+5,origin.z+offset),Vector3(origin.x+offset,origin.y+1,origin.z+offset)]
			_: cracks = [Vector3(origin.x,origin.y+7,origin.z),Vector3(origin.x,origin.y+5,origin.z),Vector3(origin.x,origin.y+1,origin.z)]
	var contribution: float = count/6.0
	var filling: float = 1.0/sqrt(1.7); var inner: float = 1.0/sqrt(2.2+contribution)
	var middle: float = 1.0/sqrt(3.2+contribution); var outer: float = 1.0/sqrt(4.2+contribution)
	var crack_size: float = 2.0+rng.randf()*0.5+(contribution if count > 3 else 0.0)
	var crack_threshold: float = 1.0/sqrt(crack_size)
	var noise := FastNoiseLite.new(); noise.seed = gen.world_seed+7894353; noise.frequency = 1.0/16; noise.fractal_octaves = 1
	var voxels: Dictionary = {}; var decorate: Array = []
	for x in range(origin.x-EXTENT,origin.x+EXTENT+1):
		for y in range(maxi(gen.min_y()+1,origin.y-EXTENT),mini(gen.terrain_ceiling(),origin.y+EXTENT+1)):
			for z in range(origin.z-EXTENT,origin.z+EXTENT+1):
				var p := Vector3i(x,y,z); var point := Vector3(p)
				var jitter: float = noise.get_noise_3d(x,y,z)*0.05; var distance: float = 0
				for dot in points: distance += 1.0/sqrt(point.distance_squared_to(dot[0])+dot[1])+jitter
				if distance < outer: continue
				var crack_distance: float = 0
				for dot in cracks: crack_distance += 1.0/sqrt(point.distance_squared_to(dot)+2)+jitter
				var id: int
				if cracked and crack_distance >= crack_threshold and distance < filling: id = Nodes.AIR
				elif distance >= filling: id = Nodes.AIR
				elif distance >= inner:
					id = Amethyst.BUDDING if rng.randf() <= 0.083 else Amethyst.BLOCK
					if id == Amethyst.BUDDING and rng.randf() < 0.35: decorate.append(p)
				elif distance >= middle: id = Amethyst.CALCITE
				else: id = Amethyst.SMOOTH_BASALT
				if replaceable(int(sample.call(p))): voxels[p] = id
	for p in decorate:
		if voxels.get(p,0) != Amethyst.BUDDING: continue
		var crystal: int = Amethyst.STAGES[rng.randi_range(0,3)]
		for direction in SIDES:
			var at: Vector3i = p+direction
			if at.y <= gen.min_y() or at.y >= gen.terrain_ceiling(): continue
			var before: int = int(voxels[at]) if voxels.has(at) else int(sample.call(at))
			if before == Nodes.AIR or Fluids.water(before): voxels[at] = Amethyst.oriented(crystal,direction)
	return {"origin":origin,"voxels":voxels,"points":points,"cracked":cracked}

static func candidate(gen: TerrainGenerator, coord: Vector2i) -> Dictionary:
	if gen.dimension != "overworld": return {}
	if not gen.has_meta("amethyst_cache"): gen.set_meta("amethyst_cache",{})
	var cache: Dictionary = gen.get_meta("amethyst_cache")
	if cache.has(coord): return cache[coord]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(coord.x,7894353,coord.y)
	var result: Dictionary = {}
	if rng.randi_range(1,24) == 1:
		var origin := Vector3i(coord.x*16+rng.randi_range(0,15),rng.randi_range(gen.min_y()+6,30),coord.y*16+rng.randi_range(0,15))
		if WorldBounds.horizontal(origin-Vector3i.ONE*17) and WorldBounds.horizontal(origin+Vector3i.ONE*17) and not protected_area(gen,origin): result = plan(gen,origin,rng.randi())
	if cache.size() >= 64: cache.erase(cache.keys()[0])
	cache[coord] = result
	return result

static func nearby(gen: TerrainGenerator, coord: Vector2i) -> Array:
	var result: Array = []
	for x in range(coord.x-2,coord.x+3):
		for z in range(coord.y-2,coord.y+3):
			var room: Dictionary = candidate(gen,Vector2i(x,z))
			if not room.is_empty(): result.append(room)
	return result

static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> void:
	if gen.dimension != "overworld": return
	var base: Vector2i = coord*16-Vector2i.ONE
	for room in nearby(gen,coord):
		for p in room.voxels:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			var before: int = deep[index] if p.y < 0 else data[index]
			if not replaceable(before): continue
			if p.y < 0: deep[index] = room.voxels[p]
			else: data[index] = room.voxels[p]

class_name Dungeons
extends RefCounted

# Mineclonia mcl_dungeons/init.lua and mcl_mobspawners/init.lua.
const SPAWNER = 7300
const REGION = 32
const HEIGHT = 4
const DATA = {SPAWNER:{"name":"Mob spawner","block":true,"shape":"spawner","color":"495563","hardness":5.0,"tool":0,"hidden":true,"blast_resistance":5.0}}
const MOBS = ["zombie","zombie","spider","skeleton"]
const SIDES = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
# Zero IDs keep unavailable source entries' weight, never redistribute it.
# item, weight, minimum, maximum. Book is enchanted when selected.
const TREASURE = [[1200,20,1,1],[Nodes.LEATHER,20,1,5],[Jukeboxes.DISC_13,15,1,1],[Jukeboxes.FAR,15,1,1],[Jukeboxes.CHIRP,3,1,1],[0,15,1,1],[0,15,1,1],[Nodes.GOLDEN_APPLE,15,1,1],[VillageContent.ENCHANTED_BOOK,10,1,1],[0,10,1,1],[0,5,1,1],[0,2,1,1]]
const SUPPLIES = [[Nodes.GRAIN,20,1,4],[Nodes.BREAD,20,1,1],[Nodes.COAL,15,1,4],[Nodes.REDSTONE_WIRE,15,1,4],[VillageContent.BEETROOT_SEEDS,10,2,4],[FruitCrops.MELON_SEEDS,10,2,4],[FruitCrops.PUMPKIN_SEEDS,10,2,4],[Nodes.IRON,10,1,4],[Nodes.BUCKET,10,1,1],[Nodes.GOLD,5,1,4]]
const REMAINS = [[Nodes.BONE,10,1,8],[Nodes.GUNPOWDER,10,1,8],[Nodes.ROTTEN_FLESH,10,1,8],[Nodes.STRING,10,1,8]]

static func ground(id: int) -> bool:
	return id != Nodes.BEDROCK and (id == Nodes.AIR or id in [Nodes.STONE,Nodes.DEEPSLATE,Nodes.COBBLE,Nodes.MOSSY_COBBLE,Nodes.GRAVEL,Nodes.DIRT,Nodes.GRASS,Nodes.SAND,Nodes.SANDSTONE,Nodes.SNOW,Nodes.ICE] or Nodes.DEEP_ORES.has(id) or id in [MinecloniaOres.TUFF,VillageContent.GRANITE,VillageContent.DIORITE,VillageContent.ANDESITE,Nodes.COAL_ORE,Nodes.IRON_ORE,Nodes.COPPER_ORE,Nodes.GOLD_ORE,Nodes.DIAMOND_ORE,Nodes.LAPIS_ORE,Nodes.REDSTONE_ORE,VillageContent.EMERALD_ORE,VillageContent.DEEP_EMERALD_ORE])

# Dungeons test unedited geological terrain. No recursive column generation or
# scene-tree access occurs on workers. Ores do not change these solid/air tests.
static func natural(gen: TerrainGenerator, p: Vector3i) -> int:
	if p.y < 0: return gen.deep_node(p.x,p.y,p.z,false)
	var h: int = gen.terrain_height(p.x,p.z)
	if p.y > h: return Nodes.WATER if p.y <= TerrainGenerator.SEA else Nodes.AIR
	var c: float = gen.climate.get_noise_2d(p.x,p.z)
	if p.y == h: return Nodes.SAND if c > 0.28 or h <= TerrainGenerator.SEA+1 else (Nodes.SNOW if c < -0.35 else Nodes.GRASS)
	if p.y > h-4: return Nodes.SAND if c > 0.28 or h <= TerrainGenerator.SEA+1 else Nodes.DIRT
	if p.y > 2 and p.y < h-4 and gen.caves.get_noise_3d(p.x,p.y*1.3,p.z) > 0.39: return Nodes.LAVA if p.y <= 7 else Nodes.AIR
	return Nodes.STONE

static func openings(origin: Vector3i, size: Vector2i, sample: Callable) -> Dictionary:
	for x in range(1,size.x+1):
		for z in range(1,size.y+1):
			if not Nodes.solid(sample.call(origin+Vector3i(x,0,z))) or not Nodes.solid(sample.call(origin+Vector3i(x,HEIGHT+1,z))): return {}
	var holes: Dictionary = {}; var corners: Array = []
	for x in range(size.x+2):
		for z in range(size.y+2):
			if x not in [0,size.x+1] and z not in [0,size.y+1]: continue
			var at: Vector3i = origin+Vector3i(x,1,z)
			if sample.call(at) == Nodes.AIR and sample.call(at+Vector3i.UP) == Nodes.AIR:
				holes[Vector2i(x,z)] = true
				if x in [0,size.x+1] and z in [0,size.y+1]: corners.append(Vector2i(x,z))
	if holes.is_empty() or holes.size() > 5: return {}
	# Source corner caves are widened along the two adjoining wall cells.
	for corner in (corners if holes.size() == corners.size() else []):
		if holes.size() >= 5: break
		holes[corner+Vector2i(0,1 if corner.y == 0 else -1)] = true
		if holes.size() < 5: holes[corner+Vector2i(1 if corner.x == 0 else -1,0)] = true
	return holes

static func plan(gen: TerrainGenerator, origin: Vector3i, size: Vector2i, seed_value: int, sample: Callable = Callable()) -> Dictionary:
	if not sample.is_valid(): sample = func(p): return natural(gen,p)
	var holes: Dictionary = openings(origin,size,sample)
	if holes.is_empty(): return {}
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var walls: Array = []
	for x in range(1,size.x+1):
		for z in range(1,size.y+1):
			if x in [1,size.x] or z in [1,size.y]: walls.append(Vector3i(x,1,z))
	var a: int = rng.randi_range(0,walls.size()-1); var b: int = rng.randi_range(0,walls.size()-1)
	if a == b: b = rng.randi_range(0,walls.size()-1)
	var chests: Dictionary = {}; var voxels: Dictionary = {}
	for x in range(size.x+2):
		for z in range(size.y+2):
			for y in range(HEIGHT+1):
				var p: Vector3i = origin+Vector3i(x,y,z)
				var before: int = int(sample.call(p))
				if not ground(before): continue
				if y == 0: voxels[p] = Nodes.COBBLE if rng.randi_range(1,4) == 1 else Nodes.MOSSY_COBBLE
				elif x in [0,size.x+1] or z in [0,size.y+1]:
					if y == HEIGHT or not holes.has(Vector2i(x,z)): voxels[p] = Nodes.COBBLE
					elif y < HEIGHT-1: voxels[p] = Nodes.AIR
					elif before != Nodes.AIR: voxels[p] = Nodes.COBBLE
				else: voxels[p] = Nodes.AIR
	for index in [a,b]:
		var p: Vector3i = origin+walls[index]
		if voxels.has(p): voxels[p] = Nodes.CHEST; chests[p] = gen.hash_at(p.x,p.y+20117,p.z)
	var spawner: Vector3i = origin+Vector3i(ceili(size.x/2.0),1,ceili(size.y/2.0))
	var kinds: Dictionary = {}
	if ground(int(sample.call(spawner))): voxels[spawner] = SPAWNER; kinds[spawner] = MOBS[rng.randi_range(0,3)]
	return {"origin":origin,"size":size,"voxels":voxels,"spawners":kinds,"chests":chests,"openings":holes}

# VillageGenerator flattens terrain before dungeon overlay. Raw geology must
# not qualify a room whose floor/roof was removed, or carve village buildings.
static func touches_village(gen: TerrainGenerator, origin: Vector3i, size: Vector2i) -> bool:
	if origin.y+HEIGHT+1 < 1: return false
	var village: Dictionary = VillageGenerator.settlement(gen,Vector2i(floori(origin.x/320.0),floori(origin.z/320.0)))
	var center: Vector3i = village.center
	for x in range(maxi(origin.x,center.x-42),mini(origin.x+size.x+2,center.x+43)):
		for z in range(maxi(origin.z,center.z-36),mini(origin.z+size.y+2,center.z+48)):
			var q := Vector2i(x-center.x,z-center.z)
			var edge: float = maxf(absf(q.x)/42.0,maxf(-q.y/36.0,q.y/47.0))
			var terrain: int = gen.terrain_height(x,z)
			var base_y: int = center.y if edge < 0.82 else roundi(lerpf(center.y,terrain,clampf((edge-0.82)/0.18,0,1)))
			if origin.y+HEIGHT+1 >= maxi(1,mini(base_y,terrain)-7): return true
	return false

static func region_plans(gen: TerrainGenerator, region: Vector2i) -> Array:
	if gen.dimension != "overworld": return []
	if gen.dungeon_cache.has(region): return gen.dungeon_cache[region]
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(region.x,20119,region.y)
	var result: Array = []
	var attempts: int = ceili(float(REGION*REGION*(gen.terrain_ceiling()-gen.min_y()))/8192)
	for i in attempts:
		var size := Vector2i(5+2*rng.randi_range(0,1),5+2*rng.randi_range(0,1))
		var origin := Vector3i(region.x*REGION+rng.randi_range(0,REGION-1),rng.randi_range(gen.min_y()+1,gen.terrain_ceiling()-HEIGHT-2),region.y*REGION+rng.randi_range(0,REGION-1))
		if not WorldBounds.horizontal(origin) or not WorldBounds.horizontal(origin+Vector3i(size.x+1,0,size.y+1)): continue
		if touches_village(gen,origin,size): continue
		var stronghold: Vector3i = WorldStructures.stronghold(gen.world_seed,Vector2i(floori(origin.x/512.0),floori(origin.z/512.0)))
		if origin.y <= stronghold.y+10 and origin.y+HEIGHT >= stronghold.y and absi(origin.x-stronghold.x) <= 34 and absi(origin.z-stronghold.z) <= 21: continue
		var candidate: Dictionary = plan(gen,origin,size,rng.randi())
		if not candidate.is_empty(): result.append(candidate)
	if gen.dungeon_cache.size() >= 32: gen.dungeon_cache.erase(gen.dungeon_cache.keys()[0])
	gen.dungeon_cache[region] = result
	return result

static func nearby_plans(gen: TerrainGenerator, coord: Vector2i) -> Array:
	var base: Vector2i = coord*16-Vector2i.ONE
	var result: Array = []
	for rx in range(floori((base.x-8)/float(REGION)),floori((base.x+17)/float(REGION))+1):
		for rz in range(floori((base.y-8)/float(REGION)),floori((base.y+17)/float(REGION))+1):
			for candidate in region_plans(gen,Vector2i(rx,rz)):
				var p: Vector3i = candidate.origin; var size: Vector2i = candidate.size
				if p.x+size.x+1 >= base.x and p.x <= base.x+17 and p.z+size.y+1 >= base.y and p.z <= base.y+17: result.append(candidate)
	return result

static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> Dictionary:
	var result: Dictionary = {"spawners":{},"chests":{}}
	if gen.dimension != "overworld": return result
	var base: Vector2i = coord*16-Vector2i.ONE
	for candidate in nearby_plans(gen,coord):
		for p in candidate.voxels:
			var x: int = p.x-base.x; var z: int = p.z-base.y
			if x < 0 or x >= 18 or z < 0 or z >= 18: continue
			var index: int = x+z*18+(p.y-gen.min_y() if p.y < 0 else p.y)*324
			# The candidate only replaces geological terrain; actual structures
			# and later player edits keep priority over this overlay.
			var existing: int = deep[index] if p.y < 0 else data[index]
			if not ground(existing): continue
			if p.y < 0: deep[index] = candidate.voxels[p]
			else: data[index] = candidate.voxels[p]
			if x in range(1,17) and z in range(1,17):
				if candidate.spawners.has(p): result.spawners[p] = candidate.spawners[p]
				if candidate.chests.has(p): result.chests[p] = candidate.chests[p]
	return result

static func weighted(rng: RandomNumberGenerator, pool: Array) -> Dictionary:
	var total: int = 0
	for entry in pool: total += entry[1]
	var roll: int = rng.randi_range(1,total)
	for entry in pool:
		roll -= entry[1]
		if roll > 0: continue
		var amount: int = rng.randi_range(entry[2],entry[3])
		if entry[0] == 0: return {}
		var stack: Dictionary = {"id":entry[0],"count":amount,"wear":0}
		if entry[0] == VillageContent.ENCHANTED_BOOK:
			var choices: Array = Enchantments.DATA.keys().filter(func(name): return name != "Soul Speed")
			var name: String = choices[rng.randi_range(0,choices.size()-1)]
			stack.data = {"enchantments":{name:rng.randi_range(1,Enchantments.DATA[name].max)}}
		return stack
	return {}

static func fill(station: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var indices: Array = range(station.slots.size())
	for i in range(indices.size()-1,0,-1):
		var other: int = rng.randi_range(0,i); var old: int = indices[i]; indices[i] = indices[other]; indices[other] = old
	var cursor: int = 0
	for group in [[TREASURE,1,3],[SUPPLIES,1,4],[REMAINS,3,3]]:
		for roll in rng.randi_range(group[1],group[2]):
			var stack: Dictionary = weighted(rng,group[0])
			if not stack.is_empty(): station.slots[indices[cursor]] = stack
			cursor += 1
	station.label = "Dungeon treasure"; station.dungeon_loot = true

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("dungeons"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+20123
		world.set_meta("dungeons",{"cells":{},"columns":{},"jobs":[],"pending":{},"rng":rng})
	return world.get_meta("dungeons")

static func station(world: VoxelWorld, p: Vector3i, kind: String = "zombie") -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.stations.has(key): world.stations[key] = {"kind":"mob_spawner","mob":kind,"remaining":2.0,"slots":[]}
	var result: Dictionary = world.stations[key]
	result.kind = "mob_spawner"; result.slots = []
	result.mob = str(result.get("mob",kind)) if str(result.get("mob",kind)) in MOBS else "zombie"
	result.remaining = clampf(float(result.get("remaining",2.0)),0,40)
	return result

static func doll(kind: String) -> Node3D:
	# Build a visual-only copy of existing original art, never a registered mob.
	var builder := Creature.new(); builder.kind = kind; builder.model = Node3D.new(); builder.add_child(builder.model)
	builder._build_model()
	var model: Node3D = builder.model; builder.remove_child(model); builder.free()
	model.scale = Vector3.ONE*0.32
	return model

static func registered(world: VoxelWorld, p: Vector3i, kind: String = "zombie") -> void:
	if world.node_at(p) != SPAWNER or not world.loaded_at(Vector3(p)): return
	var state: Dictionary = runtime(world)
	if state.cells.has(p): return
	var data: Dictionary = station(world,p,kind)
	var display: Node3D = doll(data.mob)
	world.add_child(display); display.position = Vector3(p)+Vector3(0.5,0.15,0.5)
	state.cells[p] = display
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not state.columns.has(column): state.columns[column] = {}
	state.columns[column][p] = true

static func remove_runtime(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("dungeons"): return
	var state: Dictionary = runtime(world)
	if state.cells.has(p):
		if is_instance_valid(state.cells[p]): state.cells[p].queue_free()
		state.cells.erase(p)
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if state.columns.has(column):
		state.columns[column].erase(p)
		if state.columns[column].is_empty(): state.columns.erase(column)
	state.jobs = state.jobs.filter(func(job): return job.pos != p)
	state.pending.erase(p)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("dungeons"): return
	for p in runtime(world).columns.get(column,{}).keys(): remove_runtime(world,p)

static func reset(world: VoxelWorld) -> void:
	if not world.has_meta("dungeons"): return
	for p in runtime(world).cells.keys(): remove_runtime(world,p)
	world.remove_meta("dungeons")

static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if old_id == SPAWNER and id != SPAWNER:
		remove_runtime(world,p); world.stations.erase(VoxelWorld.station_key(p))
		var game: Node = world.get_parent()
		if game != null and game.has_method("spawn_creature"): game.experience += randi_range(15,43)
	elif id == SPAWNER: registered(world,p)

static func allowed(world: VoxelWorld, p: Vector3i, kind: String, rng: RandomNumberGenerator) -> bool:
	if not world.loaded_at(Vector3(p)): return false
	var info: Dictionary = Creature.KINDS[kind]
	var at: Vector3 = Vector3(p)+Vector3(0.5,0.01,0.5)
	if world.intersects(at,info.width,info.height): return false
	for y in range(p.y,ceili(p.y+info.height)):
		var id: int = world.node_at(Vector3i(p.x,y,p.z))
		if Fluids.liquid(id) or Fire.is_fire(id) or id == Nodes.CACTUS: return false
	if Pasture.block_light(world,p,1) > 0: return false
	var sky: int = RedstoneSensors.natural_light(world,p)
	return sky <= 6 and sky <= rng.randi_range(0,31)

static func nearby_count(world: VoxelWorld, p: Vector3i, kind: String) -> int:
	var count: int = 0
	for mob in world.get_parent().creatures.get_children():
		if not mob.is_queued_for_deletion() and mob.kind == kind and mob.position.distance_to(Vector3(p)+Vector3.ONE*0.5) <= 8: count += 1
	return count

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("dungeons"): return
	var game: Node = world.get_parent()
	if game == null or not game.playing(): return
	var state: Dictionary = runtime(world); var rng: RandomNumberGenerator = state.rng
	for p in state.cells.keys():
		if world.node_at(p) != SPAWNER or not world.loaded_at(Vector3(p)): remove_runtime(world,p); continue
		state.cells[p].rotation.y += PI*2.9*delta
		var data: Dictionary = station(world,p)
		if state.pending.has(p): continue
		data.remaining = maxf(0,float(data.remaining)-maxf(0,delta))
		if data.remaining > 0: continue
		if game.player.position.distance_to(Vector3(p)+Vector3.ONE*0.5) > 15: data.remaining = 2.0; continue
		if nearby_count(world,p,data.mob) >= 4: data.remaining = rng.randf_range(5,20); continue
		var cells: Array = range(243)
		for i in range(cells.size()-1,0,-1):
			var j: int = rng.randi_range(0,i); var old: int = cells[i]; cells[i] = cells[j]; cells[j] = old
		data.remaining = rng.randf_range(10,39.95)
		state.pending[p] = true
		state.jobs.append({"pos":p,"mob":data.mob,"cells":cells,"cursor":0,"spawned":0})
	# Bound cold light/collision work to eight candidates total per frame.
	var budget: int = 8
	while budget > 0 and not state.jobs.is_empty():
		var job: Dictionary = state.jobs[0]
		if not state.cells.has(job.pos) or game.player.position.distance_to(Vector3(job.pos)+Vector3.ONE*0.5) > 15: state.pending.erase(job.pos); state.jobs.pop_front(); continue
		# Another queued spawner may have completed a wave first. Source checks
		# this once before each burst, not after each individual spawned mob.
		if job.cursor == 0 and nearby_count(world,job.pos,job.mob) >= 4:
			station(world,job.pos).remaining = rng.randf_range(5,20)
			state.pending.erase(job.pos); state.jobs.pop_front(); continue
		var index: int = job.cells[job.cursor]
		job.cursor += 1; budget -= 1
		var p: Vector3i = job.pos+Vector3i(index%9-4,(index/9)%3,index/27-4)
		if allowed(world,p,job.mob,rng):
			game.spawn_creature(job.mob,Vector3(p)+Vector3(0.5,0.01,0.5)); job.spawned += 1
		if job.spawned >= 4 or job.cursor >= 243: state.pending.erase(job.pos); state.jobs.pop_front()

static func pixel(_id: int, x: int, y: int, noise: Color) -> Color:
	return Color("66727b") if x%5 == 0 or y%5 == 0 else noise.darkened(0.35)

static func mesh(out: Array, at: Vector3) -> void:
	var tile: int = Nodes.tile(SPAWNER,0)
	for axis in 3:
		for a in [0.04,0.34,0.66,0.96]:
			for b in [0.04,0.96]:
				var center := Vector3.ONE*0.5; var size := Vector3.ONE*0.055
				center[(axis+1)%3] = a; center[(axis+2)%3] = b; size[axis] = 1.0
				BlockMesher._art_box(out,at+center,size,tile,tile)

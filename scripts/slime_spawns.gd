class_name SlimeSpawns
extends RefCounted

static func slime_chunk(seed: int, chunk: Vector2i) -> bool:
	# One tenth of 16x16 columns. Floor division is deliberate at negative X/Z.
	var h: int = (chunk.x*73428767) ^ (chunk.y*912931) ^ seed ^ 987234911
	h = ((h ^ (h >> 13))*1274126177)&0x7fffffff
	return (h ^ (h >> 16))%10 == 0

static func underground(gen: TerrainGenerator, pos: Vector3) -> bool:
	return gen.dimension == "overworld" and pos.y <= -24 and slime_chunk(gen.world_seed,Vector2i(floori(pos.x/16),floori(pos.z/16)))

static func surface(gen: TerrainGenerator, pos: Vector3, daylight: float, day: int) -> bool:
	# Voxey's surface datum is lower than Mineclonia's, so use the local ground height.
	var height: int = gen.terrain_height(floori(pos.x),floori(pos.z))
	return gen.dimension == "overworld" and gen.biome(floori(pos.x),floori(pos.z)) == "Swamp" and absf(pos.y-(height+1)) <= 3 and daylight < 0.35 and posmod(day-1,8) != 4

static func try_spawn(game: Node3D, pos: Vector3) -> bool:
	var gen: TerrainGenerator = game.world.generator
	var cave: bool = underground(gen,pos)
	var swamp: bool = surface(gen,pos,game.daylight,game.day_number())
	if not cave and not swamp: return false
	if swamp and not cave:
		for p in game.torch_lights:
			if Vector3(p).distance_to(pos) < 8: return false
		var phase: int = posmod(game.day_number()-1,8)
		if randf() > absf(4-phase)/4.0*0.5: return false
	elif randf() > 0.6: return false
	if not game.world.loaded_at(pos) or game.world.intersects(pos,0.48,1.0): return false
	var size: int = [1,2,4][randi_range(0,2)]
	if size == 4 and game.world.intersects(pos,0.94,1.9): size = 2
	var slime: Creature = game.spawn_creature("slime",pos)
	slime.set_slime_size(size)
	return true

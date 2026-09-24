class_name MinecloniaOres
extends RefCounted

const NETHER_GOLD = 695
const TUFF = 696
const BLACKSTONE = 697
const CHUNK_SIZE = 80
const CHUNK_OFFSET = -32

# Luanti scatter: floor(clipped mapchunk volume / scarcity) clusters, each
# voxel in a cubic cluster accepted with probability count / size^3. Separate
# cluster-local seeds keep halos independent of the order columns are loaded.
static func placements(gen: TerrainGenerator, coord: Vector2i) -> Array:
	var result: Array = []
	if gen.dimension == "end": return result
	var lo := Vector2i(coord.x*16-1,coord.y*16-1)
	var hi: Vector2i = lo+Vector2i(17,17)
	var first := Vector2i(floori((lo.x-CHUNK_OFFSET)/80.0),floori((lo.y-CHUNK_OFFSET)/80.0))
	var last := Vector2i(floori((hi.x-CHUNK_OFFSET)/80.0),floori((hi.y-CHUNK_OFFSET)/80.0))
	var source_y: int = -29067 if gen.dimension == "nether" else 0
	for index in MinecloniaOreRules.DATA.size():
		var rule: Dictionary = MinecloniaOreRules.DATA[index]
		if rule.dimension != gen.dimension: continue
		var low: int = maxi(gen.min_y(),rule.min)
		var high: int = mini(gen.terrain_ceiling()-1,rule.max)
		if low > high: continue
		for cy in range(floori((low+source_y-CHUNK_OFFSET)/80.0),floori((high+source_y-CHUNK_OFFSET)/80.0)+1):
			var min_y: int = maxi(rule.min,cy*80+CHUNK_OFFSET-source_y)
			var max_y: int = mini(rule.max,cy*80+CHUNK_OFFSET+79-source_y)
			if rule.size >= max_y-min_y+1: continue
			var count: int = (80*80*(max_y-min_y+1))/int(rule.scarcity)
			for cz in range(first.y,last.y+1):
				for cx in range(first.x,last.x+1):
					var clusters: PackedInt64Array = _clusters(gen,index,rule,cy,cx,cz,min_y,max_y,count).get(coord,PackedInt64Array())
					for entry in range(0,clusters.size(),4):
						var origin := Vector3i(clusters[entry],clusters[entry+1],clusters[entry+2])
						var seed_value: int = clusters[entry+3]
						if not biome_matches(gen.biome(origin.x,origin.z),rule.biomes): continue
						var nodes_rng := RandomNumberGenerator.new(); nodes_rng.seed = seed_value
						for z in rule.size:
							for y in rule.size:
								for x in rule.size:
									if nodes_rng.randi_range(1,rule.size*rule.size*rule.size) > rule.count: continue
									var p: Vector3i = origin+Vector3i(x,y,z)
									if p.x >= lo.x and p.x <= hi.x and p.z >= lo.y and p.z <= hi.y and p.y >= low and p.y <= high:
										result.append({"pos":p,"id":rule.id,"hosts":rule.hosts})
	return result

# Every cluster of one rule layer in one mapchunk, as `x, y, z, seed` runs keyed
# by each column whose halo the cluster reaches, in generation order. Columns of
# the same mapchunk share it instead of replaying every cluster's draws.
static func _clusters(gen: TerrainGenerator, index: int, rule: Dictionary, cy: int, cx: int, cz: int, min_y: int, max_y: int, count: int) -> Dictionary:
	var key := Vector4i(index,cy,cx,cz)
	if gen.ore_cluster_cache.has(key): return gen.ore_cluster_cache[key]
	var buckets: Dictionary = {}
	var size: int = rule.size
	var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(cx,cy+index*7919,cz)
	for cluster in count:
		var origin := Vector3i(rng.randi_range(cx*80+CHUNK_OFFSET,cx*80+CHUNK_OFFSET+80-size),rng.randi_range(min_y,max_y-size+1),rng.randi_range(cz*80+CHUNK_OFFSET,cz*80+CHUNK_OFFSET+80-size))
		var seed_value: int = rng.randi()
		# A column's halo spans x = 16c-1 .. 16c+16.
		for column_z in range(ceili((origin.z-16)/16.0),floori((origin.z+size)/16.0)+1):
			for column_x in range(ceili((origin.x-16)/16.0),floori((origin.x+size)/16.0)+1):
				var column := Vector2i(column_x,column_z)
				if not buckets.has(column): buckets[column] = PackedInt64Array()
				var bucket: PackedInt64Array = buckets[column]
				bucket.append(origin.x); bucket.append(origin.y); bucket.append(origin.z); bucket.append(seed_value)
				buckets[column] = bucket
	if gen.ore_cluster_cache.size() >= 4096: gen.ore_cluster_cache.erase(gen.ore_cluster_cache.keys()[0])
	gen.ore_cluster_cache[key] = buckets
	return buckets

static func biome_matches(name: String, biomes: Array) -> bool:
	if biomes.is_empty(): return true
	if str(biomes[0]).begins_with("ExtremeHills"): return name == "Frostpine highlands"
	if str(biomes[0]).begins_with("Mesa"): return name == "Badlands"
	if str(biomes[0]).begins_with("Dripstone"): return name == "Dripstone caves"
	return biomes.has(name)

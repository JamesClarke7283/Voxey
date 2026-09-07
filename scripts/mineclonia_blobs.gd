class_name MinecloniaBlobs
extends RefCounted

# First source blob family: tuff below layer 16 (-46 in the legacy world).
# Blob count uses scarcity; clust_num_ores is unused by Luanti's blob generator.
const TUFF = {"id":MinecloniaOres.TUFF,"hosts":[Nodes.STONE,VillageContent.DIORITE,VillageContent.ANDESITE,VillageContent.GRANITE,Nodes.DEEPSLATE],"size":7,"scarcity":1000,"min":-128,"max":-46}

static func placements(gen: TerrainGenerator, coord: Vector2i) -> Array:
	var result: Array = []
	if gen.dimension != "overworld": return result
	var lo := Vector2i(coord.x*16-1,coord.y*16-1)
	var hi: Vector2i = lo+Vector2i(17,17)
	var first := Vector2i(floori((lo.x+32)/80.0),floori((lo.y+32)/80.0))
	var last := Vector2i(floori((hi.x+32)/80.0),floori((hi.y+32)/80.0))
	for cy in range(floori((TUFF.min+32)/80.0),floori((TUFF.max+32)/80.0)+1):
		var low: int = maxi(TUFF.min,cy*80-32)
		var high: int = mini(TUFF.max,cy*80+47)
		if TUFF.size >= high-low+1: continue
		var count: int = 80*80*(high-low+1)/TUFF.scarcity
		for cz in range(first.y,last.y+1):
			for cx in range(first.x,last.x+1):
				var block_seed: int = gen.hash_at(cx,cy+14741,cz)
				var rng := RandomNumberGenerator.new(); rng.seed = block_seed+2404
				for cluster in count:
					var origin := Vector3i(rng.randi_range(cx*80-32,cx*80+48-TUFF.size),rng.randi_range(low,high-TUFF.size+1),rng.randi_range(cz*80-32,cz*80+48-TUFF.size))
					if origin.x > hi.x or origin.x+TUFF.size <= lo.x or origin.z > hi.y or origin.z+TUFF.size <= lo.y: continue
					var noise := LuantiValueNoise.new(block_seed+cluster)
					var center: Vector3 = Vector3(origin)+Vector3.ONE*(TUFF.size/2)
					for z in range(maxi(lo.y,origin.z),mini(hi.y+1,origin.z+TUFF.size)):
						for y in range(origin.y,origin.y+TUFF.size):
							for x in range(maxi(lo.x,origin.x),mini(hi.x+1,origin.x+TUFF.size)):
								var p := Vector3i(x,y,z)
								if noise.sample(Vector3(p))-Vector3(p).distance_to(center)/TUFF.size >= 0:
									result.append({"pos":p,"id":TUFF.id,"hosts":TUFF.hosts})
	return result

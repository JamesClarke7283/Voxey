class_name TerrainGenerator
extends RefCounted

const SIZE = 16
const HEIGHT = 64 # Existing Overworld ceiling; surface coordinates are unchanged.
const OVERWORLD_MIN = -128
const NETHER_HEIGHT = 129
const SEA = 21
var ore_cache: Dictionary = {}
var dimension: String = "overworld"
var world_seed: int
var hills := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var climate := FastNoiseLite.new()
var caves := FastNoiseLite.new()

func _init(seed_value: int = 8675309, dimension_name: String = "overworld") -> void:
	dimension = dimension_name
	world_seed = seed_value
	hills.seed = seed_value
	hills.frequency = 0.008
	hills.fractal_octaves = 4
	detail.seed = seed_value + 41
	detail.frequency = 0.038
	detail.fractal_octaves = 2
	climate.seed = seed_value + 169
	climate.frequency = 0.003
	caves.seed = seed_value + 532
	caves.frequency = 0.065
	caves.fractal_octaves = 2

func min_y() -> int:
	return OVERWORLD_MIN if dimension == "overworld" else 0

func max_y() -> int:
	return WorldBounds.maximum(dimension)+1

func terrain_ceiling() -> int:
	return HEIGHT if dimension == "overworld" else (NETHER_HEIGHT if dimension == "nether" else 128)

func block_levels() -> Array:
	var levels: Array = range(0,ceili(terrain_ceiling()/16.0))
	if min_y() < 0: levels.append_array(range(min_y()/SIZE,0))
	return levels

func terrain_height(x: int, z: int) -> int:
	if dimension == "end": return 44
	if dimension == "nether": return clampi(int(14+hills.get_noise_2d(x,z)*23+detail.get_noise_2d(x,z)*9),7,36)
	var continental: float = hills.get_noise_2d(x, z)
	return clampi(int(25.0 + continental * 23.0 + detail.get_noise_2d(x, z) * 5.0), 7, 48)

func biome(x: int, z: int) -> String:
	if dimension == "end": return "The End" if Vector2(x,z).length() < 160 else "End highlands"
	if dimension == "nether":
		var n: float = climate.get_noise_2d(x,z)
		if n < -0.22: return "Warped forest"
		if n < -0.07: return "Soul sand valley"
		if n > 0.22: return "Crimson forest"
		if n > 0.07: return "Basalt deltas"
		return "Nether wastes"
	var c: float = climate.get_noise_2d(x, z)
	if c > 0.28: return "Sunwash desert"
	if c < -0.35: return "Frostpine highlands"
	if c > -0.24 and c < 0.24 and hills.get_noise_2d(x,z) < -0.12 and terrain_height(x,z) in range(19,28): return "Swamp"
	if hills.get_noise_2d(x,z) < -0.18: return "Willow shores"
	return "Oakwood meadow"

func hash_at(x: int, y: int, z: int) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ world_seed
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)

func generate_column(coord: Vector2i, edits: Dictionary) -> Dictionary:
	# An 18-node halo gives the mesher complete boundary information. Trees are
	# seeded in world coordinates, including roots outside the requested column.
	var data := PackedInt32Array()
	data.resize(18 * 18 * terrain_ceiling())
	var deep := PackedInt32Array()
	deep.resize(18*18*absi(min_y()))
	var stronghold := WorldStructures.stronghold(world_seed,Vector2i(floori((coord.x*16)/512.0),floori((coord.y*16)/512.0)))
	var end_towers: Array = WorldStructures.towers()
	var base_x: int = coord.x * 16 - 1
	var base_z: int = coord.y * 16 - 1
	for z in 18:
		for x in 18:
			var wx: int = base_x + x
			var wz: int = base_z + z
			if dimension == "end":
				for y in terrain_ceiling(): data[x+z*18+y*324] = WorldStructures.end_node(wx,y,wz,detail)
				for tower in end_towers:
					var r: int = 2 if tower.y < 70 else 3
					if Vector2(wx-tower.x,wz-tower.z).length_squared() <= r*r:
						for y in range(30,tower.y+1): data[x+z*18+y*324] = Nodes.BEDROCK if y == tower.y and wx == tower.x and wz == tower.z else Nodes.OBSIDIAN
					if tower.y >= 80 and absi(wx-tower.x) <= 2 and absi(wz-tower.z) <= 2:
						for y in range(tower.y+1,tower.y+5):
							if absi(wx-tower.x) == 2 or absi(wz-tower.z) == 2 or y == tower.y+4: data[x+z*18+y*324] = Nodes.IRON_BARS
				if absi(wx) <= 3 and absi(wz) <= 3:
					data[x+z*18+44*324] = Nodes.BEDROCK
					if wx == 0 and wz == 0:
						for y in range(45,49): data[x+z*18+y*324] = Nodes.BEDROCK
				if wx in range(49,54) and wz in range(-2,3):
					data[x+z*18+44*324] = Nodes.OBSIDIAN
					for y in range(45,49): data[x+z*18+y*324] = Nodes.AIR
				continue
			if dimension == "nether":
				var metrics: Dictionary = {"floor":terrain_height(wx,wz),"roof":108+int(detail.get_noise_2d(wx+500,wz)*8),"region":biome(wx,wz)}
				for y in terrain_ceiling():
					var structure_id: int = WorldStructures.fortress_node(Vector3i(wx,y,wz))
					data[x+z*18+y*324] = structure_id if structure_id >= 0 else nether_node(wx,y,wz,false,metrics)
				continue
			for y in range(min_y(),0): deep[x+z*18+(y-min_y())*324] = deep_node(wx,y,wz,false)
			if absi(wx-stronghold.x) <= 24 and absi(wz-stronghold.z) <= 11:
				for y in range(stronghold.y,stronghold.y+10):
					var structure_id: int = WorldStructures.stronghold_node(Vector3i(wx,y,wz),stronghold)
					if structure_id >= 0: deep[x+z*18+(y-min_y())*324] = structure_id
			var h: int = terrain_height(wx, wz)
			var c: float = climate.get_noise_2d(wx, wz)
			var desert: bool = c > 0.28
			var snowy: bool = c < -0.35
			for y in maxi(h + 1, SEA + 1):
				var id: int = Nodes.AIR
				if y > h: id = Nodes.WATER
				elif y == h: id = Nodes.SAND if desert or h <= SEA + 1 else (Nodes.SNOW if snowy else Nodes.GRASS)
				elif y > h - 4: id = Nodes.SAND if desert or h <= SEA + 1 else Nodes.DIRT
				else:
					id = Nodes.STONE
					if desert and y >= h - 7: id = Nodes.SANDSTONE
					if snowy and y == h - 4 and h > SEA + 4: id = Nodes.ICE
					if y > 2 and y < h - 4 and caves.get_noise_3d(wx, y * 1.3, wz) > 0.39:
						id = Nodes.LAVA if y <= 7 else Nodes.AIR
					else:
						var stone_variant: int = hash_at(wx/2,y/2,wz/2)%1000
						if stone_variant in range(110,140): id = [VillageContent.GRANITE,VillageContent.DIORITE,VillageContent.ANDESITE][stone_variant%3]
						elif stone_variant > 981: id = Nodes.GRAVEL
				data[x + z * 18 + y * 324] = id
			if biome(wx,wz) == "Swamp":
				if h > SEA: data[x+z*18+h*324] = VillageContent.MUD if hash_at(wx/3,93,wz/3)%5 == 0 else VillageContent.SWAMP_GRASS
				if h < SEA and hash_at(wx,94,wz)%21 == 0: data[x+z*18+(SEA+1)*324] = VillageContent.LILY_PAD
			if h < SEA-2 and not snowy and hash_at(wx,95,wz)%11 == 0:
				for ky in range(h+1,mini(h+4,SEA)): data[x+z*18+ky*324] = VillageContent.KELP_PLANT
			# Underwater clay patches and frozen lakes give the surface variety.
			if h <= SEA and not desert:
				if hash_at(wx, 55, wz) % 23 == 0: data[x + z * 18 + (h - 1) * 324] = Nodes.CLAY
				if snowy and h <= SEA: data[x + z * 18 + (SEA) * 324] = Nodes.ICE
			# Cane starts on dry banks with adjacent water. World-coordinate hashes
			# keep vegetation identical in the neighboring column's mesh halo.
			if h in [SEA,SEA+1] and not snowy and hash_at(wx,61,wz)%7 == 0:
				var waterside: bool = false
				for side in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					if terrain_height(wx+side.x,wz+side.y) < SEA: waterside = true
				if waterside:
					for dy in range(1,3+hash_at(wx,62,wz)%2): data[x+z*18+(h+dy)*324] = Nodes.SUGAR_CANE
			if h > SEA + 1:
				var decoration: int = hash_at(wx, 100, wz) % 100
				if desert and decoration < 2:
					for y in range(h + 1, h + 4): data[x + z * 18 + y * 324] = Nodes.CACTUS
				elif not desert and not snowy and decoration < 5:
					data[x + z * 18 + (h + 1) * 324] = Nodes.FLOWER if decoration == 0 else Nodes.WHEAT
				elif decoration == 6 and not snowy:
					data[x + z * 18 + (h + 1) * 324] = Nodes.PUMPKIN
				elif decoration == 7 and snowy:
					data[x + z * 18 + (h + 1) * 324] = Nodes.PUMPKIN
				elif decoration == 8 and not desert:
					data[x + z * 18 + (h + 1) * 324] = Nodes.MELON
				elif decoration == 11 and not desert:
					data[x+z*18+(h+1)*324] = VillageContent.SWEET_BERRIES_3
				elif decoration in [9,10] and not desert and not snowy:
					data[x + z * 18 + (h + 1) * 324] = Nodes.RED_MUSHROOM if decoration == 9 else Nodes.BROWN_MUSHROOM
	for wz in (range(base_z - 2, base_z + 20) if dimension == "overworld" else []):
		for wx in range(base_x - 2, base_x + 20):
			if posmod(hash_at(wx, 77, wz), 105) != 0: continue
			var h: int = terrain_height(wx, wz)
			var c: float = climate.get_noise_2d(wx, wz)
			if h <= SEA + 2 or c > 0.28: continue
			var trunk: int = 4 + hash_at(wx, 9, wz) % 3
			for dy in range(trunk - 2, trunk + 2):
				var radius: int = 1 if dy == trunk + 1 else 2
				for dz in range(-radius, radius + 1):
					for dx in range(-radius, radius + 1):
						if absi(dx) == 2 and absi(dz) == 2: continue
						var lx: int = wx + dx - base_x
						var lz: int = wz + dz - base_z
						if lx < 0 or lx >= 18 or lz < 0 or lz >= 18: continue
						var index: int = lx + lz * 18 + (h + dy + 1) * 324
						if data[index] == 0 or Nodes.plant(data[index]): data[index] = Nodes.LEAVES
			for dy in range(1, trunk + 1):
				var lx: int = wx - base_x
				var lz: int = wz - base_z
				if lx >= 0 and lx < 18 and lz >= 0 and lz < 18: data[lx + lz * 18 + (h + dy) * 324] = Nodes.LOG
			if c > -0.2 and hash_at(wx,63,wz)%3 == 0:
				var lx: int = wx+1-base_x
				var lz: int = wz-base_z
				if lx >= 0 and lx < 18 and lz >= 0 and lz < 18:
					for dy in range(1,trunk-1):
						var index: int = lx+lz*18+(h+dy)*324
						if data[index] == Nodes.AIR: data[index] = Nodes.VINE
	if dimension == "overworld": VillageGenerator.overlay(self,coord,data)
	for placement in MinecloniaBlobs.placements(self,coord)+MinecloniaOres.placements(self,coord):
		var p: Vector3i = placement.pos
		var index: int = p.x-base_x+(p.z-base_z)*18+(p.y-min_y() if p.y < 0 else p.y)*324
		if p.y < 0:
			if placement.hosts.has(deep[index]): deep[index] = placement.id
		elif placement.hosts.has(data[index]): data[index] = placement.id
	if dimension == "nether": Bastions.overlay(self,coord,data)
	for p in edits:
		var lx: int = p.x - base_x
		var lz: int = p.z - base_z
		if lx >= 0 and lx < 18 and lz >= 0 and lz < 18 and p.y >= min_y() and p.y < terrain_ceiling():
			if p.y < 0: deep[lx+lz*18+(p.y-min_y())*324] = edits[p]
			else: data[lx + lz * 18 + p.y * 324] = edits[p]
	var blocks: Array = []
	var special: Dictionary = {}
	var reactive: Dictionary = {}
	var flowing: Dictionary = {}
	var fuel_cache: Dictionary = {}
	var fluid_cache: Dictionary = {}
	var replaceable_cache: Dictionary = {}
	var levels: Array = block_levels()
	for p in edits:
		if p.y >= terrain_ceiling() and p.y < max_y():
			var by: int = floori(p.y/16.0)
			if not levels.has(by): levels.append(by)
	for by in levels:
		var padded := PackedInt32Array()
		padded.resize(18 * 18 * 18)
		var compact := PackedInt32Array()
		compact.resize(4096)
		for y in 18:
			var wy: int = by * 16 + y - 1
			for z in 18:
				for x in 18:
					var id: int = Nodes.AIR
					if wy < min_y(): id = Nodes.AIR if dimension == "end" else Nodes.BEDROCK
					elif wy < 0: id = deep[x+z*18+(wy-min_y())*324]
					elif wy < terrain_ceiling(): id = data[x+z*18+wy*324]
					var p := Vector3i(base_x+x,wy,base_z+z)
					if wy >= terrain_ceiling() and edits.has(p): id = edits[p]
					padded[x + z * 18 + y * 324] = id
					if x > 0 and x < 17 and y > 0 and y < 17 and z > 0 and z < 17:
						compact[(x-1) + (z-1)*16 + (y-1)*256] = id
		# Index gameplay nodes on the worker, using its complete halo. Ordinary
		# terrain and inert lava never need a main-thread scan on arrival.
		for y in 16:
			for z in 16:
				for x in 16:
					var index: int = x+z*16+y*256
					var id: int = compact[index]
					if id in Nodes.CIRCUIT_NODES or id == Nodes.CHEST or Fire.is_fire(id):
						special[Vector3i(coord.x*16+x,by*16+y,coord.y*16+z)] = id
					if not fluid_cache.has(id): fluid_cache[id] = Fluids.base(id)
					if fluid_cache[id] == 0: continue
					var center: int = x+1+(z+1)*18+(y+1)*324
					var fluid_pos := Vector3i(coord.x*16+x,by*16+y,coord.y*16+z)
					if Fluids.flowing(id): flowing[fluid_pos] = id
					for offset in [-1,1,-18,18,-324,324]:
						var neighbor: int = padded[center+offset]
						if not replaceable_cache.has(neighbor): replaceable_cache[neighbor] = Fluids.replaceable(neighbor)
						if offset != 324 and replaceable_cache[neighbor]: flowing[fluid_pos] = id
						if not fuel_cache.has(neighbor): fuel_cache[neighbor] = Fire.flammable(neighbor)
						if not fluid_cache.has(neighbor): fluid_cache[neighbor] = Fluids.base(neighbor)
						if fluid_cache[id] == Nodes.LAVA and (fluid_cache[neighbor] == Nodes.WATER or fuel_cache[neighbor]) or fluid_cache[id] == Nodes.WATER and fluid_cache[neighbor] == Nodes.LAVA:
							reactive[Vector3i(coord.x*16+x,by*16+y,coord.y*16+z)] = id
		blocks.append({"y":by,"data":compact, "surfaces":BlockMesher.build(padded,true)})
	return {"coord":coord, "blocks":blocks,"special":special,"reactive":reactive,"flowing":flowing}

# World-coordinate evaluation keeps terrain and vegetation identical in halos.
func nether_node(x: int, y: int, z: int, ores: bool = true, metrics: Dictionary = {}) -> int:
	if ores: return ore_at(Vector3i(x,y,z),nether_node(x,y,z,false))
	if y == 0 or y == NETHER_HEIGHT-1: return Nodes.BEDROCK
	var floor_y: int = int(metrics.floor) if not metrics.is_empty() else terrain_height(x,z)
	var roof: int = int(metrics.roof) if not metrics.is_empty() else 108+int(detail.get_noise_2d(x+500,z)*8)
	var region: String = str(metrics.region) if not metrics.is_empty() else biome(x,z)
	if y <= floor_y or y >= roof or (y > 10 and absf(caves.get_noise_3d(x,y*0.7,z)) > 0.49):
		if y == floor_y:
			match region:
				"Soul sand valley": return Nodes.SOUL_SAND
				"Warped forest": return Nodes.WARPED_NYLIUM
				"Crimson forest": return Nodes.CRIMSON_NYLIUM
		if region == "Basalt deltas": return Nodes.BASALT
		return Nodes.NETHERRACK
	if y <= 13: return Nodes.LAVA
	var fx: int = posmod(x,160)
	var fz: int = posmod(z,160)
	if fx in range(44,77) and fz in range(44,77):
		var bridge: bool = fx in range(57,62) or fz in range(57,62)
		if bridge and y in [28,29]: return Nodes.NETHER_BRICKS
		if bridge and y in [30,31] and (fx in [57,61] or fz in [57,61]) and not (fx in range(58,61) and fz in range(58,61)): return Nodes.NETHER_BRICKS
		if fx in [45,46,74,75] and fz in [57,61] and y < 29: return Nodes.NETHER_BRICKS
	# Lavafalls descend from the roof into the lava sea.
	if hash_at(x/2,90,z/2)%173 == 0: return Nodes.LAVA
	if y >= roof-2 and hash_at(x/3,80,z/3)%13 == 0: return Nodes.GLOWSTONE
	if region in ["Warped forest","Crimson forest"]:
		var rx: int = floori(float(x)/7)*7+3
		var rz: int = floori(float(z)/7)*7+3
		var ground_y: int = terrain_height(rx,rz)
		if ground_y > 13 and hash_at(rx,83,rz)%3 != 0:
			var stem: int = Nodes.WARPED_STEM if region == "Warped forest" else Nodes.CRIMSON_STEM
			if x == rx and z == rz and y > ground_y and y <= ground_y+4: return stem
			if absi(x-rx) <= 2 and absi(z-rz) <= 2 and y in [ground_y+4,ground_y+5]:
				return Nodes.SHROOMLIGHT if hash_at(x,y,z)%5 == 0 else (Nodes.WARPED_NYLIUM if region == "Warped forest" else Nodes.CRIMSON_NYLIUM)
	return Nodes.AIR

# Negative levels extend old worlds without shifting terrain or player builds.
func deep_node(x: int, y: int, z: int, ores: bool = true) -> int:
	if ores: return ore_at(Vector3i(x,y,z),deep_node(x,y,z,false))
	if y <= OVERWORLD_MIN: return Nodes.BEDROCK
	if y < OVERWORLD_MIN+4 and hash_at(x,y,z)%5 < OVERWORLD_MIN+4-y: return Nodes.BEDROCK
	var deepslate: bool = y < -64 or (y <= -46 and hash_at(x,y,z)%18 < -46-y)
	var stone: int = Nodes.DEEPSLATE if deepslate else Nodes.STONE
	var tunnel: float = caves.get_noise_3d(x,y*1.3,z)
	var cavern: float = detail.get_noise_3d(x*0.7,y*1.2,z*0.7)
	if y > OVERWORLD_MIN+4 and (tunnel > 0.33 or (y < -12 and cavern > 0.32)):
		return Nodes.LAVA if y <= -112 else Nodes.AIR
	if hash_at(x,y,z)%1000 > 984: return Nodes.GRAVEL
	return stone

func ore_at(p: Vector3i, host: int) -> int:
	var c := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not ore_cache.has(c):
		var indexed: Dictionary = {}
		for placement in MinecloniaBlobs.placements(self,c)+MinecloniaOres.placements(self,c):
			if not indexed.has(placement.pos): indexed[placement.pos] = []
			indexed[placement.pos].append(placement)
		ore_cache[c] = indexed
	for placement in ore_cache[c].get(p,[]):
		if placement.hosts.has(host): host = placement.id
	return host

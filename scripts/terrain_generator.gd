class_name TerrainGenerator
extends RefCounted

const SIZE = 16
const HEIGHT = 64
const SEA = 21
var world_seed: int
var hills := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var climate := FastNoiseLite.new()
var caves := FastNoiseLite.new()

func _init(seed_value: int = 8675309) -> void:
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

func terrain_height(x: int, z: int) -> int:
	var continental: float = hills.get_noise_2d(x, z)
	return clampi(int(25.0 + continental * 23.0 + detail.get_noise_2d(x, z) * 5.0), 7, 48)

func biome(x: int, z: int) -> String:
	var c: float = climate.get_noise_2d(x, z)
	if c > 0.28: return "Sunwash desert"
	if c < -0.35: return "Frostpine highlands"
	if hills.get_noise_2d(x,z) < -0.18: return "Willow shores"
	return "Oakwood meadow"

func hash_at(x: int, y: int, z: int) -> int:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ world_seed
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h ^ (h >> 16)

func generate_column(coord: Vector2i, edits: Dictionary) -> Dictionary:
	# An 18-node halo gives the mesher complete boundary information. Trees are
	# seeded in world coordinates, including roots outside the requested column.
	var data := PackedByteArray()
	data.resize(18 * 18 * HEIGHT)
	var base_x: int = coord.x * 16 - 1
	var base_z: int = coord.y * 16 - 1
	for z in 18:
		for x in 18:
			var wx: int = base_x + x
			var wz: int = base_z + z
			var h: int = terrain_height(wx, wz)
			var c: float = climate.get_noise_2d(wx, wz)
			var desert: bool = c > 0.28
			var snowy: bool = c < -0.35
			for y in maxi(h + 1, SEA + 1):
				var id: int = Nodes.AIR
				if y == 0: id = Nodes.BEDROCK
				elif y > h: id = Nodes.WATER
				elif y == h: id = Nodes.SAND if desert or h <= SEA + 1 else (Nodes.SNOW if snowy else Nodes.GRASS)
				elif y > h - 4: id = Nodes.SAND if desert or h <= SEA + 1 else Nodes.DIRT
				else:
					id = Nodes.STONE
					if y > 2 and y < h - 4 and caves.get_noise_3d(wx, y * 1.3, wz) > 0.39:
						id = Nodes.AIR
					else:
						var ore: int = hash_at(wx / 2, y / 2, wz / 2) % 1000
						if ore < 33: id = Nodes.COAL_ORE
						elif ore < 53 and y < 25: id = Nodes.IRON_ORE
						elif ore < 59 and y < 12: id = Nodes.DIAMOND_ORE
						elif ore < 70 and y < 18: id = Nodes.GOLD_ORE
						elif ore < 92 and y < 32: id = Nodes.COPPER_ORE
						elif ore > 981: id = Nodes.GRAVEL
				data[x + z * 18 + y * 324] = id
			if h > SEA + 1:
				var decoration: int = hash_at(wx, 100, wz) % 100
				if desert and decoration < 2:
					for y in range(h + 1, h + 4): data[x + z * 18 + y * 324] = Nodes.CACTUS
				elif not desert and not snowy and decoration < 5:
					data[x + z * 18 + (h + 1) * 324] = Nodes.FLOWER if decoration == 0 else Nodes.WHEAT
	for wz in range(base_z - 2, base_z + 20):
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
	for p in edits:
		var lx: int = p.x - base_x
		var lz: int = p.z - base_z
		if lx >= 0 and lx < 18 and lz >= 0 and lz < 18 and p.y >= 0 and p.y < HEIGHT:
			data[lx + lz * 18 + p.y * 324] = edits[p]
	var blocks: Array = []
	for by in 4:
		var padded := PackedByteArray()
		padded.resize(18 * 18 * 18)
		var compact := PackedByteArray()
		compact.resize(4096)
		for y in 18:
			var wy: int = by * 16 + y - 1
			for z in 18:
				for x in 18:
					var id: int = data[x + z * 18 + wy * 324] if wy >= 0 and wy < HEIGHT else (Nodes.BEDROCK if wy < 0 else Nodes.AIR)
					padded[x + z * 18 + y * 324] = id
					if x > 0 and x < 17 and y > 0 and y < 17 and z > 0 and z < 17:
						compact[(x-1) + (z-1)*16 + (y-1)*256] = id
		blocks.append({"data":compact, "surfaces":BlockMesher.build(padded)})
	return {"coord":coord, "blocks":blocks}

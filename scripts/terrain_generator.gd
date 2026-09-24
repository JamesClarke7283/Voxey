class_name TerrainGenerator
extends RefCounted

const SIZE = 16
const HEIGHT = 64 # Existing Overworld ceiling; surface coordinates are unchanged.
const OVERWORLD_MIN = -128
const NETHER_HEIGHT = 129
const SEA = 21
const ALL_LEVELS = Vector2i(-2147483647,2147483647)
# Cells the column index must look at: pasture, gameplay, or any fluid.
const INDEXED = NodeInfo.PASTURE|NodeInfo.SPECIAL|NodeInfo.BASE_WATER|NodeInfo.BASE_LAVA
var ore_cache: Dictionary = {}
var ore_cluster_cache: Dictionary = {}
var dungeon_cache: Dictionary = {}
var corridor_cache: Dictionary = {}
var treasure_cache: Dictionary = {}
var ruin_cache: Dictionary = {}
var wreck_cache: Dictionary = {}
var temple_cache: Dictionary = {}
var ruin_portal_cache: Dictionary = {}
var jungle_cache: Dictionary = {}
var outpost_cache: Dictionary = {}
var igloo_cache: Dictionary = {}
var witch_cache: Dictionary = {}
var ocean_temple_cache: Dictionary = {}
var cabin_cache: Dictionary = {}
# Vertical bounds are read for nearly every node lookup, so they are kept as
# plain values and refreshed whenever the dimension changes.
var dimension: String = "overworld":
	set(value):
		dimension = value
		floor_y = OVERWORLD_MIN if value == "overworld" else 0
		top_y = WorldBounds.maximum(value)+1
		ceiling_y = HEIGHT if value == "overworld" else (NETHER_HEIGHT if value == "nether" else 128)
var floor_y: int = OVERWORLD_MIN
var top_y: int = WorldBounds.OVERWORLD_MAX+1
var ceiling_y: int = HEIGHT
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
	return floor_y

func max_y() -> int:
	return top_y

func terrain_ceiling() -> int:
	return ceiling_y

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

# A bamboo grove at one column, which is the source's levelgen feature. It raises a
# short run of stalks rather than one, each `5 + rng:next_within(12)` tall, with the
# top three cells carrying the small and large leaf forms. The source's own soil rule
# and its warm-dry placement are both applied; the swamp regions here are below sea
# level, so the surface node is checked rather than assumed.
func bamboo_grove(data: PackedInt32Array, base_x: int, base_z: int, wx: int, wz: int, h: int, decoration: int, desert: bool, snowy: bool) -> bool:
	if decoration >= 5 or desert or snowy: return false
	if climate.get_noise_2d(wx,wz) <= 0.05: return false
	# Any warm region, which is where the source's biome modifier places bamboo. The
	# swamp regions here sit below sea level, and this call happens only above the
	# sea, so a warm meadow or shore is where a grove can actually stand.
	if biome(wx,wz) not in ["Swamp","Willow shores","Oakwood meadow"]: return false
	if data[(wx-base_x)+(wz-base_z)*18+h*324] not in [Nodes.GRASS,Nodes.DIRT]: return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash_at(wx,120,wz)
	var run: int = 2+rng.randi_range(0,2)
	var placed: bool = false
	for step in run:
		var sx: int = wx+step
		var lx: int = sx-base_x
		var lz: int = wz-base_z
		if lx < 0 or lx >= 18 or lz < 0 or lz >= 18: continue
		# Only where the ground is level with this column, so a grove stays on one
		# terrace rather than hanging over a slope.
		if terrain_height(sx,wz) != h: continue
		if data[lx+lz*18+(h+1)*324] != Nodes.AIR: continue
		if not Bamboo.grove_soil(data[lx+lz*18+h*324]): continue
		# The source's height is `5 + rng:next_within(12)`, so five to sixteen, and
		# the stalk stops early only when something blocks it.
		var wanted: int = 5+rng.randi_range(0,11)
		var room: int = 0
		while room < wanted and h+1+room < terrain_ceiling() and data[lx+lz*18+(h+1+room)*324] == Nodes.AIR: room += 1
		if room <= 3: continue
		for i in room-3: data[lx+lz*18+(h+1+i)*324] = Bamboo.STALK
		data[lx+lz*18+(h+room-2)*324] = Bamboo.SMALL
		data[lx+lz*18+(h+room-1)*324] = Bamboo.BIG
		data[lx+lz*18+(h+room)*324] = Bamboo.BIG
		placed = true
	return placed

# `info` is the node lookup for this job; worker jobs bring a NodeInfo snapshot.
# Only map blocks whose level lies within `mesh_levels` get render surfaces.
func generate_column(coord: Vector2i, edits: Dictionary, map_only: bool = false, info: NodeInfo.View = null, mesh_levels: Vector2i = ALL_LEVELS) -> Dictionary:
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
				nether_column(data,x+z*18,wx,wz)
				continue
			deep_column(deep,x+z*18,wx,wz)
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
			if snowy and h > SEA+1: data[x+z*18+(h+1)*324] = SnowCover.BASE
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
				# Bamboo is tested *first*, because its window overlaps the ordinary
				# decoration ids and the chain below claims those.
				if bamboo_grove(data,base_x,base_z,wx,wz,h,decoration,desert,snowy):
					pass
				elif desert and decoration < 2:
					for y in range(h + 1, h + 4): data[x + z * 18 + y * 324] = Nodes.CACTUS
				elif not desert and not snowy and decoration < 5:
					if decoration != 0: data[x + z * 18 + (h + 1) * 324] = Nodes.WHEAT
					elif data[x+z*18+h*324] == Nodes.GRASS: data[x+z*18+(h+1)*324] = FoodFeatures.natural_flower(hash_at(wx,101,wz))
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
				# Tall grass is the source's most common surface plant; it covers
				# grassland far more densely than the flowers above. It needs grass
				# beneath it, so a bare or snowy column stays bare.
				elif decoration in [12,13,14,15,16,17,18] and not desert and not snowy and data[x+z*18+h*324] == Nodes.GRASS:
					data[x + z * 18 + (h + 1) * 324] = FoodFeatures.TALL_GRASS
	# The source giant jungle canopy reaches seven cells from its root. Include
	# every root capable of contributing to this column's one-cell mesh halo.
	for wz in (range(base_z-7,base_z+25) if dimension == "overworld" else []):
		for wx in range(base_x-7,base_x+25):
			var tree: Dictionary = WoodTypes.natural_tree(self,wx,wz)
			if tree.is_empty(): continue
			for offset in tree.blocks:
				var point: Vector3i = tree.origin+offset
				var lx: int = point.x-base_x; var lz: int = point.z-base_z
				if lx < 0 or lx >= 18 or lz < 0 or lz >= 18 or point.y >= terrain_ceiling(): continue
				var index: int = lx+lz*18+point.y*324
				var previous: int = data[index]
				if previous == Nodes.AIR or Nodes.plant(previous) or WoodTypes.is_leaves(previous) or SnowCover.is_snow(previous): data[index] = tree.blocks[offset]
	if dimension == "overworld": VillageGenerator.overlay(self,coord,data)
	for placement in MinecloniaBlobs.placements(self,coord)+MinecloniaOres.placements(self,coord):
		var p: Vector3i = placement.pos
		var index: int = p.x-base_x+(p.z-base_z)*18+(p.y-min_y() if p.y < 0 else p.y)*324
		if p.y < 0:
			if placement.hosts.has(deep[index]): deep[index] = placement.id
		elif placement.hosts.has(data[index]): data[index] = placement.id
	# Dripstone grows in the caves the terrain has already carved, so it runs after
	# the terrain and ores are final and only ever replaces air.
	if dimension == "overworld":
		# The frozen plains grow spike fields, which is what makes them a landmark.
		IceSpikes.decorate(self,coord,data,deep,biome(coord.x*16+8,coord.y*16+8))
		Dripstones.decorate(self,coord,data,deep)
	if dimension == "nether": Bastions.overlay(self,coord,data)
	var dungeons: Dictionary = Dungeons.overlay(self,coord,data,deep)
	# Corridors carve last and report separately, so a chest or spawner that both
	# systems want keeps its dungeon identity rather than being overwritten.
	var corridors: Dictionary = Corridors.overlay(self,coord,data,deep)
	# Buried treasure is placed after the ground is final, and reports its own chests.
	var treasure: Dictionary = BuriedTreasure.overlay(self,coord,data,deep)
	# Ocean ruins place coral, sea pickles and the suspicious nodes archaeology needs.
	var ruins: Dictionary = OceanRuins.overlay(self,coord,data,deep)
	# Shipwrecks bury a treasure chest, which is a second heart-of-the-sea route.
	var wrecks: Dictionary = Shipwrecks.overlay(self,coord,data,deep)
	# Desert temples carry their own archaeology table, which holds a sherd.
	var temples: Dictionary = DesertTemples.overlay(self,coord,data,deep)
	# Ruined portals are the surface source of crying obsidian and loose obsidian.
	var portals: Dictionary = RuinedPortals.overlay(self,coord,data,deep)
	# Jungle temples hold the trapped chest whose opening fires their dispensers.
	var jungles: Dictionary = JungleTemples.overlay(self,coord,data,deep)
	# A pillager outpost spawns a raiding party of pillagers, parrots and a golem.
	var outposts: Dictionary = PillagerOutposts.overlay(self,coord,data,deep)
	# An igloo hides a basement that is a self-contained cure puzzle.
	var igloos: Dictionary = Igloos.overlay(self,coord,data,deep)
	# A witch hut spawns its witch and an all-black cat on its own stilts.
	var witches: Dictionary = WitchHuts.overlay(self,coord,data,deep)
	# The ocean monument is where the guardians live, and the elder's sponges come from.
	var monuments: Dictionary = OceanTemples.overlay(self,coord,data,deep)
	# A woodland cabin garrisons illagers, and its evoker drops the totem of undying.
	var cabins: Dictionary = WoodlandCabins.overlay(self,coord,data,deep)
	Amethyst.overlay(self,coord,data,deep)
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
	# Pasture membership is split here so the main thread can merge it whole:
	# grass cells, and light cells grouped by map block.
	var pasture_cells: Dictionary = {}
	var pasture_lights: Dictionary = {}
	# Flowers and tall grass whose ground a later structure replaced would break
	# (and drop as items) the moment the column loads. They are never generated.
	var plant_cache: Dictionary = {}
	var soil_cache: Dictionary = {}
	if info == null: info = BlockMesher.default_info()
	var levels: Array = block_levels()
	var high_edits: Array = []
	for p in edits:
		if p.y < terrain_ceiling(): continue
		high_edits.append(p)
		if p.y < max_y():
			var by: int = floori(p.y/16.0)
			if not levels.has(by): levels.append(by)
	# Whole 18 x 18 layers are contiguous in both the terrain buffers and the
	# padded block, so each block is assembled from layer slices.
	var air_layer := PackedInt32Array()
	air_layer.resize(324)
	var floor_layer := PackedInt32Array()
	floor_layer.resize(324)
	floor_layer.fill(Nodes.AIR if dimension == "end" else Nodes.BEDROCK)
	for by in levels:
		var padded := PackedInt32Array()
		for y in 18:
			var wy: int = by * 16 + y - 1
			if wy < min_y(): padded.append_array(floor_layer)
			elif wy < 0: padded.append_array(deep.slice((wy-min_y())*324,(wy-min_y()+1)*324))
			elif wy < terrain_ceiling(): padded.append_array(data.slice(wy*324,(wy+1)*324))
			else: padded.append_array(air_layer)
		for p in high_edits:
			var ly: int = p.y-by*16+1
			var lx: int = p.x-base_x
			var lz: int = p.z-base_z
			if ly >= 0 and ly < 18 and lx >= 0 and lx < 18 and lz >= 0 and lz < 18: padded[lx+lz*18+ly*324] = edits[p]
		var compact := PackedInt32Array()
		for y in range(1,17):
			for z in range(1,17):
				var row: int = 1+z*18+y*324
				compact.append_array(padded.slice(row,row+16))
		# Surveys need the identical generated voxels, but no render meshes or
		# active simulation indexes. Keep normal world generation unchanged.
		if map_only:
			blocks.append({"y":by,"data":compact})
			continue
		var flags: PackedInt32Array = BlockMesher.classify(padded,info)
		# Index gameplay nodes on the worker, using its complete halo. Ordinary
		# terrain and inert lava never need a main-thread scan on arrival.
		for y in 16:
			for z in 16:
				for x in 16:
					var center: int = x+1+(z+1)*18+(y+1)*324
					var bits: int = flags[center]
					if bits & INDEXED == 0: continue
					var id: int = padded[center]
					var cell := Vector3i(coord.x*16+x,by*16+y,coord.y*16+z)
					if bits & NodeInfo.PASTURE:
						if id != Nodes.DIRT or flags[center+324] & NodeInfo.COVER == 0:
							if Pasture.is_grass(id) or id == Nodes.DIRT: pasture_cells[cell] = true
							elif id not in [Campfires.UNLIT,Campfires.SOUL_UNLIT]:
								var light_block := Vector3i(coord.x,by,coord.y)
								if not pasture_lights.has(light_block): pasture_lights[light_block] = {}
								pasture_lights[light_block][cell] = true
					if bits & NodeInfo.SPECIAL:
						if not plant_cache.has(id): plant_cache[id] = FoodFeatures.flower(id) or FoodFeatures.is_tall_grass(id)
						if plant_cache[id] and not edits.has(cell):
							var ground: int = padded[center-324]
							if not soil_cache.has(ground): soil_cache[ground] = Farmland.is_soil(ground) or ground in [Nodes.DIRT,Nodes.GRASS]
							if not soil_cache[ground]:
								padded[center] = Nodes.AIR
								compact[x+z*16+y*256] = Nodes.AIR
								flags[center] = info.of(Nodes.AIR)
								if cell.y >= 0 and cell.y < terrain_ceiling(): data[x+1+(z+1)*18+cell.y*324] = Nodes.AIR
								continue
						special[cell] = id
					var fluid: int = bits & (NodeInfo.BASE_WATER|NodeInfo.BASE_LAVA)
					if fluid == 0: continue
					if bits & NodeInfo.FLOWING: flowing[cell] = id
					for offset in [-1,1,-18,18,-324,324]:
						var neighbor: int = flags[center+offset]
						if offset != 324 and neighbor & NodeInfo.REPLACEABLE: flowing[cell] = id
						if fluid == NodeInfo.BASE_LAVA and neighbor & (NodeInfo.BASE_WATER|NodeInfo.FUEL) or fluid == NodeInfo.BASE_WATER and neighbor & NodeInfo.BASE_LAVA:
							reactive[cell] = id
		if by < mesh_levels.x or by > mesh_levels.y: blocks.append({"y":by,"data":compact})
		else: blocks.append({"y":by,"data":compact, "surfaces":BlockMesher.build(padded,true,info,flags)})
	return {"coord":coord, "blocks":blocks,"special":special,"reactive":reactive,"flowing":flowing,"pasture_cells":pasture_cells,"pasture_lights":pasture_lights,"dungeons":dungeons,"corridors":corridors,"treasure":treasure,"ruins":ruins,"wrecks":wrecks,"temples":temples,"portals":portals,"jungles":jungles,"outposts":outposts,"igloos":igloos,"witches":witches,"monuments":monuments,"cabins":cabins}

# The column forms below write exactly what the per-node functions return, but
# compute everything that depends only on x and z once per column.
func deep_column(deep: PackedInt32Array, column: int, x: int, z: int) -> void:
	deep[column] = Nodes.BEDROCK
	for y in range(OVERWORLD_MIN+1,0):
		var id: int
		var h: int = hash_at(x,y,z)
		if y < OVERWORLD_MIN+4 and h%5 < OVERWORLD_MIN+4-y: id = Nodes.BEDROCK
		elif y > OVERWORLD_MIN+4 and (caves.get_noise_3d(x,y*1.3,z) > 0.33 or (y < -12 and detail.get_noise_3d(x*0.7,y*1.2,z*0.7) > 0.32)):
			id = Nodes.LAVA if y <= -112 else Nodes.AIR
		elif h%1000 > 984: id = Nodes.GRAVEL
		elif y < -64 or (y <= -46 and h%18 < -46-y): id = Nodes.DEEPSLATE
		else: id = Nodes.STONE
		deep[column+(y-OVERWORLD_MIN)*324] = id

func nether_column(data: PackedInt32Array, column: int, x: int, z: int) -> void:
	var floor_y: int = terrain_height(x,z)
	var roof: int = 108+int(detail.get_noise_2d(x+500,z)*8)
	var region: String = biome(x,z)
	var floor_id: int = Nodes.NETHERRACK
	match region:
		"Soul sand valley": floor_id = Nodes.SOUL_SAND
		"Warped forest": floor_id = Nodes.WARPED_NYLIUM
		"Crimson forest": floor_id = Nodes.CRIMSON_NYLIUM
		"Basalt deltas": floor_id = Nodes.BASALT
	var rock: int = Nodes.BASALT if region == "Basalt deltas" else Nodes.NETHERRACK
	var qx: int = posmod(x,160)-60
	var qz: int = posmod(z,160)-60
	var fortress: bool = absi(qx) <= 28 and absi(qz) <= 28 and (absi(qx) <= 3 or absi(qz) <= 3 or absi(qx) <= 9 and absi(qz) <= 9)
	var fx: int = posmod(x,160)
	var fz: int = posmod(z,160)
	var bridge_area: bool = fx >= 44 and fx < 77 and fz >= 44 and fz < 77
	var bridge: bool = bridge_area and (fx >= 57 and fx < 62 or fz >= 57 and fz < 62)
	var rail: bool = bridge and (fx == 57 or fx == 61 or fz == 57 or fz == 61) and not (fx >= 58 and fx < 61 and fz >= 58 and fz < 61)
	var pillar: bool = bridge_area and fx in [45,46,74,75] and (fz == 57 or fz == 61)
	var lavafall: bool = hash_at(x/2,90,z/2)%173 == 0
	var glow: bool = hash_at(x/3,80,z/3)%13 == 0
	var warped: bool = region == "Warped forest"
	var tree_ground: int = -1000
	var stem_column: bool = false
	var cap_column: bool = false
	if warped or region == "Crimson forest":
		var rx: int = floori(float(x)/7)*7+3
		var rz: int = floori(float(z)/7)*7+3
		var ground_y: int = terrain_height(rx,rz)
		if ground_y > 13 and hash_at(rx,83,rz)%3 != 0:
			tree_ground = ground_y
			stem_column = x == rx and z == rz
			cap_column = absi(x-rx) <= 2 and absi(z-rz) <= 2
	var stem: int = Nodes.WARPED_STEM if warped else Nodes.CRIMSON_STEM
	var cap: int = Nodes.WARPED_NYLIUM if warped else Nodes.CRIMSON_NYLIUM
	for y in NETHER_HEIGHT:
		var id: int = WorldStructures.fortress_node(Vector3i(x,y,z)) if fortress else -1
		if id < 0:
			if y == 0 or y == NETHER_HEIGHT-1: id = Nodes.BEDROCK
			elif y <= floor_y or y >= roof or (y > 10 and absf(caves.get_noise_3d(x,y*0.7,z)) > 0.49): id = floor_id if y == floor_y else rock
			elif y <= 13: id = Nodes.LAVA
			elif bridge and (y == 28 or y == 29): id = Nodes.NETHER_BRICKS
			elif rail and (y == 30 or y == 31): id = Nodes.NETHER_BRICKS
			elif pillar and y < 29: id = Nodes.NETHER_BRICKS
			elif lavafall: id = Nodes.LAVA
			elif y >= roof-2 and glow: id = Nodes.GLOWSTONE
			elif stem_column and y > tree_ground and y <= tree_ground+4: id = stem
			elif cap_column and (y == tree_ground+4 or y == tree_ground+5): id = Nodes.SHROOMLIGHT if hash_at(x,y,z)%5 == 0 else cap
			else: id = Nodes.AIR
		data[column+y*324] = id

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

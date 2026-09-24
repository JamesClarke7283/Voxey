class_name NodeInfo
extends RefCounted

# Node properties never change once startup registration has finished, but most
# of them are long chains of family checks that cost 15-25 µs per call. Terrain
# generation, meshing and collision ask them for almost every voxel, so each id
# is classified once and kept as a bit set.
#
# The shared tables belong to the main thread: only it writes them, and only by
# overwriting whole entries in place. Packed arrays are shared by reference and
# these are never resized or replaced, so any thread may read them and sees
# either the old entry or the new one. A worker computes an entry the table does
# not have yet in its View and hands it back to the main thread with its job.
const LIMIT = 12288
const KNOWN = 1
const SOLID = 1 << 1
const TRANSPARENT = 1 << 2
const PLANT = 1 << 3
const CUBE = 1 << 4 # Drawn by greedy cube faces.
const OCCLUDES = 1 << 5 # Hides a neighbouring cube face.
const SOURCE = 1 << 6 # Fluid source node.
const FLOWING = 1 << 7 # Flowing fluid node.
const WATERY = 1 << 8 # Any water node.
const SURFACE = 1 << 9 # Greedy faces use the translucent water material.
const SPECIAL = 1 << 10 # Needs a gameplay index entry when a column loads.
const PASTURE = 1 << 11 # Light or grass cell tracked by Pasture.
const COVER = 1 << 12 # Covers grass below it (liquid or opaque).
const FUEL = 1 << 13 # Fire.flammable.
const REPLACEABLE = 1 << 14 # Fluids.replaceable.
const BASE_WATER = 1 << 15 # Fluids.base is water.
const BASE_LAVA = 1 << 16 # Fluids.base is lava.
const MESH_SHIFT = 17 # Custom mesh kind, circuits drawn by the mesher.
const EXTERNAL_SHIFT = 23 # Custom mesh kind, circuits drawn elsewhere.
const MESH_MASK = 63
const BOX = 1 << 29 # Solid, and collides as the whole unit cube.
const NO_TILE = -2147483648

static var main_thread: int = OS.get_main_thread_id()
# Set while the main thread classifies an id. The rules call each other, so
# queries made during classification use the uncached rules instead of recursing.
static var busy: bool = false
static var traits: PackedInt32Array = _blank(LIMIT,0)
static var tiles: PackedInt32Array = _blank(LIMIT*6,NO_TILE)

static func _blank(size: int, value: int) -> PackedInt32Array:
	var table := PackedInt32Array()
	table.resize(size)
	table.fill(value)
	return table

static func on_main_thread() -> bool:
	return OS.get_thread_caller_id() == main_thread

# Whether the calling thread may use the shared tables right now.
static func cached() -> bool:
	return OS.get_thread_caller_id() == main_thread and not busy

# Registration can add node families, so a registry change discards every entry.
static func invalidate() -> void:
	traits.fill(0)
	tiles.fill(NO_TILE)
	VoxelWorld.hook_memo.clear()
	RedstoneSensors.filter_memo.clear()
	Pasture.emission_memo.clear()
	Nodes.title_memo.clear()
	VoxelWorld.change_memo.clear()
	RedstoneCircuit.preserve_memo.clear()

# Bits for one id. Worker threads read the table and compute what it lacks.
static func of(id: int) -> int:
	if cached(): return memo(id)
	var bits: int = peek(id)
	return bits if bits != 0 else compute(id)

# An entry as the table holds it now, or 0. Safe from any thread.
static func peek(id: int) -> int:
	return traits[id] if id >= 0 and id < LIMIT else 0

# The main-thread lookup. Callers must already be on the main thread.
static func memo(id: int) -> int:
	var stored: bool = id >= 0 and id < LIMIT
	if stored and traits[id] != 0: return traits[id]
	busy = true
	var bits: int = compute(id)
	busy = false
	if stored: traits[id] = bits
	return bits

static func tile(id: int, face: int) -> int:
	if id < 0 or id >= LIMIT or face < 0 or face > 5: return Nodes.uncached_tile(id,face)
	var index: int = id*6+face
	var value: int = tiles[index]
	if value == NO_TILE:
		value = Nodes.uncached_tile(id,face)
		if cached(): tiles[index] = value
	return value

# A worker-safe copy of the current tables. Create it on the main thread.
static func view() -> View:
	return View.new(traits,tiles)

# The shared tables themselves, for synchronous work on the main thread.
static func live_view() -> View:
	var shared := View.new(PackedInt32Array(),PackedInt32Array())
	shared.live = true
	return shared

# Folds a finished worker's discoveries into the shared tables (main thread).
static func learn(from: View) -> void:
	if from == null or not on_main_thread(): return
	for id in from.learned_traits: traits[id] = from.learned_traits[id]
	for index in from.learned_tiles: tiles[index] = from.learned_tiles[index]

static func compute(id: int) -> int:
	var bits: int = KNOWN
	if Nodes.uncached_solid(id): bits |= SOLID
	if Nodes.uncached_transparent(id): bits |= TRANSPARENT
	if Nodes.uncached_plant(id): bits |= PLANT
	var cube: bool = id != 0 and not FoodFeatures.is_cake(id) and not Doors.is_door(id) and not SnowCover.is_snow(id) and not Trapdoors.is_trapdoor(id) and not Barriers.is_barrier(id) and not Fluids.flowing(id) and (not BuildingShapes.is_shape(id) or BuildingShapes.variant(id) == 2) and not VillageContent.special(id) and id not in Nodes.CIRCUIT_NODES and not Nodes.uncached_plant(id) and id not in [Nodes.TORCH,Nodes.LADDER,Nodes.BED_FOOT,Nodes.BED_HEAD,Nodes.NETHER_PORTAL,Nodes.END_PORTAL,Nodes.ENCHANTING_TABLE]
	cube = cube and not Farmland.is_soil(id) and not Signs.is_sign(id) and not RedstoneInputs.is_device(id) and not Copper.is_rod(id) and not Sponges.is_sponge(id) and not Archaeology.DATA.has(id) and not Decor.is_pot(id) and not Decor.is_stand(id) and not Rails.is_rail(id) and not Heads.is_any(id) and not Scaffolding.is_scaffolding(id) and not Conduits.is_conduit(id) and not Corals.is_coral(id) and not SeaPickles.is_pickle(id) and not Seagrass.is_seagrass(id) and not Beacons.is_beacon(id) and not Beacons.is_beam(id)
	if cube: bits |= CUBE
	if not Nodes.uncached_transparent(id) and id not in [Nodes.BED_FOOT,Nodes.BED_HEAD,Nodes.ENCHANTING_TABLE]: bits |= OCCLUDES
	if Fluids.source(id): bits |= SOURCE
	if Fluids.flowing(id): bits |= FLOWING
	if Fluids.water(id): bits |= WATERY
	if id in [Nodes.WATER,Amethyst.TINTED_GLASS,Beehives.HONEY_BLOCK]: bits |= SURFACE
	if RedstoneCircuit.circuit_node(id) or Archaeology.is_suspicious(id) or id in [Nodes.CHEST,VillageContent.CAULDRON,Dungeons.SPAWNER] or Campfires.is_campfire(id) or SnowCover.is_snow(id) or Fire.is_fire(id) or WoodTypes.is_leaves(id) or WoodTypes.is_sapling(id) or FoodFeatures.is_cake(id) or FoodFeatures.flower(id) or FoodFeatures.is_tall_grass(id) or Signs.is_sign(id) or CropFarming.is_crop(id) or Farmland.is_soil(id) or FruitCrops.is_stem(id) or FruitCrops.is_pumpkin_head(id) or Amethyst.tracked(id) or Beehives.is_hive(id): bits |= SPECIAL
	if Pasture.TRACKED.has(id) or Fluids.lava(id) or FruitCrops.lit(id) or Amethyst.is_crystal(id): bits |= PASTURE
	if Fluids.liquid(id) or Pasture.opaque(id): bits |= COVER
	if Fire.flammable(id): bits |= FUEL
	if Fluids.replaceable(id): bits |= REPLACEABLE
	if Fluids.base(id) == Nodes.WATER: bits |= BASE_WATER
	elif Fluids.base(id) == Nodes.LAVA: bits |= BASE_LAVA
	if Nodes.uncached_solid(id) and not (Farmland.is_soil(id) or Amethyst.is_crystal(id) or FoodFeatures.is_cake(id) or Doors.is_door(id) or SnowCover.is_snow(id) or Trapdoors.is_trapdoor(id) or Barriers.is_barrier(id) or BuildingShapes.is_shape(id) or Campfires.is_campfire(id) or id == VillageContent.CAULDRON or RedstoneSensors.is_detector(id)): bits |= BOX
	bits |= mesh_kind(id,false) << MESH_SHIFT
	bits |= mesh_kind(id,true) << EXTERNAL_SHIFT
	return bits

# The custom drawing branch BlockMesher takes for a node, in its original order.
# Zero means the node has no custom geometry.
static func mesh_kind(id: int, external_circuits: bool) -> int:
	if id == 0: return 0
	if Farmland.is_soil(id): return 1
	if CropFarming.is_crop(id): return 2
	if FruitCrops.is_stem(id): return 3
	if RedstoneInputs.is_device(id) and not external_circuits: return 4
	if RedstoneSensors.is_device(id) and not external_circuits: return 5
	if id in Nodes.CIRCUIT_NODES and not external_circuits: return 6
	if SnowCover.is_snow(id): return 7
	if Signs.is_sign(id): return 8
	if FoodFeatures.is_cake(id): return 9
	if Doors.is_door(id): return 10
	if Trapdoors.is_trapdoor(id): return 11
	if Barriers.is_barrier(id): return 12
	if BuildingShapes.is_shape(id) and BuildingShapes.variant(id) != 2: return 13
	if Torches.is_torch(id): return 14
	if Heads.is_any(id): return 15
	if Beacons.is_beacon(id) or Beacons.is_beam(id): return 16
	if Seagrass.is_seagrass(id): return 17
	if SeaPickles.is_pickle(id): return 18
	if Corals.is_coral(id): return 19
	if Conduits.is_conduit(id): return 20
	if Scaffolding.is_scaffolding(id): return 21
	if VillageContent.special(id): return 22
	if Sponges.is_sponge(id): return 23
	if Archaeology.DATA.has(id): return 24
	if Copper.is_rod(id): return 25
	if id == Nodes.NETHER_PORTAL: return 26
	if id == Nodes.END_PORTAL: return 27
	if Rails.is_rail(id): return 28
	if id == Nodes.ENCHANTING_TABLE: return 29
	if Nodes.uncached_plant(id): return 30
	if id == Nodes.LADDER: return 31
	if id in [Nodes.BED_FOOT,Nodes.BED_HEAD]: return 32
	return 0

# Worker-side lookups over a snapshot. Misses are computed once per job and
# returned to the main thread through `learn`.
class View:
	extends RefCounted
	var traits: PackedInt32Array
	var tiles: PackedInt32Array
	var learned_traits: Dictionary = {}
	var learned_tiles: Dictionary = {}
	var live: bool = false

	func _init(trait_table: PackedInt32Array, tile_table: PackedInt32Array) -> void:
		traits = trait_table
		tiles = tile_table

	func of(id: int) -> int:
		if live: return NodeInfo.of(id)
		var bits: int = traits[id] if id >= 0 and id < traits.size() else 0
		if bits != 0: return bits
		bits = learned_traits.get(id,0)
		if bits == 0:
			bits = NodeInfo.compute(id)
			learned_traits[id] = bits
		return bits

	func tile(id: int, face: int) -> int:
		if live: return NodeInfo.tile(id,face)
		if face < 0 or face > 5: return Nodes.uncached_tile(id,face)
		var index: int = id*6+face
		var value: int = tiles[index] if id >= 0 and index < tiles.size() else NO_TILE
		if value != NO_TILE: return value
		value = learned_tiles.get(index,NO_TILE)
		if value == NO_TILE:
			value = Nodes.uncached_tile(id,face)
			learned_tiles[index] = value
		return value

class_name AzaleaTrees
extends RefCounted

# Mineclonia mcl_lush_caves/{nodes,init,lg_register}.lua and the shipped
# schematics/azalea1.mts, GPL-3.0-or-later. Numeric ids keep this module below
# LushCaveExtra/VillageContent in the content dependency graph.

const AIR = 0
const DIRT = 2
const OAK_LOG = 6
const OAK_LOG_X = 6008
const OAK_LOG_Z = 6009
const ROOTED_DIRT = 11470
const AZALEA = 11472
const AZALEA_FLOWERING = 11473
const AZALEA_LEAVES = 11474
const AZALEA_LEAVES_FLOWERING = 11475
const MOSS = 1204
const MOSS_CARPET = 1205
const HANGING_ROOTS = 1206
const TALL_GRASS = 5613
const MUD = 683
const SWAMP_GRASS = 685
const COARSE_DIRT = 13600
const PALE_MOSS = 11526
const RED_SAND = 13702
const POWDER_SNOW = 1175

const GROWTH_CHANCE = 0.45
const TREE_SIZE = Vector3i(7,6,7)
const ROOT_ATTEMPTS = 20
const ROOT_RADIUS = 3
const ROOT_COLUMN_MAX_HEIGHT = 100
const HANGING_ROOT_ATTEMPTS = 20

const LEAF_IDS = [7,6033,6065,6097,6129,6161,13002,13034,13066,13098,13130,AZALEA_LEAVES,AZALEA_LEAVES_FLOWERING]
const LOG_BASES = [6000,6032,6064,6096,6128,6160,13001,13033,13065,13097,13129,13200]
const DIRT_IDS = [1,DIRT,COARSE_DIRT,ROOTED_DIRT,MOSS,MUD,SWAMP_GRASS,PALE_MOSS,13602,13604]
const MOSS_CONVERTIBLE = [1,DIRT,COARSE_DIRT,ROOTED_DIRT,MUD,SWAMP_GRASS,PALE_MOSS,13602,13604,3,194,533,534,535,540,696]
const ROOT_REPLACEABLE = [3,10,11,12,34,35,190,210,194,198,199,206,207,208,209,211,512,513,
	533,534,535,540,696,44,26,4,RED_SAND,33,POWDER_SNOW,62]

# Decoded directly from azalea1.mts (MTS version 4): x is fastest, then y, then
# z. These are offsets from its centered (3,0,3) trunk. The file has 43 forced
# nodes: five oak logs, 31 ordinary azalea leaves and seven flowering leaves.
# It is not an oak schematic with recoloured foliage. The one branch log uses
# source param2=7, represented by Voxey's z-axis oak log before Y rotation.
const SCHEMATIC = [
	[Vector3i(0,2,-3),AZALEA_LEAVES],
	[Vector3i(0,3,-3),AZALEA_LEAVES_FLOWERING],
	[Vector3i(-1,2,-2),AZALEA_LEAVES_FLOWERING],
	[Vector3i(0,2,-2),AZALEA_LEAVES],
	[Vector3i(1,2,-2),AZALEA_LEAVES],
	[Vector3i(-1,3,-2),AZALEA_LEAVES],
	[Vector3i(0,3,-2),AZALEA_LEAVES],
	[Vector3i(1,3,-2),AZALEA_LEAVES],
	[Vector3i(-1,4,-2),AZALEA_LEAVES],
	[Vector3i(0,4,-2),AZALEA_LEAVES],
	[Vector3i(1,4,-2),AZALEA_LEAVES_FLOWERING],
	[Vector3i(0,1,-1),AZALEA_LEAVES],
	[Vector3i(-1,2,-1),AZALEA_LEAVES],
	[Vector3i(0,2,-1),AZALEA_LEAVES],
	[Vector3i(1,2,-1),AZALEA_LEAVES],
	[Vector3i(2,2,-1),AZALEA_LEAVES],
	[Vector3i(-2,3,-1),AZALEA_LEAVES],
	[Vector3i(-1,3,-1),AZALEA_LEAVES],
	[Vector3i(0,3,-1),OAK_LOG_Z],
	[Vector3i(1,3,-1),AZALEA_LEAVES_FLOWERING],
	[Vector3i(2,3,-1),AZALEA_LEAVES],
	[Vector3i(-1,4,-1),AZALEA_LEAVES],
	[Vector3i(0,4,-1),AZALEA_LEAVES],
	[Vector3i(1,4,-1),AZALEA_LEAVES],
	[Vector3i(0,5,-1),AZALEA_LEAVES],
	[Vector3i(0,0,0),OAK_LOG],
	[Vector3i(0,1,0),OAK_LOG],
	[Vector3i(0,2,0),OAK_LOG],
	[Vector3i(0,3,0),OAK_LOG],
	[Vector3i(-1,2,0),AZALEA_LEAVES],
	[Vector3i(1,2,0),AZALEA_LEAVES],
	[Vector3i(-1,3,0),AZALEA_LEAVES_FLOWERING],
	[Vector3i(1,3,0),AZALEA_LEAVES],
	[Vector3i(2,3,0),AZALEA_LEAVES],
	[Vector3i(0,4,0),AZALEA_LEAVES],
	[Vector3i(1,4,0),AZALEA_LEAVES_FLOWERING],
	[Vector3i(0,2,1),AZALEA_LEAVES],
	[Vector3i(1,2,1),AZALEA_LEAVES],
	[Vector3i(-1,3,1),AZALEA_LEAVES],
	[Vector3i(0,3,1),AZALEA_LEAVES],
	[Vector3i(1,3,1),AZALEA_LEAVES],
	[Vector3i(0,4,1),AZALEA_LEAVES],
	[Vector3i(0,3,2),AZALEA_LEAVES_FLOWERING],
]

static func is_azalea(id: int) -> bool: return id == AZALEA or id == AZALEA_FLOWERING
static func is_leaf(id: int) -> bool: return id in LEAF_IDS

static func is_log(id: int) -> bool:
	if id == OAK_LOG: return true
	for base in LOG_BASES:
		if id >= base and id < base+32 and id-base in [0,4,5,6,8,9,10,11]: return true
	return false

static func rotated(offset: Vector3i, turn: int) -> Vector3i:
	var result: Vector3i = offset
	for i in posmod(turn,4): result = Vector3i(-result.z,result.y,result.x)
	return result

# A fresh sparse plan is safe for generation workers and tests. The source's
# slice and node probabilities are all 127, so rotation is the only plan roll.
static func tree_plan(turn: int = 0) -> Dictionary:
	var blocks: Dictionary = {}
	var normalized: int = posmod(turn,4)
	for entry in SCHEMATIC:
		var id: int = entry[1]
		if id == OAK_LOG_Z and normalized%2 == 1: id = OAK_LOG_X
		blocks[rotated(entry[0],normalized)] = id
	return {"blocks":blocks,"size":TREE_SIZE,"clearance":6,"schematic":"azalea1"}

static func _loaded_plan(world: VoxelWorld, origin: Vector3i, plan: Dictionary) -> bool:
	for offset in plan.blocks:
		var p: Vector3i = origin+offset
		if not world.loaded_at(Vector3(p)) or p.y < world.generator.min_y() or p.y >= world.generator.max_y(): return false
	return true

# `force=true` is the levelgen entry point. Bone meal uses false, matching the
# source's place_schematic force_place=false: existing solid nodes in the canopy
# are left alone rather than being demolished by a player-grown tree.
static func place_plan(world: VoxelWorld, origin: Vector3i, plan: Dictionary, force: bool) -> bool:
	if not _loaded_plan(world,origin,plan): return false
	for offset in plan.blocks:
		var p: Vector3i = origin+offset
		var old: int = world.node_at(p)
		if not force and old != AIR and not Nodes.plant(old): continue
		world.set_node(p,int(plan.blocks[offset]))
	return true

static func _growth_passable(id: int) -> bool:
	# mcl_trees.node_stops_growth also admits dirt, logs and leaves despite their
	# full collision shapes; non-solid plants/torches/buildable nodes pass too.
	return id == AIR or not Nodes.solid(id) or id in DIRT_IDS or is_log(id) or is_leaf(id)

static func has_growth_clearance(world: VoxelWorld, p: Vector3i) -> bool:
	# check_growth_simple(pos,6): five cells above the bush, not a 7x7 canopy
	# volume and not the sapling's own cell.
	for dy in range(1,6):
		var at: Vector3i = p+Vector3i.UP*dy
		if not world.loaded_at(Vector3(at)) or not _growth_passable(world.node_at(at)): return false
	return true

# Bone meal on either azalea form. Both forms use the same shipped schematic;
# its seven flowering leaves remain flowering instead of collapsing to oak or
# ordinary azalea foliage. A failed roll or clearance check changes nothing.
static func grow(world: VoxelWorld, p: Vector3i, rng: RandomNumberGenerator = null) -> bool:
	if not is_azalea(world.node_at(p)): return false
	if rng == null: rng = RandomNumberGenerator.new(); rng.randomize()
	if rng.randf() > GROWTH_CHANCE or not has_growth_clearance(world,p): return false
	var plan: Dictionary = tree_plan(rng.randi_range(0,3))
	if not _loaded_plan(world,p,plan): return false
	# The source converts whatever support the bush had after the two gates; it
	# does not re-run the placement soil predicate here.
	world.set_node(p+Vector3i.DOWN,ROOTED_DIRT)
	world.set_node(p,AIR)
	return place_plan(world,p,plan,false)

# --- moss vegetation: the survival route from traded moss to azaleas --------

static func converts_to_moss(id: int) -> bool: return id in MOSS_CONVERTIBLE

# nodes.lua:random_moss_vegetation, including its double-grass row and both
# azalea forms with their relative weights.
static func moss_vegetation(rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	if roll < 0.5208: return TALL_GRASS
	if roll < 0.7812: return MOSS_CARPET
	if roll < 0.8854: return LargePlants.DOUBLE_GRASS
	if roll < 0.9583: return AZALEA
	return AZALEA_FLOWERING

# set_moss_with_chance_vegetation for one already-selected convertible block.
static func moss_cell(world: VoxelWorld, p: Vector3i, rng: RandomNumberGenerator) -> bool:
	if not converts_to_moss(world.node_at(p)) or world.node_at(p+Vector3i.UP) != AIR: return false
	if not world.set_node(p,MOSS): return false
	if rng.randf() < 0.6:
		LargePlants.place_moss_vegetation(world,p+Vector3i.UP,moss_vegetation(rng))
	return true

# mcl_lush_caves.bone_meal_moss: random 5x5 or 7x7 bounds without the four
# corners, vertical range -6..4, convertible nodes under literal air only.
static func bone_meal_moss(world: VoxelWorld, p: Vector3i, rng: RandomNumberGenerator = null) -> bool:
	if world.node_at(p) != MOSS or world.node_at(p+Vector3i.UP) != AIR: return false
	if rng == null: rng = RandomNumberGenerator.new(); rng.randomize()
	var x_max: int = rng.randi_range(2,3)
	var z_max: int = rng.randi_range(2,3)
	for dx in range(-x_max,x_max+1):
		for dz in range(-z_max,z_max+1):
			if absi(dx) == x_max and absi(dz) == z_max: continue
			for dy in range(-6,5):
				var at: Vector3i = p+Vector3i(dx,dy,dz)
				if not world.loaded_at(Vector3(at)): continue
				if not converts_to_moss(world.node_at(at)) or world.node_at(at+Vector3i.UP) != AIR: continue
				if (absi(dx) == x_max or absi(dz) == z_max) and rng.randf() >= 0.75: continue
				moss_cell(world,at,rng)
	return true

# --- optional natural rooted_azalea_tree feature -----------------------------
# These predicates and generate_rooted are real generation entry points, but no
# lush-cave biome dispatcher exists in TerrainGenerator yet. They intentionally
# do not claim that trees currently occur in new worlds.

static func natural_soil(id: int) -> bool:
	# group:dirt plus hardened clay, sand/red sand, snow block and powder snow.
	return id in DIRT_IDS or id in [4,RED_SAND,33,POWDER_SNOW,62] or id >= 603 and id <= 618

static func root_replaceable(id: int) -> bool:
	# Deliberately no dirt: lg_register's root_replaceable list has stone and
	# deepslate ore targets, clay, gravel, sand and snow, but not group:dirt.
	return id in ROOT_REPLACEABLE or id >= 603 and id <= 618

static func _tree_replaceable(id: int) -> bool:
	return id == AIR or id == Nodes.WATER or is_leaf(id) or Nodes.plant(id)

static func _natural_space(world: VoxelWorld, p: Vector3i) -> bool:
	for dy in 3:
		var at: Vector3i = p+Vector3i.UP*dy
		if not world.loaded_at(Vector3(at)): return false
		var id: int = world.node_at(at)
		if id == Nodes.WATER: 
			if dy < 2: continue
			return false
		if not (id == AIR or is_leaf(id) or not Nodes.solid(id)): return false
	return true

static func _sturdy(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	return Nodes.solid(id) and not Nodes.transparent(id)

static func _hanging_roots(world: VoxelWorld, origin: Vector3i, rng: RandomNumberGenerator) -> void:
	for attempt in HANGING_ROOT_ATTEMPTS:
		var dx: int = rng.randi_range(0,ROOT_RADIUS-1)-rng.randi_range(0,ROOT_RADIUS-1)
		var dz: int = rng.randi_range(0,ROOT_RADIUS-1)-rng.randi_range(0,ROOT_RADIUS-1)
		var dy: int = rng.randi_range(0,1)-rng.randi_range(0,1)
		var at: Vector3i = origin+Vector3i(dx,dy,dz)
		if world.loaded_at(Vector3(at)) and world.node_at(at) == AIR and _sturdy(world,at+Vector3i.UP):
			world.set_node(at,HANGING_ROOTS)

# lg_register.lua's rooted_azalea_tree/root_system. The initial cell must be
# air. The feature searches upward for a replaceable cell over natural soil,
# requires three cells of tree space, force-places azalea1, then makes twenty
# rooted-dirt attempts per root-column level and twenty hanging-root attempts.
static func generate_rooted(world: VoxelWorld, origin: Vector3i, rng: RandomNumberGenerator = null) -> bool:
	if world.node_at(origin) != AIR: return false
	if rng == null: rng = RandomNumberGenerator.new(); rng.randomize()
	for dy in ROOT_COLUMN_MAX_HEIGHT:
		var at: Vector3i = origin+Vector3i.UP*dy
		if not world.loaded_at(Vector3(at)) or not world.loaded_at(Vector3(at+Vector3i.DOWN)): return false
		if not _tree_replaceable(world.node_at(at)) or not natural_soil(world.node_at(at+Vector3i.DOWN)): continue
		if not _natural_space(world,at): continue
		var root_rng := RandomNumberGenerator.new(); root_rng.seed = rng.randi()
		var plan: Dictionary = tree_plan(rng.randi_range(0,3))
		if not place_plan(world,at,plan,true): return false
		for y in range(origin.y,at.y):
			for attempt in ROOT_ATTEMPTS:
				var dx: int = root_rng.randi_range(0,ROOT_RADIUS-1)-root_rng.randi_range(0,ROOT_RADIUS-1)
				var dz: int = root_rng.randi_range(0,ROOT_RADIUS-1)-root_rng.randi_range(0,ROOT_RADIUS-1)
				var root: Vector3i = Vector3i(origin.x+dx,y,origin.z+dz)
				if world.loaded_at(Vector3(root)) and root_replaceable(world.node_at(root)):
					world.set_node(root,ROOTED_DIRT)
		_hanging_roots(world,origin,root_rng)
		return true
	return false

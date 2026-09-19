class_name Bamboo
extends RefCounted

# Mineclonia ITEMS/mcl_bamboo/{init,nodes,recipes}.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference; all art is original
# procedural code.
#
# Bamboo is the source's own wood family, and it is unusual in three ways that
# make it worth having on its own:
#
#   * **It grows as a stalk**, one segment at a time, to a height the source picks
#     per-stalk from its own position hash: `pr:next(12,16)`. So each stalk has its
#     own ceiling rather than a shared maximum.
#   * **It needs light.** A stalk only grows when the cell above it has light 9 or
#     more, which is why bamboo stops in a cave.
#   * **It branches into two sizes.** Once a stalk is more than one segment tall the
#     source picks, by a coin flip, whether it becomes *small* or *big*, and the
#     choice changes the leaf shape at its top. That is why a bamboo grove has two
#     distinct stalk thicknesses.
#
# Voxey had the **scaffolding** built from bamboo, and `scaffolding.gd` recorded
# bamboo itself as the missing piece; its recipe had to substitute another
# material. This adds the stalk, so the substitution is no longer needed.
#
# The bamboo *wood* family (planks, mosaic, the rafts) is not part of this batch
# and is recorded as still open.

# The stalk grows one segment at a time, from a shoot to a full stalk.
const SHOOT = 1170
const STALK = 1171
# The two thicknesses the source picks between, once a stalk is established.
const SMALL = 1172
const BIG = 1173
const BLOCKS = [SHOOT,STALK,SMALL,BIG]
# A stalk's own width, which is the source's collision box: a narrow column rather
# than a cube, so bamboo does not block movement like a wall.
const STALK_WIDTH = 0.11
# The item a stalk drops, which is what the scaffolding recipe consumes.
const BAMBOO_ITEM = 1174

# Source `pr:next(12,16)`: each stalk's own height ceiling.
const HEIGHT_MIN = 12
const HEIGHT_MAX = 16
# Source requires light 9 above the growing tip.
const MIN_LIGHT = 9
# Source `math.random() < 0.5` picks small, else big.
const SMALL_CHANCE = 0.5
# The source's scaffold recipe is six bamboo around a string:
#   bamboo string bamboo
#   bamboo  ....  bamboo
#   bamboo  ....  bamboo
const SCAFFOLD_COUNT = 6

static func is_bamboo(id: int) -> bool: return BLOCKS.has(id)
static func is_shoot(id: int) -> bool: return id == SHOOT
static func is_stalk(id: int) -> bool: return id == STALK

# A constant with literal keys, so the content table can reference it without a
# const cycle. A shoot is a short green spike; a stalk is a ribbed column.
const BLOCK_DATA = {
	1170: {"name":"Bamboo shoot","block":true,"shape":"bamboo","color":"7ea33c","hardness":1.0,"tool":0,"plant":true},
	1171: {"name":"Bamboo","block":true,"shape":"bamboo","color":"8fb04a","hardness":1.0,"tool":0,"plant":true},
	1172: {"name":"Bamboo","block":true,"shape":"bamboo","color":"8fb04a","hardness":1.0,"tool":0,"plant":true,"hidden":true},
	1173: {"name":"Bamboo","block":true,"shape":"bamboo","color":"9abd52","hardness":1.0,"tool":0,"plant":true,"hidden":true},
}

# --- the stalk's own height --------------------------------------------------

# The height a stalk grows to, which the source derives from the stalk's own
# position rather than from a shared maximum. Each stalk therefore has its own
# ceiling, so a grove is uneven.
static func max_height(gen: TerrainGenerator, p: Vector3i) -> int:
	return HEIGHT_MIN+posmod(gen.hash_at(p.x,p.y,p.z),HEIGHT_MAX-HEIGHT_MIN+1)

# The segments of a stalk at `p`, walking down to its base. The base is the lowest
# bamboo cell beneath it.
static func base_of(world: VoxelWorld, p: Vector3i) -> Vector3i:
	var bottom: Vector3i = p
	while is_bamboo(world.node_at(bottom+Vector3i.DOWN)): bottom += Vector3i.DOWN
	return bottom

static func segments(world: VoxelWorld, p: Vector3i) -> int:
	var top: Vector3i = p
	while is_bamboo(world.node_at(top+Vector3i.UP)): top += Vector3i.UP
	return top.y-base_of(world,top).y+1

# The ground bamboo grows on, which is the source's `soil_bamboo` group. The
# source lists dirt, grass, podzol and moss; Voxey has neither podzol nor moss, so
# the ground it does have is used and the omission is recorded in the notes.
static func soil(id: int) -> bool:
	return id in [Nodes.DIRT,Nodes.GRASS,Nodes.SAND]

# --- growth ------------------------------------------------------------------

# Grow a stalk by one segment, which is the source's `grow`. Returns true when a
# segment was added, so the caller can sound or animate it.
#
# The three source rules are applied in order:
#   1. The stalk must be below its own height ceiling.
#   2. The cell it grows into must have enough light, so bamboo stops in a cave.
#   3. When it has more than one segment it takes one of the two thicknesses, by a
#      coin flip, which is what gives a grove its mixed stalks.
static func grow(world: VoxelWorld, gen: TerrainGenerator, p: Vector3i, light_at: Callable, rng: RandomNumberGenerator) -> bool:
	if not is_bamboo(world.node_at(p)): return false
	var base: Vector3i = base_of(world,p)
	var top: Vector3i = p
	while is_bamboo(world.node_at(top+Vector3i.UP)): top += Vector3i.UP
	var height: int = top.y-base.y+1
	# The ceiling comes from the base's own position, so a stalk keeps its height
	# however far it grows.
	if height >= max_height(gen,base): return false
	var above: Vector3i = top+Vector3i.UP
	if world.node_at(above) != Nodes.AIR: return false
	# Light is what stops bamboo underground.
	if int(light_at.call(above)) < MIN_LIGHT: return false
	# A stalk of more than one segment takes a thickness, so a grove has two.
	var wanted: int = STALK
	if height > 1:
		wanted = SMALL if rng.randf() < SMALL_CHANCE else BIG
	if not world.set_node(above,wanted): return false
	# The whole stalk is restyled, which is the source's `bulk_set_node` over the
	# tower: a stalk does not change thickness partway up.
	if wanted != STALK:
		var at: Vector3i = base
		while at.y <= top.y:
			if is_bamboo(world.node_at(at)): world.set_node(at,wanted)
			at += Vector3i.UP
	return true

# --- placement ---------------------------------------------------------------

# Whether a stalk can be planted at `p`: the source requires soil or bamboo below.
static func can_plant(world: VoxelWorld, p: Vector3i) -> bool:
	if world.node_at(p) != Nodes.AIR: return false
	var below: int = world.node_at(p-Vector3i.UP)
	return soil(below) or is_bamboo(below)

# Plant a shot at `p`, which is the source's `after_place_node`.
static func plant(world: VoxelWorld, p: Vector3i) -> bool:
	if not can_plant(world,p): return false
	return world.set_node(p,SHOOT)

# --- harvest -----------------------------------------------------------------

# What a stalk drops, which is the bamboo item. The source's drop is the item
# itself, so a broken segment returns one.
static func drop(id: int) -> int:
	return BAMBOO_ITEM if is_bamboo(id) else 0

# --- recipes -----------------------------------------------------------------

# --- recipes -----------------------------------------------------------------

# The source's own bamboo recipes that Voxey can support. The wood family (planks,
# mosaic, rafts) is registered by `mcl_trees` in the source and is not part of this
# batch; these are the ones `mcl_bamboo/recipes.lua` owns directly.
static func recipes(inv: Inventory) -> void:
	# Two bamboo make a stick, stacked vertically rather than in the usual 2x2.
	inv._recipe("Sticks from bamboo",Nodes.STICK,1,[BAMBOO_ITEM,0,BAMBOO_ITEM],2)

# --- natural groves ----------------------------------------------------------

# The source's levelgen feature: a count placed by noise, then a stalk whose height
# is `5 + rng:next_within(12)` — so five to sixteen — with the top three cells being
# the small and large leaf forms rather than plain trunk. Only a stalk taller than
# three gets that tip; a shorter one is all trunk.
#
# Voxey's jungle species grows in the swamp and willow-shore regions, so a bamboo
# grove uses the same regions. The source additionally accepts podzol and moss
# ground, which Voxey does not have.
const GROVE_CHANCE = 12
const TRUNK_MIN = 5
const TRUNK_RANGE = 12

# Whether a grove may stand at `p`, which is the source's soil rule.
static func grove_soil(id: int) -> bool:
	return id in [Nodes.DIRT,Nodes.GRASS,Nodes.SAND]

# Raise one stalk at `p`, which is the source's `bamboo_place`. Returns the number of
# segments placed so a caller can tell a failed placement from a short stalk.
static func raise_stalk(world: VoxelWorld, gen: TerrainGenerator, p: Vector3i, rng: RandomNumberGenerator) -> int:
	if not world.loaded_at(Vector3(p)): return 0
	if world.node_at(p) != Nodes.AIR: return 0
	if not grove_soil(world.node_at(p-Vector3i.UP)): return 0
	var wanted: int = TRUNK_MIN+rng.randi_range(0,TRUNK_RANGE-1)
	# Stop at the first blocked cell, which is how the source counts a trunk.
	var room: int = 0
	while room < wanted and world.node_at(p+Vector3i.UP*room) == Nodes.AIR: room += 1
	if room <= 0: return 0
	if room <= 3:
		# A short stalk is all trunk.
		for i in room: world.set_node(p+Vector3i.UP*i,STALK)
		return room
	# A tall stalk is trunk up to its last three cells, which carry the leaf forms.
	for i in room-3: world.set_node(p+Vector3i.UP*i,STALK)
	world.set_node(p+Vector3i.UP*(room-3),SMALL)
	world.set_node(p+Vector3i.UP*(room-2),BIG)
	world.set_node(p+Vector3i.UP*(room-1),BIG)
	return room

# --- art ---------------------------------------------------------------------

# A bamboo stalk is a narrow ribbed column, which is what tells it from a log.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if not is_bamboo(id): return Color(0,0,0,0)
	if is_shoot(id):
		# A shoot is a short green spike rather than a full column.
		return Color("7ea33c") if x in range(6,10) and y > 4 else Color(0,0,0,0)
	var base: Color = Color(VillageContent.DATA[id].color)
	# The node is a narrow column, so the tile's sides are transparent.
	if x < 5 or x > 10: return Color(0,0,0,0)
	# Rings across the stalk, which are the joints between segments.
	if y%8 in [0,1]: return base.darkened(0.35)
	return base.lightened(0.08) if x in [5,6] else base.darkened(0.1)

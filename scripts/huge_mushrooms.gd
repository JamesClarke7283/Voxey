class_name HugeMushrooms
extends RefCounted

# Mineclonia ITEMS/mcl_mushrooms/{init,small,huge}.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference; all art is original
# procedural code.
#
# Huge mushrooms are what the source's **bone meal on a small mushroom** grows. The
# rule is layered, and every layer matters:
#
#   1. **A 40% roll.** `math.random(1, 100) > 40 then return`, so most attempts do
#      nothing at all.
#   2. **Soil.** The mushroom must stand on dirt, grass, mycelium, coarse dirt or
#      podzol.
#   3. **Room.** The source scans a box around the mushroom for opaque blocks and
#      refuses if any is lower than the required height; every cell of the box must
#      otherwise be air or leaves.
#   4. **A random height.** `base_height = math.random(0, 2)`, and one time in twelve
#      the stem is doubled.
#
# The two species differ in *shape*, which the source ships as two schematics. Both
# are reproduced here from the source's own `.mts` files rather than guessed:
#
#   * **Brown** — a 7x7 cap. Its rim is a ring at the second layer from the top,
#     with corner blocks one layer below, so the outline steps down at the edges.
#   * **Red** — a 5x5 cap. It is a ring two layers tall with a 3x3 top, and its stem
#     starts one layer lower because the cap sits lower.
#
# The **cap blocks** are the other half of the feature. A huge mushroom cap is not
# one block but a *family*: a cap block's skin depends on which of its six faces are
# exposed, and the source registers all 63 interior variants (`cap_000000` through
# `cap_111111`, one bit per face) plus the all-skin block a player can place. Two cap
# blocks placed next to each other turn their touching faces to pores permanently,
# which is why a huge mushroom's interior is pores and its outside is skin.
#
# Voxey could not grow a huge mushroom before this: bone meal on a mushroom did
# nothing, and none of the stem, cap or pore blocks existed.

# --- the blocks --------------------------------------------------------------

const BROWN_STEM = 1207
const RED_STEM = 1208
# The all-skin cap, which is the block a player obtains and places.
const BROWN_CAP = 1209
const RED_CAP = 1210
# The pore block, which is what a hidden face becomes and what fills the interior.
const BROWN_PORES = 1211
const RED_PORES = 1212

const STEMS = [BROWN_STEM,RED_STEM]
const CAPS = [BROWN_CAP,RED_CAP]
const PORES = [BROWN_PORES,RED_PORES]
const BLOCKS = [BROWN_STEM,RED_STEM,BROWN_CAP,RED_CAP,BROWN_PORES,RED_PORES]

# Literal keys, so the content table can reference this without a const cycle.
const BLOCK_DATA = {
	1207: {"name":"Brown mushroom stem","block":true,"color":"c9b287","hardness":0.2,"tool":0,"flammable":true,"compostability":65},
	1208: {"name":"Red mushroom stem","block":true,"color":"e4e0d3","hardness":0.2,"tool":0,"flammable":true,"compostability":65},
	1209: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65},
	1210: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65},
	1211: {"name":"Brown mushroom block pores","block":true,"color":"cbb99c","hardness":0.2,"tool":0,"flammable":true,"compostability":65},
	1212: {"name":"Red mushroom block pores","block":true,"color":"e0d6c2","hardness":0.2,"tool":0,"flammable":true,"compostability":65},
}

static func is_stem(id: int) -> bool: return STEMS.has(id)
static func is_cap(id: int) -> bool: return CAPS.has(id)
static func is_pores(id: int) -> bool: return PORES.has(id)
static func is_huge(id: int) -> bool: return BLOCKS.has(id)

static func stem_for(small: int) -> int:
	return RED_STEM if small == Nodes.RED_MUSHROOM else BROWN_STEM

static func cap_for(small: int) -> int:
	return RED_CAP if small == Nodes.RED_MUSHROOM else BROWN_CAP

static func pores_for(small: int) -> int:
	return RED_PORES if small == Nodes.RED_MUSHROOM else BROWN_PORES

# The small mushroom a huge-mushroom block belongs to, which is what the block drops
# without Silk Touch.
static func species_of(id: int) -> int:
	if id in [RED_STEM,RED_CAP,RED_PORES]: return Nodes.RED_MUSHROOM
	return Nodes.BROWN_MUSHROOM

# The cap of a species, as horizontal layers listed **top-down**. `C` is a cap
# block and `.` is empty. These are the source schematics' cap layers, read
# directly, with the stem's own column marked `S` so a caller can see where the
# stem meets the cap.
const BROWN_CAP_LAYERS = [
	[
		".CCCCC.",
		".CCCCC.",
		".CCCCC.",
		".CCCCC.",
		".CCCCC.",
	],
	[
		".CCCCC.",
		"C.....C",
		"C.....C",
		"C..S..C",
		"C.....C",
		"C.....C",
		".CCCCC.",
	],
]
const RED_CAP_LAYERS = [
	[
		".CCC.",
		".CCC.",
		".CCC.",
	],
	[
		".CCC.",
		"C...C",
		"C.S.C",
		"C...C",
		".CCC.",
	],
	[
		"CCCCC",
		"C...C",
		"C.S.C",
		"C...C",
		"CCCCC",
	],
]

# The stem height in the source's schematic, i.e. how many cells the stem occupies
# below the cap before `base_height` is added.
const SCHEM_STEM = 3
const SCHEM_HEIGHT = 5
# Source `base_height = math.random(0, 2)`.
const BASE_HEIGHT_MAX = 2
# Source `if math.random(1, 12) == 1` doubles the height.
const DOUBLE_CHANCE = 12
# Source `if math.random(1, 100) > 40 then return`, i.e. a 40% success roll.
const GROW_CHANCE = 0.4
# The soils the source accepts under a mushroom: mycelium, dirt, any grass block,
# coarse dirt and podzol. Voxey has neither mycelium, coarse dirt nor podzol, so this
# is the dirt and grass it does have; the omission is recorded in the notes.
const SOILS = [Nodes.DIRT,Nodes.GRASS]

static func cap_layers(small: int) -> Array:
	return RED_CAP_LAYERS if small == Nodes.RED_MUSHROOM else BROWN_CAP_LAYERS

# The cells a huge mushroom occupies, keyed by offset from the small mushroom's own
# cell. `height` is the stem's length; the cap sits directly on top of it.
#
# The cap is centred on the stem, so a 7-wide cap reaches three cells either way and
# a 5-wide one two.
static func shape(small: int, height: int) -> Dictionary:
	var result: Dictionary = {}
	for y in height:
		result[Vector3i(0,y,0)] = stem_for(small)
	var layers: Array = cap_layers(small)
	var cap_id: int = cap_for(small)
	var pores_id: int = pores_for(small)
	for depth in layers.size():
		var layer: Array = layers[depth]
		var width: int = layer[0].length()
		var origin: int = width/2
		var y: int = height+depth
		for z in layer.size():
			for x in layer[z].length():
				var cell: String = layer[z][x]
				if cell == ".": continue
				var offset := Vector3i(x-origin,y,z-origin)
				# The stem's own column stays stem rather than becoming cap, and the
				# cap's underside becomes pores where it is not exposed.
				if cell == "S":
					result[offset] = stem_for(small) if not result.has(offset) else result[offset]
				else:
					result[offset] = cap_id
	# Every cap cell with a cap directly above it is interior, so it becomes pores.
	# This is what the source's per-face skin bits express: a face hidden by another
	# cap block is pores rather than skin.
	var interior: Dictionary = {}
	for offset in result:
		if result[offset] != cap_id: continue
		if result.get(offset+Vector3i.UP,0) == cap_id:
			interior[offset] = pores_id
	for offset in interior: result[offset] = pores_id
	return result

# The cap's footprint at its widest, which is what the room check measures.
static func cap_width(small: int) -> int:
	var layer: Array = cap_layers(small)[0]
	return layer[0].length()

# Whether the source's growth would fit at `p`. The source scans a box that spans
# the cap's width and the required height, refuses if any opaque block is below that
# height, and requires every cell to be air or leaves.
static func room_for(world: VoxelWorld, p: Vector3i, small: int, height: int) -> bool:
	var half: int = cap_width(small)/2
	var top: int = height+cap_layers(small).size()-1
	for x in range(-half,half+1):
		for z in range(-half,half+1):
			for y in range(1,top+1):
				var at: Vector3i = p+Vector3i(x,y,z)
				if not world.loaded_at(Vector3(at)): return false
				var id: int = world.node_at(at)
				# The source allows air and leaves; anything else blocks the growth.
				if id != Nodes.AIR and not WoodTypes.is_leaves(id): return false
	return true

# --- art ---------------------------------------------------------------------

# A cap's skin is the species colour with the source's own blotches; its pores are
# the pale underside with a regular hole pattern, which is what makes a huge
# mushroom's interior read differently from its outside.
static func pixel(id: int, x: int, y: int) -> Color:
	var cap: bool = is_cap(id)
	var pores: bool = is_pores(id)
	var stem: bool = is_stem(id)
	var base: Color = Color(BLOCK_DATA[id].color)
	if stem:
		# A stem's side is ribbed and its ends are open pores, so the two are drawn
		# from the same colour at different densities.
		if y%4 == 3: return base.darkened(0.2)
		if x%4 == 0: return base.darkened(0.1)
		return base
	if pores:
		# The source's pore texture is an even grid of holes.
		if x%4 in [1,2] and y%4 in [1,2]: return base.darkened(0.24)
		return base.lightened(0.03)
	if cap:
		# Skin: mottled, with a darker rim so a cap edge reads as an edge.
		var blotch: bool = (x*7+y*11)%23 < 5
		if x in [0,15] or y in [0,15]: return base.darkened(0.22)
		return base.darkened(0.14) if blotch else base
	return base

# --- growth ------------------------------------------------------------------

# Grow a huge mushroom at `p`, replacing the small mushroom. Returns false when the
# roll fails, the soil is wrong or the space is too small, which is the source's own
# set of refusals.
static func grow(world: VoxelWorld, p: Vector3i, small: int, rng: RandomNumberGenerator) -> bool:
	if rng.randf() > GROW_CHANCE: return false
	if not SOILS.has(world.node_at(p+Vector3i.DOWN)): return false
	var height: int = rng.randi_range(0,BASE_HEIGHT_MAX)
	if rng.randi_range(1,DOUBLE_CHANCE) == 1: height = height*2+SCHEM_STEM-1
	var stem: int = height+SCHEM_STEM
	if not room_for(world,p,small,stem): return false
	var plan: Dictionary = shape(small,stem)
	if not world.set_node(p,Nodes.AIR): return false
	for offset in plan:
		world.set_node(p+offset,plan[offset])
	return true

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
# exposed, and the source registers all 64 variants (`cap_000000` through
# `cap_111111`, one bit per face) plus separate ordinary and all-faces stems. Two
# cap blocks placed next to each other turn their touching faces to pores
# permanently, which is why a huge mushroom's interior is pores and its outside is
# skin.
#
# Voxey could not grow a huge mushroom before this: bone meal on a mushroom did
# nothing, and none of the stem, cap or pore blocks existed.

# --- the blocks --------------------------------------------------------------

# Keep the original IDs stable. The contiguous 16000-16125 allocation is below
# NodeInfo.LIMIT, above ShapeCatalog.NEW_END, and unused by existing content.
const BROWN_STEM = 1207
const RED_STEM = 1208
const BROWN_FULL_STEM = 16000
const RED_FULL_STEM = 16001
# The all-skin cap, which is the block a player obtains and places.
const BROWN_CAP = 1209
const RED_CAP = 1210
# The all-pore cap (source huge_mushroom_cap group value zero).
const BROWN_PORES = 1211
const RED_PORES = 1212
# Masks 1-62 for each species; masks 0 and 63 retain their legacy IDs above.
const BROWN_CAP_FIRST = 16002
const RED_CAP_FIRST = 16064
const NEW_LAST = 16125

const STEMS = [BROWN_STEM,RED_STEM,BROWN_FULL_STEM,RED_FULL_STEM]
const PORES = [BROWN_PORES,RED_PORES]

# Source tile order, not BlockMesher's axis-major face order. Bit 5 is the first
# character of the source's six-digit name; zero is pores and one is skin.
const FACES = [Vector3i.UP,Vector3i.DOWN,Vector3i.RIGHT,Vector3i.LEFT,Vector3i.BACK,Vector3i.FORWARD]
const FACE_BITS = [32,16,8,4,2,1]
const OPPOSITE = [1,0,3,2,5,4]
const SOURCE_FACE_FOR_RENDER = [2,3,0,1,4,5] # +X,-X,+Y,-Y,+Z,-Z -> tile order


static func mask_of(id: int) -> int:
	if id == BROWN_PORES or id == RED_PORES: return 0
	if id == BROWN_CAP or id == RED_CAP: return 63
	if id >= BROWN_CAP_FIRST and id < RED_CAP_FIRST: return id-BROWN_CAP_FIRST+1
	if id >= RED_CAP_FIRST and id <= NEW_LAST: return id-RED_CAP_FIRST+1
	return -1

static func cap_for(small: int, mask: int = 63) -> int:
	mask = clampi(mask,0,63)
	if small == Nodes.RED_MUSHROOM:
		if mask == 0: return RED_PORES
		if mask == 63: return RED_CAP
		return RED_CAP_FIRST+mask-1
	if mask == 0: return BROWN_PORES
	if mask == 63: return BROWN_CAP
	return BROWN_CAP_FIRST+mask-1

static func pores_for(small: int) -> int: return cap_for(small,0)
static func is_stem(id: int) -> bool: return STEMS.has(id)
static func is_full_stem(id: int) -> bool: return id in [BROWN_FULL_STEM,RED_FULL_STEM]
static func is_cap(id: int) -> bool: return mask_of(id) >= 0
static func is_pores(id: int) -> bool: return PORES.has(id)
static func is_huge(id: int) -> bool: return is_stem(id) or is_cap(id)

static func stem_for(small: int) -> int:
	return RED_STEM if small == Nodes.RED_MUSHROOM else BROWN_STEM

static func full_stem_for(small: int) -> int:
	return RED_FULL_STEM if small == Nodes.RED_MUSHROOM else BROWN_FULL_STEM

# The small mushroom a huge-mushroom block belongs to, which is what the block drops
# without Silk Touch.
static func species_of(id: int) -> int:
	if id in [RED_STEM,RED_FULL_STEM,RED_CAP,RED_PORES] or id >= RED_CAP_FIRST and id <= NEW_LAST: return Nodes.RED_MUSHROOM
	return Nodes.BROWN_MUSHROOM

static func mask_string(mask: int) -> String:
	var result: String = ""
	for bit in FACE_BITS: result += "1" if mask & bit else "0"
	return result

static func source_name(id: int) -> String:
	return str(DATA.get(id,{}).get("source_node",""))

const DATA = {
	1207: {"name":"Brown mushroom stem","block":true,"color":"c9b287","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"source_node":"mcl_mushrooms:brown_mushroom_block_stem"},
	1208: {"name":"Red mushroom stem","block":true,"color":"e4e0d3","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"source_node":"mcl_mushrooms:red_mushroom_block_stem"},
	1209: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_111111"},
	1210: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"source_node":"mcl_mushrooms:red_mushroom_block_cap_111111"},
	1211: {"name":"Brown mushroom block pores","block":true,"color":"cbb99c","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_000000"},
	1212: {"name":"Red mushroom block pores","block":true,"color":"e0d6c2","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_000000"},
	16000: {"name":"Huge Brown Mushroom All-Faces Stem","block":true,"color":"c9b287","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"source_node":"mcl_mushrooms:brown_mushroom_block_stem_full"},
	16001: {"name":"Huge Red Mushroom All-Faces Stem","block":true,"color":"e4e0d3","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"source_node":"mcl_mushrooms:red_mushroom_block_stem_full"},
	16002: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_000001"},
	16003: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_000010"},
	16004: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_000011"},
	16005: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_000100"},
	16006: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_000101"},
	16007: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_000110"},
	16008: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_000111"},
	16009: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_001000"},
	16010: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_001001"},
	16011: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_001010"},
	16012: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_001011"},
	16013: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_001100"},
	16014: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_001101"},
	16015: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_001110"},
	16016: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_001111"},
	16017: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_010000"},
	16018: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_010001"},
	16019: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_010010"},
	16020: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_010011"},
	16021: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_010100"},
	16022: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_010101"},
	16023: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_010110"},
	16024: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_010111"},
	16025: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_011000"},
	16026: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_011001"},
	16027: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_011010"},
	16028: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_011011"},
	16029: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_011100"},
	16030: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_011101"},
	16031: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_011110"},
	16032: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_011111"},
	16033: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_100000"},
	16034: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_100001"},
	16035: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_100010"},
	16036: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_100011"},
	16037: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_100100"},
	16038: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_100101"},
	16039: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_100110"},
	16040: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_100111"},
	16041: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_101000"},
	16042: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_101001"},
	16043: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_101010"},
	16044: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_101011"},
	16045: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_101100"},
	16046: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_101101"},
	16047: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_101110"},
	16048: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_101111"},
	16049: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_110000"},
	16050: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_110001"},
	16051: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_110010"},
	16052: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_110011"},
	16053: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_110100"},
	16054: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_110101"},
	16055: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_110110"},
	16056: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_110111"},
	16057: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_111000"},
	16058: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_111001"},
	16059: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_111010"},
	16060: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_111011"},
	16061: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_111100"},
	16062: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_111101"},
	16063: {"name":"Brown mushroom block","block":true,"color":"b08a5e","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:brown_mushroom_block_cap_111110"},
	16064: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_000001"},
	16065: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_000010"},
	16066: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_000011"},
	16067: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_000100"},
	16068: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_000101"},
	16069: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_000110"},
	16070: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_000111"},
	16071: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_001000"},
	16072: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_001001"},
	16073: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_001010"},
	16074: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_001011"},
	16075: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_001100"},
	16076: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_001101"},
	16077: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_001110"},
	16078: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_001111"},
	16079: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_010000"},
	16080: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_010001"},
	16081: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_010010"},
	16082: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_010011"},
	16083: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_010100"},
	16084: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_010101"},
	16085: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_010110"},
	16086: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_010111"},
	16087: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_011000"},
	16088: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_011001"},
	16089: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_011010"},
	16090: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_011011"},
	16091: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_011100"},
	16092: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_011101"},
	16093: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_011110"},
	16094: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_011111"},
	16095: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_100000"},
	16096: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_100001"},
	16097: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_100010"},
	16098: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_100011"},
	16099: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_100100"},
	16100: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_100101"},
	16101: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_100110"},
	16102: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_100111"},
	16103: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_101000"},
	16104: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_101001"},
	16105: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_101010"},
	16106: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_101011"},
	16107: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_101100"},
	16108: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_101101"},
	16109: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_101110"},
	16110: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_101111"},
	16111: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_110000"},
	16112: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_110001"},
	16113: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_110010"},
	16114: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_110011"},
	16115: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_110100"},
	16116: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_110101"},
	16117: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_110110"},
	16118: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_110111"},
	16119: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_111000"},
	16120: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_111001"},
	16121: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_111010"},
	16122: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_111011"},
	16123: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_111100"},
	16124: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_111101"},
	16125: {"name":"Red mushroom block","block":true,"color":"c8452f","hardness":0.2,"tool":0,"flammable":true,"compostability":65,"hidden":true,"source_node":"mcl_mushrooms:red_mushroom_block_cap_111110"},
}
static var BLOCKS: Array = DATA.keys()
static var CAPS: Array = _make_caps()

static func _make_caps() -> Array:
	var result: Array = []
	for small in [Nodes.BROWN_MUSHROOM,Nodes.RED_MUSHROOM]:
		for mask in 64: result.append(cap_for(small,mask))
	return result

static func silk_touch_drop(id: int) -> int:
	if is_cap(id): return cap_for(species_of(id))
	return id if is_stem(id) else 0

# Six booleans in source tile order. These are also sufficient to reconstruct a
# cap's persisted/networked ID: no block_states or other side channel is needed.
static func face_states(id: int) -> Array:
	var result: Array = []
	var mask: int = mask_of(id)
	if mask >= 0:
		for bit in FACE_BITS: result.append(bool(mask & bit))
	elif is_stem(id):
		for face in 6: result.append(is_full_stem(id) or face >= 2)
	return result

# Return the registered ID whose procedural atlas art should be used for a face.
# `face` uses source tile order (+Y,-Y,+X,-X,+Z,-Z).
static func face_texture(id: int, face: int) -> int:
	if face < 0 or face >= 6: return id
	var states: Array = face_states(id)
	if states.is_empty(): return id
	if is_cap(id): return cap_for(species_of(id),63 if states[face] else 0)
	if not states[face]: return pores_for(species_of(id))
	return id

# BlockMesher/Nodes.face order is +X,-X,+Y,-Y,+Z,-Z.
static func render_texture(id: int, face: int) -> int:
	return face_texture(id,SOURCE_FACE_FOR_RENDER[face]) if face >= 0 and face < 6 else id

static func state_snapshot(id: int) -> Dictionary:
	var textures: Array = []
	for face in 6: textures.append(face_texture(id,face))
	return {"id":id,"source_node":source_name(id),"species":species_of(id) if is_huge(id) else 0,"kind":"full_stem" if is_full_stem(id) else ("stem" if is_stem(id) else ("cap" if is_cap(id) else "")),"mask":mask_of(id),"skin":face_states(id),"textures":textures}

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
# The source's `supports_mushrooms` hosts, including the coarse and covered soil
# variants. Huge growth still applies its own room and forty-percent rolls.
const SOILS = [Nodes.DIRT,Nodes.GRASS,685,DryTerrain.COARSE_DIRT,SoilVariants.PODZOL,SoilVariants.MYCELIUM] # 685: swamp grass, without a VillageContent constant cycle.

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
				# The stem's own column stays stem rather than becoming cap.
				if cell == "S":
					result[offset] = stem_for(small) if not result.has(offset) else result[offset]
				else:
					result[offset] = cap_id
	# Encode every schematic cap face in the source's own mask. Stems do not hide
	# cap skin; only a touching cap of the same species does.
	for offset in result:
		if result[offset] != cap_id: continue
		var mask: int = 63
		for face in 6:
			if is_cap(result.get(offset+FACES[face],0)): mask &= ~FACE_BITS[face]
		result[offset] = cap_for(small,mask)
	return result

# Source cap_111111.on_construct. Only the all-skin cap runs this callback. The
# source's `huge_mushroom_cap ~= 0` test deliberately excludes cap_000000: its
# group exists but has value zero, so an all-pore neighbour triggers nothing.
static func placed(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if mask_of(id) != 63: return false
	var small: int = species_of(id)
	for face in 6:
		var at: Vector3i = p+FACES[face]
		var neighbor: int = world.node_at(at)
		var neighbor_mask: int = mask_of(neighbor)
		if neighbor_mask <= 0 or species_of(neighbor) != small: continue
		var own_mask: int = mask_of(world.node_at(p))
		var own_next: int = own_mask & ~FACE_BITS[face]
		var neighbor_next: int = neighbor_mask & ~FACE_BITS[OPPOSITE[face]]
		# The source writes the neighbor first, then its accumulated self update.
		if neighbor_next != neighbor_mask: world.set_node(at,cap_for(small,neighbor_next))
		if own_next != own_mask: world.set_node(p,cap_for(small,own_next))
	return true

# VoxelWorld integration hook. Internal masks never reconstruct on neighbour
# removal, and replacing a cap with another cap of the same ID is not placement.
static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> bool:
	if old_id == id or mask_of(id) != 63: return false
	return placed(world,p)

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
	var base: Color = Color(DATA[id].color)
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

# `mcl_mushrooms:mushroom_island_vegetation`: one huge red or brown mushroom
# on a square-heightmap candidate, selected evenly. The source's feature uses
# the normal huge-mushroom shape roll, so the same limits apply. Deterministic
# world-coordinate seeds keep neighboring column halos identical.
static func decorate_island(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array) -> bool:
	var base: Vector2i = coord*16-Vector2i.ONE
	var placed: bool = false
	for z in range(1,17):
		for x in range(1,17):
			var wx: int = base.x+x
			var wz: int = base.y+z
			if gen.hash_at(wx,701,wz)%97 != 0: continue
			if gen.biome(wx,wz) != "MushroomIslands": continue
			var h: int = gen.terrain_height(wx,wz)
			if h <= TerrainGenerator.SEA or h >= gen.terrain_ceiling()-1: continue
			if data[x+z*18+h*324] != SoilVariants.MYCELIUM: continue
			var small: int = Nodes.RED_MUSHROOM if gen.hash_at(wx,702,wz)%2 == 0 else Nodes.BROWN_MUSHROOM
			var rng := RandomNumberGenerator.new(); rng.seed = gen.hash_at(wx,703,wz)
			var height: int = rng.randi_range(0,BASE_HEIGHT_MAX)
			if rng.randi_range(1,DOUBLE_CHANCE) == 1: height = height*2+SCHEM_STEM-1
			var stem: int = height+SCHEM_STEM
			var half: int = cap_width(small)/2
			var top: int = stem+cap_layers(small).size()-1
			if h+1+top >= gen.terrain_ceiling(): continue
			if not island_room(data,x,h,z,half,top): continue
			var plan: Dictionary = shape(small,stem)
			for offset in plan:
				var lx: int = x+offset.x
				var lz: int = z+offset.z
				if lx < 0 or lx >= 18 or lz < 0 or lz >= 18: continue
				data[lx+lz*18+(h+1+offset.y)*324] = int(plan[offset])
			placed = true
	return placed

static func island_room(data: PackedInt32Array, x: int, h: int, z: int, half: int, top: int) -> bool:
	if data[x+z*18+h*324] != SoilVariants.MYCELIUM: return false
	for ox in range(-half,half+1):
		for oz in range(-half,half+1):
			var lx: int = x+ox
			var lz: int = z+oz
			if lx < 0 or lx >= 18 or lz < 0 or lz >= 18: return false
			for y in range(1,top+1):
				if data[lx+lz*18+(h+y)*324] != Nodes.AIR: return false
	return true

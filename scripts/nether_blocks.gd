class_name NetherBlocks
extends RefCounted

# The remaining nether and blackstone building materials that Voxey did not have.
# Ported from the local Mineclonia checkout:
#   * mods/ITEMS/mcl_nether/init.lua           (nether brick variants, quartz family)
#   * mods/ITEMS/mcl_nether/nether_wart.lua    (nether wart block)
#   * mods/ITEMS/mcl_blackstone/init.lua       (polished basalt, quartz bricks,
#                                               cracked polished blackstone bricks,
#                                               eternal soul fire)
#   * mods/ITEMS/mcl_stairs/crafting.lua       (chiseled quartz from quartz slabs)
#   * mods/CORE/mcl_explosions/init.lua:40-41  (blast resistance defaults to hardness)
#   * mods/ITEMS/mcl_fire/init.lua:93-99       (fire's on_construct upgrade)
# Textures are original procedural Voxey artwork.
#
# Hardness and blast resistance are the source's own values. Where the source
# declares no `_mcl_blast_resistance`, mcl_explosions falls back to `_mcl_hardness`
# (mods/CORE/mcl_explosions/init.lua:40-41), which is what the `blast_resistance`
# values below record so an explosion treats a chiseled quartz block as 0.8.

const RED_NETHER_BRICKS = 11200
const CHISELED_NETHER_BRICKS = 11201
const CRACKED_NETHER_BRICKS = 11202
const NETHER_WART_BLOCK = 11203
const CHISELED_QUARTZ = 11204
const SMOOTH_QUARTZ = 11205
const QUARTZ_BRICK = 11206
const POLISHED_BASALT = 11207
const CRACKED_BLACKSTONE_BRICKS = 11208
const SOUL_FIRE = 11209

const BLOCKS = [RED_NETHER_BRICKS,CHISELED_NETHER_BRICKS,CRACKED_NETHER_BRICKS,NETHER_WART_BLOCK,CHISELED_QUARTZ,SMOOTH_QUARTZ,QUARTZ_BRICK,POLISHED_BASALT,CRACKED_BLACKSTONE_BRICKS,SOUL_FIRE]

const DATA = {
	# Source mcl_nether/init.lua:214-217, from the shared `nether_brick` template at
	# :200-207: `pickaxey=1, material_stone=1`, `_mcl_blast_resistance = 6`,
	# `_mcl_hardness = 2`.
	11200:{"name":"Red nether bricks","block":true,"color":"6d2f34","hardness":2.0,"blast_resistance":6,"tool":0,"note_material":"stone","source_node":"mcl_nether:red_nether_brick"},
	# Source mcl_nether/init.lua:220-224: same template, `_mcl_stonecutter_recipes`
	# of the plain nether bricks.
	11201:{"name":"Chiseled nether bricks","block":true,"color":"452c34","hardness":2.0,"blast_resistance":6,"tool":0,"note_material":"stone","source_node":"mcl_nether:chiseled_nether_brick"},
	# Source mcl_nether/init.lua:226-229: the furnace output of the plain nether
	# bricks, same template.
	11202:{"name":"Cracked nether bricks","block":true,"color":"38242b","hardness":2.0,"blast_resistance":6,"tool":0,"note_material":"stone","source_node":"mcl_nether:cracked_nether_brick"},
	# Source mcl_nether/init.lua:231-244: `handy=1, hoey=7, swordy=1`,
	# `_mcl_hardness = 1`, no blast resistance (so 1) and no `material_stone`, which
	# is why this one block is a hoe block and not a pickaxe block.
	11203:{"name":"Nether wart block","block":true,"color":"8f2b30","hardness":1.0,"blast_resistance":1,"tool":4,"source_node":"mcl_nether:nether_wart_block"},
	# Source mcl_nether/init.lua:258-267: `pickaxey=1, quartz_block=1`,
	# `_mcl_hardness = 0.8`, no blast resistance.
	11204:{"name":"Chiseled quartz block","block":true,"color":"e8e2d4","hardness":0.8,"blast_resistance":0.8,"tool":0,"note_material":"stone","source_node":"mcl_nether:quartz_chiseled"},
	# Source mcl_nether/init.lua:282-292: `_mcl_blast_resistance = 6`,
	# `_mcl_hardness = 2`. Smelted from the quartz block, which is an existing id.
	11205:{"name":"Smooth quartz","block":true,"color":"ded7c5","hardness":2.0,"blast_resistance":6,"tool":0,"note_material":"stone","source_node":"mcl_nether:quartz_smooth"},
	# Source mcl_blackstone/init.lua:145-152: `_mcl_hardness = 0.8`, no blast
	# resistance. Crafted from the quartz block (mcl_nether/init.lua:255).
	11206:{"name":"Quartz bricks","block":true,"color":"e3dccd","hardness":0.8,"blast_resistance":0.8,"tool":0,"note_material":"stone","source_node":"mcl_blackstone:quartz_brick"},
	# Source mcl_blackstone/init.lua:69-80: `_mcl_blast_resistance = 4.2`,
	# `_mcl_hardness = 1.25`. Crafted from basalt (:93).
	11207:{"name":"Polished basalt","block":true,"color":"414049","hardness":1.25,"blast_resistance":4.2,"tool":0,"note_material":"stone","source_node":"mcl_blackstone:basalt_polished"},
	# Source mcl_blackstone/init.lua:136-143: `_mcl_blast_resistance = 6`,
	# `_mcl_hardness = 1.5`. The furnace output of polished blackstone bricks.
	11208:{"name":"Cracked polished blackstone bricks","block":true,"color":"413b45","hardness":1.5,"blast_resistance":6,"tool":0,"note_material":"stone","source_node":"mcl_blackstone:blackstone_brick_polished_cracked"},
	# Source mcl_blackstone/init.lua:161-200: "Eternal Soul Fire",
	# `drawtype = "firelike"`, `light_source = 10`, `walkable = false`,
	# `buildable_to = true`, `sunlight_propagates = true`, `damage_per_second = 2`,
	# `groups = {fire = 1, dig_immediate = 3, not_in_creative_inventory = 1,
	# soul_firelike = 1}`. It carries no hardness and no drop, so it is a hidden
	# fire state rather than an item. `shape` is "plant" because that is how Voxey
	# already models its own flame (scripts/village_content.gd:626-627), which gives
	# the crossed-quad flame mesh and a non-solid, see-through node.
	11209:{"name":"Soul fire","block":true,"shape":"plant","color":"9fe8ff","hardness":0.0,"blast_resistance":0.0,"light":10,"emits":10,"transparent":true,"hidden":true,"tool":-1,"source_node":"mcl_blackstone:soul_fire"},
}

# --- predicates --------------------------------------------------------------

static func is_soul_fire(id: int) -> bool: return id == SOUL_FIRE

# Source `light_source = 10` (mcl_blackstone/init.lua:178), against plain fire's
# `core.LIGHT_MAX` and Voxey's flat 14 for a flame
# (scripts/pasture.gd:40 `id in [...] or Fire.is_fire(id): return 14`). Every other
# light-emitting module here exposes this accessor for `Pasture.emission`, so soul
# fire follows the same shape rather than being special-cased there.
static func light_level(id: int) -> int: return 10 if is_soul_fire(id) else 0

# The source's `group:soul_block` (mcl_nether/init.lua:150 soul_sand,
# mcl_blackstone/init.lua:158 soul_soil). Voxey holds both ids already.
static func soul_block(id: int) -> bool: return id in [Nodes.SOUL_SAND,Campfires.SOUL_SOIL]

# Source mcl_fire/init.lua:93-99 swaps a newly built fire above netherrack, magma
# or end bedrock to eternal fire; mcl_blackstone/init.lua:201-208 extends that rule
# to `group:soul_block` but swaps to soul fire instead. `flame_for` is the id an
# ignite above `support` should place, or 0 when the plain rules apply.
static func flame_for(support: int) -> int: return SOUL_FIRE if soul_block(support) else 0

# Soul fire's own on_construct (mcl_blackstone/init.lua:192-198) turns it straight
# back to air when its support is a soul block. The two rules do not conflict: the
# fire patch uses `core.swap_node`, which runs no construct callback, so an ignited
# soul flame survives while a *constructed* one over soul block does not. A caller
# that builds soul fire directly rather than through the ignite path has to apply
# that second rule itself. Soul fire's `damage_per_second = 2` against plain fire's
# 1 (mcl_fire/init.lua:87) is likewise a per-node rate rather than Voxey's flat 1.

# --- recipes -----------------------------------------------------------------

# Every material below is made only from blocks Voxey can already obtain: nether
# wart from wart farms on soul sand (VillageContent.NETHER_WART_ITEM), nether brick
# items from smelted netherrack, quartz from nether quartz ore, basalt from the
# basalt deltas surface, and blackstone from the ore scatter.
static func recipes(inv: Inventory) -> void:
	# Source mcl_nether/init.lua:421-434 registers the same 2x2 twice, once in each
	# diagonal. `Inventory.matching_recipe` mirrors a pattern, so one registration
	# covers both arrangements.
	var wart: int = VillageContent.NETHER_WART_ITEM
	var brick: int = Nodes.NETHER_BRICK_ITEM
	inv._recipe("Red nether bricks",RED_NETHER_BRICKS,1,[wart,brick,brick,wart],2)
	# Source mcl_nether/init.lua:436-442: one column of two nether brick slabs.
	# `Nodes.NETHER_BRICKS` is index 13 of `BuildingShapes.MATERIALS`, so its slab is
	# 4208.
	var nether_slab: int = BuildingShapes.slab_for(Nodes.NETHER_BRICKS)
	inv._recipe("Chiseled nether bricks",CHISELED_NETHER_BRICKS,1,[nether_slab,nether_slab],1)
	# Source mcl_nether/nether_wart.lua:140, the wart item's `square3` output.
	inv._recipe("Nether wart block",NETHER_WART_BLOCK,1,[wart,wart,wart,wart,wart,wart,wart,wart,wart],3,"table")
	# The checkout's nether wart block carries no `single` decraft, unlike its
	# netherite block (:69) and hay bale; this reverse is registered on the
	# integration brief's instruction so the block is not a crafting dead end.
	inv._recipe("Nether wart",VillageContent.NETHER_WART_ITEM,9,[NETHER_WART_BLOCK],1)
	# Source mcl_stairs/crafting.lua:30-37: one column of two quartz slabs giving
	# two chiseled blocks. `VillageContent.QUARTZ_BLOCK` is index 17 of
	# `BuildingShapes.MATERIALS`, so its slab is 4272.
	var quartz_slab: int = BuildingShapes.slab_for(VillageContent.QUARTZ_BLOCK)
	inv._recipe("Chiseled quartz block",CHISELED_QUARTZ,2,[quartz_slab,quartz_slab],1)
	# Source mcl_nether/init.lua:255, the quartz block's `square2` output of
	# "mcl_blackstone:quartz_brick 4".
	var quartz: int = VillageContent.QUARTZ_BLOCK
	inv._recipe("Quartz bricks",QUARTZ_BRICK,4,[quartz,quartz,quartz,quartz],2)
	# Source mcl_blackstone/init.lua:93, basalt's `square2` output of
	# "mcl_blackstone:basalt_polished 4".
	var basalt: int = Nodes.BASALT
	inv._recipe("Polished basalt",POLISHED_BASALT,4,[basalt,basalt,basalt,basalt],2)

# Furnace outputs that belong to *existing* ids, so they cannot live in a `smelt`
# key on this module's own DATA. `Nodes.smelt_result` should consult this first:
#   * nether bricks -> cracked nether bricks (mcl_nether/init.lua:211)
#   * polished blackstone bricks -> their cracked form (mcl_blackstone/init.lua:134)
#   * quartz block -> smooth quartz (mcl_nether/init.lua:254)
static func smelt_output(id: int) -> int:
	if id == Nodes.NETHER_BRICKS: return CRACKED_NETHER_BRICKS
	if id == Bastions.BRICKS: return CRACKED_BLACKSTONE_BRICKS
	if id == VillageContent.QUARTZ_BLOCK: return SMOOTH_QUARTZ
	return 0

# --- art ---------------------------------------------------------------------

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(DATA[id].color)
	# A soul flame keeps the source flame's silhouette (VillageArt draws it at
	# scripts/village_art.gd:47-48) but burns cold: a pale blue-white core over a
	# deep blue body, transparent everywhere the flame is not.
	if id == SOUL_FIRE:
		if y > 10 and x in range(4,12): return Color("c6f2ff")
		if y > (x*7)%11: return Color("3f8fd8")
		return Color.TRANSPARENT
	# Wart is a mass of small red blobs with darker pores, denser than the noisy
	# cube base so it does not read as plain coloured stone.
	if id == NETHER_WART_BLOCK:
		if (x/2*3+y/2*5)%7 < 2: return base.darkened(0.3)
		return noise.lightened(0.06) if (x+y)%5 == 0 else noise
	# The chiseled faces are a squared ring around a pair of centre grooves, the
	# shape both the source's chiseled nether bricks and chiseled quartz share.
	if id in [CHISELED_NETHER_BRICKS,CHISELED_QUARTZ]:
		var ring: int = maxi(absi(x-7),absi(y-7))
		if ring in [3,6] or (x in [6,9] and y in range(5,11)):
			return base.darkened(0.35) if id == CHISELED_NETHER_BRICKS else base.darkened(0.12)
		return noise
	# Smooth quartz is nearly flat, so only its edges read as a block boundary.
	if id == SMOOTH_QUARTZ:
		return base.darkened(0.1) if x in [0,15] or y in [0,15] else noise.lightened(0.03)
	# Quartz bricks are the same running bond as the masonry bricks but with pale
	# mortar and a lighter seam, matching the source's own quartz brick sheet.
	if id == QUARTZ_BRICK:
		if y%4 == 0 or posmod(x+(4 if y/4%2 else 0),8) == 0: return base.darkened(0.16)
		return noise.lightened(0.04) if y%4 == 1 else noise
	if id == POLISHED_BASALT:
		return base.darkened(0.22) if x in [0,15] or y in [0,15] else (base.lightened(0.08) if x == 1 or y == 1 else noise)
	# A nether brick is a four-pixel course staggered every other row. Cracked
	# bricks carry scorched seams through the course, and the red variant is the
	# same course in the source's warmer colour.
	if id in [RED_NETHER_BRICKS,CRACKED_NETHER_BRICKS,CRACKED_BLACKSTONE_BRICKS]:
		if y%4 == 0 or posmod(x+(4 if y/4%2 else 0),8) == 0: return base.darkened(0.4)
		if id in [CRACKED_NETHER_BRICKS,CRACKED_BLACKSTONE_BRICKS] and (x == y/2+2 or x == 15-y/3): return base.darkened(0.5)
		return noise.lightened(0.06) if y%4 == 1 else noise
	return noise

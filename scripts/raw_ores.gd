class_name RawOres
extends RefCounted

# Mineclonia mcl_raw_ores/init.lua, mcl_copper/items.lua, mcl_copper/nodes.lua and
# the ore drop tables in mcl_core/nodes_base.lua, GPL-3.0-or-later. Original
# procedural Voxey art; no source texture is copied.
#
# Source-exact rules reproduced here:
# - `register_raw_ore` registers one craftitem plus one 9-item storage block per
#   metal. The item's `_mcl_cooking_output` is the matching ingot, so a raw ore
#   smelts in a furnace and a blast furnace; the block is only decorative storage.
# - Both the item and its block declare `blast_furnace_smeltable = 1`, but **only
#   the item declares a cooking output**. A raw block therefore smelts into
#   nothing, which Voxey records rather than repairs: `smelt` is absent from the
#   three raw-block entries below.
# - Raw blocks are `pickaxey = 2` (iron tier), hardness 5, blast resistance 6.
#   Both raw block variants in source are `is_ground_content = false`.
# - `mcl_copper:block_raw` is "Block of Raw Copper", hardness 5, blast resistance
#   6, `pickaxey = 2`, and unpacks into nine `mcl_copper:raw_copper`.
# - `mcl_copper:block` (Block of Copper) is `pickaxey = 2`, hardness 3, blast
#   resistance 6, and unpacks into nine ingots.
# - `mcl_copper:copper_nugget` -> 3x3 of it makes one `mcl_copper:copper_ingot`;
#   one ingot unpacks into nine nuggets (`mcl_copper:copper_ingot.single`).
#
# Ore drops stay in `Nodes.drop`, which the parent wires, and follow the source's
# `mcl_core.fortune_drop_ore` (discrete uniform 2..1+fortune, chance
# 1-2/(fortune+2), multiply): iron ore drops one raw iron, gold ore one raw gold,
# copper ore two to five raw copper.
#
# Recorded integration decision, not a silent overlap:
# - Voxey's "Block of Copper" already exists as `Nodes.COPPER_NODE` (id 37). It is
#   `Copper.BLOCK_STAGES[0]`, so it is the pristine stage of the oxidation chain,
#   and `inventory.gd` plus `Copper.recipes` already register both directions of the
#   nine-ingot pair against it. This module therefore does **not** register a second
#   copper block: a duplicate would have given the game two ids for one observable
#   block. The nugget recipes below use id 37.

const RAW_IRON = 11300
const RAW_GOLD = 11301
const RAW_COPPER = 11302
const RAW_IRON_BLOCK = 11303
const RAW_GOLD_BLOCK = 11304
const RAW_COPPER_BLOCK = 11305
const COPPER_NUGGET = 11306

# Only the placeable storage blocks take a generated atlas tile; the raw items and
# the nugget are drawn by `ItemArt`. `Nodes.COPPER_NODE` already has its own tile.
const BLOCKS = [RAW_IRON_BLOCK,RAW_GOLD_BLOCK,RAW_COPPER_BLOCK]

const DATA = {
	11300:{"name":"Raw iron","color":"dba36f","stack":64,"smelt":Nodes.IRON,"source_node":"mcl_raw_ores:raw_iron"},
	11301:{"name":"Raw gold","color":"d9b45c","stack":64,"smelt":Nodes.GOLD,"source_node":"mcl_raw_ores:raw_gold"},
	11302:{"name":"Raw copper","color":"dd8452","stack":64,"smelt":Nodes.COPPER,"source_node":"mcl_copper:raw_copper"},
	# No `note_material`: every source definition here uses
	# `mcl_sounds.node_sound_metal_defaults()`, and Voxey's note-block material
	# vocabulary has no metal class. `source_node` carries the source name so the
	# parent can map these to the metal instruments beside `Nodes.IRON_BLOCK`
	# (xylophone_metal) and `Nodes.GOLD_BLOCK` (bell) in note_blocks.gd.
	11303:{"name":"Block of raw iron","block":true,"shape":"cube","color":"c9a483","hardness":5.0,"tool":0,"blast_resistance":6.0,"source_node":"mcl_raw_ores:raw_iron_block"},
	11304:{"name":"Block of raw gold","block":true,"shape":"cube","color":"d9ba5c","hardness":5.0,"tool":0,"blast_resistance":6.0,"source_node":"mcl_raw_ores:raw_gold_block"},
	11305:{"name":"Block of raw copper","block":true,"shape":"cube","color":"c9805a","hardness":5.0,"tool":0,"blast_resistance":6.0,"source_node":"mcl_copper:block_raw"},
	11306:{"name":"Copper nugget","color":"e0a06a","stack":64,"source_node":"mcl_copper:copper_nugget"},
}

static func is_raw(id: int) -> bool: return id in [RAW_IRON,RAW_GOLD,RAW_COPPER]
static func is_raw_block(id: int) -> bool: return id in [RAW_IRON_BLOCK,RAW_GOLD_BLOCK,RAW_COPPER_BLOCK]

static func block_for(raw_id: int) -> int:
	match raw_id:
		RAW_IRON: return RAW_IRON_BLOCK
		RAW_GOLD: return RAW_GOLD_BLOCK
		RAW_COPPER: return RAW_COPPER_BLOCK
	return 0

static func raw_for(block_id: int) -> int:
	match block_id:
		RAW_IRON_BLOCK: return RAW_IRON
		RAW_GOLD_BLOCK: return RAW_GOLD
		RAW_COPPER_BLOCK: return RAW_COPPER
	return 0

# --- recipes ----------------------------------------------------------------

# Source `_mcl_crafting_output.square3` on each raw item, and the storage block's
# `single` output of nine items. The ingot/nugget pair is `mcl_copper`'s own
# square3/single pair. Unpacking is a one-ingredient recipe and is hand craftable,
# matching every other storage block in Voxey.
static func recipes(inv: Inventory) -> void:
	for raw in [RAW_IRON,RAW_GOLD,RAW_COPPER]:
		var block: int = block_for(raw)
		var square: Array = []; square.resize(9); square.fill(raw)
		inv._recipe(Nodes.title(block),block,1,square,3,"table")
		inv._recipe(Nodes.title(raw)+" (unpack)",raw,9,[block],1)
	# Source `mcl_copper:copper_nugget`: a 3x3 of nuggets makes one ingot, and one
	# ingot unpacks into nine nuggets.
	var nuggets: Array = []; nuggets.resize(9); nuggets.fill(COPPER_NUGGET)
	inv._recipe(Nodes.title(Nodes.COPPER),Nodes.COPPER,1,nuggets,3,"table")
	inv._recipe(Nodes.title(COPPER_NUGGET)+" (unpack)",COPPER_NUGGET,9,[Nodes.COPPER],1)

# --- art --------------------------------------------------------------------

# `Color * float` scales the alpha channel as well as the colour, which would
# leave every tile partly transparent (0.90-1.02 alpha here) and let the terrain
# shader fade it against whatever is behind. Brightness scaling for opaque art has
# to rebuild the colour and pin alpha back to one.
static func _shade(c: Color, factor: float) -> Color:
	return Color(c.r*factor,c.g*factor,c.b*factor,1.0)

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(VillageContent.DATA[id].color)
	if is_raw_block(id):
		# Raw ore blocks are a stone matrix shot through with raw metal; the flecks
		# are irregular clusters rather than single pixels, as the source tiles are.
		# Each metal shifts the cluster pattern so the three are not one recolour.
		var offset: int = [RAW_IRON_BLOCK,RAW_GOLD_BLOCK,RAW_COPPER_BLOCK].find(id)*3
		var rock: Color = _shade(Color("86898c"),0.9+float((x/3*3+y/2*7)%5)*0.03)
		if posmod(x/2*7+y/2*11+offset,13) < 4 and posmod(x*3+y+offset,7) != 0:
			return _shade(base,0.94+float((x+y)%4)*0.035)
		if posmod(x*5+y*3+offset,29) == 0: return base.darkened(0.12)
		return rock
	# Block of copper: a polished metal face, bevelled at the tile edge with a soft
	# diagonal sheen so it reads as a worked block rather than a raw ore.
	if x in [0,15] or y in [0,15]: return base.darkened(0.22)
	if x in [1,14] or y in [1,14]: return base.lightened(0.14)
	if posmod(x+y*2,8) < 2: return base.lightened(0.07)
	if posmod(x*3+y*5,17) == 0: return base.darkened(0.08)
	return noise.lerp(base,0.7)

# --- ore drops ---------------------------------------------------------------

# Source `mcl_core/nodes_base.lua`: iron ore `drop = "mcl_raw_ores:raw_iron"` and
# gold ore `drop = "mcl_raw_ores:raw_gold"`. Copper ore keeps its own table in the
# source (two to five raw copper with a Fortune rarity), which `Nodes.drop` handles
# by returning the single raw item and the break path rolls the count through
# `harvest` below.
static func drop_for(ore_id: int) -> int:
	if ore_id == Nodes.IRON_ORE: return RAW_IRON
	if ore_id == Nodes.GOLD_ORE: return RAW_GOLD
	if ore_id == Nodes.COPPER_ORE: return RAW_COPPER
	return ore_id

# Source `mcl_copper/nodes.lua` copper ore drop table: `max_items = 1` with rarity
# 4 -> 5, 3 -> 4, 2 -> 3, default 2, under `mcl_core.fortune_drop_ore`
# (a discrete uniform min..1+fortune with chance 1 - 2/(fortune+2)).
static func harvest(id: int, slot: Dictionary) -> Array:
	if id != Nodes.COPPER_ORE and id != Nodes.DEEP_COPPER_ORE: return []
	var fortune: int = Inventory.enchantment(slot,"Fortune")
	# Source `mcl_core.fortune_drop_ore` with the copper ore's own table: the base
	# drop is `raw_copper 2`, and a **discrete uniform multiplier** of
	# `random(min_count = 2, max_count + fortune = 1 + fortune)` replaces it with
	# chance `1 - 2 / (fortune + 2)`. At Fortune 0 the chance is zero, so the count
	# is always the base two rather than one.
	var count: int = 2
	if randf() < 1.0-2.0/(fortune+2): count *= randi_range(2,1+fortune)
	return [[RAW_COPPER,count]]

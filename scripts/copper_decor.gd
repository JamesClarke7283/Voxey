class_name CopperDecor
extends RefCounted

# Mineclonia ITEMS/mcl_copper/nodes.lua, GPL-3.0-or-later. Original GDScript using
# the source as a behaviour reference; all art is original procedural code.
#
# The source's copper module registers four **decorative** families beside the
# building blocks, each of which oxidises as its own decay chain, is waxed and
# scraped by an axe, and is de-oxidised by lightning like every other copper node:
#
# - **Copper lantern** — a light source at the source's maximum, placed on a floor or
#   hanging from a ceiling, in all four oxidation stages (eight nodes).
# - **Copper chain** — a thin metal column, four stages.
# - **Copper bars** — a pane that connects to its neighbours, four stages.
#
# Voxey already had the iron lantern, the soul lantern and the plain chain, and it
# already carries the whole copper oxidation engine in `Copper`. This module adds
# the three copper families as **ordinary members of that engine**, so they oxidise,
# wax, scrape and strike exactly as the copper blocks do: their stage arrays are
# registered into `Copper.CHAINS` and their metadata travels through the existing
# `copper_waxed` flag.
#
# The source's copper **torch** is absent from this checkout (`mcl_torches` registers
# no copper variant), so it is not invented here.

const LANTERN_FLOOR = 11530
const LANTERN_CEILING = 11534
const CHAIN = 11538
const BARS = 11542
# Four oxidation stages per family, in source order: plain, exposed, weathered,
# oxidized.
const STAGES = 4
const COUNT = 16
const BLOCKS = [11530,11531,11532,11533,11534,11535,11536,11537,11538,11539,11540,11541,11542,11543,11544,11545]
const LANTERN_FLOOR_STAGES = [11530,11531,11532,11533]
const LANTERN_CEILING_STAGES = [11534,11535,11536,11537]
const CHAIN_STAGES = [11538,11539,11540,11541]
const BAR_STAGES = [11542,11543,11544,11545]

# The stage colours, matching the copper block chain's own progression.
const STAGE_COLORS = ["c77a52","c08a6a","8ba07c","5aa88c"]
const STAGE_NAMES = ["Copper","Exposed copper","Weathered copper","Oxidized copper"]

const DATA = {
	11530:{"name":"Copper lantern","block":true,"shape":"lantern","color":"c77a52","hardness":3.0,"tool":0,"blast_resistance":6.0,"light":14,"family":"copper_decor","copper_stage":0,"copper_family":"lantern"},
	11534:{"name":"Copper lantern","block":true,"shape":"lantern","color":"c77a52","hardness":3.0,"tool":0,"blast_resistance":6.0,"light":14,"family":"copper_decor","copper_stage":0,"copper_family":"lantern_ceiling"},
	11538:{"name":"Copper chain","block":true,"shape":"chain","color":"c77a52","hardness":5.0,"tool":0,"blast_resistance":6.0,"family":"copper_decor","copper_stage":0,"copper_family":"chain"},
	11542:{"name":"Copper bars","block":true,"shape":"pane","color":"c77a52","hardness":5.0,"tool":0,"blast_resistance":6.0,"family":"copper_decor","copper_stage":0,"copper_family":"bars"},
	11531:{"name":"Exposed copper lantern","block":true,"shape":"lantern","color":"c08a6a","hardness":3.0,"tool":0,"blast_resistance":6.0,"light":14,"family":"copper_decor","copper_stage":1,"copper_family":"lantern","hidden":true},
	11535:{"name":"Exposed copper lantern","block":true,"shape":"lantern","color":"c08a6a","hardness":3.0,"tool":0,"blast_resistance":6.0,"light":14,"family":"copper_decor","copper_stage":1,"copper_family":"lantern_ceiling","hidden":true},
	11539:{"name":"Exposed copper chain","block":true,"shape":"chain","color":"c08a6a","hardness":5.0,"tool":0,"blast_resistance":6.0,"family":"copper_decor","copper_stage":1,"copper_family":"chain","hidden":true},
	11543:{"name":"Exposed copper bars","block":true,"shape":"pane","color":"c08a6a","hardness":5.0,"tool":0,"blast_resistance":6.0,"family":"copper_decor","copper_stage":1,"copper_family":"bars","hidden":true},
	11532:{"name":"Weathered copper lantern","block":true,"shape":"lantern","color":"8ba07c","hardness":3.0,"tool":0,"blast_resistance":6.0,"light":14,"family":"copper_decor","copper_stage":2,"copper_family":"lantern","hidden":true},
	11536:{"name":"Weathered copper lantern","block":true,"shape":"lantern","color":"8ba07c","hardness":3.0,"tool":0,"blast_resistance":6.0,"light":14,"family":"copper_decor","copper_stage":2,"copper_family":"lantern_ceiling","hidden":true},
	11540:{"name":"Weathered copper chain","block":true,"shape":"chain","color":"8ba07c","hardness":5.0,"tool":0,"blast_resistance":6.0,"family":"copper_decor","copper_stage":2,"copper_family":"chain","hidden":true},
	11544:{"name":"Weathered copper bars","block":true,"shape":"pane","color":"8ba07c","hardness":5.0,"tool":0,"blast_resistance":6.0,"family":"copper_decor","copper_stage":2,"copper_family":"bars","hidden":true},
	11533:{"name":"Oxidized copper lantern","block":true,"shape":"lantern","color":"5aa88c","hardness":3.0,"tool":0,"blast_resistance":6.0,"light":14,"family":"copper_decor","copper_stage":3,"copper_family":"lantern","hidden":true},
	11537:{"name":"Oxidized copper lantern","block":true,"shape":"lantern","color":"5aa88c","hardness":3.0,"tool":0,"blast_resistance":6.0,"light":14,"family":"copper_decor","copper_stage":3,"copper_family":"lantern_ceiling","hidden":true},
	11541:{"name":"Oxidized copper chain","block":true,"shape":"chain","color":"5aa88c","hardness":5.0,"tool":0,"blast_resistance":6.0,"family":"copper_decor","copper_stage":3,"copper_family":"chain","hidden":true},
	11545:{"name":"Oxidized copper bars","block":true,"shape":"pane","color":"5aa88c","hardness":5.0,"tool":0,"blast_resistance":6.0,"family":"copper_decor","copper_stage":3,"copper_family":"bars","hidden":true},
}

static func is_decor(id: int) -> bool: return id >= LANTERN_FLOOR and id <= BARS+STAGES-1
static func stage(id: int) -> int: return int(DATA[id].get("copper_stage",-1)) if is_decor(id) else -1
# A readable alias, so a caller need not know the DATA key.
static func chain_stage(id: int) -> int: return stage(id)
static func copper_family(id: int) -> String: return str(DATA.get(id,{}).get("copper_family",""))
static func is_lantern(id: int) -> bool: return copper_family(id) == "lantern" or copper_family(id) == "lantern_ceiling"
static func is_chain(id: int) -> bool: return copper_family(id) == "chain"
static func is_bars(id: int) -> bool: return copper_family(id) == "bars"
static func light_level(id: int) -> int: return 14 if is_lantern(id) else 0

# The stage chain a node belongs to, in source order. `Copper` iterates `CHAINS`, so
# registering these four arrays is all the oxidation needs.
static func chains() -> Array:
	return [LANTERN_FLOOR_STAGES,LANTERN_CEILING_STAGES,CHAIN_STAGES,BAR_STAGES]

# The next stage of the same family, or 0 at the end of the chain.
static func oxidized(id: int) -> int:
	var s: int = stage(id)
	if s < 0 or s+1 >= STAGES: return 0
	var family: String = copper_family(id)
	for candidate in range(LANTERN_FLOOR,BARS+STAGES):
		if copper_family(candidate) == family and stage(candidate) == s+1: return candidate
	return 0

# A copper lantern is placed on a floor or hangs from a ceiling, which the source
# keeps as two nodes. Given the aimed face, this is the node to place.
static func oriented(id: int, normal: Vector3i, rotation_y: float = 0.0) -> int:
	if not is_lantern(id): return id
	return LANTERN_CEILING_STAGES[stage(id)] if normal.y < 0 else LANTERN_FLOOR_STAGES[stage(id)]

# --- recipes -----------------------------------------------------------------

static func recipes(inv: Inventory) -> void:
	# Source `mcl_copper/crafting.lua`: a chain of nugget-ingot-nugget, four lanterns
	# from nuggets around the plain chain, and bars from six copper ingots.
	# A chain is nugget-ingot-nugget, which is the source's own recipe shape.
	inv._recipe("Copper chain",CHAIN_STAGES[0],4,[RawOres.COPPER_NUGGET,Nodes.COPPER,RawOres.COPPER_NUGGET],1)
	inv._recipe("Copper lantern",LANTERN_FLOOR_STAGES[0],1,
		[Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,CHAIN_STAGES[0],Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET,Nodes.IRON_NUGGET],3,"table")
	inv._recipe("Copper bars",BAR_STAGES[0],16,[Nodes.COPPER,Nodes.COPPER,Nodes.COPPER,Nodes.COPPER,Nodes.COPPER,Nodes.COPPER],3,"table")

# --- art ---------------------------------------------------------------------

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(DATA[id].color)
	if is_bars(id):
		# Thin bright rails against transparency, like the iron bars' own tile.
		if x in [2,7,12] or y in [0,15]: return base.lightened(0.15)
		return Color(0,0,0,0)
	if is_chain(id):
		# A narrow link column down the middle.
		var link: bool = x in range(6,10) and (y%4 < 3)
		return base.lightened(0.1) if link else Color(0,0,0,0)
	# A lantern: a metal cage around a bright core.
	if x in [0,15] or y in [0,15]: return base.darkened(0.3)
	if x in range(5,11) and y in range(4,12): return Color("ffe6a8")
	if x in range(3,13) and y in range(2,14): return base
	return Color(0,0,0,0)

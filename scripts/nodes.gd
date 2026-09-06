class_name Nodes
extends RefCounted

# Voxels are nodes; a map block holds 16 x 16 x 16 nodes.
const AIR = 0
const GRASS = 1
const DIRT = 2
const STONE = 3
const SAND = 4
const WATER = 5
const LOG = 6
const LEAVES = 7
const PLANKS = 8
const COBBLE = 9
const COAL_ORE = 10
const IRON_ORE = 11
const DIAMOND_ORE = 12
const SNOW = 13
const CACTUS = 14
const WORKBENCH = 15
const FURNACE = 16
const CHEST = 17
const TORCH = 18
const GLASS = 19
const BRICKS = 20
const FARMLAND = 21
const WHEAT = 22
const SAPLING = 23
const BED = 24
const OBSIDIAN = 25
const GRAVEL = 26
const FLOWER = 27
const BEDROCK = 28
const RIPE_WHEAT = 29
const GOLD_ORE = 34
const COPPER_ORE = 35
const GOLD_NODE = 36
const COPPER_NODE = 37
const IRON_NODE = 38
const DIAMOND_NODE = 39
const TNT = 40
const GOLD = 76
const COPPER = 77
const LEATHER = 78
const BONE = 79
const STICK = 64
const COAL = 65
const IRON = 66
const DIAMOND = 67
const APPLE = 68
const RAW_MEAT = 69
const COOKED_MEAT = 70
const GRAIN = 71
const SEEDS = 72
const BREAD = 73
const LEGACY_ARMOR = 74
const WOOL = 75
const TOOLS = 80
const TOOLS_END = 100
const ARMOR_BASE = 100
const ARMOR_END = 116
const ARMOR = 105 # Iron chestplate; older saves stored it as id 74.
const ROTTEN_FLESH = 116
const GUNPOWDER = 117
const STRING = 118
const BONE_MEAL = 119
# Mineclonia-style expansion nodes. Node ids stay below 64 (placeable range);
# items live at 120+ next to the mod item space.
const SANDSTONE = 30
const SANDSTONE_BRICK = 31
const ICE = 32
const SNOW_BLOCK = 33
const LADDER = 42
const BUCKET = 120
const WATER_BUCKET = 121
const MILK_BUCKET = 122
const SHEARS = 123
const SADDLE = 124
const PAPER = 125
const BOOK = 126
const BOOKSHELF = 43
const BRICK_ITEM = 127
const CLAY = 44
const CLAY_BALL = 128
const SNOWBALL = 129
const SNOW_GOLEM_SCARECROW = 45 # carved pumpkin block (jack-o-lantern base)
const PUMPKIN = 46
const MELON = 47
const SUGAR = 130
const PUMPKIN_PIE = 131
const MELON_SLICE = 132
const GOLDEN_APPLE = 133
const BOW = 134
const ARROW_ITEM = 135
const FEATHER = 136
const FLINT = 137
const FLINT_AND_STEEL = 138
const COMPASS = 139
const CLOCK = 140
const IRON_BLOCK = 48
const GOLD_BLOCK = 49
const DIAMOND_BLOCK = 50
const GLOWSTONE = 51
# A bed is two half-height nodes: foot + head, always adjacent on one axis.
const BED_FOOT = 54
const BED_HEAD = 55
# Keep new inventory items above the byte-sized node/mod ranges. Existing save
# ids and the six reserved mod atlas tiles remain unchanged.
const VINE = 41
const RED_BRICKS = 52
const HAY_BALE = 53
const SUGAR_CANE = 56
const RED_MUSHROOM = 57
const BROWN_MUSHROOM = 58
const MOSSY_COBBLE = 59
const MOSSY_BRICKS = 60
const COAL_BLOCK = 61
const TERRACOTTA = 62
const CHARCOAL = 256
const BOWL = 257
const MUSHROOM_STEW = 258
const GOLD_NUGGET = 259
const IRON_NUGGET = 260
const EGG = 261
# The old single-node bed id, migrated on load and in recipes.
const LEGACY_BED = 24
# Mods register new nodes at 200+ (atlas tiles 58..63 cap the count at 6) and
# new items at 120+. Registration happens at startup, so ids stay stable in saves.
const MOD_NODE_BASE = 200
const MOD_ITEM_BASE = 140
const MAX_CUSTOM_NODES = 6
const MAX_CUSTOM_ITEMS = 40
static var custom_nodes := {}
static var custom_tiles := {}
static var custom_items := {}
const NAMES = {
	0:"Air", 1:"Grass", 2:"Dirt", 3:"Stone", 4:"Sand", 5:"Water", 6:"Oak log", 7:"Oak leaves", 8:"Oak planks", 9:"Cobblestone",
	10:"Coal ore", 11:"Iron ore", 12:"Diamond ore", 13:"Snow", 14:"Cactus", 15:"Crafting table", 16:"Furnace", 17:"Chest", 18:"Torch",
	19:"Glass", 20:"Stone bricks", 21:"Farmland", 22:"Wheat seedling", 23:"Oak sapling", 24:"Bed", 25:"Obsidian", 26:"Gravel", 27:"Wildflower", 28:"Bedrock", 29:"Ripe wheat",
	30:"Sandstone", 31:"Sandstone bricks", 32:"Ice", 33:"Snow block", 42:"Ladder", 43:"Bookshelf", 44:"Clay", 45:"Carved pumpkin", 46:"Pumpkin", 47:"Melon",
	34:"Gold ore", 35:"Copper ore", 36:"Gold node", 37:"Copper node", 38:"Iron node", 39:"Diamond node", 40:"TNT", 76:"Gold ingot", 77:"Copper ingot", 78:"Leather", 79:"Bone",
	64:"Stick", 65:"Coal", 66:"Iron ingot", 67:"Diamond", 68:"Apple", 69:"Raw meat", 70:"Cooked meat", 71:"Wheat", 72:"Wheat seeds", 73:"Bread", 75:"Wool",
	116:"Rotten flesh", 117:"Gunpowder", 118:"String", 119:"Bone meal",
	120:"Bucket", 121:"Water bucket", 122:"Milk bucket", 123:"Shears", 124:"Saddle", 125:"Paper", 126:"Book", 127:"Brick", 128:"Clay ball", 129:"Snowball",
	130:"Sugar", 131:"Pumpkin pie", 132:"Melon slice", 133:"Golden apple",
	134:"Bow", 135:"Arrow", 136:"Feather", 137:"Flint", 138:"Flint and steel", 139:"Compass", 140:"Clock",
	48:"Block of iron", 49:"Block of gold", 50:"Block of diamond", 51:"Glowstone",
	54:"Bed (foot)", 55:"Bed (head)",
	41:"Vines", 52:"Red bricks", 53:"Hay bale", 56:"Sugar cane", 57:"Red mushroom", 58:"Brown mushroom",
	59:"Mossy cobblestone", 60:"Mossy stone bricks", 61:"Block of coal", 62:"Terracotta",
	256:"Charcoal", 257:"Bowl", 258:"Mushroom stew", 259:"Gold nugget", 260:"Iron nugget", 261:"Egg"
}
const COLORS = {
	1:Color("709f40"), 2:Color("906244"), 3:Color("898b87"), 4:Color("dacc91"), 5:Color("438eac"), 6:Color("725137"), 7:Color("52863b"),
	8:Color("c39760"), 9:Color("777d7a"), 10:Color("787e7e"), 11:Color("95958c"), 12:Color("728d8c"), 13:Color("e1edf0"), 14:Color("4c8849"),
	15:Color("a3794c"), 16:Color("626d71"), 17:Color("a47d43"), 18:Color("ffca67"), 19:Color("aadbdc"), 20:Color("8f9693"), 21:Color("684831"),
	22:Color("749b35"), 23:Color("5b8e36"), 24:Color("b6543d"), 25:Color("342c48"), 26:Color("9b9991"), 27:Color("f2c765"), 28:Color("414846"), 29:Color("c6ab4c"),
	30:Color("d9cf9c"), 31:Color("cfc394"), 32:Color("a8cff0"), 33:Color("eef4f6"), 42:Color("a8834f"), 43:Color("9c7a43"), 44:Color("9aa2a8"), 45:Color("d9942f"), 46:Color("cf8a2a"), 47:Color("9dc14f"),
	34:Color("929085"),35:Color("8a928a"),36:Color("ddb44c"),37:Color("c17e58"),38:Color("b9c7c5"),39:Color("69c7c0"),40:Color("c8402f"),76:Color("ddb44c"),77:Color("c17e58"),78:Color("9a6238"),79:Color("e9e6d6"),
	64:Color("9d6a3b"), 65:Color("343b42"), 66:Color("d1d9d5"), 67:Color("57d4cb"), 68:Color("d9674a"), 69:Color("c57266"), 70:Color("986245"), 71:Color("d0af50"), 72:Color("87a942"), 73:Color("dca257"), 75:Color("e5e0ce"),
	116:Color("7f8f4e"), 117:Color("4a4d52"), 118:Color("ece9dc"), 119:Color("f1efe2"),
	120:Color("b8bdc2"), 121:Color("5d9bc0"), 122:Color("e8e4da"), 123:Color("c0c6cc"), 124:Color("a5623d"), 125:Color("efe9d8"), 126:Color("9c4a33"), 127:Color("b0654a"), 128:Color("a8b2b8"), 129:Color("f4f8fa"),
	130:Color("f2f0e6"), 131:Color("d9a545"), 132:Color("c94f5c"), 133:Color("e3b93e"),
	134:Color("8a6a45"), 135:Color("c9b98a"), 136:Color("f0efe8"), 137:Color("3a3d42"), 138:Color("b8a06a"), 139:Color("c0392b"), 140:Color("d4b24c"),
	48:Color("d1d9d5"), 49:Color("e5c44f"), 50:Color("5fd8cf"), 51:Color("e8d170"),
	54:Color("b6543d"), 55:Color("e2dacc"),
	41:Color("527c3d"), 52:Color("b46950"), 53:Color("c5a54a"), 56:Color("96b95a"), 57:Color("c44f42"), 58:Color("977254"),
	59:Color("6b7b5c"), 60:Color("7e8970"), 61:Color("343b40"), 62:Color("a66d52"),
	256:Color("484039"), 257:Color("987047"), 258:Color("b3824f"), 259:Color("edc753"), 260:Color("cbd3d1"), 261:Color("eee2c5")
}
const KIND_NAMES = ["pickaxe", "axe", "shovel", "sword", "hoe", "shears"]
const TIER_NAMES = ["Wooden", "Stone", "Iron", "Diamond"]
const DURABILITY = [60, 132, 251, 1562]
const SHEARS_ID = SHEARS # 123; outside the TOOLS id range but behaves as kind 5
const ARMOR_MATERIALS = ["Leather", "Iron", "Golden", "Diamond"]
const ARMOR_PIECES = ["helmet", "chestplate", "leggings", "boots"]
const ARMOR_INGREDIENT = [LEATHER, IRON, GOLD, DIAMOND]
const ARMOR_COLORS = [Color("9a6238"), Color("d6dedb"), Color("e8c34a"), Color("5fd8cf")]
# Defence points per piece, in helmet / chestplate / leggings / boots order. Each point absorbs 4% of damage.
const ARMOR_POINTS = [[1, 3, 2, 1], [2, 6, 5, 2], [2, 5, 3, 1], [3, 8, 6, 3]]
const ARMOR_DURABILITY = [80, 240, 112, 528]

static func title(id: int) -> String:
	if custom_items.has(id) or custom_nodes.has(id):
		return String((custom_items.get(id) if custom_items.has(id) else custom_nodes[id]).get("name","Unknown"))
	if id == SHEARS: return "Shears"
	if is_tool_id(id): return TIER_NAMES[tool_tier(id)] + " " + KIND_NAMES[tool_kind(id)]
	if is_armor(id): return ARMOR_MATERIALS[armor_material(id)] + " " + ARMOR_PIECES[armor_piece(id)]
	return NAMES.get(id, "Unknown")

static func color(id: int) -> Color:
	if custom_items.has(id) or custom_nodes.has(id):
		return Color((custom_items.get(id) if custom_items.has(id) else custom_nodes[id]).get("color","#ffffff"))
	if id == SHEARS: return Color("c0c6cc")
	if is_tool_id(id): return [Color("bd8e55"), Color("909995"), Color("cedcdd"), Color("63d5c5")][tool_tier(id)]
	if is_armor(id): return ARMOR_COLORS[armor_material(id)]
	return COLORS.get(id, Color.WHITE)

static func exists(id: int) -> bool:
	return NAMES.has(id) or is_tool_id(id) or is_armor(id) or custom_nodes.has(id) or custom_items.has(id)

# Every item that can appear in an inventory, for the creative catalog and console.
static func all_ids() -> Array:
	var ids: Array = []
	for id in NAMES:
		if id != AIR: ids.append(id)
	ids.append_array(custom_items.keys())
	ids.append_array(custom_nodes.keys())
	ids.append_array(range(TOOLS, TOOLS_END))
	ids.append_array(range(ARMOR_BASE, ARMOR_END))
	return ids

# Saves from before the armor system stored the single chestplate as id 74;
# saves from before the two-block bed stored a single bed node as id 24.
static func migrate(id: int) -> int:
	if id == LEGACY_ARMOR: return ARMOR
	if id == LEGACY_BED: return BED_FOOT
	return id

static func lookup(query: String) -> int:
	var wanted: String = query.strip_edges().to_lower().replace("_", " ")
	if wanted.is_valid_int() and exists(int(wanted)): return int(wanted)
	for id in all_ids():
		if title(id).to_lower() == wanted: return id
	for id in all_ids():
		if wanted in title(id).to_lower(): return id
	return 0

# Registration entry points used by the modding API. Ids are assigned in order;
# registration happens once at startup, so ids are stable across saves.
static func register_node(name_text: String, properties: Dictionary) -> int:
	if custom_nodes.size() >= MAX_CUSTOM_NODES or custom_nodes.values().any(func(n): return n.name == name_text): return 0
	var id: int = MOD_NODE_BASE + custom_nodes.size()
	properties["name"] = name_text
	custom_nodes[id] = properties
	custom_tiles[id] = 58 + custom_tiles.size()
	return id

static func register_item(name_text: String, properties: Dictionary) -> int:
	if custom_items.size() >= MAX_CUSTOM_ITEMS or custom_items.values().any(func(i): return i.name == name_text): return 0
	var id: int = MOD_ITEM_BASE + custom_items.size()
	while exists(id): id += 1
	properties["name"] = name_text
	custom_items[id] = properties
	return id

static func is_tool_id(id: int) -> bool:
	return id >= TOOLS and id < TOOLS_END

static func is_armor(id: int) -> bool:
	return id >= ARMOR_BASE and id < ARMOR_END

static func tool_kind(id: int) -> int:
	return (id - TOOLS) % 5 if is_tool_id(id) else -1

static func tool_tier(id: int) -> int:
	return clampi((id - TOOLS) / 5, 0, 3) if is_tool_id(id) else -1

static func armor_material(id: int) -> int:
	return (id - ARMOR_BASE) / 4 if is_armor(id) else -1

static func armor_piece(id: int) -> int:
	return (id - ARMOR_BASE) % 4 if is_armor(id) else -1

static func armor_id(material: int, piece: int) -> int:
	return ARMOR_BASE + material * 4 + piece

static func armor_points(id: int) -> int:
	return ARMOR_POINTS[armor_material(id)][armor_piece(id)] if is_armor(id) else 0

static func durability(id: int) -> int:
	if is_tool_id(id): return DURABILITY[tool_tier(id)]
	if is_armor(id): return ARMOR_DURABILITY[armor_material(id)]
	return 0

static func max_stack(id: int) -> int:
	if id == EGG: return 16
	return 1 if is_tool_id(id) or is_armor(id) or id in [SHEARS,BUCKET,WATER_BUCKET,MILK_BUCKET,SADDLE,MUSHROOM_STEW] else 64

static func solid(id: int) -> bool:
	if custom_nodes.has(id): return not bool(custom_nodes[id].get("transparent",false))
	return id != AIR and id != WATER and not plant(id) and id not in [TORCH,LADDER]

static func plant(id: int) -> bool:
	return id in [WHEAT, RIPE_WHEAT, SAPLING, FLOWER, VINE, SUGAR_CANE, RED_MUSHROOM, BROWN_MUSHROOM]

static func transparent(id: int) -> bool:
	if custom_nodes.has(id): return bool(custom_nodes[id].get("transparent",false))
	return id in [AIR, WATER, GLASS, LADDER, ICE] or plant(id) or id == TORCH

# Sand and gravel are Luanti-style falling nodes: they drop when unsupported.
static func falls(id: int) -> bool:
	return id in [SAND, GRAVEL, SNOW_BLOCK]

static func placeable(id: int) -> bool:
	if custom_nodes.has(id) and not bool(custom_nodes[id].get("unobtainable",false)): return true
	# The legacy single-node bed is no longer obtainable; only the two-block bed is.
	if id == LEGACY_BED: return false
	return id > AIR and id < 64 and NAMES.has(id) and id not in [WATER, BEDROCK, RIPE_WHEAT]

static func preferred_tool(id: int) -> int:
	if id in [RED_BRICKS,MOSSY_COBBLE,MOSSY_BRICKS,COAL_BLOCK,TERRACOTTA]: return 0
	if id == HAY_BALE: return 4
	if id in [STONE, COBBLE, COAL_ORE, IRON_ORE, DIAMOND_ORE, FURNACE, BRICKS, OBSIDIAN, GOLD_ORE, COPPER_ORE, GOLD_NODE, COPPER_NODE, IRON_NODE, DIAMOND_NODE, SANDSTONE, SANDSTONE_BRICK, BOOKSHELF, IRON_BLOCK, GOLD_BLOCK, DIAMOND_BLOCK, GLOWSTONE]: return 0
	if id in [LOG, PLANKS, WORKBENCH, CHEST, BED, BED_FOOT, BED_HEAD, LADDER, PUMPKIN, MELON]: return 1
	if id in [DIRT, GRASS, SAND, SNOW, GRAVEL, FARMLAND, CLAY, SNOW_BLOCK]: return 2
	return -1

static func hardness(id: int) -> float:
	if id in [RED_BRICKS,MOSSY_COBBLE,MOSSY_BRICKS,TERRACOTTA]: return 2.0
	if id == COAL_BLOCK: return 5.0
	if id == HAY_BALE: return 0.5
	if custom_nodes.has(id): return float(custom_nodes[id].get("hardness",1.0))
	if id == BEDROCK: return INF
	if id == OBSIDIAN: return 18.0
	if id in [IRON_BLOCK, DIAMOND_BLOCK]: return 5.0
	if id == GOLD_BLOCK: return 3.0
	if id == GLOWSTONE: return 0.4
	if id in [STONE, COBBLE, FURNACE, BRICKS, SANDSTONE_BRICK, BOOKSHELF]: return 3.0
	if id in [COAL_ORE, IRON_ORE, DIAMOND_ORE, GOLD_ORE, COPPER_ORE]: return 4.5
	if id in [GOLD_NODE, COPPER_NODE, IRON_NODE, DIAMOND_NODE]: return 5.0
	if id in [LOG, WORKBENCH, CHEST]: return 2.1
	if id in [BED_FOOT, BED_HEAD]: return 0.8
	if id == SANDSTONE: return 1.6
	if id == PLANKS or id == LADDER: return 1.5
	if id in [LEAVES, TORCH, TNT] or plant(id): return 0.22
	if id == PUMPKIN: return 1.0
	if id == MELON: return 0.9
	if id == CLAY: return 0.75
	if id in [SNOW_BLOCK, ICE]: return 0.5
	return 0.7

static func break_time(id: int, tool: int) -> float:
	if id in [LEAVES,TORCH,TNT] or plant(id) or id == SNOW_BLOCK:
		if tool == SHEARS or (is_tool_id(tool) and tool_kind(tool) == 5):
			return hardness(id)/5.0 if id != SNOW_BLOCK else 0.05
	var speed: float = [2.0, 4.0, 6.0, 9.0][tool_tier(tool)] if is_tool_id(tool) and tool_kind(tool) == preferred_tool(id) else 1.0
	return hardness(id) / speed

static func harvestable(id: int, tool: int) -> bool:
	if id == BEDROCK: return false
	if id == VINE: return tool == SHEARS
	if preferred_tool(id) == 0:
		if tool_kind(tool) != 0 and tool != SHEARS: return false
		if tool == SHEARS and id not in [BOOKSHELF]: return id in [BOOKSHELF]
		if id in [IRON_ORE,COPPER_ORE]: return tool_tier(tool) >= 1
		if id in [DIAMOND_ORE,GOLD_ORE,GOLD_NODE,DIAMOND_NODE]: return tool_tier(tool) >= 2
		if id == OBSIDIAN: return tool_tier(tool) >= 3
	return true

static func drop(id: int) -> int:
	return {GRASS:DIRT, STONE:COBBLE, COAL_ORE:COAL, DIAMOND_ORE:DIAMOND, FARMLAND:DIRT, WHEAT:SEEDS, RIPE_WHEAT:GRAIN,
		LEAVES:SAPLING, ICE:0, CLAY:CLAY_BALL, GLOWSTONE:GLOWSTONE_DUST_ALIAS,
		PUMPKIN:PUMPKIN, MELON:MELON_SLICE, BOOKSHELF:BOOKSHELF, SNOW_BLOCK:SNOW_BALL_ALIAS,
		BED_FOOT:BED_FOOT, BED_HEAD:BED_FOOT}.get(id, id)

# Aliases so the drop table reads cleanly above.
const SNOW_BALL_ALIAS = SNOWBALL
const GLOWSTONE_DUST_ALIAS = GLOWSTONE # glowstone drops itself; kept for clarity

static func food(id: int) -> int:
	if custom_items.has(id): return clampi(int(custom_items[id].get("food",0)),0,20)
	return {APPLE:4, RAW_MEAT:2, COOKED_MEAT:8, BREAD:6, ROTTEN_FLESH:2, PUMPKIN_PIE:8, MELON_SLICE:2, GOLDEN_APPLE:10, MUSHROOM_STEW:6}.get(id, 0)

static func tile(id: int, face: int) -> int:
	if custom_tiles.has(id): return custom_tiles[id]
	if id == GRASS: return 30 if face == 2 else (2 if face == 3 else 1)
	if id == LOG and face in [2, 3]: return 31
	if id == WORKBENCH and face == 2: return 32
	if id == FURNACE and face == 5: return 33
	if id == TNT and face in [2, 3]: return 41
	if id == SANDSTONE and face == 2: return 52
	if id == SANDSTONE: return 64
	if id == SANDSTONE_BRICK: return 65
	if id == ICE: return 66
	if id == SNOW_BLOCK: return 67
	if id == VINE: return 68
	if id == RED_BRICKS: return 69
	if id == HAY_BALE: return 71 if face in [2,3] else 70
	if id in [SUGAR_CANE,RED_MUSHROOM,BROWN_MUSHROOM,MOSSY_COBBLE,MOSSY_BRICKS,COAL_BLOCK,TERRACOTTA]: return 72+id-SUGAR_CANE
	if id == PUMPKIN and face == 2: return 45
	if id == MELON and face == 2: return 53
	# Bed halves use dedicated tiles: 56 foot top, 57 head (pillow) top.
	if id == BED_FOOT: return 56
	if id == BED_HEAD: return 57
	return id

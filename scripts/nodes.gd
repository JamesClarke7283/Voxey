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
const NAMES = {
	0:"Air", 1:"Grass", 2:"Dirt", 3:"Stone", 4:"Sand", 5:"Water", 6:"Oak log", 7:"Oak leaves", 8:"Oak planks", 9:"Cobblestone",
	10:"Coal ore", 11:"Iron ore", 12:"Diamond ore", 13:"Snow", 14:"Cactus", 15:"Crafting table", 16:"Furnace", 17:"Chest", 18:"Torch",
	19:"Glass", 20:"Stone bricks", 21:"Farmland", 22:"Wheat seedling", 23:"Oak sapling", 24:"Bed", 25:"Obsidian", 26:"Gravel", 27:"Wildflower", 28:"Bedrock", 29:"Ripe wheat", 34:"Gold ore", 35:"Copper ore", 36:"Gold node", 37:"Copper node", 38:"Iron node", 39:"Diamond node", 40:"TNT", 76:"Gold ingot", 77:"Copper ingot", 78:"Leather", 79:"Bone",
	64:"Stick", 65:"Coal", 66:"Iron ingot", 67:"Diamond", 68:"Apple", 69:"Raw meat", 70:"Cooked meat", 71:"Wheat", 72:"Wheat seeds", 73:"Bread", 75:"Wool",
	116:"Rotten flesh", 117:"Gunpowder", 118:"String", 119:"Bone meal"
}
const COLORS = {
	1:Color("709f40"), 2:Color("906244"), 3:Color("898b87"), 4:Color("dacc91"), 5:Color("438eac"), 6:Color("725137"), 7:Color("52863b"),
	8:Color("c39760"), 9:Color("777d7a"), 10:Color("787e7e"), 11:Color("95958c"), 12:Color("728d8c"), 13:Color("e1edf0"), 14:Color("4c8849"),
	15:Color("a3794c"), 16:Color("626d71"), 17:Color("a47d43"), 18:Color("ffca67"), 19:Color("aadbdc"), 20:Color("8f9693"), 21:Color("684831"),
	22:Color("749b35"), 23:Color("5b8e36"), 24:Color("b6543d"), 25:Color("342c48"), 26:Color("9b9991"), 27:Color("f2c765"), 28:Color("414846"), 29:Color("c6ab4c"),
	34:Color("929085"),35:Color("8a928a"),36:Color("ddb44c"),37:Color("c17e58"),38:Color("b9c7c5"),39:Color("69c7c0"),40:Color("c8402f"),76:Color("ddb44c"),77:Color("c17e58"),78:Color("9a6238"),79:Color("e9e6d6"),
	64:Color("9d6a3b"), 65:Color("343b42"), 66:Color("d1d9d5"), 67:Color("57d4cb"), 68:Color("d9674a"), 69:Color("c57266"), 70:Color("986245"), 71:Color("d0af50"), 72:Color("87a942"), 73:Color("dca257"), 75:Color("e5e0ce"),
	116:Color("7f8f4e"), 117:Color("4a4d52"), 118:Color("ece9dc"), 119:Color("f1efe2")
}
const KIND_NAMES = ["pickaxe", "axe", "shovel", "sword", "hoe"]
const TIER_NAMES = ["Wooden", "Stone", "Iron", "Diamond"]
const DURABILITY = [60, 132, 251, 1562]
const ARMOR_MATERIALS = ["Leather", "Iron", "Golden", "Diamond"]
const ARMOR_PIECES = ["helmet", "chestplate", "leggings", "boots"]
const ARMOR_INGREDIENT = [LEATHER, IRON, GOLD, DIAMOND]
const ARMOR_COLORS = [Color("9a6238"), Color("d6dedb"), Color("e8c34a"), Color("5fd8cf")]
# Defence points per piece, in helmet / chestplate / leggings / boots order. Each point absorbs 4% of damage.
const ARMOR_POINTS = [[1, 3, 2, 1], [2, 6, 5, 2], [2, 5, 3, 1], [3, 8, 6, 3]]
const ARMOR_DURABILITY = [80, 240, 112, 528]

static func title(id: int) -> String:
	if is_tool_id(id): return TIER_NAMES[tool_tier(id)] + " " + KIND_NAMES[tool_kind(id)]
	if is_armor(id): return ARMOR_MATERIALS[armor_material(id)] + " " + ARMOR_PIECES[armor_piece(id)]
	return NAMES.get(id, "Unknown")

static func color(id: int) -> Color:
	if is_tool_id(id): return [Color("bd8e55"), Color("909995"), Color("cedcdd"), Color("63d5c5")][tool_tier(id)]
	if is_armor(id): return ARMOR_COLORS[armor_material(id)]
	return COLORS.get(id, Color.WHITE)

static func exists(id: int) -> bool:
	return NAMES.has(id) or is_tool_id(id) or is_armor(id)

# Every item that can appear in an inventory, for the creative catalog and console.
static func all_ids() -> Array:
	var ids: Array = []
	for id in NAMES:
		if id != AIR: ids.append(id)
	ids.append_array(range(TOOLS, TOOLS_END))
	ids.append_array(range(ARMOR_BASE, ARMOR_END))
	return ids

# Saves from before the armor system stored the single chestplate as id 74.
static func migrate(id: int) -> int:
	return ARMOR if id == LEGACY_ARMOR else id

static func lookup(query: String) -> int:
	var wanted: String = query.strip_edges().to_lower().replace("_", " ")
	if wanted.is_valid_int() and exists(int(wanted)): return int(wanted)
	for id in all_ids():
		if title(id).to_lower() == wanted: return id
	for id in all_ids():
		if wanted in title(id).to_lower(): return id
	return 0

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
	return 1 if is_tool_id(id) or is_armor(id) else 64

static func solid(id: int) -> bool:
	return id != AIR and id != WATER and not plant(id) and id != TORCH

static func plant(id: int) -> bool:
	return id in [WHEAT, RIPE_WHEAT, SAPLING, FLOWER]

static func transparent(id: int) -> bool:
	return id in [AIR, WATER, GLASS] or plant(id) or id == TORCH

# Sand and gravel are Luanti-style falling nodes: they drop when unsupported.
static func falls(id: int) -> bool:
	return id in [SAND, GRAVEL]

static func placeable(id: int) -> bool:
	return id > AIR and id < 64 and NAMES.has(id) and id not in [WATER, BEDROCK, RIPE_WHEAT]

static func preferred_tool(id: int) -> int:
	if id in [STONE, COBBLE, COAL_ORE, IRON_ORE, DIAMOND_ORE, FURNACE, BRICKS, OBSIDIAN, GOLD_ORE, COPPER_ORE, GOLD_NODE, COPPER_NODE, IRON_NODE, DIAMOND_NODE]: return 0
	if id in [LOG, PLANKS, WORKBENCH, CHEST, BED]: return 1
	if id in [DIRT, GRASS, SAND, SNOW, GRAVEL, FARMLAND]: return 2
	return -1

static func hardness(id: int) -> float:
	if id == BEDROCK: return INF
	if id == OBSIDIAN: return 18.0
	if id in [STONE, COBBLE, FURNACE, BRICKS]: return 3.0
	if id in [COAL_ORE, IRON_ORE, DIAMOND_ORE, GOLD_ORE, COPPER_ORE]: return 4.5
	if id in [GOLD_NODE, COPPER_NODE, IRON_NODE, DIAMOND_NODE]: return 5.0
	if id in [LOG, WORKBENCH, CHEST]: return 2.1
	if id == PLANKS: return 1.5
	if id in [LEAVES, TORCH, TNT] or plant(id): return 0.22
	return 0.7

static func break_time(id: int, tool: int) -> float:
	var speed: float = [2.0, 4.0, 6.0, 9.0][tool_tier(tool)] if is_tool_id(tool) and tool_kind(tool) == preferred_tool(id) else 1.0
	return hardness(id) / speed

static func harvestable(id: int, tool: int) -> bool:
	if id == BEDROCK: return false
	if preferred_tool(id) == 0:
		if tool_kind(tool) != 0: return false
		if id in [IRON_ORE,COPPER_ORE]: return tool_tier(tool) >= 1
		if id in [DIAMOND_ORE,GOLD_ORE,GOLD_NODE,DIAMOND_NODE]: return tool_tier(tool) >= 2
		if id == OBSIDIAN: return tool_tier(tool) >= 3
	return true

static func drop(id: int) -> int:
	return {GRASS:DIRT, STONE:COBBLE, COAL_ORE:COAL, DIAMOND_ORE:DIAMOND, FARMLAND:DIRT, WHEAT:SEEDS, RIPE_WHEAT:GRAIN}.get(id, id)

static func food(id: int) -> int:
	return {APPLE:4, RAW_MEAT:2, COOKED_MEAT:8, BREAD:6, ROTTEN_FLESH:2}.get(id, 0)

static func tile(id: int, face: int) -> int:
	if id == GRASS: return 30 if face == 2 else (2 if face == 3 else 1)
	if id == LOG and face in [2, 3]: return 31
	if id == WORKBENCH and face == 2: return 32
	if id == FURNACE and face == 5: return 33
	if id == TNT and face in [2, 3]: return 41
	return id

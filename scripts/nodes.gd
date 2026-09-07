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
const LAVA = 180
const NETHERRACK = 181
const SOUL_SAND = 182
const BASALT = 183
const NETHER_BRICKS = 184
const NETHER_QUARTZ_ORE = 185
const CRIMSON_NYLIUM = 186
const WARPED_NYLIUM = 187
const NETHER_PORTAL = 188
const ENCHANTING_TABLE = 189
const LAPIS_ORE = 190
const CRIMSON_STEM = 191
const WARPED_STEM = 192
const SHROOMLIGHT = 193
const DEEPSLATE = 194
const COBBLED_DEEPSLATE = 195
const POLISHED_DEEPSLATE = 196
const DEEPSLATE_BRICKS = 197
const DEEP_DIAMOND_ORE = 198
const DEEP_IRON_ORE = 199
const DEEP_GOLD_ORE = 206
const DEEP_LAPIS_ORE = 207
const DEEP_COAL_ORE = 208
const DEEP_COPPER_ORE = 209
const DEEP_NODES = [194,195,196,197,198,199,206,207,208,209]
const DEEP_ORES = {198:12,199:11,206:34,207:190,208:10,209:35}

# Expansion voxel ids remain byte-sized; 200..205 stay reserved for mods.
const REDSTONE_ORE = 210
const DEEP_REDSTONE_ORE = 211
const REDSTONE_WIRE = 212
const REDSTONE_TORCH = 213
const LEVER = 214
const BUTTON = 215
const PRESSURE_PLATE = 216
const REPEATER = 217
const COMPARATOR = 218
const PISTON = 219
const STICKY_PISTON = 220
const PISTON_HEAD = 221
const REDSTONE_LAMP = 222
const REDSTONE_BLOCK = 223
const OBSERVER = 224
const DISPENSER = 225
const DROPPER = 226
const HOPPER = 227
const IRON_DOOR = 228
const IRON_DOOR_OPEN = 229
const END_STONE = 230
const END_BRICKS = 231
const END_FRAME = 232
const END_FRAME_EYE = 233
const END_PORTAL = 234
const IRON_BARS = 235
const PURPUR = 236
const CHORUS_PLANT = 237
const END_ROD = 238
const DRAGON_EGG = 239
const BLAZE_SPAWNER = 240
const SOUL_TORCH = 241
const END_GATEWAY = 242
const ELYTRA = 277
const SHULKER_SHELL = 278
const ENDER_PEARL = 267
const ENDER_EYE = 268
const BLAZE_ROD = 269
const BLAZE_POWDER = 270
const GHAST_TEAR = 271
const END_CRYSTAL = 272
const SLIME_BALL = 273
const CHORUS_FRUIT = 274
const MAGMA_CREAM = 275
const NETHER_BRICK_ITEM = 276
const EXPANSION_NODES = [210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242]
const CIRCUIT_NODES = [REDSTONE_WIRE,REDSTONE_TORCH,LEVER,BUTTON,PRESSURE_PLATE,REPEATER,COMPARATOR,PISTON,STICKY_PISTON,PISTON_HEAD,REDSTONE_LAMP,REDSTONE_BLOCK,OBSERVER,DISPENSER,DROPPER,HOPPER,IRON_DOOR,IRON_DOOR_OPEN]
const SMALL_CIRCUITS = [REDSTONE_WIRE,REDSTONE_TORCH,LEVER,BUTTON,PRESSURE_PLATE,REPEATER,COMPARATOR,IRON_DOOR_OPEN]
const LAPIS = 262
const WRITABLE_BOOK = 263
const WRITTEN_BOOK = 264
const QUARTZ = 265
const LAVA_BUCKET = 266
const NETHER_NODES = [180,181,182,183,184,185,186,187,188,189,190,191,192,193]
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
	242:"End gateway",
	277:"Elytra",278:"Shulker shell",
	210:"Redstone ore",
	211:"Deepslate redstone ore",
	212:"Redstone dust",
	213:"Redstone torch",
	214:"Lever",
	215:"Stone button",
	216:"Stone pressure plate",
	217:"Redstone repeater",
	218:"Redstone comparator",
	219:"Piston",
	220:"Sticky piston",
	221:"Piston head",
	222:"Redstone lamp",
	223:"Block of redstone",
	224:"Observer",
	225:"Dispenser",
	226:"Dropper",
	227:"Hopper",
	228:"Iron door",
	229:"Open iron door",
	230:"End stone",
	231:"End stone bricks",
	232:"End portal frame",
	233:"Filled End portal frame",
	234:"End portal",
	235:"Iron bars",
	236:"Purpur block",
	237:"Chorus plant",
	238:"End rod",
	239:"Dragon egg",
	240:"Blaze spawner",
	241:"Soul torch",
	267:"Ender pearl",
	268:"Eye of Ender",
	269:"Blaze rod",
	270:"Blaze powder",
	271:"Ghast tear",
	272:"End crystal",
	273:"Slime ball",
	274:"Chorus fruit",
	275:"Magma cream",
	276:"Nether brick",

	194:"Deepslate",
	195:"Cobbled deepslate",
	196:"Polished deepslate",
	197:"Deepslate bricks",
	198:"Deepslate diamond ore",
	199:"Deepslate iron ore",
	206:"Deepslate gold ore",
	207:"Deepslate lapis ore",
	208:"Deepslate coal ore",
	209:"Deepslate copper ore",

	180:"Lava",
	181:"Netherrack",
	182:"Soul sand",
	183:"Basalt",
	184:"Nether bricks",
	185:"Nether quartz ore",
	186:"Crimson nylium",
	187:"Warped nylium",
	188:"Nether portal",
	189:"Enchanting table",
	190:"Lapis lazuli ore",
	191:"Crimson stem",
	192:"Warped stem",
	193:"Shroomlight",
	262:"Lapis lazuli",
	263:"Writable book",
	264:"Written book",
	265:"Nether quartz",
	266:"Lava bucket",

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
	242:Color("51487c"),
	277:Color("92909f"),278:Color("a77aab"),
	210:Color("857274"),
	211:Color("654853"),
	212:Color("a82126"),
	213:Color("e43b32"),
	214:Color("a48e72"),
	215:Color("7d8589"),
	216:Color("84888b"),
	217:Color("d2bcaf"),
	218:Color("cdb9ab"),
	219:Color("ac8b59"),
	220:Color("80ac58"),
	221:Color("ac8b59"),
	222:Color("94613b"),
	223:Color("ba292e"),
	224:Color("777d85"),
	225:Color("81858a"),
	226:Color("7c8589"),
	227:Color("454b53"),
	228:Color("b4bfc4"),
	229:Color("b4bfc4"),
	230:Color("ddd9a0"),
	231:Color("d4cea0"),
	232:Color("628774"),
	233:Color("509988"),
	234:Color("191327"),
	235:Color("929c9f"),
	236:Color("ab7ead"),
	237:Color("815781"),
	238:Color("f2e1bc"),
	239:Color("32253f"),
	240:Color("472d26"),
	241:Color("44e1d8"),
	267:Color("247e79"),
	268:Color("68b573"),
	269:Color("e7ad36"),
	270:Color("f8bd3b"),
	271:Color("c5e8e3"),
	272:Color("e09be2"),
	273:Color("86bb59"),
	274:Color("a36ea3"),
	275:Color("dd842c"),
	276:Color("613c42"),

	194:Color("4b4d53"),
	195:Color("505359"),
	196:Color("54575e"),
	197:Color("454851"),
	198:Color("53979a"),
	199:Color("9b8981"),
	206:Color("ac954e"),
	207:Color("375db4"),
	208:Color("30353a"),
	209:Color("9d7864"),

	180:Color("ed651b"),
	181:Color("813d3a"),
	182:Color("655044"),
	183:Color("48474e"),
	184:Color("402b34"),
	185:Color("a47569"),
	186:Color("a33e4e"),
	187:Color("328d82"),
	188:Color("9a4bd1"),
	189:Color("662e43"),
	190:Color("537cac"),
	191:Color("713b50"),
	192:Color("337369"),
	193:Color("efa25e"),
	262:Color("285fc3"),
	263:Color("9c643d"),
	264:Color("7948a6"),
	265:Color("eee3dd"),
	266:Color("f17b2c"),

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
# Defense points per piece; damage also depends on hit strength and toughness.
const ARMOR_POINTS = [[1, 3, 2, 1], [2, 6, 5, 2], [2, 5, 3, 1], [3, 8, 6, 3]]
const ARMOR_DURABILITY = [80, 240, 112, 528]

static func title(id: int) -> String:
	if Fluids.flowing(id): return "Flowing water" if Fluids.water(id) else "Flowing lava"
	if BuildingShapes.is_shape(id): return BuildingShapes.title(id)
	if id == WOOL: return "White wool"
	if VillageContent.DATA.has(id): return VillageContent.DATA[id].name
	if id == ELYTRA: return "Elytra"
	if custom_items.has(id) or custom_nodes.has(id):
		return String((custom_items.get(id) if custom_items.has(id) else custom_nodes[id]).get("name","Unknown"))
	if id == SHEARS: return "Shears"
	if is_tool_id(id): return TIER_NAMES[tool_tier(id)] + " " + KIND_NAMES[tool_kind(id)]
	if is_armor(id): return ARMOR_MATERIALS[armor_material(id)] + " " + ARMOR_PIECES[armor_piece(id)]
	return NAMES.get(id, "Unknown")

static func color(id: int) -> Color:
	if Fluids.flowing(id): return color(Fluids.base(id))
	if BuildingShapes.is_shape(id): return color(BuildingShapes.material(id))
	if VillageContent.DATA.has(id): return Color(VillageContent.DATA[id].color)
	if id == ELYTRA: return COLORS[ELYTRA]
	if custom_items.has(id) or custom_nodes.has(id):
		return Color((custom_items.get(id) if custom_items.has(id) else custom_nodes[id]).get("color","#ffffff"))
	if id == SHEARS: return Color("c0c6cc")
	if is_tool_id(id): return [Color("bd8e55"), Color("909995"), Color("cedcdd"), Color("63d5c5")][tool_tier(id)]
	if is_armor(id): return ARMOR_COLORS[armor_material(id)]
	return COLORS.get(id, Color.WHITE)

static func exists(id: int) -> bool:
	if Fluids.flowing(id): return true
	if BuildingShapes.is_shape(id): return true
	return VillageContent.DATA.has(id) or NAMES.has(id) or is_tool_id(id) or is_armor(id) or custom_nodes.has(id) or custom_items.has(id)

# Every item that can appear in an inventory, for the creative catalog and console.
static func all_ids() -> Array:
	var ids: Array = []
	for id in NAMES:
		if id != AIR: ids.append(id)
	for id in VillageContent.DATA:
		if not VillageContent.DATA[id].get("hidden",false): ids.append(id)
	ids.erase(VillageContent.WOOL_WHITE)
	ids.append_array(BuildingShapes.items())
	ids.append_array(custom_items.keys())
	ids.append_array(custom_nodes.keys())
	ids.append_array(range(TOOLS, TOOLS_END))
	ids.append_array(range(ARMOR_BASE, ARMOR_END))
	return ids

# Saves from before the armor system stored the single chestplate as id 74;
# saves from before the two-block bed stored a single bed node as id 24.
static func migrate(id: int) -> int:
	if id == VillageContent.WOOL_WHITE: return WOOL
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
	return VillageContent.DATA.get(id,{}).has("tool_kind") or id >= TOOLS and id < TOOLS_END

static func is_armor(id: int) -> bool:
	return VillageContent.DATA.get(id,{}).has("armor") or id == ELYTRA or id >= ARMOR_BASE and id < ARMOR_END

static func tool_kind(id: int) -> int:
	return int(VillageContent.DATA[id].tool_kind) if VillageContent.DATA.get(id,{}).has("tool_kind") else ((id - TOOLS) % 5 if is_tool_id(id) else -1)

static func tool_tier(id: int) -> int:
	return int(VillageContent.DATA[id].tier) if VillageContent.DATA.get(id,{}).has("tier") else (clampi((id - TOOLS) / 5, 0, 3) if is_tool_id(id) else -1)

static func armor_material(id: int) -> int:
	if VillageContent.DATA.get(id,{}).has("armor"): return VillageContent.DATA[id].get("armor_material",1)
	return 0 if id == ELYTRA else (id - ARMOR_BASE) / 4 if is_armor(id) else -1

static func armor_piece(id: int) -> int:
	if VillageContent.DATA.get(id,{}).has("armor"): return ["helmet","chestplate","leggings","boots"].find(VillageContent.DATA[id].armor)
	return 1 if id == ELYTRA else (id - ARMOR_BASE) % 4 if is_armor(id) else -1

static func armor_id(material: int, piece: int) -> int:
	return Netherite.ARMOR+piece if material == 4 else ARMOR_BASE + material * 4 + piece

static func armor_toughness(id: int) -> float:
	if not is_armor(id) or id == ELYTRA: return 0
	return float(VillageContent.DATA.get(id,{}).get("toughness",2 if armor_material(id) == 3 else 0))

static func armor_points(id: int) -> int:
	if VillageContent.DATA.get(id,{}).has("armor_points"): return VillageContent.DATA[id].armor_points
	if id == VillageContent.TURTLE_HELMET: return 2
	if id in range(VillageContent.CHAIN_HELMET,VillageContent.CHAIN_HELMET+4): return [2,5,4,1][id-VillageContent.CHAIN_HELMET]
	return ARMOR_POINTS[armor_material(id)][armor_piece(id)] if is_armor(id) and id != ELYTRA else 0

static func durability(id: int) -> int:
	if VillageContent.DATA.has(id): return VillageContent.DATA[id].get("durability",0)
	if id == ELYTRA: return 433
	if id == FLINT_AND_STEEL: return 65
	if id == BOW: return 385
	if id == SHEARS: return 239
	if is_tool_id(id): return DURABILITY[tool_tier(id)]
	if is_armor(id): return floori(ARMOR_DURABILITY[armor_material(id)]*Netherite.ARMOR_FACTORS[armor_piece(id)])+1
	return 0

static func max_stack(id: int) -> int:
	if VillageContent.DATA.has(id): return VillageContent.DATA[id].get("stack",1 if VillageContent.DATA[id].has("armor") else 64)
	if id in [WRITABLE_BOOK,WRITTEN_BOOK,BOW,LAVA_BUCKET]: return 1
	if id in [EGG,ENDER_PEARL]: return 16
	return 1 if is_tool_id(id) or is_armor(id) or id in [SHEARS,BUCKET,WATER_BUCKET,MILK_BUCKET,SADDLE,MUSHROOM_STEW] else 64

static func solid(id: int) -> bool:
	if Fluids.flowing(id): return false
	if BuildingShapes.is_shape(id): return true
	if Torches.is_torch(id): return false
	if VillageContent.DATA.has(id): return VillageContent.DATA[id].get("block",false) and VillageContent.shape(id) not in ["crop","plant","door_open","carpet","banner","frame","painting","candle","lantern","brewing"]
	if custom_nodes.has(id): return not bool(custom_nodes[id].get("transparent",false))
	return id not in [AIR,WATER,LAVA,NETHER_PORTAL,END_PORTAL,END_GATEWAY,END_ROD,SOUL_TORCH] and id not in SMALL_CIRCUITS and not plant(id) and id not in [TORCH,LADDER]

static func plant(id: int) -> bool:
	return VillageContent.shape(id) in ["crop","plant"] or id in [WHEAT, RIPE_WHEAT, SAPLING, FLOWER, VINE, SUGAR_CANE, RED_MUSHROOM, BROWN_MUSHROOM]

static func transparent(id: int) -> bool:
	if Fluids.flowing(id): return true
	if BuildingShapes.is_shape(id): return BuildingShapes.variant(id) != 2
	if VillageContent.DATA.has(id): return VillageContent.shape(id) != "cube"
	if custom_nodes.has(id): return bool(custom_nodes[id].get("transparent",false))
	return id in CIRCUIT_NODES or id in [AIR, WATER, LAVA, NETHER_PORTAL, END_PORTAL, END_GATEWAY, END_ROD, SOUL_TORCH, IRON_BARS, GLASS, LADDER, ICE] or plant(id) or id == TORCH

# Sand and gravel are Luanti-style falling nodes: they drop when unsupported.
static func falls(id: int) -> bool:
	return id in [SAND, GRAVEL, SNOW_BLOCK]

static func placeable(id: int) -> bool:
	if Fluids.flowing(id): return false
	if BuildingShapes.is_shape(id): return id == BuildingShapes.item(id)
	if id in Torches.WALLS: return false
	if id == WOOL: return true
	if VillageContent.DATA.has(id): return VillageContent.DATA[id].get("block",false) and VillageContent.shape(id) not in ["crop","bed_head","door_open"]
	if id in EXPANSION_NODES: return id not in [PISTON_HEAD,IRON_DOOR_OPEN,END_FRAME_EYE,END_PORTAL,END_GATEWAY,BLAZE_SPAWNER]
	if id in DEEP_NODES: return true
	if id in NETHER_NODES: return id not in [LAVA,NETHER_PORTAL]
	if custom_nodes.has(id) and not bool(custom_nodes[id].get("unobtainable",false)): return true
	# The legacy single-node bed is no longer obtainable; only the two-block bed is.
	if id == LEGACY_BED: return false
	return id > AIR and id < 64 and NAMES.has(id) and id not in [WATER, BEDROCK, RIPE_WHEAT]

static func preferred_tool(id: int) -> int:
	if BuildingShapes.is_shape(id): return preferred_tool(BuildingShapes.material(id))
	if VillageContent.DATA.has(id): return VillageContent.DATA[id].get("tool",-1 if VillageContent.shape(id) == "crop" or VillageContent.DATA[id].get("family","") in ["wool","carpet","banner","bed","bed_head"] else 0)
	if id in SMALL_CIRCUITS: return -1
	if id in EXPANSION_NODES: return 0
	if id in DEEP_NODES: return 0
	if id in [CRIMSON_STEM,WARPED_STEM,BOOKSHELF]: return 1
	if id == SOUL_SAND: return 2
	if id in NETHER_NODES: return 0
	if id in [RED_BRICKS,MOSSY_COBBLE,MOSSY_BRICKS,COAL_BLOCK,TERRACOTTA]: return 0
	if id == HAY_BALE: return 4
	if id in [STONE, COBBLE, COAL_ORE, IRON_ORE, DIAMOND_ORE, FURNACE, BRICKS, OBSIDIAN, GOLD_ORE, COPPER_ORE, GOLD_NODE, COPPER_NODE, IRON_NODE, DIAMOND_NODE, SANDSTONE, SANDSTONE_BRICK, BOOKSHELF, IRON_BLOCK, GOLD_BLOCK, DIAMOND_BLOCK, GLOWSTONE]: return 0
	if id in [LOG, PLANKS, WORKBENCH, CHEST, BED, BED_FOOT, BED_HEAD, LADDER, PUMPKIN, MELON]: return 1
	if id in [DIRT, GRASS, SAND, SNOW, GRAVEL, FARMLAND, CLAY, SNOW_BLOCK]: return 2
	return -1

static func hardness(id: int) -> float:
	if Fluids.flowing(id): return INF
	if BuildingShapes.is_shape(id): return hardness(BuildingShapes.material(id))
	if VillageContent.DATA.has(id): return VillageContent.DATA[id].get("hardness",0.2 if VillageContent.shape(id) == "crop" else 1.5)
	if id in [END_FRAME,END_FRAME_EYE,END_PORTAL,END_GATEWAY]: return INF
	if id in SMALL_CIRCUITS: return 0.2
	if id in EXPANSION_NODES: return 3.0
	if id in DEEP_NODES: return 4.5 if DEEP_ORES.has(id) else 3.5
	if id in [RED_BRICKS,MOSSY_COBBLE,MOSSY_BRICKS,TERRACOTTA]: return 2.0
	if id == COAL_BLOCK: return 5.0
	if id == HAY_BALE: return 0.5
	if custom_nodes.has(id): return float(custom_nodes[id].get("hardness",1.0))
	if id in [BEDROCK,LAVA,NETHER_PORTAL]: return INF
	if id == NETHERRACK: return 0.4
	if id == ENCHANTING_TABLE: return 5.0
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
	var speed: float = VillageContent.DATA.get(tool,{}).get("speed",[2.0,4.0,6.0,9.0][clampi(tool_tier(tool),0,3)]) if is_tool_id(tool) and tool_kind(tool) == preferred_tool(id) else 1.0
	return hardness(id) / speed

static func harvestable(id: int, tool: int) -> bool:
	if Fluids.flowing(id): return false
	if BuildingShapes.is_shape(id): return harvestable(BuildingShapes.material(id),tool)
	if id in [Netherite.ANCIENT_DEBRIS,Netherite.BLOCK,Bastions.CRYING_OBSIDIAN]: return tool_kind(tool) == 0 and tool_tier(tool) >= 3
	if id in [VillageContent.EMERALD_ORE,VillageContent.DEEP_EMERALD_ORE]: return tool_kind(tool) == 0 and tool_tier(tool) >= 2
	if DEEP_ORES.has(id): return harvestable(DEEP_ORES[id],tool)
	if id in [BEDROCK,END_FRAME,END_FRAME_EYE,END_PORTAL,END_GATEWAY,PISTON_HEAD]: return false
	if id in [REDSTONE_ORE,DEEP_REDSTONE_ORE]: return tool_kind(tool) == 0 and tool_tier(tool) >= 2
	if id == VINE: return tool == SHEARS
	if preferred_tool(id) == 0:
		if tool_kind(tool) != 0 and tool != SHEARS: return false
		if tool == SHEARS and id not in [BOOKSHELF]: return id in [BOOKSHELF]
		if id in [IRON_ORE,COPPER_ORE,LAPIS_ORE]: return tool_tier(tool) >= 1
		if id in [DIAMOND_ORE,GOLD_ORE,GOLD_NODE,DIAMOND_NODE]: return tool_tier(tool) >= 2
		if id == OBSIDIAN: return tool_tier(tool) >= 3
	return true

static func drop(id: int) -> int:
	if Fluids.flowing(id): return 0
	if BuildingShapes.is_shape(id): return BuildingShapes.item(id)
	if Torches.is_torch(id): return TORCH
	if Fire.is_fire(id): return AIR
	if id == MinecloniaOres.NETHER_GOLD: return GOLD_NUGGET
	if id == VillageContent.SWAMP_GRASS: return DIRT
	if id == VillageContent.KELP_PLANT: return VillageContent.KELP
	if id in [VillageContent.COCOA_POD,VillageContent.RIPE_COCOA_POD]: return VillageContent.COCOA_BEANS
	if id in [VillageContent.EMERALD_ORE,VillageContent.DEEP_EMERALD_ORE]: return VillageContent.EMERALD
	if VillageContent.is_bed(id): return VillageContent.bed_foot(id)
	if id == VillageContent.WOODEN_DOOR_OPEN: return VillageContent.WOODEN_DOOR
	if VillageContent.shape(id) == "crop": return VillageContent.crop_seed(id)
	if DEEP_ORES.has(id): return drop(DEEP_ORES[id])
	if id in [REDSTONE_ORE,DEEP_REDSTONE_ORE]: return REDSTONE_WIRE
	if id in [END_PORTAL,END_GATEWAY,END_FRAME,END_FRAME_EYE,PISTON_HEAD,BLAZE_SPAWNER]: return 0
	if id == IRON_DOOR_OPEN: return IRON_DOOR
	if id == CHORUS_PLANT: return CHORUS_FRUIT
	if id == DEEPSLATE: return COBBLED_DEEPSLATE
	return {GRASS:DIRT, STONE:COBBLE, COAL_ORE:COAL, DIAMOND_ORE:DIAMOND, FARMLAND:DIRT, WHEAT:SEEDS, RIPE_WHEAT:GRAIN,
		LAPIS_ORE:LAPIS, NETHER_QUARTZ_ORE:QUARTZ, LAVA:0, NETHER_PORTAL:0, LEAVES:SAPLING, ICE:0, CLAY:CLAY_BALL, GLOWSTONE:GLOWSTONE_DUST_ALIAS,
		PUMPKIN:PUMPKIN, MELON:MELON_SLICE, BOOKSHELF:BOOKSHELF, SNOW_BLOCK:SNOW_BALL_ALIAS,
		BED_FOOT:BED_FOOT, BED_HEAD:BED_FOOT}.get(id, id)

# Aliases so the drop table reads cleanly above.
const SNOW_BALL_ALIAS = SNOWBALL
const GLOWSTONE_DUST_ALIAS = GLOWSTONE # glowstone drops itself; kept for clarity

static func food(id: int) -> int:
	if VillageContent.DATA.has(id): return VillageContent.DATA[id].get("food",0)
	if custom_items.has(id): return clampi(int(custom_items[id].get("food",0)),0,20)
	return {CHORUS_FRUIT:4,APPLE:4, RAW_MEAT:2, COOKED_MEAT:8, BREAD:6, ROTTEN_FLESH:2, PUMPKIN_PIE:8, MELON_SLICE:2, GOLDEN_APPLE:10, MUSHROOM_STEW:6}.get(id, 0)

static func tile(id: int, face: int) -> int:
	if Fluids.flowing(id): return tile(Fluids.base(id),face)
	if BuildingShapes.is_shape(id): return tile(BuildingShapes.material(id),face)
	if Torches.is_torch(id): return TORCH
	if id == WOOL: id = VillageContent.WOOL_WHITE
	if VillageContent.DATA.has(id): return 137+VillageContent.BLOCKS.find(id)
	if id in EXPANSION_NODES: return 104+EXPANSION_NODES.find(id)
	if id in DEEP_NODES: return 94+DEEP_NODES.find(id)
	if id == ENCHANTING_TABLE: return 93 if face == 2 else 88
	if id in NETHER_NODES: return 79+id-LAVA
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

static func smelt_result(id: int) -> int:
	if id == DEEPSLATE_BRICKS: return Masonry.CRACKED_DEEP_BRICKS
	if VillageContent.DATA.has(id): return VillageContent.DATA[id].get("smelt",0)
	if DEEP_ORES.has(id): id = DEEP_ORES[id]
	return {NETHERRACK:NETHER_BRICK_ITEM,IRON_ORE:IRON,GOLD_ORE:GOLD,COPPER_ORE:COPPER,SAND:GLASS,COBBLE:STONE,RAW_MEAT:COOKED_MEAT,LOG:CHARCOAL,CLAY_BALL:BRICK_ITEM,CLAY:TERRACOTTA,COBBLED_DEEPSLATE:DEEPSLATE}.get(id,0)

static func fuel_time(id: int) -> float:
	if BuildingShapes.is_shape(id): return fuel_time(BuildingShapes.material(id))*0.5 if BuildingShapes.half_slab(id) else fuel_time(BuildingShapes.material(id))
	if id == VillageContent.DRIED_KELP_BLOCK: return 200
	return {COAL:80,CHARCOAL:80,COAL_BLOCK:800,LOG:15,PLANKS:15,STICK:5,BOWL:10,LAVA_BUCKET:1000,CRIMSON_STEM:15,WARPED_STEM:15}.get(id,0)

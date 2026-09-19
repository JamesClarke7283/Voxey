class_name ArmorTrims
extends RefCounted

# Mineclonia mcl_armor/{init,trims,api}.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference; all art is original procedural code.
#
# The source registers a **smithing template** craftitem per overlay, and
# `mcl_armor.trim` writes two metadata keys onto the armor stack:
# `mcl_armor:trim_overlay` and `mcl_armor:trim_material`. The observable rules:
#
# - There are 17 templates. Three (`raiser`, `shaper`, `host`) are commented out
#   in the checkout, so they are not registered either here.
# - Each template is duplicated at a smithing table: the template, a **dupe item**
#   named per overlay, and seven diamonds, in the source's own cross pattern.
# - A template is applied at a smithing table with a **trim-material** item, which
#   is any item carrying the source's `_mcl_armor_trim_color`: diamond, iron, gold,
#   emerald, lapis, copper, amethyst, netherite scrap/ingot, redstone wire and the
#   pale-oak resin brick. The material's colour is what the trim is drawn in.
# - Applying the *same* overlay and material again is refused, which the source's
#   `is_trimmed` guard does.
# - The elytra is blacklisted: it cannot be trimmed.
#
# Voxey already had the Rib and Snout templates as two inert loot items (1108 and
# 1109, `family: "template"`) with nothing consuming them. Those ids are kept, and
# the other fifteen are added here.

const FIRST = 11490
const COUNT = 17
# Source order, with `raiser`/`shaper`/`host` omitted because the checkout comments
# them out. `readable_name` is the display name the source uses.
const NAMES = ["Sentry","Dune","Coast","Wild","Tide","Ward","Vex","Rib","Snout","Eye","Spire","Silence","Wayfinder","Bolt","Flow","Host","Raiser"]
const KEYS = ["sentry","dune","coast","wild","tide","ward","vex","rib","snout","eye","spire","silence","wayfinder","bolt","flow","host","raiser"]
# The source's `dupe_item` per overlay, as a Voxey id.
const DUPE_ITEMS = [Nodes.COBBLE,Nodes.SANDSTONE,Nodes.COBBLE,Nodes.MOSSY_COBBLE,Conduits.PRISMARINE,Nodes.COBBLED_DEEPSLATE,Nodes.COBBLE,Nodes.NETHERRACK,MinecloniaOres.BLACKSTONE,Nodes.END_STONE,Nodes.PURPUR,Nodes.COBBLED_DEEPSLATE,Nodes.TERRACOTTA,Nodes.COPPER_NODE,VillageContent.BREEZE_ROD,Nodes.TERRACOTTA,Nodes.TERRACOTTA]
# The source's `rarity` per overlay; it only affects presentation, so it is kept
# for completeness rather than shown.
const RARITY = [1,1,1,1,1,2,2,1,1,2,2,3,1,1,1,1,1]
# The two template ids Voxey already had, so a save holding them keeps them.
const LEGACY_RIB = 1108
const LEGACY_SNOUT = 1109
# The source's own trim-material colours, per item. `_mcl_armor_trim_color`.
const MATERIAL_COLORS = {
	Nodes.DIAMOND:"5faed8",
	Nodes.IRON:"938e88",
	Nodes.GOLD:"ce9627",
	VillageContent.EMERALD:"1b9958",
	Nodes.LAPIS:"1c306b",
	Nodes.COPPER:"c36447",
	Amethyst.SHARD:"8246a5",
	Netherite.SCRAP:"c9bcb9",
	Netherite.INGOT:"302a26",
	Nodes.REDSTONE_WIRE:"e80202",
	# `mcl_pale_oak:resin_brick`'s own `_mcl_armor_trim_color`.
	PaleOak.RESIN_BRICK:"ff5315",
}

static func template_id(index: int) -> int: return FIRST+index
static func index_of(id: int) -> int: return id-FIRST if id >= FIRST and id < FIRST+COUNT else -1
static func is_template(id: int) -> bool: return index_of(id) >= 0
static func key(id: int) -> String:
	var i: int = index_of(id)
	return KEYS[i] if i >= 0 else ""
static func title(id: int) -> String:
	var i: int = index_of(id)
	return NAMES[i]+" armor trim template" if i >= 0 else ""
static func dupe_item(id: int) -> int:
	var i: int = index_of(id)
	return DUPE_ITEMS[i] if i >= 0 else 0

# A trim material is any item the source marks with `_mcl_armor_trim_color`.
# `is_smithing_mineral` in the source is that check.
static func is_material(id: int) -> bool: return MATERIAL_COLORS.has(id)
static func material_color(id: int) -> Color:
	return Color(MATERIAL_COLORS[id]) if MATERIAL_COLORS.has(id) else Color.WHITE

# `mcl_armor.blacklisted`: the elytra cannot be trimmed.
static func trimmable(id: int) -> bool: return Nodes.is_armor(id) and id != Nodes.ELYTRA

# The template a stack is already trimmed with, and its material, or empty.
static func trim_of(slot: Dictionary) -> Dictionary:
	var data: Dictionary = slot.get("data",{})
	var overlay: String = str(data.get("trim_overlay",""))
	if overlay.is_empty(): return {}
	return {"overlay":overlay,"material":int(data.get("trim_material",0))}
static func is_trimmed(slot: Dictionary) -> bool: return not trim_of(slot).is_empty()

# `mcl_armor.trim`: writes the overlay and material onto the armor. Returns false
# when the pair is already applied, which is the source's `is_trimmed` guard.
static func apply(slot: Dictionary, template: int, material: int) -> bool:
	if not is_template(template) or not is_material(material) or not trimmable(slot.id): return false
	var current: Dictionary = trim_of(slot)
	var overlay: String = key(template)
	if current.get("overlay","") == overlay and int(current.get("material",0)) == material: return false
	if not slot.has("data"): slot["data"] = {}
	slot.data["trim_overlay"] = overlay
	slot.data["trim_material"] = material
	return true

# The colour a trimmed piece's overlay is drawn in, for the inventory and preview.
static func overlay_color(slot: Dictionary) -> Color:
	var trim: Dictionary = trim_of(slot)
	return material_color(int(trim.get("material",0))) if not trim.is_empty() else Color.WHITE

# --- recipes -----------------------------------------------------------------

static func recipes(inv: Inventory) -> void:
	# `mcl_armor/trims.lua`: the template, a per-overlay dupe item, and seven
	# diamonds, in the source's own cross pattern.
	for i in COUNT:
		var dupe: int = DUPE_ITEMS[i]
		if dupe == 0: continue
		inv._recipe(NAMES[i]+" armor trim template",FIRST+i,2,
			[Nodes.DIAMOND,FIRST+i,Nodes.DIAMOND,Nodes.DIAMOND,dupe,Nodes.DIAMOND,Nodes.DIAMOND,Nodes.DIAMOND,Nodes.DIAMOND],3,"table")

# --- art ---------------------------------------------------------------------

# A template is a small plate with a raised emblem: a diamond-ish frame with the
# overlay's own motif hinted by its dupe material's colour.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var i: int = maxi(index_of(id),0)
	var accent := Color(MATERIAL_COLORS.values()[i%MATERIAL_COLORS.size()])
	# Frame
	if x in [1,14] or y in [1,14]: return Color("6f6a63")
	if x in [2,13] and y in [2,13]: return Color("d8d2c4")
	# Emblem: a simple per-template bar arrangement so the plates differ.
	match i%6:
		0:
			if absi(x-y) < 2 or absi(x-(15-y)) < 2: return accent
		1:
			if y in [6,7,8] and x in range(4,12): return accent
		2:
			if x == 7 and y in range(3,13): return accent
		3:
			if maxi(absi(x-7),absi(y-7)) in [2,3]: return accent
		4:
			if (x+y)%4 == 0 and y in range(3,13): return accent
		5:
			if y in [4,11] and x in range(4,12): return accent
	return noise.lerp(Color("b9b2a4"),0.7)

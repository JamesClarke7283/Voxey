class_name ArchaeologyLoot
extends RefCounted

static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/archaeology_loot.json"))
const ITEMS = {
	"mcl_core:emerald":VillageContent.EMERALD,"mcl_farming:wheat_item":Nodes.GRAIN,
	"mcl_farming:hoe_wood":Nodes.TOOLS+4,"mcl_core:clay_lump":Nodes.CLAY_BALL,
	"mcl_core:brick":Nodes.BRICK_ITEM,"mcl_core:gold_nugget":Nodes.GOLD_NUGGET,
	"mcl_core:coal_lump":Nodes.COAL,"mcl_farming:wheat_seeds":Nodes.SEEDS,
	"mcl_farming:beetroot_seeds":VillageContent.BEETROOT_SEEDS,"mcl_core:deadbush":DryTerrain.DEAD_BUSH,
	"mcl_flowerpots:flower_pot":Decor.POT,"mcl_mobitems:string":Nodes.STRING,
	"mcl_mobitems:gunpowder":Nodes.GUNPOWDER,"mcl_tnt:tnt":Nodes.TNT,"mcl_core:diamond":Nodes.DIAMOND,
	"mcl_tools:axe_iron":Nodes.TOOLS+11,"mcl_armor:wayfinder":ArmorTrims.FIRST+12,
	"mcl_core:stick":Nodes.STICK,"mcl_sus_stew:stew":VillageContent.SUSPICIOUS_STEW,
}
# Kept in the project's stable sherd-ID order, not alphabetic order.
const SHERDS = ["angler","blade","explorer","skull","archer","arms_up","brewer","burn","danger","friend","heartbreak","heart","howl","miner","mourner","plenty","prize","sheaf","shelter","snort","flow","guster","scrape"]

static func item_id(name: String) -> int:
	if ITEMS.has(name): return ITEMS[name]
	if name.begins_with("mcl_pottery_sherds:"): return 9910+SHERDS.find(name.get_slice(":",1)) if SHERDS.has(name.get_slice(":",1)) else 0
	if name.begins_with("mcl_dyes:"):
		var index: int = GlassColors.COLORS.find(name.get_slice(":",1))
		return VillageContent.DYE_WHITE+index if index >= 0 else 0
	if name.begins_with("mcl_panes:pane_"):
		var index: int = GlassColors.COLORS.find(name.trim_prefix("mcl_panes:pane_").trim_suffix("_flat"))
		return GlassColors.PANE_FIRST+index if index >= 0 else 0
	if name.begins_with("mcl_signs:hanging_sign_"):
		var index: int = WoodTypes.KEYS.find(name.trim_prefix("mcl_signs:hanging_sign_"))
		return Signs.HANGING_ITEMS[index] if index >= 0 and index < Signs.HANGING_ITEMS.size() else 0
	if name == "mcl_candles:candle_1": return Candles.FIRST
	return 0

static func tables() -> Dictionary:
	var result: Dictionary = {}
	for name in source.tables:
		var entries: Array = []
		for raw in source.tables[name]:
			var entry: Dictionary = {"id":item_id(raw.item),"weight":int(raw.weight),"min":1,"max":1}
			if raw.has("candle_colors"):
				entry.variants = []
				for color in raw.candle_colors: entry.variants.append(Candles.FIRST+8*GlassColors.COLORS.find(color))
			entries.append(entry)
		result["desert_temple" if name == "desert_pyramid_archeology" else name] = entries
	return result

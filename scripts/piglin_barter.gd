class_name PiglinBarter
extends RefCounted
const NETHER_BRICK = Nodes.NETHER_BRICK_ITEM
const FIRE_CHARGE = 1116
# Mineclonia mobs_mc/piglin.lua trading_items. Special tokens are potion forms
# and Soul Speed equipment; weights and quantity ranges are kept verbatim.
const ITEMS = [[Nodes.OBSIDIAN,40,1,1],[Nodes.GRAVEL,40,8,16],[Nodes.LEATHER,40,4,10],
	[Nodes.SOUL_SAND,40,4,16],[NETHER_BRICK,40,4,16],[Nodes.STRING,20,3,9],
	[Nodes.QUARTZ,20,4,10],[VillageContent.WATER_BOTTLE,40,1,1],[Nodes.IRON_NUGGET,10,10,36],
	[Nodes.ENDER_PEARL,10,2,6],["fire_resistance",8,1,1],["fire_resistance_splash",8,1,1],
	["soul_speed_book",5,1,1],["soul_speed_boots",8,1,1],[MinecloniaOres.BLACKSTONE,40,8,16],
	[Nodes.ARROW_ITEM,40,6,12],[Bastions.CRYING_OBSIDIAN,40,1,1],[FIRE_CHARGE,40,1,1]]
static func reward(rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for entry in ITEMS: total += entry[1]
	var selection: int = rng.randi_range(1,total)
	for entry in ITEMS:
		selection -= entry[1]
		if selection > 0: continue
		var id: int = entry[0] if entry[0] is int else 0
		if entry[0] is String:
			match entry[0]:
				"fire_resistance": id = PotionCatalog.find("fire_resistance")
				"fire_resistance_splash": id = PotionCatalog.find("fire_resistance","splash")
				"soul_speed_book": id = VillageContent.ENCHANTED_BOOK
				"soul_speed_boots": id = Nodes.armor_id(1,3)
		var result: Dictionary = {"id":id,"count":rng.randi_range(entry[2],entry[3]),"wear":0}
		if entry[0] in ["soul_speed_book","soul_speed_boots"]: result["data"] = {"enchantments":{"Soul Speed":rng.randi_range(1,3)}}
		return result
	return {}

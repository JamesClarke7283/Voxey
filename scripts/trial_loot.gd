class_name TrialLoot
extends RefCounted

# Source tables are exported, not reweighted when a route is unavailable.
static var catalog: Dictionary = {}
const ITEMS = {
	"mcl_core:emerald":VillageContent.EMERALD,"mcl_bows:arrow":Nodes.ARROW_ITEM,
	"mcl_core:iron_ingot":Nodes.IRON,"mcl_charges:wind_charge":WindCharge.ID,
	"mcl_honey:honey_bottle":Beehives.BOTTLE,"mcl_shields:shield":VillageContent.SHIELD,
	"mcl_bows:bow":Nodes.BOW,"mcl_mobitems:breeze_rod":VillageContent.BREEZE_ROD,
	"mcl_core:diamond":Nodes.DIAMOND,"mcl_farming:carrot_item_gold":VillageContent.GOLDEN_CARROT,
	"mcl_books:book":VillageContent.ENCHANTED_BOOK,"mcl_bows:crossbow":VillageContent.CROSSBOW,
	"mcl_tools:axe_iron":Nodes.TOOLS+11,"mcl_armor:chestplate_iron":Nodes.ARMOR_BASE+5,
	"mcl_tools:axe_diamond":Nodes.TOOLS+16,"mcl_armor:chestplate_diamond":Nodes.ARMOR_BASE+13,
	"mcl_core:apple_gold":Nodes.GOLDEN_APPLE,"mcl_armor:bolt":ArmorTrims.FIRST+13,
	"mcl_jukebox:record_mall":Jukeboxes.MALL,"mcl_banners:pattern_guster":VillageContent.PATTERN_FIRST+8,
	"mcl_tridents:trident":VillageContent.TRIDENT,"mcl_core:emeraldblock":VillageContent.EMERALD_BLOCK,
	"mcl_core:ironblock":Nodes.IRON_BLOCK,"mcl_core:diamondblock":Nodes.DIAMOND_BLOCK,
	"mcl_armor:flow":ArmorTrims.FIRST+14,"mcl_core:apple_gold_enchanted":12212,
	"mcl_banners:pattern_flow":VillageContent.PATTERN_FIRST+9,"mcl_jukebox:record_mellohi":Jukeboxes.MELLOHI,
	"mcl_tools:heavy_core":VillageContent.HEAVY_CORE,"mcl_farming:bread":Nodes.BREAD,
	"mcl_mobitems:cooked_chicken":VillageContent.COOKED_CHICKEN,"mcl_farming:potato_item_baked":VillageContent.BAKED_POTATO,
	"mcl_mobitems:cooked_beef":VillageContent.COOKED_BEEF,
	"mcl_honey:honeycomb":Beehives.COMB,"mcl_tools:axe_wood":Nodes.TOOLS+1,
	"mcl_core:stick":Nodes.STICK,"mcl_vaults:trial_key":12210,
	"mcl_amethyst:amethyst_shard":Amethyst.SHARD,"mcl_cake:cake":VillageContent.CAKE,
	"mcl_tools:pick_diamond":Nodes.TOOLS+15,
	"mcl_lush_caves:glow_berry":VillageContent.GLOW_BERRY,"mcl_tools:pick_stone":Nodes.TOOLS+5,
	"mcl_deepslate:tuff":MinecloniaOres.TUFF,"mcl_trees:wood_acacia":6131,
	"mcl_torches:torch":Nodes.TORCH,"mcl_bone_meal:bone_meal":Nodes.BONE_MEAL,
	"mcl_lush_caves:moss":VillageContent.MOSS,"mcl_mobitems:milk_bucket":Nodes.MILK_BUCKET,
	"mcl_trees:wood_bamboo":BambooWood.PLANKS,"mcl_tools:axe_gold":1111,"mcl_tools:pick_gold":1110,
	"mcl_buckets:bucket_empty":Nodes.BUCKET,"mcl_compass:compass":Nodes.COMPASS,
	"mcl_bamboo:scaffolding":Scaffolding.ID,"mcl_signs:hanging_sign_bamboo":BambooWood.HANGING,
	"mcl_throwing:ender_pearl":Nodes.ENDER_PEARL,"mcl_tools:axe_stone":Nodes.TOOLS+6,
	"mcl_fire:fire_charge":1116,"mcl_throwing:snowball":Nodes.SNOWBALL,
	"mcl_buckets:bucket_water":Nodes.WATER_BUCKET,"mcl_throwing:egg":Nodes.EGG,
}

static func tables() -> Dictionary:
	if catalog.is_empty(): catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/trial_loot.json")).tables
	return catalog

static func item_id(name: String) -> int:
	if ITEMS.has(name): return int(ITEMS[name])
	if name == "mcl_potions:ominous": return PotionCatalog.find("ominous")
	if name.begins_with("mcl_potions:"):
		var potion: String = name.get_slice(":",1)
		for form in ["arrow","lingering","splash"]:
			if potion.ends_with("_"+form): return PotionCatalog.find(potion.trim_suffix("_"+form),form)
		return PotionCatalog.find(potion)
	return 0

static func enchant_name(source: String) -> String:
	for name in Enchantments.DATA:
		if name.to_lower() == source.replace("_"," "): return name
	return ""

static func stack(entry: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var id: int = item_id(entry.item)
	if id == 0: return {}
	var result: Dictionary = {"id":id,"count":rng.randi_range(int(entry.amount_min),int(entry.amount_max)),"wear":0}
	var data: Dictionary = {}
	if entry.has("wear"):
		result.wear = roundi(Nodes.durability(id)*rng.randi_range(entry.wear[0],entry.wear[1])/65535.0)
	if entry.has("omen"): data.omen_level = rng.randi_range(entry.omen[0],entry.omen[1])
	if entry.has("potency"): data.potion_level = int(entry.potency)+1
	if entry.has("potency") and int(entry.potency) == 3:
		result.id = PotionCatalog.find("slowness","arrow","strong")
	if entry.has("enchantments"):
		var names: Array = entry.enchantments
		var name: String = enchant_name(names[rng.randi_range(0,names.size()-1)])
		data.enchantments = {name:int(entry.get("enchantment_level",rng.randi_range(1,Enchantments.DATA[name].max)))}
	elif entry.has("enchant_power"):
		var power: int = rng.randi_range(entry.enchant_power[0],entry.enchant_power[1])
		var enchantment: Dictionary = Enchanting.generate_reliable(result,power,EnchantRolls.new(1,rng),true,true)
		if not enchantment.is_empty(): data.enchantments = enchantment.enchantments
	if not data.is_empty(): result.data = data
	return result

static func pick(items: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for entry in items: total += int(entry.weight)
	var roll: int = rng.randi_range(1,total)
	for entry in items:
		roll -= int(entry.weight)
		if roll <= 0: return stack(entry,rng)
	return {}

static func roll(name: String, rng: RandomNumberGenerator) -> Array:
	var result: Array = []
	for pool in tables()[name]:
		for i in rng.randi_range(int(pool.min),int(pool.max)):
			var item: Dictionary = pick(pool.items,rng)
			if not item.is_empty(): result.append(item)
	return result

static func fill(station: Dictionary, name: String, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var items: Array = roll(name,rng)
	for i in mini(items.size(),station.slots.size()): station.slots[i] = items[i]
	station.label = "Trial chamber supplies"

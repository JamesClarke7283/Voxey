class_name Harvesting
extends RefCounted

# Registered node drops and mcl_item_entity's ordered shears/Silk/Fortune
# transformation. Dig speed and harvest eligibility are distinct contracts.
# Mineclonia rules: GPL-3.0-or-later. Luanti get_node_drops behavior:
# LGPL-2.1-or-later. Source paths and verification: docs/harvesting-source.md.
static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/harvesting.json"))
static var item_ids: Dictionary = {}
static var initialized: bool = false

static func canonical(name: String) -> String:
	for _i in 16:
		if not source.aliases.has(name): break
		name = str(source.aliases[name])
	return name

static func item_for(id: int) -> int:
	if GrindstoneRepair.is_grindstone(id): return VillageContent.GRINDSTONE
	if Stonecutting.is_cutter(id): return VillageContent.STONECUTTER
	if BuildingShapes.is_shape(id): return BuildingShapes.item(id)
	if DenseMaterials.is_bone(id): return DenseMaterials.BONE
	if FruitCrops.is_pumpkin_head(id): return FruitCrops.canonical(id)
	if SweetBerryCrops.is_bush(id): return SweetBerryCrops.BERRY
	if Doors.is_door(id): return Doors.item(id)
	if Trapdoors.is_trapdoor(id): return Trapdoors.item(id)
	if Barriers.is_barrier(id): return Barriers.item(id)
	if Signs.is_hanging(id): return Signs.hanging_item(id)
	if Signs.is_sign(id): return Signs.item(id)
	if RedstoneInputs.is_device(id): return RedstoneInputs.item(id)
	if WoodTypes.is_log(id): return WoodTypes.canonical(id)
	if Heads.is_any(id): return Heads.item(id)
	if Rails.is_rail(id): return Rails.item(id)
	if Amethyst.is_crystal(id): return Amethyst.item(id)
	if SnowCover.is_snow(id): return SnowCover.BASE
	if Torches.is_torch(id): return Torches.item(id)
	return id

static func initialize() -> void:
	if initialized: return
	initialized = true
	MiningNodes.initialize()
	var explicit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/harvest_items.json")).items
	for name in explicit: item_ids[canonical(name)] = int(explicit[name])
	for id in Nodes.all_ids()+VillageContent.DATA.keys()+WoodTypes.DATA.keys():
		var name: String = ToolCapabilities.node_name(id)
		if name.is_empty() or item_ids.has(name): continue
		item_ids[name] = item_for(id)
	for item in Doors.ITEMS+Copper.DOOR_ITEMS+WoodTypes.DOOR_ITEMS+[BambooWood.DOOR]:
		var name: String = ToolCapabilities.node_name(item)
		if not name.is_empty(): item_ids[canonical(name.substr(0,name.length()-4))] = item

static func item_id(name: String, broken: int = 0) -> int:
	initialize()
	name = canonical(name)
	if Candles.is_candle(broken) and name.begins_with("mcl_candles:candle_"): return Candles.item_for(Candles.color_index(broken))
	if broken in [547,548] and name.begins_with("mcl_candles:candle_"): return broken
	if broken >= 635 and broken < 651 and name == "mcl_banners:banner_item": return broken
	if name == ToolCapabilities.node_name(broken): return item_for(broken)
	return int(item_ids.get(name,0))

static func harvest(id: int, slot: Dictionary, random: EnchantRolls = null) -> Dictionary:
	var name: String = ToolCapabilities.node_name(id)
	if name.is_empty(): return {"handled":false}
	var result: Dictionary = evaluate(name,int(slot.get("id",0)),Inventory.enchantment(slot,"Fortune"),Inventory.enchantment(slot,"Silk Touch") > 0,random,int(slot.get("id",0)) in [Nodes.BOOK,VillageContent.ENCHANTED_BOOK])
	var drops: Array = []
	for entry in result.drops:
		var output: int = item_id(entry[0],id)
		if output == 0: return {"handled":false,"missing":entry[0]}
		drops.append([output,int(entry[1])])
	return {"handled":true,"drops":drops,"xp":result.xp,"harvestable":result.harvestable}

static func tool(id: int) -> Dictionary:
	var profile: Dictionary = source.tools.get(str(id),{"name":"","groups":{},"tags":{},"shears":0})
	if not profile.groups is Dictionary: profile.groups = {}
	if not profile.get("tags") is Dictionary: profile.tags = {}
	return profile

static func truthy(value: Variant) -> bool:
	return value != null and (not value is bool or value)

static func can_harvest_name(name: String, tool_id: int) -> bool:
	if not source.nodes.has(name): return false
	var groups: Dictionary = source.nodes[name].groups if source.nodes[name].groups is Dictionary else {}
	if int(groups.get("dig_immediate",0)) >= 2: return true
	for profile in [tool(tool_id),tool(0)]:
		for group in profile.groups:
			if groups.has(group) and float(groups[group]) <= float(profile.groups[group]): return true
	return false

static func has_groups(tags: Dictionary, requirement: Variant) -> bool:
	if requirement is String: return float(tags.get(requirement,0)) != 0
	if requirement is Array:
		for group in requirement:
			if float(tags.get(str(group),0)) == 0: return false
		return true
	return false

static func accepts_tool(entry: Dictionary, tool_id: int) -> bool:
	var good: bool = not entry.has("tools") and not entry.has("tool_groups")
	var profile: Dictionary = tool(tool_id)
	for pattern in entry.get("tools",[]):
		if (str(pattern).begins_with("~") and str(profile.name).contains(str(pattern).substr(1))) or pattern == profile.name:
			good = true
	if entry.has("tool_groups"):
		var groups: Variant = entry.tool_groups
		if groups is String: good = has_groups(profile.tags,groups)
		elif groups is Array:
			good = false
			for requirement in groups:
				if has_groups(profile.tags,requirement): good = true; break
	return good

static func stack(value: String) -> Array:
	var parts: PackedStringArray = value.split(" ",false,2)
	if parts.is_empty(): return []
	return [canonical(parts[0]),clampi(int(parts[1]) if parts.size() > 1 else 1,0,65535)]

static func stacks(values: Variant) -> Array:
	var result: Array = []
	if values is Array:
		for value in values:
			var parsed: Array = stack(str(value))
			if not parsed.is_empty() and parsed[1] > 0: result.append(parsed)
	return result

static func table_drops(value: Variant, tool_id: int, random: EnchantRolls) -> Array:
	if value is String: return stacks([value])
	if not value is Dictionary: return []
	var result: Array = []
	var obtained: int = 0
	var maximum: int = int(value.get("max_items",0))
	for entry in value.get("items",[]):
		var rarity: int = int(entry.get("rarity",0))
		var good: bool = rarity < 1 or random.integer(1,rarity) == 1
		if good and accepts_tool(entry,tool_id):
			obtained += 1
			result.append_array(stacks(entry.get("items",[])))
			if maximum > 0 and obtained == maximum: break
	return result

static func fortune_table(value: Variant, level: int) -> Variant:
	while level > 0:
		if value is Array and value.size() >= level: return value[level-1]
		if value is Dictionary and value.has(str(level)): return value[str(level)]
		level -= 1
	return {}

static func evaluate(name: String, tool_id: int, fortune: int = 0, silk: bool = false, random: EnchantRolls = null, book: bool = false) -> Dictionary:
	var result: Dictionary = {"drops":[],"xp":0,"harvestable":false}
	if not source.nodes.has(name): return result
	book = book or bool(tool(tool_id).get("is_book",false))
	if random == null:
		var native := RandomNumberGenerator.new(); native.randomize()
		random = EnchantRolls.new(1,native)
	var def: Dictionary = source.nodes[name]
	# Luanti computes the base table before calling handle_node_drops, even if
	# the held tool ultimately cannot harvest the block.
	var drops: Array = stacks([name]) if def.get("drop_kind","nil") == "nil" else table_drops(def.get("drop"),tool_id,random)
	if tool_id < 0: return {"drops":drops,"xp":0,"harvestable":true}
	if not can_harvest_name(name,tool_id): return result
	result.harvestable = true
	var silk_used: bool = false
	if int(tool(tool_id).shears) > 0 and truthy(def.get("shears")):
		drops = stacks([name]) if def.shears is bool else stacks(def.shears)
	elif silk and not book and truthy(def.get("silk")):
		silk_used = true
		if def.silk is bool: drops = stacks([name])
		elif def.silk is Dictionary: drops = table_drops(def.silk,tool_id,random)
		else: drops = stacks(def.silk)
	var rule: Variant = def.get("fortune")
	if fortune > 0 and not book and rule != null:
		if rule is Dictionary and rule.get("discrete_uniform_distribution",false):
			var chance: float = float(rule.get("chance",1))
			if rule.get("chances") is Array: chance = float(rule.chances[mini(fortune,rule.chances.size())-1])
			if not rule.has("chance") and not rule.has("chances") or random.unit() < chance:
				drops = drops.duplicate(true) if rule.get("multiply",false) else stacks(rule.get("items",[]))
				for entry in drops:
					var count: int = random.integer(int(rule.min_count),int(rule.max_count)+fortune*int(rule.get("factor",1)))
					if rule.has("cap"): count = mini(count,int(rule.cap))
					entry[1] = mini(65535,int(entry[1])*count)
			elif rule.get("overwrite",false): drops = []
		else: drops = table_drops(fortune_table(rule,fortune),tool_id,random)
		if rule is Dictionary: drops.append_array(stacks(rule.get("drop_without_fortune",[])))
	result.drops = drops
	result.xp = 0 if silk_used else int(def.groups.get("xp",0)) if def.groups is Dictionary else 0
	return result

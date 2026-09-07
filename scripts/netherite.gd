class_name Netherite
extends RefCounted

# Mineclonia mcl_nether, mcl_tools/register.lua and mcl_armor/register.lua.
const ANCIENT_DEBRIS = 693
const BLOCK = 694
const SCRAP = 1080
const INGOT = 1081
const TEMPLATE = 1082
const TOOLS = 1090
const ARMOR = 1095
const ARMOR_FACTORS = [0.6857,1.0,0.9375,0.8125]

static func upgrade_id(id: int) -> int:
	if Nodes.is_tool_id(id) and Nodes.tool_tier(id) == 3: return TOOLS+Nodes.tool_kind(id)
	if Nodes.is_armor(id) and Nodes.armor_material(id) == 3: return ARMOR+Nodes.armor_piece(id)
	return 0

static func upgrade(inv: Inventory, index: int) -> bool:
	if index < 0 or index >= inv.slots.size(): return false
	var original: Dictionary = inv.slots[index]
	var result: int = upgrade_id(original.id)
	if result == 0 or inv.count_item(INGOT) < 1 or inv.count_item(TEMPLATE) < 1: return false
	var replacement: Dictionary = original.duplicate(true)
	replacement.id = result
	# Luanti retains normalized wear when changing an item name.
	replacement.wear = mini(Nodes.durability(result)-1,ceili(float(original.wear)*Nodes.durability(result)/Nodes.durability(original.id)))
	var trial := Inventory.new(); trial.slots = inv.slots.duplicate(true)
	trial.remove_item(INGOT); trial.remove_item(TEMPLATE)
	trial.slots[index] = replacement
	inv.slots = trial.slots
	inv.changed.emit()
	return true

static func recipes(inv: Inventory) -> void:
	inv._recipe("Netherite ingot",INGOT,1,[SCRAP,SCRAP,SCRAP,SCRAP,Nodes.GOLD,Nodes.GOLD,Nodes.GOLD,Nodes.GOLD,0],3,"table")
	inv.recipes.back()["shapeless"] = true
	inv._recipe("Block of netherite",BLOCK,1,[INGOT,INGOT,INGOT,INGOT,INGOT,INGOT,INGOT,INGOT,INGOT],3,"table")
	inv._recipe("Netherite ingots",INGOT,9,[BLOCK],1)
	inv._recipe("Duplicate netherite upgrade template",TEMPLATE,2,[Nodes.DIAMOND,TEMPLATE,Nodes.DIAMOND,Nodes.DIAMOND,Nodes.NETHERRACK,Nodes.DIAMOND,Nodes.DIAMOND,Nodes.DIAMOND,Nodes.DIAMOND],3,"table")

# Version 2 used one durability for every piece in an armor material.
# Preserve the remaining fraction as saves adopt the source's piece factors.
static func migrate_wear(value) -> void:
	if value is Array:
		for child in value: migrate_wear(child)
	elif value is Dictionary:
		if value.has("id") and value.has("count") and value.has("wear"):
			var id: int = Nodes.migrate(int(value.id))
			if id >= Nodes.ARMOR_BASE and id < Nodes.ARMOR_END:
				var old: int = Nodes.ARMOR_DURABILITY[Nodes.armor_material(id)]
				value.wear = ceili(float(value.wear)*Nodes.durability(id)/old)
		for child in value.values(): migrate_wear(child)

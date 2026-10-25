class_name Anvils
extends RefCounted

# Mineclonia ITEMS/mcl_anvils/init.lua and ITEMS/mcl_enchanting/engine.lua,
# GPL-3.0-or-later. Preview is pure; AnvilWorkbench commits the exchange.

# The source's `MAX_WEAR`, which Voxey expresses per-item through `Nodes.durability`.
const MAX_WEAR = 65535
# `SAME_TOOL_REPAIR_BOOST = ceil(MAX_WEAR * 0.12)`.
const SAME_TOOL_BOOST = 0.12
# `MATERIAL_TOOL_REPAIR_BOOST` for one to four consumed materials.
const MATERIAL_BOOSTS = [0.25,0.5,0.75,1.0]
# `damage_anvil_by_using`: a 12% chance per use.
const DAMAGE_CHANCE = 0.12
# Three damage levels, then the anvil is destroyed.
const MAX_DAMAGE = 3

# --- prior work penalty ------------------------------------------------------

static func pwp_of(slot: Dictionary) -> int:
	return maxi(0,int(slot.get("data",{}).get("pwp",0)))
static func set_pwp(slot: Dictionary, value: int) -> void:
	if not slot.has("data"): slot["data"] = {}
	if value <= 0: slot.data.erase("pwp")
	else: slot.data["pwp"] = value
static func add_pwp(slot: Dictionary, amount: int = 1) -> void:
	set_pwp(slot,pwp_of(slot)+amount)
# `combine_prior_work_penalty`: the result takes max of both, plus one.
static func combine_pwp(target: Dictionary, other: Dictionary) -> void:
	set_pwp(target,maxi(pwp_of(target),pwp_of(other))+1)
# `2^pwp - 1` for one input, which is the source's own cost term.
static func pwp_cost(slot: Dictionary) -> int:
	return (1 << mini(pwp_of(slot),60))-1

# --- repair ------------------------------------------------------------------

# `calculate_repair(wear, boost)`: the damage removed is the boost fraction of the
# whole item, plus the other piece's own repaired health when combining.
static func repair_wear(wear: int, boost: float, span: int = MAX_WEAR) -> int:
	return maxi(0,int(wear)-int(span*boost))

# `get_consumed_materials(tool, material)`: one material is consumed at a time and
# the loop stops as soon as the remaining wear would be covered.
# `span` is the item's own durability. The source works on the normalized
# 0..65535 wear, where 25% is 25% of the whole item; Voxey stores wear in the
# item's own units, so the same fractions must be taken of `Nodes.durability(id)`
# or a single material would fully repair a wooden pickaxe.
static func normalized_wear(wear: int, span: int) -> int:
	return clampi(floori(float(wear)*MAX_WEAR/span),0,MAX_WEAR) if span > 0 else 0

static func item_wear(wear: int, span: int) -> int:
	return clampi(ceili(float(wear)*span/MAX_WEAR),0,span)

static func consumed_materials(wear: int, available: int, span: int = MAX_WEAR) -> int:
	return materials_for_wear(normalized_wear(wear,span),available)

static func materials_for_wear(normalized: int, available: int) -> int:
	for m in mini(4,available):
		if normalized <= ceili(MAX_WEAR*MATERIAL_BOOSTS[m]): return m+1
	return mini(4,available)

static func accepts_material(id: int, material: int) -> bool:
	var expected: int = repair_material(id)
	if expected == Nodes.PLANKS: return material == Nodes.PLANKS or WoodTypes.is_planks(material)
	if expected == Nodes.COBBLE: return material in [Nodes.COBBLE,Nodes.COBBLED_DEEPSLATE,MinecloniaOres.BLACKSTONE]
	return expected != 0 and material == expected

static func material_repair(tool: Dictionary, count: int, material: int) -> Dictionary:
	if Nodes.durability(tool.id) <= 0 or int(tool.get("wear",0)) <= 0 or not accepts_material(tool.id,material): return {}
	var span: int = Nodes.durability(tool.id)
	var normalized: int = Durability.normalized(tool)
	var used: int = materials_for_wear(normalized,count)
	if used == 0: return {}
	var new_wear: int = maxi(0,normalized-ceili(MAX_WEAR*MATERIAL_BOOSTS[used-1]))
	return {"wear":item_wear(new_wear,span),"normalized":new_wear,"materials":used}

static func repair_material(id: int) -> int:
	# Explicit mappings precede ranges: golden tools have larger ids than netherite.
	if VillageContent.DATA.get(id,{}).has("repair_material"): return int(VillageContent.DATA[id].repair_material)
	if id == VillageContent.SHIELD: return Nodes.PLANKS
	if id == VillageContent.MACE: return VillageContent.BREEZE_ROD
	if id == Nodes.ELYTRA: return 0 # This source registers no repair material.
	if Nodes.is_armor(id):
		if id in range(VillageContent.CHAIN_HELMET,VillageContent.CHAIN_HELMET+4): return Nodes.IRON
		return [Nodes.LEATHER,Nodes.IRON,Nodes.GOLD,Nodes.DIAMOND,Netherite.INGOT][clampi(Nodes.armor_material(id),0,4)]
	if Nodes.is_tool_id(id) and Nodes.tool_kind(id) in range(5):
		return [Nodes.PLANKS,Nodes.COBBLE,Nodes.IRON,Nodes.DIAMOND,Netherite.INGOT][clampi(Nodes.tool_tier(id),0,4)]
	return 0

static func same_type_repair(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.id != b.id or Nodes.durability(a.id) <= 0: return {}
	var span: int = Nodes.durability(a.id)
	var before: int = Durability.normalized(a)
	var combined: int = maxi(0,before+Durability.normalized(b)-MAX_WEAR-ceili(MAX_WEAR*SAME_TOOL_BOOST))
	return {"wear":item_wear(combined,span),"normalized":combined,"bonus":2 if combined < before else 0}

# Source combine returns false unless at least one enchantment changes. It still
# counts one conflict per rejected incoming enchantment when another can apply.
static func combine(a: Dictionary, b: Dictionary) -> Dictionary:
	var id: int = int(a.get("id",0)); var other: int = int(b.get("id",0))
	if Enchanting.ability(id) == 0 or id != other and not (Enchanting.book(id) and Enchanting.book(other)) and not Enchanting.book(other): return {}
	var result: Dictionary = a.duplicate(true)
	var current: Dictionary = result.get("data",{}).get("enchantments",{}).duplicate(true)
	var changed: Dictionary = {}; var conflicts: int = 0
	for name in b.get("data",{}).get("enchantments",{}):
		if not Enchanting.source.definitions.has(name): continue
		var def: Dictionary = Enchanting.source.definitions[name]
		var incoming: int = int(b.data.enchantments[name])
		if current.has(name):
			var level: int = mini(int(def.max_level),incoming+1) if int(current[name]) == incoming else maxi(int(current[name]),incoming)
			if level != int(current[name]): changed[name] = true; current[name] = level
		elif Enchanting.support(id,name,not current.is_empty()).x != 0:
			if def.incompatible.any(func(key):return current.has(key)): conflicts += 1
			else: current[name] = incoming; changed[name] = true
	if changed.is_empty(): return {}
	combine_pwp(result,b)
	result.data.enchantments = current
	if Enchanting.book(id): result.id = VillageContent.ENCHANTED_BOOK
	var cost: int = conflicts
	for name in changed:
		var def: Dictionary = Enchanting.source.definitions[name]
		cost += int(current[name])*int(def.anvil_book_factor if Enchanting.book(other) else def.anvil_item_factor)
	return {"output":result,"cost":cost,"conflicts":conflicts}

# Complete two-input preview, including name, level cost and exact consumption.
# Native wear is quantized through the source's 0..65535 scale for repair math.
static func plan(first: Dictionary, second: Dictionary = {}, new_name: Variant = null) -> Dictionary:
	var a: Dictionary = first.duplicate(true); var b: Dictionary = second.duplicate(true)
	var has_a: bool = int(a.get("id",0)) > 0 and int(a.get("count",0)) > 0
	var has_b: bool = int(b.get("id",0)) > 0 and int(b.get("count",0)) > 0
	if not has_a and not has_b: return {}
	var output: Dictionary = {}; var consume: Array = [0,0]; var cost: int = 0; var operation: String = "Rename"
	if has_a and has_b:
		cost = pwp_cost(a)+pwp_cost(b)
		var merged: Dictionary = combine(a,b)
		if not merged.is_empty():
			output = merged.output; cost += int(merged.cost); operation = "Combine"
			if Nodes.durability(a.id) > 0 and Nodes.durability(b.id) > 0:
				var repaired: Dictionary = same_type_repair(a,b)
				Durability.set_normalized(output,repaired.normalized); cost += int(repaired.bonus)
		else:
			var reverse: bool = repair_material(int(a.id)) == 0
			var tool: Dictionary = b if reverse else a; var material: Dictionary = a if reverse else b
			var repaired: Dictionary = material_repair(tool,int(material.count),int(material.id))
			if repaired.is_empty(): return {}
			output = tool.duplicate(true); Durability.set_normalized(output,repaired.normalized); add_pwp(output)
			cost += int(repaired.materials); operation = "Repair"
		# Taking a result uses the source's independent tool/material distinction.
		# Even an enchanted book is the material operand when a tool defines one.
		var tool_index: int = 0 if repair_material(int(a.id)) != 0 else (1 if repair_material(int(b.id)) != 0 else -1)
		if tool_index >= 0:
			var tool: Dictionary = a if tool_index == 0 else b; var material: Dictionary = b if tool_index == 0 else a
			consume[tool_index] = 1; consume[1-tool_index] = materials_for_wear(Durability.normalized(tool),int(material.count))
		else: consume = [1,1]
	else:
		output = a if has_a else b
		consume[0 if has_a else 1] = int(output.count)
	if int(output.id) == Nodes.WRITTEN_BOOK: return {}
	var old_name: String = str(output.get("data",{}).get("custom_name",""))
	var text: String = NameTags.bounded(str(new_name),50) if new_name != null else old_name
	if text != old_name:
		cost += 1
		if not output.has("data"): output.data = {}
		if text.is_empty(): output.data.erase("custom_name")
		else: output.data.custom_name = text
	elif operation == "Rename": return {}
	output.count = mini(int(output.count),Nodes.max_stack(output.id))
	if output.get("data",{}).is_empty(): output.erase("data")
	return {"output":output,"cost":cost,"consume":consume,"operation":operation}

# --- rename ------------------------------------------------------------------

# A rename costs one level, and only when the name actually changes.
static func rename_cost(slot: Dictionary, new_name: String) -> int:
	return 0 if str(slot.get("data",{}).get("custom_name","")) == new_name else 1

# --- damage ladder -----------------------------------------------------------

# `damage_anvil_by_using` rolls the source's 12%. Returns the new damage level, or
# -1 when the anvil survives unharmed.
static func use_damage(level: int, rng: RandomNumberGenerator = null) -> int:
	var roll: int = rng.randi_range(1,100) if rng != null else randi_range(1,100)
	if roll > 12: return -1
	# Past the last level the anvil is destroyed, which the caller reads as any value
	# at or above `MAX_DAMAGE`. Returning the level itself used to report "unharmed".
	return level+1

# `damage_anvil_by_falling`: `5 * distance` percent, and only above one block.
static func falling_damage(distance: int, rng: RandomNumberGenerator = null) -> bool:
	if distance <= 1: return false
	var roll: int = rng.randi_range(1,100) if rng != null else randi_range(1,100)
	return roll <= 5*distance

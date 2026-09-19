class_name Anvils
extends RefCounted

# Mineclonia ITEMS/mcl_anvils/init.lua and ITEMS/mcl_enchanting/engine.lua,
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference.
#
# Voxey's anvil and grindstone existed but used simplified costs. This module adds
# the source's own cost model so the two agree on the numbers:
#
# - **Prior work penalty.** Every anvil operation raises a stored counter. A repair
#   adds one; a combination takes `max(p1, p2) + 1`. The counter's cost is
#   `2^pwp - 1` levels per input, which is what makes repeatedly reworking one item
#   progressively more expensive.
# - **Repair boosts.** Tool plus the same tool type sums their health and adds 12%.
#   Tool plus its repair material consumes one to four materials for 25/50/75/100%.
# - **Rename** costs one level when the name actually changes.
# - **Damage.** Every use has a 12% chance of damaging the anvil one level; falling
#   onto it deals `5 * distance` percent. The third level destroys it and drops
#   whatever it held.
#
# Voxey stores the counter under `data.pwp` alongside the existing enchantment and
# `custom_name` metadata, so it travels with the item through the inventory, chests,
# drops, death and saves.

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
	return int(pow(2,pwp_of(slot)))-1

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
static func consumed_materials(wear: int, available: int, span: int = MAX_WEAR) -> int:
	var used: int = 0
	for m in mini(4,available):
		used += 1
		if wear-int(span*MATERIAL_BOOSTS[m]) <= 0: break
	return used

# A material repair of `tool` using `count` of its repair material. Returns the new
# wear and how many materials were consumed, or empty when not applicable.
static func material_repair(tool: Dictionary, count: int, material: int) -> Dictionary:
	if Nodes.durability(tool.id) <= 0 or int(tool.get("wear",0)) <= 0: return {}
	if repair_material(tool.id) != material: return {}
	var span: int = Nodes.durability(tool.id)
	var used: int = consumed_materials(int(tool.wear),count,span)
	if used == 0: return {}
	# The boosts are cumulative up to the material count consumed.
	var new_wear: int = int(tool.wear)-int(span*MATERIAL_BOOSTS[used-1])
	return {"wear":maxi(0,new_wear),"materials":used}

# The item that repairs a tool, which the source declares as `_repair_material` on
# the tool definition. Voxey keeps that mapping here.
static func repair_material(id: int) -> int:
	# Armor materials are their own ladder (0 leather, 1 iron, 2 gold, 3 diamond)
	# and are not the tool tiers, so they must be mapped separately.
	if Nodes.is_armor(id) and id != Nodes.ELYTRA:
		if id >= Netherite.ARMOR: return Netherite.INGOT
		if id in range(VillageContent.CHAIN_HELMET,VillageContent.CHAIN_HELMET+4): return Nodes.IRON
		return [Nodes.LEATHER,Nodes.IRON,Nodes.GOLD,Nodes.DIAMOND][clampi(Nodes.armor_material(id),0,3)]
	if Nodes.is_tool_id(id):
		# Netherite tools use their own ingot, as `mcl_tools` does.
		if Nodes.tool_tier(id) == 4 or id >= Netherite.TOOLS: return Netherite.INGOT
		return [Nodes.PLANKS,Nodes.COBBLE,Nodes.IRON,Nodes.DIAMOND][clampi(Nodes.tool_tier(id),0,3)]
	return 0

# Tool plus the same tool type: their health sums and a 12% bonus is added.
static func same_type_repair(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.id != b.id or Nodes.durability(a.id) <= 0: return {}
	var durability: int = Nodes.durability(a.id)
	# The source sums the *health* of both, so damage is removed accordingly.
	var total_wear: int = int(a.get("wear",0))+int(b.get("wear",0))
	var new_wear: int = maxi(0,total_wear-int(durability*SAME_TOOL_BOOST))
	return {"wear":mini(new_wear,durability),"bonus":2}

# --- rename ------------------------------------------------------------------

# A rename costs one level, and only when the name actually changes.
static func rename_cost(slot: Dictionary, new_name: String) -> int:
	return 0 if str(slot.get("data",{}).get("custom_name","")) == new_name else 1

# --- damage ladder -----------------------------------------------------------

# `damage_anvil_by_using` rolls the source's 12%. Returns the new damage level, or
# -1 when the anvil survives unharmed.
static func use_damage(level: int, rng: RandomNumberGenerator = null) -> int:
	var roll: float = rng.randf() if rng != null else randf()
	if roll >= DAMAGE_CHANCE: return -1
	# Past the last level the anvil is destroyed, which the caller reads as any value
	# at or above `MAX_DAMAGE`. Returning the level itself used to report "unharmed".
	return level+1

# `damage_anvil_by_falling`: `5 * distance` percent, and only above one block.
static func falling_damage(distance: int, rng: RandomNumberGenerator = null) -> bool:
	if distance <= 1: return false
	var roll: int = rng.randi_range(1,100) if rng != null else randi_range(1,100)
	return roll <= 5*distance

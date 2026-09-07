class_name FurnaceRules
extends RefCounted

# All insertion paths share this rule; extracting items never needs permission.
static func accepts(slots: Array, index: int, id: int) -> bool:
	if id == 0: return true
	if slots.size() != 3: return false
	if index == 1: return Nodes.fuel_time(id) > 0
	return index == 0 and int(slots[2].get("count",0)) == 0 and Nodes.smelt_result(id) != 0

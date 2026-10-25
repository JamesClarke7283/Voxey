class_name Smithing
extends RefCounted

# mcl_smithing_table/init.lua and the completed item registry, GPL-3.0-or-later.
# Slots: equipment, mineral, template, virtual output. The source's sorter is
# represented by quick_move; it never stores a second copy of an input.
static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/smithing.json"))
const REQUIRED_TRIMS = ["spire","snout","rib","ward","silence","vex","tide","wayfinder"]
const NATIVE_TEMPLATES = ["host","raiser"]
static func empty() -> Dictionary: return {"id":0,"count":0,"wear":0}
static func profile(slot: Dictionary) -> Dictionary:
	return source.profiles.get(str(int(slot.get("id",0))),{}).get("enchanted" if not slot.get("data",{}).get("enchantments",{}).is_empty() else "base",{})
static func item_name(id: int) -> String: return "" if id == 0 else str(source.profiles.get(str(id),{}).get("base",{}).get("name",""))
static func mineral(id: int) -> bool: return bool(profile({"id":id}).get("allowed",{}).get("mineral",false))
static func template(id: int) -> bool:
	return bool(profile({"id":id}).get("allowed",{}).get("template",false)) or ArmorTrims.key(id) in NATIVE_TEMPLATES
static func accepts(index: int, item: Variant, protected: bool = false) -> bool:
	if protected: return false
	var slot: Dictionary = item if item is Dictionary else {"id":int(item)}
	if int(slot.get("id",0)) == 0: return true
	if index == 3: return false
	if index == 2: return template(int(slot.id))
	return bool(profile(slot).get("allowed",{}).get("upgrade_item" if index == 0 else "mineral",false))
static func sort_index(slot: Dictionary) -> int:
	if accepts(2,slot): return 2
	if accepts(1,slot): return 1
	if accepts(0,slot): return 0
	return -1
static func sorted_count(state: Dictionary, slot: Dictionary) -> int:
	if int(slot.get("id",0)) == 0: return 0
	var index: int = sort_index(slot)
	if index < 0: return 0
	var existing: Dictionary = state.slots[index]
	if existing.id != 0 and (existing.id != slot.id or existing.wear != slot.get("wear",0) or existing.get("data",{}) != slot.get("data",{})): return 0
	return mini(int(slot.count),Nodes.max_stack(int(slot.id))-int(existing.count))
static func quick_move(state: Dictionary, slot: Dictionary) -> void:
	var amount: int = sorted_count(state,slot)
	if amount <= 0: return
	var index: int = sort_index(slot)
	if state.slots[index].id == 0: state.slots[index] = slot.duplicate(true); state.slots[index].count = 0
	state.slots[index].count += amount
	slot.count -= amount
	if slot.count == 0: slot.clear(); slot.merge(empty())
static func same_trim(slot: Dictionary, material: int, pattern: int) -> bool:
	var trim: Dictionary = ArmorTrims.trim_of(slot)
	return trim.get("overlay","") == ArmorTrims.key(pattern) and item_name(int(trim.get("material",0))) == item_name(material)
static func preview(equipment: Dictionary, material: Dictionary, pattern: Dictionary) -> Dictionary:
	if int(equipment.get("id",0)) == 0 or int(material.get("id",0)) == 0 or int(pattern.get("id",0)) == 0: return empty()
	var result: Dictionary = equipment.duplicate(true)
	var registered: Dictionary = profile(equipment)
	if material.id == Netherite.INGOT and pattern.id == Netherite.TEMPLATE:
		if not registered.get("upgradable",false): return empty()
		var upgraded: int = Netherite.upgrade_id(int(equipment.id))
		if upgraded == 0: return empty()
		var wear: int = Durability.normalized(equipment)
		result.id = upgraded; Durability.set_normalized(result,wear)
		return result
	if not template(int(pattern.id)) or pattern.id == Netherite.TEMPLATE or str(registered.get("armor","")).is_empty() or not mineral(int(material.id)) or same_trim(equipment,int(material.id),int(pattern.id)): return empty()
	# Source armor-element registrations lacking an armor texture still return
	# the input stack from upgrade_trimmed; they consume supplies without a trim.
	if registered.get("armor_texture",false):
		if not result.has("data"): result.data = {}
		result.data.trim_overlay = ArmorTrims.key(int(pattern.id)); result.data.trim_material = int(material.id)
	return result
static func refresh(state: Dictionary) -> void:
	state.slots[3] = preview(state.slots[0],state.slots[1],state.slots[2])
static func station(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.stations.has(key): world.stations[key] = VoxelWorld._new_station("smithing",4)
	return world.stations[key]
static func after_transfer(state: Dictionary, before: Array) -> Dictionary:
	var event: Dictionary = {}
	if before[3].id != 0 and int(state.slots[3].count) < int(before[3].count):
		event = {"id":int(before[3].id),"trimmed":ArmorTrims.is_trimmed(before[3]),"pattern":ArmorTrims.key(int(before[2].id))}
		for index in 3:
			state.slots[index].count = maxi(0,int(state.slots[index].count)-1)
			if state.slots[index].count == 0: state.slots[index] = empty()
	if not event.is_empty() or before[0] != state.slots[0] or before[1] != state.slots[1] or before[2] != state.slots[2]: refresh(state)
	return event
static func take(state: Dictionary) -> Dictionary:
	var before: Array = state.slots.duplicate(true); var result: Dictionary = state.slots[3].duplicate(true)
	state.slots[3] = empty()
	return {"item":result,"event":after_transfer(state,before)}
static func award(game: Node3D, event: Dictionary) -> void:
	if event.is_empty(): return
	if int(event.get("id",0)) == Netherite.TOOLS+4: game.achievements.award("serious_dedication")
	elif event.get("trimmed",false):
		game.achievements.award("crafting_a_new_look")
		if event.get("pattern","") in REQUIRED_TRIMS:
			var seen: Dictionary = game.achievements.distinct.get("smithing_with_style",{})
			for key in seen.keys():
				if key not in REQUIRED_TRIMS: seen.erase(key)
			game.achievements.distinct["smithing_with_style"] = seen
			game.achievements.counters["smithing_with_style"] = seen.size()
			game.achievements.track_distinct("smithing_with_style",event.pattern)

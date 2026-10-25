class_name VillagerFood
extends RefCounted
const POINTS = {Nodes.BREAD:4,VillageContent.POTATO:1,VillageContent.CARROT:1,VillageContent.BEETROOT:1}
static func clean(person: Dictionary) -> void:
	if not person.has("food_level"): person.food_level = int(person.get("food",0))
	person.erase("food"); person.erase("breed_time")
static func points(items: Array) -> int:
	var value: int = 0
	for item in items: value += int(POINTS.get(int(item.get("id",0)),0))*int(item.get("count",0))
	return value
static func possible(person: Dictionary, sleeping: bool = false) -> bool:
	clean(person)
	return int(person.food_level)+points(VillagerInventory.slots(person)) > 12 and not sleeping and float(person.get("age",0)) <= 0
static func eat(person: Dictionary) -> void:
	clean(person)
	if person.food_level >= 12: return
	var items: Array = VillagerInventory.slots(person)
	for i in items.size():
		var item: Dictionary = items[i]; var value: int = int(POINTS.get(int(item.get("id",0)),0))
		if value <= 0: continue
		var wanted: int = ceili((12-float(person.food_level))/value)
		# Preserve the source's point-count bound followed by ItemStack:take_item.
		var amount: int = mini(int(item.count),mini(int(item.count)*value,wanted))
		item.count -= amount; person.food_level += amount*value
		if item.count == 0: items[i] = VillagerInventory.empty()
		if person.food_level >= 12: break
static func digest(person: Dictionary) -> void:
	clean(person); person.food_level -= 12
static func take_share(items: Array, accepted: Array) -> Dictionary:
	for item in items:
		var id: int = int(item.get("id",0)); var count: int = int(item.get("count",0))
		if id not in accepted or count <= 0: continue
		var retain: int = mini(24,Nodes.max_stack(id)/2)
		if count <= retain: continue
		var stack: Dictionary = item.duplicate(true); stack.count = count-retain; item.count = retain
		return stack
	return {}
static func shared_stacks(sender: Dictionary, recipient: Dictionary) -> Array:
	var items: Array = VillagerInventory.slots(sender); var result: Array = []; var stack: Dictionary
	if points(items) > 24 and points(VillagerInventory.slots(recipient)) < 12:
		stack = take_share(items,VillagerInventory.FOOD)
		if not stack.is_empty(): result.append(stack)
	if recipient.get("profession","") == "farmer" and VillagerInventory.count(items,Nodes.GRAIN) > 32:
		stack = take_share(items,[Nodes.GRAIN])
		if not stack.is_empty(): result.append(stack)
	# The installed source indexes its numeric profession array with string
	# names in get_villager_trades, so the extra-item intersection is empty.
	return result
# The installed source's comparison permits early self-pickup, then rejects
# older self-thrown items. Do not reverse it to match its contradictory comment.
static func may_reclaim(same_donor: bool, has_time: bool, thrown: float, now: float) -> bool:
	return not same_donor or not has_time or thrown > now-2

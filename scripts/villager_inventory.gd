class_name VillagerInventory
extends RefCounted
const SIZE = 8
const FOOD = [Nodes.BREAD,VillageContent.CARROT,VillageContent.POTATO,VillageContent.BEETROOT]
const FARMER = [Nodes.BONE_MEAL,Nodes.GRAIN,Nodes.SEEDS,VillageContent.BEETROOT_SEEDS]

static func empty() -> Dictionary: return {"id":0,"count":0,"wear":0}
static func clean(value: Variant) -> Array:
	var result: Array = []
	for i in SIZE: result.append(Inventory.clean_slot(value[i]) if value is Array and i < value.size() and value[i] is Dictionary else empty())
	return result
static func slots(person: Dictionary) -> Array:
	if not person.get("inventory") is Array or person.inventory.size() != SIZE: person.inventory = clean(person.get("inventory",[]))
	return person.inventory
static func same(a: Dictionary, b: Dictionary) -> bool:
	return a.get("id",0) == b.get("id",0) and a.get("wear",0) == b.get("wear",0) and a.get("data",{}) == b.get("data",{})
static func space(items: Array, stack: Dictionary) -> bool:
	if stack.get("id",0) == 0 or stack.get("count",0) <= 0: return true
	for slot in items:
		if (int(slot.get("id",0)) == 0 and stack.count <= Nodes.max_stack(stack.id)) or (same(slot,stack) and slot.count+stack.count <= Nodes.max_stack(stack.id)): return true
	return false
static func wanted(profession: String, id: int) -> bool:
	return id in FOOD or profession == "farmer" and id in FARMER
static func add(items: Array, stack: Dictionary) -> int:
	var remaining: int = int(stack.get("count",0))
	for i in items.size():
		if remaining <= 0: break
		var slot: Dictionary = items[i]
		if slot.get("id",0) != 0 and not same(slot,stack): continue
		var room: int = Nodes.max_stack(stack.id)-(int(slot.get("count",0)) if slot.get("id",0) != 0 else 0)
		var amount: int = mini(remaining,maxi(0,room))
		if amount <= 0: continue
		if slot.get("id",0) == 0: items[i] = stack.duplicate(true); items[i].count = amount
		else: slot.count += amount
		remaining -= amount
	return remaining
static func count(items: Array, id: int) -> int:
	var total: int = 0
	for slot in items:
		if slot.get("id",0) == id: total += int(slot.get("count",0))
	return total
static func take(items: Array, id: int, amount: int) -> int:
	var removed: int = 0; var first: Dictionary = {}
	for i in items.size():
		var slot: Dictionary = items[i]
		if slot.get("id",0) != id or slot.get("count",0) <= 0: continue
		if first.is_empty(): first = slot.duplicate(true)
		elif not same(first,slot): continue
		var n: int = mini(int(slot.get("count",0)),mini(amount-removed,Nodes.max_stack(id)-removed))
		slot.count -= n; removed += n
		if slot.count == 0: items[i] = empty()
		if removed >= amount or removed >= Nodes.max_stack(id): break
	return removed
static func pickup(mob: VillageMob) -> void:
	if mob.kind != "villager": return
	var person: Dictionary = mob.game.villages.record(mob.person_key)
	if person.is_empty(): return
	var items: Array = slots(person)
	for drop in mob.game.drops.get_children():
		if not drop is ItemDrop or drop.is_queued_for_deletion() or drop.age < 1 or drop.position.distance_to(mob.position) > 1.95: continue
		if not wanted(mob.profession,drop.item_id): continue
		if not VillagerFood.may_reclaim(drop.get_meta("villager_donor",0) == mob.get_instance_id(),drop.has_meta("villager_thrown"),float(drop.get_meta("villager_thrown",0)),VillagerSocial.clock(mob.game)): continue
		var stack: Dictionary = {"id":drop.item_id,"count":drop.amount,"wear":drop.wear,"data":drop.data.duplicate(true)}
		if not space(items,stack): continue
		drop.amount = add(items,stack)
		if drop.amount <= 0: drop.queue_free()

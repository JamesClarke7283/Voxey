extends SceneTree

var names: Dictionary = {}
var failures: int = 0

func _init() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: print("PASS  "+label)
	else: failures += 1; push_error("FAIL  "+label)

func slot(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.has("id"): return {"id":0,"count":0,"wear":0}
	var enchants: Dictionary = {}
	for key in raw.get("enchantments",{}): enchants[names.get(key,key)] = int(raw.enchantments[key])
	var result: Dictionary = {"id":int(raw.id),"count":1,"wear":0,"data":{"enchantments":enchants}}
	Durability.set_normalized(result,int(raw.get("normalized",0)))
	return result

func wear(slots: Array) -> Array:
	var result: Array = []
	for item in slots: result.append(-1 if item.id == 0 else Durability.normalized(item))
	return result

func integers(values: Array) -> Array:
	return values.map(func(value):return int(value))

func run() -> void:
	for name in Enchanting.source.definitions: names[Enchanting.source.definitions[name].source_key] = name
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/durability_reference.json"))
	var matched: int = 0; var shown: int = 0
	for row in reference.wear:
		var item: Dictionary = slot({"id":row.id,"normalized":row.initial,"enchantments":{"unbreaking":row.level}})
		var actual: Array = []
		for expected in row.steps:
			Durability.use(item,row.use); actual.append(-1 if item.id == 0 else Durability.normalized(item))
		if actual == integers(row.steps): matched += 1
		elif shown < 4: shown += 1; push_error("Wear mismatch "+str(row)+" actual="+str(actual))
	check(matched == reference.wear.size(),"%d/%d native wear sequences match real Luanti ItemStacks"%[matched,reference.wear.size()])
	matched = 0; shown = 0
	for row in reference.mending:
		var slots: Array = []
		for raw in row.case.slots: slots.append(slot(raw))
		var rng := EnchantRolls.new(int(row.case.seed))
		var remaining: float = Durability.mend(slots,row.case.xp,rng)
		if remaining == row.remaining and wear(slots) == integers(row.wear) and rng.state == int(row.state): matched += 1
		elif shown < 4: shown += 1; push_error("Mending mismatch "+str(row)+" actual="+str(wear(slots))+" xp="+str(remaining)+" state="+str(rng.state))
	check(matched == reference.mending.size(),"%d/%d Mending cases match source selection, wear, XP rounding and random consumption"%[matched,reference.mending.size()])
	matched = 0; shown = 0
	var order: Array = []
	for index in reference.order: order.append(int(index)-1)
	for row in reference.armor:
		var slots: Array = []
		for raw in row.case.slots: slots.append(slot(raw))
		var rng := EnchantRolls.new(int(row.case.seed))
		var armor: Array = slots.slice(1,5)
		var remains: Callable = func(_damage): return not row.case.get("remove_source",false)
		var result: Dictionary = ArmorEffects.resolve(armor,row.case.damage,row.case.flags if row.case.flags is Dictionary else {},row.case.reason,row.case.source,rng,order,remains)
		var after: Array = [slots[0]]+armor+[slots[5]]
		if is_equal_approx(result.damage,row.damage) and result.reflected == row.reflected and wear(after) == integers(row.wear) and rng.state == int(row.state): matched += 1
		elif shown < 4: shown += 1; push_error("Armor mismatch "+str(row)+" actual="+str(result)+" wear="+str(wear(after))+" state="+str(rng.state))
	check(matched == reference.armor.size(),"%d/%d armor cases match damage, per-piece Thorns, wear and random consumption"%[matched,reference.armor.size()])
	print("DURABILITY SOURCE CHECKS: ",failures," failed")
	quit(1 if failures else 0)

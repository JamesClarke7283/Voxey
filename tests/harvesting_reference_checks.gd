extends SceneTree

func _init() -> void: call_deferred("run")

func normalized(drops: Array) -> Array:
	var amounts: Dictionary = {}
	for drop in drops: amounts[drop[0]] = int(amounts.get(drop[0],0))+int(drop[1])
	var names: Array = amounts.keys(); names.sort()
	var result: Array = []
	for name in names:
		if amounts[name] > 0: result.append([name,amounts[name]])
	return result

func declared_items(value: Variant) -> Array:
	var result: Array = []
	if value is String:
		if value.contains(":") and not value.begins_with("~"): result.append(value.get_slice(" ",0))
	elif value is Array:
		for child in value: result.append_array(declared_items(child))
	elif value is Dictionary:
		for key in value:
			if key not in ["tools","tool_groups"]: result.append_array(declared_items(value[key]))
	return result

func run() -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/harvesting_reference.json"))
	var failed: int = 0
	var matched: int = 0
	var total: int = 0
	for name in reference.eligibility:
		for id in reference.eligibility[name]:
			total += 1
			if Harvesting.can_harvest_name(name,int(id)) == reference.eligibility[name][id]: matched += 1
			else:
				failed += 1
				if failed <= 5: push_error("Harvest eligibility mismatch: "+name+" tool="+id)
	print("HARVEST ELIGIBILITY: ",matched," / ",total)
	matched = 0
	for row in reference.cases:
		var random := EnchantRolls.new(int(row.seed))
		var actual: Dictionary = Harvesting.evaluate(row.name,int(row.id),int(row.fortune),row.silk,random)
		var expected: Array = row.drops if row.drops is Array else []
		if actual.harvestable == row.eligible and actual.xp == row.xp and normalized(actual.drops) == normalized(expected) and random.state == int(row.state): matched += 1
		else:
			failed += 1
			if failed <= 10: push_error("Harvest drop mismatch: "+str(row)+" actual="+str(actual)+" state="+str(random.state))
	print("HARVEST SOURCE CASES: ",matched," / ",reference.cases.size())
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/mining_reference.json"))
	var ids: Dictionary = {}
	for row in registry.nodes: ids[row.name] = int(row.ids[0])
	var checked: int = 0
	var missing: Dictionary = {}
	for row in reference.cases:
		if not row.drops is Array: continue
		for drop in row.drops:
			checked += 1
			if Harvesting.item_id(drop[0],int(ids[row.name])) == 0: missing[drop[0]] = true
	# Also cover rare outcomes that the finite random stream did not select.
	for name in ids:
		var def: Dictionary = Harvesting.source.nodes[name]
		for field in ["drop","silk","shears","fortune"]:
			for item in declared_items(def.get(field)):
				checked += 1
				if Harvesting.item_id(item,int(ids[name])) == 0: missing[item] = true
	if not missing.is_empty():
		failed += 1
		push_error("Unmapped source drops: "+str(missing.keys()))
	print("HARVEST DROP ITEM MAPPING: ",checked," checked; ",missing.size()," missing")
	quit(1 if failed else 0)

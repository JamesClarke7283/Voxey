extends SceneTree

func _init() -> void: call_deferred("run")

func same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not same(a[i],b[i]): return false
		return true
	return a == b

func run() -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/anvil_reference.json"))
	var matches: int = 0; var failures: int = 0
	for row in reference.cases:
		var plan: Dictionary = Anvils.plan(row.case.a,row.case.b,row.case.name)
		var result: Dictionary = {}
		if not plan.is_empty():
			var output: Dictionary = plan.output.duplicate(true)
			if output.has("data"):
				output.data.erase("wear_normalized"); output.data.erase("wear_display")
				if output.data.is_empty(): output.erase("data")
			result = {"output":output,"cost":plan.cost,"consume":plan.consume,"normalized":Durability.normalized(plan.output)}
		if same(result,row.value if row.value is Dictionary else {}): matches += 1
		else:
			failures += 1
			if failures <= 10: push_error("Mismatch: "+str(row.case)+" expected="+str(row.value)+" actual="+str(result))
	print("ANVIL SOURCE CASES: %d / %d matched"%[matches,reference.cases.size()])
	quit(0 if matches == reference.cases.size() else 1)

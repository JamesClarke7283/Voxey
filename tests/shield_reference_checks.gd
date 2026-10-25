extends SceneTree
var failures: int = 0
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
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/shield_reference.json"))
	var inv := Inventory.new(); var matched: int = 0
	for row in source.cases:
		inv.grid = []
		for item in row.input: inv.grid.append(Inventory.clean_slot(item))
		var output: Dictionary = inv.take_grid_result("table")
		var ok: bool = int(output.get("id",0)) == int(row.output.id) and int(output.get("count",0)) == int(row.output.count) and int(output.get("wear",0)) == int(row.output.wear) and same(output.get("data",{}),row.output.get("data",{}))
		for i in 9: ok = ok and inv.grid[i].count == int(row.remaining[i])
		if ok: matched += 1
		else:
			failures += 1
			if failures < 7: push_error(row.label+" expected="+str(row.output)+" actual="+str(output))
	print("SHIELD SOURCE: %d/%d crafts match; %d failures" % [matched,source.cases.size(),failures])
	quit(1 if failures else 0)

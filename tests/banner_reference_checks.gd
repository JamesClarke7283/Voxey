extends SceneTree

var failures: int = 0

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

func _init() -> void: call_deferred("run")

func run() -> void:
	var inv := Inventory.new()
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/banner_reference.json"))
	if reference.limit != Banners.MAX_LAYERS: push_error("Banner layer limit differs"); failures += 1
	for key in reference.patterns:
		var expected: Dictionary = reference.patterns[key]
		var actual: Dictionary = Banners.PATTERNS[key]
		if actual.name != expected.name or actual.get("grid","") != expected.get("grid","") or Banners.key_item(key) != int(expected.get("signature",0)):
			push_error("Banner pattern differs: "+key); failures += 1
	var matched: int = 0
	for row in reference.cases:
		inv.grid = []
		for input in row.input: inv.grid.append(Inventory.clean_slot(input))
		var original: Array = inv.grid.duplicate(true)
		var output: Dictionary = inv.take_grid_result("table")
		var expected: Dictionary = row.output
		var ok: bool = int(output.get("id",0)) == int(expected.id) and int(output.get("count",0)) == int(expected.count)
		ok = ok and same(output.get("data",{}),expected.get("data",{}))
		var keep: Array = row.keep if row.keep is Array else []
		keep = keep.map(func(index): return int(index))
		for i in inv.grid.size():
			var count: int = original[i].count
			if expected.id != 0 and i not in keep: count = maxi(0,count-1)
			ok = ok and inv.grid[i].count == count
		if ok: matched += 1
		else:
			failures += 1
			if failures < 8: push_error("Banner craft differs: "+row.label+" expected="+str(expected)+" actual="+str(output))
	print("BANNER REFERENCE: %d/%d crafts match the installed source; %d failures" % [matched,reference.cases.size(),failures])
	quit(1 if failures else 0)

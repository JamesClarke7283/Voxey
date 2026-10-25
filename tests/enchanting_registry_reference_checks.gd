extends SceneTree
var failures: int = 0
var compared: int = 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	compared += 1
	if not ok:
		failures += 1
		if failures <= 18: push_error(message)
func equivalent(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b == null: return a.is_empty()
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not equivalent(a[i],b[i]): return false
		return true
	return a == b
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/enchanting_registry_reference.json"))
	for row in data.support:
		for i in data.order.size():
			var support: Vector2i = Enchanting.support(int(row.id),data.order[i],row.variant)
			var bits: int = 0 if support.x == 0 else (2 if support.y != 0 else 1)
			check(bits == int(row.values[i]),"Support differs id=%d %s enchanted=%s actual=%d expected=%d"%[int(row.id),data.order[i],row.variant,bits,int(row.values[i])])
	for row in data.applications:
		var current: Dictionary = row.current if row.current is Dictionary else {}
		for i in data.order.size(): check(Enchanting.can_apply(int(row.id),data.order[i],1,current) == (row.allowed.substr(i,1) == "1"),"Application differs id=%d current=%s add=%s"%[int(row.id),str(current),data.order[i]])
	for row in data.levels:
		for i in data.order.size():
			var name: String = data.order[i]; var max_level: int = Enchanting.source.definitions[name].max_level
			var levels: Array = [0,1,max_level,max_level+1]
			for j in levels.size(): check(Enchanting.can_apply(int(row.id),name,levels[j],{},row.variant) == bool(row.values[i][j]),"Level bound differs id=%d %s level=%d"%[int(row.id),name,levels[j]])
	for row in data.rolls:
		var current: Dictionary = row.current if row.current is Dictionary else {}
		var slot: Dictionary = {"id":int(row.id),"count":1,"data":{"enchantments":current.duplicate(true)}}
		var rng := EnchantRolls.new(int(row.seed))
		var actual: Dictionary = Enchanting.generate(slot,row.power,rng,row.treasure,row.unrestricted,row.ignore)
		var expected: Dictionary = row.value if row.value is Dictionary else {}
		check(equivalent(actual,expected) and rng.state == int(row.state),"Generation differs id=%d seed=%d current=%s actual=%s expected=%s stream=%d/%d"%[int(row.id),int(row.seed),str(current),str(actual),str(expected),rng.state,int(row.state)])
	for row in data.offers:
		var rng := EnchantRolls.new(int(row.seed))
		var actual: Array = Enchanting.generate_offers({"id":int(row.id),"count":1},int(row.shelves),rng)
		var expected: Array = []
		for value in row.value: expected.append(value if value is Dictionary else {})
		for value in actual: value.erase("glyphs")
		check(equivalent(actual,expected) and rng.state == int(row.state),"Table offers differ id=%d shelves=%d seed=%d"%[int(row.id),int(row.shelves),int(row.seed)])
	print("REGISTERED ENCHANTING SOURCE: %d item support rows, %d application rows, %d level-bound rows, %d generated cases; %d comparisons, %d failures"%[data.support.size(),data.applications.size(),data.levels.size(),data.rolls.size(),compared,failures])
	quit(1 if failures else 0)

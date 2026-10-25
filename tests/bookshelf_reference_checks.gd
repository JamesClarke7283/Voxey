extends SceneTree

class ShelfWorld extends VoxelWorld:
	func node_at(p: Vector3i) -> int: return Bookshelves.ID if p == Vector3i.ZERO else Nodes.AIR

var failures: int = 0
func _init() -> void: call_deferred("run")

func equal(a: Variant, b: Variant) -> bool:
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not equal(a[i],b[i]): return false
		return true
	return a == b

func item(row: Array) -> Dictionary:
	return Inventory.clean_slot({"id":int(row[0]),"count":int(row[1]),"wear":0,"data":{"custom_name":str(row[2])}})

func record(stack: Dictionary) -> Array:
	return [stack.get("id",0),stack.get("count",0),stack.get("data",{}).get("custom_name","")]

func setup(world: VoxelWorld, mask: int, face: int) -> void:
	world.stations.clear()
	var state: Dictionary = Bookshelves.state(world,Vector3i.ZERO); state.facing = face
	var ids: Array = [126,263,264,791]
	for i in 6: state.slots[i] = item([ids[i%4],1,"Volume "+str(i+1)]) if mask & (1 << i) else Bookshelves.empty()

func run() -> void:
	Inventory.new()
	var world := ShelfWorld.new(); world.circuits = RedstoneCircuit.new(world)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/bookshelf_reference.json"))
	var matched: int = 0
	for row in source.clicks:
		setup(world,int(row.mask),int(row.face))
		var hit := Vector3(row.hit[0],row.hit[1],row.hit[2])
		var result: Dictionary = Bookshelves.click(world,Vector3i.ZERO,Bookshelves.slot_at(hit,int(row.face)),item(row.input))
		var books: Array = Bookshelves.slots(world,Vector3i.ZERO).map(record)
		var drops: Array = [] if result.drop.is_empty() else [record(result.drop)]
		var expected_drops: Array = row.drops if row.drops is Array else []
		var ok: bool = equal(books,row.books) and equal(record(result.hand),row.hand) and equal(drops,expected_drops) and Bookshelves.comparator_output(world,Vector3i.ZERO) == int(row.last)
		if ok: matched += 1
		else:
			failures += 1
			if failures < 7: push_error("Bookshelf click differs: "+str(row)+" actual "+str(result)+" books "+str(books))
	print("BOOKSHELF CLICKS: %d/%d match source" % [matched,source.clicks.size()])
	matched = 0
	for row in source.hoppers:
		setup(world,int(row.mask),0)
		var cargo: Array = []
		for i in 5: cargo.append(item([0,0,""] if int(row.mode) == 0 else [3,64,""]))
		if int(row.mode) == 2: cargo[0] = item([126,1,"Volume 1"])
		var success: bool = Bookshelves.hopper_out(world,Vector3i.ZERO,cargo)
		var ok: bool = success == bool(row.success) and equal(Bookshelves.slots(world,Vector3i.ZERO).map(record),row.books) and equal(cargo.map(record),row.cargo) and Bookshelves.comparator_output(world,Vector3i.ZERO) == int(row.last)
		if ok: matched += 1
		else:
			failures += 1
			if failures < 7: push_error("Bookshelf hopper differs: "+str(row))
	print("BOOKSHELF HOPPERS: %d/%d match source; %d failures" % [matched,source.hoppers.size(),failures])
	matched = 0
	for row in source.insertions:
		setup(world,int(row.mask),0)
		var cargo: Array = [item([3,2,""]),Bookshelves.empty(),Bookshelves.empty(),Bookshelves.empty(),Bookshelves.empty()]
		if row.mode < 4: cargo[1] = item([[126,263,264,791][int(row.mode)],1,"Incoming"])
		var success: bool = false
		for entry in cargo:
			if Bookshelves.hopper_in(world,Vector3i.ZERO,entry): RedstoneCircuit.consume_one(entry); success = true; break
		var ok: bool = success == bool(row.success) and equal(Bookshelves.slots(world,Vector3i.ZERO).map(record),row.books) and equal(cargo.map(record),row.cargo) and Bookshelves.comparator_output(world,Vector3i.ZERO) == int(row.last)
		if ok: matched += 1
		else:
			failures += 1
			if failures < 7: push_error("Bookshelf insertion differs: "+str(row))
	print("BOOKSHELF INSERTIONS: %d/%d match source; %d failures" % [matched,source.insertions.size(),failures])
	world.free(); quit(1 if failures else 0)

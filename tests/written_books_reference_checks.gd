extends SceneTree
var failures: int = 0
func _init() -> void: call_deferred("run")
func equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not equal(a[i],b[i]): return false
		return true
	return a == b
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		if failures < 7: push_error(label)
func fields(raw: Dictionary) -> Dictionary:
	var data: Dictionary = raw.duplicate(true)
	if data.has("name"): data.custom_name = data.name; data.erase("name")
	for key in ["date","generation"]:
		if data.has(key): data[key] = int(data[key])
	return data
func run() -> void:
	var inv := Inventory.new()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/written_books_reference.json"))
	for row in source.caps:
		check(WrittenBooks.cap(row.input,int(row.limit)) == row.output,"UTF-8 cap mismatch: "+str(row.limit)+" / "+str(row.input.length()))
	for row in source.copies:
		inv.grid = []
		for i in 9: inv.grid.append({"id":0,"count":0,"wear":0})
		var where: int = int(row.where)
		inv.grid[where] = {"id":Nodes.WRITTEN_BOOK,"count":int(row.count),"wear":0,"data":fields(row.input)}
		var original: Dictionary = inv.grid[where].duplicate(true)
		var blanks: int = 0
		for i in 9:
			if i != where and blanks < int(row.copies): inv.grid[i] = {"id":Nodes.WRITABLE_BOOK,"count":1,"wear":0}; blanks += 1
		var result: Dictionary = inv.take_grid_result("table")
		var expected: Dictionary = row.output
		var ok: bool = int(result.get("id",0)) == int(expected.id) and int(result.get("count",0)) == int(expected.count)
		ok = ok and equal(result.get("data",{}),expected.get("data",{})) and equal(inv.grid[where],original)
		for i in 9: ok = ok and inv.grid[i].count == int(row.remaining[i])
		check(ok,"Book copy mismatch "+str(row.input)+" count="+str(row.count)+" copies="+str(row.copies)+" result="+str(result))
	for row in source.signs:
		var draft: Dictionary = {"id":Nodes.WRITABLE_BOOK,"count":1,"wear":0,"data":{"custom_name":"Draft label"}}
		WrittenBooks.draft(draft,row.text)
		var draft_data: Dictionary = draft.data.duplicate(true); draft_data["title"] = draft_data.get("title","")
		check(equal(draft_data,row.draft.data),"Saved draft differs from source")
		WrittenBooks.sign(draft,row.title,"The author",1700000123)
		check(draft.id == int(row.output.id) and equal(draft.data,row.output.data),"Signed metadata differs from source: "+row.title)
	for row in source.plain:
		check((int(row.count) if Bookshelves.plain_allows(int(row.id)) else 0) == int(row.put) and int(row.put) == int(row.take),"Plain-shelf put/take differs from source for item "+str(row.id))
	print("WRITTEN BOOKS SOURCE: %d copies, %d UTF-8 caps, %d signatures, %d plain-shelf cases; %d failures" % [source.copies.size(),source.caps.size(),source.signs.size(),source.plain.size(),failures])
	quit(1 if failures else 0)

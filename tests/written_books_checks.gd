extends RefCounted
static func original(generation: int = 0, count: int = 1) -> Dictionary:
	return {"id":Nodes.WRITTEN_BOOK,"count":count,"wear":0,"data":{"title":"Notes","text":"The source text.","author":"A writer","date":1700000000,"generation":generation,"custom_name":"Archive"}}
static func blank_grid(inv: Inventory) -> void:
	for i in inv.grid.size(): inv.grid[i] = {"id":0,"count":0,"wear":0}
static func run(t: SceneTree, game: Node3D) -> void:
	var inv := Inventory.new()
	for copies in range(1,9):
		blank_grid(inv); inv.grid[0] = original(0,16)
		for i in copies: inv.grid[i+1] = {"id":Nodes.WRITABLE_BOOK,"count":1,"wear":0,"data":{"text":"Discarded blank notes"}}
		var result: Dictionary = inv.take_grid_result("table")
		t.check(result.get("count",0) == copies and result.get("data",{}).get("generation",0) == 1 and result.data.author == "A writer" and result.data.date == 1700000000,"copying %d blanks produces %d authored copies" % [copies,copies])
		t.check(inv.grid[0] == original(0,16) and not result.data.has("data"),"copying retains all sixteen originals and writes flat metadata")
		var guide := Inventory.new(); guide.restore([])
		guide.add_item(Nodes.WRITTEN_BOOK,16,0,original().data); guide.add_item(Nodes.WRITABLE_BOOK,copies)
		var recipe_index: int = guide.recipe_index(Nodes.WRITTEN_BOOK)+copies-1
		var filled: bool = guide.fill_grid(recipe_index,"table")
		var copied: Dictionary = guide.take_grid_result("table") if filled else {}
		guide.grid_to_inventory()
		t.check(copied.get("count",0) == copies and guide.count_item(Nodes.WRITTEN_BOOK) == 16 and guide.count_item(Nodes.WRITABLE_BOOK) == 0,"recipe guide fits %d blanks and retains the complete original stack" % copies)
	blank_grid(inv); inv.grid[0] = original(2); inv.grid[1] = {"id":Nodes.WRITABLE_BOOK,"count":1,"wear":0}
	t.check(inv.matching_recipe("table") == -1 and inv.take_grid_result("table").is_empty() and inv.grid[1].count == 1,"a second-generation book has no craft preview and spends no blank")
	blank_grid(inv); inv.grid[0] = original(1); inv.grid[4] = {"id":Nodes.WRITABLE_BOOK,"count":1,"wear":0}
	t.check(inv.take_grid_result("hand").get("data",{}).get("generation",0) == 2,"the copy recipe works in the two-by-two hand grid")
	var legacy: Dictionary = Inventory.clean_slot({"id":Nodes.WRITTEN_BOOK,"count":1,"data":{"data":original().data}})
	t.check(legacy.data.title == "Notes" and legacy.data.author == "A writer" and legacy.data.date == 1700000000,"legacy nested book copies recover their title, author and date")
	var data: Dictionary = original().data
	t.check(Inventory.clean_slot({"id":Nodes.WRITTEN_BOOK,"count":16,"data":data}).data == data,"book metadata survives inventory cleanup without dropping its date")
	var direct := Inventory.new(); direct.restore([])
	direct.add_item(Nodes.WRITTEN_BOOK,4,0,data); direct.add_item(Nodes.WRITABLE_BOOK,1)
	var index: int = direct.recipe_index(Nodes.WRITTEN_BOOK)
	t.check(direct.craft(index,"hand") and direct.slots.any(func(item): return item.id == Nodes.WRITTEN_BOOK and item.get("data",{}).get("generation",-1) == 1) and direct.slots.any(func(item): return item.id == Nodes.WRITTEN_BOOK and item.count == 4 and item.data.generation == 0),"direct recipe crafting preserves the original stack and creates a separate copy")
	var full := Inventory.new()
	for i in full.slots.size(): full.slots[i] = {"id":Nodes.STONE,"count":64,"wear":0}
	full.slots[0] = original(0,16)
	# A blank stack can only hold one; two selected blanks free two slots, so
	# simulate the public direct path with an overfull legacy stack to test rollback.
	full.slots[1] = {"id":Nodes.WRITABLE_BOOK,"count":2,"wear":0}
	var before: Array = full.slots.duplicate(true)
	t.check(not full.craft(full.recipe_index(Nodes.WRITTEN_BOOK),"hand") and full.slots == before,"insufficient output room rolls back every input without changing the original")
	var recipe: Dictionary = inv.recipes[inv.recipe_index(Nodes.WRITABLE_BOOK)]
	t.check(recipe.ingredients.has(VillageContent.INK_SAC) and not recipe.ingredients.has(Nodes.CHARCOAL),"book-and-quill crafting uses an ink sac instead of charcoal")
	var old_grid: Array = game.inventory.grid.duplicate(true); var old_cursor: Dictionary = game.hud.cursor.duplicate(true)
	var old_shift: bool = game.hud.shift_mode; game.hud.shift_mode = false
	blank_grid(game.inventory); game.inventory.grid[0] = original(); game.inventory.grid[1] = {"id":Nodes.WRITABLE_BOOK,"count":1,"wear":0}
	game.open_inventory("table")
	game.hud.cursor = original(1); game.hud.cursor.data.title = "Another book"
	game.hud._take_output()
	t.check(game.hud.cursor.count == 1 and game.hud.cursor.data.title == "Another book" and game.inventory.grid[1].count == 1,"the output cursor cannot merge copies into a different written book")
	game.hud.cursor = {"id":Nodes.WRITTEN_BOOK,"count":15,"wear":0,"data":WrittenBooks.copy_data([original()])}
	game.hud._take_output()
	t.check(game.hud.cursor.count == 16 and game.inventory.grid[0] == original() and game.inventory.grid[1].count == 0,"matching cursor copies stack to sixteen while retaining the source book")
	game.hud.cursor = old_cursor; game.hud.shift_mode = old_shift; game.inventory.grid = old_grid
	game.resume(); game.pause()
	var saved_slots: Array = game.inventory.slots.duplicate(true); var selected: int = game.inventory.selected
	game.inventory.slots[0] = {"id":Nodes.WRITABLE_BOOK,"count":1,"wear":0,"data":{"text":"Draft"}}
	game.inventory.selected = 0; game.open_book()
	var editor: TextEdit; var title: LineEdit; var sign_button: Button
	for child in game.hud.layer.get_children().back().get_children():
		if child is TextEdit: editor = child
		elif child is LineEdit: title = child
		elif child is Button and child.text.begins_with("Sign"): sign_button = child
	var long_text: String = "x".repeat(12800)
	editor.text = long_text; editor.text_changed.emit(); title.text = "Travel notes"
	t.check(game.inventory.slots[0].data.text.length() == 12800,"the actual editor retains the source's full 12,800-character ASCII limit")
	sign_button.pressed.emit()
	var signed: Dictionary = game.inventory.slots[0]
	t.check(signed.id == Nodes.WRITTEN_BOOK and signed.data.title == "Travel notes" and signed.data.generation == 0 and signed.data.date > 0 and signed.data.author == CharacterSkin.clean(game.network.appearance).name,"the actual Sign button records author, date and original generation")
	game.open_book(); var readonly: bool = false
	for child in game.hud.layer.get_children().back().get_children():
		if child is TextEdit: readonly = not child.editable
	t.check(readonly and not WrittenBooks.sign(signed,"Changed","Other",1),"signed books stay read-only and cannot be signed again")
	game.resume(); game.pause(); game.inventory.slots = saved_slots; game.inventory.selected = selected

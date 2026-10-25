extends RefCounted

static func run(t: SceneTree, game: Node3D) -> void:
	var old_slots: Array = game.inventory.slots.duplicate(true)
	var old_cursor: Dictionary = game.hud.cursor.duplicate(true)
	var old_shift: bool = game.hud.shift_mode
	var old_selected: int = game.inventory.selected
	var p := Vector3i(8,2100,8)
	game.world.set_node(p,Nodes.BOOKSHELF)
	game.world.set_node(p+Vector3i.LEFT,Nodes.HOPPER)
	game.world.circuits.configure(p+Vector3i.LEFT,Vector3i.RIGHT)
	game.world.set_node(p+Vector3i.DOWN,Nodes.HOPPER)
	game.world.circuits.configure(p+Vector3i.DOWN,Vector3i.RIGHT)
	var shelf: Dictionary = game.world.get_station(p,"chest")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/written_books_reference.json"))
	t.check(shelf.get("books_only",false) and shelf.slots.size() == 27 and shelf.label == "BOOKSHELF","plain shelves expose a labelled 27-slot book inventory")
	for row in source.plain:
		var stack: Dictionary = {"id":int(row.id),"count":int(row.count),"wear":0}
		t.check((int(row.count) if Bookshelves.plain_allows(int(row.id)) else 0) == int(row.put) and int(row.put) == int(row.take),"plain shelf put/take matches source for item %d count %d" % [row.id,row.count])
		t.check(VoxeyNetwork.accepts_slot(shelf,"chest",0,int(row.id)) == (int(row.put) > 0),"host deposit validation uses the same source book filter")
		for entry in shelf.slots: entry.clear(); entry.merge(Bookshelves.empty())
		var hopper: Array = game.world.circuits.container(p+Vector3i.LEFT)
		hopper[0] = stack.duplicate(true)
		var pushed: bool = game.world.circuits.hopper(p+Vector3i.LEFT)
		t.check(pushed == row.push and hopper[0].count == int(row.push_remaining) and shelf.slots[0].id == 0,"plain-shelf hopper push matches the source's container-group gate")
		shelf.slots[0] = stack.duplicate(true)
		var pulled: bool = game.world.circuits.hopper(p+Vector3i.DOWN)
		t.check(pulled == row.pull and shelf.slots[0].count == int(row.pull_remaining),"plain-shelf hopper extraction matches the source's missing automatic source list")
		game.world.set_node(p+Vector3i.LEFT,Nodes.DROPPER)
		game.world.circuits.configure(p+Vector3i.LEFT,Vector3i.RIGHT)
		var dropper: Array = game.world.circuits.container(p+Vector3i.LEFT)
		dropper[0] = stack.duplicate(true)
		game.world.circuits.dispense(p+Vector3i.LEFT,false)
		t.check(dropper[0].count == int(row.dropper_remaining),"a dropper retains its item when aimed at a plain bookshelf")
		game.world.set_node(p+Vector3i.LEFT,Nodes.HOPPER)
		game.world.circuits.configure(p+Vector3i.LEFT,Vector3i.RIGHT)
	for entry in shelf.slots: entry.clear(); entry.merge(Bookshelves.empty())
	game.open_inventory("chest",p); game.hud.shift_mode = false
	for id in [Nodes.BOOK,Nodes.WRITABLE_BOOK,Nodes.WRITTEN_BOOK,VillageContent.ENCHANTED_BOOK]:
		game.hud.cursor = {"id":id,"count":1,"wear":0}
		game.hud._slot_click(0,true,false)
		t.check(shelf.slots[0].id == id and game.hud.cursor.id == 0,"the actual shelf UI accepts each source book type")
		game.hud._slot_click(0,true,false)
		t.check(game.hud.cursor.id == id and shelf.slots[0].id == 0,"the actual shelf UI returns each source book type")
	game.hud.cursor = {"id":Nodes.STONE,"count":2,"wear":0}
	game.hud._slot_click(0,true,true)
	t.check(shelf.slots[0].id == 0 and game.hud.cursor.count == 2,"a right-click cannot insert a non-book")
	shelf.slots[0] = {"id":Nodes.BOOK,"count":3,"wear":0}
	game.hud._slot_click(0,true,false)
	t.check(shelf.slots[0].id == Nodes.BOOK and game.hud.cursor.id == Nodes.STONE,"a swap cannot replace stored books with a non-book")
	game.hud.cursor = Bookshelves.empty(); game.hud.shift_mode = true
	game.inventory.slots[0] = {"id":Nodes.STONE,"count":2,"wear":0}
	game.hud._slot_click(0,false,false)
	t.check(game.inventory.slots[0].count == 2 and shelf.slots[1].id == 0,"shift-click cannot bypass plain-shelf input filtering")
	# Preserve pre-existing invalid contents for recovery by breaking the block.
	shelf.slots[1] = {"id":Nodes.STONE,"count":1,"wear":0}
	game.hud._slot_click(1,true,false)
	t.check(shelf.slots[1].id == Nodes.STONE,"legacy non-book contents remain intact when their take is refused by the source rule")
	game.hud.shift_mode = false; game.hud.cursor = Bookshelves.empty()
	game.resume(); game.pause()
	var drops_before: int = game.drops.get_child_count()
	game.break_node(p,Nodes.BOOKSHELF,0)
	var recovered: bool = false
	for i in range(drops_before,game.drops.get_child_count()):
		var drop: ItemDrop = game.drops.get_child(i)
		if drop.item_id == Nodes.STONE and drop.amount == 1: recovered = true
	t.check(recovered and not game.world.stations.has(VoxelWorld.station_key(p)),"breaking a plain shelf recovers legacy non-books and clears the old inventory")
	game.inventory.slots = old_slots; game.inventory.selected = old_selected
	game.hud.cursor = old_cursor; game.hud.shift_mode = old_shift
	for at in [p,p+Vector3i.LEFT,p+Vector3i.DOWN]:
		game.world.set_node(at,Nodes.AIR); game.world.stations.erase(VoxelWorld.station_key(at))

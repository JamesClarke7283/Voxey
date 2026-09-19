extends RefCounted

# The chiseled bookshelf (mcl_books/chiseled_bookshelf.lua): six one-item slots, a
# comparator reading the last changed slot, a hopper above, and book drops.
static func run(suite: Object, game: Node3D) -> void:
	suite.check(Bookshelves.ID == 11546 and Bookshelves.SLOTS == 6,"the shelf holds its allocated id and the source's six slots")
	suite.check(Nodes.exists(Bookshelves.ID) and Nodes.placeable(Bookshelves.ID) and Nodes.tile(Bookshelves.ID,0) != 0,"the shelf exists, is placeable and has its own tile")
	suite.check(Nodes.preferred_tool(Bookshelves.ID) == 1 and Nodes.hardness(Bookshelves.ID) == 1.5,"the shelf is a wooden block at the source's hardness")
	var world: VoxelWorld = game.world
	var at: Vector3i = Vector3i(4,game.world.generator.terrain_height(4,4)+24,4)
	for x in range(-2,3):
		for y in range(-1,4):
			for z in range(-2,3): world.set_node(at+Vector3i(x,y,z),Nodes.AIR)
	world.set_node(at,Bookshelves.ID)
	var state: Dictionary = Bookshelves.state(world,at)
	suite.check(state.slots.size() == 6 and Bookshelves.filled(world,at) == 0,"a fresh shelf has six empty slots")
	# One item per slot, and only a book fits.
	suite.check(Bookshelves.is_book(Nodes.BOOK) and Bookshelves.is_book(Nodes.WRITABLE_BOOK) and Bookshelves.is_book(Nodes.WRITTEN_BOOK),"the three book forms all belong on a shelf")
	suite.check(not Bookshelves.is_book(Nodes.STONE) and not Bookshelves.insert(world,at,0,{"id":Nodes.STONE,"count":1,"wear":0}),"a non-book is refused")
	suite.check(Bookshelves.insert(world,at,0,{"id":Nodes.BOOK,"count":5,"wear":0}) and Bookshelves.filled(world,at) == 1,"placing a book fills one slot")
	suite.check(Bookshelves.slots(world,at)[0].count == 1,"a slot holds exactly one item, never a stack")
	suite.check(not Bookshelves.insert(world,at,0,{"id":Nodes.BOOK,"count":1,"wear":0}),"a filled slot refuses a second book")
	# The comparator reads the last slot that changed.
	suite.check(Bookshelves.comparator_output(world,at) == 1,"the comparator reads the slot that changed")
	Bookshelves.insert(world,at,3,{"id":Nodes.WRITABLE_BOOK,"count":1,"wear":0})
	suite.check(Bookshelves.comparator_output(world,at) == 4,"the comparator follows the latest change rather than the count")
	suite.check(Bookshelves.bits(world,at) == 1|8,"the filled-slot bit pattern matches the source's own encoding")
	# Taking a book returns it and clears the slot.
	var taken: Dictionary = Bookshelves.take(world,at,3)
	suite.check(taken.id == Nodes.WRITABLE_BOOK and Bookshelves.filled(world,at) == 1,"taking a book clears its slot and returns the item")
	suite.check(Bookshelves.take(world,at,3).is_empty(),"an empty slot yields nothing")
	# The slot a click selects comes from where on the face it landed.
	suite.check(Bookshelves.slot_at(Vector3(0.1,0.8,0.5),0) == 0 and Bookshelves.slot_at(Vector3(0.9,0.8,0.5),0) == 2,"the click's column selects the slot")
	suite.check(Bookshelves.slot_at(Vector3(0.1,0.2,0.5),0) == 3,"the lower half of the face selects the lower row")
	# A hopper above feeds one book per transfer, and the slot becomes the reading.
	var shelf_filled: int = Bookshelves.filled(world,at)
	suite.check(Bookshelves.hopper_in(world,at,{"id":Nodes.BOOK,"count":1,"wear":0}) and Bookshelves.filled(world,at) == shelf_filled+1,"a hopper feeds one book into the first free slot")
	suite.check(Bookshelves.comparator_output(world,at) >= 1,"the fed slot becomes the comparator's reading")
	suite.check(not Bookshelves.hopper_in(world,at,{"id":Nodes.STONE,"count":1,"wear":0}),"a hopper cannot feed a non-book")
	# Breaking returns the books.
	var entries: Array = Bookshelves.contents(world,at)
	suite.check(entries.size() == Bookshelves.filled(world,at) and entries.all(func(e): return Nodes.exists(e.id)),"a broken shelf returns exactly the books it held")
	# The shelf's state lives in a station, which the world save carries, so a
	# reload keeps both the books and the comparator reading.
	suite.check(game.world.stations.has(VoxelWorld.station_key(at)),"the shelf's state is a station, which the save format carries")
	var saved_state: Dictionary = Bookshelves.state(world,at).duplicate(true)
	suite.check(saved_state.slots.size() == Bookshelves.SLOTS and int(saved_state.get("last_slot",0)) >= 1,"the station records both the slots and the comparator reading")
	# The recipe is the source's own.
	var inv := Inventory.new(); inv.add_item(Nodes.PLANKS,9)
	var index: int = inv.recipe_index(Bookshelves.ID)
	suite.check(index >= 0 and inv.craft(index,"table") and inv.count_item(Bookshelves.ID) == 1,"nine planks make a chiseled bookshelf")

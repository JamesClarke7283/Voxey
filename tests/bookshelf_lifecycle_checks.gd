extends RefCounted

static func book(name: String = "Field notes", count: int = 1) -> Dictionary:
	return {"id":Nodes.WRITTEN_BOOK,"count":count,"wear":0,"data":{"custom_name":name,"title":name,"text":"A saved chapter.","author":"Voxey","generation":1}}

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.free()

static func dropped(game: Node3D, id: int) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if drop.item_id == id and not drop.is_queued_for_deletion(): count += drop.amount
	return count

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	var inventory: Array = game.inventory.slots.duplicate(true); var selected: int = game.inventory.selected
	var old_position: Vector3 = game.player.position; var old_mode: String = game.gamemode
	var old_target: Dictionary = game.player.target.duplicate(true)
	game.gamemode = "survival"; game.inventory.selected = 0
	var world: VoxelWorld = game.world; var p := Vector3i(8,1100,8)
	for x in range(-3,4):
		for z in range(-3,4):
			for y in range(-2,3): world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(p)+Vector3(0.5,0,5)
	world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	game.inventory.slots[0] = {"id":Bookshelves.ID,"count":2,"wear":0}
	t.check(Bookshelves.place(game,{"pos":p+Vector3i.DOWN,"normal":Vector3i.UP},game.inventory,0) and Bookshelves.facing(world,p) == 2 and game.inventory.held().count == 1,"shelf placement stores the front opposite the player's view and consumes one block")
	var state: Dictionary = Bookshelves.state(world,p)
	var item: Dictionary = book()
	for face in 4:
		state.facing = face
		for i in 6:
			for j in 6: state.slots[j] = Bookshelves.empty()
			state.slots[i] = item.duplicate(true); game.inventory.slots[0] = Bookshelves.empty()
			var u: float = (i%3+0.5)/3.0; var v: float = 0.75 if i < 3 else 0.25
			var hit: Vector3 = [Vector3(u,v,0),Vector3(0,v,1-u),Vector3(1-u,v,1),Vector3(1,v,u)][face]
			t.check(Bookshelves.interact(game,p,Bookshelves.FRONTS[face],hit,game.inventory) and game.inventory.held() == item and Bookshelves.filled(world,p) == 0 and Bookshelves.comparator_output(world,p) == i+1,"front %d slot %d returns its exact authored book" % [face,i])
	state.facing = 0; state.slots[0] = item.duplicate(true)
	game.inventory.slots[0] = {"id":Nodes.BOOK,"count":3,"wear":0}
	clear_drops(game)
	t.check(Bookshelves.interact(game,p,Vector3i.FORWARD,Vector3(0.15,0.75,0),game.inventory) and Bookshelves.filled(world,p) == 0 and game.inventory.held().count == 3 and dropped(game,Nodes.WRITTEN_BOOK) == 1,"clicking a filled slot while holding another book ejects the old book without replacing it")
	t.check(game.drops.get_child(0).data == item.data,"an ejected book retains title, author, contents and generation")
	game.inventory.slots[0] = item.duplicate(true)
	t.check(not Bookshelves.interact(game,p,Vector3i.UP,Vector3(0.2,1,0.2),game.inventory) and not Bookshelves.interact(game,p,Vector3i.BACK,Vector3(0.2,0.8,1),game.inventory),"top and back faces cannot access shelf slots")
	var observer: Vector3i = p+Vector3i.BACK
	world.set_node(observer,Nodes.OBSERVER); world.circuits.configure(observer,Vector3i.BACK); world.circuits.state(observer).pulse = 0
	Bookshelves.insert(world,p,0,item)
	t.check(Bookshelves.info(world,p) == PackedStringArray(["Field notes · Voxey"]),"pointing at the shelf exposes its stored title and author")
	t.check(is_equal_approx(float(world.circuits.state(observer).pulse),0.2) and world.circuits.container_signal(p) == 1,"book insertion notifies an observer and the real comparator path")
	var comparator: Vector3i = p+Vector3i.RIGHT
	world.set_node(comparator,Nodes.COMPARATOR); world.circuits.configure(comparator,Vector3i.RIGHT)
	game.player.target = {"id":Bookshelves.ID,"pos":p,"normal":Vector3i.FORWARD,"distance":3.0}
	var overlay: Array = game.hud._overlay_state()
	Bookshelves.insert(world,p,5,item)
	t.check(game.hud._overlay_state() != overlay,"book changes refresh the pointed-at inventory text without moving the player")
	for i in 4: world.circuits.step(0.1)
	t.check(world.circuits.state(comparator).out == 6,"a live comparator emits the last changed slot rather than shelf fullness")
	world.set_node(comparator,Nodes.AIR); Bookshelves.take(world,p,5)
	var model: Node3D = Bookshelves.display_model(world,p)
	t.check(model.get_child(1).material_override.albedo_texture == Bookshelves.texture(1),"the visible shelf front shows its actual filled-slot mask")
	model.free(); world.set_node(observer,Nodes.AIR)
	# A hopper aimed into any side inserts; a hopper underneath extracts.
	world.set_node(p,Nodes.AIR); world.set_node(p,Bookshelves.ID)
	var source: Vector3i = p+Vector3i.LEFT
	world.set_node(source,Nodes.HOPPER); world.circuits.configure(source,Vector3i.RIGHT)
	var cargo: Array = world.circuits.container(source)
	cargo[0] = {"id":Nodes.STONE,"count":3,"wear":0}; cargo[1] = item.duplicate(true)
	var pushed: bool = world.circuits.hopper(source)
	t.check(pushed and cargo[0].count == 3 and cargo[1].id == 0 and Bookshelves.slots(world,p)[0] == item,"an actual side hopper skips non-books and inserts one authored book")
	var lower: Vector3i = p+Vector3i.DOWN
	world.set_node(lower,Nodes.HOPPER); world.circuits.configure(lower,Vector3i.DOWN)
	var pulled: bool = world.circuits.hopper(lower)
	t.check(pulled and Bookshelves.filled(world,p) == 0 and world.circuits.container(lower)[0] == item,"an actual lower hopper extracts the first stored book with all metadata")
	world.set_node(source,Nodes.AIR); world.set_node(lower,Nodes.AIR)
	Bookshelves.insert(world,p,2,item); state = Bookshelves.state(world,p); state.facing = 3
	var base: Vector3i = p+Vector3i.LEFT
	world.set_node(base,Nodes.PISTON); world.circuits.configure(base,Vector3i.RIGHT)
	clear_drops(game)
	var moved: bool = world.circuits.piston(base,true)
	t.check(moved and Bookshelves.slots(world,p+Vector3i.RIGHT)[2] == item and Bookshelves.facing(world,p+Vector3i.RIGHT) == 3 and Bookshelves.comparator_output(world,p+Vector3i.RIGHT) == 3,"a piston carries the exact books, facing and last-slot reading")
	t.check(game.survival.displays.has(VoxelWorld.station_key(p+Vector3i.RIGHT)) and not game.survival.displays.has(VoxelWorld.station_key(p)),"the rendered book slots move immediately with the piston")
	t.check(not world.stations.has(VoxelWorld.station_key(p)) and game.drops.get_child_count() == 0,"piston movement leaves no duplicate shelf station or books")
	world.circuits.piston(base,false); world.set_node(base,Nodes.AIR); p += Vector3i.RIGHT
	clear_drops(game); game.inventory.slots[0] = Bookshelves.empty()
	game.break_node(p,Bookshelves.ID,0)
	t.check(dropped(game,Nodes.WRITTEN_BOOK) == 1 and dropped(game,Bookshelves.ID) == 0 and not world.stations.has(VoxelWorld.station_key(p)),"a normal dig returns the book, drops no shelf and clears storage")
	clear_drops(game); world.set_node(p,Bookshelves.ID)
	game.break_node(p,Bookshelves.ID,0)
	t.check(game.drops.get_child_count() == 0,"replacing and rebreaking a shelf cannot duplicate the former contents")
	world.set_node(p,Bookshelves.ID); Bookshelves.insert(world,p,0,item)
	game.inventory.slots[0] = {"id":96,"count":1,"wear":0,"data":{"enchantments":{"Silk Touch":1}}}
	game.break_node(p,Bookshelves.ID,96)
	t.check(dropped(game,Bookshelves.ID) == 1 and dropped(game,Nodes.WRITTEN_BOOK) == 1,"Silk Touch returns the shelf plus its separate stored book")
	clear_drops(game); world.set_node(p,Bookshelves.ID); Bookshelves.insert(world,p,0,item); game.gamemode = "creative"
	game.break_node(p,Bookshelves.ID,0)
	t.check(dropped(game,Nodes.WRITTEN_BOOK) == 1 and dropped(game,Bookshelves.ID) == 0,"creative digging still releases stored books exactly once")
	clear_drops(game); game.gamemode = "survival"; world.set_node(p,Bookshelves.ID); Bookshelves.insert(world,p,0,item)
	game.explode(Vector3(p),0.75)
	t.check(dropped(game,Nodes.WRITTEN_BOOK) == 1 and dropped(game,Bookshelves.ID) == 0 and not world.stations.has(VoxelWorld.station_key(p)),"explosion destruction preserves contents without a second generic block drop")
	clear_drops(game); world.set_node(p,Bookshelves.ID); Bookshelves.insert(world,p,4,item); Bookshelves.state(world,p).facing = 1
	t.check(game.save_game("user://bookshelf_roundtrip.json"),"shelf state writes to a real world save")
	var saved: Dictionary = game.read_save("user://bookshelf_roundtrip.json")
	game.load_world_data(saved); game.set_process(true); game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	t.check(game.state != "loading" and Bookshelves.slots(game.world,p)[4] == item and Bookshelves.facing(game.world,p) == 1 and Bookshelves.comparator_output(game.world,p) == 5,"actual reload preserves authored book metadata, shelf orientation and comparator reading")
	game.world.set_node(p,Nodes.AIR)
	game.inventory.slots = inventory; game.inventory.selected = selected; game.player.position = old_position; game.gamemode = old_mode
	game.player.target = old_target

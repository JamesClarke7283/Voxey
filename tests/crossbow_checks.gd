extends RefCounted

static func equip(game: Node3D, quick: int = 0, ammo: int = Nodes.ARROW_ITEM) -> void:
	CrossbowUse.cancel(game.player); game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":VillageContent.CROSSBOW,"count":1,"wear":0,"data":{"custom_name":"Sentinel","enchantments":{"Quick Charge":quick}}}
	if ammo: game.inventory.slots[1] = {"id":ammo,"count":3,"wear":0,"data":{"custom_name":"Fletching"}}
	game.player.health = 20; game.player.target = {}; game.player.crossbow_attack_held = false
	game.player.use_cooldown = 0; game.resume()

static func load_full(game: Node3D, now: int = 100) -> void:
	CrossbowUse.begin(game.player,now)
	CrossbowUse.update(game.player,true,false,false,now+CrossbowUse.half_time(game.inventory.held()))
	CrossbowUse.update(game.player,true,false,false,now+CrossbowUse.full_time(game.inventory.held()))
	CrossbowUse.release(game.player)

static func input_mouse(button: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new(); event.button_index = button; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()

static func run(t: SceneTree, game: Node3D) -> void:
	var old_slots: Array = game.inventory.slots.duplicate(true); var old_selected: int = game.inventory.selected
	var old_position: Vector3 = game.player.position; var old_mode: String = game.gamemode
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	if not is_instance_valid(game.controls): game.controls = TouchControls.new(); game.controls.game = game; game.add_child(game.controls)
	game.gamemode = "survival"; game.touch = true; game.player.position = Vector3(8,1700,8)
	for q in 4:
		equip(game,q); var item: Dictionary = game.inventory.held()
		t.check(CrossbowUse.full_time(item) == 900000-q*130000 and CrossbowUse.half_time(item) == 350000-q*65000,"Quick Charge %d follows source draw thresholds"%q)
		CrossbowUse.begin(game.player,100)
		CrossbowUse.update(game.player,true,false,false,100+CrossbowUse.half_time(item)-1)
		t.check(CrossbowUse.current_stage(game.player) == 0,"crossbow stays at first pull before the half threshold")
		CrossbowUse.update(game.player,true,false,false,100+CrossbowUse.half_time(item))
		t.check(CrossbowUse.current_stage(game.player) == 1,"crossbow advances at the half threshold")
		CrossbowUse.release(game.player)
		t.check(not CrossbowUse.loaded(item) and game.inventory.slots[1].count == 3,"releasing an incomplete crossbow consumes nothing")
		load_full(game)
		t.check(CrossbowUse.loaded(item) and game.inventory.slots[1].count == 2 and Durability.normalized(item) == 0,"full release chambers one arrow without shooting or wear")
		t.check(item.data.loaded_arrow_data.custom_name == "Fletching" and game.hud.hotbar[0].bow_stage == 3,"loaded arrow metadata and loaded icon survive chambering")
		game.inventory.restore(JSON.parse_string(JSON.stringify(game.inventory.slots)))
		t.check(CrossbowUse.loaded(game.inventory.held()),"loaded crossbow survives JSON inventory restoration")
		var shots: Array = CrossbowUse.fire(game.player,[0.5,0.5,0.5,0.5,0.5,0.5])
		t.check(shots.size() == 1 and is_equal_approx(shots[0].velocity.length(),63) and shots[0].critical and shots[0].recoverable,"chambered crossbow fires a critical collectible arrow at source speed")
		t.check(shots[0].potion_data.custom_name == "Fletching" and Durability.normalized(game.inventory.held()) == 510,"firing transfers arrow metadata and the measured source wear")
		shots[0].stuck = true; shots[0].position = game.player.position+Vector3.UP*0.8
		shots[0]._physics_process(0.25)
		var recovered: ItemDrop = game.drops.get_children().back()
		var offhand: Dictionary = game.player.offhand_slot
		game.player.offhand_slot = {"id":Nodes.STONE,"count":64,"wear":0}
		recovered.age = 1; recovered._physics_process(0)
		game.player.offhand_slot = offhand
		t.check(game.inventory.slots[1].count == 3,"recovering a crossbow arrow preserves its item metadata")
		shots[0].free(); item = Inventory.clean_slot(game.inventory.held())
		t.check(not CrossbowUse.loaded(item) and item.data.loaded_arrow == Nodes.ARROW_ITEM and item.data.custom_name == "Sentinel","unloaded crossbow keeps historical arrow metadata without becoming loaded again")
		t.check(CrossbowUse.fire(game.player).is_empty(),"an unloaded crossbow cannot fire twice")
	equip(game); load_full(game); game.pause()
	t.check(CrossbowUse.loaded(game.inventory.held()),"menus preserve a loaded chamber")
	game.resume(); var item: Dictionary = game.inventory.held().duplicate(true)
	var dropped: bool = game.drop_stack(game.inventory.held())
	var drop: ItemDrop
	for entity in game.drops.get_children():
		if entity is ItemDrop and entity.item_id == VillageContent.CROSSBOW: drop = entity
	t.check(dropped and drop != null and CrossbowUse.loaded({"id":drop.item_id,"data":drop.data}) and drop.mesh_instance.mesh == ItemArt.mesh(VillageContent.CROSSBOW,3),"a dropped loaded crossbow preserves its chamber and loaded model")
	if drop != null: drop.free()
	# Drawing slows movement without the bow's FOV zoom; loading removes it.
	equip(game); game.gamemode = "creative"; game.player.flying = true; game.controls.stick = Vector2(0,-1)
	game.boats.reset(); game.survival.mount = null; game.player.camera.fov = 78
	CrossbowUse.begin(game.player,100)
	for i in 12: game.player._physics_process(0.1)
	t.check(is_equal_approx(game.player.velocity.length(),12*CrossbowUse.SPEED_FACTOR) and is_equal_approx(game.player.camera.fov,78),"crossbow draw uses source slowdown without a FOV zoom")
	CrossbowUse.update(game.player,true,false,false,400100); CrossbowUse.update(game.player,true,false,false,900100); CrossbowUse.release(game.player)
	game.player._physics_process(0.1)
	t.check(is_equal_approx(game.player.velocity.length(),12),"loaded crossbow restores normal movement")
	game.player.flying = false; game.controls.stick = Vector2.ZERO; game.gamemode = "survival"
	for mode in ["slot","remove","menu"]:
		equip(game); CrossbowUse.begin(game.player,100)
		if mode == "slot": game.inventory.selected = 2
		elif mode == "remove": game.inventory.slots[0] = Bookshelves.empty()
		else: game.pause()
		CrossbowUse.update(game.player,false,false,false,1000000)
		t.check(game.player.crossbow_draw.is_empty() and game.inventory.slots[1].count == 3,"%s cancels an incomplete crossbow without spending ammunition"%mode)
	# Desktop: use loads, Attack fires only on its press edge.
	equip(game); game.touch = false
	input_mouse(MOUSE_BUTTON_RIGHT,true); game.player._process(0.016)
	var start: int = game.player.crossbow_draw.start
	CrossbowUse.update(game.player,true,false,false,start+400000); CrossbowUse.update(game.player,true,false,false,start+900000)
	var count: int = game.entities.get_child_count()
	input_mouse(MOUSE_BUTTON_RIGHT,false); game.player._process(0.016)
	t.check(CrossbowUse.loaded(game.inventory.held()) and game.entities.get_child_count() == count,"actual RMB release loads without launching")
	input_mouse(MOUSE_BUTTON_RIGHT,true); game.player._process(0.016); input_mouse(MOUSE_BUTTON_RIGHT,false); game.player._process(0.016)
	t.check(CrossbowUse.loaded(game.inventory.held()),"using a loaded crossbow does not discharge it")
	input_mouse(MOUSE_BUTTON_LEFT,true); game.player._process(0.016)
	for i in 5: game.player._process(0.016)
	t.check(game.entities.get_child_count() == count+1 and not CrossbowUse.loaded(game.inventory.held()),"actual Attack fires exactly once while held")
	input_mouse(MOUSE_BUTTON_LEFT,false); game.player._process(0.016); game.entities.get_children().back().free()
	# The same two-stage controls work on touch.
	equip(game); game.touch = true; game.controls.use_held = true; game.controls.use_pressed = true; game.player._process(0.016)
	start = game.player.crossbow_draw.start
	CrossbowUse.update(game.player,true,false,false,start+400000); CrossbowUse.update(game.player,true,false,false,start+900000)
	game.controls.use_held = false; game.player._process(0.016)
	t.check(CrossbowUse.loaded(game.inventory.held()),"touch Use release chambers the arrow")
	game.controls.mine_held = true; game.player._process(0.016); game.controls.mine_held = false; game.player._process(0.016)
	t.check(not CrossbowUse.loaded(game.inventory.held()),"touch Attack fires the chambered arrow")
	game.entities.get_children().back().free()
	# Real save/load and a chest item exercise the ordinary storage path.
	equip(game); load_full(game)
	var saved_arrow: Arrow = CrossbowUse.fire(game.player)[0]
	saved_arrow.stuck = true; saved_arrow.position = game.player.position+Vector3(5,0,0)
	load_full(game); var chest := Vector3i(8,1700,5)
	game.world.set_node(chest,Nodes.CHEST)
	game.world.get_station(chest,"chest").slots[0] = game.inventory.held().duplicate(true)
	game.save_game(); game.set_process(true); game.world.set_process(true)
	game.load_world_data(game.read_save(game.saves.save_path(game.active_world_id)))
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	t.check(game.state != "loading" and CrossbowUse.loaded(game.inventory.held()) and CrossbowUse.loaded(game.world.get_station(chest,"chest").slots[0]),"both held and chest-stored loaded crossbows survive an actual world reload")
	var recovered_metadata: bool = false
	for entity in game.entities.get_children():
		if entity is Arrow and entity.potion_data.get("custom_name","") == "Fletching": recovered_metadata = true
	t.check(recovered_metadata,"a fired and grounded arrow retains its item metadata through the world save")
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.inventory.slots = old_slots; game.inventory.selected = old_selected; game.player.position = old_position; game.gamemode = old_mode

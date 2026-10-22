extends SceneTree

var game: Node3D
var passed: int = 0
var failed: int = 0
var port: int = 28000

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-hosting-tests-"+str(OS.get_process_id()))
	port += OS.get_process_id()%10000
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: passed += 1; print("PASS  "+message)
	else: failed += 1; push_error("FAIL  "+message)

func button(text_value: String) -> Button:
	return load("res://tests/world_delete_checks.gd").button(game.hud.layer,text_value)

func select_world(id: String) -> void:
	var picker: OptionButton = game.hud.layer.find_child("HostWorldPicker",true,false)
	for index in picker.item_count:
		if str(picker.get_item_metadata(index)) == id:
			picker.select(index); picker.item_selected.emit(index)
			return
	check(false,"saved world is available in the host picker")

func set_port(value: int) -> void:
	var field: SpinBox = game.hud.layer.find_child("NetworkPort",true,false)
	field.value = value

func wait_for_world() -> void:
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	check(game.state != "loading","selected world finishes loading")

func saved_world(name_value: String, seed_value: int, mode: String) -> String:
	var id: String = game.saves.create_world(name_value,seed_value,mode)
	WorldStore.write_json(game.saves.save_path(id),{
		"version":3,"world_id":id,"name":name_value,"seed":seed_value,"gamemode":mode,
		"inventory":[{"id":Nodes.DIAMOND,"count":7,"wear":0}],"position":[8.5,101.01,8.5],
		"spawn":[8.5,101.01,8.5],"edits":[[8,100,8,Nodes.STONE],[12,100,8,Nodes.DIAMOND_BLOCK]],
		"gamerules":{"keepInventory":true},"difficulty":2,"settings":{"distance":2,"audio":false}})
	return id

func screenshot(label: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args(): return
	for i in 4: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/voxey-hosting-"+label+".png")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.hud.show_multiplayer()
	check(button("Host selected world").disabled,"empty save list explains why hosting is unavailable")
	check(button("Create a world") != null,"empty host picker offers world creation")
	var first: String = saved_world("Workshop",8675309,"creative")
	var second: String = saved_world("Survival island",42,"survival")
	game.hud.show_multiplayer()
	var picker: OptionButton = game.hud.layer.find_child("HostWorldPicker",true,false)
	check(picker.item_count == 2 and not picker.disabled,"title multiplayer lists saved singleplayer worlds")
	check(not button("Host selected world").disabled,"title hosting is enabled without opening a world first")
	select_world(first); set_port(port)
	await screenshot("world-picker")
	button("Host selected world").pressed.emit()
	check(game.state == "loading" and not game.network.active(),"host waits until the selected world is loaded")
	await wait_for_world()
	check(game.network.active() and game.state == "paused","hosting from the title opens the Escape menu")
	check(game.active_world_id == first and game.world.seed_value == 8675309,"hosting opens the selected save and seed")
	check(game.world.node_at(Vector3i(12,100,8)) == Nodes.DIAMOND_BLOCK and game.inventory.count_item(Nodes.DIAMOND) == 7,"hosting keeps the saved blocks and inventory")
	check(game.gamemode == "creative" and game.game_rules.keepInventory and game.difficulty == 2,"hosting keeps the saved game mode, rules, and difficulty")
	check(game.network.server_port == port and button("Copy IP") != null,"hosted world exposes Copy IP in Escape with the chosen port")
	check(game.server_on_load == 0 and not game.show_host_menu_on_load,"completed hosting clears the pending request")
	await screenshot("escape")
	game.hud.show_multiplayer()
	check(button("Host this world").disabled,"active hosting cannot start a second server")
	game.network.stop(); game.hud.show_multiplayer()
	picker = game.hud.layer.find_child("HostWorldPicker",true,false)
	check(picker.item_count == 2 and str(picker.get_item_metadata(0)) == first,"pause picker defaults to current world without duplicate saves")
	var instance_id: int = game.world.get_instance_id()
	set_port(port+1); button("Host this world").pressed.emit()
	check(game.network.active() and game.world.get_instance_id() == instance_id,"current world starts hosting without reloading")
	game.network.stop()
	game.world.set_node(Vector3i(13,100,8),Nodes.GOLD_BLOCK)
	game.inventory.add_item(Nodes.IRON,4)
	game.hud.show_multiplayer(); select_world(second); set_port(port+2)
	button("Host selected world").pressed.emit()
	var saved: Dictionary = game.read_save(game.saves.save_path(first))
	check(saved.edits.any(func(entry): return int(entry[0]) == 13 and int(entry[1]) == 100 and int(entry[2]) == 8 and int(entry[3]) == Nodes.GOLD_BLOCK),"switching host worlds saves the current world's latest blocks")
	check(saved.inventory.any(func(slot): return int(slot.id) == Nodes.IRON and int(slot.count) == 4),"switching host worlds saves the current inventory")
	await wait_for_world()
	check(game.active_world_id == second and game.network.active() and game.gamemode == "survival","pause picker can load and host another singleplayer world")
	game.return_to_title()
	var broken: String = game.saves.create_world("Unreadable world",5,"survival")
	WorldStore.write_json(game.saves.save_path(broken),{"broken":true})
	game.hud.show_multiplayer(); select_world(broken)
	button("Host selected world").pressed.emit()
	check(game.state == "title" and not game.network.active() and game.server_on_load == 0 and not game.show_host_menu_on_load,"unreadable world cancels hosting without starting a server")
	check(game.hud.network_status_label.text.contains("Could not open"),"unreadable world reports the error in the multiplayer menu")
	var blocker := ENetMultiplayerPeer.new()
	check(blocker.create_server(port+3) == OK,"occupied-port test binds a temporary server")
	# ENet logs a native error for the intentional bind failure; the menu and
	# recovery assertions below verify that expected error without failing CI.
	var previous_errors: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	select_world(first); set_port(port+3); button("Host selected world").pressed.emit()
	await wait_for_world()
	Engine.print_error_messages = previous_errors
	check(not game.network.active() and game.state == "paused" and game.hud.screen == "multiplayer","occupied port returns to multiplayer without losing the loaded world")
	check(game.hud.network_status_label.text.contains("Could not host"),"occupied port gives a visible hosting error")
	blocker.close()
	set_port(port+3); button("Host this world").pressed.emit()
	check(game.network.active() and game.network.server_port == port+3,"hosting can be retried after a port becomes available")
	game.return_to_title()
	game.enter_world(first)
	await wait_for_world()
	check(game.state == "playing" and not game.network.active(),"opening a world normally still starts singleplayer")
	game.network.stop(); game.queue_free()
	for i in 4: await process_frame
	print("HOSTING TESTS: %d passed, %d failed"%[passed,failed])
	quit(1 if failed else 0)

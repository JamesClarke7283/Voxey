extends SceneTree

var game: Node3D
var failures: int = 0
var mode: String = "host"
var port: int = 24683
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--client": mode = "client"
		if arg.begins_with("--port="): port = int(arg.get_slice("=",1))
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-network-tests-"+mode+"-"+str(OS.get_process_id()))
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if value: print("PASS  "+message)
	else: failures += 1; push_error("FAIL  "+message)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.network.appearance = CharacterSkin.clean({"name":"Host" if mode == "host" else "Guest","shirt":"a82277","hat":true})
	if mode == "host":
		game.start_new("8675309","Network test","creative")
		var deadline: int = Time.get_ticks_msec()+90000
		while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
		check(game.network.host(port) == OK,"server binds all interfaces")
		check(game.network.local_ip().is_valid_ip_address() and game.network.join_address().ends_with(":"+str(port)),"host provides a copyable local IP and join address")
		print("NETWORK HOST READY")
		var origin := Vector3i(8,100,8)
		game.player.position = Vector3(origin)+Vector3(0.5,2,0.5); game.player.flying = true
		for x in range(-2,5):
			for z in range(-2,5): game.world.set_node(origin+Vector3i(x,0,z),Nodes.STONE)
		game.world.set_node(origin+Vector3i(2,1,0),Nodes.DIAMOND_NODE)
		game.world.set_node(origin+Vector3i(-1,1,0),Nodes.LEVER)
		var chest: Vector3i = origin+Vector3i(0,1,2)
		game.world.set_node(chest,Nodes.CHEST)
		game.game_rules.keepInventory = true
		game.world.get_station(chest,"chest").slots[0] = {"id":Nodes.IRON,"count":9,"wear":0}
		deadline = Time.get_ticks_msec()+240000
		var updated: bool = false
		while Time.get_ticks_msec() < deadline and not FileAccess.file_exists("/tmp/voxey-network-client-done-"+str(port)):
			if game.network.players.size() > 1 and not updated:
				updated = true
				GameRules.apply_settings(game,{"rules":{"keepInventory":true,"signsEditable":true,"mobGriefing":false},"name":"Updated server","max_players":8})
			await process_frame
		check(game.network.players.size() >= 2,"host sees connected guest")
		check(game.world.node_at(origin+Vector3i(1,1,0)) == Nodes.GOLD_NODE,"guest block edit reaches host")
		check(game.world.get_station(chest,"chest").slots[0].count == 8,"guest chest transaction is authoritative on host")
		check(game.world.circuits.state(origin+Vector3i(-1,1,0)).get("on",false),"guest redstone control reaches host")
		check(game.world.circuits.direction(origin+Vector3i(1,1,1)) == Vector3i.UP,"guest machine orientation reaches host")
		check(game.network.players.values().any(func(value): return value.skin.name == "Guest" and value.skin.hat),"guest character appearance reaches host")
		print("NETWORK HOST TESTS: ",failures," failed")
		game.network.stop(); game.queue_free()
		for i in 4: await process_frame
		quit(1 if failures else 0)
	else:
		check(game.network.join("127.0.0.1",port) == OK,"client starts connecting")
		var deadline: int = Time.get_ticks_msec()+240000
		while (not game.network.session_ready or game.state != "playing") and Time.get_ticks_msec() < deadline: await process_frame
		check(game.network.session_ready and game.state == "playing","guest receives and loads server world")
		if not game.network.session_ready or game.state != "playing": game.queue_free(); quit(1); return
		var origin := Vector3i(8,100,8)
		game.player.position = Vector3(origin)+Vector3(0.5,2,0.5); game.player.flying = true
		for i in 60: await process_frame
		check(game.world.node_at(origin+Vector3i(2,1,0)) == Nodes.DIAMOND_NODE,"host's initial world edits are synchronized")
		check(game.network.avatars.size() >= 1,"guest renders the host avatar")
		check(game.game_rules.keepInventory and game.game_rules.signsEditable and game.network.player_limit == 8,"host settings and game rules reach guest")
		check(not GameRules.apply_settings(game,{"name":"Forbidden"}),"guest cannot edit host settings")
		game.world.set_node(origin+Vector3i(1,1,0),Nodes.GOLD_NODE)
		game.world.set_node(origin+Vector3i(1,1,1),SteamMachines.BELLOWS)
		game.world.circuits.configure(origin+Vector3i(1,1,1),Vector3i.UP)
		game.network.use_node.rpc_id(1,origin+Vector3i(-1,1,0))
		game.open_inventory("chest",origin+Vector3i(0,1,2))
		game.hud._slot_click(0,true,true)
		deadline = Time.get_ticks_msec()+10000
		while game.hud.cursor.id != Nodes.IRON and Time.get_ticks_msec() < deadline: await process_frame
		check(game.hud.cursor.id == Nodes.IRON and game.hud.cursor.count == 5,"right-click chest transfer returns server-owned items")
		# Return four, retaining one in the cursor, to exercise serialized changes.
		for i in 4:
			game.hud._slot_click(0,true,true)
			var response_deadline: int = Time.get_ticks_msec()+5000
			while game.network.station_busy and Time.get_ticks_msec() < response_deadline: await process_frame
		game.hud.return_cursor()
		game.network.inventory_state.rpc_id(1,game.inventory.slots,game.hud.cursor,game.player.health,game.player.hunger)
		var until: int = Time.get_ticks_msec()+1200
		while Time.get_ticks_msec() < until: await process_frame
		game.network.stop(); game.state = "title"
		check(game.network.join("127.0.0.1:"+str(port)) == OK,"copied IP:port join address is accepted")
		deadline = Time.get_ticks_msec()+120000
		while (not game.network.session_ready or game.state != "playing") and Time.get_ticks_msec() < deadline: await process_frame
		check(game.network.session_ready and game.inventory.count_item(Nodes.IRON) == 1,"guest inventory survives reconnecting")
		var file := FileAccess.open("/tmp/voxey-network-client-done-"+str(port),FileAccess.WRITE); file.store_string("done"); file.close()
		for i in 60: await process_frame
		print("NETWORK CLIENT TESTS: ",failures," failed")
		game.network.stop(); game.queue_free()
		for i in 4: await process_frame
		quit(1 if failures else 0)

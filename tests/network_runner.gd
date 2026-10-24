extends SceneTree

var game: Node3D
var failures: int = 0
var mode: String = "host"
var port: int = 24683
var connect_port: int = 0
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--client": mode = "client"
		if arg.begins_with("--port="): port = int(arg.get_slice("=",1))
		if arg.begins_with("--connect-port="): connect_port = int(arg.get_slice("=",1))
	if connect_port == 0: connect_port = port
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-network-tests-"+mode+"-"+str(OS.get_process_id()))
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if value: print("PASS  "+message)
	else: failures += 1; push_error("FAIL  "+message)
func mark(name_value: String, value: String = "ready") -> void:
	var file := FileAccess.open("/tmp/voxey-network-"+str(port)+"-"+name_value,FileAccess.WRITE)
	file.store_string(value); file.close()

func stage(name_value: String) -> void:
	mark("stage",name_value)
	var deadline: int = Time.get_ticks_msec()+10000
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists("/tmp/voxey-network-"+str(port)+"-ack"):
			var file := FileAccess.open("/tmp/voxey-network-"+str(port)+"-ack",FileAccess.READ)
			if file.get_as_text() == name_value: return
		await process_frame
	check(false,"host acknowledges "+name_value)

func wait_for_count(id: int, count: int, limit: int = 10000) -> void:
	var deadline: int = Time.get_ticks_msec()+limit
	while game.inventory.count_item(id) != count and Time.get_ticks_msec() < deadline: await process_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.network.appearance = CharacterSkin.clean({"name":"Host" if mode == "host" else "Guest","shirt":"a82277","hat":true})
	if mode == "host":
		game.start_new("8675309","Network test","creative")
		var deadline: int = Time.get_ticks_msec()+90000
		while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
		var world_id: String = game.active_world_id
		game.return_to_title()
		check(game.host_world(world_id,port) == OK,"saved singleplayer world starts loading for hosting")
		deadline = Time.get_ticks_msec()+90000
		while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
		check(game.network.active() and game.state == "paused","loaded singleplayer world starts hosting and opens Escape menu")
		check(game.network.local_ip().is_valid_ip_address() and game.network.join_address().ends_with(":"+str(port)),"host provides a copyable local IP and join address")
		print("NETWORK HOST READY")
		var origin := Vector3i(8,100,8)
		game.player.position = Vector3(origin)+Vector3(0.5,2,0.5); game.player.flying = true
		for x in range(-2,5):
			for z in range(-2,5): game.world.set_node(origin+Vector3i(x,0,z),Nodes.STONE)
		game.world.set_node(origin+Vector3i(2,1,0),Nodes.DIAMOND_NODE)
		game.world.set_node(origin+Vector3i(3,1,0),Nodes.STONE)
		game.world.set_node(origin+Vector3i(4,1,0),Nodes.DIRT)
		game.inventory.slots[0] = {"id":Nodes.TOOLS+15,"count":1,"wear":0,"data":{"enchantments":{"Silk Touch":1}}}
		game.inventory.selected = 0
		game.world.set_node(origin+Vector3i(-1,1,0),Nodes.LEVER)
		var chest: Vector3i = origin+Vector3i(0,1,2)
		game.world.set_node(chest,Nodes.CHEST)
		game.game_rules.keepInventory = true
		game.world.get_station(chest,"chest").slots[0] = {"id":Nodes.IRON,"count":9,"wear":0}
		deadline = Time.get_ticks_msec()+240000
		var updated: bool = false
		var previous_stage: String = ""
		var held_inventory: Array = []
		while Time.get_ticks_msec() < deadline and not FileAccess.file_exists("/tmp/voxey-network-client-done-"+str(port)):
			if game.network.players.size() > 1 and not updated:
				updated = true
				GameRules.apply_settings(game,{"rules":{"keepInventory":true,"signsEditable":true,"mobGriefing":false},"name":"Updated server","max_players":8,"gamemode":"survival"})
			var stage_path: String = "/tmp/voxey-network-"+str(port)+"-stage"
			if FileAccess.file_exists(stage_path):
				var file := FileAccess.open(stage_path,FileAccess.READ)
				var requested: String = file.get_as_text()
				if requested != previous_stage:
					previous_stage = requested
					var guest: int = 0
					for peer in game.network.players:
						if peer != 1: guest = peer; break
					match requested:
						"give":
							game.inventory.slots[1] = {"id":Nodes.GOLD,"count":5,"wear":0,"data":{"custom_name":"Parcel"}}
							game.inventory.selected = 1
							check(game.network.pass_held(guest),"host can hand an item directly to a guest")
							check(game.network.pass_held(guest),"host can queue another handover before its first receipt")
						"position":
							check(game.network.players[guest].position.distance_to(Vector3(origin+Vector3i(3,1,0))+Vector3(0.5,0.2,0.5)) < 0.1,"stale movement packets do not move a player backwards")
						"saved":
							check(game.network._bag(guest).count_item(Nodes.GOLD) == 2,"stale inventory snapshots cannot erase a received item")
						"drop":
							# File markers can arrive before the client's reliable RPCs
							# when the impairment relay delays those packets.
							await wait_for_count(Nodes.GOLD,5)
							check(game.inventory.count_item(Nodes.GOLD) == 5,"guest's handover reaches the host inventory")
							game.drop_stack(game.inventory.slots[1],2)
							for drop in game.drops.get_children():
								if drop.data.get("custom_name","") == "Parcel": drop.position = game.network.players[guest].position+Vector3.UP*0.8; drop.velocity = Vector3.ZERO
						"full":
							held_inventory = game.inventory.slots.duplicate(true)
							for slot in game.inventory.slots: slot.clear(); slot.merge({"id":Nodes.COBBLE,"count":64,"wear":0})
						"restore": game.inventory.restore(held_inventory)
						"collect":
							for drop in game.drops.get_children():
								if drop.data.get("custom_name","") == "Parcel": game.player.position = drop.position-Vector3.UP*0.8; drop.velocity = Vector3.ZERO
					mark("ack",requested)
			await process_frame
		check(game.network.players.size() >= 2,"host sees connected guest")
		check(game.world.node_at(origin+Vector3i(1,1,0)) == Nodes.GOLD_NODE,"guest block edit reaches host")
		check(game.world.get_station(chest,"chest").slots[0].count == 8,"guest chest transaction is authoritative on host")
		check(game.world.circuits.state(origin+Vector3i(-1,1,0)).get("on",false),"guest redstone control reaches host")
		check(game.world.circuits.direction(origin+Vector3i(1,1,1)) == Vector3i.UP,"guest machine orientation reaches host")
		check(game.network.players.values().any(func(value): return value.skin.name == "Guest" and value.skin.hat),"guest character appearance reaches host")
		check(game.world.node_at(origin+Vector3i(3,1,0)) == Nodes.AIR,"guest mining removes stone on the host")
		check(game.inventory.count_item(Nodes.GOLD) == 4,"guest-dropped item is picked up by the paused host")
		deadline = Time.get_ticks_msec()+5000
		while game.network.avatars.size() != 1 and Time.get_ticks_msec() < deadline: await process_frame
		check(game.network.avatars.size() == 1,"reconnection does not leave an extra player avatar")
		print("NETWORK HOST TESTS: ",failures," failed")
		game.network.stop(); game.queue_free()
		for i in 4: await process_frame
		quit(1 if failures else 0)
	else:
		check(game.network.join("127.0.0.1",connect_port) == OK,"client starts connecting")
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
		game.hud.return_cursor(); game.resume()
		game.player.set_process(false); game.player.set_physics_process(false)
		game.inventory.add_item(Nodes.TOOLS+5,1)
		var mining_index: int = 0
		for index in game.inventory.slots.size():
			if game.inventory.slots[index].id == Nodes.TOOLS+5: mining_index = index
		game.inventory.selected = mining_index
		var stone: Vector3i = origin+Vector3i(3,1,0)
		game.player.target = {"pos":stone,"id":Nodes.STONE,"normal":Vector3i.UP}
		game.player.mine(10.0)
		deadline = Time.get_ticks_msec()+10000
		while not game.network.pending_breaks.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
		check(game.world.node_at(stone) == Nodes.AIR,"guest can mine stone through the player mining input")
		check(game.inventory.slots[mining_index].wear == 1,"successful guest mining wears the guest's tool once")
		game.player.position = Vector3(stone)+Vector3(0.5,0.2,0.5)
		await wait_for_count(Nodes.COBBLE,1)
		check(game.inventory.count_item(Nodes.COBBLE) == 1 and game.inventory.count_item(Nodes.STONE) == 0,"guest collects cobblestone using their own tool, while host is paused")
		var stale_stone: Vector3i = origin+Vector3i(4,1,0)
		game.network.applying = true; game.world.set_node(stale_stone,Nodes.STONE); game.network.applying = false
		game.player.target = {"pos":stale_stone,"id":Nodes.STONE,"normal":Vector3i.UP}
		game.player.mine(10.0)
		deadline = Time.get_ticks_msec()+10000
		while not game.network.pending_breaks.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
		check(game.world.node_at(stale_stone) == Nodes.DIRT and game.inventory.slots[mining_index].wear == 1,"a rejected stale block is corrected without wearing the mining tool")
		game.network.timer = -100.0
		var motion: int = game.network._next_motion_sequence()
		game.network.player_state.rpc_id(1,{"position":game.player.position,"yaw":0.0,"skin":game.network.appearance,"motion":motion})
		game.network.player_state.rpc_id(1,{"position":game.player.position+Vector3.RIGHT*30,"yaw":0.0,"skin":game.network.appearance,"motion":motion-1})
		var arrival: int = Time.get_ticks_msec()+250
		while Time.get_ticks_msec() < arrival: await process_frame
		await stage("position")
		game.network.timer = 0.0
		var stale: Dictionary = game.network.inventory_snapshot()
		await stage("give")
		await wait_for_count(Nodes.GOLD,2)
		check(game.inventory.count_item(Nodes.GOLD) == 2,"queued host handovers each arrive once in guest inventory")
		var gift_index: int = -1
		for index in game.inventory.slots.size():
			if game.inventory.slots[index].id == Nodes.GOLD: gift_index = index
		check(gift_index >= 0 and game.inventory.slots[gift_index].get("data",{}).get("custom_name","") == "Parcel","handover preserves item metadata")
		stale.sequence = game.network.inventory_sequence+100
		game.network.inventory_state.rpc_id(1,stale)
		await stage("saved")
		game.inventory.selected = gift_index
		game.player.camera.look_at(game.network.players[1].position+Vector3.UP*0.9)
		game.player.target = game.world.raycast(game.player.camera.global_position,-game.player.camera.global_basis.z,5)
		check(game.network.target_player() == 1,"aiming at a nearby player selects them for handover")
		game.player.use()
		await wait_for_count(Nodes.GOLD,1)
		check(game.inventory.count_item(Nodes.GOLD) == 1,"right-click handover consumes one item")
		game.network.pass_held(1,true)
		await wait_for_count(Nodes.GOLD,0)
		check(game.inventory.count_item(Nodes.GOLD) == 0,"whole-stack handover consumes the remaining stack")
		await stage("drop")
		await wait_for_count(Nodes.GOLD,2)
		check(game.inventory.count_item(Nodes.GOLD) == 2,"thrown items become collectible even while the host has Escape open")
		await stage("full")
		for index in game.inventory.slots.size():
			if game.inventory.slots[index].id == Nodes.GOLD: game.inventory.selected = index
		game.network.pass_held(1,true)
		await wait_for_count(Nodes.GOLD,2)
		check(game.inventory.count_item(Nodes.GOLD) == 2,"a full recipient inventory returns the entire offered stack")
		await stage("restore")
		for index in game.inventory.slots.size():
			if game.inventory.slots[index].id == Nodes.GOLD: game.inventory.selected = index
		game.drop_stack(game.inventory.held(),1)
		var pause_until: int = Time.get_ticks_msec()+500
		while Time.get_ticks_msec() < pause_until: await process_frame
		game.player.position = Vector3(origin)+Vector3(9,2,0)
		await stage("collect")
		check(game.inventory.count_item(Nodes.GOLD) == 1,"guest dropping an item consumes it once")
		game.network.send_inventory()
		var until: int = Time.get_ticks_msec()+1200
		while Time.get_ticks_msec() < until: await process_frame
		game.network.stop(); game.state = "title"
		check(game.network.join("127.0.0.1:"+str(connect_port)) == OK,"copied IP:port join address is accepted")
		deadline = Time.get_ticks_msec()+120000
		while (not game.network.session_ready or game.state != "playing") and Time.get_ticks_msec() < deadline: await process_frame
		print("RECONNECTED INVENTORY: iron=",game.inventory.count_item(Nodes.IRON)," gold=",game.inventory.count_item(Nodes.GOLD)," cobble=",game.inventory.count_item(Nodes.COBBLE))
		check(game.network.session_ready and game.inventory.count_item(Nodes.IRON) == 1 and game.inventory.count_item(Nodes.GOLD) == 1 and game.inventory.count_item(Nodes.COBBLE) == 1,"mined and transferred inventory survives reconnecting")
		var file := FileAccess.open("/tmp/voxey-network-client-done-"+str(port),FileAccess.WRITE); file.store_string("done"); file.close()
		for i in 60: await process_frame
		print("NETWORK CLIENT TESTS: ",failures," failed")
		game.network.stop(); game.queue_free()
		for i in 4: await process_frame
		quit(1 if failures else 0)

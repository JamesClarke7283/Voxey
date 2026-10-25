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

# Test deliveries can fill the first hotbar. Place a selected bag item in a
# real hotbar slot before invoking the same held-item RPC that the UI uses.
func select_slot(index: int) -> void:
	if index >= 9:
		var previous: Dictionary = game.inventory.slots[0]
		game.inventory.slots[0] = game.inventory.slots[index]
		game.inventory.slots[index] = previous
		game.inventory.selected = 0
	else: game.inventory.selected = index

func map_slot(id: String) -> int:
	for i in game.inventory.slots.size():
		var item: Dictionary = game.inventory.slots[i]
		if item.id == VillageContent.FILLED_MAP and str(item.get("data",{}).get("map",{}).get("id","")) == id: return i
	return -1

func wait_map(id: String) -> String:
	var deadline: int = Time.get_ticks_msec()+30000
	while str(game.maps.records.get(id,{}).get("png","")).is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	return str(game.maps.records.get(id,{}).get("png",""))

func check_guest_maps() -> Dictionary:
	await stage("maps")
	await wait_for_count(VillageContent.EMPTY_MAP,2)
	game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = Vector3(8.5,650,8.5)
	for i in game.inventory.slots.size():
		if game.inventory.slots[i].id == VillageContent.EMPTY_MAP: select_slot(i); break
	check(game.maps.use(),"guest requests a host-owned map from its held empty stack")
	var deadline: int = Time.get_ticks_msec()+10000
	while game.network.map_busy and Time.get_ticks_msec() < deadline: await process_frame
	var first: Dictionary = {}
	for item in game.inventory.slots:
		if item.id == VillageContent.FILLED_MAP: first = item.duplicate(true); break
	var id: String = str(first.get("data",{}).get("map",{}).get("id",""))
	check(not id.is_empty() and first.data.map.min == [0,640,0] and first.data.map.positive_z and game.inventory.count_item(VillageContent.EMPTY_MAP) == 1,"guest receives the host's ID and aligned map after consuming exactly one empty map")
	var png: String = await wait_map(id)
	check(not png.is_empty() and game.maps.job.is_empty() and game.maps.builds.is_empty(),"host finishes and sends its image while the guest runs no survey")
	if not png.is_empty():
		var pixels := Image.new(); pixels.load_png_from_buffer(Marshalls.base64_to_raw(png))
		check(pixels.get_pixel(9,118).is_equal_approx(ExplorationMaps.map_color(Nodes.GOLD_BLOCK)),"guest image contains the host's captured gold block with source north orientation")
	game.resume()
	await stage("maps_edit")
	await wait_for_count(VillageContent.EMPTY_MAP,3)
	for i in game.inventory.slots.size():
		if game.inventory.slots[i].id == VillageContent.EMPTY_MAP: select_slot(i); break
	game.maps.use()
	deadline = Time.get_ticks_msec()+10000
	while game.network.map_busy and Time.get_ticks_msec() < deadline: await process_frame
	var second_id: String = ""
	for item in game.inventory.slots:
		if item.id == VillageContent.FILLED_MAP and item.data.map.id != id: second_id = item.data.map.id
	var second_png: String = await wait_map(second_id)
	check(not second_id.is_empty() and second_id != id and not second_png.is_empty() and second_png != png and game.maps.records[id].png == png,"a second guest survey gets a unique global ID without changing the first snapshot")
	game.survival.show_station(Vector3i(10,650,8),VillageContent.CARTOGRAPHY_TABLE)
	game.maps.copy_map(map_slot(id))
	deadline = Time.get_ticks_msec()+10000
	while game.network.map_busy and Time.get_ticks_msec() < deadline: await process_frame
	var copied_index: int = map_slot(id)
	check(copied_index >= 0 and game.inventory.slots[copied_index].count == 2 and game.inventory.count_item(VillageContent.EMPTY_MAP) == 1 and game.maps.records[id].png == png,"guest table copy stacks identical metadata and consumes one empty map on the host")
	game.survival.workstation_pos = Vector3i(100,650,100)
	game.maps.copy_map(copied_index)
	deadline = Time.get_ticks_msec()+10000
	while game.network.map_busy and Time.get_ticks_msec() < deadline: await process_frame
	check(game.inventory.slots[map_slot(id)].count == 2 and game.inventory.count_item(VillageContent.EMPTY_MAP) == 1,"an unreachable cartography table cannot consume or duplicate guest maps")
	var missing_id: String = "999999"
	var missing: Dictionary = first.duplicate(true); missing.data.map.id = missing_id
	game.maps.ensure(missing)
	deadline = Time.get_ticks_msec()+10000
	while not game.maps.records.get(missing_id,{}).get("missing",false) and Time.get_ticks_msec() < deadline: await process_frame
	check(game.maps.records.get(missing_id,{}).get("missing",false) and game.maps.job.is_empty(),"unknown host map IDs stay unavailable instead of resurveying guest terrain")
	game.maps.records.clear(); game.maps.textures.clear(); game.network.requested_maps.clear()
	game.maps.ensure(game.inventory.slots[map_slot(id)])
	check(await wait_map(id) == png,"clearing the guest cache downloads the original host image")
	await stage("maps_copied")
	game.resume(); game.player.position = Vector3(8.5,102,8.5)
	game.player.set_process(true); game.player.set_physics_process(true)
	return {"id":id,"png":png}

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	if not is_instance_valid(game.controls): game.controls = TouchControls.new(); game.controls.game = game; game.add_child(game.controls)
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
		var wall: Vector3i = origin+Vector3i(-2,1,4)
		game.world.set_node(wall+Vector3i.LEFT,Nodes.STONE); game.world.set_node(wall+Vector3i.RIGHT,Nodes.STONE)
		game.world.set_node(wall+Vector3i.UP,Nodes.STONE)
		game.world.set_node(wall,BarrierCatalog.wall_for(ShapeMaterials.RED_SANDSTONE))
		game.world.set_node(origin+Vector3i(-2,1,2),WoodTypes.FENCE_BASES[0])
		game.world.set_node(origin+Vector3i(2,1,3),Stonecutting.placed(1))
		game.world.get_station(origin+Vector3i(2,1,3),"stonecutter").slots[0] = {"id":Nodes.COPPER_NODE,"count":3,"wear":0,"data":{"copper_waxed":true}}
		var grinder: Vector3i = origin+Vector3i(12,1,0)
		for x in range(4,17):
			for z in range(-2,3): game.world.set_node(origin+Vector3i(x,0,z),Nodes.STONE)
		game.world.set_node(grinder,GrindstoneRepair.placed(13))
		var grind: Dictionary = game.world.get_station(grinder,"grindstone")
		grind.slots[0] = {"id":Nodes.TOOLS+10,"count":1,"wear":200,"data":{"enchantments":{"Efficiency":3,"Curse of Vanishing":1},"custom_name":"Guest tool","pwp":5}}
		grind.slots[1] = {"id":Nodes.TOOLS+10,"count":1,"wear":0}
		var smith_at: Vector3i = origin+Vector3i(3,1,3)
		game.world.set_node(smith_at,VillageContent.SMITHING_TABLE)
		var smith: Dictionary = game.world.get_station(smith_at,"smithing")
		smith.slots[0] = {"id":99,"count":1,"wear":0,"data":{"custom_name":"Network hoe","enchantments":{"Efficiency":2},"pwp":3}}
		Durability.set_normalized(smith.slots[0],22222)
		smith.slots[1] = {"id":Netherite.INGOT,"count":2,"wear":0}
		smith.slots[2] = {"id":Netherite.TEMPLATE,"count":2,"wear":0}
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
		var melee_probe: Creature
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
						"maps":
							game.world.set_node(Vector3i(9,650,9),Nodes.GOLD_BLOCK)
							game.world.set_node(Vector3i(10,650,8),VillageContent.CARTOGRAPHY_TABLE)
							game.network._deliver(guest,{"id":VillageContent.EMPTY_MAP,"count":2,"wear":0},2)
						"maps_edit":
							game.world.set_node(Vector3i(9,650,9),Nodes.STONE)
							game.network._deliver(guest,{"id":VillageContent.EMPTY_MAP,"count":2,"wear":0},2)
						"maps_copied":
							var bag: Inventory = game.network._bag(guest)
							check(bag.count_item(VillageContent.FILLED_MAP) == 3 and bag.count_item(VillageContent.EMPTY_MAP) == 1 and game.maps.next_id == 2,"host owns both guest surveys and exact copy inventory")
						"soil":
							var soil: Vector3i = origin+Vector3i(0,1,-2)
							game.world.set_node(soil,Farmland.WET); game.world.set_node(soil+Vector3i.UP,Nodes.AIR)
							game.world.set_node(soil+Vector3i.LEFT,Nodes.STONE)
							game.world.set_node(soil+Vector3i.LEFT+Vector3i.UP,VillageContent.COMPOSTER)
						"soil_verified":
							var soil: Vector3i = origin+Vector3i(0,1,-2)
							check(game.world.node_at(soil) == Nodes.DIRT and game.world.node_at(soil+Vector3i.LEFT) == Nodes.DIRT,"host applies both source dirtifier callbacks to guest placements")
							Farmland.reset(game.world)
							var plot: Vector3i = origin+Vector3i(0,4,-2)
							game.world.set_node(plot,Farmland.DRY); game.world.set_node(plot+Vector3i.RIGHT,Nodes.WATER)
							Farmland.state(game.world,plot).remaining = 0
							var rng := RandomNumberGenerator.new()
							for seed in 100:
								rng.seed = seed
								if rng.randi_range(1,4) == 1: Farmland.runtime(game.world).rng.seed = seed; break
							Farmland.update(game.world,0.01)
							check(game.state == "paused" and game.world.node_at(plot) == Farmland.WET,"host soil continues its authoritative hydration while Escape is open")
						"banner":
							var banner: Dictionary = load("res://tests/banner_checks.gd").patterned(2)
							game.network._deliver(guest,banner,1)
						"banner_placed":
							var at: Vector3i = origin+Vector3i(-2,1,-1)
							check(Banners.is_banner(game.world.node_at(at)) and Banners.stored_item(game.world,at).data == load("res://tests/banner_checks.gd").patterned().data,"host receives the guest's exact banner design and custom name")
						"banner_rotated":
							check(Banners.station(game.world,origin+Vector3i(-2,1,-1)).rotation == posmod(Banners.rotation_level(0.7)-1,16),"host receives guest banner rotation")
						"bookshelf":
							game.network._deliver(guest,{"id":Bookshelves.ID,"count":1,"wear":0},1)
							var volume: Dictionary = load("res://tests/bookshelf_lifecycle_checks.gd").book("Network volume")
							volume.data.date = 1700000000
							game.network._deliver(guest,volume,1)
						"book_stored":
							var shelf: Dictionary = Bookshelves.state(game.world,origin+Vector3i(-2,1,1))
							check(shelf.facing == 2 and shelf.slots[0].data.get("text","") == "A saved chapter." and shelf.slots[0].data.get("author","") == "Voxey","host stores the guest's selected slot, shelf facing and complete authored book")
						"book_turned":
							check(Bookshelves.facing(game.world,origin+Vector3i(-2,1,1)) == 3,"host rotates the bookshelf without losing its inventory")
						"plain_shelf":
							game.world.set_node(origin+Vector3i(2,1,2),Nodes.BOOKSHELF)
						"plain_shelf_stored":
							var shelf: Dictionary = game.world.get_station(origin+Vector3i(2,1,2),"chest")
							check(shelf.books_only and shelf.slots[0].id == Nodes.WRITTEN_BOOK and shelf.slots[0].data.generation == 2,"host stores the guest's copied book in the plain shelf")
						"furnace":
							var at: Vector3i = origin+Vector3i(1,1,2)
							game.world.set_node(at,Nodes.FURNACE)
							var furnace: Dictionary = game.world.get_station(at,"furnace")
							furnace.slots[2] = {"id":Nodes.BRICK_ITEM,"count":2,"wear":0}; furnace.xp = 7
						"furnace_taken":
							var furnace: Dictionary = game.world.get_station(origin+Vector3i(1,1,2),"furnace")
							check(furnace.slots[2].count == 0 and not furnace.has("xp"),"host consumes the guest's furnace output and stored XP once")
						"shield_equipped":
							var shield_deadline: int = Time.get_ticks_msec()+5000
							while (not game.network.shield_equipment.get(guest,{}).get("offhand",{}).get("data",{}).has("shield_color") or not game.network.shield_equipment.get(guest,{}).get("raised",false)) and Time.get_ticks_msec() < shield_deadline: await process_frame
							var item: Dictionary = game.network.shield_equipment.get(guest,{}).get("offhand",{})
							check(item.get("data",{}).get("shield_color",-1) == 6 and Banners.layers(item).size() == 2,"host receives the guest's decorated offhand shield appearance")
							check(game.network.avatars.has(guest) and game.network.avatars[guest].shield_nodes.has("offhand"),"host renders the guest's shield on its multiplayer avatar")
							check(game.network.shield_equipment.get(guest,{}).get("raised",false) and is_equal_approx(game.network.avatars[guest].shield_nodes.offhand.position.y,1.1),"the remote shield uses the guest's raised pose")
						"shield_saved":
							var saved_deadline: int = Time.get_ticks_msec()+5000
							var saved_guest: Dictionary = {}
							while Time.get_ticks_msec() < saved_deadline:
								saved_guest = game.world.adventure_state.get("network_players",{}).get(game.network.peer_identity.get(guest,""),{})
								if saved_guest.get("experience",0) == 1451 and saved_guest.get("offhand",{}).get("data",{}).get("shield_color",-1) == 6: break
								await process_frame
							check(saved_guest.get("experience",0) == 1451 and saved_guest.get("offhand",{}).get("data",{}).get("shield_color",-1) == 6,"host persists the guest's experience and decorated second hand before disconnect")
						"melee":
							melee_probe = game.spawn_creature("cow",game.network.players[guest].position+Vector3(0,0,2))
							melee_probe.set_physics_process(false); melee_probe.health = 100
							mark("melee_target",str(melee_probe.get_instance_id()))
						"melee_result":
							var hit_deadline: int = Time.get_ticks_msec()+5000
							while is_equal_approx(melee_probe.health,100) and Time.get_ticks_msec() < hit_deadline: await process_frame
							check(is_equal_approx(melee_probe.health,92),"remote melee retains the resolved damage and Breach through its RPC")
							melee_probe.queue_free()
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
		mark("verified")
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
		var avatar_deadline: int = Time.get_ticks_msec()+5000
		while game.network.avatars.is_empty() and Time.get_ticks_msec() < avatar_deadline: await process_frame
		check(game.world.node_at(origin+Vector3i(2,1,0)) == Nodes.DIAMOND_NODE,"host's initial world edits are synchronized")
		var wall: Vector3i = origin+Vector3i(-2,1,4)
		check(BarrierCatalog.info(game.world.node_at(wall)).get("state","") == "tall_flat","host wall variants reach the guest")
		check(game.world.node_at(origin+Vector3i(-2,1,2)) == WoodTypes.FENCE_BASES[0],"relocated cherry fence reaches the guest as wood")
		game.world.set_node(wall+Vector3i.UP,Nodes.AIR)
		var wall_deadline: int = Time.get_ticks_msec()+10000
		while BarrierCatalog.info(game.world.node_at(wall)).get("state","") != "short_flat" and Time.get_ticks_msec() < wall_deadline: await process_frame
		check(BarrierCatalog.info(game.world.node_at(wall)).get("state","") == "short_flat","host-derived wall state follows a guest's neighbor edit")
		var cutter: Vector3i = origin+Vector3i(2,1,3)
		check(Stonecutting.facing(game.world.node_at(cutter)) == 1,"guest receives the oriented stonecutter")
		game.world.set_node(cutter,Stonecutting.placed(20))
		var rotate_deadline: int = Time.get_ticks_msec()+10000
		while not game.network.pending_requests.is_empty() and Time.get_ticks_msec() < rotate_deadline: await process_frame
		check(Stonecutting.facing(game.world.node_at(cutter)) == 20,"server accepts a rotated stonecutter and retains its input")
		game.open_inventory("stonecutter",origin+Vector3i(2,1,3))
		var cut_deadline: int = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < cut_deadline: await process_frame
		game.hud._select_cut("mcl_copper:block_grate_preserved")
		cut_deadline = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < cut_deadline: await process_frame
		check(game.hud.station_data.slots[1].count == 4,"guest selects a server-owned stonecutting preview")
		game.hud._fill_cut()
		cut_deadline = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < cut_deadline: await process_frame
		check(game.hud.station_data.slots[1].count == 12,"guest fills virtual output without consuming material")
		game.hud._slot_click(1,true,true)
		cut_deadline = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < cut_deadline: await process_frame
		check(game.hud.cursor.count == 6 and Copper.waxed_item(game.hud.cursor) and game.hud.station_data.slots[0].count == 1 and game.hud.station_data.slots[1].id == 0,"guest output withdrawal preserves wax and consumes rounded input exactly once")
		game.hud._slot_click(1,true,false)
		cut_deadline = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < cut_deadline: await process_frame
		check(game.hud.cursor.count == 6 and game.hud.station_data.slots[1].id == 0,"server rejects inserting into a stonecutter output")
		game.hud.return_cursor(); game.resume()

		var grinder: Vector3i = origin+Vector3i(12,1,0)
		game.player.position = Vector3(grinder)+Vector3(-7.6,0,0)
		for i in 60: await process_frame
		game.open_inventory("grindstone",grinder)
		var grind_deadline: int = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < grind_deadline: await process_frame
		check(game.hud.station_data.slots.size() == 3 and game.hud.station_data.slots[2].id == Nodes.TOOLS+10,"guest receives a server-computed grindstone preview")
		var grind_xp: float = game.experience
		game.hud._slot_click(2,true,false)
		grind_deadline = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < grind_deadline: await process_frame
		check(game.hud.cursor.id == Nodes.TOOLS+10 and game.hud.cursor.wear == 0 and game.hud.cursor.data.enchantments == {"Curse of Vanishing":1} and game.hud.station_data.slots[0].id == 0 and game.hud.station_data.slots[1].id == 0,"guest withdrawal repairs, strips and consumes the authoritative pair")
		check(game.experience == grind_xp,"grindstone XP is not immediately credited on output withdrawal")
		game.hud._slot_click(2,true,false)
		grind_deadline = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < grind_deadline: await process_frame
		check(game.hud.cursor.id == Nodes.TOOLS+10 and game.hud.station_data.slots[2].id == 0,"server rejects grindstone output insertion")
		game.hud.return_cursor(); game.resume()
		grind_deadline = Time.get_ticks_msec()+5000
		while XpOrbs.orb_count(game) == 0 and Time.get_ticks_msec() < grind_deadline: await process_frame
		check(XpOrbs.orb_count(game) > 0,"host grindstone XP orbs are visible to the guest")
		game.player.position = Vector3(grinder)+Vector3(2,0,0)
		grind_deadline = Time.get_ticks_msec()+10000
		while (game.experience == grind_xp or XpOrbs.orb_count(game) > 0) and Time.get_ticks_msec() < grind_deadline: await process_frame
		check(game.experience-grind_xp >= 21 and game.experience-grind_xp <= 39,"the nearby guest collects the physical grindstone XP exactly once")
		game.player.position = Vector3(origin)+Vector3(0.5,2,0.5)
		for i in 30: await process_frame

		game.open_inventory("smithing",origin+Vector3i(3,1,3))
		var smith_deadline: int = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < smith_deadline: await process_frame
		check(game.hud.station_data.slots[3].id == Netherite.TOOLS+4 and Durability.normalized(game.hud.station_data.slots[3]) == 22222,"guest sees the exact smithing preview and normalized wear")
		game.hud._slot_click(3,true,false)
		smith_deadline = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < smith_deadline: await process_frame
		check(game.hud.cursor.id == Netherite.TOOLS+4 and game.hud.cursor.data.custom_name == "Network hoe" and game.hud.cursor.data.pwp == 3 and game.hud.station_data.slots[0].id == 0 and game.hud.station_data.slots[1].count == 1 and game.hud.station_data.slots[2].count == 1,"guest takes a host-owned upgrade and consumes all three inputs once")
		check(game.achievements.is_unlocked("serious_dedication"),"host smithing result unlocks the guest's hoe achievement")
		game.hud._slot_click(3,true,false)
		smith_deadline = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < smith_deadline: await process_frame
		check(game.hud.cursor.id == Netherite.TOOLS+4 and game.hud.station_data.slots[3].id == 0,"server rejects insertion into smithing output")
		game.hud.return_cursor(); game.resume()

		var remembered_map: Dictionary = await check_guest_maps()
		await stage("soil")
		var soil: Vector3i = origin+Vector3i(0,1,-2)
		deadline = Time.get_ticks_msec()+10000
		while game.world.node_at(soil) != Farmland.WET and Time.get_ticks_msec() < deadline: await process_frame
		game.world.set_node(soil+Vector3i.UP,VillageContent.COMPOSTER)
		game.world.set_node(soil+Vector3i.LEFT,VillageContent.PATH)
		deadline = Time.get_ticks_msec()+10000
		while (not game.network.pending_requests.is_empty() or game.world.node_at(soil) != Nodes.DIRT or game.world.node_at(soil+Vector3i.LEFT) != Nodes.DIRT) and Time.get_ticks_msec() < deadline: await process_frame
		check(game.world.node_at(soil) == Nodes.DIRT and game.world.node_at(soil+Vector3i.LEFT) == Nodes.DIRT,"guest sees host dirtification above soil and below an existing composter")
		await stage("soil_verified")

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
		PotionEffects.apply(game.player,"haste",30,1)
		game.player.mine(10.0)
		PotionEffects.clear_one(game.player,"haste")
		deadline = Time.get_ticks_msec()+10000
		while not game.network.pending_breaks.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
		check(game.world.node_at(stone) == Nodes.AIR,"guest can mine stone through the player mining input")
		check(game.inventory.slots[mining_index].wear == 1,"successful guest mining wears the tool even if Haste expires before acknowledgement")
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
		await stage("melee")
		var melee_key: int = int(FileAccess.get_file_as_string("/tmp/voxey-network-"+str(port)+"-melee_target"))
		game.network.attack.rpc_id(1,melee_key,5.0,"player_melee",4)
		await stage("melee_result")
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
		await stage("banner")
		var banner_id: int = Banners.FIRST+6
		await wait_for_count(banner_id,2)
		for i in game.inventory.slots.size():
			if game.inventory.slots[i].id == banner_id: select_slot(i); break
		var banner_at: Vector3i = origin+Vector3i(-2,1,-1)
		game.player.position = Vector3(origin)+Vector3(1,2,2)
		game.network.request_banner_place({"pos":banner_at+Vector3i.DOWN,"id":Nodes.STONE,"normal":Vector3i.UP},0.7)
		await wait_for_count(banner_id,1)
		await stage("banner_placed")
		check(game.inventory.count_item(banner_id) == 1,"guest banner placement consumes exactly one item")
		# Inventory receipts can precede the next block-state stream. The real
		# screwdriver input needs a visible banner before it can target it.
		deadline = Time.get_ticks_msec()+10000
		while not Banners.is_banner(game.world.node_at(banner_at)) and Time.get_ticks_msec() < deadline: await process_frame
		game.inventory.add_item(Screwdriver.ID,1)
		for i in game.inventory.slots.size():
			if game.inventory.slots[i].id == Screwdriver.ID: select_slot(i); break
		var old_revision: int = game.network.inventory_revision
		check(Screwdriver.turn(game,banner_at,Screwdriver.ROTATE_FACE),"guest can target the synchronized banner for rotation")
		deadline = Time.get_ticks_msec()+10000
		while game.network.inventory_revision == old_revision and Time.get_ticks_msec() < deadline: await process_frame
		await stage("banner_rotated")
		check(game.inventory.held().wear == 1,"guest banner rotation wears the guest's screwdriver once")
		game.break_node(banner_at,banner_id,Screwdriver.ID)
		deadline = Time.get_ticks_msec()+10000
		while not game.network.pending_breaks.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
		game.player.position = Vector3(banner_at)+Vector3(0.5,0.3,0.5)
		await wait_for_count(banner_id,2)
		check(game.inventory.count_item(banner_id) == 2,"guest harvests and recollects the patterned banner without duplication")
		await stage("bookshelf")
		await wait_for_count(Bookshelves.ID,1)
		await wait_for_count(Nodes.WRITTEN_BOOK,1)
		for i in game.inventory.slots.size():
			if game.inventory.slots[i].id == Bookshelves.ID: select_slot(i); break
		var shelf_at: Vector3i = origin+Vector3i(-2,1,1)
		game.network.place_bookshelf.rpc_id(1,shelf_at+Vector3i.DOWN,Nodes.STONE,Vector3i.UP,0.0,game.player.position,game.network.inventory_snapshot())
		await wait_for_count(Bookshelves.ID,0)
		for i in game.inventory.slots.size():
			if game.inventory.slots[i].id == Nodes.WRITTEN_BOOK: select_slot(i); break
		game.network.use_bookshelf.rpc_id(1,shelf_at,Vector3i.BACK,Vector3(5.0/6,0.75,1),game.player.position,game.network.inventory_snapshot())
		await wait_for_count(Nodes.WRITTEN_BOOK,0)
		await stage("book_stored")
		for i in game.inventory.slots.size():
			if game.inventory.slots[i].id == Screwdriver.ID: select_slot(i); break
		old_revision = game.network.inventory_revision
		game.network.turn_bookshelf.rpc_id(1,shelf_at,game.player.position,game.network.inventory_snapshot())
		deadline = Time.get_ticks_msec()+10000
		while game.network.inventory_revision == old_revision and Time.get_ticks_msec() < deadline: await process_frame
		await stage("book_turned")
		# Selecting a screwdriver from the backpack can reuse the former empty
		# hotbar slot. Choose an empty hand again before requesting the book.
		for i in game.inventory.slots.size():
			if game.inventory.slots[i].id == 0: select_slot(i); break
		game.network.use_bookshelf.rpc_id(1,shelf_at,Vector3i.RIGHT,Vector3(1,0.75,1.0/6),game.player.position,game.network.inventory_snapshot())
		await wait_for_count(Nodes.WRITTEN_BOOK,1)
		check(game.inventory.held().get("data",{}).get("author","") == "Voxey","guest retrieves the exact authored book into the selected hand")
		game.network.use_bookshelf.rpc_id(1,shelf_at,Vector3i.RIGHT,Vector3(1,0.75,1.0/6),game.player.position,game.network.inventory_snapshot())
		await wait_for_count(Nodes.WRITTEN_BOOK,0)
		game.break_node(shelf_at,Bookshelves.ID,0)
		deadline = Time.get_ticks_msec()+10000
		while not game.network.pending_breaks.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
		game.player.position = Vector3(shelf_at)+Vector3(0.5,0.3,0.5)
		await wait_for_count(Nodes.WRITTEN_BOOK,1)
		check(game.inventory.count_item(Nodes.WRITTEN_BOOK) == 1 and game.inventory.count_item(Bookshelves.ID) == 0,"guest harvesting returns the stored book without an ordinary shelf drop")
		game.inventory.add_item(Nodes.WRITABLE_BOOK,1)
		check(game.inventory.fill_grid(game.inventory.recipe_index(Nodes.WRITTEN_BOOK),"hand"),"guest can fill the written-book copy recipe")
		var copied_book: Dictionary = game.inventory.take_grid_result("hand")
		game.inventory.add_item(copied_book.id,copied_book.count,0,copied_book.get("data",{})); game.inventory.grid_to_inventory()
		check(copied_book.get("data",{}).get("generation",0) == 2 and copied_book.data.date == 1700000000 and game.inventory.count_item(Nodes.WRITTEN_BOOK) == 2,"guest copies preserve dates and retain the original volume")
		await stage("plain_shelf")
		var plain_at: Vector3i = origin+Vector3i(2,1,2)
		deadline = Time.get_ticks_msec()+10000
		while game.world.node_at(plain_at) != Nodes.BOOKSHELF and Time.get_ticks_msec() < deadline: await process_frame
		game.open_inventory("chest",plain_at); game.hud.shift_mode = true
		var cobble_before: int = game.inventory.count_item(Nodes.COBBLE)
		for i in game.inventory.slots.size():
			if game.inventory.slots[i].id == Nodes.COBBLE: game.hud._slot_click(i,false,false); break
		deadline = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < deadline: await process_frame
		check(not game.network.station_busy and game.inventory.count_item(Nodes.COBBLE) == cobble_before and game.hud.station_data.slots.all(func(item): return item.id == 0),"guest shift-click cannot put a non-book into a plain shelf")
		for i in game.inventory.slots.size():
			if game.inventory.slots[i].id == Nodes.WRITTEN_BOOK and game.inventory.slots[i].data.generation == 2: game.hud._slot_click(i,false,false); break
		deadline = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < deadline: await process_frame
		check(game.inventory.count_item(Nodes.WRITTEN_BOOK) == 1 and game.hud.station_data.slots[0].get("data",{}).get("date",0) == 1700000000,"guest shelf transfer preserves the copied book's date")
		await stage("plain_shelf_stored")
		game.hud._slot_click(0,true,false)
		deadline = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < deadline: await process_frame
		check(game.inventory.count_item(Nodes.WRITTEN_BOOK) == 2 and game.hud.station_data.slots[0].id == 0,"guest can withdraw the exact copied book from the plain shelf")
		game.hud.shift_mode = false; game.resume()
		await stage("furnace")
		var furnace_at: Vector3i = origin+Vector3i(1,1,2)
		deadline = Time.get_ticks_msec()+10000
		while game.world.stations.get(VoxelWorld.station_key(furnace_at),{}).get("xp",0) != 7 and Time.get_ticks_msec() < deadline: await process_frame
		game.open_inventory("furnace",furnace_at)
		var furnace_xp: float = game.experience
		game.hud._slot_click(2,true,true)
		deadline = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < deadline: await process_frame
		check(game.experience == furnace_xp+7 and game.hud.cursor.id == Nodes.BRICK_ITEM and game.hud.cursor.count == 1,"guest partial furnace withdrawal receives the full source XP award")
		game.hud.return_cursor(); game.hud._slot_click(2,true,true)
		deadline = Time.get_ticks_msec()+10000
		while game.network.station_busy and Time.get_ticks_msec() < deadline: await process_frame
		check(game.experience == furnace_xp+7 and game.hud.cursor.count == 1,"guest second furnace withdrawal cannot duplicate the stored XP")
		game.hud.return_cursor(); await stage("furnace_taken"); game.resume()
		var network_shield: Dictionary = Shields.decorate([load("res://tests/shield_decor_checks.gd").guard(),load("res://tests/shield_decor_checks.gd").flag()])
		game.player.offhand_slot = network_shield.duplicate(true)
		game.controls.sneak_held = true
		game.network.send_inventory()
		await stage("shield_equipped")
		game.controls.sneak_held = false
		# Seed the reconnect fixture without awarding XP to the worn Mending
		# shield; actual XP pickup correctly spends that XP repairing it.
		game.pause()
		game.experience = 1451
		var remembered_offers: Array = Enchanting.offers(game,{"id":95,"count":1},15)
		game.resume()
		game.network.send_inventory()
		await stage("shield_saved")
		var until: int = Time.get_ticks_msec()+1200
		while Time.get_ticks_msec() < until: await process_frame
		game.network.stop(); game.state = "title"
		check(game.network.join("127.0.0.1:"+str(connect_port)) == OK,"copied IP:port join address is accepted")
		deadline = Time.get_ticks_msec()+120000
		while (not game.network.session_ready or game.state != "playing") and Time.get_ticks_msec() < deadline: await process_frame
		check(game.achievements.is_unlocked("serious_dedication"),"guest smithing achievements survive reconnecting")
		var restored_map_index: int = map_slot(remembered_map.id)
		check(restored_map_index >= 0 and game.inventory.slots[restored_map_index].count == 2,"guest copied map identity and stack survive reconnecting")
		if restored_map_index >= 0:
			game.maps.ensure(game.inventory.slots[restored_map_index])
			check(await wait_map(remembered_map.id) == remembered_map.png and game.maps.job.is_empty(),"reconnecting retrieves the same immutable host map without a local survey")
		print("RECONNECTED INVENTORY: iron=",game.inventory.count_item(Nodes.IRON)," gold=",game.inventory.count_item(Nodes.GOLD)," cobble=",game.inventory.count_item(Nodes.COBBLE))
		check(game.network.session_ready and game.inventory.count_item(Nodes.IRON) == 1 and game.inventory.count_item(Nodes.GOLD) == 1 and game.inventory.count_item(Nodes.COBBLE) == 1,"mined and transferred inventory survives reconnecting")
		check(game.experience == 1451 and Enchanting.offers(game,{"id":95,"count":1},15) == remembered_offers,"reconnecting preserves earned XP and exact cached enchanting offers")
		check(game.inventory.slots.any(func(item): return item.id == Nodes.WRITTEN_BOOK and item.get("data",{}).get("generation",0) == 2 and item.data.get("author","") == "Voxey" and item.data.get("date",0) == 1700000000),"reconnecting preserves copied book authors, dates and generation")
		check(game.player.offhand_slot == network_shield,"reconnecting preserves the decorated second-hand shield, damage, name and enchantments")
		var file := FileAccess.open("/tmp/voxey-network-client-done-"+str(port),FileAccess.WRITE); file.store_string("done"); file.close()
		deadline = Time.get_ticks_msec()+10000
		while not FileAccess.file_exists("/tmp/voxey-network-"+str(port)+"-verified") and Time.get_ticks_msec() < deadline: await process_frame
		print("NETWORK CLIENT TESTS: ",failures," failed")
		game.network.stop(); game.queue_free()
		for i in 4: await process_frame
		quit(1 if failures else 0)

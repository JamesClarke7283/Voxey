class_name VoxeyNetwork
extends Node

const DEFAULT_PORT = 24570
const PROTOCOL = 6
const MAX_PLAYERS = 16
const CHANNEL_COUNT = 6
const MOTION_INTERVAL = 0.05
const ENTITY_INTERVAL = 0.1
const EDIT_BATCH_SIZE = 128
const COLUMN_WINDOW = 2
const ENTITY_MOTION_BATCH = 12
var game: Node3D
var peer: ENetMultiplayerPeer
var status: String = "Offline"
var players: Dictionary = {}
var avatars: Dictionary = {}
var replicas: Dictionary = {}
var pending_edits: Dictionary = {}
var world_revision: int = 0
var edit_revisions: Dictionary = {}
var repair_timer: float = 0.0
var edit_sequence: int = 0
var pending_requests: Dictionary = {}
var pending_actions: Array = []
var applying: bool = false
var session_ready: bool = false
var timer: float = 0.0
var state_timer: float = 0.0
var appearance: Dictionary = CharacterSkin.DEFAULT.duplicate()
var map_busy: bool = false
var requested_maps: Dictionary = {}
var map_waiters: Dictionary = {}
var station_pos := Vector3i.ZERO
var station_open: bool = false
var station_busy: bool = false
var connection_time: float = 0.0
var identity_id: String = ""
var server_port: int = DEFAULT_PORT
var player_limit: int = MAX_PLAYERS
var share_address: String = ""
var inventory_revision: int = 0
var inventory_sequence: int = 0
var motion_sequence: int = 0
var peer_motion_sequences: Dictionary = {}
var peer_revisions: Dictionary = {}
var peer_sequences: Dictionary = {}
var peer_bags: Dictionary = {}
var peer_identity: Dictionary = {}
var pending_breaks: Dictionary = {}
var deliveries: Dictionary = {}
var delivery_serial: int = 0
var inventory_dirty: bool = true
var observed_inventory: Inventory
var mining_inventory: Inventory
var entity_timer: float = 0.0
var roster_sequence: int = 0
var received_roster: int = -1
var entity_sequence: int = 0
var received_entities: int = -1
var replica_motion: Dictionary = {}
var ready_peers: Dictionary = {}
var loaded_announced: bool = false
var column_sync: Dictionary = {}
var column_revisions: Dictionary = {}
var column_transfers: Dictionary = {}
var state_sequence: int = 0
var received_state: int = -1
var station_sequences: Dictionary = {}
var last_stations: Dictionary = {}
var last_states: Dictionary = {}
var sent_profiles: Dictionary = {}
var shield_equipment: Dictionary = {}
var last_entities: Dictionary = {}
var replica_sequences: Dictionary = {}

func _ready() -> void:
	var path: String = game.saves.root_path.path_join("network_identity.json")
	identity_id = str(WorldStore.read_json(path).get("id",""))
	if identity_id.is_empty():
		identity_id = Crypto.new().generate_random_bytes(16).hex_encode()
		WorldStore.write_json(path,{"id":identity_id})
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_failed)
	multiplayer.server_disconnected.connect(_server_left)

func active() -> bool: return peer != null
func client() -> bool: return active() and not multiplayer.is_server()

func host(port: int = DEFAULT_PORT) -> Error:
	if active() or game.state in ["title","loading"]: return ERR_ALREADY_IN_USE
	if port < 1024 or port > 65535: status = "Use a port from 1024 to 65535."; return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip("0.0.0.0")
	var error: Error = peer.create_server(port,MAX_PLAYERS-1,CHANNEL_COUNT)
	if error != OK: peer = null; status = "Could not host: "+error_string(error); return error
	multiplayer.multiplayer_peer = peer
	session_ready = true; server_port = port; status = "Hosting on 0.0.0.0:%d (UDP)"%port
	players[1] = {"skin":appearance.duplicate(),"position":game.player.position,"yaw":game.player.rotation.y}
	game.toast(status+" · Join: "+join_address())
	return OK

func join(address: String, port: int = DEFAULT_PORT) -> Error:
	if active(): return ERR_ALREADY_IN_USE
	address = address.strip_edges()
	if address.count(":") == 1 and address.get_slice(":",1).is_valid_int():
		port = int(address.get_slice(":",1)); address = address.get_slice(":",0)
	if address.is_empty() or address in ["0.0.0.0","*"] or port < 1024 or port > 65535:
		status = "Enter the host's IP address and a port from 1024 to 65535."; return ERR_INVALID_PARAMETER
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address.strip_edges(),port,CHANNEL_COUNT)
	if error != OK: peer = null; status = "Could not join: "+error_string(error); return error
	multiplayer.multiplayer_peer = peer
	status = "Connecting to %s:%d…"%[address,port]; connection_time = 0
	return OK

func stop() -> void:
	session_ready = false
	if peer != null: peer.close()
	peer = null; multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for avatar in avatars.values(): if is_instance_valid(avatar): avatar.queue_free()
	for replica in replicas.values(): if is_instance_valid(replica): replica.queue_free()
	avatars.clear(); replicas.clear(); players.clear(); pending_edits.clear()
	world_revision = 0; edit_revisions.clear(); repair_timer = 0.0; edit_sequence = 0
	pending_requests.clear(); pending_actions.clear()
	station_open = false; station_busy = false; status = "Offline"
	map_busy = false; requested_maps.clear(); map_waiters.clear()
	inventory_revision = 0; inventory_sequence = 0; motion_sequence = 0
	peer_motion_sequences.clear()
	peer_revisions.clear(); peer_sequences.clear(); peer_bags.clear(); peer_identity.clear()
	pending_breaks.clear(); deliveries.clear(); inventory_dirty = true
	timer = 0.0; state_timer = 0.0; entity_timer = 0.0
	roster_sequence = 0; received_roster = -1; entity_sequence = 0; received_entities = -1
	state_sequence = 0; received_state = -1; station_sequences.clear()
	replica_motion.clear(); ready_peers.clear(); loaded_announced = false
	column_sync.clear(); column_revisions.clear(); column_transfers.clear()
	last_stations.clear(); last_states.clear()
	sent_profiles.clear(); shield_equipment.clear(); last_entities.clear(); replica_sequences.clear()
	if game != null and game.world != null:
		game.world.network_replica = false
		game.world.interest_centers.clear(); game.world.desired = Vector2i(999999,999999)

func _connected() -> void:
	status = "Connected; receiving world…"
	hello.rpc_id(1,PROTOCOL,appearance,identity_id)

func _failed() -> void:
	stop(); status = "Connection failed. Check the address and UDP port."; game.toast(status)

func _server_left() -> void:
	stop(); game.state = "title"; game.world.active = false
	game.hud.show_title(); Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	status = "The server disconnected."; game.toast(status)

func _peer_left(id: int) -> void:
	LushCaveExtra.player_left(game.world,id)
	players.erase(id)
	ready_peers.erase(id); column_sync.erase(id); column_transfers.erase(id)
	sent_profiles.erase(id)
	shield_equipment.erase(id)
	peer_motion_sequences.erase(id); peer_sequences.erase(id); peer_revisions.erase(id)
	# Persisted bags survive reconnects in adventure_state, not as abandoned peers.
	peer_bags.erase(id); peer_identity.erase(id)
	for serial in deliveries.keys():
		if int(deliveries[serial].to) == id: deliveries.erase(serial)
	if avatars.has(id):
		if is_instance_valid(avatars[id]): avatars[id].queue_free()
		avatars.erase(id)
	if active() and multiplayer.is_server():
		roster_sequence += 1
		remove_player.rpc(id,roster_sequence)

@rpc("authority","call_remote","reliable")
func remove_player(id: int, sequence: int) -> void:
	received_roster = maxi(received_roster,sequence)
	players.erase(id)
	shield_equipment.erase(id)
	if avatars.has(id):
		if is_instance_valid(avatars[id]): avatars[id].queue_free()
		avatars.erase(id)

@rpc("any_peer","call_remote","reliable")
func hello(protocol: int, skin: Dictionary, identity: String) -> void:
	if not active() or not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL or players.size() >= player_limit or players.has(sender): peer.disconnect_peer(sender); return
	players[sender] = {"skin":CharacterSkin.clean(skin),"position":game.player.position+Vector3(2,0,0),"yaw":0.0,"identity":identity.left(64)}
	peer_identity[sender] = identity.left(64)
	peer_revisions[sender] = 0; peer_sequences[sender] = -1; peer_motion_sequences[sender] = -1
	var saved: Dictionary = game.world.adventure_state.get("network_players",{}).get(peer_identity[sender],{})
	var bag := Inventory.new(); bag.restore(saved.get("inventory",[]),saved.get("pouches",[])); bag.selected = clampi(int(saved.get("selected",0)),0,8)
	peer_bags[sender] = bag
	column_sync[sender] = NetworkBlockSync.new()
	var snapshot: Dictionary = game.dimension_snapshot()
	var data: Dictionary = {"version":game.SAVE_VERSION,"world_id":"","name":game.world_name,"seed":game.world.seed_value,"gamemode":game.gamemode,"difficulty":game.difficulty,"dimension":game.dimension,"edits":snapshot.edits,"growth":snapshot.growth,"stations":snapshot.stations,"block_states":snapshot.block_states,"adventure":snapshot.adventure,"position":[game.player.position.x+2,game.player.position.y,game.player.position.z],"spawn":[game.spawn_point.x,game.spawn_point.y,game.spawn_point.z],"inventory":[],"time":game.day_time,"settings":{"distance":game.world.radius},"gamerules":game.game_rules}
	if not saved.is_empty():
		data.inventory = saved.get("inventory",[])
		data.cursor = saved.get("cursor",{})
		data.pouches = saved.get("pouches",[])
		data.selected = saved.get("selected",0)
		data.health = saved.get("health",20)
		data.hunger = saved.get("hunger",20)
		data.experience = saved.get("experience",0)
		data.enchanting = saved.get("enchanting",{})
		data.achievements = VoxeyAchievements.clean_save(saved.get("achievements",{}))
		data.offhand = Inventory.clean_slot(saved.get("offhand",{}))
	data["world_revision"] = world_revision
	welcome.rpc_id(sender,data,players)
	settings_changed.rpc_id(sender,settings_snapshot())

@rpc("authority","call_remote","reliable")
func welcome(data: Dictionary, roster: Dictionary) -> void:
	if not client(): return
	applying = true
	game.load_world_data(data)
	game.world.network_replica = true
	game.hud.show_loading()
	world_revision = int(data.get("world_revision",0)); edit_revisions.clear()
	players = roster; inventory_revision = 0; inventory_sequence = 0; session_ready = true; applying = false
	status = "Connected to "+game.world_name

@rpc("any_peer","call_remote","reliable")
func world_ready() -> void:
	if not active() or not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not players.has(sender) or ready_peers.has(sender): return
	ready_peers[sender] = true
	# The initial save and loading-time edits use channel 0. Only begin other
	# streams after the guest has applied that save and finished loading.
	state_sequence += 1
	world_state.rpc_id(sender,game.world.stations,game.world.block_states,[],[],game.day_time,state_sequence,true)
	entity_state.rpc_id(sender,entity_snapshot(),entity_sequence)
	for id in shield_equipment: player_shields.rpc_id(sender,id,shield_equipment[id])

func update(dt: float) -> void:
	if not active(): return
	if observed_inventory != game.inventory:
		observed_inventory = game.inventory
		if not observed_inventory.changed.is_connected(_inventory_changed): observed_inventory.changed.connect(_inventory_changed)
	if not session_ready:
		connection_time += dt
		if connection_time > 20: _failed()
		return
	if client(): game.world.active = false
	elif game.state != "loading": game.world.active = true
	if game.state == "loading": return
	if client() and not loaded_announced:
		loaded_announced = true
		world_ready.rpc_id(1)
	_update_replica_motion(dt)
	for p in pending_breaks.keys():
		if Time.get_ticks_msec()-int(pending_breaks[p].time) > 15000:
			pending_breaks.erase(p); game.toast("Mining timed out. Try again.")
	timer += dt; state_timer += dt; repair_timer += dt; entity_timer += dt
	if timer < MOTION_INTERVAL: return
	timer = fmod(timer,MOTION_INTERVAL)
	var own: int = multiplayer.get_unique_id()
	var record: Dictionary = {"skin":appearance,"position":game.player.position,"velocity":game.player.velocity,"yaw":game.player.rotation.y,"motion":_next_motion_sequence()}
	players[own] = record
	var equipment: Dictionary = _clean_shields({"main":game.inventory.held(),"offhand":game.player.offhand_slot,"raised":Shields.raised(game.player)})
	if shield_equipment.get(own,{}) != equipment:
		shield_equipment[own] = equipment
		if client(): update_shields.rpc_id(1,equipment)
		else: player_shields.rpc(own,equipment)
	if client():
		player_state.rpc_id(1,record)
		if inventory_dirty or state_timer >= 1.0:
			state_timer = 0; send_inventory()
	else:
		roster_sequence += 1
		var roster: Dictionary = {}
		for id in players:
			roster[id] = [players[id].position,players[id].yaw]
			if players[id].skin != sent_profiles.get(id):
				sent_profiles[id] = players[id].skin.duplicate(true)
				player_profile.rpc(id,players[id].skin)
		for id in ready_peers: player_roster.rpc_id(id,roster,roster_sequence)
		if not pending_edits.is_empty():
			var changes: Array = []
			for p in pending_edits.keys():
				changes.append([p,pending_edits[p],edit_revisions[p]])
				pending_edits.erase(p)
				if changes.size() >= EDIT_BATCH_SIZE*2: break
			for offset in range(0,changes.size(),EDIT_BATCH_SIZE): apply_edits.rpc(changes.slice(offset,offset+EDIT_BATCH_SIZE))
		var centers: Array[Vector2i] = []
		for id in players:
			if id != 1:
				var p: Vector3 = players[id].position
				centers.append(Vector2i(floori(p.x/16),floori(p.z/16)))
		if game.world.interest_centers != centers:
			game.world.interest_centers = centers; game.world.desired = Vector2i(999999,999999)
		_flush_actions()
		# Periodic audits repair local prediction mistakes. Per-peer acknowledgements
		# and a bounded window keep distant/large worlds from flooding the connection.
		var audit: bool = repair_timer >= 3.0
		if audit:
			repair_timer = 0.0
			for sync in column_sync.values(): sync.sent.clear()
		_sync_columns()
		if entity_timer >= ENTITY_INTERVAL:
			entity_timer = fmod(entity_timer,ENTITY_INTERVAL)
			entity_sequence += 1
			var snapshot: Array = entity_snapshot()
			var definitions: Dictionary = {}
			for entry in snapshot:
				var definition: Dictionary = entry.duplicate()
				definition.erase("at"); definition.erase("yaw")
				definitions[entry.key] = definition
			if definitions != last_entities:
				last_entities = definitions.duplicate(true)
				for id in ready_peers: entity_state.rpc_id(id,snapshot,entity_sequence)
			for batch in entity_motion_batches(snapshot):
				for id in ready_peers: entity_motion.rpc_id(id,batch,entity_sequence)
		if state_timer >= 0.5 or audit:
			state_timer = 0
			_publish_world_state(audit)

@rpc("any_peer","call_remote","unreliable_ordered",1)
func player_state(record: Dictionary) -> void:
	if not active() or not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not players.has(sender) or not record.get("position") is Vector3: return
	var at: Vector3 = record.position
	if not at.is_finite() or not is_finite(float(record.get("yaw",0))) or not WorldBounds.horizontal(Vector3i(at.floor())): return
	var sequence: int = int(record.get("motion",0))
	if sequence <= int(peer_motion_sequences.get(sender,-1)): return
	peer_motion_sequences[sender] = sequence
	var identity: String = players[sender].get("identity","")
	var velocity: Vector3 = record.get("velocity",Vector3.ZERO) if record.get("velocity",Vector3.ZERO) is Vector3 else Vector3.ZERO
	if not velocity.is_finite(): velocity = Vector3.ZERO
	players[sender] = {"position":at,"velocity":velocity.limit_length(100),"yaw":float(record.get("yaw",0)),"skin":CharacterSkin.clean(record.get("skin",{})),"identity":identity}
	_update_avatar(sender)

func _inventory_changed() -> void:
	inventory_dirty = true

func _next_motion_sequence() -> int:
	motion_sequence += 1
	return motion_sequence

func inventory_snapshot() -> Dictionary:
	inventory_sequence += 1
	game.inventory.sync_pouches()
	return {"inventory":game.inventory.slots.slice(0,Inventory.BASE_SLOTS).duplicate(true),"pouches":game.inventory.pouch_slots.duplicate(true),"selected":game.inventory.selected,"cursor":game.hud.cursor.duplicate(true),"offhand":game.player.offhand_slot.duplicate(true),"health":game.player.health,"hunger":game.player.hunger,"experience":game.experience,"enchanting":game.enchanting_state.duplicate(true),"achievements":game.achievements.to_save(),"revision":inventory_revision,"sequence":inventory_sequence,"motion":_next_motion_sequence()}

func send_inventory() -> void:
	if not client() or not session_ready: return
	inventory_dirty = false
	inventory_state.rpc_id(1,inventory_snapshot())

@rpc("any_peer","call_remote","reliable",2)
func inventory_state(data: Dictionary) -> void:
	if active() and multiplayer.is_server(): _receive_inventory(multiplayer.get_remote_sender_id(),data)

func _receive_inventory(id: int, data: Dictionary) -> bool:
	if not peer_bags.has(id) or int(data.get("revision",-1)) != int(peer_revisions.get(id,0)) or int(data.get("sequence",0)) <= int(peer_sequences.get(id,-1)): return false
	if not data.get("inventory") is Array or not data.get("pouches",[]) is Array: return false
	peer_sequences[id] = int(data.sequence)
	var bag: Inventory = peer_bags[id]
	bag.restore(data.inventory,data.get("pouches",[])); bag.selected = clampi(int(data.get("selected",0)),0,8)
	_persist_inventory(id,data)
	return true

func _resync_inventory(id: int) -> void:
	if not peer_bags.has(id): return
	peer_revisions[id] = int(peer_revisions.get(id,0))+1
	var saved: Dictionary = game.world.adventure_state.get("network_players",{}).get(peer_identity.get(id,""),{})
	var bag: Inventory = peer_bags[id]
	inventory_resync.rpc_id(id,bag.slots,bag.pouch_slots,saved.get("cursor",{}),peer_revisions[id],Inventory.clean_slot(saved.get("offhand",{})))

@rpc("authority","call_remote","reliable",2)
func inventory_resync(slots: Array, pouches: Array, cursor: Dictionary, revision: int, offhand: Dictionary = {}) -> void:
	if not client() or revision < inventory_revision: return
	inventory_revision = revision
	game.inventory.restore(slots,pouches); game.hud.cursor = Inventory.clean_slot(cursor)
	game.player.offhand_slot = Inventory.clean_slot(offhand)
	send_inventory()

func _persist_inventory(id: int, state: Dictionary = {}) -> void:
	var identity: String = str(peer_identity.get(id,""))
	if identity.is_empty() or not peer_bags.has(id): return
	if not game.world.adventure_state.has("network_players"): game.world.adventure_state["network_players"] = {}
	var record: Dictionary = game.world.adventure_state.network_players.get(identity,{}).duplicate(true)
	record.merge(state,true)
	var bag: Inventory = peer_bags[id]; bag.sync_pouches()
	record.inventory = bag.slots.slice(0,Inventory.BASE_SLOTS).duplicate(true)
	record.pouches = bag.pouch_slots.duplicate(true); record.selected = bag.selected
	record.cursor = Inventory.clean_slot(record.get("cursor",{}))
	record.offhand = Inventory.clean_slot(record.get("offhand",{}))
	record.health = clampf(float(record.get("health",20)),0,20); record.hunger = clampf(float(record.get("hunger",20)),0,20)
	record.experience = maxf(0,float(record.get("experience",0)))
	if not is_finite(record.experience): record.experience = 0
	record.enchanting = Enchanting.restore(record.get("enchanting",{}))
	record.achievements = VoxeyAchievements.clean_save(record.get("achievements",{}))
	game.world.adventure_state.network_players[identity] = record

# Appearance packets contain shield visuals only; they never change a player's
# inventory or combat state. Unchanged designs are not resent with movement.
static func _clean_shields(value: Dictionary) -> Dictionary:
	var result: Dictionary = {"raised":bool(value.get("raised",false))}
	for hand in ["main","offhand"]:
		var raw: Variant = value.get(hand,{})
		var item: Dictionary = Bookshelves.empty()
		# Ordinary carried containers can have large nested inventories; the
		# visual update never needs to traverse those on every movement tick.
		if raw is Dictionary and (raw.get("id") is int or raw.get("id") is float) and Shields.is_shield(int(raw.id)):
			item = Inventory.clean_slot(raw)
			item.count = 1; item.wear = 0
			var data: Dictionary = {}
			if Shields.color(item) >= 0: data.shield_color = Shields.color(item); data.layers = Banners.layers(item)
			item["data"] = data
		result[hand] = item
	return result

@rpc("any_peer","call_remote","reliable")
func update_shields(equipment: Dictionary) -> void:
	if not active() or not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not players.has(sender): return
	var clean: Dictionary = _clean_shields(equipment)
	shield_equipment[sender] = clean; _update_avatar(sender)
	player_shields.rpc(sender,clean)

@rpc("authority","call_remote","reliable")
func player_shields(id: int, equipment: Dictionary) -> void:
	if not client(): return
	shield_equipment[id] = _clean_shields(equipment)
	if players.has(id): _update_avatar(id)

@rpc("authority","call_remote","unreliable_ordered",1)
func player_roster(roster: Dictionary, sequence: int) -> void:
	if not client() or not loaded_announced or sequence <= received_roster: return
	received_roster = sequence
	var own: int = multiplayer.get_unique_id()
	for id in players.keys():
		if id != own and not roster.has(id): players.erase(id)
	for id in roster:
		if id == own: continue
		if not players.has(id): players[id] = {"skin":CharacterSkin.DEFAULT.duplicate()}
		players[id].position = roster[id][0]; players[id].yaw = roster[id][1]
	update_avatars()

@rpc("authority","call_remote","reliable")
func player_profile(id: int, skin: Dictionary) -> void:
	if not client(): return
	if not players.has(id): players[id] = {"position":Vector3.ZERO,"yaw":0.0}
	players[id].skin = CharacterSkin.clean(skin)
	if avatars.has(id): avatars[id].set_appearance(players[id].skin)

func update_avatars() -> void:
	for id in avatars.keys():
		if not players.has(id):
			if is_instance_valid(avatars[id]): avatars[id].queue_free()
			avatars.erase(id)
	for id in players:
		_update_avatar(id)

func _update_avatar(id: int) -> void:
	if id == multiplayer.get_unique_id(): return
	if not avatars.has(id):
		var avatar := NetworkAvatar.new(); game.add_child(avatar); avatar.set_meta("peer_id",id); avatars[id] = avatar
	avatars[id].set_appearance(players[id].skin)
	avatars[id].set_shields(shield_equipment.get(id,{}))
	avatars[id].move_to(players[id].position,players[id].yaw)

func local_edit(p: Vector3i, id: int, previous: int = -1) -> void:
	if not active() or applying or not session_ready: return
	if multiplayer.is_server():
		world_revision += 1; edit_revisions[p] = world_revision
		pending_edits[p] = id
		var column := Vector2i(p.x >> 4,p.z >> 4)
		column_revisions[column] = world_revision
		for sync in column_sync.values(): sync.invalidate(column)
	else:
		edit_sequence += 1
		pending_requests[edit_sequence] = {"pos":p,"previous":previous,"time":Time.get_ticks_msec()}
		request_edit.rpc_id(1,p,id,game.player.position,_next_motion_sequence(),edit_sequence)

func reachable(sender: int, p: Vector3i, distance: float = 9) -> bool:
	return players.has(sender) and Vector3(p).distance_to(players[sender].position) <= distance

@rpc("any_peer","call_remote","reliable")
func request_edit(p: Vector3i, id: int, at: Vector3, motion: int, request: int) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _action_position(sender,at,motion):
		_reply_edit(sender,p,request); return
	var allowed: bool = id in [Nodes.AIR,Nodes.WATER,Nodes.LAVA] or Nodes.exists(id) and (Nodes.placeable(id) or VillageContent.DATA.get(id,{}).get("block",false) or Doors.is_door(id) or Trapdoors.is_trapdoor(id))
	if not reachable(sender,p) or not allowed or (game.gamemode != "creative" and id in [Nodes.BEDROCK,CommandBlocks.ID]):
		_reply_edit(sender,p,request); return
	# Older actions waiting on this column must run before a newly arrived one.
	_flush_actions()
	if not game.world.loaded_at(Vector3(p)):
		_queue_action({"peer":sender,"pos":p,"id":id,"request":request}); return
	_apply_edit(sender,p,id,request)

func _apply_edit(sender: int, p: Vector3i, id: int, request: int) -> void:
	if reachable(sender,p) and game.world.set_node(p,id):
		Farmland.placed(game.world,p)
		if CocoaCrops.is_cocoa(id) and not game.world.block_states.get(VoxelWorld.station_key(p),{}).has(CocoaCrops.FACING_KEY):
			var supports: Array = []
			for side in CocoaCrops.SIDES:
				if CocoaCrops.normal_jungle_log(game.world.node_at(p+side)): supports.append(side)
			if supports.size() == 1: CocoaCrops.set_facedir(game.world,p,CocoaCrops.facedir_for(supports[0]))
	_reply_edit(sender,p,request)

func _reply_edit(sender: int, p: Vector3i, request: int) -> void:
	var actual: int = game.world.node_at(p) if game.world.loaded_at(Vector3(p)) else -1
	edit_result.rpc_id(sender,p,actual,int(edit_revisions.get(p,0)),request)

@rpc("authority","call_remote","reliable")
func edit_result(p: Vector3i, actual: int, revision: int, request: int) -> void:
	if not client(): return
	var pending: Dictionary = pending_requests.get(request,{})
	pending_requests.erase(request)
	for newer in pending_requests:
		if newer > request and pending_requests[newer].pos == p: return
	if actual < 0: actual = int(pending.get("previous",-1))
	if actual >= 0: apply_edits([[p,actual,revision]])

func _queue_action(action: Dictionary) -> void:
	action["time"] = Time.get_ticks_msec()
	if pending_actions.size() < 256:
		pending_actions.append(action)
	elif action.has("request"):
		_reply_edit(action.peer,action.pos,action.request)
	elif action.has("inventory"):
		break_result.rpc_id(action.peer,action.pos,action.id,false,int(edit_revisions.get(action.pos,0)))

func _flush_actions() -> void:
	for action in pending_actions.duplicate():
		if not players.has(action.peer): pending_actions.erase(action); continue
		var loaded: bool = game.world.loaded_at(Vector3(action.pos))
		if not loaded and Time.get_ticks_msec()-int(action.time) < 10000: continue
		pending_actions.erase(action)
		if action.has("request"):
			if loaded: _apply_edit(action.peer,action.pos,action.id,action.request)
			else: _reply_edit(action.peer,action.pos,action.request)
		elif action.has("direction"):
			if loaded: _configure_node(action.peer,action.pos,action.direction,action.support)
		elif action.has("use"):
			if loaded: _use_node(action.peer,action.pos)
		elif loaded: _break_block(action.peer,action.pos,action.id,action.inventory)
		else: break_result.rpc_id(action.peer,action.pos,action.id,false,int(edit_revisions.get(action.pos,0)))

func request_break(p: Vector3i, id: int, _tool: int) -> void:
	if not pending_breaks.is_empty(): return
	pending_breaks[p] = {"index":game.inventory.selected,"slot":game.inventory.held().duplicate(true),"node":id,"time":Time.get_ticks_msec()}
	break_block.rpc_id(1,p,id,game.player.position,inventory_snapshot())

func request_banner_place(target: Dictionary, yaw: float) -> void:
	if not client() or not session_ready: return
	place_banner.rpc_id(1,target.pos,int(target.id),target.normal,yaw,game.player.position,inventory_snapshot())

@rpc("any_peer","call_remote","reliable",2)
func place_bookshelf(p: Vector3i, expected: int, normal: Vector3i, yaw: float, at: Vector3, data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not is_finite(yaw) or absi(normal.x)+absi(normal.y)+absi(normal.z) != 1: return
	if not _action_position(sender,at,int(data.get("motion",0))) or not reachable(sender,p): return
	if not _receive_inventory(sender,data): _resync_inventory(sender); return
	if game.world.loaded_at(Vector3(p)) and game.world.node_at(p) == expected:
		var target: Dictionary = {"pos":p,"normal":normal}
		if SnowCover.is_snow(expected): target["replace"] = p
		Bookshelves.place(game,target,_bag(sender),yaw)
	_persist_inventory(sender); _resync_inventory(sender)

@rpc("any_peer","call_remote","reliable",2)
func use_bookshelf(p: Vector3i, normal: Vector3i, hit: Vector3, at: Vector3, data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _action_position(sender,at,int(data.get("motion",0))) or not reachable(sender,p) or not hit.is_finite(): return
	if not _receive_inventory(sender,data): _resync_inventory(sender); return
	if game.world.loaded_at(Vector3(p)): Bookshelves.interact(game,p,normal,hit,_bag(sender))
	_persist_inventory(sender); _resync_inventory(sender)

@rpc("any_peer","call_remote","reliable",2)
func turn_bookshelf(p: Vector3i, at: Vector3, data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _action_position(sender,at,int(data.get("motion",0))) or not reachable(sender,p): return
	if not _receive_inventory(sender,data): _resync_inventory(sender); return
	var bag: Inventory = _bag(sender)
	if game.world.loaded_at(Vector3(p)) and game.world.node_at(p) == Bookshelves.ID and Screwdriver.is_screwdriver(int(bag.held().id)):
		Bookshelves.rotate(game.world,p)
		if game.gamemode != "creative": bag.damage_tool()
	_persist_inventory(sender); _resync_inventory(sender)

@rpc("any_peer","call_remote","reliable",2)
func place_banner(p: Vector3i, expected: int, normal: Vector3i, yaw: float, at: Vector3, data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not is_finite(yaw) or absi(normal.x)+absi(normal.y)+absi(normal.z) != 1: return
	if not _action_position(sender,at,int(data.get("motion",0))) or not reachable(sender,p): return
	if not _receive_inventory(sender,data): _resync_inventory(sender); return
	if game.world.loaded_at(Vector3(p)) and game.world.node_at(p) == expected:
		var target: Dictionary = {"pos":p,"id":expected,"normal":normal}
		if SnowCover.is_snow(expected): target["replace"] = p
		Banners.place(game,target,_bag(sender),yaw)
	_persist_inventory(sender)
	_resync_inventory(sender)

@rpc("any_peer","call_remote","reliable",2)
func rotate_banner(p: Vector3i, at: Vector3, data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _action_position(sender,at,int(data.get("motion",0))) or not reachable(sender,p): return
	if not _receive_inventory(sender,data): _resync_inventory(sender); return
	var bag: Inventory = _bag(sender)
	if game.world.loaded_at(Vector3(p)) and Banners.is_banner(game.world.node_at(p)) and Screwdriver.is_screwdriver(int(bag.held().id)):
		if Banners.rotate(game.world,p,Screwdriver.ROTATE_FACE) and game.gamemode != "creative": bag.damage_tool()
	_persist_inventory(sender)
	_resync_inventory(sender)

func _action_position(id: int, at: Vector3, sequence: int) -> bool:
	if not players.has(id) or not at.is_finite() or not WorldBounds.horizontal(Vector3i(at.floor())): return false
	if sequence > int(peer_motion_sequences.get(id,-1)):
		peer_motion_sequences[id] = sequence
		players[id].position = at
	return true

@rpc("any_peer","call_remote","reliable",2)
func break_block(p: Vector3i, expected: int, at: Vector3, data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _action_position(sender,at,int(data.get("motion",0))) or not data.get("inventory") is Array or not data.get("pouches",[]) is Array: return
	# Accept the tool snapshot on arrival, in order with other inventory actions.
	# A queued dig must not become stale merely because terrain took time to load.
	if not _receive_inventory(sender,data):
		_resync_inventory(sender)
		break_result.rpc_id(sender,p,game.world.node_at(p) if game.world.loaded_at(Vector3(p)) else expected,false,int(edit_revisions.get(p,0)))
		return
	_flush_actions()
	if reachable(sender,p) and not game.world.loaded_at(Vector3(p)):
		_queue_action({"peer":sender,"pos":p,"id":expected,"inventory":data}); return
	_break_block(sender,p,expected,data)

func _break_block(sender: int, p: Vector3i, expected: int, data: Dictionary) -> void:
	var actual: int = game.world.node_at(p)
	var success: bool = false
	if reachable(sender,p) and actual == expected and is_finite(Nodes.hardness(actual)) and actual != Nodes.AIR:
		# Harvest with this miner's tool and enchantments, never the host's hand.
		var host_inventory: Inventory = game.inventory
		if mining_inventory == null: mining_inventory = Inventory.new()
		mining_inventory.restore(data.get("inventory",[]),data.get("pouches",[])); mining_inventory.selected = clampi(int(data.get("selected",0)),0,8)
		game.inventory = mining_inventory
		game.break_node(p,actual,mining_inventory.held().id)
		game.inventory = host_inventory
		success = game.world.node_at(p) != actual
	break_result.rpc_id(sender,p,game.world.node_at(p),success,int(edit_revisions.get(p,0)))

@rpc("authority","call_remote","reliable",2)
func break_result(p: Vector3i, actual: int, success: bool, revision: int) -> void:
	if not client(): return
	apply_edits([[p,actual,revision]])
	var pending: Dictionary = pending_breaks.get(p,{})
	pending_breaks.erase(p)
	if success and not pending.is_empty():
		Hunger.exhaust(game.player,Hunger.DIG)
		if game.gamemode != "creative":
			var indices: Array = [int(pending.index)]
			for index in game.inventory.slots.size():
				if index != int(pending.index): indices.append(index)
			for index in indices:
				if ToolCapabilities.same_mining_item(game.inventory.slots[index],pending.slot):
					var selected: int = game.inventory.selected; game.inventory.selected = index
					ToolCapabilities.wear(game.inventory,int(pending.node)); game.inventory.selected = selected
					break
		game.sound("break"); game.progress("gather")
		send_inventory()
	game.player.mining = 0.0

@rpc("authority","call_remote","reliable")
func apply_edits(changes: Array) -> void:
	if not client(): return
	applying = true
	for entry in changes:
		var p: Vector3i = entry[0]
		var revision: int = int(entry[2])
		if revision < int(edit_revisions.get(p,0)): continue
		edit_revisions[p] = revision
		world_revision = maxi(world_revision,revision)
		game.world.apply_network_edit(p,int(entry[1]))
	applying = false

func _sync_columns() -> void:
	var now: int = Time.get_ticks_msec()
	for id in ready_peers:
		var sync: NetworkBlockSync = column_sync[id]
		sync.expire(now)
		var center := Vector2i(floori(players[id].position.x/16.0),floori(players[id].position.z/16.0))
		var transfers: Dictionary = column_transfers.get(id,{})
		column_transfers[id] = transfers
		for column in transfers.keys():
			if not sync.sending.has(column): transfers.erase(column)
		for column in sync.sent.keys():
			if maxi(absi(column.x-center.x),absi(column.y-center.y)) > game.world.radius+1: sync.sent.erase(column)
		var columns: Array[Vector2i] = []
		for z in range(-game.world.radius,game.world.radius+1):
			for x in range(-game.world.radius,game.world.radius+1): columns.append(center+Vector2i(x,z))
		columns.sort_custom(func(a: Vector2i,b: Vector2i): return a.distance_squared_to(center) < b.distance_squared_to(center))
		for column in columns:
			if sync.sending.size() >= COLUMN_WINDOW: break
			var revision: int = int(column_revisions.get(column,0))
			if not sync.needed(column,revision): continue
			var edits: Array = game.world.column_edits(column)
			if edits.is_empty(): sync.sent[column] = revision; continue
			var changes: Array = []
			for p in edits: changes.append([p,game.world.edits[p],edit_revisions.get(p,0)])
			var token: int = sync.begin(column,revision,now)
			transfers[column] = {"changes":changes,"offset":0,"token":token,"revision":revision}
		for column in transfers.keys():
			var transfer: Dictionary = transfers[column]
			var end: int = mini(int(transfer.offset)+EDIT_BATCH_SIZE,transfer.changes.size())
			column_snapshot.rpc_id(id,column,transfer.token,transfer.revision,transfer.changes.slice(transfer.offset,end),end == transfer.changes.size())
			sync.sending[column].time = now
			transfer.offset = end
			if end == transfer.changes.size(): transfers.erase(column)

@rpc("authority","call_remote","reliable",5)
func column_snapshot(column: Vector2i, token: int, revision: int, changes: Array, complete: bool) -> void:
	if not client() or not loaded_announced: return
	apply_edits(changes)
	if complete: column_received.rpc_id(1,column,token,revision)

@rpc("any_peer","call_remote","reliable",5)
func column_received(column: Vector2i, token: int, revision: int) -> void:
	if not active() or not multiplayer.is_server(): return
	var sync: NetworkBlockSync = column_sync.get(multiplayer.get_remote_sender_id())
	if sync != null: sync.acknowledge(column,token,revision)

func _publish_world_state(full: bool = false) -> void:
	var stations: Dictionary = {}
	var states: Dictionary = {}
	var removed_stations: Array = []
	var removed_states: Array = []
	for key in game.world.stations:
		if full or game.world.stations[key] != last_stations.get(key): stations[key] = game.world.stations[key]
	for key in game.world.block_states:
		if full or game.world.block_states[key] != last_states.get(key): states[key] = game.world.block_states[key]
	for key in last_stations:
		if not game.world.stations.has(key): removed_stations.append(key)
	for key in last_states:
		if not game.world.block_states.has(key): removed_states.append(key)
	last_stations = game.world.stations.duplicate(true)
	last_states = game.world.block_states.duplicate(true)
	state_sequence += 1
	for id in ready_peers: world_state.rpc_id(id,stations,states,removed_stations,removed_states,game.day_time,state_sequence,full)

@rpc("authority","call_remote","reliable",3)
func world_state(stations: Dictionary, states: Dictionary, removed_stations: Array, removed_states: Array, time: float, sequence: int, full: bool = false) -> void:
	if not client() or not loaded_announced or sequence <= received_state: return
	received_state = sequence
	game.day_time = time
	# Deltas keep ordinary traffic small; checkpoints also remove client-only
	# predictions, even if the authoritative state did not change afterwards.
	if full:
		removed_stations = removed_stations.duplicate()
		removed_states = removed_states.duplicate()
		for key in game.world.stations:
			if not stations.has(key): removed_stations.append(key)
		for key in game.world.block_states:
			if not states.has(key): removed_states.append(key)
	# Preserve the open station reference used by the HUD while updating its data.
	for key in stations:
		if sequence < int(station_sequences.get(key,-1)): continue
		if game.world.stations.get(key) == stations[key]: continue
		if game.world.stations.has(key):
			var local: Dictionary = game.world.stations[key]
			local.clear(); local.merge(stations[key].duplicate(true))
		else: game.world.stations[key] = stations[key].duplicate(true)
	for key in removed_stations:
		if sequence >= int(station_sequences.get(key,-1)): game.world.stations.erase(key)
	var changed_states: Dictionary = {}
	for key in states:
		if game.world.block_states.get(key) != states[key]:
			changed_states[key] = true
			game.world.block_states[key] = states[key].duplicate(true)
	for key in removed_states:
		if game.world.block_states.erase(key): changed_states[key] = true
	for p in game.world.circuits.tracked:
		var key: String = game.world.station_key(p)
		if changed_states.has(key): game.world.circuits.refresh(p)
	for key in changed_states:
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() != 3: continue
		var p := Vector3i(int(parts[0]),int(parts[1]),int(parts[2]))
		if CocoaCrops.is_cocoa(game.world.node_at(p)): game.world._mark_dirty(p)

@rpc("authority","call_remote","reliable",3)
func entity_state(entries: Array, sequence: int) -> void:
	if not client() or not loaded_announced or sequence <= received_entities: return
	received_entities = sequence
	apply_entities(entries,sequence)

# Only transforms travel unreliably. Each bounded packet is independent and
# each entity has its own sequence, so losing one batch does not discard others.
static func entity_motion_batches(entries: Array) -> Array:
	var batches: Array = []
	var batch: Array = []
	for entry in entries:
		batch.append([entry.key,entry.at,float(entry.get("yaw",0.0))])
		if batch.size() == ENTITY_MOTION_BATCH:
			batches.append(batch); batch = []
	if not batch.is_empty(): batches.append(batch)
	return batches

@rpc("authority","call_remote","unreliable",4)
func entity_motion(samples: Array, sequence: int) -> void:
	if not client() or not loaded_announced: return
	for sample in samples:
		var key: int = sample[0]
		if not replicas.has(key) or sequence <= int(replica_sequences.get(key,-1)): continue
		replica_sequences[key] = sequence
		replica_motion[key].update(sample[1],sample[2])

func entity_snapshot() -> Array:
	var result: Array = []
	for mob in game.creatures.get_children():
		if not mob.is_queued_for_deletion(): result.append({"key":mob.get_instance_id(),"kind":mob.kind,"at":mob.position,"yaw":mob.rotation.y,"health":mob.health})
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion(): result.append({"key":drop.get_instance_id(),"kind":"drop","at":drop.position,"stack":{"id":drop.item_id,"count":drop.amount,"wear":drop.wear,"data":drop.data}})
	for orb in XpOrbs.orbs(game):
		result.append({"key":orb.get_instance_id(),"kind":"xp_orb","at":orb.position,"xp":orb.xp})
	return result

func apply_entities(entries: Array, sequence: int = 0) -> void:
	for local in game.creatures.get_children()+game.drops.get_children()+XpOrbs.orbs(game):
		if not local.has_meta("network_id"): local.queue_free()
	applying = true
	var seen: Dictionary = {}
	for entry in entries:
		var key: int = entry.key; seen[key] = true
		if not replicas.has(key) or not is_instance_valid(replicas[key]):
			var entity: Node3D
			if entry.kind == "xp_orb":
				entity = XpOrbs.spawn(game,entry.at,int(entry.xp),Vector3.ZERO)
			elif entry.kind == "drop":
				entity = game.spawn_drop(entry.at,entry.stack.id,entry.stack.count,entry.stack.wear,entry.stack.data)
			else: entity = game.spawn_creature(entry.kind,entry.at)
			if entity == null: continue
			entity.set_meta("network_id",key); entity.set_process(false); entity.set_physics_process(false)
			replicas[key] = entity
		var entity: Node3D = replicas[key]
		if not replica_motion.has(key): replica_motion[key] = NetworkMotion.new()
		var motion: NetworkMotion = replica_motion[key]
		if sequence >= int(replica_sequences.get(key,-1)):
			replica_sequences[key] = sequence
			motion.update(entry.at,float(entry.get("yaw",0.0)))
		entity.position = motion.current
		if entry.kind == "xp_orb": entity.xp = int(entry.xp)
		elif entry.kind != "drop": entity.rotation.y = motion.current_yaw; entity.health = entry.health
		else:
			entity.amount = int(entry.stack.count); entity.wear = int(entry.stack.wear); entity.data = entry.stack.data.duplicate(true)
		if entry.kind == "drop" and game.playing() and game.player.position.distance_to(entry.at) < 2.0 and game.inventory.capacity(entry.stack.id,entry.stack.wear,entry.stack.data) >= entry.stack.count:
			pickup.rpc_id(1,key)
	for key in replicas.keys():
		if not seen.has(key):
			if is_instance_valid(replicas[key]): replicas[key].queue_free()
			replicas.erase(key)
			replica_motion.erase(key)
			replica_sequences.erase(key)

	applying = false

func _update_replica_motion(delta: float) -> void:
	for key in replica_motion:
		if not is_instance_valid(replicas.get(key)): continue
		var motion: NetworkMotion = replica_motion[key]
		motion.advance(delta)
		replicas[key].position = motion.current
		if not replicas[key] is ItemDrop: replicas[key].rotation.y = motion.current_yaw

func _bag(id: int) -> Inventory:
	return game.inventory if id == 1 else peer_bags.get(id)

func _remove_stack(bag: Inventory, stack: Dictionary) -> bool:
	var count: int = int(stack.count)
	var available: int = 0
	for slot in bag.slots:
		if slot.id == stack.id and slot.wear == stack.wear and slot.get("data",{}) == stack.get("data",{}): available += int(slot.count)
	if available < count: return false
	var indices: Array = [bag.selected]
	for index in bag.slots.size():
		if index != bag.selected: indices.append(index)
	for index in indices:
		var slot: Dictionary = bag.slots[index]
		if slot.id != stack.id or slot.wear != stack.wear or slot.get("data",{}) != stack.get("data",{}): continue
		var taken: int = mini(count,int(slot.count)); slot.count -= taken; count -= taken
		if slot.count == 0: slot.clear(); slot.merge({"id":0,"count":0,"wear":0})
		if count == 0: break
	bag.changed.emit()
	return true

# Credit the server's copy before delivery. Old client snapshots cannot erase
# a new pickup, and a disconnect still leaves the item in its saved inventory.
func _deliver(id: int, stack: Dictionary, source: int = 0) -> bool:
	var bag: Inventory = _bag(id)
	if bag == null or bag.capacity(stack.id,stack.wear,stack.get("data",{})) < int(stack.count): return false
	bag.add_item(stack.id,stack.count,stack.wear,stack.get("data",{}))
	if id == 1:
		game.sound("pickup"); game.progress("gather")
		return true
	peer_revisions[id] = int(peer_revisions.get(id,0))+1
	_persist_inventory(id)
	if players.has(id):
		delivery_serial += 1
		deliveries[delivery_serial] = {"to":id,"from":source,"stack":stack.duplicate(true)}
		give_item.rpc_id(id,stack,int(peer_revisions[id]),delivery_serial)
	return true

@rpc("any_peer","call_remote","reliable",2)
func pickup(key: int) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not is_instance_id_valid(key): return
	var drop: Object = instance_from_id(key)
	if not drop is ItemDrop or drop.get_parent() != game.drops or drop.is_queued_for_deletion() or drop.age < 0.6 or drop.pickup_delay > 0 or not reachable(sender,Vector3i(drop.position.floor()),3): return
	if _deliver(sender,{"id":drop.item_id,"count":drop.amount,"wear":drop.wear,"data":drop.data}): drop.queue_free()

@rpc("authority","call_remote","reliable",2)
func give_item(stack: Dictionary, revision: int, serial: int) -> void:
	if not client() or revision <= inventory_revision: return
	inventory_revision = revision
	var clean: Dictionary = Inventory.clean_slot(stack)
	var accepted: bool = clean.id != 0 and game.inventory.capacity(clean.id,clean.wear,clean.get("data",{})) >= int(clean.count)
	if accepted:
		game.inventory.add_item(clean.id,clean.count,clean.wear,clean.get("data",{})); game.sound("pickup"); game.progress("gather")
	delivery_reply.rpc_id(1,serial,accepted,inventory_snapshot())

@rpc("any_peer","call_remote","reliable",2)
func delivery_reply(serial: int, accepted: bool, data: Dictionary) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not deliveries.has(serial) or int(deliveries[serial].to) != sender: return
	var delivery: Dictionary = deliveries[serial]; deliveries.erase(serial)
	var received: bool = _receive_inventory(sender,data)
	if accepted: return
	if not received: _remove_stack(_bag(sender),delivery.stack); _persist_inventory(sender)
	_refund(int(delivery.from),delivery.stack,players.get(sender,{}).get("position",game.player.position))

func _refund(id: int, stack: Dictionary, at: Vector3) -> void:
	if id > 0 and _deliver(id,stack):
		if id == 1: game.toast("Their inventory is full; your item was returned.")
		return
	game.spawn_drop(at,stack.id,stack.count,stack.wear,stack.get("data",{}))

func target_player() -> int:
	if not active() or not session_ready: return 0
	var eye: Vector3 = game.player.camera.global_position
	var direction: Vector3 = -game.player.camera.global_basis.z
	var nearest: float = minf(4.0,float(game.player.target.get("distance",4.0)))
	var found: int = 0
	for id in players:
		if id == multiplayer.get_unique_id(): continue
		var at: Vector3 = avatars[id].position if avatars.has(id) and is_instance_valid(avatars[id]) else players[id].position
		var center: Vector3 = at+Vector3.UP*0.9
		var along: float = (center-eye).dot(direction)
		if along > 0 and along < nearest and (eye+direction*along).distance_to(center) < 0.8: found = id; nearest = along
	return found

func pass_held(target: int, whole_stack: bool = false) -> bool:
	if not active() or not players.has(target): return false
	var stack: Dictionary = Inventory.clean_slot(game.inventory.held())
	if stack.id == 0: return false
	if not whole_stack: stack.count = 1
	if client():
		pass_item.rpc_id(1,target,stack,game.player.position,inventory_snapshot())
		game.inventory.consume_selected(stack.count)
	else:
		_transfer(1,target,stack)
	return true

@rpc("any_peer","call_remote","reliable",2)
func pass_item(target: int, stack: Dictionary, at: Vector3, data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _action_position(sender,at,int(data.get("motion",0))): return
	if not _receive_inventory(sender,data): _resync_inventory(sender); return
	_transfer(sender,target,Inventory.clean_slot(stack))

func _transfer(sender: int, target: int, stack: Dictionary) -> void:
	var bag: Inventory = _bag(sender)
	if stack.id == 0 or bag == null: return
	if sender == target or not players.has(target) or not reachable(sender,Vector3i(players[target].position.floor()),5):
		if sender != 1: _remove_stack(bag,stack); _persist_inventory(sender); _refund(sender,stack,players[sender].position)
		return
	if not _remove_stack(bag,stack):
		if sender != 1: _refund(sender,stack,players[sender].position)
		return
	if sender != 1: _persist_inventory(sender)
	if not _deliver(target,stack,sender): _refund(sender,stack,players[sender].position)

func collect_drop(drop: ItemDrop, delta: float) -> bool:
	var nearest: int = 0; var distance: float = 2.4
	for id in players:
		var health: float = game.player.health if id == 1 else float(game.world.adventure_state.get("network_players",{}).get(peer_identity.get(id,""),{}).get("health",20))
		if health <= 0: continue
		var bag: Inventory = _bag(id)
		if bag == null or bag.capacity(drop.item_id,drop.wear,drop.data) < drop.amount: continue
		var gap: float = drop.position.distance_to(players[id].position+Vector3.UP*0.8)
		if gap < distance: nearest = id; distance = gap
	if nearest == 0: return false
	drop.position = drop.position.move_toward(players[nearest].position+Vector3.UP*0.8,delta*8)
	if distance < 0.65 and _deliver(nearest,{"id":drop.item_id,"count":drop.amount,"wear":drop.wear,"data":drop.data}): drop.queue_free()
	return true

# XP orbs are host-simulated entities. Any living nearby player may collect
# them, and only a host pickup emits an award (including Mending on the guest).
func xp_player(id: int) -> Dictionary:
	if id == 1: return {"position":game.player.position,"velocity":game.player.velocity,"health":game.player.health}
	if not players.has(id) or not ready_peers.has(id): return {}
	var saved: Dictionary = game.world.adventure_state.get("network_players",{}).get(peer_identity.get(id,""),{})
	return {"position":players[id].position,"velocity":players[id].get("velocity",Vector3.ZERO),"health":float(saved.get("health",20))}
func xp_collector(at: Vector3) -> int:
	for id in players:
		var player: Dictionary = xp_player(id)
		if not player.is_empty() and float(player.health) > 0 and at.distance_to(player.position+Vector3.UP*XpOrbs.COLLECT_HEIGHT) < XpOrbs.MAGNET_RANGE: return id
	return 0
func award_xp(id: int, amount: int) -> void:
	if amount <= 0 or not active() or not multiplayer.is_server(): return
	if id == 1: XpOrbs.award(game,amount); return
	if not ready_peers.has(id): return
	var saved: Dictionary = game.world.adventure_state.get("network_players",{}).get(peer_identity.get(id,""),{})
	_persist_inventory(id,{"experience":float(saved.get("experience",0))+amount})
	collected_xp.rpc_id(id,amount)
@rpc("authority","call_remote","reliable",2)
func collected_xp(amount: int) -> void:
	if not client(): return
	XpOrbs.award(game,maxi(0,amount)); send_inventory()

func hit_mob(mob: Node3D, damage: float, reason: String, armor_breach: int = 0) -> void:
	if mob.has_meta("network_id"): attack.rpc_id(1,int(mob.get_meta("network_id")),damage,reason,armor_breach)

@rpc("any_peer","call_remote","reliable")
func attack(key: int, damage: float, reason: String, armor_breach: int = 0) -> void:
	if not multiplayer.is_server() or not is_instance_id_valid(key) or not is_finite(damage): return
	var mob: Object = instance_from_id(key)
	var sender: int = multiplayer.get_remote_sender_id()
	if not mob is Creature or mob.is_queued_for_deletion() or not reachable(sender,Vector3i(mob.position.floor()),100): return
	mob.hit(clampf(damage,0,20),players[sender].position,reason,clampi(armor_breach,0,4))

func station_click(index: int, is_station: bool, right: bool, shift: bool) -> bool:
	if not client() or not station_open or game.hud.station not in ["chest","furnace","steam","brewing","stonecutter","grindstone","smithing"]: return false
	if station_busy: return true
	if not is_station and not shift: return false
	station_busy = true
	station_action.rpc_id(1,station_pos,game.hud.station,index,is_station,right,shift,inventory_snapshot())
	return true

static func accepts_slot(s: Dictionary, kind: String, index: int, id: int) -> bool:
	if s.get("books_only",false) and not Bookshelves.plain_allows(id): return false
	if kind == "steam": return SteamMachines.accepts(s,index,id)
	if kind == "furnace": return FurnaceRules.accepts(s.slots,index,id)
	if kind == "brewing": return Brewing.accepts(index,id)
	if kind == "stonecutter": return Stonecutting.accepts(index,id)
	if kind == "grindstone": return GrindstoneRepair.accepts(index,id)
	if kind == "smithing": return Smithing.accepts(index,id)
	return id == 0 or Nodes.exists(id)

@rpc("any_peer","call_remote","reliable",2)
func station_action(p: Vector3i, kind: String, index: int, is_station: bool, right: bool, shift: bool, data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not reachable(sender,p) or kind not in ["chest","furnace","steam","brewing","stonecutter","grindstone","smithing"] or (kind == "stonecutter" and not Stonecutting.is_cutter(game.world.node_at(p))) or (kind == "grindstone" and not GrindstoneRepair.is_grindstone(game.world.node_at(p))) or (kind == "smithing" and game.world.node_at(p) != VillageContent.SMITHING_TABLE) or (kind not in ["stonecutter","grindstone","smithing"] and game.world.node_at(p) not in RedstoneCircuit.CONTAINERS):
		station_denied.rpc_id(sender); return
	if not _receive_inventory(sender,data): station_denied.rpc_id(sender,false); return
	var s: Dictionary = game.world.get_station(p,kind)
	var inv: Inventory = peer_bags[sender]
	var cursor: Dictionary = Inventory.clean_slot(data.get("cursor",{}))
	var source: Array = s.slots if is_station else inv.slots
	if index < 0 or index >= source.size(): station_denied.rpc_id(sender); return
	var slot: Dictionary = source[index]
	var furnace_output_before: int = int(s.slots[2].count) if kind == "furnace" and is_station and index == 2 else -1
	var furnace_before: Array = s.slots.duplicate(true) if kind == "furnace" else []
	var cut_before: Array = s.slots.duplicate(true) if kind == "stonecutter" else []
	var grind_before: Array = s.slots.duplicate(true) if kind == "grindstone" else []
	var smith_before: Array = s.slots.duplicate(true) if kind == "smithing" else []
	var allowed: bool = not is_station or not s.get("books_only",false) or Bookshelves.plain_allows(int(slot.id)) and Bookshelves.plain_allows(int(cursor.id))
	if not allowed:
		pass # Still acknowledge an unchanged inventory so the guest UI unlocks.
	elif shift and cursor.id == 0:
		if is_station:
			slot.count = inv.add_item(slot.id,slot.count,slot.wear,slot.get("data",{}))
			if slot.count == 0: source[index] = {"id":0,"count":0,"wear":0}
		else:
			if kind == "furnace": FurnaceRules.quick_move(s,slot)
			if kind == "smithing": Smithing.quick_move(s,slot)
			for n in ([] if kind in ["furnace","smithing"] else range(s.slots.size())):
				if not accepts_slot(s,kind,n,slot.id): continue
				while slot.id != 0 and slot.count > 0 and RedstoneCircuit.insert_one([s.slots[n]],slot):
					RedstoneCircuit.consume_one(slot)
	elif cursor.id == 0:
		var count: int = ceili(slot.count/2.0) if right else slot.count
		cursor = slot.duplicate(true); cursor.count = count
		slot.count -= count
		if slot.count == 0: source[index] = {"id":0,"count":0,"wear":0}
	elif not is_station or (Smithing.accepts(index,cursor) if kind == "smithing" else accepts_slot(s,kind,index,cursor.id)):
		if slot.id == 0 or (slot.id == cursor.id and slot.get("data",{}) == cursor.get("data",{})):
			var count: int = mini(1 if right else cursor.count,Nodes.max_stack(cursor.id)-int(slot.count))
			if is_station and kind == "furnace": count = mini(count,FurnaceRules.allowed_count(s.slots,index,cursor))
			if count > 0:
				if slot.id == 0: source[index] = cursor.duplicate(true); source[index].count = 0
				source[index].count += count; cursor.count -= count
				if cursor.count == 0: cursor = {"id":0,"count":0,"wear":0}
		elif not right:
			if not is_station or kind != "furnace" or FurnaceRules.allowed_count(s.slots,index,cursor) >= int(cursor.count):
				var swap: Dictionary = source[index]; source[index] = cursor; cursor = swap
	if kind == "stonecutter": Stonecutting.after_transfer(s,cut_before)
	if kind == "grindstone":
		var xp: int = GrindstoneRepair.after_transfer(s,grind_before)
		if xp > 0: XpOrbs.throw_xp(game,Vector3(p)+Vector3.ONE*0.5,xp)
	var smith_event: Dictionary = Smithing.after_transfer(s,smith_before) if kind == "smithing" else {}
	peer_revisions[sender] = int(peer_revisions[sender])+1
	var awarded_xp: int = FurnaceRules.take_xp(s) if furnace_output_before >= 0 and int(s.slots[2].count) < furnace_output_before else 0
	if kind == "furnace" and furnace_before != s.slots: FurnaceRules.reset_clock(s,game.day_time*1200.0)
	var saved_xp: float = float(game.world.adventure_state.get("network_players",{}).get(peer_identity.get(sender,""),{}).get("experience",0))
	_persist_inventory(sender,{"cursor":cursor,"experience":saved_xp+awarded_xp})
	state_sequence += 1
	station_result.rpc_id(sender,p,inv.slots,inv.pouch_slots,cursor,s,int(peer_revisions[sender]),state_sequence,awarded_xp,smith_event)

# A map ID and its immutable image belong to the hosting world. Clients request
# existing records; only a server-side fill can allocate another ID.
func request_map(id: String) -> bool:
	if not client() or not session_ready or not id.is_valid_int() or int(id) < 0: return false
	if requested_maps.has(id): return true
	requested_maps[id] = true
	map_request.rpc_id(1,id)
	return true
@rpc("any_peer","call_remote","reliable",2)
func map_request(id: String) -> void:
	if not multiplayer.is_server() or not id.is_valid_int() or int(id) < 0: return
	var sender: int = multiplayer.get_remote_sender_id()
	# A restored held map can request its image as loading ends, before the
	# world-ready message arrives on the other channel. Map records are
	# self-contained and safe to deliver once this player has joined.
	if not players.has(sender): return
	_send_map(sender,id)
func _send_map(sender: int, id: String) -> void:
	var record: Dictionary = game.maps.public_record(id)
	map_record.rpc_id(sender,id,record)
	if not record.is_empty() and str(record.png).is_empty():
		if not map_waiters.has(id): map_waiters[id] = {}
		map_waiters[id][sender] = true
func map_ready(id: String) -> void:
	if not active() or client() or not map_waiters.has(id): return
	for sender in map_waiters[id]:
		if players.has(sender): map_record.rpc_id(sender,id,game.maps.public_record(id))
	map_waiters.erase(id)
@rpc("authority","call_remote","reliable",2)
func map_record(id: String, record: Dictionary) -> void:
	if not client(): return
	requested_maps[id] = true
	game.maps.accept_remote(id,record)

func map_action_request(kind: String, index: int) -> bool:
	if not client() or not session_ready: return false
	if map_busy: return true
	map_busy = true
	map_action.rpc_id(1,kind,index,game.survival.workstation_pos,game.player.position,inventory_snapshot())
	return true
@rpc("any_peer","call_remote","reliable",2)
func map_action(kind: String, index: int, table_pos: Vector3i, at: Vector3, data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if kind not in ["fill","migrate","copy"] or not _action_position(sender,at,int(data.get("motion",0))) or not _receive_inventory(sender,data):
		_resync_inventory(sender)
		map_action_result.rpc_id(sender,false,kind,{},table_pos); return
	var inv: Inventory = peer_bags[sender]
	var item: Dictionary = {}
	var success: bool = false
	if index >= 0 and index < inv.slots.size():
		if kind == "copy" and reachable(sender,table_pos) and game.world.node_at(table_pos) == VillageContent.CARTOGRAPHY_TABLE:
			game.maps.ensure(inv.slots[index],at)
			success = ExplorationMaps.copy_inventory(inv,index)
			if success: item = inv.slots[index].duplicate(true)
		elif index == inv.selected and kind in ["fill","migrate"]:
			var result: Dictionary = game.maps.fill_inventory(inv,at,kind == "migrate")
			if not result.is_empty():
				item = result.item; success = true
				if int(result.overflow) > 0: game.spawn_drop(at,item.id,int(result.overflow),0,item.data)
	_persist_inventory(sender)
	_resync_inventory(sender)
	if success:
		var id: String = str(item.get("data",{}).get("map",{}).get("id",""))
		_send_map(sender,id)
	map_action_result.rpc_id(sender,success,kind,item,table_pos)
@rpc("authority","call_remote","reliable",2)
func map_action_result(success: bool, kind: String, item: Dictionary, table_pos: Vector3i) -> void:
	if not client(): return
	map_busy = false
	if not success:
		game.toast("Map action could not be completed. Check the inputs and inventory space."); return
	if kind in ["fill","migrate"]: game.maps.show_map(item)
	elif kind == "copy" and game.state == "workstation": game.survival.show_station(table_pos,VillageContent.CARTOGRAPHY_TABLE)

func smithing_open() -> bool:
	if not client() or not station_open or game.hud.station != "smithing": return false
	if station_busy: return true
	station_busy = true
	smithing_refresh.rpc_id(1,station_pos,inventory_snapshot())
	return true
@rpc("any_peer","call_remote","reliable",2)
func smithing_refresh(p: Vector3i, data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not reachable(sender,p) or game.world.node_at(p) != VillageContent.SMITHING_TABLE:
		station_denied.rpc_id(sender); return
	if not _receive_inventory(sender,data): station_denied.rpc_id(sender,false); return
	var state: Dictionary = Smithing.station(game.world,p)
	Smithing.refresh(state)
	var inv: Inventory = peer_bags[sender]
	var cursor: Dictionary = Inventory.clean_slot(data.get("cursor",{}))
	peer_revisions[sender] = int(peer_revisions[sender])+1
	_persist_inventory(sender,{"cursor":cursor})
	state_sequence += 1
	station_result.rpc_id(sender,p,inv.slots,inv.pouch_slots,cursor,state,int(peer_revisions[sender]),state_sequence)

func grindstone_open() -> bool:
	if not client() or not station_open or game.hud.station != "grindstone": return false
	if station_busy: return true
	station_busy = true
	grindstone_refresh.rpc_id(1,station_pos,inventory_snapshot())
	return true
@rpc("any_peer","call_remote","reliable",2)
func grindstone_refresh(p: Vector3i, data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not reachable(sender,p) or not GrindstoneRepair.is_grindstone(game.world.node_at(p)):
		station_denied.rpc_id(sender); return
	if not _receive_inventory(sender,data): station_denied.rpc_id(sender,false); return
	var state: Dictionary = GrindstoneRepair.station(game.world,p)
	GrindstoneRepair.refresh(state)
	var inv: Inventory = peer_bags[sender]
	var cursor: Dictionary = Inventory.clean_slot(data.get("cursor",{}))
	peer_revisions[sender] = int(peer_revisions[sender])+1
	_persist_inventory(sender,{"cursor":cursor})
	state_sequence += 1
	station_result.rpc_id(sender,p,inv.slots,inv.pouch_slots,cursor,state,int(peer_revisions[sender]),state_sequence)

func stonecutting_select(name: String, fill: bool = false, opening: bool = false) -> bool:
	if not client() or not station_open or game.hud.station != "stonecutter": return false
	if station_busy: return true
	station_busy = true
	stonecutting_action.rpc_id(1,station_pos,name,fill,opening,inventory_snapshot())
	return true
@rpc("any_peer","call_remote","reliable",2)
func stonecutting_action(p: Vector3i, name: String, fill: bool, opening: bool, data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not reachable(sender,p) or not Stonecutting.is_cutter(game.world.node_at(p)):
		station_denied.rpc_id(sender); return
	if not _receive_inventory(sender,data): station_denied.rpc_id(sender,false); return
	var state: Dictionary = Stonecutting.station(game.world,p)
	if opening: Stonecutting.refresh(state)
	elif fill: Stonecutting.fill(state)
	else: Stonecutting.select(state,name)
	var inv: Inventory = peer_bags[sender]
	var cursor: Dictionary = Inventory.clean_slot(data.get("cursor",{}))
	peer_revisions[sender] = int(peer_revisions[sender])+1
	_persist_inventory(sender,{"cursor":cursor})
	state_sequence += 1
	station_result.rpc_id(sender,p,inv.slots,inv.pouch_slots,cursor,state,int(peer_revisions[sender]),state_sequence)

@rpc("authority","call_remote","reliable",2)
func station_result(p: Vector3i, inventory: Array, pouches: Array, cursor: Dictionary, s: Dictionary, revision: int, sequence: int, awarded_xp: int = 0, smith_event: Dictionary = {}) -> void:
	if not client(): return
	station_busy = false
	if revision < inventory_revision: return
	inventory_revision = revision
	game.inventory.restore(inventory,pouches); game.hud.cursor = Inventory.clean_slot(cursor)
	XpOrbs.award(game,maxi(0,awarded_xp))
	Smithing.award(game,smith_event)
	send_inventory()
	var key: String = game.world.station_key(p)
	# An earlier bulk snapshot may still be in flight on the world-state channel.
	station_sequences[key] = sequence
	if sequence >= received_state:
		if game.world.stations.has(key):
			game.world.stations[key].clear(); game.world.stations[key].merge(s.duplicate(true))
		else: game.world.stations[key] = s.duplicate(true)
	if station_open and station_pos == p:
		game.hud.station_data = game.world.stations[key]
		game.hud.refresh_slots()

# Prefer physical LAN interfaces; keep other non-loopback IPv4 addresses as
# fallbacks so hosts with VPNs or multiple adapters can still share an address.
static func local_ip_addresses() -> PackedStringArray:
	var preferred: PackedStringArray = []
	var fallback: PackedStringArray = []
	for interface in IP.get_local_interfaces():
		var name_text: String = str(interface.get("name","")).to_lower()
		var virtual: bool = name_text.begins_with("docker") or name_text.begins_with("veth") or name_text.begins_with("br-") or name_text.begins_with("virbr")
		for address in interface.get("addresses",[]):
			var ip_text: String = str(address)
			if not ip_text.is_valid_ip_address() or ip_text.contains(":") or ip_text.begins_with("127.") or ip_text.begins_with("169.254.") or ip_text == "0.0.0.0": continue
			if virtual:
				if ip_text not in fallback: fallback.append(ip_text)
			elif ip_text not in preferred: preferred.append(ip_text)
	for ip_text in fallback:
		if ip_text not in preferred: preferred.append(ip_text)
	return preferred

func local_ip() -> String:
	var addresses: PackedStringArray = local_ip_addresses()
	return addresses[0] if not addresses.is_empty() else "127.0.0.1"

func join_address() -> String:
	return "%s:%d"%[share_address if not share_address.is_empty() else local_ip(),server_port]

@rpc("authority","call_remote","reliable",2)
func station_denied(close: bool = true) -> void:
	station_busy = false
	if not client(): return
	if close: game.resume(); game.toast("That storage is no longer in reach. Open it again.")
	else: game.toast("Your inventory updated. Try that move again.")

func settings_snapshot() -> Dictionary:
	return {"name":game.world_name,"gamemode":game.gamemode,"difficulty":game.difficulty,"rules":game.game_rules.duplicate(),"max_players":player_limit,"day_time":game.day_time}

func publish_settings() -> void:
	if active() and multiplayer.is_server(): settings_changed.rpc(settings_snapshot())

@rpc("authority","call_remote","reliable")
func settings_changed(value: Dictionary) -> void:
	if not client(): return
	game.world_name = str(value.get("name",game.world_name)).left(64)
	game.gamemode = "creative" if value.get("gamemode") == "creative" else "survival"
	game.difficulty = clampi(int(value.get("difficulty",1)),0,2)
	game.game_rules = GameRules.restore(value.get("rules",{}))
	game.day_time = float(value.get("day_time",game.day_time))
	player_limit = clampi(int(value.get("max_players",MAX_PLAYERS)),1,MAX_PLAYERS)

@rpc("any_peer","call_remote","reliable")
func configure_node(p: Vector3i, direction: Vector3i, support: Vector3i) -> void:
	if not multiplayer.is_server() or not reachable(multiplayer.get_remote_sender_id(),p): return
	if absi(direction.x)+absi(direction.y)+absi(direction.z) != 1: return
	var sender: int = multiplayer.get_remote_sender_id()
	_flush_actions()
	if not game.world.loaded_at(Vector3(p)):
		_queue_action({"peer":sender,"pos":p,"direction":direction,"support":support}); return
	_configure_node(sender,p,direction,support)

func _configure_node(sender: int, p: Vector3i, direction: Vector3i, support: Vector3i) -> void:
	if not reachable(sender,p): return
	if not RedstoneCircuit.circuit_node(game.world.node_at(p)): return
	game.world.circuits.configure(p,direction,support)

@rpc("any_peer","call_remote","reliable")
func use_node(p: Vector3i) -> void:
	if not multiplayer.is_server() or not reachable(multiplayer.get_remote_sender_id(),p): return
	var sender: int = multiplayer.get_remote_sender_id()
	_flush_actions()
	if not game.world.loaded_at(Vector3(p)):
		_queue_action({"peer":sender,"pos":p,"use":true}); return
	_use_node(sender,p)

func _use_node(sender: int, p: Vector3i) -> void:
	if not reachable(sender,p): return
	if RedstoneInputs.is_button(game.world.node_at(p)): RedstoneInputs.press(game.world,p)
	else: game.world.circuits.interact(p)

@rpc("any_peer","call_remote","reliable",2)
func use_trial(p: Vector3i, data: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not reachable(sender,p) or not game.world.loaded_at(Vector3(p)) or not Trials.is_vault(game.world.node_at(p)): return
	if not _receive_inventory(sender,data): _resync_inventory(sender); return
	var bag: Inventory = _bag(sender)
	Trials.open_vault(game.world,p,Trials.identity(game,sender),bag.held(),game.gamemode == "creative")
	_persist_inventory(sender)
	_resync_inventory(sender)

@rpc("any_peer","call_remote","reliable",2)
func drop_item(stack: Dictionary, origin: Vector3, direction: Vector3, at: Vector3, data: Dictionary) -> void:
	if not multiplayer.is_server() or not origin.is_finite() or not direction.is_finite(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _action_position(sender,at,int(data.get("motion",0))) or not reachable(sender,Vector3i(origin.floor()),3): return
	if not _receive_inventory(sender,data): _resync_inventory(sender); return
	var cleaned: Dictionary = Inventory.clean_slot(stack)
	if cleaned.id == 0: return
	if data.get("drop_from_cursor",false):
		var cursor: Dictionary = Inventory.clean_slot(data.get("cursor",{}))
		if cursor.id != cleaned.id or cursor.wear != cleaned.wear or cursor.get("data",{}) != cleaned.get("data",{}) or int(cursor.count) < int(cleaned.count): return
		cursor.count -= cleaned.count
		_persist_inventory(sender,{"cursor":Inventory.clean_slot(cursor)})
	else:
		if not _remove_stack(_bag(sender),cleaned): return
		_persist_inventory(sender)
	var drop: ItemDrop = game.spawn_drop(origin,cleaned.id,cleaned.count,cleaned.wear,cleaned.get("data",{}))
	if drop != null: drop.velocity = direction.normalized()*5+Vector3.UP*1.5; drop.pickup_delay = 1.5

func carry_player(id: int, at: Vector3) -> void:
	if not active() or not multiplayer.is_server() or not players.has(id): return
	players[id].position = at
	move_player.rpc_id(id,at)

@rpc("authority","call_remote","reliable")
func move_player(at: Vector3) -> void:
	if client(): game.player.position = at

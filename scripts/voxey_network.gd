class_name VoxeyNetwork
extends Node

const DEFAULT_PORT = 24570
const PROTOCOL = 1
const MAX_PLAYERS = 16
var game: Node3D
var peer: ENetMultiplayerPeer
var status: String = "Offline"
var players: Dictionary = {}
var avatars: Dictionary = {}
var replicas: Dictionary = {}
var pending_edits: Dictionary = {}
var applying: bool = false
var session_ready: bool = false
var timer: float = 0.0
var state_timer: float = 0.0
var appearance: Dictionary = CharacterSkin.DEFAULT.duplicate()
var station_pos := Vector3i.ZERO
var station_open: bool = false
var station_busy: bool = false
var connection_time: float = 0.0
var identity_id: String = ""
var server_port: int = DEFAULT_PORT
var player_limit: int = MAX_PLAYERS
var share_address: String = ""

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
	var error: Error = peer.create_server(port,MAX_PLAYERS-1,3)
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
	var error: Error = peer.create_client(address.strip_edges(),port,3)
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
	station_open = false; station_busy = false; status = "Offline"
	if game != null and game.world != null:
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
	players.erase(id)
	if avatars.has(id): avatars[id].queue_free(); avatars.erase(id)
	if active() and multiplayer.is_server(): remove_player.rpc(id)

@rpc("authority","call_remote","reliable")
func remove_player(id: int) -> void:
	players.erase(id)
	if avatars.has(id): avatars[id].queue_free(); avatars.erase(id)

@rpc("any_peer","call_remote","reliable")
func hello(protocol: int, skin: Dictionary, identity: String) -> void:
	if not active() or not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL or players.size() >= player_limit: peer.disconnect_peer(sender); return
	players[sender] = {"skin":CharacterSkin.clean(skin),"position":game.player.position+Vector3(2,0,0),"yaw":0.0,"identity":identity.left(64)}
	var saved: Dictionary = game.world.adventure_state.get("network_players",{}).get(identity,{})
	var snapshot: Dictionary = game.dimension_snapshot()
	var data: Dictionary = {"version":game.SAVE_VERSION,"world_id":"","name":game.world_name,"seed":game.world.seed_value,"gamemode":game.gamemode,"difficulty":game.difficulty,"dimension":game.dimension,"edits":snapshot.edits,"growth":snapshot.growth,"stations":snapshot.stations,"block_states":snapshot.block_states,"adventure":snapshot.adventure,"position":[game.player.position.x+2,game.player.position.y,game.player.position.z],"spawn":[game.spawn_point.x,game.spawn_point.y,game.spawn_point.z],"inventory":[],"time":game.day_time,"settings":{"distance":game.world.radius},"gamerules":game.game_rules}
	if not saved.is_empty():
		data.inventory = saved.get("inventory",[])
		data.cursor = saved.get("cursor",{})
		data.health = saved.get("health",20)
		data.hunger = saved.get("hunger",20)
	welcome.rpc_id(sender,data,players)
	settings_changed.rpc_id(sender,settings_snapshot())

@rpc("authority","call_remote","reliable")
func welcome(data: Dictionary, roster: Dictionary) -> void:
	if not client(): return
	applying = true
	game.load_world_data(data)
	game.hud.show_loading()
	players = roster; session_ready = true; applying = false
	status = "Connected to "+game.world_name

func update(dt: float) -> void:
	if not active(): return
	if not session_ready:
		connection_time += dt
		if connection_time > 20: _failed()
		return
	if client(): game.world.active = false
	elif game.state != "loading": game.world.active = true
	if game.state == "loading": return
	timer += dt; state_timer += dt
	if timer < 0.1: return
	timer = 0
	var own: int = multiplayer.get_unique_id()
	var record: Dictionary = {"skin":appearance,"position":game.player.position,"yaw":game.player.rotation.y}
	players[own] = record
	if client():
		player_state.rpc_id(1,record)
		if state_timer >= 1.0:
			state_timer = 0
			inventory_state.rpc_id(1,game.inventory.slots,game.hud.cursor,game.player.health,game.player.hunger)
	else:
		player_roster.rpc(players)
		if not pending_edits.is_empty():
			var changes: Array = []
			for p in pending_edits: changes.append([p,pending_edits[p]])
			pending_edits.clear(); apply_edits.rpc(changes)
		var centers: Array[Vector2i] = []
		for id in players:
			if id != 1:
				var p: Vector3 = players[id].position
				centers.append(Vector2i(floori(p.x/16),floori(p.z/16)))
		if game.world.interest_centers != centers:
			game.world.interest_centers = centers; game.world.desired = Vector2i(999999,999999)
		if state_timer >= 0.5:
			state_timer = 0
			world_state.rpc(game.world.stations,game.world.block_states,game.day_time,entity_snapshot())
	update_avatars()

@rpc("any_peer","call_remote","unreliable_ordered",1)
func player_state(record: Dictionary) -> void:
	if not active() or not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not players.has(sender) or not record.get("position") is Vector3: return
	var at: Vector3 = record.position
	if not at.is_finite() or not WorldBounds.horizontal(Vector3i(at.floor())): return
	var identity: String = players[sender].get("identity","")
	players[sender] = {"position":at,"yaw":float(record.get("yaw",0)),"skin":CharacterSkin.clean(record.get("skin",{})),"identity":identity}

@rpc("any_peer","call_remote","reliable",2)
func inventory_state(items: Array, cursor: Dictionary, health: float, hunger: float) -> void:
	if not active() or not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not players.has(sender): return
	var identity: String = players[sender].get("identity","")
	if identity.is_empty(): return
	var bag: Array = []
	for i in mini(36,items.size()): bag.append(Inventory.clean_slot(items[i]))
	if not game.world.adventure_state.has("network_players"): game.world.adventure_state["network_players"] = {}
	game.world.adventure_state.network_players[identity] = {"inventory":bag,"cursor":Inventory.clean_slot(cursor),"health":clampf(health,0,20),"hunger":clampf(hunger,0,20)}

@rpc("authority","call_remote","reliable",2)
func player_roster(roster: Dictionary) -> void:
	if client(): players = roster

func update_avatars() -> void:
	for id in players:
		if id == multiplayer.get_unique_id(): continue
		if not avatars.has(id):
			var avatar := NetworkAvatar.new(); game.add_child(avatar); avatar.set_meta("peer_id",id); avatars[id] = avatar
		avatars[id].set_appearance(players[id].skin)
		avatars[id].move_to(players[id].position,players[id].yaw)

func local_edit(p: Vector3i, id: int) -> void:
	if not active() or applying or not session_ready: return
	if multiplayer.is_server(): pending_edits[p] = id
	else: request_edit.rpc_id(1,p,id)

func reachable(sender: int, p: Vector3i, distance: float = 9) -> bool:
	return players.has(sender) and Vector3(p).distance_to(players[sender].position) <= distance

@rpc("any_peer","call_remote","reliable")
func request_edit(p: Vector3i, id: int) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not reachable(sender,p) or not Nodes.exists(id) or not (Nodes.placeable(id) or id in [Nodes.AIR,Nodes.WATER,Nodes.LAVA] or VillageContent.DATA.get(id,{}).get("block",false) or Doors.is_door(id) or Trapdoors.is_trapdoor(id)): return
	if game.gamemode != "creative" and id in [Nodes.BEDROCK,CommandBlocks.ID]: return
	if not game.world.set_node(p,id): return

func request_break(p: Vector3i, id: int, tool: int) -> void:
	break_block.rpc_id(1,p,id,tool)

@rpc("any_peer","call_remote","reliable")
func break_block(p: Vector3i, expected: int, tool: int) -> void:
	if not multiplayer.is_server() or not reachable(multiplayer.get_remote_sender_id(),p): return
	if game.world.node_at(p) != expected or Nodes.hardness(expected) < 0: return
	game.break_node(p,expected,tool)

@rpc("authority","call_remote","reliable")
func apply_edits(changes: Array) -> void:
	if not client(): return
	applying = true
	for entry in changes:
		if not game.world.set_node(entry[0],entry[1]): game.world.record_edit(entry[0],entry[1])
	applying = false

@rpc("authority","call_remote","reliable",2)
func world_state(stations: Dictionary, states: Dictionary, time: float, entities: Array) -> void:
	if not client() or game.state == "loading": return
	game.day_time = time
	# Preserve the open station reference used by the HUD while updating its data.
	for key in stations:
		if game.world.stations.has(key):
			var local: Dictionary = game.world.stations[key]
			local.clear(); local.merge(stations[key].duplicate(true))
		else: game.world.stations[key] = stations[key].duplicate(true)
	for key in game.world.stations.keys():
		if not stations.has(key): game.world.stations.erase(key)
	game.world.block_states = states.duplicate(true)
	for p in game.world.circuits.tracked: game.world.circuits.refresh(p)
	apply_entities(entities)

func entity_snapshot() -> Array:
	var result: Array = []
	for mob in game.creatures.get_children():
		if not mob.is_queued_for_deletion(): result.append({"key":mob.get_instance_id(),"kind":mob.kind,"at":mob.position,"yaw":mob.rotation.y,"health":mob.health})
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion(): result.append({"key":drop.get_instance_id(),"kind":"drop","at":drop.position,"stack":{"id":drop.item_id,"count":drop.amount,"wear":drop.wear,"data":drop.data}})
	return result

func apply_entities(entries: Array) -> void:
	for local in game.creatures.get_children()+game.drops.get_children():
		if not local.has_meta("network_id"): local.queue_free()
	applying = true
	var seen: Dictionary = {}
	for entry in entries:
		var key: int = entry.key; seen[key] = true
		if not replicas.has(key) or not is_instance_valid(replicas[key]):
			var entity: Node3D
			if entry.kind == "drop":
				entity = game.spawn_drop(entry.at,entry.stack.id,entry.stack.count,entry.stack.wear,entry.stack.data)
			else: entity = game.spawn_creature(entry.kind,entry.at)
			if entity == null: continue
			entity.set_meta("network_id",key); entity.set_process(false); entity.set_physics_process(false)
			replicas[key] = entity
		var entity: Node3D = replicas[key]
		entity.position = entry.at
		if entry.kind != "drop": entity.rotation.y = entry.yaw; entity.health = entry.health
		elif game.playing() and game.player.position.distance_to(entry.at) < 2.0 and game.inventory.capacity(entry.stack.id,entry.stack.wear,entry.stack.data) >= entry.stack.count:
			pickup.rpc_id(1,key)
	for key in replicas.keys():
		if not seen.has(key):
			if is_instance_valid(replicas[key]): replicas[key].queue_free()
			replicas.erase(key)

	applying = false

@rpc("any_peer","call_remote","reliable")
func pickup(key: int) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not is_instance_id_valid(key): return
	var drop: Object = instance_from_id(key)
	if not drop is ItemDrop or drop.is_queued_for_deletion() or drop.pickup_delay > 0 or not reachable(sender,Vector3i(drop.position.floor()),3): return
	give_item.rpc_id(sender,{"id":drop.item_id,"count":drop.amount,"wear":drop.wear,"data":drop.data})
	drop.queue_free()

@rpc("authority","call_remote","reliable")
func give_item(stack: Dictionary) -> void:
	if client(): game.inventory.add_item(stack.id,stack.count,stack.wear,stack.get("data",{})); game.sound("pickup")

func hit_mob(mob: Node3D, damage: float, reason: String) -> void:
	if mob.has_meta("network_id"): attack.rpc_id(1,int(mob.get_meta("network_id")),damage,reason)

@rpc("any_peer","call_remote","reliable")
func attack(key: int, damage: float, reason: String) -> void:
	if not multiplayer.is_server() or not is_instance_id_valid(key) or not is_finite(damage): return
	var mob: Object = instance_from_id(key)
	var sender: int = multiplayer.get_remote_sender_id()
	if not mob is Creature or mob.is_queued_for_deletion() or not reachable(sender,Vector3i(mob.position.floor()),100): return
	mob.hit(clampf(damage,0,20),players[sender].position,reason)

func station_click(index: int, is_station: bool, right: bool, shift: bool) -> bool:
	if not client() or not station_open or game.hud.station not in ["chest","furnace","steam","brewing"]: return false
	if station_busy: return true
	if not is_station and not shift: return false
	station_busy = true
	station_action.rpc_id(1,station_pos,game.hud.station,index,is_station,right,shift,game.inventory.slots,game.hud.cursor)
	return true

static func accepts_slot(s: Dictionary, kind: String, index: int, id: int) -> bool:
	if kind == "steam": return SteamMachines.accepts(s,index,id)
	if kind == "furnace": return FurnaceRules.accepts(s.slots,index,id)
	if kind == "brewing": return Brewing.accepts(index,id)
	return id == 0 or Nodes.exists(id)

@rpc("any_peer","call_remote","reliable")
func station_action(p: Vector3i, kind: String, index: int, is_station: bool, right: bool, shift: bool, carried: Array, cursor: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not reachable(sender,p) or kind not in ["chest","furnace","steam","brewing"] or game.world.node_at(p) not in RedstoneCircuit.CONTAINERS:
		station_denied.rpc_id(sender); return
	var s: Dictionary = game.world.get_station(p,kind)
	var inv := Inventory.new(); inv.restore(carried)
	cursor = Inventory.clean_slot(cursor)
	var source: Array = s.slots if is_station else inv.slots
	if index < 0 or index >= source.size(): station_denied.rpc_id(sender); return
	var slot: Dictionary = source[index]
	if shift and cursor.id == 0:
		if is_station:
			slot.count = inv.add_item(slot.id,slot.count,slot.wear,slot.get("data",{}))
			if slot.count == 0: source[index] = {"id":0,"count":0,"wear":0}
		else:
			for n in s.slots.size():
				if not accepts_slot(s,kind,n,slot.id): continue
				while slot.id != 0 and slot.count > 0 and RedstoneCircuit.insert_one([s.slots[n]],slot):
					RedstoneCircuit.consume_one(slot)
	elif cursor.id == 0:
		var count: int = ceili(slot.count/2.0) if right else slot.count
		cursor = slot.duplicate(true); cursor.count = count
		slot.count -= count
		if slot.count == 0: source[index] = {"id":0,"count":0,"wear":0}
	elif not is_station or accepts_slot(s,kind,index,cursor.id):
		if slot.id == 0 or (slot.id == cursor.id and slot.get("data",{}) == cursor.get("data",{})):
			var count: int = mini(1 if right else cursor.count,Nodes.max_stack(cursor.id)-int(slot.count))
			if count > 0:
				if slot.id == 0: source[index] = cursor.duplicate(true); source[index].count = 0
				source[index].count += count; cursor.count -= count
				if cursor.count == 0: cursor = {"id":0,"count":0,"wear":0}
		elif not right:
			var swap: Dictionary = source[index]; source[index] = cursor; cursor = swap
	station_result.rpc_id(multiplayer.get_remote_sender_id(),p,inv.slots,cursor,s)

@rpc("authority","call_remote","reliable")
func station_result(p: Vector3i, inventory: Array, cursor: Dictionary, s: Dictionary) -> void:
	if not client(): return
	station_busy = false
	game.inventory.restore(inventory); game.hud.cursor = Inventory.clean_slot(cursor)
	if station_open and station_pos == p:
		game.hud.station_data.clear(); game.hud.station_data.merge(s.duplicate(true))
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

@rpc("authority","call_remote","reliable")
func station_denied() -> void:
	station_busy = false
	if client(): game.resume(); game.toast("That storage is no longer in reach. Open it again.")

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
	if not RedstoneCircuit.circuit_node(game.world.node_at(p)): return
	game.world.circuits.configure(p,direction,support)

@rpc("any_peer","call_remote","reliable")
func use_node(p: Vector3i) -> void:
	if not multiplayer.is_server() or not reachable(multiplayer.get_remote_sender_id(),p): return
	if RedstoneInputs.is_button(game.world.node_at(p)): RedstoneInputs.press(game.world,p)
	else: game.world.circuits.interact(p)

@rpc("any_peer","call_remote","reliable")
func drop_item(stack: Dictionary, origin: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server() or not origin.is_finite() or not direction.is_finite(): return
	if not reachable(multiplayer.get_remote_sender_id(),Vector3i(origin.floor()),3): return
	var cleaned: Dictionary = Inventory.clean_slot(stack)
	if cleaned.id == 0: return
	var drop: ItemDrop = game.spawn_drop(origin,cleaned.id,cleaned.count,cleaned.wear,cleaned.get("data",{}))
	if drop != null: drop.velocity = direction.normalized()*5+Vector3.UP*1.5; drop.pickup_delay = 1.5

func carry_player(id: int, at: Vector3) -> void:
	if not active() or not multiplayer.is_server() or not players.has(id): return
	players[id].position = at
	move_player.rpc_id(id,at)

@rpc("authority","call_remote","reliable")
func move_player(at: Vector3) -> void:
	if client(): game.player.position = at

class_name DeathRecovery
extends RefCounted

const NO_POSITION = Vector3i(999999,999999,999999)

static func leave(game: Node3D) -> void:
	# Extra pages already belong to pouch contents, never loose chest entries.
	for slot in game.inventory.slots:
		if Inventory.enchantment(slot,"Curse of Vanishing") > 0: slot.clear(); slot.merge({"id":0,"count":0,"wear":0})
	game.inventory.sync_pouches()
	var storage: Dictionary = VoxelWorld._new_station("chest",54)
	var sources: Array = game.inventory.slots.slice(0,Inventory.BASE_SLOTS)+game.inventory.pouch_slots+game.player.armor_slots+game.inventory.grid+[game.hud.cursor]
	for i in sources.size():
		if Inventory.enchantment(sources[i],"Curse of Vanishing") == 0: storage.slots[i] = sources[i].duplicate(true)
	storage["label"] = "Recovery chest · "+game.player_id
	storage["owner"] = game.player_id
	storage["origin"] = [game.player.position.x,game.player.position.y,game.player.position.z]
	game.world.adventure_state.erase("last_recovery")
	var pending: Array = game.world.adventure_state.get("pending_recovery",[])
	pending.append(storage)
	game.world.adventure_state["pending_recovery"] = pending
	# Even the exceptional unloaded/solid case retains all cargo in the save.
	retry(game)
	for slot in game.player.armor_slots+game.inventory.grid: slot.clear(); slot.merge({"id":0,"count":0,"wear":0})
	game.hud.cursor = {"id":0,"count":0,"wear":0}
	game.survival.open_pouch_index = -1; game.survival.open_equipped_pouch = -1
	game.inventory.restore([])
	game.spawn_drop(game.player.position+Vector3.UP,Nodes.BONE,2)

static func retry(game: Node3D) -> void:
	var pending: Array = game.world.adventure_state.get("pending_recovery",[])
	for i in range(pending.size()-1,-1,-1):
		var entry: Dictionary = pending[i]
		var origin := Vector3(entry.origin[0],entry.origin[1],entry.origin[2])
		if not game.world.loaded_at(origin): continue
		var p: Vector3i = find_position(game.world,origin)
		if p == NO_POSITION or not game.world.set_node(p,VillageContent.RECOVERY_CHEST): continue
		game.world.stations[VoxelWorld.station_key(p)] = entry
		game.world.adventure_state["last_recovery"] = {"position":[p.x,p.y,p.z],"owner":entry.owner}
		pending.remove_at(i)

static func find_position(world: VoxelWorld, origin: Vector3) -> Vector3i:
	var center := Vector3i(origin.floor())
	center.y = clampi(center.y,world.generator.min_y()+1,world.generator.max_y()-1)
	# Prefer nearby air. Repeated deaths cannot overwrite earlier chests.
	for radius in range(5):
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				for z in range(-radius,radius+1):
					if maxi(absi(x),maxi(absi(y),absi(z))) != radius: continue
					var p: Vector3i = center+Vector3i(x,y,z)
					if usable(world,p): return p
	# A drowned/burning player can leave a chest in the fluid they occupied.
	if Fluids.liquid(world.node_at(center)): return center
	for height in range(world.generator.min_y()+1,world.generator.max_y()):
		var p := Vector3i(center.x,height,center.z)
		if usable(world,p): return p
	return NO_POSITION

static func usable(world: VoxelWorld, p: Vector3i) -> bool:
	return p.y > world.generator.min_y() and p.y < world.generator.max_y() and world.loaded_at(Vector3(p)) and world.node_at(p) == Nodes.AIR

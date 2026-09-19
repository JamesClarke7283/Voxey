class_name Boats
extends RefCounted

const CHEST_FIRST = 1250
const JUNGLE = 1260
const JUNGLE_CHEST = 1261
const ORDINARY = [837,839,841,1260,838,840]
const CHESTS = [1250,1252,1254,1261,1251,1253]
const DATA = {
	1260:{"name":"Jungle boat","color":"b88661","stack":1,"family":"boat"},
	1261:{"name":"Jungle chest boat","color":"b88661","stack":1,"family":"chest_boat"},
	1250:{"name":"Oak chest boat","color":"b7955e","stack":1,"family":"chest_boat"},
	1251:{"name":"Acacia chest boat","color":"ba6f4c","stack":1,"family":"chest_boat"},
	1252:{"name":"Spruce chest boat","color":"896744","stack":1,"family":"chest_boat"},
	1253:{"name":"Dark oak chest boat","color":"594336","stack":1,"family":"chest_boat"},
	1254:{"name":"Birch chest boat","color":"dbcf9c","stack":1,"family":"chest_boat"},
}

var game: Node3D
var active: Dictionary = {}
var riding: BoatEntity
var previous_flying: bool = false
var stream_timer: float = 0

func _init(owner_game: Node3D) -> void: game = owner_game

static func is_chest(id: int) -> bool: return id in CHESTS
static func is_boat(id: int) -> bool: return is_chest(id) or id in ORDINARY
static func is_passenger(mob: Creature) -> bool: return mob.has_meta("boat_key")

static func recipes(inv: Inventory) -> void:
	for i in ORDINARY.size():
		var p: int = WoodTypes.PLANKS[i]
		inv._recipe(Nodes.title(ORDINARY[i]),ORDINARY[i],1,[p,0,p,p,p,p],3,"table")
		inv._recipe(Nodes.title(CHESTS[i]),CHESTS[i],1,[Nodes.CHEST,ORDINARY[i]],1,"hand")

static func can_ride(mob: Creature) -> bool:
	if mob == null or mob.is_queued_for_deletion() or mob.health <= 0 or is_passenger(mob): return false
	# These local counterparts explicitly disable can_ride_boat in mobs_mc.
	if mob.kind in ["end_crystal","ender_dragon","ghast","spider","iron_golem","horse","magma_cube"]: return false
	if mob.kind == "slime" and mob is ExpeditionCreature and mob.slime_size != 1: return false
	return not mob.game.leads.attached(mob) and mob != mob.game.survival.mount

func records() -> Dictionary:
	if not game.world.adventure_state.get("boats") is Dictionary: game.world.adventure_state["boats"] = {}
	return game.world.adventure_state.boats

func ridden() -> bool:
	return is_instance_valid(riding) and not riding.is_queued_for_deletion() and not riding.removed

static func finite_vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	for part in value:
		if not (part is float or part is int) or not is_finite(float(part)): return false
	return true

static func clean_record(value: Variant) -> Dictionary:
	if not value is Dictionary or not is_boat(int(value.get("id",0))) or not finite_vector(value.get("position")): return {}
	var item: Dictionary = Inventory.clean_slot({"id":int(value.id),"count":1,"wear":0,"data":value.get("item_data",{})})
	var result: Dictionary = {"id":int(value.id),"position":value.position.duplicate(),"yaw":0.0,"speed":0.0,"vertical":0.0,"health":4.0,"item_data":item.get("data",{}),"rider":bool(value.get("rider",false))}
	for key in ["yaw","speed","vertical","health"]:
		var number: Variant = value.get(key,result[key])
		if (number is float or number is int) and is_finite(float(number)): result[key] = float(number)
	result.health = clampf(result.health,0.01,4); result.speed = clampf(result.speed,-81,81); result.vertical = clampf(result.vertical,-8,8)
	if is_chest(result.id):
		result["slots"] = []
		var slots: Variant = value.get("slots",[])
		for i in 27: result.slots.append(Inventory.clean_slot(slots[i] if slots is Array and i < slots.size() else {}))
	var passenger: Variant = value.get("passenger",{})
	if passenger is Dictionary and Creature.KINDS.has(passenger.get("kind","")) and finite_vector(passenger.get("position")):
		result["passenger"] = passenger.duplicate(true)
	return result

func spawn(id: int, pos: Vector3, yaw: float = 0, metadata: Dictionary = {}) -> BoatEntity:
	if not is_boat(id) or not pos.is_finite() or not game.world.loaded_at(pos) or game.world.intersects(pos,0.5,0.55): return null
	for boat in active.values():
		if is_instance_valid(boat) and not boat.removed and boat.position.distance_to(pos) < 1.05: return null
	var serial: int = int(Farming.number(game.world.adventure_state.get("boat_serial",0),0,2147483646))
	while true:
		serial += 1
		if not records().has("boat_%d"%serial): break
	game.world.adventure_state["boat_serial"] = serial
	var key: String = "boat_%d"%serial
	var entry: Dictionary = clean_record({"id":id,"position":[pos.x,pos.y,pos.z],"yaw":yaw,"item_data":metadata})
	records()[key] = entry
	return _wake(key,entry)

func _wake(key: String, entry: Dictionary) -> BoatEntity:
	var saved_rider: bool = entry.get("rider",false)
	var boat := BoatEntity.new(); boat.service = self; boat.game = game; boat.key = key; boat.saved = entry
	boat.item_id = int(entry.id); boat.position = VillageLife.vec(entry.position); boat.rotation.y = float(entry.yaw)
	boat.speed = float(entry.speed); boat.vertical = float(entry.vertical); boat.health = float(entry.health)
	active[key] = boat; game.entities.add_child(boat)
	if entry.has("passenger"):
		var mob: Creature = game.leads._restore_mob(entry.passenger)
		if mob != null and not is_passenger(mob):
			if entry.passenger.get("farm_state") is Dictionary and Farming.managed(mob): Farming.restore_state(mob,entry.passenger.farm_state)
			boat.attach_mob(mob)
	entry["rider"] = saved_rider
	return boat

func restore() -> void:
	for key in records().keys():
		if active.has(key): continue
		var clean: Dictionary = clean_record(records()[key])
		if clean.is_empty(): records().erase(key)
		else: records()[key] = clean
	stream_timer = 1
	update(0)
	for boat in active.values():
		if boat.saved.get("rider",false) and not ridden() and game.player.health > 0 and game.player.position.distance_to(boat.position) < 4: board(boat)
		boat.saved["rider"] = false

func update(delta: float) -> void:
	stream_timer += delta
	if stream_timer < 0.5: return
	stream_timer = 0
	for key in active.keys():
		var boat: BoatEntity = active[key]
		if not is_instance_valid(boat) or boat.is_queued_for_deletion(): active.erase(key); continue
		if boat != riding and (not game.world.loaded_at(boat.position) or boat.position.distance_to(game.player.position) > 90): hibernate(boat)
	for key in records():
		if active.has(key): continue
		var entry: Dictionary = records()[key]
		if not finite_vector(entry.get("position")): continue
		var pos: Vector3 = VillageLife.vec(entry.position)
		if game.world.loaded_at(pos) and game.player.position.distance_to(pos) <= 80: _wake(str(key),entry)

func snapshot() -> void:
	for boat in active.values():
		if is_instance_valid(boat) and not boat.removed and not boat.is_queued_for_deletion(): boat.store_record()

func hibernate(boat: BoatEntity) -> void:
	if boat == riding: return
	boat.store_record()
	if is_instance_valid(boat.passenger):
		var mob: Creature = boat.passenger
		Farming.remember(mob)
		if mob is VillageMob or mob is SnowGolem: mob.store_record()
		if mob is NetherResident: mob.ensure_record(); mob.store_record()
		mob.queue_free(); boat.passenger = null
	active.erase(boat.key); boat.queue_free()

func reset() -> void:
	dismount(false)
	for boat in active.values():
		if not is_instance_valid(boat): continue
		boat.release_mob(false); boat.queue_free()
	active.clear(); stream_timer = 0

func passenger_keys() -> Dictionary:
	var keys: Dictionary = {}
	for entry in records().values():
		var key: String = str(entry.get("passenger",{}).get("crystal_key",""))
		if not key.is_empty(): keys[key] = true
	return keys

func board(boat: BoatEntity) -> bool:
	if boat == null or boat.removed or ridden() or is_instance_valid(game.survival.mount): return false
	if is_chest(boat.item_id) and is_instance_valid(boat.passenger): game.toast("This chest boat's seat is occupied."); return false
	riding = boat; previous_flying = game.player.flying; game.player.flying = false; game.player.gliding = false
	game.player.velocity = Vector3.ZERO; game.player.rotation.y = boat.rotation.y; boat.seat_occupants()
	game.toast("A/D steer; W/S row. Ctrl leaves the boat in the world.")
	return true

func dismount(move_player: bool = true) -> void:
	if not ridden(): riding = null; return
	var boat: BoatEntity = riding
	riding = null; boat.control = Vector3.ZERO; boat.saved["rider"] = false
	game.player.flying = previous_flying; game.player.velocity = Vector3.ZERO
	if move_player: game.player.position = exit_position(boat,0.3,1.8)
	boat.seat_occupants()

func exit_position(boat: BoatEntity, width: float, height: float) -> Vector3:
	for offset in [Vector3(1.15,0.25,0),Vector3(-1.15,0.25,0),Vector3(0,0.25,1.3),Vector3(0,0.25,-1.3),Vector3(0,0.6,0)]:
		var pos: Vector3 = boat.position+boat.basis*offset
		if game.world.loaded_at(pos) and not game.world.intersects(pos,width,height): return pos
	return boat.position+Vector3.UP*0.2

func drive(delta: float, direction: Vector3) -> void:
	if not ridden(): return
	var pad: TouchControls = game.controls if game.touch else null
	if Input.is_physical_key_pressed(KEY_CTRL) or pad != null and pad.sneak_held: dismount(); return
	riding.control = direction; riding.seat_occupants()
	var player: VoxeyPlayer = game.player
	player.camera.position.y = 1.62; player.camera.fov = lerpf(player.camera.fov,78,delta*7)
	player.underwater = Fluids.contains(game.world,player.camera.global_position,Nodes.WATER)
	player.survival_timer += delta
	if game.gamemode == "creative": player.health = 20; player.hunger = 20; player.breath = 10; return
	if player.survival_timer >= 1:
		player.survival_timer = 0
		if player.underwater and not game.survival.effects.has("water_breathing"):
			player.breath = maxf(0,player.breath-1.0/(1+Enchantments.worn(player,"Respiration")))
			if player.breath <= 0: player.hurt(2,true)
		else: player.breath = minf(10,player.breath+3)

func target() -> BoatEntity:
	var origin: Vector3 = game.player.camera.global_position
	var direction: Vector3 = -game.player.camera.global_basis.z
	var distance: float = minf(4,float(game.player.target.get("distance",4)))
	for mob in game.creatures.get_children():
		if mob.is_queued_for_deletion() or mob.health <= 0: continue
		var box := AABB(mob.position+Vector3(-mob.width,0,-mob.width),Vector3(mob.width*2,mob.height,mob.width*2))
		var point: Variant = box.intersects_ray(origin,direction)
		if point is Vector3: distance = minf(distance,origin.distance_to(point))
	var nearest: BoatEntity
	for boat in active.values():
		if not is_instance_valid(boat) or boat.removed or boat.is_queued_for_deletion(): continue
		var box := AABB(boat.position+Vector3(-0.7,-0.15,-0.7),Vector3(1.4,0.9 if is_chest(boat.item_id) else 0.7,1.4))
		var point: Variant = box.intersects_ray(origin,direction)
		if point is Vector3 and origin.distance_to(point) < distance:
			distance = origin.distance_to(point); nearest = boat
	return nearest

func use() -> bool:
	var boat: BoatEntity = target()
	var sneak: bool = Input.is_physical_key_pressed(KEY_CTRL) or game.touch and is_instance_valid(game.controls) and game.controls.sneak_held
	if boat != null:
		if is_chest(boat.item_id) and sneak: open_chest(boat)
		else: board(boat)
		return true
	var held: Dictionary = game.inventory.held()
	if not is_boat(int(held.id)): return false
	place(held,game.player.target)
	return true

func place(slot: Dictionary, pointed: Dictionary) -> BoatEntity:
	if pointed.is_empty(): game.toast("Use a block or the water surface to place the boat."); return null
	var p: Vector3i = pointed.pos
	var normal: Vector3i = pointed.get("normal",Vector3i.UP)
	var pos: Vector3 = Vector3(p)+Vector3.ONE*0.5
	if normal.y == 0: pos += Vector3(normal)*1.001
	elif Fluids.water(int(pointed.id)): pos.y = p.y+Fluids.height(int(pointed.id))-0.15
	elif normal.y > 0: pos.y = p.y+1.01
	else: pos.y = p.y-0.56
	var boat: BoatEntity = spawn(int(slot.id),pos,game.player.rotation.y,slot.get("data",{}))
	if boat == null: game.toast("The boat needs clear space."); return null
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.toast("Boat placed. Right click it to board." if not is_chest(boat.item_id) else "Chest boat placed. Right click to board; Ctrl + right click opens cargo.")
	return boat

func open_chest(boat: BoatEntity) -> void:
	if not is_chest(boat.item_id) or boat.removed: return
	game.hud.return_cursor(); game.inventory.sync_pouches()
	game.state = "inventory"; game.world.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(game.controls): game.controls.hide_all()
	game.hud.container_page = 0
	game.hud.show_inventory("chest",{"kind":"boat","label":boat.saved.get("item_data",{}).get("custom_name",Nodes.title(boat.item_id)),"slots":boat.saved.slots,"boat_key":boat.key})

# RedstoneCircuit owns consuming the source slot, exactly as for arrows/items.
func dispense(slot: Dictionary, p: Vector3i, facing: Vector3i) -> void:
	var destination: Vector3i = p+facing
	var id: int = game.world.node_at(destination)
	var water_cell: Vector3i = destination
	if id == Nodes.AIR and Fluids.water(game.world.node_at(destination+Vector3i.DOWN)): water_cell += Vector3i.DOWN
	var water_id: int = game.world.node_at(water_cell)
	if Fluids.water(water_id):
		var pos: Vector3 = Vector3(destination)+Vector3(0.5,0,0.5)
		pos.y = water_cell.y+Fluids.height(water_id)-0.15
		if spawn(int(slot.id),pos,atan2(-float(facing.x),-float(facing.z)),slot.get("data",{})) != null: return
	var origin: Vector3 = Vector3(p)+Vector3.ONE*0.5+Vector3(facing)*0.75
	var drop: ItemDrop = game.spawn_drop(origin,int(slot.id),1,int(slot.get("wear",0)),slot.get("data",{}))
	if drop != null: drop.velocity = Vector3(facing)*4+Vector3.UP*1.5

func explode(center: Vector3, radius: float) -> void:
	var reach: float = radius*2.0
	if reach <= 0: return
	for boat in active.values().duplicate():
		if not is_instance_valid(boat) or boat.removed or boat.is_queued_for_deletion(): continue
		var distance: float = center.distance_to(boat.position+Vector3.UP*0.275)
		if distance < reach: boat.hit(lerpf(20.0,1.0,distance/reach)*1.25)

func punch_target() -> bool:
	var boat: BoatEntity = target()
	if boat == null: return false
	var held: int = game.inventory.held().id
	var damage: float = float(VillageContent.DATA.get(held,{}).get("attack_damage",2+(Nodes.tool_tier(held)+1)*(2 if Nodes.tool_kind(held) == 3 else 1)))
	damage = (damage+Inventory.enchantment(game.inventory.held(),"Sharpness")*1.5)*PotionEffects.melee(game.player)
	boat.hit(100 if game.gamemode == "creative" else damage*1.25,true)
	Hunger.exhaust(game.player,Hunger.ATTACK)
	if game.gamemode != "creative": game.inventory.damage_tool()
	return true

func destroy(boat: BoatEntity, player_broke: bool = false) -> void:
	if boat.removed: return
	boat.removed = true
	if boat == riding: boat.removed = false; dismount(); boat.removed = true
	boat.release_mob()
	records().erase(boat.key); active.erase(boat.key)
	if is_chest(boat.item_id):
		for slot in boat.saved.slots:
			if slot.id != 0: game.spawn_drop(boat.position+Vector3.UP*0.4,int(slot.id),int(slot.count),int(slot.wear),slot.get("data",{}))
		boat.saved.slots.clear()
	var metadata: Dictionary = boat.saved.get("item_data",{})
	if player_broke and game.gamemode == "creative":
		if game.inventory.count_item(boat.item_id) == 0:
			if game.inventory.add_item(boat.item_id,1,0,metadata) > 0: game.spawn_drop(boat.position,boat.item_id,1,0,metadata)
	else: game.spawn_drop(boat.position,boat.item_id,1,0,metadata)
	boat.queue_free()

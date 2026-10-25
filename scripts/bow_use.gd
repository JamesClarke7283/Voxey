class_name BowUse
extends RefCounted

# mcl_bows/bow.lua and arrow.lua. Pull state belongs to the player, never the
# saved item: switching, dropping, menus and loading cannot preserve a charge.
const HALF_US = 200000
const FULL_US = 500000
const MAX_SPEED = 60.0
const SPEED_FACTOR = 1.295/4.317
const FOV_FACTOR = 0.8
const DURABILITY = 385
const SPREAD = 0.0172275

static func stage(elapsed_us: int) -> int:
	return 2 if elapsed_us >= FULL_US else 1 if elapsed_us >= HALF_US else 0

static func current_stage(player: VoxeyPlayer) -> int:
	return int(player.bow_draw.get("stage",-1))

static func ammunition(slots: Array) -> int:
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if int(slot.get("count",0)) > 0 and (slot.id == Nodes.ARROW_ITEM or VillageContent.DATA.get(slot.id,{}).get("family","") == "arrow"): return i
	return -1

static func shot_plan(bow: Dictionary, ammo_id: int, creative: bool, elapsed_us: int) -> Dictionary:
	var infinity: bool = Inventory.enchantment(bow,"Infinity") > 0
	var power: int = Inventory.enchantment(bow,"Power")
	return {"fires":creative or ammo_id != 0,"ammo":ammo_id if ammo_id else Nodes.ARROW_ITEM,
		"speed":MAX_SPEED*clampf(float(elapsed_us)/FULL_US,0,1),"critical":elapsed_us >= FULL_US,
		"consume":not creative and not (infinity and ammo_id == Nodes.ARROW_ITEM),
		"collectable":not infinity,"damage":2.0+(power/2.0+0.5 if power > 0 else 0.0),
		"punch":Inventory.enchantment(bow,"Punch"),"flame":Inventory.enchantment(bow,"Flame") > 0,
		"wear":0 if creative else floori(65535.0/(DURABILITY*(Inventory.enchantment(bow,"Unbreaking")+1)))}

static func inaccuracy(direction: Vector3, samples: Array = []) -> Vector3:
	# The source adds independent triangular noise; it does not renormalize.
	var result: Vector3 = direction
	for axis in 3:
		result[axis] += SPREAD*(float(samples[axis*2])-float(samples[axis*2+1]) if samples.size() == 6 else randf()-randf())
	return result

static func valid(player: VoxeyPlayer) -> bool:
	return not player.bow_draw.is_empty() and player.game.playing() and player.health > 0 and player.game.inventory.selected == player.bow_draw.slot and is_same(player.game.inventory.held(),player.bow_draw.item) and player.game.inventory.held().id == Nodes.BOW and player.game.inventory.held().count > 0

static func refresh(player: VoxeyPlayer) -> void:
	if is_instance_valid(player.hand): player._make_hand(player.game.inventory.held().id)
	if is_instance_valid(player.game.hud): player.game.hud.refresh_slots()

static func begin(player: VoxeyPlayer, now_us: int = -1, zoom: bool = false) -> bool:
	var game: Node3D = player.game
	if not player.bow_draw.is_empty(): return true
	if not game.playing() or player.health <= 0 or game.inventory.held().id != Nodes.BOW or game.inventory.held().count <= 0: return false
	if game.gamemode != "creative" and ammunition(game.inventory.slots) < 0: return false
	player.bow_draw = {"slot":game.inventory.selected,"item":game.inventory.held(),"start":Time.get_ticks_usec() if now_us < 0 else now_us,"stage":0,"rmb":not zoom,"zoom":zoom}
	# The bow has no repeat-use timer; another pull can start on the next click.
	player.use_cooldown = 0
	refresh(player)
	return true

static func cancel(player: VoxeyPlayer) -> void:
	if player.bow_draw.is_empty(): return
	player.bow_draw.clear()
	refresh(player)

static func update(player: VoxeyPlayer, use_held: bool, zoom_held: bool, now_us: int = -1) -> bool:
	var now: int = Time.get_ticks_usec() if now_us < 0 else now_us
	if player.bow_draw.is_empty():
		return begin(player,now,true) if zoom_held else false
	if not valid(player): cancel(player); return false
	# Either source control's release shoots, even if the other remains held.
	if player.bow_draw.rmb and not use_held or player.bow_draw.zoom and not zoom_held:
		release(player,now)
		return true
	player.bow_draw.rmb = use_held; player.bow_draw.zoom = zoom_held
	var next: int = stage(now-int(player.bow_draw.start))
	if next != current_stage(player): player.bow_draw.stage = next; refresh(player)
	player.hand.position = Vector3(0.28,-0.24,-0.6)
	player.hand.rotation = Vector3(-0.1,0.1,-0.14)
	return true

static func release(player: VoxeyPlayer, now_us: int = -1, samples: Array = []) -> Arrow:
	if not valid(player): cancel(player); return null
	var game: Node3D = player.game
	var bow: Dictionary = game.inventory.held()
	var index: int = ammunition(game.inventory.slots)
	var plan: Dictionary = shot_plan(bow,int(game.inventory.slots[index].id) if index >= 0 else 0,game.gamemode == "creative",(Time.get_ticks_usec() if now_us < 0 else now_us)-int(player.bow_draw.start))
	cancel(player)
	if not plan.fires: return null
	var origin: Vector3 = player.camera.global_position-Vector3.UP*0.1
	var shot: Arrow = game.spawn_arrow(origin,inaccuracy(-player.camera.global_basis.z,samples)*float(plan.speed),int(plan.ammo))
	shot.from_player = true; shot.shooter_id = player.get_instance_id(); shot.shooter_kind = "player"
	shot.damage = plan.damage; shot.critical = plan.critical; shot.recoverable = plan.collectable
	shot.flame = plan.flame; shot.punch = plan.punch
	if index >= 0: shot.potion_data = game.inventory.slots[index].get("data",{}).duplicate(true)
	if plan.consume:
		var ammo: Dictionary = game.inventory.slots[index]
		ammo.count -= 1
		if ammo.count == 0: ammo.clear(); ammo.merge({"id":0,"count":0,"wear":0})
	if plan.wear > 0: Durability.set_normalized(bow,Durability.normalized(bow)+int(plan.wear))
	game.inventory.changed.emit()
	game.sound("arrow"); player.swing = 1
	return shot

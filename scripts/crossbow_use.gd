class_name CrossbowUse
extends RefCounted

# Installed mcl_bows/crossbow.lua: release a full draw to load, press Attack
# to fire. A loaded projectile belongs to the item; an unfinished draw does not.
const HALF_US = 350000
const FULL_US = 900000
const QUICK_US = 130000
const SPEED = 63.0
const SPEED_FACTOR = 1.295/4.317

static func ammunition_id(id: int) -> bool:
	return id == Nodes.ARROW_ITEM or VillageContent.DATA.get(id,{}).get("family","") == "arrow"

static func loaded(item: Dictionary) -> bool:
	return item.get("id",0) == VillageContent.CROSSBOW and ammunition_id(int(item.get("data",{}).get("loaded_arrow",0))) and bool(item.get("data",{}).get("crossbow_loaded",true))

static func loaded_form(item: Dictionary) -> bool:
	# NPC crossbows change their item form without consuming/storing an arrow.
	# Such a dropped weapon dry-fires once, as the source's empty loaded form does.
	if item.get("id",0) != VillageContent.CROSSBOW: return false
	var data: Dictionary = item.get("data",{})
	return bool(data.get("crossbow_loaded",false)) if data.get("mob_crossbow",false) else loaded(item)

static func current_stage(player: VoxeyPlayer) -> int:
	if loaded_form(player.game.inventory.held()): return 3
	return int(player.crossbow_draw.get("stage",-1))

static func half_time(item: Dictionary) -> int:
	return HALF_US-Inventory.enchantment(item,"Quick Charge")*QUICK_US/2

static func full_time(item: Dictionary) -> int:
	return FULL_US-Inventory.enchantment(item,"Quick Charge")*QUICK_US

static func valid(player: VoxeyPlayer) -> bool:
	return not player.crossbow_draw.is_empty() and player.game.playing() and player.health > 0 and player.game.inventory.selected == player.crossbow_draw.slot and is_same(player.game.inventory.held(),player.crossbow_draw.item) and player.game.inventory.held().id == VillageContent.CROSSBOW and player.game.inventory.held().count > 0

static func cancel(player: VoxeyPlayer) -> void:
	if player.crossbow_draw.is_empty(): return
	player.crossbow_draw.clear(); BowUse.refresh(player)

static func begin(player: VoxeyPlayer, now_us: int = -1, zoom: bool = false) -> bool:
	if loaded_form(player.game.inventory.held()) or not player.crossbow_draw.is_empty(): return true
	if not player.game.playing() or player.health <= 0 or player.game.inventory.held().id != VillageContent.CROSSBOW: return false
	if player.game.gamemode != "creative" and BowUse.ammunition(player.game.inventory.slots) < 0: return false
	player.crossbow_draw = {"slot":player.game.inventory.selected,"item":player.game.inventory.held(),"start":Time.get_ticks_usec() if now_us < 0 else now_us,"stage":0,"rmb":not zoom,"zoom":zoom}
	player.use_cooldown = 0; player.game.sound("equip"); BowUse.refresh(player)
	return true

static func update(player: VoxeyPlayer, use_held: bool, zoom_held: bool, attack_held: bool, now_us: int = -1) -> bool:
	var press: bool = attack_held and not player.crossbow_attack_held
	player.crossbow_attack_held = attack_held
	if press and loaded_form(player.game.inventory.held()): fire(player); return true
	var now: int = Time.get_ticks_usec() if now_us < 0 else now_us
	if player.crossbow_draw.is_empty():
		return begin(player,now,true) if zoom_held and player.game.inventory.held().id == VillageContent.CROSSBOW and not loaded_form(player.game.inventory.held()) else false
	if not valid(player): cancel(player); return false
	if player.crossbow_draw.rmb and not use_held or player.crossbow_draw.zoom and not zoom_held:
		release(player); return true
	player.crossbow_draw.rmb = use_held; player.crossbow_draw.zoom = zoom_held
	var elapsed: int = now-int(player.crossbow_draw.start)
	var item: Dictionary = player.game.inventory.held()
	# Source advances one stage per hold callback, even after a long frame.
	var next: int = current_stage(player)
	if next == 0 and elapsed >= half_time(item): next = 1
	elif next == 1 and elapsed >= full_time(item): next = 2
	if next != current_stage(player):
		player.crossbow_draw.stage = next; player.game.sound("equip"); BowUse.refresh(player)
	player.hand.position = Vector3(0.25,-0.25,-0.6)
	player.hand.rotation = Vector3(-0.1,0.12,-0.08)
	return true

static func release(player: VoxeyPlayer) -> bool:
	if not valid(player) or current_stage(player) != 2: cancel(player); return false
	var game: Node3D = player.game
	var index: int = BowUse.ammunition(game.inventory.slots)
	if index < 0 and game.gamemode != "creative": cancel(player); return false
	var ammo: Dictionary = game.inventory.slots[index] if index >= 0 else {"id":Nodes.ARROW_ITEM,"count":1,"wear":0}
	var item: Dictionary = game.inventory.held()
	if not item.has("data"): item.data = {}
	item.data.loaded_arrow = ammo.id; item.data.crossbow_loaded = true
	if ammo.has("data"): item.data.loaded_arrow_data = ammo.data.duplicate(true)
	else: item.data.erase("loaded_arrow_data")
	item.data.erase("charge")
	if game.gamemode != "creative":
		ammo.count -= 1
		if ammo.count == 0: ammo.clear(); ammo.merge({"id":0,"count":0,"wear":0})
	cancel(player); game.inventory.changed.emit(); game.sound("equip")
	return true

static func rotate_source(v: Vector3, rot: Vector3) -> Vector3:
	# Luanti builtin vector.rotate uses negative angles and yaw/pitch/roll order.
	var sx: float = sin(-rot.x); var sy: float = sin(-rot.y); var sz: float = sin(-rot.z)
	var cx: float = cos(rot.x); var cy: float = cos(rot.y); var cz: float = cos(rot.z)
	return Vector3((sy*sx*sz+cy*cz)*v.x+(sy*sx*cz-cy*sz)*v.y+sy*cx*v.z,cx*sz*v.x+cx*cz*v.y-sx*v.z,(cy*sx*sz-sy*cz)*v.x+(cy*sx*cz+sy*sz)*v.y+cy*cx*v.z)

static func directions(item: Dictionary, direction: Vector3, yaw: float, samples: Array = [], inaccuracy: float = 1.0) -> Array:
	var dir: Vector3 = direction+BowUse.inaccuracy(Vector3.ZERO,samples)*inaccuracy
	if Inventory.enchantment(item,"Multishot") <= 0: return [dir]
	var pitch: float = atan2(-dir.y,sqrt(dir.x*dir.x+dir.z*dir.z))
	var rot := Vector3(cos(yaw+PI/2)*sin(pitch),cos(pitch),sin(yaw+PI/2)*sin(pitch))*PI/18
	return [rotate_source(dir,rot),rotate_source(dir,-rot),dir]

static func wear_step(item: Dictionary) -> int:
	# Source tests get_enchantment("multishot") as a Lua boolean: even zero is
	# truthy, so its /3 durability branch applies to every crossbow shot.
	return floori(65535.0/((385.0*(Inventory.enchantment(item,"Unbreaking")+1))/3.0))

static func fire(player: VoxeyPlayer, samples: Array = []) -> Array:
	var game: Node3D = player.game
	var item: Dictionary = game.inventory.held()
	if not game.playing() or player.health <= 0 or not loaded_form(item): return []
	if not loaded(item):
		item.data.crossbow_loaded = false; BowUse.refresh(player); game.inventory.changed.emit(); return []
	var arrows: Array = []
	for dir in directions(item,-player.camera.global_basis.z,player.rotation.y,samples):
		var shot: Arrow = game.spawn_arrow(player.camera.global_position-Vector3.UP*0.1,dir*SPEED,int(item.data.loaded_arrow))
		shot.from_player = true; shot.shooter_id = player.get_instance_id(); shot.shooter_kind = "player"
		shot.critical = true; shot.piercing = Inventory.enchantment(item,"Piercing"); shot.recoverable = true
		shot.potion_data = item.data.get("loaded_arrow_data",{}).duplicate(true)
		arrows.append(shot)
	# The source keeps the last arrow metadata when reverting the item name.
	item.data.crossbow_loaded = false; item.data.erase("charge")
	if game.gamemode != "creative": Durability.set_normalized(item,Durability.normalized(item)+wear_step(item))
	cancel(player); BowUse.refresh(player); game.inventory.changed.emit(); player.swing = 1
	return arrows

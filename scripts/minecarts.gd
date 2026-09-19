class_name Minecarts
extends RefCounted

# Mineclonia mcl_minecarts entity service, GPL-3.0-or-later. Mirrors the existing
# `Boats` service: one owner for the live carts, their save records, streaming
# and the ridden cart, so carts persist independently of the player.
#
# Records live in `world.adventure_state.carts`, keyed by cart id, exactly as
# boats keep theirs. They deliberately do NOT go into `world.stations`, whose
# values are all typed as station dictionaries.

var game: Node3D
var active: Dictionary = {}
var riding: MinecartEntity = null
var stream_timer: float = 0.0
const STREAM_INTERVAL = 0.5

func _init(owner_game: Node3D) -> void:
	game = owner_game

func ridden() -> bool: return is_instance_valid(riding) and not riding.removed

func reset() -> void:
	for cart in active.values():
		if is_instance_valid(cart): cart.queue_free()
	active.clear(); riding = null

func records() -> Dictionary:
	if not game.world.adventure_state.get("carts") is Dictionary: game.world.adventure_state["carts"] = {}
	return game.world.adventure_state.carts

# --- records ----------------------------------------------------------------

func store(cart: MinecartEntity) -> void:
	if not is_instance_valid(cart) or cart.removed: return
	cart.store_record()
	active[cart.key] = cart
	var record: Dictionary = records().get(cart.key,{})
	record.merge(cart.saved,true)
	records()[cart.key] = record

func forget(cart: MinecartEntity) -> void:
	if not is_instance_valid(cart): return
	active.erase(cart.key)
	records().erase(cart.key)

# The cargo of a chest or hopper cart, created on first use.
func cargo(cart: MinecartEntity) -> Array:
	var size: int = CHEST_CART_SLOTS if cart.kind == Rails.CHEST_CART else (HOPPER_CART_SLOTS if cart.kind == Rails.HOPPER_CART else 0)
	if size == 0: return []
	var record: Dictionary = records().get(cart.key,{})
	if not record.get("cargo") is Array or record.cargo.size() != size:
		var slots: Array = []
		for i in size: slots.append({"id":0,"count":0,"wear":0})
		record["cargo"] = slots
		records()[cart.key] = record
	return record.cargo

const CHEST_CART_SLOTS = Rails.CHEST_CART_SLOTS
const HOPPER_CART_SLOTS = Rails.HOPPER_CART_SLOTS

func destroy(cart: MinecartEntity, drop_item: bool = true) -> void:
	if not is_instance_valid(cart) or cart.removed: return
	var kind: int = cart.kind
	var at: Vector3 = cart.position
	var slots: Array = cargo(cart).duplicate(true)
	cart.removed = true
	if riding == cart: dismount()
	forget(cart)
	cart.queue_free()
	if drop_item and game.gamemode != "creative":
		game.spawn_drop(at,kind,1)
		# Source returns a chest cart's contents when it is broken.
		for slot in slots:
			if int(slot.get("id",0)) != 0:
				game.spawn_drop(at,int(slot.id),int(slot.count),int(slot.get("wear",0)),slot.get("data",{}))
	game.puff(at,Color("9aa0a6"),10)

# --- spawning ---------------------------------------------------------------

# `key` is the identity of a saved cart; a fresh cart derives one from its cell.
# The key must be settled before the record is written, or a re-keyed cart leaves
# an orphan record behind that streaming would resurrect on every pass.
func spawn(kind: int, at: Vector3, key: String = "") -> MinecartEntity:
	if not Rails.is_cart(kind): return null
	var cart := MinecartEntity.new()
	cart.game = game; cart.service = self; cart.kind = kind
	cart.position = at
	if key.is_empty():
		cart.key = "%d:%d:%d" % [floori(at.x),floori(at.y),floori(at.z)]
		while active.has(cart.key) or records().has(cart.key): cart.key += "'"
	else: cart.key = key
	game.entities.add_child(cart)
	active[cart.key] = cart
	store(cart)
	return cart

# A cart is placed onto a rail, as source's `place_minecart` requires.
static func place(game: Node3D, target: Dictionary, kind: int) -> bool:
	if not Rails.is_cart(kind) or target.is_empty(): return false
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	if not Rails.is_rail(game.world.node_at(at)):
		var below: Vector3i = at+Vector3i.DOWN
		if not Rails.is_rail(game.world.node_at(below)):
			game.toast("Place rails first.")
			return true
		at = below
	var cart: MinecartEntity = game.rails.spawn(kind,Vector3(at)+Vector3(0.5,0.08,0.5))
	if cart == null: return true
	# Source sets the cart's yaw from the player's facing.
	var forward: Vector3 = -game.player.camera.global_basis.z
	cart.rotation.y = atan2(-forward.x,-forward.z)
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1
	game.api.emit_node_placed(at,kind)
	return true

# --- interaction ------------------------------------------------------------

func use(game_node: Node3D, target: Dictionary) -> bool:
	var cart: MinecartEntity = nearest(target)
	if cart == null: return false
	var held: int = game.inventory.held().id
	# A cart placed on a cart stacks in source, so let placement have it.
	if Rails.is_cart(held): return false
	var sneak: bool = Input.is_physical_key_pressed(KEY_CTRL) or (game.touch and is_instance_valid(game.controls) and game.controls.sneak_held)
	if sneak:
		# Sneak-use picks the cart up, returning it and its cargo.
		destroy(cart,true)
		game.player.swing = 1
		return true
	if cart.kind == Rails.FURNACE_CART and held in [Nodes.COAL,Nodes.CHARCOAL]:
		cart.fuel += Rails.FUEL_SECONDS
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.toast("The furnace cart burns for %d more seconds." % int(cart.fuel))
		game.player.swing = 1
		return true
	if cart.kind == Rails.TNT_CART and held == Nodes.FLINT_AND_STEEL:
		cart.ignite(Rails.TNT_FUSE)
		game.player.swing = 1
		return true
	# A chest cart opens its cargo from the side, as source's on_rightclick does.
	if cart.kind == Rails.CHEST_CART:
		open_chest(cart)
		return true
	board(cart)
	return true

func open_chest(cart: MinecartEntity) -> void:
	if cart.kind != Rails.CHEST_CART or cart.removed: return
	game.hud.return_cursor(); game.inventory.sync_pouches()
	game.state = "inventory"; game.world.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(game.controls): game.controls.hide_all()
	game.hud.container_page = 0
	game.hud.show_inventory("chest",{"kind":"cart","label":Nodes.title(cart.kind),"slots":cargo(cart),"cart_key":cart.key})

func board(cart: MinecartEntity) -> void:
	if ridden(): dismount()
	riding = cart; cart.rider = true
	game.sound("place"); game.player.swing = 1

func dismount() -> void:
	if not is_instance_valid(riding): riding = null; return
	var cart: MinecartEntity = riding
	cart.rider = false
	riding = null
	var exit: Vector3 = cart.position+Vector3.UP*1.2
	if game.world.loaded_at(exit) and not game.world.intersects(exit,0.29,1.8):
		game.player.position = exit
	game.player.velocity = Vector3.ZERO

func nearest(target: Dictionary) -> MinecartEntity:
	if target.is_empty(): return null
	var at: Vector3 = Vector3(target.pos)+Vector3.ONE*0.5
	var best: MinecartEntity = null
	var best_distance: float = 1.4
	for cart in active.values():
		if not is_instance_valid(cart) or cart.removed: continue
		var distance: float = cart.position.distance_to(at)
		if distance < best_distance: best_distance = distance; best = cart
	return best

# A cart whose rounded cell matches this rail, i.e. the one a rail is holding.
func cart_on(p: Vector3i) -> bool:
	for cart in active.values():
		if not is_instance_valid(cart) or cart.removed: continue
		if Vector3i(roundi(cart.position.x),roundi(cart.position.y),roundi(cart.position.z)) == p: return true
	return false

# Source `push_minecart`: every stationary cart in the cell gets `set_velocity`.
func push_cart_at(p: Vector3i) -> void:
	for cart in active.values():
		if not is_instance_valid(cart) or cart.removed: continue
		if Vector3i(roundi(cart.position.x),roundi(cart.position.y),roundi(cart.position.z)) != p: continue
		if cart.velocity.length_squared() > 0.0001: continue
		var direction: Vector3i = cart.find_direction(p,Vector3i(1,0,0))
		if direction == Vector3i.ZERO: return
		cart.punch(Vector3(direction),Rails.PUNCH_MAX)

func activate_at(p: Vector3i) -> void:
	for cart in active.values():
		if not is_instance_valid(cart) or cart.removed: continue
		if Vector3i(roundi(cart.position.x),roundi(cart.position.y),roundi(cart.position.z)) == p: cart.activate()

# --- simulation -------------------------------------------------------------

func update(delta: float) -> void:
	if ridden() and is_instance_valid(riding):
		# Source leaves the driver attached; the player rides along.
		game.player.position = riding.position+Vector3.UP*0.6
		game.player.velocity = Vector3.ZERO
	for cart in active.values():
		if not is_instance_valid(cart) or cart.removed: continue
		if cart.kind == Rails.HOPPER_CART: _collect(cart)
	stream_timer += delta
	if stream_timer < STREAM_INTERVAL: return
	stream_timer = 0.0
	snapshot()
	wake_near()

# Source hopper cart picks up one nearby dropped item per step.
func _collect(cart: MinecartEntity) -> void:
	var slots: Array = cargo(cart)
	for drop in game.drops.get_children():
		if not drop is ItemDrop or drop.is_queued_for_deletion() or drop.amount <= 0: continue
		if drop.position.distance_to(cart.position+Vector3.UP*0.9) > Rails.HOPPER_PICKUP_RADIUS: continue
		if not _insert(slots,drop): continue
		drop.amount -= 1
		if drop.amount <= 0: drop.queue_free()
		records()[cart.key]["cargo"] = slots
		return

func _insert(slots: Array, drop: ItemDrop) -> bool:
	for slot in slots:
		if slot.id == drop.item_id and int(slot.count) < Nodes.max_stack(int(drop.item_id)):
			slot.count = int(slot.count)+1
			return true
	for slot in slots:
		if int(slot.id) == 0:
			slot.id = drop.item_id; slot.count = 1; slot.wear = drop.wear
			if drop.data is Dictionary and not drop.data.is_empty(): slot["data"] = drop.data.duplicate(true)
			return true
	return false

# --- persistence and streaming ----------------------------------------------

func snapshot() -> void:
	for cart in active.values():
		if is_instance_valid(cart) and not cart.removed and not cart.is_queued_for_deletion(): store(cart)

static func restore(game_node: Node3D, saved: Dictionary) -> void:
	if not game_node.rails is Minecarts: return
	var service: Minecarts = game_node.rails
	service.reset()
	var entries: Dictionary = saved if saved is Dictionary else {}
	for key in entries:
		var entry: Dictionary = entries[key]
		if not entry is Dictionary: continue
		var kind: int = int(entry.get("kind",Rails.CART))
		if not Rails.is_cart(kind): continue
		var at: Vector3 = VillageLife.vec(entry.get("position",[0,0,0]))
		var cart: MinecartEntity = service.spawn(kind,at,str(key))
		if cart == null: continue
		cart.rotation.y = float(entry.get("yaw",0.0))
		var stored: Array = entry.get("velocity",[0,0,0])
		if stored.size() == 3: cart.velocity = Vector3(float(stored[0]),float(stored[1]),float(stored[2]))
		cart.fuel = float(entry.get("fuel",0.0))
		service.store(cart)

# Source unloads a cart that has left its streaming range; its record stays.
func unload(column: Vector2i) -> void:
	for cart in active.values():
		if not is_instance_valid(cart) or cart.removed: continue
		store(cart)
		if Vector2i(floori(cart.position.x/16.0),floori(cart.position.z/16.0)) == column:
			active.erase(cart.key)
			cart.queue_free()
	if is_instance_valid(riding) and riding.is_queued_for_deletion(): riding = null

# Wake the records whose cart has come back into range.
func wake_near() -> void:
	for key in records().keys():
		if active.has(key): continue
		var entry: Dictionary = records()[key]
		if not entry is Dictionary: continue
		if not Boats.finite_vector(entry.get("position")): continue
		var at: Vector3 = VillageLife.vec(entry.position)
		if not game.world.loaded_at(at): continue
		if game.player.position.distance_to(at) > 80: continue
		var kind: int = int(entry.get("kind",Rails.CART))
		if not Rails.is_cart(kind): continue
		var cart: MinecartEntity = spawn(kind,at,str(key))
		if cart == null: continue
		var stored: Array = entry.get("velocity",[0,0,0])
		if stored.size() == 3: cart.velocity = Vector3(float(stored[0]),float(stored[1]),float(stored[2]))
		cart.fuel = float(entry.get("fuel",0.0))

class_name Rails
extends RefCounted

# Mineclonia ENTITIES/mcl_minecarts/{init,functions,rails}.lua, GPL-3.0-or-later.
# Original procedural art.
#
# Source registers seven rail nodes with the engine `raillike` drawtype and lets
# the ENGINE resolve their shape from neighbours. Voxey has no raillike drawtype,
# so the engine's own table is transcribed here and evaluated in GDScript:
#
#   rail_direction[4]   = {(0,0,1), (0,0,-1), (-1,0,0), (1,0,0)}   (mapnode.cpp)
#   rail_slope_angle[4] = {0, 180, 90, -90}
#   rail_kinds[16] = {
#     {straight,  0}, {straight,  0}, {straight,  0}, {straight,  0},
#     {straight, 90}, {curved, 180},  {curved, 270},   {junction,180},
#     {straight, 90}, {curved,  90},  {curved,   0},   {junction, 0},
#     {straight, 90}, {junction,90},  {junction,270},  {cross,    0},
#   }
#
# The 4-bit code's bit order is `rail_direction`'s: +Z, -Z, -X, +X. A neighbour
# counts when the same rail sits at `dir`, `dir+(0,1,0)` or `dir+(0,-1,0)`. When
# any `dir+(0,1,0)` is the same rail the node is SLOPED; the engine then always
# uses the straight texture and tilts the mesh by `rail_slope_angle[dir]`, and it
# lets the LAST matching direction set the angle.
#
# Rails carry NO param2 in the source: the shape is derived from neighbours every
# time it is needed, so Voxey derives it the same way and stores no rail metadata.
#
# Redstone is `propagate_golden_rail_power`: a source neighbour injects 8, every
# traversed golden rail costs 1, over 4 lateral plus 4 diagonal-up and 4
# diagonal-down directions, where a diagonal step is skipped when its obstructing
# node is opaque. Only golden rails carry the power; detector and activator rails
# are plain on/off swaps.
#
# Movement is the source's Lua on_step, not engine physics: carts are
# `physical = false` there. Transcribed constants:
#   speed_max = 10 per axis, friction = 0.4, slope term = dir.y * -1.8,
#   furnace fuel adds 0.6, and `_rail_acceleration` is -3 for an unpowered
#   golden rail and +4 for a powered one.
#
# Recorded source gaps, not repaired:
# - Carts have no water or lava handling at all in the checkout; there is no
#   buoyancy to port, so carts follow their rail or roll to a stop.
# - Carts do not push each other, and the source deliberately never drops a cart
#   for leaving its rail (the comment at init.lua:330 says so outright).
# - Command-block carts are registered inert with no recipe, so none is added.
# - The corridor generator lives in a separate mapgen mod, not here.

const RAIL_BASE = 9300
const POWERED = 9320
const POWERED_ON = 9321
const DETECTOR = 9322
const DETECTOR_ON = 9323
const ACTIVATOR = 9324
const ACTIVATOR_ON = 9325
const CART = 9340
const CHEST_CART = 9341
const FURNACE_CART = 9342
const HOPPER_CART = 9343
const TNT_CART = 9344
const RAIL_IDS = [RAIL_BASE,POWERED,POWERED_ON,DETECTOR,DETECTOR_ON,ACTIVATOR,ACTIVATOR_ON]
const ITEM_RAILS = [RAIL_BASE,POWERED,DETECTOR,ACTIVATOR]
const CART_IDS = [CART,CHEST_CART,FURNACE_CART,HOPPER_CART,TNT_CART]
const RAIL_NAMES = ["Rail","Powered rail","Powered rail (on)","Detector rail","Detector rail (on)","Activator rail","Activator rail (on)"]
const CART_NAMES = ["Minecart","Minecart with chest","Minecart with furnace","Minecart with hopper","Minecart with TNT"]

const SPEED_MAX = 10.0
const FRICTION = 0.4
const SLOPE_TERM = -1.8
const FUEL_BOOST = 0.6
const POWERED_BRAKE = -3.0
const POWERED_ACCELERATE = 4.0
const FUEL_SECONDS = 180.0
const TNT_FUSE = 4.0
const ACTIVATOR_TNT_FUSE = 2.0
# Source `set_velocity` multiplies the direction by three.
const PUNCH_MAX = 3.0
const HOPPER_CART_SLOTS = 5
const CHEST_CART_SLOTS = 27
const HOPPER_PICKUP_RADIUS = 1.25

const DIRECTIONS = [Vector3i(0,0,1),Vector3i(0,0,-1),Vector3i(-1,0,0),Vector3i(1,0,0)]
const SLOPE_ANGLES = [0,180,90,-90]
const SHAPES = [[0,0],[0,0],[0,0],[0,0],[0,90],[1,180],[1,270],[2,180],[0,90],[1,90],[1,0],[2,0],[0,90],[2,90],[2,270],[3,0]]
const STRAIGHT = 0
const CURVED = 1
const JUNCTION = 2
const CROSS = 3

const RAIL_POWER = 8

const DATA = {
	9300:{"name":"Rail","block":true,"color":"9aa0a6","hardness":0.7},
	9320:{"name":"Powered rail","block":true,"color":"d8b04a","hardness":0.7},
	9321:{"name":"Powered rail (on)","block":true,"color":"f0d071","hardness":0.7,"drop":9320,"hidden":true},
	9322:{"name":"Detector rail","block":true,"color":"b08d6a","hardness":0.7},
	9323:{"name":"Detector rail (on)","block":true,"color":"d8a86a","hardness":0.7,"drop":9322,"hidden":true},
	9324:{"name":"Activator rail","block":true,"color":"c07a5a","hardness":0.7},
	9325:{"name":"Activator rail (on)","block":true,"color":"e09a6a","hardness":0.7,"drop":9324,"hidden":true},
	9340:{"name":"Minecart","stack":1,"color":"9aa0a6"},
	9341:{"name":"Minecart with chest","stack":1,"color":"a47d43"},
	9342:{"name":"Minecart with furnace","stack":1,"color":"74787c"},
	9343:{"name":"Minecart with hopper","stack":1,"color":"454b53"},
	9344:{"name":"Minecart with TNT","stack":1,"color":"c8402f"},
}
static var icons: Dictionary = {}

# --- registry ---------------------------------------------------------------

static func is_rail(id: int) -> bool: return RAIL_IDS.has(id)
static func is_item_rail(id: int) -> bool: return ITEM_RAILS.has(id)
static func is_cart(id: int) -> bool: return CART_IDS.has(id)
static func is_golden(id: int) -> bool: return id == POWERED or id == POWERED_ON

# The three powered families swap between an off and an on node. A swap must not
# clear the block's circuit state, so the solver treats each pair as one family.
static func same_family(a: int, b: int) -> bool:
	return powered_pair(a) == powered_pair(b) and powered_pair(a) >= 0
static func powered_pair(id: int) -> int:
	if id in [POWERED,POWERED_ON]: return 0
	if id in [DETECTOR,DETECTOR_ON]: return 1
	if id in [ACTIVATOR,ACTIVATOR_ON]: return 2
	return -1

static func is_on(id: int) -> bool: return id in [POWERED_ON,DETECTOR_ON,ACTIVATOR_ON]

static func title(id: int) -> String:
	var rail: int = RAIL_IDS.find(id)
	if rail >= 0: return RAIL_NAMES[rail]
	var cart: int = CART_IDS.find(id)
	return CART_NAMES[cart] if cart >= 0 else "Rail"

# What the node breaks into and what the inventory shows.
static func item(id: int) -> int:
	if id == POWERED_ON: return POWERED
	if id == DETECTOR_ON: return DETECTOR
	if id == ACTIVATOR_ON: return ACTIVATOR
	return id

# The on/off swap of a powered family, keeping its identity.
static func toggled(id: int, on: bool) -> int:
	match powered_pair(id):
		0: return POWERED_ON if on else POWERED
		1: return DETECTOR_ON if on else DETECTOR
		2: return ACTIVATOR_ON if on else ACTIVATOR
	return id

# --- engine shape resolution -------------------------------------------------

# Source `is_rail` uses the rail group, so every rail family connects to every
# other: `connect_to_raillike` is the same rail group for all seven nodes.
static func same_rail(world: VoxelWorld, p: Vector3i) -> bool:
	return is_rail(world.node_at(p))

# The engine's 4-bit neighbour code, bit order +X, -X, +Z, -Z.
static func shape_code(world: VoxelWorld, p: Vector3i) -> int:
	var code: int = 0
	for bit in 4:
		var dir: Vector3i = DIRECTIONS[bit]
		if same_rail(world,p+dir) or same_rail(world,p+dir+Vector3i.UP) or same_rail(world,p+dir+Vector3i.DOWN): code |= 1 << bit
	return code

static func resolved_shape(world: VoxelWorld, p: Vector3i) -> int:
	return SHAPES[shape_code(world,p)][0]

static func resolved_turn(world: VoxelWorld, p: Vector3i) -> float:
	return float(SHAPES[shape_code(world,p)][1])

# The engine marks a rail sloped when the same rail sits directly above a
# horizontal neighbour; the slope always draws as straight, tilted.
static func slope(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var result: Dictionary = {"sloped":false,"angle":0.0,"dir":Vector3i.ZERO}
	for bit in 4:
		var dir: Vector3i = DIRECTIONS[bit]
		if same_rail(world,p+dir+Vector3i.UP): result = {"sloped":true,"angle":float(SLOPE_ANGLES[bit]),"dir":dir}
	return result

# --- placement, support ------------------------------------------------------

static func supported(world: VoxelWorld, p: Vector3i, placing: bool = false) -> bool:
	var below: Vector3i = p+Vector3i.DOWN
	if not world.loaded_at(Vector3(below)): return not placing
	if Nodes.solid(world.node_at(below)): return true
	# Source `attached_node` allows a rail to rest on the rail below it, which is
	# what makes a slope's upper end legal.
	return is_rail(world.node_at(below))

static func try_place(game: Node3D, target: Dictionary) -> bool:
	var held: int = game.inventory.held().id
	if not is_item_rail(held) or target.is_empty(): return false
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	var current: int = game.world.node_at(at)
	if current != Nodes.AIR and not SnowCover.replaceable(current) and not Nodes.plant(current) and not Fluids.liquid(current) and not Fire.is_fire(current): return true
	if not supported(game.world,at,true): return true
	if game.world.set_node(at,held):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,held)
		# Neighbours re-resolve their shape, and a slope may become legal.
		support_changed(game.world,at)
	return true

static func support_changed(world: VoxelWorld, p: Vector3i) -> void:
	for side in [Vector3i.ZERO,Vector3i.DOWN,Vector3i.UP,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		var at: Vector3i = p+side
		var id: int = world.node_at(at)
		if not is_rail(id) or supported(world,at): continue
		if world.set_node(at,Nodes.AIR):
			world.get_parent().spawn_drop(Vector3(at)+Vector3.ONE*0.5,item(id),1)

# --- redstone ----------------------------------------------------------------

# Source `propagate_golden_rail_power`: a directly powered golden rail stores 8,
# and each golden rail reached from it stores one less, over the 12 directions.
# The level a rail holds is therefore `8 - distance` to the nearest powered rail,
# which is what its own param2 — and so its output — carries.
static func rail_power(world: VoxelWorld, p: Vector3i) -> int:
	if not is_golden(world.node_at(p)): return 0
	var best: Dictionary = {p:0}
	var queue: Array = [p]
	var index: int = 0
	var result: int = 0
	while index < queue.size():
		var at: Vector3i = queue[index]; index += 1
		var distance: int = int(best[at])
		if world.circuits.input_power(at) > 0: result = maxi(result,RAIL_POWER-distance)
		if distance >= RAIL_POWER-1: continue
		for step in _propagation_steps(world,at):
			var next: Vector3i = step.pos
			if not is_golden(world.node_at(next)) or best.has(next): continue
			if step.obstruct != Vector3i.ZERO and Pasture.opaque(world.node_at(at+step.obstruct)): continue
			best[next] = distance+1
			queue.append(next)
	return result

static func _propagation_steps(world: VoxelWorld, at: Vector3i) -> Array:
	var result: Array = []
	for dir in DIRECTIONS:
		result.append({"pos":at+dir,"obstruct":Vector3i.ZERO})
		result.append({"pos":at+dir+Vector3i.UP,"obstruct":Vector3i.UP})
		result.append({"pos":at+dir+Vector3i.DOWN,"obstruct":dir})
	return result

# The solver calls this for every tracked rail. Only golden rails keep power;
# detector and activator rails are plain swaps.
static func tick(world: VoxelWorld, p: Vector3i, id: int, state: Dictionary, _delta: float) -> void:
	if not is_rail(id): return
	var power: int = world.circuits.input_power(p)
	match powered_pair(id):
		0:
			var wanted: int = toggled(id,power > 0)
			state["out"] = RAIL_POWER if power > 0 else 0
			if wanted != id:
				if world.set_node(p,wanted): world.circuits.refresh(p)
				# Source pushes every stationary cart when a rail newly powers on.
				if power > 0 and world.get_parent() != null and world.get_parent().rails != null:
					world.get_parent().rails.push_cart_at(p)
			return
		1:
			var occupied: bool = world.get_parent() != null and world.get_parent().rails != null and world.get_parent().rails.cart_on(p)
			state["out"] = 15 if occupied else 0
			var wanted: int = toggled(id,occupied)
			if wanted != id and world.set_node(p,wanted): world.circuits.refresh(p)
			return
		2:
			var wanted: int = toggled(id,power > 0)
			if wanted != id and world.set_node(p,wanted): world.circuits.refresh(p)
			# The ON node activates the carts standing on it.
			if power > 0 and world.get_parent() != null and world.get_parent().rails != null:
				world.get_parent().rails.activate_at(p)
			state["out"] = 0

# A golden rail emits its stored level in every direction; an ON detector rail
# powers the block below it strongly, exactly as source's `get_power` says.
static func output(id: int, state: Dictionary, toward: Vector3i) -> int:
	if id == POWERED or id == POWERED_ON: return clampi(int(state.get("out",0)),0,15)
	if id == DETECTOR or id == DETECTOR_ON: return 15 if toward == Vector3i.DOWN else 0
	return 0

# --- art --------------------------------------------------------------------

# Two metal strips over wooden sleepers. Drawn as a flat plate because the rail
# occupies only the bottom sixteenth of its cell.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base: Color = Color(DATA[id].color)
	if is_rail(id):
		if y in [3,12]: return Color("8a6a42")
		if x in [2,3,12,13] or x in [7,8]: return base
		return Color(base.r,base.g,base.b,0.0)
	return base.lightened(0.12) if posmod(x*3+y*5,9) == 0 else noise

static func draw(img: Image, id: int) -> void:
	if is_cart(id):
		ItemArt._polygon(img,[[2,4],[13,4],[15,9],[12,13],[3,13],[1,9]],Color("8f959b") if id == CART else Color(DATA[id].color))
		ItemArt._line(img,Vector2(3,6),Vector2(13,6),Color("c2c8ce"))
		if id == CHEST_CART: img.fill_rect(Rect2i(5,6,6,4),Color("a47d43"))
		if id == FURNACE_CART: img.fill_rect(Rect2i(5,6,6,4),Color("4a4e52"))
		if id == HOPPER_CART: img.fill_rect(Rect2i(5,6,6,4),Color("2f3438"))
		if id == TNT_CART: img.fill_rect(Rect2i(5,6,6,4),Color("c8402f"))
		return
	ItemArt._line(img,Vector2(1,7),Vector2(14,7),Color("8a6a42"),2)
	ItemArt._line(img,Vector2(1,10),Vector2(14,10),Color("8a6a42"),2)
	ItemArt._line(img,Vector2(3,3),Vector2(3,13),Color(DATA[id].color),2)
	ItemArt._line(img,Vector2(12,3),Vector2(12,13),Color(DATA[id].color),2)

# Source walkable = false with a bottom-sixteenth selection box.
static func boxes(id: int) -> Array:
	return [AABB(Vector3.ZERO,Vector3(1,1.0/16,1))] if is_rail(id) else []

# --- mesher-facing shape resolution ------------------------------------------
#
# The chunk mesher works on its own padded 18^3 array, so the same neighbour
# tests have to read that array rather than the world. Index layout is
# `x + z*18 + y*324` with the cell itself already offset by one.

static func _packed(data: Variant, cell: Vector3i, dx: int, dy: int, dz: int) -> int:
	return int(data[cell.x+dx+(cell.z+dz)*18+(cell.y+dy)*324])

static func shape_code_in(data: Variant, cell: Vector3i) -> int:
	var code: int = 0
	for bit in 4:
		var dir: Vector3i = DIRECTIONS[bit]
		if is_rail(_packed(data,cell,dir.x,dir.y,dir.z)) \
			or is_rail(_packed(data,cell,dir.x,1,dir.z)) \
			or is_rail(_packed(data,cell,dir.x,-1,dir.z)): code |= 1 << bit
	return code

static func slope_in(data: Variant, cell: Vector3i) -> Dictionary:
	var result: Dictionary = {"sloped":false,"angle":0.0,"dir":Vector3i.ZERO}
	for bit in 4:
		var dir: Vector3i = DIRECTIONS[bit]
		if is_rail(_packed(data,cell,dir.x,1,dir.z)): result = {"sloped":true,"angle":float(SLOPE_ANGLES[bit]),"dir":dir}
	return result

static func mesh_in(out: Array, p: Vector3, id: int, data: Variant, cell: Vector3i) -> void:
	var code: int = shape_code_in(data,cell)
	mesh(out,p,id,slope_in(data,cell),SHAPES[code][0],float(SHAPES[code][1]))

# The mesh follows the engine's resolved shape: curved and junction pieces turn
# their sleepers, a crossing draws both axes, and a slope tilts the whole plate.
static func mesh(out: Array, p: Vector3, id: int, world_slope: Dictionary = {}, shape: int = STRAIGHT, turn: float = 0.0) -> void:
	var tile: int = Nodes.tile(id,0)
	var basis := Basis()
	if world_slope.get("sloped",false): basis = Basis(Vector3.RIGHT,deg_to_rad(float(world_slope.angle)))
	if turn != 0.0: basis = basis*Basis(Vector3.UP,deg_to_rad(turn))
	for strip in [-0.28,0.28]:
		_art(out,basis*Vector3(0.5+strip*0.4,0.045,0.5)+p,Vector3(0.12,0.05,0.94),tile)
	# A crossing carries a second pair of strips along the other axis.
	if shape == CROSS:
		for strip in [-0.28,0.28]:
			_art(out,basis*Vector3(0.5,0.045,0.5+strip*0.4)+p,Vector3(0.94,0.05,0.12),tile)
	var sleepers: Array = [0.22,0.5,0.78] if shape != CROSS else [0.22,0.78]
	for sleeper in sleepers:
		for offset in [-0.4,0.4]:
			_art(out,basis*Vector3(0.5+offset,0.02,sleeper)+p,Vector3(0.28,0.045,0.13),tile)
			if shape == CROSS:
				_art(out,basis*Vector3(sleeper,0.02,0.5+offset)+p,Vector3(0.13,0.045,0.28),tile)

static func _art(out: Array, centre: Vector3, size: Vector3, tile: int) -> void:
	BlockMesher._art_box(out,centre,size,tile,tile)

static func icon_faces(id: int) -> Array:
	if not icons.has(id):
		var out: Array = BlockMesher._empty()
		if is_rail(id): mesh(out,Vector3.ZERO,id)
		else: BlockMesher._art_box(out,Vector3(0.5,0.3,0.5),Vector3(0.8,0.6,0.8),Nodes.tile(Nodes.IRON_BLOCK,0),Nodes.tile(Nodes.IRON_BLOCK,2))
		icons[id] = Barriers.project_icon(out)
	return icons[id]

# --- recipes ----------------------------------------------------------------

static func recipes(inv: Inventory) -> void:
	var iron: int = Nodes.IRON
	var gold: int = Nodes.GOLD
	var stick: int = Nodes.STICK
	var redstone: int = Nodes.REDSTONE_WIRE
	inv._recipe("Rails",RAIL_BASE,16,[iron,0,iron,iron,stick,iron,iron,0,iron],3,"table")
	inv._recipe("Powered rails",POWERED,6,[gold,0,gold,gold,stick,gold,gold,redstone,gold],3,"table")
	inv._recipe("Detector rails",DETECTOR,6,[iron,0,iron,iron,Nodes.PRESSURE_PLATE,iron,iron,redstone,iron],3,"table")
	inv._recipe("Activator rails",ACTIVATOR,6,[iron,stick,iron,iron,Nodes.REDSTONE_TORCH,iron,iron,stick,iron],3,"table")
	inv._recipe("Minecart",CART,1,[iron,0,iron,iron,iron,iron],2,"table")
	inv._recipe("Minecart with chest",CHEST_CART,1,[0,Nodes.CHEST,0,CART,Nodes.CHEST,CART],2,"table")
	inv._recipe("Minecart with furnace",FURNACE_CART,1,[0,Nodes.FURNACE,0,CART,Nodes.FURNACE,CART],2,"table")
	inv._recipe("Minecart with hopper",HOPPER_CART,1,[0,Nodes.HOPPER,0,CART,Nodes.HOPPER,CART],2,"table")
	inv._recipe("Minecart with TNT",TNT_CART,1,[0,Nodes.TNT,0,CART,Nodes.TNT,CART],2,"table")

class_name MinecartEntity
extends Node3D

# Mineclonia mcl_minecarts entity behavior, GPL-3.0-or-later. Source carts are
# `physical = false` with all movement in Lua, so this is the source formula
# rather than engine physics: on flat ground the acceleration is
# `dir.y * -1.8 - 0.4`, a powered rail adds +4 or subtracts 3, furnace fuel adds
# 0.6, and each axis is clamped to 10.

var game: Node3D
var service: Minecarts
var key: String
var kind: int = Rails.CART
var saved: Dictionary = {}
var rider: bool = false
# Movement state, in the source's own units.
var velocity := Vector3.ZERO
var acceleration := Vector3.ZERO
# The direction the source remembers between steps, and the switch it latched.
var old_direction := Vector3.ZERO
var old_switch: int = 0
var fuel: float = 0.0
var fuse: float = -1.0
var removed: bool = false
var animation: float = 0.0
var model: Node3D
# Source only re-queries the node when the cart leaves its cell.
var last_cell := Vector3i(0,2147483647,0)
var last_direction := Vector3.ZERO
# Rolling resistance once a cart leaves its rail, and the punch factor source
# applies over a half-second window.
const STOP_FRICTION = 2.0

func _ready() -> void:
	model = RailsArt.build(self,kind)

func _physics_process(delta: float) -> void:
	if removed or game == null or not game.playing() or not game.world.loaded_at(position): return
	step(delta)

# The source runs on_step per server step; a 20 Hz reference with substeps keeps
# fast and slow frames consistent.
func step(delta: float) -> void:
	if removed: return
	if fuse >= 0.0:
		fuse -= delta
		if fuse <= 0.0:
			detonate()
			return
	if fuel > 0.0: fuel = maxf(0.0,fuel-delta)
	var remaining: float = minf(delta,0.5)
	while remaining > 0.00001 and not removed:
		var part: float = minf(remaining,0.05); remaining -= part
		_move_step(part)
		if velocity.length_squared() < 0.000001 and fuel <= 0.0: break
	if removed: return
	animation += delta*4.0*clampf(Vector2(velocity.x,velocity.z).length()*0.25,0.2,2.0)

# Source `get_rail_direction` probes forward, then left, then right, then back;
# `check_front_up_down` tries the same horizontal cell, then one up (only when
# `check_down`), then one down.
func find_direction(cell: Vector3i, dir: Vector3i, check_down: bool = true) -> Vector3i:
	var horizontal := Vector3i(dir.x,0,dir.z)
	if Rails.is_rail(game.world.node_at(cell+horizontal)): return horizontal
	if check_down and Rails.is_rail(game.world.node_at(cell+horizontal+Vector3i.UP)): return horizontal+Vector3i.UP
	if Rails.is_rail(game.world.node_at(cell+horizontal+Vector3i.DOWN)): return horizontal+Vector3i.DOWN
	return Vector3i.ZERO

# The full source search, including the junction switch the driver's ctrl uses.
func rail_direction(cell: Vector3i, dir: Vector3i, ctrl: int = 0) -> Array:
	var left := Vector3i.ZERO
	var right := Vector3i.ZERO
	var left_check: bool = true
	var right_check: bool = true
	if dir.z != 0 and dir.x == 0:
		left.x = -dir.z; right.x = dir.z
	elif dir.x != 0 and dir.z == 0:
		left.z = dir.x; right.z = -dir.x
	if ctrl != 0:
		if old_switch == 1: left_check = false
		elif old_switch == 2: right_check = false
		if ctrl == 1 and left_check:
			var turned_left: Vector3i = find_direction(cell,left,false)
			if turned_left != Vector3i.ZERO: return [turned_left,1]
			left_check = false
		if ctrl == 2 and right_check:
			var turned_right: Vector3i = find_direction(cell,right,false)
			if turned_right != Vector3i.ZERO: return [turned_right,2]
			right_check = true
	var straight: Vector3i = find_direction(cell,dir)
	if straight != Vector3i.ZERO: return [straight,0]
	if left_check:
		var found_left: Vector3i = find_direction(cell,left,false)
		if found_left != Vector3i.ZERO: return [found_left,0]
	if right_check:
		var found_right: Vector3i = find_direction(cell,right,false)
		if found_right != Vector3i.ZERO: return [found_right,0]
	# Backwards, only while the source has no latched switch.
	if old_switch == 0:
		var back: Vector3i = find_direction(cell,Vector3i(-dir.x,0,-dir.z))
		if back != Vector3i.ZERO: return [back,0]
	return [Vector3i.ZERO,0]

# `velocity_to_dir`, the source's own sign snap.
static func get_sign(value: float) -> int:
	return 0 if value == 0.0 else (1 if value > 0.0 else -1)

static func velocity_to_dir(v: Vector3) -> Vector3i:
	if absf(v.x) > absf(v.z): return Vector3i(get_sign(v.x),0,0)
	return Vector3i(0,0,get_sign(v.z))

func _move_step(delta: float) -> void:
	var cell := Vector3i(roundi(position.x),roundi(position.y),roundi(position.z))
	# Source returns early while the cart stays in the same cell, unless fuelled.
	if cell == last_cell and fuel <= 0.0 and old_direction != Vector3.ZERO: return
	# Detector rails under the cart switch on; the one behind switches off.
	if cell != last_cell: _refresh_rails(cell,last_cell)
	last_cell = cell
	var rail_id: int = game.world.node_at(cell)
	if not Rails.is_rail(rail_id):
		# A cart that leaves its rail rolls to a stop. Source never drops it.
		var decel: float = STOP_FRICTION*delta
		for axis in 3: velocity[axis] = move_toward(velocity[axis],0.0,decel)
		_slide(delta)
		last_direction = old_direction
		return
	# Source stops the cart outright when its velocity reverses.
	if old_direction.y == 0.0 and (old_direction.x*velocity.x < 0.0 or old_direction.z*velocity.z < 0.0):
		velocity = Vector3.ZERO; acceleration = Vector3.ZERO
		old_direction = Vector3.ZERO
		return
	if velocity.y == 0.0:
		for axis in [0,2]:
			if velocity[axis] != 0.0 and absf(velocity[axis]) < 0.9: velocity[axis] = 0.0
	var cart_dir: Vector3i = velocity_to_dir(velocity)
	var found: Array = rail_direction(cell,cart_dir if cart_dir != Vector3i.ZERO else velocity_to_dir(old_direction),rider_ctrl())
	var direction: Vector3i = found[0]
	old_switch = int(found[1])
	if direction == Vector3i.ZERO and fuel <= 0.0:
		velocity = Vector3.ZERO; acceleration = Vector3.ZERO
		return
	var acc: float = float(direction.y)*Rails.SLOPE_TERM
	# Turning transfers the speed to the new axis, as source does.
	if direction.x != 0 and old_direction.z != 0.0:
		velocity.x = float(direction.x)*absf(velocity.z); velocity.z = 0.0
		position.z = floorf(position.z+0.5)
	if direction.z != 0 and old_direction.x != 0.0:
		velocity.z = float(direction.z)*absf(velocity.x); velocity.x = 0.0
		position.x = floorf(position.x+0.5)
	if float(direction.y) != old_direction.y:
		velocity.y = float(direction.y)*absf(velocity.x+velocity.z)
		position = position.round()
	acc -= Rails.FRICTION
	if fuel > 0.0: acc += Rails.FUEL_BOOST
	var speed_mod: float = 0.0
	if rail_id == Rails.POWERED_ON: speed_mod = Rails.POWERED_ACCELERATE
	elif rail_id == Rails.POWERED: speed_mod = Rails.POWERED_BRAKE
	if speed_mod != 0.0: acc += speed_mod+Rails.FRICTION
	acceleration = Vector3(direction)*acc
	velocity += acceleration*delta
	for axis in 3:
		if absf(velocity[axis]) > Rails.SPEED_MAX:
			velocity[axis] = signf(velocity[axis])*Rails.SPEED_MAX
			acceleration[axis] = 0.0
	old_direction = Vector3(direction)
	_slide(delta)

# The source reads the driver's left/right keys and hands them to the junction
# logic; without a driver there is no switch input.
func rider_ctrl() -> int:
	if not rider or service == null or service.riding != self: return 0
	if Input.is_action_pressed("move_left"): return 1
	if Input.is_action_pressed("move_right"): return 2
	return 0

# Source swaps a detector rail on under the cart and the one behind it back off.
func _refresh_rails(cell: Vector3i, previous: Vector3i) -> void:
	if cell == previous: return
	var here: int = game.world.node_at(cell)
	if here == Rails.DETECTOR: game.world.set_node(cell,Rails.DETECTOR_ON)
	if game.world.node_at(previous) == Rails.DETECTOR_ON and not (game.rails != null and game.rails.cart_on(previous)):
		game.world.set_node(previous,Rails.DETECTOR)

func _slide(delta: float) -> void:
	if velocity.length_squared() < 0.000001: return
	if position.y < game.world.generator.min_y()-5: service.destroy(self); return
	var motion: Vector3 = velocity*delta
	var steps: int = maxi(1,ceili(motion.length()/0.2))
	var part: Vector3 = motion/steps
	for i in steps:
		var next: Vector3 = position+part
		if not game.world.loaded_at(next): velocity = Vector3.ZERO; return
		# Rails are not solid and carts pass players, so only terrain blocks.
		if game.world.intersects(next,0.62,0.75):
			velocity = Vector3.ZERO
			return
		position = next

func seat_occupants() -> void:
	if not rider: return

func store_record() -> void:
	if removed: return
	saved["position"] = [position.x,position.y,position.z]
	saved["yaw"] = rotation.y
	saved["kind"] = kind
	saved["velocity"] = [velocity.x,velocity.y,velocity.z]
	saved["fuel"] = fuel
	saved["rider"] = rider

# `set_velocity`: a punch is always three units along the puncher's look.
func punch(direction: Vector3, factor: float = Rails.PUNCH_MAX) -> void:
	velocity = direction.normalized()*factor
	old_direction = Vector3.ZERO
	last_cell = Vector3i(0,2147483647,0)

func ignite(fuse_seconds: float) -> void:
	if kind != Rails.TNT_CART or fuse >= 0.0: return
	fuse = fuse_seconds
	game.sound_at("fuse",position,0.8)

func detonate() -> void:
	if removed: return
	var at: Vector3 = position
	service.destroy(self,false)
	game.explode(at,4.0)

# Only the plain minecart ejects its driver and only the TNT cart ignites, as
# the source's on_activate_by_rail implementations do.
func activate() -> void:
	if kind == Rails.CART:
		rider = false
		saved["rider"] = false
		if service != null and service.riding == self: service.dismount()
	elif kind == Rails.TNT_CART:
		ignite(Rails.ACTIVATOR_TNT_FUSE)

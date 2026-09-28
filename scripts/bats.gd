class_name Bats
extends RefCounted

# `mobs_mc:bat` (ENTITIES/mobs_mc/bat.lua): the cave's ambient flyer. It has no
# drops, no experience and no attack; it flits between random nearby targets
# and hangs from a ceiling until a player comes within four nodes.
#
# Source numbers, per 0.05 s tick unless noted:
# * `motion_step` (bat.lua:61-145). A new target is picked when there is none,
#   when the target has become walkable, at 1 in 30, or within 2 nodes. It is
#   the bat's own node plus `random(0,6) - random(0,6)` on x and z and
#   `random(0,5) - 2` on y. Velocity moves `0.1` of the way toward
#   `sign(d) * 10` horizontally and `sign(d) * 14` vertically.
# * Resting. With an opaque solid node above, a flying bat starts hanging at
#   1 in 100 per tick. It hangs 0.9 below that ceiling and turns at 1 in 200.
#   It wakes when the ceiling goes or when a player comes within four nodes.
# * `gravity_drag = 0.6`, `_no_fall_damage`, six health, `can_despawn`.
# * Spawning (bat.lua:165-203): the `ambient` category, packs of 8, only below
#   the source's sea level of zero, at light 3 or less (6 in Halloween week),
#   and never where the sky can be seen.
#
# Voxey runs its step every frame, so each per-tick chance `1/n` becomes the
# probability of at least one success over the frame's ticks, which is
# `mcl_mobs.scale_chance`. The flight target is kept on the mob.

const KIND = "bat"
const HORIZONTAL = 10.0
const VERTICAL = 14.0
const LERP = 0.1
const TICK = 0.05
const RETARGET_ODDS = 30
const REST_ODDS = 100
const TURN_ODDS = 200
const WAKE_RANGE = 4.0
const HANG_BELOW = 0.9
const MAX_LIGHT = 3
const HALLOWEEN_LIGHT = 6
const PACK = 8
# The ambient category's cap for one player, which is the source's
# `min_chunk_mob_cap = 5`: Voxey loads far fewer chunks than a server's view.
const AMBIENT_CAP = 5

static func is_bat(kind: String) -> bool: return kind == KIND

# `mcl_mobs.scale_chance`: the per-tick denominator scaled to a step of `delta`
# seconds, never below one.
static func scale_chance(odds: int, delta: float) -> int:
	return maxi(1,roundi(float(odds)/maxf(delta/TICK,0.0001)))

static func pick_target(cell: Vector3i, rng: RandomNumberGenerator) -> Vector3i:
	var x: int = rng.randi_range(0,6)-rng.randi_range(0,6)
	var z: int = rng.randi_range(0,6)-rng.randi_range(0,6)
	var y: int = rng.randi_range(0,5)-2
	return cell+Vector3i(x,y,z)

# One axis of the bat's velocity update, which the source applies per tick.
static func steer(velocity: float, distance: float, top: float, delta: float) -> float:
	var sign_value: float = -1.0 if distance < 0.0 else (0.0 if distance == 0.0 else 1.0)
	var scale: float = minf(1.0,LERP*delta/TICK)
	return velocity+(sign_value*top-velocity)*scale

static func opaque_solid(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	return Nodes.solid(id) and not Nodes.transparent(id)

# `bat_spawner:test_spawn_position`.
static func halloween_week(date: Dictionary) -> bool:
	var month: int = int(date.get("month",1)); var day: int = int(date.get("day",1))
	return (month == 10 and day >= 20) or (month == 11 and day <= 3)

static func max_light(date: Dictionary) -> int:
	return HALLOWEEN_LIGHT if halloween_week(date) else MAX_LIGHT

static func spawn_allowed(world: VoxelWorld, cell: Vector3i, date: Dictionary) -> bool:
	if world.dimension != "overworld": return false
	if cell.y >= TerrainGenerator.SEA: return false
	if world.open_sky(cell): return false
	if Nodes.solid(world.node_at(cell)) or not Nodes.solid(world.node_at(cell+Vector3i.DOWN)): return false
	return Pasture.light(world,cell,max_light(date)+1) <= max_light(date)

static func ambient_count(game: Node3D) -> int:
	var count: int = 0
	for mob in game.creatures.get_children():
		if mob.kind == KIND and not mob.is_queued_for_deletion() and mob.position.distance_to(game.player.position) <= 128: count += 1
	return count

# A pack around `center`: up to the source's eight, stopped by the cap, each at
# a cell that passes the spawn test. Returns the bats made.
static func spawn_pack(game: Node3D, center: Vector3, rng: RandomNumberGenerator) -> Array:
	var made: Array = []
	var room: int = AMBIENT_CAP-ambient_count(game)
	var date: Dictionary = Time.get_date_dict_from_system()
	for attempt in PACK:
		if made.size() >= room: break
		var cell := Vector3i(center.floor())+Vector3i(rng.randi_range(-3,3),rng.randi_range(-1,1),rng.randi_range(-3,3))
		if not game.world.loaded_at(Vector3(cell)) or not spawn_allowed(game.world,cell,date): continue
		var bat: Creature = game.spawn_creature(KIND,Vector3(cell)+Vector3(0.5,0.05,0.5))
		if bat != null: made.append(bat)
	return made

static func rng_for(world: VoxelWorld) -> RandomNumberGenerator:
	if not world.has_meta("bats_rng"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+8191
		world.set_meta("bats_rng",rng)
	return world.get_meta("bats_rng")

class Mob extends Creature:
	var target := Vector3i.MAX
	var resting: bool = false

	func _build_model() -> void:
		# A small furry body with a face, big ears and two leathery wings.
		var fur := Color("4c3e30")
		var membrane := Color("2a221c")
		_box(Vector3(0,0.42,0),Vector3(0.24,0.3,0.2),fur,"fur")
		head = _joint(Vector3(0,0.62,0),"Head")
		_box(Vector3(0,0.06,0),Vector3(0.22,0.2,0.2),fur,"fur",head)
		for side in [-1,1]:
			_box(Vector3(side*0.08,0.22,0),Vector3(0.06,0.1,0.04),membrane,"skin",head)
			_box(Vector3(side*0.05,0.08,-0.105),Vector3(0.035,0.035,0.012),Color("0f0f0f"),"",head)
			var wing := _joint(Vector3(side*0.12,0.46,0),"Wing")
			_box(Vector3(side*0.22,0,0.02),Vector3(0.44,0.26,0.03),membrane,"skin",wing)
			arms.append(wing)
		for side in [-1,1]:
			var leg := _joint(Vector3(side*0.06,0.28,0),"Hip")
			_box(Vector3(0,-0.06,0),Vector3(0.04,0.12,0.04),membrane,"",leg)
			legs.append(leg)

	func animate(delta: float, _chasing: bool = false) -> void:
		for i in arms.size():
			var side: float = -1.0 if i == 0 else 1.0
			# Hanging bats fold their wings; flying ones beat them.
			arms[i].rotation.z = side*(1.2 if resting else sin(life*28.0)*0.9)
		# Upside down, the flipped body is lifted by its height so the feet grip the
		# ceiling rather than hanging a body-length below it.
		model.rotation.x = PI if resting else 0.0
		model.position.y = height if resting else 0.0

	func _physics_process(delta: float) -> void:
		if not game.playing(): return
		delta = _engine_step(delta)
		if delta < 0.0: return
		life += delta
		hurt_flash = maxf(0,hurt_flash-delta)
		var distance: float = position.distance_to(game.player.position)
		if distance > 90 and not has_meta("persistent") and custom_name.is_empty(): queue_free(); return
		if not game.world.loaded_at(position): return
		if not weather_step(delta): return
		Bats.step(game,self,delta,Bats.rng_for(game.world))
		animate(delta)
		if hurt_flash > 0: _tint(Color("d8402f"),0.55)
		elif tinted: _tint(Color.WHITE,0.0)

# The flight and resting rules for one step of `delta` seconds.
static func step(game: Node3D, bat: Node3D, delta: float, rng: RandomNumberGenerator) -> void:
	var world: VoxelWorld = game.world
	# The source's `floor(y + 0.5) + 1` in node-centred coordinates is the cell
	# above the one the bat's feet are in, which is where it hangs from.
	var above := Vector3i(floori(bat.position.x),floori(bat.position.y)+1,floori(bat.position.z))
	if bat.resting:
		if not opaque_solid(world,above) or bat.position.distance_to(game.player.position) <= WAKE_RANGE:
			bat.resting = false
		else:
			bat.position.y = float(above.y)-HANG_BELOW
			bat.velocity = Vector3.ZERO
			if rng.randi_range(1,scale_chance(TURN_ODDS,delta)) == 1: bat.model.rotation.y = rng.randf()*TAU
			return
	var cell := Vector3i(bat.position.floor())
	var mid: Vector3 = bat.position+Vector3.UP*bat.height*0.5
	var target: Vector3i = bat.target
	if target == Vector3i.MAX or Nodes.solid(world.node_at(target)) or rng.randi_range(1,scale_chance(RETARGET_ODDS,delta)) == 1 or mid.distance_to(Vector3(target)) <= 2.0:
		target = pick_target(cell,rng)
	bat.target = target
	var d: Vector3 = Vector3(target)+Vector3(0.5,0.1,0.5)-bat.position
	bat.velocity.x = steer(bat.velocity.x,d.x,HORIZONTAL,delta)
	bat.velocity.y = steer(bat.velocity.y,d.y,VERTICAL,delta)
	bat.velocity.z = steer(bat.velocity.z,d.z,HORIZONTAL,delta)
	bat.velocity += bat.knock
	bat.knock = bat.knock.move_toward(Vector3.ZERO,delta*12)
	for axis in [0,2,1]:
		var next: Vector3 = bat.position
		next[axis] += bat.velocity[axis]*delta
		if not world.intersects(next,bat.width,bat.height): bat.position = next
		else: bat.velocity[axis] = 0.0
	if Vector2(bat.velocity.x,bat.velocity.z).length() > 0.05:
		bat.model.rotation.y = atan2(-bat.velocity.x,-bat.velocity.z)
	if rng.randi_range(1,scale_chance(REST_ODDS,delta)) == 1 and opaque_solid(world,above):
		bat.resting = true

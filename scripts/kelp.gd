class_name Kelp
extends RefCounted

# Mineclonia ITEMS/mcl_ocean/kelp.lua, GPL-3.0-or-later. Original GDScript using
# the source as a behaviour reference.
#
# Kelp is a **rooted, growing column**: one node represents the whole stalk, and
# its height lives in its metadata. The source's rules:
#
#   * Height is `floor(param2/16) + floor(param2 % 16 / 8)`, so a param2 step of
#     16 adds one to the height, and the top step doubles back to add the 16th
#     stem — hence `min(param2 + 16 - param2 % 16, 255)`.
#   * Age runs 0..24 (`MAX_AGE` 25, rolled to `MAX_AGE - 1`). Once the age
#     reaches 25 the kelp **stops growing** entirely.
#   * Growth chance per tick is `216 * 0.2 / (100 * 1200)`, which is the source's
#     own derivation from Minecraft's average of 2.16 growths per day.
#   * Kelp must stay submerged: if any cell of the stalk is no longer water, the
#     part above that cell is detached and dropped, and the age is rerolled.
#   * Digging a stalk drops one kelp item per unit of height.
#
# Voxey already had a decorative kelp node with no growth, no height and no
# drowning rule. This adds those, which is what makes kelp function.

const ITEM = VillageContent.KELP
const PLANT = VillageContent.KELP_PLANT
const DRIED = VillageContent.DRIED_KELP
const MIN_AGE = 0
const MAX_AGE = 25
# Source tick interval and growth probability.
const TICK = 0.2
const GROW_NUMERATOR = 216*TICK
const GROW_DENOMINATOR = 100*1200

static func is_kelp(id: int) -> bool: return id == PLANT

# `kelp_get_height`: the source's param2 encoding, which Voxey stores as a plain
# height alongside the node because it has no per-node param2 table.
static func height(world: VoxelWorld, p: Vector3i) -> int:
	var state: Dictionary = world.block_states.get(VoxelWorld.station_key(p),{})
	return maxi(1,int(state.get("kelp_height",1)))

static func set_height(world: VoxelWorld, p: Vector3i, value: int) -> void:
	var key: String = VoxelWorld.station_key(p)
	if not world.block_states.has(key): world.block_states[key] = {}
	world.block_states[key]["kelp_height"] = clampi(value,1,16)

static func age(world: VoxelWorld, p: Vector3i) -> int:
	var state: Dictionary = world.block_states.get(VoxelWorld.station_key(p),{})
	return int(state.get("kelp_age",-1))

static func set_age(world: VoxelWorld, p: Vector3i, value: int) -> void:
	var key: String = VoxelWorld.station_key(p)
	if not world.block_states.has(key): world.block_states[key] = {}
	world.block_states[key]["kelp_age"] = value

# `is_age_growable`: kelp stops growing once it reaches the maximum age.
static func growable(age_value: int) -> bool: return age_value >= MIN_AGE and age_value < MAX_AGE

# The next height, capped so the sixteenth stem is the tallest.
static func next_height(current: int) -> int: return mini(current+1,16)

# Every cell of the stalk must still be water, or the stalk is overgrown.
static func submerged(world: VoxelWorld, p: Vector3i) -> bool:
	var h: int = height(world,p)
	for i in range(1,h+1):
		var at: Vector3i = p+Vector3i(0,i,0)
		# The stalk's own cells may hold kelp; anything else must be water.
		if world.node_at(at) == PLANT: continue
		if not Fluids.water(world.node_at(at)): return false
	return Fluids.water(world.node_at(p+Vector3i(0,h+1,0)))

# --- simulation --------------------------------------------------------------

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("kelp"): return
	var tracked: Dictionary = world.get_meta("kelp")
	var clock: float = float(tracked.get("clock",0.0))+delta
	if clock < TICK:
		tracked["clock"] = clock
		world.set_meta("kelp",tracked)
		return
	tracked["clock"] = 0.0
	var rng: RandomNumberGenerator = Corals._rng(world)
	for key in tracked.keys():
		if not key is Vector3i: continue
		var p: Vector3i = key
		if world.node_at(p) != PLANT: tracked.erase(p); continue
		# A stalk that is no longer submerged drops its overgrown part.
		if not submerged(world,p):
			var lost: int = height(world,p)
			for i in range(1,lost+1):
				var at: Vector3i = p+Vector3i(0,i,0)
				if world.node_at(at) == PLANT: world.set_node(at,Nodes.AIR)
			world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,ITEM,lost)
			set_age(world,p,roll_age(rng))
			continue
		var current_age: int = age(world,p)
		if current_age < 0:
			current_age = roll_age(rng)
			set_age(world,p,current_age)
		if not growable(current_age): continue
		# Source probability per tick.
		if rng.randf() > float(GROW_NUMERATOR)/float(GROW_DENOMINATOR): continue
		set_age(world,p,current_age+1)
		var h: int = height(world,p)
		if h >= 16: continue
		set_height(world,p,next_height(h))
	world.set_meta("kelp",tracked)

# `roll_init_age`: between MIN_AGE and MAX_AGE-1.
static func roll_age(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(MIN_AGE,MAX_AGE-1)

static func _tracked(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("kelp"): world.set_meta("kelp",{})
	return world.get_meta("kelp")

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if not is_kelp(id): return
	var tracked: Dictionary = _tracked(world)
	tracked[p] = true
	world.set_meta("kelp",tracked)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	var tracked: Dictionary = _tracked(world)
	for p in tracked.keys():
		if p is Vector3i and Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == column: tracked.erase(p)
	world.set_meta("kelp",tracked)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("kelp"): world.set_meta("kelp",{})

# --- placement and digging ---------------------------------------------------

# Kelp must be placed in water on a supported surface, as the source requires.
static func can_place(world: VoxelWorld, at: Vector3i) -> bool:
	if not Fluids.water(world.node_at(at)): return false
	return Seagrass.SURFACES.has(world.node_at(at-Vector3i.UP))

static func place(game: Node3D, target: Dictionary, held: int) -> bool:
	if held != ITEM or target.is_empty(): return false
	var world: VoxelWorld = game.world
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	if not can_place(world,at):
		game.toast("Kelp must be placed in water on dirt, sand, gravel or prismarine.")
		return true
	if not world.set_node(at,PLANT): return true
	set_height(world,at,1)
	set_age(world,at,roll_age(Corals._rng(world)))
	registered(world,at,PLANT)
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1
	game.api.emit_node_placed(at,PLANT)
	return true

# Digging a stalk drops one item per unit of height, which the source's
# `detach_drop` does by walking the column.
static func break_node(game: Node3D, p: Vector3i, id: int, _tool: int) -> bool:
	if not is_kelp(id): return false
	var world: VoxelWorld = game.world
	var h: int = height(world,p)
	# Digging restores the surface block the kelp grew from.
	world.set_node(p,world.node_at(p-Vector3i.UP))
	game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,ITEM,h)
	game.sound("dig")
	return true

class_name Striders
extends RefCounted

# `mobs_mc:strider` (ENTITIES/mobs_mc/strider.lua): the Nether's lava walker.
#
# * 20 health, `armor = {fleshy = 90, water_vulnerable = 90}`, 9 experience,
#   water-sensitive and fire-resistant, and it runs when struck. It stands on
#   lava (`floats_on_lava`) and sinks in nothing else.
# * Out of lava it is `_aground`, meaning cold: purple, shaking, at 0.66 of its
#   speed, and driven at 0.35 instead of 0.55 (ai_step, 390-423). While aground
#   it looks every half second for the nearest lava within ±8, ±2 with air above
#   and walks to it (`strider_go_to_lava`, 437-487).
# * Drops: two to five string, or one to three string and the saddle when
#   saddled (`equip_saddle`, 219-246).
# * Warped fungus breeds and grows it, and it follows a player holding warped
#   fungus or the warped-fungus stick. A saddle rides it; shears take the saddle
#   back; its rider steers with the warped-fungus stick, whose right-click starts
#   the same timed boost as the pig's (262-328).
# * A player riding a strider takes no lava damage (156-171).
# * `on_spawn` (112-141): an adult carries a zombified piglin holding a
#   warped-fungus stick one time in thirty, and otherwise a baby strider one time
#   in ten. Voxey records the pairing, as `SpiderClimb` does for its jockeys,
#   rather than simulating a mounted pair.
# * Spawning: weight 60 in the creature category, packs of one or two, on lava
#   with air above in every Nether biome (524-541).

const KIND = "strider"
const COLD_SPEED = 0.66
const DRIVE_HOT = 0.55
const DRIVE_COLD = 0.35
const LAVA_SEARCH = Vector3i(8,2,8)
const SEARCH_INTERVAL = 0.5
const JOCKEY_ODDS = 30
const BABY_RIDER_ODDS = 10
const FOLLOW_ITEMS = [CrimsonPlants.WARPED_FUNGUS,PigRiding.WARPED_FUNGUS_ON_A_STICK]

static func is_strider(kind: String) -> bool: return kind == KIND

# `_aground`: not standing on lava or in it.
static func lava_under(world: VoxelWorld, pos: Vector3) -> bool:
	return Fluids.lava(world.node_at(Vector3i((pos+Vector3.DOWN*0.05).floor()))) or Fluids.lava(world.node_at(Vector3i(pos.floor())))

static func aground(mob: Node3D) -> bool: return bool(mob.get_meta("strider_cold",false))

static func speed_factor(mob: Node3D) -> float: return COLD_SPEED if aground(mob) else 1.0
static func drive_bonus(mob: Node3D) -> float: return DRIVE_COLD if aground(mob) else DRIVE_HOT

# `floats_on_lava`: a strider that has sunk into a lava cell stands on its top.
static func float_on_lava(mob: Node3D) -> bool:
	var world: VoxelWorld = mob.game.world
	var cell := Vector3i(mob.position.floor())
	if not Fluids.lava(world.node_at(cell)): return false
	var top: int = cell.y
	while Fluids.lava(world.node_at(Vector3i(cell.x,top+1,cell.z))) and top < cell.y+4: top += 1
	mob.position.y = float(top+1)
	if mob.velocity.y < 0.0: mob.velocity.y = 0.0
	mob.grounded = true
	return true

# Per-frame bookkeeping: the cold flag and its look, and the lava search.
static func step(game: Node3D, mob: Node3D, delta: float) -> void:
	float_on_lava(mob)
	var cold: bool = not lava_under(game.world,mob.position)
	# The cold purple is drawn by `Creature.rest_tint`.
	if cold != aground(mob): mob.set_meta("strider_cold",cold)
	if cold and mob.model != null: mob.model.position.x = sin(mob.life*50.0)*0.02
	elif mob.model != null: mob.model.position.x = 0.0
	var clock: float = float(mob.get_meta("strider_search",0.0))-delta
	if clock > 0.0: mob.set_meta("strider_search",clock); return
	mob.set_meta("strider_search",SEARCH_INTERVAL)
	if not cold:
		if mob.has_meta("strider_lava"): mob.remove_meta("strider_lava")
		return
	var lava: Vector3i = nearest_lava(game.world,Vector3i(mob.position.floor()))
	if lava == Vector3i.MAX:
		if mob.has_meta("strider_lava"): mob.remove_meta("strider_lava")
	else: mob.set_meta("strider_lava",lava)

# The nearest lava by Manhattan distance with air above, as the source's sort does.
static func nearest_lava(world: VoxelWorld, here: Vector3i) -> Vector3i:
	var best := Vector3i.MAX
	var best_distance: int = 1 << 30
	for y in range(-LAVA_SEARCH.y,LAVA_SEARCH.y+1):
		for z in range(-LAVA_SEARCH.z,LAVA_SEARCH.z+1):
			for x in range(-LAVA_SEARCH.x,LAVA_SEARCH.x+1):
				var cell: Vector3i = here+Vector3i(x,y,z)
				if not Fluids.lava(world.node_at(cell)) or world.node_at(cell+Vector3i.UP) != Nodes.AIR: continue
				var d: int = absi(x)+absi(y)+absi(z)
				if d < best_distance: best = cell; best_distance = d
	return best

static func direction(mob: Node3D) -> Vector3:
	if not mob.has_meta("strider_lava"): return Vector3.INF
	var cell: Vector3i = mob.get_meta("strider_lava")
	var toward: Vector3 = (Vector3(cell)+Vector3(0.5,0,0.5)-mob.position)*Vector3(1,0,1)
	if toward.length() < 1.0: return Vector3.INF
	return toward.normalized()

# `mobs_mc.is_riding_strider`'s lava immunity.
static func rider_protected(game: Node3D) -> bool:
	var mount: Variant = game.survival.mount if game.survival != null else null
	return mount != null and is_instance_valid(mount) and is_strider(mount.kind)

static func follows(id: int) -> bool: return FOLLOW_ITEMS.has(id)

static func roll_drops(saddled: bool, rng: RandomNumberGenerator) -> Array:
	if saddled: return [[Nodes.STRING,rng.randi_range(1,3)]]
	return [[Nodes.STRING,rng.randi_range(2,5)]]

# `on_spawn`: the one in thirty zombified-piglin rider, else one in ten baby.
static func spawn_rider(game: Node3D, mob: Node3D, rng: RandomNumberGenerator) -> Node3D:
	if mob.growth_remaining > 0: return null
	if rng.randi_range(1,JOCKEY_ODDS) == 1:
		var rider: Node3D = game.spawn_creature("zombified_piglin",mob.position+Vector3.UP*1.7)
		if rider != null:
			rider.set_meta("jockey",mob.get_instance_id()); mob.set_meta("jockey",rider.get_instance_id())
			rider.set_meta("wield",PigRiding.WARPED_FUNGUS_ON_A_STICK)
		return rider
	if rng.randi_range(1,BABY_RIDER_ODDS) == 1:
		var baby: Node3D = game.spawn_creature(KIND,mob.position+Vector3.UP*1.7)
		if baby != null:
			baby.growth_remaining = Farming.GROW_TIME; Farming.resize(baby)
			baby.set_meta("jockey",mob.get_instance_id()); mob.set_meta("jockey",baby.get_instance_id())
		return baby
	return null

static func spawn_pack(game: Node3D, near: Vector3, rng: RandomNumberGenerator) -> Array:
	var made: Array = []
	var size: int = rng.randi_range(int(NetherSpawns.STRIDER[2]),int(NetherSpawns.STRIDER[3]))
	for i in size:
		var cell: Vector3i = NetherSpawns.strider_cell(game.world,near,rng)
		if cell == Vector3i.MAX: continue
		var mob: Node3D = game.spawn_creature(KIND,Vector3(cell)+Vector3(0.5,0.01,0.5))
		if mob == null: continue
		Farming.remember(mob)
		made.append(mob)
		spawn_rider(game,mob,rng)
	return made

static func build(mob: Node3D) -> void:
	var skin := Color("a8433a")
	var dark := Color("6e2723")
	mob._box(Vector3(0,1.25,0),Vector3(0.9,0.8,0.9),skin,"skin")
	# The hair-like filaments along its top and sides.
	for i in 6:
		var angle: float = TAU*float(i)/6.0
		mob._box(Vector3(sin(angle)*0.38,1.75,cos(angle)*0.38),Vector3(0.06,0.34,0.06),Color("e6c48a"),"")
	mob.head = mob._joint(Vector3(0,1.25,-0.45),"Head")
	for side in [-1,1]:
		mob._box(Vector3(side*0.2,0.18,-0.01),Vector3(0.18,0.08,0.02),Color("f6d45e"),"",mob.head)
		mob._box(Vector3(side*0.2,0.18,-0.015),Vector3(0.06,0.06,0.02),Color("2a1b12"),"",mob.head)
	mob._box(Vector3(0,-0.1,-0.01),Vector3(0.5,0.05,0.02),dark,"",mob.head)
	for side in [-1,1]:
		var leg: Node3D = mob._joint(Vector3(side*0.24,0.85,0),"Hip")
		mob._box(Vector3(0,-0.42,0),Vector3(0.18,0.85,0.18),dark,"skin",leg)
		mob.legs.append(leg)

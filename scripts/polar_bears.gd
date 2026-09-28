class_name PolarBears
extends RefCounted

# `mobs_mc:polar_bear` (ENTITIES/mobs_mc/polar_bear.lua): a neutral animal of the
# cold biomes that defends its cubs.
#
# * 30 health, 6 damage at reach 2, 1-3 experience, `_can_freeze = false`.
# * Drops (polar_bear.lua:38-55): raw cod 0-2 at 1 in 2 and raw salmon 0-2 at
#   1 in 4, both with common looting. A cub drops nothing, as `item_drop` skips a
#   child that is not a monster.
# * Targeting (254-260). It retaliates on the attacker, and when a **cub** is
#   struck it alerts every adult bear within its `view_range` of 20. An adult
#   also goes for the nearest player whenever a cub is within ±8 nodes
#   horizontally and ±4 vertically.
# * A cub runs from its attacker (`runaway = self.child`) and never attacks.
# * Close to its target an adult rears up: `pre_melee_attack` rears when the
#   target is within the box width plus three and the attack delay is under
#   half a second.
# * Spawning (275-321): the cold biomes on grass or snow blocks, packs of one or
#   two, and the second of a pack is always a cub.

const KIND = "polar_bear"
const VIEW_RANGE = 20.0
const CUB_BOX = Vector3(8,4,8)
const REAR_RANGE = 1.4+3.0
const COD_CHANCE = 2
const SALMON_CHANCE = 4
const WEIGHT = 1
const PACK_MAX = 2

static func is_bear(kind: String) -> bool: return kind == KIND
static func cub(mob: Node3D) -> bool: return mob.growth_remaining > 0

static func cub_nearby(game: Node3D, bear: Node3D) -> bool:
	for other in game.creatures.get_children():
		if other == bear or other.is_queued_for_deletion() or other.kind != KIND or not cub(other): continue
		var gap: Vector3 = (other.position-bear.position).abs()
		if gap.x <= CUB_BOX.x and gap.y <= CUB_BOX.y and gap.z <= CUB_BOX.z: return true
	return false

# Whether this bear hunts the player now: never as a cub, always once provoked,
# and otherwise only while guarding a cub.
static func aggressive(game: Node3D, bear: Node3D) -> bool:
	if cub(bear) or game.gamemode == "creative": return false
	if bear.provoked: return true
	return cub_nearby(game,bear)

# `child_to_adult_p` with `broadcast_attack`: a struck cub provokes every adult
# bear within twenty nodes; a struck adult alerts nobody.
static func alert(game: Node3D, victim: Node3D) -> int:
	if not cub(victim): return 0
	var count: int = 0
	for other in game.creatures.get_children():
		if other == victim or other.is_queued_for_deletion() or other.kind != KIND or cub(other): continue
		if other.position.distance_to(victim.position) > VIEW_RANGE: continue
		other.provoked = true
		other.last_seen = other.life
		count += 1
	return count

static func roll_drops(rng: RandomNumberGenerator, looting: int) -> Array:
	var out: Array = []
	for entry in [[VillageContent.RAW_COD,COD_CHANCE],[VillageContent.RAW_SALMON,SALMON_CHANCE]]:
		var count: int = UndeadVariants.roll_entry(rng,1.0/float(entry[1]),0,2,looting,true)
		if count > 0: out.append([entry[0],count])
	return out

# `pre_melee_attack`'s rearing test.
static func rearing(distance: float, chasing: bool, reach: float) -> bool:
	return chasing and distance > reach and distance < REAR_RANGE

# The source's spawn: a cold-biome grass or snow cell with room above.
static func spawn_allowed(world: VoxelWorld, cell: Vector3i) -> bool:
	if world.dimension != "overworld": return false
	if not Weather.snowy_biome(world.generator.biome(cell.x,cell.z)): return false
	var below: int = world.node_at(cell+Vector3i.DOWN)
	if below not in [Nodes.GRASS,Nodes.SNOW_BLOCK]: return false
	return not world.intersects(Vector3(cell)+Vector3(0.5,0.01,0.5),0.7,1.4)

static func spawn_pack(game: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> Array:
	var made: Array = []
	var size: int = rng.randi_range(1,PACK_MAX)
	for i in size:
		var at: Vector3 = pos+Vector3(rng.randf_range(-2,2),0,rng.randf_range(-2,2)) if i > 0 else pos
		var cell := Vector3i(at.floor())
		if i > 0 and not spawn_allowed(game.world,cell): at = pos; cell = Vector3i(pos.floor())
		var bear: Creature = game.spawn_creature(KIND,Vector3(cell)+Vector3(0.5,0.01,0.5))
		if bear == null: continue
		# The second of a pack is always a cub.
		if i == 1: make_cub(bear)
		made.append(bear)
	return made

static func make_cub(bear: Node3D) -> void:
	bear.growth_remaining = Farming.GROW_TIME
	CreatureArt.farm_age(bear,true)

# The cold biome's animal spawners weigh the bear at 1 against the rabbit's 10,
# so one cold-biome animal spawn in eleven tries for a bear.
const COLD_ANIMAL_WEIGHT = 10
static func spawn_share() -> float: return float(WEIGHT)/float(WEIGHT+COLD_ANIMAL_WEIGHT)

# A cub grows up after the source's twenty minutes, and an adult close to its
# target rears up on its hind legs.
static func tick(bear: Node3D, delta: float, chasing: bool, distance: float) -> void:
	if bear.growth_remaining > 0:
		bear.growth_remaining = maxf(0.0,bear.growth_remaining-delta)
		if bear.growth_remaining == 0.0:
			if bear.game.world.intersects(bear.position,bear.width,bear.height): bear.growth_remaining = 0.01
			else: CreatureArt.farm_age(bear,false)
	var rear: bool = not cub(bear) and rearing(distance,chasing,bear.melee_reach())
	bear.model.rotation.x = move_toward(bear.model.rotation.x,1.1 if rear else 0.0,delta*4.0)

static func build(bear: Node3D) -> void:
	var fur := Color("eeeae0")
	var shade := Color("d6d1c4")
	bear._box(Vector3(0,0.8,0.05),Vector3(0.95,0.8,1.5),fur,"fur")
	bear._box(Vector3(0,0.92,-0.62),Vector3(0.78,0.7,0.4),shade,"fur")
	bear.head = bear._joint(Vector3(0,1.0,-0.9),"Head")
	bear._box(Vector3(0,0.02,-0.12),Vector3(0.52,0.46,0.4),fur,"fur",bear.head)
	bear._box(Vector3(0,-0.08,-0.4),Vector3(0.3,0.24,0.2),shade,"fur",bear.head)
	bear._box(Vector3(0,-0.02,-0.51),Vector3(0.12,0.08,0.03),Color("24211e"),"",bear.head)
	for side in [-1,1]:
		bear._box(Vector3(side*0.19,0.28,-0.02),Vector3(0.13,0.12,0.08),shade,"fur",bear.head)
		bear._box(Vector3(side*0.13,0.1,-0.325),Vector3(0.06,0.06,0.02),Color("1b1916"),"",bear.head)
		for z in [-0.5,0.55]:
			var leg: Node3D = bear._joint(Vector3(side*0.3,0.5,z),"Hip")
			bear._box(Vector3(0,-0.25,0),Vector3(0.3,0.52,0.32),fur,"fur",leg)
			bear._box(Vector3(0,-0.49,-0.03),Vector3(0.32,0.06,0.36),shade,"",leg)
			bear.legs.append(leg)
	bear._box(Vector3(0,0.9,0.82),Vector3(0.2,0.2,0.14),shade,"fur")

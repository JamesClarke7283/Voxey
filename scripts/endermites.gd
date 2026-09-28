class_name Endermites
extends RefCounted

# `mobs_mc:endermite` (ENTITIES/mobs_mc/endermite.lua): a small hostile arthropod
# with eight health, three experience, two damage at reach one, no drops and
# `climb_powder_snow`. It has no natural spawner: its only source is the ender
# pearl, which leaves one at the thrower's old position one time in ten
# (ITEMS/mcl_throwing/register.lua:294-297). Endermen hunt endermites
# (ENTITIES/mobs_mc/enderman.lua:710-712), which Voxey expresses through the
# shared `hunts` list.

const KIND = "endermite"
const PEARL_ODDS = 10

static func is_endermite(kind: String) -> bool: return kind == KIND

# `math.random (10) == 1`, taken with the roll so the check can pin it.
static func pearl_spawns(roll: int) -> bool: return roll == 1

static func after_pearl(game: Node3D, origin: Vector3, rng: RandomNumberGenerator) -> Node3D:
	if not pearl_spawns(rng.randi_range(1,PEARL_ODDS)): return null
	return game.spawn_creature(KIND,origin)

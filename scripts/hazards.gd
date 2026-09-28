class_name Hazards
extends RefCounted

# Mineclonia PLAYER/mcl_player/init.lua (suffocation at :153-174, the fall-damage
# modifier at :177-213) and CORE/mcl_damage/init.lua (the damage-type flags).
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference.
#
# Two hazard rules the reference applies to every actor and Voxey was missing:
#
#  * **Suffocation (`in_wall`).** The source's slow step checks the actor's head
#    node - the feet node when swimming or in a one-high pose - and deals one
#    point per tick when it is a walkable full opaque cube that does not carry
#    `disable_suffocation`. A player buried by gravel or sealed by a piston
#    therefore takes steady damage rather than standing there indefinitely.
#  * **Fall-damage modifiers.** A trace from the landing point along the fall
#    velocity cancels the damage in water, an End portal, a cobweb, a vine or
#    powder snow, and the Jump Boost (`leaping`) effect subtracts one point per
#    level. Landing on a forgiving block therefore costs nothing.
#
# Both are consumed by `scripts/player.gd` and `scripts/creature.gd`.

# `mcl_player.register_globalstep_slow` runs on a `slow_gs_timer = 0.5` cadence.
const SUFFOCATION_INTERVAL = 0.5
# `mcl_util.deal_damage(player, 1, {type = "in_wall"})`.
const SUFFOCATION_DAMAGE = 1.0
# The trace step is `ceil(v_axis_max/5)+1` samples along the velocity direction.
const TRACE_DIVISOR = 5.0

# --- suffocation --------------------------------------------------------------

# `mcl_powder_snow` is the only node in the checkout carrying
# `disable_suffocation = 1`, and it is deliberately non-solid, so the group test
# resolves to the same answer as an explicit list here.
static func exempt(id: int) -> bool:
	return PowderSnow.is_powder_snow(id)

# The source's condition is `walkable == true`, a regular collision box, a
# regular node box, `opaque == 1` and no `disable_suffocation`. Voxey models the
# last two as `Nodes.solid` plus a fully opaque cube, which is what
# `RedstoneSensors.light_filter` reports as -1.
static func suffocates(id: int) -> bool:
	if id == Nodes.AIR or exempt(id): return false
	if not Nodes.solid(id) or Nodes.transparent(id): return false
	return RedstoneSensors.light_filter(id) < 0

# The cell the source samples: the head, or the feet while swimming or crouching
# into a one-high space, because a swimmer's head node sits above the body.
static func sample_cell(target: Node3D, low_pose: bool) -> Vector3i:
	return Vector3i((target.position+Vector3.UP*(0.1 if low_pose else 1.55)).floor())

# One slow-step tick. Returns whether suffocation damage was applied, so callers
# can report it and tests can assert the transition.
static func suffocate(world: VoxelWorld, target: Node3D, low_pose: bool) -> bool:
	var cell: Vector3i = sample_cell(target,low_pose)
	if not world.loaded_at(Vector3(cell)): return false
	var id: int = world.node_at(cell)
	if not suffocates(id): return false
	if target is VoxeyPlayer:
		(target as VoxeyPlayer).hurt(SUFFOCATION_DAMAGE,true,Vector3.INF,"in_wall")
	elif target is Creature:
		(target as Creature).hit(SUFFOCATION_DAMAGE,Vector3.INF)
	return true

# --- fall damage --------------------------------------------------------------

# The `mcl_core`/`mcl_portals` nodes whose item groups or names cancel a fall in
# the source's modifier. Water is handled separately because Voxey treats flowing
# and still water as `Fluids.water`.
static func forgiving(id: int) -> bool:
	if Fluids.water(id): return true
	if id == Nodes.END_PORTAL or id == Nodes.END_GATEWAY: return true
	if id == VillageContent.COBWEB: return true
	if id == Nodes.VINE or LushCaves.is_vine(id) or CrimsonPlants.is_vine(id): return true
	if PowderSnow.is_powder_snow(id): return true
	return false

# `mcl_player`'s modifier: walk the fall direction from the landing point in at
# least one sample per five nodes, cancelling the damage in a forgiving node, and
# subtract the leaping level from what remains.
static func fall_damage(world: VoxelWorld, landing: Vector3, velocity: Vector3, base: float, leaping: int = 0) -> float:
	if base <= 0: return 0.0
	var magnitude: float = maxf(maxf(absf(velocity.x),absf(velocity.y)),absf(velocity.z))
	if magnitude <= 0.0001: return maxf(0.0,base-leaping)
	var step: Vector3 = velocity/magnitude
	var at: Vector3 = landing
	for sample in (ceili(magnitude/TRACE_DIVISOR)+1):
		var cell := Vector3i(at.floor())
		if world.loaded_at(at) and forgiving(world.node_at(cell)): return 0.0
		at += step
	return maxf(0.0,base-float(leaping))

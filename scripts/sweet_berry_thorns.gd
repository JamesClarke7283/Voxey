class_name SweetBerryThorns
extends RefCounted

# Mineclonia ITEMS/mcl_farming/sweet_berry.lua (the `sweet_berry_thorny` group at
# :16-20 and the half-second `berry_damage_check` globalstep at :120-143) and
# ENTITIES/mcl_mobs/physics.lua (:1550-1567 `slowdown_nodes`), GPL-3.0-or-later.
# Original GDScript using the source as a behaviour reference. No new content ids:
# Voxey already has the four `SWEET_BERRIES_0..3` nodes and no contact rule for them.
#
# A grown sweet berry bush is hostile to touch, and the source splits that into two
# separate rules which are easy to conflate:
#
#   * **Thorns.** The source adds the `sweet_berry_thorny` group to every stage
#     *except the first* (`if i > 0 then groups.sweet_berry_thorny = 1 end`), so a
#     freshly planted bush is harmless and stage 1 is the first that bites.
#   * **Damage.** A globalstep runs every 0.5s over every connected player and every
#     `is_mob` entity and deals **0.5** `sweet_berry` damage to an actor that is in a
#     thorny bush *and is moving*. The velocity gate is the interesting half: standing
#     still inside a berry patch is safe, being pushed or running through one is not.
#   * **Slowdown.** Both of the source's slow tables — `mcl_mobs.slowdown_nodes` for
#     mobs and `mcl_serverplayer.movement_arresting_nodes` for players — list *all
#     four* stages at `x = 0.8, y = 0.75, z = 0.8`. Thorniness therefore gates the
#     damage only: even the harmless stage-0 bush drags an actor down.
#
# Where the slowdown is consumed differs from the source by necessity. The source
# damps an *existing* velocity: `post_motion_step` multiplies it by
# `pow(factor, dtime/0.05)` per axis, and the player's table is sent to the client,
# which applies it to its own motion. Voxey's actors rebuild their target velocity
# from a speed number every frame, so a per-frame velocity damp would simply be
# overwritten. `slow` therefore returns the source's per-axis tuple and the caller
# multiplies its speed line by the ground factor, which is the same rule expressed
# where Voxey actually reads it (see `PARENT WIRING`).
#
# Cell resolution: the source calls
# `core.find_node_near(pos, 0.4, {"group:sweet_berry_thorny"}, true)`. The 0.4 is
# passed straight to a function that takes an integer radius, and the LuaJIT build
# the game ships with truncates it to 0, so the lookup degenerates to the single
# node at the actor's own position. Voxey reads the node the feet are *in*
# (`Vector3i(position.floor())`), which is what every other Voxey contact rule
# (`PowderSnow.submerged`, `Hazards.sample_cell`, the player's cactus loop) means by
# "the cell the actor occupies".

# The four stages, in order. Stage 0 is a bush that has only just been planted.
const FIRST = VillageContent.SWEET_BERRIES_0
const COUNT = 4
# `if i > 0 then groups.sweet_berry_thorny = 1 end` — stage 0 is the one the source
# leaves out of the group, so it is the only harmless stage.
const THORNY_FROM = 1
# Source `if etime < 0.5 then return end` — the globalstep's own interval.
const INTERVAL = 0.5
# Source `mcl_util.deal_damage(obj, 0.5, {type = "sweet_berry"})`.
const DAMAGE = 0.5
# Source `if math.abs(v.x) < 0.1 and math.abs(v.y) < 0.1 and math.abs(v.z) < 0.1
# then return end`. Any single axis at or above it counts as moving.
const MOVING = 0.1
# The source's two slow tables agree on the berries at x = 0.8, y = 0.75, z = 0.8,
# for all four stages. A bush is never a full stop.
const SLOW = Vector3(0.8,0.75,0.8)
const FREE = Vector3.ONE
# The source's damage type, `{type = "sweet_berry"}`.
const CAUSE = "sweet_berry"

# The bush's stage, or -1 for anything that is not one of the four nodes.
static func stage(id: int) -> int:
	return id-FIRST if id >= FIRST and id < FIRST+COUNT else -1

static func is_bush(id: int) -> bool: return stage(id) >= 0

# Whether the source puts this node in the `sweet_berry_thorny` group, which is
# every stage above the first.
static func thorny(id: int) -> bool: return stage(id) >= THORNY_FROM

# The source's per-axis slowdown for an actor standing in this node, or free
# movement for anything that is not a sweet berry bush. All four stages are in both
# of the source's tables, so a stage-0 bush slows without hurting.
static func slow(id: int) -> Vector3: return SLOW if is_bush(id) else FREE

# The node an actor's feet occupy, which is the one node the source's
# `find_node_near(pos, 0.4, …, true)` ends up testing.
static func cell(target: Node3D) -> Vector3i:
	return Vector3i(target.position.floor())

# The source's velocity gate, which is what makes a berry patch safe to stand in.
static func is_moving(target: Node3D) -> bool:
	var v: Vector3 = target.velocity
	return absf(v.x) >= MOVING or absf(v.y) >= MOVING or absf(v.z) >= MOVING

# The damage half of `berry_damage_check`: the source's 0.5 to an actor that is
# inside a thorny bush and is moving. Reports whether the damage landed, so a caller
# can react to it. A creative player is immune, which the source's own player damage
# enforces; refusing here as well keeps the report honest rather than claiming a hit
# that changed nothing.
static func damage(game: Node3D, target: Node3D, id: int) -> bool:
	if target == null or target.is_queued_for_deletion(): return false
	# The type test comes before the velocity read, so a node that is neither an
	# actor nor a mob is refused rather than reported as an error.
	var actor: bool = target is VoxeyPlayer
	if not actor and not target is Creature: return false
	if not thorny(id) or not is_moving(target): return false
	if actor:
		if game.gamemode == "creative": return false
		(target as VoxeyPlayer).hurt(DAMAGE,false,Vector3.INF,CAUSE)
	else: (target as Creature).hit(DAMAGE,Vector3.INF)
	return true

# The per-step hook, which is the body of the source's `berry_damage_check`. Reads
# the node the actor's feet occupy and acts on it.
#
# `moving` is the caller's own motion signal, so a player can pass the movement
# intent it has already computed rather than a velocity the mover has not written
# yet; passing false skips the damage outright. `damage` re-tests the real velocity
# as well, so the flag never lets a stationary actor be hurt.
#
# Returns whether the hook did anything: the actor took damage, or it is standing in
# a bush that is dragging it down (which every stage does, thorny or not).
static func step(game: Node3D, target: Node3D, moving: bool) -> bool:
	if target == null or target.is_queued_for_deletion(): return false
	var id: int = game.world.node_at(cell(target))
	if not is_bush(id): return false
	var hurt: bool = moving and damage(game,target,id)
	return hurt or not slow(id).is_equal_approx(FREE)

# --- PARENT WIRING -----------------------------------------------------------
# Nothing is registered and no content id is added, so there is no registry append,
# no dispatcher branch, no update registration, no recipe, no metadata allow-list
# and no art branch for this module. The three edits below are the whole integration.
#
# 1. scripts/player.gd — the same 0.5s clock the source uses. Insert inside
#    `_physics_process`, in the `suffocation_clock >= SUFFOCATION_INTERVAL` block
#    (the head-node/suffocation branch, which is the one that already ticks every
#    half second), immediately after `Hazards.suffocate(...)`:
#
# 	# Source `register_globalstep`: a sweet berry bush deals half a point to a
# 	# moving player every half second, and drags down anyone standing in one.
# 	SweetBerryThorns.step(game,self,moving)
#
#    `moving` is the local computed earlier in the same function
#    (`var moving: bool = direction.length() > 0.1`), so no new state is needed.
#
# 2. scripts/creature.gd — `weather_step(delta)` runs every frame, but the source's
#    berry check runs every 0.5s, so it needs its own clock. Add the member beside
#    `water_clock`:
#
# 	var berry_clock: float = 0.0
#
#    and insert immediately after the `if not weather_step(delta): return` line in
#    `_physics_process`:
#
# 	# Source `register_globalstep`: half a point every half second to a moving mob.
# 	berry_clock += delta
# 	if berry_clock >= SweetBerryThorns.INTERVAL:
# 		berry_clock = 0.0
# 		SweetBerryThorns.step(game,self,direction.length() > 0.1)
#
# 3. The speed multiplier, which is where the source's slowdown is consumed.
#    scripts/player.gd, immediately after `speed *= PotionEffects.speed(self)`:
#
# 	# A sweet berry bush drags down whoever stands in it (the source's per-axis
# 	# 0.8; the ground axes are equal, so the speed line takes one of them).
# 	speed *= SweetBerryThorns.slow(game.world.node_at(Vector3i(position.floor()))).x
#
#    scripts/creature.gd:761, appended to the existing expression:
#
# 	var speed: float = data.speed*PotionEffects.speed(self)*(1.0-frozen_for/FREEZE_SECONDS)*SweetBerryThorns.slow(game.world.node_at(Vector3i(position.floor()))).x

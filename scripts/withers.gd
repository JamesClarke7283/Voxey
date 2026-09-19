class_name Withers
extends RefCounted

# Mineclonia ENTITIES/mobs_mc/wither.lua and
# ENTITIES/mcl_wither_spawning/init.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# The wither is the boss that gates beacons. Its summoning ritual is exact: a
# **three-wide T of soul sand** with a wither skeleton skull on each of the three
# upper cells. The source stores the seven required cells in a schematic and
# checks every one of them before consuming the blocks and spawning the boss.
#
# Reproduced from the source:
#
#   * **600 health**, scaled by difficulty — hard 1.0, normal 0.75, easy 0.5.
#   * **A ten-second invulnerable spawn phase**, during which it cannot be hurt.
#   * **Two phases.** At half health it gains armour, becomes immune to arrows,
#     and halves its firing rate.
#   * **A guaranteed nether star**, which is the beacon's missing ingredient.
#   * **Wither skeletons** are released as it descends.
#
# Closing this closes the beacon's survival route, which was the last recorded
# dependency of that system.

const ID = "wither"
# Source `hp_max`.
const HEALTH = 600.0
# Source `_spawning = 10`.
const SPAWN_INVULNERABLE = 10.0
# Difficulty factors: hard 1.0, normal 0.75, easy 0.5.
const HEALTH_FACTOR = [0.5,0.75,1.0]
# The wither always drops its star.
const STAR_MIN = 1
const STAR_MAX = 1

static func is_wither(kind: String) -> bool: return kind == ID or kind == "wither_skeleton"
static func is_boss(kind: String) -> bool: return kind == ID

# The source's difficulty scaling, which uses the game's difficulty setting.
static func scaled_health(difficulty: int) -> float:
	return HEALTH*HEALTH_FACTOR[clampi(difficulty,0,2)]

# The summoning schematic: the source's own seven cells, in (x, y, z) offsets
# from the bottom-centre soul sand. The T runs along x, and the source also
# accepts the same shape rotated onto z.
const SCHEM_X = [
	{"pos":Vector3i(0,1,0),"group":"soul"},
	{"pos":Vector3i(0,2,0),"head":true},
	{"pos":Vector3i(1,0,0),"group":"soul"},
	{"pos":Vector3i(1,1,0),"group":"soul"},
	{"pos":Vector3i(1,2,0),"head":true},
	{"pos":Vector3i(2,1,0),"group":"soul"},
	{"pos":Vector3i(2,2,0),"head":true},
]
const SCHEM_Z = [
	{"pos":Vector3i(0,1,0),"group":"soul"},
	{"pos":Vector3i(0,2,0),"head":true},
	{"pos":Vector3i(0,0,1),"group":"soul"},
	{"pos":Vector3i(0,1,1),"group":"soul"},
	{"pos":Vector3i(0,2,1),"head":true},
	{"pos":Vector3i(0,1,2),"group":"soul"},
	{"pos":Vector3i(0,2,2),"head":true},
]

# The blocks that count as the source's `soul_block` group.
static func soul_block(id: int) -> bool:
	return id == Nodes.SOUL_SAND or id == Campfires.SOUL_SOIL

static func is_skull(id: int) -> bool:
	return id == Heads.FLOOR+4

# `check_schem`: every cell of one orientation must match.
static func matches(world: VoxelWorld, base: Vector3i, schematic: Array) -> bool:
	for cell in schematic:
		var at: Vector3i = base+Vector3i(cell.pos)
		if cell.get("head",false):
			if not is_skull(world.node_at(at)): return false
		elif not soul_block(world.node_at(at)): return false
	return true

# `wither_spawn`: try both orientations and report the one that matched, if any.
static func ritual_base(world: VoxelWorld, placed_above: Vector3i) -> Vector3i:
	# The source offsets from the placed skull's cell, two blocks down.
	for schematic in [SCHEM_X,SCHEM_Z]:
		var anchor: Vector3i = placed_above
		# The placed head sits at (0,2,0) in the schematic, so the bottom-left
		# soul sand is two below it.
		var base: Vector3i = anchor-Vector3i(0,2,0)
		if matches(world,base,schematic): return base
	return Vector3i(0,2147483647,0)

# Whether a ritual would succeed at this spot, without changing the world.
static func ritual_ready(world: VoxelWorld, placed_above: Vector3i) -> bool:
	return ritual_base(world,placed_above).y != 2147483647

# `wither_spawn`: consume the seven blocks and place the boss one above the T.
static func summon(game: Node3D, placed_above: Vector3i) -> Creature:
	var world: VoxelWorld = game.world
	var base: Vector3i = ritual_base(world,placed_above)
	if base.y == 2147483647: return null
	# The source removes every schematic block, not just the shell.
	for schematic in [SCHEM_X,SCHEM_Z]:
		if not matches(world,base,schematic): continue
		for cell in schematic: world.set_node(base+Vector3i(cell.pos),Nodes.AIR)
		break
	var spawn_at: Vector3 = Vector3(base)+Vector3(0.5,1.0,0.5)
	var boss: Creature = game.spawn_creature(ID,spawn_at)
	if boss == null: return null
	# The source's invulnerable opening phase, during which the boss cannot be
	# hurt while it rises.
	boss.spawn_invulnerable = SPAWN_INVULNERABLE
	boss.health = scaled_health(game.difficulty)
	game.sound_at("wither",spawn_at,1.0)
	game.puff(spawn_at,Color("3a3a3a"),40,3.0)
	game.achievements.award("withering_heights")
	return boss

# A wither skull placed on a soul block attempts the ritual, which is the
# source's item override.
static func try_place_skull(game: Node3D, at: Vector3i, held: int) -> bool:
	if held != Heads.FLOOR+4: return false
	var world: VoxelWorld = game.world
	if not soul_block(world.node_at(at-Vector3i.UP)): return false
	# The skull is placed first, as the source's override defers the check.
	if not world.set_node(at,held): return true
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1
	# `core.after(0, ...)`: the ritual is evaluated once the block is in place.
	if ritual_ready(world,at): summon(game,at)
	return true

# --- phases ------------------------------------------------------------------

# The source switches to its armoured phase at half health, after which it is
# immune to arrows and fires half as often.
static func phase_for(health: float, max_health: float) -> int:
	return 1 if health < max_health/2.0 else 0

# A boss in its opening phase ignores damage entirely.
static func invulnerable(creature: Creature) -> bool:
	return creature.spawn_invulnerable > 0.0

# The star is guaranteed, which is what makes the beacon reachable.
static func roll_star(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(STAR_MIN,STAR_MAX)

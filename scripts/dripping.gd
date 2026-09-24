class_name Dripping
extends RefCounted

# Mineclonia ENTITIES/mcl_dripping/init.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# Dripping is what makes a cave *feel* wet. The source runs one ABM per liquid and
# the rule is three cells deep:
#
#     air below, an opaque node in the middle, that liquid directly above
#
# So a water source with stone under it drips; a hole under the stone stops it,
# because the cell below the stone must be air. That is why a drip appears on the
# roof of a *corridor* and not inside solid rock, and why a drip stops when the
# player digs the block under it.
#
# The two liquids differ in the source's own numbers:
#
#   * **water** — any opaque node or leaves, interval 60.3, chance 1 in 10
#   * **lava**  — opaque nodes only, interval 110.1, chance 1 in 10, and it lights
#     the area
#
# Voxey had dripstone generation, so caves had *shape*, but nothing dripped. A cave
# was silent and dry: the particles and the drip sounds the source provides were
# absent.

# Source intervals, in seconds, and the one-in-ten chance each.
const WATER_INTERVAL = 60.3
const LAVA_INTERVAL = 110.1
const CHANCE = 10
# How long a drip particle lives and how fast it falls, which is a short bead rather
# than a stream.
const DROP_LIFE = 0.9
const DROP_FALL = 2.2

# The liquids that can drip, as node sets. Water drips through leaves as well as
# opaque rock; lava only from opaque rock, which is the source's distinction.
static func liquid_above(world: VoxelWorld, p: Vector3i) -> int:
	var above: int = world.node_at(p+Vector3i.UP)
	if Fluids.water(above): return Nodes.WATER
	if Fluids.lava(above): return Nodes.LAVA
	return 0

# Whether a drip forms at `p`, which is the source's `position_eligible_p`: the cell
# below is air, `p` itself supports a drip, and the liquid is directly above `p`.
static func eligible(world: VoxelWorld, p: Vector3i) -> bool:
	if not world.loaded_at(Vector3(p)): return false
	var liquid: int = liquid_above(world,p)
	if liquid == 0: return false
	# The drip needs open space to fall into.
	if world.node_at(p-Vector3i.UP) != Nodes.AIR: return false
	var here: int = world.node_at(p)
	if here == Nodes.AIR: return false
	if liquid == Nodes.LAVA: return Pasture.opaque(here)
	# Water drips through leaves too, which is the source's `group:leaves`.
	return Pasture.opaque(here) or WoodTypes.is_leaves(here)

# One drip's worth of particles and sound at a cell, which is the source's
# `make_drop`. The sound is quiet and positional, so a drip is heard before it is
# seen — which is the whole point of the effect in a dark cave.
static func emit(game: Node3D, p: Vector3i, liquid: int) -> bool:
	var at: Vector3 = Vector3(p)-Vector3(0,0.5,0)+Vector3(0.5,0,0.5)
	var color: Color = Color("5b8fd6") if liquid == Nodes.WATER else Color("e8722a")
	game.puff(at,color,3,DROP_FALL)
	game.sound_at("drip",at,0.4)
	return true

# --- the tracked-cell driver -------------------------------------------------

# The source runs this as an ABM over every opaque node with a liquid neighbour, so
# a drip is a *world* property rather than something attached to one block. Voxey
# tracks the candidate cells the way the crop system does: a cell is registered when
# the node that could carry a drip changes, and the driver walks those cells on the
# source's own interval.
static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("dripping"):
		world.set_meta("dripping",{"cells":{},"clocks":{"water":0.0,"lava":0.0},"rng":RandomNumberGenerator.new()})
	return world.get_meta("dripping")

# A node changed at `p`. Any cell whose three-cell window includes `p` may have
# gained or lost a drip, so the cell itself, the one above and the one below are all
# re-examined. That is what makes a dig under a drip stop it.
static func changed(world: VoxelWorld, p: Vector3i, old_id: int, new_id: int) -> void:
	var state: Dictionary = runtime(world)
	# A cell is eligible only under a liquid, so with no liquid above any of the
	# three and none of them indexed, nothing changes.
	var cells: Dictionary = state.cells
	if not cells.has(p) and not cells.has(p+Vector3i.UP) and not cells.has(p+Vector3i.DOWN) and not Fluids.liquid(world.node_at(p)) and not Fluids.liquid(world.node_at(p+Vector3i.UP)) and not Fluids.liquid(world.node_at(p+Vector3i.UP*2)): return
	for offset in [Vector3i.ZERO,Vector3i.UP,Vector3i.DOWN]:
		var cell: Vector3i = p+offset
		if eligible(world,cell): state.cells[cell] = liquid_above(world,cell)
		else: state.cells.erase(cell)

# The source's two liquids run on their own ABM, so they keep separate clocks: a
# water drip fires every 60.3 seconds and a lava drip every 110.1, independently.
static func update(world: VoxelWorld, delta: float) -> void:
	if delta <= 0 or not is_finite(delta): return
	var state: Dictionary = runtime(world)
	var cells: Dictionary = state.cells
	if cells.is_empty(): return
	var game: Node3D = world.get_parent()
	var rng: RandomNumberGenerator = state.rng
	var clocks: Dictionary = state.clocks
	for pair in [[Nodes.WATER,WATER_INTERVAL],[Nodes.LAVA,LAVA_INTERVAL]]:
		var liquid: int = pair[0]
		var key: String = "water" if liquid == Nodes.WATER else "lava"
		clocks[key] = float(clocks[key])+delta
		if clocks[key] < float(pair[1]): continue
		clocks[key] = fmod(float(clocks[key]),float(pair[1]))
		for cell in cells.keys():
			if int(cells[cell]) != liquid: continue
			if not world.loaded_at(Vector3(cell)): continue
			if not eligible(world,cell):
				# The world moved on while the cell was tracked.
				cells.erase(cell); continue
			# The source's one-in-ten chance, so a drip is occasional rather than
			# constant even where the geometry allows one.
			if rng.randi_range(1,CHANCE) != 1: continue
			emit(game,cell,liquid)

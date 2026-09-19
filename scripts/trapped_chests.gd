class_name TrappedChests
extends RefCounted

# Mineclonia ITEMS/mcl_chests/init.lua (`trapped_chest_small`), GPL-3.0-or-later.
# Original GDScript using the source as a behaviour reference.
#
# A trapped chest is a chest that **emits a redstone signal to its neighbours
# while it is open**. That is the whole difference from an ordinary chest, and it
# is what makes the jungle temple's treasure a trap: the chest sits behind
# dispensers, so opening it fires them.
#
# The source registers four nodes — small, small_open, and the two halves of a
# large chest — and swaps between them as the chest opens and closes. Voxey uses
# one node and tracks the open state in the block's saved state, which is the
# same mechanism other Voxey stations use.
#
# The source's own comparator rule also reads a trapped chest's fullness, which
# Voxey's `RedstoneCircuit.container_signal` already does for any container, so
# only the neighbour signal is new here.

# Mineclonia `mcl_chests:trapped_chest_small`. It sits beside the barrel in the
# container block range, after the composter.
const ID = 1247

# Source sends 15 to adjacent blocks while open, which is a full-strength signal.
const SIGNAL = 15

static func is_trapped(id: int) -> bool: return id == ID

# A constant, so `VillageContent.DATA` can reference it without a cyclic
# dependency on a static function.
const DATA = {1247: {"name":"Trapped chest","block":true,"color":"a2622f","hardness":2.5,"tool":0,"chest":true}}

# --- open state --------------------------------------------------------------

# Whether a trapped chest is currently open, which drives its signal.
static func is_open(world: VoxelWorld, p: Vector3i) -> bool:
	return bool(world.block_states.get(VoxelWorld.station_key(p),{}).get("trapped_open",false))

# The source swaps the node when a chest is opened and back when it is closed.
# Voxey records the state instead, so a save keeps a chest's signal state.
static func set_open(world: VoxelWorld, p: Vector3i, open_value: bool) -> void:
	if not is_trapped(world.node_at(p)): return
	var key: String = VoxelWorld.station_key(p)
	var state: Dictionary = world.block_states.get(key,{})
	state["trapped_open"] = open_value
	world.block_states[key] = state

# --- redstone ----------------------------------------------------------------

# The signal a trapped chest reports to a neighbour: full strength while open,
# and nothing while closed. This is the source's whole purpose for the block.
static func output(world: VoxelWorld, p: Vector3i) -> int:
	return SIGNAL if is_open(world,p) else 0

# --- interaction -------------------------------------------------------------

# Open the chest, marking it open for as long as the inventory screen is up. The
# game closes it again through `closed()`, which the screen's exit calls.
static func open(game: Node3D, p: Vector3i) -> void:
	set_open(game.world,p,true)
	# The circuit must re-read the node, or its neighbours keep the old level. The
	# call goes through `game.world.circuits` rather than a typed `VoxelWorld`
	# parameter, because naming `RedstoneCircuit` here would be a static cycle:
	# the circuit already depends on this module to read a chest's signal.
	game.world.circuits.refresh(p)
	game.open_inventory("chest",p)

# Called when the chest's screen closes, which is the source's chest-close hook.
static func closed(game: Node3D) -> void:
	# `get_meta` must be guarded before `remove_meta`: removing a key that was
	# never set is an error, and every inventory close calls this path.
	if not game.has_meta("open_trapped_chest"): return
	var at: Variant = game.get_meta("open_trapped_chest")
	if not at is Vector3i: return
	game.remove_meta("open_trapped_chest")
	set_open(game.world,at,false)
	game.world.circuits.refresh(at)

# Remember which chest is open, so the close path can find it again.
static func remember(game: Node3D, p: Vector3i) -> void:
	game.set_meta("open_trapped_chest",p)

# --- recipes -----------------------------------------------------------------

static func recipes(inv: Inventory) -> void:
	# The reference's own recipe, from `mcl_temp_helper_recipes`: shapeless iron
	# ingot, stick, any wood and a chest. It is the source's, not an invention —
	# the reference adds it precisely because a trapped chest is otherwise
	# unreachable, since Voxey has no tripwire hook.
	inv._shapeless("Trapped chest",ID,1,[Nodes.IRON,Nodes.STICK,Nodes.PLANKS,Nodes.CHEST])

# --- art ---------------------------------------------------------------------

# A chest with the source's red-tinted latch, which is how a trapped chest is
# told apart from an ordinary one.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if not is_trapped(id): return Color(0,0,0,0)
	var wood := Color("a2622f")
	# The banded lid, the latch, and the trap's own red mark.
	if y == 5 or y == 6: return wood.darkened(0.35)
	if x in [6,7] and y in range(6,10): return Color("b8322c")
	if x in [0,15] or y == 0 or y == 15: return wood.darkened(0.28)
	return wood.darkened(0.08*float((x+y*3)%3))

class_name Screwdriver
extends RefCounted

# Mineclonia ITEMS/screwdriver/init.lua, GPL-3.0-or-later. Original GDScript using the
# source as a behaviour reference.
#
# The screwdriver is the source's node-rotation tool: use rotates a node on its face
# axis, place rotates it on its other axis. Every family that has an orientation stores
# it differently, so this module dispatches to the owning module's own state encoding.
#
# Two modes, as the source names them:
#   * `ROTATE_FACE` — the use action. For a stair this turns the facing; for a three-way
#     node it steps along its three axis-aligned states.
#   * `ROTATE_AXIS` — the place action. For a stair this only flips a top slab to a
#     bottom one (the source's `rotate_3way` axis move); for a three-way node it steps
#     through its axes.
#
# The source wears the tool one use per rotation and refuses a rotation the node
# disallows (`screwdriver.disallow`, `on_rotate = false`).

const ID = 279
const USES = 200
const ROTATE_FACE = 1
const ROTATE_AXIS = 2

static func is_screwdriver(id: int) -> bool: return id == ID

# A node this tool can turn: the families with a stored orientation.
static func rotatable(id: int) -> bool:
	return BuildingShapes.is_shape(id) or Doors.is_door(id) or Trapdoors.is_trapdoor(id) \
		or Barriers.is_barrier(id) or Signs.is_sign(id) or Rails.is_rail(id) \
		or WoodTypes.is_log(id) or id == Nodes.PISTON or id == Nodes.STICKY_PISTON \
		or id == Nodes.DISPENSER or id == Nodes.DROPPER or id == Nodes.OBSERVER \
		or id == Nodes.HOPPER or id == Nodes.REPEATER or id == Nodes.COMPARATOR \
		or id == Nodes.CHEST or id == Nodes.FURNACE

# The rotated id for `id`, or 0 when the family has no rotation for this mode. The
# caller replaces the node in place.
static func rotate(id: int, mode: int, toward: int = 1) -> int:
	if BuildingShapes.is_shape(id) and BuildingShapes.stair(id):
		var facing: int = BuildingShapes.facing(id)
		var inverted: bool = BuildingShapes.variant(id) >= 7
		if mode == ROTATE_FACE: return BuildingShapes.family(id)+3+posmod(facing+toward,4)+(4 if inverted else 0)
		if mode == ROTATE_AXIS: return BuildingShapes.family(id)+3+facing+(0 if inverted else 4)
		return 0
	if Doors.is_door(id):
		return Doors.state_id(Doors.item(id),posmod(Doors.facing(id)+toward,4),Doors.mirrored(id),Doors.opened(id),Doors.upper(id))
	if Trapdoors.is_trapdoor(id):
		return Trapdoors.state_id(Trapdoors.item(id),posmod(Trapdoors.facing(id)+toward,4),Trapdoors.upper(id),Trapdoors.open(id))
	if Signs.is_sign(id):
		var kind_base: int = absi(Signs.base(id))  # base returns 0 for a non-sign
		if Signs.wall(id): return kind_base+posmod(Signs.facing(id)+toward,4)
		return kind_base+4+posmod(Signs.facing(id)+toward,16)
	if Barriers.is_gate(id):
		return Barriers.family(id)+1+posmod(Barriers.facing(id)+toward,4)+(4 if Barriers.open(id) else 0)
	if WoodTypes.is_log(id) and not WoodTypes.stripped(id):
		# A log turns through its three axis-aligned orientations.
		var axis: int = WoodTypes.axis(id)
		var next: int = (axis+1)%3 if mode == ROTATE_FACE else (axis+2)%3
		var kind: int = WoodTypes.species(id)
		return WoodTypes.base(kind)+(4 if next == 1 else (8 if next == 0 else 9))
	if id in [Nodes.REPEATER,Nodes.COMPARATOR]:
		return id
	return 0

# The source's `screwdriver.handler`: turn the node `p`, wear the tool one use.
static func turn(game: Node3D, p: Vector3i, mode: int) -> bool:
	var id: int = game.world.node_at(p)
	if not rotatable(id): return false
	var next: int = rotate(id,mode)
	if next == 0 or next == id: return false
	if not game.world.set_node(p,next): return false
	game.api.emit_node_placed(p,next)
	if game.gamemode != "creative": game.inventory.damage_tool()
	game.sound("dig")
	return true

static func recipes(inv: Inventory) -> void:
	inv._recipe("Screwdriver",ID,1,[Nodes.IRON,0,0,Nodes.STICK,0,0,0,0,0],1,"table")

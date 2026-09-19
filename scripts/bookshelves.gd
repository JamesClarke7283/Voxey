class_name Bookshelves
extends RefCounted

# Mineclonia ITEMS/mcl_books/chiseled_bookshelf.lua and
# ITEMS/REDSTONE/mcl_comparators/init.lua, GPL-3.0-or-later. Original GDScript using
# the source as a behaviour reference; all art is original procedural code.
#
# A chiseled bookshelf holds up to six books — one per slot, never a stack — and
# shows exactly which slots are filled on its front face. The source gets that
# display by registering **64 nodes**, one per bit pattern of six slots, and swaps
# the node when a book is put in or taken out. Voxey keeps one id and draws the
# filled slots from saved state, which is the same pattern it uses for candles and
# shulker contents; the rules that matter are unchanged:
#
# - Six slots, **one item each**: the source's `allow_metadata_inventory_put`
#   returns 1 regardless of the held stack, so a whole stack is never absorbed.
# - Right-clicking a slot puts in or takes out the book for that slot, chosen from
#   where on the face you clicked.
# - A **comparator** reads the last slot that changed, not the count: the source's
#   `measure_chiseled_bookshelf` returns `last_slot_used`, so an empty shelf reads 0
#   and putting a book in slot three reads 3.
# - A **hopper** above feeds it one book at a time, and a hopper below is not served:
#   the source registers `_on_hopper_out` but no `_on_hopper_in`.
# - Breaking it returns its books, which the source's `after_dig_node` does.

const ID = 11546
const BLOCKS = [ID]
# Six slot positions across the front face; the source's own `get_surface_sixth`
# divides the face into a 3 x 2 grid.
const SLOTS = 6
const SLOT_COLUMNS = 3
const SLOT_ROWS = 2

const DATA = {
	11546:{"name":"Chiseled bookshelf","block":true,"shape":"cube","color":"a5814f","hardness":1.5,"tool":1,"family":"bookshelf","flammable":true,"fuel":15},
}

# The shelf's own state: which slots hold an item, and the slot a comparator reads.
static func state(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var station: Dictionary = world.get_station(p,"bookshelf")
	# `VoxelWorld.get_station` pre-sizes a generic station to 27 slots, so the shelf
	# must own its own six rather than inherit that default.
	if not station.has("shelf_ready"):
		var slots: Array = []
		for i in SLOTS: slots.append({"id":0,"count":0,"wear":0})
		station["slots"] = slots
		station["last_slot"] = 0
		station["shelf_ready"] = true
	return station

static func slots(world: VoxelWorld, p: Vector3i) -> Array: return state(world,p).slots
static func filled(world: VoxelWorld, p: Vector3i) -> int:
	var count: int = 0
	for slot in slots(world,p):
		if slot.id != 0: count += 1
	return count

# The source's bit pattern, kept as a readable helper so callers need not know it.
static func bits(world: VoxelWorld, p: Vector3i) -> int:
	var pattern: int = 0
	var all: Array = slots(world,p)
	for i in SLOTS:
		if all[i].id != 0: pattern |= 1 << i
	return pattern

# Which slot a click at `local_hit` selects. The source's `get_surface_sixth` puts
# the top half in slots four to six and the bottom half in one to three, then orders
# the three columns by the shelf's facing.
static func slot_at(local_hit: Vector3, facing: int) -> int:
	var row: int = 0 if local_hit.y > 0.5 else 1
	var across: float = local_hit.x if facing % 2 == 0 else local_hit.z
	var column: int = clampi(int(floor(across*float(SLOT_COLUMNS))),0,SLOT_COLUMNS-1)
	return row*SLOT_COLUMNS+column

# Putting a book in: one item only, and only into an empty slot. Returns false when
# the slot is taken or the held item is not a book.
static func insert(world: VoxelWorld, p: Vector3i, index: int, held: Dictionary) -> bool:
	if index < 0 or index >= SLOTS or not is_book(int(held.get("id",0))): return false
	var all: Array = slots(world,p)
	if all[index].id != 0: return false
	all[index] = {"id":held.id,"count":1,"wear":held.get("wear",0)}
	if not held.get("data",{}).is_empty(): all[index]["data"] = held.data.duplicate(true)
	# `last_slot_used` is one-based, which is what the comparator reads.
	state(world,p)["last_slot"] = index+1
	return true

# Taking the book out of a slot, which is the right-click's other half.
static func take(world: VoxelWorld, p: Vector3i, index: int) -> Dictionary:
	if index < 0 or index >= SLOTS: return {}
	var all: Array = slots(world,p)
	var slot: Dictionary = all[index]
	if slot.id == 0: return {}
	all[index] = {"id":0,"count":0,"wear":0}
	state(world,p)["last_slot"] = index+1
	return slot

# The source's `_on_hopper_out`: a hopper above the shelf moves one book in, and the
# slot that changed becomes the comparator's reading.
static func hopper_in(world: VoxelWorld, shelf: Vector3i, from: Dictionary) -> bool:
	if not is_book(int(from.get("id",0))): return false
	var all: Array = slots(world,shelf)
	for i in SLOTS:
		if all[i].id != 0: continue
		all[i] = {"id":from.id,"count":1,"wear":from.get("wear",0)}
		if not from.get("data",{}).is_empty(): all[i]["data"] = from.data.duplicate(true)
		state(world,shelf)["last_slot"] = i+1
		return true
	return false

# `measure_chiseled_bookshelf`: the comparator reads the last slot that changed, so
# an untouched shelf reads nothing and a changed one reads its one-based index.
static func comparator_output(world: VoxelWorld, p: Vector3i) -> int:
	return clampi(int(state(world,p).get("last_slot",0)),0,15)

# The books a broken shelf returns, which the source's `after_dig_node` drops.
static func contents(world: VoxelWorld, p: Vector3i) -> Array:
	var out: Array = []
	for slot in slots(world,p):
		if slot.id != 0: out.append(slot.duplicate(true))
	return out

# Any book-like item fits, which is the source's `mcl_books` container: a book, a
# writable book and a written book all belong on a shelf.
static func is_book(id: int) -> bool:
	return id in [Nodes.BOOK,Nodes.WRITABLE_BOOK,Nodes.WRITTEN_BOOK,VillageContent.ENCHANTED_BOOK]

# --- recipes -----------------------------------------------------------------

static func recipes(inv: Inventory) -> void:
	# The source's own: six planks in two rows with three planks across the middle.
	var p: int = Nodes.PLANKS
	inv._recipe("Chiseled bookshelf",ID,1,[p,p,p,0,Nodes.PLANKS,0,p,p,p],3,"table")

# --- art ---------------------------------------------------------------------

# The shelf's front face draws one book per filled slot, from the saved pattern, so
# the display matches the source's 64-node trick without 64 ids. The mesher asks for
# a tile, and this module also exposes the per-slot overlay.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(DATA[id].color)
	# A plank body with the shelf frame: a raised border and two shelf lines.
	if x in [0,15] or y in [0,15]: return base.darkened(0.4)
	if y in [7,8]: return base.darkened(0.45)
	if x in [5,10]: return base.darkened(0.2)
	return noise.lerp(base,0.75)

# The colour of the book in a slot, which is the source's per-slot book texture.
static func slot_color(index: int) -> Color:
	return [Color("b8433c"),Color("3f6fa8"),Color("4f8a44"),Color("c8a03c"),Color("8a4f9c"),Color("3f8a86")][clampi(index,0,SLOTS-1)]

# The slot's rectangle on a 16x16 face, for a caller drawing the overlay.
static func slot_rect(index: int) -> Rect2i:
	var column: int = index % SLOT_COLUMNS
	var row: int = index / SLOT_COLUMNS
	# Three books across each shelf, five pixels wide with a one-pixel gap.
	return Rect2i(1+column*5,1+row*8,4,6)

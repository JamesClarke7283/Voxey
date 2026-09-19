class_name Seagrass
extends RefCounted

# Mineclonia ITEMS/mcl_ocean/seagrass.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# Seagrass is the ocean floor's ground cover. The source registers it as
# `plantlike_rooted` nodes — one per supported surface — so the node carries both
# the plant and the block it grew from:
#
#   * Seven surfaces are supported: dirt, sand, red sand, gravel, and the three
#     prismarine variants.
#   * Placement requires the cell **above** to be a water SOURCE, not merely
#     water. Placing it swaps the surface block for the matching seagrass node.
#   * The node's drop is **empty**: the source sets `drop = ""`. Only shears
#     return the seagrass item, via `_mcl_shears_drop`.
#   * Digging one restores the plain surface block underneath.
#
# The two falling surfaces — sand and red sand — carry the source's
# `falling_node` group and an alternative, so an unsupported seagrass reverts
# rather than falling as a plant.

const FIRST = VillageContent.SEAGRASS_FIRST
# The supported surfaces, in the source's own order.
# Voxey has no red sand, so six of the source's seven surfaces exist here.
const SURFACES = [Nodes.DIRT,Nodes.SAND,Nodes.GRAVEL,
	VillageContent.PRISMARINE,VillageContent.PRISMARINE_BRICK,VillageContent.PRISMARINE_DARK]
const NAMES = ["dirt","sand","gravel","prismarine","prismarine_brick","prismarine_dark"]

static func is_seagrass(id: int) -> bool: return index(id) >= 0
static func index(id: int) -> int:
	var i: int = id-FIRST
	return i if i >= 0 and i < SURFACES.size() else -1
static func surface(id: int) -> int: return SURFACES[index(id)] if is_seagrass(id) else 0
static func for_surface(surface_id: int) -> int:
	var i: int = SURFACES.find(surface_id)
	return FIRST+i if i >= 0 else 0
static func title(id: int) -> String: return "Seagrass"
static func color(id: int) -> Color: return Color("4f8f5a")

# `seagrass_on_place`: seagrass may only be placed where the cell above holds a
# water source, and only on a supported surface.
static func can_place(world: VoxelWorld, at: Vector3i) -> bool:
	if not Fluids.source(world.node_at(at+Vector3i.UP)): return false
	return SURFACES.has(world.node_at(at-Vector3i.UP))

# The node's own drop is empty in the source; only shears return the item.
static func place(game: Node3D, target: Dictionary, held: int) -> bool:
	if held != VillageContent.SEAGRASS or target.is_empty(): return false
	var world: VoxelWorld = game.world
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	var below: int = world.node_at(at-Vector3i.UP)
	if not SURFACES.has(below) or not Fluids.source(world.node_at(at+Vector3i.UP)):
		game.toast("Seagrass must be placed in water on dirt, sand, gravel or prismarine.")
		return true
	if world.node_at(at) != Nodes.AIR and not Fluids.water(world.node_at(at)): return true
	if not world.set_node(at,for_surface(below)): return true
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1
	game.api.emit_node_placed(at,world.node_at(at))
	return true

# Digging seagrass restores its surface block, which the source's `after_dig_node`
# does by swapping the rooted node back.
static func break_node(game: Node3D, p: Vector3i, id: int, tool: int) -> bool:
	if not is_seagrass(id): return false
	var world: VoxelWorld = game.world
	var restored: int = surface(id)
	world.set_node(p,restored)
	# Only shears yield the seagrass item, as `_mcl_shears_drop` requires.
	if tool == Nodes.SHEARS:
		game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,VillageContent.SEAGRASS,1)
	game.sound("dig")
	return true

# --- art --------------------------------------------------------------------

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	# The surface block shows through around the blades, as rooted plants do.
	var base: Color = Color(Nodes.color(surface(id))).darkened(0.08)
	if absf(x-7.5) > 4: return base
	return color(id) if y > 6 else base

static func draw(img: Image, id: int) -> void:
	var base: Color = color(id)
	img.fill_rect(Rect2i(4,13,8,2),base.darkened(0.25))
	for blade in [5,8,11]:
		ItemArt._line(img,Vector2(blade,14),Vector2(blade+(blade-8)/3,4),base,2)

static func mesh(out: Array, p: Vector3, id: int) -> void:
	var tile: int = Nodes.tile(id,0)
	BlockMesher._art_box(out,p+Vector3(0.5,0.5,0.5),Vector3(1,1,1),tile,tile)
	BlockMesher._art_box(out,p+Vector3(0.5,0.95,0.5),Vector3(0.85,0.9,0.85),tile,tile)

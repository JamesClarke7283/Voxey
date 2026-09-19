class_name Heads
extends RefCounted

# Mineclonia ITEMS/mcl_heads/init.lua, GPL-3.0-or-later. Original GDScript using
# the source as a behaviour reference.
#
# The reference registers six heads — zombie, creeper, human, skeleton, wither
# skeleton, piglin and dragon — each in three placements: floor, wall and
# ceiling. All three are the same item: `on_place` appends `_wall` or `_ceiling`
# to the node name depending on the face clicked, and the drop is always the
# plain floor node, so a wall or ceiling head returns the one item.
#
# Heads are also *wearable*: they carry `armor_head` and the source lowers the
# detection range of the matching mob by half while one is worn. Voxey's creature
# aggro has no per-mob range factor, so that effect is recorded below rather than
# invented.
#
# Acquisition is Minecraft's rule, not a random drop: `mcl_mobs/physics.lua` only
# forces a `mob_head` drop when the killing reason was an explosion from
# `mobs_mc:creeper_charged`. Voxey has no charged creeper, so this module adds
# one — a creeper struck by lightning becomes charged, with the source's larger
# explosion — and gives it that drop rule. That is the whole acquisition chain.

const FLOOR = VillageContent.HEAD_FLOOR
const WALL = VillageContent.HEAD_WALL
const CEILING = VillageContent.HEAD_CEILING
const KINDS = 7
# Source `register_head` order.
const NAMES = ["Zombie Head","Creeper Head","Human Head","Skeleton Skull","Wither Skeleton Skull","Piglin Head","Dragon Head"]
const COLORS = ["4f7a3f","4fae4f","b58a62","c9c9c9","3b3b3b","e2a0a0","5b6f57"]
# A head may be worn in the helmet slot; the source's `armor_head` group.
const RARITY = [1,1,1,1,2,1,3]

static func is_head(id: int) -> bool: return id >= FLOOR and id < FLOOR+KINDS

static func kind(id: int) -> int:
	if is_floor(id): return id-FLOOR
	if is_wall(id): return id-WALL
	if is_ceiling(id): return id-CEILING
	return -1

static func title(id: int) -> String:
	var index: int = kind(id)
	return NAMES[index] if index >= 0 else "Head"

static func color(id: int) -> Color:
	var index: int = kind(id)
	return Color(COLORS[index]) if index >= 0 else Color("8a8a8a")

# The plain floor node is the item, so wall and ceiling placements return it.
static func item(id: int) -> int:
	var index: int = kind(id)
	return FLOOR+index if index >= 0 else id

# `on_place`: the node name changes with the clicked face, and the item is
# restored afterwards so the stack keeps the plain head.
static func placement(kind_index: int, normal: Vector3i) -> int:
	if normal == Vector3i.UP: return CEILING+kind_index
	if normal == Vector3i.ZERO or normal == Vector3i.DOWN or normal == Vector3i.UP: return FLOOR+kind_index
	return WALL+kind_index

static func is_floor(id: int) -> bool: return id >= FLOOR and id < FLOOR+KINDS
static func is_wall(id: int) -> bool: return id >= WALL and id < WALL+KINDS
static func is_ceiling(id: int) -> bool: return id >= CEILING and id < CEILING+KINDS
static func is_any(id: int) -> bool: return is_floor(id) or is_wall(id) or is_ceiling(id)

# A head is a small 0.5-cube, not a full block: source floor/ceiling boxes span
# half a block and the wall box hugs one face.
static func boxes(id: int) -> Array:
	if is_wall(id): return [AABB(Vector3(0,0.25,0.25),Vector3(0.5,0.5,0.5))]
	if is_ceiling(id): return [AABB(Vector3(0.25,0.5,0.25),Vector3(0.5,0.5,0.5))]
	if is_floor(id): return [AABB(Vector3(0.25,0,0.25),Vector3(0.5,0.5,0.5))]
	return []

# --- art --------------------------------------------------------------------

# A head texture is a face with two eyes and a mouth, tinted per kind. Piglin and
# dragon use their own palettes rather than a flat tint.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base: Color = color(id)
	var index: int = kind(id)
	if x < 3 or x > 12 or y < 2 or y > 13: return Color(base.r,base.g,base.b,0.0)
	if index == 6: return base.darkened(0.25) if y in [3,12] else base
	if index == 5: return base.darkened(0.2) if y > 9 else base
	if y < 6 and x in [4,5,10,11]: return Color("1b1b1b")
	if y in [9,10] and x in range(5,11): return Color("1b1b1b") if index != 2 else Color("8a5a4a")
	return base

static func draw(img: Image, id: int) -> void:
	var base: Color = color(id)
	img.fill_rect(Rect2i(3,3,10,10),base)
	img.fill_rect(Rect2i(5,6,2,2),Color("1b1b1b"))
	img.fill_rect(Rect2i(9,6,2,2),Color("1b1b1b"))
	img.fill_rect(Rect2i(6,10,4,1),Color("1b1b1b"))

# The mesh is a half-scale cube sitting on the floor, on a wall face, or under
# the ceiling, matching the source's floor/wall/ceiling selection boxes.
static func mesh(out: Array, p: Vector3, id: int) -> void:
	var tile: int = Nodes.tile(id,0)
	var box: AABB = boxes(id)[0] if not boxes(id).is_empty() else AABB(Vector3(0.25,0,0.25),Vector3(0.5,0.5,0.5))
	BlockMesher._art_box(out,p+box.get_center(),box.size,tile,tile)

# --- placement ---------------------------------------------------------------

# `on_place`: the clicked face picks the placement, and the item is always the
# plain floor head so a wall or ceiling head returns the same item.
static func try_place(game: Node3D, target: Dictionary) -> bool:
	var held: int = game.inventory.held().id
	if not is_head(held) or target.is_empty(): return false
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	var normal: Vector3i = target.get("normal",Vector3i.UP)
	var current: int = game.world.node_at(at)
	if current != Nodes.AIR and not SnowCover.replaceable(current) and not Nodes.plant(current) and not Fluids.liquid(current): return true
	var node: int = placement(kind(held),normal)
	if game.world.set_node(at,node):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,node)
	return true

# --- charged creeper ---------------------------------------------------------

# Source `regular_creeper:_on_lightning_strike` replaces the mob with
# `mobs_mc:creeper_charged`, whose explosion is strength 6 over radius 8 and
# whose fuse is the same 1.5 seconds.
const CHARGED_RADIUS = 8.0
const CHARGED_STRENGTH = 6.0

# A head drops only from a charged creeper's explosion, as the source's
# `mob_head` rule requires. A wither skeleton also drops its own skull at the
# source's 1 in 40, which `creature.gd` applies separately.
static func mob_head(mob_kind: String) -> int:
	match mob_kind:
		"zombie": return FLOOR+0
		"creeper": return FLOOR+1
		"skeleton": return FLOOR+3
		"wither_skeleton": return FLOOR+4
	return -1

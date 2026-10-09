class_name CactusFlower
extends RefCounted

# Mineclonia ITEMS/mcl_core/functions.lua (`mcl_core.grow_cactus`) and
# `nodes_cactuscane.lua` (`mcl_core:cactus_flower`), GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# A cactus grows upward on sand to a height of four, and its top occasionally
# sprouts a **flower**: the source rolls `math.random() < (height >= 3 and 0.25 or
# 0.1)` and places the flower only when the cell above and all four side cells are
# air. Voxey's generator places a fixed three-tall cactus and never grows or flowers
# one, so this module supplies the growth step.
#
# The flower is `deco_block`, `attached_node`, needs nothing beneath but a cactus,
# and yields one **pink** dye (`_mcl_crafting_output`).

const ID = 701
# The source caps a cactus at four tall.
const MAX_HEIGHT = 4
# Source chance of a flower on the top: 25% at height three or more, else 10%.
const FLOWER_CHANCE_TALL = 0.25
const FLOWER_CHANCE_SHORT = 0.1
# Source `grow_cactus` sand group.
const SOIL = [Nodes.SAND,Archaeology.SUSPICIOUS_SAND]

const DATA = {
	701:{"name":"Cactus flower","block":true,"shape":"plant","color":"e06aa0","hardness":0.0,"tool":-1,"transparent":true,"flammable":true,"compostability":30,"source_node":"mcl_core:cactus_flower"},
}

static func is_flower(id: int) -> bool: return id == ID

# The height of the cactus column whose top is `p`, counting `p` itself.
static func column_height(world: VoxelWorld, p: Vector3i) -> int:
	var height: int = 0
	var at: Vector3i = p
	while world.node_at(at) == Nodes.CACTUS and height < MAX_HEIGHT:
		height += 1
		at += Vector3i.UP
	return height

# `grow_cactus`: grow the column up one, or sprout a flower, from the cactus base
# cell `p`. Returns true when something changed.
static func grow(world: VoxelWorld, p: Vector3i, rng: RandomNumberGenerator) -> bool:
	# The source starts from the base (`pos.y = pos.y-1` then back up), so `p` is the
	# base and the column rises from it.
	if world.node_at(p) != Nodes.CACTUS: return false
	if not SOIL.has(world.node_at(p+Vector3i.DOWN)): return false
	var top: Vector3i = p
	var height: int = 0
	while world.node_at(top) == Nodes.CACTUS and height < MAX_HEIGHT:
		height += 1
		top += Vector3i.UP
	# `top` is now the air cell the column would grow into.
	if rng.randf() < (FLOWER_CHANCE_TALL if height >= 3 else FLOWER_CHANCE_SHORT):
		if world.node_at(top) == Nodes.AIR and side_clear(world,top):
			return world.set_node(top,ID)
		return false
	if height < MAX_HEIGHT:
		if world.node_at(top) == Nodes.AIR: return world.set_node(top,Nodes.CACTUS)
	return false

# The source requires the flower's own cell and all four side cells to be air.
static func side_clear(world: VoxelWorld, at: Vector3i) -> bool:
	for side in [Vector3i(1,0,0),Vector3i(-1,0,0),Vector3i(0,0,1),Vector3i(0,0,-1)]:
		if world.node_at(at+side) != Nodes.AIR: return false
	return true

# --- recipes -----------------------------------------------------------------

static func recipes(inv: Inventory) -> void:
	inv._recipe("Pink dye",VillageContent.DYE_PINK,1,[ID],1)

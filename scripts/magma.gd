class_name Magma
extends RefCounted

# Mineclonia ITEMS/mcl_nether/init.lua (`mcl_nether:magma`), GPL-3.0-or-later.
# Original GDScript using the source as a behaviour reference.
#
# A magma block is a hot solid block with three behaviours the source gives it:
#
#   * It **burns whoever stands on it** — one damage per slow globalstep, which
#     is the `register_globalstep_slow` hook in the reference.
#   * **Sneaking, fire resistance or Frost Walker boots prevent the burn**, which
#     are the source's three exemptions.
#   * A fire lit on it becomes **eternal fire**, which Voxey's fire system already
#     models for netherrack and bedrock.
#
# It also emits light 3, and is crafted from four magma cream.

# Voxey's masonry family occupies 1150-1157, so the block continues from there.
const ID = 1158
const BLOCKS = [ID]

# Source `light_source = 3`.
const LIGHT = 3
# The source deals one damage per slow globalstep.
const DAMAGE = 1.0
# Source `_mcl_hardness = 0.5`.
const HARDNESS = 0.5

static func is_magma(id: int) -> bool: return id == ID

# A constant, so `VillageContent.DATA` can reference it without a cyclic
# dependency on a static function.
const DATA = {1158: {"name":"Magma block","block":true,"solid":true,"color":"8e3f22","hardness":HARDNESS,
	"tool":0,"light":LIGHT,"emits":LIGHT,"magma":true}}

# Whether the block supports eternal fire, which Voxey's `Fire` already does for
# the source's other eternal-fuel blocks.
static func eternal(id: int) -> bool: return is_magma(id)

# Whether a standing player is protected from the burn. The source exempts
# sneaking, fire resistance and Frost Walker boots.
static func protected(player: VoxeyPlayer) -> bool:
	if player.crouching: return true
	if PotionEffects.level(player,"fire_resistance") > 0: return true
	if Inventory.enchantment(player.armor_slots[3],"Frost Walker") > 0: return true
	return false

# Burn a player standing on the block, which the source does on a slow tick.
static func step(game: Node3D) -> void:
	var player: VoxeyPlayer = game.player
	if game.gamemode == "creative" or player.health <= 0: return
	# The block the player stands on, which is the source's `nodes.stand`.
	var below := Vector3i((player.position-Vector3(0,0.1,0)).floor())
	if not is_magma(game.world.node_at(below)): return
	if protected(player): return
	player.hurt(DAMAGE,true,Vector3.INF,"hot_floor")

static func recipes(inv: Inventory) -> void:
	# Source `_mcl_crafting_output = {square2 = {output = "mcl_nether:magma"}}`:
	# four magma cream in a square.
	inv._recipe("Magma block",ID,1,[Nodes.MAGMA_CREAM,Nodes.MAGMA_CREAM,Nodes.MAGMA_CREAM,Nodes.MAGMA_CREAM],2)

# --- art ---------------------------------------------------------------------

# A dark crust with bright molten veins, which is what the source's animated
# texture shows in its middle frame.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if id != ID: return Color(0,0,0,0)
	var dark := Color("8e3f22")
	var glow := Color("f2a03a")
	# A coarse cellular pattern, with the hot veins following the cell borders.
	var cell: int = (x/4)*7+(y/4)*13
	if (x+y*3+cell)%11 < 2: return glow
	if x%4 == 0 or y%4 == 0: return dark.lightened(0.12)
	return dark.darkened(0.08*float((x*3+y*5+cell)%3))

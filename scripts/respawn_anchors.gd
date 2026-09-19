class_name RespawnAnchors
extends RefCounted

# Mineclonia ITEMS/mcl_beds/respawn_anchor.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference; art is original procedural code.
#
# The respawn anchor is the Nether's answer to a bed: a block that lets a player set
# their spawn point where beds explode. It is charged with **glowstone**, up to four
# times, and each charge raises its light level and its comparator signal.
#
# The rule that makes it interesting is the failure case. A **charged** anchor used
# outside the Nether explodes — with fire — which is the source's other `info.fire`
# blast beside the Nether bed:
#
#     elseif mcl_worlds.pos_to_dimension(pos) ~= "nether" then
#         if node.name ~= "mcl_beds:respawn_anchor" then
#             core.remove_node(pos)
#             mcl_explosions.explode(pos, 5, {fire = true})
#         end
#
# An *uncharged* anchor is harmless outside the Nether, and a charged one can be used
# freely inside it. So the block is safe to carry and dangerous to arm.

# The uncharged anchor, then the four charged levels.
const BASE = 1213
const CHARGED_1 = 1214
const CHARGED_2 = 1215
const CHARGED_3 = 1216
const CHARGED_4 = 1217
const CHARGED = [CHARGED_1,CHARGED_2,CHARGED_3,CHARGED_4]
const BLOCKS = [BASE,CHARGED_1,CHARGED_2,CHARGED_3,CHARGED_4]

# Source `light_level = {3, 7, 11, core.LIGHT_MAX}`.
const LIGHT = [3,7,11,15]
# Source `comparator_signal = 4 * i - 1`.
const SIGNAL = [3,7,11,15]
# Source `_mcl_hardness = 50`, `_mcl_blast_resistance = 1200`.
const HARDNESS = 50.0
const BLAST_RESISTANCE = 1200
# The explosion a charged anchor makes outside the Nether.
const BLAST_STRENGTH = 5.0

# Literal keys, so the content table can reference this without a const cycle.
const BLOCK_DATA = {
	1213: {"name":"Respawn anchor","block":true,"color":"2b2140","hardness":HARDNESS,"blast_resistance":BLAST_RESISTANCE,"tool":0},
	1214: {"name":"Respawn anchor","block":true,"color":"3a2a58","hardness":HARDNESS,"blast_resistance":BLAST_RESISTANCE,"tool":0,"hidden":true,"light":3,"emits":3},
	1215: {"name":"Respawn anchor","block":true,"color":"4a3670","hardness":HARDNESS,"blast_resistance":BLAST_RESISTANCE,"tool":0,"hidden":true,"light":7,"emits":7},
	1216: {"name":"Respawn anchor","block":true,"color":"5a4288","hardness":HARDNESS,"blast_resistance":BLAST_RESISTANCE,"tool":0,"hidden":true,"light":11,"emits":11},
	1217: {"name":"Respawn anchor","block":true,"color":"6a4ea0","hardness":HARDNESS,"blast_resistance":BLAST_RESISTANCE,"tool":0,"hidden":true,"light":15,"emits":15},
}

static func is_anchor(id: int) -> bool: return BLOCKS.has(id)
static func is_charged(id: int) -> bool: return CHARGED.has(id)
# The source's `charge_level`, which is zero for the uncharged block.
static func charge(id: int) -> int:
	if id == BASE: return 0
	return CHARGED.find(id)+1 if is_charged(id) else 0
# The node a given charge level uses, which is how charging and discharging move.
static func for_charge(level: int) -> int:
	return BASE if level <= 0 else CHARGED[clampi(level,1,4)-1]
static func light_level(id: int) -> int:
	var level: int = charge(id)
	return LIGHT[level-1] if level > 0 else 0
static func comparator_signal(id: int) -> int:
	var level: int = charge(id)
	return SIGNAL[level-1] if level > 0 else 0

# --- charging ----------------------------------------------------------------

# Add one glowstone charge. Returns false when the anchor is already full, so the
# caller does not consume the glowstone.
static func charge_up(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if not is_anchor(id) or charge(id) >= 4: return false
	return world.set_node(p,for_charge(charge(id)+1))

# --- using it ----------------------------------------------------------------

# Use a charged anchor. Inside the Nether it sets the spawn; outside, a **charged**
# anchor explodes with fire while an uncharged one does nothing. That asymmetry is the
# source's own: the block is safe to carry and dangerous to arm.
static func use(game: Node3D, p: Vector3i) -> bool:
	var id: int = game.world.node_at(p)
	if not is_anchor(id): return false
	var level: int = charge(id)
	if level <= 0: return false
	if game.dimension == "nether":
		# The source sets the player's spawn at the anchor, which is the whole point of
		# the block: a Nether spawn where a bed would explode.
		game.spawn_point = game._safe_spawn(Vector3(p)+Vector3(0.5,1,0.5))
		game.toast("New respawn position set!")
		return true
	game.world.set_node(p,Nodes.AIR)
	game.explode(Vector3(p)+Vector3.ONE*0.5,BLAST_STRENGTH,null,true)
	return true

# --- recipes -----------------------------------------------------------------

# The source's own shape: crying obsidian, glowstone, crying obsidian.
static func recipes(inv: Inventory) -> void:
	inv._recipe("Respawn anchor",BASE,1,[Bastions.CRYING_OBSIDIAN,Bastions.CRYING_OBSIDIAN,Bastions.CRYING_OBSIDIAN,
		Nodes.GLOWSTONE,Nodes.GLOWSTONE,Nodes.GLOWSTONE,
		Bastions.CRYING_OBSIDIAN,Bastions.CRYING_OBSIDIAN,Bastions.CRYING_OBSIDIAN],3,"table")

# --- art ---------------------------------------------------------------------

# The anchor's top glows as it charges, which is what its light level represents. The
# uncharged face is dark with a dull rim; each charge brightens the core.
static func pixel(id: int, x: int, y: int) -> Color:
	var base: Color = Color(BLOCK_DATA[id].color)
	var level: int = charge(id)
	# A beveled stone frame, so the block reads as a heavy carved object.
	if x in [0,15] or y in [0,15]: return base.darkened(0.35)
	if x in [1,2] or y in [1,2] or x in [13,14] or y in [13,14]: return base.lightened(0.12)
	var centre: float = Vector2(x-7.5,y-7.5).length()
	if centre > 5.5: return base.darkened(0.18)
	if level <= 0:
		# Uncharged: a dark inset with the faintest glow, so it is evidently inert.
		return base.darkened(0.3) if centre > 3.0 else Color("1b1428")
	# Charged: the core brightens with the level, and the ring takes the same tint.
	var core: Color = Color("8a5ad6").lerp(Color("e6c8ff"),float(level-1)/3.0)
	return core if centre <= 2.6 else core.darkened(0.35)

class_name GlassColors
extends RefCounted

# Mineclonia ITEMS/mcl_core/nodes_glass.lua (stained glass) and
# ITEMS/mcl_panes/init.lua (`register_pane`, stained panes), GPL-3.0-or-later.
# Original GDScript and original procedural art; the sources are used as a
# behaviour reference only.
#
# Source rules reproduced here:
#
# * Stained glass (`nodes_glass.lua:42-59`). Registered once per entry of
#   `mcl_dyes.colors` as `mcl_core:glass_<colour>`, with
#   `drawtype = "glasslike_framed_optional"`, `paramtype2 =
#   "glasslikeliquidlevel"`, `sunlight_propagates = true`,
#   `use_texture_alpha = "blend"`, `groups = {handy=1, glass=1,
#   building_block=1, material_glass=1, ["basecolor_"..colour]=1}`,
#   `sounds = mcl_sounds.node_sound_glass_defaults()`, `drop = ""`,
#   `_mcl_hardness = 0.3` and `_mcl_silk_touch_drop = true`. The `drop = ""` is
#   the important half: an ordinary break yields nothing at all, and only Silk
#   Touch returns the block.
# * Stained glass recipe (`nodes_glass.lua:62-70`): eight `mcl_core:glass`
#   around one `mcl_dyes:<colour>`, which is the 3x3 pattern below.
# * Stained panes (`init.lua:201-246`): `register_pane` is called once per
#   `mcl_dyes.colors` entry with `node = "mcl_core:glass_"..k`, so a pane is made
#   from the *stained* glass of its own colour, not from plain glass. The pane
#   keeps `use_texture_alpha = "blend"` (only the uncoloured `_natural` pane uses
#   `"clip"`), `groups = {handy=1, material_glass=1,
#   pathfinder_partial=2}` and `connects_to = {"group:pane", "group:solid"}`, and
#   again `drop = ""` with `_mcl_hardness = 0.3` and `_mcl_silk_touch_drop`.
# * Pane recipe (`init.lua:188-193`, recipe at `232-235`): a 2x3 block of the
#   base node yields **16** panes, which is why the pane recipe pattern has six
#   entries.
# * A pane collapses to its `_flat` form when it connects on exactly two opposite
#   sides (`init.lua:71-113`). Voxey models that with the shared `"pane"` shape /
#   connection logic the parent wires; this module only declares the block.
#
# Transparency. Every id here is `"transparent": true`. `Nodes.transparent` and
# `Nodes.solid` are the readers: stained glass stays *solid* (a player walks into
# it, as the source's full-nodebox `glasslike` does) while not occluding, exactly
# like `Amethyst.TINTED_GLASS` and `VillageContent.GLASS_PANE` do today.
#
# Drops. The source sets `drop = ""` and `_mcl_silk_touch_drop = true` on both
# families, so **all 32 ids below** need a Silk-Touch-only drop: nothing on an
# ordinary break, the block itself under Silk Touch. `"drop": 0` records that in
# the DATA, which is how this project annotates "drops nothing" (`Amethyst`
# buds, `DenseMaterials` ice and `Beehives` all use it); note `Nodes.drop` has no
# generic `"drop"` reader for `VillageContent.DATA` entries, so the annotation is
# documentation until the parent adds the branch. Plain `Nodes.GLASS` is the
# existing precedent: it is excluded from the generic drop path in `game.gd` and
# returned by `Enchantments.harvest` under Silk Touch.

# Ids, in Voxey's colour order: the order of `VillageContent.DYE_WHITE` (821)
# through `DYE_BROWN` (836), shared by the wool, carpet, terracotta, banner, bed
# and concrete families.
const FIRST = 11210
const PANE_FIRST = 11226
const COUNT = 16
const COLORS = ["white","grey","silver","black","yellow","orange","red","magenta","purple","blue","cyan","lime","green","pink","light_blue","brown"]

const BLOCKS = [
	FIRST+0,FIRST+1,FIRST+2,FIRST+3,FIRST+4,FIRST+5,FIRST+6,FIRST+7,
	FIRST+8,FIRST+9,FIRST+10,FIRST+11,FIRST+12,FIRST+13,FIRST+14,FIRST+15,
	PANE_FIRST+0,PANE_FIRST+1,PANE_FIRST+2,PANE_FIRST+3,PANE_FIRST+4,PANE_FIRST+5,PANE_FIRST+6,PANE_FIRST+7,
	PANE_FIRST+8,PANE_FIRST+9,PANE_FIRST+10,PANE_FIRST+11,PANE_FIRST+12,PANE_FIRST+13,PANE_FIRST+14,PANE_FIRST+15,
]

# `"color"` reuses the matching Voxey dye colour, which is the analogue of the
# source taking the glass texture from `mcl_dyes.colors[colour].rgb` and of the
# beacon beam taking its tint from the glass (`_color` / `get_beacon_beam`).
#
# `"tool": -1` is the source's `handy=1`: glass is broken by hand and needs no
# tool at all, so a `"tool": 0` default here would wrongly demand a pickaxe.
# TINTED_GLASS uses the same value for the same reason.
#
# `"note_material": "glass"` carries the source's `material_glass=1` group and
# `node_sound_glass_defaults()` into the note block's instrument selection.
#
# `"family"` is `"glass"` for the blocks, which is what `Beacons.beam_color`
# already reads to tint a beacon beam, matching `_color` on the source nodes. The
# panes are declared `"pane"`: the source's pane nodes carry `material_glass=1`
# (so a beam passes through) but `register_pane` never copies `def._color` onto
# the registered node, so a pane does **not** tint a beam.
const DATA = {
	FIRST+0:{"name":"White stained glass","color":"e4e4d7","block":true,"family":"glass","dye":"white","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+1:{"name":"Grey stained glass","color":"626c70","block":true,"family":"glass","dye":"grey","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+2:{"name":"Light grey stained glass","color":"b0b4ac","block":true,"family":"glass","dye":"silver","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+3:{"name":"Black stained glass","color":"333740","block":true,"family":"glass","dye":"black","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+4:{"name":"Yellow stained glass","color":"edc647","block":true,"family":"glass","dye":"yellow","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+5:{"name":"Orange stained glass","color":"e4943e","block":true,"family":"glass","dye":"orange","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+6:{"name":"Red stained glass","color":"b83d41","block":true,"family":"glass","dye":"red","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+7:{"name":"Magenta stained glass","color":"b94baf","block":true,"family":"glass","dye":"magenta","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+8:{"name":"Purple stained glass","color":"824aaa","block":true,"family":"glass","dye":"purple","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+9:{"name":"Blue stained glass","color":"4966ad","block":true,"family":"glass","dye":"blue","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+10:{"name":"Cyan stained glass","color":"378a99","block":true,"family":"glass","dye":"cyan","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+11:{"name":"Lime stained glass","color":"8bbe45","block":true,"family":"glass","dye":"lime","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+12:{"name":"Green stained glass","color":"51763e","block":true,"family":"glass","dye":"green","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+13:{"name":"Pink stained glass","color":"dd8eac","block":true,"family":"glass","dye":"pink","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+14:{"name":"Light blue stained glass","color":"79b4d2","block":true,"family":"glass","dye":"light_blue","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	FIRST+15:{"name":"Brown stained glass","color":"79563e","block":true,"family":"glass","dye":"brown","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+0:{"name":"White stained glass pane","color":"e4e4d7","block":true,"shape":"pane","family":"pane","dye":"white","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+1:{"name":"Grey stained glass pane","color":"626c70","block":true,"shape":"pane","family":"pane","dye":"grey","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+2:{"name":"Light grey stained glass pane","color":"b0b4ac","block":true,"shape":"pane","family":"pane","dye":"silver","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+3:{"name":"Black stained glass pane","color":"333740","block":true,"shape":"pane","family":"pane","dye":"black","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+4:{"name":"Yellow stained glass pane","color":"edc647","block":true,"shape":"pane","family":"pane","dye":"yellow","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+5:{"name":"Orange stained glass pane","color":"e4943e","block":true,"shape":"pane","family":"pane","dye":"orange","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+6:{"name":"Red stained glass pane","color":"b83d41","block":true,"shape":"pane","family":"pane","dye":"red","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+7:{"name":"Magenta stained glass pane","color":"b94baf","block":true,"shape":"pane","family":"pane","dye":"magenta","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+8:{"name":"Purple stained glass pane","color":"824aaa","block":true,"shape":"pane","family":"pane","dye":"purple","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+9:{"name":"Blue stained glass pane","color":"4966ad","block":true,"shape":"pane","family":"pane","dye":"blue","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+10:{"name":"Cyan stained glass pane","color":"378a99","block":true,"shape":"pane","family":"pane","dye":"cyan","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+11:{"name":"Lime stained glass pane","color":"8bbe45","block":true,"shape":"pane","family":"pane","dye":"lime","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+12:{"name":"Green stained glass pane","color":"51763e","block":true,"shape":"pane","family":"pane","dye":"green","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+13:{"name":"Pink stained glass pane","color":"dd8eac","block":true,"shape":"pane","family":"pane","dye":"pink","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+14:{"name":"Light blue stained glass pane","color":"79b4d2","block":true,"shape":"pane","family":"pane","dye":"light_blue","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
	PANE_FIRST+15:{"name":"Brown stained glass pane","color":"79563e","block":true,"shape":"pane","family":"pane","dye":"brown","note_material":"glass","hardness":0.3,"tool":-1,"drop":0,"transparent":true},
}

# --- predicates --------------------------------------------------------------

static func is_stained_glass(id: int) -> bool:
	return id >= FIRST and id < FIRST+COUNT
static func is_stained_pane(id: int) -> bool:
	return id >= PANE_FIRST and id < PANE_FIRST+COUNT
static func is_stained(id: int) -> bool:
	return is_stained_glass(id) or is_stained_pane(id)
# The colour index, or -1. `index(FIRST)` and `index(PANE_FIRST)` are both 0.
static func index(id: int) -> int:
	if is_stained_glass(id): return id-FIRST
	return id-PANE_FIRST if is_stained_pane(id) else -1
# The dye that colours a block, which is `DYE_WHITE` + the colour index, or 0.
static func dye(id: int) -> int:
	var i: int = index(id)
	return VillageContent.DYE_WHITE+i if i >= 0 else 0
# The pane of a stained glass block, else 0; and the inverse.
static func pane_for(glass_id: int) -> int:
	return PANE_FIRST+index(glass_id) if is_stained_glass(glass_id) else 0
static func glass_for(pane_id: int) -> int:
	return FIRST+index(pane_id) if is_stained_pane(pane_id) else 0

# --- recipes -----------------------------------------------------------------

# Source `register_craft` in `nodes_glass.lua:62-70`: eight glass around one dye
# of the same colour, giving eight stained glass; and `init.lua:188-193` with the
# pane recipe at `228-233`: six of the stained glass block give sixteen panes.
static func recipes(inv: Inventory) -> void:
	for i in COUNT:
		var glass: int = FIRST+i
		var pane: int = PANE_FIRST+i
		var shade: int = VillageContent.DYE_WHITE+i
		inv._recipe(Nodes.title(glass),glass,8,
			[Nodes.GLASS,Nodes.GLASS,Nodes.GLASS,
			Nodes.GLASS,shade,Nodes.GLASS,
			Nodes.GLASS,Nodes.GLASS,Nodes.GLASS],3,"table")
		inv._recipe(Nodes.title(pane),pane,16,
			[glass,glass,glass,
			glass,glass,glass],3,"table")

# --- art ---------------------------------------------------------------------

# Block faces are drawn by the terrain shader, whose alpha scissor is 0.5: only
# pixels at alpha 0.5 or above survive, and everything below it is a hole. Voxey's
# plain `Nodes.GLASS` tile relies on that - a full-alpha frame plus the main
# diagonal, with the interior at zero alpha - and so does
# `VillageContent.GLASS_PANE` (0x8a for the frame, 0x18 for the interior). The
# stained tiles follow the same split, which is also the source's:
# `mcl_core_glass_<colour>.png` draws a leading frame at alpha 0xc2 over a 0x66
# interior. Here the leading carries the colour, so the block reads as a coloured
# frame around a see-through pane, and the interior stays under the scissor.
static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(VillageContent.DATA[id].color)
	if is_stained_pane(id): return pane_pixel(base,x,y,noise)
	return glass_pixel(base,x,y,noise)

static func glass_pixel(base: Color, x: int, y: int, noise: Color) -> Color:
	# The leading, one pixel in from the edge, is the darkest part of the design on
	# every face, which is what makes the frame read as a seam between panes.
	if x in [0,15] or y in [0,15]: return noise.lerp(base.darkened(0.34),0.8)
	if x in [1,14] or y in [1,14]: return noise.lerp(base.lightened(0.16),0.7)
	# The source's `glasslike_framed` draws a diagonal detail across the pane.
	if x == y or x+y == 15: return noise.lerp(base.lightened(0.06),0.75)
	# Two highlights stop a wall of one colour from reading as a flat hole.
	if (x-6)*(x-6)+(y-5)*(y-5) < 3 or (x-9)*(x-9)+(y-10)*(y-10) < 3: return noise.lerp(base.lightened(0.24),0.6)
	return Color(base.r,base.g,base.b,0.32)

static func pane_pixel(base: Color, x: int, y: int, noise: Color) -> Color:
	# A pane's tile is a divided light: a leading border all the way round plus a
	# central mullion, which tells it apart from the plain glass sheet at a glance.
	if x in [0,15] or y in [0,15]: return noise.lerp(base.darkened(0.38),0.75)
	if x in [1,14] or y in [1,14]: return noise.lerp(base.lightened(0.20),0.7)
	if x in [7,8] or y in [7,8]: return noise.lerp(base.darkened(0.16),0.72)
	if (x*3+y*7)%11 == 0: return noise.lerp(base.lightened(0.26),0.6)
	return Color(base.r,base.g,base.b,0.30)

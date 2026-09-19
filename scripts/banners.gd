class_name Banners
extends RefCounted

# Mineclonia ITEMS/mcl_banners/{init,items,patterncraft}.lua, GPL-3.0-or-later.
# Original GDScript using the source as a behaviour reference.
#
# A banner is a coloured flag that carries an ordered list of **layers**: each
# layer is a pattern plus the dye colour it was applied in. The source stores that
# list in the item's metadata and rebuilds the description and texture from it.
#
# The pattern table is the source's own, all **42 entries**:
#
#   * 32 are dye-grid patterns, crafted in a table from a ring or shape of dye
#     around the banner. The grids are transcribed exactly — `d` is a dye and `e`
#     is empty.
#   * 10 are **special** patterns, each crafted shapelessly from paper plus a
#     specific item: brick block, vine, oxeye daisy, a creeper head, a wither
#     skeleton skull, and the globe, piglin, guster and flow pattern items.
#
# A banner also combines: emblazoning an already-patterned banner with another
# pattern appends a layer, up to the source's `max_craftable_layers`.
#
# Voxey already had the sixteen coloured banner blocks and their recipes; this
# adds the layer system, which is what banners are actually for.

const FIRST = VillageContent.BANNER_FIRST
# The sixteen banner colours in the source's order. Kept here rather than derived
# from `Nodes.title`, which delegates back into `describe` and would recurse.
const BANNER_NAMES = ["White","Grey","Light grey","Black","Yellow","Orange","Red","Magenta",
	"Purple","Blue","Cyan","Lime","Green","Pink","Light blue","Brown"]
const COLORS = 16
# The source's `max_craftable_layers`.
const MAX_LAYERS = 6
# `d` is a dye, `e` is empty, in reading order across the three rows.
const DYE = "d"
const EMPTY = "e"

# The source's pattern table: key -> [display name, grid-or-signature].
# Grids are nine characters; a signature is the extra item instead of a grid.
const PATTERNS = {
	"border":{"name":"Bordure","grid":"ddddedddd"},
	"bricks":{"name":"Bricks","signature":"BRICK_BLOCK"},
	"circle":{"name":"Roundel","grid":"eeeedeeee"},
	"creeper":{"name":"Creeper Charge","signature":"HEAD_CREEPER"},
	"cross":{"name":"Saltire","grid":"dedededed"},
	"curly_border":{"name":"Bordure Indented","signature":"VINE"},
	"diagonal_up_left":{"name":"Per Bend Inverted","grid":"eeedeedde"},
	"diagonal_up_right":{"name":"Per Bend Sinister Inverted","grid":"eeeeededd"},
	"diagonal_right":{"name":"Per Bend","grid":"eddeedeee"},
	"diagonal_left":{"name":"Per Bend Sinister","grid":"ddedeeeee"},
	"flower":{"name":"Flower Charge","signature":"OXEYE_DAISY"},
	"gradient":{"name":"Gradient","grid":"dededeede"},
	"gradient_up":{"name":"Base Gradient","grid":"edeededed"},
	"half_horizontal_bottom":{"name":"Per Fess Inverted","grid":"eeedddddd"},
	"half_horizontal":{"name":"Per Fess","grid":"ddddddeee"},
	"half_vertical":{"name":"Per Pale","grid":"ddeddedde"},
	"half_vertical_right":{"name":"Per Pale Inverted","grid":"eddeddedd"},
	"globe":{"name":"Globe Charge","signature":"PATTERN_GLOBE"},
	"piglin":{"name":"Piglin Charge","signature":"PATTERN_PIGLIN"},
	"rhombus":{"name":"Lozenge","grid":"edededede"},
	"skull":{"name":"Skull Charge","signature":"HEAD_WITHER_SKELETON"},
	"small_stripes":{"name":"Paly","grid":"deddedeee"},
	"square_bottom_left":{"name":"Base Dexter Canton","grid":"eeeeeedee"},
	"square_bottom_right":{"name":"Base Sinister Canton","grid":"eeeeeeeed"},
	"square_top_left":{"name":"Chief Dexter Canton","grid":"deeeeeeee"},
	"square_top_right":{"name":"Chief Sinister Canton","grid":"eedeeeeee"},
	"straight_cross":{"name":"Cross","grid":"ededddede"},
	"stripe_bottom":{"name":"Base","grid":"eeeeeeddd"},
	"stripe_center":{"name":"Pale","grid":"edeedeede"},
	"stripe_downleft":{"name":"Bend Sinister","grid":"eedededee"},
	"stripe_downright":{"name":"Bend","grid":"deeedeeed"},
	"stripe_left":{"name":"Pale Dexter","grid":"deedeedee"},
	"stripe_middle":{"name":"Fess","grid":"eeedddeee"},
	"stripe_right":{"name":"Pale Sinister","grid":"eedeedeed"},
	"stripe_top":{"name":"Chief","grid":"dddeeeeee"},
	"thing":{"name":"Thing","signature":"GOLDEN_APPLE"},
	"triangle_bottom":{"name":"Chevron","grid":"eeeededed"},
	"triangle_top":{"name":"Chevron Inverted","grid":"dededeeee"},
	"triangles_bottom":{"name":"Base Indented","grid":"eeededede"},
	"triangles_top":{"name":"Chief Indented","grid":"edededeee"},
	"flow":{"name":"Flow","signature":"PATTERN_FLOW"},
	"guster":{"name":"Guster","signature":"PATTERN_GUSTER"},
}
const ITEM_KEYS = ["thing","skull","creeper","flower","bricks","curly_border","globe","piglin","guster","flow"]
const PATTERN_KEYS = ["border","bricks","circle","creeper","cross","curly_border","thing",
	"diagonal_up_left","diagonal_up_right","diagonal_right","diagonal_left","flower",
	"gradient","gradient_up","half_horizontal_bottom","half_horizontal","half_vertical",
	"half_vertical_right","globe","piglin","rhombus","skull","small_stripes",
	"square_bottom_left","square_bottom_right","square_top_left","square_top_right",
	"straight_cross","stripe_bottom","stripe_center","stripe_downleft","stripe_downright",
	"stripe_left","stripe_middle","stripe_right","stripe_top","triangle_bottom",
	"triangle_top","triangles_bottom","triangles_top","flow","guster"]

static func is_banner(id: int) -> bool:
	return id >= FIRST and id < FIRST+COLORS
static func color_index(id: int) -> int: return id-FIRST if is_banner(id) else -1
static func pattern(name: String) -> Dictionary: return PATTERNS.get(name,{})
static func is_special(name: String) -> bool: return PATTERNS.get(name,{}).has("signature")

# --- layers ------------------------------------------------------------------

# `read_layers`: an ordered list of {pattern, color} pairs.
static func layers(slot: Dictionary) -> Array:
	var data: Dictionary = slot.get("data",{})
	var stored: Variant = data.get("layers",[])
	return stored if stored is Array else []

static func set_layers(slot: Dictionary, value: Array) -> void:
	if not slot.has("data"): slot["data"] = {}
	if value.is_empty(): slot.data.erase("layers")
	else: slot.data["layers"] = value

# `is_same_layers`: two banners carry the same emblazoning in the same order.
static func same_layers(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if str(a[i].get("pattern","")) != str(b[i].get("pattern","")): return false
		if int(a[i].get("color",-1)) != int(b[i].get("color",-1)): return false
	return true

# `make_pattern_name`: the colour name followed by the pattern's name.
static func pattern_name(color_index_value: int, key: String) -> String:
	var entry: Dictionary = pattern(key)
	if entry.is_empty(): return key
	return "%s %s" % [BANNER_NAMES[clampi(color_index_value,0,COLORS-1)],entry.name]

# A banner's description lists its layers, most recent first, as the source does.
static func describe(slot: Dictionary) -> String:
	var list: Array = layers(slot)
	if list.is_empty(): return "Banner"
	var parts: PackedStringArray = []
	# The source shows the topmost patterns first and stops at its limit.
	for i in range(mini(list.size(),MAX_LAYERS)-1,-1,-1):
		parts.append(pattern_name(int(list[i].get("color",0)),str(list[i].get("pattern",""))))
	return "Banner\n%s" % ", ".join(parts)

# --- crafting ----------------------------------------------------------------

# Emblazoning a banner appends one layer, which is the source's rule: the banner
# keeps every earlier layer and gains the new one on top.
static func emblazon(slot: Dictionary, key: String, color_index_value: int) -> bool:
	if not is_banner(int(slot.get("id",0))): return false
	if not PATTERNS.has(key): return false
	var list: Array = layers(slot).duplicate(true)
	if list.size() >= MAX_LAYERS: return false
	list.append({"pattern":key,"color":color_index_value})
	set_layers(slot,list)
	return true

# A banner may absorb another banner's emblazoning, which is the source's combine
# rule: the layers of the one being used are appended in order.
static func combine(slot: Dictionary, other: Dictionary) -> bool:
	var mine: Array = layers(slot)
	var theirs: Array = layers(other)
	if theirs.is_empty() or same_layers(mine,theirs): return false
	var merged: Array = mine.duplicate(true)
	for layer in theirs:
		if merged.size() >= MAX_LAYERS: break
		merged.append(layer.duplicate(true))
	if same_layers(mine,merged): return false
	set_layers(slot,merged)
	return true

# The dye grid for a pattern, or an empty array for a special one.
static func grid(key: String) -> Array:
	var entry: Dictionary = pattern(key)
	if not entry.has("grid"): return []
	var cells: Array = []
	for i in entry.grid.length():
		cells.append(str(entry.grid)[i])
	return cells

# --- dye and pattern selection -----------------------------------------------

# A held dye maps to a banner colour index. Voxey's dyes and banners share the
# source's sixteen-colour order, so the offset is direct.
static func dye_color(id: int) -> int:
	var dye: int = id-VillageContent.DYE_WHITE
	return dye if dye >= 0 and dye < COLORS else -1

# The pattern a held item carries: a pattern item selects its own, otherwise the
# dye applies a plain dye-grid pattern chosen by the player's held pattern item.
const DEFAULT_PATTERN = "stripe_center"

static func pending_pattern(held: int) -> String:
	var index: int = held-VillageContent.PATTERN_FIRST
	if index >= 0 and index < ITEM_KEYS.size(): return ITEM_KEYS[index]
	return DEFAULT_PATTERN

# --- recipes -----------------------------------------------------------------

# The dye-grid patterns are crafted in a table with the banner centred; the
# signature patterns are shapeless paper plus their item, as the source does.
# `key_to_item` maps a signature key to the Voxey item that stands for it.
static func key_item(key: String) -> int:
	var entry: Dictionary = pattern(key)
	if not entry.has("signature"): return 0
	match str(entry.signature):
		"BRICK_BLOCK": return Nodes.BRICKS
		"VINE": return Nodes.VINE
		"OXEYE_DAISY": return 5612
		"HEAD_CREEPER": return Heads.FLOOR+1
		"HEAD_WITHER_SKELETON": return Heads.FLOOR+4
		"PATTERN_GLOBE": return VillageContent.PATTERN_FIRST+6
		"PATTERN_PIGLIN": return VillageContent.PATTERN_FIRST+7
		"PATTERN_FLOW": return VillageContent.PATTERN_FIRST+9
		"PATTERN_GUSTER": return VillageContent.PATTERN_FIRST+8
		"GOLDEN_APPLE": return Nodes.GOLDEN_APPLE
	return 0

static func recipes(inv: Inventory) -> void:
	for key in ITEM_KEYS:
		var extra: int = key_item(key)
		if extra == 0: continue
		var index: int = ITEM_KEYS.find(key)
		inv._recipe(Nodes.title(VillageContent.PATTERN_FIRST+index),VillageContent.PATTERN_FIRST+index,1,[Nodes.PAPER,extra],2,"table")
		inv.recipes.back()["shapeless"] = true

# --- art ---------------------------------------------------------------------

# A banner's icon is its base colour with each layer drawn over it, which is what
# the source's texture builder composes from its pattern textures.
static func draw(img: Image, id: int, slot_color: int, layer_list: Array) -> void:
	var base: Color = Nodes.color(FIRST+clampi(slot_color,0,COLORS-1))
	img.fill_rect(Rect2i(2,1,12,14),base)
	img.fill_rect(Rect2i(2,1,12,2),base.darkened(0.2))
	for layer in layer_list:
		var key: String = str(layer.get("pattern",""))
		var shade: Color = Nodes.color(FIRST+clampi(int(layer.get("color",0)),0,COLORS-1))
		_paint_pattern(img,key,shade)

# Each pattern is drawn from its own grid where it has one, so the icon really
# shows the emblazoning rather than a generic mark.
static func _paint_pattern(img: Image, key: String, shade: Color) -> void:
	var cells: Array = grid(key)
	if cells.size() == 9:
		for i in 9:
			if cells[i] != DYE: continue
			var x: int = 2+(i%3)*4
			var y: int = 1+(i/3)*4
			img.fill_rect(Rect2i(x,y,4,4),shade)
		return
	# The special patterns draw a simple distinguishing mark.
	match key:
		"bricks": img.fill_rect(Rect2i(4,4,8,1),shade); img.fill_rect(Rect2i(4,7,8,1),shade)
		"creeper": img.fill_rect(Rect2i(5,4,2,2),shade); img.fill_rect(Rect2i(9,4,2,2),shade); img.fill_rect(Rect2i(7,8,3,3),shade)
		"flower": img.fill_rect(Rect2i(7,4,2,2),shade); img.fill_rect(Rect2i(5,8,6,2),shade)
		"curly_border": img.fill_rect(Rect2i(2,1,2,14),shade); img.fill_rect(Rect2i(12,1,2,14),shade)
		"skull": img.fill_rect(Rect2i(5,3,6,6),shade); img.fill_rect(Rect2i(6,10,4,2),shade)
		"globe": img.fill_rect(Rect2i(5,3,6,8),shade)
		"piglin": img.fill_rect(Rect2i(4,4,8,6),shade)
		"guster": img.fill_rect(Rect2i(5,5,6,4),shade)
		"flow": img.fill_rect(Rect2i(6,3,4,9),shade)
		_: img.fill_rect(Rect2i(6,5,4,5),shade)

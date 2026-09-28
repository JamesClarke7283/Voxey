class_name Frames
extends RefCounted

# Mineclonia ITEMS/mcl_itemframes/init.lua (`rotate_entity` at :96-106, the saved
# index applied by `update_entity` at :108-126, the right-click gate at :130-135,
# and `get_map_id` at :90-94), ITEMS/mcl_itemframes/register.lua:3-49 (the four
# registered frame forms) and ITEMS/REDSTONE/mcl_comparators/init.lua:113-119 with
# its measurement table at :156-159. GPL-3.0-or-later. Original GDScript using the
# source as a behaviour reference; no source model or texture is used.
#
# Voxey already had one item-frame node (`VillageContent.ITEM_FRAME`) whose item is
# taken and placed by `VillageSurvival.frame_item`. Two source behaviours were
# missing:
#
#  * **Rotation.** The source's `rotate_entity` spins the frame's item entity by
#    `0.25 * math.pi * (rot or 1) * (is_map + 1)` and stores an index that wraps at
#    eight. `update_entity` re-applies the stored index after every item change, so
#    the visual angle for index *i* is `i * 0.25 * pi * (is_map + 1)` — a filled map
#    turns in ninety-degree steps, everything else in forty-five. `is_map` is
#    `mcl_maps:id` being set on the stack, which in Voxey is a `FILLED_MAP` item
#    carrying `data.map.id`.
#  * **The frame forms.** `register.lua` registers four nodes: `frame`,
#    `glow_frame` (`object_properties = {glow = 15}`), `invisible_frame` and
#    `invisible_glow_frame` (both `drawtype = "airlike"`), and
#    `mcl_itemframes_compat` only aliases old names onto them. Voxey keeps one node
#    id, so a form is a saved string beside the frame's contents: `""`, `"glow"`,
#    `"invisible"` and `"invisible_glow"`. `GlowInk` is what moves a frame between
#    them, exactly as the source's only acquisition path for a glow frame is a
#    glow ink sac (`register.lua`:74-78).
#
# The one visual limitation is the frame *border*: Voxey meshes voxels by id alone
# (`BlockMesher` never sees station state), so an `invisible`/`invisible_glow`
# frame still draws its wooden border while its item draws normally. The item's
# glow and spin, which is what the form is about, are both drawn.

# Source index range: `meta:set_int("mcl_item_rotation", (...) % 8)`
# (init.lua:103). The comparator reads `index + 1` (mcl_comparators/init.lua:116),
# which is why a plain frame idles at zero.
const ROTATIONS = 8
# `0.25 * math.pi`, the source's per-step angle for an ordinary item.
const STEP = 0.25 * PI
const ROTATION_KEY = "frame_rotation"
const VARIANT_KEY = "frame_variant"
# The four registered forms, named after the source's node names
# (`mcl_itemframes:frame`, `:glow_frame`, `:invisible_frame`,
# `:invisible_glow_frame`).
const PLAIN = ""
const GLOW = "glow"
const INVISIBLE = "invisible"
const INVISIBLE_GLOW = "invisible_glow"
const VARIANTS = [PLAIN,GLOW,INVISIBLE,INVISIBLE_GLOW]

static func is_frame(id: int) -> bool:
	return id == VillageContent.ITEM_FRAME

# --- saved state --------------------------------------------------------------

# The form a frame is drawn and counted as. An unknown string (a hand-edited save,
# or a form this port does not have) falls back to the plain source frame.
static func variant_of(station: Dictionary) -> String:
	var value: Variant = station.get(VARIANT_KEY,PLAIN)
	if not value is String or not (value in VARIANTS): return PLAIN
	return str(value)

static func set_variant(station: Dictionary, variant: String) -> void:
	station[VARIANT_KEY] = variant if variant in VARIANTS else PLAIN

static func glow_of(station: Dictionary) -> bool:
	var variant: String = variant_of(station)
	return variant == GLOW or variant == INVISIBLE_GLOW

static func invisible(station: Dictionary) -> bool:
	var variant: String = variant_of(station)
	return variant == INVISIBLE or variant == INVISIBLE_GLOW

# The source stores the index with `% 8`, so a corrupt or negative saved value is
# read exactly the way the source's own arithmetic would read it.
static func rotation_of(station: Dictionary) -> int:
	var value: Variant = station.get(ROTATION_KEY,0)
	if not (value is int or value is float) or not is_finite(float(value)): return 0
	return posmod(int(value),ROTATIONS)

# The id in the frame's single source slot; 0 when the frame is empty.
static func held_id(station: Dictionary) -> int:
	var slots: Variant = station.get("slots",[])
	if not slots is Array or slots.is_empty() or not slots[0] is Dictionary: return 0
	return int(slots[0].get("id",0))

# The saved fields, in the shape Main allow-lists for a frame station, so an old
# save without them loads as the source's plain zero-indexed frame.
static func clean_state(raw: Dictionary) -> Dictionary:
	return {ROTATION_KEY:rotation_of(raw),VARIANT_KEY:variant_of(raw)}

# `Signs.station`/`Campfires.station`'s shape: fetch the station, then normalise the
# fields this module owns. A cell that does not hold a frame returns `{}` without
# creating a station, so a stale or wrong target cannot leave a 27-slot station
# behind in an ordinary cell.
static func station(world: VoxelWorld, p: Vector3i) -> Dictionary:
	if not is_frame(world.node_at(p)): return {}
	var state: Dictionary = world.get_station(p,"frame")
	state["kind"] = "frame"
	state[ROTATION_KEY] = rotation_of(state)
	state[VARIANT_KEY] = variant_of(state)
	return state

# --- geometry -----------------------------------------------------------------

# `get_map_id` (init.lua:90-94): a stack is a map when it carries `mcl_maps:id`,
# which in Voxey is the filled map's saved survey identity. `angle` only receives
# an id, so the filled map item is the test.
static func is_map(id: int) -> bool:
	return id == VillageContent.FILLED_MAP

# The visual angle of a frame holding `id` at saved index `index`:
# `0.25 * pi * index * (is_map + 1)`.
static func angle(id: int, index: int) -> float:
	return float(posmod(index,ROTATIONS))*STEP*(2.0 if is_map(id) else 1.0)

# `rotate_entity(pos)` with no explicit rotation: one step forward, then the
# comparator is told to re-measure. The source only reaches it when the frame's
# item stack is non-empty — an empty frame has no entity, and its right-click
# places the held item instead (`init.lua`:130-135).
static func rotate(game: Node3D, p: Vector3i) -> bool:
	if not is_frame(game.world.node_at(p)): return false
	var state: Dictionary = station(game.world,p)
	if held_id(state) == 0: return false
	state[ROTATION_KEY] = posmod(rotation_of(state)+1,ROTATIONS)
	if game.get("survival") != null: game.survival.refresh_displays()
	return true

# Main's `refresh_displays` calls this on the frame's item mesh: the source spins
# the item entity to the saved index about the frame's own axis and makes a glow
# form self-lit. The item material is duplicated before the glow is applied,
# because `ItemArt.material` hands out one shared cached material per id.
#
# A framed *block* item is drawn with `game.node_material`, the terrain shader,
# which has no per-instance emission to set, so a glow form is not visually
# self-lit for those items. The item's own tile already emits where the source
# says it does (lava, glowstone, sea lantern), and the rotation applies either way.
static func apply_display(mesh: MeshInstance3D, id: int, state: Dictionary) -> void:
	if id == 0: return
	mesh.rotation.z = angle(id,rotation_of(state))
	if not glow_of(state) or not mesh.material_override is StandardMaterial3D: return
	var material: StandardMaterial3D = (mesh.material_override as StandardMaterial3D).duplicate()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material

# --- redstone -----------------------------------------------------------------

# `measure_item_frames`: the saved rotation plus one while the frame holds
# something, and nothing at all when it is empty. The source does **not** apply the
# map's doubled visual step here — the signal is the index either way.
static func comparator_signal(station: Dictionary) -> int:
	return rotation_of(station)+1 if held_id(station) != 0 else 0

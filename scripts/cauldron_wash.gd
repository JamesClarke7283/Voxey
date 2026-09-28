class_name CauldronWash
extends RefCounted

# Mineclonia ITEMS/mcl_armor/leather.lua and ITEMS/mcl_banners/init.lua,
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference.
#
# Two item-on-cauldron rules live here because they are one interaction: an
# item that carries a removable colour is used on a water cauldron and spends one
# portion of its water.
#
#   * `mcl_armor.colorize_leather_armor` (leather.lua:26) tints a leather piece
#     with a dye. A second dye does not replace the first: the two colours are
#     **averaged channel-wise** by `calculate_color` (leather.lua:18), which
#     applies `av(a, b) = (a + b) / 2` (leather.lua:14) to r, g and b separately.
#     The tint is stored on the item (leather.lua:42) and read back as the
#     starting colour of the next dye (leather.lua:33,37).
#   * The shapeless dye recipe (leather.lua:107-115) is registered once per
#     leather element with `recipe = {itemname, "group:dye"}`: one leather piece
#     plus **any** dye. `colorizing_crafting` (leather.lua:126) is the craft
#     prediction, and it refuses a grid with two leather pieces or two dyes
#     (leather.lua:136-143) before dyeing the one piece it found (leather.lua:145).
#   * `mcl_armor.wash_leather_armor` (leather.lua:51) clears the tint, which is
#     the leather `on_place` on a water cauldron (leather.lua:80-90).
#   * A banner's `on_place` (mcl_banners/init.lua:471) removes its **topmost**
#     layer with `table.remove` (init.lua:486) — the last element of the ordered
#     layer list, which is where the layer is appended when a pattern is applied
#     (`mcl_banners/patterncraft.lua:401`).
#
# The colour channels are the source's own: `color_string_to_table`
# (leather.lua:6-12) reads hex digits 2..7 of the "#RRGGBBAA" string that
# `colorspec_to_colorstring` builds (leather.lua:31,40), so alpha never takes
# part in the average. Voxey packs the same three channels into one 24-bit
# integer under the item's `data`, which is what `Inventory.clean_slot` clamps
# and preserves so a dyed piece survives a save.
#
# The source has no colour table of its own for dyes here — it looks the dye's
# `rgb` up in `mcl_dyes.colors` (`mcl_dyes/init.lua:13-133`: white is #d0d6d7,
# red #912222, and so on). Voxey already colours every dye block, so the
# averaged arithmetic is fed from that block colour through `Nodes.color`, which
# keeps one dye colour table in the project rather than a second one here.
#
# One deliberate divergence: the source spends the portion **before** it looks at
# what it is washing (`mcl_cauldrons.add_level(pointed_thing.under, -1)` at
# leather.lua:83 and mcl_banners/init.lua:482 both run first), so undyed leather
# and a plain banner waste a portion. Washing here is gated on `can_wash` so a
# cauldron is only spent when something is actually removed.

# The source's metadata key is `mcl_armor:color` (leather.lua:42), a
# "#RRGGBBAA" string. Voxey stores the three colour channels as one integer.
const DATA_KEY = "color"

# --- colour arithmetic -------------------------------------------------------

# `av(a, b)` (leather.lua:14) returns a Lua float; the byte is then truncated
# when the colourstring is rebuilt (`colorspec_to_colorstring` writes `%02X` of
# the stored channel, leather.lua:31,40). Truncation of the channel sum, not
# rounding, is therefore the source's own result.
static func average(first: int, last: int) -> int:
	return int((first+last)/2.0)

# `calculate_color` (leather.lua:18): the same average on each channel.
static func mixed(first: int, last: int) -> int:
	var red: int = average((first>>16)&0xff,(last>>16)&0xff)
	var green: int = average((first>>8)&0xff,(last>>8)&0xff)
	var blue: int = average(first&0xff,last&0xff)
	return (red<<16)|(green<<8)|blue

static func packed(color: Color) -> int:
	return (color.r8<<16)|(color.g8<<8)|color.b8

static func unpacked(value: int) -> Color:
	return Color8((value>>16)&0xff,(value>>8)&0xff,value&0xff)

# --- leather -----------------------------------------------------------------

static func is_leather_armor(id: int) -> bool:
	# `group:armor_leather` (leather.lua:27): leather is armour material zero.
	# The range test also excludes the elytra, which `Nodes.armor_material`
	# reports as material zero because it occupies the leather slot of the array.
	return id >= Nodes.ARMOR_BASE and id < Nodes.ARMOR_END and Nodes.armor_material(id) == 0

# A dye entry carries its own `dye` colour name and the `dye` family in
# `VillageContent.DATA`; both are checked so no other item is ever a dye.
static func is_dye(id: int) -> bool:
	var entry: Dictionary = VillageContent.DATA.get(id,{})
	return entry.get("family","") == "dye" and entry.has("dye")

# The source reads `mcl_dyes.colors[...].rgb` for the held dye. Voxey has one dye
# colour table — the dye block's — so the same arithmetic runs on that colour.
# A non-dye returns black, which `is_dye` is the guard against.
static func dye_color_for(id: int) -> Color:
	return Nodes.color(id) if is_dye(id) else Color.BLACK

# The stored tint, or black when the piece has never been dyed. Black is not a
# detectable dye value, so `has_tint` is the test for "dyed", never this.
static func color_of(slot: Dictionary) -> Color:
	if not (slot.get("data") is Dictionary): return Color.BLACK
	var stored: Variant = slot.data.get(DATA_KEY)
	return Color.BLACK if stored == null else unpacked(int(stored))

static func has_tint(slot: Dictionary) -> bool:
	return (slot.get("data") is Dictionary) and slot.data.has(DATA_KEY)

# `colorize_leather_armor` (leather.lua:26): the first dye is stored as it is,
# and every later dye is averaged with what is already there. A dye equal to the
# stored colour is the source's early return (leather.lua:34) — and the average of
# an equal pair is that same colour, so the two agree.
static func tint(slot: Dictionary, dye: Color) -> void:
	if not is_leather_armor(int(slot.get("id",0))): return
	var incoming: int = packed(dye)
	if not (slot.get("data") is Dictionary): slot["data"] = {}
	var stored: Variant = slot.data.get(DATA_KEY)
	if stored != null and int(stored) == incoming: return
	slot.data[DATA_KEY] = incoming if stored == null else mixed(int(stored),incoming)

# `wash_leather_armor` (leather.lua:51) clears the colour only; every other piece
# of metadata on the item, and its wear, stay where they are.
static func clear_tint(slot: Dictionary) -> void:
	if not (slot.get("data") is Dictionary): return
	slot.data.erase(DATA_KEY)
	if slot.data.is_empty(): slot.erase("data")

# --- crafting ----------------------------------------------------------------

# The source's craft prediction (leather.lua:126-146): exactly one leather piece
# and exactly one dye, nothing else. The result is that same piece with the new
# tint, so wear and every other metadata value travel with it.
static func apply_craft(ingredients: Array) -> Dictionary:
	var piece: Dictionary = {}
	var dye: int = 0
	for slot in ingredients:
		var id: int = int(slot.get("id",0))
		if id == 0: continue
		if is_leather_armor(id):
			if not piece.is_empty(): return {}
			piece = slot
		elif is_dye(id):
			if dye != 0: return {}
			dye = id
		else: return {}
	if piece.is_empty() or dye == 0: return {}
	var result: Dictionary = {"id":int(piece.id),"count":1,"wear":int(piece.get("wear",0))}
	if piece.get("data") is Dictionary: result["data"] = piece.data.duplicate(true)
	tint(result,dye_color_for(dye))
	return result

# One shapeless recipe per leather piece and dye, in the layout
# `Inventory._shapeless` takes. The source registers a single `group:dye` recipe
# per element (leather.lua:107-115); Voxey's matcher compares exact ids, so the
# group is expanded into the sixteen dyes `VillageContent.DATA` registers.
static func recipe_entries() -> Array:
	var result: Array = []
	for piece in 4:
		var id: int = Nodes.armor_id(0,piece)
		for dye in range(VillageContent.DYE_WHITE,VillageContent.DYE_BROWN+1):
			if not is_dye(dye): continue
			result.append([Nodes.title(id),id,1,[id,dye]])
	return result

# --- washing -----------------------------------------------------------------

# What a cauldron can take off an item: a dyed leather piece's colour, or an
# emblazoned banner's topmost layer.
static func can_wash(id: int, slot: Dictionary) -> bool:
	if is_leather_armor(id): return has_tint(slot)
	if Banners.is_banner(id): return not Banners.layers(slot).is_empty()
	return false

# The item's `on_place` on a water cauldron: one portion is spent and the colour
# or the topmost layer is removed. `p` is the cauldron cell, guarded exactly as
# `Cauldrons.use` guards it (cauldrons.gd:132), so a stale station dictionary
# cannot spend water for a cauldron that is no longer there.
static func wash(game: Node3D, p: Vector3i, station: Dictionary, slot: Dictionary) -> bool:
	if not can_wash(int(slot.get("id",0)),slot): return false
	if Cauldrons.level(station) == 0 or Cauldrons.liquid(station) != "water": return false
	if game.world.node_at(p) != VillageContent.CAULDRON: return false
	Cauldrons.set_contents(station,Cauldrons.level(station)-1,"water")
	if is_leather_armor(int(slot.id)):
		clear_tint(slot)
	else:
		# `table.remove` (mcl_banners/init.lua:486) drops the last layer, which is
		# the newest one. `set_layers` erases the key once the list is empty.
		var list: Array = Banners.layers(slot).duplicate(true)
		list.remove_at(list.size()-1)
		Banners.set_layers(slot,list)
	# The source plays a bottle pour here (leather.lua:86). Voxey's catalogue has
	# no pour, and the cauldron module already sounds a liquid change as "place".
	game.sound("place")
	game.survival.refresh_displays()
	return true

# PARENT WIRING — every line below is for Main to add; no shared file was edited
# while writing this module. Line numbers are as the repo reads now and will drift
# as siblings land, so each entry names its anchor too.
#
# 1. tests/lifecycle_runner.gd — done by this task: `"cauldron_wash"` is already
#    appended to the default `checks` array (lifecycle_runner.gd:28).
#
# 2. scripts/inventory.gd `craft_output_data`, which now begins at
#    inventory.gd:361 with these three lines:
#    	if id == VillageContent.SUSPICIOUS_STEW: return FoodFeatures.craft_data(ingredients)
#    	if id == VillageContent.FILLED_MAP: return ExplorationMaps.craft_output_data(ingredients)
#    	return PortableStorage.output_data(id,ingredients) if ...
#    Insert one line after the FILLED_MAP line:
#
#    	if CauldronWash.is_leather_armor(id): return CauldronWash.apply_craft(ingredients).get("data",{})
#
#    The armour recipes at inventory.gd:28 feed ingots, not a dye, so
#    `apply_craft` returns `{}` there and `.get("data",{})` is `{}` — plain armour
#    crafts untinted, exactly as before. `Inventory.craft` and
#    `take_grid_result` both build the output stack as `{"id","count","wear":0}`
#    and only merge `craft_output_data` into `data`, so the wear `apply_craft`
#    carries from the source piece is not applied by the grid path; the source
#    keeps the item's own wear (leather.lua:26 returns the same itemstack). This
#    is the one behaviour the shared craft path cannot express — it would take an
#    extra `wear` key in `craft_output_data`'s contract to preserve it.
#
# 3. scripts/inventory.gd `_init`: beside the other feature recipe calls, after
#    `Fishing.recipes(self)` (inventory.gd:149):
#
#    	for entry in CauldronWash.recipe_entries(): _shapeless(entry[0],entry[1],entry[2],entry[3])
#
#    This is 4 leather pieces x 16 dyes = 64 shapeless entries: the source's one
#    `group:dye` recipe per element (leather.lua:107-115) expanded to exact ids,
#    because `Inventory.matching_recipe` compares ids and cannot express a group.
#
# 4. scripts/inventory.gd `clean_slot`: already added by Main — `color` is
#    clamped 0..0xffffff (inventory.gd:392). No line is needed; the checks assert
#    that clamp and its JSON round trip.
#
# 5. scripts/village_survival.gd `use`, the cauldron branch that currently reads
#    (village_survival.gd:103-104):
#    	if not target.is_empty() and target.id == VillageContent.CAULDRON and not Input.is_physical_key_pressed(KEY_CTRL):
#    		return Cauldrons.use(game,target.pos)
#    Replace the body with:
#
#    	if not target.is_empty() and target.id == VillageContent.CAULDRON and not Input.is_physical_key_pressed(KEY_CTRL):
#    		var cauldron: Dictionary = game.world.get_station(target.pos,"cauldron")
#    		if CauldronWash.wash(game,target.pos,cauldron,game.inventory.held()):
#    			game.inventory.changed.emit(); game.toast("Washed.")
#    			return true
#    		return Cauldrons.use(game,target.pos)
#
#    "Washed." is the source's own message (leather.lua:164). Washing must come
#    first: `Cauldrons.use` would otherwise bottle or bucket the held item, and it
#    also returns `true` for any cauldron click. The held slot is mutated in place,
#    so `changed.emit()` is what redraws it.
#
# 6. Art. `ItemArt.texture` caches one sprite per id, so a tint cannot live there;
#    the icon must modulate the sprite with the slot's colour:
#      * scripts/item_icon.gd: add `var tint: Color = Color.WHITE` beside
#        `var enchanted` (item_icon.gd:16) with the same setter pattern (assign in
#        the setter, call `queue_redraw()` when it changes), and pass it as the
#        final `modulate` argument of the two `draw_texture_rect` calls
#        (item_icon.gd:44 and :62 — the second is the branch leather armour takes,
#        since `Nodes.placeable` is false for armour).
#      * scripts/hud.gd `_update_icon` (hud.gd:804): after
#        `icon.item_id=slot.id; ...` (hud.gd:806) add
#         	icon.tint = CauldronWash.color_of(slot) if CauldronWash.is_leather_armor(slot.id) else Color.WHITE
#        `Nodes.color` gives leather its brown base (nodes.gd:492), so modulating
#        that sprite by the stored tint shows the dye.
#      * Optional tooltip, the source's own snippet (leather.lua:93-101): after the
#        `custom_name` line (hud.gd:807) add
#         	if CauldronWash.is_leather_armor(slot.id) and CauldronWash.has_tint(slot): description += "\nDyed: "+CauldronWash.color_of(slot).to_html(false)

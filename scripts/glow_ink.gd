class_name GlowInk
extends RefCounted

# Mineclonia ITEMS/mcl_signs/init.lua:487-497 (the sign's glow-ink right-click) and
# ITEMS/mcl_itemframes/register.lua:3-49 with :74-78 (the four frame forms and the
# glow-ink recipe that produces the glow one). GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference; no source texture is used.
#
# Voxey had no consumer for the glow ink sac at all: `village_content.gd`:118-121
# registers the item and `aquatic_mobs.gd`:90-92 drops it, but the one helper that
# would use it — `Signs.apply_glow` — was unreachable, and its own comment claimed
# no glow-ink item existed. This module is that consumer.
#
# Source rules reproduced:
#
#  * **Signs.** `sign_tpl.on_rightclick` checks the held stack's name first. A glow
#    ink sac turns black text grey (`#7e7e7e`, because "#000000 doesn't glow in the
#    dark"), sets `glow = "true"`, and consumes one sac outside creative mode. The
#    check is `itemstack:get_name() == "mcl_mobitems:glow_ink_sac"`, so a sac applied
#    to an already-glowing sign still consumes. That whole effect is
#    `Signs.apply_glow`, which this module finally calls.
#  * **Item frames.** `register.lua` registers four forms — `frame`, `glow_frame`
#    (`object_properties = {glow = 15}`), `invisible_frame` and
#    `invisible_glow_frame` (both `drawtype = "airlike"`) — and the **only**
#    acquisition path in the source is the shapeless glow-ink recipe
#    (`register.lua`:74-78), which produces `glow_frame`. The two invisible forms
#    have no recipe, structure or LBM that yields them, so in the source they exist
#    only in creative inventories. Voxey keeps one frame node id, so a form is a
#    saved flag (`Frames.VARIANT_KEY`) rather than a node, and one sac advances the
#    frame along the source's own registration order —
#    `frame` → `glow_frame` → `invisible_frame` → `invisible_glow_frame` — wrapping
#    at the end. That is the cheapest representation that reaches all four
#    registered forms with the single consumable the source ties to frames.
#
# `apply` is the whole use, so the caller's dispatch is one line.

static func is_glow_ink(id: int) -> bool:
	return id == VillageContent.GLOW_INK_SAC

# The frame form this station is in: `Frames.PLAIN`, `Frames.GLOW`,
# `Frames.INVISIBLE` or `Frames.INVISIBLE_GLOW`.
static func frame_variant(station: Dictionary) -> String:
	return Frames.variant_of(station)

# One sac applied to a target: a sign starts glowing, or a frame moves one step
# along the source's registration order. Returns whether anything happened, which
# is what decides consumption.
static func apply(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or not is_glow_ink(game.inventory.held().id) or game.target_mob() != null: return false
	var p: Vector3i = target.get("pos",Vector3i.ZERO)
	var id: int = int(target.get("id",0))
	if Signs.is_sign(id):
		if not Signs.apply_glow(game.world,p): return false
		consume(game); return true
	# The node is the authority, not the reported target id, so a stale target
	# cannot write frame state into an ordinary cell.
	if not Frames.is_frame(game.world.node_at(p)): return false
	# An empty frame takes the held item instead of changing form — the source's
	# right-click reaches `rotate_entity`/the inventory path for a frame with no
	# item, and glow ink is not accepted there.
	var state: Dictionary = Frames.station(game.world,p)
	if Frames.held_id(state) == 0: return false
	Frames.set_variant(state,next_variant(Frames.variant_of(state)))
	if game.get("survival") != null: game.survival.refresh_displays()
	consume(game); return true

# The source's registration order, wrapping at the end.
static func next_variant(variant: String) -> String:
	var order: Array = Frames.VARIANTS
	var index: int = order.find(variant)
	return str(order[(index+1)%order.size()]) if index >= 0 else str(order[0])

static func consume(game: Node3D) -> void:
	if game.gamemode != "creative": game.inventory.consume_selected()

# PARENT WIRING — every line below is for Main to add; no shared file was edited
# while writing these two modules. Line numbers are as the repo reads now and will
# drift as siblings land, so each entry names its anchor too.
#
# 1. tests/lifecycle_runner.gd — done by this task: `"glow_ink"` is appended to the
#    default `checks` array (after "death_message"), and every existing entry is
#    kept.
#
# 2. scripts/signs.gd `use` — the sign half. `Signs.use` runs **before**
#    `game.survival.use()` in the player's chain (`player.gd`:584 vs :590) and
#    returns true for every sign click, so a glow-ink call placed only in
#    `village_survival.gd` would never see a sign. The line goes after the sign
#    guard at :125 and before the dye test at :127:
#
#    	if GlowInk.is_glow_ink(game.inventory.held().id):
#    		if GlowInk.apply(game,target): return true
#
#    `GlowInk.apply` itself consumes the sac in survival and calls `apply_glow`,
#    so no second consumption path is needed. Placement still works: the branch is
#    below the `not is_sign(id)` guard, so it only runs on an actual sign click.
#
# 3. scripts/village_survival.gd `use` — the frame half. The `ITEM_FRAME` branch at
#    :187-188 takes the framed item out; a filled frame holding glow ink must change
#    form instead, so the test goes immediately **before** it:
#
#    	if GlowInk.is_glow_ink(held) and GlowInk.apply(game,target): return true
#    	if id == VillageContent.ITEM_FRAME:
#    		frame_item(p); return true
#
#    `apply` refuses a target whose node is not a sign or a frame and an empty hand,
#    and a sign never reaches here (step 2 already returned), so this line only ever
#    acts on a frame.
#
# 4. scripts/village_survival.gd `frame_item` — the rotation branch. The source's
#    `on_rightclick` rotates *before* the take path when the frame holds an item
#    (`init.lua`:130-135), so this is the first statement of the function, replacing
#    nothing:
#
#    	# `mcl_itemframes/init.lua`:130-135 — a filled frame turns its item.
#    	if Frames.rotate(game,p): return
#
#    Note this makes `frame_item` on a filled frame rotate rather than take. The
#    source is explicit that the rotation wins, and the item is still retrievable by
#    breaking the frame (`piston_push.gd`:74-81 already drops the frame and its
#    contents). If Main prefers Voxey's existing take-to-empty behaviour as the
#    primary click, the alternative is to rotate only on sneak:
#
#    	if not Signs.sneaking(game) and Frames.rotate(game,p): return
#
#    `tests/glow_ink_checks.gd` calls `Frames.rotate` directly, so both choices
#    pass the checks; only the click priority differs.
#
# 5. scripts/village_survival.gd `refresh_displays` — the frame display branch at
#    :630-639. The item mesh is built there; the source spins that entity to the
#    saved index and makes a glow form self-lit, so the branch needs
#    `Frames.station(...)` for the state and one call before the mesh is added:
#
#    	elif station.kind == "frame" and station.slots[0].id != 0 and game.world.node_at(p) == VillageContent.ITEM_FRAME:
#    		var frame_state: Dictionary = Frames.station(game.world,p)
#    		var id: int = station.slots[0].id
#    		if id == VillageContent.FILLED_MAP:
#    			mesh.free(); mesh = game.maps.frame_model(station.slots[0]); mesh.position = Vector3(p)+Vector3(0.5,0.5,-0.025)
#    		else:
#    			mesh.mesh = game.node_mesh(id) if Nodes.placeable(id) else ItemArt.mesh(id)
#    			mesh.material_override = game.node_material if Nodes.placeable(id) else ItemArt.material(id)
#    			mesh.scale = Vector3.ONE*0.4; mesh.position = Vector3(p)+Vector3(0.5,0.5,-0.02)
#    			if Nodes.placeable(id): mesh.position -= Vector3.ONE*0.2
#    		Frames.apply_display(mesh,id,frame_state)
#
#    `apply_display` duplicates the shared `ItemArt` material before making a glow
#    frame unshaded, so one glowing frame does not light every item of that id.
#
# 5. scripts/redstone_circuit.gd `container_signal` — a comparator beside a frame
#    must read its rotation. Two edits:
#
#    a. `step`, at :259 — the rear read is gated on the neighbour being a
#       measurable block. The frame id joins that bracket list, which is the whole
#       edit:
#
#    				if id == Nodes.COMPARATOR and (world.node_at(p-d) in CONTAINERS or PortableStorage.is_shulker(world.node_at(p-d)) or world.node_at(p-d) in [Jukeboxes.ID,VillageContent.COMPOSTER,VillageContent.CAULDRON,VillageContent.ITEM_FRAME] or FoodFeatures.is_cake(world.node_at(p-d)) or Beehives.is_hive(world.node_at(p-d)) or Copper.is_bulb(world.node_at(p-d))): rear = container_signal(p-d)
#
#       Without this the comparator never asks the frame for a signal, so the
#       `container_signal` case below would be dead code.
#
#    b. `container_signal`, beside the composter line at :361:
#
#    	if Frames.is_frame(world.node_at(p)): return Frames.comparator_signal(Frames.station(world,p))
#
#    `container()` at :369-372 must NOT be taught about frames: the source's frame
#    node has no inventory reachable by a hopper (`allow_metadata_inventory_put/take`
#    all return 0, init.lua:38-40), and `measure_item_frames` is a comparator-only
#    measurement. Leaving `container()` alone keeps a hopper from pulling the framed
#    item.
#
# 6. scripts/game.gd `_clean_station_storage` (:1126-1131) — the frame's saved fields
#    already survive a save because the whole station dictionary round-trips through
#    JSON and `clean_state` normalises on read (`Frames.station` and
#    `Frames.clean_state`), so no line is needed. If Main wants the values clamped at
#    save time, one line beside the slot loop does it:
#
#    	if station_state.get("kind","") == "frame": station_state.merge(Frames.clean_state(station_state),true)
#
#    `tests/glow_ink_checks.gd` asserts the round trip through a real
#    `save_game`/`load_world_data` and through `Inventory.clean_slot`, so it passes
#    with or without that optional line.
#
# No content id, recipe, art entry or registry append is needed: `ITEM_FRAME` and
# `GLOW_INK_SAC` both already exist, and the frame's four forms are station state
# rather than four nodes.
#
# 7. scripts/signs.gd:112-113 — the comment above `apply_glow`
#
#    	# Source glow affects the text sprite, not neighboring light. No glow-ink item
#    	# exists in Voxey yet, so gameplay does not call this helper without acquisition.
#
#    is now wrong: `VillageContent.GLOW_INK_SAC` exists (village_content.gd:118-121)
#    and `GlowInk.apply` calls this helper. Main should replace those two lines with:
#
#    	# Source glow affects the text sprite, not neighboring light. `Signs.use`
#    	# applies it when a glow ink sac is held (mcl_signs/init.lua:487-497).
#
#    `apply_glow` itself is unchanged and correct.

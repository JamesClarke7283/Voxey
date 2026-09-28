class_name GrindstoneRepair
extends RefCounted

# Mineclonia ITEMS/mcl_grindstone/init.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# The grindstone's **repair** half. Voxey already disenchants one item at a time
# in `VillageSurvival._equipment_work`; the source's other half combines two
# damaged pieces of the same item into one:
#
# - `calculate_repair` (:133-137) sums the two pieces' *health* and adds a 5%
#   bonus. The bonus multiplies the **second** term only, so which input is
#   which is observable: `(MAX_WEAR - dur1) + (MAX_WEAR - dur2) * 1.05`.
# - The combine condition (:139-144) is "both are `type == "tool"` and their
#   enchant-name-stripped names match". In Minetopia armour and the elytra are
#   registered with `core.register_tool` too, so "tool" covers armour and the
#   elytra; in Voxey that is `Nodes.durability(id) > 0`. Names are compared with
#   the `_enchanted` suffix removed, so two differently-enchanted pieces still
#   combine, which Voxey's id comparison expresses exactly.
# - `create_new_item` (:41-53) builds a **fresh** item: count 1, the new wear,
#   and only the first input's `name` metadata. Enchantments, trims and the
#   anvil's prior-work penalty are not carried over — the curses are re-applied
#   afterwards by `transfer_curse` (:56-64), called for both inputs (:142-143),
#   which is what the node's own help text means by "if both items have a
#   different curse the curses will be combined" (:178).
# - `calculate_xp` (:67-77) pays `math.random(7, 13) * level` per **non-curse**
#   enchantment, and the take handler pays it for *both* inputs when both slots
#   were occupied (:265), or for the single input on the disenchant path
#   (:272, :276). Voxey's flat three points were a simplification of exactly
#   this, so `xp_for` serves both halves.
#
# **Wear conversion.** The source stores wear on one fixed 0..65535 scale where
# `MAX_WEAR` is the fully worn value; Voxey stores `slot.wear` in the item's own
# units, with `Nodes.durability(id)` the value at which `Inventory.damage_tool`
# destroys the item. `MAX_WEAR - wear` (the source's health) therefore becomes
# `span - wear`, and the one clamp in the formula moves with it. The arithmetic
# is otherwise the source's own expression, evaluated in doubles and truncated to
# an integer afterwards, because the source hands `set_wear` a fractional number
# and the engine stores an integer `u16` wear.
#
# **The output cap.** The source clamps the result to `MAX_WEAR`. Voxey's
# `Nodes.durability(id)` *is* that value, but sitting exactly on it is a destroyed
# item, so the cap is `span - 1`, the last usable wear (the elytra is already
# treated that way at `player.gd:1015`). No pair of damaged pieces can reach it:
# a piece with even one point of health left lands at least one wear below.

# The source's `MAX_WEAR` (`init.lua:7`) is 65535 and plays the role Voxey gives
# `Nodes.durability(id)`; no code here needs it, since every `MAX_WEAR` in the
# source's formulas is the span of the item being repaired.
# `calculate_repair`'s "Grindstone gives a 5% bonus to durability" (:134).
const BONUS = 1.05
# `calculate_xp`'s "Add a bit of uniform randomisation": `math.random(7, 13)`.
const XP_LOW = 7
const XP_HIGH = 13

# `calculate_xp`: `rng.randi_range` when a seeded generator is supplied, the
# global generator otherwise, as the project's other ports do.
static func roll(rng: RandomNumberGenerator, low: int, high: int) -> int:
	return rng.randi_range(low,high) if rng != null else randi_range(low,high)

# `def1.type == "tool" and def2.type == "tool" and name1 == name2`, with the
# source's stripped-name comparison reduced to an id comparison because Voxey
# keeps enchantments in metadata rather than in the item name. The source does
# not test the wear here; requiring both pieces to be damaged is this project's
# rule for its stations (`VillageSurvival._equipment_work`: "This item needs no
# repair"), and a piece at full durability has nothing to contribute.
static func compatible(a: Dictionary, b: Dictionary) -> bool:
	var id: int = int(a.get("id",0))
	if id == 0 or Nodes.migrate(id) != Nodes.migrate(int(b.get("id",0))): return false
	if Nodes.durability(Nodes.migrate(id)) <= 0: return false
	return int(a.get("wear",0)) > 0 and int(b.get("wear",0)) > 0

# `calculate_repair(dur1, dur2)`: the health of both pieces plus the 5% bonus on
# the second, clamped and truncated into a wear in `0 .. span - 1`.
static func repair_wear(wear1: int, wear2: int, span: int) -> int:
	if span <= 0: return 0
	var health: float = float(span-wear1)+float(span-wear2)*BONUS
	return clampi(int(float(span)-health),0,span-1)

# The source's combine: a fresh stack of `a`'s item at the combined wear, with
# `a`'s name, every curse from both inputs and no ordinary enchantment. Returns
# `{}` when the two pieces are not compatible.
#
# `rng` keeps the caller's signature; the source's wear arithmetic draws no
# random numbers, so it is unused.
static func combine(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	if not compatible(a,b): return {}
	var id: int = Nodes.migrate(int(a.get("id",0)))
	var result: Dictionary = {"id":id,"count":1,"wear":repair_wear(int(a.get("wear",0)),int(b.get("wear",0)),Nodes.durability(id))}
	var data: Dictionary = {}
	# `create_new_item` copies `name` from the **first** input only (:51).
	var label: String = str(a.get("data",{}).get("custom_name",""))
	if not label.is_empty(): data["custom_name"] = NameTags.bounded(label,50)
	var curses: Dictionary = {}
	for slot in [a,b]:
		var enchants: Dictionary = slot.get("data",{}).get("enchantments",{})
		for name in enchants:
			if bool(Enchantments.DATA.get(name,{}).get("curse",false)): curses[name] = int(enchants[name])
	if not curses.is_empty(): data["enchantments"] = curses
	if not data.is_empty(): result["data"] = data
	return result

# `calculate_xp(stack)`: seven to thirteen points per level of every non-curse
# enchantment stored on the piece. A name the enchantment table does not know is
# not a curse, so it pays, exactly as `mcl_enchanting.is_curse` returning nil
# does in the source.
static func xp_for(slot: Dictionary, rng: RandomNumberGenerator = null) -> int:
	var xp: int = 0
	var enchants: Dictionary = slot.get("data",{}).get("enchantments",{})
	for name in enchants:
		var level: int = int(enchants[name])
		if level > 0 and not bool(Enchantments.DATA.get(name,{}).get("curse",false)): xp += roll(rng,XP_LOW,XP_HIGH)*level
	return xp

# The whole operation on two live inventory slots: both pieces are consumed, the
# first becomes the repaired piece and the player is paid the sacrificed pair's
# enchantment XP (:265). The slots must be the bag's own entries — GDScript
# dictionaries are reference types, so the writes land in the inventory.
static func use(game: Node3D, first: Dictionary, second: Dictionary) -> bool:
	# The source's two inputs are two slots by construction; the same slot
	# offered twice would consume itself and erase its own result.
	if is_same(first,second) or not compatible(first,second): return false
	var result: Dictionary = combine(first,second)
	if result.is_empty(): return false
	# XP is read from the pieces while they still carry their enchantments, and
	# paid for both of them, which is the source's own order (:265).
	var xp: int = xp_for(first)+xp_for(second)
	if xp > 0: XpOrbs.throw_xp(game,game.player.position+Vector3.UP,xp)
	second.count = int(second.count)-1
	if int(second.count) <= 0:
		second.clear(); second.merge({"id":0,"count":0,"wear":0})
	first.clear(); first.merge(result)
	game.inventory.changed.emit()
	return true

# PARENT WIRING — the parent owns these central files. Exact lines:
#
# 1. `scripts/village_survival.gd` `_equipment_work` (currently line 436), the
#    `GRINDSTONE` branch. Insert the repair half **before** the existing
#    enchantment test, so a damaged pair repairs even with no enchantments, and
#    replace the flat `game.experience += 3` with the source's XP:
#
#        if device == VillageContent.GRINDSTONE:
#            # `mcl_grindstone/init.lua:139-144`: two damaged pieces of the same
#            # item combine, paying XP for both (`:265`). The screen shows one
#            # item at a time, so the partner is whatever else is carried.
#            for partner_index in game.inventory.slots.size():
#                if partner_index == index: continue
#                if GrindstoneRepair.use(game,slot,game.inventory.slots[partner_index]): return true
#            var xp: int = GrindstoneRepair.xp_for(slot)
#            if slot.get("data",{}).get("enchantments",{}).is_empty(): game.toast("This item has no enchantments."); return false
#            var kept: Dictionary = {}
#            for enchant in slot.data.enchantments:
#                if Enchantments.DATA.get(enchant,{}).get("curse",false): kept[enchant] = slot.data.enchantments[enchant]
#            if kept == slot.data.enchantments: game.toast("Curses cannot be removed by a grindstone."); return false
#            if kept.is_empty(): slot.data.erase("enchantments")
#            else: slot.data.enchantments = kept
#            if slot.id == VillageContent.ENCHANTED_BOOK and kept.is_empty(): slot.id = Nodes.BOOK
#            if slot.data.is_empty(): slot.erase("data")
#            game.experience += float(xp); game.inventory.changed.emit(); return true
#
#    (`xp` must be read before the enchantments are erased. The source pays per
#    item taken, `init.lua:272`, 276; this branch still works on one slot in
#    place, which is how Voxey's whole grindstone branch already behaves for a
#    stack of enchanted books.)
#
# 2. Optional, `show_station` line 337 — say what the grindstone now does:
#
#        var description: String = "Repair with a matching damaged piece, or remove enchantments" if id == VillageContent.GRINDSTONE else ("Apply first compatible enchanted book · 1 XP level" if id == VillageContent.ANVIL else "Repair 25% · 1 matching material")
#
# 3. `scripts/inventory.gd` `clean_slot` — **no line is needed**. The result
#    writes only `custom_name` and `enchantments`, and both are already in the
#    metadata allow-list (lines 380 and 405).

# Leather dyeing and cauldron washing

Voxey follows `ITEMS/mcl_armor/leather.lua`:17-45 and :85-130 in the supplied
Mineclonia checkout. The implementation is original GDScript using the source as a
behavioural reference.

## Dyeing with colour averaging

A leather piece plus one dye, shapelessly, tints the piece. A **second** dye
averages the two colours channel-wise — `calculate_color` is `av(a,b) = (a+b)/2` in
0..255 per channel — and the source stores the result as a colour string in the
item's metadata.

`scripts/cauldron_wash.gd` stores the tint as a packed int RGB under `data.color`
and reproduces the truncating average (the source writes `%02X` of a Lua float, so
it truncates rather than rounds). The first dye sets the dye's own colour;
re-applying the same colour is a no-op, as the source's early return says.

The tint is per **item**, so it has to travel with the stack: `Inventory.clean_slot`
now allow-lists `color`, `ItemIcon` gained a `tint` that multiplies the item's own
artwork (which is what the source's `inventory_image ^ [multiply:<colour>]` does),
and the slot tooltip names the hex value.

Two adaptations are recorded in the module header:

- The dye colour is `Nodes.color(dye_id)` — the dye **block's** own colour — where
  the source uses `mcl_dyes`' separate hex table. The names and the averaging rule
  are identical; only the source of the starting colour differs.
- **Washing is gated on there being something to wash.** The source spends a
  cauldron portion before checking, so undyed leather and a plain banner waste
  water. Here one level is only spent when a tint or a layer is actually removed.

## Cauldron washing

Using a dyed leather piece on a water cauldron consumes one level and clears the
dye (`wash_leather_armor`). Using an emblazoned banner removes its **topmost**
layer — `table.remove` drops the last entry, which is the newest.

`village_survival.gd` runs the wash **before** `Cauldrons.use`, or a held piece of
armour would be treated as a bottle or bucket instead.

The recipe path needed one line in `Inventory.craft_output_data`: a dyed piece is
the same armour id carrying metadata, so the craft output has to carry the tint.
`apply_craft` returns `{}` for every other recipe, so ordinary armour crafting is
unchanged.

## Verification

`tests/cauldron_wash_checks.gd` (55 checks) asserts the dye family test, the exact
first colour, a hand-computed two-dye average, the no-op re-dye, 64 recipe entries
of the right shape, that `clean_slot` keeps `color` and survives a JSON round trip,
and a live cauldron at level 3 washing a dyed chestplate to level 2 — refusing an
iron piece, refusing a re-wash once a full cauldron's second portion is spent, and
emptying a two-layer banner one layer at a time.

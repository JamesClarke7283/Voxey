# Water-bottle mud conversion

Reference: `/home/impulse/.minetest/games/mineclonia`, especially
`mods/ITEMS/mcl_core/functions.lua:739-746`,
`mods/ITEMS/mcl_potions/init.lua:121-151`, and
`mods/ITEMS/REDSTONE/mcl_dispensers/init.lua:139-174`.
Behavior is original GDScript in `scripts/mud_bottles.gd`; no source texture or
other asset is imported.

## Direct use

A water bottle pointed at one of the three registered `converts_to_mud` hosts —
ordinary dirt, coarse dirt, or rooted dirt — replaces only that pointed cell with
mud. Adjacent cells and podzol/mycelium variants are not hosts. Survival consumes
one water bottle and returns one empty glass bottle through the ordinary
inventory-or-overflow path. Creative use replaces the host but preserves the
water bottle and creates no glass bottle.

`VillageSurvival.use` performs this conversion before generic potion drinking.
The shared empty-bottle result is not a second potion effect.

## Dispenser use

`Dispensers.dispense` targets the cell immediately in front of the dispenser.
A valid host becomes mud and the outcome returns one glass bottle. A non-host
refuses the action without consuming the water bottle.

`RedstoneCircuit.dispense` follows the source's returned-stack transaction:
it takes one input item, puts the returned item in the emptied slot when the
original stack is exhausted, otherwise merges it into the dispenser inventory.
If no dispenser slot can accept the return, the source's own no-room branch
ejects the original dispensed item. Returns never go directly into the player's
inventory merely because the player is nearby.

This shared path also covers filled/empty bucket replacements instead of
changing the item ID and then accidentally deleting a one-item returned stack.

## Verification

`tests/mud_bottle_checks.gd` exercises all three direct hosts, adjacent-cell
refusal, creative/survival behavior, a two-item dispenser stack, a one-item
replacement in the same slot, and non-host refusal. The test is registered in
`tests/lifecycle_runner.gd` under `mud_bottle`.

# Jungle temples

Voxey follows the supplied Mineclonia `mods/MAPGEN/mcl_structures/jungle_temple.lua`. The implementation is original GDScript using the source as a behaviour reference; all art is original procedural code.

## Why it mattered

The jungle temple is the source's **trap** structure. It has **no `after_place` at all** — everything it does lives in the schematic, and the schematic's point is:

- a **trapped chest** hidden behind the temple's wall, and
- **dispensers** beside it, so the treasure is guarded by arrows.

That is why this structure sat unbuildable: it needed **two other features first**, an arrow-firing dispenser and a trapped chest. Both landed in the preceding batches, so the temple could finally be built.

## The trap is proven end to end

The interesting assertion is not that a dispenser exists — it is that **opening the chest makes it fire**. The test:

1. Places the chest and a dispenser beside it.
2. Loads one arrow into the dispenser.
3. Steps the circuit with the chest closed — nothing happens.
4. Opens the chest, steps again — **an arrow spawns** and the dispenser's arrow is consumed.

That chain is the reason the structure exists, and it now passes.

A detail that would have silently broken it: the dispensers must **directly touch** the chest, because a trapped chest powers its *adjacent* blocks. An earlier draft of this module placed them three blocks away, where the signal never reaches — the trap would have been decorative. The test asserts the adjacency explicitly (`distance == 1`), so that mistake cannot return.

## The loot

The source's own table, with the enchanted golden apple and the wild armour trim as its notable entries. The chest rolls two to six stacks. Unavailable entries — bamboo, the four horse armours, the armour trim — keep their weight with a zero id rather than being redistributed, so the source's probabilities are preserved.

## Recorded source gaps

- **The temple is generated, not loaded from a schematic.** The source ships two `.mts` files. Voxey has no schematic loader, so the temple is a stepped mossy-cobble shell over a jungle wood floor with a hidden vault, the trapped chest in the vault, the dispensers beside it and vines on the rim. The trap arrangement and the loot table are the source's intent; the block-by-block layout is not.
- **No tripwire trigger.** The source's own trap is wired to tripwires as well as the chest. Voxey has no tripwire hook item, so the chest's signal is the trigger — which is the part that makes the structure a trap either way.
- **No bamboo, horse armours or armour trim in the loot.** Voxey has no items for them, so those entries carry a zero id and their weight is kept.
- **No jungle biome test.** The source restricts placement to the `Jungle` biome. Voxey has no such biome map, so a temple is placed where the ground is grass or dirt, which is what the source's `place_on` requires.
- **Vines are decoration only.** Voxey grows and climbs vines, but the temple's hanging vines are placed as blocks rather than grown.

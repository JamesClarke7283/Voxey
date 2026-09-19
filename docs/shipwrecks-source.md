# Shipwrecks

Voxey follows the supplied Mineclonia `mods/MAPGEN/mcl_structures/shipwrecks.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or schematic is copied.

## Why it mattered

Shipwrecks carry the **heart of the sea**, which is the conduit's core ingredient. Before this, [buried treasure](buried-treasure-source.md) was the only route to it.

That mattered because the two structures reach it by the **same** rule. The wreck's `after_place` scans the surrounding sea bed, picks a sand or gravel cell, sinks a chest one to four blocks below it, and fills that chest from the **buried-treasure loot table** — which guarantees a heart of the sea in its first slot. So the wreck is a second, independent source of the conduit's core, and it is the source's own design rather than a Voxey addition.

## What the source does

| Rule | Source |
|---|---|
| Placement surface | Sand or gravel, with four water neighbours |
| Depth | `y_max = water_level-4`, `y_offset = pr:next(-4,-2)` — two to four blocks under the water line |
| Layout | Seven `.mts` schematics, chosen at random, on a sixteen-block side |
| Its own chest | Filled from supplies, treasure and navigation tables |
| **Buried chest** | Search 128×128 for sand/gravel/grass/mycelium/podzol, shuffle, sink `pr:next(1,4)`, fill from the buried-treasure table |
| Treasure map | Added to the wreck's own chest, pointing at the buried one |

## The burial is the point

The burial is reproduced exactly in behaviour: a chest is placed one to four blocks under a sand or gravel sea floor, and it holds the buried-treasure table. That is what makes the wreck a real heart-of-the-sea route rather than a chest of supplies.

The treasure map entry in the source's own navigation table is commented out as a FIXME, so it is absent here too.

## Recorded source gaps

- **The hull is generated, not loaded from schematics.** The source ships seven `.mts` files. Voxey has no schematic loader, so a wreck is built as an oak hull with a log keel, broken sides and a partly missing deck, which is the shape those wrecks have. The depth, surface and burial rules are the source's exact behaviour; the block-by-block layout is not.
- **The burial search is drawn from the wreck's vicinity, not 64 blocks away.** The source scans a 128-block box because its placement runs once in a callback that can afford the scan. Voxey places structures per column, so a reach that wide would force dozens of columns to be generated for a single wreck — measured at 1.7 s of stall on the first column that touched a region. The wreck's own floor is already verified to be sand or gravel, so the burial is sampled from the wreck's vicinity instead, which is what the source's search finds in practice. The source value is kept as `SOURCE_BURIED_SEARCH`.
- **The burial site is the local surface.** The source's `find_nodes_in_area_under_air` selects nodes with air above them, so it finds the sea floor rather than a solid node buried beneath it. An earlier version used the wreck's own floor height, which let a chest sink into the water column where the sea bed undulates; the surface height is used instead.
- **No mycelium or podzol burial surface.** The source's search includes both. Voxey has neither block, so the surfaces it does have — sand, gravel, grass and dirt — are used, and the two source entries are named here rather than silently dropped.
- **No ocean-biome split.** The source lists dozens of ocean biomes by name. Voxey has no such map, so wrecks are placed where the sea floor is submerged sand or gravel.
- **No `mcl_sus_stew`, enchanted leather armour, bamboo, pumpkin, `mcl_armor:coast` or clock/compass entries in the loot.** Voxey has a clock and a compass; the other entries have no local equivalent, so their weight is preserved with a zero id rather than redistributed, matching how Voxey's other loot tables handle unavailable content.

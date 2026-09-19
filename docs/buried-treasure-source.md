# Buried treasure

Voxey follows the supplied Mineclonia `mods/MAPGEN/mcl_levelgen/buried_treasure.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or asset is copied.

## What it is

A buried treasure is a **single chest**, hidden beneath a beach. Its placement rule is short and entirely geometric:

1. Start at the terrain surface for the structure's cell.
2. Walk **downward** until the block is andesite, diorite, granite, sandstone or stone — the source's `is_chest_surface` set. Sand and dirt are deliberately *not* chest surfaces, which is what makes the chest sink below them.
3. Place the chest in the air or water cell directly above that support.
4. Seal the chest's six neighbours: any neighbour the live map holds as air or water is filled, using the material the chest displaced, and a stable node is guaranteed underneath so the surroundings cannot collapse.

## Why it matters

[Shipwrecks](shipwrecks-source.md) reach the same table: a wreck buries a chest under the sea bed and fills it from here, so the heart of the sea has two independent sources.

This is the reference's **only route to a heart of the sea**, and the heart is the conduit's core ingredient. The loot table is:

| Group | Contents |
|---|---|
| Guaranteed | **Heart of the sea**, one per chest |
| Materials (1–4 stacks) | Emeralds, prismarine crystals, diamonds |
| Equipment (0–1 stacks) | Leather chestplate or iron sword |

Prismarine crystals and the heart of the sea are exactly what the conduit needs beside its shells, so this structure is the second half of the conduit's material route.

## Beach requirement

The source requires a beach biome. Under ersatz level generation — the mode Voxey targets elsewhere, because it is what the default settings actually run — the source replaces the biome test with `ersatz_is_beach`, a purely geometric one: the four cells ten blocks out must all be at or below sea level, and the site must sit one to four blocks above it. Voxey has no biome map, so it uses the same geometric test the source itself uses in that mode.

## Recorded source gaps

- **No biome check.** As above, the geometric beach test stands in for the biome group. The source's non-ersatz path marks a `has_buried_treasure` group on beach biomes instead.
- **The leather chestplate is a zero-weight entry.** Voxey has no leather chestplate item, so that entry keeps its source weight as a zero id rather than being deleted, which would silently shift the iron sword's odds.
- The source registers the structure through `mcl_levelgen`'s structure-set placement with a `{9, 0, 9}` offset. Voxey plans per region with an equivalent low probability, matching how its other structures work.
- Shipwrecks also carry the heart of the sea in the reference. Voxey has no shipwrecks, so buried treasure is currently the only source.

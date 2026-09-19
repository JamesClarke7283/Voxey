# Ocean ruins

Voxey follows the supplied Mineclonia `mods/MAPGEN/mcl_structures/ocean_ruins.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or schematic is copied.

## Why it mattered

Ocean ruins were the last piece of the ocean's content chain, and they close **three** recorded gaps at once:

| Gap | Closed by |
|---|---|
| Coral had no natural generation | Warm ruins carry coral |
| Sea pickles had no natural generation | Warm ruins carry pickles on dead brain coral |
| Suspicious nodes had no structure placement | The ruin's floor converts to suspicious sand or gravel |

The third is the most significant: in the reference, `place_sus_nodes` is the **only** natural source of archaeological material, which is what makes the whole archaeology system reachable in survival.

## The two variants

The source splits ruins by temperature, and the split decides the content:

| Variant | Floor material | Suspicious node |
|---|---|---|
| Cold | Gravel | Suspicious gravel |
| Warm | Sand | Suspicious sand |

A warm ruin is warm *because* it carries coral — that is what the distinction is for, and it is reproduced.

## What the source actually does

More important than the layout is what happens after placement:

1. **The ruin builds on the sea floor** — placed onto sand, gravel, dirt, clay or stone, with `spawn_by` water so the site is submerged.
2. **`place_sus_nodes` converts the flooring.** It finds the ruin's own floor material within a bounded box, shuffles the list, and converts up to **250** cells into the variant's suspicious node, tagging each with the structure's name. The cap and the shuffle are both reproduced.
3. **A chest** with the source's own loot.

## Recorded source gaps

- **The layout is generated, not loaded from schematics.** The reference ships three cold and four warm `.mts` files. Voxey has no schematic loader, so a ruin is built as a floor plate with a broken wall ring and scattered rubble, which is the shape those ruins have. The rules above — the material, the submersion requirement and the suspicious-node conversion — are the source's exact behaviour; the block-by-block layout is not.
- **`y_max = -2` is not used as a gate.** The source's bound applies to where it attempts placements in its own layered world; Voxey's sea floor sits at a different height, so the real requirement the source tests — submerged, over solid ground — is what is enforced. The source value is recorded as `SOURCE_Y_MAX` rather than dropped.
- **No cold-ocean biome split.** The source lists dozens of cold and warm ocean biomes by name. Voxey has no such biome map, so the variant is chosen randomly, which gives both variants rather than placing cold ruins only in cold seas.
- **No treasure maps in the loot.** The source's own table has the entry commented out as a FIXME, so it is absent here too.
- **Suspicious nodes are not tagged with the structure name.** The source writes `structure = <name>` into each node's metadata; Voxey's archaeology seeds loot lazily on first brush, so the tag is unnecessary.

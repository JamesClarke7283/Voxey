# Dripstone formations

Voxey follows the supplied Mineclonia `mods/MAPGEN/mcl_terrain_features/init.lua`. The implementation is original GDScript using the source as a behaviour reference.

## Why it mattered

Voxey had the dripstone **block** — id 540, craftable, placeable — but **nothing that placed it**. Caves had no dripstone at all, so the block was a crafting curiosity with no place in the world.

The source registers three formations, and each one is what gives a cave a shape rather than a ceiling.

## The three formations

| Formation | Direction | Length |
|---|---|---|
| **Stalactite** | hangs down | `min(20, air × random(0.2, 0.6))` |
| **Stalagmite** | rises up | `min(20, air × random(0.4, 0.8))` |
| **Column** | both, meeting | `min(20, air × random(0.4, 6))` |

All three are capped at **twenty blocks** and require **five air neighbours** before the source will place them.

The length rule is not arbitrary: each formation is a *fraction of the gap it grows into*. A stalactite takes the smallest fraction, so it hangs without reaching the floor; a stalagmite takes a larger one; a column takes a wide fraction so its two halves usually meet and occasionally overrun. The test asserts that ordering — a stalagmite is on average **taller** than a stalactite on the same gap — because that relationship is the source's intent, not an accident of the numbers.

## The taper is what makes it a cone

The shape comes from one formula, applied per offset from the centre:

```
length = max_length × (r² − offset²) / r²
```

So the centre is full length and the rim tapers to nothing. Measured: centre `20.0`, rim `0.0`, and the curve **only shortens** as it moves outward. Without that, a dripstone would be a square pillar; the test checks monotonicity so a broken formula cannot pass.

The source also nudges each formation's centre slightly (`random(-0.2, 0.2)` on both axes), so real ones are asymmetric rather than perfect cones.

## Generation

Dripstone runs as a **cave-feature pass** after the terrain and ores are final, and it **only ever replaces air**. That ordering matters: it means a formation hangs into the space the cave already carved and never eats into rock, so a cave keeps its shape and gains dripstone rather than losing material to it.

Sampled across twenty columns: **dripstone appears underground only**, and at least one sampled column contains it.

## Water and lava drip from a ceiling

The source ships **two** related modules, and Voxey only had the first. `mcl_dripping`
is the second: it makes a cave *feel* wet rather than merely shaped like one. The rule
is three cells deep:

    air below, an opaque node in the middle, that liquid directly above

That is why a drip appears on the roof of a corridor and not inside solid rock, and
why **digging the block under a drip stops it** — the cell below must be air, so the
drip is tied to the shape of the space rather than to the block.

The two liquids differ in the source's own numbers:

| Liquid | Drips from | Interval | Chance |
|---|---|---|---|
| Water | opaque nodes **and leaves** | 60.3 s | 1 in 10 |
| Lava | opaque nodes only | 110.1 s | 1 in 10 |

Each runs on its **own** clock, as two separate ABMs do in the source, so a lava drip
stays roughly twice as rare as a water one regardless of what the other is doing.

Drips are tracked as cells rather than found by sweeping the world: the node-change
hook re-examines the cell, the one above and the one below, so a dig or a placement
registers or unregisters a drip immediately. That is what makes the "dig under it and
it stops" behaviour work without a scan.

## Recorded source gaps

- **No DripstoneCave biome.** The source restricts placement to a DripstoneCave biome with `fill_ratio = 0.005`. Voxey has no such biome, so dripstone is placed by the same ratio across the whole underground band instead of being concentrated in one biome.
- **No pointed-dripstone block states.** The source's `generate_dripstone` writes full dripstone blocks, which is reproduced; Minecraft's pointed dripstone with its own growth states is a different block that the source does not implement either.
- **Stalactite and stalagmite are separate passes.** The source registers them as separate structures anchored to ceilings and floors; Voxey chooses one kind per site, which reaches the same three shapes without duplicating the scan.
- **No `all_floors` / `all_ceilings` multi-level placement.** The source can place a formation at each floor or ceiling in a column. Voxey scans every air cell in the column's underground band, which finds the same sites.

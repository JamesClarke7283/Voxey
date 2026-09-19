# Igloos

Voxey follows the supplied Mineclonia `mods/MAPGEN/mcl_structures/igloo.lua`. The implementation is original GDScript using the source as a behaviour reference; all art is original procedural code.

## Why it mattered

An igloo is **not a loot hut**. It is a self-contained **cure puzzle**:

- The hut hides a basement with a **brewing stand**, a **bookshelf** and a **jukebox**.
- The basement holds a **villager and a zombie villager** — the two halves of the cure.
- The chest's first group is a **guaranteed golden apple**, which is the cure item.
- The shaft down to it is lined with **infested bricks**, so the way in is an ambush.

Put together: find the trapdoor, go down past a trap, brew a weakness potion at the stand, and cure the zombie villager with the apple. The source builds an entire tutorial for the cure mechanic into a snow hut.

Three earlier batches were **prerequisites**: infested blocks, the zombie villager and its cure, and the brewing stand. All are now present, so this structure could finally be built.

## What the source does

| Rule | Source |
|---|---|
| Placement | Snow, snowy grass; a random **rotation** |
| Basement | **50%** chance (`pr:next(1,2) == 1`) |
| Shaft | Lined with bricks; **1 in 10** infested; **1 in 3** of those cracked |
| Depth | At least 7 blocks, and a shallower site is refused |
| Hidden trapdoor | Placed **5 seconds after** the hut, so it is not part of the initial structure |
| Residents | One villager, one zombie villager |
| Loot | A **guaranteed golden apple** first, then ordinary stores |

Every rate was measured across 233 igloos:

| Rule | Source | Measured |
|---|---|---|
| Basement present | 50% | 55.8% (130/233) |
| Infested shaft brick | 1 in 10 | 8.05% |
| Cracked shaft brick | 1 in 3 of the rest | 26.6% |

## The shaft is the ambush

The shaft's infested mix is not decoration — it is the source's `set_brick`, which rolls once for a monster egg and once for a crack. Measured, roughly one brick in twelve on the way down hides a silverfish.

The test asserts the infested share lands near one in ten and **not** at zero or one hundred percent, so a version that made every shaft brick infested, or none, would fail.

## The rotation decides the shaft

The source picks a rotation and derives the shaft and trapdoor positions from it. Measured across the world, more than one rotation occurs, so the ladder is not always in the same corner.

## Recorded source gaps

- **The hut and basement are generated, not loaded from schematics.** The source ships three `.mts` files (top, basement, and a variant). Voxey has no schematic loader, so the hut is a snow dome and the basement a brick room at the foot of a ladder shaft. The rotation rule, the 50% basement, the shaft's infested mix, the residents and the loot are the source's exact behaviour; the block layout is not.
- **No delayed trapdoor placement.** The source places the hidden trapdoor five seconds *after* the hut via `core.after`, so a player standing there cannot see it appear. Voxey's shaft opening is simply part of the structure, so the concealment is by geometry rather than by timing.
- **No cold-biome test.** The source restricts placement to ColdTaiga, IcePlainsSpikes and IcePlains. Voxey has no such biome map, so an igloo is placed where the ground is snow, snowy grass or grass, which is what the source's `place_on` requires.
- **No brewing-stand fuel check.** The basement's stand is placed empty, as the source's `construct_nodes` leaves it; a player still needs blaze powder and bottles to use it.
- **The two residents do not fight.** The source spawns a villager and a zombie villager in the same room and lets the zombie attack the villager. Voxey spawns both, and its zombie villager is hostile, but the source's specific villager-hunting behaviour for this pair is not scripted.

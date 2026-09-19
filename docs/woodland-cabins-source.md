# Woodland cabins, vindicators and evokers

Voxey follows the supplied Mineclonia `mods/MAPGEN/mcl_structures/woodland_mansion.lua` (which registers `woodland_cabin`), `mods/ENTITIES/mobs_mc/villager_vindicator.lua` and `villager_evoker.lua`. The implementation is original GDScript using the source as a behaviour reference; all art is original procedural code.

## Why it mattered: the totem of undying had no source

This batch closes a gap that had been **documented and unnoticed**: Voxey had the totem of undying and its entire lethal-damage interception — carried in either hand, clearing effects, restoring breath, saving you at one health — but the totem itself was **unobtainable in survival**. No drop, no recipe, no structure anywhere produced one.

The evoker is the source's route, and its drop is `chance = 1`, which in the source's convention means **always**:

| Creature | Health | Drops |
|---|---|---|
| Vindicator | 24 | Emerald, `chance = 1` with `min = 0` |
| **Evoker** | 24 | **Totem of undying, `chance = 1`** |

So an evoker is a guaranteed totem, and the woodland cabin is where evokers live.

## What the source does

The cabin's `after_place` spawns a garrison, and all three members are reproduced:

| Member | Count |
|---|---|
| Vindicators | 5 |
| **Evoker** | 1 |
| Parrot | 1 |

The cabin also runs `construct_nodes` for **barrels and bookshelves**, so it is furnished, not empty.

## Verified

- **138 cabins** exist near the origin.
- The garrison is exactly **5 vindicators, 1 evoker, 1 parrot**, and all of them **spawn in the world** when the cabin's column is applied.
- The evoker yielded a totem **300 out of 300** rolls — the source's `chance = 1` really is guaranteed, so a totem is reachable.
- The vindicator's emerald appeared in roughly half of 300 rolls, which is the source's `min = 0` doing its work: the drop can be absent.

## Recorded source gaps

- **The cabin is generated, not loaded from a schematic.** The source ships several `.mts` files for the cabin and outpost variants. Voxey has no schematic loader, so the cabin is a dark-oak hall on a stone floor with a doorway, barrels and bookshelves. The garrison, the furniture and the loot are the source's exact behaviour; the block layout is not.
- **No evoker spells.** The source's evoker summons **vexes** and conjures **fang lines**; Voxey's evoker has the source's health and its guaranteed totem, but not its spells. The totem drop is the part that closes the item gap.
- **No vindicator axe behaviour.** The source's vindicator carries an iron axe and can disable a shield with it. Voxey's vindicator is a melee attacker with the source's damage, and it carries a modelled axe, but the shield-disabling strike is not implemented.
- **No roofed-forest biome test.** The source restricts placement to the RoofedForest biome. Voxey has no such biome map, so a cabin is placed where the ground is grass or dirt, which is what the source's `place_on` requires.
- **No mansion proper.** The source registers the cabin and the outpost, and the full woodland *mansion* is a separate, much larger structure. Only the cabin is implemented here.

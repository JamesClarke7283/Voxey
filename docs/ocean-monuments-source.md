# Ocean monuments

Voxey follows the supplied Mineclonia `mods/MAPGEN/mcl_structures/shipwrecks.lua` (the `ocean_temple` registration) and the guardian garrison it spawns. The implementation is original GDScript using the source as a behaviour reference; all art is original procedural code.

## Why it mattered

The ocean monument is **the reason guardians exist**. Voxey already had the guardian and elder guardian with their full chance-weighted drop tables, and the elder's **guaranteed wet sponge** is the only natural source of sponges in the game — but nothing placed them anywhere. The monument gives them a home.

It also closes a material loop. The monument is **prismarine**, which is the conduit's frame material, so finding one is a way to gather the blocks a conduit needs without crafting the whole chain.

## What the source does

| Rule | Source |
|---|---|
| Placement | Sand or gravel sea floor, four water neighbours |
| Depth | `y_max = water_level-4`, `y_offset = pr:next(-2,0)` |
| Size | `sidelen = 32` |
| Garrison | **5 guardians and 1 elder guardian** |
| Spawn surface | Dark prismarine slabs |
| Walls | `construct_nodes` settles the `group:wall` blocks |
| Loot | A fishing rod and a block of gold, among supplies and navigation |

Every part is reproduced: the size, the sink, the five-to-one garrison, and the dark prismarine spawn surface the guardians stand on.

## The garrison is really spawned

The test checks the **world outcome**, not the plan. That distinction was the lesson of the previous batch: an earlier version of the structure code reported a garrison it never placed, because the spawn call sat inside the loop over *indexed* gameplay nodes and a chest is not one of them. The check here applies the monument's column and asserts that **guardians and an elder actually appear**, so the same class of bug cannot return unnoticed.

## Recorded source gaps

- **The monument is generated, not loaded from a schematic.** The source ships two `.mts` files. Voxey has no schematic loader, so the monument is a stepped prismarine mass with a hollow base, inset sea lanterns and dark prismarine accents. The garrison counts, the spawn surface and the loot are the source's exact behaviour; the block layout is not.
- **No four-water-neighbour check.** The source requires four water neighbours at the placement point. Voxey tests that the sea floor is deep enough (`floor_y < SEA-4`) and that the floor is sand or gravel, which is the same requirement reached a different way.
- **The elder's mining fatigue is implemented.** The elder applies **mining fatigue level 3 for five minutes** to every player within **fifty blocks**, on the source's own sixty-second cycle, and the fatigue really slows block breaking. See [guardian auras](guardian-auras-source.md).
- **The guardian's thorns is implemented.** A guardian struck in melee deals the source's **two damage** back, unless it is pacing rather than hunting — the source's own `go_pos` guard.
- **No monument rooms.** A real monument is a maze of rooms; Voxey's is a solid stepped mass with a hollow base. The guardians and the loot are present; the interior layout is not.
- **No ocean-biome test.** The source lists dozens of ocean biomes by name. Voxey has no such biome map, so a monument is placed on a submerged sand or gravel floor.

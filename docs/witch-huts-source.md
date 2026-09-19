# Witch huts, witches and cats

Voxey follows the supplied Mineclonia `mods/MAPGEN/mcl_structures/witch_hut.lua`, `mods/ENTITIES/mobs_mc/witch.lua` and the cat half of `ocelot.lua`. The implementation is original GDScript using the source as a behaviour reference; all art is original procedural code.

## Why it mattered

The witch hut needed **two creatures Voxey did not have**: a witch and a cat. So this batch adds both as well as the structure.

The witch matters beyond the hut. Her drop table is a **brewing supply line**:

| Drop | Chance | Amount |
|---|---|---|
| **Redstone** | always | 4–8 |
| Glass bottle | 1 in 8 | 0–2 |
| Glowstone dust | 1 in 8 | 0–2 |
| Gunpowder | 1 in 8 | 0–2 |
| Spider eye | 1 in 8 | 0–2 |
| Sugar | 1 in 8 | 0–2 |
| Stick | 1 in 4 | 0–2 |

Redstone always drops and in stacks of four to eight, which makes a witch one of the few reliable sources of **redstone above ground** — the material a player needs for every circuit.

The chance field is a **denominator**, so `chance = 8` is one in eight, the same convention the guardian and aquatic drops use. Voxey's shared creature drop table cannot express a denominator, so the rolls live in the witch's own module.

## What the source does

The hut's `after_place` is precise, and each part is reproduced:

1. **It finds the hut's cauldron** with `find_node_near`. The cauldron is the anchor.
2. **It looks for the hut's wooden posts at the cauldron's level** and puts the residents on top — not at a fixed offset from the hut's centre.
3. **It replaces the hut's leg blocks with oak logs down to the waterline**, so the stilts stand in the swamp.
4. It spawns a **witch** and an **all-black cat**, with `can_despawn = false` on both, and overrides the cat's texture explicitly.

## The bug this batch caught, and the test that found it

Verifying the witch hut, I found that **no structure in `voxel_world.gd` spawned creatures at all.** The pillager outpost's raiding party and the igloo's residents were planned correctly and reported by their modules — but nothing placed them in the world.

Two things caused it:

- The spawn block had been written inside `for p in result.get("special",{})`, the loop over *indexed* gameplay nodes. A party marker is an ordinary block (a chest or a cauldron), so it is never in that index, and the spawn code never ran.
- My earlier outpost and igloo suites checked the **plan** — that the module reports five pillagers and three parrots — not the **world**. A structure that reports a party it never places is a dead feature, and the tests gave a green light to exactly that.

The fix reads the resident maps directly, once per column, and the new witch-hut test asserts the world outcome: applying the hut's column must **spawn a witch and a cat**. The outpost and igloo suites were re-run against the same fix and now pass 80 checks together.

## Recorded source gaps

- **The hut is generated, not loaded from a schematic.** The source ships one `.mts` file. Voxey has no schematic loader, so the hut is a planked shack raised on four stilts with a cauldron inside. The residents, the stilt posts and the cauldron anchor are the source's behaviour; the block layout is not.
- **The cauldron search is not a 15-block scan.** The source searches a radius of fifteen for the cauldron, because it does not know where the schematic put it. Voxey generates the hut, so the cauldron's position is known exactly and the scan is unnecessary — the marker is used directly.
- **No stilt replacement pass.** The source rewrites the hut's legs to oak logs down to the water. Voxey builds them as oak logs from the start, so there is nothing to rewrite.
- **No witch potion throwing.** The source's witch throws harming and poison potions at range. Voxey's witch is a ranged attacker with the source's range, interval and damage, but it does not yet throw a visible potion or apply the source's specific negative effects.
- **No swamp biome test.** The source restricts placement to the three Swampland biomes. Voxey has no such biome map, so a hut is placed on ground at or just above the waterline, which is what the source's `liquid_surface` flag and `y_min`/`y_max` describe.
- **No ocelot.** The source's cat is the tamed form of an ocelot. Voxey has the cat alone; the untamed jungle ocelot is not implemented.

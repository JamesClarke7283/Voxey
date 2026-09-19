# Amethyst geodes and crystal growth

`scripts/amethyst.gd` and `scripts/amethyst_geodes.gd` adapt the supplied Mineclonia checkout at `/home/impulse/.minetest/games/mineclonia`, inspected on 2026-09-16. Attribution: Mineclonia and MineClone contributors; adapted algorithms and behavior are covered by [GPL-3.0-or-later](licenses/Mineclonia-GPL-3.0.txt). Crystal meshes, shard artwork and material textures are original Voxey procedural artwork.

| Source file | SHA-256 |
| --- | --- |
| `mods/ITEMS/mcl_amethyst/init.lua` | `d8b839f80a4d48842e74aa5026cea098fdc453717e3a1f5d50b03fc353bfa15a` |
| `mods/ITEMS/mcl_amethyst/grow.lua` | `33ad3908cd47e1a343b337b157f573567cc7d397c2eaba8fa9a1e0f7ae9edc8d` |
| `mods/ITEMS/mcl_amethyst/lg_register.lua` | `df45f6aecd4a9eb181e3360ee971e490d363031fc8172d3e549f317d3786108b` |
| `mods/MAPGEN/mcl_structures/geode.lua` | `682b4a14517e58756dd88d507a73cec343e6d4bc6bbbba8afe850e5616e24c27` |
| `mods/ENTITIES/mcl_item_entity/init.lua` | `e519f871d3cd09d7133687bae8bff13b4468623a85c854abf84d31de801d6e1e` |
| `mods/CORE/_mcl_autogroup/init.lua` | `042ed400ac8fbc3c226cf193652a25913b8a782be2fdbd13bfc219fce15c339c` |
| `mods/ITEMS/mcl_blackstone/init.lua` | `488931cc9f8d3b303ea314159378be8d6d45f5cc88e1df04450abfb834748a85` |

## Survival materials

Natural Overworld geodes provide smooth basalt outside, calcite in the middle, and amethyst and budding amethyst around a hollow chamber. Their initial crystals include all four growth stages. Blocks use IDs 7700–7704, shards use 7705, and the four crystal stages use 7708, 7716, 7724 and 7732. Five hidden states following each crystal item encode the remaining attachment directions. Existing block IDs are unchanged.

Four shards in a square craft one amethyst block in the hand grid. Four shards around glass craft two tinted glass at a crafting table. Smelting basalt produces smooth basalt. Both manual crafting and the recipe guide support these recipes. Shards also supply the [spyglass recipe](spyglass-source.md).

Amethyst blocks, calcite and smooth basalt require a pickaxe to drop themselves. Budding amethyst never drops, including with Silk Touch, so renewable farms remain at their natural sites. Small, medium and large buds drop nothing normally. A mature cluster mined with a pickaxe drops four shards; a pickaxe with Silk Touch instead collects the exact bud or cluster stage. Breaking the supporting block or destroying a mature cluster with a piston produces two shards; smaller buds produce nothing. Pistons destroy budding blocks without a drop.

**The supplied source does not define a Fortune drop override for amethyst.** Fortune therefore leaves the pickaxe result at four shards. The source cluster's ordinary drop table has a two-shard fallback, but the shared `mcl_item_entity` harvestability check runs before it: a player's bare hand or axe fails the cluster's `pickaxey` requirement and receives nothing. Voxey preserves this distinction between player harvesting and environmental breakage rather than assuming another Minecraft version's rules.

Tinted glass drops itself without a tool or Silk Touch. It is visually translucent while blocking both sky and gameplay block light. Crystal stages emit light levels 1, 2, 4 and 5 through the existing gameplay light solver. Tinted glass and smooth basalt retain their glass/stone note-block material groups; amethyst and calcite retain the source default instrument.

## Growth, support and persistence

Both source growth actions run on a 68-second interval with a one-in-five chance. A successful budding-block action chooses one of its six neighboring cells and creates a small bud only in air or water. It does not retry another face when that choice is blocked. Crystals advance one stage only when their actual backing block is budding amethyst; a different nearby budding block does not qualify. A mature cluster stops advancing. Growth replaces water, matching the source's node swap; it does not invent a separate waterlogged state.

All stages can be placed on six faces after collection with Silk Touch. Their rotated source selection boxes also provide collision; the supplied node definitions retain the default walkable behavior. Any walkable backing block preserves an attached crystal, but only budding amethyst grows it. Unknown support in an unloaded neighboring column preserves an existing crystal. New placement requires loaded support. Returning columns validate support after saved edits have been reconciled. Piston moves defer support checks until all moved blocks and the head are in their final cells, so temporary empty cells cannot destroy a still-supported crystal.

Voxey stores stage and orientation in the placed node ID and fractional interval time in dimension adventure state. Runtime indexes contain loaded budding blocks and crystals only. A cycle snapshots those IDs and evaluates at most sixteen candidates per frame; a newly created or advanced bud cannot advance twice in one cycle. Pauses stop the clock and unloaded nodes are absent from the active index. The adapter does not simulate missed unloaded growth or reproduce Luanti's ABM catch-up scheduler.

## Natural generation and engine adaptations

The selected algorithm is the current `mcl_amethyst/lg_register.lua` distance-field generator. The older `mcl_structures/geode.lua` was reviewed but is not combined with it. Each 16×16 Overworld column has the source one-in-24 candidate chance, with origin height uniformly chosen from world minimum plus six through Y30. Three or four distribution points, offsets 4–6, point offsets 1–2, shell thresholds 1.7/2.2/3.2/4.2, noise amplitude 0.05, 95% crack chance, 8.3% budding substitution and 35% initial decoration eligibility follow the supplied source. A decorated budding block chooses one of the four stages and places that stage on every eligible face. More than one invalid distribution point in air, water, lava, bedrock or ice rejects a candidate.

Godot's seeded random generator and FastNoiseLite replace Mineclonia's JVM random and normal-noise implementations. Candidate locations and outlines are consequently deterministic within Voxey, but not seed-identical to Luanti. The source's first crack-direction branch contains two absolute Z=0 coordinates; this branch is preserved rather than silently corrected. Source generation bounds are clipped to Voxey's terrain limits.

Worker generation uses immutable per-candidate voxel plans, a bounded 64-entry generator-local cache, and consistent neighboring candidate order. Geodes cross column boundaries and populate worker halo data before player edits, so saved construction always wins. Natural geology, cave air and liquids may be replaced. Existing chest/spawner/building cells are protected, and planned dungeon, village-pad and stronghold bounds exclude intersecting candidates. This protection adapts Mineclonia's `features_cannot_replace` group to Voxey's existing structures. Generation does not access the scene tree or allocate a scene per crystal; crystals use the normal batched chunk mesh.

## Verification

Run `godot --headless --path . --script res://tests/lifecycle_runner.gd -- amethyst`.

The focused fixture exercises actual player placement on every face, all 24 placed crystal states through the normal chunk mesher, raycast and real actor collision, light behavior, real harvesting with and without Silk Touch/Fortune, both crafting paths, piston destruction and final support, natural generation and mining, preservation of edited terrain, invalid/protected terrain, and real save/load/column streaming. Icon polygons must have nonzero projected area, matching UVs and valid triangulation; repeated apex vertices and edge-on faces are removed before Canvas drawing. Actual held and dropped tinted-glass/honey models also retain nonempty translucent meshes and the blend material. The final isolated focused run passed all 191 checks without script errors.

An isolated headless profile at seed 8675309 measured the 25 neighboring candidate queries around column (-8,6) at 73.3 ms cold and 24 µs with a reused generator cache. The structure-protection portion measured 13.7 ms cold and 7 µs cached across four dungeon regions; a complete geode plan was approximately 50 ms. Full generation and meshing of four sampled columns measured 656–736 ms initially and 658–677 ms on repeat, including all existing terrain features. **Normal world streaming creates a fresh generator per worker job**, so the cached query result is not a claim that adjacent streamed columns avoid cold planning. These measurements describe one local headless run, not a frame-time guarantee; generation remains on background workers and does not create crystal scene nodes.

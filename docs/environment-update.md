# Eating, daylight and fluid flow

This finishes the requested environment fixes. Further Mineclonia feature work is paused at the user's request.

- Hold right-click, or hold the touch Use button, to eat. Normal food takes **1.61 seconds**; dried kelp takes **0.8 seconds**. Eating slows movement and animates the held food. Releasing use, switching slots, mining or opening a menu cancels without consuming it. Completing a stew returns its bowl.
- Small overhangs and nearby outdoor openings retain daylight. The cave adjustment checks actual open sky and nearby openings, rather than only the original terrain height. Deep sheltered caves keep constant ambient light through dusk and night. This remains a cave-environment approximation, not complete per-voxel skylight propagation.
- Water and lava fall into open space before spreading horizontally on support. Water reaches seven blocks; lava reaches three in the Overworld and seven in the Nether. Flowing surfaces get shallower with distance and animate downward. Removing a source drains its dependent flow. Two supported water sources can renew a source between them; lava is not renewable.
- Water touching a lava source produces obsidian. Side contact with flowing lava produces cobblestone; falling lava onto water produces stone. Water washes away torches and extinguishes fire while preserving submerged kelp. Flowing liquids participate in swimming, submersion, irrigation, item destruction and other fluid interactions. Buckets collect sources and can pour a source into existing flow.
- Flow states persist in world edits and resume after loading. Simulation waits at unloaded column boundaries and resumes when the neighboring terrain arrives. Queue processing and column activation share a 2.5 ms frame budget; existing source surfaces retain greedy meshing and GPU rendering.

The supplied Mineclonia sources used for behavior are `mods/PLAYER/mcl_hunger/holdeat.lua`, `mods/ITEMS/mcl_ocean/kelp.lua`, `mods/ITEMS/mcl_core/nodes_liquid.lua` and `mods/ITEMS/mcl_nether/lava.lua`. Voxey uses its own queue-based fluid implementation; these changes do not claim exact Luanti engine parity or add every source hunger mechanic.

`tests/environment_runner.gd` and `tests/fluid_checks.gd` check consumption and cancellation, daylight near cover, constant cave lighting, downward flow and drainage, ranges, source renewal, reactions, geometry and face winding, bucket use, damage, chunk boundaries and save/reload continuation. `tests/environment_tour.gd` checks rendered eating, waterfalls and a covered excavation using isolated worlds. The full regression runner includes the environment suite.

Verification: the full seven-suite run passed **1,175 checks**, including **44 environment checks**, with no script diagnostics. The rendered tour confirmed one apple eaten after holding use, daylight beside an opening under cover, and both waterfalls reaching the ground. GPU rendering used the NVIDIA GeForce RTX 5090.

# Farmland soil

`scripts/farmland.gd` adapts the supplied Mineclonia checkout at `/home/impulse/.minetest/games/mineclonia`, rechecked against the completed registry on 2026-10-25. Attribution: Mineclonia and MineClone contributors; adapted behavior is covered by [GPL-3.0-or-later](licenses/Mineclonia-GPL-3.0.txt). Furrow textures and geometry are original Voxey procedural artwork.

| Source | SHA-256 |
| --- | --- |
| `mods/ITEMS/mcl_farming/soil.lua` | `31e6d6b49b5001843a1130c2dd7cdbfb6e4fd02c06ddb32d83d00818dac7dac1` |
| `mods/ITEMS/mcl_farming/hoes.lua` | `744c4d53831e08059da8e5a85fbd4896e7b935c1c289c83b80b2538a85b8d240` |
| `mods/ITEMS/mcl_core/functions.lua` | `a518566a56114d3f57e111ee1f13e672080d143e0ec8156aee0314bf7ed5b969` |
| `mods/CORE/_mcl_autogroup/init.lua` | `042ed400ac8fbc3c226cf193652a25913b8a782be2fdbd13bfc219fce15c339c` |

Additional references: `mcl_tools/init.lua` dispatches hoe use and durability; `mcl_weather/weather_core.lua:is_outdoor` defines outdoor exposure; `mcl_farming/shared_functions.lua` dirtifies soil beneath a newly grown gourd. The exported `farming.json` records the completed groups of all 2,892 source nodes. This keeps source `solid`, `plant`, `dirtifier` and `dirtifies_below_solid` behavior distinct from native collision. For example, the small chest, piston pusher, honey block and hopper have no source `solid` group; a composter has `dirtifier` despite its hollow collision.

## Survival behavior

Dry farmland keeps legacy ID 21. Wet farmland uses hidden ID 8000. Both have a 15/16-block height, 0.6 hardness, shovel preference, dirt sides and underside, and a dirt drop even with Silk Touch. Collision, targeting, chunk meshes, held items and item icons share the lowered geometry.

A hoe tills dirt, grass, swamp grass and existing dirt paths when the cell immediately above is literal air. The supplied source has no clicked-face exclusion; side and underside use are allowed. Flowers, snow, liquids and other occupied cells block tilling without being removed or wearing the tool. Survival consumes one normal tool use, while creative mode preserves wear. The later coarse-dirt implementation already converts to dirt on the first hoe use and to a path with a shovel. [Rooted dirt and azalea](azalea-source.md) now have their source conversion, root collection and acquisition paths. This checkout registers no farmland trampling callback; none is added as an inferred Minecraft requirement.

Each loaded soil checks every 15 seconds with a one-in-four chance. Hydration searches a 9×2×9 volume: X/Z offsets −4 through +4 and Y offsets 0 through +1. Flowing water and source water both hydrate. The source comment mentions water below, but its executable bounds do not; Voxey follows those bounds. Known water hydrates even when a different part of the volume is unloaded. Without water, any unknown cell in that volume prevents moisture loss.

New wet soil starts with moisture 7. Already-wet soil beside water keeps its existing metadata. On the first dry action, moisture 7 changes the visible node to dry farmland and decreases to 6. Further actions decrement through 0. One further action converts bare soil to dirt; a source plant retains its dry bed indefinitely. Rehydrating a dry node restores wet identity and moisture 7. Crop growth uses wet node identity, not the hidden positive counter on an already-dry node.

The supplied soil ABM's rain branch only **prevents decay**: it does not hydrate dry soil. It uses global rain and outdoor exposure, without the biome filtering used by the separate `is_exposed_to_rain` function. Exposure is independent of the current time of day. Following the source's documented limitation, a clear glass roof still qualifies as outdoors; opaque roofs and filtering blocks do not. Voxey uses its authoritative weather state and existing sunlight-filter classification.

A separate source ABM checks covered farmland and dirt paths every eight seconds with a one-in-fifty chance. Only the actual registered `solid` group above converts the lower cell to dirt. This check is independent of hydration, so hydration can still change moisture beneath a solid cover until the covered-soil action runs. Glass counts as solid. Player placement follows both immediate callbacks: placing a solid or `dirtifier` above affected soil converts the lower cell, and placing affected soil below an existing solid or `dirtifier` converts the newly placed cell. This includes composters, farmland and dirt paths. Generic world changes retain the separate scheduled check. Gourds already use the explicit source dirtification rule at their destination.

## Persistence and scheduling

`world.block_states[coordinate].farmland` saves the bounded moisture counter and fractional remaining interval. Missing legacy data defaults to dry 0 or wet 7. Invalid saved values are normalized. Runtime cell and column indexes contain loaded soil and dirt paths only; removal clears metadata and queued work, while unload retains saved data and removes active work. Reload resumes the timer. A single-player pause does not tick it; a hosting world continues soil simulation while its host has Escape open. Guest placements run both dirtifier rules on the host. Piston transactions carry the same saved metadata to the destination and refresh runtime identity.

This adapts Luanti's ABM to Voxey's loaded-world scheduler. Hydration and covered-soil jobs share an eight-action frame budget, limiting local water probes to at most 1,296 across the whole field. Dirt paths join the worker’s special-cell index so generated and saved paths register again on load. A pending cell cannot be enqueued twice. Timers do not simulate missed unloaded time. A saved pending action resumes from its zero timer with a fresh one-in-four selection; transient random-generator state is not serialized. This deliberately avoids offline catch-up or a large burst on returning to a farm.

## Verification

Run `godot --headless --path . --script res://tests/lifecycle_runner.gd -- farmland`.

The focused fixture exercises real player hoe use, survival wear and creative preservation, material harvest with Silk Touch, lowered targeting and body collision, water boundary/flowing-water cases, all drying stages, crop/flower/sapling retention, source solid and dirtifier distinctions, nighttime rain and roof behavior, interval/chance/budget behavior, invalid metadata, unloaded neighbors, actual piston transport, actual JSON save/reload and column streaming. It uses an isolated high plot so older ordered test buildings cannot shade its light-dependent plants.

`tools/export_farming_reference.py` executes the actual Luanti hydration, covered-soil, placement and crop callbacks. The fixture covers 1,280 moisture transitions, 36 covered-soil cases, both placement callbacks in 72 cases, and 27,648 crop-growth histories. `tests/farming_reference_checks.gd` passes 65,972 assertions and records all 633 source Lua hashes. The live fixture also verifies the independent timers, composter placement in both directions, loaded dirt-path registration, save/reload and crop history.

# Farmland soil

`scripts/farmland.gd` adapts the supplied Mineclonia checkout at `/home/impulse/.minetest/games/mineclonia`, inspected on 2026-09-16. Attribution: Mineclonia and MineClone contributors; adapted behavior is covered by [GPL-3.0-or-later](licenses/Mineclonia-GPL-3.0.txt). Furrow textures and geometry are original Voxey procedural artwork.

| Source | SHA-256 |
| --- | --- |
| `mods/ITEMS/mcl_farming/soil.lua` | `31e6d6b49b5001843a1130c2dd7cdbfb6e4fd02c06ddb32d83d00818dac7dac1` |
| `mods/ITEMS/mcl_farming/hoes.lua` | `744c4d53831e08059da8e5a85fbd4896e7b935c1c289c83b80b2538a85b8d240` |
| `mods/ITEMS/mcl_core/functions.lua` | `a518566a56114d3f57e111ee1f13e672080d143e0ec8156aee0314bf7ed5b969` |
| `mods/CORE/_mcl_autogroup/init.lua` | `042ed400ac8fbc3c226cf193652a25913b8a782be2fdbd13bfc219fce15c339c` |

Additional references: `mcl_tools/init.lua` dispatches hoe use and durability; `mcl_weather/weather_core.lua:is_outdoor` defines outdoor exposure; `mcl_farming/shared_functions.lua` dirtifies soil beneath a newly grown gourd. Source piston heads, chests, honey blocks and hoppers have fixed rather than regular node/collision boxes and therefore do not receive the automatically assigned `solid` group.

## Survival behavior

Dry farmland keeps legacy ID 21. Wet farmland uses hidden ID 8000. Both have a 15/16-block height, 0.6 hardness, shovel preference, dirt sides and underside, and a dirt drop even with Silk Touch. Collision, targeting, chunk meshes, held items and item icons share the lowered geometry.

A hoe tills dirt, grass, swamp grass and existing dirt paths when the cell immediately above is literal air. The supplied source has no clicked-face exclusion; side and underside use are allowed. Flowers, snow, liquids and other occupied cells block tilling without being removed or wearing the tool. Survival consumes one normal tool use, while creative mode preserves wear. Coarse dirt and rooted dirt are not existing Voxey resources, so their source first-step conversions remain dependent on those materials. Shovel path creation and trampling are outside this batch.

Each loaded soil checks every 15 seconds with a one-in-four chance. The action checks a solid block directly above first. It then searches a 9×2×9 volume: X/Z offsets −4 through +4 and Y offsets 0 through +1. Flowing water and source water both hydrate. The source comment mentions water below, but its executable bounds do not; Voxey follows those bounds. Known water hydrates even when a different part of the volume is unloaded. Without water, any unknown cell in that volume prevents moisture loss.

New wet soil starts with moisture 7. Already-wet soil beside water keeps its existing metadata. On the first dry action, moisture 7 changes the visible node to dry farmland and decreases to 6. Further actions decrement through 0. One further action converts bare soil to dirt; a source plant retains its dry bed indefinitely. Rehydrating a dry node restores wet identity and moisture 7. Crop growth uses wet node identity, not the hidden positive counter on an already-dry node.

The supplied soil ABM's rain branch only **prevents decay**: it does not hydrate dry soil. It uses global rain and outdoor exposure, without the biome filtering used by the separate `is_exposed_to_rain` function. Exposure is independent of the current time of day. Following the source's documented limitation, a clear glass roof still qualifies as outdoors; opaque roofs and filtering blocks do not. Voxey uses its authoritative weather state and existing sunlight-filter classification.

Source regular full collision boxes are solid for dirtification regardless of visual opacity, so glass counts. Partial collision boxes do not. Actual player placement also applies the source `dirtifier` rule immediately, including farmland or dirt paths placed above farmland. Generic world changes retain the source scheduled check. Gourds already use the explicit source dirtification rule at their destination.

## Persistence and scheduling

`world.block_states[coordinate].farmland` saves the bounded moisture counter and fractional remaining interval. Missing legacy data defaults to dry 0 or wet 7. Invalid saved values are normalized. Runtime cell and column indexes contain loaded soil only; removal clears metadata and queued work, while unload retains saved data and removes active work. Reload resumes the timer. A pause does not tick it. Piston transactions carry the same saved metadata to the destination and refresh runtime identity.

This adapts Luanti's ABM to Voxey's loaded-world scheduler. At most eight selected soil actions run in a frame, limiting local water probes to 1,296 across the whole field. A pending cell cannot be enqueued twice. Timers do not simulate missed unloaded time. A saved pending action resumes from its zero timer with a fresh one-in-four selection; transient random-generator state is not serialized. This deliberately avoids offline catch-up or a large burst on returning to a farm.

## Verification

Run `godot --headless --path . --script res://tests/lifecycle_runner.gd -- farmland`.

The focused fixture exercises real player hoe use, survival wear and creative preservation, material harvest with Silk Touch, lowered targeting and body collision, water boundary/flowing-water cases, all drying stages, crop/flower/sapling retention, source solid and dirtifier distinctions, nighttime rain and roof behavior, interval/chance/budget behavior, invalid metadata, unloaded neighbors, actual piston transport, actual JSON save/reload and column streaming. It uses an isolated high plot so older ordered test buildings cannot shade its light-dependent plants.

Final isolated focused result: **88 passed, 0 failed**, with no script errors (`/tmp/voxey-farmland-final.log`).

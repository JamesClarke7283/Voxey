# Campfire cooking and fire states

`scripts/campfires.gd` adapts the user-provided Mineclonia source at `/home/impulse/.minetest/games/mineclonia`, inspected on 2026-09-16. Attribution: Mineclonia and MineClone contributors; adapted rules are covered by [GPL-3.0-or-later](licenses/Mineclonia-GPL-3.0.txt). Voxey's block, food and smoke meshes are original; no source textures or meshes were copied.

| Reference file | SHA-256 |
| --- | --- |
| `mods/ITEMS/mcl_campfires/api.lua` | `68b95b53bdfa1ff6ef16333194421a5a03501f3301a89cd48140012e6f4e75ad` |
| `mods/ITEMS/mcl_campfires/register.lua` | `7989cd06ba664c65a55d8dfc082a51660593be7eb518a7784877a3488b9c25c0` |

## Ported behavior

The ordinary lit inventory block retains ID 531. IDs 1220–1223 add an unlit ordinary campfire, lit soul campfire, unlit soul campfire and soul soil. Both recipes use three sticks and three logs. Ordinary fires accept coal or charcoal; soul fires accept soul sand or soul soil (`register.lua:28–45`). `special_recipe()` accepts mixed logs, stripped logs and bark from all six implemented tree families, plus crimson and warped stems, matching the available source tree group. The generic recipe guide accepts every eligible log species, including mixed inputs.

There are four visible, independent cooking positions (`api.lua:9–14,80–108`). Each holds one eligible raw food and has its own saved clock. Eligible existing items are raw beef, pork, chicken, mutton, rabbit, cod, salmon, potatoes and kelp; Voxey's legacy generic raw meat remains supported. Metals, logs, tropical fish and pufferfish do not cook. Source food registration defaults to ten furnace seconds (`mods/CORE/_mcl_autogroup/init.lua:478–485`), multiplied by three for the campfire. Each result ejects once on the first update strictly past 30 seconds (`api.lua:337–345`), with no fuel or output inventory. A full fire consumes nothing and prevents accidental eating of the attempted food. Creative placement preserves the held stack.

A shovel smothers a lit fire and takes one tool use in survival. Flint and steel, a fire charge or a burning arrow reignite it, preserving ordinary/soul identity and food positions (`api.lua:132–139,204–226`). Water potion splashes smother the impacted fire and four horizontal neighbors; lingering water affects its horizontal area (`mods/ITEMS/mcl_potions/functions.lua`, `_water_effect`). Normal adjacent water and rain have no special smother rule in the inspected source. Sneaking bypasses campfire use, and an animal in front of the block retains interaction priority.

Source food clocks continue after smothering: the source entity checks elapsed time without rechecking the campfire's lit state. Voxey preserves this observed behavior. Unlit fires cannot receive new food. Both state changes refresh the flame mesh and local light immediately.

The source collision/selection box is 0.45 blocks tall. Ordinary and soul fires deal two and four HP of fire contact damage per second, respectively; unlit states deal none (`api.lua:231–246`, `register.lua:9–22`). Fire resistance and creative immunity use existing Voxey damage rules. Fires cannot be pushed or accessed as furnace/hopper inventories. Ordinary fire light is stronger than soul fire light, corresponding to source levels 14 and 10.

Smoke rises from lit fires with source upward velocity and acceleration ranges. Hay below the campfire extends its maximum lifetime from 7.25 to 11.5 seconds; generation is limited to 75 blocks from the player (`api.lua:250–277`). `scripts/campfire_smoke.gd` keeps smoke independent of food/light display rebuilds, preventing those rebuilds from truncating a signal fire's plume. The voxel smoke shape, emission density, fade and point-light rendering are Voxey visual adaptations.

Ordinary survival breaking returns two charcoal; soul breaking returns one soul soil. Silk Touch returns the corresponding lit inventory block, including when breaking an unlit state. An enchanted book does not act as a Silk Touch tool. Creative breaking adds a campfire only if absent and there is room (`api.lua:35–47`). Explosions do not produce a block-material drop because the source node drop is empty. All destruction/replacement paths return cooking food once, retaining raw item metadata.

## Saved worlds and integration

The old Voxey campfire acted as an infinite-fuel, three-slot furnace. Migration copies every legacy input, fuel and output stack into a persisted return queue and creates four empty cooking positions. The queue is cleared before physical drops are spawned, so repeated updates do not duplicate returns. It preserves item IDs, counts, wear and metadata. JSON-loaded numeric fields are normalized before item registry lookups. Current cooking positions and independent clocks persist in the existing world station save data.

`Campfires.changed(world, position, old_id, new_id)` runs after successful block writes. It preserves state across lit/unlit changes and returns contents on replacement. `station()` also registers loaded campfire blocks. `update()` processes only loaded columns while the game is active. `use()` runs before generic eating and ignition. `break_node()` covers normal and explosion destruction. Collision and raycasts call `boxes()`. The existing display lifecycle calls `display_model()`, which returns food meshes and local light positioned at the block. Potion impacts/clouds and burning arrows use `water_splash()` and `ignite()`.

Two deliberate safety/engine adaptations are distinct from literal source parity. First, food returns from unlit removal and explosion as well as lit removal; the source only explicitly calls `drop_items` from the lit node's dig callback, leaving potential orphan food entities in the other paths. Second, Voxey pauses cooking in unloaded columns and menus, matching its active station simulation; Mineclonia stores a global game-time origin that can catch up after unloading. Migration returns old furnace contents rather than guessing how old stacks should occupy the new one-item spots.

`tests/campfire_checks.gd`, run through `tests/lifecycle_runner.gd`, covers real player dispatch, four staggered clocks, exact timing, food eligibility, inventory preservation, creative actions, smother/reignite, immediate light removal, contact damage/resistance, collision/raycast shape, potion extents, signal smoke lifetimes, JSON reload/unloading, metadata-preserving legacy migration, all four break states, Silk Touch, blast returns and survival recipes. Rendering is verified separately by the lifecycle visual tour.

This bounded batch does not establish all cross-system campfire parity. [Hive harvesting](beehives-source.md) now checks lit campfire smoke within five blocks below the hive. Soul-fire piglin avoidance remains a separate mob-AI gap. Voxey does not reproduce Luanti's light propagation or exact source smoke textures, animation and sound assets.

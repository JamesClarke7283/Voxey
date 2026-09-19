# Pumpkin and melon farming

Reference: the installed Mineclonia tree at `/home/impulse/.minetest/games/mineclonia`, especially `mods/ITEMS/mcl_farming/{pumpkin,melon,shared_functions,soil}.lua`, `mods/ENTITIES/mcl_item_entity/init.lua`, `mods/ITEMS/mcl_dungeons/init.lua` and `mods/ITEMS/REDSTONE/mcl_pistons/api.lua`.

Attribution: Mineclonia and MineClone contributors. Adapted source algorithms follow [GPL-3.0-or-later](licenses/Mineclonia-GPL-3.0.txt); Voxey meshes, textures and UI artwork are original.

Implemented in `scripts/fruit_crops.gd`, with original geometric stems, carved faces and seed icons. Existing item IDs remain compatible: carved pumpkin 45, pumpkin 46, melon 47, pumpkin pie 131 and melon slice 132. New seeds use 7500/7501; pumpkin stems 7510–7521 and melon stems 7530–7541 include eight growth stages and four attached directions. Carved orientation states 7551–7553 preserve canonical item 45. Jack o'lanterns use 7560–7563.

## Survival loop

Natural pumpkins and melons already generated in Voxey now supply these recipes: one pumpkin makes four pumpkin seeds, one melon slice makes one melon seed, and nine slices reconstruct a melon. Dungeon supply loot contains each seed at its source weight 10 and stack size 2–4, retaining the other entries' weights. Seeds stack to 64, compost at 30% and tempt/feed/breed chickens. Pumpkin pie keeps its existing recipe and source nutrition. The previous conflicting pumpkin-to-yellow-dye recipe is removed.

Use seeds on farmland with air above to plant the first stage. The stem stays non-solid but has its source stage-dependent selection height. Established stems retain the source attached-node rule: any walkable solid block can support them; destroying support breaks them. Water/lava flow can clear stems through the existing plant-fluid rules.

Young stems use the source 30-second, one-in-five growth attempt. Saved elapsed game time and running mean light reproduce `grow_plant`, including its ceiling arithmetic: the normal first attempt advances two stages; fresh bone meal adds a random 2–5 plus the rounded interval, giving three to six stages. Mature or attached stems do not consume bone meal. Ordinary growth needs light 10, while long elapsed intervals use the source average-light adjustment. Load registration queues one catch-up attempt per young stem. World edits and block metadata persist stages, attachments, last growth time and the light accumulator.

Mature pumpkin stems attempt fruit every 30 seconds with chance 1/15; melon stems use 25 seconds and 1/15. Fruit needs light greater than 10, adjacent air and farmland, dirt or a grass block underneath. Growth chooses uniformly among eligible neighbors and converts destination farmland to dirt. It attaches the mature stem to that fruit; removing the fruit disconnects the stem or reconnects it to another existing matching fruit. Attached stems cannot make a second simultaneous fruit. Carved pumpkins do not count as raw attached fruit.

Source stem drops use a sequential rarity table, independent of stage: one seed at 1/6, otherwise two at 1/31, otherwise three at 1/125, otherwise nothing. Silk Touch and Fortune do not change stems. Ordinary melon drops use the source sequential table: seven slices at 1/14, otherwise six at 1/10, otherwise five at 1/5, otherwise four at 1/2, otherwise three. Silk Touch yields the intact melon. Fortune rolls uniformly from 3 through 7+level and caps the result at 9.

## Carving, light and equipment

Using shears on a horizontal raw-pumpkin face carves that face and drops four seeds. Survival consumes one shears durability; creative still drops four seeds without wear. Top/bottom use and already-carved pumpkins do not duplicate seeds. A carved pumpkin above a torch crafts a jack o'lantern, which emits light 14 and retains its placed orientation across saves.

Carved pumpkins stack to 64 but equip one at a time in the helmet slot or through inventory Shift-click. They have no armor protection and do not wear out. Ordinary block use places the pumpkin. Wearing one displays an original cutout mask and prevents Enderman gaze provocation; it does not prevent retaliation after attacking an Enderman. Jack o'lanterns are not armor.

Raw pumpkin, melon, carved pumpkin and jack o'lantern have source `dig_by_piston=1` and `unsticky=1`. Their piston harvest ignores a player's held enchantments and creative mode. Stems have neither explicit group in the source; piston movement and subsequent support validation handle them rather than assigning a made-up dig group.

## Engine adaptations and remaining dependencies

Growth now reads the actual hydrated node from [farmland soil](farmland-source.md). The saved wet/dry states and source 15-second, one-in-four hydration/decay checks replace the earlier instantaneous water-footprint approximation. Rain prevents decay in exposed soil; it does not directly hydrate dry farmland in the supplied source.

The source game-time multiplier maps to Voxey's existing 1,200-second day. Simulation indexes only loaded stems, processes up to eight queued growth actions per frame, and invalidates stale jobs when a crop is removed and replanted. Unload/reset clear runtime indexes without deleting saved crop state. A successful fruit appearance uses bounded, swept collision recovery for players, creatures, mounts and boats because Voxey moves bodies manually; corrections do not pass through surrounding walls or unloaded space.

Placing a carved pumpkin or jack o'lantern now supports [iron and snow golem construction](golems-source.md). Carving a pumpkin already in place does not invoke the source placement callback. Source enderman block pickup remains outside this implementation.

Focused regressions are in `tests/fruit_crop_checks.gd`, covering actual mouse use, crafting, stage geometry, attachment cycles, timed growth, hydration/light boundaries, probabilistic source drops, enchantments, carving, actor recovery, environmental harvesting, inventory equipment, gaze protection and actual save/load.

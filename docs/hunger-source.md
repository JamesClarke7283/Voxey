# Hunger and food parity

Reference checkout: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-09-16. This installed copy has no Git metadata, so no revision hash is available.

`scripts/hunger.gd` follows these local source files:

- `mods/PLAYER/mcl_hunger/init.lua`: initial saturation of 5, action exhaustion constants, full-food regeneration every 0.5 seconds, regeneration at 18+ food every 4 seconds, starvation every 4 seconds and Normal difficulty's 1-HP floor.
- `mods/PLAYER/mcl_hunger/api.lua`: 4000 exhaustion threshold, clamped exhaustion increments, 1.5 saturation depletion before food depletion, saturation bounded by current hunger.
- `mods/PLAYER/mcl_hunger/hunger.lua`: food saturation is added **before** hunger restoration, including its pre-meal saturation ceiling; special foods and creative players can eat when full.
- `mods/PLAYER/mcl_sprint/init.lua`: exhaustion per complete horizontal meter sprinted. Swimming tracks distance in all three axes; ordinary walking and standing have no exhaustion cost.
- `mods/CORE/mcl_damage/init.lua`: starvation bypasses armor and magic protection.

Nutrition is saved in the optional `nutrition` object. Old saves default to 5 saturation, clamped to current hunger, and zero exhaustion. Loading rejects malformed and non-finite values. New worlds, respawns, healing commands and creative transitions reset nutrition. Food tick and movement accumulators are transient, as in the reference. Hunger advances while riding; riding itself has no movement exhaustion.

Food values come from `mods/ITEMS/mcl_core/craftitems.lua`, `mcl_mobitems/init.lua`, `mcl_farming/{wheat,carrots,potatoes,beetroot,pumpkin,melon,sweet_berry}.lua`, `mcl_fishing/items.lua`, `mcl_mushrooms/small.lua`, `mcl_sus_stew/init.lua`, `mcl_ocean/kelp.lua`, and `mcl_end/chorus_plant.lua`. Bread restores 5 food, rotten flesh 4, golden apples 4; Voxey's generic meat maps to beef/steak. Individual foods now grant their reference saturation values. Custom items may specify `saturation` and `can_eat_when_full`.

`scripts/eating.gd` preserves held-use eating and the existing 1.61-second duration (0.8 seconds for dried kelp). Cancelled eating grants nothing. It applies source food effects: 80% rotten-flesh and 30% raw-chicken Hunger I for 30 seconds; spider-eye Poison I for 5 seconds; pufferfish Hunger III for 15 seconds, Poison III for 60 seconds, and Nausea II for 15 seconds; golden-apple Regeneration II for 5 seconds and Absorption I for 120 seconds. `mcl_potions/functions.lua` supplies hunger's 100 exhaustion per level per second and absorption's 4 HP per level. Reapplying absorption replenishes its shield; saves retain the remaining shield and milk/expiry remove it. Nausea uses a mild camera sway adapted to Voxey's renderer.

Known scope limits: Voxey still has one survival difficulty, using the source Normal starvation floor. Cake remains the existing portable whole-cake item with 14 food and the seven slices' combined 2.8 saturation; placement and slice interaction are separate work. Chorus-fruit teleportation and flower-specific suspicious-stew effects remain separate gaps. Full-hunger permission for those special foods matches the reference, but their missing effects are not claimed as implemented.

`tests/hunger_checks.gd` covers exhaustion thresholds, source regeneration and starvation timing, movement costs, creative immunity, meal cancellation and completion, food poisoning, absorption damage/expiry/save behavior, migration and malformed saves. Existing environment and alchemy tests cover eating and effect regressions.

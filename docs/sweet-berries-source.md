# Sweet berries

Behavioral reference: the supplied Mineclonia
`mods/ITEMS/mcl_farming/sweet_berry.lua` and `shared_functions.lua`, plus the
actual dispatchers in `mods/ITEMS/mcl_bone_meal/init.lua`,
`mods/CORE/mcl_util/environment.lua`, and
`mods/PLAYER/mcl_hunger/{instanteat,holdeat}.lua`. Natural acquisition references
are `mcl_farming/lg_register.lua`, `mcl_biomes/init.lua`, and
`mcl_villages/schemgen.lua`. The implementation and procedural art in
`SweetBerryCrops` are original GDScript; the reference is GPL-3.0-or-later.

`SweetBerryThorns` remains the sole authority for contact damage and slowdown.
This lifecycle neither duplicates nor calls that damage system.

## Saved content and planting

The four existing bush IDs remain **567, 568, 569, 570**, corresponding to source
stages 0–3. The sweet-berry item remains **775**. Bushes are hidden, noncolliding,
zero-hardness plants; their base/pick item is the berry, not a separately
obtainable bush item.

The source planting list is exact: grass, dirt, podzol, coarse dirt, dry
farmland, wet farmland, and moss. Voxey has every one except podzol, which has no
content ID and is not replaced with a look-alike. Swamp grass, dirt paths, mud,
stone, and other modern/generic soil guesses are not accepted. A successful
plant requires a top-face click, an accepted clicked host, and literal air above
it. Side/bottom clicks, non-air cells, fluids, and replaceable-snow shortcuts do
not plant. Survival consumes one berry; creative consumes none. Successful
planting selects stage 0 and prevents the held food from being eaten. An
unsuccessful placement is allowed to fall through to ordinary food handling.

Sweet berries restore two hunger points and 0.4 saturation. The item and all
four bush stages have source compostability 30. Source bush groups also specify
`dig_immediate=3`, `plant=1`, `attached_node=1`, `dig_by_water=1`,
`destroy_by_lava_flow=1`, `dig_by_piston=1`, flammability 3, fire encouragement
60, and fire flammability 20. Stages 1–3 alone carry the thorny group.

## Drops and right-click harvest

Breaking stage 0 or 1 drops nothing. Stage 2 drops one berry with probability
1/2, otherwise two; stage 3 drops two with probability 1/2, otherwise three.
This is the source `max_items=1` table: the lower-count row has rarity two and
the higher-count row is the fallback. Fortune and Silk Touch do not replace it.
Creative mining suppresses drops normally.

A non-sneaking right click on stage 2 or 3 independently rolls the same two
counts, spawns those berries even in creative, and resets the bush to **stage
1**. It never consumes the held item. Bone meal is explicitly excluded from
harvest. Source `core.swap_node` preserves node metadata, so the Voxey harvest
preserves the complete growth-history entry while changing the stage.

Support loss, water flow, and piston digging use that same ordinary drop table,
including during creative automation. Lava destroys the bush without drops.
The source's attached-node behavior permits an existing bush on any walkable
solid support; the stricter host list is for planting, not a continuing soil
requirement. Piston support checks are deferred until movement finishes.

## Shared growth and persistence

The source registration is interval **68 seconds**, chance **1 in 3**. It is not
a fixed 30-second crop timer. Each scheduled attempt uses the shared farming
algorithm, whose nominal period is `68 * 3 = 204` seconds:

- Fresh history supplies one tenth of a period. The requested one stage plus
  `ceil(0.1)` advances two visual stages: stage 0 → 2 and stage 1 → 3.
- Only literal wet farmland avoids `low_speed`. Grass, dirt, coarse dirt, moss,
  dry farmland, and every other non-wet support all use it. On an early attempt,
  9/10 of dry attempts stop after writing history; the surviving 1/10 divides
  elapsed intervals by ten.
- Recent natural attempts require current light at least 10. Long catch-up uses
  saved elapsed time and the rolling historical light average, including the
  source's dark-history rejection and dim-history scaling.
- Exact time equality, same-stage metadata clearing, out-of-range mature
  fallback, and current-light bypass for bone meal come from `FarmingRules`;
  there is no simplified substitute growth implementation.

The runtime indexes only loaded bushes and columns. Column load queues at most
one catch-up job per immature bush. Unload removes active jobs/indexes without
deleting the saved block state. Stale serials cannot affect a removed/replanted
bush, and updates process at most eight queued jobs per call. Metadata lives in
`world.block_states` under `sweet_berry`: `last_time`, `light_count`, and
`light_total`. Node replacement through growth clears old history, as source
`set_node` does; right-click harvest is the metadata-preserving exception.

## Verified bone-meal dispatch quirk

The sweet-berry `_on_bone_meal` callback calls the shared one-stage growth helper
but **does not return its result**. Consequently, if the bone-meal dispatcher is
reached, its Lua `nil` is not `false`: bone meal is consumed and particles are
produced even on a mature bush that cannot grow.

Normal item dispatch adds a crucial earlier step. `mcl_bone_meal.on_place` calls
`mcl_util.call_on_rightclick` before its `_on_bone_meal` dispatcher. Only stages
2 and 3 have a bush `on_rightclick`; its bone-meal branch returns the unchanged
stack. The real Luanti full `on_place` path was exercised and produced:

| Initial stage | Result | Bone meal | Particle calls | Harvest |
|---|---|---|---|---|
| 0 | stage 2 | consumed once | 2 | none |
| 1 | stage 3 | consumed once | 2 | none |
| 2 | unchanged stage 2 | unchanged | 0 | none |
| 3 | unchanged stage 3 | unchanged | 0 | none |

Thus ordinary bone meal grows only pre-fruit bushes and does **not** consume on
fruit-bearing bushes. This is intentional source compatibility, not a missing
growth callback. The source sneak control bypasses `on_rightclick`; sneaking
therefore reaches the callback at every stage, grows stage 2 to 3, and consumes
through the nil-return rule even at stage 3. All these interactions prevent an
accidental food action where the source calls `prevent_eating`.

## Selection and art

Source selection boxes have local X/Z minima 1/8 and sizes 3/4. Their local
heights are **0.20, 0.45, 0.70, 0.95** for stages 0–3, from
`-0.30 + stage * 0.25` after translating node-centered coordinates to Voxey's
block-base coordinates. The generic plant renderer supplies the source-style
crossed mesh; `mesh` exposes the same helper for focused checks. Original
16×16 foliage/berry pixels distinguish all four stages, and the berry has an
original inventory icon.

## Natural and survival acquisition

Mineclonia generates mature stage-3 bushes through its berry patch features and
taiga-family decoration. Voxey's existing `terrain_generator.gd` already places
ID 570, so no new generator or content ID is needed. Harvesting those natural
bushes yields the item that plants stage 0, closing the survival loop. Source
taiga village-house chest loot also contains 1–7 sweet berries at weight 5. The
master butcher trade buys 10 berries for an emerald; it is a survival sink, not
an additional way for the player to obtain berries.

## Exact parent integration hooks

The parent owns all shared-file edits. Required hooks are:

1. **`village_survival.gd` (`use`)**: dispatch `SweetBerryCrops.use(game,target)`
   immediately before `CropFarming.use`. Remove sweet berries from the following
   legacy `VillageContent.CROPS` planting branch and exclude bushes from the
   legacy crop-shaped bone-meal branch. Do not leave the grass/dirt-only fallback.
2. **`game.gd` (`break_node`)**: call
   `SweetBerryCrops.break_node(self,p,id,tool)` before generic
   `Harvesting`/enchantment/crop-drop handling and return when handled.
3. **`voxel_world.gd`**: call `reset`, `update`, `registered(...,true)` in both
   generated and edited column loops, `column_loaded`, `unload`, and `changed`
   beside their `CropFarming` counterparts. Classify bushes with `HOOK_CROP` and
   `NEAR_CROP`. Exclude bushes from legacy `growth` initialization and the
   `_simulate` crop-shaped timer. Add them to shaped raycast routing and route
   `shape_hit` to `SweetBerryCrops.boxes`.
4. **`node_info.gd`**: include bushes in `SPECIAL`, so saved/generated columns
   deliver their registration hooks. Their existing plant/crop classification
   continues to provide noncollision, transparency, and crossed meshing.
5. **`fluids.gd` (`settle`)**: before generic replaceable drops, handle bushes
   like crops: water emits `SweetBerryCrops.harvest`; lava emits nothing. The
   existing fluid replacement then removes the node.
6. **`piston_push.gd`**: include bushes in `diggable`, dispatch
   `SweetBerryCrops.piston_break` from `destroy`, and refresh the changed cell
   and its upper neighbor from `finish` after deferred support resolution.
7. **`player.gd`**: include bushes in selection/crack shaped-node conditions
   and use `Barriers.box_visuals(SweetBerryCrops.boxes(id),"sweet_berry:"+str(id))`.
   The existing `SweetBerryThorns` movement calls stay unchanged.
8. **`village_content.gd`**: preserve IDs and `CROPS[SWEET_BERRY]`, but route
   `crop_seed`/`crop_drops` for bushes to this module instead of the legacy crop
   fallback. Mark stage nodes hidden, hardness zero, and flammable (or provide
   the equivalent `Fire.flammable` branch). No registry renumbering.
9. **`nodes.gd` / `mining_nodes.gd` / `harvesting.gd`**: bushes are harvestable
   by hand, their generic drop is zero, and pick/base item is 775. Resolve source
   names through `SweetBerryCrops.source_node`; map a harvested bush to its base
   item where item conversion requires it. Keep the dedicated break hook ahead
   of generic drop transformation.
10. **`composters.gd` (`chance`)**: return the nonzero
    `SweetBerryCrops.compost_chance(id)` before fallback chances. The existing
    berry fallback is retained harmlessly, but this also covers all bush IDs.
11. **`village_art.gd` / `village_item_art.gd`**: route bush pixels to
    `SweetBerryCrops.pixel` and item 775 to `SweetBerryCrops.draw` before generic
    VillageContent art. The existing crossed plant mesher needs no new mesh kind.
12. **`tests/lifecycle_runner.gd`**: add `sweet_berry_crop` to the ordered checks
    so `tests/sweet_berry_crop_checks.gd` runs after integration. Do not merge it
    into or replace the existing thorn checks.

The focused suite covers actual survival dispatch, host/face/air planting,
creative and survival consumption, drop distributions, real mining, metadata-
preserving harvest, the verified bone-meal quirk, shared growth/history,
loaded-column work, support/water/lava/pistons, exact raycast boxes, compost,
food/art, natural-stage harvesting, and actual save/load. Tests are to be run by
the parent after these shared hooks land.

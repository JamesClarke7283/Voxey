# Wheat, carrots, potatoes and beetroot

This implementation follows the supplied Mineclonia source under
`/home/impulse/.minetest/games/mineclonia/mods/ITEMS/mcl_farming/`:
`wheat.lua`, `carrots.lua`, `potatoes.lua`, `beetroot.lua`,
`shared_functions.lua` and `soil.lua`. The source bone-meal dispatcher in
`mods/ITEMS/mcl_bone_meal/init.lua` supplies the consumption rule. Fortune
uses the discrete uniform distribution in Mineclonia's item-drop handler.

`CropFarming` owns the four crop lifecycles. `Farmland` supplies dry/wet
soil states; the existing nether-wart and sweet-berry implementations are
separate and retain their earlier behavior.

## Saved IDs and growth

| Crop | Source stages | IDs in stage order | Growth interval / chance |
|---|---:|---|---|
| Wheat | 8 | 22, 8010–8015, 29 | 25 seconds / 20 |
| Carrot | 8 | 551, 8020, 552, 8021, 553, 8022, 8023, 554 | 25 seconds / 20 |
| Potato | 8 | 555, 8030, 556, 8031, 557, 8032, 8033, 558 | 19.75 seconds / 20 |
| Beetroot | 4 | 559–562 | 68 seconds / 3 |

Existing immature carrot/potato IDs preserve the corresponding source
visual ages 1, 3 and 5; mature IDs and existing wheat/beetroot IDs remain
unchanged. New stages are hidden from the creative catalog. Exact source
selection boxes and noncolliding plants accompany original procedural
plant art. Plants retain the source block-base location, leaving the
1/16-block gap over the lowered farmland surface.

Planting uses actual air above dry or wet farmland. Carrots and potatoes
prefer planting over eating when that placement succeeds. Existing plants
use the source attached-node rule: any walkable solid support is sufficient.
Removing support drops the plant's ordinary harvest exactly once.

Scheduled growth uses each source interval and random chance, then the
shared source algorithm: current light of at least 10 for a recent attempt,
1/10 early growth on soil whose node is not wet, and saved elapsed time
plus a rolling historical light average for unloaded catch-up. The first
successful fresh attempt advances two stages because the source adds
`ceil(0.1)` to the requested one stage. Time uses Voxey's existing
20-minute day clock. Successful node replacement resets that stage's
growth history, as source `set_node` does.

Block-state metadata stores `last_time`, `light_count` and `light_total`.
Column load queues one catch-up attempt; unloading removes active jobs and
indexes without deleting the saved state. Runtime work consumes at most
eight queued attempts per update. Stale jobs cannot affect a removed and
replanted crop. World/dimension resets discard runtime indexes. Worker
application validates support after edited terrain has been reconciled.

Bone meal requests 2–5 stages for wheat/carrot/potato, plus the same source
elapsed-time rounding. Beetroot rolls 75% for a one-stage request. Its
source callback returns `nil` on the other 25%, and the bone-meal dispatcher
consumes any result other than `false`; consequently that no-growth result
consumes bone meal, including on mature beetroot. Mature wheat/carrot/potato
do not consume it. Current darkness is ignored by bone meal, while the
shared long-history behavior remains intact.

## Harvesting and use

Immature crops always return one planting item. Mature ordinary drops are:

- Wheat: one grain and one seed, independently adding a seed at 1/2 and 1/5.
- Carrots: sequential tests for four carrots at 1/5, three at 1/2, two at
  1/2, otherwise one. These are not independent or uniform outcomes.
- Potatoes: one potato plus three independent 1/2 extra potatoes and an
  independent 1/50 poisonous potato.
- Beetroot: one beetroot and sequential seed tests for four at 1/6, three
  at 1/4, two at 1/3, otherwise one.

Fortune adds its level to the upper endpoint of a uniform integer roll,
then caps the result: wheat seeds 1..6, cap 7; carrots/potatoes 2..4, cap 5;
beetroot seeds 1..3, cap 5. Wheat grain and beetroot remain guaranteed.
Source Fortune replaces the ordinary potato table, so it does not produce
poisonous potatoes. Silk Touch does not preserve crop nodes. Merely holding
an enchanted book does not apply Fortune.

Flowing water uses ordinary harvest drops; lava destroys crops without
drops. Pistons destroy all four crops. Only wheat has source `unsticky=1`:
side contact with an adhesive piston assembly leaves wheat alone, but
harvests attached carrots, potatoes or beetroot. Environmental harvest does
not inherit the player's enchantments and also produces drops during
creative piston automation. Support checks are deferred until piston
movement finishes.

Existing village plots, wheat-seed acquisition, animal foods and dungeon
beetroot-seed loot remain usable. Source food recipes include bread,
golden carrots, baked potatoes, beetroot-to-red-dye and the shaped beetroot
soup recipe: two full rows of beetroot above a centered bowl. Eating soup
returns one bowl. Crop farming does not replace the separate cocoa or
other plant systems.

Poisonous potato ID 8070 is obtainable through the actual potato harvest.
It stacks to 64, restores two hunger points and 1.2 saturation, and has an
inclusive 60% chance of Poison I for five seconds. It cannot plant a crop,
cook into a baked potato or enter a composter. Its icon is original art.

## Validation and boundaries

`tests/crop_farming_checks.gd` exercises actual mouse-use planting and bone
meal, all registered crop stages and raycasts, scheduled growth, seeded
harvest distributions and Fortune caps, darkness/history, real mining,
water/lava, adhesive/direct piston contact, crafting/eating, bounded jobs,
worker support reconciliation, and actual save/load plus unload/reload.
The test plot is above Y2100 so buildings from earlier ordered suites do
not accidentally shade growth assertions.

Voxey uses its shared voxel light approximation, with maximum skylight 14,
while preserving the source crop threshold 10. Simulation is limited to
loaded columns and catch-up is applied on load; it does not run arbitrary
unloaded-world ticks. Original voxel geometry replaces Mineclonia's plant
textures. Nether wart, sweet berries and cocoa retain their earlier
simplified systems and are not claimed as part of this parity batch.

Focused isolated checks: **162 passed, 0 failed**, with no script errors (`/tmp/voxey-crop-final.log`).

The rendered `tests/farm_golem_tour.gd` also verifies crop stages, wet/dry furrows and lowered soil, both construction patterns, constructed/sheared golem models and farming inventory icons. Images are written to `/tmp/voxey-farm-golem-shots/` using isolated temporary saves.

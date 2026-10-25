# Nether wart

The behavioral reference is the supplied Mineclonia checkout, principally
`mods/ITEMS/mcl_nether/nether_wart.lua`. Soil registration was checked across
the whole checkout; the only `soil_nether_wart=1` assignment is
`mcl_nether:soul_sand` in `mods/ITEMS/mcl_nether/init.lua:145-159`. In
particular, soul soil, nylium and nether wart blocks are not wart soil.

`NetherWartCrops` is original GDScript. Existing saved node IDs 563–566 and item
ID 774 retain their meanings. The source names on the registry entries are
`mcl_nether:nether_wart_0`, `_1`, `_2`, `mcl_nether:nether_wart`, and
`mcl_nether:nether_wart_item`.

## Placement and support

The item places stage 0 only in a `buildable_to` cell immediately above soul
sand. This is not an air-only rule: the shared replacement set includes snow,
plants, liquids and fire as well as air. The cell below the pointed position
must carry the soil group, which naturally rejects side placement. Survival
consumes one item; creative placement does not.

Every wart node has `attached_node=1`. Losing or changing the soul-sand support
therefore breaks the plant with its ordinary, unenchanted drops. Support checks
also run after edited columns are reconciled and after piston movement. A check
is deferred while the supporting column is unloaded rather than treating an
unknown node as air.

The plants are nonwalkable. Their exact source fixed selection boxes, converted
from centered coordinates to Voxey's lower-corner coordinates, are:

| IDs | Source stage | Selection size |
|---|---|---|
| 563 | 1 | 1 × 0.375 × 1 |
| 564, 565 | 2 and 3 | 1 × 0.65 × 1 |
| 566 | mature | 1 × 0.95 × 1 |

These boxes are for selection only and do not add collision.

## Growth

The source ABM names only the three immature nodes. Its interval is 35 seconds,
its chance is 11, and a successful action advances exactly one stage; stage 2
becomes the mature node on the third successful step. It checks the soil again
before growing. The runtime follows that schedule with an independent roll per
loaded immature plant. Mature plants remain registered for support handling but
do not receive growth rolls.

There is no light threshold, dimension check, biome check, hydration rule or
elapsed-time catch-up formula in this source. Growth consequently works in the
Overworld, Nether and End, including complete darkness. Unloaded columns do not
accumulate wart growth jobs. Loading registers saved nodes, unloading removes
runtime indices without changing saved node IDs, and a world/dimension reset
clears the runtime. The old Voxey 30-second `world.growth` entry is erased when a
wart is registered or changed; no second simplified timer remains.

`nether_wart.lua` has no `_on_bone_meal` callback. Bone meal therefore neither
advances a stage nor gets consumed by wart interaction. The generic crop
bone-meal ladder must not handle these IDs.

## Drops, fluids and pistons

Drops are resolved through `Harvesting` and the already exported definitions in
`assets/data/harvesting.json`; there is no second locally guessed drop table.

- Each immature stage drops one nether wart item.
- The mature ordinary table first awards two items, then tries a second
  two-item entry at rarity 3 and a one-item entry at rarity 3, with at most two
  successful entries. The resulting counts are 2 with probability 4/9, 3 with
  probability 2/9, and 4 with probability 1/3.
- Mature `_mcl_fortune_drop` **replaces** that table. Fortune level $F$ produces
  one stack whose count is discrete-uniform from 2 through $4+F$, with no cap.
  Fortune III therefore produces 2–7 uniformly. It is not a multiplier of the
  ordinary outcome.
- Silk Touch has no wart-node override. An enchanted book does not activate
  Fortune.

Water flow uses the ordinary drop table, while lava flow destroys the plant
without drops. Direct piston contact digs every stage with ordinary drops,
including in creative automation. Every stage also has `unsticky=1`, so adhesive
side contact does not drag it into a piston assembly.

## Art and acquisition

The mesh helpers draw original crossed-plant geometry at the three source
selection heights. Procedural atlas pixels make source stages 2 and 3 visually
identical, as their shared `mcl_nether_nether_wart_stage_1.png` requires. Item
774 has an original 16×16 inventory sprite. Mineclonia's textures and its
`meshoptions`/`place_param2=3` rendering data are not copied; Voxey has no
per-node param2 store for that orientation variation.

Existing survival acquisition remains intact: Voxey's fortress fixture places
source stage-0 wart over soul sand, matching `corridor_nether_warts`, and its
Nether structure loot can contain item 774. Brewing, composting,
red-nether-brick and nether-wart-block consumers retain the same item ID.

## Integration and focused checks

`tests/nether_wart_crop_checks.gd` exercises actual mouse planting and bone-meal
use, all saved stages, exact raycast boxes and noncollision, darkness and all
three dimensions, source scheduling, registered ordinary/Fortune drops, real
mining, water/lava, direct and adhesive pistons, support reconciliation, and
actual save/load/unload behavior. It also checks the existing fortress
acquisition fixture. The suite is intended for integration into the existing
lifecycle runner; it was not executed by the isolated module worker.

The shared integration must route registry DATA/source names, mesh and pixel/item
art, selection boxes, use, node changes, column registration/load/unload,
world update/reset, fluid removal, piston digging/unsticky/support completion,
and legacy-growth exclusion through this module. The existing source-aware
`Harvesting` game-break path handles actual mining once the `source_node` names
are present.

# Experience orbs

Voxey follows `HUD/mcl_experience/{orb,init,bottle}.lua` in the supplied
Mineclonia checkout. The implementation is original GDScript using the source as a
behavioural reference.

## Why it mattered

Experience was a single float. Every award was a direct `game.experience += n`, and
**dying cost nothing**: `game.die()` never touched the balance, so the source's
entire death penalty was missing. It also meant the reference's ore `group:xp`
payout had no delivery mechanism, which is why Voxey paid a flat one point for
every deep ore instead of the source's per-ore table.

## The orb — `orb.lua`:151-222

| Property | Source | Voxey |
|---|---|---|
| Throw velocity | `(random(-2,2)*random(), random(2,5), random(-2,2)*random())` | same bounds in `throw_velocity` |
| Life | `max_orb_age = 300` | `MAX_ORB_AGE` |
| Magnet | `distance < 7.25` claims the orb | `MAGNET_RANGE` |
| Collection | awards within `0.8` of the collect point | `COLLECT_RANGE` |
| Gravity | `movement_gravity`, 9.81 down | `GRAVITY` |
| Slippery slide | `slip_factor = 4.0/(slippery+4)` | `SLIP_BASE`, via `DenseMaterials.slippery` |
| Size ladder | `size_to_xp`, 11 buckets from 20 to 59 units | `orb_for`, `size_for` |

Orbs are `Node3D`s added to `game.entities`, drawn as an emissive sphere scaled by
the ladder index, but their motion is integrated by `XpOrbs.update` rather than
`_physics_process`, so a paused game freezes them and the checks can step them.
`static_save = false` in the source maps onto Voxey's `_clear_entities`, which
already drops everything under `game.entities` on a new world or a dimension change.

## Two source quirks, ported rather than corrected

1. **`100` caps the orb count, not the orb size.** `init.lua`:140's loop is
   `while i < total_xp and j < 100`, and each orb draws its own value, so a single
   orb may be worth 1234 and a request above `100 * 32767` truncates. A
   per-orb ceiling would have made buckets 7-11 unreachable.
2. **The ladder lookup compares each row's *lower* field** (`xp > size_to_xp[i][1]`),
   so the loop lands one row above the table's own bounds: the reachable rows are
   `<=3, 4..7, 8..17, ... 618..1237, 1238+`, and bucket 0 is unreachable.

Both are documented in the module header and asserted as the ported behaviour.

## The awards moved to orbs

Every site the source routes through `throw_xp` now throws:

| Award | Source | Voxey site |
|---|---|---|
| Mob death | `mcl_mobs/physics.lua`:279 | `creature.gd` `die` |
| Breeding | `mcl_mobs/breeding.lua`:212 | `farming.gd` |
| Fishing | `mcl_fishing/init.lua`:144 | `fishing.gd` |
| Spawner | `mcl_mobspawners/init.lua`:291 | `dungeons.gd` |
| Sculk | `mcl_sculk/init.lua`:95-105 | `game.gd` `break_node` |
| Ore `group:xp` | `mcl_item_entity/init.lua`:216-220 | `game.gd` `break_node`, `Nodes.ore_xp` |
| Bottle o' enchanting | `bottle.lua`:17 | `village_survival.gd`, `thrown_item.gd` |
| Grindstone | `mcl_grindstone/init.lua`:282-283 | `grindstone_repair.gd`, `village_survival.gd` |
| Dragon | `mobs_mc/ender_dragon.lua`:224-229 | `adventure.gd` |
| Villager trade | `mobs_mc/villager.lua`:402 | `village_life.gd` |
| Achievement | `mcl_achievements/init.lua`:23 | `achievements.gd` |

Direct awards the source does **not** orbify — the anvil and enchanting payments —
stay as they are.

## The ore table

`Nodes.ore_xp` is the source's own per-ore `group:xp`:

| Ore | XP |
|---|---|
| Coal | 1 |
| Nether gold | 1 |
| Nether quartz | 3 |
| Diamond | 4 |
| Emerald | 6 |
| Lapis | 6 |
| Redstone (lit and unlit) | 7 |
| Ancient debris | 0 |
| Iron, gold, copper | no `xp` group — nothing |

Voxey paid a flat 1 for every deep ore, which overpaid iron and gold and underpaid
diamond and emerald.

## Death

`mcl_experience`'s `register_on_dieplayer` throws the whole balance at the death
point and zeroes it, unless `mcl_keepInventory` is set. `game.die()` now does the
same when `keepInventory` is off, so a death finally costs experience as well as
items.

## Verification

`tests/xp_orb_checks.gd` (54 checks) covers the split invariants (sum equals the
request, at most 100 orbs, every orb within the size cap), the ladder boundaries
including the shifted row, the throw velocity bounds, the magnet and collection
distances, the 300-second cap, the slippery slide, Mending delivery through the
experience setter, and a distant player being ignored. The five check files whose
awards moved from direct credit to thrown orbs were rewritten to assert the orb
total and then the collection, rather than re-pinned to the new text.

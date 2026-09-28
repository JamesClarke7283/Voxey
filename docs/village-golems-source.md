# Village iron golems

`ENTITIES/mobs_mc/villager.lua` gives a village a **self-defence it can grow**. The
relevant pieces, all in that one file:

| Function | Line | What it decides |
| --- | --- | --- |
| `summon_golem` | 3431 | where the golem appears |
| `maybe_summon_golem` | 3463 | whether enough villagers want one |
| `desires_golem` | 3426 | whether *this* villager wants one |
| `slept_recently_enough_for_golem` | 3419 | `_last_slept_gmt` within 1200s |
| `seen_golem_lately` | 3423 | `_last_golem_gmt` within 30s |
| `sense_villagers_requesting_golem` | 3215 | the area sweep of willing villagers |
| `gossip_with` | 2559 | the trade-time gossip and its own request |
| `copy_gossips` | 2544 | how a reputation travels to a listener |
| `gossip_types` | 2463 | the per-type caps, decays and multipliers |

## The desire rule

```
desires_golem(gmt) = slept_recently_enough_for_golem(gmt) and not seen_golem_lately(gmt)
```

A villager wants a golem only if it has used a bed within 1200 game seconds **and**
has not been near one within 30. The second half is what stops a village that already
has a golem from building another.

## The two thresholds

`maybe_summon_golem(self_pos, n_villagers)` is called from exactly two places:

* `start_panic` (line 3490) passes **3**, and only while the villager is actually
  panicking — `seen_hostile_lately`.
* `gossip_with` (line 2574) passes **5**, on the ordinary path, at the moment a
  trade happens.

The count comes from `sense_villagers_requesting_golem`, which sweeps
`self_pos ± (10,10,10)` and collects every villager that `desires_golem`. **The
asking villager is inside that box**, so the threshold is a total including the
asker, not a count of neighbours: a panicking villager needs two others, a calm one
four.

On success every collected requester has `_last_golem_gmt` stamped, so the 30-second
cooldown is village-wide.

## The placement search

`summon_golem` sweeps `self_pos ± (8,5,8)` — 17×11×17 — for a cell that is
`group:solid` or `group:water`, has a solid block directly beneath (`nb_solid`), and
has at least `12` air cells in the 2×3×2 space above it at half-block offsets. The
candidates are shuffled and the first that fits is used, so the golem does **not**
appear at the nearest valid cell. A water surface places the golem one node lower.

Note the asymmetry that matters when testing: the air test reaches three nodes above
whatever cell is being checked, so a cell at the top of the search box can be a valid
spot purely because the sky is open above it.

## Gossip

`gossip_with` is driven by a villager walking up to another and holding a
conversation (line 5501). It copies the speaker's gossips to the listener:

```lua
local new = math.max (value - info.transfer_decay, 0)
self_gossip[gossiptype] = math.min (math.max (new, self_value), info.max_value)
```

So each type travels with its own `transfer_decay` (5 for `minor_positive`, 20 for
`minor_negative`, `major_positive` and `trading`, 10 for `major_negative`) and the
listener keeps whichever magnitude is larger. `evaluate_player_reputation` then sums
`gossip * rep_multiplier` across types, so a villager's standing is its positives
minus its negatives: hearing good news raises a hostile villager's net without
cancelling the grudge.

## What Voxey already had, and what this adds

`scripts/village_life.gd` already gave every village one golem at generation, and had
professions, trades, restocking, levels, breeding, panic and a reputation store. What
was missing was everything above: the desire rule, both request paths, the placement
search and the gossip transfer. `scripts/village_golems.gd` adds them, and the
records in `VillageLife.make_record` gained `slept_at`, `saw_golem_at` and
`golem_timer` to hold the source's three timers.

Two adaptations are deliberate and recorded in the module:

* **Bed use is not tracked.** The source sets `_last_slept_gmt` from an actual bed
  interaction. Voxey has no per-villager sleep event, so `VillageGolems.mark_slept`
  stamps every resident when the village passes a night, driven from the day cycle
  `VillageLife.update` already reads. Same information, coarser source.
* **Reputation is one signed number, not typed buckets.** `copy_gossips` operates per
  type, and Voxey's model has a single net. The transfer reconstructs the two types
  this model covers (`trading` and `minor_negative`) as "what is not positive is
  negative", which reproduces the source's arithmetic for them. It does not model
  `major_negative`, whose `rep_multiplier` of −5 cannot be expressed in a store that
  already treats an angry villager's −25 as a single number.

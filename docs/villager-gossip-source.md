# Villager gossip and trading prices

The installed Mineclonia checkout is the behavioral reference:
`mods/ENTITIES/mobs_mc/villager.lua` (gossip, damage, transactions and prices),
`villager_zombie.lua` (cure rewards), and `iron_golem.lua` (reputation aggression).
`VillagerGossip` is an original GDScript implementation of those rules.
See [Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

Each villager stores independent memories for each player. Reputation is the
weighted sum, so a positive memory does not erase a negative one.

| Memory | Weight | Cap | Decay per 1,200 seconds | Loss when shared |
| --- | ---: | ---: | ---: | ---: |
| Major negative | -5 | 100 | 10 | 10 |
| Minor negative | -1 | 100 | 20 | 20 |
| Minor positive | 1 | 25 | 1 | 5 |
| Major positive | 1 | 20 | 0 | 20 |
| Trading | 1 | 20 | 2 | 20 |

Accepted player damage that leaves the villager alive adds 25 minor negative.
A player kill adds 25 major negative to the victim and living villager witnesses
within sixteen blocks and line of sight. NPC and environmental damage do not
assign player blame. Projectiles use their explicit shooter. A successful trade
adds two trading memory; it does not broadcast gossip. A cure adds twenty major
positive and twenty-five minor positive to the restored villager, preserving
its earlier history. A naturally created iron golem attacks at standing below
-100; exactly -100 is insufficient, and player-created golems ignore standing.

During a social meeting, the listener keeps the larger of its own memory and
the speaker's memory minus that type's transfer loss. The listener has one
sixty-second cooldown shared by all speakers. The speaker still makes the calm
five-villager golem request when that cooldown blocks gossip. Trading and major
positive memories have no positive transferable remainder at their caps.

The first active decay step initializes the timestamp. At least 1,200 seconds
later, one decay runs and records the current time. A long gap still runs only
one decay, without retroactive loops. Values at or below one after decay are
removed; empty player maps remain, matching the source. Memories and both
clocks survive save/reload and zombie infection/cure.

Prices use `floor(-reputation * price_multiplier)` as the shared adjustment for
both payment items. Demand contributes its own nonnegative term to each item.
Hero of the Village subtracts at least one, otherwise
`floor((0.3 + 1/16) * first_adjusted_payment)` from that shared adjustment.
Amounts are floored and clamped to each item's stack limit. Opening trading captures reputation and hero status. Completed trade callbacks
and promotion refreshes reapply them, as described in the later
[trade lifecycle audit](villager-trading-source.md); the source's object-keyed table makes its numeric-length guard ineffective. The underlying demand/restock and trade-pool systems remain separate.

Old saves contain only a signed reputation total. Migration preserves that
initial total within the representable range [-600, 65], using positive trading,
minor positive and major positive memories, or negative major/minor memories.
Their original composition cannot be recovered, so future decay follows that
inferred composition. Offline identity migration includes typed memories.
The active clock is Voxey's saved, per-dimension village clock; Mineclonia uses
its global game-time clock. Social schedules, individual sleep tracking,
full navigation, trade-pool completeness and child appearances remain open.

## Verification

`tools/export_villager_gossip_reference.py` runs the real Lua callbacks inside
Luanti and records hashes of the three source files. The fixture contains
440 record cases, 300 transfer cases, 80 decay cases, 44 decay-clock cases,
40 conversation-clock cases and 5,200 price cases: **6,104 source comparisons**.
Prices include both payment slots, absent second slots, positive/negative demand,
reputation extremes, hero effects and a non-stackable first item.

`tests/villager_gossip_checks.gd` exercises live transactions and session prices,
social transfers, accepted/rejected damage, shooter attribution, visible and
obstructed murder witnesses, golem aggression, infection/cure, legacy identity
migration, persistent typed memories, loaded decay and conversation summoning.

Validation on 2026-10-24: all 6,104 source comparisons pass, and all three
fixture hashes match the supplied checkout. The focused gossip, village-golem,
zombie-villager, social and farmer run passes 183 checks. A subsequent
115-check gossip/constructed-golem run passes with the final identity migration
and verifies restoring the test world's loaded area. Separate village and
alchemy regressions pass 903 and 239 checks. The Linux pack exports.

`tests/villager_gossip_tour.gd` renders the same three offers before and after a
cure: their payments change from 20/8/20 to 17/1/11. The reviewed trade panel
also separates output quantities from item names so the values remain legible.
Full Mineclonia parity remains an active goal.

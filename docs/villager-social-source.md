# Villager food sharing and breeding

`VillagerFood` and `VillagerSocial` use the installed Mineclonia checkout's
`mods/ENTITIES/mobs_mc/villager.lua` as their behavioral reference. Private
inventory mechanics are described in [composters and workstations](composters-source.md).
See [Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

Bread contributes four food points; potatoes, carrots and beetroot contribute
one each. Other items do not count. Carried food and already-eaten food energy
are separate values. Breeding requires their sum to be **greater than twelve**,
and excludes sleeping villagers and children. Three bread alone therefore do
not enable breeding. Immediately before conception, each parent eats from its
inventory in slot order until it has at least twelve energy, then spends twelve.
Excess energy remains. Both parents pay even when no free bed is available.
The implementation retains the source's count/point expression and negative
energy when supplies have disappeared during an ongoing courtship.

A meeting can share food when the sender carries more than 24 points and the
recipient carries fewer than twelve. The source scans for the first eligible
stack with more than `min(24, stack_max/2)` items, retains that many, and throws
the remainder. It does not combine several small stacks to form a gift. Wheat
has a separate rule: more than 32 carried wheat permits a gift to a farmer.
Thrown items leave 1.14 blocks above the sender at speed four toward the
recipient. They retain their metadata and must be picked up normally.

Two source quirks are preserved. `get_villager_trades` indexes a numeric
profession array using string names, yielding no extra profession-item trade
list in this checkout. Also, the self-pickup timestamp test allows the donor
to reclaim a gift during the initial two seconds, then rejects older self-thrown
items, despite its contrary comment. Other villagers are unaffected by that
restriction. The donor marker is transient, as is the source object reference.

A successful mating attempt establishes reciprocal partners. The initiating
villager receives a 275–325-tick timer at twenty ticks per second; the other
partner has no birth timer. Partners approach while more than 2.5 blocks apart.
The timer continues during the approach, but conception waits until they are
close enough. Losing a partner or failing to navigate cancels the attempt.

After the timer expires, the initiator pays both food costs and selects the
nearest free bed from at most five candidates. The bed sensor searches ±48
blocks horizontally and ±32 vertically, excludes claimed beds, and does not
add a headroom condition absent from the source. A loaded-bed index follows
placement, removal and chunk streaming. A successful child claims the bed,
starts unemployed with twenty active minutes of childhood, and uses a half-size
model and collision box. Each successful attempt produces one child. No fixed
five-minute parent cooldown is added; further attempts depend on food and the
source's random start gate.

Direct right-click feeding remains a native convenience, but now inserts the
actual food item into the villager's inventory. It no longer bypasses courtship
or creates a baby immediately. Legacy abstract food is migrated to eaten-food
energy. Inventory, energy and children persist through saves; courtship and
meeting partners do not. Infection omits private inventory and food energy from
the previous incarnation, matching the source identity export.

## Native integration and open work

The native day phases determine when idle courtship and social meetings can
start. Meetings use the source's one-in-120 start roll, visibility and nearby
villagers; the source's full social schedule, bell attendance, cat interactions
and independently timed gossip participants are not yet reproduced. Movement
uses the bounded native voxel pathfinder. Typed reputation gossip and its
transfer/decay rules are now implemented in [villager gossip](villager-gossip-source.md). Child biome appearance/inheritance
and the complete childhood play schedule also remain open. This is progress
toward full village parity, not a complete village simulation claim.

## Verification

`tools/export_villager_social_reference.py` executes the actual source food,
sharing, self-pickup and courtship callbacks in a Luanti world. Its fixture has
862 food cases, 240 sharing cases, 36 timestamp cases and 288 courtship states:
1,426 source comparisons, with source hashes. These cover strict food thresholds,
slot-order consumption, no-bed costs, interrupted courtship, timer boundaries,
and the two documented source quirks.

`tests/villager_social_checks.gd` checks live item throws and pickup, automatic
courtship entry, births, bed ownership, failure costs, child size, feeding,
energy/inventory persistence and infection handling.

Validation on 2026-10-24: all 1,426 source cases pass. The combined social,
field/workstation, zombie-villager and baby-undead run passes 150 checks;
village and alchemy regressions pass another 903 and 239. A final 72-check
focused run covers the current bed-index reset and save/reload behavior.
The family preview was rendered and reviewed, and the Linux pack exports.
All three source hashes match the supplied checkout. Full Mineclonia parity
remains an active goal.

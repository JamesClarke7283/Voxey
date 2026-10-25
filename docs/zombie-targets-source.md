# Zombie targets and village navigation

`ZombieTargets`, `VillagePois` and `ZombieVillage` follow the installed Mineclonia
checkout's shared mob combat rules, `mobs_mc/zombie.lua`, `mobs_mc/drowned.lua`,
`mobs_mc/piglin.lua` and `mcl_villages/pois.lua`. They use original GDScript and the
native voxel geometry. See [Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

Zombies, husks, drowned and zombie villagers first retain or acquire a retaliation
target. They then consider players, villagers/wandering traders, iron golems,
and received ally alerts in that order; drowned additionally consider axolotls
before alerts. Distance chooses between candidates within a group. Acquisition
requires sight; tracking retains an ordinary unseen target for three seconds
and a retaliation or alert target for fifteen. The previous timer value decides
expiry, preserving the source's extra tick at zero. Retaliation does not switch
to a new attacker while the original is still being tracked. Unread attacks can
be considered after that pursuit ends.

An accepted retaliatory attack broadcasts to zombie-family allies in the mob's
view box even if the attacker lies outside its own pursuit range. A busy ally
refuses the alert. Alert acquisition requires a distance strictly below 72;
tracking permits 72 for twenty seconds, then uses the mob's normal tracking
range. Retaliation acquisition also uses a strict range comparison, whereas
ordinary acquisition and current-target tracking permit the boundary.

Zombified piglins have retaliation and alert rules without ordinary player
acquisition. Their broadcasts reach only zombified piglins. During pursuit,
repeated anger pulses use the view range horizontally and ten blocks vertically,
with intervals drawn from 4–6 twentieths of a second. The active movement
multiplier is 5.6/4.6, applied to Voxey's existing base speed.

New-target detection applies the source invisibility factor: armor coverage is
the number of occupied slots divided by four, clamped to at least 0.1, then
multiplied by 0.7. The existing matching-head factor multiplies this result.
Tracking does not reapply the acquisition factor. Drowned reject all dry-land
or mounted targets during daylight, including attackers and alerted targets.
At night, those restrictions lift. A trident-wielding drowned uses its selected
target for aiming, facing checks and attack range, including NPC retaliation.

Claimed, valid beds and profession workstations seed village heat at six.
A meeting bell is registered when rung near a living village record. Each POI
belongs to a 16×16×16 section; heat decays by one per neighboring section,
including diagonals. The closed-form field matches steady-state propagation
through the source's 26 neighbors, including negative coordinates and overlapping
sources. Removing a node or its living claimant removes its contribution.
Unloaded claims remain eligible until they can be checked. Sieges now use this
shared heat field instead of the earlier resident-count approximation.

A non-drowned zombie in a village starts a navigation attempt once per second
at night or outside the overworld, provided its section has heat at least three.
Ten sampled positions within ±15 horizontally and ±7 vertically test heat.
As in this checkout, destination selection searches within ten blocks of the
original position, not the sampled position, and excludes already visited POIs.
The native route finder uses loaded, walkable voxel cells, steps up/down one
block, avoids solid obstacles, and permits wooden doors only for an eligible
Hard-difficulty door breaker. It is bounded to 600 examined cells and 24 blocks.
A stalled route retries once, then records the failed destination as visited.
Targets, route progress and visited destinations are transient on reload.

## Validation and remaining scope

`tools/export_zombie_target_reference.py` runs the installed Luanti game and calls
the actual targeting rules. For the otherwise-local heat algorithm, it extracts
and runs the actual source functions. Its checked-in fixture contains 1,518
tracking steps, 188 alert states, 16 retaliation cases, 20 detection factors,
1,500 heat samples and 360 destination choices: 3,602 comparisons in
`tests/zombie_target_reference_checks.gd`. Source SHA-256 hashes travel with the
fixture. `tests/zombie_target_checks.gd` checks live selection, retaliation,
allies, drowned restrictions, POI validation, siege heat and obstacle navigation.

Native adaptations remain explicit: acquisition starts immediately instead of
using the source's randomized initial timer phase; single-player target lookup
uses the local player; meeting-bell claiming uses existing village records; heat
updates immediately instead of through a deferred propagation queue. Navigation
uses Voxey's bounded voxel route finder, not Mineclonia's complete pathfinder.
Combat pursuit, sunlight shelter, door opening, source jump/fall/liquid path costs,
other mobs' targeting rules and multiplayer target synchronization remain open.
This batch does not claim complete mob or village parity.

Validation on 2026-10-24: all 3,602 source comparisons pass, together with 215
combined undead lifecycle checks, 903 village regressions and 239 alchemy
regressions. The native obstacle-route preview was rendered and reviewed, and
the Linux pack exports successfully. All seven source hashes match the supplied
checkout. No complete-parity claim is made for the larger goal.

# Baby undead and chicken jockeys

`MobBabies` and `MobJockeys` follow the installed Mineclonia checkout's
`mobs_mc/zombie.lua`, `drowned.lua`, `villager_zombie.lua`, `villager.lua`,
`chicken.lua`, and
`mcl_mobs/{api,breeding,movement}.lua`. See [Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

Natural zombies, husks and drowned have the source's strict five-percent baby
roll. Dungeon zombie spawns use that roll too. Zombie villagers independently
roll one through one hundred on first creation, becoming children on one
through five. Saved adults and babies keep their state on loading. Native
`/spawn baby_zombie`, `baby_husk`, `baby_drowned`, and `baby_zombie_villager`
aliases provide explicit access without rerolling an adult spawn command.
The native representation retains the base family name plus a saved baby flag.

Baby zombies, husks and drowned have half-block-wide collision boxes, height
0.99, reach one, twelve XP, and a 50% movement-speed bonus. They keep the adult's
health, damage, armor, equipment and drop rules. The source uses integer `child = 1` to inhibit aging, so these children do not grow into adults. Child zombie
villagers also never mature but inherit the villager-zombie's five XP and reach
two; their collision box is half the adult box. The native models, armor and
held items scale together. Baby husks retain their hunger bite and conversion
to baby zombies, while baby zombies convert to baby drowned. Equipment and
riding relationships survive conversion. Villager infection now uses the native
difficulty mapping: none on Easy, a coin flip on Normal, always on Hard. Drowned
and all relevant baby variants can infect. Curing grants no Strength on Easy,
Strength I on Normal and Strength II on Hard. The baby melee callback can interrupt
pursuit after a successful one-in-two roll; the native controller honors the
half-second target delay and supplies a wandering direction.

Chicken jockey generation preserves the source's two separate rolls. A baby
first has a five-percent chance to search for an unoccupied, living chicken
within eight blocks. If this roll succeeds but no chicken exists, generation
stops. Only a failed first roll allows the second five-percent roll to create
a new chicken. With a suitable existing chicken the combined chance is 9.75%;
without one, the chance to create a chicken is 4.75%. These are conditional on
the undead already being a baby.

The rider controls its chicken's movement, using the chicken's movement speed
and collision box. The 1.76 attachment coordinate is converted from Luanti's
attachment units to 0.176 world units, with parent visual scaling. The rider's
world scale remains unchanged. Legs take the seated pose, then return to the
normal pose when the chicken dies. A dead rider leaves its chicken alive.
Neither direction produces a duplicate entity. Ordinary native pathfinding,
collision stepping and chicken fall behavior remain the movement foundation.

A chicken used as a jockey permanently stops laying eggs, including after its
rider dies or dismounts. An adult jockey chicken gives ten XP and may despawn
unless named or otherwise persistent. Feeding a chicken into breeding marks
it persistent, matching the source. An occupied chicken can still be carried
in a boat: the boat owns its movement and the nested rider follows its seat.

The chicken owns the rider's saved state. The rider is excluded from the
independent farm-record list, while its equipment, name, health, effects and
baby flag are stored in the chicken's record. Normal saves, region unloading,
leads and boat passenger records preserve the pair. Trial encounters own their
rider and vehicle together, including forced baby waves, conversion and reload;
they do not create an independent farm owner for the same chicken. If a
zombie-villager rider is cured, its adult villager replacement remains attached. The village identity
and the chicken's rider record cooperate to avoid loading a second villager.

`tools/export_mob_baby_reference.py` executes source callbacks in a real Luanti
world. Its fixture provides the registered baby properties, thirty spawn cases,
eight hundred jockey decisions, twelve chicken egg/XP cases, three aging cases
and forty-eight infection cases. `tests/mob_baby_reference_checks.gd` compares
896 cases.
`tests/mob_baby_checks.gd` exercises actual spawning, models, movement, equipment,
conversion, curing, boats, parent/rider deaths and world reloads.
`tests/mob_baby_tour.gd` renders adult, baby and jockey silhouettes.

This batch does not implement the source's complete natural-spawner pack
scheduler, other jockey species, baby
zombified piglins, or multiplayer synchronization of these new fields. The full
Mineclonia parity goal remains active.

Validation on 2026-10-24: all 896 source comparisons and the final 38 focused
baby/jockey lifecycle checks pass. The related farming, trial and cure recheck
passed 213 checks before the final additional lead-owner assertion; the village
suite passed 903 and the alchemy suite passed 239. The adult/baby/jockey render
was reviewed, and the final Linux pack exported successfully. Full source
parity remains unproven outside the explicitly covered behavior above.

Zombie reinforcements, randomized attributes and door breaking are covered by
the subsequent [zombie behavior batch](zombie-behavior-source.md).

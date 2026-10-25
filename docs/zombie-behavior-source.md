# Zombie attributes, doors and reinforcements

`ZombieTraits` and `ZombieDoors` follow the installed Mineclonia checkout's
`mobs_mc/zombie.lua` and the shared mob physics, combat and spawning callbacks.
They apply to zombies, husks, drowned and zombie villagers, including their
baby forms. See [Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

Each new mob receives the source's random knockback resistance from zero to
0.05. Its base detection and tracking range is 35 blocks. A view bonus is drawn
as `1.5 * special_difficulty * random()`, and only values above one apply; the
result multiplies the base range by `1 + bonus`. Melee and projectile knockback
use the resistance, and the native target search uses the extended range.
Player targeting takes priority over ordinary villager/golem targets, after retaliation.
The subsequent [targeting batch](zombie-targets-source.md) adds group alerts,
source persistence, village heat and nighttime navigation.

With probability `0.05 * special_difficulty`, a mob receives the source's
strong-zombie attributes. Its reinforcement chance gains between 0.5 and 0.75,
and it can break doors on Hard. Its maximum health becomes 40–100, while its
current spawn health stays at twenty. This deliberately preserves the source's
health-bonus quirk. Every zombie-family spawn also receives a base reinforcement
chance from zero to 0.1. All these attributes are saved with the mob through
world, trial, lead and boat records. Conversions generate the successor's
attributes, as the source's new entity runs its own spawn callback.

Door breaking begins when an eligible Hard-difficulty mob encounters a closed,
non-iron door along its native movement path. The timer continues independently
of target visibility. It stops if the door opens or disappears, the mob moves
at least 1.25 blocks horizontally or 1.5 vertically from the source anchor, or
it moves away sufficiently quickly. The source's directional test uses
`cos(100)` in radians; this expression is preserved. While breaking a door, the
mob does not jump over that obstruction. Progress sounds occur at tenths of
the twelve-second timer, with occasional 0.45-second arm punches.

After twelve seconds, both native door halves are removed and one door item is
dropped. The break does not credit the player's gathering progress. The source
protection predicate is included in the callback comparisons; the current
native world has no area-protection service. Door progress is deliberately
transient, matching the fields the source removes from saved data.

On Hard, an accepted damage event can call reinforcements if the mob has a
living attacker or attack target and its chance roll succeeds. The source makes
all fifty candidate attempts: each coordinate offset is a random integer from
7 through 40 multiplied by -1, 0 or 1. It does not stop after the first success,
and can continue spawning after the caller's chance has reached zero during
the same event. Each success subtracts five percentage points from both the
caller and the spawned mob, clamped at zero. Spawned mobs receive the caller's
current target.

Candidates use the existing native spawn environment: loaded, clear cells,
no artificial light, natural light at most six and a source random light test.
Ordinary zombies need a solid support; husks additionally need exposure to the
sky. Drowned retain their water and depth tests. Living local and connected
players exclude positions within seven blocks. This uses native coordinates,
lighting and biome coverage rather than reproducing the Luanti map generator.

`tools/export_zombie_behavior_reference.py` runs real source callbacks in a
local Luanti world. It compares 300 attribute-generation cases, 2,160 door
states, and 216 reinforcement sequences. The door cases cover movement,
distance, opening, iron doors, protection and the completion boundary. The
reinforcement sequences cover difficulty, rejected damage, chance boundaries,
all fifty offsets, multiple successes and both participants' attenuation.
`tests/zombie_behavior_reference_checks.gd` checks all 2,676 cases.

The `zombie_behavior` lifecycle group exercises actual door removal and drops,
movement collision, the normal damage callback, spawn placement and saved
attributes. `tests/zombie_behavior_tour.gd` renders the door-punch pose.

Village pacing and group retaliation are covered by the later targeting batch.
Full source navigation and native area protection remain separate work. This is progress toward the full
Mineclonia parity goal, not a claim that every zombie behavior is complete.

Validation on 2026-10-24: all 2,676 source comparisons, 258 combined gameplay
checks and 239 alchemy regressions pass. The rendered door-punch pose was
reviewed, and the Linux pack exports successfully. Source hashes match the
user-provided checkout.

# Skeleton and stray bow combat

`scripts/mob_bows.gd` follows the installed Mineclonia source in
`mods/ENTITIES/mobs_mc/skeleton+stray.lua`, `mcl_mobs/combat.lua`, and
`mods/ITEMS/mcl_bows/bow.lua`. The fixture also reads the actual registered
entities and executes their callbacks. See [Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

Skeletons and strays now use the source NPC bow cycle:

- Draw for strictly more than one second before shooting. After a shot, wait
  two seconds on Easy/Normal or one second on Hard before beginning another
  draw. This differs from the player's half-second draw.
- Track signed visibility time. A drawn bow waits for sight, and releases
  without a shot after more than three unseen seconds.
- Approach targets until they remain visible for a second within fifteen
  blocks, then strafe at one quarter movement speed. The source's lateral
  and forward components are each 0.5. Direction rolls occur after a second
  of strafing; the forward component is constrained beyond 11.25 or inside
  8.25 blocks. Obstructed or unsupported strafes fall back to forward movement.
- Acquire players or iron golems within sixteen blocks. Retaliate against
  attackers, including other skeletons, without alerting allies. Nearby wolves
  interrupt the bow attack. Creative players and villagers are not targets.

Shots originate 1.5 blocks above the feet and aim one third of the way up the
target, with the source's upward distance correction. Speed is
`0.5333333 * 60`, approximately 32 blocks per second. Base damage is
`2 + source_difficulty * 0.11 + triangular(0, 0.57425)` before Power. Difficulty
also scales directional spread. NPC arrows are not critical and cannot be
collected. Strays fire slowness arrows. Power, Punch and Flame come from the
equipped bow; NPC firing consumes neither arrows nor weapon durability.

Each archer has a real bow item, with the shared source enchantment generator's
`0.25 * special_difficulty` chance and corresponding power roll. Its equipped
bow can drop at `0.085 + 0.01 * Looting`, with the source's nested random wear;
Vanishing suppresses the drop. Existing ordinary arrow and bone loot remains
handled by `UndeadVariants`. The bow sprites show carrying and drawing states.

The registered collision box is 0.6 wide and 1.99 tall. The source registration
also resolves `can_despawn` to true for both monsters. Their equipment and draw
state now survive native world saves while their normal despawn rule remains
active. Named archers retain their state across unloading. Skeleton-to-stray
conversion keeps the enchanted weapon. Trial encounters own their archers'
saved state separately so an unloaded encounter cannot duplicate them.

The inherited projectile-kill callback grants Sniper Duel when a player kills
a skeleton or stray with an arrow or trident at **more than twenty blocks**
from the player's current position. The source tooltip says fifty, but the
callback tests twenty. Wither skeletons override the callback to do nothing.
The native behavior and description now follow the executed callback.

`tools/export_mob_bow_reference.py` executes 5,760 AI steps, ninety firing
cases, seventy-two kill-callback cases and twenty drop-wear cases in a temporary
localhost Luanti world. It records source hashes and registered entity bounds.
`tests/mob_bow_reference_checks.gd` compares the resulting state, emitted
actions, trajectories, enchantments and callbacks. The `mob_bow` lifecycle
group additionally exercises actual shots and slowness, target selection,
retaliation, drops, conversion, trial restoration and save/reload.
`tests/mob_bow_tour.gd` renders carrying, drawing and stray poses.

Validation on 2026-10-24: all 5,942 reference cases pass, alongside registered
entity bounds and despawn checks. The persistence/farming/name-tag/trial run
passes 254 checks; the projectile/crossbow run passes 98; the full survival
suite passes 534. Import, Linux pack export and visual inspection pass.

Movement still uses Voxey's existing controller and acceleration rather than
Luanti navigation. [Mob armor](mob-armor-source.md) now covers armor generation, pickup, Halloween
headgear and worn-helmet sunlight protection. Weapon pickup and melee switching,
full sunlight shelter-seeking,
skeleton jockeys, full knockback and networked weapon/projectile state remain
open. These bow changes do not establish complete skeleton or mob parity.

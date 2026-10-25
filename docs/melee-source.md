# Player melee and mace reference

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-24.
The translated rules retain the project's GPL-3.0-or-later attribution. Source
hashes and fixtures are stored in `assets/data/melee_reference.json`; runtime
item capabilities and knockback resistances are in `assets/data/melee.json`.

## Ordinary punches

`MeleeCombat` uses the registered item damage groups and full-punch intervals.
An early punch scales damage linearly by elapsed time divided by the interval,
capped at full damage. The empty hand deals one; a diamond sword deals seven.
Weapons no longer share the old tier-derived damage or a fixed recharge time.
The input repeat interval remains a native control detail; damage is calculated
from the actual elapsed time on each hit.

Sharpness adds `0.5 * level` to the fleshy group; Smite and Bane add `2.5 * level`
to their own groups. Luanti converts these groups to integers when storing the
item's capabilities. The port retains that truncation, including odd-level
fractional bonuses. Each group passes through the target's intrinsic armor
percentage once. The old pending-bonus path is no longer used for player melee.

Fire Aspect ignites before damage; Bane applies Slowness IV for a random duration
between one and `1 + level / 2` seconds when the target has an arthropod group.
The checkout applies Strength/Weakness in both the mob's punch callback and the
registered damage modifier; this implementation deliberately retains both.

A falling hit uses the source random critical bonus. Sprinting suppresses it
only when vertical velocity is nonnegative. Normal knockback uses the source
velocity formula, its half-second gate, the target's resistance and the held
item's Knockback level. Sprint velocity is included before this calculation.
Shulkers and iron golems retain full knockback resistance; ravagers and hoglins
retain their partial resistance.

Survival punches spend `floor(65535 / punch_attack_uses)` normalized wear.
Unbreaking multiplies those uses. This differs from both digging wear and the
armor-use distribution. An item that breaks is removed before the source reads
Knockback and Looting, so those enchantments no longer affect that final hit.
Creative punches do not spend wear. Items without punch uses do not spend wear
merely because they hit a creature.

## Mace

The mace uses its separate source `on_use` callback. Its 1.6-second cooldown
compares integer game times, so accepted attacks are at least two integer ticks
apart. Fall height is estimated as `-abs(vy) * vy / 40`, with the source's exact
piecewise damage thresholds and Density bonus. Passing the result through the
engine's integer capability conversion happens before the mob punch callback.

A qualifying smash cancels downward velocity; Wind Burst adds eight upward
velocity units per level when the target is within three nodes. Because this
happens before the punch callback, a cancelled fall does not also receive a
falling critical. Breach adds fifteen percent damage per level after armor.
The recent-mace window suppresses fall damage for two integer game ticks.

The callback always spends 131 normalized wear in survival. Its explicit wear
does not use Unbreaking. Normal Smite/Sharpness damage groups are replaced by
the callback's smash group; the Fire Aspect/Bane side effects still run.

## Boundaries and retained adaptations

This is the player-to-creature punch path. Mob AI attacks, complete mob-equipment
armor and projectile damage still need separate source work. Haste/Fatigue
attack-speed metadata now has a [source implementation](tool-capabilities-source.md).
Existing horse/trial armor adapters remain. The multiplayer
server's existing client-damage cap also remains, so large remote mace hits are
not yet source-equivalent. The attack message carries Breach separately so the
server applies it after armor. This wire change introduced protocol five. Shield appearance and second-hand
persistence subsequently advance it to six; hosts and guests must use matching builds.

Voxey's original additional weapons keep their native damage profiles. Saved
items with Sweeping Edge keep that older extension; the enchantment is disabled
in this reference and is not offered by the source enchanting engine. Digging
and noncombat tool interactions still have their separately documented wear
paths. The original art, sounds and native input controls remain.

## Evidence

`tools/export_melee_reference.py` starts the installed game in an isolated
temporary world. It executes the real `mcl_mobs.mob_class.on_punch`, real item
enchantment callbacks and real mace `on_use`, with controlled actor state and
randomness. Real immortal Luanti entity probes convert punch parameters through
`ObjectRef:punch`; real ItemStacks supply capabilities and wear. The harness also
executes the source critical and Strength/Weakness modifiers. It replaces scene
presentation and side-effect destinations with recordings, not the tested rules.

`tests/melee_reference_checks.gd` compares 1,222 cases across 67 profiles, checking
damage, wear, random consumption, effects, both actors' velocities, cooldown and
Looting at damage time. `tests/melee_checks.gd` drives real Voxey player attacks
and checks health, effects, breakage, knockback and the mace's fall-damage window.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/export_melee_reference.py
godot --headless --path . --script res://tests/melee_reference_checks.gd
godot --headless --path . --script res://tests/lifecycle_runner.gd -- melee
```

Verification on 2026-10-24: all 1,222 source comparisons pass in the project
and exported Linux pack. Live exported melee checks pass 24 assertions; the
combined melee/defensive/critical/guardian/shield run passes 134. All 534 survival
and 239 alchemy checks pass. The host/client regression passes, including the
new remote Breach check and reconnect persistence; protocol checks also pass.
Godot import and Linux pack export complete without script errors.

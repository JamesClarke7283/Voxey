# Pillager crossbows

`scripts/mob_crossbows.gd` follows the installed Mineclonia checkout's
`mods/ENTITIES/mobs_mc/pillager.lua`, `mods/ENTITIES/mcl_mobs/combat.lua`
and `items.lua`, and `mods/ITEMS/mcl_bows/crossbow.lua`. Raid enchantment
probabilities come from `mods/ENVIRONMENT/mcl_raids/init.lua`.
See the repository's [Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

Pillagers now carry an actual crossbow item. Their combat cycle is separate
from [the player's draw and release controls](crossbows-source.md):

- Approach until within twenty blocks and visible for at least 0.25 seconds.
  Recalculate movement every one or two seconds, at half speed if already
  charging, loaded or ready to fire. Stop moving while there is a clear shot.
- Charge for 0.9 seconds, then hold the loaded weapon for a random one to two
  seconds before firing. A ready weapon waits for line of sight. Quick Charge
  does not shorten this NPC timer in the reference implementation.
- Fire from 1.475 blocks above the feet, aim at the target's feet with an upward
  correction of `0.12 * distance`, and use speed 32. Difficulty scales the
  triangular spread by `14 - 4 * source_difficulty`. Shots are critical, use
  base damage two, carry Piercing and Multishot, and cannot be collected.
  Firing does not consume NPC ammunition or wear the weapon.

Player targets, villagers, wandering traders and iron golems participate in
target selection. Retaliation takes priority and can recruit idle pillagers;
raid allies do not provoke it. Losing sight allows three seconds of ordinary
target memory or fifteen seconds of retaliation memory. The movement controller
and obstacle handling remain native; this is not a port of Luanti's pathfinder,
patrol formations or every raid target lock.

Spawned equipment uses the shared source enchanting system, with a
`0.25 * special_difficulty` chance and power
`floor(5 + special_difficulty * random(1,18))`. A separate one-in-300 roll adds
Piercing I. Raid buffs use the source's Bad Omen probability and add Multishot I,
Quick Charge I after wave three, and Quick Charge II after wave five. Direct
source enchantment calls can combine Piercing and Multishot. The native
`mob_crossbow` item provenance flag preserves that combination through normal
inventory, drops and saves without changing ordinary enchantment validation.

Ordinary pillagers drop zero to two arrows plus common Looting extras. Their
equipped crossbow drops with probability `0.085 + 0.01 * Looting`, unless it
has Vanishing, with the source's nested random durability loss. Only a non-raid
captain adds an ominous bottle, with a random level from one to five. The former
ordinary emerald drops and unconditional ominous bottle are removed.

The source's loaded NPC weapon contains no player ammunition: it changes item
form without stocking an arrow. A dropped loaded NPC crossbow therefore looks
loaded but dry-fires once; the next normal player load supplies an arrow.
`CrossbowUse.loaded_form` models the appearance separately from a chamber that
contains ammunition. Equipped item data, combat phase, timers, and patrol and
captain identity persist through actual world saves. Target object references
are reacquired after loading. Arm poses and held-item geometry are native art.

`tools/export_mob_crossbow_reference.py` executes the real Luanti callbacks
against a small fixture for engine objects and navigation. Its source-hashed
JSON records 3,120 AI steps, sixty firing cases and twenty-four dropped-weapon
wear cases. `tests/mob_crossbow_reference_checks.gd` compares all of them.
The `mob_crossbow` lifecycle group checks actual spawning, delayed fire,
line-of-sight blocking, villager hits, forced enchantments, dry fire, retaliation,
loot and save/reload. `tests/mob_crossbow_tour.gd` renders the three arm poses.

Validation on 2026-10-24: all 3,204 NPC reference comparisons and 1,584 player
crossbow comparisons pass. The combined projectile lifecycle run passes 218
checks; the patrol/raid/outpost run passes 159. Alchemy passes 239 checks,
survival passes 534, and the shared enchanting reference suite passes. Import,
Linux pack export and visual inspection pass. Arrow impacts also carry their
damage reason and actual shooter, so retaliation cannot blame a bystander
standing near the point of impact.

Full mob knockback and multiplayer projectile/equipment synchronization remain
open, alongside the movement and raid behavior noted above. This batch does
not establish complete mob or Mineclonia parity.

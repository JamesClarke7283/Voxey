# Shields

Reference: the supplied Mineclonia `mods/ITEMS/mcl_shields/init.lua`. The native implementation uses original GDScript, geometry and procedural textures.

## Blocking

The installed source calculates `-math.cos(180/2)` without converting degrees to radians. Its actual dot-product threshold is **0.4480736161291701**, corresponding to an approximately 233-degree horizontal arc. Voxey now uses that measured value. The direction is measured from the player's shield centre (two thirds of eye height). Only the listed damage types are blocked: mob, player, arrow, generic, explosion, dragon breath and trident. Fire, void, drowning, starvation and falls pass through it.

Sneak raises a shield held in either hand. Releasing sneak lowers it. An axe hit can disable it for five seconds; the triggering frontal hit is still blocked. A hit below three damage costs no durability. Larger hits pass the damage rounded upward to the source wear algorithm, including Unbreaking and normalized-wear rounding. Actual incoming damage is used, rather than a fixed three-point charge. The source's shield use count is 336; the native display span remains 337 while exact wear is stored separately.

## Banner decoration

Combine a plain shield and a banner in either crafting grid. Both inputs are consumed. The result copies the banner's base colour and ordered layers, preserves shield damage and enchantments, and takes the shield's name when present or otherwise the banner's name. The source creates a fresh item, so unrelated metadata and anvil prior work are not inherited.

The installed source permits at most twelve banner layers. A shield already carrying a base colour cannot be decorated again, even if its layer list is empty. The recipe guide, manual output cursor and direct crafting all use the same metadata and damage rules. A blocked output transaction leaves both ingredients intact.

Voxey represents all shield colours with the existing shield ID and validated `shield_color`/`layers` metadata. Inventory icons, crafting previews, the first-person main and second hands, dropped shields, item frames and multiplayer avatars use that design. The solid model has a decorated front, wooden back, metal edge and grip. Native appearance differs from Mineclonia's supplied mesh and textures.

Second-hand contents are now normalized on disk load, included in multiplayer inventory snapshots, restored on reconnect and retained during server resynchronization. Restoring saved XP does not count as a fresh XP award, so loading from play cannot spend it on Mending or silently repair a worn shield. Shield appearance and raised/lowered pose are synchronized separately from inventory and sent only when changed. This wire change advances the multiplayer protocol to six; hosts and guests need matching builds.

## Pattern acquisition

The master cartographer sells one Globe pattern for eight emeralds, with stock twelve and thirty villager XP, matching the source trade. The existing native bulwark loot table awards the Piglin pattern with weight nine in its first one-to-two-stack group. Both rewards now use the actual loom pattern IDs. Earlier Globe (`812`) and Piglin (`1106`) rewards migrate to those functional items, including when loaded from older inventories or containers.

The supplied checkout has two world generators. Voxey's current bastion uses the **legacy `nether_bulwark`** rules in `mcl_nether_fortresses`, so the reference fixture disables `mcl_levelgen_enable_ersatz` in its temporary world to read that registered table. The newer `mcl_levelgen` bastion layouts and loot remain a separate parity task; this change does not claim to reproduce them.

## Verification and remaining differences

`tools/export_shield_reference.py` records source hashes and calls the installed engine's craft prediction and completion callbacks. `tests/shield_reference_checks.gd` compares 979 cases covering sixteen colours, layer limits, names, enchantments, damage, input positions and invalid recipes. The fixture also reads the cartographer offer and legacy bulwark reward directly from their source registrations.

`tests/shield_decor_checks.gd` exercises real recipe-guide and output controls, all sixteen colours, blocking wear, both hands, drops, item frames, acquisition-to-loom paths and disk save/reload. `tests/network_runner.gd` checks remote shield rendering and second-hand reconnect persistence. `tests/shield_tour.gd` renders the crafting preview, front/back model and raised shield.

## Projectile interception

Ordinary arrows physically reverse at 15% of their incoming velocity when the raised shield catches them. The arrow remains in the world, records its blocker, and can strike its original shooter. That contact cannot repeatedly charge wear while the arrow exits the shield. Deflection occurs before the arrow's fire and tipped-potion callbacks.

Piercing skips the physical reflection path. In this checkout its ordinary damage callback can still be blocked, while its tipped effects run; the native behavior follows those executable callbacks. Tridents reverse at 17.5% on entity impact whether damage is blocked or not, remember the targets already hit, and remain flying until their later collision or return.

Arrow impact damage now follows `ceil(base_damage * speed / 20 + critical_bonus)`, with the source Power bonus and mob-shot triangular variation. Arrows use 9.81 gravity and tridents use 24. The original shooter is retained when an arrow is reflected. Grounded-arrow saves retain the blocker and reflection flag along with the existing lifetime.

`tools/export_shield_combat_reference.py` calls the installed angle, wear, arrow-impact and trident-collision methods. `tests/shield_combat_reference_checks.gd` compares 180 angle cases, 576 wear cases, 45 arrow collisions and three trident reflections. `tests/projectile_shield_checks.gd` exercises actual projectile motion, effects, original-shooter impacts and repeat-hit prevention.

Bow charging/input, full projectile knockback and collision geometry, flying-projectile persistence, and the newer source world-generator content still require further comparison. The native Ctrl binding remains an input adaptation.

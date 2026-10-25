# Mending, armor wear, Thorns and damage flags

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-24.
The source-derived rules retain GPL-3.0-or-later attribution. Source hashes and
real-engine fixtures are in `assets/data/durability_reference.json`; the runtime
item profiles are in `assets/data/durability.json`.

## Mending and wear

`Durability` uses the reference's registered item capabilities and normalized
0–65535 wear. It retains an exact wear checkpoint alongside the existing native
integer wear, so fractional durability survives inventory transfers, equipped
pouches, saves and reloads. Old items without checkpoints convert from their
existing wear. A direct legacy edit to that integer invalidates the checkpoint.
Anvil repair/combine operations now retain their exact normalized result too.

Mending follows `mcl_enchanting/enchantments.lua`: each XP award chooses **one**
worn Mending item from the main hand, four armor slots and offhand. It repairs
that item using `calculate_durability` and the source's Unbreaking multiplier.
Excess XP is rounded as in the source and returned to the player; it does not
continue into another item. These are the actual registered capabilities, not
an assumption that every item repairs by the same number of native wear units.

Armor Unbreaking follows `mcl_util/item.lua`: effective uses are the base uses
divided by `0.6 + 0.4 / (level + 1)`. Elytra uses its separate multiplier. Wear
uses Luanti's `add_wear_by_uses` distribution, including its integer remainder,
rather than a random chance to avoid the whole hit. The exact wear is preserved
even when the displayed native unit has to round upward.

## Player damage

`ArmorEffects` ports `mcl_armor/damage.lua` and consumes the full source damage
flags already recorded by `DeathMessages`. Resistance/fire immunity run first,
then armor and enchantment protection, then absorption, and finally the totem.
An incoming amount that armor or absorption makes survivable cannot consume a
totem. Armor-bypassing drowning can consume a totem; the void still cannot.
Void damage also respects the source flag that bypasses invulnerability.

Armor wear uses the damage entering the armor modifier. Each piece contributes
its protection even if that hit breaks it. Fire, projectile and explosion flags
can all contribute protection on the same damage reason. Physical mob hits,
drowning, lava, standing fire and burning effects now pass distinct source
reasons instead of relying on a shared boolean or generic cause.

Thorns rolls independently for each equipped piece, caps regular retaliation at
four damage, and charges two extra uses to one participating piece after a
successful reflection. It does not recursively reflect Thorns or self damage.
The source's unusual early return is preserved: if retaliation immediately
removes the attacker, the armor modifier returns no replacement damage, leaving
the pre-armor amount in the outer pipeline and skipping extra Thorns wear.
Arrow, spit, magic-projectile and wither-skull hits retain their attacker when
available, so reflection can find the actual source. Guardian retaliation is
suppressed for the source's Thorns damage type.

## Boundaries

This ports the player armor modifier. It does not claim complete parity for mob
equipment, projectile damage, all potion effects, or player knockback. Player
melee timing, mace damage and Breach now have a [separate source port](melee-source.md).
Ordinary noncombat tool-use paths that still
increment native wear directly retain their existing behavior and invalidate
an obsolete exact checkpoint; their full wear migration remains separate work.
The inventory's displayed durability units and original graphics remain native.

## Evidence

`tools/export_durability_reference.py` starts the installed reference headlessly
in an isolated temporary world. It executes the actual Mending and armor
callbacks with **real Luanti ItemStacks**, including `add_wear_by_uses`, and
records registered item durability profiles. It does not modify the reference
game or an existing world.

`tests/durability_reference_checks.gd` compares 3,120 wear sequences, 604 Mending
cases, and 100 armor/Thorns cases, including random-stream consumption.
The source iterates a keyed armor table with `pairs`, so the order can change
between Luanti processes. Each fixture records its actual order, which the
comparison replays; Voxey uses a stable head-to-feet order during play.
`tests/defensive_enchantment_checks.gd` verifies live XP awards, offhand repair,
damage/absorption/totem ordering, retaliation and real disk persistence.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/export_durability_reference.py
godot --headless --path . --script res://tests/durability_reference_checks.gd
godot --headless --path . --script res://tests/lifecycle_runner.gd -- defensive_enchantment
```

Verification on 2026-10-24: all 3,824 source cases pass both in the project and
in an exported Linux pack. The pack also passes all 358 anvil source cases.
Focused defensive/XP/shield/totem/anvil/hazard checks pass 597 assertions; the
alchemy regression suite passes 239 and the full survival suite passes 534.
The Godot import and Linux pack export
complete without script errors.

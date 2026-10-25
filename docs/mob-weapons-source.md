# Undead held weapons and melee attacks

`scripts/mob_weapons.gd` follows the installed Mineclonia checkout's
`mcl_mobs/items.lua`, `mcl_mobs/combat.lua`, and the zombie, drowned, skeleton,
stray and wither-skeleton definitions. See [Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

Zombies, husks and zombie villagers can generate an iron sword or iron shovel.
The weapon chance is one in twenty on Hard and one in one hundred otherwise;
one third are swords. The source's reliable enchantment generator uses a
`0.25 * special_difficulty` chance and the corresponding power roll. Skeletons
and strays keep their real bows. Wither skeletons start with a stone sword;
drowned retain their source trident/fishing-rod generation and offhand shell.

All seven families use the existing regional item-pickup permission. Eligible
drops must be at least one second old and within 1.95 blocks. Armor selection
runs first, then held-item selection. Empty hands can take a whole ordinary
item stack. Swords can replace non-swords; tools and weapons then compare
attack damage, total durability and enchantment presence. The source reverses
the durability comparison: a **less durable** incoming tool can replace a more
durable one. It does not compare remaining wear. A drowned holding a trident
or nautilus shell refuses replacement; an incoming trident has priority.

The source durability helper selects the first available group capability,
which can differ from the material's normal attack uses. The held-item fixture
captures that runtime's registered capacities for selection and drop wear,
including Unbreaking levels zero through three. These are stored alongside
the source tool/weapon/sword groups in `assets/data/mob_weapon_items.json`.
Player attack wear and armor durability continue to use their own verified
profiles.

A replaced weapon uses its current drop chance. Acquired items have probability
two, retain their count, wear, name and enchantments, and drop without added
wear. Generated weapons use 8.5% plus one percentage point per Looting level,
with the source's nested random wear. Vanishing suppresses drops. Weapon
pickup does not itself make the mob persistent; armor pickup still does.
The drowned's old loot path cannot duplicate its real held weapon.

Skeletons, strays and wither skeletons switch between bow and melee combat
when their held item changes. Drowned use ranged attacks only with a trident.
Melee attacks require sight and use the source one-second interval. Held
capabilities add to base damage after subtracting the player's one hand-damage
point. NPC swings do not wear the weapon. Intrinsic target armor groups,
Sharpness, Smite, Bane, Fire Aspect, Knockback and strength/weakness modifiers
pass through the existing damage and armor pipeline. Melee damage against a
player uses the source difficulty modifier before Strength/Weakness: Easy is
`min(damage / 2 + 1, damage)`, Normal is unchanged, and Hard multiplies by 1.5.
Empty-handed burning
zombies can ignite their targets using regional difficulty. Wither skeletons
apply Wither I for ten seconds and are themselves immune to Wither; their base
attack is four and XP reward six. Their native dark skeleton body displays
the actual held item, and their inherited AI can target piglins and brutes.

Held item, drop probability and drowned offhand state survive world reloads,
undead conversion, trial snapshots, lead records and boat passenger records.
Restoring an equipped bow preserves an in-progress draw. Ordinary trial
weapons start with drop chance zero; ominous replacement weapons use the normal
8.5%. Curing a zombie villager drops its acquired weapon. The wither skeleton
continues to exclude the skeleton/stray Sniper Duel award.

`tools/export_mob_weapon_reference.py` runs the source callbacks inside a real
local Luanti world. Its fixture covers 720 generation cases, 1,014 replacement
comparisons, 117 capability combinations, 144 drop cases, 52 attack modes and 32 player-difficulty cases.
`tests/mob_weapon_reference_checks.gd` compares all 2,079 cases. The
`mob_weapon` lifecycle group checks actual pickup, attacks, effects, visible
item switching, conversion, save/reload and trial ownership.
`tests/mob_weapon_tour.gd` renders four equipped mob families for visual review.

Remaining work includes full source melee path scheduling and punch animation,
precise player knockback, other families' held-item rules,
and network replication of mob equipment. This is a bounded parity batch,
not a claim that all Mineclonia behavior is implemented.

Validation on 2026-10-24: all 2,079 weapon reference cases and 221 focused
lifecycle checks pass. The existing armor and skeleton-bow source suites pass
2,156 and 5,942 cases respectively. The alchemy regression suite passed 239
checks during this batch. The four-family weapon preview was reviewed and a
Linux pack exported successfully. Source hashes and runtime item classifications
match the fixture.

Baby undead and chicken jockeys are covered by the subsequent
[baby-undead batch](baby-undead-source.md).

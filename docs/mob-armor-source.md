# Mob armor and copper equipment

`scripts/mob_armor.gd` follows the installed Mineclonia checkout's
`mcl_mobs/{combat,items,physics}.lua` and `mcl_armor/{register,damage}.lua`.
It covers zombies, husks, drowned, zombie villagers, skeletons, strays and
wither skeletons. See [Mineclonia attribution](licenses/Mineclonia-GPL-3.0.txt).

For the families that generate armor, the chance is
`0.15 * special_difficulty`. The initial material is one of leather, copper
and gold, with three independent 9.5% opportunities to advance through chain,
iron and diamond. Each slot can stop the sequence: one in four on Easy/Normal
or one in ten on Hard. The reference's `armor_generated` variable is never set
true, so this stop roll applies at every slot. The implementation preserves
that behavior. Each generated piece can be enchanted with chance
`0.5 * special_difficulty`, using the shared reliable enchantment generator.
Drowned and wither skeletons do not generate ordinary armor in their source
equipment overrides, but they can acquire it.

A separate `0.55 * special_difficulty` roll permits armor pickup. A dropped
piece must be at least one second old and within 1.95 blocks. The source
comparison considers armor points, toughness, total durability capacity and
whether a piece is enchanted. It does not compare remaining durability, and
some lower-defense replacements are accepted. Binding prevents replacement.
The replaced piece can drop, while the newly acquired piece is marked with
drop probability two and makes the mob persistent.

Generated armor drops with its stored probability, normally 8.5%, plus one
percentage point per Looting level. Its remaining durability is randomized
with the source's two nested draws. Acquired armor drops without that extra
wear. Vanishing suppresses either drop. Dispensers equip empty slots, with the
entity-specific action before the player fallback. Occupied slots are not
replaced. Carved pumpkins and heads can also be equipped; failed equipment
placement can place the head or carved pumpkin as a block.

The existing source-backed `ArmorEffects` pipeline now handles mob armor as
well as player armor. A physical hit wears the pieces, then applies armor
points, toughness, protection enchantments and Thorns. A piece protects against
the blow that breaks it. Arrow and trident damage carry the actual shooter
through the hit callback so Thorns does not mistake a bystander for the attacker.
Trial armor uses these same slots rather than applying another armor factor.
Ongoing fire and withering use the source's fire and magic damage paths, so
protection enchantments apply without treating those effects as physical hits.

Head equipment prevents sunlight ignition. A successful source sunlight roll
can wear the helmet; an empty head can ignite for ten seconds. Breaking a
helmet does not ignite the mob in that same callback. The source calls
`scale_chance(dtime,30)` with its arguments reversed, producing a one-in-two
gate at normal tick lengths; this is preserved. The native world supplies roof,
water and rain checks. On Halloween, eligible mobs with empty head slots can
receive a carved pumpkin or jack o'lantern. These blocks do not wear out.

Armor, wear, item metadata, pickup permission and drop probabilities are saved
with the mob. They survive ordinary world reloads, conversion, trial snapshots,
leads and boat passenger records. Curing a zombie villager drops acquired armor.
Named or equipped mobs retain their persistence; ordinary unmarked monsters
can still despawn. Body parts carry native armor meshes that follow their joints.

The source's material table required four new copper armor items, IDs
11568–11571. They use the normal shaped armor recipes with copper ingots,
provide 2/4/3/1 armor points, have enchantability eight, repair with copper and
smelt to a copper nugget. Their exact durability profiles are exported alongside
the other armor, including Unbreaking and Mending behavior. The normal player
equipment, inventory, anvil, enchanting and trim paths accept them.

`tools/export_mob_armor_reference.py` executes the source armor generator,
comparison and drop methods, the mob damage modifier and sunlight handling.
Its 2,156 cases include 540 seeded generation cases, 120 forced material/slot
boundaries, 576 replacement decisions, 768 drop cases, 120 damage/Thorns cases
and 32 sunlight cases. `tests/mob_armor_reference_checks.gd` compares these
against native behavior. The extended durability oracle covers all four copper
pieces. The `mob_armor` lifecycle group checks actual damage, pickups,
dispensers, sunlight, conversion and world/trial reloads; `mob_armor_tour.gd`
renders the armor on articulated mobs.

Validation on 2026-10-24: all 2,156 armor reference cases pass. The combined
combat/equipment lifecycle run passes 310 checks, alchemy passes 239 and
survival passes 534. The expanded durability suite passes 3,312 wear sequences,
640 Mending cases and 100 armor cases; the enchanting reference suite passes.
Headless import, Linux pack export and visual inspection also pass.

Remaining work includes armor behavior for other mob families, full held-item
pickup and melee weapon switching, armor-derived movement and breathing effects,
the complete sunlight shelter-navigation logic, and multiplayer equipment
synchronization. Other projectile types still need their own attacker and
knockback comparisons. This does not establish complete mob or Mineclonia parity.

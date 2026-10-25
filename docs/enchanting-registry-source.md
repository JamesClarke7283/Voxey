# Registered enchantment eligibility

The supplied Mineclonia game is loaded in Luanti before data is exported. This
replaces the earlier source-text reconstruction, which applied registration
defaults even to tables assigned directly by other mods. The distinction affects
Curse of Binding: its manual armor registration omits `tradable`, so it is not
eligible for random treasure books. It remains a valid enchantment for manual
book application to armor.

`tools/export_enchanting.py` exports all 39 active definitions, 1,245 native item
bindings, the source's two bookshelf-offset arrays, and the base and enchanted
item definitions after all registration callbacks. Each item profile includes
its actual enchantability, item type, and relevant groups. The exporter records
hashes of the source files that declare or use enchantment registrations.

The shared selection and anvil paths now consult this data. Notable consequences:

- Swords are tools by item type but do not gain an invented `tool` group.
- Chestplates use the source's actual groups. Thorns is supported as a secondary
  enchantment; the source lacks the primary group needed for random chestplate
  Thorns. A Thorns book remains applicable at an anvil.
- Axe eligibility follows the active definitions. Bane of Arthropods and Smite
  remain secondary book applications, outside direct table selection.
- Copper armor and tools, netherite, elytra, shears, brushes, shields, ignition tools and
  steering items use their registered values and restrictions.
- New random books exclude the nontradable Binding, Soul Speed and Wind Burst
  entries. Existing books and equipped enchantments are retained.
- A successful source result containing zero additional enchantments is distinct
  from failure to find a first valid power match. The native generator preserves
  that distinction when rerolling already-enchanted inputs is explicitly allowed.

`Enchantments.DATA` is assembled from the active exported definitions. The two
inactive names, Aqua Affinity and Sweeping Edge, remain recognized for stored
items and their existing effects. The old compatibility table is retained only
for inventory decoding, so loading a pre-existing axe or helmet does not strip
an enchantment that Voxey previously allowed. New applications, random choices,
and anvil eligibility use the active registry. Saved-item level limits and
symmetric-conflict sanitation remain the existing native format boundary. The
one-way Soul Speed/Frost Walker pair remains intact in either serialized key
order, because the source can legitimately create it by applying Frost Walker
second. Applying Soul Speed second is rejected.

The only unmapped enchantable catalog entries are the native bayonet and turtle
shell. Their prior native behavior is retained; this is recorded in the export's
`native_extensions` list. Native randomness, the cached-offer UI, and the bounded
reliable-loot retry remain adaptations described in [enchanting](enchanting-source.md).
The full set of enchantment effects is still separate parity work.

## Verification

The exporter invokes the actual registered source functions, rather than feeding
manufactured item profiles to a copy of the selection logic. The generated
fixture includes:

- 2,490 base/enchanted item support rows, each checked against all 39 definitions;
- 3,120 current-enchantment application rows, also checked against all 39;
- 156 item/variant rows with four level-boundary checks per enchantment;
- 12,780 selection cases comparing enchantments, descriptions and RNG state;
- 936 complete three-offer table cases, including blank results and glyph draws.

Together these cover 256,842 comparisons in
`tests/enchanting_registry_reference_checks.gd`. The familiar
`tests/enchanting_reference_checks.gd` also reads a regenerated compatibility
fixture from the real game registry. The old export command remains available
and delegates to the new loaded-game exporter.

`tests/enchanting_registry_checks.gd` covers actual anvil application, uniform
books, source item-type distinctions, and saved legacy-item retention.

Validation on 2026-10-24: all 256,842 registry comparisons pass, as do the
regenerated 4,260 selection and 936 table-offer cases. The focused gameplay run
passes 118 checks; a final registry/anvil run passes 54, including one-way pair
persistence. Armor, weapon, villager-trade and anvil source regressions report
zero failures. Village and alchemy suites pass 904 and 239 checks. All 97
recorded source hashes match the supplied checkout. Full-size and compact
armor-offer screens were rendered and reviewed, and the Linux pack exports.
Full Mineclonia parity remains an active goal.

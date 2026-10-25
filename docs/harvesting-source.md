# Harvest eligibility and block drops

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-24.
Source-derived rules and exported data retain GPL-3.0-or-later attribution.

`Harvesting` uses registered definitions exported to `assets/data/harvesting.json`.
The source implementations are `mods/CORE/_mcl_autogroup/init.lua`
(`can_harvest`), `mods/ENTITIES/mcl_item_entity/init.lua` (`handle_node_drops`)
and the installed Luanti `builtin/game/item.lua` (`get_node_drops`).
Luanti's builtin drop-table behavior is LGPL-2.1-or-later; the repository includes
that license in `LICENSES/LGPL-2.1-or-later.txt`.

## Implemented behavior

Breaking time and receiving useful drops are separate checks. Mapped blocks
use the source's raw digging groups and the tool's harvest levels, then the
player's hand groups. Instant-dig nodes use the source exception. This replaces
category guesses, including the incorrect wooden-pickaxe allowance for copper
blocks, cut shapes and ore.

The shared drop path handles default drops, empty drops, ordered rarity tables,
maximum successful entries, exact-tool and tool-group requirements. Registered
aliases resolve as ItemStack does. A valid empty result is final and cannot fall
through to a generic self-drop.

Shears overrides precede Silk Touch. Fortune follows them, using the registered
per-level table or discrete multiplier, chance, cap and additional items.
Enchanted books do not apply their enchantments. Experience comes from the
node's `xp` group and is suppressed when the source actually selects a Silk
Touch drop. Ore rewards are paid once.

Concrete corrections:

- Gravel uses the registered 1/10, 1/7, 1/4 and certain-flint tables.
- Copper first rolls two through five raw copper, then independently applies
  Fortune. Fortune III can reach twenty; an ordinary pick does not always yield two.
- Lapis, redstone, crops, leaves and mushroom blocks use their source tables
  and caps. A mushroom block can yield nothing.
- Bookshelves yield three books unless Silk Touch selects the block. Shears
  recover supported vines, grass and cobwebs through their declared overrides.
- Snow yields one snowball per layer with a shovel. Silk Touch gives one through
  seven layer items, or one full snow block for eight layers. Support loss,
  flooding and piston destruction do not bypass the shovel-only drop table.
- Legacy snowy ground (ID 13) maps to snowy grass/dirt rather than a snow block:
  normal harvesting yields dirt and Silk Touch yields grass.

Source item names map through the node registry and the reviewed bindings in
`assets/data/harvest_items.json`. Generated variants normalize to inventory
items; native candle and banner colors retain their identity. Copper wax
metadata is captured before removing the block.

## Integration limits

The generic game break path and `Enchantments.harvest` use this resolver.
`Nodes.harvestable` uses its eligibility check for mapped blocks. Snow and the
legacy copper-ore helper also use it. Native blocks without a source registration
use the existing fallback implementations.

Special callbacks still own their side effects and metadata: paired doors/beds,
containers, hives, campfires, sculk storage, rooted vegetation and archaeology.
The comparisons below prove the shared transformations, not all those callbacks.
Creative collection behavior, full item metadata/palette interoperability,
other environmental drop paths and entity behavior remain separate parity work.

## Verification

`tools/export_harvesting_reference.py` runs the installed game in an isolated
temporary world. It calls the actual `mcl_autogroup.can_harvest`,
`core.get_node_drops` and `core.handle_node_drops` with real ItemStacks. A seeded
random stream verifies exact outcomes and draw order, including failed rolls.
The tool captures emitted items and experience without changing the reference
installation or the user's worlds.

All **102,414 eligibility comparisons** and **35,139 drop cases** pass. They cover
1,313 mapped source nodes, tool tiers, shears, Fortune, Silk Touch, books and
absent diggers. Every emitted source item has a native binding. The mining
fixture also passes 3,398 ID checks and 21,008 digging results after the snowy
ground correction.

`tests/harvesting_checks.gd` checks actual item entities, empty drops, tool
requirements, double slabs and XP payouts. Snow's lifecycle suite checks
ordinary, Silk Touch and environmental removal through the real world paths.

Final validation passed 2,198 combined lifecycle checks, 534 survival checks and
239 alchemy checks. The loopback host/client suite passed, including guest
mining, stale-break rejection and reconnect persistence. The exported Linux
PCK passed the same 102,414 eligibility, 35,139 drop and 21,008 mining comparisons.
Combined-test fixture isolation was repaired for leftover overhead platforms
and leather armor; the final combined run reports zero failures.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/export_mining_reference.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/export_harvesting_reference.py
godot --headless --path . --script tests/harvesting_reference_checks.gd
godot --headless --path . --script tests/mining_reference_checks.gd
godot --headless --path . --script tests/lifecycle_runner.gd -- harvesting snow_cover copper raw_ore ore_rule
```

# Copper tools and tool-action wear

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-24.
Source rules and registry exports retain GPL-3.0-or-later attribution. The five
tools are declared in `mcl_tools/register.lua` and `mcl_farming/hoes.lua`.

## Equipment

`CopperTools` registers five permanent item IDs, 11592–11596, for the pickaxe,
axe, shovel, sword and hoe. They use the source's copper-ingot and stick recipes,
including mirrored axes/hoes, and stack to one. Original procedural copper
sprites supply the inventory, held-item and dropped-item render paths.

| Tool | Attack damage | Full attack interval | Punch uses |
| --- | ---: | ---: | ---: |
| Pickaxe | 3 | 0.8333333 s | 95 |
| Axe | 9 | 1.25 s | 95 |
| Shovel | 3 | 1 s | 95 |
| Sword | 5 | 0.625 s | 191 |
| Hoe | 1 | 0.5 s | 95 |

The material declares 191 uses, mining speed 5, source level 3 and enchantability
13. Registered per-group digging capabilities determine actual mining speed,
wear and useful drops. The sword has separate general, cobweb and bamboo
capabilities. Copper picks recover iron, copper and lapis; gold, diamond,
redstone and obsidian require higher harvest levels.

Copper ingots repair the tools at an anvil, preserving names, enchantments and
exact normalized wear. The source enchantment registry supplies table offers
and book eligibility. Netherite upgrades remain restricted to diamond tools.
Every copper tool recycles into one copper nugget: ten seconds in a furnace,
five in a blast furnace. Smokers reject them.

## Right-click actions

`mcl_tools.on_tool_place` obtains wear from
`mcl_autogroup.get_wear(toolname, diggroup)`: `ceil(65535 / raw_group_uses)`.
Unbreaking does not reduce this fixed action increment. Copper tools add 344
normalized wear for a successful action; creative mode adds none. A failed
conversion leaves the tool unchanged. Wear beyond 65535 breaks the item.

The shared native action path now applies this rule when stripping logs,
removing copper wax, reversing copper oxidation, tilling and digging paths.
It selects the primary tool group, keeping the sword's special bamboo/cobweb
lifetimes out of the action calculation. All 35 ordinary material/tool
combinations have independently exported increment checks.

Hoes convert grass, dirt and paths to farmland; coarse dirt first becomes dirt.
Shovels convert grass, dirt and coarse dirt to paths, accepting top and side
faces. Both require literal air above. Stripping and copper scraping still work
when the block above is occupied. Axe use removes wax before reversing an
oxidation stage on the next click.

## Source quirks and native representation

The legacy numeric tool tier identifies harvest classes. Copper uses that
fallback's stone class, while its actual source level-3 registered profile
drives mapped mining. The displayed wear span is the material's declared 191;
the exact 0–65535 checkpoint drives wear, repairs and persistence.

`mcl_util.calculate_durability` obtains a generic tool lifetime from
`next(groupcaps)`. For swords, Lua table iteration can choose different groups
in separate processes: the copper sword can report either 95 or 238 unenchanted
uses. The native utility profile pins the captured general-sword value, 95;
its Unbreaking profiles are captured separately. The action, mining and combat
paths use their explicit groups and retain their own lifetimes. This source
iteration quirk is not treated as a deterministic sword-material rule.

## Verification

`tools/export_copper_tools_reference.py` loads the actual game in Luanti and
records five item definitions, 30 crafting layouts, 35 action increments and
384 real tool-place callbacks. The callbacks cover Unbreaking 0/1/3, survival
and creative mode, blocked/unblocked space above, and fresh/partly worn/almost
broken tools. Eight source-file hashes accompany the fixture.

`tests/copper_tools_reference_checks.gd` passes 413 registry/crafting checks.
`tests/copper_tools_checks.gd` passes 450 gameplay checks (451 including world
startup), covering those real callbacks, player mining, all three furnace
types, repair and enchantment integration, visuals and saved item metadata.
The shared digging, harvesting, melee, durability and enchanting fixtures now
include copper tools. Full-size and 800×600 crafting screens are reproduced by
`tests/copper_tools_tour.gd` and have been visually reviewed.

Final validation on 2026-10-24: the combined copper, wood, farmland, anvil,
tool-effect and enchantment gameplay run passes 881 checks. The source suites
pass 26,400 digging and 720 effect cases, 102,414 harvest eligibility decisions
and 35,139 drop cases, 1,366 melee cases, 3,552 wear sequences, 685 Mending
cases, 100 armor cases and 256,842 registered-enchantment comparisons. The
compatible offer fixture passes 4,260 rolls and 936 three-offer tables. Village
and alchemy regressions pass 904 and 239 checks. All recorded source hashes
match. The Linux pack exports without script errors.

Full Mineclonia parity remains active. Unimplemented content, complete mob
navigation, remaining enchantment effects and other module-specific gaps stay
tracked in [the parity ledger](mineclonia-parity.md).

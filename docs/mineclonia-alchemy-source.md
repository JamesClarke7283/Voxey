# Mineclonia alchemy and enchantment reference

The potion recipes, colors, effect durations, level limits and enchantment compatibility data in `scripts/potion_catalog.gd`, `scripts/enchantments.gd` and the related `scripts/village_content.gd` entries adapt the user-provided Mineclonia source read on 2026-09-07. Attribution: Mineclonia and MineClone contributors. Adapted source data is covered by GPL version 3; see [the full license](licenses/Mineclonia-GPL-3.0.txt).

The source has 26 potion definitions plus water. Voxey registers their supported drink, splash, lingering and arrow forms, including normal, extended and strong variants. Brewing uses the source’s ten-second batches and twenty-batch blaze powder fuel. Turtle-shell brewing and survival acquisition of special potions are Voxey additions. No source texture, sound, model or schematic was imported.

There are 39 active enchantment definitions in the reference. Voxey also implements Aqua Affinity and Sweeping Edge, which appear as disabled definitions in that checkout, for 41 total. Compatibility, maximum levels, treasure flags and curses come from the source. The table’s explicit enchantment selection and the simplified anvil costs are Voxey interfaces and rules, not a reproduction of Mineclonia’s random enchanting UI.

Source SHA-256 values:

| File under `mods/ITEMS` | SHA-256 |
|---|---|
| `mcl_potions/init.lua` | `d8f0bdbae83404dd8d3430427339748894302c76fbe3f071b8ea2130e9f635f7` |
| `mcl_potions/potions.lua` | `dc5b8f1359e77a383e1d68accaaa5d3a8f7d7d3e93086f234711c458543d6592` |
| `mcl_potions/functions.lua` | `86188f22f2d928a94e239697e6dfe0a20247f06050037f905042bee92ee1d9f1` |
| `mcl_brewing/init.lua` | `459e4127ab2e5c8c26a21b4257747885f4ee833d1d6e0cbb63fc34232fa36b3b` |
| `mcl_enchanting/enchantments.lua` | `ff7e36d44e8a407c1f1f17f1ff2964c9d249394392cd8e993c6d9072aae02507` |
| `mcl_armor/register.lua` | `4265fa1c640184fa4fbd8c05ee9cf611533238bf64e358e62e2fe3258a2a4cb2` |

Enchantment catalog:

| Enchantment | Maximum level | Treasure |
|---|---|---|
| Bane of Arthropods | 5 | No |
| Channeling | 1 | No |
| Curse of Vanishing | 1 | Yes |
| Depth Strider | 3 | No |
| Efficiency | 5 | No |
| Fire Aspect | 2 | No |
| Flame | 1 | No |
| Fortune | 3 | No |
| Frost Walker | 2 | Yes |
| Impaling | 5 | No |
| Infinity | 1 | No |
| Knockback | 2 | No |
| Looting | 3 | No |
| Loyalty | 3 | No |
| Luck of the Sea | 3 | No |
| Lure | 3 | No |
| Mending | 1 | Yes |
| Multishot | 1 | No |
| Piercing | 4 | No |
| Power | 5 | No |
| Punch | 2 | No |
| Quick Charge | 3 | No |
| Respiration | 3 | No |
| Riptide | 3 | No |
| Sharpness | 5 | No |
| Silk Touch | 1 | No |
| Smite | 5 | No |
| Soul Speed | 3 | Yes |
| Unbreaking | 3 | No |
| Density | 5 | Yes |
| Breach | 4 | Yes |
| Wind Burst | 3 | Yes |
| Projectile Protection | 4 | No |
| Blast Protection | 4 | No |
| Fire Protection | 4 | No |
| Protection | 4 | No |
| Feather Falling | 4 | No |
| Curse of Binding | 1 | Yes |
| Thorns | 3 | No |
| Aqua Affinity | 1 | No |
| Sweeping Edge | 3 | No |

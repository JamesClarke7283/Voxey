# Fishing source integration

Reference files are under `/home/impulse/.minetest/games/mineclonia`:

- `mods/ITEMS/mcl_fishing/init.lua`: fish, junk and treasure tables; category selection; catch XP; rod wear; 33-node line limit; waiting, Lure, rain and the bite window.
- `mods/ITEMS/mcl_fishing/items.lua`: rod recipe and fish cooking/food values.
- `mods/CORE/mcl_loot/init.lua`: weighted selection and wear quantization to increments of ten normalized wear units.
- `mods/ITEMS/mcl_enchanting/engine.lua`: weighted level-30 treasure enchantments, repeated enchantment attempts and the book-specific bonus behavior.
- `mods/ITEMS/mcl_mobitems/init.lua`: name-tag acquisition from diagonal paper and a metal nugget.

## Catch tables

Every source entry is retained. No missing item has been removed or replaced to rebalance the remaining entries.

| Category | Entries and weights |
| --- | --- |
| Fish | Raw cod 60; raw salmon 25; tropical fish 2; pufferfish 13 |
| Junk | Bowl 10; worn rod 2; leather 10; worn leather boots 10; rotten flesh 10; stick 5; string 5; water bottle 10; bone 10; ten ink sacs 1; string 10 |
| Treasure | Enchanted worn bow, enchanted book, enchanted worn rod, name tag, saddle, lily pad, nautilus shell; weight 1 each |

The two string entries in junk are deliberate: the second is still the source checkout's placeholder for a tripwire hook. Ink sacs are a single catch of ten items. Junk rods and boots have roughly 10–100% wear; treasure bows and rods have roughly 75–100% wear. Wear is converted into Voxey's discrete durability uses while keeping almost-broken catches usable.

The source compares an integer roll from 1 through 100 against fractional thresholds. Voxey reproduces those comparisons rather than treating the comments as continuous probabilities:

| Luck of the Sea | Fish rolls | Junk rolls | Treasure rolls |
| --- | ---: | ---: | ---: |
| None | 85 | 10 | 5 |
| I | 84 | 8 | 8 |
| II | 84 | 6 | 10 |
| III | 84 | 4 | 12 |

Luck and Bad Luck potion effects do not alter this table in the referenced fishing code. Lure changes waiting, not catch categories.

## Fishing loop

Use a rod while pointing at a clear surface of still source water. Wait for the bobber to dip and splash, then use the rod again within **0.8 seconds**. The normal wait is an integer **5–30 seconds**. Each Lure level subtracts five seconds from both limits, with a minimum lower limit of zero. Exposed rain or thunder multiplies waiting by 0.75. A zero waiting roll is rescheduled on update; it is not an immediate free catch. Missing the bite starts a fresh wait.

Successful catches grant **1–6 XP** and consume one rod use. Fish-category catches also unlock **Fishy Business**, with no additional XP. Empty reels consume no durability. Retrieving a bobber whose water cell became solid consumes two uses. Unbreaking follows Voxey's existing probabilistic durability mechanism; creative catches do not wear out rods. Rods have 65 uses and burn for 15 seconds as furnace fuel. A full backpack receives the entire catch as an item drop, preserving its count, wear and enchantments.

Changing away from a rod, moving beyond 33 blocks, dying, or resetting the dimension clears the transient line. Fishing timers do not survive world loading. Reeling after the pool has drained cannot produce a catch. Flowing water does not advance a fishing timer.

## Enchantments and added items

Treasure bows, rods and books use the existing source-derived enchantment weights, eligibility, conflicts and power bands. The initial enchantment power is the source level-30 roll with enchantability one. Power halves for each additional selection. Bows and rods use the source bonus-selection cutoff; books continue until power is exhausted. Books may contain conflicting enchantments together, as the source permits; applying them to equipment still enforces compatibility.

Soul Speed and Wind Burst are not tradable in this source and are excluded from fishing treasure selection. Aqua Affinity and Sweeping Edge are disabled or absent source definitions even though Voxey implements them elsewhere, so fishing does not add them to the source lottery.

Stable new item IDs are **1200 (name tag)** and **1201 (nautilus shell)**. A name tag can also be crafted from paper and either available metal nugget (iron or gold), in either diagonal of a 2×2 grid. Name editing and persistent mob naming are provided by the separate name-tag implementation.

## Remaining parity boundaries

Casting still uses Voxey's targeted water interaction. It does not simulate the source's flying bobber trajectory, fishing line mesh, hooking and pulling item entities or other hookable objects. Sounds and bobber art use Voxey's own assets. Rain eligibility uses Voxey's weather and sky-cover test rather than Mineclonia's full weather-biome system. Catch enchantments use Voxey's existing catalog; future source enchantments require additions to that catalog.

Nautilus shells are preserved as real obtainable treasure. Their downstream conduit crafting and conduit effects remain a separate missing progression feature. There is no substitute reward or silent reweighting for that dependency.

`tests/fishing_checks.gd` validates category boundaries, weighted selection, all source outputs, worn and enchanted metadata, crafting, XP, durability, timing and live cast/reel conditions using an isolated game world.

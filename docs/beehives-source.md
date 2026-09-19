# Beehives, bee nests and honey

This port follows the supplied Mineclonia implementation in `mcl_beehives` and `mcl_honey`. That implementation **does not contain bee entities**. It simulates honey production with an active-block timer and substitutes immediate damage for a bee attack. Voxey implements that same survival loop; it does not imply that autonomous bees, pollination flights or breeding exist.

## Survival loop

Oak and birch trees can contain natural bee nests. A grown oak or birch also has a 5% nest roll when a flower exists in the same-height square within two blocks of the sapling. The sapling callback tries one of the source's three directions, then searches heights 1–7 for air under leaves or a log. Other wood families do not create nests through this callback. A natural nest can be used in place; Silk Touch recovers its honey level. Three honeycomb between two rows of three wood planks craft an artificial hive. Mixed plank species work through the existing source wood-group crafting system.

Loaded hives and nests attempt honey production every 75 seconds. Production requires a flower within five blocks, time strictly between source ticks 6000 and 18000, and weather other than the literal `rain` state. An eligible attempt adds one honey level, or two on the source 1% roll, capped at five. The source does not require an unobstructed entrance, an open sky, a dimension check or visible bees. The source's literal weather check allows a distinct `thunder` state. Voxey's existing time/weather conventions are used without adding a second clock.

A full hive or nest can be harvested with a glass bottle or shears:

- A bottle becomes one honey bottle; shears eject three honeycomb and spend one use of durability.
- Harvest resets the honey to zero and retains the facing.
- Without a lit campfire in the same vertical column within five blocks below, harvesting deals ten points of ordinary mob damage. Normal armor/resistance/creative immunity apply.
- Both ordinary and soul lit campfires protect harvesting. The local source searches only the positions; it does not check intervening solid blocks. Unlit fires and fires six blocks below do not protect.
- Sneaking bypasses the interaction. Creative harvesting still empties the hive, but preserves bottles and shears durability.
- Protected bottle harvesting awards “Bee Our Guest”; Silk Touch nest recovery awards “Total Beelocation”.

The source's full-inventory bottle handler resets honey even when it cannot give the output. Voxey deliberately fixes that loss: after consuming a survival input, output is inserted into inventory or delivered as a physical honey-bottle drop. Items and input consumption are resolved before retaliation can kill the player and clear their inventory.

Digging is a separate source action. A crafted hive drops an empty hive and inflicts ten damage without Silk Touch. A nest inflicts ten damage and drops nothing without Silk Touch. Silk Touch preserves the honey level and causes no retaliation. A held enchanted book is explicitly excluded for nests in the source, but not for crafted hives; that distinction remains. Campfires do not protect digging. Creative digging grants at most one empty canonical hive/nest into the inventory, with no damage. Explosion destruction has no player-dig retaliation and no item drop.

## Honey items and building

| Item | Source behavior |
| --- | --- |
| Honeycomb | Three per full-hive shearing; four in a square make a honeycomb block |
| Honey bottle | Stacks to 16; normal 1.61-second eating action; restores 6 hunger and 1.2 saturation; can be consumed at full hunger; returns glass |
| Honeycomb block | Full cube, hardness 0.6, recoverable by hand |
| Honey block | Full collision cube, translucent amber appearance, hardness 0, recoverable by hand; reduces fall damage by 80% |

One honey bottle crafts three sugar and returns one glass bottle. Four honey bottles in a square craft a honey block and return all four glasses. The reverse uses the exact asymmetric source pattern: two glass bottles and a honey block in the top row, two glass bottles below them. It yields four honey bottles. Container returns work through direct crafting, manual grids and recipe-guide crafting. If a remaining ingredient stack prevents a replacement from occupying its cell and inventory cannot hold the returned container, the crafting transaction is rejected intact, including clicks with an empty or already occupied crafting cursor.

The supplied honey bottle does **not** cure poison. The supplied honey block does **not** define walking slowdown, suppressed jumping or side sliding. Those familiar behaviors are not invented here. Its source piston rule adheres to adjacent blocks in six directions, with honey and slime refusing adhesion to each other; forward pushing still moves either material. The source's normal piston limit and immovable/diggable rules remain active. Crafted hive levels 0–4 are immovable by their explicit source group; full crafted hives and all nests omit that group and remain movable.

Dispensers can bottle or shear full hives/nests without smoke or retaliation. Bottles return honey into the dispenser or eject it beyond the target if full. Shears eject three honeycomb beyond the target and spend the source's fixed one-of-238 use, even if enchanted with Unbreaking. Droppers retain their ordinary item-ejection behavior. Comparator output is the actual honey level, 0–5.

## Persistence, generation and bounded work

IDs 7600–7623 encode crafted hives, and 7624–7647 encode nests: six honey levels with four horizontal facings each. Silk Touch items keep the honey level but discard placed facing, just as source drops keep node name but not `param2`. Only the empty canonical hive/nest appears in the creative catalog. IDs 7650–7653 are comb, bottle, comb block and honey block. Hidden IDs 7660–7668 are atlas textures, not placeable items.

The timer lives in the existing saved station data. Registered cells are indexed by loaded column; unloading removes live work but preserves the countdown, and no offline production is granted. Pending flower searches keep a zero countdown so loading restarts the search. Searches are capped at 128 sampled cells per update across the apiary, avoiding a synchronous 11×11×11 scan per hive. Real node changes update the registry; piston moves preserve the station timer and honey state.

Natural generation uses the local `mcl_trees/lg_register.lua` forest postprocessor's 0.2% per eligible oak/birch tree probability, deterministic from world seed and tree position. It uses the source four-direction search for a leaf roof at heights 2–8. Voxey's existing climate and tree plans are different from Mineclonia's biome decorators, so this is an explicit world-generation adaptation: flower forests, meadows and cherry/mangrove nest distributions are not claimed. The source sapling callback uses a schematic placement offset; Voxey uses its already normalized trunk origin. Artwork and honey/bottle/comb icons are original procedural Voxey art; no Mineclonia textures are copied.

Copper waxing remains dependent on a real oxidation/waxed copper family, which Voxey does not yet provide. The source comb's preserved-copper swap has no valid target in the current item registry. This batch therefore does not consume comb on ordinary copper or pretend that persistent waxing is implemented.

## Source provenance and verification

Paths are relative to `/home/impulse/.minetest/games/mineclonia/`. The supplied tree has no Git revision metadata. `mcl_beehives` and `mcl_honey` identify PrairieWind as author; translated gameplay logic is adapted under the supplied Mineclonia GPLv3 license. Supporting source is the existing Mineclonia project code; no source art or audio is copied.

| Source | Rules used |
| --- | --- |
| `mods/ITEMS/mcl_beehives/init.lua` | Node levels, production, smoke, harvesting, digging, comparator values, piston groups and hive recipe |
| `mods/ITEMS/mcl_honey/init.lua` | Honey items, food values, recipes, containers, honey collision/fall damage and sticky callback |
| `mods/ITEMS/mcl_trees/functions.lua` | Flower-gated sapling nest callback and three-direction placement |
| `mods/ITEMS/mcl_trees/lg_register.lua` | Natural tree nest probabilities and four-direction leaf-roof placement |
| `mods/ITEMS/mcl_core/nodes_trees.lua` | Oak/birch after-grow dispatch |
| `mods/ITEMS/mcl_potions/init.lua` | Bottle dispenser harvest and overflow ejection |
| `mods/ITEMS/mcl_tools/init.lua` | Shears dispenser harvest and fixed durability |
| `mods/ITEMS/REDSTONE/mcl_pistons/api.lua` | Six-direction sticky frontier, piston limit, forward/side immovable rules |
| `mods/ITEMS/mcl_core/nodes_misc.lua` | Reciprocal slime-versus-honey adhesion exclusion |

`tests/beehive_checks.gd`, invoked through `tests/lifecycle_runner.gd -- beehive`, exercises the actual player, crafting, dispenser and save interfaces in addition to deterministic source boundary checks. It checks honey levels/facings, capacity safety, smoke range, separate Silk Touch/creative/blast behavior, production and unloaded timers, natural/sapling nest rules, food/container returns and JSON reload. The root integration suite covers interaction with the remaining gameplay systems.

Source SHA-256 fingerprints:

| File | SHA-256 |
| --- | --- |
| `mods/ITEMS/mcl_beehives/init.lua` | `dd7896b0999277049b02c3aa05089be63246edabbaead4404ab566da9849ad17` |
| `mods/ITEMS/mcl_honey/init.lua` | `ea06bf64ced235115da529de6ebc8a06466b71c756216eba854f5a2b040cf977` |
| `mods/ITEMS/mcl_trees/functions.lua` | `12565fef453b1dfc6939e54d4836529a0c33b0258741b133793879f19113956c` |
| `mods/ITEMS/mcl_trees/lg_register.lua` | `b04ef54545d76c64b6aa876a4cebaa9a7d163238877724bfe67cf97bb49d4e64` |
| `mods/ITEMS/mcl_core/nodes_trees.lua` | `1f0ded40f54c42f53ba49a47a99f22ae57da878bc777eff2dbe6dfcd832a2c64` |
| `mods/ITEMS/mcl_potions/init.lua` | `d8f0bdbae83404dd8d3430427339748894302c76fbe3f071b8ea2130e9f635f7` |
| `mods/ITEMS/mcl_tools/init.lua` | `cadc6d5501975551780979ee7626aeb8c648eba0799d2a4e64db62e266188104` |
| `mods/ITEMS/REDSTONE/mcl_pistons/api.lua` | `b230ebad08afe5b5f41f677347d4e6d84e087b2e31b41a2b1964eb76fefebfbf` |
| `mods/ITEMS/mcl_core/nodes_misc.lua` | `780fa1eb79ba364d2dcd2d1425618d68a132c38fe0db5a67fa87d0b53f9d7b0f` |

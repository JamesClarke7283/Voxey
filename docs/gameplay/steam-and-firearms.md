# Steam machinery and flintlocks

These are built-in Voxey additions. Existing worlds gain the recipes and creative-catalog items automatically.

## Build a steam workshop

1. Craft a **coal-fired steam generator**, **steam bellows**, and **iron steam pipes** at a crafting table. Six iron ingots make eight pipes.
2. Place the generator directly behind the bellows. The brass outlet and arrow show the bellows' forward direction; use a screwdriver to cycle through all six directions.
3. Run pipes from the bellows' outlet to a **steam ore grinder** or **steam furnace**. Power the bellows with a lever, redstone wire, or a redstone block. Pipes join on all six sides and can branch.
4. Right-click the generator and insert coal, charcoal, or a coal block. A coal item burns for 40 seconds, making 12 steam units per second; the generator stores up to 240. Steam is shared between connected machines, so adding branches does not duplicate it.
5. Put raw iron, gold, or copper into the grinder. Every raw item becomes **four ore powders** in four seconds. Smelt those powders in a steam furnace or a normal furnace; each becomes one ingot. Collected ore blocks also work, including deepslate ores, coal, diamond, lapis, redstone, quartz, and emerald. Copper and multi-drop ores yield more powder to reflect their base mining yields. Finished ingots and powders cannot be ground again.

Steam furnaces take four seconds per item and use one steam unit per second. Grinders use two per second. Both stop without using ingredients when the output is full or steam runs out. Use Ctrl + right-click to attach pipes and blocks to an existing machine without opening it.

Hoppers and droppers can feed generator fuel and machine inputs. A hopper below a grinder or steam furnace extracts only the finished output. The workstation shows fuel, steam, progress, or the reason it has stopped. Machine inventories, fuel, steam, and progress are saved with the world.

## Build a frame vehicle

Join **machine frames** into a chassis. Each frame attaches blocks touching its six sides; frames spread that connection to other frames. Cargo blocks do not spread it further. Add a deck above the frames for passengers to stand on, and keep the chassis clear of the ground and nearby buildings.

Attach a **steam frame engine**, generator, bellows, and connecting pipes to the chassis. Point the engine where you want to travel and power both it and the bellows with redstone. Carry the power source aboard to keep moving. A screwdriver turns the engine through north, east, south, west, up, and down.

A powered engine attempts one block of travel every 0.8 seconds. Each move costs four steam units plus 0.1 per attached block. Assemblies can contain up to **256 blocks**, including the engine and cargo. The engine stops if a block, passenger, world boundary, or unloaded area obstructs it. Chests keep their contents, machines keep their state, and passengers travel with the deck. Remove the engine's power source to stop.

## Old-time weapons

Craft weapons at a crafting table and **right-click to fire**. A shot consumes one **musket shot** and one **gunpowder**. Four iron nuggets craft eight musket shots by hand.

| Weapon | Damage | Reload | Character |
| --- | ---: | ---: | --- |
| Musket | 16 | 3 seconds | Accurate long barrel |
| Flintlock pistol | 10 | 1.8 seconds | Faster reload, wider spread |
| Blunderbuss | 3 per pellet, seven pellets | 3.8 seconds | Wide spread, one load per blast |
| Bayonet | Iron-tier melee | — | Durable close-range blade |

Firearms reload automatically while carried. Switching slots does not reset the timer, and saving preserves it. Creative mode does not consume ammunition or durability. Bullets collide with terrain, cannot be recovered, and do not award arrow-specific achievements.

# Voxey

An original, single-player voxel survival game built in Godot 4.7. Inspired by Luanti / Mineclonia and Minecraft, with procedural pixel textures and a native desktop interface.

Open `project.godot` in Godot and press **F5**, or run:

```sh
godot --path .
```

Choose **Play / choose a world**, create a named world or select an existing one, and choose **Survival** or **Creative** before entering.

## Playing

| Input | Action |
| --- | --- |
| WASD | Move |
| Mouse | Look |
| Space | Jump / swim upward; hold while falling with equipped elytra to glide |
| Shift | Sprint on land; swim downward in water; descend when flying |
| Ctrl | Sneak and avoid walking off edges; bypass station interaction |
| Hold left mouse | Progressively mine a node / attack |
| Right mouse | Place, interact, eat, till, plant, wear armor, or light TNT |
| Hold Z or right mouse with a spyglass | Zoom in |
| E | Inventory, crafting grid, and searchable recipe guide |
| 1–9 / mouse wheel | Select hotbar slot |
| Q | Throw one held item; in inventory, drop one carried or hovered item |
| F / double Space | Toggle Creative flight |
| Middle mouse | Pick targeted node in Creative |
| `/` or T | Open console |
| Esc | Pause / close screen; drop a carried stack when the pointer is outside inventory |
| F3 | Performance and map-block information |
| F5 | Save world |
| F11 | Toggle fullscreen |

**Crafting:** place items in the 2×2 inventory grid, or right-click a placed crafting table for a 3×3 grid. Patterns can be moved within the grid; asymmetric tools also accept mirrored patterns. Mushroom stew, pumpkin pie, and mossy stone recipes accept ingredients in any arrangement. Click the output to take it. The recipe guide shows ingredients and a reference pattern; **Fill grid** transfers the required items into the real grid. Shift-fill prepares a batch, and Shift-clicking output crafts into the inventory. Right-click splits a stack or places one item. Drag by pressing an item and moving the pointer. Carry a stack outside the inventory panel and press Escape to drop it and close the screen. Clicking outside drops the stack; right-clicking outside drops one. Q drops one carried or hovered item. Closing with the pointer inside returns unused grid/cursor items; overflow becomes a pickup. Recipe search accepts Q as text.

**Deeper worlds:** the Overworld now reaches bedrock at **Y −128**, matching Mineclonia’s documented lower limit. The old generated floor at Y 0 becomes mineable stone, while existing surface terrain and saved builds retain their coordinates. Deepslate takes over below Y −64, with a transition up to −46, with larger caverns, deep ore variants, and lava below Y −112. The Nether has terrain through local Y 128 and building room through Y 256. Overworld builds can reach Y 30927, with horizontal coordinates −30912…30927. Empty upper space is streamed sparsely. Cave enemies can spawn underground during daylight; torches help keep them away. See [the depth and inventory guide](docs/depth-inventory.md).

**Survival progression:** gather logs, make matching planks and a table, then a wooden pickaxe. Mine stone for stone tools and a furnace. Stone picks harvest iron and copper; smelt ore with coal or wood. Iron picks harvest diamond and gold. Diamond tools can be upgraded to Netherite at a smithing table. Tools have durability; using the wrong tool is slower and may not yield a drop.

**Mining feel:** holding the mouse button grows a crack overlay from the exact centre of every face of the node, in nine symmetric stages, while chips fly off the struck face. Sand and gravel are falling nodes: remove their support and they drop as entities until they land.

**Armor:** leather, iron, golden, and diamond helmets, chestplates, leggings, and boots are crafted at a table with the classic patterns. Right-click a piece to wear it, or drop it into the armor column of the inventory screen (each slot accepts only its own piece; Shift-click a piece in your bag to equip it). Every point of defence absorbs 4% of damage, up to 80% for a full diamond set; pieces wear down with each hit and eventually break. Drowning, starving, and falling bypass armor. Worn armor is saved with the world and goes into the recovery chest on death.

**Creatures:** sheep, cows, pigs, and chickens wander the surface by day; cows always drop 1–2 leather, chickens drop feathers. At night zombies, skeletons, spiders, and creepers spawn away from torchlight. Zombies groan and chase, skeletons keep their distance and shoot arrows, spiders leap and are neutral in daylight unless provoked, and creepers hiss, swell, and explode. Zombies and skeletons burn in sunlight. Craft shears from two iron ingots and right-click a sheep to clip its coat for wool — it regrows as the sheep grazes — and milk cows with an empty bucket. Creature calls, hurt sounds, hisses, and blasts are synthesized at startup and played positionally. Hostiles drop rotten flesh, bones, string, and gunpowder.

**Nether, enchanting, and books:** build a 4×5 obsidian frame (2×3 opening; corners optional), light the inside with flint and steel, and stand in the portal for one second. The Nether has lava seas and falls, quartz ore, glowstone, five biomes, giant fungi, nether-brick fortresses with blaze spawners and loot, piglins, magma cubes, ghasts, and endermen. Travel scales horizontal coordinates by 8; each dimension keeps its own edits, storage, and pickups. Water evaporates there, and a bed placed there **explodes**. A blaze fireball sets you alight for five seconds; fire-resistant mobs — blazes, ghasts, magma cubes and seven others — never catch. Water is the counter to a blaze or an enderman, and rain puts a burning mob out. Most mobs float in water — chickens and cows bob up; zombies, skeletons and golems sink.

Water and lava now flow downward before spreading on support, and dependent flows drain when their source is removed. Water touching lava from any of the six sides converts the lava source to obsidian. Deep caves now generate lava and lapis ore. Mine obsidian with a diamond pickaxe; buckets collect and place water or lava sources.

Craft an **enchanting table** from a book, two diamonds, and four obsidian. Right-click it, select equipment, and spend lapis plus XP levels. The HUD shows your current level and progress toward the next one. Bookshelves with a one-block air gap unlock stronger tiers. **Books** use three paper and one leather, in any arrangement; cows now always drop 1–2 leather. Combine a book, feather, and charcoal for a **writable book**. Right-click to write, close to keep a draft, or sign to make it read-only. Written text and enchantments stay attached through inventory moves, chests, drops, death, and saves. See [the Nether and enchanting guide](docs/nether-enchanting.md).

**Arrows and pickups:** skeletons wait until their bodies face their targets and fire forward from the bow. Grounded arrows from either side can be recovered and expire after ten active minutes; their age survives saving. Ground items are attracted only when the entire pickup fits in the inventory. Ordinary item drops still expire after five active minutes. Timers pause in menus and inactive dimensions.

**New content and artwork:** enemies now have original pixel skins, articulated limbs, and clearer faces: a ragged zombie, a skeleton with an open rib cage and bow, an eight-legged spider with fangs, and a mottled creeper. Inventory icons use the block atlas; items share pixel silhouettes across inventory, pickups, and the player’s hand. Sixteen additional items and blocks include sugar cane, red/brown mushrooms, vines, red bricks, hay bales, mossy stone, coal blocks, terracotta, charcoal, bowls, mushroom stew, metal nuggets, and eggs. See [the content guide](docs/content.md) for gathering and recipes.

**Luanti-style extras:** bones grind into bone meal that ripens wheat and cocoa pods, grows sugar cane and bamboo, grows a huge mushroom from a small one, gives a sapling a 45% growth attempt, or carpets a grass block with tall grass and flowers over a 15×15 patch. Any wool block unravels into four string; four string in a 2×2 square make a level-one pouch. Gunpowder and sand make TNT, which is lit with a right-click, falls, flashes, and detonates after three seconds, chaining into nearby TNT. Explosions leave craters, drop some of the destroyed nodes, and hurt anything close. Dropped nodes and the held node are miniature copies of the real textured node. Gravel sometimes yields flint; chickens drop feathers; flint, sticks, and feathers become a bow and arrows. Compasses point the way home, clocks read the day and hour, iron/gold/diamond form storage blocks (and revert), and glowstone lights the night.

**Achievements:** sixteen moments of pride — from *Timber!* (first log) through *The Iron Age*, *Barber* (shear a sheep), *Milkmaid* (milk a cow), *Spelunker* (dive below Y 8), to *Survivor* (five days alive). Progression awards fire in survival mode only, pay experience, and persist in the world save. Browse them from the pause menu under **Achievements**. The game version shows on the title screen and pause menu.

**Water:** hold Space to swim upward or Shift to swim downward. At the surface, hold Space and move toward a bank to climb out onto a one-block shoreline. Touch players hold Jump to rise and use Sneak to descend. Hostile creatures cannot see through walls: their aggro checks voxel line-of-sight, and they keep hunting briefly after losing sight before giving up.

**Mobile:** Voxey runs on Android, iOS, and other touch devices. Phones get on-screen controls — a floating joystick (touch the lower-left of the screen), jump, sneak, mine (hold), use, and in Creative a fly button — plus tappable hotbar slots, a pause/chat/drop row up top, and a drag-anywhere camera. The inventory adds **Split mode** and **Batch mode** toggles in place of right-click and Shift. Panels shrink to fit small and rotated screens; `window/handheld/orientation` follows the device. Export presets for Linux, Android, and iOS ship in `export_presets.cfg`.

**Mods:** drop a folder into `mods/` (or `~/.voxey/mods/`) with a `mod.json` manifest and an entry script, and it receives the sandboxed `VoxeyAPI`: register new nodes and items, read and change the world, give or take inventory items, and subscribe to gameplay hooks (`on_node_broken`, `on_player_hurt`, …). A broken mod is skipped with a logged error; it never blocks the game. See `docs/modding/` for the full guide, API reference, and worked examples. `mods/survival_tweaks/` ships as a live example.

**Food and shelter:** hold right-click to eat (1.61 seconds for most foods, 0.8 seconds for dried kelp); release to cancel. Eat apples, cook meat, or till dirt with a hoe and plant seeds. Wheat matures after 90 active world seconds; three wheat make bread. Sheep also provide wool for beds. The bed is a proper two-node bed — the recipe lays a foot and a head half in the direction you face, each rendered as a half-height mattress with a pillow end; right-click either half to set spawn and sleep at night when no hostile creature is nearby, and breaking either half removes the whole bed and drops one item. Old saves with the single-node bed load as the new foot half. Saplings attempt growth every 35 active seconds with a one-in-five chance, subject to soil, light and clear space; dark oak requires a 2×2 square. Torches illuminate the surroundings and prevent nearby hostile spawns. Death leaves recoverable item drops, which expire after five active minutes.

**Storage chests:** a chest (8 planks at a table) holds 27 stacks; right-click to open, Shift-click to move stacks in or out. Place a second chest directly beside one and they join into a single large chest with 54 slots that keeps everything already inside. A chest never joins more than one neighbour, and breaking one half drops that half's items while the other half keeps its own 27. Contents drop when a chest is broken and are saved with the world.

**Trees and wood:** oak, spruce, birch, jungle, acacia and dark oak grow naturally and from saplings. Logs follow the face you place them on; right-click with an axe to strip them. Leaves can drop sticks, saplings and, for oak/dark oak, apples; shears or Silk Touch recover leaves. Natural unsupported leaves decay, while leaves you place remain. Use matching planks for each species’ stairs, slabs, fences, doors, trapdoors and boats. Ordinary recipes such as sticks, tables and chests accept mixed wood species.

**Doors, signs and cake:** wooden doors open from either half; iron doors need redstone, which can power either half. Place matching doors beside one another for mirrored hinges. Craft an oak sign from six oak planks and a stick, write its text when placing it, and use dyes to color the lettering. `/gamerule signsEditable true` enables later editing. Place cake on a solid support and right-click to eat one of seven slices. Chorus fruit can teleport you to a nearby safe spot; craft suspicious stew with mushrooms, a bowl and a poppy, dandelion or oxeye daisy for its flower’s effect.

**Creative:** all items are available through the inventory's **All items** tab. Placement is unlimited, mining is fast, tools don't wear out, and survival damage is disabled. Flight still respects solid terrain. Switching modes keeps the same world and inventory.

Select a saved world and choose **Delete…** to delete it. The confirmation names the world; **Cancel** or Escape keeps it. Confirmed deletion includes its dimensions and backups.

See [the performance and interface update](docs/performance-and-ui.md) for the gray recipe grid, GPU diagnostics, wall torches, inventory rules and measured streaming improvements.

## Console

```text
/gamemode survival
/gamemode creative
/time day
/time night
/give <item> [count]      e.g. /give diamond_pickaxe, /give iron_ingot 16
/spawn <creature>         sheep cow pig chicken zombie skeleton spider creeper piglin magma_cube
/tp <x> <y> <z>
/dimension overworld | nether | end
/locate village | stronghold | fortress | end_city
/sethome                 save this player’s home in this world
/home                    return to that home, including across dimensions
/weather clear | rain | thunder
/gamerule keepInventory true | false
/xp <points>
/heal
/killmobs
/seed
/save
/spawnpoint
/help
```

The console pauses movement while typing. Press Esc to return to the game.

## Saves

Every desktop installation uses the home directory, independent of the project location:

- Linux: `/home/<user>/.voxey`
- macOS: `/Users/<user>/.voxey`
- Windows: `%USERPROFILE%\.voxey` (with `HOMEDRIVE` + `HOMEPATH` fallback)

Each world has its own directory:

```text
.voxey/
  worlds/
    <unique-world-id>/
      world.json       # World-picker metadata
      save.json        # Seed, edits, inventory, mode, player and station state
      save.json.bak    # Previous successful save
```

Saves are version 2 (version 1 files still load; the old single chestplate becomes an iron chestplate in the armor slots). Saves use a temporary file, flush, backup, and rename. An invalid primary save falls back to the backup. Autosave runs every 45 seconds during play; F5, leaving to title, and closing the window also save. Old `user://voxey_world.json` saves are imported as **My first world**, retaining the original file. Terrain is regenerated from the seed; modified nodes, growing crops, furnace contents/progress, chests, drops and their ages, grounded arrows, all three dimensions, written book contents, enchanted equipment, three equipped pouches and their paginated contents, brewing progress and fuel, potion effects and strengths, villages, trades, leads, player homes, and crafting ingredients are persisted.

`VOXEY_DATA_DIR` can override the storage root for portable installations and isolated tests. Sandboxed platforms without a home environment use their writable application directory. The desktop code is portable; this build has been run on Linux. Windows and macOS home-path selection is covered by tests, but native builds on those systems have not been exercised.

**Redstone and the End:** mine redstone to craft dust, torches, levers, buttons, plates, repeaters, comparators, observers, lamps, pistons, sticky pistons, doors, dispensers, droppers, and hoppers. Defeat blazes for rods and endermen for pearls, craft Eyes of Ender, and follow them to a stronghold. Fill twelve portal frames to enter the End. Destroy tower crystals and defeat the dragon for XP, an egg, and portals to home and the outer islands. Explore shulker-guarded cities for elytra. See [the redstone and End guide](docs/redstone-end.md) for controls, recipes, saving, and the encounter.

## World and rendering

Voxels are **nodes**. Each **map block** contains 16×16×16 nodes in a 32-bit integer array. The world streams horizontally around the player. The Overworld permits building from Y −127 through 30927 above its bedrock floor at −128; unedited upper air is implicit. The Nether has a local ceiling at 256, and the End at 24945. Natural terrain currently occupies the lower part of these ranges. The End has islands over an open void. See [the source comparison](docs/mineclonia-world-source.md) for coordinate mapping and remaining terrain differences.

- Worker-thread terrain generation and mesh construction with deterministic noise, caves, ore clusters, cross-boundary trees, meadows, shores, desert, and snow biomes.
- Greedy meshing merges coplanar faces; neighboring nodes and a one-node halo eliminate internal and map-block-boundary faces. One opaque/cutout surface and one water surface per map block, with a shared repeating texture atlas.
- Only affected map blocks and their boundary neighbors are remeshed after edits. Distant map blocks unload; edits persist.
- Voxel DDA targeting and swept/substepped voxel AABB movement avoid per-node scene objects and expensive collision-mesh rebuilding.
- Nine crack stages use a full UV square on each face. The crack texture is drawn in one sector and stamped with four-fold rotational symmetry about the exact face centre, so every stage grows evenly outward; forks and web rings appear in later stages.
- Day/night lighting, fog, voxel clouds, positional torch lights, generated 2D and positional 3D sound effects, textured pickups, falling nodes, mining debris, and explosion craters.

Voxey includes three dimensions, redstone simulation, villages and trading, brewing, enchantments, portable pouches, Netherite, an initial bastion adaptation and a persistent End dragon encounter. Multiplayer, the Wither and parts of Mineclonia’s full content roster remain open in the [parity ledger](docs/mineclonia-parity.md). Farm animals, named mobs, villagers, linked animals, alchemy creatures, bastion residents and major encounters persist. Unnamed ordinary hostile mobs may despawn. Visuals are original procedural assets; source data and noise algorithms retain attribution and licenses in `docs/`.

**Animal farming:** hold wheat to attract cows and sheep; carrots, potatoes or beetroot attract pigs; seeds attract chickens; carrots or golden carrots attract rabbits. Feed two healthy adults to breed. Babies grow over 20 active minutes, and feeding them speeds growth. Parents wait five minutes before breeding again. Dye sheep with any of the sixteen dyes; shearing drops matching wool, and lambs inherit mixed or parental colors. Sheep regain wool by eating grass, which can spread back from nearby grass in adequate light. Chickens lay eggs every five to ten active minutes. Animal ages, names, coat colors and cooldowns survive saves and area unloading. Horses retain their existing taming and riding behavior.

**Fences, gates and walls:** craft fences and gates from any of the six classic wood families or Nether brick, plus 21 stone wall materials. Gates open by right-click or redstone. Tie attached leads to a fence to keep animals at home; the anchors persist when you travel or save. See [source rules and crafting](docs/barriers-source.md).

**Daylight detectors and targets:** use glass, quartz and wooden slabs to craft a detector. Right-click it to invert its output. Targets use a hay bale surrounded by redstone dust and emit a one-second pulse when hit; arrows and tridents score stronger signals near the bullseye. See [device rules](docs/redstone-sensors-source.md).

**Buttons and pressure plates:** stone and polished blackstone buttons pulse for one second; the six classic wood buttons pulse for 1.5 seconds and can be triggered by arrows and tridents. Stone plates detect living entities, wood plates also detect physical objects, and gold/iron weighted plates vary their signal with the number of objects. Buttons attach to all six faces. See [source rules](docs/redstone-inputs-source.md).

**Note blocks and jukeboxes:** right-click a note block to tune one of 25 notes, punch it to play, or trigger it with redstone. Its instrument depends on the block below; leave air above it. Insert a music disc into a jukebox by right-clicking, then right-click again to eject it. Disc identity determines comparator output. The eight music tracks retain their [original credits and licenses](assets/audio/jukebox/ATTRIBUTION.md).

**Campfires:** right-click a lit campfire with raw food to fill one of four cooking spots. Food cooks in 30 seconds and drops for collection. Use a shovel to smother the fire or flint and steel to relight it. Soul campfires use soul sand or soul soil in place of coal. Both kinds emit smoke, with taller smoke over hay, and hurt creatures standing on them. Old campfire furnace inventories are returned as item drops during migration.

**Fishing and names:** cast a fishing rod into still water and reel in during the bobber's brief dip and splash. Catches include fish, junk and treasure; Luck of the Sea changes the odds and Lure shortens the wait. Name tags can be fished up or crafted diagonally from paper and an iron or gold nugget. Use an anvil to name an item stack for one XP level, then right-click a mob with a named tag. Named mobs display their label and retain it when saved.

**Trapdoors:** six classic wood families and iron support upper/lower placement, four orientations, redstone and climbing while open. Six matching planks craft two wooden trapdoors; four iron ingots craft one iron trapdoor. Wooden trapdoors also open by hand. See [trapdoor rules](docs/trapdoors-source.md).

**Boats:** place a boat, then right-click it to board. W/S row, A/D steer and Ctrl dismounts, leaving the boat in the world. Ordinary boats can carry an animal alongside you. Craft a chest above a boat for 27 cargo slots; Ctrl + right-click opens the cargo. Boats, cargo and passengers survive saves and unloading. See [boat rules](docs/boats-source.md).

**Totems:** carry a totem of undying in hand and it saves you from one lethal hit, leaving you at a single heart with regeneration, fire resistance and absorption. It is consumed in the process — except in creative — and it cannot save you from the void. See [totem rules](docs/totems-source.md).

**The void hurts by rate, not by blow:** below Y −128 you lose four health every half second, so a fall off the End's islands can sometimes be climbed out of. See [player damage](docs/player-damage-source.md).

**The wither:** build a three-wide T of soul sand and place a wither skeleton skull on each of its three top blocks to summon the wither. It rises untouchable for ten seconds, then turns armoured and arrow-proof below half health. Killing it always drops a nether star — the beacon's ingredient. Wither skeletons live in the Nether and drop the skulls you need for the ritual, though only rarely. See [wither rules](docs/wither-source.md).

**Beacons:** build a pyramid of iron, gold, diamond, emerald or netherite blocks beneath a beacon to power it — one layer gives power 1, four complete layers give power 4. Power sets both the effects available (swiftness and haste at 1, up to regeneration at 4) and the range, which is ten blocks per power level plus ten. See [beacon rules](docs/beacons-source.md).

**Banners:** emblazon banners with any of the 42 source patterns — 32 are crafted from a dye layout, and 10 special ones from paper plus an item such as a creeper head or an oxeye daisy. Apply a dye or pattern item to a placed banner to add a layer, up to six, or use one emblazoned banner on another to combine them. See [banner rules](docs/banners-source.md).

**Shields:** hold a shield with Ctrl held to block attacks from the front half of your view. Only mob, player, arrow, explosion, dragon-breath and trident hits are blocked — fire, void and starving still hurt. Hits of three or more damage wear the shield down. See [shield rules](docs/shields-source.md).

**Kelp:** plant kelp in water on dirt, sand, gravel or prismarine and it grows into a tall stalk over time. Cut any cell of its water away and the overgrown part breaks off and drops; digging a stalk yields one kelp per unit of its height. See [kelp rules](docs/kelp-source.md).

**Seagrass:** place seagrass in water on dirt, sand, gravel or prismarine and it takes root in that block. Only water that is a source counts, and only shears recover the plant — by hand you just get the block back. See [seagrass rules](docs/seagrass-source.md).

**Glow berries and cave vines:** hang cave vines from a ceiling — they are climbable, and you pass straight through them — and bone-meal the tip to grow **glow berries** — the lit vine gives off light 14, which is what lights a lush cave. Right-click a lit vine to pick a berry and the vine survives. Berries are edible. **Moss** now makes mossy cobblestone and mossy stone bricks. See [lush caves](docs/lush-caves-source.md).

**Powder snow:** some snow is not solid. Walk into powder snow and you sink in and start to freeze — the screen frosts over in three stages before it starts costing you health, and a bucket scoops it up. **Leather armour** stops the freeze completely, and powder snow puts out a burning mob. Mobs freeze too: seven seconds in slows one to a standstill, then it starts taking damage. See [powder snow](docs/powder-snow-source.md).

**Bamboo:** grows wild in warm regions in uneven groves, five to sixteen blocks tall with leafy tips — or plant a shoot on grass and it grows one segment at a time to a height of its own. It needs light, so it stops in caves, and established stalks come in two thicknesses. Two bamboo stack into a stick; six around a string make six scaffolding. See [bamboo](docs/bamboo-source.md).

**Ice spikes:** the frozen Frostpine plains are scattered with cones of packed ice — small stubs and tall spikes, all tapering to a point. They stand only on snow, and only in the cold. See [ice spikes](docs/ice-spikes-source.md).

**Dripstone caves:** stalactites hang from cave ceilings, stalagmites rise from the floor, and some meet in the middle as full columns. Dripstone blocks were already craftable — now they generate, so the caves have their own shape. **Water drips from wet ceilings and lava from molten ones**, with a quiet sound that carries in the dark; dig the block under a drip and it stops. See [dripstone formations](docs/dripstones-source.md).

**Soul lanterns and chains:** hang a lantern from a ceiling with a chain, or light a soul-themed build with a **soul lantern** — dimmer and teal, made with a soul torch instead of an ordinary one. See [soul lanterns and chains](docs/lanterns-source.md).

**Elder guardians:** an elder guardian within fifty blocks gives you **mining fatigue** on a timer, so mining through an ocean monument is slow work. Hit any guardian in melee and it deals two damage straight back. See [guardian auras](docs/guardian-auras-source.md).

**Woodland cabins and the totem of undying:** dark-oak halls in roofed forests, garrisoned by five vindicators, an evoker and a parrot. Kill the evoker and you get a **totem of undying, every time** — which saves you from a lethal hit. See [woodland cabins](docs/woodland-cabins-source.md).

**Ocean monuments:** big prismarine structures on the sea floor, guarded by five guardians and an elder. The elder drops the wet sponge, which is the only natural way to get sponges — and the prismarine walls are exactly what a conduit frame is built from. See [ocean monuments](docs/ocean-monuments-source.md).

**Witch huts and witches:** stilted swamp shacks with a cauldron, a witch and an all-black cat. Witches throw at range and **always drop redstone** in stacks of four to eight, so she is one of the few ways to get redstone above ground. See [witch huts](docs/witch-huts-source.md).

**Igloos:** a snow hut that hides a basement — but only half of them have one. Find the trapdoor, climb down past bricks that may hold silverfish, and you arrive at a brewing stand, a jukebox, and a villager locked in with a zombie villager. The chest always holds a golden apple. See [igloo rules](docs/igloos-source.md).

**Zombie villagers, both ways:** a zombie that kills a villager turns it into a zombie villager, and the villager it was is remembered — so curing it brings back *that* villager, same trades and all. Throw a weakness potion at one, then feed it a golden apple. It shakes for a few minutes and turns back. The apple does nothing without the weakness. See [zombie villagers](docs/zombie-villagers-source.md).

**Infested blocks:** some stone is not stone. An infested block looks exactly like the real thing, and breaking one without Silk Touch lets a silverfish out at you. Silk Touch gives you the plain block instead, so a trap can never be carried home. See [infested blocks](docs/monster-eggs-source.md).

**Pillager outposts:** wooden watchtowers guarded by a raiding party — five pillagers, three parrots and an iron golem. Climb the ladder for the chest: every outpost holds a crossbow. Parrots are new to the world too, and drop feathers. See [pillager outposts](docs/pillager-outposts-source.md).

**Jungle temples:** mossy-cobble temples with a hidden vault under the floor. The treasure inside is a trapped chest, so opening it fires the dispensers beside it — take the loot and run. See [jungle temple rules](docs/jungle-temples-source.md).

**Trapped chests:** craft a chest with iron, a stick and wood to get one that sends a redstone signal to everything beside it while it is open. Wire a lamp to one and you have an alarm; put one behind dispensers and you have a trap. See [trapped chests](docs/trapped-chests-source.md).

**Ruined portals:** broken Nether portal frames stand on the surface. Their obsidian frame is a source of the material you need to build your own portal, and the crying obsidian in it is what respawn anchors take. Loot the chest under the frame for gold tools, flint and steel and an enchanted golden apple. See [ruined portal rules](docs/ruined-portals-source.md).

**Magma blocks:** four magma cream make a hot block that **burns you when you stand on it**. Sneak, drink a fire resistance potion, or wear Frost Walker boots to cross safely — and a fire lit on magma burns forever. See [magma blocks](docs/magma-source.md).

**Fish and squid:** the ocean is alive — cod, salmon, pufferfish, tropical fish, squid and glow squid swim in the water, and each fish drops its own raw item when caught. Squid drop ink sacs, and a glow squid drops a glow ink sac. See [aquatic creatures](docs/aquatic-mobs-source.md).

**Your second hand:** you have a second hand as well as your main one. Put a shield or a totem there and it stays ready while you keep a weapon or a tool in your main hand — and unlike before, wearing a helmet no longer takes the shield's place. A torch held there lights up right-click placement when your main hand is busy. See [the second hand](docs/offhand-source.md).

**Desert temples:** sandstone pyramids hide a vault with a chest and a partly-disarmed TNT trap. Their floors are full of suspicious sand — brush it to find pottery sherds and other archaeology, which is the desert route to a decorated pot. See [desert temple rules](docs/desert-temples-source.md).

**Shipwrecks:** sunken hulls lie on the ocean floor, and each one buries a treasure chest under the sea bed nearby. That buried chest is where a second heart of the sea comes from, so a conduit can be built without hunting for buried treasure. See [shipwreck rules](docs/shipwrecks-source.md).

**Ocean ruins:** sunken ruins generate on sea floors. Cold ruins are gravel with suspicious gravel beneath them; warm ruins are sand, and carry the coral and sea pickles that make warm seas distinctive. Brushing the suspicious sand and gravel is how you find sherds and other archaeological loot. See [ocean ruin rules](docs/ocean-ruins-source.md).

**Guardians:** guardians prowl deep ocean water and attack with a charged laser rather than by touch, refusing to fire at anything inside three blocks. They drop prismarine shards and crystals — the conduit frame's material — and elder guardians always drop a wet sponge, which smelts into a dry one. See [guardian rules](docs/guardians-source.md).

**Sea pickles:** place a sea pickle on dead brain coral and it glows in water — brighter as it grows through four sizes. Stack a second pickle on it to grow it, or use bone meal to grow and spread it. Pickles only light up with water directly above them, and breaking one yields as many items as its size. See [sea pickle rules](docs/sea-pickles-source.md).

**Coral:** five species of coral — tube, brain, bubble, fire and horn — each in a block, a rooted plant and a fan, living and dead. Coral dies without water: a block needs water on any side, while a plant or fan needs it directly above. Plants and fans only sit on the matching species' block, and break into their dead form unless you use Silk Touch. See [coral rules](docs/corals-source.md).

**Ocean and buried treasure:** bury chests beneath beaches, found by digging down to stone — they always hold a heart of the sea alongside gems and prismarine crystals. Craft a conduit from eight nautilus shells around that heart, then build a frame of prismarine and sea lanterns around it in water to gain conduit power underwater. See [conduit rules](docs/conduits-source.md) and [buried treasure](docs/buried-treasure-source.md).

**Clocks and compasses:** craft a clock from four gold ingots and a compass from four iron, each around a redstone. The clock's face shows the time of day and the compass needle points to your world spawn; neither works in the Nether or the End, where both spin instead. See [dial rules](docs/dials-source.md).

**Scaffolding:** craft six scaffolding from a plank and string. Place it to build a climbable tower, sneak-click a side to add a horizontal arm, or look down steeply to extend a run of arms. Arms may only reach six blocks from a support; anything stranded drops as an item. See [scaffolding rules](docs/scaffolding-source.md).

**Rails and minecarts:** place rails on the ground and they connect automatically into straight pieces, curves, T-junctions, crossings and slopes. Powered rails speed carts up when redstone-powered and brake them otherwise; detector rails switch on under a cart and signal the block below; activator rails eject a driver and ignite TNT carts. Ride a minecart with right-click and push it with W/S. Chest carts hold 27 slots, furnace carts burn coal for 180 seconds, hopper carts pick up nearby drops, and TNT carts are lit with flint and steel. Carts and their cargo survive saves and unloading. See [rail and minecart rules](docs/rails-source.md).

**Mineshafts:** underground mineshafts generate as a large parlor room with corridors, junctions and descending staircases radiating from it. Corridors have timber arches, cobwebs and occasional rails; some corridors carry a chest minecart of mineshaft loot, others a cave-spider spawner. See [mineshaft rules](docs/mineshaft-source.md).

**Fireworks and heads:** craft firework rockets from paper and gunpowder to boost elytra flight — one, two or three gunpowder gives 2.2, 4.5 or 6 seconds of thrust along your look direction. Seven heads (zombie, creeper, human, skeleton, wither skeleton, piglin and dragon) place on the floor, a wall or the ceiling and all return the same item. A head drops only when a creeper charged by lightning kills the mob with its blast. See [firework rules](docs/fireworks-source.md) and [head rules](docs/heads-source.md).

**Maps:** use an empty map to capture a fixed 128×128 terrain survey. Copies and framed maps retain that same snapshot when the world changes. Cartography tables offer copy/view actions for each carried map. Survey generation runs in the background. See [map rules](docs/maps-source.md).

**Eggs and snow:** right-click to throw eggs or snowballs; block impacts sometimes hatch chicks, and snowballs hurt blazes. Shovel natural thin snow for snowballs, craft snow blocks from four balls, and craft six layers from three blocks. Place layers repeatedly to stack up to eight. Silk Touch preserves the layers; bright artificial light can melt single layers. See [throwing](docs/throwing-source.md) and [snow rules](docs/snow-cover-source.md).

**Farmland and crops:** nearby water hydrates tilled soil, which dries gradually when water is removed. Wet farmland speeds crop growth; bone meal advances growth stages. Wheat, carrots and potatoes have eight stages, while beetroot has four. Harvest and replant from the source drop tables. See [farmland](docs/farmland-source.md) and [crop rules](docs/crop-farming-source.md).

**Golems:** place a carved pumpkin or jack-o’-lantern last on two snow blocks or a T of four iron blocks. Repair damaged iron golems with ingots. Snow golems throw snowballs, leave trails, and can be sheared; protect them from water, rain and hot biomes. Their state persists through saves and unloading. See [source behavior](docs/golems-source.md).

**Pumpkins and melons:** plant their seeds on farmland. Mature stems grow fruit beside them and stay planted when you harvest it. Shear a pumpkin from the side to carve it and recover four seeds; craft a carved pumpkin over a torch for a jack-o’-lantern. Equip a carved pumpkin in the helmet slot to avoid provoking Endermen by looking at them. See [crop rules](docs/fruit-crops-source.md).

**Hives and honey:** find nests in oak/birch trees, or craft a hive with six planks and three honeycombs. Nearby flowers allow daytime honey production in dry weather. A full hive yields a bottle of honey or three combs with shears; put a lit campfire beneath it for safe harvesting. Honey bottles return their glass containers when eaten or crafted. Honey blocks cushion falls and join piston assemblies, while honey and slime do not stick to each other. See [hive and honey rules](docs/beehives-source.md).

**Amethyst and spyglasses:** underground geodes contain smooth basalt, calcite, amethyst and growing crystals. Mine mature clusters with a pickaxe for shards; Silk Touch preserves buds and clusters, but cannot recover budding amethyst. Four shards craft an amethyst block, or surround glass with four shards for two blocks of light-blocking tinted glass. Craft one shard above two copper ingots into a spyglass, then hold right-click or Z to zoom; touch players hold Use. See [amethyst](docs/amethyst-source.md) and [spyglass rules](docs/spyglass-source.md).

**Copper:** copper blocks, cut copper (with stairs and slabs), chiseled copper and open copper grates each weather through four stages: unaffected, exposed, weathered and oxidized. Oxidation advances slowly on its own — one stage per roll, and rolls are rare — and buried copper weathers just like exposed copper. Use honeycomb while sneaking, or craft a block with one honeycomb, to wax it and stop oxidation permanently; an axe scrapes the wax off, and a second use reverses exactly one oxidation stage. Copper bulbs light at 14, 12, 8 or 4 depending on stage and toggle on each rising redstone edge, remembering their lit state after power is removed. Craft a copper door or trapdoor from ingots; a lightning rod mounts on any solid face, attracts the first strike in range and pulses a strong signal for four redstone ticks. See [copper rules](docs/copper-source.md).

## Validation

Latest validation: **4,919 checks passed** across nine suites, with no failures or script errors. Rendered checks include `tests/farm_golem_tour.gd`, `tests/nature_tour.gd`, `tests/mechanism_tour.gd`, `tests/home_tour.gd` and `tests/travel_tour.gd`; all use isolated temporary saves. Source comparisons and remaining differences are tracked in the [parity ledger](docs/mineclonia-parity.md).

On Linux/macOS with Godot on `PATH`:

```sh
./tests/run_tests.sh
```

The runner creates an isolated temporary project so tests do not disturb an open editor/playtest. Direct cross-platform alternative:

```sh
godot --headless --path . --script res://tests/test_survival.gd
```

The suite exercises meshing and winding, negative coordinates, deterministic terrain, ore/tool progression, manual and guided crafting, inventory transactions, mining/placement, crack-overlay symmetry and growth, furnace and crop simulation, single and large chests, save recovery and armor persistence, separate worlds, platform home paths, armor protection and wear, falling nodes, explosions and TNT, creature AI (chasing, shooting, exploding, roaming, day/night spawning), water physics and line-of-sight, the modding API (registration, hooks, world/inventory access), touch controls and split/batch toggles, achievements, shears, buckets, the bow, the two-block bed, and console commands. Depth checks cover Q and Escape drops, negative-Y terrain/collision, underground saves, deepslate ore progression, and lava-bucket fuel. Nether checks cover portal frames and round trips, independent dimension saves, lava reactions, cave resources, XP/lapis transactions, bookshelf gaps, item metadata, book editing, and arrow pickup/expiry. Expansion checks cover redstone signal range, timed pulses, side locking, comparators, pistons, doors, machine inventory, strongholds, Nether fortresses, pearl impacts, the End boss, crystal destruction and saves, dragon respawning, gateways, shulkers, and elytra. Content checks also cover atlas coverage, item mesh winding, joint animation, shaped/shapeless recipes, container returns, sugar cane growth, egg laying, and item ids above 255 in saves.

A windowed visual smoke test writes screenshots of the crack overlay, creatures, armor inventory, large chest, console, and a dedicated asset gallery to `/tmp/voxey-shots`:

```sh
./tests/screenshots.sh
```

## Villages, alchemy and pouches

See [the village guide](docs/villages.md) for all 13 professions, leads, slimes and player homes, and [the alchemy guide](docs/alchemy.md) for brewing recipes, all enchantments, and colored pouches.

Pouches have five levels, sixteen colors, and 27–135 slots each. Equip up to three to extend the paginated inventory; additional carried pouches open with right click without adding pages. Craft a level-one pouch from four string in the 2×2 inventory grid, combine equal levels to upgrade, and recolor with wool or dye.

Death leaves two bones and a persistent recovery chest. Main inventory items, armor and pouch items go into the chest; inventory pages remain packed inside their pouches. The death screen gives the chest’s coordinates.

Offline play uses the fixed player identity `player`, with no player selector. Homes, villager reputation and recovery ownership use stable player keys so future multiplayer sessions can keep them separate. Previously selected local-profile homes and reputation migrate to `player`; other saved identities remain preserved.

## Mineclonia parity work

The [source-backed parity ledger](docs/mineclonia-parity.md) inventories 218 source modules. Full parity is not complete. The [world and Nether source comparison](docs/mineclonia-world-source.md) records implemented rules, tests and remaining differences, including ore generation and world limits.

**Netherite:** mine ancient debris with a diamond pickaxe, smelt it into scrap, and combine four scrap with four gold for an ingot. Find upgrade templates in bastion treasure (`/locate bastion`). A smithing table upgrades diamond gear with one ingot and one template while retaining enchantments and wear. Duplicate a template with seven diamonds and netherrack. Netherite drops survive lava and fire.

**Bastions and piglins:** blackstone bastions have three treasure levels, piglins and a brute. Gold armor keeps unprovoked piglins peaceful; brutes still attack. Use a gold ingot on a piglin to barter. After six seconds it drops one of eighteen source-weighted rewards. Bastion residents, deaths and barter progress persist. The complete source layouts and AI are still being ported.

**Sponges:** a sponge clears every water node in the 7x7x7 cubes around it in one pass, turning itself waterlogged. Use it beside a stream and it soaks up the stream as it lands; place a wet sponge in the Nether and it dries instantly. Smelt a wet sponge to dry it, and if an empty bucket sits in the furnace's fuel slot, the sponge's water fills it. See [sponge rules](docs/sponges-source.md).

**Pots, stands and archaeology:** craft a **flower pot** from three bricks and drop any flower, mushroom, cactus or sapling inside; breaking it returns the pot and the plant. Craft an **armor stand** from a stone slab and four sticks, dress it piece by piece, and punch it to turn it around. Craft a **decorated pot** from four sherds or bricks in a plus shape; each face keeps the pattern it was built with and turns with the pot. Brush **suspicious sand** and **gravel** to unearth their contents — the find is decided on the first stroke, and each completed block wears the brush a little. See [decoration rules](docs/decoration-source.md).

**Weather and lightning:** one weather state drives everything — sky, fire, cauldrons, farmland and Riptide. Clear, rain and thunder each last their own source duration, with a fresh roll on expiry. Rain extinguishes open-sky fire and snow accumulates in cold biomes; thunderstorms strike every few seconds, favouring the first lightning rod in range, which answers with a strong redstone pulse. Fire, creature damage and copper de-oxidation all follow from a strike. The moon cycles through eight phases. See [weather rules](docs/weather-source.md).

**Fire and navigation:** fire charges and flint and steel ignite blocks, portals and TNT. Water extinguishes fire; netherrack supports eternal flames. Use a compass on a lodestone to bind it, then use the compass to find that lodestone within its dimension. Bindings stay with the individual compass through inventory moves and saving.

**Stairs and slabs:** 60 material families provide 120 building items, with upper/lower slabs, double slabs, inverted stairs and automatic corners. Players walk up half-height steps, and targeting, mining and dropped models follow the actual shape. Natural tuff and eight additional masonry blocks support the deepslate/tuff crafting chains, and the four cut copper stages are shapes too. See [crafting and placement](docs/building-shapes.md).

The [eating, daylight and fluid-flow update](docs/environment-update.md) records the previous environment fixes. Feature parity work resumed on 2026-09-16; the [source comparison and work queue](docs/parity-next-audit.md) distinguish implemented systems from remaining gaps.


**Expanded survival systems:** [Hunger](docs/hunger-source.md) now tracks saturation and activity exhaustion, with food poisoning and golden-apple absorption. [Ender chests and shulker boxes](docs/storage-source.md) provide shared personal storage across dimensions and portable cargo with sixteen colors. [Composters](docs/composters-source.md) use source probabilities, maturation, comparator signals and hopper automation. [Cauldrons](docs/cauldrons-source.md) exchange water bottles, water buckets and lava buckets with visible fill levels. Exposed cauldrons collect rain — or powder snow where it is snowing; water extinguishes burning creatures and washes shulker dye while retaining cargo, and lava ignites creatures inside. Their source notes record remaining differences; full Mineclonia parity remains in progress.

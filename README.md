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
| Shift | Sprint; descend when flying |
| Ctrl | Sneak and avoid walking off edges; bypass station interaction |
| Hold left mouse | Progressively mine a node / attack |
| Right mouse | Place, interact, eat, till, plant, wear armor, or light TNT |
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

**Deeper worlds:** the Overworld now reaches bedrock at **Y −128**, matching Mineclonia’s documented lower limit. The old generated floor at Y 0 becomes mineable stone, while existing surface terrain and saved builds retain their coordinates. Deepslate takes over below Y −32, with larger caverns, deep ore variants, and lava below Y −112. The Nether now has a 128-block vertical range. Cave enemies can spawn underground during daylight; torches help keep them away. See [the depth and inventory guide](docs/depth-inventory.md).

**Survival progression:** gather oak logs, make planks and a table, then a wooden pickaxe. Mine stone for stone tools and a furnace. Stone picks harvest iron and copper; smelt ore with coal or wood. Iron picks harvest diamond and gold. Diamond tools are the strongest. Tools have durability; using the wrong tool is slower and may not yield a drop.

**Mining feel:** holding the mouse button grows a crack overlay from the exact centre of every face of the node, in nine symmetric stages, while chips fly off the struck face. Sand and gravel are falling nodes: remove their support and they drop as entities until they land.

**Armor:** leather, iron, golden, and diamond helmets, chestplates, leggings, and boots are crafted at a table with the classic patterns. Right-click a piece to wear it, or drop it into the armor column of the inventory screen (each slot accepts only its own piece; Shift-click a piece in your bag to equip it). Every point of defence absorbs 4% of damage, up to 80% for a full diamond set; pieces wear down with each hit and eventually break. Drowning, starving, and falling bypass armor. Worn armor is saved with the world and drops on death.

**Creatures:** sheep, cows, pigs, and chickens wander the surface by day; cows always drop 1–2 leather, chickens drop feathers. At night zombies, skeletons, spiders, and creepers spawn away from torchlight. Zombies groan and chase, skeletons keep their distance and shoot arrows, spiders leap and are neutral in daylight unless provoked, and creepers hiss, swell, and explode. Zombies and skeletons burn in sunlight. Craft shears to clip a sheep's coat for wool — it regrows as the sheep grazes — and milk cows with an empty bucket. Creature calls, hurt sounds, hisses, and blasts are synthesized at startup and played positionally. Hostiles drop rotten flesh, bones, string, and gunpowder.

**Nether, enchanting, and books:** build a 4×5 obsidian frame (2×3 opening; corners optional), light the inside with flint and steel, and stand in the portal for one second. The Nether has lava seas and falls, quartz ore, glowstone, five biomes, giant fungi, nether-brick fortresses with blaze spawners and loot, piglins, magma cubes, ghasts, and endermen. Travel scales horizontal coordinates by 8; each dimension keeps its own edits, storage, and pickups. Water evaporates there, and beds cannot set spawn.

Water touching lava from any of the six sides converts the lava source to obsidian. Deep caves now generate lava and lapis ore. Mine obsidian with a diamond pickaxe; buckets collect and place water or lava sources.

Craft an **enchanting table** from a book, two diamonds, and four obsidian. Right-click it, select equipment, and spend lapis plus XP levels. The HUD shows your current level and progress toward the next one. Bookshelves with a one-block air gap unlock stronger tiers. **Books** use three paper and one leather, in any arrangement; cows now always drop 1–2 leather. Combine a book, feather, and charcoal for a **writable book**. Right-click to write, close to keep a draft, or sign to make it read-only. Written text and enchantments stay attached through inventory moves, chests, drops, death, and saves. See [the Nether and enchanting guide](docs/nether-enchanting.md).

**Arrows and pickups:** skeletons wait until their bodies face their targets and fire forward from the bow. Grounded arrows from either side can be recovered and expire after ten active minutes; their age survives saving. Ground items are attracted only when the entire pickup fits in the inventory. Ordinary item drops still expire after five active minutes. Timers pause in menus and inactive dimensions.

**New content and artwork:** enemies now have original pixel skins, articulated limbs, and clearer faces: a ragged zombie, a skeleton with an open rib cage and bow, an eight-legged spider with fangs, and a mottled creeper. Inventory icons use the block atlas; items share pixel silhouettes across inventory, pickups, and the player’s hand. Sixteen additional items and blocks include sugar cane, red/brown mushrooms, vines, red bricks, hay bales, mossy stone, coal blocks, terracotta, charcoal, bowls, mushroom stew, metal nuggets, and eggs. See [the content guide](docs/content.md) for gathering and recipes.

**Luanti-style extras:** bones grind into bone meal that instantly ripens wheat or grows a sapling — or sprinkles wildflowers over grass. Four string weave into wool; gunpowder and sand make TNT, which is lit with a right-click, falls, flashes, and detonates after three seconds, chaining into nearby TNT. Explosions leave craters, drop some of the destroyed nodes, and hurt anything close. Dropped nodes and the held node are miniature copies of the real textured node. Gravel sometimes yields flint; chickens drop feathers; flint, sticks, and feathers become a bow and arrows. Compasses point the way home, clocks read the day and hour, iron/gold/diamond form storage blocks (and revert), and glowstone lights the night.

**Achievements:** sixteen moments of pride — from *Timber!* (first log) through *The Iron Age*, *Barber* (shear a sheep), *Milkmaid* (milk a cow), *Spelunker* (dive below Y 8), to *Survivor* (five days alive). Progression awards fire in survival mode only, pay experience, and persist in the world save. Browse them from the pause menu under **Achievements**. The game version shows on the title screen and pause menu.

**Water:** swimming replaces the sink-or-die crawl. Water slows you and lets you drift gently; hold Space to stroke upward, with extra thrust while your head is submerged, and a kick that vaults you onto the shore when you surface facing open air. Hostile creatures cannot see through walls: their aggro checks voxel line-of-sight, and they keep hunting briefly after losing sight before giving up.

**Mobile:** Voxey runs on Android, iOS, and other touch devices. Phones get on-screen controls — a floating joystick (touch the lower-left of the screen), jump, sneak, mine (hold), use, and in Creative a fly button — plus tappable hotbar slots, a pause/chat/drop row up top, and a drag-anywhere camera. The inventory adds **Split mode** and **Batch mode** toggles in place of right-click and Shift. Panels shrink to fit small and rotated screens; `window/handheld/orientation` follows the device. Export presets for Linux, Android, and iOS ship in `export_presets.cfg`.

**Mods:** drop a folder into `mods/` (or `~/.voxey/mods/`) with a `mod.json` manifest and an entry script, and it receives the sandboxed `VoxeyAPI`: register new nodes and items, read and change the world, give or take inventory items, and subscribe to gameplay hooks (`on_node_broken`, `on_player_hurt`, …). A broken mod is skipped with a logged error; it never blocks the game. See `docs/modding/` for the full guide, API reference, and worked examples. `mods/survival_tweaks/` ships as a live example.

**Food and shelter:** eat apples, cook meat, or till dirt with a hoe and plant seeds. Wheat matures after 90 active world seconds; three wheat make bread. Sheep also provide wool for beds. The bed is a proper two-node bed — the recipe lays a foot and a head half in the direction you face, each rendered as a half-height mattress with a pillow end; right-click either half to set spawn and sleep at night when no hostile creature is nearby, and breaking either half removes the whole bed and drops one item. Old saves with the single-node bed load as the new foot half. Saplings grow in 120 seconds. Torches illuminate the surroundings and prevent nearby hostile spawns. Death leaves recoverable item drops, which expire after five active minutes.

**Storage chests:** a chest (8 planks at a table) holds 27 stacks; right-click to open, Shift-click to move stacks in or out. Place a second chest directly beside one and they join into a single large chest with 54 slots that keeps everything already inside. A chest never joins more than one neighbour, and breaking one half drops that half's items while the other half keeps its own 27. Contents drop when a chest is broken and are saved with the world.

**Creative:** all items are available through the inventory's **All items** tab. Placement is unlimited, mining is fast, tools don't wear out, and survival damage is disabled. Flight still respects solid terrain. Switching modes keeps the same world and inventory.

## Console

```text
/gamemode survival
/gamemode creative
/time day
/time night
/give <item> [count]      e.g. /give diamond_pickaxe, /give iron_ingot 16
/spawn <creature>         sheep cow pig chicken zombie skeleton spider creeper piglin magma_cube
/tp <x> <y> <z>
/dimension overworld | nether
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

Saves are version 2 (version 1 files still load; the old single chestplate becomes an iron chestplate in the armor slots). Saves use a temporary file, flush, backup, and rename. An invalid primary save falls back to the backup. Autosave runs every 45 seconds during play; F5, leaving to title, and closing the window also save. Old `user://voxey_world.json` saves are imported as **My first world**, retaining the original file. Terrain is regenerated from the seed; modified nodes, growing crops, furnace contents/progress, chests, drops and their ages, grounded arrows, both dimensions, written book contents, enchanted equipment, and crafting ingredients are persisted.

`VOXEY_DATA_DIR` can override the storage root for portable installations and isolated tests. Sandboxed platforms without a home environment use their writable application directory. The desktop code is portable; this build has been run on Linux. Windows and macOS home-path selection is covered by tests, but native builds on those systems have not been exercised.

**Redstone and the End:** mine redstone to craft dust, torches, levers, buttons, plates, repeaters, comparators, observers, lamps, pistons, sticky pistons, doors, dispensers, droppers, and hoppers. Defeat blazes for rods and endermen for pearls, craft Eyes of Ender, and follow them to a stronghold. Fill twelve portal frames to enter the End. Destroy tower crystals and defeat the dragon for XP, an egg, and portals to home and the outer islands. Explore shulker-guarded cities for elytra. See [the redstone and End guide](docs/redstone-end.md) for controls, recipes, saving, and the encounter.

## World and rendering

Voxels are **nodes**. Each **map block** contains 16×16×16 nodes in a compact byte array. The world streams horizontally around the player. The Overworld covers Y −128 through 63 (192 blocks); the Nether and End cover Y 0 through 127 (128 blocks). The End has islands over an open void; the other dimensions have bedrock boundaries. Existing positive-Y terrain coordinates are preserved.

- Worker-thread terrain generation and mesh construction with deterministic noise, caves, ore clusters, cross-boundary trees, meadows, shores, desert, and snow biomes.
- Greedy meshing merges coplanar faces; neighboring nodes and a one-node halo eliminate internal and map-block-boundary faces. One opaque/cutout surface and one water surface per map block, with a shared repeating texture atlas.
- Only affected map blocks and their boundary neighbors are remeshed after edits. Distant map blocks unload; edits persist.
- Voxel DDA targeting and swept/substepped voxel AABB movement avoid per-node scene objects and expensive collision-mesh rebuilding.
- Nine crack stages use a full UV square on each face. The crack texture is drawn in one sector and stamped with four-fold rotational symmetry about the exact face centre, so every stage grows evenly outward; forks and web rings appear in later stages.
- Day/night lighting, fog, voxel clouds, positional torch lights, generated 2D and positional 3D sound effects, textured pickups, falling nodes, mining debris, and explosion craters.

Voxey includes three dimensions, redstone simulation, and a persistent End dragon encounter. It is an original adaptation rather than full Mineclonia parity: multiplayer, fluid-flow simulation, brewing, the Wither, bastions, and the complete mob/content roster are not implemented. Ordinary roaming mobs respawn between sessions; the dragon encounter and defeated city guards persist. Recipes use a fixed registry and vertical ranges are bounded. Assets and game code are original; no Minecraft or Mineclonia assets are bundled.

## Validation

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

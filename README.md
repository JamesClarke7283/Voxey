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
| Space | Jump / swim upward |
| Shift | Sprint; descend when flying |
| Ctrl | Sneak and avoid walking off edges; bypass station interaction |
| Hold left mouse | Progressively mine a node / attack |
| Right mouse | Place, interact, eat, till, plant, wear armor, or light TNT |
| E | Inventory, crafting grid, and searchable recipe guide |
| 1–9 / mouse wheel | Select hotbar slot |
| Q | Drop held item |
| F / double Space | Toggle Creative flight |
| Middle mouse | Pick targeted node in Creative |
| `/` or T | Open console |
| Esc | Pause / close screen |
| F3 | Performance and map-block information |
| F5 | Save world |
| F11 | Toggle fullscreen |

**Crafting:** place items in the 2×2 inventory grid, or right-click a placed crafting table for a 3×3 grid. Patterns can be moved within the grid; asymmetric tools also accept mirrored patterns. Click the output to take it. The recipe guide shows ingredients and a reference pattern; **Fill grid** transfers the required items into the real grid. Shift-fill prepares a batch, and Shift-clicking output crafts into the inventory. Right-click splits a stack or places one item. Unused grid/cursor items return when closing; overflow becomes a pickup.

**Survival progression:** gather oak logs, make planks and a table, then a wooden pickaxe. Mine stone for stone tools and a furnace. Stone picks harvest iron and copper; smelt ore with coal or wood. Iron picks harvest diamond and gold. Diamond tools are the strongest. Tools have durability; using the wrong tool is slower and may not yield a drop.

**Mining feel:** holding the mouse button grows a crack overlay from the exact centre of every face of the node, in nine symmetric stages, while chips fly off the struck face. Sand and gravel are falling nodes: remove their support and they drop as entities until they land.

**Armor:** leather, iron, golden, and diamond helmets, chestplates, leggings, and boots are crafted at a table with the classic patterns. Right-click a piece to wear it, or drop it into the armor column of the inventory screen (each slot accepts only its own piece; Shift-click a piece in your bag to equip it). Every point of defence absorbs 4% of damage, up to 80% for a full diamond set; pieces wear down with each hit and eventually break. Drowning, starving, and falling bypass armor. Worn armor is saved with the world and drops on death.

**Creatures:** sheep, cows, pigs, and chickens wander the surface by day; cows also drop leather, chickens drop feathers. At night zombies, skeletons, spiders, and creepers spawn away from torchlight. Zombies groan and chase, skeletons keep their distance and shoot arrows, spiders leap and are neutral in daylight unless provoked, and creepers hiss, swell, and explode. Zombies and skeletons burn in sunlight. Craft shears to clip a sheep's coat for wool — it regrows as the sheep grazes — and milk cows with an empty bucket. Creature calls, hurt sounds, hisses, and blasts are synthesized at startup and played positionally. Hostiles drop rotten flesh, bones, string, and gunpowder.

**Luanti-style extras:** bones grind into bone meal that instantly ripens wheat or grows a sapling — or sprinkles wildflowers over grass. Four string weave into wool; gunpowder and sand make TNT, which is lit with a right-click, falls, flashes, and detonates after three seconds, chaining into nearby TNT. Explosions leave craters, drop some of the destroyed nodes, and hurt anything close. Dropped nodes and the held node are miniature copies of the real textured node. Gravel sometimes yields flint; chickens drop feathers; flint, sticks, and feathers become a bow and arrows. Compasses point the way home, clocks read the day and hour, iron/gold/diamond form storage blocks (and revert), and glowstone lights the night.

**Achievements:** sixteen moments of pride — from *Timber!* (first log) through *The Iron Age*, *Barber* (shear a sheep), *Milkmaid* (milk a cow), *Spelunker* (dive below Y 8), to *Survivor* (five days alive). Progression awards fire in survival mode only, pay experience, and persist in the world save. Browse them from the pause menu under **Achievements**. The game version shows on the title screen and pause menu.

**Water:** swimming replaces the sink-or-die crawl. Water slows you and lets you drift gently; hold Space to stroke upward, with extra thrust while your head is submerged, and a kick that vaults you onto the shore when you surface facing open air. Hostile creatures cannot see through walls: their aggro checks voxel line-of-sight, and they keep hunting briefly after losing sight before giving up.

**Mobile:** Voxey runs on Android, iOS, and other touch devices. Phones get on-screen controls — a floating joystick (touch the lower-left of the screen), jump, sneak, mine (hold), use, and in Creative a fly button — plus tappable hotbar slots, a pause/chat/drop row up top, and a drag-anywhere camera. The inventory adds **Split mode** and **Batch mode** toggles in place of right-click and Shift. Panels shrink to fit small and rotated screens; `window/handheld/orientation` follows the device. Export presets for Linux, Android, and iOS ship in `export_presets.cfg`.

**Mods:** drop a folder into `mods/` (or `~/.voxey/mods/`) with a `mod.json` manifest and an entry script, and it receives the sandboxed `VoxeyAPI`: register new nodes and items, read and change the world, give or take inventory items, and subscribe to gameplay hooks (`on_node_broken`, `on_player_hurt`, …). A broken mod is skipped with a logged error; it never blocks the game. See `docs/modding/` for the full guide, API reference, and worked examples. `mods/survival_tweaks/` ships as a live example.

**Food and shelter:** eat apples, cook meat, or till dirt with a hoe and plant seeds. Wheat matures after 90 active world seconds; three wheat make bread. Sheep also provide wool for beds. Right-click a bed to set spawn and sleep at night when no hostile creature is nearby. Saplings grow in 120 seconds. Torches illuminate the surroundings and prevent nearby hostile spawns. Death leaves recoverable item drops, which expire after five active minutes.

**Storage chests:** a chest (8 planks at a table) holds 27 stacks; right-click to open, Shift-click to move stacks in or out. Place a second chest directly beside one and they join into a single large chest with 54 slots that keeps everything already inside. A chest never joins more than one neighbour, and breaking one half drops that half's items while the other half keeps its own 27. Contents drop when a chest is broken and are saved with the world.

**Creative:** all items are available through the inventory's **All items** tab. Placement is unlimited, mining is fast, tools don't wear out, and survival damage is disabled. Flight still respects solid terrain. Switching modes keeps the same world and inventory.

## Console

```text
/gamemode survival
/gamemode creative
/time day
/time night
/give <item> [count]      e.g. /give diamond_pickaxe, /give iron_ingot 16
/spawn <creature>         sheep cow pig chicken zombie skeleton spider creeper
/tp <x> <y> <z>
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

Saves are version 2 (version 1 files still load; the old single chestplate becomes an iron chestplate in the armor slots). Saves use a temporary file, flush, backup, and rename. An invalid primary save falls back to the backup. Autosave runs every 45 seconds during play; F5, leaving to title, and closing the window also save. Old `user://voxey_world.json` saves are imported as **My first world**, retaining the original file. Terrain is regenerated from the seed; modified nodes, growing crops, furnace contents/progress, chests, drops, and crafting ingredients are persisted.

`VOXEY_DATA_DIR` can override the storage root for portable installations and isolated tests. Sandboxed platforms without a home environment use their writable application directory. The desktop code is portable; this build has been run on Linux. Windows and macOS home-path selection is covered by tests, but native builds on those systems have not been exercised.

## World and rendering

Voxels are **nodes**. Each **map block** contains 16×16×16 nodes in a compact byte array. The world streams horizontally around the player and is currently 64 nodes tall, with a bedrock floor.

- Worker-thread terrain generation and mesh construction with deterministic noise, caves, ore clusters, cross-boundary trees, meadows, shores, desert, and snow biomes.
- Greedy meshing merges coplanar faces; neighboring nodes and a one-node halo eliminate internal and map-block-boundary faces. One opaque/cutout surface and one water surface per map block, with a shared repeating texture atlas.
- Only affected map blocks and their boundary neighbors are remeshed after edits. Distant map blocks unload; edits persist.
- Voxel DDA targeting and swept/substepped voxel AABB movement avoid per-node scene objects and expensive collision-mesh rebuilding.
- Nine crack stages use a full UV square on each face. The crack texture is drawn in one sector and stamped with four-fold rotational symmetry about the exact face centre, so every stage grows evenly outward; forks and web rings appear in later stages.
- Day/night lighting, fog, voxel clouds, positional torch lights, generated 2D and positional 3D sound effects, textured pickups, falling nodes, mining debris, and explosion craters.

This is a playable foundation, not full Mineclonia parity. It currently has no multiplayer, Nether/End, redstone simulation, enchantments, fluid-flow simulation, bows for the player, or the full Mineclonia mob/content roster. Water is static, creatures are not persisted between sessions, recipes use a fixed registry, and the vertical range is bounded. Assets and game code are original; no Minecraft or Mineclonia assets are bundled.

## Validation

On Linux/macOS with Godot on `PATH`:

```sh
./tests/run_tests.sh
```

The runner creates an isolated temporary project so tests do not disturb an open editor/playtest. Direct cross-platform alternative:

```sh
godot --headless --path . --script res://tests/test_survival.gd
```

The suite exercises meshing and winding, negative coordinates, deterministic terrain, ore/tool progression, manual and guided crafting, inventory transactions, mining/placement, crack-overlay symmetry and growth, furnace and crop simulation, single and large chests, save recovery and armor persistence, separate worlds, platform home paths, armor protection and wear, falling nodes, explosions and TNT, creature AI (chasing, shooting, exploding, roaming, day/night spawning), water physics and line-of-sight, the modding API (registration, hooks, world/inventory access), touch controls and split/batch toggles, achievements, shears, buckets, the bow, and console commands.

A windowed visual smoke test writes screenshots of the crack overlay, creatures, armor inventory, large chest, and console to `/tmp/voxey-shots`:

```sh
./tests/screenshots.sh
```

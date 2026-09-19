# Clocks and compasses

Voxey follows the dynamic-dial half of the supplied Mineclonia `mods/ITEMS/mcl_clock` and `mods/ITEMS/mcl_compass`. The implementation is original GDScript using the source as a behaviour reference; no source code or texture is copied.

## Both items are moving dials

Neither item does anything when used. Their whole design is that the icon moves:

| Item | Frames | What the dial shows |
|---|---|---|
| Clock | 64 | The sun/moon disc at the current time of day |
| Compass | 32 | A needle pointing at the world spawn |

The clock uses `round(64 * timeofday)` as its frame, which is the source's own expression — so noon lands in the middle of the frame table and midnight at frame zero. The source additionally maps frame 0 to `(0 + 64/2 - 1) % 64` when naming its images, which is why the dial reads half a turn round from frame ordering alone.

## They do not work everywhere

`mcl_worlds.compass_works` gates both — the clock aliases it directly. A compass or clock **does not work in the Nether or the End**, and in the void it works only within the overworld's own vertical range. When a dial cannot read the world it **spins** instead of pointing, which is the source's visible "this is not measuring anything" signal. The spin advances on the source's own 0.1 second tick rather than per frame.

## Recipes

Both are crafted with a four-way ring around a redstone:

- **Clock** — four gold ingots around one redstone.
- **Compass** — four iron ingots around one redstone.

These recipes were absent from Voxey before this work, even though both items existed; they are now registered from the source's own shapes.

## Recorded source gaps

- **The dial is drawn as a 16×16 pixel icon, not a 64-frame texture set.** The reference ships 64 clock and 32 compass texture files; Voxey draws each frame procedurally from the same original pixel-sprite system every other item uses. The frame count, the frame-to-time mapping and the spin behaviour are identical; only the source of the pixels differs.
- The source writes the current frame into each stack's item metadata (`inventory_image` / `wield_image`) and updates it per player per globalstep. Voxey's icon cache keys on the frame instead, which reaches the same visible result without writing per-stack metadata.
- The source's `mcl_serverplayer` entity-step path, which re-sends the wield item to clients every five seconds, has no equivalent in a single-process engine.
- The recovery compass and the several `clock_<n>` legacy aliases are not registered; Voxey has no death-recovery compass system and no legacy clock nodes to migrate.

# Ice spikes

Voxey follows the supplied Mineclonia ice-spike registrations in `mods/MAPGEN/mcl_structures/init.lua` and their decorations in `mods/MAPGEN/mcl_biomes/init.lua`. The implementation is original GDScript using the source as a behaviour reference.

## Why it mattered

An ice spike is a cone of packed ice rising out of snowy ground, and a **spike field is what makes a frozen plain a landmark** rather than a flat white expanse. The source places them as biome decorations restricted to one biome.

Voxey has a cold biome — `Frostpine highlands` — but **nothing decorated it**, so its snowy plains were featureless.

## What the source does

The source registers **two sizes**, each with its own noise field and placement rule:

| Size | Height | Base radius |
|---|---|---|
| Small | 3–6 | 1 |
| Large | 8–14 | 2 |

Both require **snow beneath them** (`snowblock`, `snow` or snowy grass), so a spike never grows out of bare stone, and both rotate randomly.

## The shape is a cone, and that is asserted

A spike's width tapers with height, so it comes to a point rather than being a pillar. Three properties are checked, because each is what the shape actually is:

- The **base is the full width** and the **tip is a single block**.
- The width **only narrows** as it rises — a broken taper would grow outward instead.
- The spike is **contiguous** from base to tip, so there is no gap in it.

The tip being a single block is not free: a radius of one still fills a plus-shaped five cells, because the circular test admits the four orthogonal neighbours. The top level therefore admits only its centre, and a test asserts `top_cells == 1` so that cannot regress.

## Placement is restricted to the spike biome

The source decorates one biome. The test asserts both directions:

- **Spikes generate in the cold biome**, and plentifully — more than one block per column, since the whole biome is decorated.
- **No spike grows outside it.** A warm region is sampled and must contain none, because a spike in a desert would be out of place.

## A note on how this was built

The first version read the generation halo's arrays directly and hand-computed indices. That is what the other structure overlays do, and for a *whole-column* pass it is the wrong tool: the halo's y convention differs from the world's by one, and the mismatch meant every snow surface read as the deepslate beneath it — so **no spike ever generated, silently**.

The fix uses `Dungeons.natural`, which computes a column's natural surface analytically and is the API every other structure already uses for exactly this question. That removed the index arithmetic entirely, and the measured result went from zero to **8,686 spike blocks across 100 cold columns**.

## Recorded source gaps

- **Generated, not loaded from schematics.** The source ships two `.mts` files with fixed spike shapes. Voxey has no schematic loader, so a spike is built from its taper formula. The sizes, the taper, the snowy-ground requirement and the biome restriction are the source's behaviour; the exact block layout is not.
- **No noise-field placement.** The source uses two specific noise fields (`offset 0.005, scale 0.001`, seed 1133) to decide where spikes cluster. Voxey uses a per-cell probability inside the biome, which scatters them without the source's large-scale clustering.
- **No rotation.** The source rotates each spike randomly. A cone of revolution is rotationally symmetric, so there is nothing to rotate, but a schematic-shaped spike would differ.
- **No `IcePlainsSpikes` biome.** The source has a dedicated spike biome. Voxey's `Frostpine highlands` is the nearest equivalent and is what the spikes decorate.

# Renewable grazing pasture

Reference: `/home/impulse/.minetest/games/mineclonia/mods/ITEMS/mcl_core/functions.lua`, inspected 2026-09-16. This installed copy has no Git metadata. Reference license: `docs/licenses/Mineclonia-GPL-3.0.txt`.

`scripts/pasture.gd` ports the source grass spread and grass decay rules into loaded-world simulation:

- Exposed dirt receives a spread attempt every 30 seconds with a 1-in-20 chance. Its immediately upper block must be neither opaque nor liquid.
- A grass source is chosen from the source 3×5×3 search volume: one block either way horizontally, one below to three above the dirt. The target needs light level 4 or more; the chosen source needs level 9 or more above it.
- Grass covered directly by an opaque block or liquid receives a decay attempt every eight seconds with a 1-in-50 chance. Night alone does not destroy grass.
- Unloaded time is not caught up. Clocks, RNG and work queues reset when the world is configured; changed grass/dirt persists through the ordinary world-edit save records.

This closes the [sheep grazing loop](farming-source.md): sheep consume grass into dirt, neighboring grass can grow back into that dirt, and later grazing restores wool again. Pens should retain a nearby grass source. Voxey's swamp grass participates in the same rules, with new grass selecting the biome's existing grass variant.

Voxey does not store Mineclonia's complete node-light field. The implementation shares `RedstoneSensors.natural_light` for a bounded skylight reconstruction, including transparent columns, shade and filtering. Nearby torches and common emitting blocks contribute attenuated block light along transparent voxel paths; opaque barriers block it, while light may travel around corners. Existing crying obsidian, Nether/End portals, burning furnaces/smokers/blast furnaces and lava-filled cauldrons also contribute their source light levels. Circuit, furnace burn and cauldron contents are sampled live, including changes that do not replace a node. These source levels are defined in `mcl_core/nodes_base.lua`, `mcl_portals/portal_nether.lua`, `mcl_portals/portal_end.lua`, `mcl_furnaces/init.lua` and `mcl_cauldrons/init.lua`. This supports illuminated indoor/nighttime pasture without claiming a complete port of Luanti's lighting engine. Node transparency follows Voxey's existing block geometry categories.

TerrainGenerator collects exposed dirt, grass and light candidates during its existing worker scan. The main thread indexes those candidates and reconciles subsequent edits instead of rescanning every voxel. Light sources are indexed by map block, so a small pasture query does not inspect every lava node in the loaded world. Each timed candidate scan continues across frames, visiting at most 256 positions or spending about 1.5 ms per update; spread/decay jobs share a soft 3 ms budget and run at most four per update. A single light query may exceed that soft budget. Column-specific membership indexes make unloading proportional to the departing column, and loading rebuilds indexes without duplicating state.

A 40-second rendered streaming regression at radius four crossed 240 blocks after these scheduling and unload fixes: 2,401 frames, median 16.666 ms, 95th percentile 17.06 ms and maximum 19.594 ms, with no frames over 33 ms. The original full-index unload scans produced approximately 250 ms boundary stalls. Timings are local measurements, not platform-independent guarantees.

Remaining scope: source mycelium spreading and snow-covered grass variants are not represented here. Sheep tallgrass/fern/dry-grass consumption and a configurable mob-griefing rule remain separate work; grass-block grazing is implemented. Natural and artificial lighting use Voxey adapters described above.

`tests/pasture_checks.gd` verifies source search bounds, no spontaneous isolated grass, light and cover rules, torch-lit spread, cover decay, transparent covers, source intervals/chances, no time catch-up, index unload/reload, bounded candidate scans that finish all work, opaque-light obstruction, broad roof shade, actual disk save/load and clearing stale runtime state. It reports column indexing and lighting timings to catch expensive changes. `tests/light_emission_checks.gd` checks the existing emitting blocks and live station/circuit transitions.

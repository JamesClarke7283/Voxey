# Trail ruins and archaeology loot

Reference: the local Mineclonia checkout at
`/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-24.
This implements the trail-ruin acquisition route; whole-game parity remains active.

## Source data and generation

`tools/export_trail_ruins.py` reads all 14 saved templates from
`mods/MAPGEN/mcl_levelgen/templates/trail_ruins_*.dat` and the seven pools in
`mcl_levelgen/trail_ruins.lua`. It reuses the data-only decoder from
`tools/export_trial_templates.py`. JSON retains voxel states, jigsaw metadata,
source hashes, processor assignments and the source's empty grouped-room pool.
No source code executes in the game. Data licensing is GPL-3.0-or-later; see
[the retained license](licenses/Mineclonia-GPL-3.0.txt). All artwork is original.

`scripts/trail_ruins.gd` joins the original tower, top, halls, rooms, roads and
decorations by their named connectors. Placement uses 34-chunk spacing,
8-chunk separation, the source salt 83469867, a seven-level expansion limit and
an 80-block horizontal range. Towers begin fifteen blocks below the surface.
`/locate trail_ruins` finds an eligible site in the Overworld.

The source asks for jungle, old-growth birch and several taiga biomes. Voxey uses
its existing jungle, birch and spruce distribution as their counterparts. Source
room voxels are embedded in the existing terrain. The source's continuous density
`bury` modifier is not reproduced; terrain, biome distribution and RNG therefore
remain engine adaptations, and source seeds do not reproduce the same world.
The source's template flag excluding the top from terrain adaptation is retained
in the exported data. Native assembly also has a 160-piece safety bound.

## Archaeology processors

Each house/decor piece selects up to six common and three rare gravel cells.
Road pieces select two common cells; the top selects two common cells and does
not erode. Selection is shuffled before erosion, as in the source. Erosion turns
ordinary gravel into dirt on a 20% roll, then coarse dirt on a second 10% roll if
the first failed; mud bricks become packed mud on a 10% roll. Selected cells become
suspicious gravel with a saved loot type and seed.

Some source templates already contain suspicious gravel without metadata. Those
cells remain untagged and have no reward. They do not receive an invented loot
pool. Excavated cells and user edits override regenerated templates; metadata is
installed only in the owning column and never overwrites existing saved state.

## Source loot tables

`assets/data/archaeology_loot.json` exports the current `mcl_sus_nodes/init.lua`
tables. It replaces duplicated entries in the previous hand-copied ocean tables.

| Table | Entries | Total weight |
| --- | ---: | ---: |
| Trail common | 26 | 37 |
| Trail rare | 8 | 8 |
| Desert temple | 8 | 8 |
| Cold ocean ruin | 10 | 15 |
| Warm ocean ruin | 9 | 14 |

All exported entries resolve to items. The common table includes the source's
single candle entry with a random red, green, purple or brown candle. The rare
table contains Burn, Danger, Friend, Heart, Heartbreak, Howl and Sheaf sherds plus
the Wayfinder armor trim. Commented-out trims, Relic disc and leads are excluded,
as they are in the reference. Arms Up and Brewer now have their natural
[desert-well route](desert-wells-source.md); Flow, Guster and Scrape already come from trial chambers.

The source has no generic reward for untyped suspicious nodes, so neither does
Voxey. Each generated node's seed fixes its first reveal and any later reveal.
Leaving a reveal unattended for five loaded seconds hides it and resets its
visible stage. Saves retain the chosen reward and progress; completion changes
the block to plain gravel and emits the reward once.

## Supporting materials

Coarse dirt and dead bushes are registered as actual content (13600 and 13601).
Two dirt and two gravel in either checkerboard orientation produce four coarse
dirt. A hoe first makes dirt, then farmland on a second use; a shovel makes a
path. Water bottles turn coarse dirt to mud. It supports trees, bamboo and flowers
and does not gain grass through the grass-spread path.

Dead bushes are non-walkable, use the source's low selection box and burn for five
seconds. Ordinary harvest or support loss rolls zero, one or two sticks in the
source's ordered 1-in-3 then 1-in-2 trials. Shears recover the plant for planting
or a flowerpot. Pistons destroy it instead of moving it.

## Verification

`tests/trail_template_checks.gd` verifies all templates and palette entries,
source limits, connector expansion, non-overlap, processor selection counts,
unchanged untagged nodes, determinism, bounded caches and neighboring chunk halos.
`tests/trail_checks.gd` covers exact table counts/weights, every rare reward, candle
variants, supporting materials, natural generation, real brushing, reveal timeout,
saved metadata, actual disk reload and prevention of duplicate rewards.
`tests/trail_tour.gd` renders the assembled source geometry for inspection.

Validation for this batch: 94 trail/piston gameplay checks passed, plus 693
related archaeology, temple, ocean-ruin, trial, bamboo and farmland regressions.
Template checks passed both in the working project and from a Linux resource
pack. Both new JSON exports reproduced byte-for-byte, and the existing trial
export stayed byte-identical after sharing its decoder. Editor import passed.
The assembled room preview was rendered and inspected.

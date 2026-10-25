# Desert wells

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-24.
The implementation follows the active `mcl_levelgen` feature in
`mods/MAPGEN/mcl_levelgen/default_features.lua`, plus the dedicated well loot
in `mods/ITEMS/mcl_sus_nodes/init.lua`. The older MTS-based registration in
`mcl_structures/init.lua` has different placement and archaeology rules; it is
not substituted for the active generator.

## Generation

A feature attempt uses the source's 1-in-1,000 rarity and an in-square position
within a 16×16 column. Voxey's Sunwash desert is the existing biome counterpart.
The builder descends to solid ground, checks the 5×5 foundation two layers deep,
and rejects air in either lower layer or an existing sandstone slab. Air at the
surface layer is permitted by the source check.

The 112 written cells form a sandstone foundation, a five-cell cross of water,
sand immediately underneath, a rim with four slab entrances, four pillars and
a slab roof with a solid centre. Two independently selected cardinal positions
become suspicious sand: one a block below ground and one two blocks below.
They may share an X/Z column but always occupy distinct depths. Both receive
separate saved loot seeds.

World edits override generation, and metadata is installed only in the owning
column. Existing metadata and excavated cells are preserved. Larger structure
overlays take precedence over a well, including their archaeology ownership.
`/locate desert_well` searches nearby eligible feature positions.

Geometry matches the actual Lua builder for all sixteen direction pairs.
`tools/export_desert_well.py` runs only the extracted feature in a restricted,
data-only environment, with explicit world/RNG stubs, to create
`assets/data/desert_well_reference.json`. The game uses native GDScript and does
not execute Lua. Source hashes and GPL-3.0-or-later attribution are retained;
see [the license](licenses/Mineclonia-GPL-3.0.txt). Artwork remains original.

The biome map, terrain sampling and random-number generator remain Voxey's.
Consequently the same world seed does not reproduce Luanti's well coordinates.
The feature shares the project's existing generated-column and edit lifecycle.

## Archaeology and food

The six-entry well table has total weight eight:

| Item | Weight |
| --- | ---: |
| Arms Up pottery sherd | 2 |
| Brewer pottery sherd | 2 |
| Brick | 1 |
| Emerald | 1 |
| Stick | 1 |
| Suspicious stew | 1 |

Every result has count one. The table is exported from the source alongside the
other archaeology tables. This provides the final two sherd acquisition routes:
all 23 registered sherds now have their source structure or vault route.

The stew is the plain stack emitted by the source table: it has no flower-effect
metadata. It restores six hunger and 7.2 saturation, is edible while full, and
returns a bowl without inventing a potion effect. Crafted flower stews retain
their existing effects.

Brushing uses the node's saved seed and the normal fixed-reward archaeology
lifecycle. Save/reload does not reroll a reveal, and completing an excavation
converts it to plain sand and releases its reward once.

## Verification

`tests/desert_well_reference_checks.gd` compares every voxel and suspicious-sand
position against all sixteen source oracle cases. It also checks foundation
acceptance/rejection, ground descent, biome/dimension eligibility, cross-column
halos and bounded caches. `tests/desert_well_checks.gd` exercises natural placement,
real digging and targeting, brushing, actual disk save/reload, no duplicate
rewards, all six loot results and plain-stew nutrition/bowl handling.
`tests/desert_well_tour.gd` renders the exterior and an excavation cutaway.

Final validation: 20 focused well gameplay checks passed, alongside 223 combined
well/temple/trail/food regressions. All 26 reference checks passed both locally
and from the Linux resource pack, including every voxel in all sixteen oracle
cases. The oracle and archaeology exports reproduced byte-for-byte. Exterior
and excavation previews were inspected; editor import reported no script errors.

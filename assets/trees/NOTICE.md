# Tree voxel layouts

`mineclonia_trees.json` is a sparse-format conversion of the 38 classic oak,
spruce, birch, jungle, acacia and dark-oak tree schematics referenced by
Mineclonia's `mods/ITEMS/mcl_core/nodes_trees.lua`. Every entry records the
original `.mts` filename and its SHA-256 checksum. Node identities, placement
probabilities, rotations and vertical slice probabilities are preserved.
Voxey maps their node names onto its own resources at runtime. No source
textures, sounds or models are included.

Source: the local Mineclonia distribution at
`/home/impulse/.minetest/games/mineclonia`, obtained September 2026.
Upstream project: https://codeberg.org/mineclonia/mineclonia

Attribution: Mineclonia and MineClone contributors; the `mcl_core` README
credits celeron55, Perttu Ahola <celeron55@gmail.com> and identifies the mod as
originally forked from Minetest Game's default mod. Its license notice is
reproduced in `MINECLONIA_CORE_README.md`. Its catch-all license for material
not otherwise listed is Creative Commons Attribution-ShareAlike 3.0:
https://creativecommons.org/licenses/by-sa/3.0/

The converted schematic data is distributed under that same CC BY-SA 3.0
license. Changes: binary MTS containers were converted to sparse JSON, with
filenames and checksums added for auditability. Voxey's procedural textures
and its own gameplay implementation remain separate from these voxel layouts.

Reproduce the conversion with:

```sh
python3 tools/convert_mineclonia_trees.py /path/to/mineclonia
```

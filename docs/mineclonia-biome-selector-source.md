# Source biome selection

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-25.
The exported extents and selector logic retain GPL-3.0-or-later attribution.

`scripts/mineclonia_biome_selector.gd` completes the default-Overworld
`index_biomes_block` path on top of [canonical biome names](biome-map-source.md)
and the [numerical climate sampler](mineclonia-noise-source.md).

## Public API

```gdscript
var selector := MinecloniaBiomeSelector.new(world_seed)
selector.index_biomes_block(block_x, block_y, block_z) # source canonical ID
selector.index_biomes(quart_x, quart_y, quart_z)       # same query at a quart origin
selector.select_coordinates(seven_quantized_coordinates)
selector.sample_climate(block_x, block_y, block_z)    # forwarded numerical climate
```

The constructor may receive an existing `MinecloniaNoise` as its second argument
so several selectors share one immutable sampler. Each selector keeps its own
`last_result`, matching a source preset's mutable R-tree state. The packed tree is
read-only and shared by all instances.

## Exported tree and search

`tools/export_biome_reference.py` calls the source's
`mcl_levelgen.construct_overworld_lut()` and serializes its **packed Lua R-tree**.
The default checkout has 7,593 leaves. An internal node has packed extents and up
to six children; a leaf also has a canonical `value`. Packed bounds decode as:

```text
min = packed >> 16
max = (packed & 0xffff) - 32768
```

For each of seven quantized coordinates, distance is the inclusive extent gap:
`q - max` above the range, `min - q` below it, and zero inside it. The summed
squared distance is compared with strict `<`. Traversal follows the exported child
order, and a query starts from the instance's previous leaf when one exists.
Those two details reproduce source tie and cache behaviour; a rebuilt registration
list would not.

## Oracle and checks

```sh
python3 tools/export_biome_reference.py
godot --headless --path . --script tests/mineclonia_biome_checks.gd
```

The exporter writes `assets/data/biome_lut.json` and adds 7,593 integer-coordinate
queries to `biome_reference.json`. Each query uses a leaf-center extent and is run
forward and in reverse order against the real source tree. The suite also checks
packed-bound inclusivity and exclusion, all 53 selected Overworld IDs, integrated
noise-to-ID results for signed seeds, and block/quart agreement. It passes 15,445
checks.

## Integration and boundary

`TerrainGenerator` owns one selector per Overworld generator. Its two-argument
`biome(x,z)` is a Voxey surface query: it samples at the generated surface height,
not at a fixed source Y. The three-dimensional selector and `biome_climate` are
available to structures, weather, mob and plant consumers.

This proves selection for identical source seed and source block coordinates. It
does not reproduce Voxey terrain density, source height/surface rules, cave
biomes, aquifers/carvers, structure seeds, or natural feature placement. Biome
feature dispatch remains adapted rather than claiming full source world
generation.

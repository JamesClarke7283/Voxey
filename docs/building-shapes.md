# Stairs and slabs

All 124 registered Mineclonia stair/slab families are available, together with 11 preserved native extension families: 270 craftable shape items. This includes all wood, wool, concrete and terracotta colors, dark prismarine, lapis, smooth stone, and cut/smooth/red sandstone. See the [registered shape comparison](shape-registry-source.md) for source evidence and remaining differences.

- Three matching blocks in a row make six slabs. Six blocks in a stair pattern make four stairs; mirrored patterns work.
- Slabs occupy the bottom or top half. Place against a ceiling or the upper portion of a side to choose the upper half. Matching halves combine into a double slab, which drops two slabs when mined.
- Stairs face away from the player and can be inverted. Adjacent perpendicular stairs automatically form inner or outer corners. Removing a neighbor restores the original facing.
- Collision, ray targeting, selection outlines, mining cracks, held items and ground drops use the actual shape. Players walk up half-height steps without jumping. Torches and small redstone components require a complete supporting face and drop if that support disappears.
- The recipe grid shows shape previews. Stonecutters use the source's eligible materials and yield two slabs or one stair per block, including raw-stone routes to finished shapes. Wood and decorative metal shapes remain crafting recipes. Registered wood slabs have 7 seconds of fuel value; stairs have 15.
- Placement states use stable IDs and survive saves and chunk reloads. Full double slabs participate in greedy cube meshing; other shapes emit only exposed half-voxel faces. Changes near chunk corners remesh the affected neighbors.

Deepslate bricks craft into tiles; bricks and tiles smelt into their cracked variants. Cobbled deepslate slabs craft chiseled deepslate. Natural tuff crafts into polished tuff and tuff bricks; stacked polished/brick slabs craft the two chiseled tuff blocks. These eight new blocks have original procedural textures and source stonecutter routes.

## Source and verification

References in the supplied Mineclonia checkout: `mcl_stairs/{api,cornerstair,crafting}.lua`, `mcl_core/nodes_stairs.lua`, `mcl_deepslate/deepslate.lua`, `mcl_blackstone/init.lua`, `mcl_nether/init.lua`, `mcl_end` and `mclx_stairs/init.lua`.

`cornerstair.lua` explicitly licenses its corner algorithm as CC0. `python3 tools/build_stair_reference.py` executes that local resolver through a read-only Lua harness and writes 5,000 upright/inverted neighbor configurations to `tests/stair-reference.json`, including the source hash. The building suite compares every result with Voxey's collision/mesh mask. It also tests actual placement, material separation, collision and walking, attachments, crafting yields, and saves. `tests/building_tour.gd` exercises rendered shapes and inventory previews using isolated worlds.

The dedicated building suite includes the 5,000 source stair corner cases, tuff and masonry comparisons and native noise comparisons. The registry suite adds 2,864 real source crafting cases and 390 placement callbacks. Script diagnostics are treated as test failures even when Godot returns exit status zero.

This is partial building parity. [Chiseled, cracked and mossy stone bricks](ruined-portals-source.md) are now present, with cracked bricks smelted from the plain ones. All registered shape families now have bindings, and smooth-stone slabs have their distinct side bands. Source sounds, exact lighting, some texture orientation, blast propagation and navigation remain part of the wider parity work.

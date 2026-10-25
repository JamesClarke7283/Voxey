# Registered stair and slab families

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-24.
Source-derived rules retain GPL-3.0-or-later attribution. The existing corner
resolver follows the source's CC0 `cornerstair.lua`; artwork remains procedural.

The loaded game registers 124 non-waxed stair/slab families. Voxey now binds all
124 and retains its 11 existing native extensions. Fifty families were missing:
16 concrete colors, 16 wool colors, cherry/mangrove/pale-oak/crimson/warped planks
and bark, lapis, dark prismarine, cracked stone brick, smooth stone, smooth
sandstone, and the three red-sandstone forms. This adds 100 craftable shape items.

## Registration and compatibility

`tools/export_shapes_reference.py` loads the actual Luanti game and records
names, groups, hardness, blast resistance, drops, fuel, crafting recipes,
stonecutter inputs and source hashes. `tools/build_shape_catalog.py` maps that
registry into `assets/data/shapes.json`, consumed by `ShapeCatalog`.

Existing family IDs remain unchanged. The 50 new families occupy 14000–14799,
with 16 IDs reserved per family. Lower slab, upper slab, double slab, four stair
facings and four inverted facings share the existing geometry, targeting and
collision code. The remaining five IDs in each family remain unused.

Seven base blocks at 13700–13706 supply missing ingredients: lapis block, cut
sandstone, red sand, red sandstone, cut red sandstone, chiseled red sandstone
and smooth red sandstone. Lapis packs/unpacks nine items; four red sand craft
red sandstone. Red sandstone smelts into its smooth form; red sand smelts into
glass. The wandering trader's real ordinary offer sells three red sand for one
emerald, with six uses. Natural red-sand mesa generation remains open.

The old `SANDSTONE_BRICK` constant/ID 31 represents chiseled sandstone. Its title
and two-slab recipe now reflect that source identity. The existing cut-sandstone
shape family 4128 keeps its ID and now uses actual cut sandstone, rather than
chiseled sandstone. Existing placed shapes survive this correction.

Red sand joins cane, bamboo, cactus, seagrass and kelp placement surfaces. The
six existing seagrass node IDs retain their original surfaces; red-sand seagrass
uses a new separate ID, 13707. Texture-only ID 13720 supplies the smooth-stone
slab's distinct horizontal edge bands and is hidden from inventories.

## Recipes and placement

Three base blocks craft six slabs; six blocks in either stair pattern craft
four stairs. Wool recoloring accepts the source wool-shape group. Quartz and
purpur recipes accept their registered block groups, including mixed variants.
Source recipe metadata works through the grid, recipe guide and automatic
ingredient selection. Stonecutters use each shape's final registered input
list and yield two slabs or one stair. For example, the loaded game's mud-brick
and prismarine shapes accept their respective base block; earlier broader
native input lists were corrected.

Stair facing uses the vector from the player's position to the target cell's
center, as the source does. Side hits above the 0.55 cell-height threshold invert
a shape; ceiling hits invert it and top hits keep it upright. Matching lower
and upper slabs combine through the source's direct replacement path, including
when a player occupies the unfilled half. Ordinary placement still checks body
collision. Double slabs drop two ordinary slabs.

## Verification and remaining differences

Final checks on 2026-10-24: 11,073 shape registry comparisons, 171 building
checks (including the 5,000 corner configurations), 430 live lifecycle checks,
40,615 furnace comparisons and 535 core survival checks pass without script
errors. All 16 shape-source and 70 furnace-source hashes match the supplied
checkout. Material/recipe views were visually reviewed, and the Linux pack
exports successfully.

The exporter executes 2,864 real crafting queries, including shifted/mirrored
recipes and invalid ingredients, and 390 registered placement callbacks. The
native checks compare outputs, consumption, placement, groups, fuel and drops.

Fueled half slabs preserve the source's exact 7.5-second burn time even though the exported JSON truncates it to 7; zero-fuel wool slabs remain non-fuel.
The existing exhaustive corner test compares all 5,000 neighbor configurations.
Live checks cover crafting, red-sand smelting, placement, collision and the
save/reload of all 50 new families. `shape_registry_tour.gd` renders the material
families and searchable recipe catalog for visual inspection.

This completes the registered family inventory, not every aspect of building
parity. Material artwork is original; source sound groups, exact lighting,
blast propagation, navigation and some texture orientation remain adaptations.
Red-sand terrain generation remains open. The [barrier registry](barriers-source.md)
now covers the full source fence/wall material catalog. Native extension families keep their existing IDs and
recipes and are not counted as source registrations.

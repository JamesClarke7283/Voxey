# Packed ice, blue ice and bone blocks

`scripts/dense_materials.gd` closes the survival material dependencies for note-block chimes and wooden xylophones. It uses the supplied Mineclonia source, rather than substituting different blocks for those instruments.

| Material | Recipe | Hardness | Mining drop |
| --- | --- | --- | --- |
| Packed ice (7400) | Nine ordinary ice, crafting table | 0.5 | Itself with Silk Touch; otherwise nothing |
| Blue ice (7401) | Nine packed ice, crafting table | 2.8 | Itself with Silk Touch; otherwise nothing |
| Bone block (7402) | Nine bone meal, crafting table | 2 | One canonical bone block with a pickaxe |

One bone block also reverses into nine bone meal in hand crafting. Existing bone/composter acquisition supplies bone meal, and the existing ordinary ice plus Silk Touch tool acquisition supplies ice. Compressed ice is opaque, supports ordinary full-cube building, and never turns into water when broken. Ice is hand-breakable with a pickaxe speed preference; Fortune produces no ice item. Bone requires a pickaxe to recover. Placing bone on a side aligns its long axis to that face; hidden placed IDs 7403/7404 preserve the X/Z axes across saves. They drop and middle-pick the canonical item. Atlas entry 7405 is a hidden end-grain texture, not a usable block.

## Ice behavior

The local source's ordinary ice `after_dig_node` callback unconditionally runs `mcl_core.melt_ice`. If there is a loaded non-air block below it, ordinary ice becomes a water source outside the Nether. This also runs when Silk Touch produces an ice item and during creative breaking; it is a behavior of the actual supplied source, even though it differs from familiar variants of this game. Unsupported ordinary ice and ice broken in the Nether leave air. Packed/blue ice have no such callback. The special break helper preserves normal particles, tool durability through player mining, progression, block-break events and unsupported/falling block handling.

Ordinary, frosted and packed ice have source `slippery=3`; blue ice has `slippery=4`. Voxey applies the [Luanti `LocalPlayer::getSlipFactor` rule](https://github.com/luanti-org/luanti/blob/master/src/client/localplayer.cpp) to its existing horizontal acceleration: divide by `slippery + 1`, or by `2 * slippery + 1` when there is no horizontal movement input. Thus releasing a movement key makes an already moving player coast, and blue ice retains more velocity. The effect applies while grounded and outside liquid/ladder/flying movement. This preserves the source ratio within Voxey's existing movement scale; it does not replace the entire movement controller with Luanti physics.

Mineclonia boats test the `ice` group, not the numeric slipperiness value. All four ice types therefore share the existing source boat acceleration/drag and 57.1 component velocity limit. Blue ice does not receive an invented extra boat multiplier. The boat collision sweep and unloaded-column stop remain active at these higher speeds.

This batch implements crafting, placement, breaking, material movement and persistence. Natural fossil/iceberg generation, ambient ordinary-ice heat melting and cold-water freezing remain separate world-generation/environment gaps; no claim is made that the full Mineclonia climate system is implemented. Bone and compressed-ice textures are original procedural Voxey artwork.

## Source provenance

Paths below are relative to `/home/impulse/.minetest/games/mineclonia/` (no Git revision metadata was supplied):

| File | SHA-256 |
| --- | --- |
| `mods/ITEMS/mcl_core/nodes_base.lua` | `958abfcde306b5dbd65a72ec51a7d0d77ed136fb4ab104b8ff602f6499ae8b18` |
| `mods/ITEMS/mcl_core/nodes_misc.lua` | `780fa1eb79ba364d2dcd2d1425618d68a132c38fe0db5a67fa87d0b53f9d7b0f` |
| `mods/ITEMS/mcl_core/functions.lua` | `a518566a56114d3f57e111ee1f13e672080d143e0ec8156aee0314bf7ed5b969` |
| `mods/ITEMS/mcl_bone_meal/init.lua` | `04e9643b7dbf37f50dc572e34a08f5ee0887fce7a72d83532cfaf8773dc973ec` |
| `mods/ENTITIES/mcl_item_entity/init.lua` | `e519f871d3cd09d7133687bae8bff13b4468623a85c854abf84d31de801d6e1e` |
| `mods/ENTITIES/mcl_boats/init.lua` | `88b5cc0bedd4d80164eb13ea370b178549c1a7585777e1da63ec329123b82cad` |

`nodes_base.lua` defines all ice groups, hardness, drops and compression; `nodes_misc.lua` supplies bone's pickaxe group and axis placement; bone meal registration and the crafting-output helper supply the reversible recipe. `functions.lua` defines the ordinary-ice water callback. `mcl_item_entity` changes the Silk Touch drop independently of that callback. `mcl_boats` uses one common ice-group branch.

`tests/dense_material_checks.gd` verifies actual recipe transactions, canonical/hidden item IDs, all bone faces and real placement, tools/Silk Touch/Fortune/creative drops, supported/unsupported/Nether ice breaking, real mining durability, held/released keyboard movement, boat movement on every ice kind, and real save/reload of all placed IDs. Run through `tests/lifecycle_runner.gd -- dense_material`.

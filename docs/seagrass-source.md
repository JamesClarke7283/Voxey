# Seagrass

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_ocean/seagrass.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or texture is copied.

## Rooted nodes, one per surface

The source registers seagrass as `plantlike_rooted` nodes, so each node carries **both** the plant and the block it grew from. There is one node per supported surface:

| Surface | |
|---|---|
| Dirt | ✓ |
| Sand | ✓ |
| Gravel | ✓ |
| Prismarine | ✓ |
| Prismarine bricks | ✓ |
| Dark prismarine | ✓ |

One item, `seagrass`, places whichever node matches the block beneath it.

## Placement

Two conditions, both required:

1. The block below must be a **supported surface**.
2. The cell above must be a **water source** — not merely water. The source tests both the water group and `liquidtype == "source"`, so flowing water does not qualify.

## Drops

This is the part worth stating plainly: the seagrass **node drops nothing at all**. The source sets `drop = ""` on the node. Only **shears** return the seagrass item, through the source's `_mcl_shears_drop`. Digging seagrass restores the plain surface block underneath, which is what the source's `after_dig_node` does by swapping the rooted node back.

## Recorded source gaps

- **No natural generation.** The source places seagrass on ocean floors, which Voxey does not generate. The nodes exist and behave correctly once placed, but a world will not contain them until ocean generation exists.
- **Six of the seven surfaces.** The source also supports red sand, which Voxey has no block for. The other six are implemented, and the missing one is recorded rather than substituted.
- **The plant's animated texture is drawn procedurally.** The source animates the blades through a vertical frame set; Voxey draws them from its own pixel-sprite system over the surface block's tile.
- **The two falling surfaces are not distinguished.** The source gives sand and red-sand seagrass the `falling_node` group with an alternative, so an unsupported one reverts rather than falling as a plant. Voxey's seagrass has no falling behaviour; it simply stays where it is placed.
- The source's `fix_incorrect_seagrass` LBM corrects old wrongly-rotated nodes, which has no equivalent here since there are no legacy seagrass nodes to migrate.

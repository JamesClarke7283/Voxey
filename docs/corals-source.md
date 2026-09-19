# Coral

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_ocean/corals.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or texture is copied.

## Thirty nodes from one table

Five species — tube, brain, bubble, fire and horn — each in six forms:

| Form | Living | Dead |
|---|---|---|
| Block | ✓ | ✓ |
| Rooted plant | ✓ | ✓ |
| Fan | ✓ | ✓ |

All thirty are generated from the species table, exactly as the source's loop does.

## The defining behaviour: death without water

The source uses two ABMs, both on a **17 second interval with a 1-in-5 chance**:

- A **plant or fan** needs a water source directly **above** it. Water to the side does not save it. This is because the source draws them as `plantlike_rooted`, so the node carries the coral block beneath it.
- A **coral block** survives while **any of its six neighbours** is water.

When the check fails, the node is swapped for its dead form — which is also the node's own drop. Dead coral never dies again.

Voxey rolls that chance afresh each interval, as the source's ABM does, rather than deriving it from the cell position, which would make individual corals permanently lucky or unlucky.

## Placement

A plant or fan may only be placed on top of a **matching species** coral block, and nothing else. The source's `coral_on_place` compares both the coral-block group and the species group; Voxey compares the species directly. Placing a plant on bare ground or on the wrong species is refused rather than silently dropping the block.

## Drops

A living block, plant or fan drops its **dead** form unless Silk Touch is used, which is the source's `_mcl_silk_touch_drop` setting. Dead coral drops itself. Note that the source's fan entry is its own drop, so only the block pair and the plant pair differ from their dead forms.

## Recorded source gaps

- **Coral now generates naturally.** [Ocean ruins](ocean-ruins-source.md) place coral in warm seas, which is the source's own route, so coral is gathered in survival rather than only crafted. A dye recipe remains as well, which is a Voxey addition rather than a source rule.
- **The fan's dead form is registered separately.** The source reuses the living fan node for its own drop; Voxey registers a distinct dead fan so the death swap and the drop agree, which keeps the six-form stride uniform.
- **The source's `meshoptions` plant shapes are not reproduced literally.** Coral plants and fans are drawn from Voxey's own pixel-sprite and box-mesh systems, so a fan is a narrower form than a plant rather than a distinct model.
- The source's `node_dig_prediction` and `after_dig_node` block-restoration behaviour has no direct equivalent, since Voxey stores the rooted block as a separate node.

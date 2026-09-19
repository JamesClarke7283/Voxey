# Beacons

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_beacons/init.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or texture is copied.

## The pyramid

`check_pyramid` walks **four square layers** beneath the beacon, the layer at offset *n* being a square of radius *n*. The first layer containing a block that is not in the `beacon_block` group caps the power at the layer below it, and completing all four gives the maximum of 4.

The source's own mineral blocks are accepted: iron, gold, diamond and emerald — plus netherite, which the reference also marks `beacon_block`.

| Power | Pyramid |
|---|---|
| 0 | none, or a gap in the first layer |
| 1 | one layer |
| 2 | two layers |
| 3 | three layers |
| 4 | four complete layers |

## Effects and range

Six effects, each gated by a minimum power, taken from the source's `effect_level` table:

| Effect | Minimum power |
|---|---|
| Swiftness, Haste | 1 |
| Resistance, Leaping | 2 |
| Strength | 3 |
| Regeneration | 4 |

A **power-4** beacon also grants a second effect, which the source fixes to regeneration.

Range is the source's own formula, `(power_level + 1) * 10` — 20 blocks at power 1 and 50 at power 4. The effect is granted for 16 seconds and decays normally.

## The beam

A vertical beam rises from the beacon, and its colour comes from the **stained glass directly above it**, which is how the reference tints beams. Voxey scans a fixed distance upward rather than bounding the scan by the terrain ceiling, because a beacon can legitimately sit above it.

## Recorded source gaps

- **The nether star now has a survival route.** The reference obtains it by killing the Wither, and [the wither](wither-source.md) is implemented with the source's own seven-cell soul-sand summoning ritual. Its nether star drop is guaranteed, so the beacon recipe — five glass and three obsidian around a star — is now reachable in survival rather than creative.
- **No formspec.** The reference opens a beacon UI where the player picks effects from image buttons. Voxey cycles the effect that the current power allows when the beacon is used, which reaches the same stored state without the window.
- **The beam is a node, not a rendered column.** The source draws a `beacon_beam` node stack; Voxey registers the beam block and computes its length and colour, but does not yet place a full column of beam nodes when a pyramid completes.
- **The source's payment cost** (an item consumed when an effect is changed) is not charged.
- Stained-glass tinting is honoured in `beam_color`, but Voxey's glass family is smaller than the reference's sixteen colours.

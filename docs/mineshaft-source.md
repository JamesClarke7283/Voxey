# Mineshafts

Voxey follows the supplied Mineclonia mineshaft generator. The implementation is original GDScript using the source as a behaviour reference; no source code or asset is copied.

## Which generator is the reference

Mineclonia ships **two** mineshaft implementations, and picking the right one matters:

| Module | Status in a default game |
|---|---|
| `MAPGEN/tsm_railcorridors` | **Disabled.** Its first statement is `if mcl_levelgen.enable_ersatz then return false end`. |
| `MAPGEN/mcl_levelgen/mineshaft.lua` | **Active.** This is what actually generates mineshafts. |

`mcl_levelgen_enable_ersatz` defaults to **true** (`settingtypes.txt`), and the installed Luanti reports the `generate_decorations_biomes` feature the ersatz system also requires — so `tsm_railcorridors` returns early and the piece-based `mcl_levelgen` generator runs instead. Voxey therefore ports `mcl_levelgen/mineshaft.lua`.

The two are quite different: `tsm_railcorridors` builds a dirt room with radiating corridor lines and rails nearly everywhere, while the active generator is a recursive **piece** system in which only one corridor in three carries rails at all.

## Structure

A mineshaft is a **parlor** — a room seven to twelve blocks across and two to four high — with wall openings cut in all four cardinal directions. From each opening the generator lays a chain of pieces:

- **Corridors** (70%) — a three-wide, two-high tube with an arched roof, in runs of 10, 15 or 20 blocks.
- **Junctions** (20%) — a cross-shaped passage with corner pillars, sometimes two storeys tall.
- **Staircases** (10%) — a five-step descent that changes the system's height.

Every piece is placed from a local coordinate frame rotated by its facing, so one placement routine produces all four orientations. Pieces branch recursively to a depth of eight and never stray more than 80 blocks from the parlor in x or z. Candidate pieces are rejected when their bounding box overlaps one already placed.

## Details reproduced

- **Timber arches** every fifth block along a corridor, with fence posts down each side. An arch is only built where the roof above it is solid; one in four is "broken" and leaves only its two ends.
- **Cobwebs** beside the arches at the source's descending chances, and only where the cell is buried and at least two neighbouring faces are sturdy enough to hold one.
- **Rails** on one corridor in three, laid down the middle on the existing floor.
- **Loot** is not a chest block. `create_chest` places a *rail* and then constructs a **chest minecart** on top of it, filled from the source's own `minecart_loot` table. Voxey spawns a real chest cart with that cargo.
- **Cave-spider spawners** in corridors that carry no rails, at the source's own odds.
- **Chains and pillars** at the corridor arch positions: a hanging support up to the next solid ceiling, or a wooden pillar down to the next solid floor.
- **Wall validation** — a mineshaft is refused outright if water or lava lies anywhere in its padded bounding box walls, and no cell is written outside the placement level band.

## Recorded source gaps

- Mineclonia's placement is biome-driven: a list of biomes carries `has_mineshaft`, and badlands carry `has_mineshaft_mesa` for a dark-oak palette. Voxey's region planner has no biome map at this stage, so the oak palette is used and both variants are plumbed but not selected by biome.
- The source tests the biome at the structure's centre and shifts the whole assembly to the surface. Voxey plans in a fixed underground band instead, matching how the other deep structures work.
- The source's `DeepDark` biome blocks mineshafts. There is no biome map, so that exclusion is not applied.
- Voxey has no chain block, so the hanging supports are iron bars.

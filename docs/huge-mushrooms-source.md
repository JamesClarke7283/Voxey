# Huge mushrooms

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_mushrooms/{init,small,huge}.lua`. The implementation is original GDScript using the source as a behaviour reference; art is original procedural code.

## Why it is not just "a bigger mushroom"

Bone meal on a small mushroom grows a huge one, and the source's rule has **four** gates, all of which matter:

| Gate | Source |
|---|---|
| Roll | `math.random(1, 100) > 40 then return` — a **40%** chance, so most attempts do nothing |
| Soil | mycelium, dirt, grass, coarse dirt or podzol |
| Room | a box scan: no opaque block below the needed height, and every cell air or leaves |
| Height | `base_height = math.random(0, 2)`, doubled one time in twelve |

The roll is why the checks assert a huge mushroom grows *sometimes and not every time*. A guaranteed growth would be easier to write and simply wrong.

## The shapes come from the source's own schematics

The two species differ in shape, which the source ships as `.mts` files. Rather than approximate them, the shapes are decoded from those files:

- **Brown** — a **7×7** cap: a full 7-wide layer on top, then a ring one wide, with the corners trimmed at the edge.
- **Red** — a **5×5** cap over a one-block stem, with a 3×3 top and a 2-wide ring below.

Decoding them mattered. My first attempt at the brown cap was a hand-drawn `#`/`|` diagram guessed from the Lua, and it did not match the binary schematic. Reading the actual voxel data settled both the widths and where the stem continues **through** the cap's centre — the source marks that column `S` in the cap layers too, so a height-three stem with a two-layer cap has **five** stem cells, not three.

## Cap blocks are a family, not one block

This is the part worth understanding. A huge mushroom cap block's *skin* depends on which of its six faces are exposed. The source registers:

- **63 interior variants**, `cap_000000` through `cap_111111`, one bit per face, skin where the bit is set and pores where it is not;
- the **all-skin** block a player can place;
- rules that turn two touching cap blocks' faces to pores **permanently**.

Voxey models the visible consequence rather than the full 63-variant table: any cap cell with another cap directly above it becomes **pores**, and the rest is skin. So a huge mushroom is skin outside and pores inside, which is what a player sees. The bit-level variants are recorded as an open gap below.

## Drops

A mushroom block drops the **small** mushroom — one or two — and only **Silk Touch** preserves the block itself. So breaking a huge mushroom yields food and planting stock rather than building material, which is the source's own behaviour.

## Recorded source gaps

- **No 63-variant cap table.** The interior/skin distinction is modelled by cap adjacency rather than by 63 registered blocks, so a cap block does not carry per-face skin state that survives being broken and replaced.
- **No permanent pore conversion between placed caps.** The source turns a face to pores when two cap blocks touch; Voxey computes pores from adjacency at growth time only.
- **No huge mushrooms in world generation.** The source grows them naturally in dark forests and mushroom islands; Voxey's are grown by bone meal only, because Voxey has no mushroom island biome.
- **No mycelium, coarse dirt or podzol.** The source's soil list includes them; Voxey has dirt and grass, so those two are the accepted soils and the rest are recorded.
- **No mushroom-block placement merging.** Placing a cap next to another does not permanently convert their touching faces.

# The atlas and the fallback tile

Voxey draws every block from one texture atlas. A block's tile index comes from a
hand-maintained list, and when a block is **missing** from that list the lookup
returns the fallback rather than failing:

    static func tile(id: int, face: int) -> int:
        ...
        if VillageContent.DATA.has(id): return 137+VillageContent.BLOCKS.find(id)

`Array.find` returns `-1` for a missing element, so the expression evaluates to
`137 + (-1) = 136`. Tile 136 is the **end-portal** texture — dark purple
(`171329`) with flecks. So a block missing from the list does not fail, raise, or
render as a placeholder: it renders as an **end portal**.

## Why this is the worst kind of bug

Twenty-nine blocks were in that state:

| Block | Rendered as |
|---|---|
| Powder snow | dark purple |
| Every shulker box (17 colours) | dark purple |
| Moss block, moss carpet, hanging roots | dark purple |
| Tall grass | dark purple |
| Cave vines (lit and unlit) | dark purple |
| Ender chest | dark purple |
| Soul soil, campfires (three states) | dark purple |
| Daylight detector | dark purple |

Each of those passed every check anyone would think to write. The block is
**registered**, has a **name**, has **hardness**, is **placeable**, has a **drop**
and is **solid or not** as it should be. The only thing wrong is the texture, and
nothing in the code path reports it.

## Why the existing checks missed it

The art checks called the drawing function **directly**:

    VillageArt.pixel(id, x, y, Color(0.5,0.5,0.5))

That bypasses the atlas mapping entirely, so it passed for all 29. It was testing
the *painting* function, not the *lookup* that decides whether the painting is ever
used. This is the general lesson: **test the layer that can be wrong**, which here is
`Nodes.tile`, not `VillageArt.pixel`.

The replacement check walks every registered block and asserts none resolves to tile
136:

    for id in VillageContent.DATA:
        if not VillageContent.DATA[id].get("block",false): continue
        if Nodes.tile(id,0) == 136: missing_art.append(id)

## The atlas is a fixed-size budget

The atlas is sized from the list, so adding entries is safe — but only because
`make_atlas` derives its height from `BLOCKS.size()`. The consequence is that the
list is **append-only**: inserting an id in the middle would renumber every tile
after it, and every block's saved-in-mesh tile index and every hard-coded tile
reference would shift.

At the time of writing the atlas is at **686 tiles in 86 rows of 86** — exactly full,
so the last row is the last row. Any growth beyond that resizes the image, which is
safe for correctness but worth knowing.

## The same bug in the mesh path

Fixing the atlas exposed a **second, identical** omission. `BLOCKS` decides the
*texture*; a different set of shape lists decides whether a block is *meshed at all*.
Three of those lists enumerate shapes and all three omitted `"vine"`:

| List | What it decides | Symptom when `"vine"` is missing |
|---|---|---|
| `Nodes.plant` | the plant mesher draws it | **no mesh at all** |
| `VillageContent.special` | whether it is an unmeshed special shape | **no mesh at all** |
| `Nodes.solid` | whether it blocks movement | a hanging strand is a **wall** |

So cave vines rendered as nothing, and would have been solid if they had rendered.
The source is explicit for this block — `walkable = false`, `climbable = true` — and
both facts now hold, including the climb, which the player's ladder check had no
branch for.

The general lesson is the same one as the atlas: a new shape joins an existing
mechanism only where it is **listed**, and the lists are scattered. A shape-based
block needs an entry in the mesher's dispatch, the special-shape guard, the
solidity test and the art dispatch, or it fails in a different way in each.

## The check that would have caught it

One assertion, over every registered block, comparing its tile against the fallback.
It costs a few milliseconds and covers every block ever added — which is why it lives
in the food-feature suite as a general content assertion rather than being repeated
per module.

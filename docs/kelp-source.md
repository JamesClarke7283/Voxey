# Kelp

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_ocean/kelp.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or texture is copied.

## One node is a whole stalk

The source has a known limitation it states outright in comments: because of Luanti's `plantlike_rooted`, kelp cannot be a stack of separate stem nodes. Instead **one node represents the entire stalk**, and its height is encoded in `param2`:

```
height = floor(param2 / 16) + floor(param2 % 16 / 8)
```

so a step of 16 adds one to the height, and the final step doubles back to add the sixteenth stem — hence the source's `min(param2 + 16 - param2 % 16, 255)`.

Voxey stores the height and age as plain per-block values beside the node, which is equivalent and avoids inventing a param2 table.

## Growth

| Constant | Value | Meaning |
|---|---|---|
| `MIN_AGE` | 0 | |
| `MAX_AGE` | 25 | at or beyond this, kelp **stops growing entirely** |
| `TICK` | 0.2 s | the source's update interval |
| Growth chance | `216 × 0.2 / (100 × 1200)` | derived from Minecraft's 2.16 growths per day |

Height is capped at 16 — the source's sixteenth stem. A stalk's age is rolled randomly when it is placed or when it is regrown after being cut back.

## Drowning

Kelp must stay submerged. If any cell of the stalk is no longer water, the part above that cell is detached and dropped as items, and the stalk's age is rerolled. This is the source's `detach_unsubmerged`.

## Digging

Digging a stalk drops **one kelp item per unit of height**, which is the source's `detach_drop` walking the column, and restores the surface block the kelp grew from.

## Recorded source gaps

- **No natural generation.** The source grows kelp on ocean floors, which Voxey does not generate; kelp is placed by hand and grows from there.
- **Six surfaces, not seven.** Placement uses the same surface set as seagrass, so red sand is absent as it is there.
- **The animated tip is drawn procedurally**, and the stalk's visual height in the world does not yet grow with the stored height — the node remains one block tall visually while its logical height, drops and growth all track correctly. Rendering the full column is the remaining visual gap.
- **Downward-flowing water is not treated specially.** The source lets kelp grow in flowing water and converts the tip to a water source in that case; Voxey requires still water.
- **The piston callbacks** (`surface_on_piston_move`) and the falling-node alternative are not wired, since Voxey's piston handling has its own path for plants.

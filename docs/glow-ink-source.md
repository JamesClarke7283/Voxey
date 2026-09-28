# Item frames, glow ink and signs

Two source modules share one consumable: `ITEMS/mcl_signs` and `ITEMS/mcl_itemframes`
both answer a glow ink sac.

## Signs

`mcl_signs/init.lua`:487-497 — the sign's `on_rightclick` checks the held stack's
name first:

```lua
if itemstack:get_name() == "mcl_mobitems:glow_ink_sac" then
	meta:set_string("glow", "true")
	meta:set_string("color", "#7e7e7e")  -- "#000000 doesn't glow in the dark"
	itemstack:take_item()
```

`#000000` is recoloured to `#7e7e7e` precisely because pure black does not glow in
the dark. The check is on the item's **name**, not its group or a prior state, so
applying a sac to an already-glowing sign still consumes one.

Voxey already had `Signs.apply_glow`, which did the recolour and the flag correctly —
but nothing called it, and its own comment claimed no glow-ink item existed. That
comment was wrong: `village_content.gd`:118-121 registers the sac and
`aquatic_mobs.gd`:90-92 drops it from a glow squid. `GlowInk.apply` is the missing
consumer.

## Item frames

`mcl_itemframes/register.lua`:3-49 registers **four** forms:

| Form | Property |
| --- | --- |
| `frame` | the ordinary one |
| `glow_frame` | `object_properties = {glow = 15}` |
| `invisible_frame` | `drawtype = "airlike"` |
| `invisible_glow_frame` | `drawtype = "airlike"`, glow |

Its **only** acquisition path in the source is the shapeless glow-ink recipe at
`:74-78`, which produces `glow_frame`. The two invisible forms have no recipe,
structure or LBM that yields them, so in the source they exist only in creative
inventories.

Voxey keeps one frame node id, so a form is a saved flag rather than a node, and one
sac advances the frame along the source's own registration order — plain → glow →
invisible → invisible glow, wrapping at the end. That is the cheapest representation
that reaches all four registered forms with the single consumable the source ties to
frames.

## Rotation

`mcl_itemframes/init.lua`:96-106:

```lua
local angle = 0.25 * math.pi * (entity.item_rotation or 1) * (is_map + 1)
```

So an ordinary item turns in 45° steps through eight indices and a map's visual turn
is **doubled** to 90°. `:108-126` re-applies the saved index after every item change;
`:130-135` gates the right-click on the frame holding a non-empty stack.

Voxey's existing click takes the framed item out, which is the more useful default,
so the turn is on **sneak** instead; breaking the frame still returns both the frame
and its contents. `Frames.ROTATIONS` is 8 and the angle is `PI*index/4`, doubled for
a filled map.

## The comparator

`mcl_comparators/init.lua`:113-119, `measure_item_frames`:

```lua
return frame:get_item_rotation() + 1  -- when it holds an item
return 0                              -- when empty
```

The **map's doubled visual step is not applied to the signal**: it reads the raw
index plus one, so the range is 1-8. Voxey's `container_signal` gained the frame
branch, and `container()` was deliberately **not** taught about frames — the source's
frame node has no inventory a hopper can reach (`allow_metadata_inventory_put/take`
both return 0, `init.lua`:38-40), so leaving it alone keeps a hopper from pulling the
framed item.

## Known limitation

`BlockMesher` meshes voxels by id alone, so an invisible or invisible-glow frame
still draws its wooden border while the item inside it draws, spins and glows
correctly. Closing that needs a new art id.

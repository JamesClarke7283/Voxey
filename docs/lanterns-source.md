# Soul lanterns and chains

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_lanterns/init.lua` and `register.lua`. The implementation is original GDScript using the source as a behaviour reference; all art is original procedural code.

## Why it mattered

The copper family's own notes recorded that its **lanterns and chains** were absent, because in the source those nodes belong to `mcl_lanterns` rather than to `mcl_copper`. This batch closes that gap for the iron and soul variants.

| Node | Light | Notes |
|---|---|---|
| Iron lantern | 14 | Already present |
| **Soul lantern** | **10** | Lit by a **soul torch**, in the source's `soul_firelike` group |
| **Chain** | 0 | A thin metal column that blocks hang from |

The chain is what makes a **hanging lantern** possible: the source lets a chain hold another chain or a lantern below it, so a lantern can be suspended from a ceiling rather than only placed.

## The bug this batch caught

The soul lantern's light level exposed a real defect. Voxey stores a node's light in its data table, but the **light emitter is a separate function** — so a node can claim a light level and still emit *nothing* if the emitter does not know about it.

My probe showed the data field said 10 while the plain lantern's data said 0, which led me to the emitter. A placed soul lantern would have been a **dark light source**: craftable, placeable, listed as a light level, and emitting nothing. The test now asserts `Pasture.emission` directly, which is the value the lighting engine actually uses.

Voxey has since had this shape of bug twice — the infested-block disguise and this — both cases where a node's *data* was right and the consumer did not know about it.

## Recipes

Both are the source's own:

- **Soul lantern**: the iron-nugget ring (eight nuggets) around a **soul torch**. The test asserts the recipe takes a soul torch specifically, not an ordinary one, since substituting would make the two lanterns interchangeable.
- **Chain**: nugget, ingot, nugget down a column.

## The second bug: a node missing from the texture table

Voxey paints a node's texture through `VillageArt.pixel`, which dispatches on the
node's **id**. It also maintains an explicit `BLOCKS` table that the **atlas**
walks, so a node in that table gets its own painted tile through the same
function.

Both new nodes were absent from it. The consequence is narrower than "invisible":
`Nodes.tile` returns a shared generic fallback for any node outside the table, so
the soul lantern and the chain would not have had *no* art — they would have shared
one generic tile with every other node outside the table, and their own art
functions would never have been called.

The distinction matters. Checking the fallback is what showed the difference:
masonry blocks, cracked bricks, infested blocks, magma and the trapped chest are
all also outside `BLOCKS` and render correctly, because they are drawn through
`VillageArt.pixel` by id and never need an atlas entry. The soul lantern and the
chain are different: they are shaped nodes whose art is reached through the atlas
tile, so they did need an entry, and without one their hand-written art was dead
code.

The test now asserts both are **in the table** and get their **own atlas tile**
rather than the shared fallback, and that their art differs from the iron
lantern's. It also checks the chain's tile is mostly transparent, since a chain is
a narrow column rather than a cube.

## The third bug: sixteen ids lost from the texture table

Checking whether the new nodes needed texture-table entries led to a bigger find.

`BLOCKS` is the table the atlas walks to paint nodes' art. Diffing it against the
committed version showed **sixteen ids had been dropped from it** by an earlier
edit in this session: the eight masonry blocks (`1150`-`1157`), the six bastion
blocks (`1100`-`1105`) and both fire nodes (`1117`, `1118`).

Those nodes were rendering with the **shared fallback tile** — a dark speckled
pattern meant for something else — instead of their own art. Nothing errored. The
blocks appeared, were craftable, mineable and solid, and simply had the wrong
texture.

This is the same class as the two bugs above, and the most consequential, because
it silently affected fifteen features that had already been verified as working.

The fix restores the lost ids and adds every node this batch introduced. The test
now asserts the sixteen restored ids keep their entries, that each new node
resolves to its own tile rather than the fallback, and that no two of the nodes
under test collapse onto one another.

## A chain must not block movement like a cube

The chain's mesh was already a narrow column, but its **collision box was a full
block**. A thin decorative chain would therefore have been an invisible wall down
the middle of a tile: the player could see through it and could not walk through it.

The source gives a chain a sixteenth-of-a-block collision box. `collision_boxes`
now returns that, and the test asserts the box is narrower than half a block *and*
matches the source's width, comparing against a full block so the difference is
explicit.

## Recorded source gaps

- **No floor/ceiling lantern variants.** The source registers each lantern twice, as `_floor` and `_ceiling`, so a lantern hangs from a ceiling as well as standing on a floor. Voxey has one node per lantern, placed on a surface.
- **No animated flame.** The source's lantern textures are 3.3-second vertical animations. Voxey's are static procedural art.
- **Copper-coloured lanterns and chains remain open.** The source registers copper lanterns and chains through the same module with their own oxidation chains, so they need the decay-chain system extended to lantern nodes. That is recorded rather than approximated.
- **No copper bars or copper torch.** Those belong to `mcl_panes` and `mcl_torches` in the source, and are recorded as their own gaps.
- **Chains do not yet hold a lantern in play.** `Lanterns.hangs_from_chain` answers the source's question about what may hang from a chain, and the test asserts it, but the placement path does not yet use it to attach a lantern below a chain — the interaction is the next step.

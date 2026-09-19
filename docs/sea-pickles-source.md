# Sea pickles

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_ocean/sea_pickle.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or texture is copied.

## Eight nodes from two axes

Four sizes, each in a lit and an unlit form — eight nodes in total, exactly as the source's loop registers them.

| Size | Light when lit |
|---|---|
| 1 | 6 |
| 2 | 9 |
| 3 | 12 |
| 4 | 15 (the source maximum) |

An unlit pickle emits no light. This is what the sizes are *for*: a bigger pickle lights more.

## Where it grows

Sea pickles live on **dead brain coral**, and nowhere else. The living brain coral block is not a valid parent, and neither is another species' dead coral. Voxey's coral is already implemented, so this uses the same dead brain coral block the source requires.

## Behaviour

- **Growing.** Placing a pickle on another grows it one size, up to four. Growth keeps the lit or unlit form it had.
- **Water.** The lit form requires a water source **directly above** it — water to the side does not count. This is because the source draws pickles as `plantlike_rooted`, so the node carries its parent block.
- **Toggling.** The source's ABM swaps between lit and unlit in **both** directions on the same 17 second interval with a 1-in-5 chance that coral death uses: a watered pickle lights up, an unwatered one goes dark.
- **Bone meal.** Grows the pickle one size, then attempts to spread to the source's own **sixteen offsets**. Each pickle it creates is randomised to a size of one to three, and a spread only succeeds where a valid parent exists.
- **Drops.** Breaking one yields one item per size — a size-three pickle drops three.

## Recorded source gaps

- **Pickles now generate naturally.** [Ocean ruins](ocean-ruins-source.md) place sea pickles on dead brain coral in warm seas, which is the source's own route, so they are found in survival rather than only crafted.
- **The animated pickle texture is drawn procedurally.** The source gives each size an animated frame set and the parent block's own tiles; Voxey draws the stalk from its pixel-sprite system over the parent's tile.
- **The source's separate `_off` node names are collapsed into one stride.** The reference registers literal `sea_pickle_<n>_off_<parent>` names; Voxey uses a four-apart lit/unlit run, which is the same eight nodes with a simpler lookup.
- The source's `node_dig_prediction` and `after_dig_node` parent-restoration behaviour has no direct equivalent, since Voxey stores the parent block as its own node.
- Sea pickles craft into lime dye in the source, which is not wired here.

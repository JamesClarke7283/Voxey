# Trapped chests

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_chests/init.lua` (`mcl_chests:trapped_chest_small`). The implementation is original GDScript using the source as a behaviour reference; the texture is original procedural art.

## Why it mattered

A trapped chest is a chest that **emits a redstone signal to its neighbours while it is open**. That is its entire purpose, and it is why the source uses one rather than an ordinary chest in the jungle temple: the treasure sits behind dispensers, so opening it fires them.

It is also the ordinary way to build a chest alarm or a hidden door — a player lines a chest with wire and a lamp, and knows when someone has been in it.

## What the source does

The source registers **four nodes** — `trapped_chest_small`, `trapped_chest_small_on`, and the left and right halves of the large chest — and swaps between them as the chest opens and closes. The signal is sent from the `_on` node to adjacent blocks.

Voxey uses **one node** and records the open state in the block's saved state, which is the mechanism its other stations use. The behaviour is the same:

| State | Signal |
|---|---|
| Closed | 0 |
| Open | 15 to adjacent blocks |

The state is stored, so a save keeps it.

## The two read paths

A trapped chest's signal has to be visible on **both** paths a redstone consumer uses, and getting only one right would look plausible while failing in play:

1. **`output`** — what a wire, repeater or piston reads from a neighbour. A trapped chest is not a tracked circuit node, so the signal is reported there explicitly.
2. **`container_signal`** — what a comparator reads. This is also where every other special container reports (beehives, jukeboxes, cauldrons, composters).

The first version wired only `output`, and a probe showed the circuit returning **0 while the chest was open** — because a container is never a tracked node, so that branch was unreachable. Both paths are now wired, and the test asserts a **real wire becomes powered to 15** when the chest opens and drops to 0 when it closes.

Note that a trapped chest's signal is *not* its fullness — that is a comparator's separate reading, which already works for any container. The open signal is an addition on top, which is why it is checked before the fullness path.

## The recipe

The reference's own recipe, from `mcl_temp_helper_recipes`: shapeless iron ingot, stick, any wood and a chest. It is the source's, not an invention — the reference adds it precisely because a trapped chest is otherwise unreachable, and Voxey has no tripwire hook either. An earlier draft of this module invented a tripwire-hook recipe; reading the source showed the real one.

## Recorded source gaps

- **No separate `_on` node.** The source swaps node names to show a lit chest. Voxey records the state in block data instead, so the chest looks the same open or shut. The signal — the part that matters — is unaffected.
- **No large trapped chest.** The source registers left and right halves so two chests join into a 54-slot container. Voxey's chests do not have per-material halves for this block.
- **No tripwire hook.** The source's trapped chest is normally built from one in Minecraft proper; Voxey has no such item, so the reference's own fallback recipe is the route here.

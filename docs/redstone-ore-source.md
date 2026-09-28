# Lit redstone ore

Voxey follows `ITEMS/mcl_core/nodes_base.lua`:71-149 and
`ITEMS/mcl_deepslate/deepslate.lua`:57-68 in the supplied Mineclonia checkout. The
implementation is original GDScript using the source as a behavioural reference.

## The state machine

The source builds "redstone ore glows when touched" out of **two nodes** on one
node timer:

- `redstone_timer = 68.28` (`nodes_base.lua`:71).
- The **unlit** node carries `on_punch` *and* `_on_object_over`, both
  `redstone_ore_activate`, which writes the current node's `_mcl_ore_lit` into the
  cell and starts a fresh window.
- The **lit** node is the same ore with `light_source = 9` and
  `not_in_creative_inventory = 1`. Both of its hooks are `redstone_ore_reactivate`,
  which only restarts the timer — so the window follows the **last** touch and
  standing on lit ore keeps it lit.
- `on_timer` writes back the current node's `_mcl_ore_unlit`, so ore nobody touches
  reverts.
- The deepslate pair is the same machine on the deepslate variants; its lit node
  also names the unlit deepslate ore as its Silk Touch drop.

`scripts/redstone_ore.gd` registers the two hidden lit nodes (`11590`, `11591`) at
light 9, and `activate` is both hooks at once: it lights an unlit ore or restarts a
lit one's window. Voxey's punch path is `player.gd`'s `mine` and its walk-over path
is the same stand cell the source samples, run every step rather than on the slow
tick.

## Experience and drops

Both forms carry `groups.xp = 7`, and the lit node's drop table is identical to the
unlit one's — four or five redstone, `max_items = 1`. The lit form is therefore
**not** a separate item: `item()` names the unlit ore, which is what `Nodes.drop`,
`Nodes.pick_item` and the source's own `_mcl_silk_touch_drop` resolve to, and
`xp()` is the single accessor for the 7, routed through `Nodes.ore_xp` so a break
pays exactly once from whichever form it was in. No second payout is added in the
module.

## Persistence

The source keeps node timers in the world database, so a timer there survives its
block leaving memory. This port cannot: a column's clocks are dropped when the
column unloads (`unload`) and a full fresh window is re-armed when the lit cell
comes back (`registered`). The lit node itself **is** saved, because it is an
ordinary `world.edits` entry, so a reloaded world shows a lit ore that reverts one
window after it is revisited rather than mid-count. That choice is stated in the
module header.

## Verification

`tests/redstone_ore_checks.gd` (32 checks) asserts the registry (both lit nodes
exist, light 9, hidden), the family mapping, the activation and the 68.28-second
revert, that a second touch restarts the window rather than letting the original
expire, the re-index on load, the 7 experience, the drop resolving to the unlit
ore, and that pick-block never hands back the hidden id.

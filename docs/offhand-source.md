# The second hand (offhand)

Voxey follows the supplied Mineclonia `mods/HUD/mcl_offhand/init.lua`. The implementation is original GDScript using the source as a behaviour reference; no source code or texture is copied.

## Why it mattered

The offhand is not a decorative extra slot. Three other systems depend on it, and before this Voxey had no such slot at all:

| System | What it needed | What Voxey did instead |
|---|---|---|
| [Shields](shields-source.md) | Carry the shield in the second hand while a weapon stays in the main hand | **Borrowed the head armour slot** |
| [Totems](totems-source.md) | A totem in either hand | Main hand only |
| Torches | `offhand_placeable` placement | Not implemented |

The shield's stand-in was a real defect: **wearing a helmet could silently disable your shield**, because both competed for `armor_slots[0]`. The source has no such conflict — the shield lives in a second hand that armor never touches.

## What the source does

`mcl_offhand` gives a player a dedicated `offhand` inventory list, one slot. Three things read it:

1. **`get_wielditem` plus offhand fallback.** A totem, a raised shield and several other checks ask for the main hand first and then the second hand.
2. **`mcl_offhand.place`.** On use, if the main hand cannot place and the second hand holds an `offhand_placeable` item, the item is placed from there and consumed from there. **Torches are the only `offhand_placeable` group in the game.**
3. **A HUD slot.** The second hand is drawn and is separately clickable.

## What was implemented

- **A real slot.** `player.offhand_slot`, separate from the hotbar and the armor column.
- **Carrying.** `player.carries(id)`, `player.offhand_id()`, and `player.consume_carried(id)` which returns `"main"`, `"offhand"` or `""`. The main hand keeps priority, matching the source's `get_wielditem` order.
- **Shields.** Raise from the second hand. The armor-slot stand-in is **gone**, so a helmet no longer displaces a shield. Wear lands on the copy of the shield where it is actually held.
- **Totems.** Carried in either hand, consumed from whichever supplied it. A totem in the second hand leaves a weapon in the main hand, which is how the source uses it.
- **Torches.** Placed from the second hand when the main hand cannot, and consumed there — one item, not the stack.
- **Persistence.** The slot saves and reloads with the world; a carried shield or totem does not vanish on exit.
- **Death.** The second hand's contents go into the recovery chest alongside everything else.
- **HUD.** A `2ND HAND` slot in the gap between the armor column and the pouches, exchange-on-click with the cursor.

## Recorded source gaps

- **Only torches are placeable from the second hand.** That is the source's own restriction — `offhand_placeable` is set only in `mcl_torches/api.lua` — not a Voxey omission.
- **No offhand HUD art matching the source's.** The source draws a sized, wear-aware icon with its own textures. Voxey reuses its existing `ItemIcon` for the slot, which is consistent with how every other Voxey slot is drawn.
- **No banner-shield offhand interaction.** The source's `mcl_offhand` banner-shield combination is part of the banner system's own gaps, recorded in [banners](banners-source.md).
- **No second-hand swipe animation.** The source's offhand has its own HUD animation for placing; Voxey places the node and consumes the item without a separate second-hand swing.

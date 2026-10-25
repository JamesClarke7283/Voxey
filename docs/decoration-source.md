# Decoration and archaeology

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_flowerpots/init.lua`, `mods/ITEMS/mcl_armor_stand/init.lua`, `mods/ITEMS/mcl_pottery_sherds/init.lua` and `mods/ITEMS/mcl_sus_nodes/init.lua`. The implementation is original GDScript using the source as a behavioral reference; all art is original procedural code.

## Flowerpots

Source's allowed-plant set is not a group: it is exactly the `registered_pots` table, keyed by item, and there is no height or size test at runtime despite the in-game text. Voxey accepts the same categories it has plants for — the three ported flowers, both mushrooms, cactus, vines and the six wood saplings.

Source encodes the plant in the node name, so contents need no metadata and breaking simply drops the pot plus the plant. Voxey stores the plant in saved block metadata instead, so one id covers every plant; drops, saves and the visible result are the same.

| Action | Result |
| --- | --- |
| Right-click with a plant into an empty pot | Plant goes in, one item consumed |
| Right-click with the *same* plant, survival | Nothing happens |
| Right-click with anything else, or in creative | Plant comes back out |
| Break the pot | Drops the pot **and** the plant |

The empty pot is three bricks in a U.

## Armor stands

Source's stand is a node plus a non-persisted display entity whose armor lives in the node's metadata inventory, at indices 2–5 for head, torso, legs and feet. It has no limb posing and no nine-part model. Voxey keeps the same four slots, stored in the node's saved state because Voxey has no per-node metadata inventory, and the same rule that the entity is only a display.

- Armor goes in its own slot; a non-armor item is worn on the torso, which is where a held item visibly sits.
- Right-click with an empty hand removes the last-placed piece.
- Punching a stand with nothing left to remove rotates it, matching the source's screwdriver rotation.
- Breaking returns the stand and everything it wears.
- Stored pieces survive saves and area reloads.

## Pottery and suspicious nodes

All 23 source sherds are registered with their own pattern names and procedural motifs. Ocean ruins, desert temples, trial chambers and [trail ruins](trail-ruins-source.md) supply the implemented acquisition routes. [Desert wells](desert-wells-source.md) now supply Arms Up and Brewer, completing all 23 source sherd routes.

A decorated pot carries one pattern per face, four faces, and **rotates with the block's facing** so a pattern stays on the side it was built against. Crafting is the source's plus shape of four sherds or bricks; a plain brick contributes a blank face.

| Break result | Outcome |
| --- | --- |
| Ordinary | Base plus one item per face, in face order; a blank face yields a brick |
| Silk Touch | The whole pot, with its patterns intact |

Suspicious sand and gravel keep the source's falling-node group, so they fall when unsupported, and they revert to plain sand or gravel when emptied.

Brushing follows the source exactly:
- The loot is rolled **once**, on the first stroke, and that result is fixed for the node — leaving and returning cannot re-roll it.
- The stage starts at 1 and advances with a 1-in-3 chance per later stroke, completing at stage 4. The minimum is therefore four strokes and the expected is about ten.
- One completed node costs the brush exactly 1/64 of its life, so the source's 64-use brush finishes 64 nodes.
- Breaking a suspicious node loses its contents and drops the plain node instead.
- Brushing an ordinary block does nothing.

The brush is a feather over a copper ingot over a stick, as in source.

## Verification

`godot --headless --path . --script res://tests/lifecycle_runner.gd -- decor`

The fixture exercises the flowerpot whitelist including refusals, plant insertion, the same-plant no-op, emptying, and breaking dropping both pot and plant; every armor slot, removal order, rotation, breaking returns, and a save round trip preserving stored armor; all four sherds and their distinct motifs; the exact source 7×7×7-style plus-shape craft with per-face patterns including blanks; face rotation with the block's facing; ordinary and Silk Touch breaking; the single fixed loot roll and that re-brushing yields nothing more; the 1/64 wear cost; every weighted loot entry reachable with counts inside their source ranges; that suspicious nodes fall; and that every node builds a mesh and icon. Final focused result: **87 passed, 0 failed**.

## Remaining differences

- **Current archaeology pools are exported from source.** [Trail-ruin notes](trail-ruins-source.md) describe the six active tables, fixed seeds and corrected ocean weights. The reference comments out the sniffer egg, three future trim rewards, Relic and lead entries; those are not invented. Untagged suspicious blocks have no loot. Desert wells supply the last two sherd routes.
- **The armor stand has no hands.** Source's stand maps armor to four slots and everything else to the entity's hands; Voxey has no separate hand slots, so a held item is worn on the torso.
- **Flowerpot plant list is shorter.** Source names 36 plants including azalea, mangrove propagule, crimson and warped fungi and roots, and bamboo. Voxey has not ported those species, so they are not accepted yet.
- **Source's four-brick pot guard is a no-op.** `old_craft_grid[1][2]` indexes an ItemStack userdata with a number, which is always nil, so a four-brick craft writes an empty pattern list in source too. Voxey stores four blanks, which is the intended and equivalent behaviour.

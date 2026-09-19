# Oak signs

Voxey now has a complete oak sign acquisition and writing loop: six oak planks and one stick make three signs at a crafting table; signs stack to sixteen, place on floors or walls, open a native text editor, accept all sixteen existing dyes, retain their writing through a save/restart, and drop an unwritten canonical sign when broken or detached.

## Reference and license

The reference is the local Mineclonia checkout at `/home/impulse/.minetest/games/mineclonia`, inspected on 2026-09-16:

| Source | Behavior | SHA-256 |
| --- | --- | --- |
| `mods/ITEMS/mcl_signs/init.lua` | Placement, angles, selection, Unicode normalization/wrapping, writing, dye/glow, text entities | `62dc86a1e9e5c63407da8a1bf5832d59c58847b0b42632dab3f850e1c1a3b4cd` |
| `mods/ITEMS/mcl_signs/characters.tsv` | 511 supported character entries | `b9fda43136a3904aabcb6356804aed970edb56e470b210240e6d4499803014ca` |
| `mods/ITEMS/mcl_trees/api.lua` | Per-wood recipe, canonical wall item, ten-second fuel | `fe4f42d901cb0248e442777c6abe6464ca4eb033da2f0b6067b7edc48468161d` |
| `mods/ITEMS/mcl_dyes/init.lua` | Exact RGB values and consumption rules | `b6d9efe40133a7914a3c6383567f864542e1a9f73e5294b655a8f716c49ba292` |
| `mods/CORE/mcl_attached/init.lua` | Airlike support removal and canonical drops | `39f1f2c5a34e4a7c2d9dd8170143c96ef81bae97f9d1870baffc60bcfb5377ec` |

The sign module declares its code MIT; its notice is retained in [licenses/Mineclonia-signs-MIT.txt](licenses/Mineclonia-signs-MIT.txt). Its font is declared CC0 and its models GPLv3 in the source README. Voxey uses original procedural geometry and a native monospace font, and does not copy the source models or bitmap font. Other referenced Mineclonia modules retain the project's existing GPL attribution.

## Implemented source behavior

- IDs 6600–6603 are wall orientations; 6604–6619 are standing angles. Only 6600 is a obtainable item. Standing rotation has **sixteen** angles: the source divides the player's angle by 1.5 before quantizing to param2 steps of 15, giving physical steps of 22.5 degrees.
- Initial placement requires a walkable supporting block or another sign. Ceiling placement is rejected. Signs remain non-solid while using the source selection boxes. Replacement of buildable plants, fluids, or snow checks the actual supporting block behind the replaced cell.
- Later support checks follow the source's airlike test, which differs from initial placement. Changing an existing backing to water does not detach it. In the currently represented Voxey nodes, air is the airlike case; the source Nether/End portal definitions are nodeboxes and the gateway is a normal node. Removing support drops one plain sign even when the player is creative.
- The saved station contains bounded text, exact source dye color, glow, a written flag, and an integer identity. Node removal erases station data, removes the visible text, and closes any editor for that position. Loading a chunk restores its station and validates support after edits are reconciled.
- Pistons carry the station and stable sign identity, as `mcl_pistons/api.lua` copies metadata. Support checks are deferred until the complete push/pull finishes; an unsupported destination drops one plain sign rather than losing writing in place or dropping twice.
- Normal right-click consumes the interaction even when rewriting is disabled. Sneaking bypasses it, allowing placement against an existing sign. Dye handling happens first, including during sneak; survival consumes one dye even when the color is unchanged, and creative consumes none.
- Text is converted by Unicode codepoint while preserving the source's one-based UTF-8 **byte-index** bound: a character whose first byte is below 256 is retained whole. Carriage return terminates conversion in the actual source. Six newline classes, breaking whitespace/hyphen classes, nonbreaking whitespace, and the four-line wrapping algorithm are ported directly.
- Wrapping normally targets fifteen characters. A forced long-word break appends a sixteenth hyphen glyph; long runs of breaking characters have another source quirk where their branch bypasses the length check. These cases are not incorrectly advertised as a hard sixty-character input limit. Unsupported glyphs use a replacement character, and the source's supported-character list is retained.
- The source setting `mcl_signs_editable` defaults false. Voxey exposes its equivalent as the saved boolean rule `signsEditable`; `/gamerule signsEditable true` enables rewriting. Initial placement always opens the editor. The old sign help claiming that ordinary right-click always edits does not match its default code.
- The glow helper preserves the source rules: enable self-lit text, change only the default black color to `#7e7e7e`, and keep dyed black unchanged. Dyeing does not remove glow. A glowing sign does not become a neighboring light emitter.
- The source help claims bone meal removes color/glow, but its sign node has no bone-meal callback. **Bone meal and raw ink sacs do nothing and are not consumed** in this implementation, matching the actual code.

## Native adaptations and remaining scope

The editor uses a Godot TextEdit with a live four-line preview. Done commits the draft; Cancel or Escape discards it. Resizing preserves the draft. A session records dimension, node state and persistent sign identity, so a stale editor cannot write onto a replacement block. This is an intentional transaction boundary: Mineclonia's receive-fields handler can receive text on form exit and checks the obsolete metadata key `text`, although it actually writes `utext`.

Original oak plank geometry and native monospace text replace source textures. The text is top-aligned to the board, front-facing and depth-tested. Exceptionally long source lines are clipped to nineteen central glyphs, approximating the source's 115-pixel centered canvas; font shapes and partially clipped edge pixels are not bitmap-identical. Native font fallback depends on the platform. Voxey retains its existing break-speed model and gives signs a one-second base hardness with an axe preference and hand harvesting; the source uses autogroup indices without specifying sign hardness directly.

There is **no obtainable glow ink sac or glow squid yet**. The saved metadata, rendering and tested `apply_glow` helper are ready, but no substitute item or survival recipe is invented. Other wood families, hanging signs and source bitmap-perfect typography are not implemented by this oak batch. Its material/orientation helpers leave room for further families.

## Integration and verification

`Signs` owns recipes, bounded text, geometry, placement/use, metadata/support, native editing and text display. The shared integrations are deliberately narrow:

- Nodes registers the canonical item and twenty states, stack/fuel/drop/tool semantics and non-solid transparency.
- Inventory installs the source recipe; ItemIcon uses the procedural sign model.
- Player dispatches sign use before held items and uses the placement helper and source selection/crack geometry.
- BlockMesher generates sign boards/posts in both terrain and standalone item meshes.
- VoxelWorld registers stations, validates loaded supports, handles edits and raycasts the source boxes.
- VillageSurvival rebuilds written text with its existing visible-station display lifecycle.
- GameRules persists rewriting; the game menu preserves drafts on resize and discards them on Escape.

Run `godot --headless --path <minimal-project> --script res://tests/lifecycle_runner.gd -- sign`. The checks cover source text edge cases, every wall/standing state, the recipe and item registry, native editor/resize/Escape, keyboard dispatch and touch sneak, all sixteen dyes and creative consumption, support changes, precise raycasts, stale editor prevention, a real game save/reload that recreates visible text, and piston push/pull/detachment. Final focused result: **106 passed, 0 failed**, including the startup check, with no script errors.

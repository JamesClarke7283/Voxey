# Buttons and pressure plates

`scripts/redstone_inputs.gd` adapts the Mineclonia checkout supplied at `/home/impulse/.minetest/games/mineclonia`, inspected on 2026-09-16. Attribution: Mineclonia, MineClone and Mesecons contributors; adapted behavior is covered by [GPL-3.0-or-later](licenses/Mineclonia-GPL-3.0.txt). Meshes and material textures use original Voxey procedural artwork.

| Source file | SHA-256 |
| --- | --- |
| `mods/ITEMS/REDSTONE/mcl_buttons/init.lua` | `1076a0c2cc0b687110d66dfe19f29405b2200038f64f8913f225d2826cccee36` |
| `mods/ITEMS/REDSTONE/mcl_pressureplates/init.lua` | `be47a239ca6bf5220eae740c18fbb8cb7972152edcb13aea0c6446d9437960dc` |
| `mods/ITEMS/mcl_trees/api.lua` | `fe4f42d901cb0248e442777c6abe6464ca4eb033da2f0b6067b7edc48468161d` |

Additional references are `mods/ITEMS/mcl_stairs/api.lua` for placement on full slab/stair faces, `mods/CORE/mcl_util/environment.lua:526` and the installed Luanti `builtin/game/falling.lua` for attachment checks, `mods/ITEMS/mcl_bows/arrow.lua` and `mods/ITEMS/mcl_tridents/init.lua` for projectile callbacks, and entity collision properties in `mcl_throwing`, `mcl_potions` and `mcl_boats`.

## Materials and acquisition

Buttons and plates are available in stone, polished blackstone, and oak, spruce, birch, jungle, acacia and dark oak. Gold and iron add light and heavy weighted plates. Every button crafts from one block of its corresponding stone/planks; every plate crafts from two matching blocks in a horizontal row, except weighted plates which require gold or iron **ingots**. All recipes fit the hand grid and work through the recipe guide. Wood species cannot be mixed for a plate.

Legacy stone item IDs remain 215 (button) and 216 (plate). Other button items are 6908, 6916, 6924, 6932, 6940, 6948 and 6956; hidden IDs in each eight-ID group encode attachment faces. Plates use 6971–6979. Only the 18 canonical items appear in the inventory catalogue; 58 placed IDs cover all orientations and materials. Pressed state lives in metadata rather than a separate item. Every button/plate has source hardness 0.5. Axes are preferred for wood, pickaxes for other materials; buttons can be harvested by hand, and stone/metal plates require a pickaxe. Wooden buttons burn for five seconds and wooden plates for fifteen.

## Buttons

Buttons attach to any of six faces. Placement requires a full solid opaque block or an eligible full slab/stair face. Ongoing source `attached_node` validation only requires that the backing block remains walkable, so replacing a backing block with glass preserves an existing button even though a new button cannot initially be placed on glass. Unloaded neighboring support is unknown rather than empty. Removing support drops one canonical item.

The unpressed model projects 2/16 of a block, and pressing reduces that to 1/16. Its face measures 8/16 by 4/16. Selection, held/dropped models, inventory icons and circuit visuals share these dimensions; actors and projectiles pass through the button. Stone and polished blackstone emit a one-second pulse, while wood emits a 1.5-second pulse. An already pressed button has no active press callback: another use or arrow does not extend its pulse. Buttons emit weak power 15 in every direction and strong power only into their supporting block.

Actual arrow and trident collision hooks activate wood buttons when the projectile lodges in the button's backing block from the button side. Hitting the opposite side of that backing block does not trigger it. A stuck arrow does not indefinitely hold a button on.

**Declared material rule versus source callback bug:** the supplied source sets `push_by_arrow=false` for stone and polished blackstone and `true` for wood, including its descriptive text and group. Its shared registration nevertheless installs `_on_arrow_hit` unconditionally, and the arrow/trident callers do not check that group. Voxey deliberately follows the source's declared wood-only rule rather than reproducing this unconditional callback anomaly.

Flowing water washes away buttons and drops their canonical item. Pistons destroy them with one drop instead of moving them; sticky pistons do not pull them.

## Pressure plates

Unpressed plates occupy 14/16 by 14/16 blocks and are 1/16 high; pressed plates are 1/32 high. They are selectable but have no actor collision. Plates require a walkable block below, including glass and partial blocks, following the source attachment rule.

Stone and polished blackstone plates detect players and mobs. Wooden and weighted plates detect physical objects as well, including dropped stacks, boats, primed TNT, arrows, tridents and thrown potions. Attached boat/horse riders and boat passengers are excluded, preventing double counting; the physical mount still counts. Nonphysical snowballs/eggs/ender pearls, magic projectiles and lingering potion clouds are excluded. Future physical entity types need to be added to the explicit engine adapter.

Detection follows source contact tests: the object's position must be within one block of the plate-cell center, its collision feet must be at or below the plate's 1/16-height plane, and its X/Z collision bounds must overlap the inset plate area. A player merely standing above the plate does not activate it. Each entity counts once, regardless of the number of items in a dropped stack.

Ordinary plates output 15. Gold plates output one per entity, capped at 15. Heavy iron plates output `floor(entity_count / 10)`, capped at 15. This matches the supplied Lua's division followed by Luanti's integer `param2` conversion: a temporary isolated Mineclonia server running the installed Luanti 5.16.1 verified counts 1→0, 9→0, 10→1, 11→1, 19→1, 20→2, 149→14 and 150→15. Therefore one through nine entities visibly depress an iron plate while its output remains zero; the separate `input_pressed` flag preserves that distinction in rendering, selection, observers and saves.

Eligible contact refreshes a one-second release timer; after contact ends, the output persists for that remaining time. Plates emit weak power horizontally and downward, never upward, and strongly power only the block below. Source plates have `dig_by_piston` but no `dig_by_water`: pistons destroy them with a canonical drop, while fluid flow cannot replace them.

## Persistence and simulation

The existing 10 Hz circuit simulation calls `tick`. One spatial entity index is built per circuit step when any plate is active; each plate checks only its 27 neighboring cells. Metadata stores remaining seconds, integer output and the pressed flag. Paused games and unloaded columns do not advance control timers. JSON-loaded timer/power values are normalized, and removing a control clears its circuit state.

Legacy wall/ceiling stone buttons stored their attachment in a `support` array. Column registration preserves that metadata, then migrates the placed ID **after** worker edits have been reconciled. Delaying the migration prevents a recursive setter from overwriting the converted ID. World cells, persistent edits and the circuit index then agree. Support validation runs after migration and also checks existing controls whose backing column has just returned.

This is an adaptation to Voxey's saved metadata, fixed simulation clock and existing entity models. It does not replace those systems with Luanti's scheduler or physics. Button feedback uses Voxey's existing procedural sound. Additional wood species beyond the six classic families remain outside this batch.

## Verification

Run `godot --headless --path . --script res://tests/lifecycle_runner.gd -- input_device`.

The fixture exercises actual player use and all 48 material/face placement combinations, matching small raycast geometry, both crafting paths, support rules, exact pulse duration and repeat-use rejection, weak versus strong power, living/physical object filtering, dropped-stack weights and thresholds, real arrow/trident collisions, piston/fluid drops, and actual save/load/streaming migration. It also checks a pressed zero-output iron plate and attachment across an unloaded column boundary. The final focused run passed all 300 checks with no script errors.

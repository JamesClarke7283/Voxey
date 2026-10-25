# Fences, gates and walls

Reference: `/home/impulse/.minetest/games/mineclonia`, inspected 2026-10-24.
Rules and geometry retain GPL-3.0-or-later attribution. Artwork is procedural.

The loaded registry contains 26 wall materials and 14 fence/gate pairs. All are
available, alongside six existing native wall extensions: 60 inventory items.
The two newly added walls are red sandstone and resin brick. The latter uses
six loose resin bricks in its source recipe, rather than six resin-brick blocks;
its appearance uses the resin-brick-block texture. Red Nether brick fences use
two Nether brick items and four blocks and yield three fences. Their gates use
four Nether brick items and two blocks and yield two gates.

`tools/export_barriers_reference.py` loads the real game, captures its final
registrations, invokes wall and gate callbacks, and queries Luanti's actual
node/collision/selection boxes. `tools/build_barrier_catalog.py` binds the result
to native IDs in `assets/data/barriers.json`. Source groups, recipes, hardness and canonical drops are used directly. Declared
stonecutter lists now pass through the [actual workstation filter](stonecutter-source.md);
resin brick has no valid source stonecutting recipe despite its declaration.

## Wall states and connections

Each source wall has short/tall and pillar/flat states. A straight wall loses its
center post. A solid block above makes its side panels tall without necessarily
restoring the post. A ground torch, pressure plate, standing sign or banner
above restores the post. A wall above supplies additional post and shared-side
rules. Walls connect to walls, full solid blocks and panes. Fences connect by
their registered material groups; Nether brick fences connect to each other.

Collision follows the current checkout's actual boxes: a wall post is 0.75 wide
and 1.25 high; a short flat wall collides along its entire length to height 1.25;
a tall flat wall has height 1.0. These are distinct from older source versions
and from the description claiming every wall prevents ordinary jumping. Fence
collision remains 1.51 high. Closed gates have 1.5-high collision beginning
0.3125 above the floor; open gates have selection geometry and no collision.

Native wall states are stored as IDs, so collision, targeting, meshing, drops,
saves and multiplayer share the same state. Existing unambiguous base IDs are
preserved; extra wall states use 14800–15055. The source only changes a flat
wall's facing when its height or post state changes, and this behavior is kept.
Loaded older canonical wall IDs are reconciled against their neighbors.

Gate placement uses the player's position relative to the target, as Luanti's
placement routine does. Manual use and wind charges toggle the gate and its
saved state. Redstone changes use the existing native solver. Ctrl/touch sneak
bypasses interaction. Source sound assets and the engine's notification-based
redstone scheduling remain adapted.

## Corrected ID collisions

Three later wood fence windows overlapped copper door/trapdoor states. Cherry,
mangrove and crimson fences now start at 15200, 15216 and 15232. Pale oak and
warped retain their original unambiguous IDs. All nine used fence/gate states
are checked against door, trapdoor and stair families.

An old overlapped ID cannot reveal whether a save intended a wood fence or a
copper state. Those IDs retain their copper meaning; no heuristic rewrites
existing copper doors. New wood-fence crafting and placement use the corrected
IDs. Existing unaffected fences and wall materials keep their IDs.

## Leads and persistence

Tying Voxey's existing leads to a fence is a Voxey addition; no lead implementation was found in the reference's loaded mob modules. Use the fence while holding attached animals to tie nearby leads, or use it again to release those anchors when no player-held leads remain. Removing the fence returns each lead once. Each anchor is saved with its dimension and the existing creature identity; farm animals and specialized creatures can hibernate and restore without duplicate mobs or leads. Sleeping anchors retain villager, bastion resident and End city guard identities, horse trust/equipment, names, health and effects. Releasing an anchor restores a dormant animal before deleting the link; animal death returns its lead once. Live anchored AI no longer follows the departing player.

## Verification and remaining scope

`barrier_reference_checks.gd` compares 5,248 wall transitions, 336 gate callbacks,
448 real engine geometry configurations and 432 real crafting queries. It also
checks identities, drops, fuel, item visibility and ID ownership. Live checks
cover placement, panes, height transitions, wind charges, stonecutting and real
save/reload. Network tests verify initial wall/fence state and the host's derived
wall update after a guest changes an adjacent block. `barrier_registry_tour.gd`
renders the resulting material families and recipe guide.

Final validation on 2026-10-24: 14,031 source comparisons, 673 combined
barrier/piston/control checks, 32 focused live checks and 535 core checks pass.
Protocol, host and guest network tests pass, including the new wall-state
exchange. All 17 recorded source hashes match. Rendered world/recipe views were
reviewed, and the Linux pack exports without script errors.

This closes the registered barrier-material inventory and the wall-state model.
Source sounds, detailed mob navigation and the broader redstone scheduling
model remain work for their respective systems. The six native wall extensions
remain explicit additions rather than source registrations.

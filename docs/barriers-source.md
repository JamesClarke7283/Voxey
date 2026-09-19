# Fences, gates and walls

Implemented against the local Mineclonia checkout at `/home/impulse/.minetest/games/mineclonia` on 2026-09-16. Rules and node-box coordinates in `scripts/barriers.gd` are translated from GPL-3.0-or-later Mineclonia sources; see the existing `docs/licenses/` attribution. Voxey uses its own procedural materials, mesher and controls.

## Source evidence and behavior

- `mods/ITEMS/mcl_fences/init.lua`: connected two-rail fences, gates, open/closed selection and collision boxes, manual/redstone interaction, recipes and canonical drops.
- `mods/ITEMS/mcl_trees/api.lua`: oak wood-group connection rules, hardness 2, burn time 15 seconds and plank/stick recipes.
- `mods/ITEMS/mcl_nether/init.lua` and `mclx_fences/init.lua`: Nether brick fence/gate groups and nether-brick-item recipes. Four blocks plus two brick items produce six fences; two blocks plus four brick items produce two gates. Oak yields three fences or one gate.
- `mods/ITEMS/mcl_walls/init.lua`: sixteen neighbor masks, special straight-wall pillars when covered by a solid/wall/fence/torch, six-block-to-six-wall crafting and source collision geometry.
- Wall material registrations in `mcl_core/nodes_stairs.lua`, `mcl_nether/init.lua`, `mcl_end/building.lua`, `mcl_blackstone/init.lua`, and `mcl_deepslate/{deepslate,tuff}.lua`.

There are 35 obtainable items: six classic wood species and Nether brick fences/gates, plus 21 wall materials already obtainable in Voxey. The walls are cobblestone, mossy cobblestone, brick, sandstone, stone brick, mossy stone brick, granite, diorite, andesite, Nether brick, End stone brick, blackstone and its two polished variants, four deepslate variants and three tuff variants. Each supports crafting, source stonecutter inputs, normal tool harvesting and saved block edits. Internal gate facings/open states are hidden from the catalog and drop the base gate.

Fence connections use their source material groups: wood connects to wood fences/gates; Nether brick connects to Nether brick fences/gates. Both connect to full solid blocks. Source walls connect to walls/full blocks; this checkout does not connect them to fence gates. Voxey's full-block test substitutes for Luanti's `solid` group and preserves non-full slabs/stairs as nonconnecting neighbors.

Fence collision is 1.51 blocks high; closed gate collision is 1.5 high, beginning 0.3125 above the floor. Open gates have no collision but retain a narrow selection box. Source walls have a 1.5-high central collision post regardless of the visible connections; Voxey preserves this unusual source behavior instead of silently substituting a modern wall collision model. Collision queries examine the cell below the actor's feet, preventing jumping into the invisible top portion. Targeting uses the actual visual fence/wall boxes, and gates keep the source selection box.

Right-click opens/closes gates before eating or placing items. Ctrl/touch sneak bypasses the gate interaction for placement. Gates face the placement direction and retain it when opening, breaking and reloading. A changed redstone powered state opens or closes them; manual opening remains usable between circuit ticks. The polling circuit solver is a Voxey adaptation of source notification-based redstone.

Fence connections are derived from neighbors during meshing and collision rather than stored as dozens of separate node IDs. Neighbor changes, including a block over a wall across a mapblock boundary, refresh the affected mesh. Drops and held models reuse the terrain geometry; inventory icons show connected fence/wall shapes.

## Leads and persistence

Tying Voxey's existing leads to a fence is a Voxey addition; no lead implementation was found in the reference's loaded mob modules. Use the fence while holding attached animals to tie nearby leads, or use it again to release those anchors when no player-held leads remain. Removing the fence returns each lead once. Each anchor is saved with its dimension and the existing creature identity; farm animals and specialized creatures can hibernate and restore without duplicate mobs or leads. Sleeping anchors retain villager, bastion resident and End city guard identities, horse trust/equipment, names, health and effects. Releasing an anchor restores a dormant animal before deleting the link; animal death returns its lead once. Live anchored AI no longer follows the departing player.

## Verification and remaining scope

`tests/barrier_checks.gd` exercises every connection mask, crafting yields, source group boundaries, tall collision above a voxel boundary, ray passage between rails, real placement/use, redstone edges, drops, anchoring, hibernation and actual disk reload of open/facing gates, walls and dyed named animals. `tests/habitat_tour.gd` renders the features together for visual inspection.

This does not complete all source building families. Other wood ecosystems, red Nether brick, red sandstone, mud, prismarine and resin resources need their acquisition loops before their matching barriers can be added. Seven wood/iron trapdoor materials are documented separately; pane connection rules remain open. Wind-charge gate activation awaits that projectile (the wind-charged potion effect is a different system). Source sounds, engine light propagation and detailed navigation remain adapted.

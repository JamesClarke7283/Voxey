# Trapdoors

Voxey ports the available oak and iron trapdoors from local Mineclonia. Sources are GPL-3.0-or-later; see [the included license](licenses/Mineclonia-GPL-3.0.txt).

| Source, relative to `/home/impulse/.minetest/games/mineclonia/mods` | SHA-256 |
| --- | --- |
| `ITEMS/mcl_doors/api_trapdoors.lua` | `3f33f27278129ebfccd65a339108ed854f2eb4e61327f7b8fbd735f6f3ac0385` |
| `ITEMS/mcl_doors/register.lua` | `ba060eadd9d1815aee97f4e6d6d83248fbee0170a1a40f17a3465bc67db8e3b5` |
| `ITEMS/mcl_trees/api.lua` | `fe4f42d901cb0248e442777c6abe6464ca4eb033da2f0b6067b7edc48468161d` |

## Source behavior and integration

Each material has four orientations, upper/lower placement and open/closed states. Voxey encodes these combinations in stable IDs 5200–5215 (oak) and 5216–5231 (iron); only the canonical closed item appears in the catalog. All states drop that canonical item. Collision and selection use an unbroken 3/16-node slab: horizontal when closed and vertical against the hinge side when open. The original openwork mesh has decorative holes, which do not change collision.

Oak opens by hand or redstone; iron opens only by redstone. Manual oak operation takes precedence over held food. Redstone changes act when the signal strength differs from the previously recorded value: nonzero opens, zero closes. Thus a player can close a powered oak trapdoor until the signal changes again. Orientation, upper-half state and power memory survive ordinary save/reload and piston movement. Open trapdoors are climbable without requiring a ladder below them, as this source declares.

Placement faces away from the player. Clicking an underside or the upper half of a side creates an upper trapdoor; other placement creates a lower one. A removed supporting block does not remove the trapdoor. Placement refuses to intersect the player.

Six planks craft two oak trapdoors. Four iron ingots craft one iron trapdoor. Oak hardness is 3 and its furnace fuel time is 15 seconds, while the source deliberately sets its flammability group to −1. Iron hardness is 5 and it requires an appropriate pickaxe for its drop.

## Remaining gaps

- Mineclonia's wind-charge callback toggles wooden trapdoors, but Voxey does not yet implement that interaction.
- Other Mineclonia wood families remain unimplemented; this batch contains oak and iron only.

## Collision recovery adaptation

Luanti supplies its own nodebox collision handling. Voxey's movement controller instead assumes that an actor starts each movement step outside solid geometry. Merely swapping a trapdoor could violate that assumption: opening beneath a player near the hinge, or closing an upper trapdoor through their body, left every small movement step colliding and the actor permanently stationary until the trapdoor changed again.

`Trapdoors.set_open` now keeps the source state swap and then resolves affected players, creatures and boats. It considers exactly six translations to the new slab's faces, ordered by distance. A correction must end in loaded, collision-free space and its swept body must not cross another solid node. The shortest valid correction wins; velocity toward the resolved plane is cleared. Boat occupants and mounted players follow their moved vehicle or mount. Unaffected actors are untouched.

When all faces are obstructed, the trapdoor still changes state and the actor stays in place. This avoids teleporting an actor through surrounding walls or into unloaded terrain. Recovery adds no global collision scan and does not change the general movement controller.

## Validation

`tests/trapdoor_checks.gd` covers all 32 states, survival recipes, source tool/fuel rules, placement, selection rays, thin collision, right-click priority, iron redstone operation, power-memory edges, climbing, unsupported persistence, canonical drops, piston state retention, model generation and actual disk reload.

The collision regressions reproduce 120 ordinary movement steps after opening at every hinge orientation and after closing an upper iron trapdoor. They also cover a blocked nearest face with a free upper exit, a fully boxed actor, creature recovery, boat hull recovery and preservation of unrelated actors. Run via `tests/lifecycle_runner.gd -- trapdoor`.

## Classic wood expansion

Oak5200 and iron5216 retain all prior state IDs. Spruce5380, birch5396, jungle5412, acacia5428 and dark oak5444 each add sixteen states, using their own renewable planks for two trapdoors from six planks. All six wood variants share the verified placement, power, collision, climbing, piston and fuel behavior. See [trees](wood-source.md) and `tests/wood_crafting_checks.gd`.

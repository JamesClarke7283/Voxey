# Double-plant source notes

Reference: `/home/impulse/.minetest/games/mineclonia`, especially
`mods/ITEMS/mcl_flowers/{init,register}.lua`,
`mods/ITEMS/mcl_bone_meal/init.lua`,
`mods/CORE/mcl_attached/init.lua`, and
`mods/ITEMS/mcl_lush_caves/nodes.lua`.

## Registration, placement, and removal

`mcl_flowers.add_large_plant` (`init.lua:246-415`) gives every plant separate
bottom and `_top` nodes. Both halves are `supported_node`; `after_destruct` on
either removes its matching partner. Placement (`init.lua:263-327`) requires:

- a registered `soil_flower` floor;
- `buildable_to` at **both** the bottom and upper cell;
- night block light at least 8 or full daytime sky light.

The upper-cell check is not merely an air check. Conversely, an existing large
half is not `buildable_to`, even though Voxey's broader `Nodes.plant` category
includes it. `LargePlants.buildable_to` excludes large halves explicitly.

`register.lua:267-299` allocates double grass and double fern with compostability
50 on the bottom only. Voxey IDs are respectively 11426/11427 and 11428/11429.
`LargePlants.BOTTOMS` deliberately remains the original four flowers, so their
terrain selection and two-dye recipe loop do not acquire either herb.

The source support callback is in `mcl_attached/init.lua:17-47,92-98`: an
unsupported node is removed and receives ordinary empty-tool drops. It is not a
creative break and does not inherit a player's shears. Pair removal itself does
not generate a second partner drop.

## Drops and the `overwrite` correction

`register.lua:247-265` defines the ordinary table: one wheat-seed entry with
rarity 8. Both herb bottoms and tops use that table. The Fortune table is a
`discrete_uniform_distribution` with chance 1/8, `min_count=1`, `max_count=1`,
and `factor=2`. At Fortune level L a successful roll therefore yields a count
from 1 through `1 + 2*L`.

The source key is **`overwrite`**, not `override` (`register.lua:264`). The
exported `assets/data/harvesting.json` already contains `overwrite: true`.
`Harvesting.evaluate` must test `rule.get("overwrite",false)` on its failed-roll
branch; testing `override` is a shared-dispatcher typo and is corrected by the
parent, not duplicated in `LargePlants`.

Shears are checked before Silk Touch. Double grass returns
`mcl_flowers:tallgrass 2`; double fern returns `mcl_flowers:fern 2`, from either
half (`register.lua:277,294`; top propagation at `init.lua:395-397`). There is no
`_mcl_silk_touch_drop` on these plants. Silk Touch alone therefore leaves the
ordinary seed table intact. The four existing flowers retain their ordinary
bottom-item drop and two-dye recipes.

## Bone meal and moss vegetation

Small grass and fern callbacks (`register.lua:335-369`) replace the clicked small
plant and a buildable cell above with their double forms. They do not re-run
soil or light placement checks. A blocked upper cell returns `nil`, not `false`.
The common dispatcher (`mcl_bone_meal/init.lua:27-57`) consumes and emits effects
for every result other than `false`; consequently blocked conversion still
consumes. `LargePlants.bone_meal` exposes this as
`{"consume": true, "grew": false}`.

The four existing flowers each register a bottom `_on_bone_meal` that adds one
of that flower (`register.lua:184-186,201-203,217-219,234-236`); the top inherits
it at `init.lua:407`. Their callbacks return nil, so bone meal is consumed. This
behavior is preserved as `duplicate` in `LargePlants.bone_meal`. Double grass and
double fern have no `_on_bone_meal` override: they consume nothing and, crucially,
must **not** inherit the large-flower duplicate callback.

Lush moss (`mcl_lush_caves/nodes.lua:11-46`) selects double grass in its 10.42%
row. It tries the bottom and second vegetation cell; if the latter is not
`buildable_to`, it places short grass instead. Pale oak has the same fallback in
`mcl_pale_oak/plants.lua:149-178`. `place_moss_vegetation` is the shared API; it
does not invent soil or light checks for either consumer.

## Integrated dispatcher hooks

The owned module and shared registrations/consumers are connected as follows:

1. **Content registration** — add 11426 through 11429 to `VillageContent`'s tile
   ID list and add the four corresponding `LargePlants.DATA` entries. Existing
   `MiningNodes`, `Nodes`, compost, inventory art, and harvesting registration
   then use their current generic paths.
2. **Breaking** — replace `game.gd`'s old unconditional large-plant drop branch
   with `if LargePlants.break_node(self,p,id,tool): return`. This preserves the
   existing particles, sound, progress, and clicked-node event while using the
   real held slot for drops.
3. **Live edits/support** — call
   `LargePlants.changed(self,p,old_id,id)` from `VoxelWorld.set_node` on every
   authoritative edit. In `PistonPush.finish`, revisit pending cells with
   `LargePlants.changed(world,p,world.node_at(p),world.node_at(p))`.
4. **Pistons** — include `LargePlants.is_large(id)` in `PistonPush.diggable` and
   route their destruction through `LargePlants.environmental_break(world,p)`;
   both source halves have `dig_by_piston=1`.
5. **Water destruction** — in `Fluids.settle`, add a large-plant branch before
   the generic replaceable/`Nodes.drop` fallback. On water, spawn
   `LargePlants.harvest(before,{"id":0})`; on lava, spawn nothing. The following
   `set_node` then runs the normal paired-removal hook. This prevents water from
   turning double herbs into their unsheared bottom item.
6. **Player bone meal** — route `LargePlants.bone_meal_target(id)` through
   `LargePlants.bone_meal(game.world,p)`. Consume/emit effects from
   `result.consume`, not `result.grew`; if `result` has `duplicate`, spawn that id
   once at p for the four existing flowers. Return after the branch even when
   consume is false so double herbs do not fall through to unrelated placement.
7. **Dispenser bone meal** — before crop/flower fallback, route
   `LargePlants.bone_meal_target(here)` through the same API and handle
   `duplicate` identically. Feed `result.consume` to the existing
   applied/consume/effect path; using only grew would make blocked conversion
   free and would skip the existing flowers' callbacks.
8. **Lush moss** — make the double-grass threshold in
   `AzaleaTrees.moss_vegetation` return `LargePlants.DOUBLE_GRASS`, and replace
   `world.set_node(p+UP,moss_vegetation(rng))` in `moss_cell` with
   `LargePlants.place_moss_vegetation(world,p+UP,moss_vegetation(rng))`.
   Remove the stale “unavailable double_grass” comment. The same helper is the
   correct consumer if pale-oak moss vegetation is wired; no pale-oak vegetation
   dispatcher is claimed by this module alone.
9. **Tests** — load `tests/double_plant_checks.gd` in the integration runner and
   call its `run(t,game)`. Keep the old large-flower bone-meal check: it remains
   source behavior. The new checks additionally prove that neither double herb
   inherits that callback.

`LargePlants.place(game,at)` remains available for a full held-item placement
check. The existing generic player placement can continue its explicit writes
and placed events because `can_place` now guards both cells before either write.

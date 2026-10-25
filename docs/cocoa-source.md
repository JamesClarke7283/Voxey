# Cocoa pods and beans

Reference: the installed Mineclonia tree at
`/home/impulse/.minetest/games/mineclonia`, principally
`mods/ITEMS/mcl_cocoas/init.lua`. Supporting behavior comes from
`mods/ITEMS/mcl_bone_meal/init.lua`, `mods/CORE/mcl_attached/init.lua`,
`mods/ITEMS/mcl_core/functions.lua` (`basic_flood`), and
`mods/ITEMS/REDSTONE/mcl_pistons/api.lua`.

Mineclonia and MineClone contributors own the referenced behavior. Voxey's
GDScript, procedural pod meshes, textures and bean icon are original; the
Mineclonia OBJ/PNG assets are not copied.

## Saved content and geometry

The existing IDs remain unchanged:

| Source node/item | Voxey ID | Ordinary drop |
|---|---:|---:|
| `mcl_cocoas:cocoa_1` | 687 | 1 bean |
| `mcl_cocoas:cocoa_2` | 698 | **1 bean** |
| `mcl_cocoas:cocoa_3` | 688 | 3 beans |
| `mcl_cocoas:cocoa_beans` | 816 | item, stacks to 64 |

In particular, the middle stage does not drop two beans. The fixed drop table
is not changed by Fortune or Silk Touch. Pod nodes stay out of the creative
catalog. Beans retain their existing 65% compostability, brown-dye recipe and
shaped eight-cookie recipe.

`CocoaCrops.boxes(id, facedir)` translates the exact source min/max coordinates
from a `-0.5..0.5` node to Voxey's `0..1` cell. Selection and collision use the
same box:

| Stage | Source `(min x, min y, min z, max x, max y, max z)` |
|---|---|
| 1 | `(-.125, -.0625, .1875, .125, .25, .4375)` |
| 2 | `(-.1875, -.1875, .0625, .1875, .25, .4375)` |
| 3 | `(-.25, -.3125, -.0625, .25, .25, .4375)` |

Source facedir 0/1/2/3 points to +Z/+X/-Z/-X. `SUPPORTS` preserves that order,
and `rotate_box` rotates +Z toward +X. `world_boxes` reads the saved direction;
it does not infer orientation from whichever jungle log happens to be nearby.

## Placement, attachment and metadata

Beans plant only into literal air beside a normal jungle log. Top and bottom
faces are rejected. Axis variants of `mcl_trees:tree_jungle` remain eligible;
stripped jungle logs, jungle bark wood and other log species are not.

Placement computes the source direction as `under - above`, which is the
negative of the clicked face normal. It stores that value in block-state key
`cocoa_facedir`. `grow` carries the value across both ID replacements, and the
existing save/dimension/network block-state snapshots carry it across loads.
An old pod without the key has source-compatible facedir zero.

The later attachment rule is deliberately broader than placement. Source
`attached_node_facedir` checks for a solid support, not specifically a jungle
log. Thus an already established pod remains on another regular solid cube,
and drops its ordinary harvest when that support disappears. An unloaded
support never causes a break. Column reconciliation checks both the pod's own
column and a boundary support when the real neighbor arrives.

## Growth and the bone-meal return quirk

Natural growth has no soil, light or elapsed-time requirement. The source ABM
selects stages 1 and 2 every 50 seconds with chance 1/20. Runtime indexes only
loaded pods, uses a world-seeded RNG and stable coordinate order, and processes
at most eight queued actions per update. Column loading queues one ABM-style
chance roll per growing pod, not free offline growth. Unloading removes active
jobs and indexes but leaves saved IDs and facedir intact. Serials prevent a
job for a removed pod from affecting a replacement.

`mcl_cocoas.grow` has an important non-obvious return contract:

- Stage 1 actually becomes stage 2, but falls through and returns `false`.
- Stage 2 becomes stage 3 and returns `true`.
- Stage 3 and non-cocoa return `false` without changing.

The bone-meal dispatcher consumes only when its callback result is **not
false**. Consequently bone meal on stage 1 grows the pod without consuming
bone meal or emitting the dispatcher's success effects; stage 2 grows and
consumes exactly one; stage 3 does neither. `CocoaCrops.grow` exposes the source
return value, while `bone_meal` separately reports `consume` and actual `grew`
so callers do not have to conflate them.

## Water, lava and pistons

All stages have `dig_by_water=1`, `destroy_by_lava_flow=1`,
`dig_by_piston=1` and `unsticky=1`.

- Water replaces the pod and pays its ordinary 1/1/3 bean drop.
- Lava replaces it without drops.
- Direct piston contact digs it and pays ordinary drops, including during
  creative automation.
- Adhesive side contact does not drag it. If its actual support moves away,
  deferred support validation subsequently breaks it once.

## Survival acquisition and art boundary

No creative-only acquisition shortcut or replacement loot system is added.
The existing survival bonus-chest table can yield one or two beans, and the
existing mineshaft chest loot remains intact. These paths, plus pod drops,
supply planting, cookies, dye and composting.

`mesh`, `pixel` and `draw` are owned procedural helpers. The body follows the
source stage box and `mesh` accepts explicit facedir. They are original visual
approximations, not claims of pixel- or vertex-identical Mineclonia art. The
worker mesher must receive facedir from the saved block-state snapshot; node
IDs and neighboring logs alone cannot disambiguate a pod surrounded by several
normal jungle logs.

Natural cocoa-pod world generation is not added or claimed by this module.

## Required shared integration hooks

The owned module is complete, but these existing dispatchers must call it for
the behavior above to be consumer-visible:

- **`village_content.gd`**: replace the three old pod `DATA` entries and bean
  entry with `CocoaCrops.DATA` (retaining existing `BLOCKS` membership); route
  `crop_drops` to `CocoaCrops.harvest`, correcting middle-stage drops. Existing
  `is_cocoa`/`cocoa_next` callers must use the same three-ID ladder.
- **`village_survival.gd` and `player.gd`**: dispatch `CocoaCrops.use` before
  generic planting/bone-meal paths and remove the legacy placement and cocoa
  bone-meal branches. In particular, do not consume on stage-1 growth. Add the
  selection-highlight branch using `CocoaCrops.world_boxes`.
- **`voxel_world.gd`**: reset/update the runtime; add a cocoa load-hook bit and
  register in both generated-special and reconciled-edit loops; invoke
  `column_loaded`, `unload`, and `changed` (including horizontal support
  neighbors); retire legacy cocoa entries in `growth` and the old `_simulate`
  ladder. Route `collision_boxes`, shaped `raycast`/`shape_hit`, and selection
  to `world_boxes`.
- **`node_info.gd`**: include cocoa in `SPECIAL` so workers index saved pods;
  assign a custom mesh kind. Exclude cocoa from `BOX`, or physics will use a
  full cube instead of the exact shaped collision box. Keep it non-plant and
  transparent, with physical collision enabled.
- **`nodes.gd`**: keep pod nodes non-placeable as creative items and make all
  three generic base-item lookups return bean 816. Counted drops belong to
  `CocoaCrops.harvest`, not the one-item `Nodes.drop` API.
- **`game.gd` / `enchantments.gd`**: mine through the fixed cocoa harvest table
  before generic Silk Touch/Fortune fallback. Do not let enchantments create a
  pod item or alter bean counts.
- **`fluids.gd`**: mark cocoa replaceable and handle it explicitly in `settle`;
  water calls `spawn_drops(..., false)`, lava calls it with `true` (or emits no
  drops), then the fluid node is installed. Avoid the generic one-bean plant
  fallback.
- **`piston_push.gd`**: include cocoa in `diggable`/`unsticky`, dispatch
  `piston_break` in `destroy`, include `world_boxes` in future collision
  geometry, and refresh deferred support positions after movement.
- **`block_mesher.gd`, `voxel_world.gd` remesh snapshots, `village_art.gd`, and
  `village_item_art.gd`**: dispatch the custom mesh kind with per-cell saved
  facedir, call `CocoaCrops.pixel` for pod atlas tiles, and call
  `CocoaCrops.draw` for bean item art. A default-facing worker call is not
  sufficient for oriented pods.
- **`voxey_network.gd`**: retain block-state synchronization and dirty affected
  meshes when `cocoa_facedir` changes, so guests see the authoritative
  orientation. Guests must not run a second growth/drop simulation.
- **Test runner**: load and await `tests/cocoa_crop_checks.gd.run(t, game)` in
  the farming/integration suite after the shared hooks above are installed.

The focused checks cover actual survival mouse placement and all three
bone-meal outcomes, exact/rotated geometry, four saved orientations, support
removal and load reconciliation, fixed enchanted mining drops, water/lava,
scheduled growth and stale/bounded jobs, direct/adhesive pistons, existing
survival loot/recipes/composting, original art, and actual save/load.

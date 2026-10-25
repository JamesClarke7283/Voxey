# Azalea and rooted-dirt source notes

Reference: `/home/impulse/.minetest/games/mineclonia`, chiefly
`mods/ITEMS/mcl_lush_caves/{nodes,init,lg_register}.lua`,
`mods/ITEMS/mcl_lush_caves/schematics/azalea1.mts`,
`mods/ITEMS/mcl_trees/{api,functions,lg_register}.lua`,
`mods/ITEMS/mcl_farming/hoes.lua`, and
`mods/ENTITIES/mobs_mc/wandering_trader.lua`.

## Rooted dirt

`nodes.lua:237-268` is not ordinary farmland soil with a different texture.

- Bone meal changes only literal air immediately below the block into hanging
  roots. An occupied cell rejects the operation (`_on_bone_meal`, 246-253).
- A hoe first calls `mcl_farming.cultivate_dirt`, so successful use changes rooted
  dirt to **ordinary dirt**, not farmland. It requires air above. Only after that
  success is a hanging-root node below removed and, outside creative mode,
  dropped as an item (254-266; `hoes.lua:16-27`). The hoe accepts every clicked
  face and takes normal action wear.
- Rooted dirt has `path_creation_possible=1`, `converts_to_mud=1`, and
  `converts_to_moss=1` (242). The implementation therefore also supports shovel
  paths, water-bottle-to-mud conversion, and conversion by lush moss bone meal.
  A shovel clicked on the underside does not make a path.
- Ordinary breaking still drops rooted dirt itself. The wandering trader's real
  offer is two rooted dirt for one emerald with five uses
  (`wandering_trader.lua:123`), already represented in `WanderingTraders`.

## Bushes, pots, compost and leaf drops

The two azalea bushes use `on_place` with `group:soil_flower`
(`nodes.lua:410-438`). Coarse dirt and pale moss are now included in Voxey's
mapping; the old comment claiming those nodes did not exist was stale. Podzol,
mycelium and mangrove mud roots still have no Voxey analogue.

Both forms are explicit flower-pot registrations (`init.lua:221-231`), not a
generic plant whitelist inference. Their compost values are 65 and 85
(`nodes.lua:467,483`). `Decor` continues to store the exact bush id in
`pot_plant`, so inserting and removing a flowering azalea preserves that form.

Azalea leaves use `mcl_trees.generate_leaves_def` with both bush forms as the
sapling entries and apples disabled (`nodes.lua:338-367`). The existing ordered
`max_items=1` roll is retained: two stick attempts followed by the two azalea
entries. Shears or Silk Touch recover the exact leaf id. There is no oak sapling
or apple substitution.

## The shipped tree, not a generic oak

`azalea1.mts` was decoded as MTS version 4. Its dimensions are 7 x 6 x 7; nodes
are serialized x-fastest, then y, then z. Every slice and node probability is
127. Centering the schematic on its trunk produces exactly:

- five `mcl_trees:tree_oak` logs (four vertical trunk nodes and one branch);
- 31 `mcl_trees:leaves_azalea` nodes;
- seven `mcl_trees:leaves_azalea_flowering` nodes.

`AzaleaTrees.SCHEMATIC` stores those 43 records, and `tree_plan(turn)` applies the
source's random Y rotation. The branch's source `param2=7` is represented by the
z-axis oak-log id and turns to the x-axis id on odd rotations.

Both bushes inherit the same `_on_bone_meal` (`nodes.lua:439-452`). A successful
call requires a `math.random() <= 0.45` roll and
`mcl_trees.check_growth_simple(pos,6)`, then converts the block below to rooted
dirt, removes the bush, and places this same schematic with random rotation and
`force_place=false`. There is no flowering input to the callback and no separate
flowering tree. Preserving flowering form means preserving the seven flowering
leaves already in the schematic, not inventing a second tree.

The clearance check examines only the five cells above the bush. It admits the
source's plants, dirt, logs, leaves, torches and buildable nodes; it is not a
full-canopy clearance check. Bone-meal placement does not erase a solid
off-center canopy obstruction. Failed rolls and failed clearance do not convert
the support or remove the bush, but their callback returns `nil`: the source
dispatcher still consumes one bone meal and emits both success effects.

## Survival acquisition and moss vegetation

The source wandering trader sells moss and rooted dirt, **not azalea bushes**
(`wandering_trader.lua:119-124`). No azalea trade has been added. The existing
moss offer is a real acquisition route: `nodes.lua:48-76` spreads moss with bone
meal, and `random_moss_vegetation` (5-46) can put either azalea form on the new
moss.

`AzaleaTrees.bone_meal_moss` implements the source's random 2..3 horizontal
radius, excluded outer corners, -6..4 vertical search, convertible blocks under
literal air, 75% edge conversion chance, and 60% vegetation chance. Its
vegetation thresholds preserve short grass 52.08%, moss carpet 26.04%, double
grass 10.42%, azalea 7.29%, and flowering azalea 4.17%. Voxey has no
`mcl_flowers:double_grass` node; that one row uses the source's own single
tall-grass fallback instead of pretending a two-cell double-grass plant exists.
The azalea rows themselves are exact.

## Natural generation: implemented entry points versus inactive dispatch

The checkout has two source generation routes; comments claiming it had no
schematic loader were stale.

1. `init.lua:110-159,196-219` has the legacy lush-cave-ceiling `makeazalea`,
   which searches upward for grass, converts a probabilistic underground root
   volume, sets the surface to rooted dirt, and places azalea1. Voxey has no lush
   cave biome or ceiling-feature dispatcher. This legacy search is **not** claimed
   as active or implemented by this module.
2. `lg_register.lua:430-702` registers `rooted_azalea_tree`.
   `AzaleaTrees.generate_rooted` implements its live-world feature: initial air,
   an upward search of at most 100 cells, source natural-soil and three-cell
   clearance predicates, force-placed azalea1, twenty rooted-dirt attempts per
   root-column level, and twenty hanging-root attempts. The triangular random
   offsets use `next_within(radius)` semantics. Root replacement deliberately
   excludes dirt, matching the source list. It does not guarantee that the base
   soil becomes rooted dirt when the tree is found at the initial height.
   `tree_plan` is also a pure sparse-plan hook suitable for a future column
   generator.

Neither function is called by `TerrainGenerator`; new worlds are therefore not
claimed to contain natural azalea trees or lush-cave moss patches. The levelgen
moss-patch feature (`lg_register.lua:344-428`) likewise has no active Voxey biome
hook. `generate_rooted` operates on a loaded `VoxelWorld`, not a generation-worker
column array; a worker integration should consume `tree_plan` and implement the
column-local root writes rather than calling it on another thread.

## Shared integration hooks

The owned modules expose behavior, while shared dispatch remains with the parent:

- `player.gd`: call `LushCaveExtra.use(game,target)` before `WoodTypes.use` and
  before `game.survival.use`. This ordering is required for rooted-dirt water
  bottles as well as hoes, shovels and all owned bone-meal actions.
- `player.gd`, generic placement: reject an extra id when
  `not LushCaveExtra.can_place(game.world,destination,place_id)`; after a
  successful `set_node`, call `LushCaveExtra.placed(game.world,destination,place_id)`
  to retain the existing small/big dripleaf placement behavior.
- `decor.gd`, `accepts`: admit ids for which `LushCaveExtra.pottable(id)` is true.
- Test runner: load and run `tests/azalea_checks.gd` after integration. The checks
  exercise actual player placement/use, pot storage, a wandering transaction,
  exact world tree placement, moss vegetation and natural rooted generation.

Compost dispatch (`Composters.chance`), azalea leaf harvest dispatch
(`WoodTypes.harvest`), node registration and the real moss/rooted-dirt wandering
trade rows already exist and need no second implementation.

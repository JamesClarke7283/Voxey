# Flower mechanics source notes

Reference: `/home/impulse/.minetest/games/mineclonia`. The implementation follows
executable registrations and callbacks in this checkout, not current Minecraft
behavior.

## Placement and support

`mods/ITEMS/mcl_flowers/init.lua:72-108` is the simple-flower placement
condition. Ordinary flowers require `soil_flower` and either artificial/night
light at least 8 or full daytime sky light. Voxey's existing
`Pasture.block_light` and `RedstoneSensors` predicates supply those tests.
Darkness after placement is not a support-loss condition.

The soil mapping comes from the node definitions, including
`mcl_core/nodes_base.lua`, `mcl_mud/init.lua`, `mcl_lush_caves/nodes.lua`,
`mcl_pale_oak/plants.lua`, and `mcl_farming/soil.lua`:

- `soil_generic_plant`: grass and snowy grass, dirt, coarse dirt, mud, moss,
  rooted dirt, pale moss, podzol, mycelium, and the registered snowed
  podzol/mycelium variants. Mangrove mud roots remain unrepresented.
- `soil_flower`: the generic list plus clay and dry/wet farmland.
- Firefly bush and dry grass use explicit placement lists at
  `mcl_flowers/register.lua:427-440,458-472,496-510`. Those lists include
  farmland but not ordinary clay. Dry grass adds hardened clay, sand, red sand,
  and suspicious sand.

Wither rose is not simply a “no-light flower.” Its early branch at
`init.lua:98-105` accepts generic soil, netherrack, or a soul block without a
light test. On a flower-only host such as clay or farmland, execution falls
through to the ordinary `soil_flower` **and light** condition. `soil_ok` and
`needs_light_on` preserve that distinction.

The periodic support ABM (`init.lua:417-435`) checks `soil_flower`, not light,
and has no wither-rose or leaf-litter exemption. It is separate from the
immediate attachment/support path.

## Bone meal

The callback implementations are at `mcl_flowers/init.lua:10-66`.

- Simple flowers scan grass blocks under air in a 7 x 5 x 7 volume and give
  each position an independent 20% roll. Mud and snowy grass have
  `grass_block=1` in this source and are included; moss is not included merely
  because it is a placement host.
- Every ground stage uses that same callback and copies its exact stage.
- Bush and firefly bush try four shuffled horizontally adjacent positions and
  create at most one plant on generic soil. Tall dry grass similarly creates
  **short** dry grass on generic soil, hardened clay, or sand. Short dry grass
  instead changes itself to tall dry grass.
- These propagation soil checks are narrower than the explicit placement
  lists: bush does not propagate onto clay/farmland and firefly does not
  propagate onto farmland.
- Wither rose has no `_on_bone_meal` registration
  (`register.lua:113-124`). `FoodFeatures.bone_meal_target` therefore excludes
  it instead of treating every source `flower` as a propagating simple flower.

The source dispatcher consumes only when the callback result is not exactly
`false`; other modules with `nil`-returning callbacks must not be routed through
this boolean-only flower path.

## Ground flowers

`mcl_flowers/init.lua:160-244` registers a base craftitem and four world nodes
for wildflowers, leaf litter, and pink petals. Voxey retains its existing base
ids as `_1` and uses 11430-11438 for `_2` through `_4`.

- Clicking the same family's `_1`, `_2`, or `_3` increments that node and
  consumes one item outside creative mode. `_4` does not increment.
- Clicking any ground stage with another family suppresses initial placement.
- Otherwise initial placement requires literal air above the clicked node and
  generic soil. Leaf litter alone has `placeable_on_anything=true`.
- There is no light test. Initial placement is not a general `buildable_to`
  substitution.
- Stage `i` drops `i` base items, so `Nodes.drop` alone is insufficient: the
  break/support paths also use `drop_count`.
- Dye recipes belong to the base wildflowers/pink-petals craftitems only. All
  dye recipes for this module remain in `FlowersExtra.recipes`.

## Contact withering

`mcl_flowers/register.lua:121-123` immediately applies raw factor 1 and duration
2 to an object in a wither rose. It is not a two-second delay. Withering uses
`uses_factor`, so raw factor 1 is level 2 with a one-second damage timer
(`mcl_potions/functions.lua:927-946`). Repeated feet/head containment refreshes
the effect.

Player dispatch is in `mods/CORE/mcl_walkover/init.lua:25-42`; mob dispatch is in
`mods/ENTITIES/mcl_mobs/physics.lua:1830-1840`. `FlowersExtra.apply_contact`
performs the real potion application and returns whether the node had a contact
callback.

## Flower consumers versus stew ingredients

Source `flower=1` and `sus_stew_ingredient=1` are different groups.
`FoodFeatures.flower` is the former; `stew_ingredient` is the latter.

- All 15 simple flowers (the original 13 plus both eyeblossom states) are in
  both groups.
- Every ground stage, the four large-flower bottoms, mangrove propagule, and
  flowering azalea are flower consumers but not stew ingredients.
- Large-flower tops, double grass/fern, and plain azalea do not acquire the
  flower group.
- Hives search `group:flower` (`mcl_beehives/init.lua:221-241`). This checkout
  has no bee-mob flower diet to imitate.
- Brown mooshrooms instead query `sus_stew_ingredient`
  (`mobs_mc/cow+mooshroom.lua:168-193`). They store one flower id, reject a
  second, and the next bowl produces that flower's suspicious stew and clears
  the stored id. Subsequent bowls give ordinary stew.

Composting is another independent group, not a reason to infer probabilities
from `FoodFeatures.flower`: simple flowers are 65, ground flowers 30, flowering
azalea 85, and propagule 30.

## Stew recipes and effects

Both mushrooms have `stew_mushroom=1` (`mcl_mushrooms/small.lua:94-143`).
Ordinary stew and suspicious stew each use two such group entries. Inventory
has no generic stew-mushroom key, so Voxey expands this to the three unique
shapeless combinations: red+red, red+brown, brown+brown. Shapeless matching
already handles reversed grid order; a fourth brown+red recipe would be a
duplicate. Inventory already owned ordinary red+brown stew, so FoodFeatures
adds only the two same-species ordinary recipes.

The original 13 effects and durations are unchanged. Closed eyeblossom adds
nausea for 8 seconds and open eyeblossom blindness for 8 seconds
(`mcl_pale_oak/plants.lua:73-93`). Suspicious stew metadata stores only the
effect name; `STEW_EFFECTS` supplies duration on eating, matching
`mcl_sus_stew/init.lua:4-58`.

## Integrated hooks

The module and shared dispatch files use these connections:

1. **Registration/art:** merge all `FlowersExtra.DATA`/`BLOCKS`, including
   11430-11438, and route their art through `FlowersExtra.pixel`/`draw`.
2. **Player placement:** before generic plant placement, call
   `FlowersExtra.try_place_ground(game,target)` and return when true. For other
   plants use `FoodFeatures.uses_placement_rule(place_id)` with
   `FoodFeatures.placement_supported(world,destination,place_id)`, rather than
   the broad `flower()` consumer predicate.
3. **Player/dispenser bone meal:** dispatch only when
   `FoodFeatures.bone_meal_target(id)` is true, then call
   `FoodFeatures.bone_meal(game,p)`. Do not use broad `flower()`; that would
   intercept large plants, propagules, azaleas, and wither rose.
4. **Drops:** ordinary ground breaks and environmental/support breaks use
   `FlowersExtra.drop(id)` plus `FlowersExtra.drop_count(id)`. Shears/Silk Touch
   still use `harvest` where applicable.
5. **Contact:** player feet/head and mob standing-in updates call
   `FlowersExtra.apply_contact(target,world.node_at(cell))` each step. Do not
   add a separate damage timer or potted-flower contact behavior.
6. **Effects:** add `blindness` to `PotionEffects.NAMES`; nausea and withering
   already exist. This is required for both azure-bluet and open-eyeblossom
   stew to apply, rather than merely sanitize, their metadata.
7. **Hives:** `Beehives.flower` already delegates to `FoodFeatures.flower`, so
   the widened consumer predicate covers staged ground flowers, large-flower
   bottoms, propagules, and flowering azalea without another list.
8. **Mooshrooms:** use `FoodFeatures.stew_ingredient(id)` for brown-mooshroom
   flower acceptance, persist the accepted id, and use
   `FoodFeatures.stew_item(id)` for the next bowl. Clear the id after one
   suspicious stew. `stew_effect(id)`/`stew_duration(id)` are available for
   serialization/UI but duration is not stored in the crafted item.
9. **Composters:** query the node's own compost value before the broad flower
   shortcut; do not assign 65 to every `FoodFeatures.flower` consumer.
10. **Focused checks:** register `flower_mechanics` with the lifecycle runner.
    `tests/flower_mechanics_checks.gd` uses an isolated plot, fresh inventory,
    local RNGs, real world mutation, crafting, drops, and potion application.

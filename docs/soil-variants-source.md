# Podzol, mycelium and snow-covered soils

References inspected 2026-10-25 in `/home/impulse/.minetest/games/mineclonia` (no Git metadata in the installed copy):

- `mods/ITEMS/mcl_core/nodes_base.lua:327-466` — grass, podzol and mycelium definitions and their snowed copies.
- `mods/ITEMS/mcl_core/functions.lua:229-298,560-682,717-735` — spreading/decay ABMs, snow transitions and shovel paths.
- `mods/ITEMS/mcl_core/nodes_trees.lua:111-146` — giant-spruce `_after_grow` podzol conversion.
- `mods/ENTITIES/mobs_mc/wandering_trader.lua:93-102` — the podzol offer.
- `GROUPS.md` and the registered `non_mycelium_plant` users — compatible-plant uprooting.

Reference license: [Mineclonia GPL-3.0](licenses/Mineclonia-GPL-3.0.txt).

## Data and snow behavior

`SoilVariants` assigns the previously free, stable IDs **13602 podzol**, **13603 snowy podzol**, **13604 mycelium**, and **13605 snowy mycelium**. Their `DATA` rows carry exact source names, hardness (0.5 podzol, 0.6 mycelium), shovel preference, ordinary dirt drops, and hidden snowy inventory states. Source-backed Silk Touch drops recover podzol/mycelium themselves; snowy states recover their clear item. Existing ID **13 (`Nodes.SNOW`)** remains snowy grass, so no grass ID was remapped.

`SNOWED` and `SNOWLESS` define the three pairs: grass ↔ snowy grass, podzol ↔ snowy podzol, and mycelium ↔ snowy mycelium. `changed(world,p,old_id)` combines `on_snow_construct`, `on_snowable_construct`, and `after_snow_destruct`: both top snow and full snow blocks snow the node below, clear soil constructed under snow becomes snowy, and removing or melting cover restores clear soil. Snow-to-snow layer stacking preserves the snowy state. Single-layer melting therefore clears the soil through the ordinary `VoxelWorld.set_node` path rather than a second melt-specific rule.

Snowy blocks do not spread. Podzol never spreads or decays into dirt. Shovel use on clear or snowy podzol/mycelium, and existing snowy grass, creates a dirt path only on a top/side click with air above. These new soils deliberately have neither a hoe callback nor water-bottle/mud conversion.

## Mycelium pasture API

The module supplies the mycelium half of the existing loaded-world `Pasture` ABM rather than creating a competing clock:

- `mycelium_sources(world,p)` searches exactly one block horizontally, one below, and three above (3×5×3).
- `spread_from(world,p,source)` applies a source already selected by Pasture's combined grass/mycelium draw. It rechecks exposed dirt, target light ≥4 and source light ≥9 before setting mycelium. This preserves the selected source type when grass and mycelium are both nearby.
- `spread(world,p)` is the standalone mycelium-only entry point, using Pasture's RNG for source selection.
- `_uproot_non_mycelium_plant` runs after successful mycelium spread and sends an incompatible plant through `game.break_node`; mushrooms remain.
- `decay(world,p)` converts covered clear mycelium to dirt.

Pasture retains the source's **30 s / 1-in-20 spread**, **8 s / 1-in-50 covered decay**, and `catch_up=false`. Its existing clocks and bounded queues provide those rules; there is no offline catch-up.

## Giant spruce and trader hooks

`after_giant_spruce(world,origin,rng=null)` is the spruce 2×2 `_after_grow` hook. It searches the inclusive origin±6 **13³** volume for `group:dirt` directly under air, sorts candidates by distance, and converts `random(min(candidate_count,2), candidate_count)` entries in that order. Thus zero candidates convert none, one converts one, and larger sets convert at least two. It returns the number successfully changed.

`PODZOL_OFFER` is the exact special-pool row: **3 emeralds → 3 podzol, 6 uses, 0 XP, price multiplier 0**. It belongs in `WanderingTraders.SPECIAL`, restoring the source's eight-row special table.

## Integrated dispatch

The three core files and the shared consumers now use these live connections:

1. **Registration:** add all four `SoilVariants.DATA` entries and IDs to `VillageContent.DATA`/`BLOCKS`. In `Nodes.placeable`, return false for `SoilVariants.hidden(id)` so all three snowy states (including legacy `Nodes.SNOW`) are unobtainable as placed inventory variants. The `source_node` rows automatically feed `MiningNodes`, `FarmingRules`, `Harvesting`, hardness and drops after registration.
2. **Snow:** call `SoilVariants.changed(self,p,old_id)` unconditionally for authoritative `VoxelWorld.set_node` changes. Do not gate it only on the new IDs: snow placement/removal and legacy grassy ID 13 are inputs too. This single hook covers placement, stacking, digging, flooding, piston edits and `SnowCover.melt` without duplicating transitions.
3. **Shovel dispatch:** call `SoilVariants.use(game,target)` before `Farmland.use` in the real player-use chain. Do not add these IDs to `Farmland` or `MudBottles.host`.
4. **Pasture indexing:** treat clear `SoilVariants.MYCELIUM` as a tracked decay cell in `track`, `column_loaded`, and the `NodeInfo.PASTURE`/`Pasture.TRACKED` membership path. Dirt remains the only spread target.
5. **Pasture source draw:** append `SoilVariants.mycelium_sources(world,p)` in `Pasture.sources`. After its one random source selection, route a clear-mycelium source to `SoilVariants.spread_from(world,p,source)`; retain the existing grass path otherwise. Do **not** call standalone `SoilVariants.spread` before Pasture's combined draw, which would incorrectly split source probabilities.
6. **Pasture decay:** route clear mycelium to `SoilVariants.decay`, and include `SoilVariants.spreading(id)` in the scheduled covered-decay candidate condition. Use `SoilVariants.covered(world,p)` for that mycelium branch so a `dirtifier` cover is queued as well as an opaque/liquid cover. Do not include snowy mycelium, podzol or snowy podzol.
7. **Trees:** after a successful `WoodTypes.grow` has placed its blocks, call `SoilVariants.after_giant_spruce(world,origin)` only for spruce (`kind == 1`) grown from four saplings. Ordinary spruce and other giant species have no such conversion.
8. **Trader:** insert `SoilVariants.PODZOL_OFFER` into `WanderingTraders.SPECIAL` and update its stale seven-row/missing-podzol comments. No substitute item or new trade category is needed.
9. **Tests:** add `soil_variant` to the lifecycle runner's default checks so `tests/soil_variant_checks.gd` runs against the integrated game.

`farming.json` is intentionally limited to crop/soil callback groups. `FarmingRules` therefore also carries the inspected source mappings for `dirt`, `spreading_dirt_type`, `non_mycelium_plant`, and `soil_fungus`; an absent entry in that smaller export is not evidence that a node lacks those groups.

### Soil consumers to update, not owned here

The source groups make these consumers part of the same integration; clear variants are normally sufficient because snowy states are always covered and clear synchronously when uncovered:

- `WoodTypes.soil`: podzol and mycelium (`soil_sapling=2`).
- `Bamboo.soil` and `grove_soil`: both (`soil_bamboo`).
- `VoxelWorld.can_plant_cane`: both (`soil_sugarcane`).
- `SweetBerryCrops.HOSTS`: **podzol only**, matching its explicit source list.
- `HugeMushrooms.SOILS` and the small-mushroom placement whitelist in `player.gd`: both (`supports_mushrooms` and the small-mushroom source predicate).
- `FlowersExtra.SOIL_GENERIC` (and therefore `SOIL_FLOWER`): both. The FlowerMechanics batch was given the exact constants.
- `FoodFeatures.changed` and `flower_supported`: both, so the legacy flowers use the same hosts.
- `LushCaveExtra.azalea_soil` and `dripleaf_soil`: both.
- `CrimsonPlants` placement/support: both have `soil_fungus=1`; retain the source's separate requirement of matching nylium for huge-fungus bone-meal growth.
- `AzaleaTrees.DIRT_IDS`/`MOSS_CONVERTIBLE` and `PaleOak.converts_to_moss`: both, as applicable to each source group predicate.
- `Sculk.SPREAD_TO`: coarse dirt, podzol, mycelium and mud are included through the source's group and explicit-node expansion.
- `Shipwrecks` buried-chest surface search: both.
- `TrialChambers.SIMPLE` / node translation: map the exact source names to the new IDs instead of substituting dirt.

## Explicit worldgen dependency

Natural mycelium acquisition still requires the separately owned **`MushroomIslands`** surface-generation dependency (the legacy `MushroomIsland`/`MushroomIslandShore` aliases resolve to that canonical ID). Natural podzol belongs to `OldGrowthPineTaiga` and `OldGrowthSpruceTaiga`. This module does not invent substitute terrain. Tradable podzol, giant-spruce conversion, and mycelium spreading work once an actual mycelium source exists.

`tests/soil_variant_checks.gd` exercises registry/source drops, all six snow transitions, stacking and real melting, mycelium search/light/uproot rules, mixed-source selection, real Pasture clocks and no catch-up, shovel/hoe/bottle interactions, exact giant-spruce selection plus real 2×2 growth, and the live trader pool.

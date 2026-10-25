# Flowerpot lifecycle and source parity

Behavioral reference: the supplied Mineclonia checkout, primarily `mods/ITEMS/mcl_flowerpots/init.lua` and `mods/ITEMS/mcl_pale_oak/plants.lua`. Voxey's implementation is original GDScript in `scripts/decor.gd`; its geometry and textures are procedural and original. These notes supersede the older, incomplete flowerpot summary in `decoration-source.md`; armor stands and archaeology are outside this batch.

## Exact 36-item whitelist

Admission is the source's `mcl_flowerpots.registered_pots` table, not `group:flower`, `group:plant`, a sapling predicate, or a height test. `Decor.POTTABLE` is the inverse of this exact itemstring-to-id table and `Decor.accepts(id)` performs only that lookup.

| Source itemstring | Voxey id |
| --- | ---: |
| `mcl_flowers:poppy` | 5610 |
| `mcl_flowers:dandelion` | 5611 |
| `mcl_flowers:oxeye_daisy` | 5612 |
| `mcl_flowers:tulip_orange` | 11400 |
| `mcl_flowers:tulip_pink` | 11401 |
| `mcl_flowers:tulip_red` | 11402 |
| `mcl_flowers:tulip_white` | 11403 |
| `mcl_flowers:allium` | 11404 |
| `mcl_flowers:azure_bluet` | 11405 |
| `mcl_flowers:blue_orchid` | 11406 |
| `mcl_flowers:wither_rose` | 11407 |
| `mcl_flowers:lily_of_the_valley` | 11408 |
| `mcl_flowers:cornflower` | 11409 |
| `mcl_flowers:fern` | 11410 |
| `mcl_core:deadbush` | 13601 |
| `mcl_mushrooms:mushroom_red` | 57 |
| `mcl_mushrooms:mushroom_brown` | 58 |
| `mcl_core:cactus` | 14 |
| `mcl_bamboo:bamboo_small` | 1174 |
| `mcl_trees:sapling_oak` | 23 |
| `mcl_trees:sapling_spruce` | 6034 |
| `mcl_trees:sapling_birch` | 6066 |
| `mcl_trees:sapling_jungle` | 6098 |
| `mcl_trees:sapling_acacia` | 6130 |
| `mcl_trees:sapling_dark_oak` | 6162 |
| `mcl_trees:sapling_cherry` | 13003 |
| `mcl_trees:sapling_pale_oak` | 13067 |
| `mcl_mangrove:propagule` | 13035 |
| `mcl_lush_caves:azalea` | 11472 |
| `mcl_lush_caves:azalea_flowering` | 11473 |
| `mcl_crimson:crimson_fungus` | 11511 |
| `mcl_crimson:warped_fungus` | 11512 |
| `mcl_crimson:crimson_roots` | 11513 |
| `mcl_crimson:warped_roots` | 11514 |
| `mcl_flowers:eyeblossom` | 11528 |
| `mcl_flowers:eyeblossom_open` | 11529 |

The previous 28 valid entries are retained. The additions are bamboo, fern, both fungi, both roots, and both eyeblossom forms. Ordinary vine (`Nodes.VINE`, 41) is explicitly absent. The legacy crimson/warped sapling ids 13099/13131 are also absent even though `WoodTypes.is_sapling` recognizes them; the source whitelist instead contains the fungus entries. Tall grass, bush, and every other merely plant-like item remain rejected.

## Interaction, support, and drops

The source stores contents in distinct node names. Voxey retains its save-compatible single node id, `Decor.POT = 10800`, and stores the actual item id in `world.block_states[station_key]["pot_plant"]`.

- Empty pot + accepted held plant: store the plant and consume one outside creative mode.
- Occupied pot + the same plant in survival: no-op.
- Occupied pot + any other held item, or the same plant in creative: empty the pot; outside creative, return the stored plant to inventory or drop it when inventory delivery cannot complete.
- Ordinary non-creative breaking: drop one empty flowerpot item and, when occupied, one of the stored plant.
- Empty and occupied source pots both have `attached_node = 1`. `Decor.try_place` now handles `POT` as well as the existing armor stand and refuses placement without a loaded, walkable node beneath. This is Luanti's `walkable` test, not a full-cube or shaped-top-face test. `Decor.support_changed` validates the changed cell and the cell above. Environmental support loss removes the pot and drops both items regardless of player gamemode, as an attached-node drop rather than a player break.
- `Decor.set_contents` marks the cell dirty after a real metadata change. This is necessary because insertion, removal, and eyeblossom swaps do not change the Voxey node id.

Support checks defer while a piston transaction is moving. The integration hook below is required to validate the final support arrangement.

## Potted eyeblossom timing

`mcl_pale_oak/plants.lua:113-147` registers separate ABMs for potted closed and open eyeblossoms. Both use `interval = 2`, `chance = 2`. The source night predicate is `timeofday <= 0.2 or timeofday >= 0.8`.

`Decor.update(game, delta)` accumulates two-second intervals over loaded, registered potted eyeblossoms. Each cell gets an independent 1-in-2 roll per interval, using a deterministic world-seeded `RandomNumberGenerator`. The roll occurs before the action's day/night test, matching Luanti's ABM chance gate. A successful roll opens a closed pot at night and closes an open pot by day by updating `pot_plant`; no new node id or parallel metadata field is introduced. Unloaded pots do not advance or transition offline.

`Decor.eyeblossom_step(world, p, day_time, rng)` is the single-ABM-attempt primitive used by `update` and available for deterministic focused checks. `PaleOak.is_night` supplies the exact source time window. Potted cells must use `Decor.update`, not `PaleOak.update`: the latter tracks unpotted world flower node ids and cannot update `pot_plant` metadata.

## Saved rendering API

The old `Decor.pot_mesh(out, p, plant)` was only a pure drawing helper; no saved-state snapshot connected it to the worker. The following APIs now expose the complete path:

- `Decor.pot_body_mesh(out, p)` draws the empty body. `Decor.mesh` uses it for icons and the fallback empty-node mesh.
- `Decor.pot_mesh(out, p, plant)` draws the body plus the supplied plant. It is worker-safe input-wise: all saved data is passed by value. Bamboo and cactus use the source's long-cube presentation category; flowers and both eyeblossom forms add the bloom geometry.
- `Decor.pot_snapshot(world, p) -> {"pot": 10800, "plant": pot_plant}` captures one cell for main-thread display code.
- `Decor.pot_snapshot_mesh(out, p, snapshot)` renders that detached snapshot.
- `Decor.saved_pot_mesh(out, p, world)` is the direct main-thread convenience API.
- `Decor.plant_snapshot(world, column)` returns `{block_coord: {local_index: plant_id}}` for occupied pots in the column and its one-cell border. Empty pots need no entries because their ordinary node mesh is already the body. The snapshot reads `pot_plant` for every cell independently, so adjacent pots cannot inherit a stale or hard-coded plant.

### Integrated parent wiring

Shared dispatch and the worker mesher use these exact hooks:

1. **Existing paths:** `Player` already calls `Decor.try_place` and `Decor.use`; `VoxelWorld.set_node` already calls `Decor.changed`; `Game` already calls `Decor.break_node`.
2. **Timed state:** call `Decor.update(game, delta)` from the active, authoritative world update beside `PaleOak.update`. Call `Decor.column_loaded(world, column)` after saved edits are reconciled, `Decor.unload(world, column)` on unload, and `Decor.reset(world)` on world reset.
3. **Pistons:** in `PistonPush.finish`, call `Decor.support_changed(world, p)` for each deferred support position. Normal support changes already run through `Decor.changed`.
4. **Worker meshing:** on the main thread, evaluate `Decor.plant_snapshot(world, column)` before saved-world remesh worker submission and pass the entry for the worker's `coord`. Add a detached dictionary argument alongside `cocoa_facings` through `BlockMesher.build` and `_custom`. In custom kind 22, route `Decor.POT` to `Decor.pot_mesh(out, p, int(pot_plants.get(local_index, 0)))`; keep `VillageArt.mesh` for the stand and other content. Do not read `world.block_states` on the worker. Initial structure generation must equivalently pass any newly generated `pot_plant` states it owns; those states are not yet present in the world's saved-state dictionary when its worker starts.
5. **Main-thread/display meshing:** use `saved_pot_mesh`, or `pot_snapshot` plus `pot_snapshot_mesh`, wherever a direct world-aware mesh is needed. The saved metadata dirtying is already implemented.

## Focused checks

`tests/flowerpot_checks.gd` uses the real inventory interaction, placement, world-change, breaking, drop, metadata, timing, and mesh paths. It independently enumerates all 36 source itemstrings, exercises insertion/same-plant/removal for every accepted id, checks vine and both legacy sapling rejections, verifies supported placement and two-item support-loss/break drops, drives both eyeblossom transitions, and verifies single-cell and worker-column rendering snapshots use the actual plant tile.

After runner integration, invoke:

```sh
godot --headless --path . --script res://tests/lifecycle_runner.gd -- flowerpot
```

No test or build result is claimed in this worker batch.

## Presentation boundaries

- Source uses `flower_pot.obj`, `flower_pot_plant.obj`, and `flowerpot_with_long_cube.obj` with per-species image/palette definitions. Voxey uses original procedural boxes and the plant's generated atlas tile; it does not reproduce the OBJ silhouettes or source `param2` palette behavior. The saved plant identity, open/closed tile, drops, and timing are nevertheless real state, not display-only substitutions.
- The single Voxey pot id is an intentional storage/registry difference, not an additional gameplay rule. The source's distinct potted node names map to `POT + pot_plant`; existing saves and generated allium pots retain that representation.
- ABM wall-clock scheduling is reproduced by Voxey's loaded-world two-second accumulator and per-cell chance rolls, not by Luanti's engine scheduler. There is no offline transition simulation.

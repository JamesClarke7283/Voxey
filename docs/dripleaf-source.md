# Dripleaf physics and lush ceiling support

## Source and ownership

Behavior follows `/home/impulse/.minetest/games/mineclonia/mods/ITEMS/mcl_lush_caves/dripleaf.lua` and `nodes.lua`.
`LushCaveExtra` owns behavior and original procedural art; the numeric IDs remain
`11476` through `11481` for dripleaf, `11471` for spore blossom, and `1206` for the
existing hanging roots. No source model or texture is imported.

The azalea, rooted-dirt, moss, pot, trade, and bone-meal paths are unchanged. In
particular, an azalea callback that returns nil after a failed growth roll still
uses the existing bone-meal feedback/consumption path, while rooted dirt with an
occupied cell below does not grow roots or consume bone meal.

## Collision and standing samples

`dripleaf_big.collision_box` is a thin plate at the top of its cell: source local
Y `0.45` through `0.5` becomes Voxey cell Y `0.95` through `1.0`, a literal `0.05`
height. The half-tip merges that definition and keeps the plate. The full-tip also
inherits the field, but explicitly sets `walkable = false`; its live collision set
is therefore empty. Voxey exposes this through:

- `LushCaveExtra.is_big_leaf(id)` — upright, half-tip, or full-tip;
- `LushCaveExtra.walkable(id)` — true only for upright and half-tip;
- `LushCaveExtra.collision_boxes(id)` — the exact `0.05`-high source top plate for
  the walkable forms and `[]` for full-tip.

The source globalstep does not inspect only `floor(player.position)`. At
`dripleaf.lua:294-321`, `get_player_dripleaves` scans the player's complete X/Z
collision span with the source's `0.501`/`0.499` boundary adjustments and samples
Y at collision-box bottom plus `0.45`. `player_dripleaves(world, position,
half_width, collision_bottom)` ports that loop, converting between Mineclonia's
centre-addressed nodes and Voxey's minimum-corner cells. Defaults are Voxey's real
player dimensions: half-width `0.29` and collision bottom `0.0`.

Only an upright big leaf with `world.circuits.input_power(p) == 0` enters the
current set. Power suppression is not merely a tip-time check: a powered leaf
cannot accumulate or retain a standing hold.

## Holds, stage timers, and multiplayer

The source stores `player_dripleaf[player][leaf_hash]`. The module preserves that
separation rather than sharing one accumulator between players:

- `runtime(world).holds` maps player key → leaf cell → elapsed hold;
- `runtime(world).timers` maps tipped leaf cell → elapsed current-stage time.

An upright hold tips only when elapsed is strictly greater than `0.5` seconds.
Each update replaces a player's previous table with the leaves currently under
that player, so walking away, losing power, or leaving the game abandons unfinished
holds. One player leaving a leaf does not reset another player's hold on it.

Half-tip has its own `0.5`-second timer and full-tip its own `3.0`-second timer.
These timers advance without a player and perform at most one stage transition per
update, matching a node timer being started for the new stage. Excess frame time is
not carried into the next stage.

`update(world, delta)` automatically samples the authority's local player and every
member of `game.network.players`; roster positions are read directly, so an avatar
that has not finished spawning is not omitted. Client replicas return without
simulating. `update(world, delta, players)` is the deterministic/test adapter:
records contain `key`, `position`, and optionally `width` and `bottom`.
`player_left(world, key)` is also available for immediate disconnect cleanup.

Timers and holds are transient. `unload` removes entries in the departing column.
`column_loaded` registers saved tipped nodes from real world edits, restarting
their current-stage timer; `reset` discards all transient state.

## Adjacent digging

Every dripleaf definition inherits `after_dig_node = dig_adjacent`. At
`dripleaf.lua:33-44`, it waits `0.05` seconds and calls `core.dig_node` above and
below. Those digs recurse through their own callbacks.

`dug(game, p, old_id)` implements that delayed hook. Recursive removal uses the
source's actual `group:dripleaf=1` membership: small leaf, small stem, big stem,
and upright big leaf. The tipped definitions replace the group table and therefore
do **not** get traversed as neighbors, even though they retain the callback on the
node itself. Cascade drops use ordinary no-tool `Nodes.drop`; they do not inherit
the initiating player's shears, tool, or creative inventory rule.

## Spore blossom and hanging roots

`can_place(world, p, id, normal)` now handles both attached ceiling plants:

- Spore blossom accepts an opaque block, upright stair, or bottom slab above, from
  any clicked face (`nodes.lua:387-400`).
- Hanging roots accept only an underside click (`normal == Vector3i.DOWN`) and a
  walkable block above (`nodes.lua:122-131` plus `attached_node=4`).

Later support loss uses the attached-node rule, not the blossom's placement-only
opacity/stair/slab predicate. `changed` validates the changed cell and the cell
below it. Removing walkable support removes the plant; spore blossom drops itself,
while hanging roots retain source `drop = ""`. `column_loaded` also validates the
lower boundary when a support column arrives.

## Integrated parent hooks

The module owns behavior; shared dispatch applies these exact hooks:

1. **`Nodes.uncached_solid(id)`**, before the `VillageContent.DATA` fallback:
   ```gdscript
   if LushCaveExtra.is_big_leaf(id): return LushCaveExtra.walkable(id)
   ```
   This is required as well as collision dispatch because attachment and placement
   queries use `Nodes.solid`.

2. **`VoxelWorld.collision_boxes(p)`**, before the full-cube fallback:
   ```gdscript
   if LushCaveExtra.is_big_leaf(id): return LushCaveExtra.collision_boxes(id)
   ```
   In `NodeInfo.compute(id)`, exclude `LushCaveExtra.is_big_leaf(id)` from the
   unit-cube `BOX` bit while preserving `CUBE` for rendering. Otherwise
   `VoxelWorld.intersects` returns before consulting these custom boxes. Mirror the
   same `is_big_leaf`/`collision_boxes` branch in `PistonPush.future_boxes` before
   its full-cube fallback so piston prediction uses the identical shape.

3. **`player.gd` generic placement**, replace the current three-argument extra-ID
   gate with:
   ```gdscript
   if LushCaveExtra.needs_placement_rule(place_id) and not LushCaveExtra.can_place(game.world,destination,place_id,target.normal): return
   ```
   Keep the existing post-placement `LushCaveExtra.placed(...)` call. This adds the
   hanging-root rule without changing azalea/rooted-dirt behavior.

4. **`VoxelWorld.set_node`**, on the authority path after the node data has changed:
   ```gdscript
   LushCaveExtra.changed(self,p,old_id,id)
   ```
   Do not run authoritative support/drop physics from `apply_network_edit`.

5. **`VoxelWorld._apply_column`**, after edit reconciliation and before
   `column_loaded.emit()`:
   ```gdscript
   LushCaveExtra.column_loaded(self,c)
   ```
   Call `LushCaveExtra.registered(self,p,id)` in both the generated-special and
   edited-cell loops. Add `LushCaveExtra.is_dripleaf_tipped(id)` and
   `LushCaveExtra.is_ceiling_plant(id)` to `NodeInfo.compute`'s `SPECIAL`
   predicate so worker generation supplies those cells. `column_loaded` remains
   necessary for edited cells and the cross-column lower attachment boundary.
   Existing `_process` → `LushCaveExtra.update(self,delta)` and `_unload` →
   `LushCaveExtra.unload(self,c)` calls remain in place.

6. **`game.break_node`**, immediately after the generic dripleaf's successful
   `world.set_node(p,Nodes.AIR)`:
   ```gdscript
   LushCaveExtra.dug(self,p,id)
   ```
   Exclude `LushCaveExtra.is_dripleaf(upper)` from the generic plant-above recursion
   at the end of `break_node`; the source's delayed callback owns both directions
   and its no-tool drop semantics. Server-handled remote breaks use this same path.

7. **`voxey_network.gd` peer disconnect**, optionally call
   `LushCaveExtra.player_left(game.world,id)`. The next authority update also
   prunes missing roster keys, so either integration prevents retained holds.

8. **Focused checks:** load and `await` `tests/dripleaf_checks.gd.run(t,game)` from
   the parent-selected real-game test runner. The checks cover actual collision
   dispatch, `Player.use`, `VoxelWorld.set_node`, worker column unload/reload,
   multi-player holds, power, all stage timings, client suppression, and real
   `Game.break_node` cascade behavior.

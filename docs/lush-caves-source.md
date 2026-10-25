# Lush caves

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_lush_caves/{init,nodes,crafting}.lua` and the `mcl_crimson.grow_vines` helper it calls. The implementation is original GDScript; the art is original procedural code. Numeric ids remain unchanged.

## Cave-vine survival loop

The source stores age in `param2`. Voxey has no per-node param2 table, so `LushCaves` stores `cave_vine_age` in `VoxelWorld.block_states` under `VoxelWorld.station_key(p)`. Age zero is the default and is omitted. Changing a cell to a non-vine removes only this age key, preserving unrelated saved state.

| Rule | Executable source behavior |
|---|---|
| Light | Only `cave_vines_lit` emits, at light **14**. |
| Bone meal | `nodes.lua:180-184` converts the **clicked unlit node**, preserving age. It does not find or ripen the tip. |
| Harvest | Lit `on_rightclick` (`230-234`) creates **one glow-berry item entity**, then makes that same node unlit without changing age. |
| Shears | Only the unlit form has `_on_shears_place` (`186-198`). The clicked node must already be the lowest tip; age becomes **25**. Off-tip use performs no work and does not wear the tool. |
| Passive growth | The ABM (`init.lua:162-180`) has interval **180 seconds**, chance denominator **5**, and acts only on the lowest tip below age 25. |
| New tip | `mcl_crimson.grow_vines` grows one cell downward into literal air, with old age + 1. The old tip is unchanged. The new cell has an **11%** chance to be lit. A blocked cell changes nothing. |
| Support | `vinelike_node=2` accepts the same vine group or a solid node directly above. `mcl_attached` also deliberately does **not** detach when the node above is non-solid but non-airlike; literal air detaches. Unlit drops nothing and lit drops one glow berry. |

Both internal vine forms have `not_in_creative_inventory=1`, `drop=""` for unlit and `drop="glow_berry"` for lit. Neither is a directly placeable item. A player obtains and plants the glow-berry craftitem instead.

## Glow-berry placement is deliberately unusual

The berry is food with **2 hunger points**, **1.2 saturation**, and compostability **50**. Its `on_place` (`nodes.lua:281-334`) takes precedence over eating for a node-targeted click:

1. The clicked face must be an underside (`direction(under, above).y == -1`). Other faces do not plant or begin eating.
2. Lit cave vines and other `vinelike_node=2` forms cannot be extended. The destination below must be `buildable_to`; Voxey uses its shared air/snow/plant/liquid/fire replacement vocabulary, excluding non-buildable vine nodes.
3. Extending an unlit cave vine gives the new cell `old_age + 1`. Any other underside gives age zero. Manual placement does not clamp that value to 25; 25 is the passive-growth cutoff.
4. **Line 320 calls `core.place_node(pointed_thing.under, {name=vine}, placer)`, not `above`.** This is intentional source behavior to preserve, not a typo to “fix.” Luanti placement honors `buildable_to`: on ordinary stone this call is a no-op and the stone support remains; on a buildable clicked node it places an unlit vine. The subsequent `swap_node` creates the new cell below regardless.
5. The new cell has the same independent 11% lit roll. Survival consumes one berry, creative does not, and `mcl_hunger.prevent_eating` suppresses the food action. Voxey's `LushCaves.use` returns handled before `Hunger.can_eat`, providing the same suppression without a second inventory transaction.

## Moss and recipes

`nodes.lua:78-88` registers moss with hardness **0.1**, `hoey=2`, and compostability **65**. The content entry therefore uses Voxey hoe tool kind 4, not the old 0.5 hardness and shovel kind. Moss still makes mossy cobblestone and mossy stone bricks; two moss make three moss carpet.

## Loaded-column runtime and persistence

`LushCaves.runtime` contains only transient indexes, a seeded RNG, and a bounded job cursor. `registered` tracks only loaded vine cells, `changed` refreshes registration and vertical support, `column_loaded` revalidates a column, and `unload` drops only that column's transient registrations. No growth reads or writes an unloaded destination.

The fractional ABM clock lives in saved `world.adventure_state["lush_cave_vine_elapsed"]`. Each 180-second cycle snapshots current cells. Sixteen jobs at most are processed per update; unfinished jobs remain queued and cannot be replaced by a later snapshot. `reset` removes only transient runtime state. Saved node ids, age state, and elapsed time survive save/load.

## Integrated parent wiring

These are the module's live integration contracts:

- `scripts/player.gd`: in `use()`, call `if LushCaves.use(game, target): return` **before** `Hunger.can_eat` and before generic placement. This one entry handles bone meal, lit harvest, shears, and berry planting.
- `scripts/dispensers.gd`: in the bone-meal branch, add a cave-vine case calling `LushCaves.ripen(world, target)` and use its boolean for `applied`/`consume`.
- `scripts/voxel_world.gd`: call `LushCaves.reset(self)` from `configure`; `LushCaves.update(self, delta)` in the active non-replica update; `LushCaves.changed(self, p, old_id, id)` from `set_node`; `LushCaves.unload(self, c)` from `_unload`; and `LushCaves.column_loaded(self, c)` after column reconciliation. In both generated-special and edited-cell load loops, call `LushCaves.registered(self, p, id)` when `LushCaves.is_vine(id)`.
- `scripts/hunger.gd`: in `food_saturation(id)`, return `LushCaves.BERRY_SATURATION` for `LushCaves.GLOW_BERRY` before the ordinary fixed table (the table otherwise defaults this VillageContent item to zero).
- `scripts/village_content.gd`: mirror `LushCaves.BLOCK_DATA` for ids **1177, 1178, 1179, and 1204** (including drops, hidden internal vine forms, berry saturation/compost, and moss hardness/hoe/compost). Keep the existing carpet/root entries and ids.
- `scripts/nodes.gd`: before the generic `VillageContent.DATA` placeability fallback, return `false` when `LushCaves.is_vine(id)`. `Nodes.drop` already honors each entry's explicit `drop`.
- `scripts/village_item_art.gd`: delegate `LushCaves.GLOW_BERRY` to `LushCaves.draw(img, id)` before the generic item fallback.

`tests/lush_cave_checks.gd` exercises real player clicks, a dispenser bone-meal action, world support changes, loaded-column unload/reload, and actual save/load. It no longer asserts the incorrect tip-ripening rule.

## Boundary

Natural lush-cave biome dispatch and full source biome generation remain separate from this survival lifecycle. Azalea/rooted-dirt behavior remains owned by `LushCaveExtra` and `AzaleaTrees`.

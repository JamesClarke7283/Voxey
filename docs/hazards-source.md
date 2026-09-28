# Hazards: suffocation, fall damage, void tolerance, the bonus chest and boss bars

Voxey follows the supplied Mineclonia checkout at
`/home/impulse/.minetest/games/mineclonia`. The implementation is original
GDScript using the source as a behavioural reference.

## Suffocation (`in_wall`) — `PLAYER/mcl_player/init.lua`:153-174

`mcl_player.register_globalstep_slow` runs on a `slow_gs_timer = 0.5` cadence and
deals **one** point of `in_wall` damage when the actor's head node is a walkable,
full, opaque cube that does not carry `disable_suffocation`. The node sampled is
the **feet** node when the actor is swimming or in a one-high pose, because a
swimmer's head node sits above the body.

`scripts/hazards.gd` reproduces that condition. Its `suffocates` is
`Nodes.solid` plus a fully opaque cube (`RedstoneSensors.light_filter(id) < 0`),
and its `sample_cell` takes the head or the feet. `scripts/player.gd` runs the
tick on the same half-second accumulator. Powder snow is the checkout's only
`disable_suffocation = 1` node and is deliberately non-solid, so `exempt` names
it directly.

A player buried by gravel, or sealed into a pocket by a piston, therefore takes
steady damage rather than standing there indefinitely — which is the rule that
makes those two situations dangerous.

## Fall damage — `PLAYER/mcl_player/init.lua`:177-213

A damage modifier traces from the landing point along the fall velocity, taking
`ceil(v_axis_max / 5) + 1` samples, and returns **0** if any sample lands in
water, an End portal, a cobweb, a vine or powder snow. Otherwise it subtracts the
actor's `leaping` effect level, one point per level, and never below zero.

`scripts/hazards.gd`'s `fall_damage` is that trace, and `forgiving` is the node
list. `scripts/player.gd` calls it on landing and keeps the honey-block
multiplier the source applies in the same ladder.

## Void tolerance — `CORE/mcl_worlds/init.lua`:6-28 and `mcl_void_damage`

`mcl_worlds.is_in_void` returns two values: whether a position is in a gap at all,
and whether it is in the **deadly** part. The deadly part starts
`deadly_tolerance = 64` nodes into the gap, so a player who clips the floor of the
world has room to climb back out. `mcl_void_damage` then deals four health every
half second.

Voxey previously damaged five nodes below `min_y()`. It now uses the source's
64-node tolerance and keeps its existing half-second rate. The check asserts both
halves of the boundary: inside the tolerance the void clock stays at zero, past it
the damage lands. The shallow cells are bedrock, so the source's own suffocation
rule does apply there while the void does not.

## Bonus chest — `PLAYER/mcl_bonus_chest/init.lua`:12-160

`register_on_newplayer` places a chest near the spawn point with
`mcl_loot.get_multi_loot` over fourteen groups, plus four torches in the
buildable-to neighbours, and only for a new survival world.

`scripts/bonus_chest.gd` reproduces the loot table, the placement, the
buildable-to torch rule and the once-per-world flag (`adventure_state.bonus_chest`).
Two source details needed a decision:

- The cherry-sapling entry is **dropped** rather than given a zero id. Every entry
  in that group weighs 1, so a zero id would silently lose one of the fourteen
  guaranteed stacks; dropping the entry keeps the other six saplings at equal odds.
- The source's `mcl_trees:wood_oak` is registered with the planks texture, so it
  maps to `Nodes.PLANKS`, while `mcl_trees:tree_*` maps to `WoodTypes.LOGS`.

## Boss bars — `HUD/mcl_bossbars/init.lua`:53-119

One shared bar list. `add_bar` takes a title, a fill percentage and a colour from
`light_purple, blue, red, green, yellow, dark_purple, white`; a **dynamic** bar (a
boss) is added for every player within 80 nodes and identical dynamic bars stack
as `text xN`; a **static** bar (a raid) is added once and updated by id.
`update_boss` computes `health / hp_max` and falls back to the mob's own name when
the nametag is empty.

Voxey drew one hard-coded End-dragon bar and nothing else, so a summoned wither had
**no** health readout and a raid drew a text line. `scripts/boss_bars.gd` rebuilds
the bar list from live state each frame — a dead boss disappears with no teardown
path — and `scripts/hud.gd` draws it under the crosshair. The dragon keeps its own
richer display, which also names the surviving healing crystals.

## Verification

`tests/hazard_checks.gd` (54 checks) covers the suffocation conditions and cell
sampling, the fall trace through each forgiving node, the Jump Boost subtraction
and its floor at zero, item merging and cactus/float/push behaviour, offhand-first
pickup, piglin anger and the bar list. The void tolerance lives in
`tests/environment_runner.gd`, which asserts both sides of the 64-node boundary.

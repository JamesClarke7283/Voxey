# The wind charge

`ENTITIES/mcl_charges/` registers a family of throwable "charges", of which the
checkout ships exactly one: the wind charge.

| Piece | Line | What it does |
| --- | --- | --- |
| `register_charge` | `init.lua`:103 | the item, its place and secondary-use throws, and a dispenser path |
| `wind_burst` | `init.lua`:88 | the radius-4 push |
| `wind_burst_velocity` | `init.lua`:70 | the mob/item velocity form |
| the flying entity | `init.lua`:182 | movement, node hit, and the 0.6-radius object hit |
| the charge's def | `wind_charge.lua` | its damage, its node responses and its three-second life |

## Throwing

Both `on_place` and `on_secondary_use` throw at **30** nodes per second along the
player's look direction, from `playerpos + dir + (0, 1.3, 0)` when placing and
`(0, 2, 0)` when using, with acceleration set to zero. A **one second** per-player
cooldown gates it. `_on_dispense` uses the entity's own `velocity` field (default 20)
along the dropper's facing.

This is deliberately unlike `mcl_throwing`, which throws eggs and snowballs at 22
with a −3 horizontal drag and gravity. The wind charge flies dead flat.

## The burst

`hit_node`, `hit_player_alt` and `hit_mob_alt` all call `wind_burst(pos, damage_radius)`
with `damage_radius = (4 / max(1, 4)) * 4 = 4`:

* a **player** inside gets `normalize(obj_pos - pos) * float_random(1.8, 2.0) /
  max(1, distance) * 4` added to its velocity, so strength falls off with distance;
* a **mob** or a dropped item gets `wind_burst_velocity(pos, obj_pos,
  obj.velocity, 4 * 3)`, which is `normalize(obj_pos - pos) * 12 + old velocity +
  (randf() - 0.5)` per axis, clamped to a length of 250.

`wind_burst_velocity` returns the old velocity untouched when the two positions are
equal, so a burst exactly on an object does nothing rather than dividing by zero.

## Damage

`hit_player = mcl_mobs.get_arrow_damage_func(0, "fireball")` and
`hit_mob = get_arrow_damage_func(6, "fireball")`. A charge therefore hits a mob for
six and a player for **nothing** — it is a movement tool, not a weapon. `on_activate`
sets `{immortal = 1}` and schedules a `core.after(3, ...)` removal, so a charge that
never lands despawns after three seconds.

## Blocks that answer specially

`hit_node` inspects the node it struck:

* a node in the `bell` group rings (`mcl_bells.ring_once`);
* `mcl_end:chorus_flower` is dug, and `mcl_end:chorus_flower_dead` is swapped to a
  **living** flower, each with `chorus_flower_effects(pos, 2)`;
* `mcl_pottery_sherds:pot` is swapped to air and drops four `mcl_core:brick`, with
  `pot_effects(pos, 2)`.

Anything else is left standing: the burst breaks no blocks.

## How Voxey models it

`scripts/wind_charge.gd` holds the burst, the two velocity forms and the node
responses; `ThrownItem` and `Throwables` gained the per-item speed, gravity, drag and
lifetime so one projectile class serves both the arcing egg and the flat charge.
`WindCharge.ID` is 11601, the slot after the recovery compass, and the recipe is the
reference's own — `mcl_mobitems`' breeze rod declares
`_mcl_crafting_output = {single = {output = "mcl_charges:wind_charge 4"}}`.

The source's breeze mob is still a `FIXME` in the checkout
(`MAPGEN/mcl_levelgen/trial_chambers.lua`:387), and the charges' other sources in
the reference are vault loot and trial-spawner egg projectiles. Voxey has neither
vaults nor those spawners, so the breeze rod — which Voxey already drops from its
own breeze — is the route to the item.

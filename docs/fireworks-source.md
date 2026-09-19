# Firework rockets

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_fireworks`. The implementation is original GDScript using the source as a behaviour reference; no source code or asset is copied.

## What the reference actually is

`mcl_fireworks` is **not** a firework-display system. It registers three **elytra boosters** and nothing else: no rocket entity, no explosion, no star crafting, no colours or shapes. Anyone expecting Minecraft's firework show will not find it here, and Voxey does not invent one.

The whole module is 68 lines. Three rockets exist, differing only in how long they drive the wings:

| Rocket | Flight duration | Force | Recipe |
|---|---|---|---|
| `rocket_1` | 2.2 s | 10 | 1 paper + 1 gunpowder → 3 |
| `rocket_2` | 4.5 s | 20 | 1 paper + 2 gunpowder → 3 |
| `rocket_3` | 6.0 s | 30 | 1 paper + 3 gunpowder → 3 |

All three crafts are shapeless, yield three rockets each, and `mcl_bows:rocket` is an alias of the middle tier.

## Use rules

`use_rocket` accepts a rocket only when the elytra is already deployed. Two refusals are reproduced verbatim:

- **No usable elytra** — the item is not consumed.
- **Wings stowed** — the source's message is "Elytra not deployed. Jump while falling down to deploy." A worn-out elytra is treated as unusable, matching how the rest of Voxey's wing wear works.

A successful use takes one rocket and starts the boost.

## The boost

`playerphysics/elytra.lua` sets each axis to

```
look * 2.0 + (look * 30.0 - velocity) * 0.5 + velocity
```

which drives the wings hard along the player's look direction, and counts the remaining time down by the step. The server-player path clamps the same expression to `30 + 2` as a speed ceiling, so the two agree on a maximum of 32 units. Voxey's glide update hands control to this boost entirely while it burns, because the source applies it on top of wings that are already deployed.

## Recorded source gaps

- There is no firework explosion, colour or shape system in the reference, so none exists here.
- The source's `mcl_serverplayer` client-side prediction path exists only because the reference runs the physics server-side; Voxey's single-process flight applies the boost directly.

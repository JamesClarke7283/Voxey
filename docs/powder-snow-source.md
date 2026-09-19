# Powder snow

Voxey follows the supplied Mineclonia `mods/ITEMS/mcl_powder_snow/init.lua`. The implementation is original GDScript using the source as a behaviour reference; art is original procedural code.

## Why it mattered

Powder snow is the **trap block** of a snowy biome: it looks like snow and is **not solid**. A player crossing a snowfield walks into it, sinks, and starts to freeze. Voxey had no such block, so its snowy biomes were entirely safe to cross.

The block's whole value is that it is indistinguishable from snow at a glance. Art therefore matches the snow surface rather than being distinctive.

## What the source does

The freeze rule is precise, and each part is what makes the trap **fair rather than arbitrary**:

| Rule | Source |
|---|---|
| Meter rises by **0.5 per slow tick** | `time_in_snow + 0.5` |
| Capped at **7** | `math.min(..., 7)` |
| Damage begins past **5** | `if time_in_snow > 5 then` |
| Damage is **half a heart** | `damage_player(player, 0.5)` |
| **Three frost stages** at 1, 3 and 5 | the screen frosts over gradually |
| Leaving **drains** the meter | `time_in_snow - 0.5` |
| **Leather armour prevents it** | checks the whole armour set |
| Fire mobs take **5× freeze damage** | `damage * 5.0` |

The staging is the part that makes it fair: the screen warns at three depths *before* the freeze hurts. Measured, the meter climbs through stages 1, 2 and 3, and damage only appears once the meter is past 5 — so by the time it costs health, the player has already been told.

## Two behaviours verified by measurement

- **Leather insulates.** With leather boots equipped the meter does not build at all and sixteen freeze steps deal **zero damage**; with diamond boots it does not insulate. That is what leather is for in a snowy world.
- **Fire mobs suffer more.** A blaze takes **2.5** where a zombie takes **0.5** at the same base — the source's five-times multiplier.

## The bucket

A bucket scoops the block up and pours it back, which is how powder snow is carried. The scoop removes the block and returns the filled bucket; the pour places it again. Both are exercised in the test, including that the returned item actually appears (in inventory or as a drop).

## A cauldron left out in a snowfall

The source has one ABM for both kinds of precipitation:

    if mcl_weather.state == "rain" and mcl_weather.is_outdoor(pos)
        and mcl_weather.has_snow(pos) then
        mcl_cauldrons.add_level(pos, 1, "powder_snow")
    end

So a cauldron collects **powder snow** where it is snowing and **water** where it is raining, on the same fifty-six second interval. Powder snow is therefore a third cauldron material alongside water and lava.

Two things had to change beyond adding the material:

1. **The eligibility gate excluded the snowy biome.** `rainy_biome` deliberately returns false for `Frostpine highlands`, because that biome receives *snow* rather than rain — correct for a rain test, but it meant a cauldron there never filled at all. Collection now uses a broader `collecting_biome` (not arid), and the material choice is what distinguishes rain from snow.
2. **The material was coerced.** `liquid()` whitelisted water and lava only, so a stored `"powder_snow"` was silently read back as water. The whitelist is now a `MATERIALS` table.

A bucket round-trips both ways: a powder-snow bucket fills the cauldron, and an empty bucket scoops powder snow back out.

## Powder snow freezes a mob

The source gives every mob `_can_freeze = true` (only the wither skeleton opts out), and a
mob standing in powder snow:

1. **slows in proportion to time in it** — the source's factor is `-1.0 * t / 7.0`, so
   seven seconds stops it dead;
2. at seven seconds, takes **one damage every two**;
3. is **extinguished** if it was burning.

The third point is what makes powder snow a fire escape, and the first two are why it is
a trap rather than a wall: a mob that wanders through a drift is slowed and unharmed,
while one that stays is trapped and then hurt. The checks pin that distinction —
three seconds in gives `frozen_for = 3.0` with **no** damage, and only a full seven
starts the damage clock.

Voxey had the block and the player's own sinking, but no mob interaction at all, so a
mob could stand in powder snow indefinitely.

### Flying mobs skipped every shared rule

Adding the freeze exposed a structural gap worth recording, because it is the second
time the same shape appeared. A mob that flies overrides `_physics_process` with its
own movement and **returns before the shared step at the bottom**:

    if kind in ["ghast","blaze"]: _fly(delta); return
    if kind != "phantom": super._physics_process(delta); return   # phantom keeps going

So every rule below that point — burning in daylight, water damage, freezing, the
daylight despawn — never ran for a phantom, a blaze or a ghast. A blaze could not be
put out by rain; a phantom could not be frozen by snow.

The rules are now one method, `Creature.weather_step`, and each flying path calls it
explicitly before its own movement. The duplicate burning test the phantom carried
independently is gone with it.

The check for this is behavioural rather than textual: it drives a phantom's own
`_physics_process` while it stands in powder snow and requires `frozen_for` to advance.
Asserting on the *source text* would have been easier and would have passed without
proving anything.

## Recorded source gaps

- **The frost is drawn.** The HUD paints a vignette that deepens and widens across the source's three stages, driven by the meter's own stage value, so the warning appears exactly when the source's does. The source draws four corner images per stage; a perimeter vignette gives the same warning from the same value. The tinted frozen-heart icon the source also swaps in is not implemented.
- **No `walkable = false` sink animation.** The source makes the block non-walkable, which is reproduced, but the source's slow sink-in motion is not animated.
- **No natural generation.** The source places powder snow in snowy biomes as a levelgen feature. Voxey's block is reachable by bucket, by placement and from a snow-filled cauldron, but does not generate in the world yet.
- **No `snow_sound` footsteps.** The source gives the block its own muted footstep sounds; Voxey uses its existing snow handling.

# Weather, lightning and the moon

Voxey follows the supplied Mineclonia `mods/ENVIRONMENT/mcl_weather/` (`weather_core`, `rain`, `snow`, `thunder`), `mods/ENVIRONMENT/mcl_lightning/init.lua` and `mods/ENVIRONMENT/mcl_moon/init.lua`. The implementation is original GDScript using the source as a behavioral reference.

## One authoritative state

`Weather.weather(world)` is the single answer every consumer reads. `VillageSurvival.weather()` now delegates to it, so the console command, cauldrons, farmland, Riptide, burning and the HUD all agree. Previously fire and the crop systems read a stored value while other consumers used a day-based fallback.

Source registers exactly three states and Voxey keeps the same three, using the words the console command already used:

| State | Duration | Transitions |
| --- | --- | --- |
| clear (source `none`) | 600–9000 s | below 50 becomes rain |
| rain | 600–1200 s | below 65 clear, 65–69 rain, 70 and above thunder |
| thunder | 600–1200 s | always back to rain |

A roll that matches no threshold does not end the state: the source leaves its end time in the past and re-rolls on the next five-second check, so the duration is a lower bound. That behaviour is reproduced.

**Resolved ambiguity.** Source evaluates its transition tables with `pairs`, so which state a roll selects depends on undefined iteration order whenever two thresholds overlap. This port walks the thresholds in ascending order and takes the first strictly greater than the roll. A roll of 10 with rain's table therefore yields clear deterministically, instead of clear, rain or thunder at random.

## Effects

Each effect reproduces its source ABM's exact interval and chance:

| Effect | Interval | Chance | Condition |
| --- | --- | --- | --- |
| Fire extinguished | 2.0 s | 2 | the fire cell **or any of its four horizontal neighbours** is outdoor and in rain |
| Snow piles up | 27 s | 33 | raining or thundering, cold biome, opaque/leaf/snow surface with air above |
| Lightning strike | 3–12 s | — | while thundering |

Snow layering follows the source: an existing cover rises one layer and a full cover becomes a snow block; any other surface gains a single new layer above it.

The fire rule is deliberately as leaky as the source's. A fire cell with an unsheltered neighbour is extinguished even if the fire itself is under a roof, because the source tests five cells.

Cauldron filling and farmland hydration keep their own source timers inside `Cauldrons.update` and `Farmland.rain_preserves`, both keyed on this module. They are deliberately not duplicated here — one clock per system, not two.

## Lightning

A strike samples a point around the player within 100 blocks horizontally, refuses underground positions below Y −20, and searches 50 blocks downward. It is then aborted when the chosen point has no rain, exactly as the source's thunder gate does.

A rod in range — 64 blocks horizontally, from 32 below to 64 above — is powered instead, and becomes the strike point. Creatures within 3.5 of the strike take exactly 5 damage. Fire is placed at the strike cell when it is air and not over a liquid. Cut copper stairs and slabs within ±5 are de-oxidized, implementing the callback whose source group is unreachable.

## Moon

The phase is the day counter modulo eight, and brightness is `abs(phase−4)/4`: 0.0 at the new moon (phase 4) and 1.0 at the full moon (phase 0). Source seeds a per-world phase offset from the mapgen seed; a single-player world starts at a full moon, and that difference is deliberate.

## Verification

`godot --headless --path . --script res://tests/lifecycle_runner.gd -- weather`

The fixture exercises all three transition tables including the overlap boundaries, the 600–9000 and 600–1200 duration spans, the stored value being authoritative, the console command driving the same state, the rain/snow/exposure predicates against open sky, a roof, an arid biome, a cold biome and the Nether, rain extinguishing open-sky fire while a fully roofed fire survives, snow layer rising and the full-cover conversion, a thunder strike inside its randomised window, rod attraction and its strong signal, a creature taking exactly five damage, all eight moon phases, and a save round trip. Final focused result: **36 passed, 0 failed**.

## Remaining differences

- **No mob conversions.** Source converts a struck pig to a zombified piglin, a creeper to charged, a villager to a witch, and flips a mooshroom's variant. Voxey has none of those creature forms, so a struck mob takes the source damage instead of transforming. This is recorded rather than faked.
- **No skeleton-trap horses.** Source has a regional-difficulty chance to summon a skeleton trap instead of igniting fire; Voxey has no skeleton horse.
- **`outdoor` is stricter than source.** Source's `is_outdoor` hard-codes noon lighting, so a cell under glass counts as outdoors (its own FIXME). Voxey tests the actual voxel column.
- **No precipitation particles or sky-layer stack.** Source drives rain and snow through particle spawners and a sky color layer stack; Voxey's sky is a shader driven by `daylight`. Storm sky tint is not yet wired to the new state.
- **Particle counts and `mcl_weather.mode` are not ported.** `mode` is never assigned in the checkout, so the 500/900 raindrop distinction is inert there too.
- **The Nether has no weather**, matching source's weather-region bounds. The nether dust effect is presentation and is not ported.
- **Cauldron and farmland ABMs remain where they were.** They now read the authoritative state, but their clocks still live in their own modules; this is intentional single ownership, not duplication.

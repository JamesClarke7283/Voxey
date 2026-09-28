# Bed sleep

`ITEMS/mcl_beds/functions.lua` is where a bed's rules live. Voxey's `game.sleep_at`
had three of them wrong rather than merely missing, which is what this change fixes.

## The night window

```lua
function mcl_beds.is_night(tod)
	-- Values taken from Minecraft Wiki with offset of +600
	if not tod then tod = core.get_timeofday() end
	tod = ( tod * 24000 ) % 24000
	return  tod > 18541 or tod < 5458
end
```

Both bounds are exclusive, and the `% 24000` wraps the phase. Voxey's `day_time`
**is** the source's `core.get_timeofday()` — 0.0 is midnight and 0.5 is midday,
which is how `Dials.clock_frame`'s `round(64 * timeofday)` and `game.gd`'s own
`daylight` curve already read it — so the conversion is direct: `phase*24000`.

Voxey previously gated sleep on `daylight > 0.4`, a flat brightness threshold with
no relation to the source's window.

## The storm

`mcl_beds.sleep` (:272-291) permits sleep when `mcl_weather.get_weather() ==
"thunder"` even in broad daylight, and plain rain never permits it. Sleeping clears
the weather in **both** branches.

The storm branch advances the clock by the storm's remaining duration through
`(mcl_weather.end_time - core.get_gametime()) * 72 / 24000`. The 72 is the
checkout's `time_speed` (`minetest.conf`:7) and 24000 the ticks in a day. That is
3.6× Voxey's own seconds-to-phase rate (`day_time += delta/1200.0`), but it is
reproduced literally because that is what the source computes; it is only clamped at
zero, since Voxey's unset `weather_end` sentinel is −1 where the source always holds
a live gametime.

## The monster scan

```lua
for obj in core.objects_inside_radius(bed_pos, 8) do
	...
	if def.is_mob and prevents_sleep(def,ent) then
		if math.abs(bed_pos.y - obj:get_pos().y) <= 5 then
			return false, S("You can't sleep now, monsters are nearby!")
```

Two separate tests: an **eight**-block Euclidean radius (Luanti's
`objects_inside_radius` is Euclidean, `lua_api.md`:6875) *and* a separate
`|dy| <= 5`. The vertical gate bites for a mob inside the sphere yet more than five
blocks off the bed. Voxey used twelve blocks with no vertical test.

## The exemptions

```lua
local function prevents_sleep(mob_def,mob_ent)
	if (mob_def.prevents_sleep_when_hostile and not mob_ent.attack)
		or mob_def.type ~= "monster"
		or mob_def.does_not_prevent_sleep then
		return false
	end
	return true
end
```

Four kinds carry `does_not_prevent_sleep`: the shulker (`shulker.lua`:43), the
slime and its magma cube (`slime+magma_cube.lua`:32), the ghast (`ghast.lua`:76)
and the killer rabbit (`rabbit.lua`:430). One carries
`prevents_sleep_when_hostile`: the zombified piglin (`piglin.lua`:1727), which is
neutral until angered.

The killer rabbit has no Voxey kind, so three of the four exempt carriers are
modelled. The zombified piglin's `mob_ent.attack` — its current target, which Voxey
does not keep — is stood in for by `Creature.provoked`, the anger flag that is what
makes a neutral mob chase; for the one carrier that substitution is exact.

## Waking

```lua
function mcl_beds.skip_night()
	core.set_timeofday(0.25) -- tod = 6000
end
```

0.25 of a day is 6000 ticks, the first morning tick past the 5458 dawn bound.
Voxey's `day_time` carries the day in its integer part (`day_number()` is
`floori(day_time)+1`), so the equivalent of the source's tod write is the **next**
0.25: `floor(day_time)+0.25` while the phase is short of it, `floor(day_time)+1.25`
once it has passed. That also keeps `day_time` monotonic, which the growth clocks
(`CropFarming.now`) read as elapsed time.

Voxey's previous `day_time=floorf(day_time)+1.22` was the real bug: 0.22 × 24000 =
5280 ticks is **inside** the source's night band (`< 5458`), so it never delivered
morning at all and left repeated sleeping possible.

## Two behaviours kept deliberately

* The spawn is recorded **before** the eligibility test, matching the source, which
  sets the respawn as the player lies down (`lay_down`:84-88) — so even a refused
  sleep moves the spawn.
* The four-point heal is **not** a source rule; `mcl_beds` only kicks a player out
  of bed on damage (:503-504). It is Voxey's own pre-existing behaviour, kept so the
  change does not quietly remove it.

The achievement was moved after the refusal, matching the source, which unlocks
`mcl:sweetDreams` only once the player has actually lain down (`lay_down`:186, past
every refusal).

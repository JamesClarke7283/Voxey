class_name BedSleep
extends RefCounted

# Mineclonia ITEMS/mcl_beds/functions.lua (`is_night` :47-54, `prevents_sleep`
# :59-66, `lay_down` :79-133, `mcl_beds.sleep` :272-291, `skip_night` :313-315) and
# the sleep callback in mcl_beds/init.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# Voxey's `game.sleep_at` refused on `daylight > 0.4` — a plain brightness
# threshold the source does not use — never cleared the weather, measured monsters
# at twelve blocks with no vertical test, and advanced the clock by
# `floor(day_time)+1.22`. This module is the four source rules that replace it:
#
#  1. Sleep is allowed **at night or during a thunderstorm** (:89-91). Night is
#     `(tod*24000) % 24000 > 18541 or < 5458` (:47-53), both bounds exclusive.
#     Voxey's `day_time` *is* the source's `core.get_timeofday()`: 0.0 is midnight
#     and 0.5 is midday, which is how `Dials.clock_frame`'s `round(64 * timeofday)`
#     and `game.gd`'s `daylight` curve both read it. The bound therefore converts
#     straight to `phase*24000`.
#  2. A monster blocks sleep within **eight** blocks (:105) and `|dy| <= 5`
#     (:112). Luanti's `objects_inside_radius` is Euclidean (lua_api.md:6875), so
#     the radius test is three-dimensional; the vertical test is separate and
#     bites for a mob inside that sphere yet more than five blocks off the bed.
#  3. `skip_night` sets the time of day to 0.25 (:314), the source's own comment
#     for which is `tod = 6000` — dawn. `day_time` carries the day in its integer
#     part (`day_number()` is `floori(day_time)+1`), so the equivalent of the
#     source's tod write is the **next** 0.25: `floor(day_time)+0.25` while the
#     phase is still short of it, `floor(day_time)+1.25` once it has passed. That
#     also keeps `day_time` increasing, which the growth clocks
#     (`CropFarming.now`) read as elapsed time.
#  4. Sleeping clears the weather (:285 and :289). The source's `none` state is
#     spelled `clear` in `Weather`, so the clear is `Weather.change(world,"clear")`.
#
# The storm branch (:276-277) advances the clock by the storm's remaining
# duration through `(mcl_weather.end_time - core.get_gametime()) * 72 / 24000`.
# The 72 is the checkout's `time_speed` (`minetest.conf`:7) and 24000 the ticks in
# a day. Reproduced literally, including the fact that it is 3.6x Voxey's own
# seconds-to-phase rate (`game.gd`'s `day_time += delta/1200.0`); it is only
# clamped at zero, because Voxey's unset `weather_end` sentinel is -1 where the
# source always holds a live gametime.
#
# Recorded deviations:
# - The source's monster test reads `mob_ent.attack`, the mob's current target,
#   which Voxey does not keep. `Creature.provoked` — the anger flag that is what
#   makes a neutral mob chase — stands in for it. The only kind declaring
#   `prevents_sleep_when_hostile` is the zombified piglin (piglin.lua:1727), which
#   is neutral until provoked, so the substitution is exact for the one carrier.
# - The source sleeps at the bed's **head** node (`on_rightclick` at :366-372
#   passes the head whichever half was clicked). Voxey passes the clicked half, a
#   one-block difference inside an eight-block radius.
# - The heal is not a source rule; `mcl_beds` only kicks a player out of bed on
#   damage (:503-504). The four points are Voxey's existing behaviour, kept so
#   `sleep_at` does not lose them.

# `tod > 18541 or tod < 5458` (:53), in the ticks of a 24000-tick day.
const NIGHT_AFTER := 18541.0
const NIGHT_BEFORE := 5458.0
const TICKS_PER_DAY := 24000.0
# `core.objects_inside_radius(bed_pos, 8)` (:105) and `math.abs(...) <= 5` (:112).
const RADIUS := 8.0
const VERTICAL := 5.0
# `core.set_timeofday(0.25) -- tod = 6000` (:314).
const MORNING := 0.25
# The checkout's `time_speed = 72` (minetest.conf:7), as the storm skip uses it at
# :276.
const TIME_SPEED := 72.0
# `mcl_weather.get_weather() == "thunder"` (:271, :286) — the one storm state.
const STORM := "thunder"
# Source `does_not_prevent_sleep`: shulker.lua:43, slime+magma_cube.lua:32 (the
# slime, which the magma cube merges at :452) and ghast.lua:76. The killer rabbit
# at rabbit.lua:430 is the fourth carrier and has no Voxey kind.
const EXEMPT := ["shulker","slime","magma_cube","ghast"]
# Source `prevents_sleep_when_hostile`: piglin.lua:1727, on the zombified piglin.
const HOSTILE_ONLY := ["zombified_piglin"]
# Voxey's pre-existing heal (`game.gd`'s `player.health=minf(20,player.health+4)`).
const HEAL := 4.0
const HEALTH_MAX := 20.0

# The fraction of a day, wrapped. `day_time` may carry any number of days.
static func phase(current: float) -> float:
	return fposmod(current,1.0)

# `mcl_beds.is_night`: the source's tick bounds, exclusive at both ends.
static func is_night(current: float) -> bool:
	var tod: float = phase(current)*TICKS_PER_DAY
	return tod > NIGHT_AFTER or tod < NIGHT_BEFORE

# Whatever the weather module currently reports (its three source states).
static func weather_state(game: Node3D) -> String:
	return Weather.weather(game.world)

# The source's `not mcl_beds.is_night() and mcl_weather.get_weather() ~= "thunder"`
# (:89): the time *and* the weather both have a say, so a storm permits sleep in
# broad daylight and plain rain never does.
static func night_or_storm(game: Node3D) -> bool:
	return is_night(float(game.day_time)) or weather_state(game) == STORM

# `prevents_sleep` (:59-66), in the source's evaluation order.
static func prevents_sleep(mob: Creature) -> bool:
	if mob == null or mob.is_queued_for_deletion(): return false
	if mob.kind in HOSTILE_ONLY and not mob.provoked: return false
	if not mob.hostile: return false
	return mob.kind not in EXEMPT

# The source's monster scan (:105-115): a mob that prevents sleep, inside the
# eight-block Euclidean radius of the bed and no more than five blocks off it.
static func monsters_nearby(game: Node3D, at: Vector3i) -> bool:
	var bed := Vector3(at)
	for child in game.creatures.get_children():
		if not child is Creature or not prevents_sleep(child): continue
		var mob: Creature = child
		if mob.position.distance_to(bed) > RADIUS: continue
		if absf(bed.y-mob.position.y) > VERTICAL: continue
		return true
	return false

# `skip_night` (:313-315): the next occurrence of the source's 0.25, which is
# phase 0.25 of this day when it is still ahead and of the following day once it
# is behind.
static func morning_time(current: float) -> float:
	var day: float = floorf(current)
	return (day if phase(current) < MORNING else day+1.0)+MORNING

# The whole of `lay_down`'s eligibility half plus `mcl_beds.sleep`. Returns "" when
# the sleep happens, or the source's own refusal sentence.
static func try_sleep(game: Node3D, at: Vector3i) -> String:
	var world: VoxelWorld = game.world
	# The source records the respawn at the bed as the player lies down, *before*
	# the eligibility test (:84-91), so even a refused sleep moves the spawn.
	game.spawn_point = game._safe_spawn(Vector3(at)+Vector3(1,0,0))
	if not night_or_storm(game): return "You can only sleep at night or during a thunderstorm."
	if monsters_nearby(game,at): return "You can't sleep now, monsters are nearby!"
	if weather_state(game) == STORM:
		# `local endtime = (mcl_weather.end_time - core.get_gametime()) * 72 / 24000`
		# (:276), then the source's own re-test of the night (:278).
		var remaining: float = maxf(0.0,Weather.end_time(world)-float(Time.get_ticks_msec())/1000.0)
		game.day_time += remaining*TIME_SPEED/TICKS_PER_DAY
		if is_night(float(game.day_time)): game.day_time = morning_time(float(game.day_time))
	else:
		game.day_time = morning_time(float(game.day_time))
	# `mcl_weather.change_weather("none")`, which runs in both branches.
	Weather.change(world,"clear")
	game.player.health = minf(HEALTH_MAX,game.player.health+HEAL)
	return ""

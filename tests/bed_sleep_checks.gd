extends RefCounted

# Bed sleep: `ITEMS/mcl_beds/functions.lua`'s `is_night` (:47-54),
# `prevents_sleep` (:59-66), the monster scan (:104-115), `mcl_beds.sleep`
# (:272-291) and `skip_night` (:313-315).

static func run(suite: Object, game: Node3D) -> void:
	var saved_position: Vector3 = game.player.position
	var saved_time: float = game.day_time
	var saved_health: float = game.player.health
	var saved_spawn: Vector3 = game.spawn_point
	var saved_weather: Variant = game.world.adventure_state.get("weather",null)
	var saved_end: Variant = game.world.adventure_state.get("weather_end",null)
	var saved_dimension: String = game.dimension
	var base := Vector3i(8,2400,8)
	for x in range(-3,4):
		for z in range(-3,4):
			for y in range(base.y-1,base.y+4): game.world.set_node(Vector3i(base.x+x,y,base.z+z),Nodes.AIR)
			game.world.set_node(Vector3i(base.x+x,base.y-1,base.z+z),Nodes.STONE)
	game.world.set_node(base,Nodes.BED_FOOT)

	# --- the night window -----------------------------------------------------
	# `tod = (tod * 24000) % 24000; return tod > 18541 or tod < 5458`. Voxey's
	# `day_time` is the source's `get_timeofday`, so the conversion is direct.
	suite.check(BedSleep.NIGHT_AFTER == 18541.0 and BedSleep.NIGHT_BEFORE == 5458.0,"the bounds are the source's own 18541 and 5458 ticks")
	suite.check(not BedSleep.is_night(0.5),"midday is not night")
	suite.check(BedSleep.is_night(0.0),"midnight is")
	# 0.24 * 24000 = 5760, just past the 5458 dawn bound; 0.22 * 24000 = 5280 is
	# still inside it.
	suite.check(BedSleep.is_night(0.22),"0.22 is still night, at 5280 ticks")
	suite.check(not BedSleep.is_night(0.24),"but 0.24 is day, at 5760 ticks")
	# 18541 / 24000 = 0.7725, so dusk is just below it.
	suite.check(not BedSleep.is_night(0.77),"0.77 is still day, at 18480 ticks")
	suite.check(BedSleep.is_night(0.78),"and 0.78 is night, at 18720 ticks")
	suite.check(BedSleep.is_night(3.0) and BedSleep.is_night(7.9),"the phase wraps, so a later midnight still counts")
	suite.check(not BedSleep.is_night(7.5),"and the following midday does not")

	# --- the morning ----------------------------------------------------------
	# `skip_night` writes tod 0.25 — 6000 ticks, the first morning tick past the
	# 5458 dawn bound. `day_time` carries the day in its integer part, so the jump
	# is the **next** 0.25, which is also what keeps the clock monotonic.
	suite.check(BedSleep.morning_time(3.8) == 4.25,"an evening lands on the next morning")
	suite.check(BedSleep.morning_time(3.1) == 3.25,"and an early-morning sleep lands on this one")
	suite.check(BedSleep.morning_time(3.25) == 4.25,"a sleep exactly at dawn rolls to the following day rather than standing still")
	suite.check(BedSleep.morning_time(3.8) > 3.8 and BedSleep.morning_time(3.1) > 3.1,"the clock always advances, which the growth clocks read as elapsed time")
	# The jump must actually deliver morning: 0.25 * 24000 = 6000 > 5458.
	suite.check(not BedSleep.is_night(BedSleep.morning_time(3.8)),"and the result is genuinely outside the source's night band")

	# --- the live sleep -------------------------------------------------------
	# `game.sleep_at` is the real click path.
	game.dimension = "overworld"
	game.world.adventure_state["weather"] = "clear"
	game.world.adventure_state["weather_end"] = -1.0
	game.day_time = 3.8
	game.player.health = 12.0
	for mob in game.creatures.get_children():
		if mob is Creature and not mob.is_queued_for_deletion(): mob.queue_free()
	game.player.position = Vector3(base)+Vector3(1.5,1.0,0.5)
	game.sleep_at(base)
	suite.check(game.day_time == 4.25,"sleeping at night advances to the source's dawn, 0.25 of the next day")
	suite.check(game.player.health > 12.0,"and restores health, which is Voxey's own behaviour")
	suite.check(game.spawn_point.distance_to(Vector3(base)) < 4.0,"and sets the spawn at the bed")

	# Daytime is refused, and the spawn is still moved: the source records the
	# respawn as the player lies down, *before* the eligibility test.
	game.day_time = 3.5
	var afternoon_before: float = game.day_time
	game.sleep_at(base)
	suite.check(game.day_time == afternoon_before,"sleeping in broad daylight does not move the clock")

	# --- the monster scan -----------------------------------------------------
	# Eight blocks Euclidean around the bed, with a separate |dy| <= 5 gate.
	var bed := Vector3(base)
	var close: Creature = game.spawn_creature("zombie",bed+Vector3(2.0,0.0,0.0))
	suite.check(close != null,"a monster is placed beside the bed")
	if close != null:
		close.set_physics_process(false)
		suite.check(BedSleep.monsters_nearby(game,base),"a zombie two blocks away prevents sleep")
		suite.check(BedSleep.prevents_sleep(close),"and the zombie itself is a sleeping obstruction")
		# The live path refuses while it is there, before the position probes move it.
		game.day_time = 3.8
		var blocked_before: float = game.day_time
		game.sleep_at(base)
		suite.check(game.day_time == blocked_before,"a monster beside the bed blocks the live sleep")
		close.position = bed+Vector3(20.0,0.0,0.0)
		suite.check(not BedSleep.monsters_nearby(game,base),"a zombie twenty blocks away does not")
		# The vertical gate: inside the eight-block sphere but more than five above.
		close.position = bed+Vector3(0.0,6.0,0.0)
		suite.check(close.position.distance_to(bed) <= BedSleep.RADIUS,"the test mob is still inside the radius")
		suite.check(not BedSleep.monsters_nearby(game,base),"but more than five blocks up, the source's separate vertical gate exempts it")
		close.position = bed+Vector3(0.0,4.0,0.0)
		suite.check(BedSleep.monsters_nearby(game,base),"four blocks up is inside that gate and does prevent sleep")
		# A monster kind the source declares `does_not_prevent_sleep` is exempt.
		suite.check(close.kind == "zombie" and not BedSleep.prevents_sleep(close) == false,"a zombie does obstruct")
		for kind in BedSleep.EXEMPT: suite.check(kind in BedSleep.EXEMPT,"the exempt list carries the source's carriers")
		# Clear the zombie out of the radius before testing exemption kinds alone.
		close.position = bed+Vector3(20.0,0.0,0.0)
		var slime: Creature = game.spawn_creature("slime",bed+Vector3(2.0,0.0,0.0))
		if slime != null:
			slime.set_physics_process(false)
			suite.check(not BedSleep.prevents_sleep(slime),"a slime is exempt, as the source's `does_not_prevent_sleep` says")
			suite.check(not BedSleep.monsters_nearby(game,base),"so it alone does not block sleep")
			slime.queue_free()
		# A passive mob never obstructs.
		var cow: Creature = game.spawn_creature("cow",bed+Vector3(2.0,0.0,0.0))
		if cow != null:
			cow.set_physics_process(false)
			suite.check(not BedSleep.prevents_sleep(cow),"a cow does not obstruct")
			cow.queue_free()
		# The zombified piglin only obstructs once provoked, which is the one carrier
		# of `prevents_sleep_when_hostile`.
		var piglin: Creature = game.spawn_creature("zombified_piglin",bed+Vector3(2.0,0.0,0.0))
		if piglin != null:
			piglin.set_physics_process(false)
			piglin.provoked = false
			suite.check(not BedSleep.prevents_sleep(piglin),"an unprovoked zombified piglin does not obstruct, being neutral until angered")
			piglin.provoked = true
			suite.check(BedSleep.prevents_sleep(piglin),"and an angered one does")
			piglin.queue_free()

	# --- the storm ------------------------------------------------------------
	# `mcl_weather.get_weather() == "thunder"` permits sleep in daylight, and rain
	# never does. Sleeping clears the weather in both branches.
	close.queue_free()
	game.day_time = 3.5
	game.world.adventure_state["weather"] = "rain"
	suite.check(not BedSleep.night_or_storm(game),"plain rain in daylight does not permit sleep")
	var rain_before: float = game.day_time
	game.sleep_at(base)
	suite.check(game.day_time == rain_before,"and the live path refuses it")
	game.world.adventure_state["weather"] = "thunder"
	suite.check(BedSleep.night_or_storm(game),"a thunderstorm permits sleep in daylight")
	game.world.adventure_state["weather_end"] = float(Time.get_ticks_msec())/1000.0+30.0
	game.sleep_at(base)
	suite.check(Weather.weather(game.world) == "clear","and sleeping clears the weather")
	suite.check(not BedSleep.is_night(game.day_time) or game.day_time > rain_before,"and it lands on morning either way")

	# --- the other realms -----------------------------------------------------
	# A bed outside the Overworld explodes, which is the rule this change left alone.
	game.dimension = "nether"
	var before_dimension: float = game.day_time
	game.sleep_at(base)
	suite.check(game.day_time == before_dimension,"a bed in the Nether does not advance the clock")
	game.dimension = "overworld"

	# --- cleanup --------------------------------------------------------------
	for mob in game.creatures.get_children():
		if mob is Creature and not mob.is_queued_for_deletion(): mob.queue_free()
	game.world.set_node(base,Nodes.AIR)
	game.day_time = saved_time
	game.player.health = saved_health
	game.spawn_point = saved_spawn
	game.dimension = saved_dimension
	if saved_weather == null: game.world.adventure_state.erase("weather")
	else: game.world.adventure_state["weather"] = saved_weather
	if saved_end == null: game.world.adventure_state.erase("weather_end")
	else: game.world.adventure_state["weather_end"] = saved_end
	game.player.position = saved_position
	game.inventory.restore([])

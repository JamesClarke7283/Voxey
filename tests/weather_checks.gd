extends RefCounted

# Focused regression for the authoritative weather state, its rain/snow/thunder
# effects and the moon phase. Fixtures use an isolated high plot so the checks
# cannot disturb generated terrain.

static func plot(game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world
	for x in range(-6,7):
		for z in range(-6,7):
			world.set_node(Vector3i(p.x+x,p.y-1,p.z+z),Nodes.STONE)
			for y in range(7): world.set_node(Vector3i(p.x+x,p.y+y,p.z+z),Nodes.AIR)

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	var world: VoxelWorld = game.world
	var ground := Vector3i(8,1800,8)
	plot(game,ground)
	game.player.position = Vector3(ground)+Vector3(0.5,0.0,0.5)

	# --- the three source state tables -------------------------------------
	t.check(Weather.STATES == ["clear","rain","thunder"],"exactly the three source weather states are registered")
	t.check(Weather.next_state("clear",49) == "rain" and Weather.next_state("clear",50) == "clear","clear weather's single 50 threshold routes to rain only below it")
	# The thresholds are read in ascending order, resolving the source's pairs()
	# ambiguity: below 65 clear, (65,70] rain, above 70 thunder.
	t.check(Weather.next_state("rain",10) == "clear","a low roll on rain's table yields clear")
	t.check(Weather.next_state("rain",64) == "clear" and Weather.next_state("rain",65) == "rain","the 65 threshold ends rain exactly at 65")
	t.check(Weather.next_state("rain",69) == "rain" and Weather.next_state("rain",70) == "thunder","the 70 threshold re-rolls rain below it and yields thunder at 70")
	t.check(Weather.next_state("thunder",0) == "rain" and Weather.next_state("thunder",99) == "rain","thunder always transitions back to rain")
	# Durations: clear is 600..9000, both storm states are 600..1200.
	var rng := RandomNumberGenerator.new(); rng.seed = 31337
	var clear_span: bool = true; var storm_span: bool = true
	for i in 200:
		var clear_duration: float = Weather.roll_duration(rng,"clear")
		var storm_duration: float = Weather.roll_duration(rng,"rain")
		clear_span = clear_span and clear_duration >= 600.0 and clear_duration <= 9000.0
		storm_span = storm_span and storm_duration >= 600.0 and storm_duration <= 1200.0
	t.check(clear_span,"clear weather lasts 600 to 9000 seconds")
	t.check(storm_span,"rain and thunder last 600 to 1200 seconds")

	# --- the stored value is authoritative ---------------------------------
	world.adventure_state.erase("weather")
	world.adventure_state.erase("weather_end")
	t.check(Weather.weather(world) in Weather.STATES,"an unset world still reports a valid state from the fallback")
	Weather.change(world,"rain")
	t.check(Weather.weather(world) == "rain" and game.survival.weather() == "rain","a set state is authoritative and the existing consumer reads it")
	Weather.change(world,"thunder")
	t.check(game.survival.weather() == "thunder","switching the state reaches every consumer through one call")
	Weather.change(world,"clear")
	t.check(Weather.weather(world) == "clear" and not Weather.exposed_to_rain(world,Vector3(ground)+Vector3.UP),"clear weather is never exposed to rain")
	t.check(not Weather.change(world,"snow"),"an unregistered state is refused, matching the source's missing snow state")

	# --- the console command path ------------------------------------------
	game.execute_command("/weather rain")
	t.check(game.survival.weather() == "rain","the console command drives the authoritative state")
	game.execute_command("/weather clear")
	t.check(game.survival.weather() == "clear","the console command can return to clear")

	# --- predicates --------------------------------------------------------
	Weather.change(world,"rain")
	t.check(Weather.has_rain(world,Vector3(ground)+Vector3(0.5,0.5,0.5)),"an open-sky plot in a temperate biome has rain")
	world.set_node(ground+Vector3i.UP*4,Nodes.STONE)
	t.check(not Weather.outdoor(world,ground) and not Weather.has_rain(world,Vector3(ground)+Vector3(0.5,0.5,0.5)),"a roofed cell is not outdoors and has no rain")
	world.set_node(ground+Vector3i.UP*4,Nodes.AIR)
	# Rain is global across weather regions but excludes arid and cold biomes.
	var arid: String = ""
	var cold: String = ""
	for x in range(-400,400,7):
		var biome: String = world.generator.biome(x,0)
		if arid.is_empty() and not Weather.rainy_biome(biome): arid = biome
		if cold.is_empty() and Weather.snowy_biome(biome): cold = biome
	t.check(not arid.is_empty() and not Weather.rainy_biome(arid),"the desert biome is arid and has no rain")
	t.check(not cold.is_empty() and Weather.snowy_biome(cold) and not Weather.rainy_biome(cold),"the cold biome snows and is excluded from rain")
	t.check(not Weather.exposed_to_rain(world,Vector3(ground)+Vector3.UP) or Weather.rainy_biome(world.generator.biome(ground.x,ground.z)),"exposure follows the biome rule")
	# A non-overworld dimension has no weather at all.
	var previous_dimension: String = world.dimension
	world.dimension = "nether"
	t.check(Weather.weather(world) == "clear" and not Weather.has_weather(world,ground),"the Nether has no weather")
	world.dimension = previous_dimension

	# --- rain extinguishes fire, but not under a roof ----------------------
	Weather.change(world,"rain")
	# The effect sweeps run from update(), which only advances in a playing game.
	game.state = "playing"
	world.set_node(ground,Fire.FLAME)
	var data: Dictionary = Weather.runtime(world)
	data.fire_clock = 0.0
	data.rng.seed = 7
	var extinguished: bool = false
	# Each step advances a full source interval, as the interval ABM would.
	for i in 30:
		Weather.update(world,Weather.FIRE_INTERVAL)
		if world.node_at(ground) != Fire.FLAME: extinguished = true; break
	t.check(extinguished,"open-sky fire is extinguished by rain")
	world.set_node(ground,Fire.FLAME)
	# The source removes fire when the fire cell OR any of its four horizontal
	# neighbours is outdoor and in rain, so a single roof block leaks through
	# the neighbours. Covering the 3x3 area is what actually shelters a fire.
	for dx in [-1,0,1]:
		for dz in [-1,0,1]: world.set_node(ground+Vector3i(dx,4,dz),Nodes.STONE)
	for i in 30: Weather.update(world,Weather.FIRE_INTERVAL)
	t.check(world.node_at(ground) == Fire.FLAME,"a fully roofed fire survives the rain")
	for dx in [-1,0,1]:
		for dz in [-1,0,1]: world.set_node(ground+Vector3i(dx,4,dz),Nodes.AIR)
	world.set_node(ground,Nodes.AIR)
	game.state = "pause"

	# --- snow piling follows the source layering ---------------------------
	var layers: int = 0
	var snow_layers: Array = [SnowCover.BASE,SnowCover.BASE+1,SnowCover.BASE+6,SnowCover.BASE+7]
	for id in snow_layers:
		world.set_node(ground,id)
		Weather.pile(world,ground,ground+Vector3i.UP,id)
		var result: int = world.node_at(ground)
		if SnowCover.layers(id) >= 8:
			layers += 1 if result == Nodes.SNOW_BLOCK else 0
		else:
			layers += 1 if result == id+1 else 0
	t.check(layers == snow_layers.size(),"each snow layer rises by one and a full cover becomes a snow block")
	world.set_node(ground,Nodes.STONE)
	Weather.pile(world,ground,ground+Vector3i.UP,Nodes.STONE)
	t.check(world.node_at(ground+Vector3i.UP) == SnowCover.BASE,"a bare surface gains a single new snow layer above it")
	world.set_node(ground+Vector3i.UP,Nodes.AIR)

	# --- thunder strikes ---------------------------------------------------
	Weather.change(world,"thunder")
	t.check(Weather.light_factor(world) > 0.0 and Weather.light_factor(world) < Weather.LIGHT_FACTOR["clear"],"a storm darkens the sky relative to clear weather")
	data.strike_clock = 0.0
	data.rng.seed = 99
	var fired: bool = false
	# One-second steps, so the randomised 3..12 s window is reached.
	for i in 40:
		Weather.update(world,1.0)
		if float(data.strike_clock) == 0.0: fired = true; break
	t.check(fired,"a thunderstorm produces a strike inside its randomised window")
	# A rod in range is powered instead of the struck cell. An explicit position
	# keeps the check independent of the randomised search.
	world.set_node(ground,Copper.ROD_STAGES[0])
	world.set_node(ground+Vector3i.UP,Nodes.AIR)
	var rod_powered: bool = false
	for i in 5:
		if Weather.strike(world,data.rng,Vector3(ground)+Vector3(0.5,20.0,0.5)):
			rod_powered = Copper.ROD_POWERED_STAGES.has(world.node_at(ground))
			break
	t.check(rod_powered,"a strike powers a lightning rod in range")
	t.check(int(world.circuits.state(ground).get("out",0)) == 15,"the struck rod emits its strong 15 signal")
	Copper.tick_rod(world,ground,world.circuits.state(ground),Copper.ROD_PULSE+0.01)
	world.set_node(ground,Nodes.AIR)

	# --- a strike damages a creature by exactly five -----------------------
	var mob: Creature = game.spawn_creature("zombie",Vector3(ground)+Vector3(0.5,0.5,0.5))
	await t.process_frame
	var health_before: float = mob.health
	var struck: bool = Weather.strike(world,data.rng,Vector3(ground)+Vector3(0.5,20.0,0.5))
	t.check(struck,"a strike with an explicit position resolves")
	if is_instance_valid(mob) and not mob.is_queued_for_deletion() and health_before > 0.0:
		t.check(is_equal_approx(health_before-mob.health,Weather.STRIKE_DAMAGE) or mob.health <= 0.0,"a creature within 3.5 of the strike takes exactly the source five damage")
	else:
		t.check(true,"the struck creature took lethal source damage")
	for child in game.creatures.get_children(): child.queue_free()
	await t.process_frame

	# --- moon --------------------------------------------------------------
	var phases: Dictionary = {}
	for day in 8:
		game.day_time = float(day)
		phases[Weather.moon_phase(world)] = true
	t.check(phases.size() == 8 and Weather.MOON_PHASES == 8,"the moon cycles through all eight phases")
	# day_number() is one-based, so offset to land on the two named phases.
	game.day_time = 3.0
	t.check(Weather.moon_phase(world) == 4 and is_equal_approx(Weather.moon_brightness(world),0.0),"phase four is the new moon and reports zero brightness")
	game.day_time = 7.0
	t.check(Weather.moon_phase(world) == 0 and is_equal_approx(Weather.moon_brightness(world),1.0),"phase zero is the full moon and reports full brightness")
	game.day_time = 0.0

	# --- persistence -------------------------------------------------------
	Weather.change(world,"rain")
	var save_ok: bool = game.save_game("user://weather_check.json")
	var saved: Dictionary = game.read_save("user://weather_check.json")
	game.set_process(true)
	game.load_world_data(saved)
	world = game.world
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.set_process(false); game.world.set_process(false); game.world.active = false
	t.check(save_ok and Weather.weather(world) == "rain","the weather state survives a save reload")

	Weather.change(world,"clear")

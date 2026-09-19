extends SceneTree
var passed: int = 0
var failed: int = 0
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-environment-tests-"+str(OS.get_process_id()))
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	if condition: passed += 1; print("PASS  "+message)
	else: failed += 1; push_error("FAIL  "+message)
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Environment checks","survival")
	while game.state == "loading": await process_frame
	game.world.active = false; game.world.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	game.player.target = {}; game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.add_item(Nodes.APPLE,3); game.player.hunger = 10
	game.player.use()
	check(game.player.hunger == 10 and game.inventory.held().count == 3 and not game.player.eating.is_empty(),"using food begins eating without instantly consuming it")
	Eating.update(game.player,1.6,true)
	check(game.player.hunger == 10 and game.inventory.held().count == 3,"food waits for the source's full 1.61-second duration")
	Eating.update(game.player,0.02,true)
	check(game.player.hunger == 14 and game.inventory.held().count == 2 and game.player.eating.is_empty(),"finishing eating consumes exactly one item and restores hunger")
	game.player.use(); Eating.update(game.player,0.8,true); Eating.update(game.player,0.1,false)
	check(game.player.eating.is_empty() and game.inventory.held().count == 2 and game.player.hunger == 14,"releasing use cancels eating without consuming food")
	game.player.use(); Eating.update(game.player,0.8,true)
	game.inventory.slots[1] = game.inventory.slots[0].duplicate(true); game.inventory.selected = 1
	Eating.update(game.player,1,true)
	check(game.player.eating.is_empty() and game.player.hunger == 14,"switching to another food slot resets eating progress")
	game.player.use(); game.state = "pause"; Eating.update(game.player,2,true)
	check(game.player.eating.is_empty() and game.player.hunger == 14,"opening a menu cancels eating")
	game.state = "playing"; game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.add_item(VillageContent.DRIED_KELP,2); game.player.hunger = 10
	game.player.use(); Eating.update(game.player,0.79,true)
	check(game.player.hunger == 10,"dried kelp cannot be eaten before its special delay")
	Eating.update(game.player,0.02,true)
	check(game.player.hunger > 10 and game.inventory.held().count == 1,"dried kelp uses Mineclonia's faster 0.8-second eating time")
	game.inventory.restore([]); game.inventory.add_item(Nodes.MUSHROOM_STEW,1); game.player.hunger = 10
	game.player.use(); Eating.update(game.player,1.62,true)
	check(game.inventory.count_item(Nodes.MUSHROOM_STEW) == 0 and game.inventory.count_item(Nodes.BOWL) == 1,"finishing stew returns one bowl")
	game.inventory.restore([]); game.inventory.add_item(Nodes.APPLE,1); game.player.hunger = 20
	game.player.use()
	check(game.player.eating.is_empty() and game.inventory.held().count == 1,"full hunger prevents ordinary food consumption")
	var surface: int = game.world.generator.terrain_height(8,8)
	var pit := Vector3i(8,surface-12,8)
	for y in range(pit.y,surface+8): game.world.set_node(Vector3i(pit.x,y,pit.z),Nodes.AIR)
	game.player.position = Vector3(pit)+Vector3(0.5,0.01,0.5)
	game.day_time = 0.3; game._update_day()
	var daylight_energy: float = game.sunlight.light_energy
	check(game.cave_shelter == 0 and daylight_energy > 0.5,"an excavated open-air pit stays in daylight below the original terrain height")
	game.world.set_node(pit+Vector3i.UP*3,Nodes.STONE)
	for y in range(pit.y,surface+8): game.world.set_node(Vector3i(pit.x+2,y,pit.z),Nodes.AIR)
	for y in 3: game.world.set_node(pit+Vector3i(1,y,0),Nodes.AIR)
	game._update_day()
	check(game.cave_shelter == 0 and is_equal_approx(game.sunlight.light_energy,daylight_energy),"nearby daylight keeps a slightly covered area from turning into night")
	game.player.position = Vector3(8.5,-80,8.5)
	var values: Array = []
	for time in [0.3,0.55,0.8]:
		game.day_time = time; game._update_day()
		values.append([game.sunlight.light_energy,game.environment.environment.ambient_light_energy,game.environment.environment.ambient_light_color,game.environment.environment.fog_light_color])
	check(game.cave_shelter == 1 and values[0] == values[1] and values[1] == values[2],"deep sheltered caves keep constant lighting through dusk and night")
	# --- the void hurts by the source's rate ---------------------------------
	# The source damages four health every half second below the world
	# (`VOID_DAMAGE`/`VOID_DAMAGE_FREQ`), which gives a player who falls in time to
	# climb back out. The check also pins that the branch is reachable at all: it
	# sits below the loaded world, so a guard over unloaded terrain would skip it.
	game.state = "playing"
	game.gamemode = "survival"
	game.player.health = 20.0; game.player.damage_cooldown = 0.0; game.player.void_clock = 0.0
	var void_y: float = float(game.world.generator.min_y())-10.0
	game.player.position = Vector3(8.5,void_y,8.5)
	game.player._physics_process(0.6)
	check(is_equal_approx(game.player.health,20.0-game.player.VOID_DAMAGE),"falling into the void costs the source's four health on its first tick")
	game.player.damage_cooldown = 0.0
	game.player._physics_process(0.6)
	check(is_equal_approx(game.player.health,20.0-2.0*game.player.VOID_DAMAGE),"and again on the next tick, so the void is a rate rather than one killing blow")
	# Climbing out stops it and clears the timer. Health is left to regenerate, so
	# the check is that the *void's* tick did not run rather than an exact value.
	game.player.position = Vector3(8.5,64.0,8.5); game.player.damage_cooldown = 0.0
	var outside_health: float = game.player.health
	game.player._physics_process(0.6)
	check(game.player.health >= outside_health and game.player.void_clock == 0.0,"leaving the void stops the damage and clears its timer")
	game.player.health = 20.0

	load("res://tests/fluid_checks.gd").run(self,game)
	print("ENVIRONMENT TESTS: %d passed, %d failed"%[passed,failed])
	game.queue_free()
	for i in 4: await process_frame
	quit(1 if failed else 0)

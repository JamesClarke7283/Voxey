extends SceneTree
var game: Node3D
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-environment-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func shot(name: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-environment-shots/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-environment-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Waterfalls and daylight","survival")
	while game.state == "loading": await process_frame
	game.pause(); game.hud._clear(); game.player.set_physics_process(false)
	game.player.set_process(false)
	var origin := Vector3i(8,160,8)
	for x in range(-12,13):
		for z in range(-9,10): game.world.set_node(origin+Vector3i(x,-1,z),Nodes.COBBLE)
	for x in [-6,6]:
		for y in 6:
			game.world.set_node(origin+Vector3i(x,y,-3),Nodes.RED_BRICKS)
		game.world.set_node(origin+Vector3i(x,5,-2),Nodes.WATER if x < 0 else Nodes.LAVA)
	load("res://tests/fluid_checks.gd").advance(game.world,320)
	var camera := Camera3D.new(); game.add_child(camera)
	camera.position = Vector3(origin)+Vector3(15,11,18)
	camera.look_at(Vector3(origin)+Vector3(0,1,-1)); camera.current = true
	game.player.position = Vector3(origin)+Vector3(0,2,8)
	game.day_time = 0.3; game._update_day()
	while not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty(): await process_frame
	await shot("waterfalls")
	camera.position = Vector3(origin)+Vector3(-6,3.5,7)
	camera.look_at(Vector3(origin)+Vector3(-6,1,-2)); await shot("water-depth")
	game.player.position = Vector3(origin)+Vector3(0,0.01,8)
	game.player.camera.rotation.x = -0.2; game.player.camera.current = true
	game.state = "playing"; game.player.hunger = 10
	game.inventory.restore([]); game.inventory.add_item(Nodes.APPLE,3); game.inventory.selected = 0
	game.player.set_process(true)
	var use_event := InputEventMouseButton.new(); use_event.button_index = MOUSE_BUTTON_RIGHT; use_event.pressed = true
	Input.parse_input_event(use_event)
	await create_timer(0.8).timeout
	await shot("eating")
	await create_timer(0.9).timeout
	use_event.pressed = false; Input.parse_input_event(use_event)
	print("EATING TOUR: hunger=",game.player.hunger," apples=",game.inventory.count_item(Nodes.APPLE))
	game.player.set_process(false); game.pause(); game.hud._clear()
	# Remove the elevated demonstration platform before checking open sky.
	for x in range(-12,13):
		for z in range(-9,10): game.world.set_node(origin+Vector3i(x,-1,z),Nodes.AIR)
	for x in [-6,6]:
		for y in 6: game.world.set_node(origin+Vector3i(x,y,-3),Nodes.AIR)
	var surface: int = game.world.generator.terrain_height(8,8)
	var pit := Vector3i(8,surface-12,8)
	for x in range(-3,4):
		for z in range(-3,4):
			for y in range(pit.y,surface+7): game.world.set_node(pit+Vector3i(x,y-pit.y,z),Nodes.AIR)
	for x in range(-3,1):
		for z in range(-3,4): game.world.set_node(pit+Vector3i(x,4,z),Nodes.STONE)
	game.player.position = Vector3(pit)+Vector3(0.5,0.01,2.5)
	game.player.camera.rotation.x = -0.15; game.day_time = 0.3; game._update_day()
	while not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty(): await process_frame
	await shot("covered-daylight")
	print("COVERED TOUR: shelter=",game.cave_shelter," sunlight=",game.sunlight.light_energy)
	print("ENVIRONMENT TOUR: ",JSON.stringify(game.performance_snapshot()))
	game.queue_free()
	for frame in 4: await process_frame
	quit()

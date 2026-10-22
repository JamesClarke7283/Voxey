extends SceneTree

var game: Node3D
var passed: int = 0
var failed: int = 0
var origin := Vector3i(8,513,6)
var older: Array[Vector3i] = []

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-torch-lighting-"+str(OS.get_process_id()))
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: passed += 1; print("PASS  "+message)
	else: failed += 1; push_error("FAIL  "+message)

func visible_count() -> int:
	var count: int = 0
	for light in game.torch_lights.values():
		if light.visible: count += 1
	return count

func update_lights() -> void:
	game._process(0.0)

func wait_loaded() -> void:
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	check(game.state != "loading","torch lighting fixture finishes loading")
	game.pause(); game.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	game._clear_entities()

func make_fixture() -> void:
	game.player.position = Vector3(8.5,513,12.5)
	game.world.target = game.player.position
	# One chunk-sized room, with older torches nearby outside its right wall.
	# Their light volumes overlap the chunk but cannot reach the back wall.
	for x in range(2,15):
		for z in range(2,15):
			for y in range(512,517):
				var edge: bool = x in [2,14] or z in [2,14] or y in [512,516]
				game.world.set_node(Vector3i(x,y,z),Nodes.STONE if edge else Nodes.AIR)
	for i in 24:
		var p := Vector3i(18+i%6,513,4+i/6)
		older.append(p)
		game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)
		game.world.set_node(p,Nodes.TORCH)
	game.world.set_node(origin+Vector3i.DOWN,Nodes.STONE)
	game.world.set_node(origin,Nodes.TORCH)

func screenshot(name_value: String) -> Image:
	for i in 8: await process_frame
	RenderingServer.force_draw(false)
	var picture: Image = root.get_texture().get_image()
	picture.save_png("/tmp/voxey-torch-"+name_value+".png")
	return picture

func brightness(picture: Image) -> float:
	var sum: float = 0.0
	var samples: int = 0
	for y in range(int(picture.get_height()*0.40),int(picture.get_height()*0.65),3):
		for x in range(int(picture.get_width()*0.40),int(picture.get_width()*0.60),3):
			var pixel: Color = picture.get_pixel(x,y)
			sum += pixel.r*0.2126+pixel.g*0.7152+pixel.b*0.0722
			samples += 1
	return sum/maxi(1,samples)

func visual_check() -> void:
	game.hud.hide()
	game.sunlight.hide()
	game.environment.environment.ambient_light_energy = 0.02
	game.environment.environment.ambient_light_sky_contribution = 0.0
	game.environment.environment.ambient_light_color = Color.WHITE
	game.environment.environment.fog_enabled = false
	var camera := Camera3D.new(); game.add_child(camera)
	camera.position = Vector3(8.5,514.4,12.5)
	camera.look_at(Vector3(8.5,514.0,3)); camera.make_current()
	var deadline: int = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	for light in game.torch_lights.values(): light.visible = false
	var dark: Image = await screenshot("dark")
	update_lights()
	var lit: Image = await screenshot("lit")
	var dark_level: float = brightness(dark)
	var lit_level: float = brightness(lit)
	print("ROOM BRIGHTNESS: dark=",dark_level," lit=",lit_level)
	check(lit_level > dark_level+0.025,"rendered room stays illuminated with more than 24 nearby torches")
	camera.queue_free(); game.player.camera.make_current(); game.hud.show()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	check(int(ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object",8)) >= game.MAX_TORCH_LIGHTS,"renderer supports the complete nearby torch budget")
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Torch lighting checks","creative")
	await wait_loaded()
	for p in game.torch_lights.keys(): game.remove_torch(p)
	make_fixture()
	update_lights()
	check(game.torch_lights[origin].visible,"a newly placed room torch lights after 24 older nearby torches")
	check(visible_count() == 24,"nearby light selection stays within its rendering budget")
	for i in 30: update_lights()
	check(game.torch_lights[origin].visible,"room torch remains illuminated across later updates")
	if "--visual" in OS.get_cmdline_user_args(): await visual_check()
	game.player.position = Vector3(23.5,513,4.5)
	update_lights()
	check(game.torch_lights[older[5]].visible,"walking to another torch updates the nearest-light selection")
	game.player.position = Vector3(200,513,200)
	update_lights()
	check(visible_count() == 0,"out-of-range torches stop spending the nearby light budget")
	game.player.position = Vector3(8.5,513,12.5)
	update_lights()
	check(game.torch_lights[origin].visible,"returning to a room restores its nearby torch lighting")
	# A connecting guest takes the client-only game update path.
	for light in game.torch_lights.values(): light.visible = false
	check(game.network.join("127.0.0.1",38000+OS.get_process_id()%1000) == OK,"guest lighting check creates a client peer")
	update_lights()
	check(game.torch_lights[origin].visible and visible_count() == 24,"multiplayer guests also update nearby torch lighting")
	game.network.stop()
	check(game.save_game(),"room and torches save successfully")
	var saved: Dictionary = game.read_save()
	game.load_world_data(saved); game.set_process(true)
	await wait_loaded()
	update_lights()
	check(game.torch_lights[origin].visible,"reloading a busy room restores its nearest torch light")
	game.world.set_node(origin,Nodes.AIR)
	update_lights()
	check(not game.torch_lights.has(origin),"breaking a torch removes its light")
	game.world.set_node(origin,Nodes.GLOWSTONE)
	update_lights()
	check(game.torch_lights.has(origin) and game.torch_lights[origin].visible,"placed glowstone uses the same nearby light selection")
	game.world.set_node(origin,Nodes.STONE)
	check(not game.torch_lights.has(origin),"replacing glowstone removes its stale light")
	game.world.set_node(origin,Nodes.SHROOMLIGHT)
	update_lights()
	check(game.torch_lights.has(origin) and game.torch_lights[origin].visible,"placed shroomlights use the same nearby light selection")
	game.queue_free()
	for i in 4: await process_frame
	print("TORCH LIGHTING TESTS: %d passed, %d failed"%[passed,failed])
	quit(1 if failed else 0)

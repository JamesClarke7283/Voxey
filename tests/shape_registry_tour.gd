extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-shape-registry-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func shot(path: String) -> void:
	for i in 10: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Complete shape registry","creative")
	while game.state == "loading": await process_frame
	game.pause(); game.hud._clear(); game.hud.toast_time = 0; game.set_process(false); game.player.set_physics_process(false)
	game.environment.environment.fog_enabled = false
	game.environment.environment.ambient_light_energy = 0.4
	game.environment.environment.ambient_light_sky_contribution = 0.0
	game.environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	game.sunlight.light_energy = 0.55
	var origin := Vector3i(8,58,8)
	for x in range(-10,11):
		for z in range(-8,9):
			game.world.set_node(origin+Vector3i(x,-1,z),Nodes.STONE)
			for y in 6: game.world.set_node(origin+Vector3i(x,y,z),0)
	var families := ["cherry_blossom","pale_oak","mangrove","crimson","warped","lapisblock","redsandstone","redsandstonesmooth","redsandstonesmooth2","stone","concrete_cyan","wool_magenta"]
	for i in families.size():
		var first: int = int(ShapeCatalog.data.by_key[families[i]])
		var p: Vector3i = origin+Vector3i(i%4*5-8,0,i/4*4-4)
		game.world.set_node(p,BuildingShapes.material(first))
		game.world.set_node(p+Vector3i.RIGHT,first)
		game.world.set_node(p+Vector3i.RIGHT*2,first+1)
		game.world.set_node(p+Vector3i.BACK,first+3)
		game.world.set_node(p+Vector3i.BACK+Vector3i.RIGHT,first+4)
	var camera := Camera3D.new(); game.add_child(camera)
	camera.position = Vector3(origin)+Vector3(11,12,16)
	camera.look_at(Vector3(origin)+Vector3(0,0.4,1)); camera.current = true
	game.player.position = Vector3(origin)+Vector3(7,2,7); game.world.target = game.player.position
	game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	await shot("/tmp/voxey-shapes-materials.png")
	var stairs: int = int(ShapeCatalog.data.by_key.concrete_cyan)+3
	game.inventory.restore([]); game.inventory.add_item(BuildingShapes.material(stairs),6)
	game.open_inventory("table"); game.hud.catalog_mode = false; game.hud.recipe_search.text = "concrete"; game.hud._populate_recipes()
	game.hud._select_recipe(game.inventory.recipe_index(stairs)); game.hud._fill_grid()
	await shot("/tmp/voxey-shapes-recipes.png")
	game.queue_free()
	for i in 4: await process_frame
	print("SHAPE TOUR: material families and recipe catalog captured")
	quit()

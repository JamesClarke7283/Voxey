extends SceneTree
var game: Node3D

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-home-tour-"+str(OS.get_process_id()))
	call_deferred("run")

func shot(label: String) -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	game.hud.toast_time = 0; game.hud.queue_redraw()
	for i in 10:
		RenderingServer.force_draw(false)
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/voxey-home-shots/"+label+".png")
	print("HOME SHOT: "+label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-home-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 3
	game.start_new("8675309","Trees and home tour","creative")
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": push_error("Home visual world failed to load"); game.queue_free(); quit(1); return
	game.pause(); game.hud._clear(); game.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false); game._clear_entities()
	game.sunlight.light_energy = 0.45; game.environment.environment.ambient_light_energy = 0.25; game.daylight = 1
	var origin := Vector3i(8,152,8)
	game.player.position = Vector3(origin)+Vector3(0,0,12)
	game.world.target = Vector3(origin); game.world.radius = 4
	deadline = Time.get_ticks_msec()+90000
	while (not game.world.loaded_at(Vector3(-16,152,-40)) or not game.world.loaded_at(Vector3(36,152,-40))) and Time.get_ticks_msec() < deadline: await process_frame
	for x in range(-11,12):
		for z in range(-4,10): game.world.set_node(origin+Vector3i(x,-1,z),Nodes.BRICKS)
	for i in 6:
		var p: Vector3i = origin+Vector3i(i*3-8,0,0)
		var door: int = Doors.ITEMS[0 if i == 0 else i+1]
		for top in [false,true]: game.world.set_node(p+(Vector3i.UP if top else Vector3i.ZERO),Doors.state_id(door,0,i%2 == 1,i%3 == 1,top))
		game.world.set_node(p+Vector3i.BACK*2,WoodTypes.LOGS[i])
		game.world.set_node(p+Vector3i.BACK*2+Vector3i.RIGHT,WoodTypes.oriented(WoodTypes.base(i)+4,Vector3i.RIGHT))
		game.world.set_node(p+Vector3i.BACK*4,BuildingShapes.stair_for(WoodTypes.PLANKS[i]))
		game.world.set_node(p+Vector3i.BACK*4+Vector3i.RIGHT,BuildingShapes.slab_for(WoodTypes.PLANKS[i]))
		var fence: int = Barriers.FENCE_BASES[0 if i == 0 else i+1]
		for z in range(-3,-1): game.world.set_node(p+Vector3i(0,0,z),fence)
		game.world.set_node(p+Vector3i(1,0,-2),Trapdoors.ITEMS[0 if i == 0 else i+1]+(8 if i%2 else 0))
	for i in 7: game.world.set_node(origin+Vector3i(i*2-7,0,7),FoodFeatures.cake_id(7-i))
	for i in 3:
		var p: Vector3i = origin+Vector3i(i*2-8,0,5)
		game.world.set_node(p+Vector3i.DOWN,Nodes.GRASS); game.world.set_node(p,5610+i)
	var sign: Vector3i = origin+Vector3i(8,0,6)
	game.world.set_node(sign,Signs.STANDING)
	Signs.station(game.world,sign)["text"] = "Voxey\nWoodland home\nFresh cake!"
	Signs.station(game.world,sign)["written"] = true
	game.survival.refresh_displays()
	var camera := Camera3D.new(); game.add_child(camera); camera.current = true
	camera.position = Vector3(origin)+Vector3(13,10,15); camera.look_at(Vector3(origin)+Vector3(0,0.6,2))
	await shot("six-wood-building-families")
	camera.position = Vector3(origin)+Vector3(0,4,12); camera.look_at(Vector3(origin)+Vector3(0,0.3,6))
	await shot("cake-slices-and-flowers")
	camera.position = Vector3(sign)+Vector3(0.5,1.2,2.5); camera.look_at(Vector3(sign)+Vector3(0.5,0.75,0.5))
	await shot("standing-sign")
	Signs.open_editor(game,sign,true)
	game.get_meta("sign_editor")["draft"] = "Voxey\nWoodland home\nFresh cake!"
	Signs.reflow(game); await shot("sign-editor")
	Signs.cancel(game); game.pause(); game.hud._clear(); game.set_process(false); game.world.active = false
	for kind in 6:
		var tree: Vector3i = origin+Vector3i((kind%3-1)*18,0,-17-(kind/3)*20)
		for x in range(-4,5):
			for z in range(-4,5): game.world.set_node(tree+Vector3i(x,-1,z),Nodes.GRASS)
		game.world.set_node(tree,WoodTypes.SAPLINGS[kind])
		if kind == 5:
			for offset in [Vector3i.RIGHT,Vector3i.BACK,Vector3i(1,0,1)]: game.world.set_node(tree+offset,WoodTypes.SAPLINGS[kind])
		if not WoodTypes.grow(game.world,tree,100+kind): push_error("Tour tree failed: "+str(kind))
	camera.position = Vector3(origin)+Vector3(35,27,2); camera.look_at(Vector3(origin)+Vector3(0,5,-27)); await shot("six-grown-tree-species")
	var canvas := CanvasLayer.new(); root.add_child(canvas)
	var panel := PanelContainer.new(); canvas.add_child(panel); panel.position = Vector2(60,50)
	var grid := GridContainer.new(); grid.columns = 12; panel.add_child(grid)
	for id in [Nodes.LOG,6032,6064,6096,6128,6160,Nodes.PLANKS,6035,6067,6099,6131,6163,549,6200,6201,6202,6203,6204,779,5610,5611,5612,Signs.OAK,Boats.JUNGLE_CHEST]:
		var icon := ItemIcon.new(); icon.custom_minimum_size = Vector2(72,72); icon.item_id = id; icon.count = 1; grid.add_child(icon)
	await shot("home-inventory-icons")
	game.queue_free(); canvas.queue_free()
	for i in 4: await process_frame
	quit()

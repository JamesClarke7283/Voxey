extends SceneTree

var game: Node3D

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-systems-tour-worlds")
	call_deferred("run")

func shot(name: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-systems-shots/"+name+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-systems-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Storage and farming","creative")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": push_error("Visual world did not finish loading"); game.queue_free(); quit(1); return
	game.pause(); game.hud._clear(); game.set_process(false)
	var origin := Vector3i(8,68,8)
	for x in range(-9,10):
		for z in range(-8,9):
			game.world.set_node(origin+Vector3i(x,-1,z),Nodes.STONE)
	for i in 16: game.world.set_node(origin+Vector3i(i%8*2-7,0,i/8*3-4),PortableStorage.SHULKER_BASE+i)
	var ender: Vector3i = origin+Vector3i(-4,0,4)
	game.world.set_node(ender,PortableStorage.ENDER_CHEST)
	for i in 3:
		var p: Vector3i = origin+Vector3i(i*3-1,0,4)
		game.world.set_node(p,VillageContent.COMPOSTER)
		game.world.get_station(p,"composter").compost = [0,4,8][i]
		var cauldron: Vector3i = origin+Vector3i(i*3-1,0,7)
		game.world.set_node(cauldron,VillageContent.CAULDRON)
		Cauldrons.set_contents(game.world.get_station(cauldron,"cauldron"),[1,3,3][i],"lava" if i == 2 else "water")
	game.player.position = Vector3(origin)+Vector3(6,3,8)
	game.survival.refresh_displays()
	var camera := Camera3D.new(); game.add_child(camera)
	camera.position = Vector3(origin)+Vector3(13,12,17)
	camera.look_at(Vector3(origin)); camera.current = true
	deadline = Time.get_ticks_msec()+20000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	await shot("storage-and-compost")
	game.ender_storage.slots[0] = {"id":PortableStorage.SHULKER_PURPLE,"count":1,"wear":0,"data":{"custom_name":"Expedition supplies","contents":[{"id":Nodes.DIAMOND,"count":12,"wear":0}]}}
	game.ender_storage.slots[1] = {"id":Nodes.WRITTEN_BOOK,"count":1,"wear":0,"data":{"title":"Travel log","text":"Safe in every dimension."}}
	PortableStorage.interact(game,ender)
	await shot("ender-inventory")
	PortableStorage.interact(game,origin+Vector3i(-7,0,-4))
	await shot("shulker-inventory")
	game.queue_free()
	for i in 4: await process_frame
	quit()

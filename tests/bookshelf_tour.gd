extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-bookshelf-visual-"+str(OS.get_process_id()))
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Bookshelf visual check","creative")
	while game.state == "loading": await process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var p := Vector3i(8,44,8)
	var floor := MeshInstance3D.new(); var plane := BoxMesh.new(); plane.size = Vector3(12,0.2,6); floor.mesh = plane
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("655b47"); floor.material_override = mat; floor.position = Vector3(p)+Vector3(0,-0.11,0); game.entities.add_child(floor)
	for i in 4:
		var at: Vector3i = p+Vector3i(i*2-3,0,0)
		game.world.set_node(at,Bookshelves.ID); Bookshelves.state(game.world,at).facing = 2
		for slot in range(i*2): Bookshelves.insert(game.world,at,slot,{"id":Nodes.BOOK,"count":1,"wear":0})
	Bookshelves.state(game.world,p+Vector3i(3,0,0)).slots[0] = load("res://tests/bookshelf_lifecycle_checks.gd").book()
	game.player.position = Vector3(p)+Vector3(0.5,0.2,6); game.player.rotation.y = 0; game.player.camera.rotation.x = -0.1
	game.player.target = {"id":Bookshelves.ID,"pos":p+Vector3i(3,0,0),"normal":Vector3i.BACK,"distance":6.0}
	game.survival.refresh_displays(); game.hud.show_game()
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-bookshelf-display.png")
	game.queue_free(); for i in 4: await process_frame
	quit()

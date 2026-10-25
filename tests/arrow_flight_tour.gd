extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-arrow-visual-"+str(OS.get_process_id()))
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Arrow flight","survival")
	while game.state == "loading": await process_frame
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = Vector3(8,1600,8); game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO
	game.player.hand.hide()
	for i in 3:
		var at := Vector3(6.7+i*1.3,1601.5,4.8)
		var arrow: Arrow = game.spawn_arrow(at,Vector3(0,0,-30)); arrow.set_physics_process(false); arrow.scale = Vector3.ONE*1.8
		if i == 0:
			var block := MeshInstance3D.new(); block.mesh = game.node_mesh(Nodes.STONE); block.material_override = game.node_material
			block.position = at-Vector3(0.5,0.5,0.8); game.add_child(block)
			arrow.embed(at,Vector3i(at),arrow.velocity); arrow.step_stuck(0.012)
		elif i == 1:
			arrow.velocity = Vector3(0,-20,0); arrow._orient()
		else:
			arrow.critical = true; game.puff(at+Vector3(0,0,0.4),Color("bc7a57"),8,0.2)
		var label := Label3D.new(); label.text = ["EMBEDDED","RELEASED","CRITICAL"][i]
		label.font_size = 32; label.pixel_size = 0.003; label.position = at+Vector3(0,-0.65,0); game.add_child(label)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-arrow-flight.png")
	game.queue_free(); for i in 4: await process_frame
	quit()

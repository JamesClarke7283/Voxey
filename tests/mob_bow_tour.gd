extends SceneTree

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-mob-bow-visual-"+str(OS.get_process_id()))
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Skeleton bows","creative")
	while game.state == "loading": await process_frame
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = Vector3(8,1600,9); game.player.hand.hide()
	game.player.camera.look_at(Vector3(8,1601.2,4.8))
	for i in 3:
		var at := Vector3(6.4+i*1.6,1600,4.8)
		var mob: Creature = game.spawn_creature("stray" if i == 2 else "skeleton",at); mob.set_physics_process(false)
		mob.model.rotation.y = PI; mob.bow_target = game.player if i > 0 else null
		mob.bow_ai.using = [-1.0,0.35,1.1][i]; MobBows.pose(mob)
		var label := Label3D.new(); label.text = ["CARRYING","DRAWING","STRAY / FULL DRAW"][i]
		label.font_size = 32; label.pixel_size = 0.003; label.position = at+Vector3(0,-0.25,0)
		game.add_child(label)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-mob-bows.png")
	game.queue_free(); for i in 4: await process_frame
	quit()

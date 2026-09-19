extends SceneTree

var game: Node3D
const SwimmingChecks = preload("res://tests/swimming_checks.gd")

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-swimming-tour-worlds")
	call_deferred("run")

func shot(name: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-swimming-shots/"+name+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-swimming-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Swimming regression","survival")
	while game.state == "loading": await process_frame
	game.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	if not is_instance_valid(game.controls):
		game.controls = TouchControls.new(); game.controls.game = game; game.add_child(game.controls)
	var surface: float = SwimmingChecks.pool(game,1)
	game.player.rotation.y = -PI/2
	game.player.camera.rotation.x = -0.12
	game.player.camera.current = true; game.hud.show_game()
	while not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty(): await process_frame
	game.player.underwater = true
	await shot("underwater")
	game.controls.jump_held = true
	SwimmingChecks.step(game,1.3,1.0/60.0)
	game.player.underwater = Fluids.contains(game.world,game.player.camera.global_position,Nodes.WATER)
	await shot("surface")
	game.controls.stick = Vector2(0,-1)
	SwimmingChecks.step(game,1.5,1.0/60.0)
	game.controls.jump_held = false; game.controls.stick = Vector2.ZERO
	SwimmingChecks.step(game,0.6,1.0/60.0)
	game.player.camera.rotation.x = -0.6
	print("Shore position: ",game.player.position," expected at least y=",surface+1)
	await shot("on-shore")
	game.player.position = Vector3(8.5,surface-0.1,8.5); game.player.velocity = Vector3.ZERO
	game.controls.sneak_held = true
	SwimmingChecks.step(game,1.0,1.0/60.0)
	game.controls.sneak_held = false
	print("Dive position: ",game.player.position)
	await shot("diving")
	game.queue_free()
	for i in 4: await process_frame
	quit()

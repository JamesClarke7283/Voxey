extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-character-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false
	game.network.appearance = CharacterSkin.clean({"name":"Explorer","shirt":"287fa8","hair":"64382b","hat":true})
	game.hud.show_character()
	for i in 10:
		RenderingServer.force_draw(false)
		await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-character-editor.png")
	game.state = "paused"
	game.network.host(24685)
	game.hud.show_pause()
	for button in game.hud.layer.find_children("*","Button",true,false):
		if button.text == "Copy IP": button.pressed.emit()
	assert(DisplayServer.clipboard_get() == game.network.join_address())
	print("COPY IP TEST: complete local IP:port copied")
	for i in 5:
		RenderingServer.force_draw(false)
		await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-escape-menu.png")
	game.hud.show_world_settings()
	for i in 5: RenderingServer.force_draw(false); await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-world-settings.png")
	game.state = "playing"; game.hud.show_game(); game.hud.show_player_list(true)
	for i in 5: RenderingServer.force_draw(false); await process_frame
	root.get_texture().get_image().save_png("/tmp/voxey-player-list.png")
	game.network.stop()
	game.queue_free()
	for i in 4: await process_frame
	quit()

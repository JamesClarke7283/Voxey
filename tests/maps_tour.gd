extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-maps-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func shot(path: String) -> void:
	for i in 10: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Map workshop","creative")
	while game.state == "loading": await process_frame
	game.pause(); game.set_process(false); game.player.set_physics_process(false)
	game.hud.toast_time = 0
	var item: Dictionary = game.maps.create(Vector3(8,16,8))
	game.inventory.restore([]); game.inventory.slots[0] = item
	game.inventory.slots[1] = {"id":VillageContent.EMPTY_MAP,"count":8,"wear":0}
	var deadline: int = Time.get_ticks_msec()+45000
	while str(game.maps.records[item.data.map.id].png).is_empty() and Time.get_ticks_msec() < deadline:
		game.maps.update(); await process_frame
	if str(game.maps.records[item.data.map.id].png).is_empty():
		push_error("Map tour survey timed out"); game.maps.finish_jobs(); quit(1); return
	game.player.position = Vector3(8,16,8)
	game.maps.show_map(item)
	await shot("/tmp/voxey-maps-view.png")
	root.size = Vector2i(800,600); game.maps.show_map(item)
	await shot("/tmp/voxey-maps-compact.png")
	root.size = Vector2i(1280,720)
	game.survival.show_station(Vector3i(8,16,8),VillageContent.CARTOGRAPHY_TABLE)
	await shot("/tmp/voxey-maps-table.png")
	game.queue_free()
	for i in 4: await process_frame
	print("MAP TOUR: source orientation, full/compact image and copy/view table captured")
	quit()

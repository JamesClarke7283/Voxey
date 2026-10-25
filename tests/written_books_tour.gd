extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-written-books-visual-"+str(OS.get_process_id()))
	call_deferred("run")
func shot(path: String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Written books visual check","survival")
	while game.state == "loading": await process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.inventory.restore([]); game.inventory.selected = 0; game.network.appearance.name = "Archivist"
	game.inventory.slots[0] = {"id":Nodes.WRITABLE_BOOK,"count":1,"wear":0,"data":{"text":"FIELD NOTES\n\nThe path follows the river north into the pines.\n\nBring a spare pickaxe, a compass, and a warm coat. The old tower is visible from the ridge.\n\nA small reminder: leave the last torch by the entrance."}}
	game.open_book()
	for child in game.hud.layer.get_children().back().get_children():
		if child is LineEdit: child.text = "The Frostpine Trail"
	await shot("/tmp/voxey-written-book-draft.png")
	for child in game.hud.layer.get_children().back().get_children():
		if child is Button and child.text.begins_with("Sign"): child.pressed.emit(); break
	game.open_book(); await shot("/tmp/voxey-written-book-signed.png")
	var copy: Dictionary = WrittenBooks.copy_data([game.inventory.held()]); game.inventory.slots[0]["data"] = copy
	root.size = Vector2i(800,600); game.open_book(); await shot("/tmp/voxey-written-book-copy.png")
	root.size = Vector2i(1280,720)
	game.resume(); var p := Vector3i(8,1300,8); game.world.set_node(p,Nodes.BOOKSHELF)
	var shelf: Dictionary = game.world.get_station(p,"chest")
	shelf.slots[0] = game.inventory.slots[0].duplicate(true)
	shelf.slots[1] = {"id":Nodes.BOOK,"count":12,"wear":0}
	shelf.slots[2] = {"id":Nodes.WRITABLE_BOOK,"count":1,"wear":0}
	game.open_inventory("chest",p); await shot("/tmp/voxey-plain-bookshelf.png")
	game.queue_free(); for i in 4: await process_frame
	quit()

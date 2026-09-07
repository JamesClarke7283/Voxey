extends SceneTree
var game: Node3D
var failed: bool = false
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-depth-visual-"+str(OS.get_process_id()))
	call_deferred("run")
func frames() -> void:
	for i in 8: await process_frame
func shot(name_text: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-shots/"+name_text+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Deep world visual check","creative")
	while game.state == "loading": await process_frame
	game.inventory.selected = 0
	game.inventory.slots[0] = {"id":Nodes.COBBLED_DEEPSLATE,"count":12,"wear":0}
	game.inventory.slots[1] = {"id":95,"count":1,"wear":0}
	game.inventory.slots[2] = {"id":Nodes.TORCH,"count":32,"wear":0}
	game.open_inventory()
	await frames()
	var point: Vector2 = game.hud.slots_ui[0].get_parent().get_global_rect().get_center()
	Input.warp_mouse(point)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.position = point; click.global_position = point
	Input.parse_input_event(click)
	await frames()
	if game.hud.cursor.id != Nodes.COBBLED_DEEPSLATE: failed = true; push_error("Mouse press failed to begin carrying inventory item")
	Input.warp_mouse(Vector2(16,16))
	await frames()
	await shot("16_drag_outside_inventory")
	var escape := InputEventKey.new(); escape.physical_keycode = KEY_ESCAPE; escape.pressed = true
	Input.parse_input_event(escape)
	await frames()
	if not game.playing() or game.hud.cursor.id != 0 or game.inventory.slots[0].id != 0: failed = true; push_error("Escape did not drop the carried item")
	var found: bool = false
	for drop in game.drops.get_children():
		if drop.item_id == Nodes.COBBLED_DEEPSLATE and drop.amount == 12: found = true
	if not found: failed = true; push_error("Dropped stack not found in world")
	click.pressed = false; click.position = Vector2(16,16); Input.parse_input_event(click)
	# Locate a generated cavern below zero, without carving the terrain.
	game.pause()
	var cave := Vector3.INF
	for y in range(-108,-32,4):
		for z in range(-12,28,2):
			for x in range(-12,28,2):
				var candidate: Vector3 = game.world.cave_spawn(Vector3(x,y,z),1)
				if not is_inf(candidate.x) and not game.world.intersects(candidate+Vector3(0,0,-2)):
					cave = candidate; break
			if not is_inf(cave.x): break
		if not is_inf(cave.x): break
	if is_inf(cave.x): failed = true; push_error("Could not find a generated cavern")
	else:
		game.player.position = cave; game.player.camera.rotation.x = -0.12; game.player.rotation.y = 0
		game.player._make_hand(95); game.inventory.selected = 1
		for offset in [Vector3i(0,0,1),Vector3i(1,0,-2)]:
			var p: Vector3i = Vector3i(cave.floor())+offset
			if game.world.node_at(p) == Nodes.AIR:
				game.world.set_node(p,Nodes.TORCH); game.add_torch(p)
		game.touch = false; game.hud.show_game(); game.hud.toast_time = 0
		game._update_day()
		await shot("17_deepslate_cavern")
	game.queue_free()
	await frames()
	print("DEPTH VISUAL CHECK: ","FAILED" if failed else "PASSED")
	quit(1 if failed else 0)

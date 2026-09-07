extends SceneTree
var game: Node3D
var camera: Camera3D
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-village-tour-worlds")
	call_deferred("run")
func shot(filename: String) -> void:
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-shots/"+filename+".png")
func frame(at: Vector3, focus: Vector3) -> void:
	camera.position = at; camera.look_at(focus); camera.make_current()
	game.touch = false; game.state = "paused"; game.hud.show_game(); game.hud.toast_time = 0; game.player.hand.visible = false
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.touch = true; game.audio_enabled = false; game.world.radius = 3
	game.start_new("8675309","Village tour","creative")
	while game.state == "loading": await process_frame
	game.pause()
	var village: Dictionary = VillageGenerator.nearest(game.world.generator,game.player.position)
	var c: Vector3 = Vector3(village.center)
	game.teleport(c+Vector3(4.5,1.1,4.5))
	while game.state == "loading": await process_frame
	game.pause()
	while game.world.columns.size() < 49: await process_frame
	game.villages.update(0.6)
	camera = Camera3D.new(); camera.far = 300; camera.fov = 65; game.add_child(camera)
	frame(c+Vector3(47,35,-52),c+Vector3(0,0,8)); await shot("30_village")
	var farmer := VillageMob.new(); farmer.game = game; farmer.kind = "villager"; farmer.position = c+Vector3(6.5,1,3.5)
	game.creatures.add_child(farmer)
	var person: Dictionary = game.villages.make_record("tour_farmer","farmer",farmer.position,Vector3i(c),Vector3i(c),Vector3i(c)); farmer.bind(person)
	farmer.model.rotation.y = -0.2
	game.player.position = c+Vector3(4,1,2)
	game.leads.attach(farmer,false); game.leads.update(0.016)
	frame(c+Vector3(7.8,3.2,0),farmer.position+Vector3.UP); await shot("31_villager_lead")
	game.inventory.add_item(VillageContent.EMERALD,48); game.inventory.add_item(Nodes.GRAIN,64); game.inventory.add_item(VillageContent.CARROT,48)
	game.state = "trading"; game.villages.trading_key = person.key; game.hud.show_trading(person.key); await shot("32_trading")
	game.queue_free()
	for i in 4: await process_frame
	quit()

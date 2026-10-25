extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-smithing-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func shot(path: String) -> void:
	for i in 10: await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","SmithingRepair workshop","survival")
	while game.state == "loading": await process_frame
	game.pause(); game.hud._clear(); game.hud.toast_time = 0; game.set_process(false); game.player.set_physics_process(false)
	game.environment.environment.fog_enabled = false; game.environment.environment.ambient_light_energy = 0.4
	game.environment.environment.ambient_light_sky_contribution = 0.0; game.environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR; game.sunlight.light_energy = 0.55
	var p := Vector3i(8,58,8)
	for x in range(-6,7):
		for z in range(-6,7):
			game.world.set_node(p+Vector3i(x,-1,z),Nodes.STONE)
			for y in 4: game.world.set_node(p+Vector3i(x,y,z),0)
	for i in 3: game.world.set_node(p+Vector3i(i*2,0,0),VillageContent.SMITHING_TABLE)
	var camera := Camera3D.new(); game.add_child(camera); camera.position = Vector3(p)+Vector3(5,4,7)
	camera.look_at(Vector3(p)+Vector3(1.5,0.4,1.5)); camera.current = true
	game.player.position = Vector3(p)+Vector3(5,2,5); game.world.target = game.player.position; game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	await shot("/tmp/voxey-smithing-workshop.png")
	var state: Dictionary = game.world.get_station(p,"smithing")
	state.slots[0] = {"id":95,"count":1,"wear":600,"data":{"custom_name":"Trusted pick","enchantments":{"Efficiency":3},"pwp":4}}
	state.slots[1] = {"id":Netherite.INGOT,"count":2,"wear":0}
	state.slots[2] = {"id":Netherite.TEMPLATE,"count":2,"wear":0}
	game.open_inventory("smithing",p)
	await shot("/tmp/voxey-smithing-upgrade.png")
	state.slots[0] = {"id":Nodes.ARMOR,"count":1,"wear":100}
	state.slots[1] = {"id":Nodes.COPPER,"count":3,"wear":0}
	state.slots[2] = {"id":ArmorTrims.FIRST+4,"count":2,"wear":0}
	Smithing.refresh(state); game.hud.refresh_slots()
	await shot("/tmp/voxey-smithing-trim.png")
	root.size = Vector2i(800,600); game.hud.show_inventory("smithing",state)
	await shot("/tmp/voxey-smithing-compact.png")
	state.slots[0] = state.slots[3].duplicate(true); Smithing.refresh(state); game.hud.refresh_slots()
	await shot("/tmp/voxey-smithing-unavailable.png")
	game.queue_free()
	for i in 4: await process_frame
	print("SMITHING TOUR: geometry, upgrade, trim, compact and unavailable views captured")
	quit()

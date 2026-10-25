extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-fields-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Farmer fields","creative")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": quit(1); return
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	for mob in game.creatures.get_children(): mob.free()
	game.villages.state().people = {}; game.day_time = 0.35
	game.player.position = Vector3(18,2105,3); game.player.hand.hide(); game.player.camera.look_at(Vector3(11.5,2100,10.5))
	for x in range(5,20):
		for z in range(5,17): game.world.set_node(Vector3i(x,2099,z),Nodes.GRASS)
	for x in range(8,16):
		for z in range(8,13):
			game.world.set_node(Vector3i(x,2099,z),Farmland.WET)
			game.world.set_node(Vector3i(x,2100,z),[Nodes.RIPE_WHEAT,554,558,562][(x-8)%4])
	var job := Vector3i(7,2100,9); game.world.set_node(job,VillageContent.COMPOSTER)
	var farmer: VillageMob = game.spawn_creature("villager",Vector3(8.5,2100,8.5)); farmer.set_physics_process(false)
	var person: Dictionary = game.villages.record(farmer.person_key); person.profession = "farmer"; person.job = [7,2100,9]; farmer.bind(person)
	VillagerInventory.add(VillagerInventory.slots(person),{"id":Nodes.SEEDS,"count":20,"wear":0})
	farmer.farmer_fields = FarmerFields.initial(); farmer.farmer_fields.order = ["farm"]
	for i in 120:
		for drop in game.drops.get_children():
			if not drop.is_queued_for_deletion(): drop.age += 0.05
		farmer._physics_process(0.05)
	game.world.target = game.player.position; game.world.set_process(true); game.hud.hide()
	deadline = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	for i in 12: await process_frame
	RenderingServer.force_draw(false); root.get_texture().get_image().save_png("/tmp/voxey-farmer-fields.png")
	print("FARMER FIELD TOUR: ",farmer.position," ",farmer.farmer_fields.get("mode","")); game.queue_free()
	for i in 4: await process_frame
	quit()

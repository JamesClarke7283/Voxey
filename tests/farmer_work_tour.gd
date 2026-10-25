extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-farmer-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Composter workstations","creative")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": quit(1); return
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	for mob in game.creatures.get_children(): mob.free()
	game.villages.state().people = {}; game.day_time = 0.35
	game.player.position = Vector3(17,2105,4); game.player.hand.hide(); game.player.camera.look_at(Vector3(11,2100.4,10))
	for x in range(4,20):
		for z in range(6,15): game.world.set_node(Vector3i(x,2099,z),Nodes.GRASS)
	var n: int = 0
	for level in [0,3,7,8]:
		var p := Vector3i(7+n*3,2100,10); game.world.set_node(p,VillageContent.COMPOSTER)
		var station: Dictionary = game.world.get_station(p,"composter"); station.compost = level; station.compost_version = 2
		if level == 7: station.maturation = 1.0
		n += 1
	var farmer: VillageMob = game.spawn_creature("villager",Vector3(11.5,2100,12.2)); farmer.set_physics_process(false)
	var person: Dictionary = game.villages.record(farmer.person_key); person.profession = "farmer"; person.job = [10,2100,10]; farmer.bind(person); farmer.model.rotation.y = 0
	VillagerInventory.add(VillagerInventory.slots(person),{"id":Nodes.SEEDS,"count":30,"wear":0})
	FarmerWork.use(farmer,Vector3i(10,2100,10)); game.survival.refresh_displays()
	game.world.target = game.player.position; game.world.set_process(true); game.hud.hide()
	deadline = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	for i in 12: await process_frame
	RenderingServer.force_draw(false); root.get_texture().get_image().save_png("/tmp/voxey-farmer-work.png")
	print("FARMER TOUR: saved composter and workstation preview"); game.queue_free()
	for i in 4: await process_frame
	quit()

extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-social-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Villager families","creative")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": quit(1); return
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	for mob in game.creatures.get_children(): mob.free()
	game.villages.state().people = {}; game.day_time = 0.67
	game.player.position = Vector3(16,2103,4); game.player.hand.hide(); game.player.camera.look_at(Vector3(10.5,2100.8,10))
	for x in range(5,17):
		for z in range(6,15): game.world.set_node(Vector3i(x,2099,z),Nodes.GRASS)
	for x in [8,10,12]:
		game.world.set_node(Vector3i(x,2100,12),VillageContent.BED_RED); game.world.set_node(Vector3i(x,2100,13),VillageContent.BED_HEAD_RED)
	var a: VillageMob = game.spawn_creature("villager",Vector3(9,2100,9.5)); a.set_physics_process(false)
	var b: VillageMob = game.spawn_creature("villager",Vector3(11,2100,9.5)); b.set_physics_process(false)
	var pa: Dictionary = game.villages.record(a.person_key); var pb: Dictionary = game.villages.record(b.person_key)
	pa.bed = [8,2100,12]; pb.bed = [10,2100,12]
	VillagerInventory.add(VillagerInventory.slots(pa),{"id":Nodes.BREAD,"count":4,"wear":0}); VillagerInventory.add(VillagerInventory.slots(pb),{"id":Nodes.BREAD,"count":4,"wear":0})
	VillagerSocial.pair(a,b,"breed",0.1); VillagerSocial.step(a,0.2,true)
	for mob in game.creatures.get_children():
		mob.set_physics_process(false)
		if mob != a and mob != b: mob.position = Vector3(10,2100,8.9)
	game.world.target = game.player.position; game.world.set_process(true); game.hud.hide()
	deadline = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	for i in 12: await process_frame
	RenderingServer.force_draw(false); root.get_texture().get_image().save_png("/tmp/voxey-villager-social.png")
	print("VILLAGER SOCIAL TOUR: saved family preview"); game.queue_free()
	for i in 4: await process_frame
	quit()

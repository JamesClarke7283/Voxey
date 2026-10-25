extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-zombie-target-tour-"+str(OS.get_process_id()))
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Village navigation","creative")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": quit(1); return
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = Vector3(19,2105,22); game.player.hand.hide(); game.player.camera.look_at(Vector3(12,2101,12)); game.daylight = 0.1
	game.villages.state().people = {}
	for mob in game.creatures.get_children(): mob.free()
	for x in range(4,22):
		for z in range(5,19): game.world.set_node(Vector3i(x,2099,z),Nodes.GRASS)
	for z in range(6,14):
		for y in range(2100,2102): game.world.set_node(Vector3i(12,y,z),Nodes.COBBLE)
	var job := Vector3i(17,2100,11); var bed := Vector3i(18,2100,13)
	game.world.set_node(job,VillageContent.COMPOSTER); game.world.set_node(bed,VillageContent.BED_RED)
	game.villages.make_record("tour","farmer",Vector3(job),job,bed,job)
	var mob: Creature = game.spawn_creature("zombie",Vector3(9.5,2100,11.5),"",{"baby":false,"jockey":false}); mob.set_physics_process(false)
	mob.zombie_traits.view = 0; mob.mob_armor = MobArmor.empty_slots(); MobArmor.refresh(mob); MobWeapons.set_item(mob,MobWeapons.empty_item(),0); mob.think = 100
	ZombieVillage.step(mob,1,false)
	for i in 45: mob._physics_process(0.05)
	game.world.target = game.player.position; game.world.set_process(true); game.hud.toast_time = 0; game.hud.hide()
	deadline = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	for i in 12: await process_frame
	RenderingServer.force_draw(false); root.get_texture().get_image().save_png("/tmp/voxey-zombie-target.png")
	print("ZOMBIE TARGET TOUR: ",mob.position," route ",mob.zombie_village.get("route",[])); game.queue_free()
	for i in 4: await process_frame
	quit()

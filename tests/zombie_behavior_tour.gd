extends SceneTree
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-zombie-door-visual-"+str(OS.get_process_id()))
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Zombie door behavior","creative")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	if game.state == "loading": quit(1); return
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = Vector3(12,2101,3); game.player.hand.hide(); game.player.camera.look_at(Vector3(8.5,2101,7.6)); game.difficulty = 2
	for x in range(4,12):
		for z in range(5,11): game.world.set_node(Vector3i(x,2099,z),Nodes.STONE)
	for x in range(4,12):
		for y in range(2100,2103): game.world.set_node(Vector3i(x,y,8),Nodes.PLANKS if x != 8 or y == 2102 else Doors.state_id(549,0,false,false,y == 2101))
	var mob: Creature = game.spawn_creature("zombie",Vector3(8.5,2100,7.5)); mob.set_physics_process(false)
	mob.mob_armor = MobArmor.empty_slots(); MobArmor.refresh(mob); MobWeapons.set_item(mob,MobWeapons.empty_item(),0)
	mob.zombie_traits.break_doors = true; mob.direction = Vector3.BACK; mob.model.rotation.y = PI
	ZombieDoors.step(mob,0.1,true); mob.zombie_door.time = 6.1; mob.zombie_door.punch = 0.25; mob.animate(0.05,true)
	game.world.target = game.player.position; game.world.set_process(true)
	game.hud.toast_time = 0
	deadline = Time.get_ticks_msec()+30000
	while (not game.world.dirty.is_empty() or not game.world.remesh_jobs.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	for i in 12: await process_frame
	RenderingServer.force_draw(false); root.get_texture().get_image().save_png("/tmp/voxey-zombie-door.png")
	print("ZOMBIE DOOR TOUR: saved preview"); game.queue_free()
	for i in 4: await process_frame
	quit()

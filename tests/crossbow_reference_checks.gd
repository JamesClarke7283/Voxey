extends SceneTree
var failures: int = 0
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-crossbow-reference-"+str(OS.get_process_id()))
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 10: push_error(message)
func equip(game: Node3D, row: Dictionary) -> void:
	CrossbowUse.cancel(game.player); game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":VillageContent.CROSSBOW,"count":1,"wear":0,"data":{"enchantments":{"Quick Charge":int(row.get("quick",0)),"Unbreaking":int(row.get("unbreaking",0)),"Multishot":int(row.get("multishot",0)),"Piercing":int(row.get("piercing",0))}}}
	Durability.set_normalized(game.inventory.slots[0],int(row.get("before",0)))
	if row.ammo != "none": game.inventory.slots[1] = {"id":Nodes.ARROW_ITEM if row.ammo == "regular" else VillageContent.POISON_ARROW,"count":3,"wear":0}
	game.gamemode = "creative" if row.creative else "survival"
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/crossbow_reference.json"))
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Crossbow reference","survival")
	while game.state == "loading": await process_frame
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = Vector3(5,5.38,9); game.player.health = 20; game.state = "playing"
	for row in source.loads:
		equip(game,row)
		CrossbowUse.begin(game.player,1000000)
		var half: int = CrossbowUse.half_time(game.inventory.held())
		if int(row.elapsed) >= half: CrossbowUse.update(game.player,true,false,false,1000000+half)
		CrossbowUse.update(game.player,true,false,false,1000000+int(row.elapsed))
		var group: int = CrossbowUse.current_stage(game.player)+2 if not game.player.crossbow_draw.is_empty() else 1
		check(group == int(row.stage),"Draw stage differs "+str(row)+" group="+str(group))
		CrossbowUse.release(game.player)
		check(CrossbowUse.loaded(game.inventory.held()) == bool(row.loaded) and int(game.inventory.slots[1].count) == int(row.count) and Durability.normalized(game.inventory.held()) == int(row.wear),"Load result differs "+str(row))
	for row in source.shots:
		equip(game,row); game.player.rotation.y = row.yaw; game.player.camera.rotation.x = row.pitch
		CrossbowUse.begin(game.player,1000000)
		CrossbowUse.update(game.player,true,false,false,1400000); CrossbowUse.update(game.player,true,false,false,2000000)
		CrossbowUse.release(game.player)
		check(CrossbowUse.loaded(game.inventory.held()) == bool(row.loaded),"Source load eligibility differs "+str(row))
		var shots: Array = CrossbowUse.fire(game.player,source.samples)
		var expected_shots: Array = row.shots if row.shots is Array else []
		check(shots.size() == expected_shots.size(),"Source projectile count differs "+str(row))
		for i in mini(shots.size(),expected_shots.size()):
			var shot: Arrow = shots[i]; var expected: Dictionary = expected_shots[i]
			check(shot.velocity.is_equal_approx(Vector3(expected.velocity[0],expected.velocity[1],expected.velocity[2])),"Crossbow direction differs "+str(row)+" shot="+str(i)+" got="+str(shot.velocity))
			check(shot.position.is_equal_approx(Vector3(expected.position[0],expected.position[1],expected.position[2])) and shot.damage == expected.damage and shot.critical == expected.critical and shot.piercing == expected.piercing and shot.recoverable == expected.collectable,"Projectile properties differ "+str(row))
			shot.free()
		check(Durability.normalized(game.inventory.held()) == int(row.wear) and game.inventory.held().count == int(row.bow_count) and game.inventory.slots[1].count == int(row.count),"Crossbow wear/ammo differs "+str(row))
	print("CROSSBOW SOURCE: %d loads and %d firing cases, %d failures"%[source.loads.size(),source.shots.size(),failures])
	game.queue_free(); for i in 4: await process_frame
	quit(1 if failures else 0)

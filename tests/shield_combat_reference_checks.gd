extends SceneTree
var failures: int = 0
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-shield-combat-reference-"+str(OS.get_process_id()))
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		if failures < 8: push_error(description)
func vec(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/shield_combat_reference.json"))
	check(is_equal_approx(Shields.BLOCK_COSINE,source.cosine),"Shield threshold differs from the running source")
	for row in source.angles:
		check((bool(row.active) and Shields.accepts_dot(row.dot,row.kind)) == bool(row.blocked),"Angle decision differs: "+str(row))
	for row in source.wear:
		var item: Dictionary = {"id":VillageContent.SHIELD,"count":1,"wear":0,"data":{"shield_color":6,"enchantments":{"Unbreaking":int(row.unbreaking)}}}
		Durability.set_normalized(item,int(row.before))
		var applied: bool = Shields.wear_item(item,row.damage,row.creative)
		check(applied == bool(row.applied) and item.count == int(row.count) and Durability.normalized(item) == int(row.wear),"Shield wear differs: "+str(row)+" actual="+str(item))
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Shield combat source checks","survival")
	while game.state == "loading": await process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = Vector3(8,1600,8); game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO
	for i in 4: game.player.armor_slots[i] = Bookshelves.empty()
	game.player.offhand_slot = Bookshelves.empty()
	for row in source.arrows:
		game.inventory.restore([]); game.inventory.selected = 0
		game.inventory.slots[0] = {"id":VillageContent.SHIELD,"count":1,"wear":0,"data":{"shield_color":6,"enchantments":{"Unbreaking":1}}}
		game.survival.shield_raised = true; game.survival.shield_disabled = 0
		game.player.health = 20; game.player.damage_cooldown = 0; game.player.velocity = Vector3.ZERO
		var shot: Arrow = game.spawn_arrow(game.player.position+Vector3(1,1.2,0.3),vec(row.velocity)); shot.set_physics_process(false)
		shot.piercing = int(row.piercing)
		var previous: Vector3 = game.player.position+Vector3(sqrt(1.0-row.dot*row.dot)*4,1.08,row.dot*4)
		var outcome: String = shot.hit_player(previous,game.player.position+Vector3(0,1.2,0))
		check((outcome == "deflected") == bool(row.blocked) and shot.velocity.is_equal_approx(vec(row.after)),"Arrow reflection differs: "+str(row))
		check(shot.hit_mobs.has(game.player.get_instance_id()) == bool(row.effects) and is_equal_approx(20-game.player.health,row.damage),"Arrow damage/effect branch differs: "+str(row)+" health="+str(game.player.health))
		check(Durability.normalized(game.inventory.held()) == int(row.wear),"Reflected/piercing arrow shield wear differs: "+str(row))
		if row.blocked: check(shot.position.is_equal_approx(game.player.position+vec(row.position)),"Arrow did not stop at its intersection")
		shot.free()
	for row in source.tridents:
		game.player.health = 20; game.player.damage_cooldown = 0
		var shot: Arrow = game.spawn_arrow(game.player.position+Vector3(0,1,0),vec(row.velocity)); shot.set_physics_process(false); shot.item_id = VillageContent.TRIDENT
		var outcome: String = shot.hit_player(game.player.position+Vector3(0,1,-4),game.player.position+vec(row.position))
		check(outcome == "bounced" and shot.velocity.is_equal_approx(vec(row.after)) and shot.position.is_equal_approx(game.player.position+vec(row.position)),"Trident reflection differs from source")
		shot.free()
	print("SHIELD COMBAT SOURCE: %d angles, %d wear cases, %d arrows, %d tridents; %d failures" % [source.angles.size(),source.wear.size(),source.arrows.size(),source.tridents.size(),failures])
	game.queue_free(); for i in 4: await process_frame
	quit(1 if failures else 0)

extends RefCounted

static func held(game: Node3D, id: int, count: int = 1, data: Dictionary = {}) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0,"data":data}
	game.player.eating.clear(); game.player.use_cooldown = 0; game.player.use_latched = false

static func mouse(game: Node3D, down: bool) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = down
	event.position = game.get_viewport().get_visible_rect().size*0.5; event.global_position = event.position
	Input.parse_input_event(event); Input.flush_buffered_events(); game.player._process(0.016)

static func click(game: Node3D, p: Vector3i) -> void:
	game.player.camera.look_at(Vector3(p)+Vector3.ONE*0.5); game.player.use_cooldown = 0; game.player.use_latched = false
	mouse(game,true); mouse(game,false)

static func drops(game: Node3D, id: int = -1) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and (drop.item_id == id or id < 0 and Jukeboxes.is_disc(drop.item_id)): count += drop.amount
	return count

static func arrow(game: Node3D, kind: String, at: Vector3, toward: Vector3, player: bool = false) -> Arrow:
	var shot: Arrow = game.spawn_arrow(at,toward*15)
	shot.from_player = player; shot.shooter_kind = kind; shot.set_physics_process(false)
	return shot

static func fly(shot: Arrow) -> void:
	for i in 100:
		if shot.stuck or shot.is_queued_for_deletion(): return
		shot._physics_process(0.01)

static func mob(game: Node3D, kind: String, at: Vector3) -> Creature:
	var result: Creature = game.spawn_creature(kind,at)
	result.set_physics_process(false); result.grounded = true; result.velocity = Vector3.ZERO
	return result

static func run(suite: SceneTree, game: Node3D) -> void:
	game._clear_entities(); await suite.process_frame
	game.state = "playing"; game.gamemode = "survival"; game.audio_enabled = false
	game.player.set_process(false); game.player.set_physics_process(false); game.world.active = false; game.world.set_process(false)
	for x in range(2,15):
		for z in range(2,15):
			for y in range(599,605): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 599 else Nodes.AIR)
	var p := Vector3i(8,600,8)
	game.player.position = Vector3(8.5,600.01,12.5); game.player.rotation = Vector3.ZERO; game.player.camera.position.y = 1.62
	suite.check(Jukeboxes.RECORDS.size() == 8 and Jukeboxes.MALL == Bastions.MALL_DISC,"all eight registered source records include the existing saved Mall disc")
	suite.check(Nodes.exists(Jukeboxes.ID) and Nodes.hardness(Jukeboxes.ID) == 2 and Nodes.fuel_time(Jukeboxes.ID) == 15,"jukebox has source hardness two and fifteen-second furnace fuel")
	var recipe: int = game.inventory.recipe_index(Jukeboxes.ID)
	held(game,Nodes.DIAMOND); game.inventory.add_item(Nodes.PLANKS,3); game.inventory.add_item(WoodTypes.PLANKS[1],5)
	suite.check(recipe >= 0 and game.inventory.craft(recipe,"table") and game.inventory.count_item(Jukeboxes.ID) == 1 and game.inventory.count_item(Nodes.DIAMOND) == 0,"recipe-book crafting accepts eight mixed planks around one diamond")
	for i in 9: game.inventory.grid[i] = {"id":Nodes.DIAMOND if i == 4 else WoodTypes.PLANKS[i%WoodTypes.PLANKS.size()],"count":1,"wear":0}
	var output: Dictionary = game.inventory.take_grid_result("table")
	suite.check(output.get("id",0) == Jukeboxes.ID and game.inventory.grid.all(func(slot): return slot.id == 0),"manual crafting matches mixed source wood groups and consumes all nine cells")
	held(game,Jukeboxes.ID)
	game.player.camera.look_at(Vector3(p)+Vector3(0.5,-0.01,0.5)); mouse(game,true); mouse(game,false)
	suite.check(game.world.node_at(p) == Jukeboxes.ID and game.inventory.count_item(Jukeboxes.ID) == 0,"actual use places a jukebox and consumes the survival block")
	var comparator: Vector3i = p+Vector3i.RIGHT
	game.world.set_node(comparator,Nodes.COMPARATOR); game.world.circuits.configure(comparator,Vector3i.RIGHT)
	for id in Jukeboxes.RECORDS:
		var sound: AudioStream = Jukeboxes.stream(id)
		suite.check(Nodes.max_stack(id) == 1 and sound is AudioStreamOggVorbis and sound.get_length() > 30 and not sound.loop,"record "+Nodes.title(id)+" has a real, nonlooping licensed Ogg track and stacks singly")
		held(game,id,1,{"custom_name":"Saved tune"}); click(game,p)
		var data: Dictionary = Jukeboxes.station(game.world,p)
		var audio: AudioStreamPlayer3D = Jukeboxes.players(game.world).get(p)
		suite.check(data.slots[0].id == id and data.slots[0].get("data",{}).get("custom_name","") == "Saved tune" and game.inventory.count_item(id) == 0 and is_instance_valid(audio) and audio.playing and audio.max_distance == 65,"live use inserts exactly one "+Nodes.title(id)+", retains its name and starts spatial playback")
		game.world.circuits.step(); game.world.circuits.step()
		suite.check(game.world.circuits.state(comparator).get("out",0) == Jukeboxes.RECORDS[id].signal,"live comparator reports source record strength "+str(Jukeboxes.RECORDS[id].signal))
		var before: int = drops(game,id); click(game,p)
		suite.check(Jukeboxes.station(game.world,p).slots[0].id == 0 and not Jukeboxes.players(game.world).has(p) and not audio.playing and drops(game,id) == before+1,"ejection stops "+Nodes.title(id)+" and returns its single stored disc once")
	game.world.set_node(comparator,Nodes.AIR)
	held(game,Jukeboxes.CHIRP); game.player.camera.look_at(Vector3(p)+Vector3.ONE*0.5); mouse(game,true)
	for i in 8: game.player.use_cooldown = 0; game.player._process(0.1)
	suite.check(Jukeboxes.station(game.world,p).slots[0].id == Jukeboxes.CHIRP,"holding right-click does not immediately eject an inserted record")
	mouse(game,false)
	var before: int = drops(game); held(game,Jukeboxes.STRAD); click(game,p)
	suite.check(drops(game) == before+1 and game.inventory.count_item(Jukeboxes.STRAD) == 1 and Jukeboxes.station(game.world,p).slots[0].id == 0,"using an occupied jukebox only ejects; it does not swap or consume the held record")
	game.gamemode = "creative"; click(game,p)
	suite.check(game.inventory.count_item(Jukeboxes.STRAD) == 0 and Jukeboxes.station(game.world,p).slots[0].id == Jukeboxes.STRAD,"source creative insertion consumes the disc too, preventing free ejection duplication")
	var audio: AudioStreamPlayer3D = Jukeboxes.players(game.world)[p]
	game.audio_enabled = true; Jukeboxes.update(game.world,0.01)
	suite.check(audio.volume_db == 0,"enabling game audio unmutes active music")
	game.audio_enabled = false; game.state = "paused"; game._process(0)
	suite.check(audio.volume_db <= -80,"audio settings mute existing music while gameplay is paused")
	game.state = "playing"; game.gamemode = "survival"
	# No hopper automation: source container group seven blocks both directions.
	# Remove earlier ejected loose items, which hoppers are allowed to collect.
	for drop in game.drops.get_children(): drop.queue_free()
	await suite.process_frame
	var top: Vector3i = p+Vector3i.UP; var below: Vector3i = p+Vector3i.DOWN
	game.world.set_node(top,Nodes.HOPPER); game.world.circuits.configure(top,Vector3i.DOWN)
	game.world.circuits.container(top)[0] = {"id":Jukeboxes.FAR,"count":1,"wear":0}
	game.world.set_node(below,Nodes.HOPPER); game.world.circuits.configure(below,Vector3i.DOWN)
	game.world.circuits.hopper(top); game.world.circuits.hopper(below)
	suite.check(game.world.circuits.container(top)[0].id == Jukeboxes.FAR and game.world.circuits.container(below).all(func(slot): return slot.id == 0) and Jukeboxes.station(game.world,p).slots[0].id == Jukeboxes.STRAD,"actual hopper transfer cannot insert or extract a jukebox disc")
	game.world.set_node(top,Nodes.AIR); game.world.detach_station(top); game.world.set_node(below,Nodes.STONE); game.world.detach_station(below)
	# Loaded boxes continue their recording outside hearing range; unload stops it.
	audio.stop(); Jukeboxes.update(game.world,0.1)
	suite.check(not Jukeboxes.players(game.world).has(p) and Jukeboxes.signal_strength(game.world,p) == 9,"finished playback cleans the audio node while retaining the disc and comparator output")
	held(game,0,0); click(game,p); held(game,Jukeboxes.BLOCKS); click(game,p)
	var distant_voice: AudioStreamPlayer3D = Jukeboxes.players(game.world)[p]
	game.player.position.x += 66; Jukeboxes.update(game.world,0.1)
	suite.check(Jukeboxes.players(game.world).get(p) == distant_voice and distant_voice.max_distance == 65 and Jukeboxes.station(game.world,p).slots[0].id == Jukeboxes.BLOCKS,"leaving hearing distance keeps the loaded recording while spatial audio limits audibility")
	game.player.position.x -= 66; Jukeboxes.update(game.world,0.1)
	suite.check(Jukeboxes.players(game.world).get(p) == distant_voice and distant_voice.playing,"returning within range preserves the same playing voice without restarting the record")
	click(game,p); held(game,Jukeboxes.WAIT); click(game,p); Jukeboxes.unload(game.world,Vector2i(0,0))
	suite.check(not Jukeboxes.players(game.world).has(p) and Jukeboxes.station(game.world,p).slots[0].id == Jukeboxes.WAIT,"column unload stops music and keeps the stored source record")
	click(game,p); held(game,Jukeboxes.DISC_13); click(game,p)
	before = drops(game,Jukeboxes.DISC_13); game.break_node(p,Jukeboxes.ID,0)
	suite.check(drops(game,Jukeboxes.DISC_13) == before+1 and not Jukeboxes.players(game.world).has(p) and game.world.detach_station(p).is_empty(),"real block breaking ejects one disc with no generic station double-drop")
	game.world.set_node(p,Jukeboxes.ID); held(game,Jukeboxes.MALL); click(game,p); before = drops(game,Jukeboxes.MALL)
	game.gamemode = "creative"; game.break_node(p,Jukeboxes.ID,0)
	suite.check(drops(game,Jukeboxes.MALL) == before+1,"creative jukebox breaking returns the inserted disc once")
	game.gamemode = "survival"; game.world.set_node(p,Jukeboxes.ID)
	var piston: Vector3i = p+Vector3i.LEFT
	game.world.set_node(piston,Nodes.PISTON); game.world.circuits.configure(piston,Vector3i.RIGHT)
	suite.check(not game.world.circuits.piston(piston,true) and game.world.node_at(p) == Jukeboxes.ID,"a source jukebox blocks piston movement")
	game.world.set_node(piston,Nodes.AIR)
	# Real skeleton launch carries provenance, then arrows sweep actors and walls.
	var skeleton: Creature = mob(game,"skeleton",Vector3(4.5,600.01,5.5))
	game.player.position = Vector3(4.5,600.01,13.5)
	skeleton.model.look_at(game.player.position); skeleton.attack_cooldown = 0
	skeleton._physics_process(0.016)
	var fired: Array = game.entities.get_children().filter(func(entity): return entity is Arrow and entity.shooter_id == skeleton.get_instance_id())
	suite.check(fired.size() == 1 and fired[0].shooter_kind == "skeleton","actual skeleton AI assigns its own identity to a fired arrow")
	for shot in fired: shot.queue_free()
	skeleton.queue_free(); await suite.process_frame
	for shooter in ["skeleton","stray","player",""]:
		var creeper: Creature = mob(game,"creeper",Vector3(6.5,600.01,8.5)); creeper.health = 1
		before = drops(game)
		var shot: Arrow = arrow(game,shooter if shooter != "player" else "",Vector3(6.5,601.0,12.5),Vector3.FORWARD,shooter in ["player",""])
		fly(shot)
		suite.check(creeper.health <= 0 and drops(game) == before+(1 if shooter in ["skeleton","stray"] else 0),"real "+("dispenser" if shooter == "" else shooter)+" arrow collision gives the source creeper record eligibility")
		Jukeboxes.arrow_killed(creeper,shooter,true)
		suite.check(drops(game) == before+(1 if shooter in ["skeleton","stray"] else 0),"repeated death callback never duplicates a "+shooter+" record")
		await suite.process_frame
	var creeper: Creature = mob(game,"creeper",Vector3(6.5,600.01,8.5)); creeper.health = 20
	var shot: Arrow = arrow(game,"skeleton",Vector3(6.5,601.0,12.5),Vector3.FORWARD); fly(shot)
	before = drops(game); creeper.hit(100)
	suite.check(drops(game) == before,"a later player kill never inherits an earlier nonfatal skeleton arrow cause")
	await suite.process_frame
	for y in range(600,604): game.world.set_node(Vector3i(6,y,10),Nodes.STONE)
	creeper = mob(game,"creeper",Vector3(6.5,600.01,8.5)); creeper.health = 1
	before = drops(game); shot = arrow(game,"skeleton",Vector3(6.5,601.0,12.5),Vector3.FORWARD); fly(shot)
	suite.check(shot.stuck and creeper.health == 1 and drops(game) == before,"wall collision prevents a skeleton arrow killing or awarding a disc through solid terrain")
	creeper.queue_free(); shot.queue_free()
	for y in range(600,604): game.world.set_node(Vector3i(6,y,10),Nodes.AIR)
	var rng := RandomNumberGenerator.new(); rng.seed = 10083
	var distribution: Dictionary = {}; var stronghold: int = 0
	for i in 12000:
		var id: int = Jukeboxes.creeper_disc(rng); distribution[id] = int(distribution.get(id,0))+1
		stronghold += Jukeboxes.stronghold_records(rng).size()
	suite.check(distribution.size() == 6 and not distribution.has(Jukeboxes.CHIRP) and not distribution.has(Jukeboxes.MALL) and distribution.values().all(func(n): return n > 1750 and n < 2250),"seeded creeper loot reaches all six equally weighted source records and excludes Chirp/Mall")
	suite.check(stronghold > 230 and stronghold < 360,"source stronghold Mellohi rolls retain full-table one-in-102 weighting and two-to-three attempts")
	# Actual file save/load preserves item metadata but not runtime sound handles.
	game.player.position = Vector3(8.5,600.01,12.5); held(game,Jukeboxes.CHIRP,1,{"custom_name":"Keepsake"}); click(game,p)
	var path: String = "user://jukebox-check.json"
	game.save_game(path)
	var saved: Dictionary = game.read_save(path)
	Jukeboxes.reset(game.world)
	suite.check(Jukeboxes.players(game.world).is_empty(),"reset/dimension cleanup removes every active music player")
	game.set_process(true); game.world.set_process(true); game.load_world_data(saved)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await suite.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	var restored: Dictionary = Jukeboxes.station(game.world,p).slots[0]
	suite.check(game.world.node_at(p) == Jukeboxes.ID and restored.id == Jukeboxes.CHIRP and restored.get("data",{}).get("custom_name","") == "Keepsake" and Jukeboxes.players(game.world).is_empty(),"real save/load preserves the inserted named disc without restarting music")
	game.state = "playing"; game.player.set_process(false); game.player.set_physics_process(false)

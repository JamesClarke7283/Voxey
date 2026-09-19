extends RefCounted

static func equip(game: Node3D, id: int, count: int = 1) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0}
	game.player.use_cooldown = 0; game.player.use_latched = false; game.player.eating.clear()

static func pair(game: Node3D, p: Vector3i, item: int = VillageContent.WOODEN_DOOR, face: int = 0, mirror: bool = false, opened: bool = false) -> void:
	for top in [false,true]: game.world.set_node(p+(Vector3i.UP if top else Vector3i.ZERO),Doors.state_id(item,face,mirror,opened,top))

static func clear_pair(game: Node3D, p: Vector3i) -> void:
	game.world.set_node(p,Nodes.AIR); game.world.set_node(p+Vector3i.UP,Nodes.AIR)

static func use(game: Node3D, p: Vector3i, normal: Vector3i = Vector3i.UP) -> void:
	game.player.target = {"id":game.world.node_at(p),"pos":p,"normal":normal,"point":Vector3(p)+Vector3(0.5,0.5,0.5),"distance":2.0}
	game.player.use()

static func count_drops(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func legacy_front(id: int, direction: Vector3i) -> Vector3:
	# This is the actual pre-migration renderer, not the new placement mapping.
	# Its local front is -Z and refresh() rotates it by atan2(-dir.x,-dir.z).
	var old: Node3D = RedstoneArt.build(id,{"dir":[direction.x,0,direction.z]})
	old.rotation.y = atan2(-direction.x,-direction.z)
	var result: Vector3 = old.basis*old.get_child(0).basis*Vector3.FORWARD
	old.free()
	return result

static func legacy_orientation_checks(t: SceneTree, game: Node3D) -> void:
	var fixtures: Array = []
	var directions: Array = [Vector3i.FORWARD,Vector3i.RIGHT,Vector3i.BACK,Vector3i.LEFT]
	for opened in [false,true]:
		for i in directions.size():
			var p := Vector3i(2+i*3,560,2+(4 if opened else 0))
			var direction: Vector3i = directions[i]
			var legacy: int = Nodes.IRON_DOOR_OPEN if opened else Nodes.IRON_DOOR
			var front: Vector3 = legacy_front(legacy,direction)
			for top in [false,true]:
				var at: Vector3i = p+(Vector3i.UP if top else Vector3i.ZERO)
				game.world.set_node(at,legacy)
				game.world.block_states[VoxelWorld.station_key(at)] = {"dir":[direction.x,0,direction.z],"upper":top,"powered":opened and not top}
			Doors.migrate_at(game.world,p+Vector3i.UP)
			var box: AABB = Doors.boxes(game.world.node_at(p))[0]
			var migrated_front: Vector3 = (box.get_center()-Vector3.ONE*0.5).normalized()
			t.check(migrated_front.is_equal_approx(front),"legacy "+("open" if opened else "closed")+" iron door preserves old rendered front for direction "+str(direction))
			# Save a genuinely old node pair, so the subsequent test exercises
			# automatic loading migration rather than saving already-new IDs.
			for top in [false,true]:
				var at: Vector3i = p+(Vector3i.UP if top else Vector3i.ZERO)
				game.world.set_node(at,legacy)
				game.world.block_states[VoxelWorld.station_key(at)] = {"dir":[direction.x,0,direction.z],"upper":top,"powered":opened and not top}
			game.world.set_node(p+Vector3i.RIGHT,Nodes.REDSTONE_BLOCK if opened else Nodes.AIR)
			fixtures.append({"pos":p,"dir":[direction.x,0,direction.z],"front":front,"open":opened})
	game.player.position = Vector3(8.5,560,12.5)
	t.check(game.save_game("user://door_legacy_check.json"),"legacy directional door fixture saves before migration")
	var saved: Dictionary = game.read_save("user://door_legacy_check.json")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await t.process_frame
	game.pause(); game.set_process(false); game.world.active = false; game.world.set_process(false)
	for fixture in fixtures:
		var p: Vector3i = fixture.pos; var lower: int = game.world.node_at(p)
		var lower_meta: Dictionary = game.world.block_states.get(VoxelWorld.station_key(p),{})
		var top_meta: Dictionary = game.world.block_states.get(VoxelWorld.station_key(p+Vector3i.UP),{})
		var front: Vector3 = (Doors.boxes(lower)[0].get_center()-Vector3.ONE*0.5).normalized()
		# JSON numeric array members deserialize as floats; compare their actual
		# integer direction, not Array's strict Variant-type equality.
		var lower_direction: Array = lower_meta.get("dir",[]).map(func(value): return int(value))
		var top_direction: Array = top_meta.get("dir",[]).map(func(value): return int(value))
		t.check(Doors.matching_pair(game.world,p,lower) and Doors.opened(lower) == fixture.open and front.is_equal_approx(fixture.front) and lower_direction == fixture.dir and top_direction == fixture.dir and not lower_meta.get("upper",true) and top_meta.get("upper",false) and lower_meta.get("powered",false) == fixture.open and not top_meta.get("powered",true) and lower_meta.get("door_power",0) == (15 if fixture.open else 0),"actual old-save migration retains both halves, orientation and dir/upper/powered metadata "+str(fixture.dir)+(" open" if fixture.open else " closed"))
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://door_legacy_check.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

static func run(t: SceneTree, game: Node3D) -> void:
	game._clear_entities(); await t.process_frame
	game.state = "playing"; game.gamemode = "survival"; game.player.set_process(false); game.player.set_physics_process(false); game.world.active = false; game.world.set_process(false)
	var p := Vector3i(8,560,8)
	for x in range(2,15):
		for z in range(2,15):
			for y in range(559,565): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 559 else Nodes.AIR)
	game.player.position = Vector3(p)+Vector3(0.5,0,-3); game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO
	for item in Doors.ITEMS:
		var geometry_valid: bool = true
		for face in 4:
			for mirror in [false,true]:
				for opened in [false,true]:
					for top in [false,true]:
						var id: int = Doors.state_id(item,face,mirror,opened,top)
						var box: AABB = Doors.boxes(id)[0]
						geometry_valid = geometry_valid and Nodes.exists(id) and Nodes.solid(id) and Nodes.transparent(id) and not Nodes.placeable(id) and not Nodes.all_ids().has(id) and Nodes.drop(id) == item and is_equal_approx(box.get_volume(),3.0/16.0) and box.size.y == 1 and box.position.y == 0
		t.check(geometry_valid,Doors.title(item)+" has source3/16 geometry and canonical drops across32 hidden states")
		t.check(Nodes.placeable(item) and Nodes.all_ids().has(item) and Nodes.max_stack(item) == 64 and not Doors.icon_faces(item).is_empty(),Doors.title(item)+" has one usable inventory item and original paired-door icon")
	var forward: Array = [Vector3.BACK,Vector3.RIGHT,Vector3.FORWARD,Vector3.LEFT]
	for direction in 4:
		clear_pair(game,p); equip(game,VillageContent.WOODEN_DOOR,3)
		game.player.position = Vector3(p)+Vector3(0.5,0,0.5)-forward[direction]*3
		game.player.camera.look_at(game.player.camera.global_position+forward[direction])
		use(game,p+Vector3i.DOWN)
		var lower: int = game.world.node_at(p); var top: int = game.world.node_at(p+Vector3i.UP)
		t.check(Doors.is_door(lower) and Doors.facing(lower) == posmod(-direction,4) and Doors.matching_pair(game.world,p,lower) and Doors.upper(top) and game.inventory.count_item(VillageContent.WOODEN_DOOR) == 2,"actual door placement orients both halves to look direction "+str(direction)+" and consumes one item")
	clear_pair(game,p); game.player.position = Vector3(p)+Vector3(0.5,0,-3); game.player.camera.look_at(game.player.camera.global_position+Vector3.BACK)
	var left: Vector3i = p+Vector3i.LEFT
	clear_pair(game,left); equip(game,VillageContent.WOODEN_DOOR,3); use(game,left+Vector3i.DOWN); use(game,p+Vector3i.DOWN)
	t.check(not Doors.mirrored(game.world.node_at(left)) and Doors.mirrored(game.world.node_at(p)) and Doors.facing(game.world.node_at(left)) == Doors.facing(game.world.node_at(p)),"placing a matching door to the right creates a mirrored pair of hinges")
	equip(game,Nodes.APPLE,2); game.player.hunger = 10; use(game,left+Vector3i.UP)
	t.check(Doors.opened(game.world.node_at(left)) and Doors.opened(game.world.node_at(left+Vector3i.UP)) and not Doors.opened(game.world.node_at(p)) and game.player.eating.is_empty() and game.inventory.count_item(Nodes.APPLE) == 2,"actual upper-half use opens only its two-block door and precedes held food consumption")
	use(game,p)
	var first: AABB = Doors.boxes(game.world.node_at(left))[0]; var second: AABB = Doors.boxes(game.world.node_at(p))[0]
	t.check(first.position.x < 0.01 and second.position.x > 0.8,"mirrored doors swing to opposite outer sides and leave their shared opening clear")
	clear_pair(game,left); clear_pair(game,p)
	pair(game,p); equip(game,0,0)
	game.player.camera.look_at(Vector3(p)+Vector3(0.5,1.5,0.1))
	var picked: Vector3i = Vector3i.ZERO
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = down
		Input.parse_input_event(event); Input.flush_buffered_events(); game.player._process(0.016)
		if down: picked = game.player.target.get("pos",Vector3i.ZERO)
	t.check(Doors.opened(game.world.node_at(p)) and picked == p+Vector3i.UP,"real mouse use selects a thin upper panel and operates both halves")
	for item in [VillageContent.WOODEN_DOOR,Nodes.IRON_DOOR]:
		pair(game,p,item); equip(game,0,0); use(game,p)
		t.check(Doors.opened(game.world.node_at(p)) == (item == VillageContent.WOODEN_DOOR),Doors.title(item)+" follows wood hand-use versus iron redstone-only behavior")
		pair(game,p,item)
		for power_height in [0,1]:
			var source: Vector3i = p+Vector3i.RIGHT+Vector3i.UP*power_height
			game.world.set_node(source,RedstoneSensors.TARGET_ON)
			var state: Dictionary = game.world.circuits.state(source); state.out = 7; state.target_remaining = 30
			game.world.circuits.step(); game.world.circuits.step()
			t.check(Doors.opened(game.world.node_at(p)) and Doors.opened(game.world.node_at(p+Vector3i.UP)),Doors.title(item)+" opens when powered through "+("upper" if power_height else "lower")+" half")
			game.world.set_node(source,Nodes.AIR); game.world.circuits.step(); game.world.circuits.step()
			t.check(not Doors.opened(game.world.node_at(p)) and not Doors.opened(game.world.node_at(p+Vector3i.UP)),Doors.title(item)+" closes both halves when the signal ends")
		if item == VillageContent.WOODEN_DOOR:
			use(game,p); game.world.circuits.step(); game.world.circuits.step()
			t.check(Doors.opened(game.world.node_at(p)),"manually opened unpowered wood door remains open through redstone polling")
	# Source has no attached-node group: side placement does not require a floor.
	clear_pair(game,p); game.world.set_node(p+Vector3i.DOWN,Nodes.AIR); equip(game,VillageContent.WOODEN_DOOR,2)
	game.player.target = {"pos":p+Vector3i.RIGHT,"id":Nodes.STONE,"normal":Vector3i.LEFT,"point":Vector3(p)+Vector3.ONE*0.5,"distance":2.0}
	game.world.set_node(p+Vector3i.RIGHT,Nodes.STONE); game.player.use()
	t.check(Doors.is_door(game.world.node_at(p)) and game.world.node_at(p+Vector3i.DOWN) == Nodes.AIR,"source side placement permits a floating two-block door")
	clear_pair(game,p); game.world.set_node(p+Vector3i.RIGHT,Nodes.AIR); game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	game.world.set_node(p,SnowCover.BASE); game.world.set_node(p+Vector3i.UP,Nodes.STONE); equip(game,VillageContent.WOODEN_DOOR,2); use(game,p)
	t.check(game.world.node_at(p) == SnowCover.BASE and game.inventory.count_item(VillageContent.WOODEN_DOOR) == 2,"occupied second cell rejects placement atomically without consuming lower snow or inventory")
	game.world.set_node(p,Nodes.AIR); game.world.set_node(p+Vector3i.UP,Nodes.AIR)
	for item in [VillageContent.WOODEN_DOOR,Nodes.IRON_DOOR]:
		for top in [false,true]:
			pair(game,p,item); equip(game,Nodes.TOOLS,1)
			var before: int = count_drops(game,item); var target: Vector3i = p+(Vector3i.UP if top else Vector3i.ZERO)
			game.break_node(target,game.world.node_at(target),Nodes.TOOLS)
			t.check(game.world.node_at(p) == Nodes.AIR and game.world.node_at(p+Vector3i.UP) == Nodes.AIR and count_drops(game,item)-before == 1,Doors.title(item)+" mining either half removes the pair and yields one door")
	game.gamemode = "creative"; pair(game,p); var before: int = count_drops(game,VillageContent.WOODEN_DOOR); game.break_node(p,game.world.node_at(p),0)
	t.check(game.world.node_at(p+Vector3i.UP) == Nodes.AIR and count_drops(game,VillageContent.WOODEN_DOOR) == before,"creative door removal destroys both halves without item drops")
	game.gamemode = "survival"
	pair(game,p)
	game.world.set_node(p+Vector3i.UP,Doors.state_id(Nodes.IRON_DOOR,0,false,false,true))
	equip(game,0,0); use(game,p)
	t.check(not Doors.opened(game.world.node_at(p)),"an unmatched material above cannot be opened as the other door half")
	game.break_node(p,game.world.node_at(p),0)
	t.check(Doors.is_door(game.world.node_at(p+Vector3i.UP)) and Doors.iron(game.world.node_at(p+Vector3i.UP)),"breaking an orphan half does not destroy an unrelated door above it")
	clear_pair(game,p)
	var piston: Vector3i = p+Vector3i.LEFT
	for item in [VillageContent.WOODEN_DOOR,Nodes.IRON_DOOR]:
		for height in [0,1]:
			var push: Vector3i = piston+Vector3i.UP*height
			pair(game,p,item); game.world.set_node(push,Nodes.PISTON); game.world.circuits.configure(push,Vector3i.RIGHT)
			before = count_drops(game,item); var moved: bool = game.world.circuits.piston(push,true)
			t.check(moved and game.world.node_at(p+Vector3i.UP*height) == Nodes.PISTON_HEAD and game.world.node_at(p+Vector3i.UP*(1-height)) == Nodes.AIR and count_drops(game,item)-before == 1,"piston hitting "+Doors.title(item)+" half "+str(height)+" destroys its pair for exactly one source drop")
			game.world.circuits.piston(push,false); game.world.set_node(push,Nodes.AIR)
	game.world.set_node(piston,Nodes.STICKY_PISTON); game.world.circuits.configure(piston,Vector3i.RIGHT)
	game.world.circuits.piston(piston,true); pair(game,p+Vector3i.RIGHT)
	game.world.circuits.piston(piston,false)
	t.check(game.world.node_at(p) == Nodes.AIR and Doors.matching_pair(game.world,p+Vector3i.RIGHT,game.world.node_at(p+Vector3i.RIGHT)),"sticky piston retraction leaves source unsticky doors in place")
	clear_pair(game,p+Vector3i.RIGHT); game.world.set_node(piston,Nodes.AIR)
	for legacy in [VillageContent.WOODEN_DOOR,VillageContent.WOODEN_DOOR_OPEN,Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN]:
		game.world.set_node(p,legacy); game.world.set_node(p+Vector3i.UP,legacy)
		game.world.block_states[VoxelWorld.station_key(p)] = {"dir":[1,0,0],"upper":false,"powered":true}
		game.world.block_states[VoxelWorld.station_key(p+Vector3i.UP)] = {"dir":[1,0,0],"upper":true,"powered":true}
		Doors.migrate_at(game.world,p+Vector3i.UP)
		var lower: int = game.world.node_at(p)
		t.check(Doors.is_door(lower) and Doors.matching_pair(game.world,p,lower) and Doors.opened(lower) == (legacy in [VillageContent.WOODEN_DOOR_OPEN,Nodes.IRON_DOOR_OPEN]) and game.world.circuits.state(p).get("door_power",0) == 15,"legacy door "+str(legacy)+" migration preserves paired state and redstone memory")
	for face in 4:
		pair(game,p,VillageContent.WOODEN_DOOR,face)
		var box: AABB = Doors.boxes(Doors.state_id(VillageContent.WOODEN_DOOR,face,false,true))[0]
		var at: Vector3 = box.get_center(); at.y = 0
		var closed: AABB = Doors.boxes(game.world.node_at(p))[0]
		if closed.size.x < 1: at.x = 0.6 if closed.position.x < 0.5 else 0.4
		else: at.z = 0.6 if closed.position.z < 0.5 else 0.4
		game.player.position = Vector3(p)+at; game.player.velocity = Vector3(1,0,1)
		var clear_before: bool = not game.world.intersects(game.player.position)
		var original: Vector3 = game.player.position; Doors.set_open(game.world,p,true)
		t.check(clear_before and not game.world.intersects(game.player.position) and game.player.position.distance_to(original) < 0.6,"door hinge "+str(face)+" gently resolves an intersecting player against the entire paired panel")
	game.player.position = Vector3(p)+Vector3(0.5,0,-3)
	pair(game,p)
	var sheep: Creature = game.spawn_creature("sheep",Vector3(p)+Vector3(0.10,0,0.65)); sheep.set_physics_process(false)
	var unaffected: Vector3 = game.player.position; Doors.set_open(game.world,p,true)
	t.check(not game.world.intersects(sheep.position,sheep.width,sheep.height) and game.player.position == unaffected,"paired door recovery frees an intersecting sheep without moving an unrelated player")
	Farming.forget(sheep); game.creatures.remove_child(sheep); sheep.free()
	pair(game,p)
	var boat: BoatEntity = game.boats.spawn(VillageContent.BOAT_OAK,Vector3(p)+Vector3(0.10,0,0.8))
	if boat != null:
		boat.set_physics_process(false); boat.speed = 5; Doors.set_open(game.world,p,true)
	t.check(boat != null and not boat.blocked(boat.position) and boat.speed == 0,"paired door recovery frees an overlapping boat hull and cancels its stale speed")
	if boat != null:
		game.boats.records().erase(boat.key); game.boats.active.erase(boat.key); boat.removed = true; boat.queue_free()
	pair(game,p,VillageContent.WOODEN_DOOR,2,true,true)
	t.check(game.save_game("user://door_check.json"),"door save succeeds")
	var saved: Dictionary = game.read_save("user://door_check.json")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await t.process_frame
	game.pause(); game.set_process(false); game.world.active = false; game.world.set_process(false)
	var id: int = game.world.node_at(p)
	t.check(Doors.matching_pair(game.world,p,id) and Doors.facing(id) == 2 and Doors.mirrored(id) and Doors.opened(id),"actual reload preserves paired door facing, hinge and open state")
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://door_check.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	await legacy_orientation_checks(t,game)
	game.pause()

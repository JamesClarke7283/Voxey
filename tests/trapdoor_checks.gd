extends RefCounted
const Helper = preload("res://tests/barrier_checks.gd")

static func overlap_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var world: VoxelWorld = game.world; var original: Vector3 = game.player.position
	for x in range(-2,3):
		for z in range(-2,3):
			for y in range(-1,4): world.set_node(p+Vector3i(x,y,z),Nodes.STONE if y == -1 else Nodes.AIR)
	game.player.flying = false; game.player.velocity = Vector3.ZERO
	for facing in 4:
		world.set_node(p,Trapdoors.state_id(Trapdoors.OAK,facing,false,false))
		var box: AABB = Trapdoors.boxes(Trapdoors.state_id(Trapdoors.OAK,facing,false,true))[0]
		var near_hinge: Vector3 = box.get_center(); near_hinge.y = Trapdoors.THICKNESS
		near_hinge.x = clampf(near_hinge.x,0.1,0.9); near_hinge.z = clampf(near_hinge.z,0.1,0.9)
		game.player.position = Vector3(p)+near_hinge
		var clear_before: bool = not world.intersects(game.player.position)
		var previous: Vector3 = game.player.position
		Trapdoors.set_open(world,p,true)
		var displacement: float = game.player.position.distance_to(previous)
		var clear_after: bool = not world.intersects(game.player.position)
		var motion: Vector3 = (Vector3(0.5,0,0.5)-Vector3(near_hinge.x,0,near_hinge.z)).normalized()*0.07
		previous = game.player.position
		for i in 120: game.player._move(motion,false,true)
		t.check(clear_before and clear_after and displacement > 0 and displacement < 0.41 and game.player.position.distance_to(previous)>1,"opening hinge "+str(facing)+" minimally frees an overlapping player and normal small walk steps continue")
	world.set_node(p,Trapdoors.state_id(Trapdoors.IRON,0,true,true))
	game.player.position = Vector3(p)+Vector3(0.5,0.1,0.5); game.player.velocity = Vector3.ZERO
	var clear_before: bool = not world.intersects(game.player.position)
	Trapdoors.set_open(world,p,false)
	var clear_after: bool = not world.intersects(game.player.position)
	var previous: Vector3 = game.player.position
	for i in 120: game.player._move(Vector3(0,0,-0.07),false)
	t.check(clear_before and clear_after and not Trapdoors.open(world.node_at(p)) and game.player.position.distance_to(previous)>1,"closing an upper iron trapdoor through the player's body preserves the toggle and leaves normal movement usable")
	# If the closest lateral faces are blocked, the free upper face wins.
	for side in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		for y in range(0,3): world.set_node(p+side+Vector3i.UP*y,Nodes.STONE)
	world.set_node(p,Trapdoors.state_id(Trapdoors.IRON,0,true,true))
	game.player.position = Vector3(p)+Vector3(0.5,0.1,0.5); game.player.velocity = Vector3(0,-18,0)
	Trapdoors.set_open(world,p,false)
	t.check(not world.intersects(game.player.position) and game.player.position.y >= p.y+1 and game.player.velocity.y == 0,"blocked nearest faces fall back to the free upper face and cancel stale falling velocity")
	world.set_node(p+Vector3i.UP*2,Nodes.STONE)
	world.set_node(p,Trapdoors.state_id(Trapdoors.IRON,0,true,true))
	game.player.position = Vector3(p)+Vector3(0.5,0.1,0.5); previous = game.player.position
	Trapdoors.set_open(world,p,false)
	t.check(not Trapdoors.open(world.node_at(p)) and game.player.position == previous,"fully boxed actors keep their position and source toggle rather than teleporting through walls")
	for side in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		for y in range(0,3): world.set_node(p+side+Vector3i.UP*y,Nodes.AIR)
	world.set_node(p+Vector3i.UP*2,Nodes.AIR)
	game.player.position = Vector3(p)+Vector3(0.5,0,-2)
	var unaffected: Vector3 = game.player.position
	world.set_node(p,Trapdoors.OAK)
	var sheep := Creature.new(); sheep.game = game; sheep.kind = "sheep"
	sheep.position = Vector3(p)+Vector3(0.5,Trapdoors.THICKNESS,0.9); game.creatures.add_child(sheep); sheep.set_physics_process(false)
	Trapdoors.set_open(world,p,true)
	t.check(not world.intersects(sheep.position,sheep.width,sheep.height) and sheep.position.z < p.z+0.6 and game.player.position == unaffected,"trapdoor swaps also free affected creatures without moving unrelated actors")
	Farming.forget(sheep); game.creatures.remove_child(sheep); sheep.free()
	world.set_node(p,Trapdoors.OAK)
	var boat: BoatEntity = game.boats.spawn(VillageContent.BOAT_OAK,Vector3(p)+Vector3(0.5,Trapdoors.THICKNESS,0.7))
	if boat != null:
		boat.set_physics_process(false); Trapdoors.set_open(world,p,true)
	t.check(boat != null and not boat.blocked(boat.position) and boat.position.z < p.z+0.4,"trapdoor swaps free a boat hull instead of leaving its movement solver embedded")
	if boat != null:
		game.boats.records().erase(boat.key); game.boats.active.erase(boat.key); boat.removed = true; boat.queue_free()
	for x in range(-2,3):
		for z in range(-2,3):
			for y in range(-1,4): world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = original; game.player.velocity = Vector3.ZERO

static func run(t: SceneTree, game: Node3D) -> void:
	var inv := Inventory.new()
	var oak: Dictionary = inv.recipes[inv.recipe_index(Trapdoors.OAK)]
	var iron: Dictionary = inv.recipes[inv.recipe_index(Trapdoors.IRON)]
	t.check(oak.count == 2 and oak.ingredients == {Nodes.PLANKS:6} and iron.count == 1 and iron.ingredients == {Nodes.IRON:4},"trapdoors use six planks for two or four iron ingots for one")
	t.check(Nodes.fuel_time(Trapdoors.OAK) == 15 and Nodes.fuel_time(Trapdoors.IRON) == 0 and not Fire.flammable(Trapdoors.OAK),"wood trapdoors are fifteen-second fuel but retain source nonflammable behavior")
	t.check(Nodes.hardness(Trapdoors.OAK) == 3 and Nodes.hardness(Trapdoors.IRON) == 5 and Nodes.harvestable(Trapdoors.OAK,0) and not Nodes.harvestable(Trapdoors.IRON,0) and Nodes.harvestable(Trapdoors.IRON,Nodes.TOOLS),"source wood/iron hardness and hand-versus-pickaxe harvest rules")
	for base in [Trapdoors.OAK,Trapdoors.IRON]:
		for top in [false,true]:
			for turn in 4:
				for opened in [false,true]:
					var id: int = Trapdoors.state_id(base,turn,top,opened)
					var box: AABB = Trapdoors.boxes(id)[0]
					t.check(Nodes.exists(id) and Nodes.drop(id) == base and Nodes.placeable(id) == (id == base) and is_equal_approx(box.get_volume(),3.0/16.0) and (opened or is_equal_approx(box.position.y,0.8125 if top else 0.0)),"all source trapdoor states have canonical drops, catalog visibility and 3/16 geometry: "+str(id))
	var world: VoxelWorld = game.world; var p := Vector3i(8,540,8)
	game.pause(); world.active = false; world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	for x in range(-2,4):
		for z in range(-2,4):
			for y in range(-1,4): world.set_node(p+Vector3i(x,y,z),Nodes.STONE if y == -1 else Nodes.AIR)
	game.player.position = Vector3(p)+Vector3(0.5,0,-2); game.gamemode = "survival"; game.player.eating.clear()
	Helper.equip(game,Trapdoors.OAK,3)
	game.player.target = {"pos":p+Vector3i.DOWN,"normal":Vector3i.UP,"id":Nodes.STONE,"distance":2.0,"point":Vector3(p)+Vector3(0.5,0,0.5)}
	game.player.use()
	t.check(world.node_at(p) == Trapdoors.OAK and game.inventory.held().count == 2,"actual player use places a bottom trapdoor facing away from the player")
	t.check(world.intersects(Vector3(p)+Vector3(0.5,0.01,0.5),0.1,0.1) and not world.intersects(Vector3(p)+Vector3(0.5,0.2,0.5),0.1,0.5),"closed trapdoor collision occupies only its lower 3/16 slab")
	var ray: Dictionary = world.raycast(Vector3(p)+Vector3(0.3,2,0.3),Vector3.DOWN,2)
	t.check(ray.get("pos") == p and is_equal_approx(ray.point.y,p.y+0.1875),"trapdoor selection hits its real surface even over a visual cutout")
	Helper.equip(game,Nodes.APPLE,2); game.player.hunger = 10
	game.player.target = {"pos":p,"normal":Vector3i.UP,"id":world.node_at(p),"distance":2.0,"point":Vector3(p)+Vector3(0.3,0.1875,0.3)}
	game.player.use()
	t.check(Trapdoors.open(world.node_at(p)) and game.player.eating.is_empty() and game.inventory.held().count == 2,"wood trapdoor operation takes priority over food without consuming it")
	t.check(not world.intersects(Vector3(p)+Vector3(0.5,0.1,0.5),0.1,0.5) and world.intersects(Vector3(p)+Vector3(0.5,0.1,0.9),0.05,0.5),"open trapdoor leaves central space but retains its upright thin collision")
	world.circuits.step(); world.circuits.step()
	t.check(Trapdoors.open(world.node_at(p)),"manual unpowered opening persists through redstone polling")
	for side in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		var expected: int = Trapdoors.placement_id(Trapdoors.OAK,p,Vector3i.UP,Vector3(p),Vector3(p)+Vector3.ONE*0.5-side*2)
		t.check((Trapdoors.boxes(expected+8)[0].get_center()-Vector3.ONE*0.5).dot(side)>0.0,"open hinge orientation follows source placement direction "+str(side))
	t.check(Trapdoors.upper(Trapdoors.placement_id(Trapdoors.OAK,p,Vector3i.DOWN,Vector3(p),Vector3(p)-Vector3.FORWARD)) and Trapdoors.upper(Trapdoors.placement_id(Trapdoors.OAK,p,Vector3i.RIGHT,Vector3(p)+Vector3.UP*0.8,Vector3(p)-Vector3.FORWARD)) and not Trapdoors.upper(Trapdoors.placement_id(Trapdoors.OAK,p,Vector3i.RIGHT,Vector3(p)+Vector3.UP*0.2,Vector3(p)-Vector3.FORWARD)),"undersides and upper side clicks place top trapdoors; lower side clicks place bottom ones")
	world.set_node(p,Trapdoors.IRON); Helper.equip(game,0)
	game.player.target.id = Trapdoors.IRON; game.player.use()
	t.check(world.node_at(p) == Trapdoors.IRON,"iron trapdoors cannot open by hand")
	var power_pos: Vector3i = p+Vector3i.LEFT
	world.set_node(power_pos,RedstoneSensors.TARGET_ON)
	var signal_state: Dictionary = world.circuits.state(power_pos); signal_state.out = 7; signal_state.target_remaining = 10
	world.circuits.step(); world.circuits.step()
	t.check(Trapdoors.open(world.node_at(p)),"weak redstone power opens an iron trapdoor")
	world.set_node(p,Trapdoors.OAK); world.circuits.step()
	game.player.target.id = world.node_at(p); game.player.use(); world.circuits.step()
	t.check(not Trapdoors.open(world.node_at(p)),"wood trapdoors may be manually closed under unchanged redstone power")
	signal_state.out = 6; world.circuits.step()
	t.check(Trapdoors.open(world.node_at(p)),"a nonzero signal strength change reopens a manually closed trapdoor as in source")
	signal_state.out = 0; world.circuits.step()
	t.check(not Trapdoors.open(world.node_at(p)),"losing redstone power closes the trapdoor")
	world.set_node(power_pos,Nodes.AIR)
	world.set_node(p,Trapdoors.state_id(Trapdoors.OAK,0,true,true))
	game.player.position = Vector3(p)+Vector3(0.5,0.05,0.5); game.player.velocity = Vector3.ZERO; game.player.flying = false
	var old_touch: bool = game.touch; game.touch = false
	game.state = "playing"; load("res://tests/swimming_checks.gd").keyboard(KEY_SPACE,true); game.player._physics_process(0.1); load("res://tests/swimming_checks.gd").keyboard(KEY_SPACE,false); game.touch = old_touch
	t.check(game.player.position.y > p.y+0.3 and game.player.velocity.y > 0,"an open trapdoor can be climbed without an underlying ladder")
	game.pause(); game.player.position = Vector3(p)+Vector3(0.5,0,-2)
	world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	t.check(Trapdoors.is_trapdoor(world.node_at(p)),"trapdoors stay placed after their original support is removed")
	var saved_id: int = world.node_at(p); var before: int = Helper.drops(game,Trapdoors.OAK)
	game.break_node(p,saved_id,0)
	t.check(world.node_at(p) == Nodes.AIR and Helper.drops(game,Trapdoors.OAK) == before+1,"breaking an upper open trapdoor drops exactly one canonical item")
	world.set_node(p,Trapdoors.state_id(Trapdoors.IRON,3,true,true)); world.circuits.state(p).trapdoor_power = 9
	world.circuits._move(p,p+Vector3i.RIGHT)
	t.check(world.node_at(p+Vector3i.RIGHT) == Trapdoors.state_id(Trapdoors.IRON,3,true,true) and world.circuits.state(p+Vector3i.RIGHT).get("trapdoor_power") == 9,"piston movement preserves trapdoor geometry and prior power metadata")
	world.set_node(p+Vector3i.RIGHT,Trapdoors.state_id(Trapdoors.OAK,3,true,true)); world.circuits.state(p+Vector3i.RIGHT).trapdoor_power = 0
	var padded := PackedInt32Array(); padded.resize(5832); padded[343] = Trapdoors.OAK
	var surfaces: Array = BlockMesher.build(padded,true)
	t.check(not surfaces[0].is_empty() and surfaces[0][Mesh.ARRAY_VERTEX].size()>24 and Trapdoors.icon_faces(Trapdoors.IRON).size()>6,"world meshing and inventory art expose the trapdoor's original openwork model")
	overlap_checks(t,game,p+Vector3i.UP*10)
	t.check(game.save_game("user://trapdoor_check.json"),"trapdoor states save through ordinary block edits")
	var saved: Dictionary = game.read_save("user://trapdoor_check.json")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await t.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	t.check(game.world.node_at(p+Vector3i.RIGHT) == Trapdoors.state_id(Trapdoors.OAK,3,true,true),"actual disk reload retains upper half, facing and open trapdoor state")
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://trapdoor_check.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

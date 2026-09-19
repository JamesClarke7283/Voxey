extends RefCounted

static func projectiles(game: Node3D) -> Array:
	return game.entities.get_children().filter(func(entity): return entity is ThrownItem and not entity.is_queued_for_deletion())

static func chickens(game: Node3D) -> Array:
	return game.creatures.get_children().filter(func(mob): return mob.kind == "chicken" and not mob.is_queued_for_deletion())

static func clear_shots(game: Node3D) -> void:
	for shot in projectiles(game): shot.queue_free()

static func held(game: Node3D, id: int, amount: int = 5) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":amount,"wear":0}

static func press(game: Node3D, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = down
	event.position = game.get_viewport().get_visible_rect().size*0.5; event.global_position = event.position
	Input.parse_input_event(event); Input.flush_buffered_events()
	game.player._process(1.0/60.0)

static func click(game: Node3D) -> void:
	game.player.use_cooldown = 0; press(game,true); press(game,false)

static func launch(game: Node3D, id: int, at: Vector3, direction: Vector3 = Vector3.FORWARD) -> ThrownItem:
	var shot: ThrownItem = Throwables.launch(game,id,at,direction,game.player)
	shot.set_physics_process(false)
	return shot

static func fly(shot: ThrownItem, delta: float = 1.0/60.0, limit: float = 1.5) -> void:
	for i in ceili(limit/delta):
		if shot.impacted or shot.is_queued_for_deletion(): return
		shot._physics_process(delta)

static func seed_for(wanted: int) -> int:
	var rng := RandomNumberGenerator.new()
	for value in 10000:
		rng.seed = value
		if Throwables.hatch_count(rng) == wanted: return value
	return -1

static func animal(game: Node3D, kind: String, at: Vector3) -> Creature:
	var mob: Creature = game.spawn_creature(kind,at)
	mob.set_physics_process(false); mob.grounded = true; mob.velocity = Vector3.ZERO
	return mob

static func run(suite: SceneTree, game: Node3D) -> void:
	game._clear_entities(); Farming.records(game).clear()
	await suite.process_frame
	game.state = "playing"; game.gamemode = "survival"
	var temporary_controls: bool = not is_instance_valid(game.controls)
	if temporary_controls:
		game.controls = TouchControls.new(); game.controls.game = game; game.add_child(game.controls)
	game.touch = true
	game.player.set_process(false); game.player.set_physics_process(false)
	game.world.active = false; game.world.set_process(false)
	game.player.eating.clear(); game.player.use_latched = false
	for x in range(2,15):
		for z in range(2,15):
			for y in range(479,485): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 479 else Nodes.AIR)
	game.player.position = Vector3(8.5,480.01,12.5)
	game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO
	game.player.camera.position.y = 1.62
	suite.check(Nodes.max_stack(Nodes.EGG) == 16 and Nodes.max_stack(Nodes.SNOWBALL) == 16,"eggs and snowballs use source stacks of sixteen")
	for id in [Nodes.EGG,Nodes.SNOWBALL]:
		held(game,id); clear_shots(game)
		game.player.use_cooldown = 0; press(game,true)
		var shots: Array = projectiles(game)
		suite.check(shots.size() == 1 and game.inventory.count_item(id) == 4,"live right-click throws one "+Nodes.title(id)+" and consumes one survival item")
		if shots.size() == 1:
			var shot: ThrownItem = shots[0]; shot.set_physics_process(false)
			suite.check(shot.position.is_equal_approx(game.player.position+Vector3.UP*1.5) and shot.velocity.is_equal_approx(Vector3.FORWARD*22),"player "+Nodes.title(id)+" launches from source height and speed")
			suite.check(shot.get_child_count() == 1 and shot.get_child(0).mesh == ItemArt.mesh(id),"thrown "+Nodes.title(id)+" uses the original inventory item art")
		for i in 12:
			game.player.use_cooldown = 0; game.player._process(0.1)
		suite.check(projectiles(game).size() == 1 and game.inventory.count_item(id) == 4,"holding use does not repeatedly throw "+Nodes.title(id))
		press(game,false); click(game)
		suite.check(projectiles(game).size() == 2 and game.inventory.count_item(id) == 3,"releasing and pressing again throws another "+Nodes.title(id))
		game.gamemode = "creative"; click(game)
		suite.check(projectiles(game).size() == 3 and game.inventory.count_item(id) == 3,"creative throwing preserves "+Nodes.title(id)+" inventory")
		game.gamemode = "survival"
	clear_shots(game)
	held(game,Nodes.EGG); game.controls.use_pressed = true; game.controls.use_held = true; game.player.use_cooldown = 0
	game.player._process(0.016)
	suite.check(projectiles(game).size() == 1 and game.inventory.count_item(Nodes.EGG) == 4,"touch use launches an egg through the player controller")
	game.controls.use_held = false; game.player._process(0.016); clear_shots(game)
	# Station interaction keeps priority over the throwable in hand.
	var station := Vector3i(8,481,10)
	game.world.set_node(station,Nodes.CHEST); held(game,Nodes.EGG)
	game.player.camera.look_at(Vector3(station)+Vector3.ONE*0.5); click(game)
	suite.check(game.state == "inventory" and projectiles(game).is_empty() and game.inventory.count_item(Nodes.EGG) == 5,"using a chest while holding an egg opens it before throwing")
	game.close_inventory(); game.world.set_node(station,Nodes.AIR); game.player.camera.rotation = Vector3.ZERO
	# Analytic motion gives the same ballistic path across frame rates.
	var destinations: Array = []
	for delta in [1.0/120.0,1.0/30.0,0.1]:
		var flight: ThrownItem = launch(game,Nodes.SNOWBALL,Vector3(4.5,483,13.5))
		for i in roundi(0.3/delta): flight._physics_process(delta)
		destinations.append(flight.position)
		suite.check(not flight.impacted and is_equal_approx(flight.velocity.z,-21.1) and is_equal_approx(flight.velocity.y,-3.12),"source gravity and horizontal deceleration apply at timestep "+str(delta))
		flight.queue_free()
	suite.check(destinations[0].distance_to(destinations[1]) < 0.002 and destinations[0].distance_to(destinations[2]) < 0.002,"egg/snowball ballistic motion stays consistent across frame rates")
	var outcomes: Dictionary = {0:0,1:0,4:0}
	for first in range(1,9):
		for bonus in range(1,33): outcomes[Throwables.hatch_result(first,bonus)] += 1
	suite.check(outcomes == {0:224,1:31,4:1},"egg hatch branches give exactly seven-eighths none, 31/256 one and 1/256 four")
	var hatch_seeds: Dictionary = {0:seed_for(0),1:seed_for(1),4:seed_for(4)}
	suite.check(hatch_seeds.values().all(func(value): return value >= 0),"seeded hatch rolls reach every source outcome")
	# Real creature collision: ordinary mobs lose no health; Blazes lose three.
	for id in [Nodes.EGG,Nodes.SNOWBALL]:
		var cow: Creature = animal(game,"cow",Vector3(6.5,480.01,8.5))
		var shot: ThrownItem = launch(game,id,Vector3(6.5,480.9,12.5))
		shot.rng.seed = hatch_seeds[4]; var before: int = chickens(game).size()
		fly(shot)
		suite.check(shot.impacted and cow.health == cow.info().health and cow.knock.z < -3 and cow.scared > 0,"a "+Nodes.title(id)+" hit knocks and scares an ordinary animal without health damage")
		suite.check(cow.hurt_flash == 0 and chickens(game).size() == before,"a "+Nodes.title(id)+" creature hit neither hatches chicks nor shows health-damage flash")
		Farming.forget(cow); cow.queue_free()
	var blaze: Creature = animal(game,"blaze",Vector3(6.5,480.01,8.5))
	var snowball: ThrownItem = launch(game,Nodes.SNOWBALL,Vector3(6.5,481,12.5)); fly(snowball)
	suite.check(snowball.impacted and blaze.health == 17,"a snowball deals exactly three health damage to a Blaze")
	var egg: ThrownItem = launch(game,Nodes.EGG,Vector3(6.5,481,12.5)); fly(egg)
	suite.check(egg.impacted and blaze.health == 17,"eggs do not receive the snowball-only Blaze damage bonus")
	blaze.queue_free()
	# Sweep wall before actors even when one simulation frame travels several blocks.
	for y in range(480,484): game.world.set_node(Vector3i(6,y,9),Nodes.STONE)
	for delta in [1.0/120.0,1.0/30.0,0.3]:
		var behind: Creature = animal(game,"blaze",Vector3(6.5,480.01,8.5))
		var shot: ThrownItem = launch(game,Nodes.SNOWBALL,Vector3(6.5,481,12.5)); fly(shot,delta)
		suite.check(shot.impacted and shot.position.z > 10 and behind.health == 20,"a solid wall blocks snowball damage at timestep "+str(delta))
		behind.queue_free()
	for y in range(480,484): game.world.set_node(Vector3i(6,y,9),Nodes.AIR)
	# Liquid is not a solid impact, matching the source walkable-node check.
	game.world.set_node(Vector3i(6,480,10),Nodes.WATER); game.world.set_node(Vector3i(6,481,10),Nodes.WATER)
	blaze = animal(game,"blaze",Vector3(6.5,480.01,8.5))
	snowball = launch(game,Nodes.SNOWBALL,Vector3(6.5,481,12.5)); fly(snowball)
	suite.check(blaze.health == 17,"thrown snowballs pass through water before hitting their target")
	blaze.queue_free(); game.world.set_node(Vector3i(6,480,10),Nodes.AIR); game.world.set_node(Vector3i(6,481,10),Nodes.AIR)
	# Targets get the source fixed full-strength non-arrow pulse.
	var target := Vector3i(10,481,8)
	for id in [Nodes.EGG,Nodes.SNOWBALL]:
		game.world.set_node(target,RedstoneSensors.TARGET)
		var shot: ThrownItem = launch(game,id,Vector3(10.5,481.5,10.5)); shot.rng.seed = hatch_seeds[0]; fly(shot)
		suite.check(shot.impacted and game.world.node_at(target) == RedstoneSensors.TARGET_ON and game.world.circuits.state(target).out == 15,"a thrown "+Nodes.title(id)+" activates the target at source strength fifteen")
	game.world.set_node(target,Nodes.AIR)
	# Block impact hatch results use real physics and persist actual baby animals.
	var child_keys: Array = []
	for count in [0,1,4]:
		var shot: ThrownItem = launch(game,Nodes.EGG,Vector3(9.5+count*0.75,481.5,11.5),Vector3.DOWN)
		shot.rng.seed = hatch_seeds[count]; var before: int = chickens(game).size(); fly(shot)
		suite.check(shot.impacted and chickens(game).size()-before == count,"a seeded solid egg impact hatches "+str(count)+" chicks")
		for chick in shot.chicks:
			chick.set_physics_process(false); child_keys.append(chick.farm_id)
			suite.check(chick.growth_remaining == 1200 and chick.height == chick.info().height*0.5 and not game.world.intersects(chick.position,chick.width,chick.height),"hatched chick has source baby age and collision-safe baby dimensions")
		shot.impact(null,true)
		suite.check(chickens(game).size()-before == count,"an already impacted egg cannot hatch twice")
	suite.check(child_keys.size() == 5 and child_keys.all(func(key): return not str(key).is_empty() and Farming.records(game).has(key)),"all hatched chicks enter the persistent farming registry with unique identities")
	# Dispensers launch items, while droppers continue to eject pickups.
	var dispenser := Vector3i(4,481,12)
	game.world.set_node(dispenser,Nodes.DISPENSER); game.world.circuits.configure(dispenser,Vector3i.FORWARD)
	for id in [Nodes.EGG,Nodes.SNOWBALL]:
		clear_shots(game)
		var slots: Array = game.world.circuits.container(dispenser); slots[0] = {"id":id,"count":2,"wear":0}
		game.world.circuits.dispense(dispenser,true)
		var shots: Array = projectiles(game)
		suite.check(shots.size() == 1 and slots[0].count == 1 and shots[0].velocity.length() == 22,"a dispenser launches and consumes one "+Nodes.title(id))
		clear_shots(game); game.world.set_node(dispenser+Vector3i.FORWARD,Nodes.STONE)
		game.world.circuits.dispense(dispenser,true)
		suite.check(projectiles(game).is_empty() and slots[0].count == 1,"a blocked dispenser preserves its "+Nodes.title(id))
		game.world.set_node(dispenser+Vector3i.FORWARD,Nodes.AIR)
	game.world.set_node(dispenser,Nodes.AIR)
	clear_shots(game)
	# Real save/reload and dormant restoration must retain age and never duplicate.
	suite.check(game.save_game("user://throwing_check.json"),"world with egg-hatched chicks saves successfully")
	var saved: Dictionary = game.read_save("user://throwing_check.json")
	suite.check(child_keys.all(func(key): return saved.adventure.farm_animals.has(key) and saved.adventure.farm_animals[key].growth == 1200),"saved hatched chicks retain source growth time and identities")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await suite.process_frame
	game.pause(); game.set_process(false); game.world.active = false; game.world.set_process(false)
	suite.check(child_keys.all(func(key): return Farming.active(game,key) != null and Farming.active(game,key).growth_remaining > 1199),"actual world reload restores every hatched chick as a baby")
	game.state = "playing"
	var old_player: Vector3 = game.player.position
	game.player.position += Vector3(110,0,0)
	for key in child_keys:
		var chick: Creature = Farming.active(game,key)
		if chick != null: chick.set_physics_process(false); chick._physics_process(0.1)
	await suite.process_frame
	game.player.position = old_player
	Farming.update_world(game,1); Farming.update_world(game,1)
	suite.check(chickens(game).size() == 5 and child_keys.all(func(key): return Farming.active(game,key) != null),"returning after unload restores each egg-hatched chick exactly once")
	for chick in chickens(game): chick.set_physics_process(false)
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://throwing_check.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	game.pause()
	if temporary_controls: game.controls.free(); game.controls = null

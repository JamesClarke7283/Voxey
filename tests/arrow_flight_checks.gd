extends RefCounted

static func fresh(game: Node3D, pos: Vector3, speed: Vector3) -> Arrow:
	var arrow: Arrow = game.spawn_arrow(pos,speed); arrow.set_physics_process(false); arrow.from_player = true; arrow.shooter_id = game.player.get_instance_id()
	return arrow

static func run(t: SceneTree, game: Node3D) -> void:
	var old_slots: Array = game.inventory.slots.duplicate(true); var old_pos: Vector3 = game.player.position
	var old_mode: String = game.gamemode; var old_offhand: Dictionary = game.player.offhand_slot.duplicate(true)
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"; game.state = "playing"; game.player.position = Vector3(8,1500,20)
	game.inventory.restore([]); game.player.offhand_slot = Bookshelves.empty()
	for mob in game.creatures.get_children(): mob.free()
	for child in game.entities.get_children():
		if child is Arrow: child.free()
	var at := Vector3(8.5,1501.5,8.5)
	for x in range(7,18):
		for z in range(7,11):
			for y in range(1500,1504): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	var arrow: Arrow = fresh(game,at,Vector3(20,0,0))
	arrow._physics_process(0.05)
	t.check(arrow.position.is_equal_approx(at+Vector3(1,-0.024525,0)) and arrow.velocity.is_equal_approx(Vector3(19.8,-0.485595,0)),"real arrow flight applies gravity then one source drag tick to all axes")
	arrow.life = 120; arrow._physics_process(0)
	t.check(not arrow.is_queued_for_deletion(),"airborne arrow survives the exact 120-second boundary")
	arrow._physics_process(0.0001); t.check(arrow.is_queued_for_deletion(),"airborne arrow expires immediately beyond 120 seconds"); arrow.free()
	for x in [9,10,11]: game.world.set_node(Vector3i(x,1501,8),Nodes.WATER)
	arrow = fresh(game,at,Vector3(40,0,0)); arrow.flame = true; arrow._physics_process(0.025)
	t.check(is_equal_approx(arrow.velocity.x,40*pow(0.74,2)) and not arrow.flame,"completed movement and prediction apply water drag once per newly crossed block and extinguish the arrow")
	var wet_speed: Vector3 = arrow.velocity
	arrow.trace_segment(at,at+Vector3(2.3,0,0),true)
	t.check(arrow.velocity == wet_speed,"recrossing known liquid cells does not repeatedly apply drag")
	arrow.free(); for x in [9,10,11]: game.world.set_node(Vector3i(x,1501,8),Nodes.AIR)
	var wall := Vector3i(12,1501,8); game.world.set_node(wall,Nodes.STONE)
	arrow = fresh(game,at,Vector3(100,0,0)); arrow.critical = true; arrow.piercing = 4; arrow._physics_process(0.05)
	t.check(arrow.stuck and arrow.has_support and arrow.support == wall and arrow.velocity == Vector3.ZERO and not arrow.critical and arrow.piercing == 0,"fast arrow embeds at the first solid hit and clears its flight-only state")
	t.check(arrow.position.x > 12 and arrow.position.x < 12.2,"embedding moves the shaft 0.15 blocks into the impact")
	game.world.set_node(wall,Nodes.WATER); arrow._physics_process(0.25)
	t.check(arrow.stuck,"replacing support with a non-air node retains the embedded arrow, matching source")
	game.world.set_node(wall,Nodes.AIR); arrow._physics_process(0.249)
	t.check(arrow.stuck,"support is checked at the source quarter-second cadence")
	arrow._physics_process(0.001)
	t.check(not arrow.stuck and arrow.life == 0 and arrow.drag_clock == 0,"removing support releases the arrow and resets its lifetime and drag")
	var y: float = arrow.position.y; arrow._physics_process(0.05)
	t.check(arrow.position.y < y,"released embedded arrow falls under gravity"); arrow.free()
	# Burning impacts invoke block actions without wearing the current tool.
	game.world.set_node(wall+Vector3i.DOWN,Nodes.STONE); game.world.set_node(wall,Candles.FIRST)
	game.inventory.slots[0] = {"id":Nodes.BOW,"count":1,"wear":0}; game.inventory.selected = 0
	arrow = fresh(game,Vector3(at.x,1501.25,at.z),Vector3(100,0,0)); arrow.flame = true; arrow._physics_process(0.05)
	t.check(Candles.is_lit(game.world.node_at(wall)) and game.inventory.held().wear == 0,"a burning arrow lights a candle without damaging the held bow")
	arrow.free(); game.world.set_node(wall,Nodes.TNT)
	arrow = fresh(game,at,Vector3(100,0,0)); arrow.flame = true; arrow._physics_process(0.05)
	t.check(game.world.node_at(wall) == Nodes.AIR,"a burning impact primes TNT through the source block callback")
	arrow.free()
	for entity in game.entities.get_children():
		if entity is PrimedTnt: entity.free()
	var cow: Creature = game.spawn_creature("cow",Vector3(10,1500,8.5)); cow.set_physics_process(false); cow.health = 20
	arrow = fresh(game,Vector3(8.5,1500.7,8.5),Vector3(20,0,0)); arrow._physics_process(0.01)
	t.check(cow.health < 20 and arrow.is_queued_for_deletion(),"forward prediction detects a mob before the current physical segment reaches it")
	arrow.free(); cow.health = 20; game.world.set_node(Vector3i(9,1500,8),Nodes.STONE)
	arrow = fresh(game,Vector3(8.5,1500.7,8.5),Vector3(20,0,0)); arrow._physics_process(0.01)
	t.check(cow.health == 20 and not arrow.stuck,"a solid block stops prediction without prematurely embedding or hitting through it")
	arrow.free(); game.world.set_node(Vector3i(9,1500,8),Nodes.AIR); cow.free()
	var enderman: Creature = game.spawn_creature("enderman",Vector3(10,1500,8.5)); enderman.set_physics_process(false)
	var health: float = enderman.health
	arrow = fresh(game,Vector3(8.5,1500.7,8.5),Vector3(60,0,0)); arrow._physics_process(0.05)
	t.check(enderman.health == health and not arrow.is_queued_for_deletion(),"arrows pass through Endermen without applying projectile damage")
	arrow.free(); enderman.free()
	for child in game.drops.get_children(): child.free()
	for i in game.inventory.slots.size(): game.inventory.slots[i] = {"id":Nodes.STONE,"count":64,"wear":0}
	game.player.offhand_slot = {"id":Nodes.STONE,"count":64,"wear":0}
	arrow = fresh(game,game.player.position+Vector3(1.9,0,0),Vector3.ZERO); arrow.stuck = true; arrow.potion_data = {"custom_name":"Keepsake"}
	arrow._physics_process(0.249); t.check(not arrow.is_queued_for_deletion(),"pickup waits for the embedded-arrow recheck")
	arrow._physics_process(0.001)
	t.check(arrow.is_queued_for_deletion() and game.drops.get_child_count() == 1 and game.drops.get_child(0).data.custom_name == "Keepsake","nearby arrow becomes an intact stationary item even when the inventory is full")
	arrow.free(); game.drops.get_child(0).free()
	game.gamemode = "creative"; arrow = fresh(game,game.player.position,Vector3.ZERO); arrow.stuck = true; arrow._physics_process(0.25)
	t.check(arrow.is_queued_for_deletion() and game.drops.get_child_count() == 0,"creative pickup removes the arrow without creating an item")
	arrow.free(); game.gamemode = "survival"
	game.player.health = 20; game.player.damage_cooldown = 0; game.survival.shield_raised = false
	for i in 4: game.player.armor_slots[i] = Bookshelves.empty()
	arrow = fresh(game,game.player.position+Vector3(0,1,-2),Vector3(0,0,20)); arrow.from_player = false
	arrow.hit_player(arrow.position,game.player.position+Vector3.UP)
	t.check(arrow.attached and not arrow.is_queued_for_deletion(),"an ordinary player hit leaves an attached visual arrow")
	arrow._physics_process(30); t.check(not arrow.is_queued_for_deletion(),"attached visual survives its exact 30-second boundary")
	arrow._physics_process(0.001); t.check(arrow.is_queued_for_deletion(),"attached visual expires after thirty seconds"); arrow.free()
	# Save both phases, then stop each restored arrow before it advances.
	game.inventory.restore([]); game.player.offhand_slot = Bookshelves.empty(); game.state = "playing"
	arrow = fresh(game,at,Vector3(15,1,-2)); arrow.life = 7; arrow.drag_clock = 6.95; arrow.damage = 4; arrow.critical = true; arrow.potion_data = {"custom_name":"In flight"}
	var embedded: Arrow = fresh(game,at+Vector3(5,0,0),Vector3(30,0,0)); game.world.set_node(Vector3i(at)+Vector3i(5,0,0),Nodes.STONE)
	embedded.embed(embedded.position,Vector3i(at)+Vector3i(5,0,0),embedded.velocity); embedded.life = 17
	game.save_game(); var saved: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	t.check(saved.arrows.size() == 2 and saved.arrows.any(func(row): return not row.stuck and Vector3(row.velocity[0],row.velocity[1],row.velocity[2]).is_equal_approx(Vector3(15,1,-2))),"save captures flying arrows as well as their embedded phase")
	var stop_arrow: Callable = func(node):
		if node is Arrow: node.ready.connect(func(): node.set_physics_process(false),CONNECT_ONE_SHOT)
	game.entities.child_entered_tree.connect(stop_arrow)
	game.load_world_data(saved); game.set_process(true); game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.entities.child_entered_tree.disconnect(stop_arrow)
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var flying_ok: bool = false; var embedded_ok: bool = false
	for restored in game.entities.get_children():
		if not restored is Arrow: continue
		if not restored.stuck: flying_ok = restored.velocity == Vector3(15,1,-2) and restored.life == 7 and restored.critical and restored.damage == 4 and restored.potion_data.custom_name == "In flight"
		else: embedded_ok = restored.life == 17 and restored.has_support
	t.check(flying_ok and embedded_ok,"actual reload preserves flight velocity, damage, criticals, metadata, age and embedded support")
	game.inventory.slots = old_slots; game.player.position = old_pos; game.gamemode = old_mode; game.player.offhand_slot = old_offhand

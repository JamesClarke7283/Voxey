extends RefCounted

static func run(suite: SceneTree, game: Node3D) -> void:
	game.pause()
	game.gamemode = "survival"
	game.world.active = false
	game.player.position = Vector3(8,55,28)
	for child in game.creatures.get_children(): child.queue_free()
	for child in game.entities.get_children(): child.queue_free()
	for child in game.drops.get_children(): child.queue_free()
	await suite.process_frame
	# A roomy, isolated electronics bench spanning a chunk boundary.
	for x in range(-1,31):
		for z in range(0,29):
			game.world.set_node(Vector3i(x,49,z),Nodes.STONE)
			for y in range(50,54): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	var circuit: RedstoneCircuit = game.world.circuits
	for id in Nodes.EXPANSION_NODES:
		suite.check(id <= 255 and Nodes.exists(id) and Nodes.tile(id,2) < 256,"byte-safe registered expansion node: "+Nodes.title(id))
	for id in [Nodes.REPEATER,Nodes.COMPARATOR,Nodes.PISTON,Nodes.STICKY_PISTON,Nodes.OBSERVER,Nodes.HOPPER,Nodes.DISPENSER,Nodes.ENDER_EYE,Nodes.END_CRYSTAL]:
		var bag := Inventory.new()
		var index: int = bag.recipe_index(id)
		var recipe: Dictionary = bag.recipes[index]
		for ingredient in recipe.ingredients: bag.add_item(ingredient,recipe.ingredients[ingredient])
		suite.check(bag.fill_grid(index,recipe.station) and bag.take_grid_result(recipe.station).id == id,"survival recipe: "+Nodes.title(id))
	suite.check(not Nodes.harvestable(Nodes.REDSTONE_ORE,85) and Nodes.harvestable(Nodes.REDSTONE_ORE,90),"redstone ore requires an iron pickaxe")
	var p := Vector3i(0,50,1)
	game.world.set_node(p,Nodes.LEVER); circuit.interact(p)
	for x in range(1,21): game.world.set_node(p+Vector3i.RIGHT*x,Nodes.REDSTONE_WIRE)
	circuit.step()
	suite.check(circuit.power[p+Vector3i.RIGHT] == 15 and circuit.power[p+Vector3i.RIGHT*15] == 1 and circuit.power[p+Vector3i.RIGHT*16] == 0,"dust attenuates to zero after fifteen blocks across a chunk boundary")
	var repeater := p+Vector3i.RIGHT*16
	game.world.set_node(repeater,Nodes.REPEATER); circuit.configure(repeater,Vector3i.RIGHT)
	circuit.step(); circuit.step()
	suite.check(circuit.output(repeater,Vector3i.RIGHT) == 15 and circuit.power[p+Vector3i.RIGHT*17] == 15,"repeaters restore weak dust to full signal")
	suite.check(circuit.output(repeater,Vector3i.LEFT) == 0,"repeaters only emit forward")
	circuit.interact(p); circuit.step(); circuit.step(); circuit.step()
	suite.check(circuit.power[p+Vector3i.RIGHT] == 0 and circuit.output(repeater,Vector3i.RIGHT) == 0,"turning off a source drains the circuit without self-powering wires")
	circuit.state(repeater)["delay"] = 4
	circuit.interact(p); circuit.step(); circuit.step(); circuit.step()
	suite.check(circuit.output(repeater,Vector3i.RIGHT) == 0,"four-tick repeater waits before switching on")
	circuit.step(); circuit.step()
	suite.check(circuit.output(repeater,Vector3i.RIGHT) == 15,"four-tick repeater eventually switches on")
	# Inverter: a wire powers the torch's supporting block.
	var torch := Vector3i(3,51,5)
	game.world.set_node(torch,Nodes.REDSTONE_TORCH)
	game.world.set_node(torch+Vector3i.DOWN,Nodes.STONE)
	var switch := torch+Vector3i(-1,-1,0)
	game.world.set_node(switch,Nodes.LEVER)
	circuit.step()
	suite.check(circuit.state(torch).out == 15,"unpowered redstone torch is on")
	circuit.interact(switch); circuit.step(); circuit.step()
	suite.check(circuit.state(torch).out == 0,"redstone torch inverts its supporting block's power")
	circuit.interact(switch); circuit.step(); circuit.step()
	suite.check(circuit.state(torch).out == 15,"torch turns back on after its support loses power")
	var button := Vector3i(6,50,5)
	game.world.set_node(button,Nodes.BUTTON); circuit.interact(button); circuit.step()
	suite.check(circuit.state(button).out == 15,"button produces a temporary pulse")
	for i in 12: circuit.step()
	suite.check(circuit.state(button).out == 0,"button pulse expires")
	var plate := Vector3i(9,50,5)
	game.world.set_node(plate,Nodes.PRESSURE_PLATE)
	game.player.position = Vector3(plate)+Vector3(0.5,0.01,0.5); circuit.step()
	suite.check(circuit.state(plate).out == 15,"player standing on a plate powers it")
	game.player.position = Vector3(8,55,28); circuit.step()
	suite.check(circuit.state(plate).out == 0,"pressure plate releases when empty")
	var observer := Vector3i(13,50,5)
	game.world.set_node(observer,Nodes.OBSERVER); circuit.configure(observer,Vector3i.RIGHT)
	game.world.set_node(observer+Vector3i.LEFT,Nodes.DIRT); circuit.step()
	suite.check(circuit.output(observer,Vector3i.RIGHT) == 15 and circuit.output(observer,Vector3i.LEFT) == 0,"observer pulses away from a changed watched block")
	for i in 3: circuit.step()
	suite.check(circuit.output(observer,Vector3i.RIGHT) == 0,"observer pulse stops automatically")
	# Comparator inventory strength and subtraction.
	var chest := Vector3i(1,50,9)
	var comparator := chest+Vector3i.RIGHT
	game.world.set_node(chest,Nodes.CHEST); game.world.set_node(comparator,Nodes.COMPARATOR); circuit.configure(comparator,Vector3i.RIGHT)
	var chest_slots: Array = circuit.container(chest)
	for slot in chest_slots: slot.id = Nodes.COBBLE; slot.count = 64
	circuit.step(); circuit.step()
	suite.check(circuit.container_signal(chest) == 15 and circuit.output(comparator,Vector3i.RIGHT) == 15,"comparator reads a full container at strength fifteen")
	game.world.set_node(comparator+Vector3i.BACK,Nodes.REDSTONE_BLOCK)
	circuit.interact(comparator); circuit.step(); circuit.step()
	suite.check(circuit.output(comparator,Vector3i.RIGHT) == 0,"subtract comparator removes side input from rear input")
	# A regular and sticky piston move exactly the promised blocks.
	var piston := Vector3i(1,50,13)
	game.world.set_node(piston,Nodes.PISTON); circuit.configure(piston,Vector3i.RIGHT)
	for x in range(1,13): game.world.set_node(piston+Vector3i.RIGHT*x,Nodes.DIRT)
	suite.check(circuit.piston(piston,true) and game.world.node_at(piston+Vector3i.RIGHT*13) == Nodes.DIRT and game.world.node_at(piston+Vector3i.RIGHT) == Nodes.PISTON_HEAD,"piston pushes a twelve-block line")
	suite.check(circuit.piston(piston,false) and game.world.node_at(piston+Vector3i.RIGHT) == Nodes.AIR and game.world.node_at(piston+Vector3i.RIGHT*2) == Nodes.DIRT,"regular piston retracts without pulling")
	game.world.set_node(piston+Vector3i.RIGHT,Nodes.DIRT)
	suite.check(not circuit.piston(piston,true) and game.world.node_at(piston+Vector3i.RIGHT*14) == Nodes.AIR,"piston refuses a thirteenth block atomically")
	var sticky := Vector3i(18,50,13)
	game.world.set_node(sticky,Nodes.STICKY_PISTON); circuit.configure(sticky,Vector3i.RIGHT)
	game.world.set_node(sticky+Vector3i.RIGHT,Nodes.GLASS)
	suite.check(circuit.piston(sticky,true),"sticky piston extends")
	suite.check(circuit.piston(sticky,false) and game.world.node_at(sticky+Vector3i.RIGHT) == Nodes.GLASS and game.world.node_at(sticky+Vector3i.RIGHT*2) == Nodes.AIR,"sticky piston pulls one block back")
	game.world.set_node(sticky+Vector3i.RIGHT,Nodes.OBSIDIAN)
	suite.check(not circuit.piston(sticky,true),"obsidian is immovable")
	game.world.set_node(sticky+Vector3i.RIGHT,Nodes.CHEST)
	suite.check(not circuit.piston(sticky,true),"containers cannot be pushed or lose their contents")
	var vertical := Vector3i(25,50,13)
	game.world.set_node(vertical,Nodes.PISTON); circuit.configure(vertical,Vector3i.UP)
	game.world.set_node(vertical+Vector3i.UP,Nodes.DIRT)
	suite.check(circuit.piston(vertical,true) and game.world.node_at(vertical+Vector3i.UP*2) == Nodes.DIRT,"pistons also push vertically")
	# Containers preserve counts, durability and enchantment metadata.
	var hopper := Vector3i(1,50,18)
	game.world.set_node(hopper,Nodes.HOPPER); circuit.configure(hopper,Vector3i.RIGHT)
	game.world.set_node(hopper+Vector3i.RIGHT,Nodes.CHEST)
	var hslots: Array = circuit.container(hopper)
	hslots[0] = {"id":Nodes.BOW,"count":1,"wear":12,"data":{"enchantments":{"Power":2}}}
	circuit.hopper(hopper)
	var target_slots: Array = circuit.container(hopper+Vector3i.RIGHT)
	suite.check(hslots[0].id == 0 and target_slots[0].wear == 12 and Inventory.enchantment(target_slots[0],"Power") == 2,"hopper transfers one item with wear and enchantments intact")
	for slot in target_slots: slot.id = Nodes.STONE; slot.count = 64; slot.wear = 0; slot.erase("data")
	hslots[0] = {"id":Nodes.DIAMOND,"count":2,"wear":0}; circuit.hopper(hopper)
	suite.check(hslots[0].count == 2,"hopper leaves items in place when destination inventory is full")
	var dispenser := Vector3i(5,50,18)
	game.world.set_node(dispenser,Nodes.DISPENSER); circuit.configure(dispenser,Vector3i.RIGHT)
	var dslots: Array = circuit.container(dispenser); dslots[0] = {"id":Nodes.ARROW_ITEM,"count":2,"wear":0}
	circuit.dispense(dispenser,true)
	var shot: Arrow = game.entities.get_children().back()
	suite.check(shot.velocity.x == 24 and shot.from_player and shot.hits_player and dslots[0].count == 1,"dispenser fires one forward arrow per pulse")
	shot.queue_free()
	# Short pulses, side locks and powered machinery use the same tick loop.
	var pulse_switch := Vector3i(20,50,5)
	var pulse_rep := pulse_switch+Vector3i.RIGHT
	game.world.set_node(pulse_switch,Nodes.LEVER)
	game.world.set_node(pulse_rep,Nodes.REPEATER); circuit.configure(pulse_rep,Vector3i.RIGHT); circuit.state(pulse_rep)["delay"] = 4
	circuit.interact(pulse_switch); circuit.step(); circuit.step()
	circuit.interact(pulse_switch)
	var pulse_ticks: int = 0
	for i in 12:
		circuit.step()
		if circuit.state(pulse_rep).out > 0: pulse_ticks += 1
	suite.check(pulse_ticks >= 4 and circuit.state(pulse_rep).out == 0,"repeater preserves and stretches a short pulse instead of swallowing it")
	var locked_rep := Vector3i(19,50,9)
	game.world.set_node(locked_rep,Nodes.REPEATER); circuit.configure(locked_rep,Vector3i.RIGHT)
	game.world.set_node(locked_rep+Vector3i.BACK,Nodes.REPEATER); circuit.configure(locked_rep+Vector3i.BACK,Vector3i.FORWARD)
	game.world.set_node(locked_rep+Vector3i.BACK*2,Nodes.REDSTONE_BLOCK)
	for i in 3: circuit.step()
	game.world.set_node(locked_rep+Vector3i.LEFT,Nodes.REDSTONE_BLOCK)
	for i in 3: circuit.step()
	suite.check(circuit.state(locked_rep).get("locked",false) and circuit.state(locked_rep).out == 0,"side repeater locks a repeater's existing output")
	game.world.set_node(locked_rep+Vector3i.BACK*2,Nodes.AIR)
	for i in 5: circuit.step()
	suite.check(circuit.state(locked_rep).out == 15,"unlocked repeater resumes following rear input")
	var door := Vector3i(10,50,18)
	game.world.set_node(door,Nodes.IRON_DOOR); game.world.set_node(door+Vector3i.UP,Nodes.IRON_DOOR); circuit.state(door+Vector3i.UP)["upper"] = true
	game.world.set_node(door+Vector3i.LEFT,Nodes.REDSTONE_BLOCK); circuit.step()
	suite.check(game.world.node_at(door) == Nodes.IRON_DOOR_OPEN and game.world.node_at(door+Vector3i.UP) == Nodes.IRON_DOOR_OPEN,"redstone opens both door halves")
	game.world.set_node(door+Vector3i.LEFT,Nodes.AIR); circuit.step()
	suite.check(game.world.node_at(door) == Nodes.IRON_DOOR and Nodes.solid(Nodes.IRON_DOOR),"unpowered iron door closes and blocks movement")
	dslots[0] = {"id":Nodes.ARROW_ITEM,"count":2,"wear":0}
	game.world.set_node(dispenser+Vector3i.BACK,Nodes.REDSTONE_BLOCK)
	for i in 5: circuit.step()
	suite.check(dslots[0].count == 1,"constant power triggers a dispenser once, not every tick")
	# Ore and structures are deterministic and actually appear in generated columns.
	var gen := TerrainGenerator.new(game.world.seed_value)
	var center := WorldStructures.nearest_stronghold(game.world.seed_value,Vector3.ZERO)
	var data: Dictionary = gen.generate_column(Vector2i(floori(center.x/16.0),floori(center.z/16.0)),{})
	var frames: int = 0
	for block in data.blocks: frames += block.data.count(Nodes.END_FRAME)
	suite.check(frames > 0 and center == WorldStructures.nearest_stronghold(game.world.seed_value,Vector3.ZERO),"seeded stronghold generates real portal frames below ground")
	var portal_center := Vector3i(22,50,21)
	var ring: Array = WorldStructures.frame_positions(portal_center)
	for frame in ring: game.world.set_node(frame,Nodes.END_FRAME)
	for i in 11: WorldStructures.fill_eye(game.world,ring[i])
	suite.check(game.world.node_at(portal_center) == Nodes.AIR,"eleven Eyes do not activate a portal")
	WorldStructures.fill_eye(game.world,ring[11])
	suite.check(game.world.node_at(portal_center) == Nodes.END_PORTAL and not Nodes.solid(Nodes.END_PORTAL),"twelfth Eye activates a traversable End portal")
	var pearl: MagicProjectile = game.adventure.projectile("pearl",Vector3(10.5,52,23.5),Vector3(0,-20,0),game.player)
	pearl.set_physics_process(false)
	game.player.position = Vector3(4.5,50.01,23.5); game.player.health = 20; game.player.damage_cooldown = 0
	pearl.impact(Vector3(10.5,49.98,23.5))
	suite.check(game.player.position.distance_to(Vector3(10.5,50.01,23.5)) < 0.1 and game.player.health < 20,"pearl impact teleports to a clear landing and applies survival damage")
	game.inventory.selected = 0; game.inventory.slots[0] = {"id":Nodes.ENDER_EYE,"count":2,"wear":0}
	game.adventure.throw_item(Nodes.ENDER_EYE)
	var eye: MagicProjectile = game.entities.get_children().back()
	var stronghold := WorldStructures.nearest_stronghold(game.world.seed_value,game.player.position)
	suite.check((eye.target-eye.position).dot(Vector3(stronghold)-eye.position) > 0 and game.inventory.slots[0].count == 1,"throwing an Eye consumes one and flies toward the stronghold")
	eye.queue_free()
	for kind in ["ghast","blaze","enderman","ender_dragon","end_crystal","slime","shulker"]:
		var mob: Creature = game.spawn_creature(kind,Vector3(14,50,25)); mob.set_physics_process(false)
		suite.check(mob.parts.size() >= 3 and mob.health == Creature.KINDS[kind].health,"recognizable procedural model and stats: "+kind)
		mob.queue_free()
	var fireball: MagicProjectile = game.adventure.projectile("ghast",Vector3(0,52,25),Vector3.RIGHT*10)
	fireball.deflect(Vector3.LEFT)
	suite.check(fireball.from_player and fireball.velocity.x == -22,"ghast fireballs can be deflected")
	fireball.queue_free()
	# Save both normal and machine state, then travel through every dimension.
	circuit.state(repeater)["delay"] = 4
	game.save_game("user://expansion-check.json")
	var saved: Dictionary = game.read_save("user://expansion-check.json")
	suite.check(saved.block_states[VoxelWorld.station_key(repeater)].delay == 4 and saved.stations.has(VoxelWorld.station_key(hopper)),"world save contains circuit settings and machine inventory")
	game.touch = true; game.gamemode = "creative"
	game.travel_dimension("nether")
	while game.state == "loading": await suite.process_frame
	game.pause(); game.world.active = false
	game.teleport(Vector3(64.5,29.01,60.5))
	while game.state == "loading": await suite.process_frame
	game.pause(); game.world.active = false
	suite.check(game.world.node_at(Vector3i(60,29,60)) == Nodes.BLAZE_SPAWNER,"Nether fortress generates a blaze spawner")
	game.adventure.fortress_spawn()
	var blaze_found: bool = false
	for mob in game.creatures.get_children(): blaze_found = blaze_found or mob.kind == "blaze"
	suite.check(blaze_found,"fortress spawner produces a blaze for the Eye crafting chain")
	game.travel_dimension("end")
	while game.state == "loading": await suite.process_frame
	game.pause(); game.world.active = false
	suite.check(game.dimension == "end" and game.world.node_at(Vector3i(51,44,0)) == Nodes.OBSIDIAN,"End arrival builds a safe obsidian platform")
	suite.check(game.world.node_at(Vector3i(51,-1,0)) == Nodes.AIR,"End void remains open below the world")
	# Stream the central island and all ten towers for the encounter.
	game.player.position = Vector3(0,54,0); game.world.target = game.player.position; game.world.radius = 3
	for i in 1000:
		if game.world.columns.size() >= 49 and game.world.area_ready(Vector3.ZERO): break
		await suite.process_frame
	game.adventure.ensure_end()
	var crystals: Array = []; var dragon: Creature
	for mob in game.creatures.get_children():
		mob.set_physics_process(false)
		if mob.kind == "end_crystal": crystals.append(mob)
		if mob.kind == "ender_dragon": dragon = mob
	suite.check(crystals.size() == 10 and dragon != null,"End encounter contains ten tower crystals and the dragon")
	if dragon != null and not crystals.is_empty():
		dragon.health = 100; dragon.position = crystals[0].position+Vector3(4,1,0); dragon._dragon(0.1)
		suite.check(dragon.health > 100 and dragon.beam_target != null,"nearby crystals heal the dragon and create a beam")
		var crystal: Creature = crystals[0]
		var key: String = crystal.crystal_key
		var arrow: Arrow = game.spawn_arrow(crystal.center()+Vector3(0,0,-2),Vector3.BACK*30)
		arrow.from_player = true; arrow.set_physics_process(false)
		game.state = "playing"; arrow._physics_process(0.08); game.state = "paused"
		suite.check(crystal.is_queued_for_deletion() and key in game.world.adventure_state.destroyed_crystals,"bow arrow destroys a tower crystal and records it")
		dragon.health = 72; game.world.adventure_state["dragon_health"] = 72
		game.save_game("user://expansion-check.json")
		var end_save: Dictionary = game.read_save("user://expansion-check.json")
		game.load_world_data(end_save)
		while game.state == "loading": await suite.process_frame
		game.pause(); game.world.active = false; game.adventure.ensure_end()
		suite.check(key in game.world.adventure_state.destroyed_crystals and int(game.world.adventure_state.dragon_health) == 72,"End save reload preserves destroyed crystals and dragon health")
		game.adventure.dragon_defeated()
		suite.check(game.world.adventure_state.defeated and game.world.node_at(Vector3i(1,45,0)) == Nodes.END_PORTAL and game.world.node_at(Vector3i(0,49,0)) == Nodes.DRAGON_EGG,"dragon victory awards egg and opens the return portal")
		for base in [Vector3i(3,44,0),Vector3i(-3,44,0),Vector3i(0,44,3),Vector3i(0,44,-3)]: game.adventure.place_crystal(base)
		suite.check(not game.world.adventure_state.defeated and game.world.adventure_state.destroyed_crystals.is_empty(),"four exit-fountain crystals respawn the dragon and restore towers")
	suite.check(game.world.edits.get(Vector3i(50,45,4)) == Nodes.END_GATEWAY,"dragon victory opens a gateway to the outer islands")
	# Outer islands offer a guarded city and wearable gliding equipment.
	game.portal_cooldown = 0; game.player.position = Vector3(50.5,45.01,4.5); game.adventure.enter_gateway()
	while game.state == "loading": await suite.process_frame
	game.pause(); game.world.active = false
	game.adventure.open_gateways(); game.adventure.city_guards()
	suite.check(game.player.position.x > 200 and game.world.node_at(Vector3i(280,43,0)) == Nodes.END_GATEWAY,"gateway streams a safe arrival and matching return gate")
	var guards: int = 0
	for mob in game.creatures.get_children():
		mob.set_physics_process(false)
		if mob.kind == "shulker": guards += 1
	suite.check(guards == 2 and game.world.node_at(Vector3i(288,49,0)) == Nodes.PURPUR,"outer End city generates floors and two shulker guards")
	suite.check(game.world.node_at(Vector3i(285,49,-3)) == Nodes.LADDER and game.world.node_at(Vector3i(285,57,-3)) == Nodes.LADDER,"city ladder passes through both floors to reach the treasure")
	var loot: Array = game.world.get_station(Vector3i(291,58,3),"chest").slots
	suite.check(loot[0].id == Nodes.ELYTRA,"End city treasure contains elytra")
	game.player.armor_slots[1] = {"id":Nodes.ELYTRA,"count":1,"wear":0}
	game.player.grounded = false; game.player.velocity = Vector3(0,-12,0); game.player.camera.rotation.x = 0
	suite.check(game.player.update_glide(0.2,true) and game.player.velocity.y > -12 and game.player.velocity.length() > 2,"equipped elytra turn a fall into forward gliding")
	game.player.position = Vector3(288.5,80,0.5); game.player.gliding = true; game.player.velocity = Vector3(0,-3,-12)
	game.state = "playing"
	for i in 60: game.player._physics_process(1.0/60.0)
	game.state = "paused"
	suite.check(Vector2(game.player.velocity.x,game.player.velocity.z).length() > 10 and game.player.velocity.y > -4,"gliding physics keeps forward speed without walk friction or full gravity")
	game.player.armor_slots[1].wear = 432
	suite.check(not game.player.update_glide(0.2,true),"worn-out elytra cannot glide")
	game.player.armor_slots[1] = {"id":0,"count":0,"wear":0}
	var bullet: MagicProjectile = game.adventure.projectile("shulker",game.player.position+Vector3.UP,Vector3.ZERO)
	bullet.set_physics_process(false)
	game.state = "playing"; bullet._physics_process(0.01); game.state = "paused"
	suite.check(game.player.levitation > 0,"shulker projectile applies levitation on impact")
	game.player.gliding = false; game.player.velocity = Vector3.ZERO
	var initial_y: float = game.player.position.y
	game.state = "playing"
	for i in 60: game.player._physics_process(1.0/60.0)
	game.state = "paused"
	suite.check(game.player.position.y > initial_y+1 and game.player.velocity.y > 2.9,"levitation physics rises instead of fighting ordinary gravity")
	game.player.levitation = 0
	game.travel_dimension("overworld",true)
	while game.state == "loading": await suite.process_frame
	game.pause(); game.world.active = false
	suite.check(game.dimension == "overworld" and int(game.world.circuits.state(repeater).delay) == 4,"returning from the End restores Overworld circuit state")
	for path in ["user://expansion-check.json","user://expansion-check.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

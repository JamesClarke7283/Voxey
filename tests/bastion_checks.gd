extends RefCounted
static func run(suite: SceneTree, game: Node3D) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 1942
	var templates: int = 0; var valid: bool = true
	for i in 1000:
		var station: Dictionary = VoxelWorld._new_station("chest",27)
		Bastions.fill(station,i)
		var stacks: int = 0
		for slot in station.slots:
			if slot.id == 0: continue
			stacks += 1
			if not Nodes.exists(slot.id) or slot.count > Nodes.max_stack(slot.id): valid = false
			if slot.id == Netherite.TEMPLATE: templates += 1
		if stacks < 4 or stacks > 7: valid = false
	suite.check(valid and templates > 100 and templates < 350,"bastion loot groups generate valid survival loot with source template rarity")
	var barter_types: Dictionary = {}; var soul_speed: bool = false
	for i in 4000:
		var reward: Dictionary = PiglinBarter.reward(rng)
		if not Nodes.exists(reward.id): valid = false
		barter_types[reward.id] = true
		if reward.has("data"): soul_speed = soul_speed or Inventory.enchantment(reward,"Soul Speed") in [1,2,3]
	suite.check(valid and barter_types.size() == 18 and soul_speed,"all eighteen source barter results are reachable, including Soul Speed books and boots")
	for tool in 5:
		suite.check(Nodes.durability(Bastions.GOLD_TOOLS+tool) == 33 and Nodes.tool_tier(Bastions.GOLD_TOOLS+tool) == 0,"gold tool %d has source durability and harvest tier"%tool)
	var gen := TerrainGenerator.new(game.world.seed_value,"nether")
	var site: Dictionary = Bastions.nearest(gen,Vector3.ZERO)
	suite.check(not site.is_empty() and site == Bastions.nearest(gen,Vector3.ZERO),"bastion locator selects a deterministic generated site")
	var center: Vector3i = site.center
	var chest_pos: Vector3i = center+Bastions.CHESTS[0]
	var coord := Vector2i(floori(chest_pos.x/16.0),floori(chest_pos.z/16.0))
	var column: Dictionary = gen.generate_column(coord,{})
	var chest_found: bool = false
	for block in column.blocks:
		if block.y == floori(chest_pos.y/16.0): chest_found = block.data[VoxelWorld.local_index(chest_pos)] == Nodes.CHEST
	suite.check(chest_found,"bastion treasure chest is present in generated terrain")
	var arrival: Vector3 = Vector3(center)+Vector3(0.5,1.01,7.5)
	game.player_homes[game.player_id] = {"dimension":"nether","position":[arrival.x,arrival.y,arrival.z],"yaw":0,"pitch":0}
	game.teleport_home()
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec()<deadline: await suite.process_frame
	game.pause(); game.gamemode = "creative"
	suite.check(game.dimension == "nether" and game.world.node_at(chest_pos) == Nodes.CHEST,"bastion travel streams the actual structure")
	var storage: Dictionary = game.world.get_station(chest_pos,"chest")
	var before: Array = storage.slots.duplicate(true)
	game.world._structure_loot(chest_pos)
	suite.check(storage.label == "Bastion treasure" and storage.slots == before,"generated bastion chests receive loot once without restocking on access")
	Bastions.populate(game)
	var piglin: NetherResident; var brute: NetherResident; var inhabitants: int = 0
	for mob in game.creatures.get_children():
		if mob is NetherResident and not mob.is_queued_for_deletion() and mob.resident_key.begins_with(site.key):
			mob.set_physics_process(false); inhabitants += 1
			if mob.kind == "piglin_brute": brute = mob
			else: piglin = mob
	suite.check(inhabitants == 4 and brute != null and brute.health == 50,"bastion is guarded by three piglins and a source-health brute")
	if piglin == null or brute == null: return
	game.gamemode = "survival"; game.player.health = 20; game.player.damage_cooldown = 0
	for i in 4: game.player.armor_slots[i] = {"id":0,"count":0,"wear":0}
	suite.check(piglin.aggressive(),"unprovoked piglin attacks a player without gold armor")
	game.player.armor_slots[0] = {"id":Nodes.armor_id(2,0),"count":1,"wear":0}
	suite.check(not piglin.aggressive() and brute.aggressive(),"gold armor pacifies piglins but does not pacify brutes")
	game.inventory.slots[0] = {"id":Nodes.GOLD,"count":2,"wear":0}; game.inventory.selected = 0
	suite.check(piglin.barter() and piglin.barter_time == 6 and game.inventory.slots[0].count == 1,"piglin accepts exactly one gold ingot and admires it for six seconds")
	suite.check(not piglin.barter() and game.inventory.slots[0].count == 1 and not brute.barter(),"busy piglins and brutes reject extra payment")
	var drops_before: int = game.drops.get_child_count()
	game.state = "playing"; piglin._physics_process(3); game.state = "paused"
	suite.check(game.drops.get_child_count() == drops_before and piglin.record().barter_time == 3,"unfinished barter persists without awarding an early reward")
	game.state = "playing"; piglin._physics_process(3); game.state = "paused"
	suite.check(game.drops.get_child_count() == drops_before+1 and piglin.barter_count == 1,"finished barter drops a reward in the world regardless of player capacity")
	var brute_key: String = brute.resident_key
	brute.die()
	suite.check(game.world.adventure_state.nether_residents[brute_key].dead,"killing a bastion brute marks its persistent record dead")
	Bastions.populate(game)
	var live_brutes: int = 0
	for mob in game.creatures.get_children():
		if mob is NetherResident and mob.resident_key == brute_key and not mob.is_queued_for_deletion(): live_brutes += 1
	suite.check(live_brutes == 0,"revisiting a cleared bastion does not respawn its slain brute")
	suite.check(game.save_game("user://bastion_check.json"),"bastion residents and looted containers save")
	var saved: Dictionary = game.read_save("user://bastion_check.json")
	suite.check(saved.adventure.nether_residents[brute_key].dead and saved.adventure.nether_residents[piglin.resident_key].barter_count == 1,"save data keeps resident deaths and completed barter history")
	for path in ["user://bastion_check.json","user://bastion_check.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

extends SceneTree
var passed: int = 0
var failed: int = 0
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR",OS.get_cache_dir().path_join("voxey-parity-"+str(OS.get_process_id())))
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	if condition: passed += 1; print("PASS  "+message)
	else: failed += 1; push_error("FAIL  "+message)
func run() -> void:
	var gen := TerrainGenerator.new(8675309)
	check(gen.min_y() == -128 and gen.max_y() == 30928,"Overworld source bounds are inclusive -128 through 30927")
	check(TerrainGenerator.new(1,"nether").max_y() == 257 and TerrainGenerator.new(1,"end").max_y() == 24946,"separate Nether and End realms retain source height ranges")
	check(WorldBounds.horizontal(Vector3i(-30912,0,30927)) and not WorldBounds.horizontal(Vector3i(-30913,0,0)) and not WorldBounds.horizontal(Vector3i(0,0,30928)),"source horizontal map limits are enforced")
	var high := Vector3i(8,30900,8)
	var generated: Dictionary = gen.generate_column(Vector2i.ZERO,{high:Nodes.GLASS})
	check(generated.blocks.size() == 13,"a ceiling build allocates only its occupied block plus twelve natural blocks")
	var found: bool = false
	for block in generated.blocks:
		if block.y == 1931: found = block.data[VoxelWorld.local_index(high)] == Nodes.GLASS
	check(found,"saved high-altitude edits are generated at their original coordinates")
	var first: Array = MinecloniaOres.placements(gen,Vector2i.ZERO)
	var second: Array = MinecloniaOres.placements(gen,Vector2i.RIGHT)
	var overlap_a: Array = []; var overlap_b: Array = []
	for value in first:
		if value.pos.x in [15,16]: overlap_a.append(value)
	for value in second:
		if value.pos.x in [15,16]: overlap_b.append(value)
	check(not overlap_a.is_empty() and overlap_a == overlap_b,"adjacent columns agree on ore identities throughout the shared halo")
	check(first == MinecloniaOres.placements(gen,Vector2i.ZERO),"ore placement is reproducible regardless of generation order")
	check(MinecloniaOreRules.DATA.size() == 100,"source export retains all 100 mineral scatter rules")
	var debris_rules: Array = []
	for rule in MinecloniaOreRules.DATA:
		if rule.id == Netherite.ANCIENT_DEBRIS: debris_rules.append([rule.min,rule.max,rule.scarcity,rule.count,rule.size])
	check(debris_rules.has([8,22,15000,3,3]) and debris_rules.has([0,8,32000,2,3]) and debris_rules.has([22,119,32000,2,3]),"ancient debris uses all three source rarity and depth bands")
	check(Nodes.smelt_result(Netherite.ANCIENT_DEBRIS) == Netherite.SCRAP and Nodes.smelt_result(MinecloniaOres.NETHER_GOLD) == Nodes.GOLD,"debris and Nether gold ore smelt to the correct materials")
	check(not Nodes.harvestable(Netherite.ANCIENT_DEBRIS,90) and Nodes.harvestable(Netherite.ANCIENT_DEBRIS,95),"ancient debris requires a diamond pickaxe or better")
	var inv := Inventory.new(); inv.add_item(Netherite.SCRAP,4); inv.add_item(Nodes.GOLD,4)
	check(inv.craft(inv.recipe_index(Netherite.INGOT),"table") and inv.count_item(Netherite.INGOT) == 1 and inv.count_item(Netherite.SCRAP) == 0,"four scrap and four gold craft one Netherite ingot")
	inv = Inventory.new(); inv.add_item(Netherite.TEMPLATE,1); inv.add_item(Nodes.DIAMOND,7); inv.add_item(Nodes.NETHERRACK,1)
	check(inv.craft(inv.recipe_index(Netherite.TEMPLATE),"table") and inv.count_item(Netherite.TEMPLATE) == 2,"template duplication consumes seven diamonds and netherrack")
	inv = Inventory.new()
	inv.slots[0] = {"id":95,"count":1,"wear":781,"data":{"custom_name":"Old friend","enchantments":{"Efficiency":5,"Mending":1}}}
	var original: Dictionary = inv.slots[0].duplicate(true)
	check(not Netherite.upgrade(inv,0) and inv.slots[0] == original,"smithing failure leaves equipment and ingredients untouched")
	inv.add_item(Netherite.INGOT,1); inv.add_item(Netherite.TEMPLATE,1)
	check(Netherite.upgrade(inv,0) and inv.slots[0].id == Netherite.TOOLS and inv.slots[0].data == original.data,"smithing upgrades the diamond tool while preserving all metadata")
	check(inv.slots[0].wear == 1016 and inv.count_item(Netherite.INGOT) == 0 and inv.count_item(Netherite.TEMPLATE) == 0,"smithing retains normalized wear and consumes each ingredient once")
	check(Nodes.durability(Netherite.TOOLS) == 2031 and Nodes.break_time(Nodes.STONE,Netherite.TOOLS) < Nodes.break_time(Nodes.STONE,95),"Netherite pickaxe has source durability and mining speed")
	for piece in 4:
		check(Nodes.armor_id(4,piece) == Netherite.ARMOR+piece and Nodes.durability(Netherite.ARMOR+piece) == [381,556,521,451][piece] and Nodes.armor_toughness(Netherite.ARMOR+piece) == 3,"Netherite armor piece %d retains source defense statistics"%piece)
	var legacy: Dictionary = {"inventory":[{"id":Nodes.armor_id(3,0),"count":1,"wear":264}],"chest":{"id":74,"count":1,"wear":120}}
	Netherite.migrate_wear(legacy)
	check(legacy.inventory[0].wear == 182 and legacy.chest.wear == 121,"legacy armor migration preserves wear fraction in nested storage and old chestplate IDs")
	var identity := PlayerIdentity.new("/tmp/nonexistent-voxey-identity")
	identity.legacy_offline_id = "old-selected"
	var migrated: Dictionary = {"homes":{"old-selected":{"position":[1,2,3]},"another":{"position":[4,5,6]}},"dimensions":{"nether":{"reputations":{"old-selected":7,"another":-2},"chest":{"owner":"old-selected","label":"Recovery chest · Previous name"}}}}
	identity.migrate_save(migrated)
	check(identity.session_id == "player" and migrated.homes.player.position == [1,2,3] and migrated.homes.another.position == [4,5,6],"offline identity migration preserves the active home and other identities")
	check(migrated.dimensions.nether.reputations.player == 7 and migrated.dimensions.nether.chest.owner == "player","identity migration preserves reputation and recovery ownership across dimensions")
	migrated.homes.player.position = [7,8,9]; identity.migrate_save(migrated)
	check(migrated.homes.player.position == [7,8,9],"repeated migration cannot overwrite a newly set offline home")
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.touch = true; game.audio_enabled = false; game.world.radius = 2
	game.start_new("8675309","Parity checks","creative")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec()<deadline: await process_frame
	check(game.state == "playing","source-generation world finishes loading")
	game.pause()
	check(game.world.node_at(high) == Nodes.AIR and game.world.set_node(high,Nodes.GLASS),"implicit upper air accepts a placed block without filling the empty altitude range")
	check(game.world.node_at(high) == Nodes.GLASS and not game.world.open_sky(high-Vector3i.UP*2),"ceiling builds collide and block sunlight")
	game.world.set_node(high,Nodes.AIR)
	check(game.world.open_sky(high-Vector3i.UP*2),"removing the high block restores open sky")
	game.world.set_node(high,Nodes.CHEST)
	game.world.get_station(high,"chest").slots[0] = {"id":Netherite.TOOLS,"count":1,"wear":77,"data":original.data}
	check(not game.world.set_node(Vector3i(8,30928,8),Nodes.STONE),"building cannot exceed the source ceiling")
	check(game.save_game("user://parity_check.json"),"high-altitude storage saves")
	game.load_world_data(game.read_save("user://parity_check.json"))
	deadline = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec()<deadline: await process_frame
	game.pause()
	check(game.world.node_at(high) == Nodes.CHEST and game.world.get_station(high,"chest").slots[0].data == original.data,"high-altitude chest and enchanted Netherite survive a save reload")
	var lava := Vector3i(8,50,8); game.world.set_node(lava,Nodes.LAVA)
	game.player.position = Vector3(8,40,8)
	var ordinary: ItemDrop = game.spawn_drop(Vector3(lava)+Vector3.ONE*0.5,Nodes.DIAMOND,1)
	var resistant: ItemDrop = game.spawn_drop(Vector3(lava)+Vector3.ONE*0.5,Netherite.INGOT,1)
	ordinary.age = 3; resistant.age = 3
	game.state = "playing"; ordinary._physics_process(0.01); resistant._physics_process(0.01); game.state = "paused"
	check(ordinary.is_queued_for_deletion() and not resistant.is_queued_for_deletion(),"lava burns ordinary dropped items while preserving Netherite")
	game.gamemode = "survival"; game.player.health = 20; game.player.damage_cooldown = 0
	for piece in 4: game.player.armor_slots[piece] = {"id":Netherite.ARMOR+piece,"count":1,"wear":0}
	game.player.hurt(20)
	check(is_equal_approx(game.player.health,12.8) and game.player.armor_slots[1].wear == 5,"full Netherite uses source toughness and damage-based armor wear")
	await load("res://tests/bastion_checks.gd").run(self,game)
	await load("res://tests/fire_lodestone_checks.gd").run(self,game)
	print("PARITY TESTS: %d passed, %d failed"%[passed,failed])
	game.queue_free()
	for i in 4: await process_frame
	for path in ["user://parity_check.json","user://parity_check.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit(1 if failed else 0)

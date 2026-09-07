extends SceneTree
var passed: int = 0
var failed: int = 0
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-polish-tests-"+str(OS.get_process_id()))
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	if condition: passed += 1; print("PASS  "+message)
	else: failed += 1; push_error("FAIL  "+message)
func empty() -> Dictionary: return {"id":0,"count":0,"wear":0}
func run() -> void:
	var inv := Inventory.new()
	inv.selected = 4
	var meta: Dictionary = {"custom_name":"Faithful","enchantments":{"Efficiency":3}}
	inv.slots[4] = {"id":95,"count":1,"wear":Nodes.durability(95)-1,"data":meta.duplicate(true)}
	inv.slots[0] = {"id":90,"count":1,"wear":0,"data":meta.duplicate(true)}
	inv.slots[9] = {"id":95,"count":1,"wear":0}
	inv.slots[10] = {"id":95,"count":1,"wear":100,"data":meta.duplicate(true)}
	check(inv.damage_tool() and inv.selected == 4 and inv.slots[4].wear == 100 and inv.slots[4].data == meta and inv.slots[10].id == 0,"broken tool replaces the same hotbar slot with a matching tool and preserves wear")
	inv.slots[4].wear = Nodes.durability(95)-1
	check(inv.damage_tool() and inv.slots[4].id == 0 and inv.slots[9].id == 95 and inv.slots[0].id == 90,"replacement rejects different tiers and metadata")
	inv.restore([], [{"id":Pouches.SINGLE,"count":1,"wear":0}])
	inv.selected = 3
	inv.slots[3] = {"id":80,"count":1,"wear":59}
	inv.slots[Inventory.BASE_SLOTS] = {"id":80,"count":1,"wear":12}
	check(inv.damage_tool() and inv.slots[3].wear == 12 and inv.pouch_slots[0].data.contents[0].id == 0,"automatic replacement removes the spare from its owning pouch")
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Performance and polish checks","creative")
	while game.state == "loading": await process_frame
	game.pause(); game.world.set_process(false)
	for coord in [Vector3i.ZERO,Vector3i(-1,-8,-1),Vector3i(0,3,0),Vector3i(0,1931,0)]:
		var snapshot: PackedInt32Array = game.world._snapshot(coord)
		var same: bool = true
		for y in 18:
			for z in 18:
				for x in 18:
					var p: Vector3i = coord*16+Vector3i(x-1,y-1,z-1)
					var expected: int = game.world.node_at(p)
					if p.y > game.world.generator.min_y() and expected == Nodes.BEDROCK and not game.world.blocks.has(VoxelWorld.block_coord(p)): expected = Nodes.AIR
					if snapshot[x+z*18+y*324] != expected: same = false
		check(same,"fast remesh snapshot matches voxel queries at "+str(coord))
	game.player.position = Vector3(8,-30,8)
	var lighting: Array = []
	for time in [0.3,0.49,0.7]:
		game.day_time = time; game._update_day()
		var env: Environment = game.environment.environment
		lighting.append([game.sunlight.light_energy,env.ambient_light_energy,env.ambient_light_color,env.ambient_light_sky_contribution,env.fog_light_color,env.reflected_light_source])
	check(lighting[0] == lighting[1] and lighting[1] == lighting[2],"underground terrain lighting is identical at noon, dusk and night")
	game.player.position = Vector3(8,60,8); game.day_time = 0.3; game._update_day()
	check(game.sunlight.light_energy > 0 and game.environment.environment.ambient_light_sky_contribution == 1.0,"returning to the surface restores sunlight")
	var furnace: Dictionary = VoxelWorld._new_station("furnace",3)
	furnace.slots[2] = {"id":Nodes.IRON,"count":1,"wear":0}
	game.hud.show_inventory("furnace",furnace)
	game.hud.cursor = {"id":Nodes.IRON_ORE,"count":10,"wear":0}
	for right in [false,true]:
		game.hud._slot_click(0,true,right)
		check(furnace.slots[0].id == 0 and game.hud.cursor.count == 10,"furnace rejects cursor input while output is occupied (right=%s)"%right)
	furnace.slots[0] = {"id":Nodes.RAW_MEAT,"count":1,"wear":0}
	game.hud._slot_click(0,true,false)
	check(furnace.slots[0].id == Nodes.RAW_MEAT and game.hud.cursor.id == Nodes.IRON_ORE,"furnace rejects swapping input while output is occupied")
	furnace.slots[0] = empty(); game.hud.cursor = empty(); game.inventory.restore([])
	game.inventory.slots[9] = {"id":Nodes.IRON_ORE,"count":10,"wear":0}
	game.hud.shift_mode = true; game.hud._slot_click(9,false,false); game.hud.shift_mode = false
	check(furnace.slots[0].id == 0 and game.inventory.slots[9].count == 10,"furnace rejects shift insertion without losing the source stack")
	game.hud.cursor = {"id":Nodes.COAL,"count":1,"wear":0}; game.hud._slot_click(1,true,false)
	check(furnace.slots[1].id == Nodes.COAL,"fuel remains usable when furnace output is occupied")
	game.hud.cursor = empty(); game.hud._slot_click(2,true,false)
	check(game.hud.cursor.id == Nodes.IRON and furnace.slots[2].count == 0,"furnace output can always be collected")
	game.hud.cursor = {"id":Nodes.IRON_ORE,"count":3,"wear":0}; game.hud._slot_click(0,true,false)
	check(furnace.slots[0].count == 3 and game.hud.cursor.id == 0,"empty output unlocks furnace input")
	var p := Vector3i(8,53,8)
	game.world.set_node(p,Nodes.FURNACE); game.world.stations[VoxelWorld.station_key(p)] = furnace
	furnace.slots[0] = empty(); furnace.slots[2] = {"id":Nodes.IRON,"count":1,"wear":0}
	game.world.set_node(p+Vector3i.UP,Nodes.HOPPER)
	game.world.circuits.container(p+Vector3i.UP)[0] = {"id":Nodes.IRON_ORE,"count":2,"wear":0}
	game.world.circuits.hopper(p+Vector3i.UP)
	check(furnace.slots[0].id == 0 and game.world.circuits.container(p+Vector3i.UP)[0].count == 2,"hopper respects the furnace output lock")
	game.world.set_node(p+Vector3i.UP,Nodes.DROPPER); game.world.circuits.configure(p+Vector3i.UP,Vector3i.DOWN)
	game.world.circuits.dispense(p+Vector3i.UP,false)
	check(furnace.slots[0].id == 0,"dropper respects the furnace output lock")
	furnace.slots[2] = empty(); game.world.circuits.dispense(p+Vector3i.UP,false)
	check(furnace.slots[0].id == Nodes.IRON_ORE,"dropper can insert after output has been collected")
	var torch_positions: Array = []
	for i in 5:
		var normal: Vector3i = [Vector3i.UP,Vector3i.RIGHT,Vector3i.LEFT,Vector3i.BACK,Vector3i.FORWARD][i]
		var support: Vector3i = Vector3i(2+i*3,58,3)
		var at: Vector3i = support+normal
		game.world.set_node(support,Nodes.STONE)
		var id: int = Torches.placed(normal); game.world.set_node(at,id); torch_positions.append(at)
		check(Torches.is_torch(id) and at+Torches.support(id) == support and not Nodes.solid(id) and Nodes.drop(id) == Nodes.TORCH,"torch attaches to face %d and drops the ordinary torch item"%i)
		var data := PackedInt32Array(); data.resize(5832); data[343] = id
		var mesh: Array = BlockMesher.build(data)[0]
		check(mesh[Mesh.ARRAY_VERTEX].size() == 24,"torch face %d renders a complete capped model"%i)
	check(Torches.placed(Vector3i.DOWN) == 0,"torches cannot be hung from a ceiling")
	check(not game.game_rules.keepInventory and "false" in game.execute_command("/gamerule keepinventory"),"keepInventory defaults to false and accepts the lowercase name")
	check("set to true" in game.execute_command("/gamerule keepInventory true") and game.game_rules.keepInventory,"gamerule command enables inventory preservation")
	check("Usage" in game.execute_command("/gamerule keepInventory maybe") and game.game_rules.keepInventory,"invalid gamerule values leave the rule unchanged")
	check(game.save_game("user://polish-check.json"),"polish state saves")
	game.load_world_data(game.read_save("user://polish-check.json"))
	while game.state == "loading": await process_frame
	game.pause(); game.world.set_process(false)
	check(game.game_rules.keepInventory,"keepInventory survives a save reload")
	for at in torch_positions:
		var id: int = game.world.node_at(at)
		check(Torches.is_torch(id) and game.torch_lights.has(at),"torch orientation and light survive reload at "+str(at))
		var drops_before: int = game.drops.get_child_count()
		game.world.set_node(at+Torches.support(id),Nodes.AIR)
		check(game.world.node_at(at) == Nodes.AIR and not game.torch_lights.has(at) and game.drops.get_child_count() == drops_before+1,"removing torch support drops exactly one torch and removes its light")
	game.inventory.restore([], [{"id":Pouches.SINGLE,"count":1,"wear":0}])
	game.inventory.slots[0] = {"id":95,"count":1,"wear":22,"data":meta}
	game.inventory.slots[Inventory.BASE_SLOTS] = {"id":Nodes.DIAMOND,"count":17,"wear":0}
	game.player.armor_slots[0] = {"id":Netherite.ARMOR,"count":1,"wear":7}
	game.experience = 20
	game.inventory.sync_pouches()
	var before: Array = [game.inventory.slots.duplicate(true),game.inventory.pouch_slots.duplicate(true),game.player.armor_slots.duplicate(true),game.experience]
	var chest_count: int = game.world.stations.size(); var drop_count: int = game.drops.get_child_count()
	game.die()
	check(before == [game.inventory.slots,game.inventory.pouch_slots,game.player.armor_slots,game.experience] and chest_count == game.world.stations.size() and drop_count == game.drops.get_child_count(),"keepInventory death preserves all carried pages, pouches, armor and XP without duplicate drops")
	game.game_rules.keepInventory = false; game.state = "playing"; game.die()
	check(game.inventory.slots[0].id == 0 and game.world.stations.size() == chest_count+1,"disabling keepInventory restores recovery chest deaths")
	game.hud.show_inventory("table"); game.hud.catalog_mode = false
	game.hud.recipe_search.text = "torch"; game.hud._populate_recipes()
	check(game.hud.recipe_list is GridContainer and game.hud.recipe_list.columns == 5 and game.hud.recipe_list.get_child_count() > 0,"recipe search uses five compact item columns")
	for cell in game.hud.recipe_list.get_children():
		check(cell is RecipeButton and "torch" in cell.tooltip_text.to_lower() and cell.text.is_empty(),"recipe matches show an icon and an item tooltip")
	game.hud.recipe_search.text = "no_such_recipe_xyz"; game.hud.recipe_search.text_changed.emit(game.hud.recipe_search.text)
	check(game.hud.recipe_list.get_child_count() == 1 and game.hud.recipe_list.get_child(0) is Label,"empty search has a clear no-results state")
	await load("res://tests/world_delete_checks.gd").run(self,game)
	print("POLISH TESTS: %d passed, %d failed"%[passed,failed])
	game.queue_free()
	for i in 4: await process_frame
	quit(1 if failed else 0)

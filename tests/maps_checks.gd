extends RefCounted

static func finish(suite: SceneTree, maps: ExplorationMaps) -> bool:
	var deadline: int = Time.get_ticks_msec()+120000
	var worst: int = 0
	while Time.get_ticks_msec() < deadline:
		var started: int = Time.get_ticks_usec(); maps.update(); worst = maxi(worst,Time.get_ticks_usec()-started)
		var pending: bool = false
		for record in maps.records.values():
			if str(record.png).is_empty(): pending = true; break
		if not pending:
			print("MAP MAIN-THREAD UPDATE MAX MS: ",worst/1000.0)
			return true
		await suite.process_frame
	return false

static func image_for(maps: ExplorationMaps, id: String) -> Image:
	var image := Image.new(); image.load_png_from_buffer(Marshalls.base64_to_raw(maps.records[id].png)); return image

static func close_color(a: Color, b: Color) -> bool:
	return absf(a.r-b.r) < 0.009 and absf(a.g-b.g) < 0.009 and absf(a.b-b.b) < 0.009

static func generation_equivalence() -> bool:
	var edits: Dictionary = {Vector3i(8,90,8):Nodes.GOLD_BLOCK,Vector3i(9,23,9):Nodes.AIR}
	var full: Dictionary = TerrainGenerator.new(8675309,"overworld").generate_column(Vector2i.ZERO,edits)
	var raw: Dictionary = TerrainGenerator.new(8675309,"overworld").generate_column(Vector2i.ZERO,edits,true)
	if full.blocks.size() != raw.blocks.size(): return false
	for i in full.blocks.size():
		if full.blocks[i].y != raw.blocks[i].y or full.blocks[i].data != raw.blocks[i].data: return false
	return true

static func run(suite: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	suite.check(game.save_game("user://maps_baseline_check.json"),"map fixture preserves the existing lifecycle world")
	var baseline: Dictionary = game.read_save("user://maps_baseline_check.json")
	var maps: ExplorationMaps = game.maps
	maps.reset()
	var p := Vector3i(8,650,8); game.player.position = Vector3(p)+Vector3(0.5,1.0,0.5)
	suite.check(ExplorationMaps.origin(Vector3(-0.1,255.9,-128.1)) == Vector3i(-128,128,-256),"map cubes align each signed coordinate downward to a multiple of 128")
	suite.check(ExplorationMaps.clean_data({"id":"2","min":[0.0,640.0,0.0],"dimension":"overworld","created":12.0}) == {"id":"2","min":[0,640,0],"dimension":"overworld","created":12},"map metadata normalizes JSON number types")
	suite.check(ExplorationMaps.clean_data({"id":"bad","min":[0,0,0],"dimension":"overworld"}).is_empty() and ExplorationMaps.clean_data({"id":"1","min":[INF,0,0],"dimension":"overworld"}).is_empty(),"invalid map identities and nonfinite bounds are rejected")
	var raw_check: Dictionary = {"equal":false}
	var raw_task: int = WorkerThreadPool.add_task(func(): raw_check.equal = generation_equivalence(),false,"Compare survey voxels")
	while not WorkerThreadPool.is_task_completed(raw_task): await suite.process_frame
	WorkerThreadPool.wait_for_task_completion(raw_task)
	suite.check(raw_check.equal,"survey-only terrain generation returns identical voxels to the normal world generator")
	game.world.set_node(p,Nodes.STONE)
	game.world.set_node(p+Vector3i.RIGHT*2,Nodes.GOLD_BLOCK)
	game.world.set_node(p+Vector3i.RIGHT*2+Vector3i.UP,Nodes.GLASS)
	game.world.set_node(p+Vector3i(0,128,0),Nodes.GOLD_BLOCK)
	var old_map: Dictionary = maps.create(game.player.position)
	var old_id: String = old_map.data.map.id
	game.world.set_node(p,Nodes.GOLD_BLOCK)
	var newer_map: Dictionary = maps.create(game.player.position)
	suite.check(old_id != newer_map.data.map.id and old_map.data.map.min == [0,640,0],"new maps receive unique IDs and fixed aligned regional bounds")
	suite.check(not maps.records[old_id].edits.is_empty() and maps.records[old_id].png.is_empty(),"map creation captures edits and queues generation without synchronous sampling")
	var pending: Dictionary = JSON.parse_string(JSON.stringify(maps.snapshot()))
	game.world.set_node(p,Nodes.DIAMOND_BLOCK)
	maps.restore(pending)
	maps.update()
	suite.check(not maps.job.is_empty() and game.save_game("user://maps_pending_check.json"),"world save records maps while a survey worker is still active")
	var pending_save: Dictionary = game.read_save("user://maps_pending_check.json")
	game.set_process(true); game.load_world_data(pending_save)
	while game.state == "loading": await suite.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	suite.check(game.world.node_at(p) == Nodes.DIAMOND_BLOCK and maps.records.has(old_id),"actual pending-worker reload preserves current world edits and the separately captured survey")
	suite.check(await finish(suite,maps),"pending maps finish after JSON save/restore using bounded worker jobs")
	if str(maps.records[old_id].png).is_empty(): return
	var old_image: Image = image_for(maps,old_id)
	var newer_image: Image = image_for(maps,newer_map.data.map.id)
	suite.check(old_image.get_size() == Vector2i(128,128),"persistent map images contain exactly 128 by 128 pixels")
	suite.check(close_color(old_image.get_pixel(8,8),Nodes.color(Nodes.STONE)),"map pixels retain captured edited blocks after later construction and pending reload")
	suite.check(close_color(newer_image.get_pixel(8,8),Nodes.color(Nodes.GOLD_BLOCK)),"a later map captures its own independent terrain snapshot")
	suite.check(close_color(old_image.get_pixel(10,8),Nodes.color(Nodes.GOLD_BLOCK).lerp(Nodes.color(Nodes.GLASS),64.0/255.0)),"transparent glass composites over captured blocks with the source texture alpha")
	suite.check(close_color(old_image.get_pixel(7,8),Color.BLACK),"empty sky inside the regional cube remains black instead of sampling terrain below it")
	suite.check(old_image.get_pixel(8,8) != Nodes.color(Nodes.GOLD_BLOCK),"blocks above the aligned cube cannot obscure its snapshot")
	var frozen_png: String = maps.records[old_id].png
	game.world.set_node(p,Nodes.REDSTONE_BLOCK); maps.update()
	suite.check(maps.records[old_id].png == frozen_png,"completed map images never refresh when world blocks change")
	var metadata: Dictionary = old_map.data.map
	var inside: Dictionary = ExplorationMaps.marker(metadata,Vector3(8,900,8),"overworld",PI/2)
	var outside: Dictionary = ExplorationMaps.marker(metadata,Vector3(-25,650,180),"overworld",0)
	suite.check(inside.visible and not inside.outside and inside.pixel == Vector2(8,8) and is_equal_approx(inside.rotation,-PI/2),"map marker ignores vertical travel and rounds facing to source quarter turns")
	suite.check(outside.visible and outside.outside and outside.pixel == Vector2(0,127),"travel beyond the map clamps the marker to an edge dot")
	suite.check(not ExplorationMaps.marker(metadata,Vector3(p),"nether",0).visible,"a map retains its dimension and hides a marker from another dimension")
	var clean: Dictionary = Inventory.clean_slot(JSON.parse_string(JSON.stringify(old_map)))
	suite.check(clean.get("data",{}).get("map",{}) == metadata,"inventory cleaning preserves stable map identity and bounds")
	var copied: Dictionary = ExplorationMaps.craft_output_data([old_map,{"id":VillageContent.EMPTY_MAP,"count":1}])
	suite.check(copied.map == metadata,"map-copy recipe returns the original identity rather than creating a fresh survey")
	var grid: Array = []
	for i in 9: grid.append({"id":0,"count":0,"wear":0})
	grid[0] = old_map.duplicate(true); grid[4] = {"id":VillageContent.EMPTY_MAP,"count":1,"wear":0}
	var recipe: Dictionary = ExplorationMaps.special_recipe(grid)
	suite.check(not recipe.is_empty() and recipe.count == 2,"map copying is a source shapeless one-map plus one-empty-map recipe")
	grid[8] = {"id":VillageContent.EMPTY_MAP,"count":1,"wear":0}
	suite.check(ExplorationMaps.special_recipe(grid).is_empty(),"map-copy recipe rejects extra ingredients")
	var inventory := Inventory.new(); inventory.slots[0] = old_map.duplicate(true); inventory.add_item(VillageContent.EMPTY_MAP,1)
	var recipe_index: int = -1
	for i in inventory.recipes.size():
		if inventory.recipes[i].id == VillageContent.FILLED_MAP and inventory.recipes[i].count == 2: recipe_index = i; break
	suite.check(recipe_index >= 0 and inventory.craft(recipe_index,"hand"),"survival recipe guide crafts two metadata-preserving map copies")
	var identities: Array = []
	for slot in inventory.slots:
		if slot.id == VillageContent.FILLED_MAP: identities.append(slot.get("data",{}).get("map",{}).get("id",""))
	suite.check(identities == [old_id,old_id],"copying splits unstackable maps into two inventory slots without losing identity")
	for i in game.inventory.slots.size(): game.inventory.slots[i] = {"id":0,"count":0,"wear":0}
	for i in 9: game.inventory.grid[i] = {"id":0,"count":0,"wear":0}
	game.inventory.grid[0] = old_map.duplicate(true); game.inventory.grid[1] = {"id":VillageContent.EMPTY_MAP,"count":1,"wear":0}
	game.hud.cursor = {"id":0,"count":0,"wear":0}; game.hud.station = "hand"
	game.hud._take_output()
	suite.check(game.hud.cursor.id == 0 and game.inventory.count_item(VillageContent.FILLED_MAP) == 2 and game.inventory.grid[0].id == 0 and game.inventory.grid[1].id == 0,"manual copy output enters two inventory slots instead of an oversized lossy cursor stack")
	game.inventory.slots = inventory.slots.duplicate(true); game.inventory.selected = 0
	game.inventory.add_item(VillageContent.EMPTY_MAP,1)
	suite.check(maps.copy_map(0) and game.inventory.count_item(VillageContent.FILLED_MAP) == 3 and game.inventory.count_item(VillageContent.EMPTY_MAP) == 0,"cartography copies the chosen map using one empty map")
	for i in game.inventory.slots.size(): game.inventory.slots[i] = {"id":Nodes.STONE,"count":64,"wear":0}
	game.inventory.slots[0] = old_map.duplicate(true); game.inventory.slots[1] = {"id":VillageContent.EMPTY_MAP,"count":2,"wear":0}
	var before: Array = game.inventory.slots.duplicate(true)
	suite.check(not maps.copy_map(0) and game.inventory.slots == before,"a full inventory rejects cartography copying without consuming either ingredient")
	var drops_before: int = game.drops.get_child_count()
	game.inventory.selected = 1
	suite.check(maps.use() and game.inventory.slots[1].count == 1 and game.drops.get_child_count() == drops_before+1,"using an empty map with no free slot drops the filled map without losing it")
	var overflow: ItemDrop = game.drops.get_child(game.drops.get_child_count()-1)
	suite.check(overflow.item_id == VillageContent.FILLED_MAP and maps.records.has(overflow.data.get("map",{}).get("id","")),"overflow map drops retain their persistent identity")
	var opened_id: String = maps.view_id
	suite.check(maps.show_map() and maps.view_id == opened_id,"map menu reflow keeps the current survey even when its item overflowed to the world")
	game.pause(); game.set_process(false)
	for i in game.inventory.slots.size(): game.inventory.slots[i] = {"id":0,"count":0,"wear":0}
	game.inventory.slots[0] = {"id":VillageContent.EMPTY_MAP,"count":2,"wear":0}; game.inventory.selected = 0
	var count_before: int = maps.records.size()
	suite.check(maps.use() and game.inventory.count_item(VillageContent.EMPTY_MAP) == 1 and game.inventory.count_item(VillageContent.FILLED_MAP) == 1 and maps.records.size() == count_before+1,"using a stacked empty map consumes one and delivers a uniquely filled map")
	suite.check(game.state == "map" and is_instance_valid(maps.view_image),"map use opens a persistent region view while generation is pending")
	game.pause(); game.set_process(false)
	var mode: String = game.gamemode; game.gamemode = "creative"
	suite.check(maps.use() and game.inventory.count_item(VillageContent.EMPTY_MAP) == 0,"creative map filling consumes one empty map as the source does")
	game.gamemode = mode; game.pause(); game.set_process(false)
	var legacy: Dictionary = {"id":VillageContent.FILLED_MAP,"count":1,"wear":0,"data":{"custom_name":"Old explorer"}}
	var migrated: Dictionary = maps.ensure(legacy); var again: Dictionary = maps.ensure(legacy)
	suite.check(not migrated.is_empty() and again.id == migrated.id and legacy.data.custom_name == "Old explorer","legacy filled maps migrate once without losing custom metadata")
	suite.check(ExplorationMaps.craft_output_data([{"id":VillageContent.FILLED_MAP,"count":1,"wear":0}]).has("error"),"unmigrated legacy maps cannot produce identity-free copies")
	var model: MeshInstance3D = maps.frame_model(old_map)
	suite.check(model.mesh is QuadMesh and model.material_override.albedo_texture == maps.texture(old_id),"item frames display the actual saved map image")
	model.free()
	game.inventory.slots[0] = old_map.duplicate(true); game.inventory.selected = 0; game.state = "playing"
	maps.update()
	suite.check(is_instance_valid(maps.held_panel) and maps.held_image.texture == maps.texture(old_id),"holding a filled map displays its actual saved image during play")
	game.pause(); game.set_process(false); maps.update()
	suite.check(not is_instance_valid(maps.held_panel),"leaving play removes the held-map overlay from menus")
	var frame: Vector3i = p+Vector3i.LEFT*2
	game.world.set_node(frame,VillageContent.ITEM_FRAME)
	game.inventory.slots[0] = old_map.duplicate(true); game.inventory.selected = 0
	game.survival.frame_item(frame)
	suite.check(game.world.get_station(frame,"frame").slots[0].get("data",{}).get("map",{}).get("id","") == old_id and game.inventory.slots[0].id == 0,"placing a map in a real item frame stores its identity and consumes the held item")
	var display: Variant = game.survival.displays.get(game.world.station_key(frame))
	suite.check(is_instance_valid(display) and display.material_override.albedo_texture == maps.texture(old_id),"real item-frame display refresh uses the saved survey texture")
	game.survival.frame_item(frame)
	suite.check(game.world.get_station(frame,"frame").slots[0].id == 0 and game.inventory.slots[0].get("data",{}).get("map",{}).get("id","") == old_id,"taking a map from a frame returns the same saved survey")
	game.survival.frame_item(frame)
	game.inventory.slots[0] = old_map.duplicate(true)
	game.inventory.slots[1] = newer_map.duplicate(true); game.inventory.slots[2] = {"id":VillageContent.EMPTY_MAP,"count":1,"wear":0}
	var table: Vector3i = p+Vector3i.RIGHT*3
	game.world.set_node(table,VillageContent.CARTOGRAPHY_TABLE)
	game.player.target = {"pos":table,"id":VillageContent.CARTOGRAPHY_TABLE,"normal":Vector3i.UP,"point":Vector3(table)+Vector3(0.5,1.0,0.5),"distance":3.0}
	game.player.use()
	suite.check(game.state == "workstation" and game.survival.workstation_id == VillageContent.CARTOGRAPHY_TABLE,"holding a map still opens the targeted cartography table before displaying the map")
	var copy_button: Button
	for child in game.hud.layer.find_children("*","Button",true,false):
		if "copy" in child.text.to_lower() and ("#"+str(newer_map.data.map.id)) in child.text: copy_button = child; break
	var copies_before: int = 0
	for slot in game.inventory.slots:
		if slot.get("data",{}).get("map",{}).get("id","") == newer_map.data.map.id: copies_before += 1
	if copy_button != null: copy_button.pressed.emit()
	var copies_after: int = 0
	for slot in game.inventory.slots:
		if slot.get("data",{}).get("map",{}).get("id","") == newer_map.data.map.id: copies_after += 1
	suite.check(copy_button != null and copies_after == copies_before+1,"cartography offers a working copy action for a chosen map beyond the first inventory entry")
	game.pause(); game.set_process(false)
	var chest: Vector3i = p+Vector3i.RIGHT*4
	game.world.set_node(chest,Nodes.CHEST)
	game.player.target = {"pos":chest,"id":Nodes.CHEST,"normal":Vector3i.UP,"point":Vector3(chest)+Vector3(0.5,1.0,0.5),"distance":4.0}
	game.player.use()
	suite.check(game.state == "inventory" and game.hud.station == "chest","holding a map preserves a chest's source right-click interaction")
	game.pause(); game.set_process(false); game.player.target = {}
	suite.check(await finish(suite,maps),"all newly created and migrated maps finish before saving the fixture")
	suite.check(game.save_game("user://maps_persistent_check.json"),"persistent map registry saves with the normal world")
	var saved: Dictionary = game.read_save("user://maps_persistent_check.json")
	suite.check(saved.get("maps",{}).get("records",{}).get(old_id,{}).get("png","") == frozen_png,"world save contains the immutable map pixels alongside item references")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await suite.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	suite.check(game.maps.records.has(old_id) and game.maps.records[old_id].png == frozen_png and game.inventory.slots[0].data.map.id == old_id,"actual world reload restores map IDs, item metadata and the original saved texture")
	suite.check(game.world.get_station(frame,"frame").slots[0].get("data",{}).get("map",{}).get("id","") == old_id,"map identity also survives an actual save/reload while stored in an item frame")
	game.set_process(true); game.load_world_data(baseline)
	while game.state == "loading": await suite.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	for filename in ["maps_baseline_check.json","maps_pending_check.json","maps_persistent_check.json"]:
		for suffix in ["",".bak",".tmp"]:
			var path: String = "user://"+filename+suffix
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

extends SceneTree
var game: Node3D
var failed: int = 0
func check(condition: bool, message: String) -> void:
	print(("PASS  " if condition else "FAIL  ")+message)
	if not condition: failed += 1
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-alchemy-tour-worlds")
	call_deferred("run")
func shot(filename: String) -> void:
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/voxey-shots/"+filename+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/voxey-shots")
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.touch = true; game.audio_enabled = false; game.world.radius = 2
	game.start_new("8675309","Alchemy tour","creative")
	while game.state == "loading": await process_frame
	game.pause(); game.inventory = Inventory.new()
	game.inventory.changed.connect(game.hud.refresh_slots)
	for color in [6,9,11,4,0]:
		for level in range(1,6): game.inventory.add_item(Pouches.SINGLE+(level-1)*16+color)
	for index in 3:
		game.inventory.exchange_pouch(index,{"id":Pouches.SINGLE+64+[6,9,11][index],"count":1,"wear":0})
	var cargo_index: int = 0
	for id in PotionCatalog.ITEMS:
		if cargo_index >= 135: break
		game.inventory.slots[36+cargo_index] = {"id":id,"count":1,"wear":0}; cargo_index += 1
	game.inventory.slots[440] = {"id":Nodes.WRITTEN_BOOK,"count":1,"wear":0,"data":{"title":"The far pocket","text":"Every last page is yours."}}
	game.inventory.changed.emit()
	game.open_inventory(); await shot("33_colored_pouches")
	game.hud._change_inventory_page(1); await shot("38_pouch_inventory_page")
	game.hud._change_inventory_page(14); await shot("39_pouch_last_page")
	game.hud.inventory_page = 0
	game.survival.open_pouch(0,true); game.hud._change_container_page(4)
	await shot("34_pouch_contents")
	game.hud._close_pouch_view()
	game.hud.inventory_page = 1; game.inventory.slots[62] = {"id":Nodes.DIAMOND,"count":5,"wear":0}
	game.hud.show_inventory()
	var pointer: Vector2 = game.hud.slots_ui[35].get_parent().get_global_rect().get_center()
	Input.warp_mouse(pointer)
	for i in 3: await process_frame
	var key := InputEventKey.new(); key.physical_keycode = KEY_Q; key.pressed = true
	game._input(key)
	check(game.inventory.slots[62].count == 4,"Q uses the correct inventory page and drops just one item")
	game.hud._pouch_click(0,false)
	var original: Dictionary = game.hud.cursor.duplicate(true)
	Input.warp_mouse(Vector2(1,1))
	for i in 3: await process_frame
	key = InputEventKey.new(); key.physical_keycode = KEY_ESCAPE; key.pressed = true
	game._input(key)
	var found: bool = false
	for drop in game.drops.get_children():
		if drop.item_id == original.id and drop.data == original.data: found = true
	check(found and game.hud.cursor.id == 0,"Escape with a filled pouch outside the inventory drops its exact contents")
	game.pause(); game.inventory.exchange_pouch(0,original)
	game.gamemode = "survival"; game.die(); await shot("40_recovery_death")
	var location: Array = game.world.adventure_state.last_recovery.position
	game.open_inventory("chest",Vector3i(location[0],location[1],location[2])); await shot("41_recovery_chest")
	game.gamemode = "creative"; game.player.health = 20; game.hud.return_cursor()
	game.resume(); game.pause(); game.inventory = Inventory.new()
	for id in [VillageContent.WATER_BOTTLE,VillageContent.NETHER_WART_ITEM,Nodes.BLAZE_POWDER,Nodes.SUGAR,VillageContent.GLOWSTONE_DUST,Nodes.REDSTONE_WIRE,Nodes.GUNPOWDER,VillageContent.DRAGON_BREATH,VillageContent.FERMENTED_SPIDER_EYE]: game.inventory.add_item(id,Nodes.max_stack(id) if id != VillageContent.DRAGON_BREATH else 4)
	var p := Vector3i(8,50,8); game.world.set_node(p,VillageContent.BREWING_STAND)
	var stand: Dictionary = game.world.get_station(p,"brewing")
	stand.slots[0] = {"id":Nodes.SUGAR,"count":4,"wear":0}; stand.slots[1] = {"id":Nodes.BLAZE_POWDER,"count":3,"wear":0}
	for i in range(2,5): stand.slots[i] = {"id":PotionCatalog.find("awkward"),"count":1,"wear":0}
	Brewing.step(stand,4)
	game.open_inventory("brewing",p); await shot("35_brewing")
	game.resume(); game.pause(); game.inventory = Inventory.new()
	game.inventory.add_item(Nodes.TOOLS+18); game.inventory.add_item(VillageContent.TRIDENT); game.inventory.add_item(VillageContent.MACE); game.inventory.add_item(Nodes.BOOK,4); game.inventory.add_item(Nodes.LAPIS,32)
	game.world.set_node(p,Nodes.ENCHANTING_TABLE)
	game.open_enchanting(p); await shot("36_enchantments")
	game.hud.show_profiles(); await shot("37_player_profiles")
	game.queue_free()
	for i in 4: await process_frame
	quit(1 if failed else 0)

extends RefCounted

static func guard() -> Dictionary:
	return {"id":VillageContent.SHIELD,"count":1,"wear":84,"data":{"custom_name":"Wayfarer's Guard","enchantments":{"Mending":1,"Unbreaking":2},"pwp":7}}
static func flag(base: int = 6) -> Dictionary:
	return {"id":Banners.FIRST+base,"count":3,"wear":0,"data":{"custom_name":"Flag name","layers":[{"pattern":"border","color":0},{"pattern":"rhombus","color":4}]}}
static func guide_index(inv: Inventory, base: int) -> int:
	for i in inv.recipes.size():
		if inv.recipes[i].get("shield_decoration",false) and not inv.recipes[i].get("dynamic",false) and inv.recipes[i].ingredients.has(Banners.FIRST+base): return i
	return -1
static func run(t: SceneTree, game: Node3D) -> void:
	var temporary_controls: bool = not is_instance_valid(game.controls)
	if temporary_controls: game.controls = TouchControls.new(); game.controls.game = game; game.add_child(game.controls)
	var old_sneak: bool = game.controls.sneak_held
	var inventory: Array = game.inventory.slots.duplicate(true); var grid: Array = game.inventory.grid.duplicate(true)
	var selected: int = game.inventory.selected; var offhand: Dictionary = game.player.offhand_slot.duplicate(true)
	var cursor: Dictionary = game.hud.cursor.duplicate(true); var shift: bool = game.hud.shift_mode
	var inv := Inventory.new(); inv.restore([])
	var banner: Dictionary = flag(); var shield: Dictionary = guard()
	var decorated: Dictionary = Shields.decorate([shield,banner])
	t.check(decorated.wear == shield.wear and decorated.data.custom_name == shield.data.custom_name and decorated.data.enchantments == shield.data.enchantments and not decorated.data.has("pwp"),"shield decoration preserves damage, enchantments and shield name but resets prior work")
	t.check(decorated.data.shield_color == 6 and decorated.data.layers == banner.data.layers and shield == guard() and banner == flag(),"decoration copies the base colour and ordered layers without mutating its inputs")
	for base in 16:
		inv.restore([]); inv.add_item(VillageContent.SHIELD,1,84,shield.data); inv.add_item(Banners.FIRST+base,3,0,banner.data)
		var index: int = guide_index(inv,base)
		t.check(index >= 0 and inv.fill_grid(index,"hand"),"the recipe guide fills the %s shield in a hand grid" % Banners.BANNER_NAMES[base])
		var output: Dictionary = inv.take_grid_result("hand")
		inv.grid_to_inventory()
		t.check(output.get("data",{}).get("shield_color",-1) == base and output.wear == 84 and inv.count_item(Banners.FIRST+base) == 2 and inv.count_item(VillageContent.SHIELD) == 0,"taking a decorated shield consumes one shield and one banner and retains the other banners")
	inv.restore([]); inv.add_item(VillageContent.SHIELD,1,84,shield.data); inv.add_item(banner.id,1,0,banner.data)
	t.check(inv.craft(guide_index(inv,6),"hand") and inv.slots.any(func(item): return item.id == VillageContent.SHIELD and item.wear == 84 and item.get("data",{}).get("shield_color",-1) == 6),"direct crafting preserves the same decorated shield and damage")
	t.check(Shields.decorate([decorated,banner]).is_empty(),"a coloured shield cannot receive another banner")
	var over: Dictionary = flag()
	while over.data.layers.size() < 13: over.data.layers.append({"pattern":"border","color":0})
	t.check(Shields.decorate([shield,over]).is_empty(),"the source refuses a banner with more than twelve layers")
	t.check(Inventory.clean_slot(decorated) == decorated,"shield appearance, name and enchantments survive inventory cleanup")
	game.inventory.restore([]); game.inventory.selected = 0; game.inventory.slots[0] = shield
	game.inventory.slots[1] = banner
	game.inventory.fill_grid(guide_index(game.inventory,6),"hand"); game.open_inventory("hand")
	game.hud.cursor = {"id":Nodes.STONE,"count":1,"wear":0}; game.hud.shift_mode = false
	var before: Array = game.inventory.grid.duplicate(true)
	game.hud._take_output()
	t.check(game.inventory.grid == before and game.hud.cursor.id == Nodes.STONE,"an occupied output cursor leaves both decoration ingredients untouched")
	game.hud.cursor = Bookshelves.empty(); game.hud._take_output()
	t.check(game.hud.cursor == decorated,"the actual output cursor takes the fully decorated, damaged shield")
	game.hud.cursor = Bookshelves.empty(); game.resume(); game.pause()
	game.inventory.slots[0] = decorated.duplicate(true); game.inventory.selected = 0
	game.player._make_hand(VillageContent.SHIELD)
	t.check(game.player.hand.get_child_count() > 0 and game.player.hand.get_children().any(func(node): return node is MeshInstance3D and node.mesh is ArrayMesh and node.mesh.get_surface_count() == 3),"the held shield is a solid model with separate front, back and metal edges")
	game.player.offhand_slot = decorated.duplicate(true); game.player._update_shield_view()
	t.check(is_instance_valid(game.player.offhand_shield) and game.player.offhand_shield.mesh.surface_get_material(0).albedo_texture == Shields.texture(decorated),"the second hand displays its actual shield design")
	var data_before: Dictionary = game.player.offhand_slot.data.duplicate(true)
	game.inventory.slots[0] = Bookshelves.empty()
	game.survival.shield_raised = true
	Shields.add_wear(game.player,4.1)
	t.check(Durability.normalized(game.player.offhand_slot) == 16661 and game.player.offhand_slot.data.layers == data_before.layers and game.player.offhand_slot.data.custom_name == data_before.custom_name,"Unbreaking reduces exact blocking wear without changing the offhand shield's appearance")
	game.controls.sneak_held = true; game.survival.update(0.0)
	t.check(Shields.raised(game.player),"the live sneak control raises an offhand shield with an empty main hand")
	game.controls.sneak_held = false; game.survival.update(0.0)
	t.check(not Shields.raised(game.player),"releasing the live sneak control lowers the offhand shield")
	var drop: ItemDrop = game.spawn_drop(game.player.position+Vector3(2,2,0),decorated.id,1,decorated.wear,decorated.data)
	drop.set_physics_process(false)
	t.check(drop.data == decorated.data and drop.mesh_instance.mesh.surface_get_material(0).albedo_texture == Shields.texture(decorated),"a dropped shield carries the same design and renders its decorated front")
	drop.free()
	var p := Vector3i(game.player.position.floor())+Vector3i(2,2,0)
	game.world.set_node(p,VillageContent.ITEM_FRAME)
	Frames.station(game.world,p).slots[0] = decorated.duplicate(true)
	game.survival.refresh_displays()
	var key: String = VoxelWorld.station_key(p)
	t.check(game.survival.displays.has(key) and game.survival.displays[key].mesh.surface_get_material(0).albedo_texture == Shields.texture(decorated),"an item frame renders the stored shield's actual design")
	# The existing rewards had two obsolete IDs, so neither reached the loom.
	t.check(Inventory.clean_slot({"id":812,"count":1}).id == VillageContent.PATTERN_FIRST+6 and Inventory.clean_slot({"id":1106,"count":1}).id == VillageContent.PATTERN_FIRST+7,"old Globe and Piglin pattern rewards migrate to their functional pattern items")
	game.inventory.restore([]); game.inventory.add_item(VillageContent.EMERALD,8)
	var person: Dictionary = game.villages.make_record("shield-cartographer","cartographer",game.player.position,Vector3i.ZERO,Vector3i.ZERO,Vector3i.ZERO)
	person.level = 5
	VillagerTrading.activate(person,5)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/shield_reference.json"))
	var offer: Dictionary = {}
	for candidate in person.offers:
		if candidate.give[0] == VillageContent.PATTERN_FIRST+6: offer = candidate; break
	t.check(not offer.is_empty() and offer.cost[0][1] == int(source.globe.cost) and offer.stock == int(source.globe.stock) and offer.xp == int(source.globe.xp),"the master cartographer's Globe offer matches the source price, stock and XP")
	t.check(game.villages.transaction(person,offer,true).is_empty() and game.inventory.count_item(VillageContent.PATTERN_FIRST+6) == 1,"a real cartographer transaction awards the working Globe pattern")
	game.villages.state().people.erase("shield-cartographer")
	var piglin: Dictionary = {}
	for seed_value in 100:
		var chest: Dictionary = VoxelWorld._new_station("chest",27); Bastions.fill(chest,seed_value)
		for item in chest.slots:
			if item.id == VillageContent.PATTERN_FIRST+7: piglin = item; break
		if not piglin.is_empty(): break
	var weighted: Array = Bastions.TREASURE.filter(func(entry): return entry[0] == VillageContent.PATTERN_FIRST+7)
	t.check(not piglin.is_empty() and weighted.size() == 1 and weighted[0][1] == int(source.piglin.weight),"bastion treasure awards the functional Piglin pattern at the source weight")
	for pattern_index in [6,7]:
		game.inventory.restore([]); game.inventory.slots[0] = {"id":Banners.FIRST,"count":1,"wear":0}
		game.inventory.slots[1] = {"id":VillageContent.DYE_WHITE+6,"count":1,"wear":0}
		game.inventory.slots[2] = {"id":VillageContent.PATTERN_FIRST+pattern_index,"count":1,"wear":0}
		t.check(Banners.loom_apply(game.inventory,0,1,Banners.ITEM_KEYS[pattern_index],2) and game.inventory.slots.any(func(item): return not Banners.layers(item).is_empty() and Banners.layers(item)[0].pattern == Banners.ITEM_KEYS[pattern_index]),"the acquired %s pattern works in the real loom" % Banners.ITEM_KEYS[pattern_index])
	game.inventory.slots[0] = decorated.duplicate(true); game.player.offhand_slot = decorated.duplicate(true)
	game.experience = 100
	t.check(game.save_game("user://shield_decor.json"),"decorated shields save to a world file")
	var saved: Dictionary = game.read_save("user://shield_decor.json")
	t.check(Inventory.clean_slot(saved.inventory[0]) == decorated and Inventory.clean_slot(saved.offhand) == decorated and Inventory.clean_slot(saved.stations[key].slots[0]) == decorated,"disk saves preserve shields in the inventory, second hand and item frames")
	game.experience = 0; game.state = "playing"
	game.load_world_data(saved); game.set_process(true); game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	var loaded: bool = game.state != "loading"
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	t.check(loaded and game.experience == 100 and game.inventory.slots[0] == decorated and game.player.offhand_slot == decorated and Frames.station(game.world,p).slots[0] == decorated,"actual world reload preserves saved XP and worn Mending shields without awarding XP again")
	game.world.set_node(p,Nodes.AIR); game.world.stations.erase(key); game.survival.refresh_displays()
	game.inventory.slots = inventory; game.inventory.grid = grid; game.inventory.selected = selected
	game.player.offhand_slot = offhand; game.player._update_shield_view(); game.player._make_hand(game.inventory.held().id)
	game.hud.cursor = cursor; game.hud.shift_mode = shift
	game.controls.sneak_held = old_sneak
	if temporary_controls: game.controls.free(); game.controls = null
	for path in ["user://shield_decor.json","user://shield_decor.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

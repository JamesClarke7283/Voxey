extends RefCounted

static func item(id: int, count: int = 1, data: Dictionary = {}) -> Dictionary:
	return {"id":id,"count":count,"wear":0,"data":data.duplicate(true)}

static func seed_offer(game: Node3D, slot: Dictionary, shelves: int, index: int) -> Dictionary:
	for seed_value in range(1,256):
		game.enchanting_state[game.player_id] = {"seed":seed_value,"serial":0,"cache":{}}
		var rows: Array = Enchanting.offers(game,slot,shelves)
		if not rows[index].is_empty(): return rows[index]
	return {}

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	var home: Vector3 = game.player.position
	var old_slots: Array = game.inventory.slots.slice(0,Inventory.BASE_SLOTS).duplicate(true)
	var old_pouches: Array = game.inventory.pouch_slots.duplicate(true)
	var old_state: Dictionary = game.enchanting_state.duplicate(true)
	var old_xp: float = game.experience; var old_mode: String = game.gamemode
	var world: VoxelWorld = game.world
	var p := Vector3i(8,48,8)
	var previous: Dictionary = {}
	for x in range(-2,3):
		for z in range(-2,3):
			for y in 2:
				var at := p+Vector3i(x,y,z); previous[at] = world.node_at(at); world.set_node(at,Nodes.AIR)
	world.set_node(p,Nodes.ENCHANTING_TABLE)
	var source: Dictionary = Enchanting.source
	var exact: bool = true
	for i in source.bookshelf_positions.size():
		var shelf: Array = source.bookshelf_positions[i]; var gap: Array = source.air_positions[i]
		var at := p+Vector3i(shelf[0],shelf[1],shelf[2]); var air := p+Vector3i(gap[0],gap[1],gap[2])
		world.set_node(at,Nodes.BOOKSHELF)
		exact = exact and game.bookshelf_power(p) == 1
		world.set_node(air,Nodes.TORCH)
		exact = exact and game.bookshelf_power(p) == 0
		world.set_node(air,Nodes.AIR); world.set_node(at,Nodes.AIR)
	t.check(exact,"all 32 shelves use the source's exact paired literal-air cell, including diagonal pairs")
	for shelf in source.bookshelf_positions: world.set_node(p+Vector3i(shelf[0],shelf[1],shelf[2]),Nodes.BOOKSHELF)
	t.check(game.bookshelf_power(p) == 15,"two full shelf rings are capped at fifteen power")
	game.gamemode = "survival"; game.inventory.restore([])
	game.inventory.slots[0] = item(95,1,{"custom_name":"Deep digger"}); game.inventory.slots[0].wear = 71
	game.inventory.add_item(Nodes.LAPIS,8)
	var offer: Dictionary = seed_offer(game,game.inventory.slots[0],15,2)
	t.check(not offer.is_empty() and offer.level_requirement == 30,"maximum shelf third offer requires level thirty")
	var cached: Array = Enchanting.offers(game,game.inventory.slots[0],15)
	var altered: Array = Enchanting.offers(game,item(95,1,{"custom_name":"Another pick"}),15)
	t.check(cached == altered,"same item type reuses offers across copies, names and wear")
	altered[2].enchantments.clear()
	t.check(Enchanting.offers(game,game.inventory.slots[0],15) == cached,"callers cannot mutate the saved offer cache")
	Enchanting.offers(game,game.inventory.slots[0],0); Enchanting.offers(game,item(Nodes.BOW),15)
	t.check(Enchanting.offers(game,game.inventory.slots[0],15) == cached and Enchanting.state(game).cache.size() == 3,"switching items or bookshelf counts preserves earlier offers")
	var player_id: String = game.player_id; game.identity.session_id = "enchanting-other-player"
	Enchanting.offers(game,item(95),15); Enchanting.reset(game); game.identity.session_id = player_id
	t.check(Enchanting.offers(game,game.inventory.slots[0],15) == cached,"another player's reset leaves this player's offers untouched")
	game.experience = 1394
	var before: Array = game.inventory.slots.duplicate(true)
	t.check(not game.enchant_item(0,3,p,offer.token) and game.experience == 1394 and game.inventory.slots == before,"insufficient level rejects a purchase without spending anything")
	game.experience = 1451
	t.check(not game.enchant_item(0,3,p,"stale-token") and game.inventory.slots == before,"a stale UI offer cannot purchase a different result")
	world.set_node(p,Nodes.AIR)
	t.check(not game.enchant_item(0,3,p,offer.token) and game.inventory.slots == before,"a removed enchanting table cannot complete a purchase")
	world.set_node(p,Nodes.ENCHANTING_TABLE)
	t.check(game.enchant_item(0,3,p,offer.token) and game.inventory.count_item(Nodes.LAPIS) == 5 and game.experience == 1137,"third offer consumes three lapis and three levels while preserving half-bar progress")
	t.check(game.inventory.slots[0].data.enchantments == offer.enchantments and game.inventory.slots[0].data.custom_name == "Deep digger" and game.inventory.slots[0].wear == 71,"the item receives exactly its offered enchantments and preserves existing metadata and wear")
	t.check(Enchanting.state(game).cache.is_empty() and Enchanting.state(game).serial == 1,"a successful purchase clears every cached shelf/item offer for that player")
	t.check(not game.enchant_item(0,1,p) and game.experience == 1137,"already enchanted equipment cannot be table enchanted again")
	# The third slot remains usable without shelves; only its rolled requirement matters.
	for shelf in source.bookshelf_positions: world.set_node(p+Vector3i(shelf[0],shelf[1],shelf[2]),Nodes.AIR)
	game.inventory.restore([]); game.inventory.slots[0] = item(95); game.inventory.add_item(Nodes.LAPIS,3)
	offer = seed_offer(game,game.inventory.slots[0],0,2); game.experience = 1395
	t.check(offer.level_requirement < 30 and game.enchant_item(0,3,p,offer.token),"a valid third offer at zero shelves has no artificial fifteen-shelf gate")
	game.gamemode = "creative"; game.experience = 0; game.inventory.restore([]); game.inventory.slots[0] = item(95)
	offer = seed_offer(game,game.inventory.slots[0],0,0)
	t.check(not game.enchant_item(0,1,p,offer.token) and game.experience == 0,"creative mode still requires lapis")
	game.inventory.add_item(Nodes.LAPIS,1)
	t.check(game.enchant_item(0,1,p,offer.token) and game.experience == 0 and game.inventory.count_item(Nodes.LAPIS) == 0,"creative mode consumes lapis and waives the XP cost")
	game.inventory.restore([]); game.inventory.slots[0] = item(Nodes.BOOK,4,{"custom_name":"Field notes"}); game.inventory.add_item(Nodes.LAPIS,2)
	offer = seed_offer(game,game.inventory.slots[0],0,0)
	t.check(game.enchant_item(0,1,p,offer.token) and game.inventory.slots[0].id == VillageContent.ENCHANTED_BOOK and game.inventory.slots[0].count == 1 and game.inventory.count_item(Nodes.BOOK) == 3,"enchanting a book stack splits off exactly one enchanted book")
	t.check(game.inventory.slots[0].data.custom_name == "Field notes" and game.inventory.slots[2].data.custom_name == "Field notes" and not game.inventory.slots[2].data.has("enchantments"),"both split book stacks preserve their name and only the purchased book gains enchantments")
	game.inventory.restore([])
	for i in game.inventory.slots.size(): game.inventory.slots[i] = item(Nodes.STONE,64)
	game.inventory.slots[0] = item(Nodes.BOOK,4); game.inventory.slots[1] = item(Nodes.LAPIS,64)
	offer = seed_offer(game,game.inventory.slots[0],0,0); before = game.inventory.slots.duplicate(true)
	var state_before: Dictionary = Enchanting.state(game).duplicate(true)
	t.check(not game.enchant_item(0,1,p,offer.token) and game.inventory.slots == before and Enchanting.state(game) == state_before,"a full backpack rejects a book split atomically without lapis loss or a reroll")
	game.inventory.slots[1].count = 1
	t.check(game.enchant_item(0,1,p,offer.token) and game.inventory.slots[1].id == Nodes.BOOK and game.inventory.slots[1].count == 3,"the last lapis frees a slot that can hold the remaining books")
	var pouch: Dictionary = item(Pouches.SINGLE)
	Pouches.contents(pouch)[0] = item(95,1,{"custom_name":"Pouch pick"})
	game.inventory.restore([], [pouch]); game.inventory.add_item(Nodes.LAPIS,1)
	offer = seed_offer(game,game.inventory.slots[Inventory.BASE_SLOTS],0,0)
	t.check(game.enchant_item(Inventory.BASE_SLOTS,1,p,offer.token) and Pouches.contents(game.inventory.pouch_slots[0])[0].data.enchantments == offer.enchantments,"enchanting equipment on a pouch page updates the actual saved pouch contents")
	game.inventory.restore([]); game.inventory.slots[0] = item(95); game.inventory.add_item(Nodes.LAPIS,3)
	seed_offer(game,game.inventory.slots[0],0,0)
	cached = Enchanting.offers(game,game.inventory.slots[0],0)
	game.open_enchanting(p)
	var panel: Control = game.hud.layer.get_children().back()
	var buttons: Array = panel.find_children("*","Button",true,false).filter(func(button):return button.text != "Done" and not button is OptionButton)
	t.check(buttons.size() == 3 and panel.find_children("*","OptionButton",true,false).size() == 1,"table UI has one equipment picker and exactly three generated offers")
	var ui_valid: bool = buttons.size() == 3
	for i in mini(buttons.size(),3):
		ui_valid = ui_valid and (buttons[i].disabled if cached[i].is_empty() else buttons[i].text.contains(cached[i].description))
	t.check(ui_valid,"each UI button displays its cached hint or disables the empty offer")
	game.resume(); game.pause(); game.open_enchanting(p)
	t.check(Enchanting.offers(game,game.inventory.slots[0],0) == cached,"closing and reopening the table cannot reroll its offers")
	panel = game.hud.layer.get_children().back()
	buttons = panel.find_children("*","Button",true,false).filter(func(button):return button.text != "Done" and not button is OptionButton)
	buttons[0].pressed.emit()
	t.check(game.inventory.slots[0].data.enchantments == cached[0].enchantments and game.inventory.count_item(Nodes.LAPIS) == 2 and Enchanting.state(game).cache.is_empty(),"pressing the actual UI offer purchases its displayed result and refreshes the table")
	game.inventory.slots[0] = item(95)
	cached = Enchanting.offers(game,game.inventory.slots[0],0)
	game.experience = 1451
	game.network.peer_bags[777] = game.inventory
	game.network.peer_identity[777] = "enchant-test-peer"
	game.network._persist_inventory(777,game.network.inventory_snapshot())
	var network_record: Dictionary = game.world.adventure_state.network_players["enchant-test-peer"]
	t.check(network_record.experience == game.experience and network_record.enchanting == game.enchanting_state,"hosted-player records preserve XP and cached offers for reconnects")
	game.network.peer_bags.erase(777); game.network.peer_identity.erase(777)
	game.pause(); game.player.position = home
	t.check(game.save_game("user://enchanting.json"),"enchanting state saves to disk")
	game.set_process(true); game.load_world_data(game.read_save("user://enchanting.json"))
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	world = game.world; game.pause(); game.set_process(false); world.set_process(false); world.active = false
	t.check(Enchanting.offers(game,game.inventory.slots[0],0) == cached,"disk reload retains every offer, hint, token and random glyph")
	t.check(Enchanting.restore(world.adventure_state.network_players["enchant-test-peer"].enchanting) == game.enchanting_state and world.adventure_state.network_players["enchant-test-peer"].experience == 1451,"host disk saves preserve a reconnecting player's enchanting record")
	world.adventure_state.network_players.erase("enchant-test-peer")
	var broken: Dictionary = game.enchanting_state.duplicate(true)
	for rows in broken[game.player_id].cache.values():
		for row in rows:
			if not row.is_empty(): row.erase("level_requirement")
	t.check(Enchanting.restore(broken)[game.player_id].cache.is_empty() and Enchanting.restore([]).is_empty(),"malformed saved offers are discarded instead of breaking purchases")
	game.inventory.restore(old_slots,old_pouches); game.enchanting_state = old_state
	game.gamemode = old_mode; game.experience = old_xp
	for at in previous: world.set_node(at,previous[at])
	for path in ["user://enchanting.json","user://enchanting.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

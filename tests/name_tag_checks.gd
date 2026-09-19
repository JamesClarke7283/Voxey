extends RefCounted

static func run(suite: SceneTree, game: Node3D) -> void:
	var previous_inventory: Inventory = game.inventory
	var previous_mode: String = game.gamemode
	var previous_xp: float = game.experience
	game.inventory = Inventory.new(); game.gamemode = "survival"; game.experience = 0
	game.inventory.add_item(NameTags.ITEM,3)
	suite.check(not NameTags.rename(game,0,"Daisy") and not game.inventory.held().has("data"),"anvil renaming requires one XP level and leaves items unchanged when unaffordable")
	game.experience = 20
	suite.check(NameTags.rename(game,0,"Daisy") and game.inventory.held().count == 3 and game.experience == 11,"anvil renames a whole stack for exactly one level")
	suite.check(not NameTags.rename(game,0,"Daisy") and game.experience == 11,"unchanged names do not spend XP")
	game.inventory.restore(JSON.parse_string(JSON.stringify(game.inventory.slots)))
	suite.check(game.inventory.held().get("data",{}).get("custom_name","") == "Daisy","named tags survive inventory save serialization")
	var cow: Creature = game.spawn_creature("cow",game.player.position+Vector3(2,0,0)); cow.set_physics_process(false)
	suite.check(NameTags.use(game,cow) and cow.custom_name == "Daisy" and game.inventory.count_item(NameTags.ITEM) == 2,"using a named tag names a cow and consumes one tag")
	suite.check(cow.get_node_or_null("NameTag") != null and cow.get_node("NameTag").text == "Daisy","named creatures display their name above their head")
	suite.check(Farming.records(game).get(cow.farm_id,{}).get("custom_name","") == "Daisy","naming immediately updates persistent animal state")
	var key: String = cow.farm_id; cow.free()
	var restored: Creature = Farming.resolve(game,key); restored.set_physics_process(false)
	suite.check(restored.custom_name == "Daisy" and restored.get_node_or_null("NameTag") != null,"named animals restore their name and visible label")
	Farming.forget(restored); restored.free()
	game.gamemode = "creative"; game.experience = 0
	suite.check(NameTags.rename(game,0,"B".repeat(70)) and game.inventory.held().data.custom_name.length() == 50 and game.experience == 0,"creative anvil names are free and limited to 50 bytes")
	var sheep: Creature = game.spawn_creature("sheep",game.player.position); sheep.set_physics_process(false)
	NameTags.use(game,sheep)
	suite.check(sheep.custom_name.length() == 30 and game.inventory.count_item(NameTags.ITEM) == 2,"creature names have the source 30-byte limit and creative tags are retained")
	Farming.forget(sheep); sheep.free()
	suite.check(NameTags.bounded("猫".repeat(30),50).to_utf8_buffer().size() == 48,"UTF-8 name limits preserve whole characters")
	suite.check(NameTags.rename(game,0,"") and not game.inventory.held().has("data"),"anvil can remove a custom name")
	var pig: Creature = game.spawn_creature("pig",game.player.position); pig.set_physics_process(false)
	NameTags.use(game,pig)
	suite.check(pig.custom_name.is_empty() and game.inventory.count_item(NameTags.ITEM) == 2,"blank tags leave creatures and stack counts unchanged")
	Farming.forget(pig); pig.free()
	game.inventory.slots[1] = {"id":VillageContent.CROSSBOW,"count":1,"wear":7,"data":{"enchantments":{"Quick Charge":2}}}
	NameTags.rename(game,1,"Scout")
	suite.check(Inventory.clean_slot(game.inventory.slots[1]).data == {"custom_name":"Scout","enchantments":{"Quick Charge":2}} and game.inventory.slots[1].wear == 7,"renaming preserves unloaded-crossbow enchantments and durability")
	game.survival.show_station(Vector3i.ZERO,VillageContent.ANVIL)
	var fields: Array = game.hud.find_children("ItemName","LineEdit",true,false)
	var buttons: Array = game.hud.find_children("SetItemName","Button",true,false)
	suite.check(fields.size() == 1 and buttons.size() == 1,"anvil opens an item selector and editable naming field")
	if fields.size() == 1 and buttons.size() == 1:
		fields[0].text = "Meadow"; buttons[0].pressed.emit()
		suite.check(game.inventory.held().get("data",{}).get("custom_name","") == "Meadow","anvil Set name button executes the real rename transaction")
		fields[0].text = "Enter key"; fields[0].text_submitted.emit(fields[0].text)
		suite.check(game.inventory.held().get("data",{}).get("custom_name","") == "Enter key","anvil Enter key executes the same rename transaction")
	game.experience = 7; game.gamemode = "survival"
	suite.check(not NameTags.rename(game,-1,"Invalid") and not NameTags.rename(game,99999,"Invalid") and not NameTags.rename(game,2,"Invalid") and game.experience == 7,"invalid and empty inventory indices cannot spend XP")
	suite.check(NameTags.rename(game,0,"") and game.experience == 0,"removing an existing name costs exactly one level in survival")
	suite.check(not NameTags.rename(game,0,"") and game.experience == 0,"removing an already absent name is a free no-op")
	game.gamemode = "creative"
	game.inventory.slots[2] = {"id":Nodes.WRITTEN_BOOK,"count":1,"wear":0,"data":{"title":"A signed story","text":"Original text"}}
	suite.check(not NameTags.rename(game,2,"Replacement") and game.inventory.slots[2].data.title == "A signed story","source no_rename protection preserves a signed book's title")
	game.inventory.slots[3] = {"id":PortableStorage.SHULKER_BASE,"count":1,"wear":0,"data":{"contents":[{"id":Nodes.DIAMOND,"count":6,"wear":0}]}}
	NameTags.rename(game,3,"Treasure")
	suite.check(Inventory.clean_slot(game.inventory.slots[3]).data.contents[0].count == 6,"renaming a filled shulker retains its entire cargo")
	suite.check(NameTags.bounded("First\nSecond\rThird",50) == "First Second Third" and Inventory.clean_slot({"id":NameTags.ITEM,"count":1,"data":{"custom_name":"猫".repeat(30)}}).data.custom_name.to_utf8_buffer().size() == 48,"item name sanitation keeps source byte limits and single-line visible text")
	NameTags.rename(game,0,"Protector")
	for excluded in ["ender_dragon","end_crystal"]:
		var object: Creature = game.spawn_creature(excluded,game.player.position); object.set_physics_process(false)
		var tag_count: int = game.inventory.count_item(NameTags.ITEM); game.gamemode = "survival"
		NameTags.use(game,object)
		suite.check(object.custom_name.is_empty() and game.inventory.count_item(NameTags.ITEM) == tag_count,"name tags cannot name or be spent on "+excluded)
		object.free()
	game.gamemode = "creative"
	game.pause()
	_persistence_checks(suite,game)
	game.inventory = previous_inventory; game.gamemode = previous_mode; game.experience = previous_xp

static func _persistence_checks(suite: SceneTree, game: Node3D) -> void:
	var previous_adventure: Dictionary = game.world.adventure_state.duplicate(true)
	var previous_dimensions: Dictionary = game.dimension_states.duplicate(true)
	var previous_leads: LeadManager = game.leads
	var previous_creatures: Array = game.creatures.get_children()
	var had_alchemy_marker: bool = game.world.has_meta("alchemy_restored")
	for mob in previous_creatures: game.creatures.remove_child(mob)
	game.world.adventure_state = {}; game.leads = LeadManager.new(game)
	game.inventory.slots[0] = {"id":NameTags.ITEM,"count":64,"wear":0}
	game.inventory.selected = 0; game.gamemode = "creative"
	var kinds: Array = Creature.KINDS.keys().filter(func(kind: String): return kind not in ["ender_dragon","end_crystal"])
	for kind in kinds:
		var mob: Creature = game.spawn_creature(kind,game.player.position); mob.set_physics_process(false)
		NameTags.rename(game,0,"Tag_"+kind); NameTags.use(game,mob)
		if kind == "slime": mob.set_slime_size(4)
		if kind in ["sheep","slime","villager","piglin"]: game.leads.attach(mob,false)
		if kind == "piglin": mob.barter_time = 3; mob.barter_count = 2; mob.store_record()
	var save_path: String = "user://name-tag-roundtrip.json"
	suite.check(game.save_game(save_path),"all named creature families and active leads serialize through the real save writer")
	var saved: Dictionary = game.read_save(save_path)
	suite.check(saved.leads.size() == 4 and saved.leads.any(func(entry: Dictionary): return entry.get("resident","") != ""),"lead saves retain farm, villager and Nether resident identity")
	game.leads.clear()
	for mob in game.creatures.get_children(): mob.free()
	game.world.adventure_state = saved.adventure.duplicate(true)
	if game.world.has_meta("alchemy_restored"): game.world.remove_meta("alchemy_restored")
	game.world.set_meta("farm_restore_timer",0.0)
	# Execute the loader's actual final restoration phase against the loaded
	# chunk cache, omitting unrelated drops/arrows that remain in this fixture.
	game.pending_save = {"position":saved.position,"animals":saved.animals,"leads":saved.leads}
	game._finish_loading(); game.pause()
	game.villages.timer = 0; game.villages.update(0)
	for kind in kinds:
		var found: Array = game.creatures.get_children().filter(func(mob: Creature): return mob.kind == kind and mob.custom_name == "Tag_"+kind)
		suite.check(found.size() == 1 and found[0].get_node_or_null("NameTag") != null,"save restoration retains exactly one named "+kind+" and its visible label")
		for mob in found: mob.set_physics_process(false)
	var piglins: Array = game.creatures.get_children().filter(func(mob: Creature): return mob.kind == "piglin" and mob.custom_name == "Tag_piglin")
	suite.check(piglins.size() == 1 and piglins[0].barter_time == 3 and piglins[0].barter_count == 2,"named piglin lead restoration preserves barter state and its original resident record")
	suite.check(game.leads.leads.size() == 4 and game.leads.leads.all(func(link: Dictionary): return link.mob.custom_name == "Tag_"+link.mob.kind),"all four restored leads attach to the corresponding named creatures")
	game.leads.restore(saved.leads)
	NetherResident.restore_named(game)
	suite.check(game.creatures.get_children().filter(func(mob: Creature): return mob.custom_name.begins_with("Tag_")).size() == kinds.size(),"repeated lead and Nether restoration reuse existing identities without duplicating named mobs")
	for entry in game.world.adventure_state.get("nether_residents",{}).values(): entry.dead = true
	for mob in game.creatures.get_children():
		if mob is NetherResident: mob.free()
	NetherResident.restore_named(game)
	suite.check(not game.creatures.get_children().any(func(mob: Creature): return mob is NetherResident),"dead named Nether resident records do not resurrect")
	game.leads.clear()
	for mob in game.creatures.get_children(): mob.free()
	game.world.adventure_state = previous_adventure; game.dimension_states = previous_dimensions
	game.leads = previous_leads
	if had_alchemy_marker: game.world.set_meta("alchemy_restored",true)
	elif game.world.has_meta("alchemy_restored"): game.world.remove_meta("alchemy_restored")
	for mob in previous_creatures: game.creatures.add_child(mob)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path+suffix))

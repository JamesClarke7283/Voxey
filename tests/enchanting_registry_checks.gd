extends RefCounted
static func run(t: SceneTree, game: Node3D) -> void:
	t.check(Enchanting.source.definitions.size() == 39 and Enchantments.DATA.size() == 41,"active definitions come from the loaded source registry while two disabled legacy names remain readable")
	t.check(not Enchanting.source.definitions["Curse of Binding"].tradable and not Enchanting.candidates(Nodes.BOOK,{},true).has("Curse of Binding"),"the source's manually registered Binding curse is not available from random books")
	var chest := Nodes.armor_id(3,1)
	t.check(Enchanting.support(chest,"Thorns") == Vector2i(1,0) and not Enchanting.candidates(chest,{},false).has("Thorns"),"source chestplate groups make Thorns available through an anvil, but not direct random selection")
	t.check(Enchanting.can_apply(chest,"Thorns",1) and Enchanting.can_apply(chest,"Curse of Binding",1),"manual book application still accepts Thorns and Binding on a chestplate")
	t.check(Enchanting.support(Nodes.BOW,"Punch") == Vector2i(1,0) and not Enchanting.can_apply(Nodes.BOW,"Punch",3),"secondary bow support and maximum levels use the completed registry")
	t.check(Enchantments.accepts((Nodes.TOOLS+16),"Bane of Arthropods") and not Enchantments.accepts((Nodes.TOOLS+16),"Bane of Arthropods",true) and Enchantments.accepts((Nodes.TOOLS+16),"Smite"),"axe damage enchantments remain available as secondary book applications")
	t.check(Enchanting.support((Nodes.TOOLS+13),"Unbreaking").x == 1 and not Enchanting.item_profile((Nodes.TOOLS+13)).groups.has("tool"),"source item type and tool group are distinct when checking sword enchantments")
	t.check(Enchanting.ability(MobArmor.COPPER_HELMET) == 8 and Enchanting.ability(Netherite.TOOLS) == 10,"registered material values cover copper armor and netherite equipment")
	var old: Dictionary = {"id":Nodes.armor_id(1,0),"count":1,"data":{"custom_name":"Old helmet","enchantments":{"Aqua Affinity":1,"Respiration":3}}}
	var cleaned: Dictionary = Inventory.clean_slot(old)
	t.check(Inventory.enchantment(cleaned,"Aqua Affinity") == 1 and not Enchantments.accepts(int(old.id),"Aqua Affinity"),"stored disabled enchantments survive cleanup without being offered for new application")
	old = {"id":(Nodes.TOOLS+16),"count":1,"wear":4,"data":{"enchantments":{"Bane of Arthropods":5}}}
	t.check(Inventory.enchantment(Inventory.clean_slot(old),"Bane of Arthropods") == 5,"an existing axe enchantment remains intact under registry-based rules")
	var book: Dictionary = {"id":VillageContent.ENCHANTED_BOOK,"count":1,"data":{"enchantments":{"Thorns":3}}}
	var tool: Dictionary = {"id":chest,"count":1,"wear":0}
	var operation: Dictionary = Anvils.plan(tool,book)
	t.check(not operation.is_empty() and Inventory.enchantment(operation.output,"Thorns") == 3,"the actual anvil path can apply secondary Thorns despite its exclusion from table rolls")
	book.data.enchantments = {"Curse of Binding":1}; operation = Anvils.plan(tool,book)
	t.check(not operation.is_empty() and Inventory.enchantment(operation.output,"Curse of Binding") == 1,"a supplied Binding book remains usable through the actual anvil path")
	var boots: Dictionary = {"id":Nodes.armor_id(1,3),"count":1,"data":{"enchantments":{"Soul Speed":1}}}
	var walker: Dictionary = {"id":VillageContent.ENCHANTED_BOOK,"count":1,"data":{"enchantments":{"Frost Walker":1}}}
	var asymmetric: Dictionary = Anvils.plan(boots,walker)
	t.check(not asymmetric.is_empty() and asymmetric.output.data.enchantments.size() == 2,"the source permits Frost Walker to be added after Soul Speed")
	boots.data.enchantments = {"Frost Walker":1}; walker.data.enchantments = {"Soul Speed":1}
	t.check(Anvils.plan(boots,walker).is_empty(),"the source rejects the same pair in the opposite application order")
	for metadata in [{"Soul Speed":1,"Frost Walker":1},{"Frost Walker":1,"Soul Speed":1}]:
		var loaded: Dictionary = Inventory.clean_slot({"id":Nodes.armor_id(1,3),"count":1,"data":{"enchantments":metadata}})
		t.check(loaded.data.enchantments.size() == 2,"a legitimately combined one-way pair survives either serialized key order")
	var invalid: Dictionary = Inventory.clean_slot({"id":Nodes.TOOLS+13,"count":1,"data":{"enchantments":{"Sharpness":5,"Smite":5}}})
	t.check(invalid.data.enchantments.has("Sharpness") and not invalid.data.enchantments.has("Smite"),"existing symmetric conflict sanitation remains intact")
	var random_books_valid: bool = true; var rng := RandomNumberGenerator.new(); rng.seed = 12345
	for i in 512:
		var rolled: Dictionary = Enchantments.random_book(rng)
		var name: String = rolled.enchantments.keys()[0]
		if name in ["Curse of Binding","Soul Speed","Wind Burst","Aqua Affinity","Sweeping Edge"]: random_books_valid = false
	t.check(random_books_valid,"uniform random books use the live eligible set across repeated rolls")
	# A failed first potency and a successful empty source table have distinct results.
	var exhausted: Dictionary = {"id":Nodes.ELYTRA,"count":1,"data":{"enchantments":{"Unbreaking":1}}}
	var result: Dictionary = Enchanting.generate(exhausted,1,EnchantRolls.new(1),false,false,true)
	t.check(result.has("enchantments") and result.enchantments.is_empty() and not result.has("description"),"source generation with no remaining candidate retains its successful empty result")
	var original: Array = game.inventory.slots.duplicate(true)
	game.inventory.restore([old,cleaned]); game.save_game()
	var saved: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	game.inventory.restore(saved.inventory)
	t.check(Inventory.enchantment(game.inventory.slots[0],"Bane of Arthropods") == 5 and Inventory.enchantment(game.inventory.slots[1],"Aqua Affinity") == 1,"real world serialization retains legacy item enchantments after registry migration")
	game.inventory.restore(original)

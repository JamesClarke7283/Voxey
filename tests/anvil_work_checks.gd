extends RefCounted

static func item(id: int, count: int = 1, wear: int = 0, data: Dictionary = {}) -> Dictionary:
	return {"id":id,"count":count,"wear":wear,"data":data.duplicate(true)}

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	var old_slots: Array = game.inventory.slots.slice(0,Inventory.BASE_SLOTS).duplicate(true)
	var old_pouches: Array = game.inventory.pouch_slots.duplicate(true)
	var old_mode: String = game.gamemode; var old_xp: float = game.experience
	var home: Vector3 = game.player.position
	var p := Vector3i(8,60,8); var world: VoxelWorld = game.world
	world.set_node(p+Vector3i.DOWN,Nodes.STONE); world.set_node(p,VillageContent.ANVIL)
	game.gamemode = "survival"; game.inventory.restore([])
	var a: Dictionary = item(90,1,200,{"custom_name":"Deep digger","pwp":1})
	var b: Dictionary = item(VillageContent.ENCHANTED_BOOK,1,0,{"enchantments":{"Efficiency":1},"pwp":2})
	var plan: Dictionary = Anvils.plan(a,b,"Deep digger")
	t.check(plan.cost == 5 and plan.output.data.pwp == 3 and plan.output.wear == 200,"book combining uses its enchantment factor plus both prior-work costs")
	t.check(not a.data.has("enchantments") and a.data.pwp == 1 and b.data.pwp == 2,"creating an anvil preview leaves both inputs unchanged")
	game.inventory.slots[0] = a.duplicate(true); game.inventory.slots[1] = b.duplicate(true)
	game.experience = ExperienceCurve.total(4)
	var before: Array = game.inventory.slots.duplicate(true)
	t.check(not AnvilWorkbench.use(game,p,0,1,"Deep digger") and game.inventory.slots == before and game.xp_level() == 4,"an unaffordable combine cannot mutate enchantments, consume items or XP")
	game.experience = 1451
	var token: String = AnvilWorkbench.token(a,b,"Deep digger",plan)
	game.inventory.slots[1].data.custom_name = "Changed book"
	t.check(not AnvilWorkbench.use(game,p,0,1,"Deep digger",token) and game.experience == 1451,"a stale preview cannot silently use changed input metadata")
	game.inventory.slots[1] = b.duplicate(true)
	world.set_node(p,Nodes.AIR)
	t.check(not AnvilWorkbench.use(game,p,0,1,"Deep digger",token) and game.inventory.slots[0] == a,"a removed anvil cannot complete its preview")
	world.set_node(p,VillageContent.ANVIL)
	t.check(AnvilWorkbench.use(game,p,0,1,"Deep digger",token) and game.experience == ExperienceCurve.spend(1451,5),"anvil payment spends levels and preserves fractional bar progress")
	t.check(game.inventory.slots[0] == plan.output and game.inventory.slots[1].id == 0,"taking the result consumes precisely its two inputs and preserves target metadata")
	var same_tool: Dictionary = Anvils.plan(item(90,1,200,{"enchantments":{"Efficiency":1}}),item(90,1,100,{"enchantments":{"Efficiency":1}}))
	t.check(same_tool.cost == 4 and same_tool.output.wear == 19 and same_tool.output.data.enchantments.Efficiency == 2,"two enchanted tools add their remaining durability and source twelve-percent bonus")
	t.check(Anvils.plan(item(90,1,200),item(90,1,100)).is_empty(),"unchanged enchantments leave no same-tool result in this source checkout")
	var conflict: Dictionary = Anvils.plan(item(95,1,0,{"enchantments":{"Fortune":1}}),item(VillageContent.ENCHANTED_BOOK,1,0,{"enchantments":{"Silk Touch":1,"Unbreaking":2}}))
	t.check(conflict.cost == 3 and conflict.output.data.enchantments == {"Fortune":1,"Unbreaking":2},"rejected conflicting enchantments add one level while compatible additions still apply")
	t.check(Anvils.plan(item(VillageContent.ENCHANTED_BOOK,1,0,{"enchantments":{"Fortune":1}}),item(VillageContent.ENCHANTED_BOOK,1,0,{"enchantments":{"Silk Touch":1}})).is_empty(),"anvil book combining rejects conflicts even though enchanting-table books can contain them")
	for tool in [Nodes.FLINT_AND_STEEL,PigRiding.CARROT_ON_A_STICK,PigRiding.WARPED_FUNGUS_ON_A_STICK,Screwdriver.ID]:
		var ready: Dictionary = Anvils.plan(item(tool),item(VillageContent.ENCHANTED_BOOK,1,0,{"enchantments":{"Unbreaking":2}}))
		t.check(not ready.is_empty() and ready.output.data.enchantments.Unbreaking == 2 and not Enchanting.fresh(item(tool)),"anvil-only tool accepts Unbreaking and remains excluded from the table: "+Nodes.title(tool))
	t.check(Anvils.repair_material(1110) == Nodes.GOLD and Anvils.repair_material(Netherite.TOOLS) == Netherite.INGOT,"golden tools are not mistaken for larger-id netherite tools")
	t.check(Anvils.accepts_material(80,BambooWood.PLANKS) and Anvils.accepts_material(85,MinecloniaOres.BLACKSTONE) and Anvils.accepts_material(85,Nodes.COBBLED_DEEPSLATE),"wood and cobble repair groups accept all source material variants")
	t.check(Anvils.repair_material(Nodes.ELYTRA) == 0 and Anvils.repair_material(VillageContent.MACE) == VillageContent.BREEZE_ROD,"mace uses breeze rods while this source gives elytra no material repair")
	var material_plan: Dictionary = Anvils.plan(item(Nodes.IRON,4,0,{"pwp":1}),item(90,1,200,{"pwp":2,"custom_name":"Pick"}),"Pick")
	t.check(material_plan.cost == 8 and material_plan.consume == [4,1] and material_plan.output.wear == 0 and material_plan.output.data.pwp == 3,"reverse-order material repairs include both penalties and retain the tool's identity")
	var expensive: Dictionary = Anvils.plan(item(VillageContent.ENCHANTED_BOOK,1,0,{"pwp":6,"enchantments":{"Sharpness":1}}),item(VillageContent.ENCHANTED_BOOK,1,0,{"pwp":6,"enchantments":{"Sharpness":1}}))
	t.check(expensive.cost == 128,"source combines have no invented forty-level cutoff")
	game.inventory.restore([]); game.inventory.slots[0] = item(Nodes.BOOK,12)
	game.inventory.slots[1] = item(VillageContent.ENCHANTED_BOOK,1,0,{"enchantments":{"Mending":1}}); game.experience = 1451
	t.check(AnvilWorkbench.use(game,p,0,1) and game.inventory.count_item(Nodes.BOOK) == 11 and game.inventory.count_item(VillageContent.ENCHANTED_BOOK) == 1,"combining a plain book stack spends one book and returns one enchanted book")
	t.check(Inventory.enchantment(game.inventory.slots[1],"Mending") == 1,"split anvil output is placed into the vacated input slot with its enchantment")
	game.inventory.restore([]); game.inventory.slots[0] = item(Nodes.IRON,64,0,{"pwp":10}); game.experience = 1451
	t.check(AnvilWorkbench.use(game,p,0,-1,"Stock") and game.inventory.slots[0].count == 64 and game.inventory.slots[0].data.pwp == 10 and game.experience == ExperienceCurve.spend(1451,1),"rename-only mode renames the whole stack for one level without increasing prior work")
	game.inventory.slots[0] = item(Nodes.WRITTEN_BOOK,1,0,{"title":"Story","text":"Unchanged"})
	t.check(not AnvilWorkbench.use(game,p,0,-1,"Other") and game.inventory.slots[0].data.title == "Story","written-book no-rename protection applies in the actual workstation")
	game.gamemode = "creative"; game.experience = 0
	world.set_node(p,VillageContent.ANVIL)
	for n in 64:
		game.inventory.slots[0] = item(90,1,200)
		game.inventory.slots[1] = item(Nodes.IRON,4)
		if not AnvilWorkbench.use(game,p,0,1,"Creative repair"): break
	t.check(game.experience == 0 and world.node_at(p) == VillageContent.ANVIL and game.inventory.slots[1].id == 0,"creative repairs consume materials, cost no XP and never damage the anvil")
	var pouch: Dictionary = item(Pouches.SINGLE)
	Pouches.contents(pouch)[0] = item(90,1,200,{"custom_name":"Pouch pick"})
	game.inventory.restore([], [pouch]); game.inventory.slots[0] = item(Nodes.IRON,4)
	t.check(AnvilWorkbench.use(game,p,Inventory.BASE_SLOTS,0,"Pouch pick") and Pouches.contents(game.inventory.pouch_slots[0])[0].wear == 0,"anvil replacements update equipped pouch cargo")
	game.inventory.restore([]); game.inventory.slots[0] = item(90,1,200)
	game.inventory.slots[1] = item(Nodes.IRON,4)
	game.survival.show_station(p,VillageContent.ANVIL)
	var first: OptionButton = game.hud.find_child("RenameItem",true,false)
	var second: OptionButton = game.hud.find_child("AnvilSecondItem",true,false)
	t.check(first != null and second != null,"anvil UI exposes two explicit inventory input selectors")
	for i in first.item_count:
		if first.get_item_id(i) == 0: first.select(i); first.item_selected.emit(i); break
	for i in second.item_count:
		if second.get_item_id(i) == 1: second.select(i); second.item_selected.emit(i); break
	var action: Button = game.hud.find_child("SetItemName",true,false)
	t.check(not action.disabled and action.text.contains("Repair"),"selecting material shows a usable source repair preview")
	action.pressed.emit()
	t.check(game.inventory.slots[0].wear == 0 and game.inventory.slots[1].id == 0,"the actual anvil result button performs the previewed transaction")
	game.pause(); game.gamemode = "survival"; game.experience = 0
	game.inventory.slots[0] = item(90,1,200); game.inventory.slots[1] = item(Nodes.IRON,4)
	AnvilWorkbench.show(game,p,0,1)
	action = game.hud.find_child("SetItemName",true,false)
	t.check(action.disabled and game.inventory.slots[0].wear == 200,"unaffordable UI previews remain visible without allowing a take")
	game.gamemode = "creative"; game.experience = 1451
	game.inventory.slots[0] = a.duplicate(true); game.inventory.slots[1] = b.duplicate(true)
	AnvilWorkbench.use(game,p,0,1,"Deep digger")
	var saved_item: Dictionary = game.inventory.slots[0].duplicate(true)
	game.player.position = home
	t.check(game.save_game("user://anvil-work.json"),"anvil result and prior-work metadata save to disk")
	game.set_process(true); game.load_world_data(game.read_save("user://anvil-work.json"))
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	world = game.world; game.pause(); game.set_process(false); world.set_process(false); world.active = false
	t.check(game.inventory.slots[0] == saved_item and Anvils.pwp_of(game.inventory.slots[0]) == 3,"real reload preserves the result's enchantments, name, wear and prior-work penalty")
	var before_drops: int = count_anvils(game)
	world.set_node(p,11447); game.gamemode = "survival"
	for i in 512:
		if game.survival.damage_anvil(p): break
	t.check(world.node_at(p) == Nodes.AIR and count_anvils(game) == before_drops,"the third damage stage destroys an anvil without dropping a replacement anvil")
	game.inventory.restore(old_slots,old_pouches); game.gamemode = old_mode; game.experience = old_xp
	for path in ["user://anvil-work.json","user://anvil-work.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

static func count_anvils(game: Node3D) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == VillageContent.ANVIL: count += drop.amount
	return count

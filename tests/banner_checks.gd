extends RefCounted

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.free()

static func patterned(count: int = 1) -> Dictionary:
	return {"id":Banners.FIRST+6,"count":count,"wear":0,"data":{"custom_name":"Homeward","layers":[{"pattern":"border","color":2},{"pattern":"circle","color":9}]}}

static func run(t: SceneTree, game: Node3D) -> void:
	var before: Array = game.inventory.slots.duplicate(true)
	var selected: int = game.inventory.selected
	game.inventory.selected = 0; game.gamemode = "survival"
	var p := Vector3i(8,500,8)
	for x in range(-2,3):
		for y in range(-1,3):
			for z in range(-2,3): game.world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	clear_drops(game)
	var banner: Dictionary = patterned(3)
	t.check(Inventory.clean_slot(banner) == banner,"cleanup preserves banner layers and its name")
	t.check(Nodes.max_stack(banner.id) == 16 and Inventory.clean_slot(patterned(64)).count == 64,"new banner stacks use sixteen while older overfull saves retain every item")
	t.check(Inventory.clean_slot(JSON.parse_string(JSON.stringify(banner))) == banner,"banner metadata survives JSON saves")
	var bad: Dictionary = Inventory.clean_slot({"id":Banners.FIRST,"count":1,"data":{"layers":[{"pattern":"unknown","color":0},false,{"pattern":"border","color":-1},{"pattern":"cross","color":3}]}})
	t.check(Banners.layers(bad) == [{"pattern":"cross","color":3}],"malformed banner layers are removed")
	var many: Dictionary = patterned()
	for i in range(2,Banners.MAX_LAYERS): Banners.emblazon(many,"cross",i%16)
	t.check(Banners.layers(many).size() == 12 and not Banners.emblazon(many,"border",0),"the source allows twelve layers and refuses a thirteenth")
	t.check(Banners.describe(many).contains("6 additional layers") and Banners.describe(banner).find("Bordure") < Banners.describe(banner).find("Roundel"),"tooltip lists oldest layers and the overflow count")
	var plain: Dictionary = {"id":banner.id,"count":1}
	t.check(Banners.combine(plain,banner) and plain.data == banner.data,"copy transfers layers and name to a matching plain banner")
	t.check(not Banners.combine(plain,banner) and not Banners.combine({"id":Banners.FIRST,"count":1},banner),"copy rejects decorated destinations and different colours")
	var recipes := Inventory.new()
	var paper_ok: bool = true
	for n in 6:
		for i in recipes.grid.size(): recipes.grid[i] = {"id":0,"count":0,"wear":0}
		var recipe: Dictionary = recipes.recipes[recipes.recipe_index(VillageContent.PATTERN_FIRST+n)]
		for ingredient in recipe.ingredients:
			recipes.grid[0 if ingredient == Nodes.PAPER else 1] = {"id":ingredient,"count":1,"wear":0}
		paper_ok = paper_ok and recipes.take_grid_result("hand").get("id",0) == VillageContent.PATTERN_FIRST+n
	t.check(paper_ok,"all six paper pattern recipes work in the hand crafting grid")
	game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	game.inventory.slots[0] = patterned(3)
	t.check(Banners.place(game,{"pos":p+Vector3i.DOWN,"normal":Vector3i.UP},game.inventory,0.7),"a patterned banner places on a floor")
	var state: Dictionary = Banners.station(game.world,p)
	t.check(not state.wall and state.rotation == Banners.rotation_level(0.7) and Banners.stored_item(game.world,p) == patterned(),"standing placement stores its exact item and sixteen-step facing")
	t.check(game.inventory.held().count == 2 and game.inventory.held().data == banner.data,"placement consumes one without changing the remaining stack")
	var snap: Dictionary = game.dimension_snapshot()
	var key: String = VoxelWorld.station_key(p)
	game.world.stations[key] = JSON.parse_string(JSON.stringify(snap.stations[key]))
	t.check(Banners.stored_item(game.world,p) == patterned() and Banners.station(game.world,p).rotation == Banners.rotation_level(0.7),"world snapshot preserves the placed design and facing")
	var model: Node3D = Banners.display_model(game.world,p)
	t.check(model.get_child_count() == 3 and model.get_child(2).material_override.albedo_texture == Banners.texture(patterned()),"world model displays its saved design")
	model.free()
	var face: int = int(Banners.station(game.world,p).rotation)
	t.check(Banners.rotate(game.world,p,Screwdriver.ROTATE_FACE) and Banners.station(game.world,p).rotation == posmod(face-1,16),"standing rotation decreases one source step")
	t.check(not Banners.rotate(game.world,p,Screwdriver.ROTATE_AXIS),"banner rejects axis rotation")
	game.break_node(p,banner.id,0)
	t.check(game.world.node_at(p) == Nodes.AIR and not game.world.stations.has(key) and game.drops.get_child_count() == 1,"digging clears its station and drops one banner")
	t.check(game.drops.get_child(0).data == banner.data,"harvesting retains the complete banner design and name")
	clear_drops(game)
	game.inventory.slots[0] = patterned(3)
	Banners.place(game,{"pos":p+Vector3i.DOWN,"normal":Vector3i.UP},game.inventory,0)
	game.world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	t.check(game.world.node_at(p) == Nodes.AIR and game.drops.get_child_count() == 1 and game.drops.get_child(0).data == banner.data,"floor support removal releases one patterned banner")
	clear_drops(game)
	for normal in Banners.NORMALS:
		game.world.set_node(p-normal,Nodes.STONE)
		game.inventory.slots[0] = patterned(3)
		t.check(Banners.place(game,{"pos":p-normal,"normal":normal},game.inventory,0),"banner attaches to wall "+str(normal))
		state = Banners.station(game.world,p)
		t.check(state.wall and Banners.support(state) == -normal,"wall banner records its support")
		var hit: Dictionary = game.world.raycast(Vector3(p)+Vector3.ONE*0.5+Vector3(normal)*2,-Vector3(normal),4)
		t.check(not hit.is_empty() and hit.pos == p,"wall banner uses its thin selection box")
		game.world.set_node(p-normal,Nodes.AIR)
		t.check(game.world.node_at(p) == Nodes.AIR and game.drops.get_child_count() == 1,"wall support removal yields one banner")
		clear_drops(game)
	game.world.set_node(p+Vector3i.UP,Nodes.STONE)
	game.inventory.slots[0] = patterned(3)
	t.check(not Banners.place(game,{"pos":p+Vector3i.UP,"normal":Vector3i.DOWN},game.inventory,0) and game.inventory.held().count == 3,"ceiling placement fails without consuming a banner")
	game.world.set_node(p+Vector3i.UP,Nodes.AIR)
	game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	var blasts_ok: bool = true
	for n in 16:
		clear_drops(game); game.inventory.slots[0] = patterned(2)
		Banners.place(game,{"pos":p+Vector3i.DOWN,"normal":Vector3i.UP},game.inventory,0)
		game.explode(Vector3(p),0.75)
		blasts_ok = blasts_ok and game.drops.get_child_count() == 1 and game.drops.get_child(0).data == banner.data
	t.check(blasts_ok,"sixteen explosions each return one complete banner without a second generic drop")
	clear_drops(game)
	var bag := Inventory.new()
	for i in bag.slots.size(): bag.slots[i] = {"id":0,"count":0,"wear":0}
	bag.slots[0] = patterned(3); bag.slots[1] = {"id":VillageContent.DYE_RED,"count":3,"wear":0}
	t.check(Banners.loom_apply(bag,0,1,"cross"),"loom supports a dye-only design")
	t.check(bag.slots[0].count == 2 and bag.slots[1].count == 2 and Banners.layers(bag.slots[2]).size() == 3,"loom patterns one banner and leaves the input stack unchanged")
	bag.slots[3] = {"id":VillageContent.PATTERN_FIRST,"count":2,"wear":0}
	t.check(Banners.loom_apply(bag,0,1,"thing",3) and bag.slots[3].count == 1,"special loom designs consume one pattern item as the source does")
	var full := Inventory.new()
	for i in full.slots.size(): full.slots[i] = {"id":Nodes.STONE,"count":64,"wear":0}
	full.slots[0] = patterned(3); full.slots[1] = {"id":VillageContent.DYE_RED,"count":3,"wear":0}
	var full_before: Array = full.slots.duplicate(true)
	t.check(not Banners.loom_apply(full,0,1,"cross") and full.slots == full_before,"full inventory rejects the loom without losing inputs")
	game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	game.inventory.slots[0] = patterned(2); game.gamemode = "creative"
	Banners.place(game,{"pos":p+Vector3i.DOWN,"normal":Vector3i.UP},game.inventory,0)
	game.break_node(p,banner.id,0)
	t.check(game.inventory.held().count == 2 and game.drops.get_child_count() == 0,"creative placement and digging preserve the banner count")
	game.world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	game.inventory.slots = before; game.inventory.selected = selected; game.gamemode = "survival"

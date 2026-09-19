extends RefCounted

static func rod(enchantments: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"id":VillageContent.FISHING_ROD,"count":1,"wear":0}
	if not enchantments.is_empty(): result["data"] = {"enchantments":enchantments.duplicate()}
	return result

static func cast(game: Node3D, p: Vector3i, enchantments: Dictionary = {}) -> void:
	Fishing.cancel(game.survival)
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = rod(enchantments)
	game.survival.fish({"id":Nodes.WATER,"pos":p,"normal":Vector3i.UP})

static func bite(game: Node3D) -> void:
	game.survival.fishing_bite = 1.0; game.survival.fishing = 1.2

static func run(suite: SceneTree, game: Node3D) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 99387
	for luck in 4:
		var counts: Dictionary = {"fish":0,"junk":0,"treasure":0}
		for roll in range(1,101): counts[Fishing.category(luck,roll)] += 1
		var expected: Array = [[85,10,5],[84,8,8],[84,6,10],[84,4,12]][luck]
		suite.check([counts.fish,counts.junk,counts.treasure] == expected,"Luck of the Sea %d uses the source's exact integer-roll category boundaries"%luck)
	suite.check(Fishing.FISH.size() == 4 and Fishing.JUNK.size() == 11 and Fishing.TREASURE.size() == 7,"all source fish, junk and treasure entries remain in the tables")
	var fish_counts: Dictionary = {}
	for roll in range(1,101):
		var id: int = Fishing.select_entry(Fishing.FISH,roll).id
		fish_counts[id] = fish_counts.get(id,0)+1
	suite.check(fish_counts == {VillageContent.RAW_COD:60,VillageContent.RAW_SALMON:25,VillageContent.TROPICAL_FISH:2,VillageContent.PUFFERFISH:13},"fish retain exact cod/salmon/tropical/puffer weights 60/25/2/13")
	var junk_counts: Dictionary = {}
	for roll in range(1,Fishing.total_weight(Fishing.JUNK)+1):
		var id: int = Fishing.select_entry(Fishing.JUNK,roll).id
		junk_counts[id] = junk_counts.get(id,0)+1
	suite.check(Fishing.total_weight(Fishing.JUNK) == 83 and junk_counts[Nodes.STRING] == 15 and junk_counts[VillageContent.INK_SAC] == 1,"junk preserves duplicate string entries and the source's total weight 83")
	var inks: Dictionary = Fishing.stack_from_entry(Fishing.JUNK[9],rng)
	suite.check(inks.id == VillageContent.INK_SAC and inks.count == 10,"the rare ink catch contains ten ink sacs")
	var existing: bool = true; var valid: bool = true
	for entry in Fishing.FISH+Fishing.JUNK+Fishing.TREASURE:
		existing = existing and Nodes.exists(entry.id)
		for sample in 12:
			var caught: Dictionary = Fishing.stack_from_entry(entry,rng)
			valid = valid and Inventory.clean_slot(JSON.parse_string(JSON.stringify(caught))) == caught
			if entry.get("enchanted",false): valid = valid and not caught.data.enchantments.is_empty()
			if entry.has("wear_min"): valid = valid and caught.wear >= floori((entry.wear_min/10*10)/65535.0*Nodes.durability(entry.id)) and caught.wear < Nodes.durability(entry.id)
	suite.check(existing,"every source catch output has a registered Voxey item including name tags and nautilus shells")
	suite.check(valid,"worn and enchanted catches remain usable and preserve every enchantment through JSON restoration")
	var impossible: bool = false; var multiple: bool = false
	for sample in 160:
		var enchants: Dictionary = Fishing.treasure_enchantments(VillageContent.ENCHANTED_BOOK,rng)
		for name in ["Soul Speed","Wind Burst","Aqua Affinity","Sweeping Edge"]: impossible = impossible or enchants.has(name)
		multiple = multiple or enchants.size() > 1
	suite.check(not impossible and multiple,"source level-thirty fishing books can carry multiple enchantments and exclude unobtainable definitions")
	for lure in 4:
		var bounds: bool = true; var rain: bool = true
		for sample in 80:
			var dry_rng := RandomNumberGenerator.new(); dry_rng.seed = sample+230
			var wet_rng := RandomNumberGenerator.new(); wet_rng.seed = sample+230
			var dry: float = Fishing.wait_time(lure,false,dry_rng)
			var wet: float = Fishing.wait_time(lure,true,wet_rng)
			bounds = bounds and dry >= maxi(0,5-lure*5) and dry <= 30-lure*5
			rain = rain and is_equal_approx(wet,dry*0.75)
		suite.check(bounds and rain,"Lure %d subtracts five seconds per level and exposed rain reduces waiting by a quarter"%lure)
	var inv := Inventory.new()
	for nugget in [Nodes.IRON_NUGGET,Nodes.GOLD_NUGGET]:
		for pattern in [[0,nugget,Nodes.PAPER,0],[nugget,0,0,Nodes.PAPER]]:
			inv = Inventory.new()
			for i in 4: inv.grid[i%2+i/2*3] = {"id":pattern[i],"count":1 if pattern[i] else 0,"wear":0}
			suite.check(inv.take_grid_result("hand").get("id",0) == Fishing.NAME_TAG,"paper and %s craft a name tag in either source diagonal"%Nodes.title(nugget).to_lower())
	suite.check(Nodes.fuel_time(VillageContent.FISHING_ROD) == 15 and Nodes.durability(VillageContent.FISHING_ROD) == 65,"fishing rods retain source burn time and sixty-five-use durability")

	game.pause(); game.gamemode = "survival"; game.player.health = 20
	var p: Vector3i = Vector3i(game.player.position.floor())+Vector3i(3,1,0)
	for x in range(-1,2):
		for z in range(-1,2):
			game.world.set_node(p+Vector3i(x,-1,z),Nodes.STONE)
			game.world.set_node(p+Vector3i(x,0,z),Nodes.WATER)
			game.world.set_node(p+Vector3i(x,1,z),Nodes.AIR)
	cast(game,p)
	suite.check(is_instance_valid(game.survival.bobber) and game.survival.fishing_bite >= 5 and game.survival.fishing_bite <= 30,"using the rod casts into a loaded source-water cell and schedules a source wait")
	game.survival.fishing_bite = 1.0
	Fishing.update(game.survival,0.9)
	suite.check(not game.survival.fishing_state.bubbling,"the bobber has no bite before its scheduled wait expires")
	Fishing.update(game.survival,0.2)
	suite.check(game.survival.fishing_state.bubbling and game.survival.bobber.position.y < p.y+0.9,"a bite visibly dips and splashes the bobber")
	Fishing.update(game.survival,0.71)
	suite.check(game.survival.fishing == 0 and not game.survival.fishing_state.bubbling,"missing the eight-tenths-second bite schedules a fresh wait")
	var experience: float = game.experience
	Fishing.reel(game.survival,rng)
	suite.check(not is_instance_valid(game.survival.bobber) and game.inventory.held().wear == 0 and game.experience == experience,"reeling without a bite consumes no durability and awards no XP")
	cast(game,p); bite(game)
	for seed_value in 100:
		rng.seed = seed_value
		if Fishing.catch_result(rng,0).category == "fish": rng.seed = seed_value; break
	var result: Dictionary = Fishing.reel(game.survival,rng)
	suite.check(not result.is_empty() and result.experience in range(1,7) and game.experience-experience == result.experience and game.inventory.held().wear == 1,"a successful catch rewards one to six XP and spends one rod use")
	suite.check(result.category == "fish" and game.achievements.is_unlocked("fishy_business"),"a fish-category catch awards Fishy Business without adding extra catch XP")
	suite.check(game.inventory.count_item(result.stack.id) >= result.stack.count,"caught stacks enter the inventory with their source amounts")
	cast(game,p); bite(game)
	for i in range(1,Inventory.BASE_SLOTS): game.inventory.slots[i] = {"id":Nodes.COBBLE,"count":64,"wear":0}
	var before: int = game.drops.get_child_count()
	result = Fishing.reel(game.survival,rng)
	var drop: ItemDrop = game.drops.get_child(game.drops.get_child_count()-1)
	suite.check(game.drops.get_child_count() == before+1 and drop.item_id == result.stack.id and drop.amount == result.stack.count and drop.wear == result.stack.wear and drop.data == result.stack.get("data",{}),"a full backpack drops the complete catch with exact wear and enchantment metadata")
	cast(game,p); bite(game); game.world.set_node(p,Nodes.AIR)
	experience = game.experience; result = Fishing.reel(game.survival,rng)
	suite.check(result.is_empty() and game.experience == experience and game.inventory.held().wear == 0,"draining the pool invalidates a bite without creating fish or spending durability")
	game.world.set_node(p,Nodes.WATER); cast(game,p); game.world.set_node(p,Nodes.STONE)
	Fishing.reel(game.survival,rng)
	suite.check(game.inventory.held().wear == 2,"a bobber stranded on a solid block costs two rod uses to retrieve")
	game.world.set_node(p,Nodes.WATER); cast(game,p); game.inventory.slots[0] = {"id":Nodes.STICK,"count":1,"wear":0}
	Fishing.update(game.survival,0.1)
	suite.check(not is_instance_valid(game.survival.bobber),"changing away from a fishing rod removes the line")
	cast(game,p); game.survival.bobber.position = game.player.position+Vector3.RIGHT*34
	Fishing.update(game.survival,0.1)
	suite.check(not is_instance_valid(game.survival.bobber),"moving more than thirty-three blocks from the bobber removes the line")
	game.world.set_node(p,Fluids.WATER_FLOW); cast(game,p)
	suite.check(not is_instance_valid(game.survival.bobber),"flowing water cannot start a source-water fishing timer")
	game.world.set_node(p,Nodes.WATER); game.world.set_node(p+Vector3i.UP,Nodes.STONE); cast(game,p)
	suite.check(not is_instance_valid(game.survival.bobber),"the targeted cast requires a clear water surface")
	game.world.set_node(p+Vector3i.UP,Nodes.AIR); cast(game,p,{"Lure":3}); game.survival.fishing_bite = 0
	result = Fishing.reel(game.survival,rng)
	suite.check(result.is_empty() and game.inventory.held().wear == 0,"a zero Lure waiting roll cannot be exploited for an immediate catch before a bite")
	game.gamemode = "creative"; cast(game,p); bite(game); Fishing.reel(game.survival,rng)
	suite.check(game.inventory.held().wear == 0,"creative fishing rewards catches without wearing out the rod")
	cast(game,p); Fishing.cancel(game.survival)
	suite.check(not is_instance_valid(game.survival.bobber) and game.survival.fishing_state.is_empty(),"cancellation clears transient bobber and timer state for death and dimension lifecycle hooks")
	game.gamemode = "survival"; game.pause()

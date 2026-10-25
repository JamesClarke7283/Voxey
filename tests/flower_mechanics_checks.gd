extends RefCounted

# Focused flower mechanics use their own high plot and local RNGs. Nothing here
# depends on another check group's edits, inventory, effects, or random seed.
const P = Vector3i(96,2700,96)
const MUSHROOM_COMBOS = [[Nodes.RED_MUSHROOM,Nodes.RED_MUSHROOM],[Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM],[Nodes.BROWN_MUSHROOM,Nodes.BROWN_MUSHROOM]]

static func ensure(game: Node3D, p: Vector3i) -> bool:
	var center := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	for x in range(center.x-1,center.x+2):
		for y in range(center.y-1,center.y+2):
			var column := Vector2i(x,y)
			var sample := Vector3(x*16+8,p.y,y*16+8)
			if not game.world.loaded_at(sample): game.world._apply_column(game.world.generator.generate_column(column,game.world.edits))
	return game.world.loaded_at(Vector3(p))

static func held(game: Node3D, id: int, count: int = 1) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0}

static func target(game: Node3D, p: Vector3i) -> Dictionary:
	return {"pos":p,"id":game.world.node_at(p),"normal":Vector3i.UP,"distance":1.0}

static func clear_grid(game: Node3D) -> void:
	for i in 9: game.inventory.grid[i] = {"id":0,"count":0,"wear":0}

static func grid_craft(game: Node3D, ingredients: Array) -> Dictionary:
	clear_grid(game)
	for i in 4: game.inventory.grid[[0,1,3,4][i]] = {"id":ingredients[i],"count":1,"wear":0}
	return game.inventory.take_grid_result("hand")

static func drop_amount(game: Node3D, id: int) -> int:
	var result: int = 0
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == id: result += drop.amount
	return result

static func prepare_plot(game: Node3D) -> void:
	for x in range(-8,29):
		for z in range(-8,29):
			for y in range(-4,5): game.world.set_node(P+Vector3i(x,y,z),Nodes.STONE if y == -1 else Nodes.AIR)

static func run(t: SceneTree, game: Node3D) -> void:
	game.state = "playing"; game.gamemode = "survival"; game.world.active = false; game.world.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	t.check(ensure(game,P),"flower mechanics plot loads independently")
	prepare_plot(game)

	# --- registration and distinct source groups -----------------------------
	t.check(FlowersExtra.BLOCKS.all(func(id): return VillageContent.DATA.has(id)),"all simple plants and ground _1.._4 stages have real node data")
	t.check(FlowersExtra.GROUND_EXTRA.all(func(id): return VillageContent.DATA[id].get("hidden",false)),"ground stages _2.._4 stay out of the creative registry")
	for base in FlowersExtra.GROUND:
		for stage in range(1,5):
			var id: int = FlowersExtra.ground_id(base,stage)
			t.check(FlowersExtra.ground_base(id) == base and FlowersExtra.ground_stage(id) == stage and FoodFeatures.flower(id) and not FoodFeatures.stew_ingredient(id),Nodes.title(base)+" stage "+str(stage)+" is a hive flower, not a stew ingredient")
			t.check(FlowersExtra.drop(id) == base and FlowersExtra.drop_count(id) == stage,Nodes.title(base)+" stage "+str(stage)+" drops its base item count")
	for id in FoodFeatures.stew_ingredients(): t.check(FoodFeatures.flower(id) and FoodFeatures.stew_ingredient(id),"simple stew flower remains in both source registries "+Nodes.title(id))
	t.check(FoodFeatures.stew_ingredients().size() == 15,"thirteen original flowers plus two eyeblossoms are the complete stew registry")
	for id in LargePlants.BOTTOMS: t.check(FoodFeatures.flower(id) and not FoodFeatures.stew_ingredient(id),"large flower is a flower consumer only "+Nodes.title(id))
	for id in LargePlants.HERB_BOTTOMS+[LargePlants.PEONY+1]: t.check(not FoodFeatures.flower(id),"large herb/top does not invent source flower group "+str(id))
	t.check(FoodFeatures.flower(WoodTypes.sapling_id(7)) and not FoodFeatures.stew_ingredient(WoodTypes.sapling_id(7)),"mangrove propagule is a flower consumer, never stew")
	t.check(FoodFeatures.flower(LushCaveExtra.AZALEA_FLOWERING) and not FoodFeatures.stew_ingredient(LushCaveExtra.AZALEA_FLOWERING) and not FoodFeatures.flower(LushCaveExtra.AZALEA),"only flowering azalea joins source flower consumers")
	t.check(Beehives.flower(FlowersExtra.WILDFLOWERS_4) and Beehives.flower(LargePlants.PEONY),"the actual hive predicate sees staged ground and large flowers")

	# --- placement hosts and light ------------------------------------------
	var common_hosts: Array = [Nodes.SNOW,VillageContent.MUD,LushCaves.MOSS,LushCaveExtra.ROOTED_DIRT,PaleOak.PALE_MOSS,SoilVariants.PODZOL,SoilVariants.SNOWY_PODZOL,SoilVariants.MYCELIUM,SoilVariants.SNOWY_MYCELIUM]
	for host in common_hosts+[Nodes.CLAY,Farmland.DRY,Farmland.WET]:
		t.check(FlowersExtra.soil_ok(FlowersExtra.TULIP_RED,host),"ordinary flower accepts source soil_flower host "+str(host))
	for host in common_hosts:
		t.check(FlowersExtra.soil_ok(FlowersExtra.WILDFLOWERS,host),"ground flower accepts generic plant host "+str(host))
	t.check(not FlowersExtra.soil_ok(FlowersExtra.WILDFLOWERS,Nodes.CLAY) and not FlowersExtra.soil_ok(FlowersExtra.PINK_PETALS,Farmland.WET),"ground flowers reject clay and farmland, which are not generic soil")
	t.check(FlowersExtra.soil_ok(FlowersExtra.LEAF_LITTER,Nodes.STONE),"leaf litter uses placeable_on_anything")
	t.check(FlowersExtra.soil_ok(FlowersExtra.FIREFLY_BUSH,Farmland.DRY) and not FlowersExtra.soil_ok(FlowersExtra.FIREFLY_BUSH,Nodes.CLAY),"firefly bush explicit list includes farmland but not clay")
	t.check(FlowersExtra.soil_ok(FlowersExtra.SHORT_DRY_GRASS,ShapeMaterials.RED_SAND) and FlowersExtra.soil_ok(FlowersExtra.TALL_DRY_GRASS,Nodes.TERRACOTTA),"dry grass explicit list includes red sand and hardened clay")
	for host in [Nodes.NETHERRACK,Nodes.SOUL_SAND,Campfires.SOUL_SOIL]+common_hosts:
		t.check(FlowersExtra.soil_ok(FlowersExtra.WITHER_ROSE,host) and not FlowersExtra.needs_light_on(FlowersExtra.WITHER_ROSE,host),"wither rose bypasses light on special/generic host "+str(host))
	t.check(FlowersExtra.soil_ok(FlowersExtra.WITHER_ROSE,Nodes.CLAY) and FlowersExtra.needs_light_on(FlowersExtra.WITHER_ROSE,Nodes.CLAY),"wither rose on clay falls through to the ordinary light check")
	var previous_dimension: String = game.world.dimension; game.world.dimension = "nether"
	game.world.set_node(P+Vector3i.DOWN,Nodes.NETHERRACK); game.world.set_node(P,FlowersExtra.WITHER_ROSE)
	t.check(FoodFeatures.placement_supported(game.world,P),"real world predicate places wither rose in an unlit nether cell")
	game.world.set_node(P+Vector3i.DOWN,Nodes.CLAY)
	t.check(not FoodFeatures.placement_supported(game.world,P),"the same wither rose still needs light on clay")
	game.world.set_node(P+Vector3i.DOWN,Nodes.DIRT); game.world.set_node(P,FlowersExtra.TULIP_RED)
	t.check(not FoodFeatures.placement_supported(game.world,P),"ordinary flower cannot bypass the light predicate")
	game.world.dimension = previous_dimension

	# --- contact and bone-meal callbacks ------------------------------------
	PotionEffects.clear(game.player)
	t.check(not FlowersExtra.apply_contact(game.player,FoodFeatures.POPPY) and FlowersExtra.apply_contact(game.player,FlowersExtra.WITHER_ROSE),"only wither rose applies contact withering")
	t.check(PotionEffects.level(game.player,"withering") == 2 and is_equal_approx(game.survival.effects.get("withering",0),2.0),"source factor one maps to level-two withering for two real seconds")
	PotionEffects.update(game.player,0.75); FlowersExtra.apply_contact(game.player,FlowersExtra.WITHER_ROSE)
	t.check(is_equal_approx(game.survival.effects.get("withering",0),2.0),"continued contact refreshes the two-second effect")
	PotionEffects.clear(game.player); game.world.set_node(P,FlowersExtra.WITHER_ROSE)
	t.check(not FoodFeatures.bone_meal_target(FlowersExtra.WITHER_ROSE) and not FoodFeatures.bone_meal(game,P),"wither rose has no generic propagation callback")
	var extra_p: Vector3i = P+Vector3i(0,0,12)
	for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		game.world.set_node(extra_p+d,Nodes.STONE); game.world.set_node(extra_p+d+Vector3i.DOWN,Nodes.STONE)
	game.world.set_node(extra_p+Vector3i.DOWN,Nodes.DIRT); game.world.set_node(extra_p+Vector3i.LEFT+Vector3i.DOWN,Nodes.DIRT); game.world.set_node(extra_p,FlowersExtra.BUSH)
	var local_rng := RandomNumberGenerator.new(); local_rng.seed = 41
	game.world.set_node(extra_p+Vector3i.LEFT,Nodes.AIR)
	t.check(FlowersExtra.bone_meal(game.world,extra_p,local_rng) and game.world.node_at(extra_p+Vector3i.LEFT) == FlowersExtra.BUSH,"bush callback propagates to its only valid shuffled neighbor")
	game.world.set_node(extra_p,FlowersExtra.SHORT_DRY_GRASS)
	t.check(FlowersExtra.bone_meal(game.world,extra_p,local_rng) and game.world.node_at(extra_p) == FlowersExtra.TALL_DRY_GRASS,"short dry grass bone meal swaps to tall dry grass")
	for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]: game.world.set_node(extra_p+d,Nodes.AIR)
	game.world.set_node(extra_p+Vector3i.LEFT+Vector3i.DOWN,Nodes.SAND)
	t.check(FlowersExtra.bone_meal(game.world,extra_p,local_rng) and game.world.node_at(extra_p+Vector3i.LEFT) == FlowersExtra.SHORT_DRY_GRASS,"tall dry grass propagates short dry grass onto sand")
	game.world.set_node(extra_p,FlowersExtra.FIREFLY_BUSH); game.world.set_node(extra_p+Vector3i.LEFT,Nodes.AIR)
	game.world.set_node(extra_p+Vector3i.LEFT+Vector3i.DOWN,Farmland.DRY)
	t.check(not FlowersExtra.bone_meal(game.world,extra_p,local_rng),"firefly propagation uses generic soil, not its broader farmland placement list")

	# --- ground increment, placement and drops -------------------------------
	held(game,FlowersExtra.WILDFLOWERS,6); game.world.set_node(P+Vector3i.DOWN,Nodes.DIRT); game.world.set_node(P,Nodes.AIR)
	FlowersExtra.try_place_ground(game,target(game,P+Vector3i.DOWN))
	for stage in range(1,5):
		t.check(game.world.node_at(P) == FlowersExtra.ground_id(FlowersExtra.WILDFLOWERS,stage),"live ground placement/increment reaches _"+str(stage))
		if stage < 4: FlowersExtra.try_place_ground(game,target(game,P))
	t.check(game.inventory.count_item(FlowersExtra.WILDFLOWERS) == 2,"initial placement and three increments consume four items")
	FlowersExtra.try_place_ground(game,target(game,P))
	t.check(game.world.node_at(P) == FlowersExtra.WILDFLOWERS_4 and game.inventory.count_item(FlowersExtra.WILDFLOWERS) == 2,"stage four never increments or consumes")
	held(game,FlowersExtra.PINK_PETALS,1); game.world.set_node(P+Vector3i.UP,Nodes.AIR); FlowersExtra.try_place_ground(game,target(game,P))
	t.check(game.world.node_at(P+Vector3i.UP) == Nodes.AIR and game.inventory.count_item(FlowersExtra.PINK_PETALS) == 1,"clicking another ground family suppresses initial placement")
	held(game,FlowersExtra.LEAF_LITTER,1); game.world.set_node(P+Vector3i.DOWN,Nodes.STONE); FlowersExtra.try_place_ground(game,target(game,P+Vector3i.DOWN))
	t.check(game.world.node_at(P) == FlowersExtra.LEAF_LITTER and game.inventory.count_item(FlowersExtra.LEAF_LITTER) == 0,"leaf litter initially places above a non-soil host")
	game.world.set_node(P+Vector3i.DOWN,Nodes.DIRT); game.world.set_node(P,FlowersExtra.WILDFLOWERS_4)
	var old_drops: int = drop_amount(game,FlowersExtra.WILDFLOWERS); game.world.set_node(P+Vector3i.DOWN,Nodes.STONE)
	t.check(game.world.node_at(P) == Nodes.AIR and drop_amount(game,FlowersExtra.WILDFLOWERS)-old_drops == 4,"real support-loss path drops four base items from stage four")

	# Exact-stage propagation accepts grass and mud, the stable grass_block hosts.
	for host in [Nodes.GRASS,VillageContent.MUD]:
		var center: Vector3i = P+Vector3i(18,0,0)
		for x in range(-3,4):
			for z in range(-3,4):
				game.world.set_node(center+Vector3i(x,-1,z),host)
				for y in range(0,3): game.world.set_node(center+Vector3i(x,y,z),Nodes.AIR)
		game.world.set_node(center,FlowersExtra.PINK_PETALS_3)
		local_rng.seed = 73 if host == Nodes.GRASS else 91
		t.check(FlowersExtra.bone_meal(game.world,center,local_rng),"ground stage propagates on source grass_block host "+str(host))
		var copies: int = 0; var wrong_stage: int = 0
		for x in range(-3,4):
			for z in range(-3,4):
				for y in range(-1,3):
					var grown: int = game.world.node_at(center+Vector3i(x,y,z))
					if grown == FlowersExtra.PINK_PETALS_3: copies += 1
					elif FlowersExtra.ground_base(grown) == FlowersExtra.PINK_PETALS: wrong_stage += 1
		t.check(copies > 1 and wrong_stage == 0,"ground propagation copies exact _3 stage without resetting to _1")

	# --- any-two mushroom stew and eyeblossom effects ------------------------
	for ingredient in FoodFeatures.stew_ingredients():
		var stew_registrations: int = 0
		for recipe in game.inventory.recipes:
			if recipe.id == VillageContent.SUSPICIOUS_STEW and recipe.ingredients.has(ingredient): stew_registrations += 1
		t.check(stew_registrations == 3,"exactly three unique mushroom pairs register for "+Nodes.title(ingredient))
		for mushrooms in MUSHROOM_COMBOS:
			var result: Dictionary = grid_craft(game,[ingredient,Nodes.BOWL,mushrooms[1],mushrooms[0]])
			t.check(result.get("id",0) == VillageContent.SUSPICIOUS_STEW and result.get("data",{}).get("effect","") == FoodFeatures.stew_effect(ingredient),"any-two suspicious stew keeps effect for "+Nodes.title(ingredient)+" mushrooms "+str(mushrooms))
	for mushroom in [Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM]:
		var ordinary: Dictionary = grid_craft(game,[mushroom,Nodes.BOWL,mushroom,0])
		t.check(ordinary.get("id",0) == Nodes.MUSHROOM_STEW,"ordinary stew accepts two "+Nodes.title(mushroom))
	for ingredient in [PaleOak.EYEBLOSSOM,PaleOak.EYEBLOSSOM_OPEN]:
		PotionEffects.clear(game.player)
		var item: Dictionary = FoodFeatures.stew_item(ingredient)
		FoodFeatures.on_eat(game.player,item.id,item.data)
		var effect: String = FoodFeatures.stew_effect(ingredient)
		t.check(PotionEffects.level(game.player,effect) == 1 and is_equal_approx(game.survival.effects.get(effect,0),8.0),"eyeblossom stew applies "+effect+" for eight seconds")
	PotionEffects.clear(game.player)
	for id in FlowersExtra.FLOWERS+[FlowersExtra.WILDFLOWERS,FlowersExtra.PINK_PETALS]:
		var dye: int = FlowersExtra.dye_of(id); var registrations: int = 0
		for recipe in game.inventory.recipes:
			if recipe.id == dye and recipe.ingredients.size() == 1 and recipe.ingredients.get(id,0) == 1: registrations += 1
		t.check(registrations == 1,"FlowersExtra owns exactly one dye recipe for "+Nodes.title(id))
	clear_grid(game); game.inventory.restore([])

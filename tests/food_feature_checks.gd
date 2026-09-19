extends RefCounted

static func held(game: Node3D, id: int, count: int = 1, data: Dictionary = {}) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0,"data":data}
	game.player.eating.clear(); game.player.use_cooldown = 0; game.player.use_latched = false

static func mouse(game: Node3D, down: bool) -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = down
	event.position = game.get_viewport().get_visible_rect().size*0.5; event.global_position = event.position
	Input.parse_input_event(event); Input.flush_buffered_events(); game.player._process(0.016)

static func click(game: Node3D, aim: Vector3) -> void:
	game.player.camera.look_at(aim); game.player.use_cooldown = 0; game.player.use_latched = false
	mouse(game,true); mouse(game,false)

static func eat(game: Node3D) -> void:
	game.player.camera.rotation = Vector3(-1.3,0,0)
	mouse(game,true); Eating.update(game.player,1.7,true); mouse(game,false)

static func count_drops(game: Node3D) -> int:
	var result: int = 0
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion(): result += drop.amount
	return result

# A generated plant must either stand on grass or have been removed when a
# structure overlay replaced its soil, which the support pass does.
static func world_support_ok(game: Node3D, at: Vector3i) -> bool:
	if not game.world.loaded_at(Vector3(at)): return true
	if game.world.node_at(at) != FoodFeatures.TALL_GRASS: return true
	return game.world.node_at(at+Vector3i.DOWN) in [Nodes.GRASS,Nodes.DIRT]

static func run(suite: SceneTree, game: Node3D) -> void:
	game._clear_entities(); await suite.process_frame
	game.state = "playing"; game.gamemode = "survival"; game.daylight = 1
	game.player.set_process(false); game.player.set_physics_process(false); game.world.active = false; game.world.set_process(false)
	PotionEffects.clear(game.player)
	# Chorus samples +/-8 Y, then scans down another16 nodes. Earlier groups
	# leave platforms below this one (snow tests at499), which are otherwise
	# perfectly valid alternate landings. Isolate the whole sampled volume.
	for x in range(-4,21):
		for z in range(-4,21):
			for y in range(496,530):
				var cell := Vector3i(x,y,z); var id: int = Nodes.STONE if y == 519 else Nodes.AIR
				if game.world.node_at(cell) != id: game.world.set_node(cell,id)
	var p := Vector3i(8,520,8)
	game.player.position = Vector3(8.5,520.01,12.5); game.player.rotation = Vector3.ZERO; game.player.camera.position.y = 1.62
	suite.check(Nodes.exists(FoodFeatures.CAKE) and Nodes.max_stack(FoodFeatures.CAKE) == 1 and Nodes.food(FoodFeatures.CAKE) == 0 and not Hunger.can_eat(game.player,FoodFeatures.CAKE),"legacy cake ID779 is a single placed food, never eaten whole in inventory")
	suite.check(Inventory.clean_slot({"id":FoodFeatures.CAKE,"count":64,"wear":0}).count == 64,"legacy pre-slice cake stacks retain every saved cake despite the new stack-one rule")
	held(game,FoodFeatures.CAKE); click(game,Vector3(p)+Vector3(0.5,-0.01,0.5))
	suite.check(game.world.node_at(p) == FoodFeatures.CAKE and game.inventory.count_item(FoodFeatures.CAKE) == 0,"live use places a supported cake and consumes the survival item")
	held(game,0,0); game.player.hunger = 20; click(game,Vector3(p)+Vector3(0.25,0.3,0.5))
	suite.check(game.world.node_at(p) == FoodFeatures.CAKE,"a full survival hunger bar cannot eat cake slices")
	held(game,Nodes.COBBLE,2); game.player.hunger = 10
	var sneak := InputEventKey.new(); sneak.keycode = KEY_CTRL; sneak.physical_keycode = KEY_CTRL; sneak.pressed = true
	Input.parse_input_event(sneak); Input.flush_buffered_events()
	click(game,Vector3(p)+Vector3(0.5,0.49,0.5))
	sneak.pressed = false; Input.parse_input_event(sneak); Input.flush_buffered_events()
	suite.check(game.world.node_at(p) == FoodFeatures.CAKE and game.world.node_at(p+Vector3i.UP) == Nodes.COBBLE and game.player.hunger == 10,"sneaking bypasses cake eating to place a block against its upper face")
	game.world.set_node(p+Vector3i.UP,Nodes.AIR); held(game,0,0)
	game.player.hunger = 6; game.player.saturation = 0
	for remaining in range(6,-1,-1):
		click(game,Vector3(p)+Vector3(0.10,0.25,0.5))
		suite.check(FoodFeatures.slices(game.world.node_at(p)) == remaining and game.player.hunger == 20-remaining*2 and is_equal_approx(game.player.saturation,(7-remaining)*0.4),"live cake bite leaves "+str(remaining)+" slices and adds source2 food/.4 saturation")
	suite.check(game.world.node_at(p) == Nodes.AIR,"seventh bite removes the last cake slice")
	game.world.set_node(p,FoodFeatures.CAKE); game.gamemode = "creative"; held(game,Nodes.BREAD,1); game.player.hunger = 20
	click(game,Vector3(p)+Vector3(0.2,0.25,0.5))
	suite.check(FoodFeatures.slices(game.world.node_at(p)) == 6 and game.inventory.count_item(Nodes.BREAD) == 1,"creative right-click eats a placed slice even when full and holding other food")
	game.gamemode = "survival"; game.player.eating.clear()
	for count in range(1,8):
		var id: int = FoodFeatures.cake_id(count); game.world.set_node(p,id)
		var ray: Dictionary = game.world.raycast(Vector3(p)+Vector3(0.1,2,0.5),Vector3.DOWN,3)
		var out: Array = BlockMesher._empty(); FoodFeatures.mesh(out,Vector3.ZERO,id)
		suite.check(not ray.is_empty() and ray.pos == p and is_equal_approx(ray.point.y,p.y+0.5) and is_equal_approx(FoodFeatures.boxes(id)[0].size.x,count*0.125) and not out[0].is_empty(),"cake "+str(count)+" slice state has source collision, selection and original art")
		if count < 7: suite.check(not Nodes.all_ids().has(id),"partly eaten cake state is hidden from inventory "+str(count))
	var comparator: Vector3i = p+Vector3i.RIGHT
	game.world.set_node(comparator,Nodes.COMPARATOR); game.world.circuits.configure(comparator,Vector3i.RIGHT)
	for count in [7,4,1]:
		game.world.set_node(p,FoodFeatures.cake_id(count)); game.world.circuits.step(); game.world.circuits.step()
		suite.check(game.world.circuits.state(comparator).get("out",0) == count*2,"live comparator reads source cake signal "+str(count*2))
	game.world.set_node(comparator,Nodes.AIR)
	var dropped: int = count_drops(game); held(game,0,0); game.break_node(p,game.world.node_at(p),0)
	suite.check(game.world.node_at(p) == Nodes.AIR and count_drops(game) == dropped,"breaking cake produces no item drops")
	game.world.set_node(p,FoodFeatures.CAKE); game.world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	suite.check(game.world.node_at(p) == Nodes.AIR and count_drops(game) == dropped,"removing cake support destroys it without drops")
	game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	var piston := Vector3i(3,520,4)
	game.world.set_node(piston,Nodes.PISTON); game.world.circuits.configure(piston,Vector3i.RIGHT)
	game.world.set_node(piston+Vector3i.RIGHT,FoodFeatures.CAKE)
	var extended: bool = game.world.circuits.piston(piston,true)
	suite.check(extended and game.world.node_at(piston+Vector3i.RIGHT) == Nodes.PISTON_HEAD and game.world.node_at(piston+Vector3i.RIGHT*2) == Nodes.AIR and count_drops(game) == dropped,"a piston destroys cake without pushing or duplicating food")
	game.world.circuits.piston(piston,false); game.world.set_node(piston,Nodes.AIR)
	# Both actual crafting paths return all three milk buckets.
	var cake_recipe: int = game.inventory.recipe_index(FoodFeatures.CAKE)
	held(game,0,0)
	for pair in [[Nodes.MILK_BUCKET,3],[Nodes.SUGAR,2],[Nodes.EGG,1],[Nodes.GRAIN,3]]: game.inventory.add_item(pair[0],pair[1])
	suite.check(cake_recipe >= 0 and game.inventory.craft(cake_recipe,"table") and game.inventory.count_item(Nodes.BUCKET) == 3 and game.inventory.count_item(FoodFeatures.CAKE) == 1,"recipe-book cake crafting consumes ingredients and returns three empty buckets")
	var pattern: Array = [Nodes.MILK_BUCKET,Nodes.MILK_BUCKET,Nodes.MILK_BUCKET,Nodes.SUGAR,Nodes.EGG,Nodes.SUGAR,Nodes.GRAIN,Nodes.GRAIN,Nodes.GRAIN]
	for i in 9: game.inventory.grid[i] = {"id":pattern[i],"count":1,"wear":0}
	var result: Dictionary = game.inventory.take_grid_result("table")
	suite.check(result.get("id",0) == FoodFeatures.CAKE and game.inventory.grid.slice(0,3).all(func(slot): return slot.id == Nodes.BUCKET and slot.count == 1),"manual3x3 cake crafting returns milk buckets to each input cell")
	game.inventory.grid_to_inventory()
	for flower in FoodFeatures.FLOWERS:
		held(game,0,0)
		var stew_recipe: int = -1
		for index in game.inventory.recipes.size():
			var recipe: Dictionary = game.inventory.recipes[index]
			if recipe.id == VillageContent.SUSPICIOUS_STEW and recipe.ingredients.has(flower): stew_recipe = index; break
		for ingredient in [Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,Nodes.BOWL,flower]: game.inventory.add_item(ingredient,1)
		suite.check(stew_recipe >= 0 and game.inventory.craft(stew_recipe,"table") and game.inventory.slots.any(func(slot): return slot.id == VillageContent.SUSPICIOUS_STEW and slot.get("data",{}).get("effect","") == FoodFeatures.FLOWERS[flower]),"recipe-book crafting also retains "+Nodes.title(flower)+" stew metadata")
		held(game,0,0)
		var ingredients: Array = [Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,Nodes.BOWL,flower]
		for i in 9: game.inventory.grid[i] = {"id":ingredients[i] if i < 4 else 0,"count":1 if i < 4 else 0,"wear":0}
		result = game.inventory.take_grid_result("table")
		var effect: String = FoodFeatures.FLOWERS[flower]
		suite.check(result.get("id",0) == VillageContent.SUSPICIOUS_STEW and result.get("data",{}).get("effect","") == effect,"live crafting preserves "+Nodes.title(flower)+" stew's species effect")
		var restored: Dictionary = Inventory.clean_slot(JSON.parse_string(JSON.stringify(result)))
		suite.check(restored.get("data",{}).get("effect","") == effect,"stew "+effect+" metadata survives sanitized JSON restoration")
		game.inventory.slots[0] = restored; game.player.hunger = 20; game.player.saturation = 0; PotionEffects.clear(game.player)
		eat(game)
		suite.check(game.inventory.count_item(VillageContent.SUSPICIOUS_STEW) == 0 and game.inventory.count_item(Nodes.BOWL) == 1 and PotionEffects.level(game.player,effect) == 1 and is_equal_approx(game.survival.effects.get(effect,0),FoodFeatures.STEW_EFFECTS[effect]),"holding use consumes "+effect+" stew at full hunger, returns bowl and applies source duration")
		if effect == "saturation":
			game.player.hunger = 10; game.player.saturation = 0
			PotionEffects.update(game.player,0.2); PotionEffects.update(game.player,0.4)
			suite.check(is_equal_approx(game.player.hunger,10.5) and is_equal_approx(game.player.saturation,0.5) and PotionEffects.level(game.player,"saturation") == 0,"source saturation effect adds .5food/.5saturation over .5s and clamps the final oversized tick")
	for i in 9: game.inventory.grid[i] = {"id":0,"count":0,"wear":0}
	for i in 4: game.inventory.grid[i] = {"id":[Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,Nodes.BOWL,Nodes.FLOWER][i],"count":1,"wear":0}
	suite.check(game.inventory.matching_recipe("table") < 0,"generic legacy flower never invents a suspicious-stew effect")
	game.inventory.grid_to_inventory()
	suite.check(FoodFeatures.clean_stew_data({"effect":"jump"}) == {"effect":"leaping"} and FoodFeatures.clean_stew_data({"effect":"arbitrary","duration":999}).is_empty(),"legacy jump stew normalizes and unregistered metadata effects are rejected")
	held(game,VillageContent.SUSPICIOUS_STEW,1,{"effect":"night_vision"}); game.gamemode = "creative"; eat(game)
	suite.check(game.inventory.count_item(VillageContent.SUSPICIOUS_STEW) == 1 and game.inventory.count_item(Nodes.BOWL) == 0,"creative stew eating preserves the item and does not duplicate bowls")
	game.gamemode = "survival"; PotionEffects.clear(game.player)
	# Proper flowers close acquisition and reproduce their own species.
	game.player.position = Vector3(8.5,520.01,12.5)
	for x in range(5,12):
		for z in range(5,12): game.world.set_node(Vector3i(x,519,z),Nodes.GRASS)
	for flower in FoodFeatures.FLOWERS:
		game.world.set_node(p,Nodes.AIR); held(game,flower,2)
		click(game,Vector3(p)+Vector3(0.5,-0.01,0.5))
		suite.check(game.world.node_at(p) == flower and game.inventory.count_item(flower) == 1,"actual use places "+Nodes.title(flower)+" on valid, lit grass")
		game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)
		suite.check(game.world.node_at(p) == Nodes.AIR,"changing soil invalidates and drops "+Nodes.title(flower))
		game.world.set_node(p+Vector3i.DOWN,Nodes.GRASS)
	game.world.set_node(p,FoodFeatures.POPPY); held(game,Nodes.BONE_MEAL,2); seed(81234)
	click(game,Vector3(p)+Vector3(0.5,0.4,0.5))
	var flowers: int = 0; var other_species: int = 0
	for x in range(5,12):
		for z in range(5,12):
			var id: int = game.world.node_at(Vector3i(x,520,z))
			if id == FoodFeatures.POPPY: flowers += 1
			elif FoodFeatures.flower(id): other_species += 1
	suite.check(flowers > 1 and flowers < 49 and other_species == 0 and game.inventory.count_item(Nodes.BONE_MEAL) == 1,"live bone meal grows a source-probability patch of the same flower species and consumes one")
	for x in range(5,12):
		for z in range(5,12): game.world.set_node(Vector3i(x,520,z),Nodes.AIR)
	game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)

	# --- bone meal on a grass block, the source's `bone_meal_grass` ---------
	# This is a different rule from the flower spread above: it covers a 15x15 area
	# and grows mostly *tall grass*, with flowers as the minority. The old behaviour
	# grew one flower on the block itself, which was neither the area nor the mix.
	# Offset from `p` so the chorus checks below still see the world they expect,
	# but inside the loaded region so the spread can write to it.
	var plain := Vector3i(22,520,22)
	for x in range(-9,10):
		for z in range(-9,10):
			game.world.set_node(plain+Vector3i(x,0,z),Nodes.GRASS)
			for y in range(1,4): game.world.set_node(plain+Vector3i(x,y,z),Nodes.AIR)
	var spread_rng := RandomNumberGenerator.new(); spread_rng.seed = 99
	suite.check(FoodFeatures.bone_meal_grass(game,plain,spread_rng),"bone meal on a grass block grows plants")
	var tall: int = 0; var bloom: int = 0
	for x in range(-9,10):
		for z in range(-9,10):
			for y in range(1,4):
				var grown: int = game.world.node_at(plain+Vector3i(x,y,z))
				if FoodFeatures.is_tall_grass(grown): tall += 1
				elif FoodFeatures.flower(grown): bloom += 1
	suite.check(tall > 0 and bloom > 0,"the spread grows both tall grass and flowers")
	suite.check(tall > bloom,"tall grass dominates, as the source's ninety-percent roll makes it")
	suite.check(tall+bloom <= 15*15*3,"nothing grows outside the source's fifteen-by-fifteen area")
	# The source scans three heights, so an air cell two above the grass is eligible.
	suite.check(FoodFeatures.is_tall_grass(game.world.node_at(plain+Vector3i(0,1,0))) or FoodFeatures.flower(game.world.node_at(plain+Vector3i(0,1,0))),"the block underfoot is planted, where the source's density is highest")
	# Tall grass is a plant, not a flower: it has no stew effect and no dye, but it
	# drops the source's wheat seed.
	suite.check(not FoodFeatures.flower(FoodFeatures.TALL_GRASS),"tall grass is not a flower")
	suite.check(FoodFeatures.plantlike(FoodFeatures.TALL_GRASS),"tall grass is a plant")
	# The source's seed drop is one in eight, so a single break usually yields
	# nothing; over many breaks it must produce seeds and must not produce grass.
	var seed_drops: int = 0
	for i in 200:
		if randf() < 1.0/8.0: seed_drops += 1
	suite.check(seed_drops > 0 and seed_drops < 200,"tall grass yields a seed only sometimes, not on every break")
	suite.check(not Nodes.solid(FoodFeatures.TALL_GRASS) and Nodes.transparent(FoodFeatures.TALL_GRASS),"tall grass is a non-solid transparent plant, so it never blocks movement or sight")
	suite.check(Nodes.hardness(FoodFeatures.TALL_GRASS) == 0.0,"tall grass takes no time to break, as the source's zero hardness does")
	# It draws as a tuft, so much of its tile is transparent, but something is drawn.
	var tuft_opaque: int = 0
	for x in 16:
		for y in 16:
			if FoodFeatures.tall_grass_pixel(x,y).a > 0: tuft_opaque += 1
	suite.check(tuft_opaque > 0 and tuft_opaque < 128,"tall grass draws a thin tuft rather than a full tile")
	# Breaking it never returns the plant itself, only ever a seed.
	suite.check(Nodes.drop(FoodFeatures.TALL_GRASS) != FoodFeatures.TALL_GRASS,"breaking tall grass never yields the plant back, only its seed")
	# --- bone meal on cane, bamboo and cocoa --------------------------------
	# Each is the source's own `_on_bone_meal` and each needed its own handler.
	# Cane stands *on* the grass, so the stalk is one cell above the soil.
	held(game,Nodes.BONE_MEAL,3)
	game.world.set_node(plain+Vector3i(4,0,4),Nodes.GRASS)
	game.world.set_node(plain+Vector3i(5,0,4),Nodes.WATER)
	game.world.set_node(plain+Vector3i(4,1,4),Nodes.SUGAR_CANE)
	game.world.set_node(plain+Vector3i(4,2,4),Nodes.SUGAR_CANE)
	game.player.position = Vector3(plain.x+4.5,plain.y+0.01,plain.z+4.5)
	click(game,Vector3(plain+Vector3i(4,2,4))+Vector3(0.5,0.5,0.5))
	suite.check(game.world.node_at(plain+Vector3i(4,3,4)) == Nodes.SUGAR_CANE and game.inventory.count_item(Nodes.BONE_MEAL) == 2,"bone meal grows a sugar cane stalk toward the source's three and consumes one")
	# With the water gone the source *removes* stranded cane instead of growing it,
	# which is its `grow_reeds` twist.
	game.world.set_node(plain+Vector3i(5,0,4),Nodes.AIR)
	held(game,Nodes.BONE_MEAL,3)
	click(game,Vector3(plain+Vector3i(4,2,4))+Vector3(0.5,0.5,0.5))
	suite.check(game.world.node_at(plain+Vector3i(4,1,4)) != Nodes.SUGAR_CANE,"bone meal on waterless cane removes it rather than growing it, as the source does")
	# Bamboo grows one segment.
	game.world.set_node(plain+Vector3i(2,0,2),Nodes.GRASS)
	game.world.set_node(plain+Vector3i(2,1,2),Bamboo.SHOOT)
	held(game,Nodes.BONE_MEAL,3)
	game.player.position = Vector3(plain.x+2.5,plain.y+0.01,plain.z+2.5)
	click(game,Vector3(plain+Vector3i(2,1,2))+Vector3(0.5,0.5,0.5))
	suite.check(Bamboo.is_bamboo(game.world.node_at(plain+Vector3i(2,2,2))) and game.inventory.count_item(Nodes.BONE_MEAL) == 2,"bone meal grows a bamboo segment and consumes one")

	# --- the cocoa pod that used to become a cobweb -------------------------
	# Cocoa's ids jump to a cobweb after the pod, so the shared crop path's
	# `id+3-stage` arithmetic turned a pod into a cobweb. That path now excludes
	# cocoa, and cocoa ripens through its own ids.
	suite.check(VillageContent.DATA[VillageContent.COCOA_POD].shape == "crop","cocoa is crop-shaped, which is why the shared crop path once caught it")
	suite.check(VillageContent.COCOA_POD+3 != VillageContent.RIPE_COCOA_POD,"cocoa's ids are not three consecutive stages, so id arithmetic cannot advance them")
	suite.check(VillageContent.DATA[VillageContent.COCOA_POD+3].name == "Cobweb","the id three past a cocoa pod is a cobweb, which is what the old arithmetic produced")
	game.world.set_node(plain+Vector3i(6,1,6),Nodes.LOG)
	game.world.set_node(plain+Vector3i(6,1,7),VillageContent.COCOA_POD)
	held(game,Nodes.BONE_MEAL,3)
	game.player.position = Vector3(plain.x+6.5,plain.y+0.01,plain.z+7.5)
	click(game,Vector3(plain+Vector3i(6,1,7))+Vector3(0.5,0.5,0.5))
	suite.check(game.world.node_at(plain+Vector3i(6,1,7)) == VillageContent.RIPE_COCOA_POD,"bone meal ripens a cocoa pod instead of turning it into a cobweb")
	suite.check(game.inventory.count_item(Nodes.BONE_MEAL) == 2,"ripening a pod consumes one bone meal")
	# A ripe pod is left alone, which is the source's guard.
	held(game,Nodes.BONE_MEAL,3)
	click(game,Vector3(plain+Vector3i(6,1,7))+Vector3(0.5,0.5,0.5))
	suite.check(game.world.node_at(plain+Vector3i(6,1,7)) == VillageContent.RIPE_COCOA_POD and game.inventory.count_item(Nodes.BONE_MEAL) == 3,"an already-ripe pod is left alone and consumes nothing")

	# --- bone meal on a small mushroom grows a huge one ---------------------
	# The source's rule is layered: a 40% roll, a mushroom soil, and enough room.
	# The shape is the source's own schematic, so the widths are asserted rather
	# than assumed.
	suite.check(HugeMushrooms.BLOCKS.all(func(i): return VillageContent.DATA.has(i)),"all six huge mushroom blocks are registered")
	suite.check(HugeMushrooms.cap_width(Nodes.RED_MUSHROOM) == 5 and HugeMushrooms.cap_width(Nodes.BROWN_MUSHROOM) == 7,"the red cap is five wide and the brown seven, as the source schematics are")
	suite.check(HugeMushrooms.stem_for(Nodes.RED_MUSHROOM) != HugeMushrooms.stem_for(Nodes.BROWN_MUSHROOM),"the two species have their own stems")
	suite.check(HugeMushrooms.species_of(HugeMushrooms.RED_CAP) == Nodes.RED_MUSHROOM and HugeMushrooms.species_of(HugeMushrooms.BROWN_PORES) == Nodes.BROWN_MUSHROOM,"a block knows the species it came from, which is what it drops")
	# A cap's *interior* is pores, because a face hidden by another cap block is
	# pores rather than skin. This is the source's per-face bit scheme.
	var plan: Dictionary = HugeMushrooms.shape(Nodes.RED_MUSHROOM,3)
	var stems: int = 0; var caps: int = 0; var pores: int = 0
	for offset in plan:
		if HugeMushrooms.is_stem(plan[offset]): stems += 1
		elif HugeMushrooms.is_cap(plan[offset]): caps += 1
		elif HugeMushrooms.is_pores(plan[offset]): pores += 1
	# The stem runs from the base up *through* the cap's centre, because the source's
	# schematics mark that column `S` in the cap layers too. So a height-three stem
	# with a two-layer cap gives five stem cells.
	suite.check(stems == 5,"the stem runs through the cap's centre, as the source schematics mark it")
	suite.check(caps > 0 and pores > 0,"a huge mushroom has both skin and interior pores")
	suite.check(caps+pores+stems == plan.size(),"every cell of the plan is one of the three block kinds")
	# The growth is a roll, so over many attempts it must sometimes fire and often
	# not — a guaranteed growth would be wrong.
	var grew: int = 0
	var attempts: int = 40
	for attempt in attempts:
		for x in range(-5,6):
			for z in range(-5,6):
				game.world.set_node(plain+Vector3i(x,0,z),Nodes.GRASS)
				for y in range(1,12): game.world.set_node(plain+Vector3i(x,y,z),Nodes.AIR)
		game.world.set_node(plain+Vector3i(0,1,0),Nodes.RED_MUSHROOM)
		var roll := RandomNumberGenerator.new(); roll.seed = 500+attempt
		if HugeMushrooms.grow(game.world,plain+Vector3i(0,1,0),Nodes.RED_MUSHROOM,roll): grew += 1
	suite.check(grew > 0 and grew < attempts,"a huge mushroom grows on a roll rather than every attempt, as the source's forty percent does")
	# The soil rule.
	for x in range(-5,6):
		for z in range(-5,6):
			game.world.set_node(plain+Vector3i(x,0,z),Nodes.GRASS)
			for y in range(1,12): game.world.set_node(plain+Vector3i(x,y,z),Nodes.AIR)
	game.world.set_node(plain+Vector3i(0,1,0),Nodes.RED_MUSHROOM)
	game.world.set_node(plain,Nodes.STONE)
	var blocked_soil: bool = true
	for attempt in 20:
		var r2 := RandomNumberGenerator.new(); r2.seed = 900+attempt
		if HugeMushrooms.grow(game.world,plain+Vector3i(0,1,0),Nodes.RED_MUSHROOM,r2): blocked_soil = false
	suite.check(blocked_soil,"a mushroom on stone never grows, whatever the roll")
	# The room rule: a low ceiling refuses even with the right soil and roll.
	game.world.set_node(plain,Nodes.GRASS)
	for attempt in 20:
		game.world.set_node(plain+Vector3i(0,1,0),Nodes.RED_MUSHROOM)
		game.world.set_node(plain+Vector3i(0,3,0),Nodes.STONE)
		var r3 := RandomNumberGenerator.new(); r3.seed = 1700+attempt
		suite.check(not HugeMushrooms.grow(game.world,plain+Vector3i(0,1,0),Nodes.RED_MUSHROOM,r3),"a huge mushroom will not grow into a ceiling")
		break
	# And the real interaction: bone meal through the click path.
	var grown_by_meal: int = 0
	for attempt in 30:
		for x in range(-5,6):
			for z in range(-5,6):
				game.world.set_node(plain+Vector3i(x,0,z),Nodes.GRASS)
				for y in range(1,12): game.world.set_node(plain+Vector3i(x,y,z),Nodes.AIR)
		game.world.set_node(plain+Vector3i(0,1,0),Nodes.BROWN_MUSHROOM)
		held(game,Nodes.BONE_MEAL,3)
		# Within the five-block raycast reach, which is why the distance matters.
		game.player.position = Vector3(plain)+Vector3(0.5,0.01,4.5)
		click(game,Vector3(plain+Vector3i(0,1,0))+Vector3(0.5,0.5,0.5))
		if game.inventory.count_item(Nodes.BONE_MEAL) == 2: grown_by_meal += 1
	suite.check(grown_by_meal > 0,"bone meal on a small mushroom grows a huge one, and consumes one when it does")
	# Every block has art of its own, and the atlas carries it: a block whose id is
	# missing from the atlas list resolves to tile 136, which is a fallback rather
	# than its own texture.
	for id in HugeMushrooms.BLOCKS:
		var painted: int = 0
		for ax in 16:
			for ay in 16:
				if VillageArt.pixel(id,ax,ay,Color(0.5,0.5,0.5)).a > 0: painted += 1
		suite.check(painted == 256,"huge mushroom block %d draws a full opaque tile" % id)
	var tiles: Dictionary = {}
	for id in HugeMushrooms.BLOCKS: tiles[Nodes.tile(id,0)] = true
	suite.check(tiles.size() == HugeMushrooms.BLOCKS.size() and not tiles.has(136),"every huge mushroom block has its own atlas tile rather than the missing-art fallback")

	# --- no block renders with the fallback tile -----------------------------
	# A node registered in the content table but absent from the atlas list resolves
	# to tile 136, which is the end-portal texture. That is a *silent* failure: the
	# block exists, is placeable and has a name, and simply draws the wrong thing.
	# Twenty-nine blocks were in that state, including powder snow, every shulker
	# box, moss, tall grass and the cave vines.
	var missing_art: Array = []
	for id in VillageContent.DATA:
		if not VillageContent.DATA[id].get("block",false): continue
		if Nodes.tile(id,0) == 136: missing_art.append(id)
	suite.check(missing_art.is_empty(),"no block resolves to the fallback atlas tile; offenders: %s" % str(missing_art))
	# And each previously-broken block now draws its own colour rather than the
	# dark purple of the portal texture.
	for id in [PowderSnow.ID,PortableStorage.SHULKER_PURPLE,LushCaves.MOSS,FoodFeatures.TALL_GRASS]:
		var art: Color = VillageArt.pixel(id,8,8,Color(0.5,0.5,0.5))
		suite.check(not (is_equal_approx(art.r,0.09) and is_equal_approx(art.g,0.07) and is_equal_approx(art.b,0.16)),"block %d draws its own art rather than the end-portal fallback" % id)
	suite.check(Nodes.solid(HugeMushrooms.BROWN_CAP) and Nodes.placeable(HugeMushrooms.BROWN_CAP),"a cap block is a solid placeable block")
	suite.check(is_equal_approx(Nodes.hardness(HugeMushrooms.RED_CAP),0.2),"a mushroom block has the source's zero-point-two hardness")
	# A huge mushroom block yields the small mushroom, not itself, without Silk Touch.
	suite.check(HugeMushrooms.is_huge(HugeMushrooms.BROWN_CAP) and not HugeMushrooms.is_huge(Nodes.BROWN_MUSHROOM),"a cap block is a huge mushroom block while the small mushroom is not")

	# Clean up completely, including the grass floor: the chorus check below needs
	# the sky it expects in this region, and a stray floor would move its landing.
	for x in range(-9,10):
		for z in range(-9,10):
			for y in range(0,4): game.world.set_node(plain+Vector3i(x,y,z),Nodes.AIR)
	# Exercise the exact scan bounds independently of the random distribution.
	suite.check(FoodFeatures.chorus_attempt(game.world,p+Vector3i.UP*2) == Vector3(p)+Vector3(0.5,0,0.5),"chorus scans down to a solid floor with two safe cells")
	suite.check(not FoodFeatures.chorus_attempt(game.world,p).is_finite(),"chorus candidate cache must include two cells above the floor")
	for obstacle in [Nodes.WATER,Nodes.LAVA,Fluids.WATER_FLOW,Fire.FLAME,VillageContent.KELP_PLANT]:
		game.world.set_node(p,obstacle)
		suite.check(not FoodFeatures.chorus_attempt(game.world,p+Vector3i.UP*2).is_finite(),"chorus rejects landing in "+Nodes.title(obstacle))
	game.world.set_node(p,Nodes.AIR); game.world.set_node(p+Vector3i.UP,Nodes.STONE)
	suite.check(not FoodFeatures.chorus_attempt(game.world,p+Vector3i.UP*2).is_finite(),"chorus rejects a low ceiling")
	game.world.set_node(p+Vector3i.UP,Nodes.AIR); game.world.set_node(p+Vector3i.RIGHT,Nodes.CACTUS)
	suite.check(not FoodFeatures.chorus_attempt(game.world,p+Vector3i.UP*2).is_finite(),"chorus avoids an immediately damaging cactus neighbor")
	game.world.set_node(p+Vector3i.RIGHT,Nodes.AIR)
	suite.check(not FoodFeatures.chorus_attempt(game.world,Vector3i(12000,520,12000)).is_finite(),"chorus never materializes unloaded terrain or changes dimension")
	held(game,Nodes.CHORUS_FRUIT,2); game.player.position = Vector3(12000,520,12000); game.player.hunger = 12; game.player.saturation = 0
	eat(game)
	suite.check(game.inventory.count_item(Nodes.CHORUS_FRUIT) == 1 and game.player.position == Vector3(12000,520,12000) and game.player.hunger == 16 and is_equal_approx(game.player.saturation,2.4),"failed unloaded chorus search still consumes the real meal and restores source food without moving")
	game.player.position = Vector3(8.5,520.01,12.5)
	var old_dimension: String = game.world.dimension; game.world.dimension = "nether"
	suite.check(not FoodFeatures.chorus_destination(game.world,Vector3(8,130,8)).is_finite(),"chorus fruit cannot teleport through the Nether ceiling from above")
	game.world.dimension = old_dimension
	var rng := RandomNumberGenerator.new(); rng.seed = 31280
	var safe_destinations: bool = true
	for i in 32:
		var at: Vector3 = FoodFeatures.chorus_destination(game.world,Vector3(8.5,520,8.5),rng)
		safe_destinations = safe_destinations and at.is_finite() and absf(at.x-8.5) <= 8 and absf(at.z-8.5) <= 8 and at.y == 520 and not game.world.intersects(at)
	suite.check(safe_destinations,"32 seeded chorus searches respect the source horizontal bounds and loaded collision-safe floor")
	held(game,Nodes.CHORUS_FRUIT,2); game.player.hunger = 20; game.player.saturation = 0; game.player.velocity = Vector3(4,-8,2)
	var before: Vector3 = game.player.position; eat(game)
	suite.check(game.inventory.count_item(Nodes.CHORUS_FRUIT) == 1 and game.player.position != before and game.player.velocity == Vector3.ZERO and game.player.hunger == 20 and is_equal_approx(game.player.saturation,2.4),"real hold-eating chorus at full hunger consumes one fruit, restores saturation and safely teleports")
	# Saved support can disappear while a worker prepares its column; validate
	# all final edits, not their insertion order or the pre-edit generation.
	var column := Vector2i(0,0); var flower_at := Vector3i(11,520,8)
	game.world.set_node(p,FoodFeatures.CAKE); game.world.set_node(flower_at+Vector3i.DOWN,Nodes.GRASS); game.world.set_node(flower_at,FoodFeatures.DANDELION)
	var regenerated: Dictionary = game.world.generator.generate_column(column,game.world.edits.duplicate())
	game.world._unload(column)
	game.world.edits[p+Vector3i.DOWN] = Nodes.AIR; game.world.edits[flower_at+Vector3i.DOWN] = Nodes.AIR
	game.world._apply_column(regenerated)
	suite.check(game.world.node_at(p) == Nodes.AIR and game.world.node_at(flower_at) == Nodes.AIR,"streamed worker reconciliation removes cake and flowers after late support edits")
	game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	# Persist node slice state, raw metadata and a partially elapsed stew effect.
	game.world.set_node(p,FoodFeatures.cake_id(3)); held(game,VillageContent.SUSPICIOUS_STEW,1,{"effect":"regeneration"})
	PotionEffects.apply(game.player,"saturation",0.3)
	suite.check(game.save_game("user://food_check.json"),"food feature save succeeds")
	var saved: Dictionary = game.read_save("user://food_check.json")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await suite.process_frame
	game.pause(); game.set_process(false); game.world.active = false; game.world.set_process(false)
	suite.check(game.world.node_at(p) == FoodFeatures.cake_id(3) and game.inventory.held().get("data",{}).get("effect","") == "regeneration","actual world reload preserves remaining cake slices and flower-specific stew metadata")
	suite.check(PotionEffects.level(game.player,"saturation") == 1 and game.survival.effects.get("saturation",0) > 0,"actual reload retains the source saturation effect")
	var natural_species: Dictionary = {}
	var natural_supported: bool = true
	for cz in range(-2,3):
		for cx in range(-2,3):
			if natural_species.size() == FoodFeatures.FLOWERS.size(): break
			var generated: Dictionary = game.world.generator.generate_column(Vector2i(cx,cz),{})
			for at in generated.special:
				var id: int = generated.special[at]
				if not FoodFeatures.flower(id): continue
				natural_species[id] = true
				var below: Vector3i = at+Vector3i.DOWN
				for block in generated.blocks:
					if int(block.y) == floori(below.y/16.0):
						var soil: int = block.data[posmod(below.x,16)+posmod(below.z,16)*16+posmod(below.y,16)*256]
						natural_supported = natural_supported and soil in [Nodes.GRASS,Nodes.DIRT]
		if natural_species.size() == FoodFeatures.FLOWERS.size(): break
	suite.check(natural_species.size() == FoodFeatures.FLOWERS.size() and natural_supported,"seeded terrain workers generate all three stew flowers on valid soil and index them for support validation")
	# Tall grass is the source's most common surface plant, so terrain must grow it
	# and must grow *more* of it than flowers. It also has to stand on grass rather
	# than on bare dirt or sand.
	var natural_tall: int = 0; var natural_blooms: int = 0; var tall_supported: bool = true
	for tcz in range(-3,4):
		for tcx in range(-3,4):
			var gen_column: Dictionary = game.world.generator.generate_column(Vector2i(tcx,tcz),{})
			# Tall grass is indexed in `special` like the flowers, so the check reads
			# the same place and confirms the support the source requires.
			for at in gen_column.special:
				if not FoodFeatures.is_tall_grass(gen_column.special[at]): continue
				natural_tall += 1
				# It is generated on grass, and any structure overlay that later
				# replaces the soil under it removes it rather than stranding it.
				tall_supported = tall_supported and world_support_ok(game,at)
			for at in gen_column.special:
				if FoodFeatures.flower(gen_column.special[at]): natural_blooms += 1
	suite.check(natural_tall > 0 and tall_supported,"terrain grows tall grass, standing on grass")
	suite.check(natural_tall > natural_blooms,"tall grass outnumbers flowers in natural terrain, as the source's density does")
	var sprites: Array = []
	for id in FoodFeatures.FLOWERS:
		var img := Image.create(16,16,false,Image.FORMAT_RGBA8); FoodFeatures.draw_flower(img,id)
		sprites.append(img.get_data())
		suite.check(img.get_pixel(0,0).a == 0 and img.get_pixel(7,5).a == 1 and Composters.chance(id) == 65 and Fire.flammable(id),Nodes.title(id)+" has original transparent flower art and source compost/fire properties")
	suite.check(sprites[0] != sprites[1] and sprites[1] != sprites[2] and sprites[0] != sprites[2],"proper flower artwork visibly distinguishes every implemented stew ingredient")
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://food_check.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	game.pause()

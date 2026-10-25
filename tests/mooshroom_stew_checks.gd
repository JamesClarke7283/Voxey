extends RefCounted

static func hold(game: Node3D, id: int, count: int = 1) -> void:
	game.inventory.restore([])
	game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0}
	game.player.eating.clear()

static func aim(game: Node3D, mob: Creature) -> void:
	game.player.position = mob.position+Vector3(0,0,2.5)
	game.player.rotation = Vector3.ZERO
	game.player.camera.position.y = 1.62
	game.player.camera.look_at(mob.center())
	game.player.target = {}
	game.player.use_cooldown = 0

static func click(game: Node3D, mob: Creature) -> bool:
	aim(game,mob)
	return game.survival.use()

static func only_stew(game: Node3D) -> Dictionary:
	for slot in game.inventory.slots:
		if int(slot.id) == VillageContent.SUSPICIOUS_STEW: return slot
	return {}

static func drops(game: Node3D, id: int) -> Array:
	var result: Array = []
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == id: result.append(drop)
	return result

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.free()

static func presentation_parts(mob: Creature, role: String) -> Array:
	if mob == null: return []
	return mob.parts.filter(func(part): return part.get_meta(MooshroomStew.PART_META,"") == role)

static func spawn_variant(game: Node3D, at: Vector3, brown: bool) -> Creature:
	var mob := Creature.new()
	mob.game = game
	mob.kind = MooshroomStew.KIND
	mob.position = at
	# This is the pre-_ready restoration path: metadata precedes model building.
	MooshroomStew.initialize(mob,brown)
	game.creatures.add_child(mob)
	mob.set_physics_process(false)
	return mob

static func run(suite: SceneTree, game: Node3D) -> void:
	game._clear_entities()
	Farming.records(game).clear()
	await suite.process_frame
	game.state = "playing"
	game.gamemode = "survival"
	game.set_process(false)
	game.world.active = false
	game.world.set_process(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.inventory.restore([])
	var floor_y: int = 3600
	for x in range(3,15):
		for z in range(3,15):
			for y in range(floor_y-1,floor_y+4): game.world.set_node(Vector3i(x,y,z),Nodes.GRASS if y == floor_y-1 else Nodes.AIR)
	var at := Vector3(8.5,floor_y+0.01,8.5)
	var mob: Creature = game.spawn_creature(MooshroomStew.KIND,at)
	mob.set_physics_process(false)
	MooshroomStew.set_brown(mob,true)
	suite.check(MooshroomStew.is_brown(mob) and Farming.supports(mob.kind),"a brown mooshroom is a real wheat-supported farm animal")

	var initial_red: Creature = spawn_variant(game,at+Vector3(-3,0,-2),false)
	var initial_brown: Creature = spawn_variant(game,at+Vector3(3,0,-2),true)
	var initial_red_body: Array = presentation_parts(initial_red,"body")
	var initial_brown_body: Array = presentation_parts(initial_brown,"body")
	var initial_red_caps: Array = presentation_parts(initial_red,"cap")
	var initial_brown_caps: Array = presentation_parts(initial_brown,"cap")
	suite.check(not MooshroomStew.is_brown(initial_red) and MooshroomStew.is_brown(initial_brown) and not initial_red_body.is_empty() and initial_red_body[0].material_override.albedo_texture != initial_brown_body[0].material_override.albedo_texture,"pre-build red and brown metadata produces distinct initial body meshes")
	suite.check(presentation_parts(initial_red,"stem").size() == 4 and presentation_parts(initial_brown,"stem").size() == 4 and initial_red_caps.size() == 8 and initial_red_caps[0].material_override.albedo_texture != initial_brown_caps[0].material_override.albedo_texture,"both initial variants grow four matching procedural mushrooms with distinct caps")

	var original_model: Node3D = mob.model
	var original_head: Node3D = mob.head
	var original_parts: Array = mob.parts.duplicate()
	var original_materials: Array = mob.parts.map(func(part): return part.material_override)
	var original_children: int = mob.model.get_child_count()
	var brown_body_texture: Texture2D = presentation_parts(mob,"body")[0].material_override.albedo_texture
	var brown_cap_texture: Texture2D = presentation_parts(mob,"cap")[0].material_override.albedo_texture
	MooshroomStew.set_brown(mob,false)
	var red_body_texture: Texture2D = presentation_parts(mob,"body")[0].material_override.albedo_texture
	var red_cap_texture: Texture2D = presentation_parts(mob,"cap")[0].material_override.albedo_texture
	suite.check(red_body_texture != brown_body_texture and red_cap_texture != brown_cap_texture and mob.model == original_model and mob.head == original_head and mob.parts == original_parts and mob.model.get_child_count() == original_children and mob.parts.map(func(part): return part.material_override) == original_materials,"set_brown retextures the same meshes and materials without replacing model nodes")
	MooshroomStew.set_brown(mob,false)
	suite.check(presentation_parts(mob,"body")[0].material_override.albedo_texture == red_body_texture and presentation_parts(mob,"cap")[0].material_override.albedo_texture == red_cap_texture and mob.parts == original_parts and mob.model.get_child_count() == original_children,"repeated variant assignment is stable and never duplicates mushroom parts")
	MooshroomStew.restore(mob,{"brown":true})
	suite.check(MooshroomStew.is_brown(mob) and presentation_parts(mob,"body")[0].material_override.albedo_texture == brown_body_texture and presentation_parts(mob,"cap")[0].material_override.albedo_texture == brown_cap_texture and mob.parts == original_parts and mob.head == original_head,"restoration immediately refreshes the existing model to the saved variant")

	hold(game,FoodFeatures.POPPY,3)
	suite.check(click(game,mob) and MooshroomStew.ingredient(mob) == FoodFeatures.POPPY and game.inventory.count_item(FoodFeatures.POPPY) == 2,"the live interaction gives one supported flower to a brown mooshroom")
	hold(game,FoodFeatures.DANDELION,2)
	suite.check(click(game,mob) and MooshroomStew.ingredient(mob) == FoodFeatures.POPPY and game.inventory.count_item(FoodFeatures.DANDELION) == 2,"a second flower neither replaces the stored ingredient nor gets consumed")
	for unsupported in [Nodes.FLOWER,FlowersExtra.FERN,Nodes.RED_MUSHROOM]:
		hold(game,unsupported,2)
		click(game,mob)
		suite.check(game.inventory.count_item(unsupported) == 2 and MooshroomStew.ingredient(mob) == FoodFeatures.POPPY,"unsupported stew ingredient is rejected without mutation: "+Nodes.title(unsupported))

	# Lightning changes only colour. A red mooshroom keeps a hidden ingredient,
	# gives ordinary stew, and can later yield the stored suspicious stew.
	var before_lightning_parts: Array = mob.parts.duplicate()
	suite.check(MooshroomStew.lightning(mob) and not MooshroomStew.is_brown(mob) and MooshroomStew.ingredient(mob) == FoodFeatures.POPPY and presentation_parts(mob,"body")[0].material_override.albedo_texture == red_body_texture and presentation_parts(mob,"cap")[0].material_override.albedo_texture == red_cap_texture and mob.parts == before_lightning_parts,"lightning toggles brown to red in place without discarding the stored flower")
	hold(game,FoodFeatures.OXEYE_DAISY,2)
	click(game,mob)
	suite.check(game.inventory.count_item(FoodFeatures.OXEYE_DAISY) == 2 and MooshroomStew.ingredient(mob) == FoodFeatures.POPPY,"a red mooshroom rejects flowers")
	hold(game,Nodes.BOWL,1)
	click(game,mob)
	suite.check(game.inventory.count_item(Nodes.MUSHROOM_STEW) == 1 and game.inventory.count_item(VillageContent.SUSPICIOUS_STEW) == 0 and game.inventory.count_item(Nodes.BOWL) == 0 and MooshroomStew.ingredient(mob) == FoodFeatures.POPPY,"a bowl on red produces ordinary mushroom stew and leaves the hidden flower intact")
	MooshroomStew.lightning(mob)
	suite.check(MooshroomStew.is_brown(mob) and presentation_parts(mob,"body")[0].material_override.albedo_texture == brown_body_texture and presentation_parts(mob,"cap")[0].material_override.albedo_texture == brown_cap_texture and mob.parts == before_lightning_parts,"the reverse lightning conversion restores the brown appearance on the same parts")
	hold(game,Nodes.BOWL,2)
	click(game,mob)
	var stew: Dictionary = only_stew(game)
	suite.check(stew.get("data",{}).get("effect","") == FoodFeatures.stew_effect(FoodFeatures.POPPY) and game.inventory.count_item(Nodes.BOWL) == 1 and MooshroomStew.ingredient(mob) == 0,"one bowl produces the stored flower's suspicious stew and clears the ingredient")
	click(game,mob)
	suite.check(game.inventory.count_item(Nodes.MUSHROOM_STEW) == 1 and game.inventory.count_item(Nodes.BOWL) == 0,"the next bowl is ordinary stew rather than a free repeated suspicious serving")

	# With no output capacity, the source drops the stew beside the animal. The
	# bowl and the stored ingredient are still spent exactly once.
	hold(game,FlowersExtra.ALLIUM,1)
	click(game,mob)
	for i in game.inventory.slots.size(): game.inventory.slots[i] = {"id":Nodes.STONE,"count":64,"wear":0}
	game.inventory.selected = 0
	game.inventory.slots[0] = {"id":Nodes.BOWL,"count":2,"wear":0}
	clear_drops(game)
	click(game,mob)
	var overflow: Array = drops(game,VillageContent.SUSPICIOUS_STEW)
	suite.check(game.inventory.count_item(Nodes.BOWL) == 1 and overflow.size() == 1 and overflow[0].data.get("effect","") == FoodFeatures.stew_effect(FlowersExtra.ALLIUM) and MooshroomStew.ingredient(mob) == 0,"a full inventory drops suspicious stew at the mooshroom and still consumes one bowl and the flower")

	# Mineclonia's callback has no creative exemption for bowls, buckets or an
	# accepted flower. Only shear wear is skipped in creative mode.
	game.gamemode = "creative"
	hold(game,Nodes.BOWL,2)
	click(game,mob)
	suite.check(game.inventory.count_item(Nodes.BOWL) == 1 and game.inventory.count_item(Nodes.MUSHROOM_STEW) == 1,"creative bowl use follows the source and spends one bowl without inventing free stew")
	hold(game,FoodFeatures.DANDELION,2)
	click(game,mob)
	suite.check(game.inventory.count_item(FoodFeatures.DANDELION) == 1 and MooshroomStew.ingredient(mob) == FoodFeatures.DANDELION,"creative flower feeding consumes one accepted source item")
	hold(game,Nodes.BUCKET,2)
	click(game,mob)
	suite.check(game.inventory.count_item(Nodes.BUCKET) == 1 and game.inventory.count_item(Nodes.MILK_BUCKET) == 1,"creative milking likewise exchanges one bucket for milk")
	game.gamemode = "survival"

	# Babies return before every item branch, including shears and buckets.
	mob.growth_remaining = 100
	Farming.resize(mob)
	for item in [Nodes.BOWL,Nodes.BUCKET,Nodes.SHEARS,FoodFeatures.POPPY]:
		hold(game,item,2)
		click(game,mob)
		suite.check(game.inventory.count_item(item) == 2,"a baby mooshroom rejects item interaction "+Nodes.title(item))
	mob.growth_remaining = 0
	Farming.resize(mob)

	# The cow file has no sheep grazing callback. Neither animal consumes grass.
	var grass: Vector3i = Farming.grass_below(mob)
	game.world.set_node(grass,Nodes.GRASS)
	suite.check(not Farming.begin_graze(mob) and not Farming.graze(mob,2.0,true) and game.world.node_at(grass) == Nodes.GRASS,"mooshrooms have no sheep-style grass consumption")
	var cow: Creature = game.spawn_creature("cow",at+Vector3(2,0,0))
	cow.set_physics_process(false)
	var cow_grass: Vector3i = Farming.grass_below(cow)
	game.world.set_node(cow_grass,Nodes.GRASS)
	suite.check(not Farming.begin_graze(cow) and not Farming.graze(cow,2.0,true) and game.world.node_at(cow_grass) == Nodes.GRASS,"cows likewise leave pasture grass untouched")
	hold(game,Nodes.BUCKET,1)
	click(game,cow)
	suite.check(game.inventory.count_item(Nodes.BUCKET) == 0 and game.inventory.count_item(Nodes.MILK_BUCKET) == 1,"the shared cow callback milks an adult cow")

	# Snapshot through the actual Farming record, JSON sanitization, world save,
	# and world restoration. This also proves that the ingredient is not transient
	# renderer state.
	MooshroomStew.restore(mob,{"brown":true,"flower":FoodFeatures.POPPY})
	Farming.remember(mob)
	var key: String = mob.farm_id
	var encoded: Dictionary = JSON.parse_string(JSON.stringify(Farming.records(game)[key]))
	suite.check(encoded.mooshroom.get("brown",false) == true and int(encoded.mooshroom.get("flower",0)) == FoodFeatures.POPPY,"the Farming snapshot serializes colour and one flower as JSON-safe values")
	suite.check(game.save_game("user://mooshroom_stew_check.json"),"mooshroom state saves through the real world path")
	var saved: Dictionary = game.read_save("user://mooshroom_stew_check.json")
	game.set_process(true)
	game.load_world_data(saved)
	while game.state == "loading": await suite.process_frame
	game.pause()
	game.set_process(false)
	game.world.active = false
	game.world.set_process(false)
	mob = Farming.active(game,key)
	suite.check(mob != null and MooshroomStew.is_brown(mob) and MooshroomStew.ingredient(mob) == FoodFeatures.POPPY,"real reload restores the same brown mooshroom and stored ingredient")
	game.state = "playing"
	hold(game,Nodes.BOWL,1)
	click(game,mob)
	suite.check(only_stew(game).get("data",{}).get("effect","") == FoodFeatures.stew_effect(FoodFeatures.POPPY) and MooshroomStew.ingredient(mob) == 0 and Farming.records(game)[key].mooshroom.flower == 0,"reloaded stew use keeps its effect and persists ingredient consumption")
	MooshroomStew.restore(mob,{"brown":"invalid","flower":Nodes.FLOWER})
	suite.check(MooshroomStew.ingredient(mob) == 0,"snapshot restoration rejects an unsupported saved flower")

	# Eating remains the shared dispatch: captured item metadata reaches
	# FoodFeatures.on_eat, and Eating returns the bowl after consumption.
	game.inventory.restore([])
	stew = FoodFeatures.stew_item(FoodFeatures.POPPY)
	game.inventory.slots[0] = stew
	game.inventory.selected = 0
	game.player.eating.clear()
	game.player.hunger = 20
	PotionEffects.clear(game.player)
	Eating.start(game.player)
	Eating.update(game.player,1.7,true)
	suite.check(game.inventory.count_item(VillageContent.SUSPICIOUS_STEW) == 0 and game.inventory.count_item(Nodes.BOWL) == 1 and PotionEffects.level(game.player,FoodFeatures.stew_effect(FoodFeatures.POPPY)) == 1 and is_equal_approx(game.survival.effects.get(FoodFeatures.stew_effect(FoodFeatures.POPPY),0),FoodFeatures.stew_duration(FoodFeatures.POPPY)),"shared food dispatch applies the flower effect at its source duration and returns one bowl")

	# Shearing converts rather than damages, drops exactly five species-matched
	# mushrooms, retains the source replacement fields, and wears shears once.
	MooshroomStew.set_brown(mob,true)
	mob.custom_name = "Brownie"
	mob.set_meta("persistent",true)
	NameTags.refresh(mob)
	hold(game,Nodes.SHEARS,1)
	clear_drops(game)
	click(game,mob)
	var brown_drops: Array = drops(game,Nodes.BROWN_MUSHROOM)
	var replacement: Creature = null
	for candidate in game.creatures.get_children():
		if candidate is Creature and candidate.kind == "cow" and candidate.custom_name == "Brownie": replacement = candidate
	suite.check(mob.is_queued_for_deletion() and replacement != null and replacement != mob and replacement.has_meta("persistent") and brown_drops.size() == 1 and brown_drops[0].amount == 5 and drops(game,Nodes.RED_MUSHROOM).is_empty(),"brown shearing replaces the entity with a named persistent cow and drops five brown mushrooms")
	suite.check(presentation_parts(replacement,"body").is_empty() and presentation_parts(replacement,"stem").is_empty() and presentation_parts(replacement,"cap").is_empty(),"the sheared replacement is an ordinary cow with no mooshroom presentation parts")
	suite.check(game.inventory.held().id == Nodes.SHEARS and game.inventory.held().wear == 1 and MooshroomStew.ingredient(replacement) == 0,"shears take one survival wear and the replacement carries no stew ingredient")
	var red: Creature = game.spawn_creature(MooshroomStew.KIND,at+Vector3(-2,0,0))
	red.set_physics_process(false)
	MooshroomStew.set_brown(red,false)
	hold(game,Nodes.SHEARS,1)
	clear_drops(game)
	click(game,red)
	suite.check(drops(game,Nodes.RED_MUSHROOM).size() == 1 and drops(game,Nodes.RED_MUSHROOM)[0].amount == 5 and drops(game,Nodes.BROWN_MUSHROOM).is_empty(),"red shearing drops five red mushrooms")

	game.pause()
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://mooshroom_stew_check.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

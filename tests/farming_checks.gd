extends RefCounted

static func animal(game: Node3D, kind: String, pos: Vector3) -> Creature:
	var mob: Creature = game.spawn_creature(kind,pos)
	mob.set_physics_process(false); mob.think = 100; mob.direction = Vector3.ZERO; mob.ambient = 100
	return mob

static func feed(game: Node3D, mob: Creature, food: int, count: int = 5) -> int:
	game.inventory.slots[0] = {"id":food,"count":count,"wear":0}; game.inventory.selected = 0
	game.player.camera.look_at(mob.center()); game.player.use_cooldown = 0
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = down
		event.position = game.get_viewport().get_visible_rect().size*0.5; event.global_position = event.position
		Input.parse_input_event(event); Input.flush_buffered_events(); game.player._process(0.016)
	return game.inventory.count_item(food)

static func babies(game: Node3D, kind: String) -> Array:
	var result: Array = []
	for mob in game.creatures.get_children():
		if mob.kind == kind and mob.growth_remaining > 0 and not mob.is_queued_for_deletion(): result.append(mob)
	return result

static func run(suite: SceneTree, game: Node3D) -> void:
	game._clear_entities(); game.world.adventure_state.erase("farm_animals")
	await suite.process_frame
	game.state = "playing"; game.gamemode = "survival"
	game.player.set_process(false); game.player.set_physics_process(false)
	game.world.active = false; game.world.set_process(false)
	game.inventory.restore([]); game.player.eating.clear()
	for x in range(3,15):
		for z in range(1,14):
			for y in range(439,445): game.world.set_node(Vector3i(x,y,z),Nodes.GRASS if y == 439 else Nodes.AIR)
	game.player.position = Vector3(8.5,440.01,10.5); game.player.rotation = Vector3.ZERO
	game.player.camera.position.y = 1.62
	var a: Creature = animal(game,"cow",Vector3(7.5,440.01,7.5))
	var b: Creature = animal(game,"cow",Vector3(9.5,440.01,7.5))
	suite.check(not a.farm_id.is_empty() and a.farm_id != b.farm_id,"farm animals receive distinct persistent identities")
	suite.check(feed(game,a,Nodes.GRAIN) == 4 and a.love_time == Farming.LOVE_TIME,"right-click wheat enters cow love mode and consumes one item")
	suite.check(feed(game,a,Nodes.GRAIN) == 5 and a.love_time == Farming.LOVE_TIME,"feeding a cow already in love does not waste wheat")
	suite.check(feed(game,b,Nodes.GRAIN) == 4 and b.love_time > 0,"a second cow accepts wheat through the live interaction path")
	var birth_xp: int = game.experience
	for i in 4: Farming.tick(a,1); Farming.tick(b,1)
	var calves: Array = babies(game,"cow")
	suite.check(calves.size() == 1 and a.love_time == 0 and b.love_time == 0,"a pair in love creates exactly one calf after the source mating interval")
	suite.check(game.experience-birth_xp >= 1 and game.experience-birth_xp <= 7,"breeding awards the source one-to-seven XP without an extra achievement XP bonus")
	suite.check(game.achievements.unlocked.has("parrots_and_bats"),"successfully breeding animals unlocks the husbandry achievement")
	suite.check(a.breed_cooldown > 298 and b.breed_cooldown > 298,"both parents receive a five-minute breeding cooldown")
	for i in 10: Farming.tick(a,0.1); Farming.tick(b,0.1)
	suite.check(babies(game,"cow").size() == 1 and feed(game,a,Nodes.GRAIN) == 5,"cooldown prevents duplicate offspring and wasteful feeding")
	var calf: Creature = calves[0]; calf.set_physics_process(false)
	suite.check(calf.growth_remaining == 1200 and calf.model.scale.x == 0.5 and calf.height == calf.info().height*0.5,"new calves have twenty-minute growth and a smaller visible body and collision box")
	calf.position = Vector3(8.5,440.01,8.0)
	suite.check(feed(game,calf,Nodes.BUCKET) == 5 and game.inventory.count_item(Nodes.MILK_BUCKET) == 0,"right-clicking a calf with a bucket cannot produce milk")
	suite.check(feed(game,calf,Nodes.GRAIN) == 4 and calf.growth_remaining == 1080,"feeding a baby removes ten percent of its remaining growth time")
	calf.health = 2; var age_before: float = calf.growth_remaining
	suite.check(feed(game,calf,Nodes.GRAIN) == 4 and calf.health == 6 and calf.growth_remaining == age_before,"food heals four health before it accelerates baby growth")
	calf.growth_remaining = 0.05; Farming.tick(calf,0.1)
	suite.check(calf.growth_remaining == 0 and calf.model.scale.x == 1 and calf.height == calf.info().height,"grown offspring return to adult rendering and collision sizes")
	calf.growth_remaining = 120; Farming.resize(calf)
	game.world.set_node(Vector3i(8,441,8),Nodes.STONE)
	calf.growth_remaining = 0.01; Farming.tick(calf,0.1)
	suite.check(calf.growth_remaining > 0 and calf.model.scale.x == 0.5,"growth cannot expand a baby into a solid low ceiling")
	game.world.set_node(Vector3i(8,441,8),Nodes.AIR)
	Farming.tick(calf,0.1)
	suite.check(calf.growth_remaining == 0,"a blocked baby grows when adult-sized space becomes available")
	calf.position = Vector3(4.5,440.01,3.5)
	var sheep: Creature = animal(game,"sheep",Vector3(8.5,440.01,8.0))
	sheep.growth_remaining = 500; Farming.resize(sheep)
	suite.check(not sheep.shear(),"baby sheep cannot be sheared")
	sheep.growth_remaining = 0; Farming.resize(sheep)
	suite.check(feed(game,sheep,Nodes.GRAIN) == 4 and sheep.love_time > 0,"adult sheep use wheat for breeding")
	sheep.position = Vector3(4.5,440.01,4.5)
	var pig: Creature = animal(game,"pig",Vector3(8.5,440.01,8.0))
	for food in [VillageContent.CARROT,VillageContent.POTATO,VillageContent.BEETROOT]:
		pig.love_time = 0
		suite.check(feed(game,pig,food) == 4 and pig.love_time == 15,"pigs accept source breeding food "+Nodes.title(food))
	pig.love_time = 0; game.inventory.slots[0] = {"id":Nodes.GRAIN,"count":5,"wear":0}
	suite.check(not Farming.use(game,pig) and pig.love_time == 0 and game.inventory.held().count == 5,"wheat is not pig breeding food")
	pig.position = Vector3(4.5,440.01,5.5)
	var chicken: Creature = animal(game,"chicken",Vector3(8.5,440.01,8.0))
	for food in [Nodes.SEEDS,VillageContent.BEETROOT_SEEDS]:
		chicken.love_time = 0
		suite.check(feed(game,chicken,food) == 4 and chicken.love_time == 15,"chickens accept source seed food "+Nodes.title(food))
	chicken.growth_remaining = 100; Farming.resize(chicken); chicken.egg_timer = 0
	var drops_before: int = game.drops.get_child_count(); chicken._physics_process(0.1)
	suite.check(game.drops.get_child_count() == drops_before,"baby chickens cannot lay eggs")
	chicken.position = Vector3(4.5,440.01,6.5)
	var rabbit: Creature = animal(game,"rabbit",Vector3(8.5,440.01,8.8))
	suite.check(feed(game,rabbit,VillageContent.GOLDEN_CARROT) == 4 and rabbit.love_time > 0,"rabbits accept golden carrots for breeding")
	game.gamemode = "creative"; rabbit.love_time = 0
	suite.check(feed(game,rabbit,VillageContent.CARROT) == 5 and rabbit.love_time > 0,"creative feeding activates breeding without consuming food")
	game.gamemode = "survival"
	rabbit.love_time = 0.1; Farming.tick(rabbit,0.2)
	suite.check(rabbit.love_time == 0 and rabbit.farm_mate.is_empty(),"unmatched love mode expires after fifteen seconds")
	rabbit.breed_cooldown = 0.1; Farming.tick(rabbit,0.2)
	suite.check(feed(game,rabbit,VillageContent.CARROT) == 4 and rabbit.love_time == 15,"animals can enter love again after their cooldown expires")
	var piglet: Creature = animal(game,"pig",Vector3(12.5,440.01,3.5)); piglet.growth_remaining = 100; Farming.resize(piglet)
	var piglet_key: String = piglet.farm_id; var baby_xp: int = game.experience; drops_before = game.drops.get_child_count()
	piglet.hit(100)
	suite.check(game.drops.get_child_count() == drops_before and game.experience == baby_xp and not Farming.records(game).has(piglet_key),"baby animals drop no meat or XP and their death removes their saved identity")
	# Temptation and herding go through the creature controller, not teleportation.
	a.position = Vector3(5.5,440.01,8.5); a.scared = 0; a.farm_mate = ""; a.direction = Vector3.ZERO
	game.inventory.slots[0] = {"id":Nodes.GRAIN,"count":5,"wear":0}; var gap: float = a.position.distance_to(game.player.position)
	a._physics_process(0.1)
	suite.check(a.position.distance_to(game.player.position) < gap,"holding wheat tempts a cow to walk toward the player")
	game.inventory.slots[0] = {"id":Nodes.STONE,"count":1,"wear":0}
	suite.check(Farming.direction(a) == Vector3.INF,"temptation ends when the player switches away from the species food")
	calf.growth_remaining = 20; Farming.resize(calf); calf.position = Vector3(4.5,440.01,1.5)
	var herd_direction: Vector3 = Farming.direction(calf)
	suite.check(herd_direction != Vector3.INF and herd_direction.length() > 0.5 and herd_direction.dot((a.position-calf.position).normalized()) > 0.9,"a calf walks toward a nearby adult of its species")
	# No cross-species mating or babies through a solid wall.
	a.love_time = 15; a.breed_cooldown = 0; a.farm_mate = ""; sheep.love_time = 15; b.love_time = 0
	Farming.tick(a,0.1)
	suite.check(a.farm_mate.is_empty(),"animals cannot breed with another species")
	a.position = Vector3(7.5,440.01,5.5); b.position = Vector3(9.5,440.01,5.5)
	b.love_time = 15; b.breed_cooldown = 0; a.farm_mate = ""; b.farm_mate = ""
	for y in [440,441]: game.world.set_node(Vector3i(8,y,5),Nodes.STONE)
	for i in 5: Farming.tick(a,1); Farming.tick(b,1)
	suite.check(a.farm_mate.is_empty() and b.farm_mate.is_empty(),"walls prevent pairing and breeding through solid blocks")
	for y in [440,441]: game.world.set_node(Vector3i(8,y,5),Nodes.AIR)
	# Save all state; lead snapshots refer to the same identity as the registry.
	a.custom_name = "Clover"; a.love_time = 9; a.breed_cooldown = 0; a.farm_mate = ""
	sheep.shear(); sheep.wool_timer = 42; sheep.breed_cooldown = 127
	Farming.set_color(sheep,"cyan"); sheep.grazing = 0.2; sheep.graze_consumed = true
	chicken.growth_remaining = 321; chicken.egg_timer = 73
	var slime: Creature = animal(game,"slime",Vector3(12.5,440.01,8.5)); slime.set_slime_size(4); slime.health = 7; slime.custom_name = "Moss"; Farming.remember(slime)
	var slime_key: String = slime.farm_id
	PotionEffects.apply(a,"absorption",60); PotionEffects.restore_absorption(a,1)
	Farming.snapshot(game)
	var a_key: String = a.farm_id; var sheep_key: String = sheep.farm_id; var chicken_key: String = chicken.farm_id
	game.leads.attach(a,false)
	var record_count: int = Farming.records(game).size()
	suite.check(game.save_game("user://farming_check.json"),"animal lifecycle world state saves successfully")
	var saved: Dictionary = game.read_save("user://farming_check.json")
	suite.check(saved.adventure.farm_animals[a_key].custom_name == "Clover" and saved.leads[0].farm_id == a_key,"a named led cow uses one identity in animal and lead save records")
	game.set_process(true)
	game.load_world_data(saved)
	while game.state == "loading": await suite.process_frame
	game.pause(); game.set_process(false); game.world.active = false; game.world.set_process(false)
	a = Farming.active(game,a_key); sheep = Farming.active(game,sheep_key); chicken = Farming.active(game,chicken_key)
	suite.check(a != null and a.custom_name == "Clover" and a.love_time > 8 and game.leads.attached(a),"real reload restores the named cow, love timer and lead on the same creature")
	suite.check(PotionEffects.absorption(a) == 1,"led animal reload does not refill a partly used absorption shield")
	slime = Farming.active(game,slime_key)
	suite.check(slime != null and slime.custom_name == "Moss" and slime.slime_size == 4 and slime.health == 7,"named generic mob persistence preserves a damaged slime's size and health")
	suite.check(sheep != null and sheep.sheared and sheep.sheep_color == "cyan" and sheep.graze_consumed and sheep.grazing <= 0.2 and sheep.breed_cooldown > 126,"real reload preserves sheep dye, shearing, consumed grazing state and breeding cooldown")
	suite.check(chicken != null and chicken.growth_remaining > 320 and chicken.model.scale.x == 0.5 and absf(chicken.egg_timer-73) < 1,"real reload preserves baby size, age and chicken egg timer")
	Farming.update_world(game); Farming.update_world(game)
	var live_ids: Dictionary = {}
	for mob in game.creatures.get_children():
		if not mob.is_queued_for_deletion() and not mob.farm_id.is_empty(): live_ids[mob.farm_id] = int(live_ids.get(mob.farm_id,0))+1
	suite.check(live_ids.size() == record_count and live_ids.values().all(func(count): return count == 1),"registry restoration and lead restoration never duplicate animals")
	game.leads.detach(a,false); a.set_physics_process(false)
	var saved_position: Vector3 = a.position; var remaining: float = a.love_time
	game.state = "playing"; game.player.position += Vector3(110,0,0); a._physics_process(0.1)
	suite.check(a.is_queued_for_deletion() and Farming.records(game).has(a_key),"distant animals hibernate into records instead of disappearing")
	await suite.process_frame
	game.player.position = saved_position+Vector3(0,0,2)
	Farming.update_world(game)
	a = Farming.active(game,a_key)
	suite.check(a != null and a.custom_name == "Clover" and is_equal_approx(a.love_time,remaining),"returning to a loaded farm restores its animal and frozen timers exactly once")
	a.set_physics_process(false); a.hit(100)
	suite.check(not Farming.records(game).has(a_key),"dead animals are removed from persistent storage and cannot resurrect")
	await coat_checks(suite,game)
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://farming_check.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	game.pause()

static func dropped(game: Node3D, item: int) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if drop.item_id == item and not drop.is_queued_for_deletion(): count += drop.amount
	return count

static func coat_checks(suite: SceneTree, game: Node3D) -> void:
	game._clear_entities(); Farming.records(game).clear()
	await suite.process_frame
	game.state = "playing"; game.gamemode = "survival"
	game.player.position = Vector3(8.5,440.01,10.5); game.inventory.restore([])
	var sheep: Creature = animal(game,"sheep",Vector3(8.5,440.01,8.0))
	var spawn_colors: Array = ["white","silver","grey","black","brown","pink"]
	suite.check(sheep.sheep_color in spawn_colors,"naturally spawned sheep choose a source natural coat color")
	var boundaries: Dictionary = {0:"white",81836:"white",81837:"silver",86836:"silver",86837:"grey",91836:"grey",91837:"black",96836:"black",96837:"brown",99836:"brown",99837:"pink",100000:"pink"}
	suite.check(boundaries.keys().all(func(roll): return Farming.natural_color(roll) == boundaries[roll]),"natural sheep colors use the source white, grey, black, brown and rare-pink distribution boundaries")
	for dye in range(VillageContent.DYE_WHITE,VillageContent.DYE_BROWN+1):
		var color: String = VillageContent.DATA[dye].dye
		suite.check(feed(game,sheep,dye) == 4 and sheep.sheep_color == color,"live right-click dyes sheep "+color+" and consumes one dye")
	Farming.set_color(sheep,"red")
	suite.check(sheep.wool_parts[0].material_override.albedo_texture == CreatureArt.texture("wool",Color(VillageContent.DATA[VillageContent.WOOL_RED].color)),"the visible sheep coat uses the matching colored wool texture")
	game.gamemode = "creative"
	suite.check(feed(game,sheep,VillageContent.DYE_BLUE) == 5 and sheep.sheep_color == "blue","creative sheep dyeing consumes no dye")
	game.gamemode = "survival"; sheep.growth_remaining = 100; Farming.resize(sheep)
	suite.check(feed(game,sheep,VillageContent.DYE_RED) == 4 and sheep.sheep_color == "red","baby sheep can be dyed through the real interaction path")
	sheep.growth_remaining = 0; Farming.resize(sheep)
	var wool_before: int = dropped(game,VillageContent.WOOL_RED)
	feed(game,sheep,Nodes.SHEARS,1)
	var harvest: int = dropped(game,VillageContent.WOOL_RED)-wool_before
	suite.check(sheep.sheared and harvest >= 1 and harvest <= 3 and dropped(game,Nodes.WOOL) == 0,"real shearing harvests one to three wool of the dyed sheep's color")
	suite.check(feed(game,sheep,VillageContent.DYE_BLUE) == 5 and sheep.sheep_color == "red","a bare sheep cannot be dyed and consumes no dye")
	game.inventory.slots[0] = {"id":Nodes.STONE,"count":1,"wear":0}
	var floor_pos: Vector3i = Farming.grass_below(sheep)
	game.world.set_node(floor_pos,Nodes.STONE); sheep.wool_timer = 0.01
	for i in 20: sheep._physics_process(0.1)
	suite.check(sheep.sheared and not Farming.begin_graze(sheep),"elapsed legacy wool timers and stone floors cannot regrow a sheep's coat")
	game.world.set_node(floor_pos,Nodes.GRASS)
	var graze_seed: int = -1
	for candidate in range(20000):
		seed(candidate)
		if randi_range(1,1000) == 1: graze_seed = candidate; break
	seed(graze_seed); sheep._physics_process(0.05)
	suite.check(graze_seed >= 0 and sheep.grazing == 2,"the live creature simulation starts a two-second graze on a successful source chance roll")
	var graze_position: Vector3 = sheep.position
	for i in 15: sheep._physics_process(0.1)
	suite.check(sheep.sheared and game.world.node_at(floor_pos) == Nodes.GRASS and sheep.head.rotation.x < -0.5 and sheep.position.distance_to(graze_position) < 0.05,"a grazing sheep stops and lowers its head before consuming grass")
	sheep._physics_process(0.11)
	suite.check(not sheep.sheared and sheep.sheep_color == "red" and game.world.node_at(floor_pos) == Nodes.DIRT and sheep.wool_parts.all(func(part): return part.visible),"grazing consumes grass into dirt and regrows the same colored coat at the source animation point")
	for i in 5: sheep._physics_process(0.1)
	suite.check(sheep.grazing == 0 and sheep.graze_consumed,"grazing finishes after a single consumption")
	Farming.restore_coat(sheep,{"sheep_color":"red","grazing":0.2,"graze_consumed":true}); sheep.sheared = true
	game.world.set_node(floor_pos,Nodes.GRASS); sheep._physics_process(0.1)
	suite.check(sheep.sheared and game.world.node_at(floor_pos) == Nodes.GRASS,"restoring an already-consumed grazing animation cannot consume grass or regrow wool twice")
	Farming.begin_graze(sheep); game.inventory.slots[0] = {"id":Nodes.GRAIN,"count":1,"wear":0}; sheep._physics_process(0.1)
	suite.check(sheep.grazing == 0 and game.world.node_at(floor_pos) == Nodes.GRASS,"food temptation interrupts grazing before it consumes the pasture")
	game.inventory.slots[0] = {"id":Nodes.STONE,"count":1,"wear":0}
	sheep.growth_remaining = 200; Farming.resize(sheep); Farming.begin_graze(sheep); sheep.grazing = 0.41
	sheep._physics_process(0.05)
	suite.check(absf(sheep.growth_remaining-139.95) < 0.01 and not sheep.sheared,"baby sheep gain sixty seconds of growth when grazing succeeds")
	suite.check(Farming.graze_chance(false,0.05) == 1000 and Farming.graze_chance(true,0.05) == 50 and Farming.graze_chance(false,0.1) == 500,"adult and baby grazing attempts preserve source probabilities across simulation timesteps")
	for pair in Farming.COLOR_MIXES:
		var colors: PackedStringArray = pair.split("+")
		suite.check(Farming.offspring_color(colors[0],colors[1]) == Farming.COLOR_MIXES[pair] and Farming.offspring_color(colors[1],colors[0]) == Farming.COLOR_MIXES[pair],"sheep inherit the source mixed dye color for "+pair)
	var parent_only: bool = true
	for i in 30: parent_only = parent_only and Farming.offspring_color("red","green") in ["red","green"]
	suite.check(parent_only,"non-mixable sheep colors inherit one parent's color")
	sheep.position = Vector3(7.5,440.01,7.5); sheep.growth_remaining = 0; sheep.grazing = 0; sheep.breed_cooldown = 0; sheep.love_time = 0; Farming.resize(sheep)
	Farming.set_color(sheep,"red")
	var mate: Creature = animal(game,"sheep",Vector3(9.5,440.01,7.5)); Farming.set_color(mate,"blue")
	feed(game,sheep,Nodes.GRAIN); feed(game,mate,Nodes.GRAIN)
	for i in 4: Farming.tick(sheep,1); Farming.tick(mate,1)
	var lambs: Array = babies(game,"sheep")
	suite.check(lambs.size() == 1 and lambs[0].sheep_color == "purple","actual breeding of red and blue sheep produces one purple lamb")
	var red_before: int = dropped(game,VillageContent.WOOL_RED); sheep.sheared = false; sheep.hit(100)
	suite.check(dropped(game,VillageContent.WOOL_RED)-red_before == 1,"a woolly adult sheep drops exactly one wool of its color on death")
	var chicken: Creature = animal(game,"chicken",Vector3(11.5,440.01,8.5))
	suite.check(chicken.egg_timer >= 300 and chicken.egg_timer <= 600,"new adult chickens use the source five-to-ten-minute egg timer")
	chicken.growth_remaining = 100; Farming.resize(chicken); chicken.egg_timer = 0.01
	var eggs: int = dropped(game,Nodes.EGG); chicken._physics_process(0.1)
	suite.check(chicken.egg_timer == 0.01 and dropped(game,Nodes.EGG) == eggs,"baby chicken egg timers stay frozen")
	chicken.growth_remaining = 0; Farming.resize(chicken); chicken.egg_timer = 0.5
	chicken._physics_process(0.25)
	suite.check(dropped(game,Nodes.EGG) == eggs,"adult chickens do not lay before their saved timer expires")
	chicken._physics_process(0.26)
	suite.check(dropped(game,Nodes.EGG) == eggs+1 and chicken.egg_timer >= 300 and chicken.egg_timer <= 600,"adult chickens lay one collectible egg and reset to a source five-to-ten-minute interval")

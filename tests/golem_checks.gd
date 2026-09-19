extends RefCounted

static func freeze(game: Node3D) -> void:
	game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	for mob in game.creatures.get_children(): mob.set_physics_process(false)
	game.state = "playing"; game.gamemode = "survival"

static func held(game: Node3D, id: int, count: int = 1, wear: int = 0) -> void:
	game.inventory.slots[0] = {"id":id,"count":count,"wear":wear}; game.inventory.selected = 0

static func amount(game: Node3D, id: int) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == id: count += drop.amount
	return count

static func clear(game: Node3D, p: Vector3i) -> void:
	for x in range(-4,5):
		for z in range(-4,5):
			for y in range(-4,6): game.world.set_node(p+Vector3i(x,y,z),Nodes.STONE if y == -4 else Nodes.AIR)
	game.player.position = Vector3(p)+Vector3(7,0,7)

static func discard(game: Node3D, mob: Creature) -> void:
	if mob is SnowGolem: Golems.state(game).snow.erase(mob.golem_key)
	if mob is VillageMob: game.villages.state().people.erase(mob.person_key)
	mob.queue_free()

static func run(t: SceneTree, game: Node3D) -> void:
	t.check(game.save_game("user://golem_baseline.json"),"golem fixture snapshots the existing lifecycle world")
	var baseline: Dictionary = game.read_save("user://golem_baseline.json")
	game._clear_entities(); await t.process_frame; freeze(game)
	var world: VoxelWorld = game.world; var p := Vector3i(0,904,0)
	game.world.adventure_state.weather = "clear"
	var index: int = 0
	for pattern in Golems.iron_patterns():
		clear(game,p)
		for offset in pattern.blocks: world.set_node(p+offset,Nodes.IRON_BLOCK)
		world.set_node(p,FruitCrops.head_id(index%2 == 1,index%4))
		var old_drops: int = game.drops.get_child_count()
		var mob: Creature = Golems.placed(game,p,game.player_id)
		t.check(mob is VillageMob and mob.kind == "iron_golem" and mob.health == 100 and mob.position.is_equal_approx(Vector3(p+pattern.feet)+Vector3(0.5,0,0.5)),"source iron construction pattern %d summons at its exact feet position"%index)
		var consumed: bool = world.node_at(p) == Nodes.AIR
		for offset in pattern.blocks: consumed = consumed and world.node_at(p+offset) == Nodes.AIR
		t.check(consumed and game.drops.get_child_count() == old_drops and Golems.placed(game,p,game.player_id) == null,"iron construction %d consumes exactly four iron blocks and its head once without drops"%index)
		if mob != null:
			t.check(mob.creator == game.player_id and game.villages.record(mob.person_key).creator == game.player_id,"constructed iron identity records its player creator")
			discard(game,mob)
		index += 1
	for d in Golems.SNOW_DIRECTIONS:
		clear(game,p); world.set_node(p+d,Nodes.SNOW_BLOCK); world.set_node(p+d*2,Nodes.SNOW_BLOCK); world.set_node(p,FruitCrops.CARVED)
		var mob: Creature = Golems.placed(game,p,game.player_id)
		var feet: Vector3i = p if d == Vector3i.UP else p+d*2
		t.check(mob is SnowGolem and mob.position == Vector3(feet)+Vector3(0.5,0,0.5) and mob.health == 4,"source snow construction supports axial direction "+str(d))
		t.check(world.node_at(p) == Nodes.AIR and world.node_at(p+d) == Nodes.AIR and world.node_at(p+d*2) == Nodes.AIR and Golems.placed(game,p) == null,"snow construction consumes its three blocks once")
		if mob != null: discard(game,mob)
	clear(game,p)
	var upright: Dictionary = Golems.iron_patterns()[0]
	for offset in upright.blocks: world.set_node(p+offset,Nodes.IRON_BLOCK)
	world.set_node(p,FruitCrops.CARVED); world.set_node(p+Vector3i.LEFT,Nodes.WATER)
	t.check(Golems.placed(game,p) == null and world.node_at(p) == FruitCrops.CARVED and world.node_at(p+Vector3i.DOWN) == Nodes.IRON_BLOCK,"iron summon requires literal air corners even when the obstruction has no solid collision")
	world.set_node(p+Vector3i.LEFT,Nodes.AIR); world.set_node(p+Vector3i.DOWN+Vector3i.FORWARD,Nodes.STONE)
	t.check(Golems.placed(game,p) == null and world.node_at(p+Vector3i.DOWN*2) == Nodes.IRON_BLOCK,"blocked final iron body preserves the complete structure instead of consuming blocks into an embedded mob")
	clear(game,p); world.set_node(p+Vector3i.DOWN,Nodes.SNOW_BLOCK); world.set_node(p+Vector3i.DOWN*2,Nodes.SNOW_BLOCK); world.set_node(p,Nodes.PUMPKIN)
	t.check(Golems.placed(game,p) == null,"source raw pumpkin does not construct a golem")
	held(game,Nodes.SHEARS); game.player.target = {"pos":p,"id":Nodes.PUMPKIN,"normal":Vector3i.BACK,"distance":3.0}
	FruitCrops.use(game,game.player.target)
	t.check(FruitCrops.is_pumpkin_head(world.node_at(p)) and world.node_at(p+Vector3i.DOWN) == Nodes.SNOW_BLOCK,"carving a placed raw pumpkin does not invoke source after-place summoning")
	world.set_node(p,Nodes.AIR); held(game,FruitCrops.CARVED,2); game.player.target = {"pos":p+Vector3i.DOWN,"id":Nodes.SNOW_BLOCK,"normal":Vector3i.UP,"distance":3.0}
	game.player.use()
	var snow: SnowGolem
	for mob in game.creatures.get_children():
		if mob is SnowGolem and not mob.is_queued_for_deletion(): snow = mob; break
	t.check(snow != null and world.node_at(p) == Nodes.AIR and game.inventory.held().count == 1,"actual player head placement consumes one held pumpkin and constructs a snow golem")
	if snow == null: return
	snow.set_physics_process(false)
	held(game,Nodes.SHEARS,1,20); var before: int = amount(game,FruitCrops.CARVED)
	t.check(Golems.use(game,snow) and snow.sheared and amount(game,FruitCrops.CARVED) == before+1 and game.inventory.held().wear == 21,"survival shearing returns exactly one carved head and wears shears once")
	Golems.use(game,snow)
	t.check(amount(game,FruitCrops.CARVED) == before+1 and game.inventory.held().wear == 21 and snow.pumpkin_parts.all(func(part): return not part.visible),"repeat shearing does not duplicate pumpkins or tool wear and reveals the snow face")
	discard(game,snow); await t.process_frame
	clear(game,p); snow = Golems.spawn(game,"snow_golem",Vector3(p)+Vector3(0.5,0,0.5),game.player_id); snow.set_physics_process(false)
	game.gamemode = "creative"; held(game,Nodes.SHEARS,1,20); before = amount(game,FruitCrops.CARVED); Golems.use(game,snow)
	t.check(snow.sheared and game.inventory.held().wear == 20 and amount(game,FruitCrops.CARVED) == before+1,"creative shearing returns a head without damaging the tool")
	game.gamemode = "survival"; discard(game,snow); await t.process_frame
	clear(game,p); snow = Golems.spawn(game,"snow_golem",Vector3(p)+Vector3(0.5,0,0.5)); snow.set_physics_process(false)
	var shears: Dictionary = {"id":Nodes.SHEARS,"count":1,"wear":0}; before = amount(game,FruitCrops.CARVED)
	t.check(Golems.dispense(world.circuits,p+Vector3i.LEFT,p,Vector3i.RIGHT,shears) and snow.sheared and shears.wear == 1 and amount(game,FruitCrops.CARVED) == before,"source dispenser shearing removes its pumpkin and wears shears without a head drop")
	discard(game,snow); await t.process_frame
	clear(game,p); world.set_node(p+Vector3i.DOWN,Nodes.SNOW_BLOCK); world.set_node(p+Vector3i.DOWN*2,Nodes.SNOW_BLOCK)
	var head_item: Dictionary = {"id":FruitCrops.CARVED,"count":2,"wear":0}
	t.check(Golems.dispense(world.circuits,p+Vector3i.LEFT,p,Vector3i.RIGHT,head_item) and FruitCrops.is_pumpkin_head(world.node_at(p)) and world.node_at(p+Vector3i.DOWN) == Nodes.SNOW_BLOCK and head_item.count == 1,"source dispenser places a carved pumpkin without invoking an after-place summon")
	clear(game,p)
	var iron: VillageMob = Golems.spawn(game,"iron_golem",Vector3(p)+Vector3(0.5,0,0.5),game.player_id); iron.set_physics_process(false)
	iron.health = 40; held(game,Nodes.IRON,3)
	t.check(Golems.use(game,iron) and iron.health == 65 and game.inventory.held().count == 2 and game.villages.record(iron.person_key).health == 65,"iron ingot repairs25 health, consumes one ingot and immediately persists repair")
	iron.health = 90; Golems.use(game,iron); Golems.use(game,iron)
	t.check(iron.health == 100 and game.inventory.held().count == 1,"repair clamps to100 and a full-health golem does not consume iron")
	iron.health = 40; game.gamemode = "creative"; Golems.use(game,iron); game.gamemode = "survival"
	t.check(iron.health == 65 and game.inventory.held().count == 1,"creative iron repair preserves the held ingot")
	iron.health = 20; iron.cracks()
	t.check(iron.crack_parts.all(func(part): return part.visible),"damaged iron golem displays the source critical crack stage")
	iron.health = 100; iron.cracks(); var original_velocity: Vector3 = iron.velocity
	iron.hit(1,game.player.position)
	t.check(iron.revenge_target == game.player and iron.anger_remaining == 15 and iron.knock == Vector3.ZERO and iron.velocity == original_velocity,"installed source playerbuilt golem retaliates to direct hits with full knockback resistance")
	iron.revenge_target = null; iron.anger_remaining = 0
	var villager: VillageMob = game.spawn_creature("villager",Vector3(p)+Vector3(2,0,0)); villager.set_physics_process(false)
	game.villages.record(villager.person_key).reputations[game.player_id] = -125
	t.check(iron.iron_target() == null,"creator flag suppresses reputation-based aggression for constructed iron golems")
	iron.creator = ""
	t.check(iron.iron_target() == game.player,"village iron golem pursues a player below the source negative100 reputation threshold")
	game.gamemode = "creative"
	t.check(iron.iron_target() == null,"creative player is excluded from iron aggression")
	game.gamemode = "survival"; iron.creator = game.player_id
	var zombie: Creature = game.spawn_creature("zombie",Vector3(p)+Vector3(2,0,0)); zombie.set_physics_process(false); zombie.health = 100
	iron.strike(zombie)
	t.check(zombie.health <= 92.5 and zombie.health >= 78.5 and zombie.velocity.y >= 16,"source iron strike deals7.5–21.5 damage and launches its damaged target upward16")
	var creeper: Creature = game.spawn_creature("creeper",Vector3(p)+Vector3(1,0,0)); creeper.set_physics_process(false)
	discard(game,villager); zombie.queue_free(); await t.process_frame
	var health_before: float = creeper.health; iron._physics_process(0.01)
	t.check(creeper.health == health_before,"iron golem does not automatically attack a nearby creeper")
	creeper.queue_free(); discard(game,iron); await t.process_frame
	await snow_checks(t,game,p)
	await persistence_checks(t,game,p)
	game.set_process(true); game.load_world_data(baseline)
	while game.state == "loading": await t.process_frame
	game.pause(); freeze(game)

static func snow_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	clear(game,p); game.world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	var snow: SnowGolem = Golems.spawn(game,"snow_golem",Vector3(p)+Vector3(0.5,0,0.5)); snow.set_physics_process(false)
	t.check(snow.trail() and game.world.node_at(p) == SnowCover.BASE,"snow golem leaves one top-snow layer above a full solid cube")
	game.world.set_node(p,Nodes.AIR); game.game_rules.mobGriefing = false
	t.check(not snow.trail() and game.world.node_at(p) == Nodes.AIR,"mobGriefing=false prevents snow trail placement")
	game.game_rules.mobGriefing = true; game.world.set_node(p+Vector3i.DOWN,BuildingShapes.slab_for(Nodes.STONE))
	t.check(not snow.trail(),"snow trails do not float above lower slabs")
	game.world.set_node(p+Vector3i.DOWN,Nodes.STONE); game.world.set_node(p,Nodes.WATER)
	snow.environment(0.5)
	t.check(snow.health == 3 and game.world.node_at(p) == Nodes.WATER,"water deals one health each half-second and cannot become a snow trail")
	game.world.set_node(p,Nodes.AIR); game.world.adventure_state.weather = "rain"
	snow.health = 4; snow.environment(0.5)
	t.check(snow.health == 3,"exposed temperate rain damages snow golems at the source rate")
	game.world.set_node(p+Vector3i.UP*3,Nodes.STONE); snow.environment(0.5)
	t.check(snow.health == 3,"a roof protects the snow golem from rain")
	game.world.adventure_state.weather = "clear"; game.dimension = "nether"; snow.environment(0.5)
	t.check(snow.health == 2,"source hot-biome damage also applies in the Nether")
	PotionEffects.apply(snow,"fire_resistance",30); snow.environment(0.5)
	t.check(snow.health == 2,"fire resistance prevents source on-fire heat damage")
	game.dimension = "overworld"; PotionEffects.clear(snow); game.world.set_node(p+Vector3i.UP*3,Nodes.AIR)
	snow.health = 4
	var water_potion: int = 0
	for id in PotionCatalog.ITEMS:
		if PotionCatalog.ITEMS[id].get("potion","") == "water" and PotionCatalog.ITEMS[id].form == "splash": water_potion = id; break
	PotionEffects.apply_item(snow,water_potion)
	t.check(water_potion != 0 and snow.health == 3,"water potion dispatch applies the source water-vulnerable damage to snow golems")
	var boat: BoatEntity = game.boats.spawn(VillageContent.BOAT_OAK,Vector3(p)+Vector3(0.5,0,0.5)); boat.set_physics_process(false)
	t.check(boat.attach_mob(snow) and not snow.is_physics_processing(),"snow golem can ride a boat with its own movement suspended")
	game.dimension = "nether"; boat._physics_process(0.5); game.dimension = "overworld"
	t.check(snow.health == 2 and boat.passenger == snow,"boat passenger retains source hot-biome damage while movement is suspended")
	boat.release_mob(false); game.boats.records().erase(boat.key); game.boats.reset(); snow.set_physics_process(false)
	var blaze: Creature = game.spawn_creature("blaze",Vector3(p)+Vector3(0.5,0,5)); blaze.set_physics_process(false)
	var shot: ThrownItem = snow.shoot(blaze); shot.set_physics_process(false)
	t.check(shot != null and shot.item_id == Nodes.SNOWBALL and shot.thrower == snow and shot.velocity.length() > 21,"snow golem fires the real snowball projectile with itself as thrower")
	var blaze_health: float = blaze.health; shot.impact(blaze)
	t.check(blaze.health == blaze_health-3,"real snow-golem snowball impact deals the source three damage to blazes")
	var creeper: Creature = game.spawn_creature("creeper",Vector3(p)+Vector3(0.5,0,3)); creeper.set_physics_process(false)
	t.check(snow.acquire_target() == creeper,"snow golem selects nearby monsters including creepers")
	var old_health: float = creeper.health; shot = snow.shoot(creeper); shot.set_physics_process(false); shot.impact(creeper)
	t.check(creeper.health == old_health and creeper.provoked and creeper.knock.length() > 0,"snowball impact provokes and knocks back ordinary monsters without invented health damage")
	for y in 3: game.world.set_node(p+Vector3i(0,y,2),Nodes.STONE)
	t.check(snow.acquire_target() == null,"opaque walls prevent snow golem target acquisition")
	blaze.queue_free(); creeper.queue_free(); var key: String = snow.golem_key
	var before: int = amount(game,Nodes.SNOWBALL); snow.die(); snow.die()
	t.check(not Golems.state(game).snow.has(key) and amount(game,Nodes.SNOWBALL)-before in range(0,16),"snow golem death removes its persistence record and drops at most15 snowballs once")
	await t.process_frame

static func persistence_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	clear(game,p); game.world.set_node(p+Vector3i.DOWN,Nodes.STONE); game.player.position = Vector3(p)+Vector3(3,0,3)
	var snow: SnowGolem = Golems.spawn(game,"snow_golem",Vector3(p)+Vector3(0.5,0,0.5),game.player_id); snow.set_physics_process(false)
	snow.sheared = true; snow.refresh_head(); snow.custom_name = "Winter friend"; snow.health = 3; snow.environment_clock = 0.2; snow.trail_clock = 0.3; snow.store_record()
	var key: String = snow.golem_key
	game.leads.attach(snow,false)
	var iron: VillageMob = Golems.spawn(game,"iron_golem",Vector3(p)+Vector3(3.5,0,0.5),game.player_id); iron.set_physics_process(false)
	iron.health = 40; iron.custom_name = "Foundry"; iron.retaliate(game.player); iron.anger_remaining = 8; iron.store_record()
	var iron_key: String = iron.person_key
	t.check(game.save_game("user://golem_saved.json"),"constructed golems save through the actual world JSON path")
	var saved: Dictionary = game.read_save("user://golem_saved.json")
	t.check(saved.adventure.golems.snow[key].sheared and saved.adventure.golems.snow[key].custom_name == "Winter friend" and saved.adventure.village_life.people[iron_key].creator == game.player_id,"JSON includes snow pumpkin/name state and iron creator identity")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await t.process_frame
	freeze(game); game.villages.timer = 0; game.villages.update(0.5)
	snow = Golems.resolve(game,key)
	t.check(snow != null and snow.sheared and snow.health == 3 and snow.custom_name == "Winter friend" and snow.creator == game.player_id and snow.pumpkin_parts.all(func(part): return not part.visible),"actual world reload restores the same sheared, named and damaged snow golem")
	var count: int = 0
	for mob in game.creatures.get_children():
		if mob is SnowGolem and mob.golem_key == key and not mob.is_queued_for_deletion(): count += 1
		if mob is VillageMob and mob.person_key == iron_key and not mob.is_queued_for_deletion(): iron = mob
	t.check(count == 1 and game.leads.attached(snow),"restored snow lead resolves the existing persistent identity without duplicating its creature")
	t.check(is_instance_valid(iron) and iron.health == 40 and iron.creator == game.player_id and iron.custom_name == "Foundry" and iron.anger_remaining > 0,"actual world reload preserves playerbuilt iron health, creator, name and active retaliation")
	game.leads.detach(snow,false); game.player.position += Vector3.RIGHT*110
	Golems.update(game,1); await t.process_frame
	t.check(Golems.state(game).snow.has(key) and not game.creatures.get_children().any(func(mob): return mob is SnowGolem and mob.golem_key == key and not mob.is_queued_for_deletion()),"distant snow golem hibernates without losing its saved identity")
	game.player.position -= Vector3.RIGHT*110; Golems.update(game,1)
	snow = Golems.resolve(game,key); snow.set_physics_process(false)
	t.check(snow != null and snow.sheared and snow.health == 3,"returning to the loaded area recreates one snow golem with retained health and pumpkin state")
	game.dimension = "nether"; iron.store_record(); iron.queue_free(); await t.process_frame; game.villages.timer = 0; game.villages.update(1)
	count = 0
	for mob in game.creatures.get_children():
		if mob is VillageMob and mob.person_key == iron_key and not mob.is_queued_for_deletion(): count += 1
	t.check(count == 1,"constructed iron records restore outside the Overworld without natural village generation")
	game.dimension = "overworld"

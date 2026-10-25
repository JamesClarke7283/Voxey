extends RefCounted
static func empty(person: Dictionary) -> Array:
	person.inventory = VillagerInventory.clean([]); person.food_level = 0; return person.inventory
static func add_food(person: Dictionary, count: int) -> void:
	var items: Array = empty(person); VillagerInventory.add(items,{"id":Nodes.BREAD,"count":count,"wear":0})
static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var old_pos: Vector3 = game.player.position; var old_time: float = game.day_time; var old_mode: String = game.gamemode
	var people: Dictionary = game.villages.state().people.duplicate(true)
	for mob in game.creatures.get_children(): mob.free()
	for drop in game.drops.get_children(): drop.free()
	game.villages.state().people = {}; game.day_time = 0.67; game.gamemode = "survival"; game.player.position = Vector3(20,2000,15)
	for x in range(3,23):
		for z in range(3,18):
			for y in range(1999,2003): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 1999 else Nodes.AIR)
	var a: VillageMob = game.spawn_creature("villager",Vector3(8.5,2000,8.5)); a.set_physics_process(false)
	var b: VillageMob = game.spawn_creature("villager",Vector3(10.5,2000,8.5)); b.set_physics_process(false)
	var pa: Dictionary = game.villages.record(a.person_key); var pb: Dictionary = game.villages.record(b.person_key)
	add_food(pa,3); add_food(pb,4)
	t.check(not VillagerFood.possible(pa) and VillagerFood.possible(pb),"the source requires more than twelve total food points to begin breeding")
	VillagerInventory.add(pa.inventory,{"id":Nodes.BREAD,"count":1,"wear":0})
	pa.age = 1; t.check(not VillagerFood.possible(pa),"children cannot breed even with sufficient stored food"); pa.age = 0
	t.check(not VillagerFood.possible(pa,true),"sleeping villagers cannot be chosen as mates")
	var legacy: Dictionary = {"food":17,"breed_time":200,"inventory":VillagerInventory.clean([]),"age":0}
	VillagerFood.clean(legacy)
	t.check(legacy.food_level == 17 and not legacy.has("food") and not legacy.has("breed_time"),"old abstract food migrates to eaten-food energy without retaining the artificial breeding cooldown")
	add_food(pa,40); empty(pb)
	VillagerSocial.emit_share(a,b)
	var drops: Array = game.drops.get_children().filter(func(d): return not d.is_queued_for_deletion())
	t.check(drops.size() == 1 and drops[0].amount == 16 and VillagerInventory.count(pa.inventory,Nodes.BREAD) == 24,"food sharing throws the excess from one stack while retaining twenty-four")
	t.check(is_equal_approx(drops[0].velocity.length(),4) and absf(drops[0].position.y-a.position.y-1.14) < 0.0002,"shared food uses the source throw speed and launch height")
	t.check(VillagerInventory.count(pb.inventory,Nodes.BREAD) == 0,"food transfer travels as a real item instead of appearing directly in the recipient's inventory")
	drops[0].position = b.position; drops[0].age = 1; VillagerInventory.pickup(b)
	t.check(drops[0].is_queued_for_deletion() and VillagerInventory.count(pb.inventory,Nodes.BREAD) == 16,"the recipient collects an aged shared-food item through normal inventory pickup")
	for drop in game.drops.get_children(): drop.free()
	pa.profession = "farmer"; a.profession = "farmer"; pb.profession = "farmer"; b.profession = "farmer"
	empty(pa); empty(pb); VillagerInventory.add(pa.inventory,{"id":Nodes.SEEDS,"count":64,"wear":0}); VillagerSocial.emit_share(a,b)
	t.check(game.drops.get_child_count() == 0,"the installed source's empty extra-trade lookup does not introduce seed sharing")
	VillagerInventory.add(pa.inventory,{"id":Nodes.GRAIN,"count":33,"wear":0}); VillagerSocial.emit_share(a,b)
	t.check(game.drops.get_child_count() == 1 and game.drops.get_child(0).amount == 9,"a farmer still receives surplus wheat through the source's separate wheat-sharing rule")
	var own: ItemDrop = game.drops.get_child(0); own.position = a.position; own.age = 3; game.villages.state().clock += 3
	VillagerInventory.pickup(a)
	t.check(not own.is_queued_for_deletion(),"the source's older-self-thrown-item rejection is preserved")
	own.age = 1; own.set_meta("villager_thrown",game.villages.state().clock-1); VillagerInventory.pickup(a)
	t.check(own.is_queued_for_deletion(),"the source permits the donor to reclaim its item during the initial two seconds")
	for drop in game.drops.get_children(): drop.free()
	pa.profession = "unemployed"; a.profession = "unemployed"; pb.profession = "unemployed"; b.profession = "unemployed"
	var home_a := Vector3i(6,2000,11); var home_b := Vector3i(10,2000,11); var nursery := Vector3i(14,2000,11)
	for bed in [home_a,home_b,nursery]: game.world.set_node(bed,VillageContent.BED_RED)
	pa.bed = [home_a.x,home_a.y,home_a.z]; pb.bed = [home_b.x,home_b.y,home_b.z]
	t.check(VillagerSocial.free_beds(game,a.position) == [nursery],"only a loaded, unclaimed bed is offered to a prospective child")
	game.world.set_node(nursery+Vector3i.UP,Nodes.STONE)
	t.check(nursery in VillagerSocial.free_beds(game,a.position),"the source free-bed sensor does not add a headroom condition")
	game.world.set_node(nursery+Vector3i.UP,Nodes.AIR)
	add_food(pa,4); add_food(pb,4)
	var random: RandomNumberGenerator = FarmerWork.rng_for(game.world).native
	var start_seed: int = 0
	for seed in range(1,10000):
		random.seed = seed
		if random.randi_range(1,120) == 1: start_seed = seed; break
	random.seed = start_seed
	VillagerSocial.step(a,0.05,true)
	t.check(a.social.mode == "breed" and b.social.partner == a and a.social.birth >= 13.75 and a.social.birth <= 16.25,"the live social selector starts reciprocal courtship with the source duration range")
	VillagerSocial.reset(a)
	t.check(VillagerSocial.pair(a,b,"breed",14),"two adults can start a reciprocal courtship")
	game.state = "playing"; VillagerSocial.step(a,13.9,true); VillagerSocial.step(b,13.9,true)
	t.check(game.creatures.get_child_count() == 2,"courtship waits for its birth timer before creating a child")
	VillagerSocial.step(a,0.2,true)
	var children: Array = game.creatures.get_children().filter(func(m): return m != a and m != b)
	t.check(children.size() == 1,"a completed courtship creates exactly one child")
	var child: VillageMob = children[0]; child.set_physics_process(false); var pc: Dictionary = game.villages.record(child.person_key)
	t.check(pc.bed == [nursery.x,nursery.y,nursery.z] and pc.age == 1200 and pc.profession == "unemployed","the child claims the free bed and has twenty minutes of childhood")
	t.check(is_equal_approx(child.model.scale.x,0.5) and is_equal_approx(child.height,0.95) and is_equal_approx(child.width,0.125),"the child uses the source half-size body and collision dimensions")
	t.check(VillagerInventory.count(pa.inventory,Nodes.BREAD) == 1 and VillagerInventory.count(pb.inventory,Nodes.BREAD) == 1 and pa.food_level == 0 and pb.food_level == 0,"both parents eat and spend twelve points on conception")
	t.check(VillagerSocial.free_beds(game,a.position).is_empty(),"the child's claimed bed is unavailable to another birth")
	add_food(pa,4); add_food(pb,4); VillagerSocial.pair(a,b,"breed",0.01); VillagerSocial.step(a,0.1,true)
	t.check(game.creatures.get_child_count() == 3 and VillagerInventory.count(pa.inventory,Nodes.BREAD) == 1 and VillagerInventory.count(pb.inventory,Nodes.BREAD) == 1,"an unsuccessful no-bed attempt still consumes both parents' food")
	t.check(a.social.partner == null and b.social.partner == null,"a failed birth clears both sides of the courtship")
	add_food(pa,4); add_food(pb,4); VillagerSocial.pair(a,b,"breed",5); b.health = 0; VillagerSocial.step(a,0.1,true); b.health = 20
	t.check(a.social.partner == null and VillagerInventory.count(pa.inventory,Nodes.BREAD) == 4,"losing a partner cancels courtship before food is spent")
	# Normal feeding now supplies the inventory instead of instantly creating a baby.
	empty(pa); game.inventory.restore([]); game.inventory.selected = 0; game.inventory.add_item(Nodes.BREAD,1)
	game.villages.feed(a)
	t.check(game.inventory.count_item(Nodes.BREAD) == 0 and VillagerInventory.count(pa.inventory,Nodes.BREAD) == 1 and game.creatures.get_child_count() == 3,"direct feeding adds a real food item and does not bypass courtship")
	pa.food_level = -5; var key: String = a.person_key; a.store_record(); game.save_game()
	var saved: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	var freeze: Callable = func(node):
		if node is Creature: node.ready.connect(func(): node.set_physics_process(false),CONNECT_ONE_SHOT)
	game.creatures.child_entered_tree.connect(freeze); game.load_world_data(saved); game.villages.timer = 100; game.set_process(true); game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.creatures.child_entered_tree.disconnect(freeze); game.pause(); game.set_process(false); game.world.set_process(false)
	t.check(game.villages.record(key).food_level == -5 and VillagerInventory.count(VillagerInventory.slots(game.villages.record(key)),Nodes.BREAD) == 1,"world reload preserves eaten-food energy and carried food separately")
	var new_bed := Vector3i(16,2000,11); game.world.set_node(new_bed,VillageContent.BED_RED)
	t.check(new_bed in VillagerSocial.free_beds(game,Vector3(8,2000,8)),"the live bed index accepts a newly placed bed after world reload")
	t.check(game.creatures.get_children().filter(func(m): return m is VillageMob).all(func(m): return m.social.is_empty() or m.social.get("partner") == null),"active social partners are transient across reload")
	var infected: Creature = game.spawn_creature("zombie_villager",Vector3(8,2000,8),"",{"baby":false,"jockey":false}); infected.set_physics_process(false)
	ZombieVillagers.infect(game,infected,game.villages.record(key))
	t.check(not infected.get_meta("incarnation").has("food_level"),"infection does not preserve eaten-food energy absent from the source identity export")
	for mob in game.creatures.get_children(): mob.free()
	for x in range(3,23):
		for z in range(3,18):
			for y in range(1999,2003): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.villages.timer = 0; game.villages.state().people = people; game.player.position = old_pos; game.day_time = old_time; game.gamemode = old_mode

extends RefCounted

static func equip(game: Node3D, id: int, count: int = 1) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0}

static func drops(game: Node3D, id: int) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and drop.item_id == id and not drop.is_queued_for_deletion(): count += drop.amount
	return count

static func run(t: SceneTree, game: Node3D) -> void:
	var inv := Inventory.new()
	for i in Barriers.FENCE_MATERIALS.size():
		var fence: int = Barriers.FENCE_BASES[i]; var gate: int = fence+1
		var f: Dictionary = inv.recipes[inv.recipe_index(fence)]; var g: Dictionary = inv.recipes[inv.recipe_index(gate)]
		t.check(f.count == (6 if i == 1 else 3) and g.count == (2 if i == 1 else 1) and f.ingredients[Barriers.FENCE_MATERIALS[i]] == 4 and g.ingredients[Barriers.FENCE_MATERIALS[i]] == 2,"source fence/gate recipe material counts and yields: "+Nodes.title(fence))
	for i in Barriers.WALL_MATERIALS.size():
		var wall: int = Barriers.WALL_FIRST+i; var recipe: Dictionary = inv.recipes[inv.recipe_index(wall)]
		t.check(recipe.count == 6 and recipe.ingredients == {Barriers.WALL_MATERIALS[i]:6} and Nodes.exists(wall) and Nodes.placeable(wall),"source survival wall recipe and registry: "+Nodes.title(wall))
	# Seven more wall materials were appended for the nether family, so the catalog
	# grew from 35 to 42 items. The structural claims are unchanged.
	t.check(Barriers.items().size() == 42 and not Nodes.all_ids().has(5005) and Nodes.drop(5008) == 5001 and not Nodes.placeable(5008),"catalog exposes every barrier item and hides gate placement states; all states drop their canonical gate")
	t.check(Nodes.fuel_time(5000) == 15 and Nodes.fuel_time(5001) == 15 and Nodes.fuel_time(5016) == 0 and Fire.flammable(5000) and not Fire.flammable(5016),"oak barriers burn for fifteen seconds; brick fences do not burn")
	t.check(Barriers.connects(5000,5001) and not Barriers.connects(5000,5016) and Barriers.connects(5016,5017) and not Barriers.connects(5016,5000),"wood and Nether-brick fence groups connect to matching gates without cross-material rails")
	t.check(not Barriers.connects(5100,5001) and Barriers.connects(5100,5101) and Barriers.connects(5000,Nodes.GLASS) and not Barriers.connects(5000,4000),"source walls connect to other walls and full blocks, without inventing gate/slab connections")
	for bits in 16:
		var around: Array = []
		for side in 4: around.append(Nodes.STONE if bits&(1<<side) else Nodes.AIR)
		around.append(Nodes.AIR)
		var wall_boxes: Array = Barriers.boxes(5100,bits)
		var max_y: float = 0
		for box in wall_boxes: max_y = maxf(max_y,box.end.y)
		t.check(Barriers.mask(5000,around) == bits and Barriers.mask(5100,around) == bits and Barriers.boxes(5000,bits).size() == 1+2*_bits(bits) and is_equal_approx(max_y,0.8125 if bits in [5,10] else 1.0),"source connected fence/wall geometry for neighbor mask %d"%bits)
	t.check(Barriers.mask(5100,[Nodes.STONE,0,Nodes.STONE,0,Nodes.TORCH]) == 16 and Barriers.boxes(5100,16).size() == 2,"a torch restores the center pillar on a straight wall")
	game.pause(); game.world.active = false; game.world.set_process(false); game.player.set_physics_process(false)
	game.leads.clear()
	for mob in game.creatures.get_children(): mob.queue_free()
	await t.process_frame
	var p := Vector3i(8,470,8)
	for x in range(-3,5):
		for z in range(-4,5):
			game.world.set_node(p+Vector3i(x,-1,z),Nodes.STONE)
			for y in 4: game.world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(p)+Vector3(0.5,0.01,-2)
	game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO
	game.gamemode = "survival"; game.player.eating.clear()
	game.world.set_node(p,5000); game.world.set_node(p+Vector3i.RIGHT,5000)
	t.check(game.world.intersects(Vector3(p)+Vector3(0.5,1.3,0.5)) and not game.world.intersects(Vector3(p)+Vector3(0.5,1.52,0.5)),"fence collision remains 1.51 high when feet move into the cell above")
	game.player.position = Vector3(p)+Vector3(0.5,0.01,-0.5)
	game.player.velocity = Vector3(0,8.2,0)
	var peak: float = 0
	for i in 70:
		game.player.velocity.y -= 24.0/60.0
		game.player._move(Vector3(0,game.player.velocity.y,3.0)/60.0,false)
		peak = maxf(peak,game.player.position.y-p.y)
	t.check(peak > 1.2 and game.player.position.z < p.z+0.1,"a real swept ordinary jump cannot clear the fence")
	game.player.position = Vector3(p)+Vector3(0.5,0.01,-2)
	t.check(not game.world.intersects(Vector3(p)+Vector3(0.15,0,0.15),0.05,0.4) and game.world.intersects(Vector3(p)+Vector3(0.85,1.2,0.5),0.05,0.4),"fence corner spaces stay clear while connected rails form tall barriers")
	var ray: Dictionary = game.world.raycast(Vector3(p)+Vector3(0.85,0.65,-1),Vector3.BACK,2)
	t.check(ray.is_empty(),"ray targeting passes between the two fence rails")
	ray = game.world.raycast(Vector3(p)+Vector3(0.85,0.8,-1),Vector3.BACK,2)
	t.check(ray.get("pos") == p and is_equal_approx(ray.point.z,p.z+0.4375),"ray targeting hits the actual upper fence rail")
	game.world.set_node(p,5100)
	t.check(game.world.intersects(Vector3(p)+Vector3(0.5,1.3,0.5)) and not game.world.intersects(Vector3(p)+Vector3(0.5,1.51,0.5)),"wall collision preserves the source's 1.5-high central post")
	game.world.set_node(p,Nodes.AIR); equip(game,5001,4)
	game.player.target = {"pos":p+Vector3i.DOWN,"normal":Vector3i.UP,"id":Nodes.STONE,"distance":2.0}
	game.player.use()
	t.check(Barriers.is_gate(game.world.node_at(p)) and game.inventory.held().count == 3,"real block use places an oriented gate and consumes one item")
	var closed: int = game.world.node_at(p)
	game.player.target = {"pos":p,"normal":Vector3i.FORWARD,"id":closed,"distance":2.0}; equip(game,Nodes.APPLE,2)
	game.player.use()
	t.check(Barriers.open(game.world.node_at(p)) and game.inventory.held().count == 2 and game.player.eating.is_empty(),"gate interaction takes precedence over eating and consumes no held food")
	t.check(not game.world.intersects(Vector3(p)+Vector3(0.5,0.4,0.5)),"an open gate permits passage through its center")
	for item in [Nodes.STONE,5000,4000]:
		equip(game,item,2)
		game.player.target = {"pos":p+Vector3i.DOWN,"normal":Vector3i.UP,"id":Nodes.STONE,"distance":2.0}
		game.player.use()
		t.check(Barriers.open(game.world.node_at(p)) and game.inventory.held().count == 2,"placing item %d cannot silently overwrite an open gate"%item)
	game.world.circuits.step(); game.world.circuits.step()
	t.check(Barriers.open(game.world.node_at(p)),"an unpowered manually opened gate stays open between circuit ticks")
	Barriers.set_open(game.world,p,false)
	game.world.set_node(p+Vector3i.LEFT,Nodes.LEVER); game.world.circuits.state(p+Vector3i.LEFT).on = true
	game.world.circuits.step(); game.world.circuits.step()
	t.check(Barriers.open(game.world.node_at(p)),"a powered neighboring lever opens a fence gate")
	game.world.circuits.state(p+Vector3i.LEFT).on = false; game.world.circuits.step(); game.world.circuits.step()
	t.check(not Barriers.open(game.world.node_at(p)),"removing power closes a fence gate")
	game.world.set_node(p+Vector3i.LEFT,Nodes.AIR)
	var placed: int = game.world.node_at(p)
	var before: int = drops(game,5001)
	game.break_node(p,placed,0)
	t.check(game.world.node_at(p) == 0 and drops(game,5001) == before+1,"breaking an oriented gate returns exactly one canonical item")
	game.world.set_node(p,5000)
	var sheep: Creature = game.spawn_creature("sheep",Vector3(p)+Vector3(2,0.01,2)); sheep.set_physics_process(false)
	Farming.set_color(sheep,"blue"); sheep.custom_name = "Fenced"; Farming.remember(sheep)
	var key: String = sheep.farm_id
	game.leads.attach(sheep,false)
	t.check(game.leads.anchor_at(p) and game.leads.leads[0].anchor == [p.x,p.y,p.z],"an existing lead can be tied to a fence")
	var start: Vector3 = sheep.position
	game.player.position += Vector3(25,0,0); game.leads.update(0.1)
	t.check(game.leads.attached(sheep) and sheep.position.distance_to(start) < 0.01,"fence-tied animal ignores player departure without snapping its lead")
	game.player.position += Vector3(100,0,0); Farming.sleep_if_unloaded(sheep)
	await t.process_frame
	game.leads.update(0.1)
	t.check(game.leads.leads.size() == 1 and game.leads.leads[0].has("sleeping") and game.leads.snapshot()[0].farm_id == key,"a distant anchored farm hibernates while retaining its saved lead identity")
	game.player.position = Vector3(p)+Vector3(0.5,0.01,-2)
	Farming.update_world(game); game.leads.update(0.1)
	sheep = Farming.active(game,key)
	t.check(sheep != null and game.leads.attached(sheep) and not game.leads.leads[0].has("sleeping"),"returning to the farm restores the same anchored sheep once")
	Barriers.set_open(game.world,p+Vector3i.RIGHT,true)
	game.world.set_node(p+Vector3i(0,0,3),5008)
	game.world.set_node(p+Vector3i(1,0,3),5100)
	t.check(game.save_game("user://barriers.json"),"barrier and anchored farm state writes to disk")
	var saved: Dictionary = game.read_save("user://barriers.json")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await t.process_frame
	game.pause(); game.set_process(false); game.world.active = false; game.world.set_process(false)
	sheep = Farming.active(game,key)
	t.check(game.world.node_at(p+Vector3i(0,0,3)) == 5008 and game.world.node_at(p+Vector3i(1,0,3)) == 5100,"real reload preserves gate facing/open state and wall blocks")
	t.check(sheep != null and sheep.sheep_color == "blue" and sheep.custom_name == "Fenced" and game.leads.leads.size() == 1 and game.leads.attached(sheep) and game.leads.leads[0].anchor == [p.x,p.y,p.z],"real reload restores one dyed, named sheep and its fence anchor")
	before = drops(game,VillageContent.LEAD)
	game.world.set_node(p,Nodes.AIR); game.leads.update(0.1); game.leads.update(0.1)
	t.check(game.leads.leads.is_empty() and drops(game,VillageContent.LEAD) == before+1,"breaking an anchor releases its animal and returns the lead exactly once")
	await _anchor_checks(t,game,p)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists("user://barriers.json"+suffix): DirAccess.remove_absolute("user://barriers.json"+suffix)

static func _bits(value: int) -> int:
	var n: int = 0
	for i in 4:
		if value&(1<<i): n += 1
	return n

static func _anchor_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	game.leads.clear()
	for mob in game.creatures.get_children(): Farming.forget(mob); mob.queue_free()
	await t.process_frame
	game.world.set_node(p,Barriers.FIRST)
	game.inventory.restore([])
	var previous_time: float = game.day_time
	game.day_time = 0.4
	game.player.position = Vector3(p)+Vector3(22,0.01,2)
	var sheep: Creature = game.spawn_creature("sheep",Vector3(p)+Vector3(1.5,0.01,1.5))
	sheep.set_physics_process(false); sheep.think = 100; sheep.direction = Vector3.ZERO
	game.leads.attach(sheep,false); game.leads.anchor_at(p)
	var start: Vector3 = sheep.position
	game.state = "playing"; sheep._physics_process(0.1); game.state = "paused"
	t.check(not game.leads.player_attached(sheep) and Vector2(sheep.position.x,sheep.position.z).distance_to(Vector2(start.x,start.z)) < 0.001,"live fence-tied animal AI does not steer toward the departing player")
	game.leads.detach(sheep,false); Farming.forget(sheep); sheep.free()
	var villager: VillageMob = game.spawn_creature("villager",Vector3(p)+Vector3(1.5,0.01,1.5)); villager.set_physics_process(false)
	var person: Dictionary = game.villages.record(villager.person_key)
	person.job = [p.x,p.y,p.z+1]; person.bed = [p.x,p.y,p.z+1]
	game.leads.attach(villager,false); game.leads.anchor_at(p)
	game.state = "playing"; villager._physics_process(0.1); game.state = "paused"
	t.check(villager.destination.distance_to(game.player.position) > 10,"live fence-tied villager AI retains its own work destination")
	game.leads.detach(villager,false); game.villages.state().people.erase(villager.person_key); villager.free()
	for kind in ["horse","villager","turtle","phantom","piglin","blaze","slime","shulker"]:
		game.player.position = Vector3(p)+Vector3(0.5,0.01,-2)
		var mob: Creature = game.spawn_creature(kind,Vector3(p)+Vector3(1.5,0.01,1.5)); mob.set_physics_process(false)
		if mob is RuralAnimal: mob.trust = 3; mob.equip_saddle()
		if mob is ExpeditionCreature and kind == "shulker": mob.crystal_key = "anchor-regression-guard"
		game.leads.attach(mob,false); game.leads.anchor_at(p)
		var old_count: int = drops(game,VillageContent.LEAD)
		game.player.position += Vector3(120,0,0)
		game.state = "playing"
		if mob is VillageMob: game.villages.timer = 0; game.villages.update(0.5)
		else: mob._physics_process(0.01)
		game.state = "paused"
		await t.process_frame
		game.leads.update(0.1)
		t.check(game.leads.leads.size() == 1 and game.leads.leads[0].has("sleeping") and drops(game,VillageContent.LEAD) == old_count,"distant anchored "+kind+" hibernates without losing the animal or dropping its lead")
		var saved: Array = JSON.parse_string(JSON.stringify(game.leads.snapshot()))
		game.leads.restore(saved)
		await t.process_frame
		t.check(game.leads.leads.size() == 1 and game.leads.snapshot().size() == 1 and game.leads.leads[0].has("sleeping"),"serialized distant "+kind+" anchor stays asleep when restored far away")
		game.player.position = Vector3(p)+Vector3(0.5,0.01,-2)
		if kind == "villager": game.villages.timer = 0; game.villages.update(0.5)
		if kind == "piglin": Bastions.populate(game)
		game.leads.update(0.1)
		var restored: Creature = game.leads.leads[0].mob if game.leads.leads.size() == 1 else null
		t.check(restored != null and restored.kind == kind and game.leads.anchored(restored) and not game.leads.leads[0].has("sleeping"),"returning restores the same anchored "+kind+" family and live rope")
		if restored == null: continue
		restored.set_physics_process(false)
		if kind in ["villager","piglin"]:
			var same: Array = game.creatures.get_children().filter(func(creature: Creature): return not creature.is_queued_for_deletion() and ((creature is VillageMob and restored is VillageMob and creature.person_key == restored.person_key) or (creature is NetherResident and restored is NetherResident and creature.resident_key == restored.resident_key)))
			t.check(same.size() == 1,"population before lead wakeup reuses the anchored "+kind+" identity without duplication")
		if restored is RuralAnimal: t.check(restored.trust == 3 and restored.saddled,"anchored horse keeps its trust and saddle through distant restoration")
		if restored is ExpeditionCreature and kind == "shulker": t.check(restored.crystal_key == "anchor-regression-guard","anchored city shulker keeps its generator identity")
		if kind in ["horse","turtle"]:
			game.player.position += Vector3(120,0,0)
			game.leads.sleep_if_unloaded(restored)
			await t.process_frame
			game.player.position = Vector3(p)+Vector3(0.5,0.01,-2)
			old_count = drops(game,VillageContent.LEAD)
			if kind == "horse": game.world.set_node(p,Nodes.AIR); game.leads.update(0.1)
			else: game.leads.anchor_at(p)
			game.leads.update(0.1)
			var released: Array = game.creatures.get_children().filter(func(creature: Creature): return creature.kind == kind and not creature.is_queued_for_deletion())
			t.check(released.size() == 1 and game.leads.leads.is_empty() and drops(game,VillageContent.LEAD) == old_count+1,"releasing a sleeping "+kind+" anchor restores its animal before returning exactly one lead")
			if released.is_empty(): continue
			restored = released[0]; restored.set_physics_process(false)
			game.world.set_node(p,Barriers.FIRST)
		game.leads.detach(restored,false)
		Farming.forget(restored)
		if restored is VillageMob: game.villages.state().people.erase(restored.person_key)
		if restored is NetherResident: game.world.adventure_state.nether_residents.erase(restored.resident_key)
		restored.free()
	var doomed: Creature = game.spawn_creature("cow",Vector3(p)+Vector3(1.5,0.01,1.5)); doomed.set_physics_process(false)
	game.leads.attach(doomed,false); game.leads.anchor_at(p)
	var before: int = drops(game,VillageContent.LEAD)
	doomed.die(); game.leads.update(0.1); game.leads.update(0.1)
	t.check(game.leads.leads.is_empty() and drops(game,VillageContent.LEAD) == before+1,"death of an anchored creature drops its lead exactly once")
	await _dormant_city_guard_check(t,game)
	game.day_time = previous_time
	game.pause()

static func _dormant_city_guard_check(t: SceneTree, game: Node3D) -> void:
	var previous_position: Vector3 = game.player.position
	# Install a real empty loaded map block at one of the city's guard sites.
	# The neighboring guard site remains unloaded, making this a single-guard
	# fixture while exercising Adventure.city_guards and normal mob creation.
	var column := Vector2i(18,0)
	var block := Vector3i(18,2,0)
	var anchor := Vector3i(290,43,0)
	var key: String = "291,43,0"
	game.world.columns[column] = true; game.world._create_air_block(block)
	game.world.set_node(anchor,Barriers.FIRST)
	game.player.position = Vector3(288.5,43.01,0.5)
	game.adventure.city_guards()
	var guards: Array = game.creatures.get_children().filter(func(mob: Creature): return mob is ExpeditionCreature and mob.kind == "shulker" and mob.crystal_key == key and not mob.is_queued_for_deletion())
	t.check(guards.size() == 1,"the real city generator creates the anchored guard fixture")
	if guards.size() != 1: return
	var guard: Creature = guards[0]; guard.set_physics_process(false)
	game.leads.attach(guard,false); game.leads.anchor_at(anchor)
	game.player.position += Vector3(120,0,0)
	game.leads.sleep_if_unloaded(guard)
	await t.process_frame
	game.player.position = Vector3(288.5,43.01,0.5)
	game.adventure.city_guards()
	guards = game.creatures.get_children().filter(func(mob: Creature): return mob is ExpeditionCreature and mob.kind == "shulker" and mob.crystal_key == key and not mob.is_queued_for_deletion())
	t.check(guards.is_empty() and game.leads.leads.size() == 1 and game.leads.leads[0].has("sleeping"),"city population recognizes an unnamed guard's sleeping anchor before lead restoration")
	game.leads.update(0.1); game.adventure.city_guards()
	guards = game.creatures.get_children().filter(func(mob: Creature): return mob is ExpeditionCreature and mob.kind == "shulker" and mob.crystal_key == key and not mob.is_queued_for_deletion())
	t.check(guards.size() == 1 and game.leads.anchored(guards[0]),"waking an anchored city guard restores exactly one original guard and its lead")
	game.leads.clear()
	for mob in guards: mob.free()
	game.world.set_node(anchor,Nodes.AIR); game.world.edits.erase(anchor)
	game.world._unload(column)
	game.player.position = previous_position

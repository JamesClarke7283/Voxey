extends RefCounted

static func blank_chest() -> Dictionary:
	var data: Dictionary = {"slots":[]}
	for i in 27: data.slots.append({"id":0,"count":0,"wear":0})
	return data

static func sample_from(air: Dictionary) -> Callable:
	return func(p): return air.get(p,Nodes.STONE)

static func raw_node(result: Dictionary, p: Vector3i) -> int:
	for block in result.blocks:
		if int(block.y) == floori(p.y/16.0): return int(block.data[posmod(p.x,16)+posmod(p.z,16)*16+posmod(p.y,16)*256])
	return -1

static func creatures(game: Node3D, kind: String = "") -> Array:
	return game.creatures.get_children().filter(func(mob): return not mob.is_queued_for_deletion() and (kind.is_empty() or mob.kind == kind))

static func flush_jobs(game: Node3D) -> void:
	for i in 32:
		if Dungeons.runtime(game.world).jobs.is_empty(): return
		Dungeons.update(game.world,0)

static func run(t: SceneTree, game: Node3D) -> void:
	game._clear_entities(); await t.process_frame
	game.state = "playing"; game.gamemode = "survival"; game.daylight = 1.0
	game.player.set_process(false); game.player.set_physics_process(false); game.world.active = false; game.world.set_process(false)
	var gen := TerrainGenerator.new(8675309)
	var origin := Vector3i(3,700,3)
	var air: Dictionary = {origin+Vector3i(0,1,2):Nodes.AIR,origin+Vector3i(0,2,2):Nodes.AIR}
	for size in [Vector2i(5,5),Vector2i(5,7),Vector2i(7,5),Vector2i(7,7)]:
		var plan: Dictionary = Dungeons.plan(gen,origin,size,42,sample_from(air))
		var clear: bool = not plan.is_empty() and plan.spawners.size() == 1 and plan.chests.size() in [1,2]
		for x in range(1,size.x+1):
			for z in range(1,size.y+1):
				for y in range(2,5): clear = clear and plan.voxels.get(origin+Vector3i(x,y,z),-1) == Nodes.AIR
		t.check(clear and not plan.voxels.has(origin+Vector3i(2,5,2)),"source dungeon "+str(size)+" has four clear interior cells, a natural roof, one spawner and up to two wall chests")
	t.check(Dungeons.plan(gen,origin,Vector2i(5,5),2,sample_from({})).is_empty(),"sealed rock with no cave opening rejects a dungeon")
	var invalid: Dictionary = air.duplicate(); invalid[origin+Vector3i(2,0,2)] = Nodes.AIR
	t.check(Dungeons.plan(gen,origin,Vector2i(5,5),2,sample_from(invalid)).is_empty(),"a missing interior floor cell rejects dungeon generation")
	invalid = air.duplicate(); invalid[origin+Vector3i(2,5,2)] = Nodes.AIR
	t.check(Dungeons.plan(gen,origin,Vector2i(5,5),2,sample_from(invalid)).is_empty(),"a missing natural ceiling cell rejects dungeon generation")
	invalid = air.duplicate()
	for x in range(1,6):
		for y in [1,2]: invalid[origin+Vector3i(x,y,0)] = Nodes.AIR
	t.check(Dungeons.plan(gen,origin,Vector2i(5,5),2,sample_from(invalid)).is_empty(),"more than five cave openings rejects a dungeon")
	var corner: Dictionary = {origin+Vector3i(0,1,0):Nodes.AIR,origin+Vector3i(0,2,0):Nodes.AIR}
	t.check(Dungeons.plan(gen,origin,Vector2i(5,5),2,sample_from(corner)).openings.size() == 3,"a corner-only cave entrance is widened along both neighboring walls")
	corner.merge(air)
	t.check(Dungeons.plan(gen,origin,Vector2i(5,5),2,sample_from(corner)).openings.size() == 2,"a normal cave opening does not widen additional corner openings")
	var protected: Vector3i = origin+Vector3i(2,1,2); invalid = air.duplicate(); invalid[protected] = Nodes.BEDROCK
	t.check(not Dungeons.plan(gen,origin,Vector2i(5,5),2,sample_from(invalid)).voxels.has(protected),"dungeon carving preserves non-ground bedrock")
	var moss: int = 0; var floors: int = 0; var kinds: Dictionary = {}
	for seed_value in 128:
		var plan: Dictionary = Dungeons.plan(gen,origin,Vector2i(7,7),seed_value,sample_from(air))
		for p in plan.voxels:
			if p.y == origin.y: floors += 1; moss += 1 if plan.voxels[p] == Nodes.MOSSY_COBBLE else 0
		var kind: String = plan.spawners.values()[0]; kinds[kind] = int(kinds.get(kind,0))+1
	t.check(float(moss)/floors > 0.72 and float(moss)/floors < 0.78,"seeded source floors use three-quarter mossy cobble with ordinary cobble mixed in")
	t.check(kinds.size() == 3 and kinds.zombie > 45 and kinds.zombie < 85 and kinds.spider > 15 and kinds.skeleton > 15,"seeded natural spawners retain source zombie50/spider25/skeleton25 selection")
	var rng := RandomNumberGenerator.new(); rng.seed = 61351
	var drops: Dictionary = {}; var no_soul: bool = true; var chirp_chests: int = 0
	for i in 4000:
		var item: Dictionary = Dungeons.weighted(rng,Dungeons.TREASURE)
		if not item.is_empty():
			drops[item.id] = int(drops.get(item.id,0))+1
			if item.id == VillageContent.ENCHANTED_BOOK: no_soul = no_soul and not item.data.enchantments.has("Soul Speed")
		var chest: Dictionary = blank_chest(); Dungeons.fill(chest,i)
		if chest.slots.any(func(slot): return slot.id == Jukeboxes.CHIRP): chirp_chests += 1
	t.check(drops.has(Jukeboxes.DISC_13) and drops.has(Jukeboxes.FAR) and drops.has(Jukeboxes.CHIRP) and not drops.has(Jukeboxes.MALL) and no_soul,"dungeon treasure includes its three source records and source books exclude Soul Speed")
	t.check(chirp_chests > 110 and chirp_chests < 220,"all three real loot pools give source Chirp probability without renormalizing unavailable entries")
	var first: Dictionary = blank_chest(); var second: Dictionary = blank_chest(); Dungeons.fill(first,190436573); Dungeons.fill(second,190436573)
	t.check(first == second and first.slots.any(func(slot): return slot.id == Jukeboxes.CHIRP),"source chest rolls are deterministic and include an obtainable Chirp fixture")
	# A real seed produces this cave dungeon, crossing the -144 column edge.
	var natural_origin := Vector3i(-145,-11,-13)
	var natural_plan: Dictionary = {}
	var cold: int = Time.get_ticks_usec()
	for plan in Dungeons.region_plans(gen,Vector2i(-5,-1)):
		if plan.origin == natural_origin: natural_plan = plan
	var cold_us: int = Time.get_ticks_usec()-cold
	t.check(not natural_plan.is_empty() and natural_plan.openings.size() in range(1,6),"natural seed8675309 produces a validated cave dungeon at -145,-11,-13")
	if natural_plan.is_empty(): return
	var village_conflict := Vector3i(-735,22,-834)
	t.check(Dungeons.touches_village(gen,village_conflict,Vector2i(5,5)) and not Dungeons.region_plans(gen,Vector2i(-23,-27)).any(func(plan): return plan.origin == village_conflict),"dungeon qualification rejects rooms inside terrain flattened for an existing village")
	var village_column: Dictionary = gen.generate_column(Vector2i(-46,-52),{},true)
	t.check(raw_node(village_column,Vector3i(-732,25,-832)) == Nodes.COBBLE,"natural dungeon generation preserves the actual house floor in the reproduced village collision")
	var repeat_gen := TerrainGenerator.new(8675309)
	t.check(Dungeons.region_plans(gen,Vector2i(-5,-1)) == Dungeons.region_plans(repeat_gen,Vector2i(-5,-1)),"dungeon plans are independent of generator cache and column request order")
	var results: Dictionary = {}
	for coord in [Vector2i(-10,-1),Vector2i(-9,-1)]:
		var result: Dictionary = gen.generate_column(coord,{},false); results[coord] = result
		game.world._apply_column(result)
	var spawner: Vector3i = natural_plan.spawners.keys()[0]
	var chirp_chest := Vector3i(-140,-10,-12)
	var all_cells: bool = true
	for p in natural_plan.voxels:
		if game.world.node_at(p) != natural_plan.voxels[p]: all_cells = false
	t.check(all_cells and game.world.node_at(spawner) == Dungeons.SPAWNER,"normal worker generation and column installation preserve the complete cross-column dungeon")
	var chest: Dictionary = game.world.get_station(chirp_chest,"chest")
	t.check(chest.get("dungeon_loot",false) and chest.slots.any(func(slot): return slot.id == Jukeboxes.CHIRP) and not chest.slots.any(func(slot): return slot.id == VillageContent.HEAVY_CORE),"real generated dungeon chest contains Chirp through source pools without legacy stronghold loot")
	var loot_before: String = JSON.stringify(chest.slots); game.world._structure_loot(chirp_chest,190436573)
	t.check(JSON.stringify(chest.slots) == loot_before,"repeated structure initialization cannot refill or duplicate dungeon loot")
	var edited: Dictionary = gen.generate_column(Vector2i(-9,-1),{chirp_chest:Nodes.AIR},true)
	t.check(raw_node(edited,chirp_chest) == Nodes.AIR,"saved player edits override natural dungeon chests on later generation")
	var halo_equal: bool = true
	var arrays: Array = []
	for coord in [Vector2i(-10,-1),Vector2i(-9,-1)]:
		var data := PackedInt32Array(); data.resize(18*18*64); data.fill(Nodes.STONE)
		var deep := PackedInt32Array(); deep.resize(18*18*128); deep.fill(Nodes.STONE)
		Dungeons.overlay(gen,coord,data,deep); arrays.append(deep)
	for x in [-145,-144]:
		for z in range(-17,1):
			for y in range(-128,0):
				var a: int = arrays[0][x+161+(z+17)*18+(y+128)*324]
				var b: int = arrays[1][x+145+(z+17)*18+(y+128)*324]
				if a != b: halo_equal = false
	t.check(halo_equal,"adjacent columns have identical dungeon overlay voxels throughout both shared halo cells")
	for region in range(40): Dungeons.region_plans(gen,Vector2i(region,8))
	t.check(gen.dungeon_cache.size() <= 32,"dungeon plan cache remains bounded after exploration")
	print("DUNGEON PROFILE cold_region_us=",cold_us," cache_limit=",gen.dungeon_cache.size())
	# Source chest halves can be adjacent. Exercise both arrival orders with a
	# UI-style merge between them, then save empty halves and player contents.
	var paired_fixtures: Array = []
	for reverse in [false,true]:
		var left := Vector3i(6,710+(4 if reverse else 0),4); var right: Vector3i = left+Vector3i.RIGHT
		game.world.set_node(left,Nodes.CHEST); game.world.set_node(right,Nodes.CHEST)
		var a: Vector3i = right if reverse else left; var b: Vector3i = left if reverse else right
		game.world._structure_loot(a,190436573)
		var pair: Dictionary = game.world.get_station(a,"chest")
		game.world._structure_loot(b,99123)
		var expected_a: Dictionary = blank_chest(); var expected_b: Dictionary = blank_chest()
		Dungeons.fill(expected_a,190436573); Dungeons.fill(expected_b,99123)
		var offset_a: int = 27 if reverse else 0; var offset_b: int = 0 if reverse else 27
		t.check(pair.slots.slice(offset_a,offset_a+27) == expected_a.slots and pair.slots.slice(offset_b,offset_b+27) == expected_b.slots,"adjacent dungeon chests initialize each exact27-slot source pool once, arrival reversed="+str(reverse))
		for i in 27: pair.slots[offset_a+i] = {"id":0,"count":0,"wear":0}
		pair.slots[offset_b] = {"id":Nodes.DIAMOND,"count":37,"wear":0,"data":{"custom_name":"Player savings"}}
		var contents: Array = pair.slots.duplicate(true)
		game.world._structure_loot(a,190436573); game.world._structure_loot(b,99123)
		t.check(pair.slots == contents,"revisiting adjacent chests preserves an empty looted half and player diamonds, reversed="+str(reverse))
		paired_fixtures.append({"left":left,"right":right,"offset":offset_b})
	# Old saves without a ledger also keep an entirely empty shared container.
	var legacy_left := Vector3i(10,719,4); var legacy_right: Vector3i = legacy_left+Vector3i.RIGHT
	game.world.set_node(legacy_left,Nodes.CHEST); game.world.set_node(legacy_right,Nodes.CHEST)
	var legacy: Dictionary = game.world.get_station(legacy_left,"chest")
	game.world._structure_loot(legacy_left,190436573); game.world._structure_loot(legacy_right,99123)
	t.check(legacy.slots.all(func(slot):return slot.id == 0),"a preexisting empty shared chest with no half markers never regenerates loot")
	# Focused runtime fixture at high Y: enclosed, dark and fully loaded.
	Dungeons.reset(game.world)
	for x in range(1,16):
		for z in range(1,16):
			for y in range(699,707):
				var wall: bool = x in [1,15] or z in [1,15] or y in [699,706]
				game.world.set_node(Vector3i(x,y,z),Nodes.STONE if wall else Nodes.AIR)
	var p := Vector3i(8,700,8); game.world.set_node(p,Dungeons.SPAWNER)
	game.player.position = Vector3(8.5,700.01,12.5)
	var data: Dictionary = Dungeons.station(game.world,p)
	t.check(Nodes.drop(Dungeons.SPAWNER) == 0 and not Nodes.placeable(Dungeons.SPAWNER) and Nodes.hardness(Dungeons.SPAWNER) == 5 and not game.world.circuits.movable(p),"source spawner has hardness5, no survival drop, no ordinary placement and cannot move by piston")
	var art: Array = BlockMesher._empty(); Dungeons.mesh(art,Vector3.ZERO)
	t.check(not art[0].is_empty() and Dungeons.runtime(game.world).cells[p].get_child_count() > 0 and creatures(game).is_empty(),"cage and rotating miniature use original art without registering a fake living mob")
	game.player.position.x += 30; Dungeons.update(game.world,2.1)
	t.check(creatures(game).is_empty() and data.remaining == 2,"spawner waits and retries after two seconds when no player is within15 nodes")
	game.player.position.x -= 30; data.remaining = 0; Dungeons.update(game.world,0); flush_jobs(game)
	t.check(creatures(game,"zombie").size() == 4 and data.remaining >= 10 and data.remaining <= 39.95,"active dark spawner produces four actual zombies and chooses the source post-attempt delay")
	for animal in creatures(game): animal.set_physics_process(false)
	data.remaining = 0; Dungeons.update(game.world,0)
	t.check(creatures(game,"zombie").size() == 4 and data.remaining >= 5 and data.remaining <= 20,"four same-species mobs within radius8 block another wave with source5..20s retry")
	for animal in creatures(game): animal.queue_free()
	await t.process_frame
	var second_spawner: Vector3i = p+Vector3i.RIGHT*2
	game.world.set_node(second_spawner,Dungeons.SPAWNER)
	data.remaining = 0; Dungeons.station(game.world,second_spawner).remaining = 0
	Dungeons.update(game.world,0); flush_jobs(game)
	t.check(creatures(game,"zombie").size() == 4 and Dungeons.station(game.world,second_spawner).remaining <= 20,"two queued nearby spawners recheck the source cap before each burst and cannot release eight mobs together")
	game.world.set_node(second_spawner,Nodes.AIR)
	for animal in creatures(game): animal.queue_free()
	await t.process_frame
	# Brightness blocks the actual batch; walls block individual spawn sites.
	var lighting: Array = []
	for x in [4,8,12]:
		for z in [4,8,12]:
			var lamp := Vector3i(x,704,z); lighting.append(lamp); game.world.set_node(lamp,Nodes.GLOWSTONE)
	data.remaining = 0; Dungeons.update(game.world,0)
	var pending_delay: float = data.remaining
	Dungeons.update(game.world,40); Dungeons.update(game.world,40)
	t.check(Dungeons.runtime(game.world).jobs.size() == 1 and Dungeons.runtime(game.world).pending.size() == 1 and data.remaining == pending_delay,"slow frames cannot enqueue duplicate spawner waves or advance the post-attempt timer while work is pending")
	flush_jobs(game)
	t.check(creatures(game).is_empty(),"lighting the dungeon disables all hostile spawn candidates")
	for lamp in lighting: game.world.set_node(lamp,Nodes.AIR)
	var random := RandomNumberGenerator.new(); random.seed = 61
	t.check(not Dungeons.allowed(game.world,p,"zombie",random) and not Dungeons.allowed(game.world,Vector3i(9999,700,9999),"zombie",random),"solid spawner cages and unloaded columns reject spawn collision tests")
	var unsupported := Vector3i(5,702,5)
	t.check(Dungeons.allowed(game.world,unsupported,"zombie",random),"source spawner candidates may appear above air when the whole collision box is clear")
	var before_count: int = creatures(game).size(); data.remaining = 0; Dungeons.update(game.world,0)
	var job: Dictionary = Dungeons.runtime(game.world).jobs[0] if not Dungeons.runtime(game.world).jobs.is_empty() else {}
	t.check(job.is_empty() or job.cursor <= 8,"one gameplay frame examines at most eight spawner positions across the global work queue")
	Dungeons.unload(game.world,Vector2i(0,0)); var remaining: float = data.remaining
	Dungeons.update(game.world,30)
	t.check(not Dungeons.runtime(game.world).cells.has(p) and Dungeons.runtime(game.world).jobs.is_empty() and data.remaining == remaining,"column unload removes doll and queued work while preserving its saved paused timer")
	Dungeons.registered(game.world,p); Dungeons.registered(game.world,p)
	t.check(Dungeons.runtime(game.world).cells.size() == 1 and data.remaining == remaining,"repeated load registration restores one doll and never resets the spawner timer")
	for animal in creatures(game): animal.queue_free()
	await t.process_frame
	var xp: int = game.experience; game.break_node(p,Dungeons.SPAWNER,Nodes.TOOLS+5)
	t.check(game.world.node_at(p) == Nodes.AIR and not Dungeons.runtime(game.world).cells.has(p) and not game.world.stations.has(VoxelWorld.station_key(p)) and game.experience-xp >= 15 and game.experience-xp <= 43,"actual mining removes the spawner and grants the source15..43 XP once")
	Dungeons.changed(game.world,p,Nodes.AIR,Nodes.AIR)
	t.check(game.experience-xp <= 43,"ordinary repeated cleanup does not duplicate spawner mining XP")
	# Persist an active species and countdown through the actual game loader.
	game.world.set_node(p,Dungeons.SPAWNER); data = Dungeons.station(game.world,p); data.mob = "skeleton"; data.remaining = 17.25
	game.player.position = Vector3(8.5,700.01,12.5)
	game.save_game("user://dungeon-check.json"); var saved: Dictionary = game.read_save("user://dungeon-check.json")
	game.set_process(true); game.world.set_process(true); game.load_world_data(saved)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	data = Dungeons.station(game.world,p)
	t.check(game.world.node_at(p) == Dungeons.SPAWNER and data.mob == "skeleton" and absf(data.remaining-17.25) < 0.5 and Dungeons.runtime(game.world).cells.has(p),"real save/load preserves spawner species, countdown and exactly one active visual")
	for fixture in paired_fixtures:
		var pair: Dictionary = game.world.get_station(fixture.left,"chest")
		game.world._structure_loot(fixture.left,190436573); game.world._structure_loot(fixture.right,99123)
		var offset: int = fixture.offset; var empty_offset: int = 27-offset
		t.check(int(pair.slots[offset].id) == Nodes.DIAMOND and int(pair.slots[offset].count) == 37 and pair.slots[offset].get("data",{}).get("custom_name","") == "Player savings" and pair.slots.slice(empty_offset,empty_offset+27).all(func(slot): return int(slot.id) == 0),"actual save/load and rediscovery preserve paired player contents and permanently empty looted half")
	Dungeons.reset(game.world)
	t.check(not game.world.has_meta("dungeons"),"dimension/reset cleanup clears every runtime spawner reference")
	game.state = "playing"; game.player.set_process(false); game.player.set_physics_process(false)

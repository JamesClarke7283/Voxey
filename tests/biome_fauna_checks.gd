extends RefCounted

# Source biome-only fauna: natural mooshrooms and ocelots unlocked by real
# biome selection. Reference: mobs_mc/{cow+mooshroom,ocelot,spawning}.lua.

static func hold(game: Node3D, id: int, count: int = 1) -> void:
	game.inventory.slots[game.inventory.selected] = {"id":id,"count":count,"wear":0}

static func run(suite: Object, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var old_slots: Array = game.inventory.slots.duplicate(true)
	var old_selected: int = game.inventory.selected
	var old_position: Vector3 = game.player.position
	var old_mode: String = game.gamemode
	game.gamemode = "survival"
	game.inventory.selected = 0
	game.daylight = 1.0
	for mob in game.creatures.get_children(): mob.free()
	var arena := Vector3i(768,35,-3328)
	for column in [Vector2i(arena.x >> 4,arena.z >> 4),Vector2i(arena.x >> 4,-207),Vector2i(47,-208),Vector2i(48,-207)]:
		world._apply_column(world.generator.generate_column(column,world.edits))
	for x in range(-16,17):
		for z in range(-16,17):
			world.set_node(arena+Vector3i(x,-1,z),SoilVariants.MYCELIUM)
			for y in range(0,5): world.set_node(arena+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(arena)+Vector3(0.5,0,0.5)
	world.target = game.player.position
	suite.check(world.loaded_at(Vector3(arena)) and BiomeFauna.mooshroom_allowed(world,arena),"the mushroom arena is a loaded MushroomIslands mycelium cell")
	world.columns[Vector2i(arena.x >> 4,arena.z >> 4)] = true
	# --- mushroom island vegetation ----------------------------------------------------
	var island_blocks: Dictionary = {}
	var island_stems: int = 0
	var island_caps: int = 0
	for column in [Vector2i(50,-201),Vector2i(50,-200),Vector2i(49,-201),Vector2i(50,-202)]:
		var generated: Dictionary = world.generator.generate_column(column,{},true)
		for block in generated.blocks:
			for index in block.data.size():
				var value: int = block.data[index]
				if not HugeMushrooms.is_huge(value): continue
				island_blocks[value] = int(island_blocks.get(value,0))+1
				if HugeMushrooms.is_stem(value): island_stems += 1
				else: island_caps += 1
	suite.check(not island_blocks.is_empty(),"MushroomIslands generates natural huge mushrooms")
	suite.check(island_stems > 0 and island_caps > island_stems,"a natural huge mushroom has a real stem and capped body")
	var species_seen: Dictionary = {}
	for x in range(752,785):
		for z in range(-3344,-3311):
			if world.generator.biome(x,z) != "MushroomIslands": continue
			if world.generator.hash_at(x,701,z)%97 != 0: continue
			species_seen[Nodes.RED_MUSHROOM if world.generator.hash_at(x,702,z)%2 == 0 else Nodes.BROWN_MUSHROOM] = true
	suite.check(species_seen.has(Nodes.RED_MUSHROOM) and species_seen.has(Nodes.BROWN_MUSHROOM),"the island feature candidates select both source species")

	# --- mooshrooms -------------------------------------------------------------------
	suite.check(BiomeFauna.mooshroom_share("MushroomIslands") == 1.0 and BiomeFauna.mooshroom_share("Jungle") == 0.0,"mooshrooms are the mushroom island's only creature spawner")
	suite.check(BiomeFauna.MOOSHROOM_PACK_MIN == 4 and BiomeFauna.MOOSHROOM_PACK_MAX == 8,"mooshrooms spawn in the source's four-to-eight pack")
	suite.check(BiomeFauna.mooshroom_allowed(world,arena),"mycelium and light make a valid mooshroom cell")
	world.set_node(arena+Vector3i.DOWN,Nodes.DIRT)
	suite.check(not BiomeFauna.mooshroom_allowed(world,arena),"plain dirt does not support a mooshroom")
	world.set_node(arena+Vector3i.DOWN,SoilVariants.MYCELIUM)
	world.set_node(arena+Vector3i.UP,Nodes.STONE)
	suite.check(not BiomeFauna.mooshroom_allowed(world,arena),"an obstructed cell rejects a mooshroom")
	world.set_node(arena+Vector3i.UP,Nodes.AIR)
	for x in range(-16,17):
		for z in range(-16,17):
			world.set_node(arena+Vector3i(x,-1,z),SoilVariants.MYCELIUM)
			for y in range(0,5): world.set_node(arena+Vector3i(x,y,z),Nodes.AIR)
	var pack_center := arena+Vector3i(0,0,8)
	for mob in game.creatures.get_children(): mob.free()
	game.inventory.restore([])
	var moos: Array = BiomeFauna.spawn_mooshrooms(game,Vector3(pack_center)+Vector3(0.5,0.01,0.5),RandomNumberGenerator.new())
	suite.check(moos.size() >= 4 and moos.size() <= 8 and moos.all(func(m): return m.kind == BiomeFauna.MOOSHROOM),"a real spawn attempt produces a mooshroom pack")
	if not moos.is_empty():
		suite.check(MooshroomStew.handles(moos[0].kind) and moos[0].head != null,"a natural mooshroom owns its stew state and body")

	# --- ocelots ----------------------------------------------------------------------
	var jungle := Vector3i(72,32,-280)
	for column in [Vector2i(jungle.x >> 4,jungle.z >> 4),Vector2i(4,-18),Vector2i(5,-18),Vector2i(4,-17)]:
		world._apply_column(world.generator.generate_column(column,world.edits))
	for x in range(-16,17):
		for z in range(-16,17):
			world.set_node(jungle+Vector3i(x,-1,z),Nodes.GRASS)
			for y in range(0,5): world.set_node(jungle+Vector3i(x,y,z),Nodes.AIR)
	suite.check(world.loaded_at(Vector3(jungle)) and BiomeFauna.ocelot_biome(world.generator.biome(jungle.x,jungle.z)),"the fauna arena lies in a loaded jungle")
	world.columns[Vector2i(jungle.x >> 4,jungle.z >> 4)] = true
	suite.check(BiomeFauna.ocelot_biome("Jungle") and BiomeFauna.ocelot_biome("BambooJungle") and not BiomeFauna.ocelot_biome("Forest"),"ocelots use the two jungle spawners")
	suite.check(BiomeFauna.ocelot_pack_max("Jungle") == 3 and BiomeFauna.ocelot_pack_max("BambooJungle") == 1,"the source packs differ between Jungle and BambooJungle")
	world.set_node(jungle+Vector3i.DOWN,SoilVariants.MYCELIUM)
	suite.check(not BiomeFauna.ocelot_allowed(world,jungle,0.0),"mycelium is not an ocelot floor")
	world.set_node(jungle+Vector3i.DOWN,Nodes.GRASS)
	suite.check(BiomeFauna.ocelot_allowed(world,jungle,0.0) and not BiomeFauna.ocelot_allowed(world,jungle,0.5),"ocelots require the source's one-in-three position roll")
	world.set_node(jungle+Vector3i.DOWN,WoodTypes.leaves_id(3))
	suite.check(BiomeFauna.ocelot_allowed(world,jungle,0.0),"leaves can support an ocelot")
	var ocelot: Creature = game.spawn_creature(BiomeFauna.OCELOT,Vector3(jungle)+Vector3(2.5,0.01,0.5))
	if ocelot != null: ocelot.set_physics_process(false)
	suite.check(ocelot != null and ocelot.head != null and not BiomeFauna.trusts(ocelot),"an untrusted ocelot spawns with its body")
	game.player.position = Vector3(jungle)+Vector3(0.5,0,0.5)
	hold(game,VillageContent.RAW_COD,8)
	suite.check(game.inventory.held().id == VillageContent.RAW_COD,"the held cod is visible to the ocelot interaction")
	ocelot.position = game.player.position+Vector3(3,0,0)
	suite.check(BiomeFauna.direction(game,ocelot) != Vector3.INF and BiomeFauna.following(ocelot),"a fish holder inside six draws a shy ocelot")
	ocelot.position = game.player.position+Vector3(4,0,0)
	suite.check(BiomeFauna.direction(game,ocelot) != Vector3.INF,"the shy ocelot keeps following between two and six")
	ocelot.position = game.player.position+Vector3(7,0,0)
	suite.check(BiomeFauna.direction(game,ocelot) == Vector3.INF and not BiomeFauna.following(ocelot),"an ocelot stops beyond six")
	ocelot.position = game.player.position+Vector3(3,0,0)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var tries: int = 0
	while not BiomeFauna.trusts(ocelot) and tries < 80:
		BiomeFauna.direction(game,ocelot)
		BiomeFauna.use_ocelot(game,ocelot,rng); tries += 1
	suite.check(BiomeFauna.trusts(ocelot) and ocelot.has_meta("persistent"),"repeated followed fish eventually earns trust")
	suite.check(game.inventory.held().count == 8-tries,"every trust attempt consumes one fish")
	suite.check(BiomeFauna.direction(game,ocelot) == Vector3.INF,"a trusting ocelot no longer follows shyly")
	ocelot.health = 6.0
	hold(game,VillageContent.RAW_SALMON,8)
	BiomeFauna.use_ocelot(game,ocelot,rng)
	suite.check(is_equal_approx(ocelot.health,8.0),"a trusting ocelot heals from fish")
	ocelot.health = 10.0
	BiomeFauna.use_ocelot(game,ocelot,rng)
	suite.check(ocelot.love_time > 0.0,"a full-health trusting ocelot breeds")
	var partner: Creature = game.spawn_creature(BiomeFauna.OCELOT,Vector3(jungle)+Vector3(2.5,0.01,1.0))
	if partner != null:
		partner.set_physics_process(false)
		partner.set_meta("ocelot_trusts",true)
		partner.love_time = Farming.LOVE_TIME
		var cat: Node3D = null
		for i in 80:
			cat = BiomeFauna.breed_step(game,ocelot,0.1)
			if cat != null: break
		suite.check(cat != null and cat.kind == Cats.KIND and Cats.tamed(cat) and Cats.owner(cat) == game.player_id,"an ocelot pair's child is the owner's tamed cat")
	# Persistence.
	var saved: Dictionary = BiomeFauna.snapshot(ocelot)
	var restored: Creature = game.spawn_creature(BiomeFauna.OCELOT,Vector3(jungle)+Vector3(5.5,0.01,5.5))
	if restored != null:
		restored.set_physics_process(false)
		BiomeFauna.restore(restored,saved)
		suite.check(BiomeFauna.trusts(restored) and restored.has_meta("persistent"),"trust survives a saved fauna record")
		restored.free()
	for mob in game.creatures.get_children(): mob.free()
	game.inventory.slots = old_slots
	game.inventory.selected = old_selected
	game.player.position = old_position
	game.gamemode = old_mode

extends RefCounted

static func run(suite: SceneTree, game: Node3D) -> void:
	var new_nodes: Array = [Nodes.VINE,Nodes.RED_BRICKS,Nodes.HAY_BALE,Nodes.SUGAR_CANE,Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,Nodes.MOSSY_COBBLE,Nodes.MOSSY_BRICKS,Nodes.COAL_BLOCK,Nodes.TERRACOTTA]
	var new_items: Array = [Nodes.CHARCOAL,Nodes.BOWL,Nodes.MUSHROOM_STEW,Nodes.GOLD_NUGGET,Nodes.IRON_NUGGET,Nodes.EGG]
	var atlas: Image = Art.make_atlas().get_image()
	_bed_render_checks(suite,atlas)
	_bed_blast_checks(suite,game)
	_anchor_checks(suite,game)
	var atlas_ok: bool = true
	# Regressions: expansion tiles used to be blank or alias unrelated faces.
	for id in new_nodes+[Nodes.BED_FOOT,Nodes.BED_HEAD,Nodes.GLOWSTONE,Nodes.IRON_BLOCK,Nodes.GOLD_BLOCK,Nodes.DIAMOND_BLOCK,Nodes.SANDSTONE,Nodes.SANDSTONE_BRICK,Nodes.ICE,Nodes.SNOW_BLOCK]:
		for face in 6:
			var tile: int = Nodes.tile(id,face)
			var occupied: int = 0
			for y in 16:
				for x in 16:
					if atlas.get_pixel(tile%8*16+x,tile/8*16+y).a > 0.5: occupied += 1
			if occupied == 0: atlas_ok = false
	suite.check(atlas_ok,"every new and repaired block face has visible atlas pixels")
	suite.check(Nodes.tile(Nodes.SANDSTONE,0) != Nodes.tile(Nodes.GRASS,2) and Nodes.tile(Nodes.ICE,0) != Nodes.tile(Nodes.WORKBENCH,2),"sandstone and ice no longer alias grass and crafting table textures")
	for id in new_nodes:
		var mesh: ArrayMesh = Art.build_node_mesh(id)
		suite.check(mesh.get_surface_count() == 1 and Nodes.placeable(id),Nodes.title(id)+" renders as a placeable node")
	var gen := TerrainGenerator.new(8675309)
	var found: Dictionary = {}
	for z in range(-4,5):
		for x in range(-4,5):
			if found.has(Nodes.SUGAR_CANE) and found.has(Nodes.RED_MUSHROOM) and found.has(Nodes.BROWN_MUSHROOM): break
			var column: Dictionary = gen.generate_column(Vector2i(x,z),{})
			for block in column.blocks:
				for id in [Nodes.SUGAR_CANE,Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,Nodes.VINE]:
					if block.data.has(id): found[id] = true
	# Source oak layouts do not grow jungle vines. Sample the deterministic
	# warm swamp jungle as well as the spawn region for the acquisition check.
	var jungle: Dictionary = gen.generate_column(Vector2i(24,-38),{},true)
	for block in jungle.blocks:
		if block.data.has(Nodes.VINE): found[Nodes.VINE] = true
	for id in [Nodes.SUGAR_CANE,Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,Nodes.VINE]:
		suite.check(found.has(id),Nodes.title(id)+" can be gathered in generated terrain")
	var expected_new: Array = new_nodes+new_items
	var unique_ids: Dictionary = {}
	for id in Nodes.all_ids(): unique_ids[id] = true
	suite.check(unique_ids.size() == Nodes.all_ids().size() and not Nodes.custom_items.has(Nodes.CLOCK),"mod item allocation does not shadow the clock or built-in items")
	for id in expected_new:
		var slot: Dictionary = Inventory.clean_slot({"id":id,"count":1,"wear":0})
		suite.check(slot.id == id and Nodes.lookup(Nodes.title(id)) == id,Nodes.title(id)+" survives inventory serialization and name lookup")
	# Exercise the actual guide/grid transaction, including previously ambiguous clay.
	var catalog := Inventory.new()
	for recipe in catalog.recipes:
		if recipe.id not in expected_new+[Nodes.SUGAR,Nodes.PAPER,Nodes.PUMPKIN_PIE]: continue
		var bag := Inventory.new()
		for ingredient in recipe.ingredients: bag.add_item(ingredient,recipe.ingredients[ingredient])
		var index: int = catalog.recipes.find(recipe)
		var filled: bool = bag.fill_grid(index,recipe.station)
		var result: Dictionary = bag.take_grid_result(recipe.station)
		suite.check(filled and result.get("id",0) == recipe.id and result.get("count",0) == recipe.count,"guide and real grid craft "+recipe.name)
	var soup := Inventory.new()
	soup.grid[0] = {"id":Nodes.BROWN_MUSHROOM,"count":2,"wear":0}
	soup.grid[3] = {"id":Nodes.BOWL,"count":1,"wear":0}
	soup.grid[4] = {"id":Nodes.RED_MUSHROOM,"count":1,"wear":0}
	var stew: Dictionary = soup.take_grid_result("hand")
	suite.check(stew.get("id",0) == Nodes.MUSHROOM_STEW and soup.grid[0].count == 1,"shapeless stew accepts scattered ingredients and consumes one of each")
	soup.grid[1] = {"id":Nodes.DIRT,"count":1,"wear":0}
	suite.check(soup.matching_recipe("hand") == -1,"extra ingredients prevent a shapeless match")
	for pair in [[Nodes.COAL,Nodes.COAL_BLOCK],[Nodes.GRAIN,Nodes.HAY_BALE],[Nodes.GOLD_NUGGET,Nodes.GOLD],[Nodes.IRON_NUGGET,Nodes.IRON]]:
		var bag := Inventory.new(); bag.add_item(pair[0],9)
		var packed: bool = false; var unpacked: bool = false
		for i in bag.recipes.size():
			var recipe: Dictionary = bag.recipes[i]
			if recipe.id == pair[1] and recipe.ingredients.get(pair[0],0) == 9: packed = bag.craft(i,"table")
		for i in bag.recipes.size():
			var recipe: Dictionary = bag.recipes[i]
			if recipe.id == pair[0] and recipe.ingredients.get(pair[1],0) == 1: unpacked = bag.craft(i,"hand")
		suite.check(packed and unpacked and bag.count_item(pair[0]) == 9,"packing and unpacking conserves "+Nodes.title(pair[0]))
	var furnace: Dictionary = game.world.get_station(Vector3i(8,46,8),"furnace")
	for pair in [[Nodes.LOG,Nodes.CHARCOAL],[Nodes.CLAY,Nodes.TERRACOTTA],[Nodes.CLAY_BALL,Nodes.BRICK_ITEM]]:
		furnace.slots = [{"id":pair[0],"count":1,"wear":0},{"id":Nodes.CHARCOAL,"count":1,"wear":0},{"id":0,"count":0,"wear":0}]
		furnace.burn = 0; furnace.progress = 0
		for i in 8: game.world._simulate()
		suite.check(furnace.slots[2].id == pair[1] and furnace.slots[2].count == 1,"charcoal fuel smelts "+Nodes.title(pair[1]))
	# Eating soup returns the container and preserves item ids above 255 in saves.
	var old_slots: Array = game.inventory.slots.duplicate(true)
	var old_selected: int = game.inventory.selected
	var old_hunger: float = game.player.hunger
	game.inventory.selected = 0
	game.inventory.slots[0] = {"id":Nodes.MUSHROOM_STEW,"count":1,"wear":0}
	var bowls_before: int = game.inventory.count_item(Nodes.BOWL)
	game.player.hunger = 10
	game.player.use()
	var eating_state: String = game.state
	game.state = "playing"
	Eating.update(game.player,Eating.DURATION,true)
	game.state = eating_state
	suite.check(game.player.hunger == 16 and game.inventory.count_item(Nodes.BOWL) == bowls_before+1,"eating stew restores six hunger and returns its bowl")
	game.inventory.slots[0] = {"id":Nodes.GOLD_NUGGET,"count":9,"wear":0}
	suite.check(game.save_game("user://voxey_content_test.json"),"expanded inventory saves successfully")
	var saved: Dictionary = game.read_save("user://voxey_content_test.json")
	suite.check(int(saved.inventory[0].id) == Nodes.GOLD_NUGGET,"saved item ids above the voxel byte range retain their identity")
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://voxey_content_test.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	game.inventory.slots = old_slots; game.inventory.selected = old_selected; game.player.hunger = old_hunger
	# Cane planting, capped growth and harvesting a complete upper stalk.
	var cane := Vector3i(8,45,8)
	for y in range(-1,5): game.world.set_node(cane+Vector3i.UP*y,Nodes.AIR)
	game.world.set_node(cane+Vector3i.DOWN,Nodes.SAND)
	for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]: game.world.set_node(cane+Vector3i.DOWN+d,Nodes.DIRT)
	suite.check(not game.world.can_plant_cane(cane),"cane rejects a dry planting site")
	game.world.set_node(cane+Vector3i.DOWN+Vector3i.RIGHT,Nodes.WATER)
	suite.check(game.world.can_plant_cane(cane),"cane accepts a bank beside water")
	game.world.set_node(cane,Nodes.SUGAR_CANE)
	for level in 3:
		game.world.growth[cane+Vector3i.UP*level] = 61.0
		game.world._simulate()
	suite.check(game.world.node_at(cane+Vector3i.UP*2) == Nodes.SUGAR_CANE and game.world.node_at(cane+Vector3i.UP*3) == Nodes.AIR,"cane grows up to three nodes tall")
	game.break_node(cane+Vector3i.UP,Nodes.SUGAR_CANE,0)
	suite.check(game.world.node_at(cane+Vector3i.UP*2) == Nodes.AIR and game.world.growth.has(cane),"cutting cane removes unsupported tops and starts regrowth")
	# Real pixel silhouettes in 3D; triangles must face out on front and sides.
	for id in new_items+[Nodes.TOOLS,Nodes.DIAMOND,Nodes.BOW]:
		var mesh: ArrayMesh = ItemArt.mesh(id)
		suite.check(_outward(mesh) and mesh.get_aabb().size.z > 0 and mesh == ItemArt.mesh(id),Nodes.title(id)+" has a cached solid pixel mesh with outward faces")
	for kind in ["zombie","skeleton","spider","creeper"]:
		var mob: Creature = game.spawn_creature(kind,game.player.position+Vector3(2,0,0))
		mob.set_physics_process(false)
		var texture: Texture2D = mob.parts[0].material_override.albedo_texture
		var original: Color = mob.parts[0].material_override.albedo_color
		mob.direction = Vector3.FORWARD; mob.life = 0.2; mob.animate(0.5)
		var pose_changed: bool = absf(mob.legs[0].rotation.x)+absf(mob.legs[0].rotation.z) > 0
		mob._tint(Color.RED,0.55); mob._tint(Color.WHITE,0)
		suite.check(texture != null and _outward(mob.parts[0].mesh) and pose_changed and mob.parts[0].material_override.albedo_color == original,kind+" has a textured, animated model that restores its damage tint")
		mob.free()
	var chicken: Creature = game.spawn_creature("chicken",game.player.position+Vector3(2,0,0))
	chicken.set_physics_process(false); chicken.egg_timer = 0.01
	game.resume(); chicken._physics_process(0.02); game.pause()
	var egg_found: bool = false
	for drop in game.drops.get_children():
		if drop.item_id == Nodes.EGG: egg_found = true
	suite.check(egg_found and chicken.egg_timer >= 90,"chickens lay collectible eggs and reset their timer")
	chicken.free()

# A bed in the Nether or the End explodes, which is the source's own rule and the
# reason the rule exists: the blast is what punishes trying it. `explode` gained an
# opt-in `fire` flag for this, because the source's `info.fire` makes one destroyed
# node in three burn rather than simply vanish.
static func _bed_blast_checks(suite: SceneTree, game: Node3D) -> void:
	game.pause(); game.world.set_process(false); game.world.active = false
	var was_dimension: String = game.world.dimension
	var was_mode: String = game.gamemode
	game.gamemode = "survival"
	var floor := Vector3i(8,200,8)
	for x in range(4,13):
		for y in range(197,204):
			for z in range(4,13): game.world.set_node(Vector3i(x,y,z),Nodes.NETHERRACK)
	for x in range(6,11):
		for z in range(6,11): game.world.set_node(Vector3i(x,200,z),Nodes.AIR)
	# An ordinary blast leaves no fire.
	for i in 6: game.explode(Vector3(8.5,200.5,8.5),2.5,null,false)
	var plain_fires: int = 0
	for x in range(4,13):
		for y in range(197,204):
			for z in range(4,13):
				if Fire.is_fire(game.world.node_at(Vector3i(x,y,z))): plain_fires += 1
	suite.check(plain_fires == 0,"an ordinary blast sets no fires, which is the source's default")
	# A blast asked to burn does set them.
	for x in range(4,13):
		for y in range(197,204):
			for z in range(4,13): game.world.set_node(Vector3i(x,y,z),Nodes.NETHERRACK)
	for x in range(6,11):
		for z in range(6,11): game.world.set_node(Vector3i(x,200,z),Nodes.AIR)
	# The one-in-three roll is per destroyed node, so a single blast may leave no
	# fire at all. Rebuild and blast until it lands rather than asserting on one roll
	# — a check that depends on a dice roll is a flaky check, not a check.
	var burning: int = 0
	for attempt in 12:
		if burning > 0: break
		for x in range(4,13):
			for y in range(197,204):
				for z in range(4,13): game.world.set_node(Vector3i(x,y,z),Nodes.STONE)
		for x in range(6,11):
			for z in range(6,11): game.world.set_node(Vector3i(x,200,z),Nodes.AIR)
		game.explode(Vector3(8.5,200.5,8.5),2.5,null,true)
		for x in range(4,13):
			for y in range(197,204):
				for z in range(4,13):
					if Fire.is_fire(game.world.node_at(Vector3i(x,y,z))): burning += 1
	suite.check(burning > 0,"a blast asked to burn leaves fire, as the source's `info.fire` does")
	# And the real rule: a bed in the Nether is destroyed and blasts, where Voxey used
	# to only refuse it with a message.
	game.dimension = "nether"; game.world.dimension = "nether"
	for x in range(4,13):
		for y in range(197,204):
			for z in range(4,13): game.world.set_node(Vector3i(x,y,z),Nodes.NETHERRACK)
	for x in range(6,11):
		for z in range(6,11): game.world.set_node(Vector3i(x,200,z),Nodes.AIR)
	game.world.set_node(floor,Nodes.BED_FOOT)
	game.world.set_node(floor+Vector3i.RIGHT,Nodes.BED_HEAD)
	suite.check(VillageContent.is_bed(game.world.node_at(floor)),"a bed can be placed for the blast check")
	game.sleep_at(floor)
	suite.check(game.world.node_at(floor) == Nodes.AIR and game.world.node_at(floor+Vector3i.RIGHT) == Nodes.AIR,"a bed in the Nether is destroyed outright, taking both halves")
	var blast_fires: int = 0
	for x in range(4,13):
		for y in range(197,204):
			for z in range(4,13):
				if Fire.is_fire(game.world.node_at(Vector3i(x,y,z))): blast_fires += 1
	suite.check(blast_fires > 0,"a Nether bed's blast sets fires, as the source's strength-five blast does")
	game.dimension = was_dimension; game.world.dimension = was_dimension
	game.gamemode = was_mode
	game.world.active = true

# The respawn anchor: the Nether's answer to a bed. It charges with glowstone up to
# four, and a **charged** one used outside the Nether explodes with fire — the source's
# other `info.fire` blast. An uncharged one is harmless, which is what makes the block
# safe to carry and dangerous to arm.
static func _anchor_checks(suite: SceneTree, game: Node3D) -> void:
	for id in RespawnAnchors.BLOCKS:
		suite.check(VillageContent.DATA.has(id),"the respawn anchor block %d is registered" % id)
	suite.check(RespawnAnchors.charge(RespawnAnchors.BASE) == 0 and RespawnAnchors.charge(RespawnAnchors.CHARGED_4) == 4,"the anchor's charge levels are zero through four")
	suite.check(RespawnAnchors.light_level(RespawnAnchors.CHARGED_1) == 3 and RespawnAnchors.light_level(RespawnAnchors.CHARGED_4) == 15,"the source's light levels of three through fifteen are used")
	suite.check(RespawnAnchors.comparator_signal(RespawnAnchors.CHARGED_2) == 7,"the source's comparator signal of four per charge less one")
	suite.check(is_equal_approx(RespawnAnchors.HARDNESS,50.0) and RespawnAnchors.BLAST_RESISTANCE == 1200,"the anchor is the source's hard, blast-resistant block")
	var anchor_at := Vector3i(8,1800,8)
	for x in range(6,11):
		for y in range(1797,1804):
			for z in range(6,11): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	for x in range(6,11):
		for z in range(6,11): game.world.set_node(Vector3i(x,1799,z),Nodes.STONE)
	# Charging takes a glowstone and stops at four.
	game.world.set_node(anchor_at,RespawnAnchors.BASE)
	for i in 4:
		suite.check(RespawnAnchors.charge_up(game.world,anchor_at),"charge %d is accepted" % (i+1))
	suite.check(RespawnAnchors.charge(game.world.node_at(anchor_at)) == 4,"the anchor charges to four")
	suite.check(not RespawnAnchors.charge_up(game.world,anchor_at),"a full anchor refuses another glowstone")
	# The asymmetry: harmless uncharged, explosive charged, and both safe in the Nether.
	var was_dimension: String = game.world.dimension
	game.dimension = "overworld"; game.world.dimension = "overworld"
	game.world.set_node(anchor_at,RespawnAnchors.BASE)
	suite.check(not RespawnAnchors.use(game,anchor_at) and game.world.node_at(anchor_at) == RespawnAnchors.BASE,"an uncharged anchor is inert outside the Nether")
	game.world.set_node(anchor_at,RespawnAnchors.CHARGED_2)
	suite.check(RespawnAnchors.use(game,anchor_at) and game.world.node_at(anchor_at) == Nodes.AIR,"a charged anchor explodes outside the Nether")
	game.dimension = "nether"; game.world.dimension = "nether"
	game.world.set_node(anchor_at,RespawnAnchors.CHARGED_3)
	var spawn_before: Vector3 = game.spawn_point
	suite.check(RespawnAnchors.use(game,anchor_at) and game.world.node_at(anchor_at) == RespawnAnchors.CHARGED_3,"a charged anchor survives in the Nether and sets the spawn")
	suite.check(game.spawn_point != spawn_before,"using it in the Nether moves the player's spawn")
	game.dimension = was_dimension; game.world.dimension = was_dimension
	game.world.set_node(anchor_at,Nodes.AIR)
	# The recipe is the source's own shape.
	var recipe: int = game.inventory.recipe_index(RespawnAnchors.BASE)
	suite.check(recipe >= 0,"the respawn anchor has a recipe")
	if recipe >= 0:
		suite.check(int(game.inventory.recipes[recipe].ingredients.get(Bastions.CRYING_OBSIDIAN,0)) == 6,"and it takes six crying obsidian")
		suite.check(int(game.inventory.recipes[recipe].ingredients.get(Nodes.GLOWSTONE,0)) == 3,"plus three glowstone")

static func _bed_render_checks(suite: SceneTree, atlas: Image) -> void:
	for id in [Nodes.BED_FOOT,Nodes.BED_HEAD]:
		var mesh: ArrayMesh = Art.build_node_mesh(id)
		var arrays: Array = mesh.surface_get_arrays(0)
		suite.check(_outward(mesh),Nodes.title(id)+" faces outward on every side")
		suite.check(arrays[Mesh.ARRAY_VERTEX].size() == 24 and Array(arrays[Mesh.ARRAY_NORMAL]).filter(func(n): return n.dot(Vector3.DOWN) > 0.999).size() == 4,Nodes.title(id)+" has a closed mesh including its underside")
		var opaque: bool = true
		var tile: int = Nodes.tile(id,2)
		for y in 16:
			for x in 16:
				if atlas.get_pixel(tile%8*16+x,tile/8*16+y).a != 1.0: opaque = false
		suite.check(opaque,Nodes.title(id)+" texture is fully opaque")
	# Check each facing at the center and on all four map-block boundaries.
	var correct_neighbors: bool = true
	for cell in [Vector3i(7,7,7),Vector3i(0,7,7),Vector3i(15,7,7),Vector3i(7,7,0),Vector3i(7,7,15)]:
		for direction in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
			var data := PackedByteArray(); data.resize(5832)
			var p: Vector3i = cell+Vector3i.ONE
			var neighbor: Vector3i = p+direction
			data[p.x+p.z*18+p.y*324] = Nodes.BED_FOOT
			data[neighbor.x+neighbor.z*18+neighbor.y*324] = Nodes.STONE
			var surface: Array = BlockMesher.build(data)[0]
			var bed_sides: Dictionary = {}
			for i in surface[Mesh.ARRAY_VERTEX].size():
				if surface[Mesh.ARRAY_TEX_UV2][i] == Vector2(0,7):
					var normal: Vector3 = surface[Mesh.ARRAY_NORMAL][i]
					if normal.y == 0: bed_sides[normal] = true
			if bed_sides.size() != 3 or bed_sides.has(Vector3(direction)): correct_neighbors = false
	suite.check(correct_neighbors,"bed sides only hide against their actual neighbor, including chunk borders")
	var full_faces: bool = true
	for direction in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]:
		var data := PackedByteArray(); data.resize(5832)
		var p := Vector3i(8,8,8)
		var neighbor: Vector3i = p+direction
		data[p.x+p.z*18+p.y*324] = Nodes.STONE
		data[neighbor.x+neighbor.z*18+neighbor.y*324] = Nodes.BED_HEAD
		var surface: Array = BlockMesher.build(data)[0]
		var exposed: bool = false
		for i in surface[Mesh.ARRAY_VERTEX].size():
			if surface[Mesh.ARRAY_TEX_UV2][i] == Vector2(3,0) and surface[Mesh.ARRAY_NORMAL][i] == Vector3(direction): exposed = true
		if not exposed: full_faces = false
	suite.check(full_faces,"half-height beds do not punch holes in surrounding floor and wall meshes")

static func _outward(mesh: ArrayMesh) -> bool:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0,indices.size(),3):
		var a: int = indices[i]; var b: int = indices[i+1]; var c: int = indices[i+2]
		if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).dot(normals[a]) >= 0: return false
	return true

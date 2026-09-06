extends RefCounted

static func run(suite: SceneTree, game: Node3D) -> void:
	var new_nodes: Array = [Nodes.VINE,Nodes.RED_BRICKS,Nodes.HAY_BALE,Nodes.SUGAR_CANE,Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,Nodes.MOSSY_COBBLE,Nodes.MOSSY_BRICKS,Nodes.COAL_BLOCK,Nodes.TERRACOTTA]
	var new_items: Array = [Nodes.CHARCOAL,Nodes.BOWL,Nodes.MUSHROOM_STEW,Nodes.GOLD_NUGGET,Nodes.IRON_NUGGET,Nodes.EGG]
	var atlas: Image = Art.make_atlas().get_image()
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
			if found.size() == 4: break
			var column: Dictionary = gen.generate_column(Vector2i(x,z),{})
			for block in column.blocks:
				for id in [Nodes.SUGAR_CANE,Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,Nodes.VINE]:
					if block.data.has(id): found[id] = true
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

static func _outward(mesh: ArrayMesh) -> bool:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0,indices.size(),3):
		var a: int = indices[i]; var b: int = indices[i+1]; var c: int = indices[i+2]
		if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).dot(normals[a]) >= 0: return false
	return true

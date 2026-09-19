extends RefCounted

# Focused regression for the magma block (Mineclonia `mcl_nether:magma`).
#
# The block is not decorative. The source gives it three behaviours: it burns
# whoever stands on it, three exemptions prevent that burn, and a fire lit on it
# becomes eternal fire. Voxey had none of it, and no magma block at all.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var player: VoxeyPlayer = game.player

	# --- the block exists ---------------------------------------------------
	t.check(VillageContent.DATA.has(Magma.ID),"the magma block is a registered node")
	t.check(VillageContent.DATA[Magma.ID].name == "Magma block","the magma block carries the source's name")
	t.check(Magma.is_magma(Magma.ID),"the block identifies itself")
	t.check(not Magma.is_magma(Nodes.STONE),"another block is not magma")
	# Source `light_source = 3`.
	t.check(int(VillageContent.DATA[Magma.ID].get("light",0)) == Magma.LIGHT,"the magma block emits the source's light level")

	# --- standing on it burns ----------------------------------------------
	var at := Vector3i(4,60,4)
	# Ensure the column holding the test block is loaded. `set_node` refuses
	# unloaded terrain, so without this the block would never appear and every
	# assertion below would fail for the wrong reason.
	var column := Vector2i(floori(at.x/16.0),floori(at.z/16.0))
	if not game.world.loaded_at(Vector3(at)):
		game.world._apply_column(game.world.generator.generate_column(column,game.world.edits))
	t.check(game.world.loaded_at(Vector3(at)),"the magma test column is loaded")
	game.world.set_node(at,Magma.ID)
	player.position = Vector3(at)+Vector3(0.5,1.0,0.5)
	player.crouching = false
	PotionEffects.clear(player)
	player.health = 20.0; player.damage_cooldown = 0
	Magma.step(game)
	t.check(player.health < 20.0,"standing on a magma block burns the player")
	t.check(player.health == 20.0-Magma.DAMAGE,"the burn deals the source's own damage")

	# --- the three source exemptions ---------------------------------------
	# Sneaking.
	player.health = 20.0; player.crouching = true
	Magma.step(game)
	t.check(player.health == 20.0,"sneaking prevents the magma burn")
	player.crouching = false
	# Fire resistance.
	player.health = 20.0; player.damage_cooldown = 0
	PotionEffects.apply(player,"fire_resistance",30.0,1)
	Magma.step(game)
	t.check(player.health == 20.0,"fire resistance prevents the magma burn")
	PotionEffects.clear(player)
	# Frost Walker boots, which the source checks on the foot armor slot.
	player.health = 20.0; player.damage_cooldown = 0
	player.armor_slots[3] = {"id":Nodes.armor_id(3,3),"count":1,"wear":0,"data":{"enchantments":{"Frost Walker":2}}}
	Magma.step(game)
	t.check(player.health == 20.0,"Frost Walker boots prevent the magma burn")
	player.armor_slots[3] = {"id":0,"count":0,"wear":0}

	# --- it only burns on magma --------------------------------------------
	player.position = Vector3(30,60,30); player.health = 20.0; player.damage_cooldown = 0
	Magma.step(game)
	t.check(player.health == 20.0,"standing elsewhere does not burn")
	# And a player in creative is exempt, as the source's damage path is.
	player.position = Vector3(at)+Vector3(0.5,1.0,0.5)
	game.gamemode = "creative"; player.health = 20.0; player.damage_cooldown = 0
	Magma.step(game)
	t.check(player.health == 20.0,"creative mode is not burned by magma")
	game.gamemode = "survival"

	# --- eternal fire ------------------------------------------------------
	# The source gives magma the same eternal-fire behaviour as netherrack.
	t.check(Magma.eternal(Magma.ID),"a magma block is eternal fire fuel")
	var above: Vector3i = at+Vector3i.UP
	game.world.set_node(above,Nodes.AIR)
	Fire.ignite(game.world,above)
	t.check(game.world.node_at(above) == Fire.ETERNAL,"a fire lit on magma is eternal")
	# A block that is not eternal fuel still gives ordinary fire.
	var stone_at := Vector3i(9,60,9)
	var stone_column := Vector2i(floori(stone_at.x/16.0),floori(stone_at.z/16.0))
	if not game.world.loaded_at(Vector3(stone_at)):
		game.world._apply_column(game.world.generator.generate_column(stone_column,game.world.edits))
	game.world.set_node(stone_at,Nodes.STONE)
	game.world.set_node(stone_at+Vector3i.UP,Nodes.AIR)
	Fire.ignite(game.world,stone_at+Vector3i.UP)
	t.check(game.world.node_at(stone_at+Vector3i.UP) == Fire.FLAME,"a fire lit on stone is not eternal")

	# --- the recipe --------------------------------------------------------
	# Source `_mcl_crafting_output = {square2 = ...}`: four magma cream.
	var recipe_index: int = game.inventory.recipe_index(Magma.ID)
	t.check(recipe_index >= 0,"four magma cream craft a magma block")
	if recipe_index >= 0:
		var recipe: Dictionary = game.inventory.recipes[recipe_index]
		t.check(int(recipe.count) == 1,"the recipe yields one magma block")
		t.check(int(recipe.ingredients.get(Nodes.MAGMA_CREAM,0)) == 4,"the recipe takes the source's four magma cream")
	# And it is a masonry-cuttable material, which the source's building group makes it.
	var cuts: Array = Magma.BLOCKS
	t.check(cuts.size() == 1 and cuts.has(Magma.ID),"the magma block is offered as a building material")

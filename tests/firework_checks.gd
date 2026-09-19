extends RefCounted

# Focused regression for firework rockets, which the reference implements purely
# as an elytra booster: three tiers, three-per-craft from paper and gunpowder,
# and a look-directed boost that only applies while the wings are deployed.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.player.camera.set_process(false)
	game.gamemode = "survival"

	# --- registry ----------------------------------------------------------
	t.check(Fireworks.ROCKETS.size() == 3 and Fireworks.is_rocket(VillageContent.ROCKET_1) and Fireworks.is_rocket(VillageContent.ROCKET_3),"the three source rockets are registered")
	t.check(not Fireworks.is_rocket(Nodes.GUNPOWDER) and not Fireworks.is_rocket(Nodes.PAPER),"ordinary items are not rockets")
	t.check(Nodes.max_stack(VillageContent.ROCKET_1) == 64,"rockets stack to 64 as craftitems do")
	for i in 3:
		t.check(Nodes.title(VillageContent.ROCKET_1+i).begins_with("Firework rocket"),"each rocket has its own title")
	# The source's own durations and forces, in registration order.
	t.check(is_equal_approx(Fireworks.duration(VillageContent.ROCKET_1),2.2) and is_equal_approx(Fireworks.duration(VillageContent.ROCKET_2),4.5) and is_equal_approx(Fireworks.duration(VillageContent.ROCKET_3),6.0),"rocket flight durations match the source 2.2, 4.5 and 6 seconds")
	t.check(is_equal_approx(Fireworks.FORCES[0],10.0) and is_equal_approx(Fireworks.FORCES[2],30.0),"rocket forces match the source 10, 20 and 30")

	# --- recipes -----------------------------------------------------------
	var inv := Inventory.new()
	for i in 3:
		var id: int = VillageContent.ROCKET_1+i
		var index: int = inv.recipe_index(id)
		t.check(index >= 0 and inv.recipes[index].shapeless,"rocket %d is crafted shapeless, as the source registers it"%(i+1))
		t.check(inv.recipes[index].count == 3,"rocket %d crafts three at a time"%[i+1])
		t.check(inv.recipes[index].ingredients.get(Nodes.PAPER,0) == 1,"rocket %d takes one paper"%[i+1])
		t.check(inv.recipes[index].ingredients.get(Nodes.GUNPOWDER,0) == i+1,"rocket %d takes %d gunpowder"%[i+1,i+1])

	# --- use rules ---------------------------------------------------------
	var player = game.player
	player.armor_slots[1] = {"id":0,"count":0,"wear":0}
	game.inventory.restore([]); game.inventory.add_item(VillageContent.ROCKET_3,4); game.inventory.selected = 0
	# Without wings the rocket is refused and the item is kept.
	t.check(Fireworks.use(game,VillageContent.ROCKET_3),"using a rocket without elytra is handled")
	t.check(game.inventory.count_item(VillageContent.ROCKET_3) == 4 and player.rocketing <= 0.0,"a rocket is not consumed without usable elytra")
	# With wings but no deployment the source says to jump while falling.
	player.armor_slots[1] = {"id":Nodes.ELYTRA,"count":1,"wear":0}
	player.gliding = false; player.grounded = false; player.rocketing = 0.0
	Fireworks.use(game,VillageContent.ROCKET_3)
	t.check(game.inventory.count_item(VillageContent.ROCKET_3) == 4 and player.rocketing <= 0.0,"a rocket is not consumed while the wings are stowed")
	# Deployed wings accept it and start the boost.
	player.gliding = true; player.grounded = false; player.rocketing = 0.0
	Fireworks.use(game,VillageContent.ROCKET_3)
	t.check(is_equal_approx(player.rocketing,6.0),"a tier-three rocket grants the source six seconds of boost")
	t.check(game.inventory.count_item(VillageContent.ROCKET_3) == 3,"using a rocket consumes exactly one")
	# A worn-out elytra cannot be boosted.
	player.armor_slots[1] = {"id":Nodes.ELYTRA,"count":1,"wear":Nodes.durability(Nodes.ELYTRA)-1}
	player.rocketing = 0.0
	Fireworks.use(game,VillageContent.ROCKET_3)
	t.check(player.rocketing <= 0.0 and game.inventory.count_item(VillageContent.ROCKET_3) == 3,"a broken elytra cannot be boosted")

	# --- the boost itself --------------------------------------------------
	# Source `rocket_boost`: each axis becomes
	#   look*2 + (look*30 - v)*0.5 + v,  so a rocket drives the wings hard along
	# the look direction. Fly level and boost forward.
	player.armor_slots[1] = {"id":Nodes.ELYTRA,"count":1,"wear":0}
	player.camera.rotation = Vector3.ZERO
	player.camera.global_position = Vector3(0,100,0)
	player.rotation.y = 0.0
	player.gliding = true
	player.rocketing = 6.0
	player.velocity = Vector3(0,0,0)
	var forward: Vector3 = -player.camera.global_basis.z
	Fireworks.boost(player,0.05)
	var expected: Vector3 = Vector3.ZERO
	for axis in 3:
		expected[axis] = forward[axis]*Fireworks.BASE_ROCKET_BOOST+(forward[axis]*Fireworks.ROCKET_BOOST_FORCE-0.0)*0.5
	t.check(player.velocity.distance_to(expected) < 0.01,"the boost matches the source expression exactly")
	t.check(player.velocity.length() > 10.0,"a rocket produces a strong forward boost")
	t.check(is_equal_approx(player.rocketing,5.95),"the boost counts down by the step time")
	# The boost dies out once its time is spent.
	var spent: Vector3 = player.velocity
	player.rocketing = 0.0
	Fireworks.boost(player,0.05)
	t.check(player.velocity.is_equal_approx(spent),"an expired rocket no longer changes velocity")
	# The glide update hands control to the rocket while it burns.
	var before: Vector3 = player.velocity
	player.rocketing = 3.0
	var flying: bool = player.update_glide(0.05,true)
	t.check(flying and player.velocity.length() > before.length(),"the glide update applies the rocket boost while it burns")
	player.rocketing = 0.0
	player.gliding = false
	player.velocity = Vector3.ZERO

	# --- art ---------------------------------------------------------------
	var art := Image.create(16,16,false,Image.FORMAT_RGBA8)
	Fireworks.draw(art,VillageContent.ROCKET_1,0)
	var pixels: int = 0
	for y in 16:
		for x in 16:
			if art.get_pixel(x,y).a > 0.0: pixels += 1
	t.check(pixels > 0,"a firework rocket draws a non-empty icon")
	t.check(Nodes.color(VillageContent.ROCKET_1) != Nodes.color(Nodes.GUNPOWDER),"the rocket has its own item colour")

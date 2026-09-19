extends RefCounted

static func wool(game: Node3D) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == Nodes.WOOL: count += drop.amount
	return count

static func click(game: Node3D, button: MouseButton) -> void:
	game.player.use_cooldown = 0
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = button; event.pressed = pressed
		event.position = game.get_viewport().get_visible_rect().size*0.5
		event.global_position = event.position
		Input.parse_input_event(event); Input.flush_buffered_events()
		# This refreshes the world raycast and runs the same aim/use or attack
		# dispatch used by the live game, rather than directly calling shear().
		game.player._process(1.0/60.0)

static func coat_visible(sheep: Creature, wanted: bool) -> bool:
	if sheep.wool_parts.is_empty(): return false
	for part in sheep.wool_parts:
		if part.visible != wanted: return false
	return true

static func regrow(sheep: Creature) -> void:
	sheep.game.world.set_node(Farming.grass_below(sheep),Nodes.GRASS)
	sheep.grazing = 0.41; sheep.graze_consumed = false; sheep.direction = Vector3.ZERO; sheep.think = 100
	sheep._physics_process(0.05)

static func run(suite: SceneTree, game: Node3D) -> void:
	var player: VoxeyPlayer = game.player
	var old_position: Vector3 = player.position
	var old_rotation: Vector3 = player.rotation
	var old_camera: Vector3 = player.camera.rotation
	var old_state: String = game.state
	var old_mode: String = game.gamemode
	var old_inventory: Array = game.inventory.slots.duplicate(true)
	var old_selected: int = game.inventory.selected
	game.state = "playing"; game.gamemode = "survival"
	for x in range(6,12):
		for z in range(1,12):
			for y in range(399,405): game.world.set_node(Vector3i(x,y,z),Nodes.GRASS if y == 399 else Nodes.AIR)
	player.position = Vector3(8.5,400.01,8.5); player.rotation = Vector3.ZERO
	player.eating.clear(); player.camera.position.y = 1.62
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":Nodes.SHEARS,"count":1,"wear":0}
	var sheep: Creature = game.spawn_creature("sheep",Vector3(8.5,400.01,5.8))
	sheep.set_physics_process(false); Farming.set_color(sheep,"white")
	player.camera.look_at(sheep.center())
	player._process(1.0/60.0)
	suite.check(game.target_mob() == sheep,"aiming the crosshair at a nearby sheep selects it through the live target path")
	var health: float = sheep.health
	var before: int = wool(game)
	click(game,MOUSE_BUTTON_RIGHT)
	var first_coat: int = wool(game)-before
	suite.check(sheep.sheared and sheep.health == health and coat_visible(sheep,false),"right-clicking with shears removes the coat without hurting the aimed sheep")
	suite.check(first_coat >= 1 and first_coat <= 3,"real right-click shearing drops one to three wool")
	suite.check(game.inventory.held().id == Nodes.SHEARS and game.inventory.held().wear == 1,"survival right-click shearing spends one durability use")
	var after_first: int = wool(game)
	click(game,MOUSE_BUTTON_RIGHT)
	suite.check(sheep.health == health and wool(game) == after_first and game.inventory.held().wear == 1,"right-clicking an already-sheared sheep adds no wool, damage or wear")
	click(game,MOUSE_BUTTON_LEFT)
	suite.check(sheep.health == health and wool(game) == after_first and game.inventory.held().wear == 1,"left-click shears cannot injure or repeatedly harvest an already-sheared sheep")
	regrow(sheep)
	suite.check(not sheep.sheared and coat_visible(sheep,true),"the creature simulation regrows the visible coat when grazing consumes the grass beneath it")
	# A wall closer to the camera must block both input routes.
	for y in [400,401,402]: game.world.set_node(Vector3i(8,y,7),Nodes.STONE)
	player._process(1.0/60.0)
	suite.check(game.target_mob() == null and not player.target.is_empty(),"a solid wall blocks the sheep's real target ray")
	click(game,MOUSE_BUTTON_RIGHT); click(game,MOUSE_BUTTON_LEFT)
	suite.check(not sheep.sheared and sheep.health == health and wool(game) == after_first and game.inventory.held().wear == 1,"shears cannot reach a sheep through a wall")
	for y in [400,401,402]: game.world.set_node(Vector3i(8,y,7),Nodes.AIR)
	game.gamemode = "creative"
	click(game,MOUSE_BUTTON_RIGHT)
	suite.check(sheep.sheared and sheep.health == health and game.inventory.held().wear == 1 and wool(game) > after_first,"creative right-click shearing drops wool without tool wear")
	game.gamemode = "survival"; regrow(sheep)
	game.inventory.slots[0] = {"id":Nodes.SHEARS,"count":1,"wear":Nodes.durability(Nodes.SHEARS)-1}
	before = wool(game); click(game,MOUSE_BUTTON_RIGHT)
	suite.check(sheep.sheared and wool(game) > before and game.inventory.count_item(Nodes.SHEARS) == 0,"the last shears use still harvests wool and then breaks the tool")
	regrow(sheep); game.inventory.slots[0] = {"id":Nodes.SHEARS,"count":1,"wear":0}
	before = wool(game); click(game,MOUSE_BUTTON_LEFT)
	suite.check(sheep.sheared and sheep.health == health and wool(game) > before and game.inventory.held().wear == 1,"the existing left-click shearing shortcut still works without combat damage")
	regrow(sheep); sheep.position.z = 2.5; player.camera.look_at(sheep.center())
	before = wool(game); click(game,MOUSE_BUTTON_RIGHT)
	suite.check(game.target_mob() == null and not sheep.sheared and wool(game) == before and game.inventory.held().wear == 1,"a sheep outside interaction reach cannot be sheared")
	sheep.position.z = 5.8; player.camera.look_at(sheep.center())
	click(game,MOUSE_BUTTON_RIGHT); before = wool(game)
	sheep.hit(100,player.position)
	suite.check(sheep.sheared and sheep.is_queued_for_deletion() and wool(game) == before,"a sheep killed after shearing cannot drop the same wool coat again")
	sheep.free()
	game.inventory.slots = old_inventory; game.inventory.selected = old_selected
	player.position = old_position; player.rotation = old_rotation; player.camera.rotation = old_camera
	player.target = {}; player.mining = 0; player.use_cooldown = 0
	game.state = old_state; game.gamemode = old_mode

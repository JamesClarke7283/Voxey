extends RefCounted

static func pool(game: Node3D, shore_height: int = 0, flowing: bool = false) -> float:
	# An isolated pool above generated terrain. Water surface is 146, with a
	# one-block bank at 147 or a tall un-climbable wall when requested.
	for x in range(4,16):
		for z in range(4,13):
			for y in range(139,153):
				var id: int = Nodes.AIR
				if y == 139: id = Nodes.STONE
				elif y < 146: id = Fluids.flow_id(Nodes.WATER,0,true) if flowing else Nodes.WATER
				if shore_height > 0 and x >= 10 and y < 146+shore_height: id = Nodes.STONE
				game.world.set_node(Vector3i(x,y,z),id)
	game.player.position = Vector3(8.5,140.05,8.5)
	game.player.velocity = Vector3.ZERO; game.player.grounded = false
	game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO
	game.player.camera.position.y = 1.62
	game.player.health = 20; game.player.breath = 10; game.player.survival_timer = 0
	Hunger.reset(game.player); PotionEffects.clear(game.player)
	game.controls.stick = Vector2.ZERO; game.controls.jump_held = false; game.controls.sneak_held = false
	return 146.0

static func step(game: Node3D, seconds: float, delta: float) -> Dictionary:
	var peak: float = game.player.position.y
	var collided: bool = false
	for frame in ceili(seconds/delta):
		game.player._physics_process(delta)
		peak = maxf(peak,game.player.position.y)
		collided = collided or game.world.intersects(game.player.position)
	return {"peak":peak,"collided":collided}

static func keyboard(code: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code; key.keycode = code; key.pressed = pressed
	Input.parse_input_event(key)
	Input.flush_buffered_events()

static func run(suite: SceneTree, game: Node3D) -> void:
	var old_touch: bool = game.touch
	var old_state: String = game.state
	var old_mode: String = game.gamemode
	var old_position: Vector3 = game.player.position
	var old_rotation: Vector3 = game.player.rotation
	var old_camera: Vector3 = game.player.camera.rotation
	var old_health: float = game.player.health
	var old_hunger: float = game.player.hunger
	var old_breath: float = game.player.breath
	var old_nutrition: Dictionary = Hunger.snapshot(game.player)
	var old_effects: Dictionary = game.survival.effect_snapshot()
	var temporary_controls: bool = not is_instance_valid(game.controls)
	if temporary_controls:
		game.controls = TouchControls.new(); game.controls.game = game; game.add_child(game.controls)
	game.state = "playing"; game.gamemode = "survival"; game.touch = true
	game.player.flying = false; game.player.gliding = false
	for delta in [1.0/60.0,1.0/20.0]:
		var surface: float = pool(game)
		game.controls.jump_held = true
		var result: Dictionary = step(game,3.0,delta)
		suite.check(result.peak >= surface and not result.collided,"holding touch jump rises from deep source water above the waterline at %d FPS"%roundi(1/delta))
		surface = pool(game,1)
		game.player.position.y = surface-1.5
		game.controls.jump_held = true; game.controls.stick = Vector2(1,0)
		result = step(game,2.0,delta)
		suite.check(game.player.position.x > 10.3 and game.player.position.y >= surface+1 and not result.collided,"holding jump and moving sideways exits onto a full-block shore at %d FPS"%roundi(1/delta))
	var surface: float = pool(game,0,true)
	game.controls.jump_held = true
	var result: Dictionary = step(game,3.0,1.0/60.0)
	suite.check(result.peak >= surface and not result.collided,"holding jump rises through falling water and clears its surface")
	surface = pool(game)
	for x in range(4,10):
		for z in range(4,13): game.world.set_node(Vector3i(x,145,z),Fluids.flow_id(Nodes.WATER,1))
	game.controls.jump_held = true
	result = step(game,3.0,1.0/60.0)
	suite.check(result.peak >= surface-0.125 and not result.collided,"swimming follows the actual flowing-water surface and can clear it")
	surface = pool(game)
	for y in range(140,146): game.world.set_node(Vector3i(8,y,8),VillageContent.KELP_PLANT)
	game.controls.jump_held = true
	result = step(game,3.0,1.0/60.0)
	suite.check(result.peak >= surface and not result.collided,"submerged kelp does not turn the swimmer's water column into air")
	surface = pool(game,4)
	game.player.position.y = surface-1.0
	game.controls.jump_held = true; game.controls.stick = Vector2(1,0)
	result = step(game,3.0,1.0/60.0)
	suite.check(game.player.position.x < 9.71 and result.peak < surface+2 and not result.collided,"swimming cannot climb a tall wall or pass through its collision")
	surface = pool(game)
	for x in range(4,10):
		for z in range(4,13): game.world.set_node(Vector3i(x,147,z),Nodes.STONE)
	game.controls.jump_held = true
	result = step(game,3.0,1.0/60.0)
	suite.check(result.peak <= 145.21 and not result.collided,"rising in water respects a solid ceiling")
	surface = pool(game)
	game.touch = false; keyboard(KEY_SPACE,true)
	result = step(game,3.0,1.0/60.0)
	keyboard(KEY_SPACE,false)
	suite.check(result.peak >= surface and not result.collided,"holding physical Space continuously swims to and above the surface")
	surface = pool(game,1); game.touch = false
	game.player.position.y = surface-1.5; keyboard(KEY_SPACE,true); keyboard(KEY_D,true)
	result = step(game,2.0,1.0/60.0)
	keyboard(KEY_D,false); keyboard(KEY_SPACE,false)
	suite.check(game.player.position.x > 10.3 and game.player.position.y >= surface+1 and not result.collided,"physical Space and movement climb a full-block shore without clipping")
	surface = pool(game); game.touch = false
	game.player.position.y = surface-3.0; keyboard(KEY_SHIFT,true)
	result = step(game,0.5,1.0/60.0)
	keyboard(KEY_SHIFT,false)
	suite.check(game.player.position.y < surface-4.0 and not result.collided,"physical Shift swims downward against buoyancy in deep water")
	surface = pool(game); game.touch = false
	game.player.position.y = surface-0.2; keyboard(KEY_SHIFT,true)
	result = step(game,0.5,1.0/60.0)
	keyboard(KEY_SHIFT,false)
	suite.check(game.player.position.y < surface-1.2 and not result.collided,"Shift begins diving while only the feet are in water")
	surface = pool(game); game.touch = false
	game.player.position.y = surface-2.0; keyboard(KEY_SPACE,true); keyboard(KEY_SHIFT,true)
	step(game,0.3,1.0/60.0)
	keyboard(KEY_SHIFT,false); keyboard(KEY_SPACE,false)
	suite.check(game.player.position.y < surface-2.5,"descend takes priority when Space and Shift are held together")
	surface = pool(game); game.touch = false
	game.player.position.y = surface-1.0; keyboard(KEY_W,true); keyboard(KEY_SHIFT,true)
	step(game,1.0,1.0/60.0)
	keyboard(KEY_SHIFT,false); keyboard(KEY_W,false)
	suite.check(8.5-game.player.position.z < 3 and player_sprint_empty(game),"Shift diving keeps ordinary swim speed and adds no sprint exhaustion")
	surface = pool(game,1); game.touch = false
	game.player.position = Vector3(12.5,surface+1.01,11.5)
	keyboard(KEY_W,true); keyboard(KEY_SHIFT,true)
	step(game,0.8,1.0/60.0)
	keyboard(KEY_SHIFT,false); keyboard(KEY_W,false)
	suite.check(11.5-game.player.position.z > 4.5 and -game.player.velocity.z > 6.9,"Shift still sprints on dry land")
	surface = pool(game); game.touch = true
	game.player.position.y = surface-2.0; game.controls.sneak_held = true
	result = step(game,0.5,1.0/60.0)
	game.controls.sneak_held = false
	suite.check(game.player.position.y < surface-3.0 and not result.collided,"touch sneak descends through water just like keyboard Shift")
	game.touch = true; game.controls.show_game_controls()
	var jump_button: Button
	for button in game.controls.button_box.get_children():
		if button is Button and button.text == "▲" and not button.is_queued_for_deletion(): jump_button = button
	jump_button.button_down.emit()
	suite.check(game.controls.jump_held,"touch jump starts on finger-down and remains held for swimming")
	jump_button.button_up.emit()
	suite.check(not game.controls.jump_held,"releasing touch jump stops ascent input")
	game.gamemode = "creative"; game.player.flying = false
	game.controls._last_jump_tap = Time.get_ticks_msec()-100
	jump_button.button_down.emit(); jump_button.button_up.emit()
	suite.check(game.player.flying,"double-tapping touch jump still toggles creative flight")
	game.player.flying = false
	game.controls.jump_held = false; game.controls.stick = Vector2.ZERO
	game.player.position = old_position; game.player.rotation = old_rotation; game.player.camera.rotation = old_camera
	game.player.velocity = Vector3.ZERO; game.player.health = old_health; game.player.hunger = old_hunger; game.player.breath = old_breath
	Hunger.restore(game.player,old_nutrition); game.survival.restore_effects(old_effects)
	game.touch = old_touch; game.state = old_state; game.gamemode = old_mode
	if temporary_controls: game.controls.free(); game.controls = null

static func player_sprint_empty(game: Node3D) -> bool:
	return is_zero_approx(game.player.sprint_distance) and game.player.exhaustion < Hunger.SPRINT

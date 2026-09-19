extends RefCounted
const Helper = preload("res://tests/barrier_checks.gd")

static func find_named(node: Node, title: String) -> Node:
	if node.name == title: return node
	for child in node.get_children():
		if child.is_queued_for_deletion(): continue
		var result: Node = find_named(child,title)
		if result != null: return result
	return null

static func freeze(game: Node3D) -> void:
	game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)

static func target(p: Vector3i, id: int, normal: Vector3i = Vector3i.UP) -> Dictionary:
	return {"pos":p,"id":id,"normal":normal,"point":Vector3(p)+Vector3.ONE*0.5,"distance":3.0}

static func run(t: SceneTree, game: Node3D) -> void:
	t.check(Signs.clean_text("abc\rdef") == "abc" and Signs.clean_text("A".repeat(270)).length() == 255,"sign source normalization terminates at CR and limits ASCII by one-based UTF-8 byte offset")
	t.check(Signs.clean_text("é".repeat(140)).length() == 128 and Signs.clean_text("A".repeat(254)+"😀Z") == "A".repeat(254)+"😀","sign byte bound retains a final complete multibyte character without corrupting UTF-8")
	t.check(Signs.lines("one\ntwo\nthree\nfour\nfive") == PackedStringArray(["one","two","three","four"]),"sign displays at most four source lines")
	t.check(Signs.lines("abcdefghijklmnoP") == PackedStringArray(["abcdefghijklmno‐","P"]),"source forced long-word wrap retains fifteen characters plus its hyphen glyph")
	t.check(Signs.lines("hello wonderful world") == PackedStringArray(["hello","wonderful","world"]),"source sign wrapping breaks at preceding spaces rather than splitting a word")
	t.check(Signs.lines("abc-defghijklmnop") == PackedStringArray(["abc-","defghijklmnop"]),"source wrapping preserves an explicit breaking hyphen")
	t.check(Signs.lines("abc\u00a0defghijklmnop")[0] == "abc\u00a0defghijklmn‐","nonbreaking Unicode spaces do not become source wrap opportunities")
	t.check(Signs.lines("one\u2028two\u0085three\u000bfour\u000cfive") == PackedStringArray(["one","two","three","four"]),"all source Unicode newline classes count toward four lines")
	t.check(Signs.display_text("Welcome ΩЖ\n😀") == "Welcome ΩЖ\n�" and Signs.display_text("-".repeat(255)).length() == 19,"native sign text retains source supported characters and bounded central clipping")
	t.check(GameRules.restore({}).signsEditable == false and GameRules.restore({"signsEditable":true}).signsEditable and not GameRules.restore({"signsEditable":"true"}).signsEditable,"editable signs rule defaults false and only restores booleans")
	var original_rules: Dictionary = game.game_rules.duplicate(true)
	t.check("signsEditable" in GameRules.command(game,PackedStringArray(["gamerule"])) and "true" in GameRules.command(game,PackedStringArray(["gamerule","signseditable","true"])) and game.game_rules.signsEditable,"native gamerule listing and case-insensitive command expose sign rewriting")
	game.game_rules.signsEditable = false
	var inv := Inventory.new()
	var recipe: Dictionary = inv.recipes[inv.recipe_index(Signs.OAK)]
	t.check(recipe.count == 3 and recipe.ingredients == {Nodes.PLANKS:6,Nodes.STICK:1} and recipe.station == "table","six oak planks and one stick craft three source signs at a table")
	t.check(Nodes.max_stack(Signs.OAK) == 16 and Nodes.fuel_time(Signs.OAK) == 10,"oak signs stack to sixteen and provide ten seconds of furnace fuel")
	for id in range(Signs.OAK,Signs.END):
		var out: Array = BlockMesher._empty(); Signs.mesh(out,Vector3.ZERO,id)
		t.check(Nodes.exists(id) and not Nodes.solid(id) and Nodes.transparent(id) and Nodes.drop(id) == Signs.OAK and Nodes.placeable(id) == (id == Signs.OAK) and out[0].size() > 0,"sign registry keeps oriented state non-solid with canonical drops and generated art: "+str(id))
	for direction in 4:
		var id: int = Signs.OAK+direction; var box: AABB = Signs.boxes(id)[0]
		t.check(Signs.placement_id(-Signs.SUPPORT[direction],0) == id and box.get_center().distance_to(Vector3.ONE*0.5+Vector3(Signs.SUPPORT[direction])*(0.5-5.0/112)) < 0.0001,"wall sign selection and placement face agree: "+str(direction))
	for direction in 16:
		t.check(Signs.placement_id(Vector3i.UP,direction*TAU/16.0) == Signs.STANDING+direction,"source standing angle "+str(direction)+" snaps to 22.5-degree steps")
	t.check(Signs.placement_id(Vector3i.DOWN,0) == 0 and Signs.placement_id(Vector3i.UP,-0.01) == Signs.STANDING,"ordinary signs reject ceilings and normalize negative yaw at zero")
	var p := Vector3i(8,900,8)
	var world: VoxelWorld = game.world; var original_pos: Vector3 = game.player.position
	var original_rotation: Vector3 = game.player.rotation; var original_camera: Vector3 = game.player.camera.rotation
	var original_mode: String = game.gamemode; var original_touch: bool = game.touch
	var original_inventory: Array = game.inventory.slots.duplicate(true); var original_selected: int = game.inventory.selected
	var original_target: Dictionary = game.player.target
	var temporary_controls: bool = not is_instance_valid(game.controls)
	if temporary_controls:
		game.controls = TouchControls.new(); game.controls.game = game; game.add_child(game.controls)
	var original_sneak: bool = game.controls.sneak_held
	game.pause(); freeze(game); game.gamemode = "survival"; game.touch = false
	for creature in game.creatures.get_children(): creature.queue_free()
	await t.process_frame
	for x in range(-2,4):
		for z in range(-2,4):
			for y in range(-1,4): world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	game.player.position = Vector3(p)+Vector3(0.5,0,-2); game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO
	Helper.equip(game,Signs.OAK,3)
	t.check(Signs.try_place(game,target(p+Vector3i.DOWN,Nodes.STONE)) and world.node_at(p) == Signs.STANDING and game.inventory.held().count == 2 and game.state == "sign" and game.hud.screen == "sign","real survival placement consumes one sign and opens the initial native editor")
	t.check(world.collision_boxes(p).is_empty() and not world.intersects(Vector3(p)+Vector3(0.5,0,0.5)),"standing sign is selectable but never blocks player movement")
	var editor: TextEdit = find_named(game.hud.layer,"SignEditor")
	t.check(editor != null,"initial sign editor contains a native multiline text control")
	if editor != null: editor.text = "Voxey signs\nΩ Ж café\nThird\nFourth\nHidden"; editor.text_changed.emit()
	var draft: String = game.get_meta("sign_editor",{}).get("draft","")
	game._resize_ui()
	editor = find_named(game.hud.layer,"SignEditor")
	t.check(editor != null and editor.text == draft and find_named(game.hud.layer,"SignPreview").text == Signs.display_text(draft),"sign menu reflow preserves the draft and exact bounded preview")
	t.check(Signs.station(world,p).text == "" and Signs.submit(game) and Signs.station(world,p).text == draft and Signs.station(world,p).written and game.state == "playing","sign text commits only on Done and returns to gameplay")
	freeze(game); Helper.equip(game,Nodes.APPLE,2)
	t.check(Signs.use(game,target(p,world.node_at(p))) and game.state != "sign" and game.inventory.held().count == 2,"default source sign right-click stays locked and suppresses held-food use")
	t.check(not Signs.open_editor(game,p,false),"default world rule blocks later editing even for empty-handed native UI calls")
	game.touch = true; game.controls.sneak_held = true
	t.check(not Signs.use(game,target(p,world.node_at(p))),"touch sneaking bypasses the sign callback for placement on an existing sign")
	game.controls.sneak_held = false
	game.player.target = target(p,world.node_at(p)); game.player.use()
	t.check(game.inventory.held().count == 2 and game.state != "sign","real player dispatch consumes neither held food nor a locked sign interaction")
	game.touch = false
	game.game_rules.signsEditable = true
	t.check(Signs.use(game,target(p,world.node_at(p))) and game.state == "sign","enabled saved game rule opens an existing sign")
	editor = find_named(game.hud.layer,"SignEditor")
	if editor != null: editor.text = "Discard this"; editor.text_changed.emit()
	Signs.cancel(game); freeze(game)
	t.check(Signs.station(world,p).text == draft,"canceling a later edit retains the last committed text")
	Signs.open_editor(game,p)
	var escape := InputEventKey.new(); escape.physical_keycode = KEY_ESCAPE; escape.pressed = true
	game._input(escape); freeze(game)
	t.check(game.state == "playing" and not game.has_meta("sign_editor") and Signs.station(world,p).text == draft,"Escape closes the native sign editor without leaving a stale editing session")
	for dye in range(VillageContent.DYE_WHITE,VillageContent.DYE_BROWN+1):
		var color: String = VillageContent.DATA[dye].dye
		Helper.equip(game,dye,2)
		Signs.use(game,target(p,world.node_at(p)))
		t.check(Signs.station(world,p).color == Signs.DYE_COLORS[color] and game.inventory.held().count == 1 and Signs.station(world,p).text == draft,"source sign dye updates only color and consumes one in survival: "+color)
	Helper.equip(game,VillageContent.DYE_BROWN,2); Signs.use(game,target(p,world.node_at(p)))
	t.check(game.inventory.held().count == 1,"reapplying the same sign dye still consumes it as in source")
	game.gamemode = "creative"; Helper.equip(game,VillageContent.DYE_RED,2); Signs.use(game,target(p,world.node_at(p)))
	t.check(game.inventory.held().count == 2 and Signs.station(world,p).color == "#912222","creative dye updates signs without consuming inventory")
	game.gamemode = "survival"; game.game_rules.signsEditable = false
	var state: Dictionary = Signs.station(world,p); state.color = Signs.DEFAULT_COLOR
	t.check(Signs.apply_glow(world,p) and state.glow and state.color == "#7e7e7e","source glow helper brightens only default black text while setting glow metadata")
	Signs.apply_dye(world,p,"black"); Signs.apply_glow(world,p)
	t.check(state.color == "#080a10" and state.glow,"dye preserves glow and dyed black is not recolored by another glow application")
	for held in [Nodes.BONE_MEAL,VillageContent.INK_SAC]:
		Helper.equip(game,held,2); Signs.use(game,target(p,world.node_at(p)))
		t.check(game.inventory.held().count == 2 and state.color == "#080a10" and state.glow,"actual source has no bone-meal or raw-ink wash callback: "+Nodes.title(held))
	var model: Node3D = Signs.display_model(game,p,state); var label: Label3D = model.get_child(0)
	t.check(model.position == Vector3(p) and label.text == Signs.display_text(draft) and not label.shaded and not label.double_sided,"persistent sign display positions native text on its front and glow makes text self-lit")
	model.free()
	Helper.equip(game,Signs.OAK,4)
	Signs.try_place(game,target(p+Vector3i.DOWN,Nodes.STONE,Vector3i.DOWN))
	t.check(game.inventory.held().count == 4 and world.node_at(p+Vector3i.DOWN*2) == Nodes.AIR,"ceiling placement rejects without inventory loss")
	world.set_node(p+Vector3i.RIGHT,Nodes.TORCH)
	Signs.try_place(game,target(p+Vector3i.RIGHT,Nodes.TORCH))
	t.check(game.inventory.held().count == 4 and world.node_at(p+Vector3i(1,1,0)) == Nodes.AIR,"nonwalkable non-sign support rejects initial placement")
	world.set_node(p+Vector3i.RIGHT,Nodes.STONE)
	Signs.try_place(game,target(p+Vector3i.RIGHT,Nodes.STONE,Vector3i.BACK))
	var wall_pos: Vector3i = p+Vector3i(1,0,1)
	t.check(world.node_at(wall_pos) == Signs.OAK and game.inventory.held().count == 3,"real side placement creates the matching wall state")
	var hit: Dictionary = world.raycast(Vector3(wall_pos)+Vector3(0.5,0.5,2),Vector3.FORWARD,3)
	t.check(not hit.is_empty() and hit.pos == wall_pos and hit.normal == Vector3i.BACK and is_equal_approx(hit.point.z,wall_pos.z+5.0/56),"real raycast strikes the thin wall selection face instead of the whole cell")
	Signs.cancel(game); freeze(game)
	world.set_node(p+Vector3i.RIGHT,Nodes.WATER)
	t.check(world.node_at(wall_pos) == Signs.OAK,"source later support checks retain a sign when backing changes to non-airlike water")
	var before: int = Helper.drops(game,Signs.OAK)
	world.set_node(p+Vector3i.RIGHT,Nodes.AIR)
	t.check(world.node_at(wall_pos) == Nodes.AIR and not world.stations.has(VoxelWorld.station_key(wall_pos)) and Helper.drops(game,Signs.OAK) == before+1,"removing wall support drops one plain sign and clears persistent text")
	game.game_rules.signsEditable = true; Signs.open_editor(game,p)
	var stale: Dictionary = game.get_meta("sign_editor").duplicate(true)
	before = Helper.drops(game,Signs.OAK); game.break_node(p,world.node_at(p),0)
	t.check(Helper.drops(game,Signs.OAK) == before+1 and not game.has_meta("sign_editor") and game.state != "sign","breaking a written sign drops its canonical item and closes the editor")
	world.set_node(p,Signs.STANDING)
	game.set_meta("sign_editor",stale)
	t.check(not Signs.submit(game) and Signs.station(world,p).text == "","stale editor transaction cannot write onto a replaced sign")
	game.remove_meta("sign_editor")
	Helper.equip(game,Signs.OAK,3); world.set_node(p+Vector3i(2,-1,0),Nodes.STONE)
	game.player.target = target(p+Vector3i(2,-1,0),Nodes.STONE); game.player.use()
	t.check(world.node_at(p+Vector3i(2,0,0)) == Signs.STANDING and game.inventory.held().count == 2 and game.state == "sign","normal player use reaches sign placement and initial editing after target interaction routing")
	Signs.cancel(game); freeze(game); world.set_node(p+Vector3i(2,0,0),Nodes.AIR)
	state = Signs.station(world,p); state.text = "Saved ΩЖ\nSecond line"; state.color = "#167b8c"; state.glow = true; state.written = true
	game.game_rules.signsEditable = true; game.player.position = Vector3(p)+Vector3(0.5,0,-2)
	t.check(game.save_game("user://signs.json"),"sign text, color, glow, identity and edit rule write through a real save")
	var saved: Dictionary = game.read_save("user://signs.json")
	game.set_process(true); game.load_world_data(saved)
	while game.state == "loading": await t.process_frame
	game.pause(); freeze(game); world = game.world
	state = Signs.station(world,p)
	t.check(world.node_at(p) == Signs.STANDING and state.text == "Saved ΩЖ\nSecond line" and state.color == "#167b8c" and state.glow and state.written and state.serial is int and game.game_rules.signsEditable,"real restart restores sign state, Unicode and saved rewriting rule with integer identity")
	game.survival.refresh_displays()
	t.check(game.survival.displays.has(VoxelWorld.station_key(p)) and game.survival.displays[VoxelWorld.station_key(p)].get_child(0).text == "Saved ΩЖ\nSecond line","reloaded sign automatically reconstructs its visible written text")
	before = Helper.drops(game,Signs.OAK)
	world.set_node(p+Vector3i.DOWN,Nodes.AIR)
	t.check(world.node_at(p) == Nodes.AIR and Helper.drops(game,Signs.OAK) == before+1,"standing sign drops when its floor support is removed after restart")
	var piston: Vector3i = p+Vector3i(0,0,2)
	game.player.position = Vector3(p)+Vector3(-2,0,-2)
	world.set_node(piston,Nodes.STICKY_PISTON); world.circuits.configure(piston,Vector3i.RIGHT)
	world.set_node(piston+Vector3i(1,-1,0),Nodes.STONE); world.set_node(piston+Vector3i(2,-1,0),Nodes.STONE)
	world.set_node(piston+Vector3i.RIGHT,Signs.STANDING)
	state = Signs.station(world,piston+Vector3i.RIGHT); state.text = "Piston Ω"; state.color = "#258ec9"; state.glow = true
	var sign_serial: int = state.serial
	var pushed: bool = world.circuits.piston(piston,true)
	state = Signs.station(world,piston+Vector3i.RIGHT*2)
	t.check(pushed and world.node_at(piston+Vector3i.RIGHT*2) == Signs.STANDING and state.text == "Piston Ω" and state.color == "#258ec9" and state.glow and state.serial == sign_serial,"piston push carries the written sign station and identity instead of silently erasing text")
	# `mcl_redstone_sticky_pistons_one_tick_detach` (default true) means an
	# immediate reversal detaches; this case wants a real later pull.
	world.circuits.ticks += 5
	var pulled: bool = world.circuits.piston(piston,false)
	state = Signs.station(world,piston+Vector3i.RIGHT)
	t.check(pulled and world.node_at(piston+Vector3i.RIGHT) == Signs.STANDING and state.text == "Piston Ω" and state.serial == sign_serial,"sticky piston pull returns the same written sign identity")
	world.set_node(piston+Vector3i(2,-1,0),Nodes.AIR); before = Helper.drops(game,Signs.OAK)
	pushed = world.circuits.piston(piston,true)
	t.check(pushed and world.node_at(piston+Vector3i.RIGHT*2) == Nodes.AIR and Helper.drops(game,Signs.OAK) == before+1 and not world.stations.has(VoxelWorld.station_key(piston+Vector3i.RIGHT*2)),"piston-moved sign checks final support after the whole move and drops once when unsupported")
	world.circuits.piston(piston,false)
	for x in range(-2,4):
		for z in range(-2,4):
			for y in range(-2,4): world.set_node(p+Vector3i(x,y,z),Nodes.AIR)
	game.game_rules = original_rules; game.gamemode = original_mode; game.touch = original_touch
	game.inventory.slots = original_inventory; game.inventory.selected = original_selected
	game.player.target = original_target
	if is_instance_valid(game.controls): game.controls.sneak_held = original_sneak
	if temporary_controls and is_instance_valid(game.controls): game.controls.queue_free(); game.controls = null
	game.player.position = original_pos; game.player.rotation = original_rotation; game.player.camera.rotation = original_camera
	game.pause(); freeze(game)

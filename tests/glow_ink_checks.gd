extends RefCounted

# Regression checks for `GlowInk` (Mineclonia `mcl_signs/init.lua`:487-497 and
# `mcl_itemframes/register.lua`:74-78) and `Frames` (`mcl_itemframes/init.lua`:96-106,
# :130-135 and `mcl_comparators/init.lua`:113-119, :156-159).

static func held(game: Node3D, id: int, count: int = 1) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0}

static func target(p: Vector3i, id: int) -> Dictionary:
	return {"pos":p,"id":id,"normal":Vector3i.UP,"point":Vector3(p)+Vector3.ONE*0.5,"distance":3.0}

static func run(t: SceneTree, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	# Y1500 is high above every other fixture's column and inside loaded terrain.
	# X8/Z8 stays in column (0,0), which the lifecycle world always has loaded.
	var sign_pos := Vector3i(8,1500,8)
	var frame_pos: Vector3i = sign_pos+Vector3i(3,0,0)
	var original_position: Vector3 = game.player.position
	var original_rotation: Vector3 = game.player.rotation
	var original_camera: Vector3 = game.player.camera.rotation
	var original_target: Dictionary = game.player.target
	var original_mode: String = game.gamemode
	var original_inventory: Array = game.inventory.slots.duplicate(true)
	var original_selected: int = game.inventory.selected
	var had_sign_station: bool = world.stations.has(VoxelWorld.station_key(sign_pos))
	var had_frame_station: bool = world.stations.has(VoxelWorld.station_key(frame_pos))
	var save_path: String = "user://glow_ink_check.json"
	game.gamemode = "survival"; game.player.target = {}
	game.player.position = Vector3(sign_pos)+Vector3(0.5,0,-3)
	game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO
	game.player.camera.position.y = 1.62
	game.player.force_update_transform(); game.player.camera.force_update_transform()

	# --- recognition ----------------------------------------------------------
	t.check(GlowInk.is_glow_ink(VillageContent.GLOW_INK_SAC) and not GlowInk.is_glow_ink(VillageContent.INK_SAC) and not GlowInk.is_glow_ink(0) and not GlowInk.is_glow_ink(Nodes.STONE),"glow ink is recognised by its own source item and no other item, including the plain ink sac")

	# --- signs ----------------------------------------------------------------
	world.set_node(sign_pos,Signs.STANDING)
	var sign_state: Dictionary = Signs.station(world,sign_pos)
	t.check(not sign_state.glow and sign_state.color == Signs.DEFAULT_COLOR,"a freshly placed sign starts unlit and black")
	held(game,VillageContent.INK_SAC,2)
	t.check(not GlowInk.apply(game,target(sign_pos,Signs.STANDING)) and not sign_state.glow and game.inventory.held().count == 2,"a plain ink sac is refused by a sign and nothing is consumed")
	held(game,VillageContent.GLOW_INK_SAC,2)
	t.check(GlowInk.apply(game,target(sign_pos,Signs.STANDING)) and sign_state.glow and sign_state.color == "#7e7e7e" and game.inventory.held().count == 1,"glow ink makes sign text glow, brightens source black to #7e7e7e and consumes exactly one sac in survival")
	t.check(GlowInk.apply(game,target(sign_pos,Signs.STANDING)) and game.inventory.held().count == 0,"applying glow ink to an already-glowing sign still consumes a sac, as the source's name check does")
	held(game,0,0)
	t.check(not GlowInk.apply(game,target(sign_pos,Signs.STANDING)),"an empty hand cannot apply glow ink to a sign")
	held(game,VillageContent.GLOW_INK_SAC,2)
	game.gamemode = "creative"
	t.check(GlowInk.apply(game,target(sign_pos,Signs.STANDING)) and game.inventory.held().count == 2,"creative glow-ink use leaves the sac in the inventory")
	game.gamemode = "survival"

	# --- frames: form and glow ink --------------------------------------------
	world.set_node(frame_pos,VillageContent.ITEM_FRAME)
	var frame_state: Dictionary = Frames.station(world,frame_pos)
	frame_state.slots[0] = {"id":Nodes.STONE,"count":1,"wear":0}
	t.check(Frames.is_frame(VillageContent.ITEM_FRAME) and not Frames.is_frame(Nodes.STONE) and GlowInk.frame_variant(frame_state) == Frames.PLAIN,"a station frame starts as the source's plain frame form")
	held(game,VillageContent.GLOW_INK_SAC,6)
	t.check(GlowInk.apply(game,target(frame_pos,VillageContent.ITEM_FRAME)) and GlowInk.frame_variant(frame_state) == Frames.GLOW and game.inventory.held().count == 5,"glow ink on a filled frame produces the source's glow frame and consumes one sac")
	t.check(GlowInk.apply(game,target(frame_pos,VillageContent.ITEM_FRAME)) and GlowInk.frame_variant(frame_state) == Frames.INVISIBLE and game.inventory.held().count == 4,"a second sac reaches the source's invisible frame form")
	t.check(GlowInk.apply(game,target(frame_pos,VillageContent.ITEM_FRAME)) and GlowInk.frame_variant(frame_state) == Frames.INVISIBLE_GLOW and game.inventory.held().count == 3,"a third sac reaches the source's invisible glow frame form")
	t.check(GlowInk.apply(game,target(frame_pos,VillageContent.ITEM_FRAME)) and GlowInk.frame_variant(frame_state) == Frames.PLAIN and game.inventory.held().count == 2,"the frame forms wrap back to the plain frame, the source's own registration order")
	t.check(GlowInk.apply(game,target(frame_pos,VillageContent.ITEM_FRAME)) and GlowInk.frame_variant(frame_state) == Frames.GLOW and game.inventory.held().count == 1,"the frame cycle repeats on a second pass")
	t.check(Frames.glow_of(frame_state) and not Frames.invisible(frame_state) and Frames.glow_of({Frames.VARIANT_KEY:Frames.INVISIBLE_GLOW}) and Frames.invisible({Frames.VARIANT_KEY:Frames.INVISIBLE}) and not Frames.glow_of({Frames.VARIANT_KEY:Frames.INVISIBLE}),"the glow and invisible halves of a form are read independently")
	t.check(GlowInk.frame_variant({Frames.VARIANT_KEY:"nonsense"}) == Frames.PLAIN and not Frames.glow_of({Frames.VARIANT_KEY:"nonsense"}),"an unknown saved form falls back to the plain frame rather than glowing invisibly")

	# --- frames: rotation -----------------------------------------------------
	var item_frame_pos: Vector3i = frame_pos+Vector3i(3,0,0)
	world.set_node(item_frame_pos,VillageContent.ITEM_FRAME)
	var rotation_state: Dictionary = Frames.station(world,item_frame_pos)
	held(game,VillageContent.GLOW_INK_SAC,1)
	t.check(not Frames.rotate(game,item_frame_pos) and Frames.rotation_of(rotation_state) == 0 and game.inventory.held().count == 1,"an empty frame refuses to rotate, exactly as the source's filled-stack gate does")
	t.check(not GlowInk.apply(game,target(item_frame_pos,VillageContent.ITEM_FRAME)) and GlowInk.frame_variant(rotation_state) == Frames.PLAIN and game.inventory.held().count == 1,"an empty frame does not accept glow ink and consumes nothing")
	rotation_state.slots[0] = {"id":Nodes.STONE,"count":1,"wear":0}
	t.check(Frames.ROTATIONS == 8 and Frames.rotate(game,item_frame_pos) and Frames.rotation_of(rotation_state) == 1 and Frames.rotate(game,item_frame_pos) and Frames.rotation_of(rotation_state) == 2,"rotating a filled frame advances the saved source index once per use, in a range of eight")
	for i in 6: Frames.rotate(game,item_frame_pos)
	t.check(Frames.rotation_of(rotation_state) == 0,"the source's saved frame index wraps back to zero at eight")
	for i in 4: Frames.rotate(game,item_frame_pos)
	t.check(Frames.rotation_of(rotation_state) == 4 and Frames.rotation_of({}) == 0 and Frames.rotation_of({Frames.ROTATION_KEY:8}) == 0 and Frames.rotation_of({Frames.ROTATION_KEY:11}) == 3 and Frames.rotation_of({Frames.ROTATION_KEY:-3}) == 5 and Frames.rotation_of({Frames.ROTATION_KEY:"x"}) == 0,"the saved index is read modulo eight the way the source's own arithmetic does")
	t.check(not Frames.rotate(game,sign_pos) and not Frames.rotate(game,sign_pos+Vector3i(0,0,1)),"a cell that is not an item frame cannot be rotated")
	t.check(is_equal_approx(Frames.angle(Nodes.STONE,0),0.0) and is_equal_approx(Frames.angle(Nodes.STONE,1),PI/4.0) and is_equal_approx(Frames.angle(Nodes.STONE,7),PI*7.0/4.0),"an ordinary frame item turns in the source's forty-five-degree steps")
	t.check(is_equal_approx(Frames.angle(VillageContent.FILLED_MAP,1),PI/2.0) and is_equal_approx(Frames.angle(VillageContent.FILLED_MAP,3),PI*1.5) and is_equal_approx(Frames.angle(VillageContent.FILLED_MAP,2),Frames.angle(Nodes.STONE,4)),"a map uses the source's doubled ninety-degree step")
	t.check(is_equal_approx(Frames.angle(Nodes.STONE,8),Frames.angle(Nodes.STONE,0)) and is_equal_approx(Frames.angle(Nodes.STONE,-1),Frames.angle(Nodes.STONE,7)),"the angle wraps with the saved index instead of growing without bound")

	# --- frames: comparator ---------------------------------------------------
	var signals: Array = []
	for index in 8: signals.append(Frames.comparator_signal({Frames.ROTATION_KEY:index,"slots":[{"id":Nodes.STONE,"count":1,"wear":0}]}))
	t.check(signals == [1,2,3,4,5,6,7,8],"a comparator reads the frame's source index plus one for every index in range")
	t.check(Frames.comparator_signal({"slots":[{"id":0,"count":0,"wear":0}]}) == 0 and Frames.comparator_signal({"slots":[]}) == 0 and Frames.comparator_signal({}) == 0,"an empty frame reports no comparator signal")
	t.check(Frames.comparator_signal({Frames.ROTATION_KEY:9,"slots":[{"id":Nodes.STONE}]}) == 2 and Frames.comparator_signal({Frames.ROTATION_KEY:3,"slots":[{"id":VillageContent.FILLED_MAP,"count":1,"wear":0}]}) == 4,"the signal is the wrapped index for every item, including a map whose visual step is twice as large")

	# --- frames: display ------------------------------------------------------
	# `refresh_displays` builds the framed item's mesh; the source spins that entity
	# and makes a glow form self-lit, and the item material `ItemArt` hands out is
	# shared per id, so a glowing frame must not shade every item of that kind.
	var plain_material: StandardMaterial3D = ItemArt.material(Nodes.STONE)
	var display := MeshInstance3D.new()
	display.mesh = ItemArt.mesh(Nodes.STONE); display.material_override = plain_material
	Frames.apply_display(display,Nodes.STONE,{Frames.ROTATION_KEY:2})
	t.check(is_equal_approx(display.rotation.z,PI/2.0) and display.material_override == plain_material and plain_material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL,"an ordinary frame display turns its item without touching the shared item material")
	Frames.apply_display(display,Nodes.STONE,{Frames.ROTATION_KEY:2,Frames.VARIANT_KEY:Frames.GLOW})
	t.check(is_equal_approx(display.rotation.z,PI/2.0) and display.material_override != plain_material and display.material_override.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,"a glow frame makes its own copy of the item material self-lit and leaves the shared one shaded")
	Frames.apply_display(display,VillageContent.FILLED_MAP,{Frames.ROTATION_KEY:2})
	t.check(is_equal_approx(display.rotation.z,PI),"a framed map display uses the source's doubled ninety-degree step")
	display.rotation.z = 0.0
	Frames.apply_display(display,0,{Frames.ROTATION_KEY:5})
	t.check(is_equal_approx(display.rotation.z,0.0),"an empty frame display is left untouched")
	display.free()

	# --- saved state ----------------------------------------------------------
	rotation_state[Frames.ROTATION_KEY] = 3
	rotation_state[Frames.VARIANT_KEY] = Frames.GLOW
	var fields: Dictionary = Frames.clean_state(rotation_state)
	t.check(fields == {Frames.ROTATION_KEY:3,Frames.VARIANT_KEY:Frames.GLOW},"clean_state returns exactly the fields this module owns")
	# JSON turns the integers into floats, which is what a real save does to them.
	var raw: Dictionary = JSON.parse_string(JSON.stringify(fields))
	t.check(raw.has(Frames.ROTATION_KEY) and raw.has(Frames.VARIANT_KEY) and Frames.rotation_of(raw) == 3 and Frames.variant_of(raw) == Frames.GLOW and Frames.clean_state(raw) == fields,"the frame's saved fields survive a JSON round trip unchanged")
	t.check(game.save_game(save_path),"a frame station writes through a real save")
	var persisted: Dictionary = game.read_save(save_path)
	var restored: Dictionary = persisted.get("stations",{}).get(VoxelWorld.station_key(item_frame_pos),{})
	# The game's own load path re-cleans every station's slots through
	# `Inventory.clean_slot` (`game.gd`:1126-1131); the frame's own fields are not
	# slots, so the round trip below is what a real load does to them.
	var slots: Array = restored.get("slots",[])
	for i in slots.size(): slots[i] = Inventory.clean_slot(slots[i])
	var cleaned: Dictionary = Frames.clean_state(restored)
	t.check(not restored.is_empty() and Frames.rotation_of(restored) == 3 and Frames.variant_of(restored) == Frames.GLOW and Frames.comparator_signal(restored) == 4 and slots[0].id == Nodes.STONE and cleaned == {Frames.ROTATION_KEY:3,Frames.VARIANT_KEY:Frames.GLOW},"a real save keeps the frame's rotation index and form through the inventory allow-list, and the signal still reads three plus one")
	var legacy: Dictionary = Frames.clean_state({})
	t.check(legacy == {Frames.ROTATION_KEY:0,Frames.VARIANT_KEY:Frames.PLAIN} and Frames.comparator_signal({"slots":[{"id":Nodes.STONE,"count":1,"wear":0}]}) == 1,"an old save without the frame's fields loads as the source's plain zero-indexed frame")

	# --- restore --------------------------------------------------------------
	var user_path: String = ProjectSettings.globalize_path(save_path)
	for candidate in [user_path,user_path+".bak"]:
		if FileAccess.file_exists(candidate): DirAccess.remove_absolute(candidate)
	for p in [sign_pos,frame_pos,item_frame_pos]: world.set_node(p,Nodes.AIR)
	if not had_sign_station: world.stations.erase(VoxelWorld.station_key(sign_pos))
	if not had_frame_station:
		world.stations.erase(VoxelWorld.station_key(frame_pos)); world.stations.erase(VoxelWorld.station_key(item_frame_pos))
	game.survival.refresh_displays()
	game.gamemode = original_mode
	game.inventory.slots = original_inventory; game.inventory.selected = original_selected
	game.player.target = original_target
	game.player.position = original_position; game.player.rotation = original_rotation
	game.player.camera.rotation = original_camera
	game.player.force_update_transform(); game.player.camera.force_update_transform()

	wiring(t,game)

# --- the wired click paths ---------------------------------------------------
# The three lines Main landed are exercised through the modules that own them, not
# through `Frames` directly, so a later change to a dispatcher shows up here.

static func wiring(t: SceneTree, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var saved_position: Vector3 = game.player.position
	var saved_target: Dictionary = game.player.target
	var saved_mode: String = game.gamemode
	var saved_touch: bool = game.touch
	var temporary_controls: bool = not is_instance_valid(game.controls)
	if temporary_controls:
		game.controls = TouchControls.new(); game.controls.game = game; game.add_child(game.controls)
	var saved_sneak: bool = game.controls.sneak_held
	# Y2400 sits between the crop fixture (Y2100) and the ore fixture (Y2000 is
	# lower still), and X8/Z8 is the column every fixture shares.
	var base := Vector3i(8,2400,8)
	var sign_cell: Vector3i = base
	var frame_cell: Vector3i = base+Vector3i(2,0,0)
	var empty_cell: Vector3i = base+Vector3i(4,0,0)
	var saved_cells: Dictionary = {}
	for offset in [Vector3i.ZERO,Vector3i(2,0,0),Vector3i(4,0,0)]:
		saved_cells[base+offset] = world.stations.has(VoxelWorld.station_key(base+offset))
	for x in range(-2,7):
		for z in range(-2,3):
			for y in range(base.y-1,base.y+5): world.set_node(Vector3i(base.x+x,y,base.z+z),Nodes.AIR)
			world.set_node(Vector3i(base.x+x,base.y-1,base.z+z),Nodes.STONE)
	game.touch = false; game.gamemode = "survival"
	# The plot is high above every creature, so `target_mob` cannot find one and
	# steal the click. The camera is moved with the player for the same reason.
	game.player.position = Vector3(base)+Vector3(0.5,0,-3)
	game.player.rotation = Vector3.ZERO; game.player.camera.rotation = Vector3.ZERO
	game.player.camera.position.y = 1.62
	game.player.force_update_transform(); game.player.camera.force_update_transform()
	game.player.target = {}

	# `Signs.use` is consulted before `game.survival.use()` in the player's chain
	# (`player.gd`:584 vs :590), so the sign half lives there.
	world.set_node(sign_cell,Signs.STANDING)
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":VillageContent.GLOW_INK_SAC,"count":1,"wear":0}
	t.check(Signs.is_sign(world.node_at(sign_cell)),"a sign stands for the wired glow-ink click")
	t.check(Signs.use(game,target(sign_cell,Signs.STANDING)) and Signs.station(world,sign_cell).glow and game.inventory.count_item(VillageContent.GLOW_INK_SAC) == 0,"the sign module's own click consumes glow ink and sets the sign's glow")

	# The frame half is in the survival module's `use`.
	world.set_node(frame_cell,VillageContent.ITEM_FRAME)
	var frame_station: Dictionary = Frames.station(world,frame_cell)
	frame_station.slots[0] = {"id":Nodes.STONE,"count":1,"wear":0}
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":VillageContent.GLOW_INK_SAC,"count":1,"wear":0}
	game.player.target = target(frame_cell,VillageContent.ITEM_FRAME)
	t.check(game.survival.use(),"the survival dispatcher handles a glow-ink click on a frame (the target is the aimed frame)")
	var wired: Dictionary = Frames.station(world,frame_cell)
	t.check(Frames.glow_of(wired) and wired.slots[0].id == Nodes.STONE and game.inventory.count_item(VillageContent.GLOW_INK_SAC) == 0,"the wired frame branch changes the form, keeps the item and consumes the sac")

	# A second sac on the same frame keeps advancing the form, so the branch is not a
	# one-shot; this is the source's own repeat behaviour on a sign.
	game.inventory.restore([]); game.inventory.selected = 0
	game.gamemode = "creative"
	game.inventory.slots[0] = {"id":VillageContent.GLOW_INK_SAC,"count":1,"wear":0}
	var glow_only: Dictionary = Frames.station(world,frame_cell)
	t.check(game.survival.use() and Frames.variant_of(glow_only) == Frames.INVISIBLE and game.inventory.count_item(VillageContent.GLOW_INK_SAC) == 1,"creative glow-ink use advances the frame form without consuming the sac")
	game.gamemode = "survival"

	# `frame_item`'s rotation branch is gated on sneak, so a normal click still takes.
	game.inventory.restore([]); game.inventory.selected = 0
	game.player.target = target(frame_cell,VillageContent.ITEM_FRAME)
	world.set_node(frame_cell,VillageContent.ITEM_FRAME)
	var station: Dictionary = Frames.station(world,frame_cell)
	station.slots[0] = {"id":Nodes.STONE,"count":1,"wear":0}
	var before: int = Frames.rotation_of(station)
	game.survival.frame_item(frame_cell)
	t.check(Frames.rotation_of(Frames.station(world,frame_cell)) == before and game.inventory.count_item(Nodes.STONE) == 1,"an ordinary frame click takes the item out without rotating, which is Voxey's own click order")
	game.inventory.restore([]); game.inventory.selected = 0
	station = Frames.station(world,frame_cell)
	station.slots[0] = {"id":Nodes.STONE,"count":1,"wear":0}
	game.controls.sneak_held = true; game.touch = true
	game.survival.frame_item(frame_cell)
	t.check(Frames.rotation_of(Frames.station(world,frame_cell)) == 1 and Frames.station(world,frame_cell).slots[0].id == Nodes.STONE,"a sneaking click turns the frame instead of taking its item")
	game.controls.sneak_held = false; game.touch = false

	# The comparator's own read is `RedstoneCircuit.container_signal`, which needs the
	# real circuit instance; the node is what it dispatches on.
	station = Frames.station(world,frame_cell)
	station[Frames.ROTATION_KEY] = 3
	t.check(world.circuits.container_signal(frame_cell) == 4,"the comparator reads a real frame cell as its rotation plus one")
	world.set_node(empty_cell,VillageContent.ITEM_FRAME)
	Frames.station(world,empty_cell)
	t.check(world.circuits.container_signal(empty_cell) == 0,"the comparator reads an empty frame cell as no signal")

	# The display spin and the glow form's self-lit material, driven from a real
	# frame station's own saved fields.
	var display_state: Dictionary = Frames.station(world,frame_cell)
	display_state[Frames.ROTATION_KEY] = 3
	display_state[Frames.VARIANT_KEY] = Frames.GLOW
	var mesh := MeshInstance3D.new()
	mesh.mesh = ItemArt.mesh(Nodes.STONE); mesh.material_override = ItemArt.material(Nodes.STONE)
	Frames.apply_display(mesh,Nodes.STONE,display_state)
	t.check(is_equal_approx(mesh.rotation.z,PI*3.0/4.0) and (mesh.material_override as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and not is_same(mesh.material_override,ItemArt.material(Nodes.STONE)),"a glowing frame's display spins the item to the saved rotation with its own self-lit material")
	mesh.free()

	# --- restore --------------------------------------------------------------
	for cell in [sign_cell,frame_cell,empty_cell]:
		world.set_node(cell,Nodes.AIR)
		if not saved_cells.get(cell,false): world.stations.erase(VoxelWorld.station_key(cell))
	game.survival.refresh_displays()
	game.gamemode = saved_mode; game.touch = saved_touch
	game.player.target = saved_target; game.player.position = saved_position
	if is_instance_valid(game.controls): game.controls.sneak_held = saved_sneak
	if temporary_controls and is_instance_valid(game.controls): game.controls.queue_free(); game.controls = null

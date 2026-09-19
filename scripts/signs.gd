class_name Signs
extends RefCounted

# Text, placement and dye semantics adapted from Mineclonia mcl_signs (MIT).
# See docs/signs-source.md and docs/licenses/Mineclonia-signs-MIT.txt.
# Original procedural geometry and native text; no source models/font textures.
const OAK = 6600
const STANDING = OAK+4
const END = STANDING+16
const DEFAULT_COLOR = "#000000"
const NEWLINES = [10,11,12,133,8232,8233]
const WHITESPACE = [9,32,5760,8192,8193,8194,8195,8196,8197,8198,8200,8201,8202,8287,12288]
const HYPHENS = [45,173,1418,1470,6150,8208,11799,11869,12539,65123,65293,65381]
const SUPPORT = [Vector3i.FORWARD,Vector3i.LEFT,Vector3i.BACK,Vector3i.RIGHT]
const DYE_COLORS = {"white":"#d0d6d7","silver":"#818177","grey":"#383c40","black":"#080a10","purple":"#6821a0","blue":"#2e3094","light_blue":"#258ec9","cyan":"#167b8c","green":"#4b5e25","lime":"#60ac19","yellow":"#f1b216","brown":"#633d20","orange":"#e26501","red":"#912222","magenta":"#ab31a2","pink":"#d56791"}
const SUPPORTED = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz 0123456789(){}[]'!?@#$%^&*_+-=;,\"/~<>\\|.:`äëïöüÄËÏÖÜß×·÷»«¢¿±©®¨§¦¥¤£¡¬¯°¹²³´¶¼½¾ÀÁÂÃÅÆªº¸ÇçÈÉÊÌÍÎÐÑÒÓÔÕØÙÚÛÝÞàáâãåæèéêìíîðñòóôõøùúûýþÿĄŁ€ĽŚŠŞȘŤŹŽŻąłľśšşșťźžżŔĂĹĆČĘĚĎŃŇŐŘŮŰŢȚŕăĺćčęěďńňőřůűţțĦĤİĞĴħĥığĵĊĈĠĜŬŜċĉġĝŭŝĸŖĨĻĒĢŦĩļēģŧŊŋĀĮĖĪŅŌĶŲŨŪāįėīņōķųũūАаӐӑӒӓӘәБбВвГгҐґҒғДдЂђЃѓЕеЀѐЁёЄєЖжӁӂЗзЅѕИиЍѝӢӣЙйӤӥІіЇїЈјКкЌќҚқЛлЉљМмНнҢңЊњОоӦӧѲѳӨөПпРрСсТтЋћУуӮӯЎўӰӱҰұҮүФфХхҺһЦцЧчЏџШшЩщЪъЫыЬьѢѣЭэЮюЯяΑαΆάΒβΓγΔδΕεΈέΖζΗηΉήΘϴθϑΙιΊίΪϊΐΚκϏϗΛλΜµμΝνΞξΟοΌόΠπΡρΣσςΤτΥυΎύΫϋΰΦφϕΧχΨψΩωΏώ‐…↵"
static var supported_characters: Dictionary = {}
static var icons: Dictionary = {}
static var text_font: SystemFont

static func is_sign(id: int) -> bool: return id >= OAK and id < END
static func item(_id: int) -> int: return OAK
static func wall(id: int) -> bool: return id < STANDING
static func facing(id: int) -> int: return id-OAK if wall(id) else id-STANDING
static func yaw(id: int) -> float: return facing(id)*(PI/2.0 if wall(id) else TAU/16.0)
static func material(_id: int) -> int: return Nodes.PLANKS
static func support_offset(id: int) -> Vector3i: return SUPPORT[facing(id)] if wall(id) else Vector3i.DOWN

static func definitions() -> Dictionary:
	var result: Dictionary = {}
	for id in range(OAK,END): result[id] = {"name":"Oak sign","block":true,"shape":"sign","color":"b28c52","stack":16,"hardness":1.0,"tool":1,"hidden":id != OAK}
	return result

static func recipes(inv: Inventory) -> void:
	inv._recipe("Oak sign",OAK,3,[Nodes.PLANKS,Nodes.PLANKS,Nodes.PLANKS,Nodes.PLANKS,Nodes.PLANKS,Nodes.PLANKS,0,Nodes.STICK,0],3,"table")

static func boxes(id: int) -> Array:
	if wall(id): return [Barriers.rotate_box(AABB(Vector3(0,0.25,0),Vector3(1,0.5,5.0/56.0)),posmod(-facing(id),4))]
	return [AABB(Vector3(0.3,0,0.3),Vector3(0.4,1,0.4))]

static func mesh(out: Array, at: Vector3, id: int) -> void:
	var parts: Array = BlockMesher._empty()
	var tile: int = Nodes.tile(material(id),0)
	if wall(id): BlockMesher._art_box(parts,Vector3(0.5,0.5,1.0/24),Vector3(1,0.5,1.0/12),tile,tile)
	else:
		BlockMesher._art_box(parts,Vector3(0.5,7.0/24,0.5),Vector3(1.0/12,7.0/12,1.0/12),tile,tile)
		BlockMesher._art_box(parts,Vector3(0.5,5.0/6,0.5),Vector3(1,0.5,1.0/12),tile,tile)
	var pivot := Vector3(0.5,0,0.5)
	var offset: int = out[0].size()
	for vertex in parts[0]: out[0].append(at+pivot+(vertex-pivot).rotated(Vector3.UP,yaw(id)))
	for normal in parts[1]: out[1].append(normal.rotated(Vector3.UP,yaw(id)))
	for channel in [2,3,4]: out[channel].append_array(parts[channel])
	for index in parts[5]: out[5].append(offset+index)

static func icon_faces(id: int) -> Array:
	id = item(id)
	if not icons.has(id):
		var out: Array = BlockMesher._empty(); mesh(out,Vector3.ZERO,STANDING)
		icons[id] = Barriers.project_icon(out)
	return icons[id]

# Lua utf8.codes supplies one-based BYTE offsets. A codepoint starting below
# byte 256 is retained whole; CR terminates conversion in the actual source.
static func clean_text(value: String) -> String:
	var result: String = ""; var byte_index: int = 1
	for character in value:
		if byte_index >= 256 or character.unicode_at(0) == 13: break
		result += character; byte_index += character.to_utf8_buffer().size()
	return result

static func lines(value: String) -> PackedStringArray:
	var text: String = clean_text(value)
	var result := PackedStringArray(); var start: int = 0; var stop: int = 0
	for cursor in text.length():
		if result.size() >= 4: break
		var code: int = text.unicode_at(cursor)
		if code in WHITESPACE or code in HYPHENS: stop = cursor
		elif code in NEWLINES:
			result.append(text.substr(start,cursor-start)); start = cursor+1; stop = start
		elif cursor-start+1 >= 15:
			if stop <= start:
				result.append(text.substr(start,cursor-start+1)+"‐"); start = cursor+1; stop = start
			else:
				result.append(text.substr(start,stop-start+(1 if text.unicode_at(stop) in HYPHENS else 0))); start = stop+1; stop = start
	if result.size() < 4 and start < text.length(): result.append(text.substr(start))
	return result

static func station(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.stations.has(key): world.stations[key] = {}
	var state: Dictionary = world.stations[key]
	state["kind"] = "sign"; state["text"] = clean_text(str(state.get("text","")))
	var color: String = str(state.get("color",DEFAULT_COLOR)).to_lower()
	state["color"] = color if color == DEFAULT_COLOR or color == "#7e7e7e" or color in DYE_COLORS.values() else DEFAULT_COLOR
	state["glow"] = state.get("glow",false) == true
	state["written"] = state.get("written",false) == true
	state["serial"] = int(state.get("serial",0))
	if state.serial <= 0:
		world.adventure_state["sign_serial"] = int(world.adventure_state.get("sign_serial",0))+1
		state.serial = int(world.adventure_state.sign_serial)
	else: world.adventure_state["sign_serial"] = maxi(int(world.adventure_state.get("sign_serial",0)),state.serial)
	return state

static func refresh(world: VoxelWorld) -> void:
	var game: Node = world.get_parent()
	if game != null and game.get("survival") != null: game.survival.refresh_displays()

static func apply_dye(world: VoxelWorld, p: Vector3i, color: String) -> bool:
	if not is_sign(world.node_at(p)) or not DYE_COLORS.has(color): return false
	station(world,p)["color"] = DYE_COLORS[color]; refresh(world); return true

# Source glow affects the text sprite, not neighboring light. No glow-ink item
# exists in Voxey yet, so gameplay does not call this helper without acquisition.
static func apply_glow(world: VoxelWorld, p: Vector3i) -> bool:
	if not is_sign(world.node_at(p)): return false
	var state: Dictionary = station(world,p)
	state.glow = true
	if state.color == DEFAULT_COLOR: state.color = "#7e7e7e"
	refresh(world); return true

static func sneaking(game: Node3D) -> bool:
	return Input.is_physical_key_pressed(KEY_CTRL) or game.touch and is_instance_valid(game.controls) and game.controls.sneak_held

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or not is_sign(int(target.get("id",0))) or game.target_mob() != null: return false
	var definition: Dictionary = VillageContent.DATA.get(int(game.inventory.held().id),{})
	if definition.get("family","") == "dye" and apply_dye(game.world,target.pos,str(definition.get("dye",""))):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.player.swing = 1; game.sound("place"); return true
	if sneaking(game): return false
	if game.game_rules.get("signsEditable",false): open_editor(game,target.pos,false)
	# The source sign right-click callback returns the held stack even when
	# editing is disabled, so ordinary use does not eat food or place a block.
	return true

static func replaceable(id: int) -> bool:
	return id == Nodes.AIR or Fluids.liquid(id) or Nodes.plant(id) or Fire.is_fire(id) or SnowCover.is_snow(id)

static func placement_id(normal: Vector3i, angle: float) -> int:
	if normal == Vector3i.UP: return STANDING+posmod(int(floorf(angle/(TAU/16.0)+0.5)),16)
	var direction: int = SUPPORT.find(-normal)
	return OAK+direction if direction >= 0 else 0

static func try_place(game: Node3D, target: Dictionary) -> bool:
	var held: int = game.inventory.held().id
	if not is_sign(held) or target.is_empty(): return false
	if held != OAK: return true
	var at: Vector3i = target.get("replace",target.pos if replaceable(int(target.id)) else target.pos+target.normal)
	if not replaceable(game.world.node_at(at)): return true
	var id: int = placement_id(target.normal,game.player.rotation.y)
	if id == 0: return true
	var behind: Vector3i = at+support_offset(id)
	var backing: int = game.world.node_at(behind)
	if not game.world.loaded_at(Vector3(at)) or not game.world.loaded_at(Vector3(behind)) or not (Nodes.solid(backing) or is_sign(backing)): return true
	if game.world.set_node(at,id):
		station(game.world,at)
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.player.swing = 1; game.sound("place"); game.api.emit_node_placed(at,id)
		open_editor(game,at,true)
	return true

# mcl_attached removes supported nodes only when the support is airlike;
# non-solid mesh/plant/fluid replacements are not treated as newly absent.
static func airlike(id: int) -> bool:
	return id == Nodes.AIR

static func supported(world: VoxelWorld, p: Vector3i, id: int) -> bool:
	var backing: Vector3i = p+support_offset(id)
	return not world.loaded_at(Vector3(backing)) or not airlike(world.node_at(backing))

static func validate_support(world: VoxelWorld, p: Vector3i) -> void:
	if world.circuits.moving:
		var pending: Dictionary = world.get_meta("sign_support_pending",{})
		pending[p] = true; world.set_meta("sign_support_pending",pending); return
	var id: int = world.node_at(p)
	if is_sign(id) and not supported(world,p,id) and world.set_node(p,Nodes.AIR):
		world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,OAK,1)

static func finish_piston(world: VoxelWorld) -> void:
	var pending: Dictionary = world.get_meta("sign_support_pending",{})
	if world.has_meta("sign_support_pending"): world.remove_meta("sign_support_pending")
	for p in pending: validate_support(world,p)
	if not pending.is_empty(): refresh(world)

static func changed(world: VoxelWorld, p: Vector3i, old_id: int, new_id: int) -> void:
	if is_sign(old_id) and not is_sign(new_id):
		world.stations.erase(VoxelWorld.station_key(p))
		var game: Node = world.get_parent()
		var session: Dictionary = game.get_meta("sign_editor",{})
		if not session.is_empty() and session.pos == p and session.dimension == game.dimension:
			game.remove_meta("sign_editor")
			if game.state == "sign": game.resume()
		if game.get("survival") != null:
			var key: String = VoxelWorld.station_key(p)
			if game.survival.displays.has(key):
				if is_instance_valid(game.survival.displays[key]): game.survival.displays[key].queue_free()
				game.survival.displays.erase(key)
	elif is_sign(new_id):
		station(world,p)
		if world.circuits.moving: validate_support(world,p)
	if not airlike(new_id): return
	for offset in [Vector3i.UP,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		var at: Vector3i = p+offset; var id: int = world.node_at(at)
		if not is_sign(id) or at+support_offset(id) != p: continue
		validate_support(world,at)

static func font() -> SystemFont:
	if text_font == null:
		text_font = SystemFont.new(); text_font.font_names = PackedStringArray(["DejaVu Sans Mono","Noto Sans Mono","monospace"])
	return text_font

static func display_text(text: String) -> String:
	var rendered := PackedStringArray()
	if supported_characters.is_empty():
		for character in SUPPORTED: supported_characters[character] = true
	for line in lines(text):
		# Source texture is a fixed 115 px canvas, clipping exceptionally long
		# whitespace/hyphen runs after centering rather than expanding the board.
		if line.length() > 19: line = line.substr((line.length()-19)/2,19)
		var visible: String = ""
		for character in line: visible += character if supported_characters.has(character) else "�"
		rendered.append(visible)
	return "\n".join(rendered)

static func display_model(game: Node3D, p: Vector3i, state: Dictionary) -> Node3D:
	var id: int = game.world.node_at(p)
	var model := Node3D.new(); model.position = Vector3(p)
	var label := Label3D.new(); label.name = "SignText"
	label.text = display_text(str(state.get("text",""))); label.font = font()
	label.font_size = 48; label.pixel_size = 0.00168; label.outline_size = 0
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.modulate = Color(str(state.get("color",DEFAULT_COLOR))); label.shaded = not state.get("glow",false)
	label.double_sided = false; label.no_depth_test = false
	var local_position := Vector3(0.5,0.73,1.0/12+0.002) if wall(id) else Vector3(0.5,1.0+1.0/12-0.02,0.5+1.0/24+0.002)
	var pivot := Vector3(0.5,0,0.5)
	label.position = pivot+(local_position-pivot).rotated(Vector3.UP,yaw(id)); label.rotation.y = yaw(id)
	model.add_child(label); return model

static func open_editor(game: Node3D, p: Vector3i, initial: bool = false) -> bool:
	if not is_sign(game.world.node_at(p)) or not initial and not game.game_rules.get("signsEditable",false): return false
	var state: Dictionary = station(game.world,p)
	game.set_meta("sign_editor",{"pos":p,"dimension":game.dimension,"id":game.world.node_at(p),"serial":state.serial,"draft":state.text,"initial":initial})
	game.state = "sign"; game.world.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(game.controls): game.controls.hide_all()
	reflow(game); return true

static func session_valid(game: Node3D, session: Dictionary) -> bool:
	if session.is_empty() or session.dimension != game.dimension or game.world.node_at(session.pos) != session.id: return false
	if not game.world.loaded_at(Vector3(session.pos)): return false
	var state: Dictionary = game.world.stations.get(VoxelWorld.station_key(session.pos),{})
	return int(state.get("serial",0)) == int(session.serial)

static func submit(game: Node3D) -> bool:
	var session: Dictionary = game.get_meta("sign_editor",{})
	if not session_valid(game,session) or not session.initial and not game.game_rules.get("signsEditable",false): return false
	var state: Dictionary = station(game.world,session.pos)
	state.text = clean_text(session.draft); state.written = true
	game.remove_meta("sign_editor"); refresh(game.world); game.resume(); return true

static func cancel(game: Node3D) -> void:
	if game.has_meta("sign_editor"): game.remove_meta("sign_editor")
	game.resume()

static func reflow(game: Node3D) -> void:
	var session: Dictionary = game.get_meta("sign_editor",{})
	if not session_valid(game,session): cancel(game); return
	game.hud._clear(); game.hud.screen = "sign"; game.hud._dim()
	var panel: Panel = game.hud._fitted_panel(Vector2(640,510),Color("3c342e"))
	game.hud._label(panel,"WRITE ON SIGN",Vector2(24,18),24,game.hud.ACCENT)
	game.hud._label(panel,"4 lines · 15 characters before wrapping",Vector2(24,55),15,game.hud.MUTED)
	var editor := TextEdit.new(); editor.name = "SignEditor"
	editor.position = Vector2(24,88); editor.size = Vector2(592,158); editor.text = session.draft
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; editor.add_theme_font_override("font",font())
	editor.add_theme_font_size_override("font_size",19); panel.add_child(editor)
	game.hud._label(panel,"SIGN PREVIEW",Vector2(24,264),13,game.hud.MUTED)
	var preview: Label = game.hud._label(panel,display_text(session.draft),Vector2(24,290),22,Color("eadbc0"))
	preview.name = "SignPreview"; preview.size = Vector2(592,112); preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_theme_font_override("font",font()); preview.clip_text = true
	var status: Label = game.hud._label(panel,"",Vector2(24,417),12,game.hud.MUTED)
	var changed_text: Callable = func():
		var normalized: String = clean_text(editor.text)
		if normalized != editor.text:
			var row: int = editor.get_caret_line(); var column: int = editor.get_caret_column()
			editor.text = normalized; editor.set_caret_line(mini(row,editor.get_line_count()-1)); editor.set_caret_column(column)
		session.draft = normalized; preview.text = display_text(normalized)
		status.text = "Only this preview will appear on the sign. Choose Done to save."
	changed_text.call(); editor.text_changed.connect(changed_text)
	game.hud._button(panel,"Cancel",Rect2(24,456,170,34),func(): cancel(game))
	game.hud._button(panel,"Done",Rect2(208,456,408,34),func(): submit(game))
	editor.grab_focus()

class_name Banners
extends RefCounted

# Mineclonia ITEMS/mcl_banners/{init,items,patterncraft}.lua, GPL-3.0-or-later.
# Original GDScript using the source as a behaviour reference.
#
# Item metadata, floor/wall placement, pattern crafting and the visual loom.
# The installed source allows twelve craftable layers and lists six per tooltip.
# Geometry and pattern artwork are native to Voxey.

const FIRST = VillageContent.BANNER_FIRST
# The sixteen banner colours in the source's order. Kept here rather than derived
# from `Nodes.title`, which delegates back into `describe` and would recurse.
const BANNER_NAMES = ["White","Grey","Light grey","Black","Yellow","Orange","Red","Magenta",
	"Purple","Blue","Cyan","Lime","Green","Pink","Light blue","Brown"]
const COLORS = 16
# The source's `max_craftable_layers`.
const MAX_LAYERS = 12
const DESCRIPTION_LAYERS = 6
const MAX_STORED_LAYERS = 64
const NORMALS = [Vector3i.RIGHT,Vector3i.BACK,Vector3i.LEFT,Vector3i.FORWARD]
static var textures: Dictionary = {}
static var removals: Dictionary = {}
# `d` is a dye, `e` is empty, in reading order across the three rows.
const DYE = "d"
const EMPTY = "e"

# The source's pattern table: key -> [display name, grid-or-signature].
# Grids are nine characters; a signature is the extra item instead of a grid.
const PATTERNS = {
	"border":{"name":"Bordure","grid":"ddddedddd"},
	"bricks":{"name":"Bricks","signature":"BRICK_BLOCK"},
	"circle":{"name":"Roundel","grid":"eeeedeeee"},
	"creeper":{"name":"Creeper Charge","signature":"HEAD_CREEPER"},
	"cross":{"name":"Saltire","grid":"dedededed"},
	"curly_border":{"name":"Bordure Indented","signature":"VINE"},
	"diagonal_up_left":{"name":"Per Bend Inverted","grid":"eeedeedde"},
	"diagonal_up_right":{"name":"Per Bend Sinister Inverted","grid":"eeeeededd"},
	"diagonal_right":{"name":"Per Bend","grid":"eddeedeee"},
	"diagonal_left":{"name":"Per Bend Sinister","grid":"ddedeeeee"},
	"flower":{"name":"Flower Charge","signature":"OXEYE_DAISY"},
	"gradient":{"name":"Gradient","grid":"dededeede"},
	"gradient_up":{"name":"Base Gradient","grid":"edeededed"},
	"half_horizontal_bottom":{"name":"Per Fess Inverted","grid":"eeedddddd"},
	"half_horizontal":{"name":"Per Fess","grid":"ddddddeee"},
	"half_vertical":{"name":"Per Pale","grid":"ddeddedde"},
	"half_vertical_right":{"name":"Per Pale Inverted","grid":"eddeddedd"},
	"globe":{"name":"Globe Charge","signature":"PATTERN_GLOBE"},
	"piglin":{"name":"Piglin Charge","signature":"PATTERN_PIGLIN"},
	"rhombus":{"name":"Lozenge","grid":"edededede"},
	"skull":{"name":"Skull Charge","signature":"PATTERN_SKULL"},
	"small_stripes":{"name":"Paly","grid":"deddedeee"},
	"square_bottom_left":{"name":"Base Dexter Canton","grid":"eeeeeedee"},
	"square_bottom_right":{"name":"Base Sinister Canton","grid":"eeeeeeeed"},
	"square_top_left":{"name":"Chief Dexter Canton","grid":"deeeeeeee"},
	"square_top_right":{"name":"Chief Sinister Canton","grid":"eedeeeeee"},
	"straight_cross":{"name":"Cross","grid":"ededddede"},
	"stripe_bottom":{"name":"Base","grid":"eeeeeeddd"},
	"stripe_center":{"name":"Pale","grid":"edeedeede"},
	"stripe_downleft":{"name":"Bend Sinister","grid":"eedededee"},
	"stripe_downright":{"name":"Bend","grid":"deeedeeed"},
	"stripe_left":{"name":"Pale Dexter","grid":"deedeedee"},
	"stripe_middle":{"name":"Fess","grid":"eeedddeee"},
	"stripe_right":{"name":"Pale Sinister","grid":"eedeedeed"},
	"stripe_top":{"name":"Chief","grid":"dddeeeeee"},
	"thing":{"name":"Thing Charge","signature":"PATTERN_THING"},
	"triangle_bottom":{"name":"Chevron","grid":"eeeededed"},
	"triangle_top":{"name":"Chevron Inverted","grid":"dededeeee"},
	"triangles_bottom":{"name":"Base Indented","grid":"eeededede"},
	"triangles_top":{"name":"Chief Indented","grid":"edededeee"},
	"flow":{"name":"Flow","signature":"PATTERN_FLOW"},
	"guster":{"name":"Guster","signature":"PATTERN_GUSTER"},
}
const ITEM_KEYS = ["thing","skull","creeper","flower","bricks","curly_border","globe","piglin","guster","flow"]
const PATTERN_KEYS = ["border","bricks","circle","creeper","cross","curly_border","thing",
	"diagonal_up_left","diagonal_up_right","diagonal_right","diagonal_left","flower",
	"gradient","gradient_up","half_horizontal_bottom","half_horizontal","half_vertical",
	"half_vertical_right","globe","piglin","rhombus","skull","small_stripes",
	"square_bottom_left","square_bottom_right","square_top_left","square_top_right",
	"straight_cross","stripe_bottom","stripe_center","stripe_downleft","stripe_downright",
	"stripe_left","stripe_middle","stripe_right","stripe_top","triangle_bottom",
	"triangle_top","triangles_bottom","triangles_top","flow","guster"]

static func is_banner(id: int) -> bool:
	return id >= FIRST and id < FIRST+COLORS
static func color_index(id: int) -> int: return id-FIRST if is_banner(id) else -1
static func pattern(name: String) -> Dictionary: return PATTERNS.get(name,{})
static func is_special(name: String) -> bool: return PATTERNS.get(name,{}).has("signature")

# --- layers ------------------------------------------------------------------

# `read_layers`: an ordered list of {pattern, color} pairs.
static func layers(slot: Dictionary) -> Array:
	var data: Variant = slot.get("data",{})
	return clean_layers(data.get("layers",[])) if data is Dictionary else []

static func clean_layers(value: Variant) -> Array:
	var result: Array = []
	if not value is Array: return result
	for entry in value:
		if result.size() >= MAX_STORED_LAYERS: break
		if not entry is Dictionary or not PATTERNS.has(str(entry.get("pattern",""))): continue
		var color: Variant = entry.get("color",-1)
		if not color is int and not color is float: continue
		if not is_finite(float(color)) or int(color) < 0 or int(color) >= COLORS: continue
		result.append({"pattern":str(entry.pattern),"color":int(color)})
	return result

static func set_layers(slot: Dictionary, value: Array) -> void:
	if not slot.get("data") is Dictionary: slot["data"] = {}
	var clean: Array = clean_layers(value)
	if clean.is_empty(): slot.data.erase("layers")
	else: slot.data["layers"] = clean
	if slot.data.is_empty(): slot.erase("data")

# `is_same_layers`: two banners carry the same emblazoning in the same order.
static func same_layers(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if str(a[i].get("pattern","")) != str(b[i].get("pattern","")): return false
		if int(a[i].get("color",-1)) != int(b[i].get("color",-1)): return false
	return true

# `make_pattern_name`: the colour name followed by the pattern's name.
static func pattern_name(color_index_value: int, key: String) -> String:
	var entry: Dictionary = pattern(key)
	if entry.is_empty(): return key
	return "%s %s" % [BANNER_NAMES[clampi(color_index_value,0,COLORS-1)],entry.name]

# The description lists the oldest layers first, followed by an overflow count.
static func describe(slot: Dictionary) -> String:
	var list: Array = layers(slot)
	var title: String = BANNER_NAMES[clampi(color_index(int(slot.id)),0,COLORS-1)]+" banner"
	if list.is_empty(): return title
	var parts: PackedStringArray = []
	for i in mini(list.size(),DESCRIPTION_LAYERS):
		parts.append(pattern_name(int(list[i].get("color",0)),str(list[i].get("pattern",""))))
	if list.size() > DESCRIPTION_LAYERS:
		var extra: int = list.size()-DESCRIPTION_LAYERS
		parts.append("And one additional layer" if extra == 1 else "And %d additional layers" % extra)
	return title+"\n"+"\n".join(parts)

# A placed banner keeps the actual item, just like the reference node's one-slot
# metadata inventory. Legacy stations stored the layer list directly.
static func station(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	var id: int = world.node_at(p)
	if not world.stations.has(key): world.stations[key] = {"kind":"banner","slots":[]}
	var state: Dictionary = world.stations[key]
	state.kind = "banner"
	if not state.get("item") is Dictionary:
		var data: Dictionary = {"layers":clean_layers(state.get("layers",[]))}
		if state.get("custom_name") is String: data.custom_name = state.custom_name
		state.item = Inventory.clean_slot({"id":id,"count":1,"wear":0,"data":data})
	if not is_banner(int(state.item.get("id",0))): state.item = {"id":id,"count":1,"wear":0}
	state.slots = []
	state.erase("layers")
	state["wall"] = bool(state.get("wall",false))
	state["face"] = posmod(int(state.get("face",3)),4)
	state["rotation"] = posmod(int(state.get("rotation",0)),16)
	return state

static func stored_item(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var state: Dictionary = station(world,p)
	var result: Dictionary = Inventory.clean_slot(state.item)
	result.id = world.node_at(p); result.count = 1
	return result

static func rotation_level(yaw: float) -> int:
	return posmod(int(floorf(yaw/(TAU/16.0)+0.5)),16)

static func support(state: Dictionary) -> Vector3i:
	return -NORMALS[int(state.face)] if state.wall else Vector3i.DOWN

static func try_place(game: Node3D, target: Dictionary) -> bool:
	if not is_banner(int(game.inventory.held().id)) or target.is_empty(): return false
	if game.network != null and game.network.client():
		game.network.request_banner_place(target,game.player.rotation.y)
		return true
	place(game,target,game.inventory,game.player.rotation.y)
	return true

static func place(game: Node3D, target: Dictionary, bag: Inventory, yaw: float) -> bool:
	var held: Dictionary = bag.held()
	if not is_banner(int(held.id)) or int(held.count) <= 0 or not target.has("pos") or not target.has("normal"): return false
	var normal: Vector3i = target.normal
	if absi(normal.x)+absi(normal.y)+absi(normal.z) != 1: return false
	var at: Vector3i = target.get("replace",target.pos if Doors.replaceable(game.world.node_at(target.pos)) else target.pos+normal)
	if not game.world.loaded_at(Vector3(at)) or not Doors.replaceable(game.world.node_at(at)): return false
	# The reference attempts a standing banner before trying wall attachment.
	var wall: bool = not Nodes.solid(game.world.node_at(at+Vector3i.DOWN))
	var face: int = NORMALS.find(normal)
	if wall and (face < 0 or not Nodes.solid(game.world.node_at(at-normal))): return false
	var item: Dictionary = Inventory.clean_slot(held); item.count = 1
	var station_key: String = VoxelWorld.station_key(at)
	var previous: Variant = game.world.stations.get(station_key)
	game.world.stations[station_key] = {"kind":"banner","slots":[],"item":item,"wall":wall,"face":maxi(face,0),"rotation":(face+1)*4%16 if wall else rotation_level(yaw)}
	if not game.world.set_node(at,int(item.id)):
		if previous == null: game.world.stations.erase(station_key)
		else: game.world.stations[station_key] = previous
		return false
	if game.gamemode != "creative": bag.consume_selected()
	if bag == game.inventory: game.player.swing = 1
	game.sound("place"); game.api.emit_node_placed(at,int(item.id))
	game.survival.refresh_displays()
	return true

static func boxes(state: Dictionary) -> Array:
	if not state.wall: return [AABB(Vector3(0.2,0,0.2),Vector3(0.6,1,0.6))]
	var normal: Vector3i = NORMALS[int(state.face)]
	var origin := Vector3.ZERO; var size := Vector3.ONE
	if normal.x != 0: size.x = 0.25; origin.x = 0 if normal.x > 0 else 0.75
	else: size.z = 0.25; origin.z = 0 if normal.z > 0 else 0.75
	return [AABB(origin,size)]

static func break_node(game: Node3D, p: Vector3i, id: int) -> bool:
	if not is_banner(id): return false
	var item: Dictionary = stored_item(game.world,p)
	var key: String = str(game.world.get_instance_id())+":"+VoxelWorld.station_key(p)
	removals[key] = true
	var removed: bool = game.world.set_node(p,Nodes.AIR)
	removals.erase(key)
	if not removed: return true
	if game.gamemode != "creative": game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,item.id,1,0,item.get("data",{}))
	else:
		var present: bool = false
		for slot in game.inventory.slots:
			if slot.id == item.id and slot.count > 0 and slot.get("data",{}) == item.get("data",{}): present = true; break
		if not present: game.inventory.add_item(item.id,1,0,item.get("data",{}))
	game._break_particles(p,id); game.sound("break"); game.api.emit_node_broken(p,id)
	game.survival.refresh_displays()
	return true

static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if old_id != id and is_banner(old_id):
		var state_key: String = VoxelWorld.station_key(p)
		var old: Dictionary = world.stations.get(state_key,{})
		var item: Dictionary = Inventory.clean_slot(old.get("item",{"id":old_id,"count":1,"data":{"layers":old.get("layers",[])}}))
		world.stations.erase(state_key)
		if not removals.has(str(world.get_instance_id())+":"+state_key):
			world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,old_id,1,0,item.get("data",{}))
	if is_banner(id): station(world,p)
	if world.circuits.moving:
		var pending: Dictionary = world.get_meta("banner_support_pending",{})
		pending[p] = true; world.set_meta("banner_support_pending",pending)
		return
	for at in [p,p+Vector3i.UP,p+Vector3i.RIGHT,p+Vector3i.LEFT,p+Vector3i.BACK,p+Vector3i.FORWARD]: validate_support(world,at)

static func validate_support(world: VoxelWorld, p: Vector3i) -> void:
	if not is_banner(world.node_at(p)): return
	var anchor: Vector3i = p+support(station(world,p))
	if world.loaded_at(Vector3(anchor)) and world.node_at(anchor) == Nodes.AIR: world.set_node(p,Nodes.AIR)

static func finish_piston(world: VoxelWorld) -> void:
	var pending: Dictionary = world.get_meta("banner_support_pending",{})
	world.set_meta("banner_support_pending",{})
	for p in pending:
		for at in [p,p+Vector3i.UP,p+Vector3i.RIGHT,p+Vector3i.LEFT,p+Vector3i.BACK,p+Vector3i.FORWARD]: validate_support(world,at)

static func column_loaded(world: VoxelWorld, column: Vector2i) -> void:
	if world.network_replica: return
	# A wall banner can load while its support's neighbouring column is absent.
	# Recheck it when that column becomes available.
	for key in world.stations.keys():
		var state: Dictionary = world.stations[key]
		if state.get("kind","") != "banner": continue
		var xyz: PackedStringArray = str(key).split(",")
		if xyz.size() != 3: continue
		var p := Vector3i(int(xyz[0]),int(xyz[1]),int(xyz[2]))
		if not world.loaded_at(Vector3(p)) or not is_banner(world.node_at(p)): continue
		var anchor: Vector3i = p+support(station(world,p))
		if Vector2i(anchor.x >> 4,anchor.z >> 4) == column: validate_support(world,p)

static func texture(slot: Dictionary) -> Texture2D:
	var key: String = str(slot.id)+":"+JSON.stringify(layers(slot))
	if not textures.has(key):
		if textures.size() > 256: textures.clear()
		var img := Image.create(16,16,false,Image.FORMAT_RGBA8)
		draw(img,int(slot.id),color_index(int(slot.id)),layers(slot))
		textures[key] = ImageTexture.create_from_image(img)
	return textures[key]

static func display_model(world: VoxelWorld, p: Vector3i) -> Node3D:
	var state: Dictionary = station(world,p)
	var root := Node3D.new(); root.position = Vector3(p)+Vector3(0.5,0,0.5)
	if state.wall:
		var normal: Vector3i = NORMALS[int(state.face)]
		root.position -= Vector3(normal)*0.44
		root.rotation.y = atan2(float(normal.x),float(normal.z))
	else: root.rotation.y = float(state.rotation)*TAU/16+PI
	var wooden := StandardMaterial3D.new(); wooden.albedo_color = Color("795430")
	var rail := MeshInstance3D.new(); var bar := BoxMesh.new()
	bar.size = Vector3(0.9,0.055,0.055); rail.mesh = bar; rail.material_override = wooden
	rail.position.y = 0.94 if state.wall else 1.85; root.add_child(rail)
	if not state.wall:
		var post := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = Vector3(0.06,1.9,0.06)
		post.mesh = box; post.material_override = wooden; post.position.y = 0.95; root.add_child(post)
	var cloth := MeshInstance3D.new(); var quad := QuadMesh.new(); quad.size = Vector2(1.06,1.6)
	cloth.mesh = quad; cloth.position = Vector3(0,0.24 if state.wall else 1.15,0.04)
	var mat := StandardMaterial3D.new(); mat.albedo_texture = texture(stored_item(world,p))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cloth.material_override = mat; root.add_child(cloth)
	return root

static func rotate(world: VoxelWorld, p: Vector3i, mode: int) -> bool:
	if mode != Screwdriver.ROTATE_FACE: return false
	var state: Dictionary = station(world,p)
	if state.wall: state.face = posmod(int(state.face)+1,4); state.rotation = (int(state.face)+1)*4%16
	else: state.rotation = posmod(int(state.rotation)-1,16)
	world.get_parent().survival.refresh_displays()
	return true

# One dye and one banner produce one new item. The supplied source consumes a
# special pattern item too. A full inventory rejects the entire transaction.
static func loom_apply(bag: Inventory, banner_index: int, dye_index: int, key: String, pattern_index: int = -1) -> bool:
	if not PATTERNS.has(key) or banner_index < 0 or dye_index < 0 or banner_index >= bag.slots.size() or dye_index >= bag.slots.size(): return false
	var banner: Dictionary = bag.slots[banner_index]
	var color: int = dye_color(int(bag.slots[dye_index].id))
	if not is_banner(int(banner.id)) or color < 0 or banner.count <= 0 or bag.slots[dye_index].count <= 0: return false
	if is_special(key) and (pattern_index < 0 or pattern_index >= bag.slots.size() or int(bag.slots[pattern_index].id) != VillageContent.PATTERN_FIRST+ITEM_KEYS.find(key) or int(bag.slots[pattern_index].count) <= 0): return false
	var output: Dictionary = Inventory.clean_slot(banner); output.count = 1
	if not emblazon(output,key,color): return false
	var plan: Array = bag.slots.duplicate(true)
	var consumed: Array = [banner_index,dye_index]
	if is_special(key): consumed.append(pattern_index)
	for index in consumed:
		plan[index].count -= 1
		if plan[index].count <= 0: plan[index] = {"id":0,"count":0,"wear":0}
	var placed: bool = false
	for merge in [true,false]:
		for slot in plan:
			if merge and slot.id == output.id and slot.get("data",{}) == output.get("data",{}) and slot.count < Nodes.max_stack(output.id): slot.count += 1; placed = true; break
			if not merge and slot.id == 0: slot.merge(output,true); placed = true; break
		if placed: break
	if not placed: return false
	bag.slots = plan; bag.changed.emit()
	return true

static func show_loom(game: Node3D, p: Vector3i) -> void:
	game.survival.workstation_pos = p; game.survival.workstation_id = VillageContent.LOOM
	game.state = "workstation"; game.world.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.hud._clear(); game.hud.screen = "workstation"; game.hud._dim()
	var panel: Panel = game.hud._fitted_panel(Vector2(750,560))
	game.hud._label(panel,"LOOM",Vector2(26,18),26,game.hud.ACCENT)
	var banners: Array = []; var dyes: Array = []; var dye_colors: Dictionary = {}
	for i in game.inventory.slots.size():
		var slot: Dictionary = game.inventory.slots[i]
		if is_banner(slot.id): banners.append(i)
		var color: int = dye_color(slot.id)
		if color >= 0 and not dye_colors.has(color): dyes.append(i); dye_colors[color] = true
	game.hud._button(panel,"Back",Rect2(26,504,100,34),func(): game.resume())
	if banners.is_empty() or dyes.is_empty():
		game.hud._label(panel,"Bring a banner and a dye to choose a design.",Vector2(26,85),18)
		return
	var banner_index: int = int(game.survival.get_meta("loom_banner",banners[0]))
	var dye_index: int = int(game.survival.get_meta("loom_dye",dyes[0]))
	if banner_index not in banners: banner_index = banners[0]
	if dye_index not in dyes: dye_index = dyes[0]
	var banner_select := OptionButton.new(); banner_select.position = Vector2(26,66); banner_select.size = Vector2(430,36); panel.add_child(banner_select)
	for i in banners:
		var slot: Dictionary = game.inventory.slots[i]
		banner_select.add_item("%s · %d layers · slot %d" % [slot.get("data",{}).get("custom_name",Nodes.title(slot.id)),layers(slot).size(),i+1],i)
	banner_select.select(banners.find(banner_index))
	banner_select.item_selected.connect(func(i): game.survival.set_meta("loom_banner",banners[i]); show_loom(game,p))
	var dye_select := OptionButton.new(); dye_select.position = Vector2(470,66); dye_select.size = Vector2(254,36); panel.add_child(dye_select)
	for i in dyes: dye_select.add_item(Nodes.title(game.inventory.slots[i].id),i)
	dye_select.select(dyes.find(dye_index))
	dye_select.item_selected.connect(func(i): game.survival.set_meta("loom_dye",dyes[i]); show_loom(game,p))
	var source: Dictionary = game.inventory.slots[banner_index]
	if layers(source).size() >= MAX_LAYERS:
		game.hud._label(panel,"This banner already has all %d layers." % MAX_LAYERS,Vector2(26,125),18)
		return
	var key: String = str(game.survival.get_meta("loom_pattern","border"))
	var color: int = dye_color(game.inventory.slots[dye_index].id)
	var scroll := ScrollContainer.new(); scroll.position = Vector2(26,120); scroll.size = Vector2(476,370); panel.add_child(scroll)
	var grid_view := GridContainer.new(); grid_view.columns = 6; grid_view.add_theme_constant_override("h_separation",4); grid_view.add_theme_constant_override("v_separation",4); scroll.add_child(grid_view)
	var signatures: Dictionary = {}
	for i in game.inventory.slots.size():
		var n: int = int(game.inventory.slots[i].id)-VillageContent.PATTERN_FIRST
		if n >= 0 and n < ITEM_KEYS.size(): signatures[ITEM_KEYS[n]] = i
	for candidate in PATTERN_KEYS:
		var choice: String = candidate
		var button := Button.new(); button.custom_minimum_size = Vector2(70,72); grid_view.add_child(button)
		button.disabled = is_special(choice) and not signatures.has(choice)
		button.tooltip_text = pattern_name(color,choice)+( " · needs its pattern item" if button.disabled else "")
		var icon := ItemIcon.new(); icon.show_slot = false; icon.size = Vector2(68,68)
		var preview: Dictionary = source.duplicate(true); emblazon(preview,choice,color)
		icon.item_id = preview.id; icon.item_data = preview.get("data",{}); button.add_child(icon)
		button.pressed.connect(func(): game.survival.set_meta("loom_pattern",choice); show_loom(game,p))
	var preview: Dictionary = source.duplicate(true); emblazon(preview,key,color)
	var icon := ItemIcon.new(); icon.show_slot = false; icon.position = Vector2(540,125); icon.size = Vector2(150,180); icon.item_id = source.id; icon.item_data = preview.get("data",{}); panel.add_child(icon)
	var description: Label = game.hud._label(panel,pattern_name(color,key),Vector2(516,314),14)
	description.size = Vector2(208,50); description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game.hud._label(panel,"1 banner + 1 dye"+("\n+ 1 pattern item" if is_special(key) else ""),Vector2(516,372),14)
	var apply: Button = game.hud._button(panel,"Apply design",Rect2(516,420,208,42),func():
		if not loom_apply(game.inventory,banner_index,dye_index,key,int(signatures.get(key,-1))): game.toast("Make room for the patterned banner.")
		else: game.sound("place")
		show_loom(game,p))
	apply.disabled = not PATTERNS.has(key) or is_special(key) and not signatures.has(key)

# --- crafting ----------------------------------------------------------------

# Emblazoning a banner appends one layer, which is the source's rule: the banner
# keeps every earlier layer and gains the new one on top.
static func emblazon(slot: Dictionary, key: String, color_index_value: int) -> bool:
	if not is_banner(int(slot.get("id",0))): return false
	if not PATTERNS.has(key) or color_index_value < 0 or color_index_value >= COLORS: return false
	var list: Array = layers(slot).duplicate(true)
	if list.size() >= MAX_LAYERS: return false
	list.append({"pattern":key,"color":color_index_value})
	set_layers(slot,list)
	return true

# Copy a decorated banner onto a plain banner of the same base colour.
static func combine(slot: Dictionary, other: Dictionary) -> bool:
	var theirs: Array = layers(other)
	if not is_banner(int(slot.get("id",0))) or slot.id != other.get("id",0) or not layers(slot).is_empty() or theirs.is_empty() or theirs.size() > MAX_LAYERS: return false
	slot["data"] = craft_data(other)
	return true

static func craft_data(slot: Dictionary) -> Dictionary:
	var data: Dictionary = {"layers":layers(slot)}
	var title: String = str(slot.get("data",{}).get("custom_name",""))
	if not title.is_empty(): data.custom_name = title
	return data

# Patterns depend on the absolute 3x3 dye positions. The banner can occupy any
# empty cell. Copying retains its source stack and consumes only the plain one.
static func special_recipe(cells: Array) -> Dictionary:
	var banners: Array = []; var objects: Array = []; var dye: int = -1
	var mask: String = ""
	for i in cells.size():
		var slot: Dictionary = cells[i]; var id: int = int(slot.id)
		var color: int = dye_color(id)
		mask += "d" if color >= 0 else "e"
		if id == 0: continue
		if is_banner(id): banners.append(i)
		elif color >= 0:
			if dye >= 0 and dye != color: return {}
			dye = color
		else: objects.append(id)
	var output: Dictionary = {}; var keep: Array = []
	if banners.size() == 2 and dye < 0 and objects.is_empty():
		var a: Dictionary = cells[banners[0]]; var b: Dictionary = cells[banners[1]]
		var src: int = banners[0] if not layers(a).is_empty() else banners[1]
		output = Inventory.clean_slot(b if src == banners[0] else a)
		if not combine(output,cells[src]): return {}
		keep.append(src)
	elif banners.size() == 1 and dye >= 0:
		var pattern_key: String = ""
		if objects.size() == 1:
			var dye_count: int = mask.count("d")
			if dye_count != 1: return {}
			for key in PATTERNS:
				if is_special(key) and key_item(key) == objects[0]: pattern_key = key; break
		elif objects.is_empty():
			for key in PATTERNS:
				if str(PATTERNS[key].get("grid","")) == mask: pattern_key = key; break
		output = Inventory.clean_slot(cells[banners[0]])
		output["data"] = craft_data(output)
		if not emblazon(output,pattern_key,dye): return {}
	else: return {}
	var ids: Array = []; var ingredients: Dictionary = {}
	for slot in cells:
		ids.append(int(slot.id))
		if slot.id: ingredients[slot.id] = int(ingredients.get(slot.id,0))+1
	return {"name":"Copy banner" if not keep.is_empty() else "Patterned banner","id":output.id,"count":1,"station":"table","dynamic":true,"width":3,"pattern":ids,"ingredients":ingredients,"output_data":output.get("data",{}),"keep_grid":keep}

# The dye grid for a pattern, or an empty array for a special one.
static func grid(key: String) -> Array:
	var entry: Dictionary = pattern(key)
	if not entry.has("grid"): return []
	var cells: Array = []
	for i in entry.grid.length():
		cells.append(str(entry.grid)[i])
	return cells

# --- dye and pattern selection -----------------------------------------------

# A held dye maps to a banner colour index. Voxey's dyes and banners share the
# source's sixteen-colour order, so the offset is direct.
static func dye_color(id: int) -> int:
	var dye: int = id-VillageContent.DYE_WHITE
	return dye if dye >= 0 and dye < COLORS else -1

# The pattern a held item carries: a pattern item selects its own, otherwise the
# dye applies a plain dye-grid pattern chosen by the player's held pattern item.
const DEFAULT_PATTERN = "stripe_center"

static func pending_pattern(held: int) -> String:
	var index: int = held-VillageContent.PATTERN_FIRST
	if index >= 0 and index < ITEM_KEYS.size(): return ITEM_KEYS[index]
	return DEFAULT_PATTERN

# --- recipes -----------------------------------------------------------------

# The dye-grid patterns are crafted in a table with the banner centred; the
# signature patterns are shapeless paper plus their item, as the source does.
# `key_to_item` maps a signature key to the Voxey item that stands for it.
static func key_item(key: String) -> int:
	var entry: Dictionary = pattern(key)
	if not entry.has("signature"): return 0
	match str(entry.signature):
		"BRICK_BLOCK": return Nodes.BRICKS
		"VINE": return Nodes.VINE
		"OXEYE_DAISY": return 5612
		"HEAD_CREEPER": return Heads.FLOOR+1
		"PATTERN_SKULL": return VillageContent.PATTERN_FIRST+1
		"PATTERN_THING": return VillageContent.PATTERN_FIRST
		"PATTERN_GLOBE": return VillageContent.PATTERN_FIRST+6
		"PATTERN_PIGLIN": return VillageContent.PATTERN_FIRST+7
		"PATTERN_FLOW": return VillageContent.PATTERN_FIRST+9
		"PATTERN_GUSTER": return VillageContent.PATTERN_FIRST+8
	return 0

static func recipes(inv: Inventory) -> void:
	for key in ITEM_KEYS:
		var extra: int = {"thing":Trials.ENCHANTED_APPLE,"skull":Heads.FLOOR+4,"creeper":Heads.FLOOR+1,"flower":5612,"bricks":Nodes.BRICKS,"curly_border":Nodes.VINE}.get(key,0)
		if extra == 0: continue
		var index: int = ITEM_KEYS.find(key)
		inv._recipe(Nodes.title(VillageContent.PATTERN_FIRST+index),VillageContent.PATTERN_FIRST+index,1,[Nodes.PAPER,extra],2)
		inv.recipes.back()["shapeless"] = true

# --- art ---------------------------------------------------------------------

# A banner's icon is its base colour with each layer drawn over it, which is what
# the source's texture builder composes from its pattern textures.
static func draw(img: Image, id: int, slot_color: int, layer_list: Array) -> void:
	var base: Color = Nodes.color(FIRST+clampi(slot_color,0,COLORS-1))
	img.fill_rect(Rect2i(2,1,12,14),base)
	img.fill_rect(Rect2i(2,1,12,2),base.darkened(0.2))
	for layer in layer_list:
		var key: String = str(layer.get("pattern",""))
		var shade: Color = Nodes.color(FIRST+clampi(int(layer.get("color",0)),0,COLORS-1))
		_paint_pattern(img,key,shade)

# The craft recipe specifies ingredients, not the finished silhouette. Draw
# native flag silhouettes separately, including gradients and diagonal fields.
static func _paint_pattern(img: Image, key: String, shade: Color) -> void:
	for y in range(1,15):
		for x in range(2,14):
			var u: float = float(x-2)/11.0; var v: float = float(y-1)/13.0
			var dx: float = u-0.5; var dy: float = v-0.5
			var fill: bool = false; var opacity: float = 1.0
			match key:
				"border": fill = u < 0.15 or u > 0.85 or v < 0.13 or v > 0.87
				"curly_border": fill = u < 0.1 or u > 0.9 or v < 0.08 or v > 0.92 or ((x+y)%4 < 2 and (u < 0.24 or u > 0.76 or v < 0.2 or v > 0.8))
				"bricks": fill = y%4 == 0 or (x+(3 if (y/4)%2 else 0))%6 == 0
				"circle": fill = dx*dx+dy*dy*2.2 < 0.065
				"rhombus": fill = absf(dx)/0.34+absf(dy)/0.25 < 1.0
				"cross": fill = absf(u-v) < 0.12 or absf(u+v-1.0) < 0.12
				"straight_cross": fill = absf(dx) < 0.14 or absf(dy) < 0.11
				"diagonal_up_left": fill = v > u
				"diagonal_up_right": fill = v > 1.0-u
				"diagonal_right": fill = v < u
				"diagonal_left": fill = v < 1.0-u
				"gradient": fill = true; opacity = 1.0-v
				"gradient_up": fill = true; opacity = v
				"half_horizontal": fill = v < 0.5
				"half_horizontal_bottom": fill = v >= 0.5
				"half_vertical": fill = u < 0.5
				"half_vertical_right": fill = u >= 0.5
				"small_stripes": fill = (x-2)%3 == 0
				"square_bottom_left": fill = u < 0.4 and v > 0.6
				"square_bottom_right": fill = u > 0.6 and v > 0.6
				"square_top_left": fill = u < 0.4 and v < 0.4
				"square_top_right": fill = u > 0.6 and v < 0.4
				"stripe_bottom": fill = v > 0.75
				"stripe_center": fill = absf(dx) < 0.14
				"stripe_downleft": fill = absf(u+v-1.0) < 0.13
				"stripe_downright": fill = absf(u-v) < 0.13
				"stripe_left": fill = u < 0.25
				"stripe_middle": fill = absf(dy) < 0.11
				"stripe_right": fill = u > 0.75
				"stripe_top": fill = v < 0.25
				"triangle_bottom": fill = v > 0.42+absf(dx)*1.16
				"triangle_top": fill = v < 0.58-absf(dx)*1.16
				"triangles_bottom": fill = v > 0.73+absf(fposmod(u*3,1.0)-0.5)*0.54
				"triangles_top": fill = v < 0.27-absf(fposmod(u*3,1.0)-0.5)*0.54
				"creeper": fill = v > 0.2 and v < 0.38 and (u > 0.18 and u < 0.42 or u > 0.58 and u < 0.82) or v > 0.45 and v < 0.72 and absf(dx) < 0.14 or v > 0.63 and v < 0.84 and absf(dx) < 0.3
				"skull": fill = dx*dx+dy*dy*1.5 < 0.15 and not (v > 0.37 and v < 0.52 and absf(dx) > 0.08 and absf(dx) < 0.25) and not (v > 0.68 and x%3 == 0)
				"flower": fill = dx*dx+dy*dy*2 < 0.025 or absf(dx) < 0.1 and absf(dy) < 0.34 or absf(dx) < 0.32 and absf(dy) < 0.08
				"globe":
					var r: float = dx*dx+dy*dy*1.9
					fill = r < 0.19 and (r > 0.12 or absf(dx) < 0.05 or absf(dy) < 0.05 or absf(absf(dy)-0.19) < 0.04)
				"piglin": fill = absf(dx) < 0.35 and v > 0.2 and v < 0.73 and not (v < 0.39 and absf(dx) < 0.25 and absf(dx) > 0.08) or absf(dx) < 0.3 and v > 0.8
				"thing": fill = absf(dx) < 0.15 and absf(dy) < 0.37 or absf(dx) < 0.35 and absf(dy+0.2) < 0.07 or absf(u-v) < 0.1 and v > 0.45
				"guster": fill = v > 0.2 and v < 0.8 and absf(sin(v*19.0)*0.22+dx) < 0.1 or v > 0.48 and v < 0.6 and absf(dx) < 0.4
				"flow": fill = absf(dy-sin(u*8.0)*0.2) < 0.08 or absf(dy-sin(u*8.0)*0.2-0.25) < 0.05
			if fill: img.set_pixel(x,y,img.get_pixel(x,y).lerp(shade,opacity))

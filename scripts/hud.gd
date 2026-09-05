class_name VoxeyHUD
extends Control

const INK = Color("16251f")
const PANEL = Color("202e27")
const TEXT = Color("eee9d5")
const MUTED = Color("a8b39b")
const ACCENT = Color("becb82")
var game: Node3D
var layer: Control
var hotbar: Array = []
var screen: String = ""
var toast_text: String = ""
var toast_time: float = 0.0
var flash: float = 0.0
var debug: bool = false
var cursor: Dictionary = {"id":0,"count":0,"wear":0}
var cursor_icon: ItemIcon
var slots_ui: Array = []
var station_ui: Array = []
var station: String = "hand"
var station_data: Dictionary = {}
var recipe_index: int = 0
var preview: Control
var seed_field: LineEdit
var start_button: Button
var furnace_label: Label
var elapsed_refresh: float = 0.0
var grid_ui: Array = []
var output_icon: ItemIcon
var output_button: Button
var recipe_list: VBoxContainer
var recipe_search: LineEdit
var requirements_label: Label
var fill_button: Button
var result_label: Label
var catalog_mode: bool = false
var world_detail: Control
var console_input: LineEdit
var console_output: RichTextLabel
var armor_ui: Array = []
var armor_label: Label
var split_mode: bool = false
var shift_mode: bool = false
var split_toggle: CheckButton
var shift_toggle: CheckButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_value := Theme.new()
	theme_value.default_font_size = 16
	theme_value.set_color("font_color","Label",TEXT)
	theme_value.set_color("font_color","Button",TEXT)
	theme_value.set_color("font_hover_color","Button",Color.WHITE)
	theme_value.set_color("font_disabled_color","Button",Color("6d7b6c"))
	for type_name in ["Button","LineEdit"]:
		theme_value.set_stylebox("normal",type_name,_style(Color("304332"),Color("546443"),1,6))
		theme_value.set_stylebox("hover",type_name,_style(Color("435639"),ACCENT,1,6))
		theme_value.set_stylebox("pressed",type_name,_style(Color("26382b"),ACCENT,2,6))
		theme_value.set_stylebox("focus",type_name,_style(Color(0,0,0,0),ACCENT,2,6))
		theme_value.set_stylebox("disabled",type_name,_style(Color("28332b"),Color("3b4636"),1,6))
	theme = theme_value
	layer = Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	game.inventory.changed.connect(refresh_slots)
	show_title()

func _style(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 4) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = bg
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(radius)
	result.content_margin_left = 16
	result.content_margin_right = 16
	result.content_margin_top = 10
	result.content_margin_bottom = 10
	return result

func _clear() -> void:
	for child in layer.get_children():
		layer.remove_child(child)
		child.queue_free()
	hotbar.clear()
	slots_ui.clear()
	station_ui.clear()
	grid_ui.clear()
	armor_ui.clear()
	armor_label=null
	output_icon=null; output_button=null; recipe_list=null; recipe_search=null; requirements_label=null; fill_button=null; result_label=null
	preview = null
	cursor_icon = null
	start_button = null
	furnace_label = null

func _label(parent: Node, text_value: String, pos: Vector2, font_size: int = 16, color: Color = TEXT, width: float = 0) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	if width > 0:
		label.size.x = width
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text_value: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _panel(parent: Node, rect: Rect2, color: Color = PANEL) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel",_style(color,Color("4b5944"),1,8))
	parent.add_child(panel)
	return panel

func _center(size_value: Vector2) -> Vector2:
	return (size-size_value)*0.5

func show_title() -> void:
	_clear()
	screen = "title"
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.055,0.105,0.085,0.96),Color(0.055,0.105,0.085,0.8),Color(0.055,0.105,0.085,0.04)])
	gradient.offsets = PackedFloat32Array([0,0.32,1])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2.ZERO
	tex.fill_to = Vector2.RIGHT
	shade.texture = tex
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	var origin := Vector2(70,maxf(60,size.y*0.16))
	var title_size: float = 100.0 if size.x > 700.0 else 64.0
	_label(layer,"V  /  VOXEY",Vector2(38,24),18,ACCENT)
	_label(layer,"A LITTLE WILD. ENTIRELY YOURS.",origin,13,ACCENT)
	var title := _label(layer,"VOXEY",origin+Vector2(-5,21),int(title_size),TEXT)
	title.add_theme_color_override("font_shadow_color",Color("0c1c15"))
	title.add_theme_constant_override("shadow_offset_y",6)
	_label(layer,"One node. Endless possibilities.",origin+Vector2(0,title_size*0.5+92),23,TEXT)
	_label(layer,"Gather, craft, and find your own way.\nA living voxel wilderness awaits.",origin+Vector2(0,title_size*0.5+137),16,MUTED)
	start_button = _button(layer,"Play / choose a world  →",Rect2(origin+Vector2(0,title_size*0.5+217),Vector2(minf(340,size.x-90),56)),show_worlds)
	start_button.add_theme_font_size_override("font_size",19)
	_button(layer,"Create a new world",Rect2(origin+Vector2(0,title_size*0.5+285),Vector2(minf(340,size.x-90),44)),show_new_world)
	_label(layer,"SURVIVAL & CREATIVE  ·  YOUR OWN WORLDS",origin+Vector2(0,title_size*0.5+351),11,MUTED)
	_label(layer,"VOXEY    ·    SINGLE PLAYER    ·    INFINITE HORIZONS",Vector2(38,size.y-40),11,MUTED)
	var tag := _panel(layer,Rect2(Vector2(size.x-290,size.y-96),Vector2(254,58)),Color(0.09,0.16,0.13,0.75))
	_label(tag,"THE OVERWORLD",Vector2(16,10),10,ACCENT)
	_label(tag,"Oakwood meadow  /  Day 1",Vector2(16,27),14,TEXT)

func show_game() -> void:
	_clear()
	screen = "game"
	var scale_value: float = _hud_scale()
	var slot_w: float = 53.0*scale_value
	var gap: float = 4.0*scale_value
	var start: Vector2 = Vector2(size.x*0.5-9*(slot_w+gap)*0.5+gap*0.5,size.y-(77.0*scale_value if not game.touch else 40.0+62.0*scale_value))
	for i in 9:
		var icon := ItemIcon.new()
		icon.position = start+Vector2(i*(slot_w+gap),0)
		icon.size = Vector2(slot_w,55.0*scale_value)
		icon.number = str(i+1)
		layer.add_child(icon)
		hotbar.append(icon)
		# Tappable hotbar: every slot selects itself (desktop parity via 1-9 keys).
		var tap := Button.new()
		tap.flat = true
		tap.focus_mode = Control.FOCUS_NONE
		tap.position = icon.position
		tap.size = icon.size
		tap.tooltip_text = "Select slot %d" % [i+1]
		tap.pressed.connect(func():
			game.inventory.selected = i
			refresh_slots())
		layer.add_child(tap)
	refresh_slots()

# Uniform shrink factor for phones (portrait or small landscape); 1.0 on desktop.
func _hud_scale() -> float:
	var shorter: float = minf(size.x,size.y)
	if shorter >= 600.0: return 1.0
	return clampf(shorter/600.0,0.62,1.0)

# Panels keep their design size on desktop; on phones they fill the screen
# minus a small margin so nothing falls off-screen.
func _panel_rect(design: Vector2) -> Rect2:
	if size.x >= design.x+40 and size.y >= design.y+40: return Rect2(_center(design),design)
	var fitted: Vector2 = (size-Vector2(16,16)).min(design)
	return Rect2(_center(fitted),fitted)

func show_pause() -> void:
	_clear()
	screen = "pause"
	_dim()
	var panel := _panel(layer,_panel_rect(Vector2(480,530)))
	_label(panel,"TAKE A BREATHER",Vector2(34,26),12,ACCENT)
	_label(panel,"A moment of quiet.",Vector2(34,49),30)
	_label(panel,"Your world is paused.",Vector2(34,93),15,MUTED)
	_button(panel,"Back to the wilderness",Rect2(34,137,412,48),game.resume)
	_label(panel,"View distance",Vector2(34,212),15)
	var distance := HSlider.new()
	distance.position = Vector2(218,214)
	distance.size = Vector2(222,20)
	distance.min_value = 2
	distance.max_value = 6
	distance.step = 1
	distance.value = game.world.radius
	distance.value_changed.connect(func(value: float): game.world.radius=int(value); game.world.desired=Vector2i(999999,999999))
	panel.add_child(distance)
	_label(panel,"Mouse sensitivity",Vector2(34,258),15)
	var sensitivity := HSlider.new()
	sensitivity.position = Vector2(218,260)
	sensitivity.size = Vector2(222,20)
	sensitivity.min_value = 0.0006
	sensitivity.max_value = 0.005
	sensitivity.step = 0.0001
	sensitivity.value = game.player.sensitivity
	sensitivity.value_changed.connect(func(value: float): game.player.sensitivity=value)
	panel.add_child(sensitivity)
	var audio_button := CheckButton.new()
	audio_button.text = "Sound effects"
	audio_button.position = Vector2(28,302)
	audio_button.button_pressed = game.audio_enabled
	audio_button.toggled.connect(func(value: bool): game.audio_enabled=value)
	panel.add_child(audio_button)
	_button(panel,"Field guide",Rect2(34,358,198,43),show_guide)
	_button(panel,"Fullscreen  ·  F11",Rect2(246,358,200,43),game.toggle_fullscreen)
	_button(panel,"Save & return to title",Rect2(34,420,412,46),game.return_to_title)
	_label(panel,"World edits and inventory autosave every 45 seconds.",Vector2(34,483),12,MUTED)

func show_guide() -> void:
	_clear()
	screen = "guide"
	_dim()
	var panel := _panel(layer,_panel_rect(Vector2(790,600)))
	_label(panel,"THE VOXEY FIELD GUIDE",Vector2(32,25),12,ACCENT)
	_label(panel,"Make yourself at home.",Vector2(32,47),30)
	var text_value: String = "01   START SMALL\nHold left click on an oak log. Open your inventory with E, turn logs into planks, then craft a table. Place it and right click to unlock tools.\n\n02   DIG A LITTLE DEEPER\nA wooden pickaxe mines stone and coal. Stone picks unlock iron. Smelt iron ore in a furnace; an iron pickaxe can harvest diamonds below Y 12.\n\n03   BUILD A LIFE\nTill grass with a hoe and plant seeds. Crops ripen in 90 seconds. Sheep drop meat and wool; cook meat and make a bed. Right click a bed to set your spawn and sleep through the night. Saplings grow into trees.\n\n04   STAY ALIVE\nEat with right click. Keep hunger high to regenerate health. Watch your breath underwater and your footing on cliffs. The dark brings zombies, skeletons, spiders, and creepers. Build a shelter, place torches, and keep a sword close.\n\n05   ARMOR & THE WILD\nCraft leather, iron, golden, or diamond armor at a table and right click to wear it; each piece wears down as it protects you. Cows drop leather, chickens and pigs give meat, bones become bone meal for instant crops, string weaves wool, and gunpowder plus sand makes TNT. Sand and gravel fall when unsupported. Two chests placed together join into one large chest."
	_label(panel,text_value,Vector2(32,100),14,TEXT,720)
	_label(panel,"WASD  Move    SPACE  Jump / swim    SHIFT  Sprint    CTRL  Sneak    /  Console\nLMB  Mine / attack    RMB  Place / use / eat / wear    E  Inventory    Q  Drop\n1–9 / WHEEL  Hotbar    F3  Debug    F5  Save    ESC  Pause",Vector2(32,470),13,MUTED)
	_button(panel,"Back",Rect2(610,530,146,42),show_pause)

func show_inventory(kind: String = "hand", data: Dictionary = {}) -> void:
	_clear()
	screen = "inventory"
	station = kind
	catalog_mode = game.gamemode=="creative" and kind in ["hand","table"]
	station_data = data
	var tall: bool = kind == "chest" and data.get("slots",[]).size() > 27
	var extra: int = 84 if tall else 0
	_dim()
	var panel := _panel(layer,_panel_rect(Vector2(1100,616+extra)))
	_label(panel,"YOUR SATCHEL",Vector2(28,22),12,ACCENT)
	_label(panel,{"hand":"A little ingenuity.","table":"The crafting table.","furnace":"Into the fire.","chest":"One large chest." if tall else "Room for everything."}[kind],Vector2(28,44),28)
	_button(panel,"×",Rect2(1029,22,43,40),game.resume)
	if game.gamemode=="creative":
		_button(panel,"Recipes",Rect2(24,94,136,28),func(): catalog_mode=false; _populate_recipes())
		_button(panel,"All items",Rect2(168,94,140,28),func(): catalog_mode=true; _populate_recipes())
	else: _label(panel,"RECIPE GUIDE",Vector2(28,105),12,MUTED)
	recipe_search = LineEdit.new()
	recipe_search.position = Vector2(24,129)
	recipe_search.size = Vector2(284,34)
	recipe_search.placeholder_text = "Search recipes…"
	recipe_search.text_changed.connect(func(_value: String): _populate_recipes())
	panel.add_child(recipe_search)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24,175)
	scroll.size = Vector2(284,367)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	recipe_list = VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list.add_theme_constant_override("separation",5)
	scroll.add_child(recipe_list)
	_populate_recipes()
	_label(panel,"Look up a pattern, or arrange your own.\nFill grid places the ingredients for you.",Vector2(28,556),12,MUTED)
	preview = Control.new()
	preview.position = Vector2(340,102)
	preview.size = Vector2(668,194+extra)
	panel.add_child(preview)
	if kind in ["hand","table"]: _recipe_preview()
	elif kind == "furnace": _furnace_preview()
	else: _chest_preview()
	# Worn armor lives in its own column. Each slot only accepts its own piece.
	_label(panel,"ARMOR",Vector2(1030,80),10,MUTED)
	for i in 4:
		var button := _button(panel,"",Rect2(Vector2(1030,96+i*49),Vector2(46,46)),_slot_click.bind(i,false,false,false,true))
		button.gui_input.connect(_armor_input.bind(i))
		var icon := ItemIcon.new()
		icon.size = Vector2(46,46)
		button.add_child(icon)
		armor_ui.append(icon)
	armor_label = _label(panel,"",Vector2(1030,292),11,MUTED)
	_label(panel,"INVENTORY",Vector2(342,316+extra),12,MUTED)
	_label(panel,"Click to move  ·  Right click to split / place one",Vector2(616,316+extra),12,MUTED)
	for i in 36:
		var x: int = i%9
		var y: int = i/9
		var pos := Vector2(342+x*73,344+extra+y*57+(10 if y>0 else 0))
		var button := _button(panel,"",Rect2(pos,Vector2(65,51)),_slot_click.bind(i,false,false))
		button.gui_input.connect(_slot_input.bind(i,false))
		var icon := ItemIcon.new()
		icon.size = Vector2(65,51)
		icon.number = str(i+1) if i<9 else ""
		button.add_child(icon)
		slots_ui.append(icon)
	_label(panel,"HOTBAR",Vector2(342,589+extra),10,MUTED)
	_label(panel,"E / ESC  Close",Vector2(900,589+extra),10,MUTED)
	cursor_icon = ItemIcon.new()
	cursor_icon.size = Vector2(48,48)
	cursor_icon.show_slot = false
	layer.add_child(cursor_icon)
	# Touch has no Shift/right-click: on-screen toggles provide both semantics.
	if game.touch:
		var toggle_panel := _panel(layer,Rect2(Vector2(8,size.y-124),Vector2(198,116)),Color(0.06,0.11,0.08,0.85))
		split_toggle = CheckButton.new()
		split_toggle.text = "Split mode"
		split_toggle.position = Vector2(10,8)
		split_toggle.size = Vector2(178,40)
		split_toggle.toggled.connect(func(value: bool): split_mode=value)
		toggle_panel.add_child(split_toggle)
		shift_toggle = CheckButton.new()
		shift_toggle.text = "Batch mode"
		shift_toggle.position = Vector2(10,54)
		shift_toggle.size = Vector2(178,40)
		shift_toggle.toggled.connect(func(value: bool): shift_mode=value)
		toggle_panel.add_child(shift_toggle)
	refresh_slots()

func _select_recipe(index: int) -> void:
	recipe_index = index
	if station in ["hand","table"]: _recipe_preview()
	else: game.toast("Open your inventory or a crafting table to craft.")

func _populate_recipes() -> void:
	if not is_instance_valid(recipe_list): return
	for child in recipe_list.get_children(): recipe_list.remove_child(child); child.queue_free()
	var query: String = recipe_search.text.to_lower() if is_instance_valid(recipe_search) else ""
	if catalog_mode:
		for id in Nodes.all_ids():
			if not query.is_empty() and not query in Nodes.title(id).to_lower(): continue
			var button := Button.new()
			button.text="      "+Nodes.title(id)
			button.alignment=HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size=Vector2(261,37)
			button.add_theme_font_size_override("font_size",14)
			button.pressed.connect(_creative_take.bind(id))
			recipe_list.add_child(button)
			var icon := ItemIcon.new()
			icon.position=Vector2(8,2); icon.size=Vector2(30,32); icon.item_id=id; icon.show_slot=false
			button.add_child(icon)
		return
	for i in game.inventory.recipes.size():
		var recipe: Dictionary = game.inventory.recipes[i]
		if not query.is_empty() and not query in String(recipe.name).to_lower(): continue
		var can: bool = game.inventory.can_craft(recipe,station)
		var button := Button.new()
		button.text = ("•  " if can else "   ")+recipe.name
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(261,37)
		button.add_theme_font_size_override("font_size",14)
		button.add_theme_color_override("font_color",ACCENT if can else MUTED)
		button.pressed.connect(_select_recipe.bind(i))
		recipe_list.add_child(button)

func _recipe_preview() -> void:
	for child in preview.get_children(): preview.remove_child(child); child.queue_free()
	grid_ui.clear()
	var recipe: Dictionary = game.inventory.recipes[recipe_index]
	var width: int = 3 if station == "table" else 2
	_label(preview,"CRAFTING  ·  %d × %d" % [width,width],Vector2.ZERO,12,ACCENT)
	for y in width:
		for x in width:
			var index: int = x+y*3
			var pos := Vector2(x*42,35+y*42)
			var button := _button(preview,"",Rect2(pos,Vector2(38,38)),_slot_click.bind(index,false,false,true))
			button.gui_input.connect(_grid_input.bind(index))
			var icon := ItemIcon.new()
			icon.size = Vector2(38,38)
			button.add_child(icon)
			grid_ui.append({"icon":icon,"index":index})
	_label(preview,"→",Vector2(140,70),32,ACCENT)
	output_button = _button(preview,"",Rect2(189,53,70,70),_take_output)
	output_icon = ItemIcon.new()
	output_icon.size = Vector2(70,70)
	output_button.add_child(output_icon)
	result_label = _label(preview,"Arrange a recipe",Vector2(0,168),12,MUTED,270)
	_label(preview,recipe.name,Vector2(294,-2),19,TEXT)
	requirements_label = _label(preview,"",Vector2(294,31),13,MUTED,235)
	# The guide pattern is a reference; the slots on the left are the real grid.
	for y in 3:
		for x in 3:
			var icon := ItemIcon.new()
			icon.size = Vector2(23,23)
			icon.position = Vector2(567+x*26,35+y*26)
			var index: int = y*int(recipe.width)+x
			icon.item_id = recipe.pattern[index] if x<recipe.width and index<recipe.pattern.size() else 0
			preview.add_child(icon)
	_label(preview,"PATTERN",Vector2(571,119),10,MUTED)
	fill_button = _button(preview,"Fill grid",Rect2(294,117,176,37),_fill_grid)
	_label(preview,"Requires a crafting table" if recipe.station=="table" and station!="table" else "Shift + fill: batch  ·  Click output to craft",Vector2(294,166),11,MUTED)
	_refresh_crafting()

func _grid_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_slot_click(index,false,true,true)

func _refresh_crafting() -> void:
	for entry in grid_ui: _update_icon(entry.icon,game.inventory.grid[entry.index],false)
	if not is_instance_valid(output_icon): return
	var match_index: int = game.inventory.matching_recipe(station)
	output_button.disabled = match_index<0
	if match_index>=0:
		var matched: Dictionary = game.inventory.recipes[match_index]
		output_icon.item_id = matched.id
		output_icon.count = matched.count
		result_label.text = matched.name+"  ·  Click output to take"
	else:
		output_icon.item_id=0; output_icon.count=0
		result_label.text="Arrange a recipe  ·  Shift output: craft all"
	var recipe: Dictionary = game.inventory.recipes[recipe_index]
	var description: String = ""
	var can_fill: bool = recipe.station!="table" or station=="table"
	for id in recipe.ingredients:
		var owned: int = game.inventory.count_item(id)
		for slot in game.inventory.grid:
			if slot.id==id: owned+=slot.count
		if owned<recipe.ingredients[id]: can_fill=false
		description += "%s  %d / %d\n" % [Nodes.title(id),owned,recipe.ingredients[id]]
	requirements_label.text=description
	fill_button.disabled=not can_fill

func _fill_grid() -> void:
	if game.inventory.fill_grid(recipe_index,station,Input.is_physical_key_pressed(KEY_SHIFT) or shift_mode):
		game.sound("click")
	else: game.toast("Make room in your inventory or gather the missing ingredients.")
	refresh_slots()

func _take_output() -> void:
	var match_index: int = game.inventory.matching_recipe(station)
	if match_index<0: return
	var recipe: Dictionary = game.inventory.recipes[match_index]
	var crafted: bool = false
	if Input.is_physical_key_pressed(KEY_SHIFT) or shift_mode:
		for i in 64:
			if not game.inventory.craft_grid_to_inventory(station): break
			crafted=true
	elif cursor.id==0 or (cursor.id==recipe.id and cursor.wear==0 and cursor.count+recipe.count<=Nodes.max_stack(recipe.id)):
		var output: Dictionary = game.inventory.take_grid_result(station)
		if cursor.id==0: cursor=output
		else: cursor.count+=output.count
		crafted=true
	if crafted:
		game.sound("craft")
		game.progress("craft")
	refresh_slots()

func _furnace_preview() -> void:
	_label(preview,"SMELTING",Vector2.ZERO,12,ACCENT)
	var labels: Array = ["INPUT","FUEL","OUTPUT"]
	for i in 3:
		var x: int = i*128
		_label(preview,labels[i],Vector2(x,31),11,MUTED)
		_station_slot(i,Vector2(x,55),Vector2(64,64))
		if i<2: _label(preview,"+" if i==0 else "→",Vector2(x+84,70),27,ACCENT)
	furnace_label = _label(preview,"Add ore or food, then coal or wood.",Vector2(0,140),14,MUTED)
	_label(preview,"RECIPES\nIron / gold / copper ore → ingots\nSand → glass · Raw meat → cooked meat\nCobblestone → stone · Log → charcoal",Vector2(400,32),13,MUTED)

func _chest_preview() -> void:
	var rows: int = station_data.slots.size()/9
	_label(preview,"LARGE CHEST  ·  TWO CHESTS JOINED" if rows > 3 else "CHEST STORAGE",Vector2.ZERO,12,ACCENT)
	var spacing: int = 51 if rows <= 3 else 44
	for i in station_data.slots.size():
		_station_slot(i,Vector2((i%9)*73,27+(i/9)*spacing),Vector2(65,47 if rows <= 3 else 40))

func _station_slot(index: int, pos: Vector2, size_value: Vector2) -> void:
	var button := _button(preview,"",Rect2(pos,size_value),_slot_click.bind(index,true,false))
	button.gui_input.connect(_slot_input.bind(index,true))
	var icon := ItemIcon.new()
	icon.size = size_value
	button.add_child(icon)
	station_ui.append(icon)

func _slot_input(event: InputEvent, index: int, is_station: bool) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_slot_click(index,is_station,true)

func _armor_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_slot_click(index,false,true,false,true)

func _slot_click(index: int, is_station: bool, right: bool, is_grid: bool = false, is_armor: bool = false) -> void:
	if split_mode: right = true
	var source: Array = game.player.armor_slots if is_armor else (game.inventory.grid if is_grid else (station_data.slots if is_station else game.inventory.slots))
	var slot: Dictionary = source[index]
	if is_armor and cursor.id != 0 and Nodes.armor_piece(cursor.id) != index: return
	if is_station and station == "furnace" and cursor.id != 0:
		if index == 2: return
		if index == 1 and cursor.id not in [Nodes.COAL,Nodes.LOG,Nodes.PLANKS,Nodes.STICK]: return
		if index == 0 and cursor.id not in [Nodes.IRON_ORE,Nodes.GOLD_ORE,Nodes.COPPER_ORE,Nodes.SAND,Nodes.COBBLE,Nodes.RAW_MEAT,Nodes.LOG]: return
	if (Input.is_physical_key_pressed(KEY_SHIFT) or shift_mode) and cursor.id == 0 and slot.id != 0:
		if is_station or is_grid or is_armor:
			slot.count = game.inventory.add_item(slot.id,slot.count,slot.wear)
			if slot.count == 0: slot.id = 0; slot.wear = 0
		elif Nodes.is_armor(slot.id) and game.player.armor_slots[Nodes.armor_piece(slot.id)].id == 0:
			game.player.equip_armor(slot)
		elif station == "chest":
			for destination in station_data.slots:
				if destination.id == 0 or (destination.id == slot.id and destination.wear == slot.wear):
					var moved: int = mini(slot.count,Nodes.max_stack(slot.id)-int(destination.count))
					destination.id = slot.id; destination.wear = slot.wear; destination.count += moved; slot.count -= moved
					if slot.count == 0: slot.id=0; slot.wear=0; break
		else:
			var start: int = 9 if index<9 else 0
			var end: int = 36 if index<9 else 9
			for j in range(start,end):
				if game.inventory.slots[j].id == 0:
					game.inventory.slots[j] = slot.duplicate()
					slot.id=0; slot.count=0; slot.wear=0
					break
	elif cursor.id == 0:
		if slot.id == 0: return
		var taken: int = ceili(slot.count/2.0) if right else int(slot.count)
		cursor = {"id":slot.id,"count":taken,"wear":slot.wear}
		slot.count -= taken
		if slot.count == 0: slot.id=0; slot.wear=0
	elif slot.id == 0 or (slot.id == cursor.id and slot.wear == cursor.wear):
		var moved: int = mini(1 if right else int(cursor.count),Nodes.max_stack(cursor.id)-int(slot.count))
		slot.id=cursor.id; slot.wear=cursor.wear; slot.count += moved; cursor.count -= moved
		if cursor.count == 0: cursor={"id":0,"count":0,"wear":0}
	elif not right:
		var temp: Dictionary = slot.duplicate()
		slot.id=cursor.id; slot.count=cursor.count; slot.wear=cursor.wear
		cursor=temp
	game.sound("equip" if is_armor else "click")
	game.inventory.changed.emit()

func return_cursor() -> void:
	for overflow in game.inventory.grid_to_inventory():
		game.spawn_drop(game.player.position+Vector3.UP,overflow.id,overflow.count,overflow.wear)
	if cursor.id != 0:
		var rest: int = game.inventory.add_item(cursor.id,cursor.count,cursor.wear)
		if rest>0: game.spawn_drop(game.player.position+Vector3.UP,cursor.id,rest,cursor.wear)
	cursor={"id":0,"count":0,"wear":0}

func refresh_slots() -> void:
	for i in hotbar.size(): _update_icon(hotbar[i],game.inventory.slots[i],i==game.inventory.selected)
	for i in slots_ui.size(): _update_icon(slots_ui[i],game.inventory.slots[i],i==game.inventory.selected)
	for i in station_ui.size(): _update_icon(station_ui[i],station_data.slots[i],false)
	for i in armor_ui.size():
		_update_icon(armor_ui[i],game.player.armor_slots[i],false)
		if game.player.armor_slots[i].id == 0: armor_ui[i].get_parent().tooltip_text = Nodes.ARMOR_PIECES[i].capitalize()+" slot"
	if is_instance_valid(armor_label): armor_label.text = "%d / 20 defence\n%d%% protection" % [game.player.armor_points(),game.player.armor_points()*4]
	if is_instance_valid(cursor_icon): _update_icon(cursor_icon,cursor,false)
	if screen=="inventory" and station in ["hand","table"]: _refresh_crafting()

func _update_icon(icon: ItemIcon, slot: Dictionary, selected_value: bool) -> void:
	icon.item_id=slot.id; icon.count=slot.count; icon.wear=slot.wear; icon.selected=selected_value
	if icon.get_parent() is Button: icon.get_parent().tooltip_text=Nodes.title(slot.id) if slot.id else "Empty slot"

func show_death() -> void:
	_clear()
	screen="dead"
	_dim()
	var panel := _panel(layer,_panel_rect(Vector2(500,300)))
	_label(panel,"THE WILDERNESS REMEMBERS",Vector2(32,26),12,ACCENT)
	_label(panel,"A new beginning.",Vector2(32,53),32)
	_label(panel,"Your belongings remain where you fell.\nReturn to collect them before they fade.",Vector2(32,113),16,MUTED)
	_button(panel,"Return to your spawn",Rect2(32,205,436,52),game.respawn)

func _dim() -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.025,0.055,0.04,0.76)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)

func toast(message: String) -> void:
	toast_text = message
	toast_time = 4.0

func _process(delta: float) -> void:
	toast_time = maxf(0,toast_time-delta)
	flash = maxf(0,flash-delta)
	if screen == "title" and is_instance_valid(start_button):
		start_button.disabled = false
	if is_instance_valid(cursor_icon): cursor_icon.position=get_local_mouse_position()-Vector2(24,24)
	elapsed_refresh += delta
	if elapsed_refresh > 0.25:
		elapsed_refresh=0
		if screen=="inventory":
			refresh_slots()
			if is_instance_valid(furnace_label): furnace_label.text="Smelting  %d%%  ·  Fuel remaining: %ds" % [int(station_data.progress/8.0*100),int(station_data.burn)] if station_data.burn>0 else "Add ore or food, then coal or wood."
	queue_redraw()

func _draw() -> void:
	if game == null: return
	var font: Font = ThemeDB.fallback_font
	if screen == "game":
		var player: VoxeyPlayer = game.player
		var center: Vector2 = size*0.5
		if player.underwater: draw_rect(Rect2(Vector2.ZERO,size),Color(0.12,0.4,0.62,0.28))
		draw_line(center-Vector2(6,0),center+Vector2(6,0),Color(0.94,0.95,0.85,0.85),2)
		draw_line(center-Vector2(0,6),center+Vector2(0,6),Color(0.94,0.95,0.85,0.85),2)
		draw_style_box(_style(Color(0.08,0.14,0.10,0.76),Color(0.5,0.6,0.4,0.2),1),Rect2(24,24,253,65))
		draw_string(font,Vector2(40,48),"V /  "+game.world.generator.biome(int(player.position.x),int(player.position.z)),HORIZONTAL_ALIGNMENT_LEFT,-1,16,TEXT)
		draw_string(font,Vector2(40,72),"%d   /   %d   /   %d" % [player.position.x,player.position.y,player.position.z],HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
		var time_label: String = "DAY %d  ·  %s" % [game.day_number(),game.time_name()]
		draw_style_box(_style(Color(0.08,0.14,0.10,0.76)),Rect2(size.x-217,24,193,45))
		draw_circle(Vector2(size.x-193,46),7,Color("e8cc80") if game.daylight>0.4 else Color("bdcede"))
		draw_string(font,Vector2(size.x-175,51),time_label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,TEXT)
		if not player.target.is_empty():
			var node_name: String = Nodes.title(player.target.id)
			var width: float = font.get_string_size(node_name,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+36
			draw_style_box(_style(Color(0.08,0.14,0.10,0.8)),Rect2(center.x-width/2,30,width,35))
			draw_string(font,Vector2(center.x-width/2+18,53),node_name,HORIZONTAL_ALIGNMENT_LEFT,-1,15,TEXT)
			if not Nodes.harvestable(player.target.id,game.inventory.held().id):
				draw_string(font,Vector2(center.x-100,84),"A better pickaxe is needed",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e0b07a"))
			if player.mining>0:
				draw_rect(Rect2(center+Vector2(-24,20),Vector2(48,3)),Color(0,0,0,0.4))
				draw_rect(Rect2(center+Vector2(-24,20),Vector2(48*player.mining,3)),ACCENT)
		# Status bar shrinks on phones so the touch buttons stay clear.
		var bar_scale: float = _hud_scale()
		var bar_w: float = 536.0*bar_scale
		var bar_h: float = 107.0*bar_scale
		var bar_y: float = size.y-bar_h-(62.0 if game.touch else 0.0)
		draw_style_box(_style(Color(0.07,0.13,0.09,0.84),Color(0.44,0.54,0.34,0.5),1),Rect2(center.x-bar_w*0.5,bar_y,bar_w,bar_h))
		var left: float = center.x-255.0*bar_scale
		var row_y: float = bar_y+16.0*bar_scale
		for i in (10 if game.gamemode=="survival" else 0):
			_heart(Vector2(left+8+i*20*bar_scale,row_y),i<float(player.health)/2.0)
			_food(Vector2(center.x+63.0*bar_scale+i*19*bar_scale,row_y),i<float(player.hunger)/2.0)
		if game.gamemode=="creative": draw_string(font,Vector2(center.x-244.0*bar_scale,bar_y+21.0*bar_scale),"CREATIVE  ·  "+("FLYING  /  ▲ ✈" if player.flying else "TAP ✈ TO FLY")+"  ·  / CONSOLE",HORIZONTAL_ALIGNMENT_LEFT,-1,11,ACCENT)
		draw_rect(Rect2(center.x-254.0*bar_scale,bar_y+31.0*bar_scale,508.0*bar_scale,3),Color("263c2b"))
		draw_rect(Rect2(center.x-254.0*bar_scale,bar_y+31.0*bar_scale,508.0*bar_scale*clampf(game.experience/30.0,0,1),3),Color("a6be69"))
		var selected_name: String = Nodes.title(game.inventory.held().id) if game.inventory.held().id else "Empty hand"
		var text_width: float = font.get_string_size(selected_name,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_style_box(_style(Color(0.07,0.13,0.09,0.8)),Rect2(center.x-text_width/2-14,bar_y-32,text_width+28,32))
		draw_string(font,Vector2(center.x-text_width/2,bar_y-9),selected_name,HORIZONTAL_ALIGNMENT_LEFT,-1,16,TEXT)
		var defence: int = player.armor_points()
		if defence>0 and game.gamemode=="survival":
			for i in 10: _shield(Vector2(left+8+i*20*bar_scale,row_y-20.0*bar_scale),(i+1)*2<=defence,i*2+1==defence)
		if player.breath<10:
			for i in 10: draw_circle(Vector2(center.x+64.0*bar_scale+i*18*bar_scale,row_y-18.0*bar_scale),4,Color("b5dbe6") if i<player.breath else Color("3c616b"))
		if game.journal_step<4 and game.gamemode=="survival":
			var mine_hint: String = "Hold the ⛏ button to gather an oak log." if game.touch else "Hold LMB to gather an oak log."
			var craft_hint: String = "Tap the bag button. Turn your logs into planks." if game.touch else "Press E. Turn your logs into planks."
			var place_hint: String = "Craft a table, then place it with the ✋ button." if game.touch else "Craft a table, then place it with RMB."
			var tasks: Array = [["A HUMBLE BEGINNING",mine_hint],["MAKE SOMETHING",craft_hint],["ROOM TO GROW",place_hint],["THE NEXT CHAPTER","Use your table to craft a wooden pickaxe."]]
			draw_style_box(_style(Color(0.08,0.14,0.10,0.78)),Rect2(24,size.y-177,286,85))
			draw_string(font,Vector2(40,size.y-151),tasks[game.journal_step][0],HORIZONTAL_ALIGNMENT_LEFT,-1,11,ACCENT)
			draw_string(font,Vector2(40,size.y-125),tasks[game.journal_step][1],HORIZONTAL_ALIGNMENT_LEFT,-1,13,TEXT)
		if not game.touch:
			draw_style_box(_style(Color(0.07,0.13,0.09,0.75)),Rect2(size.x-236,size.y-89,212,65))
			draw_string(font,Vector2(size.x-223,size.y-64),"E  Inventory     ESC  Pause",HORIZONTAL_ALIGNMENT_LEFT,-1,12,TEXT)
			draw_string(font,Vector2(size.x-223,size.y-41),"LMB  Mine       RMB  Use",HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
		if debug:
			var info: String = "%d FPS  ·  %d map blocks  ·  %d columns\n%d generation jobs  ·  %d remesh jobs\nSeed %d  ·  Greedy meshing  ·  16³ nodes / block" % [Engine.get_frames_per_second(),game.world.blocks.size(),game.world.columns.size(),game.world.jobs.size(),game.world.remesh_jobs.size(),game.world.seed_value]
			draw_style_box(_style(Color(0,0,0,0.72)),Rect2(24,105,410,83))
			for i in 3: draw_string(font,Vector2(36,129+i*23),info.split("\n")[i],HORIZONTAL_ALIGNMENT_LEFT,-1,13,TEXT)
		if flash>0: draw_rect(Rect2(Vector2.ZERO,size),Color(0.6,0.15,0.1,flash*0.6))
	if toast_time>0:
		var width: float = font.get_string_size(toast_text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+40
		draw_style_box(_style(Color(0.09,0.17,0.12,0.95),Color("6e8552"),1),Rect2(size.x/2-width/2,100,width,42))
		draw_string(font,Vector2(size.x/2-width/2+20,127),toast_text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,TEXT)

func _heart(p: Vector2, full: bool) -> void:
	var col: Color = Color("c8735d") if full else Color("3d4940")
	var points := PackedVector2Array([p+Vector2(-7,-3),p+Vector2(-4,-6),p+Vector2(0,-3),p+Vector2(4,-6),p+Vector2(7,-3),p+Vector2(7,1),p+Vector2(0,8),p+Vector2(-7,1)])
	draw_colored_polygon(points,col)
	if full: draw_rect(Rect2(p+Vector2(-4,-3),Vector2(2,3)),Color("e9a484"))

func _shield(p: Vector2, full: bool, half: bool) -> void:
	var col: Color = Color("cfd8dc") if full else (Color("8a969b") if half else Color("3d4940"))
	var points := PackedVector2Array([p+Vector2(-6,-5),p+Vector2(6,-5),p+Vector2(6,2),p+Vector2(0,7),p+Vector2(-6,2)])
	draw_colored_polygon(points,col)
	if full or half: draw_rect(Rect2(p+Vector2(-2,-3),Vector2(4,3)),Color("f1f5f4") if full else Color("b7c2c6"))

func _food(p: Vector2, full: bool) -> void:
	draw_line(p+Vector2(-5,6),p+Vector2(1,0),Color("e0d7b4") if full else Color("4b5543"),3)
	draw_circle(p+Vector2(2,-2),5,Color("c99e60") if full else Color("4b5543"))

func _creative_take(id: int) -> void:
	if game.gamemode!="creative": return
	if cursor.id!=0:
		var rest: int=game.inventory.add_item(cursor.id,cursor.count,cursor.wear)
		if rest>0: game.spawn_drop(game.player.position+Vector3.UP,cursor.id,rest,cursor.wear)
	cursor={"id":id,"count":Nodes.max_stack(id),"wear":0}
	game.sound("click")
	refresh_slots()

func show_worlds() -> void:
	_clear()
	screen="worlds"
	_dim()
	var panel := _panel(layer,_panel_rect(Vector2(900,560)))
	_label(panel,"A PLACE TO CALL YOUR OWN",Vector2(30,24),12,ACCENT)
	_label(panel,"Your worlds.",Vector2(30,46),32)
	_button(panel,"+ New world",Rect2(700,32,170,44),show_new_world)
	var scroll := ScrollContainer.new()
	scroll.position=Vector2(30,110); scroll.size=Vector2(494,355)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",10)
	scroll.add_child(list)
	var worlds: Array=game.saves.list_worlds()
	for entry in worlds:
		var button := Button.new()
		button.custom_minimum_size=Vector2(473,80)
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.text="          "+String(entry.name)+"\n          Day %d  ·  Seed %s  ·  %s" % [int(entry.get("day",1)),str(entry.seed),String(entry.get("mode","survival")).capitalize()]
		button.add_theme_font_size_override("font_size",15)
		button.pressed.connect(_world_details.bind(entry))
		list.add_child(button)
		var icon := ItemIcon.new()
		icon.position=Vector2(12,13); icon.size=Vector2(51,51); icon.item_id=Nodes.GRASS; icon.show_slot=false
		button.add_child(icon)
	if worlds.is_empty(): _label(list,"Your next adventure starts here.\nCreate a world to begin.",Vector2.ZERO,17,MUTED)
	world_detail=_panel(panel,Rect2(552,110,318,355),Color("26362c"))
	if not worlds.is_empty(): _world_details(worlds[0])
	else:
		_label(world_detail,"Endless possibilities.",Vector2(24,27),21)
		_label(world_detail,"Each world has its own terrain,\nbuildings, inventory, and story.",Vector2(24,77),15,MUTED)
		_button(world_detail,"Create your first world",Rect2(24,256,270,47),show_new_world)
	_button(panel,"Back",Rect2(30,491,130,40),show_title)
	var path_label:=_label(panel,"Saves: "+game.saves.worlds_path,Vector2(183,501),12,MUTED)
	path_label.tooltip_text=game.saves.worlds_path
	path_label.size.x=687
	path_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS

func _world_details(entry: Dictionary) -> void:
	for child in world_detail.get_children(): world_detail.remove_child(child); child.queue_free()
	_label(world_detail,String(entry.name),Vector2(24,23),24,TEXT,267)
	_label(world_detail,"CHOOSE HOW TO PLAY",Vector2(24,98),11,ACCENT)
	var mode := OptionButton.new()
	mode.position=Vector2(24,125); mode.size=Vector2(270,43)
	mode.add_item("Survival"); mode.add_item("Creative")
	mode.selected=1 if entry.get("mode","survival")=="creative" else 0
	world_detail.add_child(mode)
	_label(world_detail,"Survival: gather, craft, and stay alive.\nCreative: all items, flight, and no damage.\n\nChange anytime with /gamemode.",Vector2(24,188),13,MUTED,270)
	_button(world_detail,"Enter world  →",Rect2(24,288,270,45),func(): game.enter_world(entry.id,"creative" if mode.selected==1 else "survival"))

func show_new_world() -> void:
	_clear()
	screen="new_world"
	_dim()
	var panel := _panel(layer,_panel_rect(Vector2(620,548)))
	_label(panel,"TURN A NEW LEAF",Vector2(34,26),12,ACCENT)
	_label(panel,"A world of your own.",Vector2(34,49),32)
	_label(panel,"WORLD NAME",Vector2(34,117),12,MUTED)
	var name_field := LineEdit.new()
	name_field.position=Vector2(34,143); name_field.size=Vector2(552,43)
	name_field.text="My world"; name_field.max_length=64
	panel.add_child(name_field)
	_label(panel,"SEED",Vector2(34,209),12,MUTED)
	seed_field=LineEdit.new()
	seed_field.position=Vector2(34,235); seed_field.size=Vector2(262,43)
	seed_field.placeholder_text="Random, or enter a seed"
	panel.add_child(seed_field)
	_label(panel,"GAME MODE",Vector2(322,209),12,MUTED)
	var mode := OptionButton.new()
	mode.position=Vector2(322,235); mode.size=Vector2(264,43)
	mode.add_item("Survival"); mode.add_item("Creative")
	panel.add_child(mode)
	_label(panel,"Survival",Vector2(34,313),17,ACCENT)
	_label(panel,"Gather resources. Craft tools.\nBuild a shelter before nightfall.",Vector2(34,345),14,MUTED)
	_label(panel,"Creative",Vector2(322,313),17,ACCENT)
	_label(panel,"Every node at your fingertips.\nFly, explore, and build freely.",Vector2(322,345),14,MUTED)
	_button(panel,"Back",Rect2(34,449,122,48),show_worlds)
	_button(panel,"Create world  →",Rect2(174,449,412,48),func(): game.start_new(seed_field.text,name_field.text,"creative" if mode.selected==1 else "survival"))
	_label(panel,"Each world saves separately in your .voxey folder.",Vector2(34,515),12,MUTED)

func show_loading() -> void:
	_clear()
	screen="loading"
	_dim()
	var panel:=_panel(layer,_panel_rect(Vector2(500,190)))
	_label(panel,"GROWING YOUR WORLD",Vector2(30,26),12,ACCENT)
	_label(panel,game.world_name,Vector2(30,56),30,TEXT,440)
	_label(panel,"Preparing the terrain. Your adventure is almost ready.",Vector2(30,131),14,MUTED)

func show_console(initial: String = "") -> void:
	_clear()
	screen="console"
	_dim()
	var panel:=_panel(layer,Rect2(Vector2(24,size.y-342),Vector2(size.x-48,318)),Color("15251e"))
	_label(panel,"VOXEY CONSOLE",Vector2(20,15),12,ACCENT)
	_label(panel,"ESC to return",Vector2(panel.size.x-120,15),12,MUTED)
	console_output=RichTextLabel.new()
	console_output.position=Vector2(20,43); console_output.size=Vector2(panel.size.x-40,206)
	console_output.scroll_following=true
	console_output.add_theme_color_override("default_color",TEXT)
	console_output.add_theme_font_size_override("normal_font_size",15)
	console_output.text="\n".join(game.console_messages)
	panel.add_child(console_output)
	console_input=LineEdit.new()
	console_input.name="ConsoleInput"
	console_input.position=Vector2(20,262); console_input.size=Vector2(panel.size.x-40,38)
	console_input.placeholder_text="/gamemode creative"
	console_input.text=initial
	console_input.text_submitted.connect(func(command: String):
		game.execute_command(command)
		console_output.text="\n".join(game.console_messages)
		console_input.clear())
	panel.add_child(console_input)
	console_input.grab_focus()
	console_input.caret_column=initial.length()

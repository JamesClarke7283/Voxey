class_name VoxeyHUD
extends Control

const INK = Color("202020")
const PANEL = Color("484848")
const TEXT = Color("f0f0f0")
const MUTED = Color("c3c3c3")
const ACCENT = Color("e1e1e1")
var game: Node3D
var layer: Control
var hotbar: Array = []
var screen: String = ""
var book_index: int = 0
var enchanting_pos := Vector3i.ZERO
var toast_text: String = ""
var toast_time: float = 0.0
var flash: float = 0.0
var debug: bool = false
var cursor: Dictionary = {"id":0,"count":0,"wear":0}
var inventory_panel: Panel
var cursor_icon: ItemIcon
var slots_ui: Array = []
var station_ui: Array = []
var pouch_ui: Array = []
var inventory_indices: Array = []
var station_indices: Array = []
var inventory_page: int = 0
var container_page: int = 0
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
var recipe_list: GridContainer
var recipe_search: LineEdit
var requirements_label: Label
var fill_button: Button
var result_label: Label
var catalog_mode: bool = false
var world_detail: Control
var delete_world_entry: Dictionary = {}
var console_input: LineEdit
var console_output: RichTextLabel
var armor_ui: Array = []
var armor_label: Label
var offhand_ui: ItemIcon
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
	theme_value.set_color("font_disabled_color","Button",Color("909090"))
	for type_name in ["Button","LineEdit"]:
		theme_value.set_stylebox("normal",type_name,_style(Color("646464"),Color("858585"),1,6))
		theme_value.set_stylebox("hover",type_name,_style(Color("7a7a7a"),ACCENT,1,6))
		theme_value.set_stylebox("pressed",type_name,_style(Color("383838"),ACCENT,2,6))
		theme_value.set_stylebox("focus",type_name,_style(Color(0,0,0,0),ACCENT,2,6))
		theme_value.set_stylebox("disabled",type_name,_style(Color("3b3b3b"),Color("555555"),1,6))
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
	pouch_ui.clear()
	inventory_indices.clear()
	station_indices.clear()
	grid_ui.clear()
	armor_ui.clear()
	inventory_panel=null
	armor_label=null
	offhand_ui=null
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

func _compact_button(parent: Node, text_value: String, rect: Rect2, callback: Callable) -> Button:
	var button: Button = _button(parent,text_value,rect,callback)
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		var style: StyleBox = button.get_theme_stylebox(state_name).duplicate()
		style.content_margin_top = 4; style.content_margin_bottom = 4
		style.content_margin_left = 6; style.content_margin_right = 6
		button.add_theme_stylebox_override(state_name,style)
	button.add_theme_font_size_override("font_size",14)
	button.size = rect.size
	return button

func _panel(parent: Node, rect: Rect2, color: Color = PANEL) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel",_style(color,Color("777777"),1,8))
	parent.add_child(panel)
	return panel

func _center(size_value: Vector2) -> Vector2:
	return (size-size_value)*0.5

func show_title() -> void:
	_clear()
	screen = "title"
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.08,0.08,0.08,0.96),Color(0.08,0.08,0.08,0.8),Color(0.08,0.08,0.08,0.04)])
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
	title.add_theme_color_override("font_shadow_color",Color("141414"))
	title.add_theme_constant_override("shadow_offset_y",6)
	_label(layer,"One node. Endless possibilities.",origin+Vector2(0,title_size*0.5+92),23,TEXT)
	_label(layer,"Gather, craft, and find your own way.\nA living voxel wilderness awaits.",origin+Vector2(0,title_size*0.5+137),16,MUTED)
	start_button = _button(layer,"Play / choose a world  →",Rect2(origin+Vector2(0,title_size*0.5+217),Vector2(minf(340,size.x-90),56)),show_worlds)
	start_button.add_theme_font_size_override("font_size",19)
	_button(layer,"Create a new world",Rect2(origin+Vector2(0,title_size*0.5+285),Vector2(minf(340,size.x-90),44)),show_new_world)
	_label(layer,"SURVIVAL & CREATIVE  ·  YOUR OWN WORLDS",origin+Vector2(0,title_size*0.5+351),11,MUTED)
	_label(layer,"VOXEY    ·    SINGLE PLAYER    ·    INFINITE HORIZONS",Vector2(38,size.y-40),11,MUTED)
	var version_tag := _panel(layer,Rect2(Vector2(size.x-224,20),Vector2(186,32)),Color(0.08,0.08,0.08,0.6))
	_label(version_tag,"v"+Game.VERSION+"  ·  "+Game.VERSION_NAME,Vector2(14,7),13,ACCENT)
	var tag := _panel(layer,Rect2(Vector2(size.x-290,size.y-96),Vector2(254,58)),Color(0.12,0.12,0.12,0.75))
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
	var panel := _fitted_panel(Vector2(480,580))
	_label(panel,"TAKE A BREATHER",Vector2(34,26),12,ACCENT)
	_label(panel,"A moment of quiet.",Vector2(34,49),30)
	_label(panel,"v"+Game.VERSION+" "+Game.VERSION_NAME+"    ·    "+game.world_name,Vector2(34,93),13,MUTED)
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
	audio_button.text = "Sound and music"
	audio_button.position = Vector2(28,302)
	audio_button.button_pressed = game.audio_enabled
	audio_button.toggled.connect(func(value: bool): game.audio_enabled=value)
	panel.add_child(audio_button)
	var actions := GridContainer.new()
	actions.position = Vector2(34,354)
	actions.size.x = 412
	actions.columns = 2
	actions.add_theme_constant_override("h_separation",12)
	actions.add_theme_constant_override("v_separation",12)
	panel.add_child(actions)
	for action in [["Field guide",show_guide],["Achievements",show_achievements]]:
		var button := _button(actions,action[0],Rect2(0,0,200,43),action[1])
		button.custom_minimum_size = Vector2(200,43)
	if not game.touch:
		var button := _button(actions,"Fullscreen",Rect2(0,0,200,43),game.toggle_fullscreen)
		button.custom_minimum_size = Vector2(200,43)
	_button(panel,"Save & return to title",Rect2(34,464,412,46),game.return_to_title)
	_label(panel,"World edits and inventory autosave every 45 seconds.",Vector2(34,534),12,MUTED)

func show_achievements() -> void:
	_clear()
	screen="achievements"
	_dim()
	var panel := _panel(layer,_panel_rect(Vector2(700,600)))
	_label(panel,"MOMENTS OF PRIDE",Vector2(32,25),12,ACCENT)
	_label(panel,"Achievements.",Vector2(32,47),30)
	var scroll := ScrollContainer.new()
	scroll.position=Vector2(32,104)
	scroll.size=Vector2(636,424)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",8)
	scroll.add_child(list)
	var total: int = 0
	var done: int = 0
	for definition in game.achievements.DEFINITIONS:
		total += 1
		var earned: bool = game.achievements.is_unlocked(definition.id)
		if earned: done += 1
		var row := Button.new()
		row.custom_minimum_size=Vector2(620,54)
		row.alignment=HORIZONTAL_ALIGNMENT_LEFT
		row.disabled=true
		row.text=("✔  " if earned else "      ")+String(definition.title)+(("  —  "+String(definition.description)) if earned else "")
		row.add_theme_font_size_override("font_size",14)
		row.add_theme_color_override("font_disabled_color",ACCENT if earned else MUTED)
		list.add_child(row)
	_label(panel,"%d / %d earned" % [done,total],Vector2(32,540),14,ACCENT)
	_button(panel,"Back",Rect2(500,534,168,44),show_pause)

func show_guide() -> void:
	_clear()
	screen = "guide"
	_dim()
	var panel := _panel(layer,_panel_rect(Vector2(790,600)))
	_label(panel,"THE VOXEY FIELD GUIDE",Vector2(32,25),12,ACCENT)
	_label(panel,"Make yourself at home.",Vector2(32,47),30)
	var text_value: String = "01   START SMALL\nHold left click on a log. Open your inventory with E, turn logs into planks, then craft a table. Place it and right click to unlock tools.\n\n02   DIG A LITTLE DEEPER\nA wooden pickaxe mines stone and coal. Stone picks unlock iron. Smelt iron ore in a furnace; an iron pickaxe can harvest diamonds below Y 12.\n\n03   BUILD A LIFE\nTill grass with a hoe and plant seeds. Crops ripen in 90 seconds. Right click a sheep with shears to gather wool without killing it; its coat regrows when it eats grass. Cook meat and use wool for a bed. Right click a bed to set your spawn and sleep through the night. Saplings grow into trees.\n\n04   STAY ALIVE\nHold right click to eat; release to cancel. Keep hunger high to regenerate health. Hold Space to swim up and Shift to swim down; hold Space while moving toward a bank to climb out. Watch your breath underwater and your footing on cliffs. The dark brings zombies, skeletons, spiders, and creepers. Build a shelter, place torches, and keep a sword close.\n\n05   ARMOR & THE WILD\nCraft leather, iron, golden, or diamond armor at a table and right click to wear it; each piece wears down as it protects you. Cows drop leather, chickens and pigs give meat, bones become bone meal for instant crops, each wool block unravels into four string, and gunpowder plus sand makes TNT. Sand and gravel fall when unsupported. Two chests placed together join into one large chest."
	text_value += "\n\n06   THE NETHER\nWater touching cave lava makes obsidian. Mine it with a diamond pickaxe. Build a 4 × 5 obsidian frame with a 2 × 3 opening, light it with flint and steel, and step inside. Return through a portal. Water evaporates there; beds cannot set spawn.\n\n07   BOOKS & ENCHANTING\nCows always drop leather. Three paper + leather make a book; add a feather + charcoal for a writable book. Hold it and right click to write. A book, two diamonds, and four obsidian make an enchanting table. Mine lapis underground; right click the table to upgrade equipment using lapis and XP levels. Leave a one-block air gap between the table and nearby bookshelves.\n\n08   RECOVER YOUR ARROWS\nArrows stuck in the world last ten active minutes. Walk near them to pick them up. Ground items stay put until the entire pickup fits in your inventory."
	text_value += "\n\n09   INTO THE DEEP\nThe Overworld now reaches bedrock at Y -128. Find deepslate, larger caverns and deep ores below zero. Carry torches: cave enemies can appear even during the day. Four cobbled deepslate make polished deepslate; four polished blocks make bricks. Lava buckets fuel furnaces and leave an empty bucket.\n\n10   DROP WHAT YOU CARRY\nQ throws one item. In inventory, press an item to carry it, move outside the panel, then press Escape to drop the stack and close. Left-click outside drops a stack; right-click drops one. Thrown items have a short pickup delay. Esc with the pointer inside returns carried items to your bag."
	text_value += "\n\n11   REDSTONE\nMine redstone ore deep underground with an iron pickaxe. Dust carries power up to 15 blocks. Right click levers and buttons; walk on plates. Repeaters face away from you and restore power; right click to set a 1–4 tick delay. Comparators read container fullness and switch compare/subtract modes. Torches invert the power of their supporting block. Observers pulse when the block at their face changes. Pistons move up to 12 blocks; honey and slime carry adjoining blocks without sticking to each other. Sticky pistons pull assemblies back. Hoppers move items when unpowered; powered dispensers fire arrows and droppers eject one item. Hold Ctrl to place against interactive blocks.\n\n12   FIND THE END\nExplore Nether fortresses for blazes and their rods. Craft blaze powder, then combine it with ender pearls from endermen to make Eyes of Ender. Throw an Eye in the Overworld and follow it to an underground stronghold. Fill all twelve portal frames with Eyes and step into the portal. Pearls teleport you to their landing spot, costing health.\n\n13   THE DRAGON\nShoot the healing crystals atop the End’s ten obsidian towers; two have iron cages. Fight the dragon with your bow or strike when it perches. Avoid its purple breath and the void. Victory gives XP, a dragon egg, and a portal home. Four crafted crystals placed on the cardinal edges of the exit fountain summon another dragon. Victory also opens a gateway near the arrival platform, leading to the outer islands and a return gateway. Beyond the main island lie chorus groves and purpur cities guarded by shulkers. Their homing shots cause levitation. Find elytra in the treasure chests, equip them in your chest slot, and hold Jump while falling to glide. Aim to steer and dive; worn-out wings stop gliding."
	text_value += "\n\n14   VILLAGES & LEADS\nUse /locate village to find a settlement. Right click villagers to trade with emeralds. Working restocks their trades, and trading unlocks five profession levels. Ctrl + right click with food feeds villagers; two fed adults and a spare bed allow a baby. Craft two leads from five string and one slime ball. Use a lead on an animal or villager and walk to pull it. Use a lead or an empty hand again to release it. Slimes spawn in dark swamps and in seeded underground chunks below Y -24.\n\n15   YOUR OWN HOME\n/sethome saves your position and facing in this world. /home returns there, even from another dimension. Offline, your player name is player.\n\n16   BREWING\nA blaze rod and cobblestone make a brewing stand. Fill glass bottles with water. The stand takes one ingredient, blaze powder fuel and up to three bottles. Batches take 10 seconds; one blaze powder fuels 20. Water + nether wart makes awkward potion. Try sugar for swiftness, a ghast tear for regeneration or magma cream for fire resistance. Redstone extends duration; glowstone dust strengthens effects. Gunpowder makes splash bottles; dragon breath makes lingering bottles. Surround a lingering potion with eight arrows to tip them. Drink milk to clear effects.\n\n17   ENCHANTED GEAR\nChoose an enchantment at the table. Books can be enchanted too. Combine equal-level books at an anvil to reach higher levels. Equipment rejects conflicting enchantments. Librarians, treasure and fishing supply treasure enchantments. Mending repairs worn or held gear with new XP. Grindstones remove enchantments but keep curses. Check tooltips for every level.\n\n18   COLORED POUCHES\nCraft a level 1 white pouch from four string in a 2×2 square in your inventory. No chest or wool is needed. Recolor it with dye or wool. Combine two pouches of the same level to upgrade, up to level 5: 27, 54, 81, 108 and 135 slots. Both inputs keep their cargo; empty some first if it cannot fit. Equip up to three in the pouch slots to add inventory pages. The hotbar stays visible on every page. Carried pouches add no pages but can still be opened: right click one in inventory, or hold and use it. Pouches have their own page arrows and Back button. Unequipping takes the contents along. Craft a pouch with wool or dye to recolor it. Pouches cannot hold other pouches. All sixteen wool colors can be recolored with dyes.\n\n19   DEATH & RECOVERY\nDying leaves two bones and a recovery chest. Your main backpack, armor, equipped pouches, crafting ingredients and cursor stack go into the chest. Items on extra inventory pages remain inside their pouches. The chest persists; its coordinates appear on the death screen. Right click to retrieve your items, then re-equip the pouches to restore their pages. Another death leaves a separate chest."
	text_value += "\n\n20   NETHERITE & BASTIONS\nMine ancient debris with a diamond pickaxe. Smelt four debris for four scrap, then combine with four gold for an ingot. Bastion chests can contain upgrade templates. At a smithing table, upgrade diamond gear with one ingot and one template. Duplicate templates using seven diamonds and netherrack. /locate bastion finds a blackstone stronghold in the Nether. Gold armor pacifies piglins; brutes still attack. Give a piglin one gold ingot to receive a barter reward after six seconds.\n\n21   FIRE & LODESTONES\nFlint and steel or fire charges ignite blocks, portals and TNT. Netherrack supports eternal fire; water extinguishes flames. Use a compass on a lodestone to bind that compass. Use it again to get a bearing. It works within the lodestone’s dimension and stops tracking if the lodestone is destroyed."
	text_value += "\n\n22   ANIMAL FARMING\nFeed healthy adult cows and sheep wheat, pigs carrots/potatoes/beetroot, chickens seeds, or rabbits carrots to breed a pair. Parents wait five minutes before breeding again. Babies grow over twenty active minutes; feeding speeds growth. Hold their food to lead animals home. Dye sheep with any dye; lambs inherit mixed or parental colors. Sheep eat grass to regrow their wool. Nearby grass spreads into dirt with enough light. Chickens lay eggs every five to ten minutes. Animals and their coats persist when you save or travel.\n\n23   CAMPFIRE COOKING\nUse raw food on a lit campfire to fill up to four cooking spots. Each cooks for thirty seconds and drops the cooked food. Use a shovel to smother or flint and steel to relight. Soul campfires use soul sand instead of coal. Hay below makes taller smoke. Avoid standing on a lit fire.\n\n24   FISHING & NAMES\nCast a rod into still water, wait for the bobber to dip and splash, then reel in quickly. Luck of the Sea increases treasure odds; Lure shortens the wait. Fish up name tags or craft one diagonally from paper and an iron or gold nugget. At an anvil, choose an item stack and set its name for one XP level. Use a named tag on a mob to give it a visible, persistent name."
	text_value += "\n\n25   FENCES & GATES\nCraft oak or Nether brick fences and gates to enclose a pasture. Gates open by right-click or redstone. Use a fence to tie nearby animals already attached to leads; use it again to release the anchored leads. Stonecutters also produce walls in twenty-one materials.\n\n26   LIGHT & TARGETS\nDaylight detectors use glass, quartz and wooden slabs. Right-click to invert the output for night lighting. Targets use a hay bale surrounded by redstone dust; projectile hits produce one-second pulses, stronger near the bullseye for arrows and tridents.\n\n27   CAULDRONS\nExposed cauldrons collect rain. Water extinguishes burning creatures using one portion; lava ignites them. Use a dyed shulker box on a water cauldron to remove its color while retaining its contents."
	text_value += "\n\n28   TRAPDOORS\nSix matching wood planks make two wooden trapdoors; four iron ingots make an iron trapdoor. Place them on the upper or lower half of a block face. Wooden trapdoors open by hand; both respond to redstone. Open trapdoors can be climbed.\n\n29   BOATS\nUse a boat to place it, then right-click to board. W/S row and A/D steer; Ctrl dismounts and leaves the boat in the world. Animals can ride along. Craft a chest above a boat to add 27 cargo slots; Ctrl + right-click opens its cargo.\n\n30   MAPS\nUse an empty map to capture the region around you. Copies keep that same survey after the terrain changes. A cartography table lets you choose which map to copy or view. Place filled maps in item frames for a wall display.\n\n31   EGGS & SNOW\nRight-click to throw eggs or snowballs. Eggs sometimes hatch chicks when they hit a block; snowballs hurt blazes. Collect snowballs from thin snow with a shovel. Four snowballs make a snow block; three snow blocks make six layers. Place layers repeatedly to stack them, up to eight per block."
	text_value += "\n\n32   TREES & WOOD\nOak, spruce, birch, jungle, acacia and dark oak have their own planks and building parts. Ordinary recipes accept mixed planks. Right-click logs with an axe to strip them. Shears or Silk Touch recover leaves; ordinary leaves may drop sticks, saplings or eligible apples. Placed leaves stay, while unsupported natural leaves decay. Dark oak needs four matching saplings in a 2x2 square; spruce and jungle also grow giant trees from squares. Bone meal gives a sapling a growth attempt.\n\n33   DOORS & SIGNS\nSix matching planks craft three wooden doors. Use either half to open both. Iron doors require power; redstone can reach either half. Neighboring matching doors form mirrored hinges. Craft an oak sign from six oak planks and a stick, then write when placing it. Dyes change the lettering. To allow later editing, use /gamerule signsEditable true.\n\n34   CAKE & FLOWER STEW\nPlace cake on a solid support and right-click to eat one of its seven slices. A comparator reads its remaining slices. Chorus fruit can teleport you nearby after eating. A red mushroom, brown mushroom, bowl and poppy make night-vision stew; dandelion gives saturation and oxeye daisy gives regeneration. Use bone meal on these flowers to spread the same species over nearby grass."
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(32,100); scroll.size = Vector2(726,350)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	text_value += "\n\nMUSIC & MECHANISMS\nRight-click a note block to tune it, punch to play, or trigger it with redstone. Leave air above it; the material below chooses the instrument. Right-click a jukebox with a disc to insert it, then right-click again to eject it. Wooden buttons last 1.5 seconds and respond to arrows; stone buttons last one second. Stone plates detect living creatures; wood and weighted plates also detect physical objects.\n\nMUSIC CREDITS\n"+Jukeboxes.CREDITS.replace(". ",".\n\n")
	text_value += "\n\nFARMLAND & CROPS\nHoe dirt, grass or paths with clear air above, then plant wheat seeds, carrots, potatoes or beetroot seeds. Nearby water hydrates farmland; wet soil grows crops faster. Soil dries gradually after water is removed, and empty dry beds return to dirt. Bone meal advances growth stages. Harvest mature crops and save seeds to replant. A rare poisonous potato is unsafe to eat and cannot be planted.\n\nGOLEMS\nPlace a carved pumpkin or jack-o'-lantern last on two stacked snow blocks to make a snow golem, or on four iron blocks arranged as a T to make an iron golem. Iron golems defend against monsters; use iron ingots to repair damage. Shear a snow golem to remove its pumpkin. Snow golems throw snowballs and leave snow trails; protect them from water, rain and hot biomes."
	text_value += "\n\nPUMPKINS & MELONS\nPlant their seeds on farmland and leave adjacent dirt or grass for fruit. Harvest the fruit while keeping its stem planted. Use shears on a pumpkin's side to carve it and collect four seeds. A carved pumpkin above a torch makes a jack-o'-lantern. Equip a carved pumpkin in the helmet slot to avoid provoking Endermen with your gaze.\n\nHONEY\nLook for nests in oak and birch trees, or craft a hive with six planks and three honeycombs. Flowers nearby allow daytime production in dry weather. Use a bottle or shears on a full hive; a lit campfire below it prevents retaliation. Honey bottles return their glass when eaten or crafted. Honey blocks cushion falls and carry adjoining blocks with pistons; honey and slime do not stick to each other.\n\nAMETHYST & SPYGLASSES\nUnderground geodes contain crystals. Mine mature clusters with a pickaxe for shards; the budding blocks grow new crystals and cannot be collected. Four shards around glass make two tinted glass, which blocks light. Craft one shard above two copper ingots for a spyglass, then hold right-click or Z to zoom. Touch players hold Use."
	var guide_text := Label.new()
	guide_text.text = text_value; guide_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_text.custom_minimum_size.x = 700
	guide_text.add_theme_font_size_override("font_size",14)
	scroll.add_child(guide_text)
	_label(panel,"WASD  Move    SPACE  Jump / swim    SHIFT  Sprint    CTRL  Sneak    /  Console\nLMB  Mine / attack    RMB  Place / use / eat / wear    E  Inventory    Q  Drop\n1–9 / WHEEL  Hotbar    F3  Debug    F5  Save    ESC  Pause",Vector2(32,470),13,MUTED)
	_button(panel,"Back",Rect2(610,530,146,42),show_pause)

func show_inventory(kind: String = "hand", data: Dictionary = {}) -> void:
	_clear()
	screen = "inventory"
	station = kind
	catalog_mode = game.gamemode=="creative" and kind in ["hand","table"]
	station_data = data
	var tall: bool = kind == "chest" and data.get("kind","") != "pouch" and data.get("slots",[]).size() > 27
	var extra: int = 84 if tall else 0
	_dim()
	var panel := _fitted_panel(Vector2(1100,616+extra))
	inventory_panel = panel
	_label(panel,"YOUR SATCHEL",Vector2(28,22),12,ACCENT)
	_label(panel,{"hand":"A little ingenuity.","table":"The crafting table.","furnace":"Into the fire.","brewing":"A little alchemy.","chest":data.get("label","One large chest." if tall else "Room for everything.")}[kind],Vector2(28,44),28)
	_button(panel,"×",Rect2(1029,22,43,40),game.resume)
	if game.gamemode=="creative":
		_compact_button(panel,"Recipes",Rect2(24,94,136,28),func(): catalog_mode=false; _populate_recipes())
		_compact_button(panel,"All items",Rect2(168,94,140,28),func(): catalog_mode=true; _populate_recipes())
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
	recipe_list = GridContainer.new()
	recipe_list.columns = 5
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list.add_theme_constant_override("h_separation",5)
	recipe_list.add_theme_constant_override("v_separation",5)
	scroll.add_child(recipe_list)
	_populate_recipes()
	_label(panel,"Look up a pattern, or arrange your own.\nFill grid places the ingredients for you.",Vector2(28,556),12,MUTED)
	preview = Control.new()
	preview.position = Vector2(340,102)
	preview.size = Vector2(668,194+extra)
	panel.add_child(preview)
	if kind in ["hand","table"]: _recipe_preview()
	elif kind == "furnace": _furnace_preview()
	elif kind == "brewing": _brewing_preview()
	else: _chest_preview()
	# Worn armor lives in its own column. Each slot only accepts its own piece.
	_label(panel,"ARMOR",Vector2(1030,80),10,MUTED)
	for i in 4:
		var button := _button(panel,"",Rect2(Vector2(1030,96+i*49),Vector2(46,46)),_slot_click.bind(i,false,false,false,true))
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.gui_input.connect(_armor_input.bind(i))
		var icon := ItemIcon.new()
		icon.size = Vector2(46,46)
		button.add_child(icon)
		armor_ui.append(icon)
	armor_label = _label(panel,"",Vector2(1030,292),11,MUTED)
	# The second hand. The source gives it its own slot, and it is what a shield
	# or a totem is carried in while the main hand holds something else. It sits in
	# the gap between the armor column and the pouches.
	_label(panel,"2ND HAND",Vector2(1030,312),10,MUTED)
	var offhand_button := _button(panel,"",Rect2(Vector2(1030,326),Vector2(40,40)),_offhand_click)
	offhand_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	offhand_ui = ItemIcon.new()
	offhand_ui.size = Vector2(40,40)
	offhand_button.add_child(offhand_ui)
	_label(panel,"POUCHES",Vector2(1020,334+extra),10,ACCENT)
	for i in Inventory.POUCH_SLOTS:
		var button := _button(panel,"",Rect2(Vector2(1028,355+extra+i*62),Vector2(50,54)),_pouch_click.bind(i,false))
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.gui_input.connect(_pouch_input.bind(i))
		var icon := ItemIcon.new(); icon.size = Vector2(50,54); button.add_child(icon); pouch_ui.append(icon)
	inventory_page = clampi(inventory_page,0,game.inventory.page_count()-1)
	inventory_indices = game.inventory.page_indices(inventory_page)
	var page_label: String = "Backpack" if inventory_page == 0 else "Pouch storage"
	_label(panel,"%s · %d slots"%[page_label,game.inventory.slots.size()],Vector2(342,316+extra),12,MUTED)
	_compact_button(panel,"‹",Rect2(750,308+extra,35,28),_change_inventory_page.bind(-1)).disabled = inventory_page == 0
	_label(panel,"Page %d / %d"%[inventory_page+1,game.inventory.page_count()],Vector2(800,316+extra),12,ACCENT)
	_compact_button(panel,"›",Rect2(958,308+extra,35,28),_change_inventory_page.bind(1)).disabled = inventory_page == game.inventory.page_count()-1
	for i in 36:
		var index: int = inventory_indices[i]
		var x: int = i%9
		var y: int = i/9
		var pos := Vector2(342+x*73,344+extra+y*57+(10 if y>0 else 0))
		var button := _button(panel,"",Rect2(pos,Vector2(65,51)),_slot_click.bind(index,false,false))
		button.disabled = index < 0
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.gui_input.connect(_slot_input.bind(index,false))
		var icon := ItemIcon.new()
		icon.size = Vector2(65,51)
		icon.number = str(i+1) if i<9 else ""
		button.add_child(icon)
		slots_ui.append(icon)
	_label(panel,"HOTBAR",Vector2(342,589+extra),10,MUTED)
	_label(panel,"Q  Drop one · Drag outside + Esc  Drop stack",Vector2(682,589+extra),10,MUTED)
	cursor_icon = ItemIcon.new()
	cursor_icon.size = Vector2(48,48)
	cursor_icon.show_slot = false
	layer.add_child(cursor_icon)
	# Touch has no Shift/right-click: on-screen toggles provide both semantics.
	if game.touch:
		var toggle_panel := _panel(layer,Rect2(Vector2(8,size.y-124),Vector2(198,116)),Color(0.08,0.08,0.08,0.85))
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
	var query: String = recipe_search.text.strip_edges().to_lower() if is_instance_valid(recipe_search) else ""
	if catalog_mode:
		for id in Nodes.all_ids():
			if not query.is_empty() and not query in Nodes.title(id).to_lower(): continue
			_recipe_cell(id,Nodes.title(id),_creative_take.bind(id))
	else:
		for i in game.inventory.recipes.size():
			var recipe: Dictionary = game.inventory.recipes[i]
			if not query.is_empty() and not query in String(recipe.name).to_lower(): continue
			var can: bool = game.inventory.can_craft(recipe,station)
			var description: String = recipe.name+"\n"+("Crafting table" if recipe.station == "table" else "Hand crafting")
			description += "\n"+("Ready to craft" if can else "Select to see ingredients")
			var button: RecipeButton = _recipe_cell(recipe.id,description,_select_recipe.bind(i))
			button.set_meta("recipe_index",i)
			if can: button.add_theme_stylebox_override("normal",_style(Color("727272"),Color("d6d6d6"),2,2))
	if recipe_list.get_child_count() == 0:
		var label := Label.new(); label.text = "No matching items"; recipe_list.add_child(label)

func _recipe_cell(id: int, description: String, callback: Callable) -> RecipeButton:
	var button := RecipeButton.new()
	button.item_id = id
	button.tooltip_text = description
	button.custom_minimum_size = Vector2(49,49)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	recipe_list.add_child(button)
	var icon := ItemIcon.new()
	icon.item_id = id; icon.show_slot = false
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)
	return button

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
			button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
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
	_label(preview,"ANY ORDER" if recipe.get("shapeless",false) else "PATTERN",Vector2(571,119),10,MUTED)
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
		var owned: int = game.inventory.count_ingredient(recipe,id)
		for slot in game.inventory.grid:
			if Inventory.ingredient_key(recipe,slot.id)==id: owned+=slot.count
		if owned<recipe.ingredients[id]: can_fill=false
		var name_text: String = Inventory.ingredient_title(recipe,id)
		description += "%s  %d / %d\n" % [name_text,owned,recipe.ingredients[id]]
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
	elif recipe.count > Nodes.max_stack(recipe.id):
		# Multiple nonstackable results must never become an oversized cursor
		# stack that save normalization would truncate (for example map copies).
		crafted = game.inventory.craft_grid_to_inventory(station)
	elif cursor.id==0 or (cursor.id==recipe.id and cursor.wear==0 and cursor.count+recipe.count<=Nodes.max_stack(recipe.id)):
		var output: Dictionary = game.inventory.take_grid_result(station)
		if output.is_empty(): return
		if cursor.id==0: cursor=output
		else: cursor.count+=output.count
		crafted=true
	if crafted:
		game.sound("craft")
		game.progress("craft")
	refresh_slots()

func _brewing_preview() -> void:
	_label(preview,"BREWING STAND",Vector2.ZERO,12,ACCENT)
	var labels: Array = ["INGREDIENT","BLAZE POWDER","BOTTLE 1","BOTTLE 2","BOTTLE 3"]
	for i in 5:
		_label(preview,labels[i],Vector2(i*125,31),11,MUTED)
		_station_slot(i,Vector2(i*125,55),Vector2(64,64))
	furnace_label = _label(preview,"",Vector2(0,132),13,MUTED)
	_label(preview,"Water + wart → awkward. Add an ingredient, then redstone or glowstone dust.\nGunpowder → splash. Dragon breath → lingering. One blaze powder fuels 20 batches.",Vector2(0,157),12,MUTED,640)

func _furnace_preview() -> void:
	_label(preview,"SMELTING",Vector2.ZERO,12,ACCENT)
	var labels: Array = ["INPUT","FUEL","OUTPUT"]
	for i in 3:
		var x: int = i*128
		_label(preview,labels[i],Vector2(x,31),11,MUTED)
		_station_slot(i,Vector2(x,55),Vector2(64,64))
		if i<2: _label(preview,"+" if i==0 else "→",Vector2(x+84,70),27,ACCENT)
	furnace_label = _label(preview,"Add ore or food, then coal, charcoal, wood or a lava bucket.",Vector2(0,140),14,MUTED)
	_label(preview,"RECIPES\nIron / gold / copper ore → ingots\nSand → glass · Raw meat → cooked meat\nCobblestone → stone · Log → charcoal",Vector2(400,32),13,MUTED)

func _chest_preview() -> void:
	var portable: bool = station_data.get("kind","") == "pouch"
	var pages: int = maxi(1,ceili(station_data.slots.size()/27.0))
	container_page = clampi(container_page,0,pages-1)
	var start: int = container_page*27 if portable else 0
	var end: int = mini(start+27,station_data.slots.size()) if portable else station_data.slots.size()
	var rows: int = (end-start)/9
	_label(preview,station_data.get("label","LARGE CHEST  ·  TWO CHESTS JOINED" if rows > 3 else "CHEST STORAGE"),Vector2.ZERO,12,ACCENT)
	if portable:
		_compact_button(preview,"‹",Rect2(448,-8,32,28),_change_container_page.bind(-1)).disabled = container_page == 0
		_label(preview,"%d / %d"%[container_page+1,pages],Vector2(492,0),12,MUTED)
		_compact_button(preview,"›",Rect2(544,-8,32,28),_change_container_page.bind(1)).disabled = container_page == pages-1
		_compact_button(preview,"Back",Rect2(587,-8,65,28),_close_pouch_view)
	var spacing: int = 51 if rows <= 3 else 44
	for i in range(start,end):
		_station_slot(i,Vector2(((i-start)%9)*73,27+((i-start)/9)*spacing),Vector2(65,47 if rows <= 3 else 40))

func _change_inventory_page(direction: int) -> void:
	inventory_page = clampi(inventory_page+direction,0,game.inventory.page_count()-1)
	show_inventory(station,station_data)

func _change_container_page(direction: int) -> void:
	container_page += direction
	show_inventory(station,station_data)

func _close_pouch_view() -> void:
	return_cursor()
	show_inventory()

func _pouch_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed: _pouch_click(index,true)

func _pouch_click(index: int, right: bool) -> void:
	if right and cursor.id == 0:
		game.survival.open_pouch(index,true)
		return
	if game.survival.open_pouch_index >= 0 or game.survival.open_equipped_pouch >= 0:
		game.toast("Close the pouch view before changing equipped pouches."); return
	if cursor.id != 0 and not Pouches.is_pouch(cursor.id): game.toast("This slot takes a pouch."); return
	cursor = game.inventory.exchange_pouch(index,cursor)
	game.sound("equip")
	show_inventory(station,station_data)

func _station_slot(index: int, pos: Vector2, size_value: Vector2) -> void:
	var button := _button(preview,"",Rect2(pos,size_value),_slot_click.bind(index,true,false))
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.gui_input.connect(_slot_input.bind(index,true))
	var icon := ItemIcon.new()
	icon.size = size_value
	button.add_child(icon)
	station_ui.append(icon)
	station_indices.append(index)

func _slot_input(event: InputEvent, index: int, is_station: bool) -> void:
	if index < 0: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not is_station and cursor.id == 0 and Pouches.is_pouch(game.inventory.slots[index].id):
			game.survival.open_pouch(index); return
		_slot_click(index,is_station,true)

func _armor_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_slot_click(index,false,true,false,true)

func _offhand_click() -> void:
	var slot: Dictionary = game.player.offhand_slot
	if cursor.id != 0:
		if slot.id != 0:
			# Swap, so an occupied hand exchanges rather than refusing.
			var previous: Dictionary = slot.duplicate(true)
			game.player.offhand_slot = cursor.duplicate(true)
			cursor = previous
		else:
			game.player.offhand_slot = cursor.duplicate(true)
			cursor = {"id":0,"count":0,"wear":0}
	elif slot.id != 0:
		cursor = slot.duplicate(true)
		game.player.offhand_slot = {"id":0,"count":0,"wear":0}
	refresh_slots()

func _slot_click(index: int, is_station: bool, right: bool, is_grid: bool = false, is_armor: bool = false) -> void:
	if split_mode: right = true
	var source: Array = game.player.armor_slots if is_armor else (game.inventory.grid if is_grid else (station_data.slots if is_station else game.inventory.slots))
	if index < 0 or index >= source.size(): return
	var slot: Dictionary = source[index]
	if is_armor and game.gamemode != "creative" and Inventory.enchantment(slot,"Curse of Binding") > 0: game.toast("Curse of Binding prevents removing this armor."); return
	if not is_station and not is_grid and not is_armor and index == game.survival.open_pouch_index: return
	if not is_station and not is_grid and not is_armor and index >= Inventory.BASE_SLOTS and PortableStorage.contains_kind(cursor,false): game.toast("Pouches cannot contain other pouches."); return
	if is_station and not PortableStorage.accepts(station_data,cursor): return
	if not is_station and (shift_mode or Input.is_physical_key_pressed(KEY_SHIFT)) and not PortableStorage.accepts(station_data,slot): return
	if is_armor and cursor.id != 0 and Nodes.armor_piece(cursor.id) != index: return
	if is_armor and cursor.count > 1 and slot.id != 0 and (slot.id != cursor.id or slot.get("data",{}) != cursor.get("data",{})):
		game.player.equip_armor(cursor); return
	if is_station and station == "brewing" and not Brewing.accepts(index,cursor.id): return
	if is_station and station == "furnace" and not FurnaceRules.accepts(station_data.slots,index,cursor.id): return
	if (Input.is_physical_key_pressed(KEY_SHIFT) or shift_mode) and cursor.id == 0 and slot.id != 0:
		if is_station or is_grid or is_armor:
			var exclude_start: int = -1; var exclude_end: int = -1
			if is_station and station_data.get("equipped",-1) >= 0:
				exclude_start = game.inventory.pouch_offset(station_data.equipped)
				exclude_end = exclude_start+station_data.slots.size()
			slot.count = game.inventory.add_item(slot.id,slot.count,slot.wear,slot.get("data",{}),exclude_start,exclude_end)
			if slot.count == 0: slot.id = 0; slot.wear = 0; slot.erase("data")
		elif Nodes.is_armor(slot.id) and game.player.armor_slots[Nodes.armor_piece(slot.id)].id == 0:
			game.player.equip_armor(slot)
		elif station in ["chest","brewing","furnace"]:
			if station_data.get("equipped",-1) >= 0:
				var offset: int = game.inventory.pouch_offset(station_data.equipped)
				if index >= offset and index < offset+station_data.slots.size(): return
			for destination_index in station_data.slots.size():
				if station == "brewing" and not Brewing.accepts(destination_index,slot.id): continue
				if station == "furnace" and not FurnaceRules.accepts(station_data.slots,destination_index,slot.id): continue
				var destination: Dictionary = station_data.slots[destination_index]
				if destination.id == 0 or (destination.id == slot.id and destination.wear == slot.wear and destination.get("data",{}) == slot.get("data",{})):
					var moved: int = mini(slot.count,Nodes.max_stack(slot.id)-int(destination.count))
					Inventory.copy_data(destination,slot)
					destination.id = slot.id; destination.wear = slot.wear; destination.count += moved; slot.count -= moved
					if slot.count == 0: slot.id=0; slot.wear=0; slot.erase("data"); break
		else:
			var start: int = 9 if index<9 else 0
			var end: int = (Inventory.BASE_SLOTS if PortableStorage.contains_kind(slot,false) else game.inventory.slots.size()) if index<9 else 9
			for j in range(start,end):
				if game.inventory.slots[j].id == 0:
					game.inventory.slots[j] = slot.duplicate(true)
					slot.id=0; slot.count=0; slot.wear=0; slot.erase("data")
					break
	elif cursor.id == 0:
		if slot.id == 0: return
		var taken: int = ceili(slot.count/2.0) if right else int(slot.count)
		cursor = slot.duplicate(true)
		cursor.count = taken
		slot.count -= taken
		if slot.count == 0: slot.id=0; slot.wear=0; slot.erase("data")
	elif slot.id == 0 or (slot.id == cursor.id and slot.wear == cursor.wear and slot.get("data",{}) == cursor.get("data",{})):
		var moved: int = mini(1 if right else int(cursor.count),(1 if is_armor else Nodes.max_stack(cursor.id))-int(slot.count))
		Inventory.copy_data(slot,cursor)
		slot.id=cursor.id; slot.wear=cursor.wear; slot.count += moved; cursor.count -= moved
		if cursor.count == 0: cursor={"id":0,"count":0,"wear":0}
	elif not right:
		var temp: Dictionary = slot.duplicate(true)
		Inventory.copy_data(slot,cursor)
		slot.id=cursor.id; slot.count=cursor.count; slot.wear=cursor.wear
		cursor=temp
	game.sound("equip" if is_armor else "click")
	game.inventory.changed.emit()

func return_cursor() -> void:
	game.survival.open_pouch_index = -1
	game.survival.open_equipped_pouch = -1
	for overflow in game.inventory.grid_to_inventory():
		game.spawn_drop(game.player.position+Vector3.UP,overflow.id,overflow.count,overflow.wear,overflow.get("data",{}))
	if cursor.id != 0:
		var rest: int = game.inventory.add_item(cursor.id,cursor.count,cursor.wear,cursor.get("data",{}))
		if rest>0: game.spawn_drop(game.player.position+Vector3.UP,cursor.id,rest,cursor.wear,cursor.get("data",{}))
	cursor={"id":0,"count":0,"wear":0}

func refresh_slots() -> void:
	for i in hotbar.size(): _update_icon(hotbar[i],game.inventory.slots[i],i==game.inventory.selected)
	for i in slots_ui.size():
		var index: int = inventory_indices[i]
		_update_icon(slots_ui[i],game.inventory.slots[index] if index >= 0 and index < game.inventory.slots.size() else {"id":0,"count":0,"wear":0},index==game.inventory.selected)
	for i in station_ui.size(): _update_icon(station_ui[i],station_data.slots[station_indices[i]],false)
	for i in pouch_ui.size():
		_update_icon(pouch_ui[i],game.inventory.pouch_slots[i],false)
		if game.inventory.pouch_slots[i].id == 0: pouch_ui[i].get_parent().tooltip_text = "Pouch slot %d / 3\nEquip a pouch to add its inventory pages."%(i+1)
	if is_instance_valid(offhand_ui): _update_icon(offhand_ui,game.player.offhand_slot,false)
	for i in armor_ui.size():
		_update_icon(armor_ui[i],game.player.armor_slots[i],false)
		if game.player.armor_slots[i].id == 0: armor_ui[i].get_parent().tooltip_text = Nodes.ARMOR_PIECES[i].capitalize()+" slot"
	if is_instance_valid(armor_label): armor_label.text = "%d / 20 defence\n%d toughness" % [game.player.armor_points(),game.player.armor_toughness()]
	if is_instance_valid(cursor_icon): _update_icon(cursor_icon,cursor,false)
	if screen=="inventory" and station in ["hand","table"]: _refresh_crafting()

func _update_icon(icon: ItemIcon, slot: Dictionary, selected_value: bool) -> void:
	icon.enchanted = not slot.get("data",{}).get("enchantments",{}).is_empty() and slot.id != 0
	icon.item_id=slot.id; icon.count=slot.count; icon.wear=slot.wear; icon.selected=selected_value
	if icon.get_parent() is Button:
		var description: String = str(slot.get("data",{}).get("custom_name",Nodes.title(slot.id))) if slot.id else "Empty slot"
		for enchant in slot.get("data",{}).get("enchantments",{}): description += "\n%s %d" % [enchant,slot.data.enchantments[enchant]]
		if Pouches.is_pouch(slot.id): description += "\n%d slots · Right click to open\nEquip in one of three pouch slots to extend inventory.\nCombine two of the same level to upgrade (maximum 5).\nCraft with wool or dye to recolor; contents are preserved."%Pouches.size_of(slot.id)
		if PotionCatalog.ITEMS.has(slot.id): description += "\n"+PotionCatalog.description(slot.id)
		if slot.id == Spyglass.ID: description += "\nHold right-click or Z to zoom. Touch: hold Use."
		if slot.id == FruitCrops.CARVED: description += "\nEquip in the helmet slot to avoid provoking Endermen with your gaze."
		if slot.get("data",{}).has("title"): description += "\n"+str(slot.data.title)
		icon.get_parent().tooltip_text = description

func show_death() -> void:
	_clear()
	screen="dead"
	_dim()
	var panel := _panel(layer,_panel_rect(Vector2(500,300)))
	_label(panel,"THE WILDERNESS REMEMBERS",Vector2(32,26),12,ACCENT)
	_label(panel,"A new beginning.",Vector2(32,53),32)
	var recovery: Dictionary = game.world.adventure_state.get("last_recovery",{})
	var message: String = "Your items are saved for a recovery chest."
	if not recovery.is_empty():
		var p: Array = recovery.position
		message = "Recovery chest · %s · %d, %d, %d"%[game.dimension.capitalize(),p[0],p[1],p[2]]
	message += "\nPouch contents stay packed. The chest persists."
	if game.game_rules.keepInventory: message = "Your inventory, pouches, armor and XP are kept."
	_label(panel,message,Vector2(32,113),14,MUTED,436)
	_button(panel,"Return to your spawn",Rect2(32,205,436,52),game.respawn)

func _dim() -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.025,0.025,0.025,0.76)
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
			if is_instance_valid(furnace_label) and station == "brewing": furnace_label.text = "Brewing %d%% · Fuel: %d / 20 batches"%[int(station_data.get("progress",0)*10),int(station_data.get("fuel_batches",0))]
			if is_instance_valid(furnace_label) and station == "furnace": furnace_label.text="Smelting  %d%%  ·  Fuel remaining: %ds" % [int(station_data.progress/8.0*100),int(station_data.burn)] if station_data.burn>0 else "Add ore or food, then coal, charcoal, wood or a lava bucket."
	queue_redraw()

# The powder snow frost, drawn as a vignette that deepens with the source's stage.
# Stage 1 is a faint icy edge, stage 2 spreads further in, and stage 3 closes over
# the corners, which is the source's three-stage warning before the freeze hurts.
const FROST_TINTS = [Color(0.78,0.88,0.95,0.16),Color(0.72,0.85,0.94,0.28),Color(0.68,0.82,0.94,0.42)]
const FROST_BANDS = [26.0,46.0,70.0]

func _draw_frost(stage_value: int) -> void:
	var index: int = clampi(stage_value,1,3)-1
	var tint: Color = FROST_TINTS[index]
	var band: float = FROST_BANDS[index]
	# Four bands, one per edge, laid as gradients of decreasing alpha toward the
	# middle so the frost reads as creeping in rather than as a flat border.
	var steps: int = 6
	for i in steps:
		var depth: float = band*float(i+1)/float(steps)
		var alpha: float = tint.a*float(steps-i)/float(steps)
		var edge := Color(tint.r,tint.g,tint.b,alpha)
		# Top and bottom.
		draw_rect(Rect2(0,depth-band/float(steps),size.x,band/float(steps)),edge)
		draw_rect(Rect2(0,size.y-depth,size.x,band/float(steps)),edge)
		# Left and right.
		draw_rect(Rect2(depth-band/float(steps),0,band/float(steps),size.y),edge)
		draw_rect(Rect2(size.x-depth,0,band/float(steps),size.y),edge)

func _draw() -> void:
	if game == null: return
	var font: Font = ThemeDB.fallback_font
	if screen == "game":
		var player: VoxeyPlayer = game.player
		var center: Vector2 = size*0.5
		if player.underwater: draw_rect(Rect2(Vector2.ZERO,size),Color(0.12,0.4,0.62,0.28))
		# Powder snow frosts the edges of the screen in three stages, which is the
		# source's warning that the freeze is deepening. The source draws four
		# corner images; a perimeter vignette gives the same warning from the same
		# stage value.
		var frost: int = PowderSnow.stage(PowderSnow.time_in_snow(player))
		if frost > 0: _draw_frost(frost)
		if PumpkinHelmet.worn(player): PumpkinHelmet.draw(self)
		if player.scoping: Spyglass.draw_scope(self)
		draw_line(center-Vector2(6,0),center+Vector2(6,0),Color(0.94,0.95,0.85,0.85),2)
		draw_line(center-Vector2(0,6),center+Vector2(0,6),Color(0.94,0.95,0.85,0.85),2)
		draw_style_box(_style(Color(0.12,0.12,0.12,0.76),Color(0.6,0.6,0.6,0.2),1),Rect2(24,24,253,65))
		draw_string(font,Vector2(40,48),"V /  "+("Deepslate caverns" if game.dimension == "overworld" and player.position.y < -32 else ("Deep caves" if game.dimension == "overworld" and player.position.y < 0 else game.world.generator.biome(int(player.position.x),int(player.position.z)))),HORIZONTAL_ALIGNMENT_LEFT,-1,16,TEXT)
		draw_string(font,Vector2(40,72),"%d   /   %d   /   %d" % [player.position.x,player.position.y,player.position.z],HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
		var time_label: String = "THE END" if game.dimension == "end" else "THE NETHER" if game.dimension == "nether" else "DAY %d  ·  %s" % [game.day_number(),game.time_name()]
		draw_style_box(_style(Color(0.12,0.12,0.12,0.76)),Rect2(size.x-217,24,193,45))
		draw_circle(Vector2(size.x-193,46),7,Color("e8cc80") if game.daylight>0.4 else Color("bdcede"))
		draw_string(font,Vector2(size.x-175,51),time_label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,TEXT)
		if not player.target.is_empty():
			var node_name: String = Nodes.title(player.target.id)
			var width: float = font.get_string_size(node_name,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+36
			draw_style_box(_style(Color(0.12,0.12,0.12,0.8)),Rect2(center.x-width/2,30,width,35))
			draw_string(font,Vector2(center.x-width/2+18,53),node_name,HORIZONTAL_ALIGNMENT_LEFT,-1,15,TEXT)
			if not Nodes.harvestable(player.target.id,game.inventory.held().id):
				draw_string(font,Vector2(center.x-100,84),"A better pickaxe is needed",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e0b07a"))
			if player.mining>0:
				draw_rect(Rect2(center+Vector2(-24,20),Vector2(48,3)),Color(0,0,0,0.4))
				draw_rect(Rect2(center+Vector2(-24,20),Vector2(48*player.mining,3)),ACCENT)
		if game.dimension == "end" and not game.world.adventure_state.get("defeated",false) and Vector2(player.position.x,player.position.z).length() < 110:
			var boss_width: float = minf(360,size.x*0.42)
			var boss_health: float = float(game.world.adventure_state.get("dragon_health",200))
			draw_string(font,Vector2(center.x-boss_width/2,106),"ENDER DRAGON",HORIZONTAL_ALIGNMENT_CENTER,boss_width,15,Color("e1b5ef"))
			draw_rect(Rect2(center.x-boss_width/2,116,boss_width,8),Color("31233e"))
			draw_rect(Rect2(center.x-boss_width/2,116,boss_width*clampf(boss_health/200,0,1),8),Color("b975d3"))
			var remaining: int = 10-game.world.adventure_state.get("destroyed_crystals",[]).size()
			draw_string(font,Vector2(center.x-boss_width/2,143),"%d / 10 healing crystals remain" % remaining,HORIZONTAL_ALIGNMENT_CENTER,boss_width,12,Color("c7b5cf"))
		# Status bar shrinks on phones so the touch buttons stay clear.
		var bar_scale: float = _hud_scale()
		var bar_w: float = 536.0*bar_scale
		var bar_h: float = 107.0*bar_scale
		var bar_y: float = size.y-bar_h-(62.0 if game.touch else 0.0)
		draw_style_box(_style(Color(0.12,0.12,0.12,0.84),Color(0.6,0.6,0.6,0.5),1),Rect2(center.x-bar_w*0.5,bar_y,bar_w,bar_h))
		var left: float = center.x-255.0*bar_scale
		var row_y: float = bar_y+16.0*bar_scale
		for i in (10 if game.gamemode=="survival" else 0):
			_heart(Vector2(left+8+i*20*bar_scale,row_y),i<float(player.health)/2.0)
			_food(Vector2(center.x+63.0*bar_scale+i*19*bar_scale,row_y),i<float(player.hunger)/2.0)
		if game.gamemode=="creative": draw_string(font,Vector2(center.x-244.0*bar_scale,bar_y+21.0*bar_scale),"CREATIVE  ·  "+("FLYING  /  ▲ ✈" if player.flying else "TAP ✈ TO FLY")+"  ·  / CONSOLE",HORIZONTAL_ALIGNMENT_LEFT,-1,11,ACCENT)
		draw_rect(Rect2(center.x-254.0*bar_scale,bar_y+31.0*bar_scale,508.0*bar_scale,3),Color("263c2b"))
		draw_rect(Rect2(center.x-254.0*bar_scale,bar_y+31.0*bar_scale,508.0*bar_scale*game.xp_progress(),3),Color("a6be69"))
		draw_string(font,Vector2(center.x-20,bar_y+22*bar_scale),str(game.xp_level()),HORIZONTAL_ALIGNMENT_CENTER,40,16,Color("b9e17c"))
		if player.levitation > 0: draw_string(font,Vector2(center.x-70,bar_y-50),"Levitation · %ds" % ceili(player.levitation),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d8b7e4"))
		elif player.gliding: draw_string(font,Vector2(center.x-55,bar_y-50),"ELYTRA GLIDING",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("d8b7e4"))
		var effect_row: int = 0
		for effect in game.survival.effects:
			var duration: int = ceili(game.survival.effects[effect])
			var effect_text: String = "%s %d · %d:%02d"%[String(effect).replace("_"," ").capitalize(),PotionEffects.level(player,effect),duration/60,duration%60]
			if effect == "absorption": effect_text += " · %s HP"%str(snappedf(PotionEffects.absorption(player),0.5))
			draw_string(font,Vector2(size.x-260,180+effect_row*19),effect_text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e6c96b") if effect == "absorption" else Color("c9d9ab"))
			effect_row += 1
		if game.world.adventure_state.has("raid"):
			var raid: Dictionary = game.world.adventure_state.raid
			draw_string(font,Vector2(center.x-140,160),"RAID · Wave %d / 3 · %d pillagers"%[int(raid.wave),int(raid.get("alive",0))],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e8aaa0"))
		var selected_name: String = str(game.inventory.held().get("data",{}).get("custom_name",Nodes.title(game.inventory.held().id))) if game.inventory.held().id else "Empty hand"
		var text_width: float = font.get_string_size(selected_name,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_style_box(_style(Color(0.12,0.12,0.12,0.8)),Rect2(center.x-text_width/2-14,bar_y-32,text_width+28,32))
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
			draw_style_box(_style(Color(0.12,0.12,0.12,0.78)),Rect2(24,size.y-177,286,85))
			draw_string(font,Vector2(40,size.y-151),tasks[game.journal_step][0],HORIZONTAL_ALIGNMENT_LEFT,-1,11,ACCENT)
			draw_string(font,Vector2(40,size.y-125),tasks[game.journal_step][1],HORIZONTAL_ALIGNMENT_LEFT,-1,13,TEXT)
		if not game.touch:
			draw_style_box(_style(Color(0.12,0.12,0.12,0.75)),Rect2(size.x-236,size.y-89,212,65))
			draw_string(font,Vector2(size.x-223,size.y-64),"E  Inventory     ESC  Pause",HORIZONTAL_ALIGNMENT_LEFT,-1,12,TEXT)
			draw_string(font,Vector2(size.x-223,size.y-41),"LMB  Mine       RMB  Use",HORIZONTAL_ALIGNMENT_LEFT,-1,12,MUTED)
		if debug:
			var info: String = "%d FPS  ·  %d map blocks  ·  %d columns\n%d generation jobs  ·  %d remesh jobs\nSeed %d  ·  Greedy meshing  ·  16³ nodes / block" % [Engine.get_frames_per_second(),game.world.blocks.size(),game.world.columns.size(),game.world.jobs.size(),game.world.remesh_jobs.size(),game.world.seed_value]
			info += "\nGPU: "+RenderingServer.get_video_adapter_name()+"\nRenderer: "+RenderingServer.get_current_rendering_method()
			draw_style_box(_style(Color(0,0,0,0.72)),Rect2(24,105,510,130))
			for i in 5: draw_string(font,Vector2(36,129+i*23),info.split("\n")[i],HORIZONTAL_ALIGNMENT_LEFT,-1,13,TEXT)
		if flash>0: draw_rect(Rect2(Vector2.ZERO,size),Color(0.6,0.15,0.1,flash*0.6))
	if toast_time>0:
		var width: float = font.get_string_size(toast_text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+40
		draw_style_box(_style(Color(0.12,0.12,0.12,0.95),Color("858585"),1),Rect2(size.x/2-width/2,100,width,42))
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
		var rest: int=game.inventory.add_item(cursor.id,cursor.count,cursor.wear,cursor.get("data",{}))
		if rest>0: game.spawn_drop(game.player.position+Vector3.UP,cursor.id,rest,cursor.wear,cursor.get("data",{}))
	cursor={"id":id,"count":Nodes.max_stack(id),"wear":0}
	game.sound("click")
	refresh_slots()

func show_worlds() -> void:
	_clear()
	screen="worlds"
	_dim()
	var panel := _fitted_panel(Vector2(900,560))
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
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.text="          "+String(entry.name)+"\n          Day %d  ·  Seed %s  ·  %s" % [int(entry.get("day",1)),str(entry.seed),String(entry.get("mode","survival")).capitalize()]
		button.add_theme_font_size_override("font_size",15)
		button.pressed.connect(_world_details.bind(entry))
		list.add_child(button)
		var icon := ItemIcon.new()
		icon.position=Vector2(12,13); icon.size=Vector2(51,51); icon.item_id=Nodes.GRASS; icon.show_slot=false
		button.add_child(icon)
	if worlds.is_empty(): _label(list,"Your next adventure starts here.\nCreate a world to begin.",Vector2.ZERO,17,MUTED)
	world_detail=_panel(panel,Rect2(552,110,318,355),Color("383838"))
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
	var name_label: Label = _label(world_detail,String(entry.name),Vector2(24,23),22,TEXT,267)
	name_label.max_lines_visible = 2
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label(world_detail,"CHOOSE HOW TO PLAY",Vector2(24,98),11,ACCENT)
	var mode := OptionButton.new()
	mode.position=Vector2(24,125); mode.size=Vector2(270,43)
	mode.add_item("Survival"); mode.add_item("Creative")
	mode.selected=1 if entry.get("mode","survival")=="creative" else 0
	world_detail.add_child(mode)
	_label(world_detail,"Survival: gather, craft, and stay alive.\nCreative: all items, flight, and no damage.\n\nChange anytime with /gamemode.",Vector2(24,188),13,MUTED,270)
	_button(world_detail,"Enter world  →",Rect2(24,288,160,45),func(): game.enter_world(entry.id,"creative" if mode.selected==1 else "survival"))
	_button(world_detail,"Delete…",Rect2(196,288,98,45),show_delete_world.bind(entry))

func show_delete_world(entry: Dictionary) -> void:
	delete_world_entry = entry.duplicate(true)
	_clear()
	screen = "delete_world"
	_dim()
	var panel: Panel = _fitted_panel(Vector2(560,340))
	_label(panel,"Delete this world?",Vector2(30,26),28)
	_label(panel,String(entry.get("name","World")),Vector2(30,82),22,TEXT,500)
	_label(panel,"This deletes its terrain, items, dimensions and backups.\nThis cannot be undone.",Vector2(30,171),15,MUTED,500)
	var cancel: Button = _button(panel,"Cancel",Rect2(30,265,236,45),show_worlds)
	_button(panel,"Delete world",Rect2(282,265,248,45),func():
		if game.delete_world(str(entry.get("id",""))): show_worlds())
	cancel.grab_focus()

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

func show_enchanting(p: Vector3i, selected_item: int = -1, selected_enchantment: String = "") -> void:
	enchanting_pos = p
	_clear(); screen = "enchanting"; _dim()
	var panel := _fitted_panel(Vector2(720,540))
	_label(panel,"ENCHANTING",Vector2(28,22),26,Color("d5b5f0"))
	_label(panel,"Level %d · %d lapis lazuli · %d / 15 bookshelves" % [game.xp_level(),game.inventory.count_item(Nodes.LAPIS),game.bookshelf_power(p)],Vector2(28,65),16,ACCENT)
	_label(panel,"Choose equipment from your inventory",Vector2(28,105),15,MUTED)
	var available: Array = []
	for i in game.inventory.slots.size():
		var slot: Dictionary = game.inventory.slots[i]
		if not Enchantments.choices(slot.id,true).is_empty(): available.append(i)
	if not available.has(selected_item): selected_item = available[0] if not available.is_empty() else -1
	var picker := OptionButton.new()
	picker.position = Vector2(28,138); picker.size = Vector2(660,42)
	for i in available.size():
		picker.add_item(Nodes.title(game.inventory.slots[available[i]].id)+" · slot "+str(available[i]+1),available[i])
		if available[i] == selected_item: picker.select(i)
	picker.disabled = available.is_empty()
	if available.is_empty(): picker.add_item("Bring a tool, sword, bow or piece of armor")
	panel.add_child(picker)
	picker.item_selected.connect(func(index: int): show_enchanting(p,picker.get_item_id(index)))
	var names: Array = Enchantments.choices(game.inventory.slots[selected_item].id,true) if selected_item >= 0 else []
	var enchant_picker := OptionButton.new(); enchant_picker.position = Vector2(28,187); enchant_picker.size = Vector2(660,35)
	for name in names: enchant_picker.add_item(name)
	if not names.has(selected_enchantment): selected_enchantment = names[0] if not names.is_empty() else ""
	if not names.is_empty(): enchant_picker.select(names.find(selected_enchantment))
	enchant_picker.disabled = names.is_empty(); panel.add_child(enchant_picker)
	enchant_picker.item_selected.connect(func(index: int): show_enchanting(p,selected_item,names[index]))
	for tier in range(1,4):
		var chosen: int = selected_item
		var strength: int = tier
		var label: String = "%s · Requires level %d · Costs %d lapis + %d XP level(s)" % [["I","II","III"][tier-1],[1,10,30][tier-1],tier,tier]
		var button := _button(panel,label,Rect2(28,233+(tier-1)*50,660,42),func():
			game.enchant_item(chosen,strength,p,selected_enchantment)
			show_enchanting(p,chosen,selected_enchantment))
		button.disabled = chosen < 0 or game.bookshelf_power(p) < [0,5,15][tier-1] or (game.gamemode != "creative" and (game.xp_level() < [1,10,30][tier-1] or game.inventory.count_item(Nodes.LAPIS) < tier))
	_label(panel,"Bookshelves need a one-block air gap. Tiers II / III need 5 / 15 shelves.\nChoose an enchantment; combine equal-level books at an anvil for higher levels.\nTreasure enchantments and curses come from trades and loot.",Vector2(28,390),14,MUTED,660)
	_button(panel,"Done",Rect2(28,478,660,40),game.resume)

func show_book(index: int) -> void:
	book_index = index
	_clear(); screen = "book"; _dim()
	var panel := _fitted_panel(Vector2(720,570),Color("3c342e"))
	var slot: Dictionary = game.inventory.slots[index]
	var writable: bool = slot.id == Nodes.WRITABLE_BOOK
	var metadata: Dictionary = slot.get("data",{})
	_label(panel,"BOOK & QUILL" if writable else "WRITTEN BOOK",Vector2(28,20),24,Color("e7cd9c"))
	var title_field := LineEdit.new()
	title_field.position = Vector2(28,66); title_field.size = Vector2(664,42)
	title_field.placeholder_text = "Give your book a title"; title_field.max_length = 64
	title_field.text = str(metadata.get("title","")); title_field.editable = writable
	panel.add_child(title_field)
	var editor := TextEdit.new()
	editor.position = Vector2(28,124); editor.size = Vector2(664,350)
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.text = str(metadata.get("text","")); editor.editable = writable
	editor.add_theme_color_override("font_color",Color("eee2c6"))
	editor.add_theme_stylebox_override("normal",_style(Color("292722")))
	panel.add_child(editor)
	var count_label := _label(panel,"",Vector2(28,482),12,MUTED)
	var save_draft: Callable = func():
		if not writable: return
		if editor.text.length() > 12000: editor.text = editor.text.left(12000)
		slot["data"] = {"title":title_field.text,"text":editor.text}
		count_label.text = "%d / 12000 characters · Draft saved automatically" % editor.text.length()
	save_draft.call()
	editor.text_changed.connect(save_draft)
	title_field.text_changed.connect(func(_text: String): save_draft.call())
	if writable:
		_button(panel,"Sign & finish (locks editing)",Rect2(28,518,370,36),func():
			save_draft.call()
			slot.id = Nodes.WRITTEN_BOOK
			game.inventory.changed.emit()
			game.resume())
	_button(panel,"Close",Rect2(426,518,266,36),game.resume)

func _fitted_panel(design: Vector2, color: Color = PANEL) -> Panel:
	var factor: float = minf(1.0,minf((size.x-16)/design.x,(size.y-16)/design.y))
	var panel := _panel(layer,Rect2((size-design*factor)*0.5,design),color)
	panel.scale = Vector2.ONE*factor
	return panel

func pointer_outside_inventory() -> bool:
	return is_instance_valid(inventory_panel) and not inventory_panel.get_global_rect().has_point(get_global_mouse_position())

func drop_cursor(one: bool = true) -> void:
	game.drop_stack(cursor,1 if one else int(cursor.count))
	refresh_slots()

func drop_hovered_one() -> void:
	if cursor.id != 0: drop_cursor(true); return
	var pointer: Vector2 = get_global_mouse_position()
	for collection in [slots_ui,station_ui,armor_ui,pouch_ui]:
		for i in collection.size():
			if collection[i].get_parent().get_global_rect().has_point(pointer):
				var index: int = inventory_indices[i] if collection == slots_ui else (station_indices[i] if collection == station_ui else i)
				if index < 0: return
				var source: Array = game.inventory.slots if collection == slots_ui else (station_data.slots if collection == station_ui else (game.inventory.pouch_slots if collection == pouch_ui else game.player.armor_slots))
				if collection == slots_ui and index == game.survival.open_pouch_index: return
				if collection == pouch_ui:
					if game.survival.open_pouch_index >= 0 or game.survival.open_equipped_pouch >= 0: return
					var pouch: Dictionary = game.inventory.exchange_pouch(index,{"id":0,"count":0,"wear":0})
					game.drop_stack(pouch,1); show_inventory(station,station_data); return
				if collection == armor_ui and game.gamemode != "creative" and Inventory.enchantment(source[index],"Curse of Binding") > 0: return
				game.drop_stack(source[index],1)
				return
	for entry in grid_ui:
		if entry.icon.get_parent().get_global_rect().has_point(pointer): game.drop_stack(game.inventory.grid[entry.index],1); return

func show_trading(key: String, selected_offer: int = -1) -> void:
	var person: Dictionary = game.villages.record(key)
	if person.is_empty(): game.resume(); return
	_clear(); screen = "trading"; _dim()
	var panel := _fitted_panel(Vector2(900,620))
	var level: int = person.level
	_label(panel,person.profession.to_upper()+"  ·  "+VillageContent.RANKS[level-1],Vector2(28,20),26,ACCENT)
	_label(panel,"%d emeralds  ·  %d villager XP  ·  %d restocks remaining"%[game.inventory.count_item(VillageContent.EMERALD),person.xp,person.restocks],Vector2(28,60),15,MUTED)
	var bar := ProgressBar.new(); bar.position = Vector2(28,89); bar.size = Vector2(844,12); bar.show_percentage = false
	bar.max_value = VillageContent.LEVELS[level]-VillageContent.LEVELS[level-1] if level < 5 else 1
	bar.value = person.xp-VillageContent.LEVELS[level-1] if level < 5 else 1; panel.add_child(bar)
	_label(panel,"PAY",Vector2(28,121),13,MUTED)
	_label(panel,"RECEIVE",Vector2(270,121),13,MUTED)
	_label(panel,"STOCK",Vector2(585,121),13,MUTED)
	var scroll := ScrollContainer.new(); scroll.position = Vector2(22,151); scroll.size = Vector2(856,380); panel.add_child(scroll)
	var rows := VBoxContainer.new(); rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation",5); scroll.add_child(rows)
	var last_tier: int = 0; var scroll_to: int = 0
	for i in person.offers.size():
		var offer: Dictionary = person.offers[i]
		if offer.tier != last_tier:
			last_tier = offer.tier
			var heading := Label.new(); heading.text = VillageContent.RANKS[last_tier-1]+(" · locked" if last_tier > level else ""); heading.add_theme_color_override("font_color",MUTED); rows.add_child(heading)
		var row := Panel.new(); row.custom_minimum_size = Vector2(820,61); row.add_theme_stylebox_override("panel",_style(Color("484848") if offer.tier <= level else Color("383838"))); rows.add_child(row)
		var x: float = 12
		for cost in game.villages.costs(person,offer):
			_trade_icon(row,cost[0],cost[1],Vector2(x,9),{}); x += 85
		_label(row,"→",Vector2(206,16),23,ACCENT)
		_trade_icon(row,offer.give[0],offer.give[1],Vector2(248,9),offer.data)
		var title: String = Nodes.title(offer.give[0])
		if not offer.data.is_empty(): title += " ✦"
		_label(row,title,Vector2(302,9),15,TEXT,260)
		_label(row,"+%d XP"%int(offer.xp),Vector2(302,33),12,MUTED)
		_label(row,"%d / %d"%[maxi(0,int(offer.stock)-int(offer.uses)),offer.stock],Vector2(563,20),14,MUTED)
		var index: int = i
		var reason: String = game.villages.transaction(person,offer)
		var button := _button(row,"Trade",Rect2(638,10,86,40),func(): game.villages.trade(key,index))
		button.disabled = not reason.is_empty(); button.tooltip_text = reason if not reason.is_empty() else "Make this trade once."
		var batch := _button(row,"Max",Rect2(731,10,63,40),func(): game.villages.trade(key,index,true))
		batch.disabled = button.disabled; batch.tooltip_text = "Trade until supplies, stock or inventory space run out."
		if selected_offer == i: scroll_to = maxi(0,int(i*66)-100)
	if selected_offer >= 0: scroll.set_deferred("scroll_vertical",scroll_to)
	_label(panel,"Workplaces replenish stock twice per day. Frequent trades build reputation.\nHigher demand raises prices. Unlocked offers and stock survive saving and travel.",Vector2(28,542),13,MUTED,650)
	_button(panel,"Done",Rect2(736,551,136,43),game.resume)

func _trade_icon(parent: Control, id: int, count: int, at: Vector2, data: Dictionary) -> void:
	var icon := ItemIcon.new(); icon.position = at; icon.size = Vector2(42,42); parent.add_child(icon)
	_update_icon(icon,{"id":id,"count":1,"wear":0,"data":data},false)
	icon.tooltip_text = Nodes.title(id)+(str(data.enchantments) if data.has("enchantments") else "")
	_label(parent,"×%d"%count,at+Vector2(45,12),14,TEXT)

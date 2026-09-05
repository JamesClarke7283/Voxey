class_name TouchControls
extends Control

## On-screen controls for touch devices. Owns the virtual joystick, look-drag
## surface, and action buttons. The player reads `stick`, `jump_held`,
## `sneak_held`, `mine_held`, and `use_pressed` each physics frame; everything
## here is pure state relay — gameplay stays in the player controller.
##
## Layout (landscape phone, 800×360 baseline, safe-area aware):
##   bottom-left joystick   ·  bottom-right buttons (jump, sneak, fly)
##   bottom-right pair       ·  top-right system buttons (pause, chat, drop)

const STICK_RADIUS: float = 58.0
const BUTTON_SIZE: float = 62.0

var game: Node3D
var stick := Vector2.ZERO            # normalized -1..1 movement vector
var jump_held: bool = false
var sneak_held: bool = false
var mine_held: bool = false
var use_pressed: bool = false
var _stick_origin := Vector2.ZERO
var _stick_touch: int = -1
var _look_touch: int = -1
var _last_jump_tap: int = 0
var stick_base: Control
var stick_nub: Control
var button_box: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_stick()
	_build_buttons()
	hide_all()

func _safe_top() -> float:
	return DisplayServer.get_display_safe_area().position.y if DisplayServer.get_name() in ["Android","iOS"] else 0.0

func _build_stick() -> void:
	stick_base = Control.new()
	stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stick_base)
	var ring := Panel.new()
	ring.size = Vector2.ONE*STICK_RADIUS*2.0
	ring.add_theme_stylebox_override("panel",_ring_style(Color(0.05,0.1,0.08,0.35),Color(0.85,0.9,0.8,0.35)))
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick_base.add_child(ring)
	stick_nub = Panel.new()
	stick_nub.size = Vector2.ONE*56.0
	stick_nub.position = Vector2.ONE*(STICK_RADIUS*2.0-56.0)*0.5
	stick_nub.add_theme_stylebox_override("panel",_ring_style(Color(0.9,0.93,0.85,0.5),Color(0.95,0.97,0.9,0.6)))
	stick_nub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(stick_nub)

func _ring_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(90)
	return style

func _touch_button(label: String, callback: Callable, toggle: bool = false) -> TouchButton:
	var button := TouchButton.new()
	button.text = label
	button.toggle_mode = toggle
	button.custom_minimum_size = Vector2.ONE*BUTTON_SIZE
	button.add_theme_font_size_override("font_size",17)
	button.add_theme_color_override("font_pressed_color",Color("becb82"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05,0.1,0.08,0.42)
	style.border_color = Color(0.85,0.9,0.8,0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	for state in ["normal","hover","pressed","focus"]:
		button.add_theme_stylebox_override(state,style.duplicate())
	var pressed_style: StyleBoxFlat = style.duplicate()
	pressed_style.bg_color = Color(0.2,0.32,0.18,0.7)
	pressed_style.border_color = Color("becb82")
	button.add_theme_stylebox_override("pressed",pressed_style)
	button.pressed.connect(callback)
	return button

func _build_buttons() -> void:
	button_box = Control.new()
	button_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(button_box)

func show_game_controls() -> void:
	visible = true
	# Rebuild layout against the current viewport (handles rotation).
	for child in button_box.get_children(): child.queue_free()
	var view: Vector2 = size
	if view.x < 10: view = Vector2(get_viewport_rect().size)
	var edge: float = 18.0
	stick_base.position = Vector2(edge,view.y-STICK_RADIUS*2.0-edge)
	# Jump bottom-right; sneak beside it; fly above (creative only).
	var jump := _touch_button("▲",_on_jump)
	jump.position = Vector2(view.x-BUTTON_SIZE-edge,view.y-BUTTON_SIZE-edge)
	button_box.add_child(jump)
	var sneak := _touch_button("⬇",_on_sneak_press,false)
	sneak.position = jump.position+Vector2(-BUTTON_SIZE-14,0)
	button_box.add_child(sneak)
	# Action buttons: mine (hold) and use (tap), above jump.
	var mine := _touch_button("⛏",func(): pass)
	mine.position = jump.position+Vector2(0,-BUTTON_SIZE-14)
	mine.button_down.connect(func(): mine_held=true)
	mine.button_up.connect(func(): mine_held=false)
	button_box.add_child(mine)
	var use := _touch_button("✋",_on_use_press,false)
	use.position = mine.position+Vector2(-BUTTON_SIZE-14,0)
	button_box.add_child(use)
	if game.gamemode=="creative":
		var fly := _touch_button("✈",_on_fly_tap,false)
		fly.position = Vector2(view.x-BUTTON_SIZE-edge,sneak.position.y-BUTTON_SIZE-14)
		button_box.add_child(fly)
	# System buttons: a vertical column on the right edge, below the clock
	# panel, so nothing overlaps.
	var top: float = _safe_top()+78.0
	var column_x: float = view.x-52-edge
	var pause := _touch_button("❚❚",func(): game.pause())
	pause.custom_minimum_size = Vector2(52,52)
	pause.position = Vector2(column_x,top)
	button_box.add_child(pause)
	var bag := _touch_button("≡",func(): game.open_inventory())
	bag.custom_minimum_size = Vector2(52,52)
	bag.position = Vector2(column_x,top+66)
	button_box.add_child(bag)
	var chat := _touch_button("/",func(): game.open_console("/"))
	chat.custom_minimum_size = Vector2(52,52)
	chat.position = Vector2(column_x,top+132)
	button_box.add_child(chat)
	var drop := _touch_button("↓",func():
		if game.inventory.held().id!=0:
			var slot: Dictionary=game.inventory.held()
			game.spawn_drop(game.player.camera.global_position-game.player.camera.global_basis.z,slot.id,1,slot.wear)
			game.inventory.consume_selected())
	drop.custom_minimum_size = Vector2(52,52)
	drop.position = Vector2(column_x,top+198)
	button_box.add_child(drop)

func hide_all() -> void:
	visible = false
	_reset()

func _reset() -> void:
	stick = Vector2.ZERO
	jump_held = false
	sneak_held = false
	mine_held = false
	use_pressed = false
	_stick_touch = -1
	_look_touch = -1
	if is_instance_valid(stick_nub): stick_nub.position = Vector2.ONE*(STICK_RADIUS*2.0-56.0)*0.5

# Joystick: touch down on the lower-left quadrant grabs the stick; the nub
# follows the finger and produces a normalized direction. Uses raw _input so
# the Control can live under a plain Node3D without GUI focus games.
func _input(event: InputEvent) -> void:
	if not visible or game == null or not game.playing(): return
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed and _stick_touch < 0 and pos.x < size.x*0.45 and pos.y > size.y*0.4 and not _hit_test(pos):
			_stick_touch = event.index
			_stick_origin = pos
			stick_base.position = pos-STICK_RADIUS*Vector2.ONE
		elif not event.pressed and event.index == _stick_touch:
			_stick_touch = -1
			stick = Vector2.ZERO
			stick_base.position = Vector2(18.0,size.y-STICK_RADIUS*2.0-18.0)
			stick_nub.position = Vector2.ONE*(STICK_RADIUS*2.0-56.0)*0.5
	elif event is InputEventScreenDrag and event.index == _stick_touch:
		var offset: Vector2 = event.position-_stick_origin
		if offset.length() > STICK_RADIUS: offset = offset.normalized()*STICK_RADIUS
		stick = offset/STICK_RADIUS
		stick_nub.position = Vector2.ONE*(STICK_RADIUS*2.0-56.0)*0.5+offset

func _on_jump() -> void:
	jump_held = true
	var now: int = Time.get_ticks_msec()
	if now-_last_jump_tap < 300 and game.gamemode=="creative": game.player.flying = not game.player.flying; game.player.velocity=Vector3.ZERO
	_last_jump_tap = now
	get_tree().create_timer(0.25).timeout.connect(func(): jump_held = false)

func _on_sneak_press() -> void:
	sneak_held = not sneak_held

func _on_use_press() -> void:
	use_pressed = true

func _on_fly_tap() -> void:
	game.player.flying = not game.player.flying
	game.player.velocity=Vector3.ZERO

# Buttons consume touches; the rest of this full-rect control passes drags to
# the game for camera look.
func _hit_test(pos: Vector2) -> bool:
	for button in button_box.get_children():
		if button is TouchButton and Rect2(button.position,button.size).has_point(pos): return true
	return false
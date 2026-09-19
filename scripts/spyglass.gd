class_name Spyglass
extends RefCounted

# Local Mineclonia mcl_spyglass/init.lua: absolute8-degree FOV while RMB or
# zoom is held, with node right-click actions taking priority on initial use.
const ID = 7890
const FOV = 8.0
const DATA = {7890:{"name":"Spyglass","color":"bb8353","stack":1,"family":"spyglass"}}

static func recipes(inv: Inventory) -> void:
	inv._recipe("Spyglass",ID,1,[7705,Nodes.COPPER,Nodes.COPPER],1,"table")

static func request(player: VoxeyPlayer) -> bool:
	if int(player.game.inventory.held().id) != ID: return false
	player.spyglass_blocked = false
	return true

static func reset(player: VoxeyPlayer) -> void:
	set_active(player,false)
	player.spyglass_held = false
	player.spyglass_blocked = false

static func set_active(player: VoxeyPlayer, active: bool) -> void:
	if player.scoping == active: return
	player.scoping = active
	player.camera.fov = FOV if active else 78.0
	player.hand.visible = not active

static func update(player: VoxeyPlayer, use_held: bool, zoom_held: bool) -> bool:
	if not player.game.playing() or player.health <= 0 or int(player.game.inventory.held().id) != ID:
		reset(player)
		return false
	# A held spyglass must not reopen/toggle an interactable every quarter second.
	# Normal use dispatch reaches request only when no block action consumed it.
	if use_held and not player.spyglass_held and not player.scoping:
		player.spyglass_blocked = true
		player.use()
	player.spyglass_held = use_held
	set_active(player,player.game.playing() and (use_held or zoom_held) and not player.spyglass_blocked)
	return true

static func draw(img: Image) -> void:
	ItemArt._polygon(img,[[2,11],[10,3],[14,7],[6,15]],Color("845337"))
	ItemArt._polygon(img,[[3,10],[9,4],[13,8],[7,14]],Color("c78950"))
	ItemArt._line(img,Vector2(4,11),Vector2(10,5),Color("e9c18a"),2)
	ItemArt._polygon(img,[[0,10],[3,7],[8,12],[5,15]],Color("d8b05d"))
	ItemArt._polygon(img,[[9,3],[12,0],[15,3],[12,6]],Color("e6c57c"))
	ItemArt._polygon(img,[[11,3],[12,2],[14,3],[12,5]],Color("7bbdcc"))
	img.set_pixel(12,2,Color("d3eeec"))

static func draw_scope(control: Control) -> void:
	var center: Vector2 = control.size*0.5
	var radius: float = minf(control.size.x,control.size.y)*0.43
	# An original circular aperture, with an opaque surrounding mask at every
	# aspect ratio. HUD status/controls remain drawn above this overlay.
	for i in 96:
		var a: Vector2 = Vector2.from_angle(TAU*i/96.0)
		var b: Vector2 = Vector2.from_angle(TAU*(i+1)/96.0)
		var outer: float = control.size.length()
		control.draw_colored_polygon(PackedVector2Array([center+a*radius,center+a*outer,center+b*outer,center+b*radius]),Color.BLACK)
	control.draw_arc(center,radius,0,TAU,97,Color("42392c"),10,true)
	control.draw_arc(center,radius-5,0,TAU,97,Color("b28b52"),2,true)
	control.draw_arc(center,radius+5,0,TAU,97,Color("d5bc7f"),2,true)

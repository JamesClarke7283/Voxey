class_name ItemIcon
extends Control

var item_id: int = 0:
	set(value): item_id = value; queue_redraw()
var count: int = 0:
	set(value): count = value; queue_redraw()
var wear: int = 0:
	set(value): wear = value; queue_redraw()
var selected: bool = false:
	set(value): selected = value; queue_redraw()
var show_slot: bool = true
var number: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO,size)
	if show_slot:
		draw_style_box(_style(Color("344237") if selected else Color("202b26"),Color("d1bf83") if selected else Color("4d5b47"),2 if selected else 1),rect)
		if selected: draw_rect(Rect2(3,size.y-5,size.x-6,2),Color("dbca93"))
	if not number.is_empty(): draw_string(ThemeDB.fallback_font,Vector2(6,14),number,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("889584"))
	if item_id == 0: return
	var center: Vector2 = size*Vector2(0.5,0.47)
	var scale_value: float = minf(size.x,size.y)*0.027
	if Nodes.placeable(item_id) or item_id in [Nodes.WATER,Nodes.BEDROCK,Nodes.RIPE_WHEAT]:
		if Art.atlas_texture == null: Art.make_atlas()
		var s: float = scale_value
		if Nodes.plant(item_id) or item_id in [Nodes.TORCH,Nodes.LADDER]:
			var tile: int = Nodes.tile(item_id,0)
			draw_texture_rect_region(Art.atlas_texture,Rect2(center-Vector2.ONE*9*s,Vector2.ONE*18*s),Rect2(tile%8*16,tile/8*16,16,16))
		else:
			var top := PackedVector2Array([center+Vector2(0,-9)*s,center+Vector2(9,-4)*s,center+Vector2(0,1)*s,center+Vector2(-9,-4)*s])
			var left := PackedVector2Array([center+Vector2(-9,-4)*s,center+Vector2(0,1)*s,center+Vector2(0,11)*s,center+Vector2(-9,6)*s])
			var right := PackedVector2Array([center+Vector2(0,1)*s,center+Vector2(9,-4)*s,center+Vector2(9,6)*s,center+Vector2(0,11)*s])
			_face(top,Nodes.tile(item_id,2),Color.WHITE)
			_face(left,Nodes.tile(item_id,5),Color(0.8,0.8,0.8))
			_face(right,Nodes.tile(item_id,0),Color(0.62,0.62,0.62))
	else:
		var extent: float = roundf(minf(size.x,size.y)*0.72/16.0)*16.0
		if extent < 16: extent = 16
		draw_texture_rect(ItemArt.texture(item_id),Rect2((center-Vector2.ONE*extent*0.5).floor(),Vector2.ONE*extent),false)
	if count > 1:
		draw_string(ThemeDB.fallback_font,Vector2(size.x-8,size.y-7)-Vector2(str(count).length()*9,0),str(count),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f3efda"))
	if Nodes.durability(item_id) > 0 and wear > 0:
		var fraction: float = 1.0-float(wear)/Nodes.durability(item_id)
		draw_rect(Rect2(7,size.y-10,size.x-14,3),Color("132119"))
		draw_rect(Rect2(7,size.y-10,(size.x-14)*fraction,3),Color("a2bf6a") if fraction>0.2 else Color("d67f55"))

func _face(points: PackedVector2Array, tile: int, shade: Color) -> void:
	var origin := Vector2(tile%8*16,tile/8*16)
	var uvs := PackedVector2Array()
	for uv in [Vector2(0.5,0.5),Vector2(15.5,0.5),Vector2(15.5,15.5),Vector2(0.5,15.5)]:
		uvs.append((origin+uv)/Vector2(Art.atlas_texture.get_size()))
	draw_polygon(points,PackedColorArray([shade,shade,shade,shade]),uvs,Art.atlas_texture)

static func _style(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	return style

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
	var col: Color = Nodes.color(item_id)
	if Nodes.is_tool_id(item_id):
		var kind: int = Nodes.tool_kind(item_id)
		_pixels(center,scale_value,[[0,2],[1,1],[2,0],[3,-1],[-1,3],[-2,4],[-3,5],[-4,6]],Color("ad8250"),2)
		var head: Array = []
		match kind:
			0: head = [[-3,-5],[-2,-5],[-1,-5],[0,-4],[1,-3],[2,-2],[3,-1],[4,0],[4,1],[4,2]]
			1: head = [[-2,-4],[-1,-4],[0,-3],[1,-2],[-3,-3],[-2,-2],[-1,-1],[0,0]]
			2: head = [[0,-3],[1,-4],[2,-3],[3,-2],[2,-1],[1,0]]
			3: head = [[0,0],[1,-1],[2,-2],[3,-3],[4,-4],[5,-5],[6,-6],[-1,-2],[0,-1],[1,0],[2,1]]
			4: head = [[-3,-4],[-2,-4],[-1,-4],[0,-3],[1,-2]]
		_pixels(center,scale_value,head,col,2)
	elif Nodes.is_armor(item_id):
		var shape: Array = []
		match Nodes.armor_piece(item_id):
			0: shape = [[-3,-2],[-1,-3],[1,-3],[3,-2],[-5,0],[-3,0],[-1,0],[1,0],[3,0],[5,0],[-5,2],[-3,2],[-1,2],[1,2],[3,2],[5,2],[-5,4],[5,4]]
			1: shape = [[-6,-4],[-4,-4],[4,-4],[6,-4],[-6,-2],[-4,-2],[-2,-2],[0,-2],[2,-2],[4,-2],[6,-2],[-4,0],[-2,0],[0,0],[2,0],[4,0],[-4,2],[-2,2],[0,2],[2,2],[4,2],[-4,4],[-2,4],[0,4],[2,4],[4,4]]
			2: shape = [[-4,-5],[-2,-5],[0,-5],[2,-5],[4,-5],[-4,-3],[-2,-3],[2,-3],[4,-3],[-4,-1],[-2,-1],[2,-1],[4,-1],[-4,1],[-2,1],[2,1],[4,1],[-4,3],[-2,3],[2,3],[4,3],[-4,5],[-2,5],[2,5],[4,5]]
			3: shape = [[-5,-2],[-3,-2],[3,-2],[5,-2],[-5,0],[-3,0],[3,0],[5,0],[-6,2],[-4,2],[-2,2],[2,2],[4,2],[6,2],[-6,4],[-4,4],[-2,4],[2,4],[4,4],[6,4]]
		_pixels(center,scale_value,shape,col,2.2)
	elif item_id < 64 and not Nodes.plant(item_id) and item_id != Nodes.TORCH:
		var s: float = scale_value
		var top := PackedVector2Array([center+Vector2(0,-9)*s,center+Vector2(9,-4)*s,center+Vector2(0,1)*s,center+Vector2(-9,-4)*s])
		var left := PackedVector2Array([center+Vector2(-9,-4)*s,center+Vector2(0,1)*s,center+Vector2(0,11)*s,center+Vector2(-9,6)*s])
		var right := PackedVector2Array([center+Vector2(0,1)*s,center+Vector2(9,-4)*s,center+Vector2(9,6)*s,center+Vector2(0,11)*s])
		draw_colored_polygon(top,col.lightened(0.12))
		draw_colored_polygon(left,(Color("8a6446") if item_id==Nodes.GRASS else col).darkened(0.15))
		draw_colored_polygon(right,(Color("8a6446") if item_id==Nodes.GRASS else col).darkened(0.34))
		for i in 5:
			var p: Vector2 = center+Vector2(-7+i*1.2,-2+i*0.6)*s
			draw_rect(Rect2(p,Vector2(1.2,2)*s),col.darkened(0.3))
		if item_id == Nodes.TNT:
			draw_rect(Rect2(center+Vector2(-8,0)*s,Vector2(8,3)*s),Color("efe6d2"))
			draw_rect(Rect2(center+Vector2(0,0)*s,Vector2(8,3)*s),Color("d9cfb8"))
	else:
		var shape: Array = []
		var pixel: float = 2.5
		if item_id in [Nodes.STICK,Nodes.TORCH,Nodes.BONE]:
			shape = [[-3,5],[-2,4],[-1,3],[0,2],[1,1],[2,0],[3,-1],[4,-2]]
			if item_id == Nodes.BONE: shape.append_array([[-4,4],[-3,6],[5,-3],[3,-3]])
		elif item_id in [Nodes.WHEAT,Nodes.RIPE_WHEAT,Nodes.GRAIN,Nodes.SEEDS,Nodes.SAPLING,Nodes.FLOWER]:
			shape = [[0,5],[0,3],[0,1],[0,-1],[0,-3],[-2,0],[2,-2],[-2,-4],[2,-5]]
		elif item_id == Nodes.STRING:
			shape = [[-5,-4],[-4,-2],[-3,0],[-2,2],[-1,4],[0,5],[1,4],[2,2],[3,0],[4,-2],[5,-4]]
			pixel = 1.6
		elif item_id in [Nodes.GUNPOWDER,Nodes.BONE_MEAL]:
			shape = [[-4,2],[-2,4],[0,1],[2,3],[4,0],[-1,-2],[1,-4],[-3,-1],[3,-3],[0,4]]
			pixel = 2.0
		elif item_id == Nodes.LEATHER:
			shape = [[-4,-3],[-2,-4],[0,-4],[2,-4],[4,-2],[5,0],[4,2],[2,4],[0,4],[-2,4],[-4,3],[-5,1],[-5,-1],[-2,-1],[0,0],[2,1],[-1,2]]
		else:
			shape = [[-3,-3],[-1,-4],[1,-4],[3,-3],[-4,-1],[-2,-1],[0,-1],[2,-1],[4,-1],[-4,1],[-2,1],[0,1],[2,1],[4,1],[-3,3],[-1,4],[1,4],[3,3]]
		_pixels(center,scale_value,shape,col,pixel)
		if item_id == Nodes.APPLE: draw_rect(Rect2(center+Vector2(0,-8)*scale_value,Vector2(3,3)*scale_value),Color("77944a"))
	if count > 1:
		draw_string(ThemeDB.fallback_font,Vector2(size.x-8,size.y-7)-Vector2(str(count).length()*9,0),str(count),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f3efda"))
	if Nodes.durability(item_id) > 0 and wear > 0:
		var fraction: float = 1.0-float(wear)/Nodes.durability(item_id)
		draw_rect(Rect2(7,size.y-10,size.x-14,3),Color("132119"))
		draw_rect(Rect2(7,size.y-10,(size.x-14)*fraction,3),Color("a2bf6a") if fraction>0.2 else Color("d67f55"))

func _pixels(center: Vector2, scale_value: float, points: Array, color: Color, pixel_size: float) -> void:
	for i in points.size():
		var p: Array = points[i]
		draw_rect(Rect2(center+Vector2(p[0],p[1])*scale_value,Vector2.ONE*pixel_size*scale_value),color.darkened((i%3)*0.07))

static func _style(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	return style

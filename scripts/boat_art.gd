class_name BoatArt
extends RefCounted

static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = size
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 0.9
	piece.mesh = mesh; piece.material_override = material; piece.position = pos; parent.add_child(piece)
	return piece

static func build(boat: Node3D, id: int) -> Array:
	var color := Color(VillageContent.DATA.get(id,{}).get("color","b7955e"))
	box(boat,Vector3(0,0.06,0),Vector3(1.1,0.12,1.45),color.darkened(0.22))
	for side in [-1,1]:
		box(boat,Vector3(side*0.59,0.24,0),Vector3(0.12,0.36,1.55),color)
		box(boat,Vector3(0,0.24,side*0.72),Vector3(1.2,0.36,0.12),color.lightened(0.08))
	box(boat,Vector3(0,0.23,-0.26),Vector3(1.05,0.1,0.23),color.lightened(0.18))
	if Boats.is_chest(id):
		box(boat,Vector3(0,0.39,0.38),Vector3(0.7,0.57,0.57),Color("a5793c"))
		box(boat,Vector3(0,0.53,0.38),Vector3(0.73,0.035,0.61),Color("553e2a"))
		box(boat,Vector3(0,0.47,0.078),Vector3(0.1,0.14,0.035),Color("dbcf9e"))
	var paddles: Array = []
	for side in [-1,1]:
		var pivot := Node3D.new(); pivot.position = Vector3(side*0.57,0.31,0); boat.add_child(pivot)
		pivot.rotation.z = side*0.22
		box(pivot,Vector3(side*0.31,0,0),Vector3(0.68,0.055,0.06),color.darkened(0.2))
		box(pivot,Vector3(side*0.71,0,0),Vector3(0.31,0.09,0.21),color.lightened(0.05))
		paddles.append(pivot)
	return paddles

static func draw(img: Image, id: int, color: Color) -> void:
	ItemArt._polygon(img,[[0,8],[5,5],[15,8],[12,13],[4,14]],color.darkened(0.3))
	ItemArt._polygon(img,[[1,7],[6,4],[15,7],[12,11],[4,12]],color)
	ItemArt._polygon(img,[[3,7],[6,6],[12,8],[10,10],[5,10]],color.darkened(0.48))
	ItemArt._line(img,Vector2(0,12),Vector2(9,5),color.lightened(0.3),2)
	ItemArt._line(img,Vector2(7,5),Vector2(15,12),color.lightened(0.3),2)
	if Boats.is_chest(id):
		img.fill_rect(Rect2i(7,3,6,6),Color("a7793d"))
		img.fill_rect(Rect2i(7,5,6,1),Color("503e2b"))
		img.fill_rect(Rect2i(9,5,2,2),Color("e3d5a4"))

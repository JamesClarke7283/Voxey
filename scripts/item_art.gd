class_name ItemArt
extends RefCounted

# One original pixel sprite drives inventory icons, held items and pickups.
static var textures: Dictionary = {}
static var meshes: Dictionary = {}
static var materials: Dictionary = {}

static func texture(id: int) -> Texture2D:
	if textures.has(id): return textures[id]
	var img := Image.create(16,16,false,Image.FORMAT_RGBA8)
	var base: Color = Nodes.color(id)
	var dark := Color("36332d")
	if Nodes.is_tool_id(id):
		_line(img,Vector2(3,13),Vector2(10,6),Color("765034"),2)
		_line(img,Vector2(3,12),Vector2(9,6),Color("ba8c54"))
		match Nodes.tool_kind(id):
			0: _polygon(img,[[3,2],[9,2],[14,7],[14,11],[12,9],[11,6],[7,4],[3,4]],base)
			1: _polygon(img,[[7,1],[12,3],[13,7],[9,9],[5,5]],base)
			2: _polygon(img,[[11,1],[14,4],[12,7],[9,8],[7,6],[8,3]],base)
			3:
				_polygon(img,[[13,1],[15,1],[15,3],[7,11],[5,9]],base)
				_line(img,Vector2(4,7),Vector2(9,12),Color("9b8154"),2)
			4: _polygon(img,[[4,2],[10,2],[13,5],[11,7],[9,5],[4,4]],base)
	elif Nodes.is_armor(id):
		match Nodes.armor_piece(id):
			0: _polygon(img,[[4,2],[12,2],[14,5],[14,13],[11,13],[11,8],[5,8],[5,13],[2,13],[2,5]],base)
			1: _polygon(img,[[4,2],[6,2],[6,5],[10,5],[10,2],[12,2],[15,5],[14,8],[12,7],[12,14],[4,14],[4,7],[2,8],[1,5]],base)
			2: _polygon(img,[[3,2],[13,2],[13,14],[9,14],[9,7],[7,7],[7,14],[3,14]],base)
			3:
				_polygon(img,[[3,4],[6,4],[6,13],[1,13],[1,10],[3,10]],base)
				_polygon(img,[[10,4],[13,4],[13,10],[15,10],[15,13],[10,13]],base)
	elif id in [Nodes.BOWL,Nodes.MUSHROOM_STEW]:
		_polygon(img,[[1,7],[3,5],[13,5],[15,7],[13,12],[10,14],[6,14],[3,12]],base)
		_polygon(img,[[2,7],[4,6],[12,6],[14,7],[12,9],[4,9]],Color("533a2b") if id == Nodes.BOWL else Color("d49a52"))
		if id == Nodes.MUSHROOM_STEW:
			img.fill_rect(Rect2i(5,6,2,2),Color("b84d37")); img.fill_rect(Rect2i(10,7,2,1),Color("eee0b3"))
	elif id in [Nodes.IRON,Nodes.GOLD,Nodes.COPPER,Nodes.BRICK_ITEM]:
		_polygon(img,[[3,5],[11,3],[15,6],[13,11],[5,13],[1,10]],base)
		_line(img,Vector2(4,6),Vector2(11,4),base.lightened(0.35))
		_line(img,Vector2(5,11),Vector2(12,9),base.darkened(0.25),2)
	elif id in [Nodes.GOLD_NUGGET,Nodes.IRON_NUGGET]:
		_polygon(img,[[6,4],[10,3],[13,6],[11,11],[7,13],[3,10],[4,6]],base)
		img.fill_rect(Rect2i(6,5,3,2),base.lightened(0.45))
	elif id in [Nodes.COAL,Nodes.CHARCOAL,Nodes.FLINT,Nodes.DIAMOND,Nodes.CLAY_BALL,Nodes.SNOWBALL]:
		_polygon(img,[[5,2],[10,1],[14,5],[13,11],[9,14],[3,13],[1,8]],base)
		_polygon(img,[[5,3],[10,2],[12,5],[7,7],[3,8]],base.lightened(0.23))
		_polygon(img,[[8,8],[13,6],[11,11],[7,13]],base.darkened(0.22))
		if id == Nodes.DIAMOND: _line(img,Vector2(4,4),Vector2(10,4),Color("c0f7e9"))
	elif id in [Nodes.APPLE,Nodes.GOLDEN_APPLE]:
		_polygon(img,[[3,5],[6,4],[8,5],[11,4],[14,6],[14,10],[11,14],[8,13],[5,14],[2,10],[2,7]],base)
		_line(img,Vector2(8,5),Vector2(8,1),Color("775135"))
		_polygon(img,[[9,2],[13,1],[12,3],[9,4]],Color("83a44b"))
		img.fill_rect(Rect2i(4,6,2,3),base.lightened(0.35))
	elif id == Nodes.EGG:
		_polygon(img,[[7,1],[9,1],[12,5],[14,10],[12,14],[5,14],[2,11],[3,6]],base)
		_line(img,Vector2(5,6),Vector2(4,10),Color("fff4dc"),2)
	elif id in [Nodes.BREAD,Nodes.PUMPKIN_PIE]:
		_polygon(img,[[2,7],[5,3],[10,2],[14,5],[15,10],[12,13],[4,13],[1,10]],base)
		for x in [5,8,11]: _line(img,Vector2(x,5),Vector2(x-1,8),base.lightened(0.28))
		_line(img,Vector2(4,12),Vector2(12,12),Color("945d35"))
	elif id == Nodes.MELON_SLICE:
		_polygon(img,[[1,4],[14,4],[14,8],[11,13],[5,13],[1,9]],Color("638945"))
		_polygon(img,[[2,4],[13,4],[12,8],[10,11],[5,10],[3,8]],Color("f08a70"))
		_polygon(img,[[3,4],[12,4],[11,7],[8,9],[5,8]],base)
		for point in [Vector2i(5,5),Vector2i(9,5),Vector2i(7,7)]: img.set_pixelv(point,dark)
	elif id in [Nodes.STICK,Nodes.BONE,Nodes.ARROW_ITEM,Nodes.FEATHER]:
		_line(img,Vector2(3,13),Vector2(12,3),base,2)
		if id == Nodes.BONE:
			img.fill_rect(Rect2i(1,10,4,4),base); img.fill_rect(Rect2i(10,1,4,4),base)
		elif id == Nodes.ARROW_ITEM:
			_polygon(img,[[10,1],[15,1],[15,6]],Color("cad7d2"))
			_line(img,Vector2(2,10),Vector2(5,13),Color("e2dccc"),2)
		elif id == Nodes.FEATHER:
			_polygon(img,[[5,11],[4,6],[9,1],[13,1],[14,4],[10,9]],base)
			_line(img,Vector2(3,13),Vector2(12,3),Color("b1bbad"))
	elif id == Nodes.BOW:
		_line(img,Vector2(4,2),Vector2(4,14),Color("ded7bb"))
		for pair in [[4,2,9,4],[9,4,12,8],[12,8,9,12],[9,12,4,14]]:
			_line(img,Vector2(pair[0],pair[1]),Vector2(pair[2],pair[3]),Color("a87b48"),2)
	elif id in [Nodes.BUCKET,Nodes.MILK_BUCKET,Nodes.WATER_BUCKET]:
		_polygon(img,[[2,5],[14,5],[12,14],[4,14]],Color("aab7b8"))
		_polygon(img,[[3,5],[5,3],[11,3],[13,5],[11,7],[5,7]],Color("495d65") if id == Nodes.BUCKET else (Color("69afd1") if id == Nodes.WATER_BUCKET else Color("f3edd9")))
		_line(img,Vector2(5,9),Vector2(6,12),Color("e2e8df"))
	elif id in [Nodes.PAPER,Nodes.BOOK]:
		_polygon(img,[[3,2],[12,1],[14,12],[5,14],[2,12]],base)
		_polygon(img,[[5,3],[11,2],[12,10],[5,12]],Color("f2e5c6"))
		for y in [5,7,9]: _line(img,Vector2(6,y),Vector2(10,y-1),Color("bdba9e"))
	elif id in [Nodes.COMPASS,Nodes.CLOCK]:
		_polygon(img,[[5,1],[11,1],[15,5],[15,11],[11,15],[5,15],[1,11],[1,5]],Color("c9ab58") if id == Nodes.CLOCK else Color("98a8ac"))
		_polygon(img,[[5,3],[11,3],[13,5],[13,11],[11,13],[5,13],[3,11],[3,5]],Color("e1d9ba") if id == Nodes.CLOCK else Color("34434a"))
		_line(img,Vector2(8,8),Vector2(8,4),Color("ad493e"),2)
		_line(img,Vector2(8,8),Vector2(11,10),dark)
	elif id in [Nodes.GRAIN,Nodes.SEEDS,Nodes.SUGAR,Nodes.BONE_MEAL,Nodes.GUNPOWDER]:
		if id == Nodes.GRAIN:
			_line(img,Vector2(5,14),Vector2(10,2),Color("99813d"))
			for y in [4,7,10]:
				_line(img,Vector2(8,y+1),Vector2(5,y-1),base,2)
				_line(img,Vector2(9,y),Vector2(12,y-2),base,2)
		else:
			for p in [Vector2i(4,9),Vector2i(8,7),Vector2i(10,11),Vector2i(5,4),Vector2i(11,3),Vector2i(2,12)]: img.fill_rect(Rect2i(p,Vector2i(3,2)),base)
	elif id == Nodes.STRING:
		for p in [[3,3,11,3],[11,3,13,6],[13,6,5,10],[5,10,3,7],[3,7,10,6],[10,6,11,12],[11,12,7,14]]: _line(img,Vector2(p[0],p[1]),Vector2(p[2],p[3]),base)
	elif id == Nodes.SHEARS:
		_line(img,Vector2(3,2),Vector2(11,12),base,2)
		_line(img,Vector2(13,2),Vector2(5,12),base,2)
		img.fill_rect(Rect2i(2,10,4,4),Color("747c7b")); img.fill_rect(Rect2i(10,10,4,4),Color("747c7b"))
		img.fill_rect(Rect2i(3,11,2,2),Color.TRANSPARENT); img.fill_rect(Rect2i(11,11,2,2),Color.TRANSPARENT)
	elif id in [Nodes.RAW_MEAT,Nodes.COOKED_MEAT,Nodes.ROTTEN_FLESH,Nodes.LEATHER,Nodes.SADDLE]:
		_polygon(img,[[4,2],[8,3],[12,1],[14,5],[12,9],[14,12],[10,14],[6,12],[2,14],[1,10],[3,7],[1,4]],base)
		_line(img,Vector2(5,4),Vector2(11,6),base.lightened(0.3),2)
	else:
		_polygon(img,[[5,3],[11,2],[14,6],[12,12],[7,14],[2,10],[2,6]],base)
	# A one-pixel dark edge makes silhouettes readable over the world and slots.
	var original: Image = img.duplicate()
	for y in 16:
		for x in 16:
			if original.get_pixel(x,y).a > 0: continue
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var p: Vector2i = Vector2i(x,y)+d
				if p.x >= 0 and p.x < 16 and p.y >= 0 and p.y < 16 and original.get_pixelv(p).a > 0:
					img.set_pixel(x,y,original.get_pixelv(p).darkened(0.5)); break
	textures[id] = ImageTexture.create_from_image(img)
	return textures[id]

static func _polygon(img: Image, points: Array, color: Color) -> void:
	var polygon := PackedVector2Array()
	for p in points: polygon.append(Vector2(p[0],p[1]))
	for y in 16:
		for x in 16:
			if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),polygon): img.set_pixel(x,y,color)

static func _line(img: Image, a: Vector2, b: Vector2, color: Color, width: int = 1) -> void:
	var steps: int = maxi(1,ceili(a.distance_to(b)*2))
	for i in steps+1:
		var p := Vector2i(a.lerp(b,float(i)/steps))
		img.fill_rect(Rect2i(p,Vector2i(width,width)).intersection(Rect2i(0,0,16,16)),color)

static func material(id: int) -> StandardMaterial3D:
	if materials.has(id): return materials[id]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture(id)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	materials[id] = mat
	return mat

static func mesh(id: int) -> ArrayMesh:
	if meshes.has(id): return meshes[id]
	var img: Image = texture(id).get_image()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for y in 16:
		for x in 16:
			if img.get_pixel(x,y).a < 0.5: continue
			var center := Vector3((x+0.5)/16.0-0.5,0.5-(y+0.5)/16.0,0)
			for face in 6:
				var normal: Vector3 = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD][face]
				if face < 4:
					var neighbor := Vector2i(x+int(normal.x),y-int(normal.y))
					if neighbor.x >= 0 and neighbor.x < 16 and neighbor.y >= 0 and neighbor.y < 16 and img.get_pixelv(neighbor).a > 0.5: continue
				var right: Vector3 = [Vector3.FORWARD,Vector3.BACK,Vector3.RIGHT,Vector3.RIGHT,Vector3.RIGHT,Vector3.LEFT][face]
				var up: Vector3 = normal.cross(right)
				var offset: int = vertices.size()
				for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
					vertices.append(center+(normal+right*corner.x+up*corner.y)*Vector3(1.0/16,1.0/16,0.07)*0.5)
					normals.append(normal)
					uvs.append(Vector2(x+0.5,y+0.5)/16.0)
				for index in [0,2,1,0,3,2]: indices.append(offset+index)
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	meshes[id] = result
	return result

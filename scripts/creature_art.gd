class_name CreatureArt
extends RefCounted

# Original, deterministic pixel skins. Textures are shared; each creature owns
# its tint materials so taking damage never flashes another creature.
static var textures: Dictionary = {}
static var meshes: Dictionary = {}

static func texture(style: String, base: Color) -> Texture2D:
	var key: String = style+base.to_html()
	if textures.has(key): return textures[key]
	var img := Image.create(16,16,false,Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var patch: int = (x/2*7+y/2*13+x/4*y/3*3)%17
			var c: Color = base
			match style:
				"moss":
					c = base * [0.65,0.82,1.05,1.2,0.92][patch%5]
					if (x*3+y*7)%23 == 0: c = Color("c0c982")
				"skin":
					c = base * (0.78+float(patch%5)*0.07)
					if (x/3+y/4*3)%9 == 0: c = base.darkened(0.3)
				"cloth":
					c = base*(0.91+float(patch%4)*0.035)
					if x in [0,15] or y == 15: c = base.darkened(0.25)
					if y > 11 and (x/3)%3 == 0: c = base.darkened(0.36)
				"bone":
					c = base*(0.92+float(patch%4)*0.025)
					if x in [0,15]: c = base.darkened(0.18)
					if x == 2 and y%7 < 3: c = base.lightened(0.13)
				"shell":
					c = base*(0.86+float(patch%5)*0.04)
					if (x/3+y/4)%4 == 0: c = base.lightened(0.1)
					if y in [0,15]: c = base.darkened(0.22)
				"wood":
					c = base*(0.8+float((x/2+y/6)%4)*0.08)
				_:
					c = base*(0.94+float(patch%4)*0.02)
			c.a = 1.0
			img.set_pixel(x,y,c)
	textures[key] = ImageTexture.create_from_image(img)
	return textures[key]

static func cuboid(size_value: Vector3) -> ArrayMesh:
	if meshes.has(size_value): return meshes[size_value]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# Full UV squares on each face keep the skin pixels square on cube heads.
	for face in 6:
		var normal: Vector3 = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD][face]
		var right: Vector3 = [Vector3.FORWARD,Vector3.BACK,Vector3.RIGHT,Vector3.RIGHT,Vector3.RIGHT,Vector3.LEFT][face]
		var up: Vector3 = normal.cross(right)
		var offset: int = vertices.size()
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			vertices.append((normal+right*corner.x+up*corner.y)*size_value*0.5)
			normals.append(normal)
			uvs.append(Vector2((corner.x+1)*0.5,(1-corner.y)*0.5))
		for i in [0,2,1,0,3,2]: indices.append(offset+i)
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	meshes[size_value] = mesh
	return mesh

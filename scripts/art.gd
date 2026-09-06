class_name Art
extends RefCounted

static var atlas_texture: Texture2D

static func make_atlas() -> ImageTexture:
	var img := Image.create(128, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7164
	for tile in 79:
		if tile in range(58,64): continue # Reserved for existing mod nodes.
		var base: Color = Nodes.color(tile)
		if tile >= 64: base = Nodes.color([Nodes.SANDSTONE,Nodes.SANDSTONE_BRICK,Nodes.ICE,Nodes.SNOW_BLOCK,Nodes.VINE,Nodes.RED_BRICKS,Nodes.HAY_BALE,Nodes.HAY_BALE,Nodes.SUGAR_CANE,Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,Nodes.MOSSY_COBBLE,Nodes.MOSSY_BRICKS,Nodes.COAL_BLOCK,Nodes.TERRACOTTA][tile-64])
		if tile == 41: base = Color("a08a6a")
		if tile == 30: base = Color("719f43")
		if tile == 31: base = Color("bb945e")
		if tile == 32: base = Color("b78b52")
		if tile == 33: base = Color("626d71")
		if tile == 42: base = Color("a8834f")
		if tile == 44: base = Color("9aa2a8")
		if tile == 45: base = Color("cf8a2a")
		if tile == 46: base = Color("cf8a2a")
		if tile == 47: base = Color("9dc14f")
		for y in 16:
			for x in 16:
				var c: Color = base * rng.randf_range(0.86,1.1)
				c.a = 1.0
				match tile:
					3,25,28:
						# Broad mineral planes with sparse seams, instead of white noise.
						c = base * (0.93 + float((x/4*3+y/3*7)%5)*0.025)
						if (x+y*3)%23 == 0: c = base.darkened(0.16)
						if tile == 25 and (x/3+y/2)%5 == 0: c = Color("4c3d61")
					1:
						c = (Color("719f43") if y < 3 + int(x * 7 + 3) % 3 else Color("916747")) * rng.randf_range(0.86,1.08)
					6:
						if x % 4 == 0 or (x % 4 == 1 and y % 7 < 4): c = base * 0.66
					7:
						if (x/3 + y/3) % 3 == 0: c *= 0.8
					8,15,17:
						if y % 4 == 0 or (x + (y/4)%2*8) % 16 == 0: c *= 0.63
						if tile == 17 and (y < 2 or y > 13 or x < 2 or x > 13): c *= 0.65
						if tile == 17 and x in [7,8] and y in [7,8,9]: c = Color("edcf78")
					9:
						if y % 5 == 0 or (x + y/5*3) % 7 == 0: c *= 0.62
					10,11,12,34,35:
						if (x/2*7 + y/2*13) % 17 < 4:
							c = {10:Color("30363b"),11:Color("bf977b"),12:Color("64d9d4"),34:Color("e5b64e"),35:Color("c78156")}[tile] * rng.randf_range(0.8,1.1)
					14:
						if x % 4 == 0: c *= 0.55
						if x % 7 == 1 and y % 5 == 1: c = Color("dee5a4")
					16,33:
						if x == 0 or y == 0 or x == 15 or y == 15: c *= 0.7
						if tile == 33 and x > 3 and x < 12 and y > 5 and y < 13: c = Color("242e32")
					18:
						c = Color("ffda6b") if y < 5 else Color("805738")
						if y < 2: c = Color("fff1b4")
					19:
						c = Color("b9dfe3") if x == 0 or y == 0 or x == 15 or y == 15 or (x+y)%16 == 0 else Color(0,0,0,0)
					36,37,38,39:
						if x in [0,15] or y in [0,15]: c *= 0.72
						elif x in [1,2] or y in [1,2]: c = base.lightened(0.2)
					20:
						if y % 8 == 0 or (x+(y/8)*8)%16 == 0: c *= 0.55
					21:
						if x % 4 < 2: c *= 0.68
					22,29:
						c.a = 0.0
						if (x % 4 == 1 and y > 5) or (y in [4,6,8] and x % 4 < 3):
							c = Color("699541") if tile == 22 else Color("d3b754")
					23:
						c.a = 0.0
						if x in [7,8] and y > 7: c = Color("845931")
						if y > 1 and y < 11 and abs(x-8) < 6-abs(y-6)/2: c = Color("668f3a") * rng.randf_range(0.8,1.2)
					24:
						c = Color("e2dacc") if y < 5 else Color("b85241")
						if y > 12: c = Color("8f683c")
					27:
						c.a = 0.0
						if x == 8 and y > 5: c = Color("5a8f3c")
						if abs(x-8)+abs(y-4) < 4: c = Color("f0cf66") if x != 8 else Color("a57235")
					31:
						var ring: int = maxi(absi(x-8), absi(y-8))
						if ring % 3 == 1 or ring > 6: c *= 0.7
					32:
						if x in [0,1,14,15] or y in [0,1,14,15] or x%5 == 0 or y%5 == 0: c *= 0.55
					40:
						if y >= 6 and y <= 9: c = Color("efe6d2") * rng.randf_range(0.92,1.04)
						if y in [7,8] and x in [2,3,4,6,7,8,9,10,12,13,14] and (y == 7 or x in [3,7,9,13]): c = Color("2b2422")
						if y == 0 or y == 15: c *= 0.7
					41:
						if x in [0,15] or y in [0,15]: c *= 0.6
						if x > 3 and x < 12 and y > 3 and y < 12: c = Color("6c5a44") * rng.randf_range(0.9,1.1)
					42:
						# Ladder: two rails with rungs, transparent elsewhere.
						if x in [2,3,12,13]: c = Color("a8834f")*rng.randf_range(0.85,1.1)
						elif y % 5 in [1,2] and x > 3 and x < 12: c = Color("b8955c")*rng.randf_range(0.85,1.1)
						else: c.a = 0.0
					43:
						# Bookshelf: plank frame, rows of colored book spines.
						if y < 2 or y > 13 or (y in [7,8]): c = Color("c39760")*rng.randf_range(0.85,1.05)
						else:
							var spine: int = (x/2+y/8*3)%5
							c = [Color("9c4a33"),Color("3e5a7a"),Color("5d7a3e"),Color("b08a3e"),Color("6a4a7a")][spine]*rng.randf_range(0.85,1.1)
							if x % 4 == 0: c *= 0.6
					44:
						# Clay: grey-blue with darker speckles.
						if (x/2*5+y/2*11)%13 < 3: c *= 0.82
					45:
						# Carved pumpkin face.
						c = Color("cf8a2a")*rng.randf_range(0.9,1.1)
						if y in [4,5] and x in [3,4,11,12]: c = Color("3a2410")
						if y in [9,10,11] and x in [4,5,10,11]: c = Color("3a2410")
						if y == 11 and x in [6,7,8,9]: c = Color("3a2410")
						if x in [0,15] or y in [0,15]: c *= 0.72
					46:
						# Pumpkin side: ribs.
						if x % 4 == 0: c *= 0.72
						if x in [0,15] or y in [0,15]: c *= 0.72
					47:
						# Melon: striped rind.
						c = (Color("9dc14f") if x % 3 != 0 else Color("6f9437"))*rng.randf_range(0.9,1.1)
					56:
						# Bed foot: red blanket over a plank frame.
						c = Color("b6543d")*rng.randf_range(0.92,1.06)
						if y > 12: c = Color("8f683c")
						if y < 2: c = Color("e2dacc")*rng.randf_range(0.92,1.04)
						c.a = 1.0
					57:
						# Bed head: white pillow with a folded blanket edge.
						c = Color("e2dacc")*rng.randf_range(0.92,1.04)
						if y > 11: c = Color("b6543d")*rng.randf_range(0.92,1.06)
						if y > 13: c = Color("8f683c")
						if (x == 7 or x == 8) and y in [4,5]: c = c.darkened(0.08)
						c.a = 1.0
					48,49,50:
						# Metal storage blocks: beveled ingot grid.
						if x in [0,15] or y in [0,15]: c *= 0.8
						elif (x in [5,10] or y in [5,10]): c = base.darkened(0.18)
						elif x in [6,11] or y in [6,11]: c = base.lightened(0.15)
					51:
						# Glowstone: mottled bright patches.
						if (x/2*7+y/2*5)%9 < 3: c = base.lightened(0.35)*rng.randf_range(0.95,1.1)
						else: c = base.darkened(0.12)
					64,65:
						if y % 8 == 7 or (tile == 65 and (x+(y/8)*8)%16 == 0): c = base.darkened(0.24)
						elif y % 8 == 0: c = base.lightened(0.15)
					66:
						c = Color("91bbcf").lerp(Color("d5edf0"),float((x+y)%13 < 2)*0.65)
						if x in [0,15] or y in [0,15]: c = Color("79a5c2")
					67:
						c = Color("edf3ee") * rng.randf_range(0.97,1.0)
						if y > 12: c = Color("d6e4e6")
					68:
						c = Color.TRANSPARENT
						if x%7 == 2 or (y%5 < 3 and (x+y/5*2)%7 < 4): c = base*rng.randf_range(0.8,1.15)
					69,76:
						if y%4 == 3 or (x+(y/4)%2*4)%8 == 0: c = Color("c4b6a0") if tile == 69 else Color("525c58")
						elif y%4 == 0: c = base.lightened(0.12)
						if tile == 76 and (x*3+y*7)%19 < 5: c = Color("617a43")
					70,71:
						c = base * (0.8 + float((x*7+y/3)%5)*0.08)
						if tile == 70 and y in [3,4,11,12]: c = Color("986440")
						if tile == 71 and maxi(absi(x-8),absi(y-8))%3 == 0: c = base.darkened(0.2)
					72:
						c = Color.TRANSPARENT
						if x%5 in [1,2,3]: c = [Color("72983e"),Color("b5ce73"),Color("91b751")][x%5-1]
						if c.a > 0 and y%5 == 4: c = Color("597d38")
					73,74:
						c = Color.TRANSPARENT
						if x in [7,8,9] and y > 6 and y < 15: c = Color("d6c7a0") if x == 7 else Color("a79777")
						if y in range(2,9) and absi(x-8) <= mini(y+1,6):
							c = base*rng.randf_range(0.85,1.12)
							if y == 8: c = base.darkened(0.32)
							if tile == 73 and (x/2*3+y/2*7)%11 < 2: c = Color("f2e5cf")
					75:
						if y%5 == 0 or (x+y/5*3)%7 == 0: c = base.darkened(0.3)
						elif (x/2*5+y/2*7)%13 < 5: c = Color("627d41")*rng.randf_range(0.8,1.1)
					77:
						if x%5 == 0 or y%5 == 0: c = base.darkened(0.25)
						elif (x+y)%7 == 0: c = base.lightened(0.1)
					78:
						c = base*rng.randf_range(0.97,1.03)
						if y in [0,15]: c = base.darkened(0.05)
				img.set_pixel(tile%8*16+x, tile/8*16+y, c)
	# Expansion-node face tiles (drawn after the loop so they can override).
	# Tile 52: sandstone top, tile 53: melon top. Ladder (42), bookshelf (43),
	# clay (44), pumpkins (45/46), melon side (47), and the metal blocks
	# (48..51) are drawn by the main loop above.
	for y in 16:
		for x in 16:
			var c: Color = Color("d9cf9c")*rng.randf_range(0.9,1.08)
			c.a = 1.0
			if x in [0,15] or y in [0,15]: c = Color("cfc394")*rng.randf_range(0.9,1.05)
			img.set_pixel(52%8*16+x, 52/8*16+y, c)
			var melon_top: Color = (Color("9dc14f") if (x/2+y/2)%2 == 0 else Color("8ab344"))*rng.randf_range(0.9,1.08)
			img.set_pixel(53%8*16+x, 53/8*16+y, melon_top)
	# Mod nodes retain their reserved tiles 58..63.
	for mod_id in Nodes.custom_tiles:
		var base: Color = Nodes.color(mod_id)
		var tile_index: int = Nodes.custom_tiles[mod_id]
		for y in 16:
			for x in 16:
				var c: Color = base * rng.randf_range(0.85,1.1)
				c.a = 1.0
				img.set_pixel(tile_index%8*16+x, tile_index/8*16+y, c)
	atlas_texture = ImageTexture.create_from_image(img)
	return atlas_texture

static func crack_texture(stage: int) -> ImageTexture:
	# Luanti-style crack overlay. The image has an even size, so its exact centre is
	# the corner shared by the four middle pixels. Everything is drawn in one 90°
	# sector and stamped with four-fold rotational symmetry, so no stage can lean
	# to one side: the cracks always grow outward from the middle of the face.
	var img := Image.create(32,32,false,Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var reach: float = 3.0+float(stage)*1.65
	var zig: Array = [0.0,0.6,0.9,0.4,-0.3,-0.8,-0.6,0.1,0.7,0.5,-0.2,-0.7,-0.4,0.3,0.8,0.2,-0.5,-0.9]
	for branch in 2:
		var angle: float = deg_to_rad(22.5+branch*45.0)
		var direction := Vector2(cos(angle),sin(angle))
		var side: Vector2 = direction.orthogonal()
		var flip: float = 1.0 if branch == 0 else -1.0
		var previous := Vector2(16,16)
		for step in range(1,19):
			if step > reach: break
			var next: Vector2 = Vector2(16,16)+direction*step+side*float(zig[step-1])*flip
			_crack_line(img,previous,next)
			# Forks appear once the main cracks are established and lengthen with the stage.
			if step in [6,11] and stage >= 3:
				var fork_angle: float = angle+(0.8 if step == 6 else -0.8)*flip
				var fork_length: float = minf(float(stage-2)*1.3,7.0)
				_crack_line(img,next,next+Vector2(cos(fork_angle),sin(fork_angle))*fork_length)
			previous = next
	# Web rings join neighbouring cracks near the end so the node visibly shatters.
	if stage >= 5:
		for ring in ([6.0] if stage < 7 else [6.0,11.0]):
			for arc in 2:
				var from_angle: float = deg_to_rad(22.5+arc*45.0)
				var to_angle: float = from_angle+deg_to_rad(45.0)
				var a: Vector2 = Vector2(16,16)+Vector2(cos(from_angle),sin(from_angle))*ring
				var b: Vector2 = Vector2(16,16)+Vector2(cos(to_angle),sin(to_angle))*ring
				_crack_line(img,a,b)
	for x in [15,16]:
		for y in [15,16]: img.set_pixel(x,y,Color(0.065,0.055,0.04,0.92))
	return ImageTexture.create_from_image(img)

static func _crack_line(img: Image, start: Vector2, end: Vector2) -> void:
	var distance: int = maxi(1,ceili(start.distance_to(end)*2))
	for i in distance+1:
		var p: Vector2 = start.lerp(end,float(i)/distance)
		_crack_stamp(img,floori(p.x),floori(p.y))

# Stamps a pixel and its three 90° rotations about the image centre.
static func _crack_stamp(img: Image, x: int, y: int) -> void:
	for point in [Vector2i(x,y),Vector2i(31-y,x),Vector2i(31-x,31-y),Vector2i(y,31-x)]:
		if point.x>=0 and point.y>=0 and point.x<32 and point.y<32:
			img.set_pixel(point.x,point.y,Color(0.065,0.055,0.04,0.92))

static func crack_mesh() -> ArrayMesh:
	# BoxMesh packs faces into an atlas UV layout. Giving every face the complete
	# 0..1 UV square keeps the crack origin centered on all six sides.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for axis in 3:
		for direction in [-1,1]:
			var p := Vector3.ONE*-0.504
			p[axis] = direction*0.504
			var du := Vector3.ZERO
			var dv := Vector3.ZERO
			du[(axis+1)%3] = 1.008
			dv[(axis+2)%3] = 1.008
			var normal := Vector3.ZERO
			normal[axis] = direction
			var offset: int = vertices.size()
			for point in [p,p+du,p+du+dv,p+dv]: vertices.append(point); normals.append(normal)
			uvs.append_array(PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]))
			for index in ([0,2,1,0,3,2] if direction>0 else [0,1,2,0,2,3]): indices.append(offset+index)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

# A single node meshed by the same greedy mesher as the terrain, spanning 0..1 on
# every axis. Item drops, falling nodes, and the held block reuse the terrain atlas.
# The game instance caches these per id.
static func build_node_mesh(id: int) -> ArrayMesh:
	var padded := PackedByteArray()
	padded.resize(5832)
	padded[1+18+324] = id
	var surfaces: Array = BlockMesher.build(padded)
	var mesh := ArrayMesh.new()
	var arrays: Array = surfaces[1] if id == Nodes.WATER else surfaces[0]
	if not arrays.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

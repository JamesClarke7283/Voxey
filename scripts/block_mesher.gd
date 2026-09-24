class_name BlockMesher
extends RefCounted

# Greedy face merging: one quad for a coplanar rectangle of matching nodes.
# Only packed arrays leave the worker; GPU and scene resources stay on the main thread.
const BRIGHTNESS = [0.82,0.73,1.0,0.53,0.87,0.77]

# Classification bits for every cell of an 18^3 buffer. Runs of one id reuse the
# previous lookup, which covers most stone, air and water.
static func classify(data: PackedInt32Array, info: NodeInfo.View) -> PackedInt32Array:
	var flags := PackedInt32Array()
	flags.resize(data.size())
	var table: PackedInt32Array = info.traits
	var known: int = table.size()
	var last_id: int = -1
	var last_bits: int = 0
	for index in data.size():
		var id: int = data[index]
		if id != last_id:
			last_id = id
			last_bits = table[id] if id >= 0 and id < known else 0
			if last_bits == 0: last_bits = info.of(id)
		flags[index] = last_bits
	return flags

# A lookup for callers that did not bring one: the shared tables on the main
# thread, or a private cache on a worker.
static func default_info() -> NodeInfo.View:
	return NodeInfo.live_view() if NodeInfo.on_main_thread() else NodeInfo.View.new(PackedInt32Array(),PackedInt32Array())

static func build(source: Variant, external_circuits: bool = false, info: NodeInfo.View = null, flags: PackedInt32Array = PackedInt32Array()) -> Array:
	var data: PackedInt32Array = source if source is PackedInt32Array else PackedInt32Array(Array(source))
	if info == null: info = default_info()
	if flags.size() != data.size(): flags = classify(data,info)
	var shift: int = NodeInfo.EXTERNAL_SHIFT if external_circuits else NodeInfo.MESH_SHIFT
	var outputs: Array = [_empty(), _empty()]
	var has_nodes: bool = false
	var has_cubes: bool = false
	# Visible cube faces are recorded in their own plane as `position << 20 | id`,
	# where position is the cell's place in that plane's 16 x 16 mask, so the
	# greedy merge below touches only faces that are actually drawn.
	var planes: Array = []
	planes.resize(96)
	for index in 96: planes[index] = PackedInt32Array()
	var inert: int = NodeInfo.FLOWING|NodeInfo.SOURCE|(NodeInfo.MESH_MASK << shift)
	for y in 16:
		var layer: int = (y+1)*324
		# A layer of air draws nothing. Neither does a layer of one plain cube
		# between two more layers of it: every face touches the same node.
		var fill: int = data[layer]
		if data.slice(layer,layer+324).count(fill) == 324:
			if fill == 0: continue
			if flags[layer] & NodeInfo.CUBE and flags[layer] & inert == 0 and data.slice(layer-324,layer).count(fill) == 324 and data.slice(layer+324,layer+648).count(fill) == 324:
				has_nodes = true
				continue
		for z in 16:
			var row: int = layer+(z+1)*18
			if data.slice(row,row+18).count(0) == 18: continue
			for x in 16:
				var center: int = row+x+1
				var id: int = data[center]
				if id == 0: continue
				has_nodes = true
				var bits: int = flags[center]
				if bits & NodeInfo.CUBE:
					has_cubes = true
					var hide: int = NodeInfo.OCCLUDES
					if bits & NodeInfo.SOURCE: hide |= NodeInfo.BASE_WATER if id == Nodes.WATER else NodeInfo.BASE_LAVA
					var water: bool = id == Nodes.WATER
					var neighbor: int = data[center+1]
					if neighbor != id and flags[center+1] & hide == 0 and not (water and neighbor == Nodes.GLASS): planes[x].append((y+z*16) << 20 | id)
					neighbor = data[center-1]
					if neighbor != id and flags[center-1] & hide == 0 and not (water and neighbor == Nodes.GLASS): planes[16+x].append((y+z*16) << 20 | id)
					neighbor = data[center+324]
					if neighbor != id and flags[center+324] & hide == 0 and not (water and neighbor == Nodes.GLASS): planes[32+y].append((z+x*16) << 20 | id)
					neighbor = data[center-324]
					if neighbor != id and flags[center-324] & hide == 0 and not (water and neighbor == Nodes.GLASS): planes[48+y].append((z+x*16) << 20 | id)
					neighbor = data[center+18]
					if neighbor != id and flags[center+18] & hide == 0 and not (water and neighbor == Nodes.GLASS): planes[64+z].append((x+y*16) << 20 | id)
					neighbor = data[center-18]
					if neighbor != id and flags[center-18] & hide == 0 and not (water and neighbor == Nodes.GLASS): planes[80+z].append((x+y*16) << 20 | id)
				if bits & inert == 0: continue
				if bits & NodeInfo.FLOWING: Fluids.mesh(outputs[1 if bits & NodeInfo.WATERY else 0],Vector3(x,y,z),id,data,Vector3i(x+1,y+1,z+1))
				elif bits & NodeInfo.SOURCE:
					for offset in [-1,1,-18,18]:
						if flags[center+offset] & NodeInfo.FLOWING and Fluids.base(data[center+offset]) == id:
							Fluids.mesh(outputs[1 if id == Nodes.WATER else 0],Vector3(x,y,z),id,data,Vector3i(x+1,y+1,z+1))
							break
				var kind: int = (bits >> shift) & NodeInfo.MESH_MASK
				if kind != 0: _custom(kind,outputs[0],Vector3(x,y,z),id,data,info)
	if not has_nodes: return [[], []]
	var mask := PackedInt32Array()
	mask.resize(256)
	# Opaque greedy faces go straight into typed arrays; taking them out of the
	# output list keeps each array singly owned, so appends never copy it.
	var verts: PackedVector3Array = outputs[0][0]
	var normals: PackedVector3Array = outputs[0][1]
	var uvs: PackedVector2Array = outputs[0][2]
	var cells: PackedVector2Array = outputs[0][3]
	var colors: PackedColorArray = outputs[0][4]
	var indices: PackedInt32Array = outputs[0][5]
	outputs[0] = []
	# Per id and face: the atlas cell, negative for translucent surface faces.
	var face_cells: Dictionary = {}
	for axis in (range(3) if has_cubes else []):
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		for sign_dir in [-1, 1]:
			var normal := Vector3.ZERO
			normal[axis] = sign_dir
			var face: int = axis * 2 + (0 if sign_dir == 1 else 1)
			var brightness: float = BRIGHTNESS[face]
			var shade := Color(brightness,brightness,brightness)
			var four_normals := PackedVector3Array([normal,normal,normal,normal])
			var four_shades := PackedColorArray([shade,shade,shade,shade])
			for plane in 16:
				var faces: PackedInt32Array = planes[face*16+plane]
				if faces.is_empty(): continue
				# Start cells are visited row by row, the order of a full mask scan.
				# The z planes were recorded in that order already.
				if axis != 2: faces.sort()
				for entry in faces: mask[entry >> 20] = entry & 0xFFFFF
				for entry in faces:
					var start: int = entry >> 20
					var id: int = mask[start]
					if id == 0: continue
					var i: int = start & 15
					var j: int = start >> 4
					var w: int = 1
					while i+w < 16 and mask[start+w] == id: w += 1
					var h: int = 1
					var expand: bool = true
					while j+h < 16 and expand:
						var row: int = start+h*16
						for k in w:
							if mask[row+k] != id: expand = false; break
						if expand: h += 1
					var p := Vector3.ZERO
					p[axis] = plane + (1 if sign_dir == 1 else 0)
					p[u] = i
					p[v] = j
					var du := Vector3.ZERO
					var dv := Vector3.ZERO
					du[u] = w
					dv[v] = h
					var key: int = id*8+face
					var tile: int = face_cells.get(key,-1)
					if tile == -1:
						tile = info.tile(id,face)
						if info.of(id) & NodeInfo.SURFACE: tile = -2-tile
						face_cells[key] = tile
					if tile < -1:
						var uv: Array = [Vector2(0,h),Vector2(w,h),Vector2(w,0),Vector2(0,0)]
						if axis == 0: uv = [Vector2(0,w),Vector2(0,0),Vector2(h,0),Vector2(h,w)]
						_quad(outputs[1], [p,p+du,p+du+dv,p+dv], uv, normal, -2-tile, shade, sign_dir == 1)
					else:
						var offset: int = verts.size()
						var corner: Vector3 = p+du
						verts.append(p)
						verts.append(corner)
						verts.append(corner+dv)
						verts.append(p+dv)
						normals.append_array(four_normals)
						if axis == 0:
							uvs.append(Vector2(0,w)); uvs.append(Vector2(0,0)); uvs.append(Vector2(h,0)); uvs.append(Vector2(h,w))
						else:
							uvs.append(Vector2(0,h)); uvs.append(Vector2(w,h)); uvs.append(Vector2(w,0)); uvs.append(Vector2(0,0))
						var cell := Vector2(tile % 8, tile / 8)
						cells.append(cell); cells.append(cell); cells.append(cell); cells.append(cell)
						colors.append_array(four_shades)
						if sign_dir == 1:
							indices.append(offset); indices.append(offset+2); indices.append(offset+1)
							indices.append(offset); indices.append(offset+3); indices.append(offset+2)
						else:
							indices.append(offset); indices.append(offset+1); indices.append(offset+2)
							indices.append(offset); indices.append(offset+2); indices.append(offset+3)
					for yy in h:
						for xx in w: mask[start+xx+yy*16] = 0
	outputs[0] = [verts,normals,uvs,cells,colors,indices]
	var result: Array = []
	for out in outputs:
		if out[0].is_empty(): result.append([]); continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = out[0]
		arrays[Mesh.ARRAY_NORMAL] = out[1]
		arrays[Mesh.ARRAY_TEX_UV] = out[2]
		arrays[Mesh.ARRAY_TEX_UV2] = out[3]
		arrays[Mesh.ARRAY_COLOR] = out[4]
		arrays[Mesh.ARRAY_INDEX] = out[5]
		result.append(arrays)
	return result

# Custom geometry, dispatched on the kind NodeInfo recorded for the node.
static func _custom(kind: int, out: Array, p: Vector3, id: int, data: PackedInt32Array, info: NodeInfo.View) -> void:
	var cell := Vector3i(p)+Vector3i.ONE
	match kind:
		1: Farmland.mesh(out,p,id)
		2: CropFarming.mesh(out,p,id)
		3: FruitCrops.mesh(out,p,id)
		4: RedstoneInputs.mesh(out,p,id)
		5: RedstoneSensors.mesh(out,p,id)
		6: _art_box(out,p+Vector3(0.5,0.2,0.5),Vector3(0.85,0.4,0.85),info.tile(id,0),info.tile(id,2))
		7: SnowCover.mesh(out,p,id)
		8: Signs.mesh(out,p,id)
		9: FoodFeatures.mesh(out,p,id)
		10: Doors.mesh(out,p,id)
		11: Trapdoors.mesh(out,p,id)
		12: Barriers.mesh(out,p,id,data,cell)
		13: BuildingShapes.mesh(out,p,id,data,cell)
		14: _torch(out,p,id)
		15: Heads.mesh(out,p,id)
		16: Beacons.mesh(out,p,id)
		17: Seagrass.mesh(out,p,id)
		18: SeaPickles.mesh(out,p,id)
		19: Corals.mesh(out,p,id)
		20: Conduits.mesh(out,p,id)
		21: Scaffolding.mesh(out,p,id)
		22: VillageArt.mesh(out,p,id)
		23: Sponges.mesh(out,p,id)
		24: Archaeology.mesh(out,p,id)
		25: Copper.mesh(out,p,id)
		26: _portal(out,p,data,Vector3i(p))
		27: _end_portal(out,p)
		28: Rails.mesh_in(out,p,id,data,cell)
		29: _enchanting_table(out,p)
		30: _plant(out,p,id,info)
		31: _ladder(out,p,data,Vector3i(p))
		32: _bed_half(out,p,id,data,Vector3i(p))

static func _empty() -> Array:
	return [PackedVector3Array(),PackedVector3Array(),PackedVector2Array(),PackedVector2Array(),PackedColorArray(),PackedInt32Array()]

static func _quad(out: Array, vertices: Array, uvs: Array, normal: Vector3, tile: int, shade: Color, reverse: bool) -> void:
	var offset: int = out[0].size()
	for i in 4:
		out[0].append(vertices[i])
		out[1].append(normal)
		out[2].append(uvs[i])
		out[3].append(Vector2(tile % 8, tile / 8))
		out[4].append(shade)
	for index in ([0,2,1,0,3,2] if reverse else [0,1,2,0,2,3]): out[5].append(offset + index)

static func _plant(out: Array, p: Vector3, id: int, info: NodeInfo.View = null) -> void:
	var h: float = 0.55 if id == Nodes.WHEAT else 0.9
	if id in [Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM]: h = 0.45
	if id in [Nodes.SUGAR_CANE,Nodes.VINE]: h = 1.0
	var uv: Array = [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
	for flip in 2:
		var verts: Array = [p+Vector3(0.08,0,0.08),p+Vector3(0.92,0,0.92),p+Vector3(0.92,h,0.92),p+Vector3(0.08,h,0.08)] if flip == 0 else [p+Vector3(0.08,0,0.92),p+Vector3(0.92,0,0.08),p+Vector3(0.92,h,0.08),p+Vector3(0.08,h,0.92)]
		var tile: int = info.tile(id,0) if info != null else Nodes.tile(id,0)
		_quad(out,verts,uv,Vector3.UP,tile,Color.WHITE,false)
		_quad(out,verts,uv,Vector3.UP,tile,Color.WHITE,true)

static func _torch(out: Array, p: Vector3, id: int = Nodes.TORCH) -> void:
	var start: int = out[0].size()
	_art_box(out,Vector3(0,0.375,0),Vector3(0.125,0.75,0.125),Nodes.TORCH,Nodes.TORCH)
	var rotation := Basis.IDENTITY
	var base: Vector3 = p+Vector3(0.5,0,0.5)
	if id in Torches.WALLS:
		var support: Vector3 = Vector3(Torches.support(id))
		rotation = Basis(Vector3.UP.cross(-support).normalized(),PI/6.0)
		base += support*0.4+Vector3.UP*0.15
	for i in range(start,out[0].size()):
		out[0][i] = base+rotation*out[0][i]
		out[1][i] = rotation*out[1][i]
		# Horizontal end caps sample the flame or the foot of the shaft.
		if i-start in range(8,12): out[2][i] = Vector2(0.5,0.05)
		elif i-start in range(12,16): out[2][i] = Vector2(0.5,0.95)

# A ladder is a flat quad mounted against the first solid neighbor (or the
# west face when free-standing, as when a supporting node was mined first).
static func _ladder(out: Array, p: Vector3, data: Variant, cell: Vector3i) -> void:
	var uv: Array = [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
	var mounts: Array = [[Vector3i(1,0,0),Vector3(0.92,0,0),Vector3(0.92,0,1)],
		[Vector3i(-1,0,0),Vector3(0.08,0,1),Vector3(0.08,0,0)],
		[Vector3i(0,0,1),Vector3(1,0,0.92),Vector3(0,0,0.92)],
		[Vector3i(0,0,-1),Vector3(0,0,0.08),Vector3(1,0,0.08)]]
	for mount in mounts:
		var neighbor: Vector3i = cell+mount[0]
		if neighbor.x < 0 or neighbor.x > 17 or neighbor.z < 0 or neighbor.z > 17: continue
		var wall: int = data[neighbor.x + neighbor.z*18 + (cell.y+1)*324]
		if Nodes.solid(wall) and not Nodes.transparent(wall):
			var a: Vector3 = p+mount[1]
			var b: Vector3 = p+mount[2]
			_quad(out,[a,b,b+Vector3.UP,a+Vector3.UP],uv,Vector3(mount[0])*-1.0,Nodes.LADDER,Color.WHITE,mount[0].x+mount[0].z > 0)
			return
	var a: Vector3 = p+Vector3(0.08,0,0)
	var b: Vector3 = p+Vector3(0.08,0,1)
	_quad(out,[a,b,b+Vector3.UP,a+Vector3.UP],uv,Vector3.RIGHT,Nodes.LADDER,Color.WHITE,false)

# A bed half is a 9/16-height box: blanket top, oak frame sides. The head
# half's end shows the pillow tile edge; the foot/blanket use the same tile
# family. Hide only faces covered by the actual neighboring voxel.
static func _bed_half(out: Array, p: Vector3, id: int, data: Variant, cell: Vector3i) -> void:
	var h: float = 0.5625
	var top_tile: int = Nodes.tile(id,2)
	var padded_cell: Vector3i = cell+Vector3i.ONE
	var uv: Array = [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
	_quad(out,[p+Vector3(0,h,0),p+Vector3(1,h,0),p+Vector3(1,h,1),p+Vector3(0,h,1)],
		[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)],Vector3.UP,top_tile,Color.WHITE,false)
	# Pickups and unsupported beds need an underside too.
	var below: Vector3i = padded_cell+Vector3i.DOWN
	if Nodes.transparent(data[below.x+below.z*18+below.y*324]):
		_quad(out,[p,p+Vector3.RIGHT,p+Vector3(1,0,1),p+Vector3.BACK],
			uv,Vector3.DOWN,Nodes.tile(Nodes.PLANKS,3),Color(0.53,0.53,0.53),true)
	# Four sides: oak frame color, blanket shade on the long sides.
	var frame: Color = Color(0.62,0.62,0.62)
	for side in [[Vector3i(1,0,0),Vector3.RIGHT],[Vector3i(-1,0,0),Vector3.LEFT],[Vector3i(0,0,1),Vector3.BACK],[Vector3i(0,0,-1),Vector3.FORWARD]]:
		var d: Vector3i = side[0]
		var n: Vector3i = padded_cell+d
		var neighbor: int = data[n.x+n.z*18+n.y*324]
		if not Nodes.transparent(neighbor): continue
		var a: Vector3
		var b: Vector3
		if d.x == 1: a = p+Vector3(1,0,0); b = p+Vector3(1,0,1)
		elif d.x == -1: a = p+Vector3(0,0,1); b = p+Vector3(0,0,0)
		elif d.z == 1: a = p+Vector3(0,0,1); b = p+Vector3(1,0,1)
		else: a = p+Vector3(1,0,0); b = p+Vector3(0,0,0)
		# Both Z faces use the opposite vertex order to the X faces.
		_quad(out,[a,b,b+Vector3.UP*h,a+Vector3.UP*h],uv,Vector3(d.x,0,d.z),top_tile,frame,d.z != 0)

static func _portal(out: Array, p: Vector3, data: Variant, cell: Vector3i) -> void:
	var c: Vector3i = cell+Vector3i.ONE
	var along_x: bool = data[c.x+1+c.z*18+c.y*324] == Nodes.NETHER_PORTAL or data[c.x-1+c.z*18+c.y*324] == Nodes.NETHER_PORTAL
	var a: Vector3 = p+Vector3(0,0,0.5) if along_x else p+Vector3(0.5,0,0)
	var b: Vector3 = a+(Vector3.RIGHT if along_x else Vector3.BACK)
	var points: Array = [a,b,b+Vector3.UP,a+Vector3.UP]
	var uv: Array = [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
	var normal: Vector3 = Vector3.FORWARD if along_x else Vector3.RIGHT
	_quad(out,points,uv,normal,87,Color.WHITE,false)
	_quad(out,points,uv,-normal,87,Color.WHITE,true)

static func _art_box(out: Array, center: Vector3, extent: Vector3, side_tile: int, top_tile: int) -> void:
	for face in 6:
		var normal: Vector3 = [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD][face]
		var right: Vector3 = [Vector3.FORWARD,Vector3.BACK,Vector3.RIGHT,Vector3.RIGHT,Vector3.RIGHT,Vector3.LEFT][face]
		var up: Vector3 = normal.cross(right)
		var points: Array = []
		for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]: points.append(center+(normal+right*corner.x+up*corner.y)*extent*0.5)
		_quad(out,points,[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)],normal,top_tile if face == 2 else side_tile,Color.WHITE,true)

static func _enchanting_table(out: Array, p: Vector3) -> void:
	_art_box(out,p+Vector3(0.5,0.31,0.5),Vector3(1,0.62,1),88,88)
	# A hovering open book with a gilt spine and separate page blocks.
	_art_box(out,p+Vector3(0.5,0.82,0.5),Vector3(0.66,0.08,0.45),8,93)
	_art_box(out,p+Vector3(0.5,0.87,0.5),Vector3(0.035,0.035,0.46),49,49)

static func _end_portal(out: Array, p: Vector3) -> void:
	var points: Array = [p+Vector3(0,0.75,0),p+Vector3(1,0.75,0),p+Vector3(1,0.75,1),p+Vector3(0,0.75,1)]
	var uv: Array = [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
	_quad(out,points,uv,Vector3.UP,Nodes.tile(Nodes.END_PORTAL,2),Color.WHITE,false)
	_quad(out,points,uv,Vector3.DOWN,Nodes.tile(Nodes.END_PORTAL,2),Color.WHITE,true)

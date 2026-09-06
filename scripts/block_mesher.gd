class_name BlockMesher
extends RefCounted

# Greedy face merging: one quad for a coplanar rectangle of matching nodes.
# Only packed arrays leave the worker; GPU and scene resources stay on the main thread.
static func build(data: PackedByteArray) -> Array:
	var outputs: Array = [_empty(), _empty()]
	var has_nodes: bool = false
	for y in 16:
		for z in 16:
			for x in 16:
				var id: int = data[(x+1) + (z+1)*18 + (y+1)*324]
				if id == 0: continue
				has_nodes = true
				if Nodes.plant(id): _plant(outputs[0], Vector3(x,y,z), id)
				elif id == Nodes.TORCH: _torch(outputs[0], Vector3(x,y,z))
				elif id == Nodes.LADDER: _ladder(outputs[0], Vector3(x,y,z), data, Vector3i(x,y,z))
				elif id in [Nodes.BED_FOOT,Nodes.BED_HEAD]: _bed_half(outputs[0], Vector3(x,y,z), id, data, Vector3i(x,y,z))
	if not has_nodes: return [[], []]
	for axis in 3:
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		for sign_dir in [-1, 1]:
			var normal := Vector3.ZERO
			normal[axis] = sign_dir
			var face: int = axis * 2 + (0 if sign_dir == 1 else 1)
			for plane in 16:
				var mask := PackedInt32Array()
				mask.resize(256)
				for j in 16:
					for i in 16:
						var p := Vector3i.ONE
						p[axis] += plane
						p[u] += i
						p[v] += j
						var id: int = data[p.x + p.z*18 + p.y*324]
						if id == 0 or Nodes.plant(id) or id == Nodes.TORCH or id == Nodes.LADDER or id in [Nodes.BED_FOOT,Nodes.BED_HEAD]: continue
						p[axis] += sign_dir
						var neighbor: int = data[p.x + p.z*18 + p.y*324]
						if neighbor == id or not Nodes.transparent(neighbor): continue
						if id == Nodes.WATER and neighbor == Nodes.GLASS: continue
						mask[i + j*16] = id
				var j: int = 0
				while j < 16:
					var i: int = 0
					while i < 16:
						var id: int = mask[i + j*16]
						if id == 0: i += 1; continue
						var w: int = 1
						while i+w < 16 and mask[i+w+j*16] == id: w += 1
						var h: int = 1
						var expand: bool = true
						while j+h < 16 and expand:
							for k in w:
								if mask[i+k+(j+h)*16] != id: expand = false; break
							if expand: h += 1
						var p := Vector3.ZERO
						p[axis] = plane + (1 if sign_dir == 1 else 0)
						p[u] = i
						p[v] = j
						var du := Vector3.ZERO
						var dv := Vector3.ZERO
						du[u] = w
						dv[v] = h
						var uv: Array = [Vector2(0,h),Vector2(w,h),Vector2(w,0),Vector2(0,0)]
						if axis == 0: uv = [Vector2(0,w),Vector2(0,0),Vector2(h,0),Vector2(h,w)]
						var brightness: float = [0.82,0.73,1.0,0.53,0.87,0.77][face]
						_quad(outputs[1 if id == Nodes.WATER else 0], [p,p+du,p+du+dv,p+dv], uv, normal, Nodes.tile(id,face), Color(brightness,brightness,brightness), sign_dir == 1)
						for yy in h:
							for xx in w: mask[i+xx+(j+yy)*16] = 0
						i += w
					j += 1
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

static func _plant(out: Array, p: Vector3, id: int) -> void:
	var h: float = 0.55 if id == Nodes.WHEAT else 0.9
	if id in [Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM]: h = 0.45
	if id in [Nodes.SUGAR_CANE,Nodes.VINE]: h = 1.0
	var uv: Array = [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
	for flip in 2:
		var verts: Array = [p+Vector3(0.08,0,0.08),p+Vector3(0.92,0,0.92),p+Vector3(0.92,h,0.92),p+Vector3(0.08,h,0.08)] if flip == 0 else [p+Vector3(0.08,0,0.92),p+Vector3(0.92,0,0.08),p+Vector3(0.92,h,0.08),p+Vector3(0.08,h,0.92)]
		_quad(out,verts,uv,Vector3.UP,Nodes.tile(id,0),Color.WHITE,false)
		_quad(out,verts,uv,Vector3.UP,Nodes.tile(id,0),Color.WHITE,true)

static func _torch(out: Array, p: Vector3) -> void:
	var uv: Array = [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
	for axis in [0,2]:
		for side in [-1,1]:
			var a: Vector3 = p + Vector3(0.43,0,0.43)
			var b: Vector3 = p + Vector3(0.57,0,0.57)
			a[axis] = p[axis]+0.5+side*0.07
			b[axis] = a[axis]
			_quad(out,[a,b,b+Vector3.UP*0.75,a+Vector3.UP*0.75],uv,Vector3.UP,Nodes.TORCH,Color.WHITE,side == 1)

# A ladder is a flat quad mounted against the first solid neighbor (or the
# west face when free-standing, as when a supporting node was mined first).
static func _ladder(out: Array, p: Vector3, data: PackedByteArray, cell: Vector3i) -> void:
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
# family. Neighbor-aware so beds against walls skip hidden faces.
static func _bed_half(out: Array, p: Vector3, id: int, data: PackedByteArray, cell: Vector3i) -> void:
	var h: float = 0.5625
	var top_tile: int = Nodes.tile(id,2)
	var uv: Array = [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
	_quad(out,[p+Vector3(0,h,0),p+Vector3(1,h,0),p+Vector3(1,h,1),p+Vector3(0,h,1)],
		[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)],Vector3.UP,top_tile,Color.WHITE,false)
	# Four sides: oak frame color, blanket shade on the long sides.
	var frame: Color = Color(0.62,0.62,0.62)
	for side in [[Vector3i(1,0,0),Vector3.RIGHT],[Vector3i(-1,0,0),Vector3.LEFT],[Vector3i(0,0,1),Vector3.BACK],[Vector3i(0,0,-1),Vector3.FORWARD]]:
		var d: Vector3i = side[0]
		var n: Vector3i = cell+d
		if n.x >= 0 and n.x <= 17 and n.z >= 0 and n.z <= 17:
			var neighbor: int = data[n.x + n.z*18 + (cell.y+1)*324]
			# Skip faces against solid non-bed nodes; bed halves stay visible so
			# the pair reads as one continuous bed.
			if Nodes.solid(neighbor) and neighbor != Nodes.BED_FOOT and neighbor != Nodes.BED_HEAD: continue
		var a: Vector3
		var b: Vector3
		if d.x == 1: a = p+Vector3(1,0,0); b = p+Vector3(1,0,1)
		elif d.x == -1: a = p+Vector3(0,0,1); b = p+Vector3(0,0,0)
		elif d.z == 1: a = p+Vector3(0,0,1); b = p+Vector3(1,0,1)
		else: a = p+Vector3(1,0,0); b = p+Vector3(0,0,0)
		_quad(out,[a,b,b+Vector3.UP*h,a+Vector3.UP*h],uv,Vector3(d.x,0,d.z),top_tile,frame,d.x+d.z < 0)

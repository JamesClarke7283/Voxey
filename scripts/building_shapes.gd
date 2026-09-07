class_name BuildingShapes
extends RefCounted

# Stable 16-ID families: lower slab, upper slab, double slab, then four upright
# and four inverted stair facings. Reserve the final five states for additions.
const FIRST = 4000
const MATERIALS = [Nodes.PLANKS,Nodes.STONE,Nodes.COBBLE,Nodes.MOSSY_COBBLE,Nodes.BRICKS,Nodes.MOSSY_BRICKS,Nodes.RED_BRICKS,Nodes.SANDSTONE,Nodes.SANDSTONE_BRICK,Nodes.TERRACOTTA,Nodes.COBBLED_DEEPSLATE,Nodes.POLISHED_DEEPSLATE,Nodes.DEEPSLATE_BRICKS,Nodes.NETHER_BRICKS,Nodes.END_STONE,Nodes.END_BRICKS,Nodes.PURPUR,VillageContent.QUARTZ_BLOCK,VillageContent.GRANITE,VillageContent.DIORITE,VillageContent.ANDESITE,VillageContent.POLISHED_GRANITE,VillageContent.POLISHED_DIORITE,VillageContent.POLISHED_ANDESITE,MinecloniaOres.BLACKSTONE,Bastions.POLISHED,Bastions.BRICKS,Nodes.IRON_BLOCK,Nodes.GOLD_BLOCK,603,604,605,606,607,608,609,610,611,612,613,614,615,616,617,618,Masonry.DEEP_TILES,Masonry.CRACKED_DEEP_BRICKS,Masonry.CRACKED_DEEP_TILES,MinecloniaOres.TUFF,Masonry.POLISHED_TUFF,Masonry.TUFF_BRICKS]
const DIRECTIONS = [Vector3i.BACK,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.LEFT]
const SIDES = [Vector3i.RIGHT,Vector3i.LEFT,Vector3i.UP,Vector3i.DOWN,Vector3i.BACK,Vector3i.FORWARD]
static var icon_cache: Dictionary = {}

static func is_shape(id: int) -> bool: return id >= FIRST and id < FIRST+MATERIALS.size()*16 and (id-FIRST)%16 <= 10
static func variant(id: int) -> int: return (id-FIRST)%16
static func material(id: int) -> int: return MATERIALS[(id-FIRST)/16]
static func family(id: int) -> int: return FIRST+(id-FIRST)/16*16
static func slab_for(base: int) -> int: return FIRST+MATERIALS.find(base)*16 if base in MATERIALS else 0
static func stair_for(base: int) -> int: return slab_for(base)+3 if base in MATERIALS else 0
static func stair(id: int) -> bool: return is_shape(id) and variant(id) >= 3
static func half_slab(id: int) -> bool: return is_shape(id) and variant(id) < 2
static func upper(id: int) -> bool: return variant(id) == 1 or variant(id) >= 7
static func facing(id: int) -> int: return (variant(id)-3)%4
static func item(id: int) -> int: return family(id)+(3 if stair(id) else 0)
static func count(id: int) -> int: return 2 if variant(id) == 2 else 1
static func title(id: int) -> String:
	var name: String = "Oak" if material(id) == Nodes.PLANKS else Nodes.title(material(id))
	return name+ (" stairs" if stair(id) else " slab")
static func items() -> Array:
	var ids: Array = []
	for base in MATERIALS: ids.append(slab_for(base)); ids.append(stair_for(base))
	return ids

# Matches mcl_stairs/cornerstair.lua's lead/trail rules. Stored facings are the
# original placement orientation; corners are derived, never recursively saved.
static func mask(id: int, neighbors: Array = []) -> int:
	if not is_shape(id): return 255 if Nodes.solid(id) and not Nodes.transparent(id) else 0
	var state: int = variant(id)
	if state == 2: return 255
	if state < 2: return 15 if state == 0 else 240
	var direction: int = facing(id)
	var inverted: bool = upper(id)
	var shape: int = 0 # straight, outer, inner
	var visual: int = direction
	if neighbors.size() == 4:
		var observed: Array = []
		for n in neighbors: observed.append(facing(n) if stair(n) and upper(n) == inverted else -1)
		var lead: int = observed[direction]
		var trail: int = observed[(direction+2)%4]
		var left: bool = observed[(direction+3)%4] == direction
		var right: bool = observed[(direction+1)%4] == direction
		if inverted: var saved: bool = left; left = right; right = saved
		for rule in [[lead,-1,right,1],[lead,1,left,1],[trail,-1,left,2],[trail,1,right,2]]:
			var turn: int = int(rule[1])*(-1 if inverted else 1)
			if rule[0] != posmod(direction+turn,4) or rule[2]: continue
			shape = rule[3]
			if rule[1] == 1: visual = posmod(direction+(-1 if inverted else 1),4)
			break
	var result: int = 0
	for y in 2:
		for z in 2:
			for x in 2:
				var filled: bool = y == 0 or (z == 1 and (shape != 1 or x == 0)) or (shape == 2 and x == 0)
				if not filled: continue
				var point := Vector3i(1-x if inverted else x,1-y if inverted else y,z)
				for turn in visual: point = Vector3i(point.z,point.y,1-point.x)
				result |= 1 << (point.x+point.z*2+point.y*4)
	return result

static func occupied(bits: int, p: Vector3i) -> bool: return bits & (1 << (p.x+p.z*2+p.y*4)) != 0
static func neighbors_in(data: Variant, p: Vector3i) -> Array:
	var values: Array = []
	for side in DIRECTIONS:
		var q: Vector3i = p+side
		values.append(data[q.x+q.z*18+q.y*324] if q.x >= 0 and q.x < 18 and q.z >= 0 and q.z < 18 else 0)
	return values
static func world_mask(world: VoxelWorld, p: Vector3i) -> int:
	var id: int = world.node_at(p)
	var neighbors: Array = []
	if stair(id):
		for side in DIRECTIONS: neighbors.append(world.node_at(p+side))
	return mask(id,neighbors)

static func boxes(bits: int) -> Array:
	if bits == 255: return [AABB(Vector3.ZERO,Vector3.ONE)]
	var result: Array = []
	for y in 2:
		for z in 2:
			for x in 2:
				var p := Vector3i(x,y,z)
				if occupied(bits,p): result.append(AABB(Vector3(p)*0.5,Vector3.ONE*0.5))
	return result

static func mesh(out: Array, p: Vector3, id: int, data: Variant, padded_cell: Vector3i, override_mask: int = -1) -> void:
	var bits: int = mask(id,neighbors_in(data,padded_cell)) if override_mask < 0 else override_mask
	var around: Array = []
	for side in SIDES:
		var q: Vector3i = padded_cell+side
		var neighbor: int = data[q.x+q.z*18+q.y*324]
		if is_shape(neighbor):
			# The neighbor's corner can need a second halo cell. Keep its boundary
			# face when that information is outside the snapshot, avoiding holes.
			around.append(mask(neighbor,neighbors_in(data,q)) if q.x > 0 and q.x < 17 and q.z > 0 and q.z < 17 else 0)
		else: around.append(255 if not Nodes.transparent(neighbor) and neighbor not in [Nodes.BED_FOOT,Nodes.BED_HEAD,Nodes.ENCHANTING_TABLE] else 0)
	for y in 2:
		for z in 2:
			for x in 2:
				var cell := Vector3i(x,y,z)
				if not occupied(bits,cell): continue
				for face in 6:
					var next: Vector3i = cell+SIDES[face]
					var internal: bool = next.x in [0,1] and next.y in [0,1] and next.z in [0,1]
					if occupied(bits if internal else around[face],Vector3i(posmod(next.x,2),posmod(next.y,2),posmod(next.z,2))): continue
					var normal: Vector3 = Vector3(SIDES[face])
					var right: Vector3 = [Vector3.FORWARD,Vector3.BACK,Vector3.RIGHT,Vector3.RIGHT,Vector3.RIGHT,Vector3.LEFT][face]
					var up: Vector3 = normal.cross(right)
					var center: Vector3 = Vector3(cell)*0.5+Vector3.ONE*0.25
					var points: Array = []; var uv: Array = []
					for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
						var local: Vector3 = center+(normal+right*corner.x+up*corner.y)*0.25
						points.append(p+local)
						uv.append(Vector2(local.dot(right)+(1.0 if right.dot(Vector3.ONE) < 0 else 0.0),-local.dot(up)+(1.0 if up.dot(Vector3.ONE) > 0 else 0.0)))
					var shade: float = [0.82,0.73,1.0,0.53,0.87,0.77][face]
					BlockMesher._quad(out,points,uv,normal,Nodes.tile(material(id),face),Color(shade,shade,shade),true)

static func recipes(inv: Inventory) -> void:
	for base in MATERIALS:
		inv._recipe(title(slab_for(base)),slab_for(base),6,[base,base,base],3,"table")
		inv._recipe(title(stair_for(base)),stair_for(base),4,[base,0,0,base,base,0,base,base,base],3,"table")

static func stonecutter_inputs(base: int) -> Array:
	# Source _mcl_stonecutter_recipes includes earlier stages of these materials.
	# Decorative metal stairs have crafting recipes but no stonecutter recipes.
	match base:
		Nodes.PLANKS,Nodes.IRON_BLOCK,Nodes.GOLD_BLOCK: return []
		Masonry.CRACKED_DEEP_BRICKS,Masonry.CRACKED_DEEP_TILES: return []
		Masonry.DEEP_TILES: return [Nodes.COBBLED_DEEPSLATE,Nodes.POLISHED_DEEPSLATE,Nodes.DEEPSLATE_BRICKS,Masonry.DEEP_TILES,Nodes.DEEPSLATE]
		Masonry.POLISHED_TUFF: return [MinecloniaOres.TUFF,Masonry.POLISHED_TUFF]
		Masonry.TUFF_BRICKS: return [MinecloniaOres.TUFF,Masonry.POLISHED_TUFF,Masonry.TUFF_BRICKS]
		Nodes.COBBLE: return [Nodes.COBBLE,Nodes.STONE]
		Nodes.BRICKS: return [Nodes.STONE,Nodes.BRICKS]
		Nodes.SANDSTONE_BRICK: return [Nodes.SANDSTONE,Nodes.SANDSTONE_BRICK]
		Nodes.COBBLED_DEEPSLATE: return [Nodes.COBBLED_DEEPSLATE,Nodes.DEEPSLATE]
		Nodes.POLISHED_DEEPSLATE: return [Nodes.COBBLED_DEEPSLATE,Nodes.POLISHED_DEEPSLATE,Nodes.DEEPSLATE]
		Nodes.DEEPSLATE_BRICKS: return [Nodes.COBBLED_DEEPSLATE,Nodes.POLISHED_DEEPSLATE,Nodes.DEEPSLATE_BRICKS,Nodes.DEEPSLATE]
		VillageContent.POLISHED_GRANITE: return [VillageContent.GRANITE,VillageContent.POLISHED_GRANITE]
		VillageContent.POLISHED_DIORITE: return [VillageContent.DIORITE,VillageContent.POLISHED_DIORITE]
		VillageContent.POLISHED_ANDESITE: return [VillageContent.ANDESITE,VillageContent.POLISHED_ANDESITE]
		Bastions.POLISHED: return [MinecloniaOres.BLACKSTONE,Bastions.POLISHED]
		Bastions.BRICKS: return [MinecloniaOres.BLACKSTONE,Bastions.POLISHED,Bastions.BRICKS]
	return [base]

static func try_place(game: Node, target: Dictionary) -> bool:
	var held: int = game.inventory.held().id
	if not is_shape(held) or target.is_empty(): return false
	if held != item(held): return true
	var normal: Vector3i = target.normal
	var at: Vector3i = target.pos+normal
	var id: int = item(held)
	var hit: Vector3 = target.get("point",game.player.camera.global_position-game.player.camera.global_basis.z*float(target.get("distance",0)))
	var inverted: bool = normal.y < 0 or normal.y == 0 and hit.y-floorf(hit.y) > 0.55
	if half_slab(held):
		if half_slab(target.id) and family(target.id) == family(held) and ((variant(target.id) == 0 and normal.y > 0) or (variant(target.id) == 1 and normal.y < 0)):
			at = target.pos; id = family(held)+2
		elif half_slab(game.world.node_at(at)) and family(game.world.node_at(at)) == family(held): id = family(held)+2
		else: id += 1 if inverted else 0
	else:
		var look: Vector3 = -game.player.camera.global_basis.z
		var facing_value: int = (1 if look.x > 0 else 3) if absf(look.x) > absf(look.z) else (0 if look.z > 0 else 2)
		id += facing_value+(4 if inverted else 0)
	var previous: int = game.world.node_at(at)
	if Nodes.solid(previous) and not (half_slab(previous) and family(previous) == family(id) and variant(id) == 2): return true
	var neighbors: Array = []
	for side in DIRECTIONS: neighbors.append(game.world.node_at(at+side))
	var body := AABB(game.player.position-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58))
	for box in boxes(mask(id,neighbors)):
		if AABB(Vector3(at)+box.position,box.size).intersects(body): return true
	if game.world.set_node(at,id):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,id)
	return true

static func supports(world: VoxelWorld, p: Vector3i, normal: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if not is_shape(id): return Nodes.solid(id)
	var bits: int = world_mask(world,p)
	var axis: int = 0 if normal.x != 0 else (1 if normal.y != 0 else 2)
	var side: int = 1 if normal[axis] > 0 else 0
	for a in 2:
		for b in 2:
			var cell := Vector3i.ZERO
			cell[axis] = side; cell[(axis+1)%3] = a; cell[(axis+2)%3] = b
			if not occupied(bits,cell): return false
	return true

static func icon_faces(id: int) -> Array:
	id = item(id)
	if icon_cache.has(id): return icon_cache[id]
	var data := PackedInt32Array(); data.resize(5832); data[343] = id
	var out: Array = BlockMesher._empty()
	# Face the open stair tread toward the inventory camera.
	mesh(out,Vector3.ZERO,id+2 if stair(id) else id,data,Vector3i.ONE)
	var faces: Array = []
	for start in range(0,out[0].size(),4):
		var normal: Vector3 = out[1][start]
		if normal.dot(Vector3.ONE) <= 0: continue
		var depth: float = 0
		var points := PackedVector2Array(); var uv := PackedVector2Array()
		for i in 4:
			var vertex: Vector3 = out[0][start+i]-Vector3.ONE*0.5
			points.append(Vector2((vertex.x-vertex.z)*9,(vertex.x+vertex.z)*5-vertex.y*14))
			depth += vertex.dot(Vector3.ONE)
			uv.append(out[2][start+i])
		faces.append({"points":points,"uv":uv,"tile":out[3][start],"shade":out[4][start],"depth":depth})
	faces.sort_custom(func(a: Dictionary,b: Dictionary): return a.depth < b.depth)
	icon_cache[id] = faces
	return faces

static var visual_cache: Dictionary = {}
static func visuals(bits: int) -> Dictionary:
	if visual_cache.has(bits): return visual_cache[bits]
	var data := PackedInt32Array(); data.resize(5832)
	var out: Array = BlockMesher._empty()
	mesh(out,Vector3.ZERO,FIRST,data,Vector3i.ONE,bits)
	var edges: Dictionary = {}
	for start in range(0,out[0].size(),4):
		for edge in 4:
			var a: Vector3 = out[0][start+edge]
			var b: Vector3 = out[0][start+(edge+1)%4]
			var key: String = str(a)+":"+str(b) if a < b else str(b)+":"+str(a)
			var face_key: String = key+":"+str(out[1][start])
			if edges.has(face_key): edges.erase(face_key)
			else: edges[face_key] = [key,a,b]
	var outline := ImmediateMesh.new()
	outline.surface_begin(Mesh.PRIMITIVE_LINES)
	var drawn: Dictionary = {}
	for edge in edges.values():
		if drawn.has(edge[0]): continue
		drawn[edge[0]] = true
		outline.surface_add_vertex(edge[1]*1.006-Vector3.ONE*0.003)
		outline.surface_add_vertex(edge[2]*1.006-Vector3.ONE*0.003)
	outline.surface_end()
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	var vertices: PackedVector3Array = out[0].duplicate()
	for i in vertices.size(): vertices[i] += out[1][i]*0.003
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = out[1]
	arrays[Mesh.ARRAY_TEX_UV] = out[2]; arrays[Mesh.ARRAY_INDEX] = out[5]
	var cracks := ArrayMesh.new(); cracks.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	visual_cache[bits] = {"outline":outline,"cracks":cracks}
	return visual_cache[bits]

class_name Barriers
extends RefCounted

# Geometry, connections and recipes translated from the local Mineclonia
# mcl_fences, mcl_walls, mcl_trees and mclx_fences sources (GPL-3.0-or-later).
# State IDs are stable: each fence family reserves 16 IDs, gate facings 1..4
# closed and 5..8 open. Wall connections are derived from neighbors.
const FIRST = 5000
const WALL_FIRST = 5100
const FENCE_BASES = [5000,5016,5300,5316,5332,5348,5364]
const FENCE_MATERIALS = [Nodes.PLANKS,Nodes.NETHER_BRICKS,6035,6067,6099,6131,6163]
const WALL_MATERIALS = [Nodes.COBBLE,Nodes.MOSSY_COBBLE,Nodes.RED_BRICKS,Nodes.SANDSTONE,Nodes.BRICKS,Nodes.MOSSY_BRICKS,VillageContent.GRANITE,VillageContent.DIORITE,VillageContent.ANDESITE,Nodes.NETHER_BRICKS,Nodes.END_BRICKS,MinecloniaOres.BLACKSTONE,Bastions.POLISHED,Bastions.BRICKS,Nodes.COBBLED_DEEPSLATE,Nodes.POLISHED_DEEPSLATE,Nodes.DEEPSLATE_BRICKS,Masonry.DEEP_TILES,MinecloniaOres.TUFF,Masonry.POLISHED_TUFF,Masonry.TUFF_BRICKS,NetherBlocks.RED_NETHER_BRICKS,NetherBlocks.NETHER_WART_BLOCK,NetherBlocks.CHISELED_QUARTZ,NetherBlocks.SMOOTH_QUARTZ,NetherBlocks.QUARTZ_BRICK,NetherBlocks.POLISHED_BASALT,NetherBlocks.CRACKED_BLACKSTONE_BRICKS]
const SIDES = [Vector3i.RIGHT,Vector3i.BACK,Vector3i.LEFT,Vector3i.FORWARD]
static var icon_cache: Dictionary = {}
static var visual_cache: Dictionary = {}

static func family(id: int) -> int:
	if id >= FIRST and id < FIRST+32: return FIRST+(id-FIRST)/16*16
	if id >= 5300 and id < 5380: return 5300+(id-5300)/16*16
	return -1
static func is_fence(id: int) -> bool: return id in FENCE_BASES
static func is_gate(id: int) -> bool: return family(id) >= 0 and id-family(id) in range(1,9)
static func is_wall(id: int) -> bool: return id >= WALL_FIRST and id < WALL_FIRST+WALL_MATERIALS.size()
static func is_barrier(id: int) -> bool: return is_fence(id) or is_gate(id) or is_wall(id)
static func item(id: int) -> int: return family(id)+1 if is_gate(id) else id
static func facing(id: int) -> int: return (id-family(id)-1)%4
static func open(id: int) -> bool: return is_gate(id) and id-family(id) >= 5
static func material(id: int) -> int: return WALL_MATERIALS[id-WALL_FIRST] if is_wall(id) else FENCE_MATERIALS[FENCE_BASES.find(family(id))]
static func title(id: int) -> String: return (WoodTypes.NAMES[WoodTypes.species(material(id))] if WoodTypes.is_planks(material(id)) else Nodes.title(material(id)))+(" wall" if is_wall(id) else (" fence gate" if is_gate(id) else " fence"))
static func items() -> Array:
	var ids: Array = []
	for base in FENCE_BASES: ids.append(base); ids.append(base+1)
	for i in WALL_MATERIALS.size(): ids.append(WALL_FIRST+i)
	return ids

static func full_solid(id: int) -> bool:
	# mcl's solid group describes a full block, not every walkable node.
	return not is_barrier(id) and Nodes.solid(id) and (not Nodes.transparent(id) or id in [Nodes.GLASS,Nodes.ICE]) and id not in [Nodes.BED_FOOT,Nodes.BED_HEAD,Nodes.ENCHANTING_TABLE]

static func connects(id: int, other: int) -> bool:
	if is_wall(id): return is_wall(other) or full_solid(other)
	if is_fence(id): return full_solid(other) or (is_fence(other) or is_gate(other)) and (material(id) == material(other) or WoodTypes.is_planks(material(id)) and WoodTypes.is_planks(material(other)))
	return false

static func neighbors(world: VoxelWorld, p: Vector3i) -> Array:
	var result: Array = []
	for d in SIDES: result.append(world.node_at(p+d))
	result.append(world.node_at(p+Vector3i.UP))
	return result

static func mask(id: int, around: Array) -> int:
	var bits: int = 0
	for side in mini(4,around.size()):
		if connects(id,int(around[side])): bits |= 1 << side
	if is_wall(id) and bits in [5,10] and around.size() > 4:
		var above: int = around[4]
		if is_wall(above) or full_solid(above) or is_fence(above) or Torches.is_torch(above): bits += 11
	return bits

static func rotate_box(box: AABB, turns: int) -> AABB:
	for turn in turns:
		box = AABB(Vector3(1-box.end.z,box.position.y,box.position.x),Vector3(box.size.z,box.size.y,box.size.x))
	return box

static func boxes(id: int, bits: int = 0, collision: bool = false, selection: bool = false) -> Array:
	var result: Array = []
	if is_gate(id):
		if collision and open(id): return []
		if collision: return [rotate_box(AABB(Vector3(0,0.3125,0.375),Vector3(1,1.1875,0.25)),facing(id))]
		if selection: return [rotate_box(AABB(Vector3(0,0.3125,0.4375),Vector3(1,0.6875,0.125)),facing(id))]
		result = [AABB(Vector3(0,0.3125,0.4375),Vector3(0.125,0.6875,0.125)),AABB(Vector3(0.875,0.3125,0.4375),Vector3(0.125,0.6875,0.125))]
		if open(id):
			# Source's two folded leaves are deliberately asymmetric at the tips.
			for y in [0.375,0.75]:
				result.append(AABB(Vector3(0,y,0.5625),Vector3(0.125,0.1875,0.3125)))
				result.append(AABB(Vector3(0.875,y,0.5625),Vector3(0.125,0.1875,0.4375)))
			result.append(AABB(Vector3(0,0.375,0.875),Vector3(0.125,0.5625,0.125)))
			result.append(AABB(Vector3(0.875,0.5625,0.875),Vector3(0.125,0.1875,0.125)))
		else:
			result.append(AABB(Vector3(0.375,0.375,0.4375),Vector3(0.25,0.5625,0.125)))
			for x in [0.0,0.625]:
				for y in [0.375,0.75]: result.append(AABB(Vector3(x,y,0.4375),Vector3(0.375,0.1875,0.125)))
		for i in result.size(): result[i] = rotate_box(result[i],facing(id))
	elif is_wall(id):
		# The checkout uses a tall central collision box, even on straight walls.
		if collision: return [AABB(Vector3(0.25,0,0.25),Vector3(0.5,1.5,0.5))]
		var sides: int = 5 if bits == 16 else (10 if bits == 21 else bits)
		if bits not in [5,10]: result.append(AABB(Vector3(0.25,0,0.25),Vector3(0.5,1,0.5)))
		if sides&5 == 5: result.append(AABB(Vector3(0,0,0.3125),Vector3(1,0.8125,0.375)))
		else:
			for side in [0,2]:
				if sides&(1<<side): result.append(rotate_box(AABB(Vector3(0.75,0,0.3125),Vector3(0.25,0.8125,0.375)),side))
		if sides&10 == 10: result.append(AABB(Vector3(0.3125,0,0),Vector3(0.375,0.8125,1)))
		else:
			for side in [1,3]:
				if sides&(1<<side): result.append(rotate_box(AABB(Vector3(0.75,0,0.3125),Vector3(0.25,0.8125,0.375)),side))
	else:
		result.append(AABB(Vector3(0.375,0,0.375),Vector3(0.25,1.51 if collision else 1,0.25)))
		for side in 4:
			if not bits&(1<<side): continue
			if collision: result.append(rotate_box(AABB(Vector3(0.625,0,0.375),Vector3(0.375,1.51,0.25)),side))
			else:
				for y in [0.375,0.75]: result.append(rotate_box(AABB(Vector3(0.625,y,0.4375),Vector3(0.375,0.1875,0.125)),side))
	return result

static func world_boxes(world: VoxelWorld, p: Vector3i, collision: bool = false, selection: bool = false) -> Array:
	var id: int = world.node_at(p)
	return boxes(id,mask(id,neighbors(world,p)),collision,selection)

static func mesh(out: Array, p: Vector3, id: int, data: Variant, cell: Vector3i) -> void:
	var around: Array = []
	for d in SIDES+[Vector3i.UP]:
		var q: Vector3i = cell+d
		around.append(data[q.x+q.z*18+q.y*324])
	for box in boxes(id,mask(id,around)):
		BlockMesher._art_box(out,p+box.get_center(),box.size,Nodes.tile(material(id),0),Nodes.tile(material(id),2))

static func set_open(world: VoxelWorld, p: Vector3i, value: bool) -> bool:
	var id: int = world.node_at(p)
	if not is_gate(id) or open(id) == value: return false
	return world.set_node(p,item(id)+facing(id)+(4 if value else 0))

static func use(game: Node, target: Dictionary) -> bool:
	if target.is_empty() or game.target_mob() != null: return false
	if Input.is_physical_key_pressed(KEY_CTRL) or (game.touch and is_instance_valid(game.controls) and game.controls.sneak_held): return false
	if is_gate(target.id):
		set_open(game.world,target.pos,not open(target.id))
		game.player.swing = 1; game.sound("place")
		return true
	if is_fence(target.id) and game.leads.anchor_at(target.pos): return true
	return false

static func try_place(game: Node, target: Dictionary) -> bool:
	var id: int = game.inventory.held().id
	if not is_barrier(id) or target.is_empty(): return false
	if id != item(id): return true
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	var previous: int = game.world.node_at(at)
	if previous != Nodes.AIR and not SnowCover.is_snow(previous) and not Fluids.liquid(previous) and not Nodes.plant(previous) and not Fire.is_fire(previous): return true
	if is_gate(id):
		var look: Vector3 = -game.player.camera.global_basis.z
		id += (1 if look.x < 0 else 3) if absf(look.x)>absf(look.z) else (0 if look.z>0 else 2)
	var body := AABB(game.player.position-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58))
	for box in boxes(id,mask(id,neighbors(game.world,at)),true):
		if body.intersects(AABB(Vector3(at)+box.position,box.size)): return true
	if game.world.set_node(at,id):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,id)
	return true

static func recipes(inv: Inventory) -> void:
	for i in FENCE_MATERIALS.size():
		var base: int = FENCE_MATERIALS[i]
		var stick: int = Nodes.NETHER_BRICK_ITEM if i == 1 else Nodes.STICK
		inv._recipe(title(FENCE_BASES[i]),FENCE_BASES[i],6 if i == 1 else 3,[base,stick,base,base,stick,base],3,"table")
		inv._recipe(title(FENCE_BASES[i]+1),FENCE_BASES[i]+1,2 if i == 1 else 1,[stick,base,stick,stick,base,stick],3,"table")
	for i in WALL_MATERIALS.size():
		var base: int = WALL_MATERIALS[i]
		inv._recipe(title(WALL_FIRST+i),WALL_FIRST+i,6,[base,base,base,base,base,base],3,"table")

static func stonecutter_inputs(base: int) -> Array:
	if base == Bastions.BRICKS: return [MinecloniaOres.BLACKSTONE,Bastions.POLISHED,Bastions.BRICKS]
	if base == Masonry.POLISHED_TUFF: return [MinecloniaOres.TUFF,Masonry.POLISHED_TUFF]
	if base == Masonry.TUFF_BRICKS: return [MinecloniaOres.TUFF,Masonry.POLISHED_TUFF,Masonry.TUFF_BRICKS]
	return BuildingShapes.stonecutter_inputs(base)

static func icon_faces(id: int) -> Array:
	id = item(id)
	if icon_cache.has(id): return icon_cache[id]
	var out: Array = BlockMesher._empty()
	for box in boxes(id,5): BlockMesher._art_box(out,box.get_center(),box.size,Nodes.tile(material(id),0),Nodes.tile(material(id),2))
	var faces: Array = project_icon(out)
	icon_cache[id] = faces
	return faces

static func project_icon(out: Array) -> Array:
	var faces: Array = []
	for start in range(0,out[0].size(),4):
		var normal: Vector3 = out[1][start]
		if normal.dot(Vector3.ONE) <= 0: continue
		var points := PackedVector2Array(); var uv := PackedVector2Array(); var depth: float = 0
		for i in 4:
			var v: Vector3 = out[0][start+i]-Vector3.ONE*0.5
			points.append(Vector2((v.x-v.z)*9,(v.x+v.z)*5-v.y*14)); depth += v.dot(Vector3.ONE); uv.append(out[2][start+i])
		faces.append({"points":points,"uv":uv,"tile":out[3][start],"shade":Color.WHITE.darkened(0.2 if normal.x > 0 else (0.35 if normal.z > 0 else 0.0)),"depth":depth})
	faces.sort_custom(func(a: Dictionary,b: Dictionary): return a.depth < b.depth)
	return faces

static func visuals(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var id: int = world.node_at(p)
	var bits: int = mask(id,neighbors(world,p))
	return box_visuals(boxes(id,bits,false,true),str(id)+":"+str(bits))

static func box_visuals(shape_boxes: Array, key: String) -> Dictionary:
	if visual_cache.has(key): return visual_cache[key]
	var out: Array = BlockMesher._empty()
	for box in shape_boxes: BlockMesher._art_box(out,box.get_center(),box.size,0,0)
	var outline := ImmediateMesh.new(); outline.surface_begin(Mesh.PRIMITIVE_LINES)
	for start in range(0,out[0].size(),4):
		for edge in 4:
			outline.surface_add_vertex(out[0][start+edge]*1.004-Vector3.ONE*0.002)
			outline.surface_add_vertex(out[0][start+(edge+1)%4]*1.004-Vector3.ONE*0.002)
	outline.surface_end()
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out[0]; arrays[Mesh.ARRAY_NORMAL] = out[1]; arrays[Mesh.ARRAY_TEX_UV] = out[2]; arrays[Mesh.ARRAY_INDEX] = out[5]
	var cracks := ArrayMesh.new(); cracks.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	visual_cache[key] = {"outline":outline,"cracks":cracks}
	return visual_cache[key]

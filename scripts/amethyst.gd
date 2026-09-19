class_name Amethyst
extends RefCounted

# Local Mineclonia mcl_amethyst; attribution and engine adapters in docs.
const BLOCK = 7700
const BUDDING = 7701
const CALCITE = 7702
const SMOOTH_BASALT = 7703
const TINTED_GLASS = 7704
const SHARD = 7705
const SMALL = 7708
const MEDIUM = 7716
const LARGE = 7724
const CLUSTER = 7732
const STAGES = [SMALL,MEDIUM,LARGE,CLUSTER]
const BLOCKS = [BLOCK,BUDDING,CALCITE,SMOOTH_BASALT,TINTED_GLASS,SMALL,MEDIUM,LARGE,CLUSTER]
const SUPPORTS = [Vector3i.DOWN,Vector3i.UP,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
const INTERVAL = 68.0
const CHANCE = 5
const DATA = {
	7700:{"name":"Block of amethyst","block":true,"color":"9567c5","hardness":1.5,"tool":0},
	7701:{"name":"Budding amethyst","block":true,"color":"a578cd","hardness":1.5,"tool":0,"drop":0},
	7702:{"name":"Calcite","block":true,"color":"e0ddcf","hardness":0.75,"tool":0},
	7703:{"name":"Smooth basalt","block":true,"color":"56535b","hardness":1.25,"blast_resistance":4.2,"tool":0,"note_material":"stone"},
	7704:{"name":"Tinted glass","block":true,"color":"51445c","hardness":0.3,"tool":-1,"transparent":true,"note_material":"glass"},
	7705:{"name":"Amethyst shard","color":"b385e2"},
	7708:{"name":"Small amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0},
	7709:{"name":"Small amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7710:{"name":"Small amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7711:{"name":"Small amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7712:{"name":"Small amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7713:{"name":"Small amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7716:{"name":"Medium amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0},
	7717:{"name":"Medium amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7718:{"name":"Medium amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7719:{"name":"Medium amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7720:{"name":"Medium amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7721:{"name":"Medium amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7724:{"name":"Large amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0},
	7725:{"name":"Large amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7726:{"name":"Large amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7727:{"name":"Large amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7728:{"name":"Large amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7729:{"name":"Large amethyst bud","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7732:{"name":"Amethyst cluster","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0},
	7733:{"name":"Amethyst cluster","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7734:{"name":"Amethyst cluster","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7735:{"name":"Amethyst cluster","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7736:{"name":"Amethyst cluster","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
	7737:{"name":"Amethyst cluster","block":true,"shape":"amethyst","color":"b385e2","hardness":1.5,"tool":0,"drop":0,"hidden":true},
}
static var icons: Dictionary = {}
static func is_crystal(id: int) -> bool: return id >= SMALL and id <= CLUSTER+5 and (id-SMALL)%8 < 6
static func stage(id: int) -> int: return (id-SMALL)/8 if is_crystal(id) else -1
static func is_amethyst(id: int) -> bool: return DATA.has(id)
static func item(id: int) -> int: return STAGES[stage(id)] if is_crystal(id) else id
static func support(id: int) -> Vector3i: return SUPPORTS[(id-SMALL)%8] if is_crystal(id) else Vector3i.DOWN
static func oriented(id: int, normal: Vector3i) -> int:
	var face: int = SUPPORTS.find(-normal)
	return item(id)+maxi(face,0) if is_crystal(id) else id
static func light_level(id: int) -> int: return [1,2,4,5][stage(id)] if is_crystal(id) else 0
static func tracked(id: int) -> bool: return id == BUDDING or is_crystal(id)
static func transform(id: int, point: Vector3) -> Vector3:
	return Basis(Quaternion(Vector3.UP,-Vector3(support(id))))*(point-Vector3.ONE*0.5)+Vector3.ONE*0.5
static func boxes(id: int) -> Array:
	if not is_crystal(id): return [AABB(Vector3.ZERO,Vector3.ONE)]
	var rank: int = stage(id)
	var width: float = [8.0,9.0,9.0,9.6][rank]/16.0
	var low: float = 1.0/16 if rank == 0 else 0.0
	var height: float = [4.0,6.0,7.0,11.9][rank]/16.0
	var box := AABB(Vector3((1-width)*0.5,low,(1-width)*0.5),Vector3(width,height,width))
	var result := AABB(transform(id,box.position),Vector3.ZERO)
	for x in 2:
		for y in 2:
			for z in 2: result = result.expand(transform(id,box.position+box.size*Vector3(x,y,z)))
	return [result]

static func recipes(inv: Inventory) -> void:
	inv._recipe("Block of amethyst",BLOCK,1,[SHARD,SHARD,SHARD,SHARD],2)
	inv._recipe("Tinted glass",TINTED_GLASS,2,[0,SHARD,0,SHARD,Nodes.GLASS,SHARD,0,SHARD,0],3,"table")

static func harvest(id: int, slot: Dictionary) -> Array:
	if id == TINTED_GLASS: return [[TINTED_GLASS,1]]
	if id == BUDDING or id == SHARD: return []
	var tool: int = int(slot.get("id",0))
	if not Nodes.is_tool_id(tool) or Nodes.tool_kind(tool) != 0: return []
	if is_crystal(id):
		if Inventory.enchantment(slot,"Silk Touch") > 0: return [[item(id),1]]
		# Source has no _mcl_fortune_drop. Fortune does not alter this result.
		return [[SHARD,4]] if stage(id) == 3 else []
	return [[id,1]] if id in [BLOCK,CALCITE,SMOOTH_BASALT] else []

static func environment_drops(id: int) -> Array:
	return [[SHARD,2]] if is_crystal(id) and stage(id) == 3 else []

static func piston_break(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if id != BUDDING and not is_crystal(id): return false
	if not world.set_node(p,Nodes.AIR): return false
	for entry in environment_drops(id): world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
	return true

static func supported(world: VoxelWorld, p: Vector3i, id: int, placing: bool = false) -> bool:
	var at: Vector3i = p+support(id)
	if not world.loaded_at(Vector3(at)): return not placing
	return Nodes.solid(world.node_at(at))

static func try_place(game: Node3D, target: Dictionary) -> bool:
	var id: int = int(game.inventory.held().id)
	if not is_crystal(id) or target.is_empty(): return false
	var target_id: int = int(target.get("id",0))
	var at: Vector3i = target.get("replace",target.pos if Nodes.plant(target_id) or SnowCover.is_snow(target_id) else target.pos+target.normal)
	var current: int = game.world.node_at(at)
	if current != Nodes.AIR and not Fluids.water(current) and not Nodes.plant(current) and not SnowCover.is_snow(current): return true
	id = oriented(id,target.normal)
	if not supported(game.world,at,id,true): return true
	for box in boxes(id):
		if AABB(Vector3(at)+box.position,box.size).intersects(AABB(game.player.position-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58))): return true
	if game.world.set_node(at,id):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("place"); game.api.emit_node_placed(at,id)
	return true

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("amethyst"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+7701
		world.set_meta("amethyst",{"cells":{},"columns":{},"jobs":[],"cursor":0,"rng":rng})
	return world.get_meta("amethyst")

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if not tracked(id) or not world.loaded_at(Vector3(p)): return
	var data: Dictionary = runtime(world)
	data.cells[p] = id
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if not data.columns.has(column): data.columns[column] = {}
	data.columns[column][p] = true

static func forget(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("amethyst"): return
	var data: Dictionary = runtime(world); data.cells.erase(p)
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0))
	if data.columns.has(column):
		data.columns[column].erase(p)
		if data.columns[column].is_empty(): data.columns.erase(column)

static func changed(world: VoxelWorld, p: Vector3i, _old: int, id: int) -> void:
	forget(world,p); registered(world,p,id)
	validate_support(world,p)
	for direction in SUPPORTS: validate_support(world,p+direction)

static func validate_support(world: VoxelWorld, p: Vector3i) -> void:
	var id: int = world.node_at(p)
	if not is_crystal(id): return
	# A piston replaces a whole group atomically in source. Its intermediate
	# empty cells must not break crystals whose final support remains solid.
	if world.circuits != null and world.circuits.moving:
		var data: Dictionary = runtime(world)
		if not data.has("support_pending"): data.support_pending = {}
		data.support_pending[p] = true
		return
	if supported(world,p,id): return
	if world.set_node(p,Nodes.AIR):
		for entry in environment_drops(id): world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])

static func finish_piston(world: VoxelWorld) -> void:
	if not world.has_meta("amethyst"): return
	var data: Dictionary = runtime(world)
	var pending: Dictionary = data.get("support_pending",{})
	data.erase("support_pending")
	for p in pending: validate_support(world,p)

static func column_loaded(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("amethyst"): return
	for p in runtime(world).cells.keys():
		var at: Vector3i = p+support(world.node_at(p))
		if Vector2i(floori(p.x/16.0),floori(p.z/16.0)) == column or Vector2i(floori(at.x/16.0),floori(at.z/16.0)) == column: validate_support(world,p)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("amethyst"): return
	for p in runtime(world).columns.get(column,{}).keys(): forget(world,p)

static func reset(world: VoxelWorld) -> void:
	if world.has_meta("amethyst"): world.remove_meta("amethyst")

static func spawn_bud(world: VoxelWorld, p: Vector3i, direction: Vector3i) -> bool:
	if world.node_at(p) != BUDDING or not SUPPORTS.has(direction): return false
	var at: Vector3i = p+direction
	if not world.loaded_at(Vector3(at)): return false
	var id: int = world.node_at(at)
	if id != Nodes.AIR and not Fluids.water(id): return false
	return world.set_node(at,oriented(SMALL,direction))

static func grow_bud(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if not is_crystal(id) or stage(id) >= 3: return false
	var at: Vector3i = p+support(id)
	if not world.loaded_at(Vector3(at)) or world.node_at(at) != BUDDING: return false
	return world.set_node(p,id+8)

static func update(world: VoxelWorld, delta: float) -> void:
	if not world.has_meta("amethyst") or not world.get_parent().playing(): return
	var data: Dictionary = runtime(world)
	var elapsed: float = float(world.adventure_state.get("amethyst_elapsed",0.0))
	elapsed = maxf(0,elapsed) if is_finite(elapsed) else 0.0
	elapsed += maxf(0,delta)
	if elapsed >= INTERVAL and data.cursor >= data.jobs.size():
		elapsed = fmod(elapsed,INTERVAL); data.jobs.clear(); data.cursor = 0
		for p in data.cells: data.jobs.append([p,data.cells[p]])
	world.adventure_state.amethyst_elapsed = minf(elapsed,INTERVAL)
	var rng: RandomNumberGenerator = data.rng
	for i in 16:
		if data.cursor >= data.jobs.size(): break
		var entry: Array = data.jobs[data.cursor]; data.cursor += 1
		var p: Vector3i = entry[0]; var id: int = entry[1]
		if not data.cells.has(p) or world.node_at(p) != id or rng.randi_range(1,CHANCE) != 1: continue
		if id == BUDDING: spawn_bud(world,p,SUPPORTS[rng.randi_range(0,5)])
		else: grow_bud(world,p)
	if data.cursor >= data.jobs.size(): data.jobs.clear(); data.cursor = 0

static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array, deep: PackedInt32Array) -> void:
	AmethystGeodes.overlay(gen,coord,data,deep)

static func mesh(out: Array, at: Vector3, id: int) -> void:
	if not is_crystal(id): BlockMesher._art_box(out,at+Vector3.ONE*0.5,Vector3.ONE,Nodes.tile(id,0),Nodes.tile(id,2)); return
	var rank: int = stage(id)
	var height: float = [4.0,6.0,7.0,11.9][rank]/16.0
	var low: float = 1.0/16 if rank == 0 else 0.0
	var tips: Array = [[Vector2(0.5,0.5),1.0,0.13],[Vector2(0.33,0.4),0.68,0.1],[Vector2(0.62,0.63),0.75,0.11]]
	if rank > 1: tips.append([Vector2(0.37,0.66),0.58,0.095]); tips.append([Vector2(0.67,0.37),0.55,0.09])
	for tip in tips:
		var middle := Vector3(tip[0].x,low+height*tip[1]*0.64,tip[0].y)
		var apex := Vector3(middle.x,low+height*tip[1],middle.z)
		for side in 4:
			var a: Vector3 = middle+Vector3(cos(side*PI/2),0,sin(side*PI/2))*tip[2]
			var b: Vector3 = middle+Vector3(cos((side+1)*PI/2),0,sin((side+1)*PI/2))*tip[2]
			for vertices in [[Vector3(a.x,low,a.z),Vector3(b.x,low,b.z),b,a],[a,b,apex,apex]]:
				var verts: Array = []; for point in vertices: verts.append(at+transform(id,point))
				var normal: Vector3 = -(verts[1]-verts[0]).cross(verts[2]-verts[0]).normalized()
				BlockMesher._quad(out,verts,[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)],normal,Nodes.tile(item(id),0),Color.WHITE,false)

static func build(id: int) -> Node3D:
	var root := Node3D.new(); var out: Array = BlockMesher._empty(); mesh(out,Vector3(-0.5,0,-0.5),id)
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	for pair in [[Mesh.ARRAY_VERTEX,0],[Mesh.ARRAY_NORMAL,1],[Mesh.ARRAY_TEX_UV,2],[Mesh.ARRAY_TEX_UV2,3],[Mesh.ARRAY_COLOR,4],[Mesh.ARRAY_INDEX,5]]: arrays[pair[0]] = out[pair[1]]
	var shape := ArrayMesh.new(); shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var instance := MeshInstance3D.new(); instance.mesh = shape
	var mat := ShaderMaterial.new(); mat.shader = preload("res://shaders/terrain.gdshader"); mat.set_shader_parameter("atlas",Art.atlas_texture)
	instance.material_override = mat; root.add_child(instance); return root

static func icon_faces(id: int) -> Array:
	id = item(id)
	if not icons.has(id):
		var out: Array = BlockMesher._empty(); mesh(out,Vector3.ZERO,id)
		var faces: Array = []
		for face in Barriers.project_icon(out):
			# Pointed tips use a repeated apex in the chunk's quad buffer. Canvas
			# polygons require three distinct vertices rather than that quad.
			var points := PackedVector2Array(); var uv := PackedVector2Array()
			for i in face.points.size():
				if not points.is_empty() and points[-1].is_equal_approx(face.points[i]): continue
				points.append(face.points[i]); uv.append(face.uv[i])
			if points.size() > 1 and points[0].is_equal_approx(points[-1]): points.resize(points.size()-1); uv.resize(uv.size()-1)
			var area: float = 0.0
			for i in points.size(): area += points[i].cross(points[(i+1)%points.size()])
			if points.size() < 3 or absf(area) <= 0.00001 or Geometry2D.triangulate_polygon(points).size() != (points.size()-2)*3: continue
			face.points = points; face.uv = uv; faces.append(face)
		icons[id] = faces
	return icons[id]

static func draw(img: Image, id: int) -> void:
	if id != SHARD: return
	ItemArt._polygon(img,[[3,11],[8,2],[12,1],[14,5],[8,14],[5,15]],Color("63418e"))
	ItemArt._polygon(img,[[4,10],[9,3],[12,2],[11,7],[7,13]],Color("b283e1"))
	ItemArt._polygon(img,[[9,3],[12,2],[13,5],[11,7]],Color("eedbff"))
	ItemArt._polygon(img,[[7,13],[11,7],[13,5],[8,14],[5,15]],Color("8553b5"))
	ItemArt._line(img,Vector2(5,10),Vector2(9,4),Color("d6b5f4"))

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	id = item(id)
	if id == CALCITE:
		return noise.lerp(Color("e0ddcf"),0.8).darkened(0.12 if posmod(x*3+y,13) < 2 else 0.0)
	if id == SMOOTH_BASALT: return noise.lerp(Color("56535b"),0.75).lightened(0.06 if (x+y*3)%11 == 0 else 0.0)
	if id == TINTED_GLASS:
		if x in [0,15] or y in [0,15]: return Color(0.32,0.27,0.36,0.9)
		if posmod(x-y,11) == 0: return Color(0.53,0.45,0.58,0.65)
		return Color(0.2,0.15,0.24,0.4)
	var result: Color = noise.lerp(Color("9567c5") if id == BLOCK else Color("b385e2"),0.7)
	if id == BUDDING and (absi(x-7) < 1 or absi(y-7) < 1 or x+y == 14): return Color("5c367e")
	if posmod(x+y*2,9) == 0: result = result.lightened(0.25)
	if posmod(x*3-y,13) == 0: result = result.darkened(0.25)
	return result

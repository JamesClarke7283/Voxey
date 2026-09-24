class_name RedstoneInputs
extends RefCounted

# IDs encode attachment direction; electrical state stays in saved metadata.
# Source behavior and the material-rule exception are documented alongside tests.
const FIRST = 6900
const BUTTON_ITEMS = [Nodes.BUTTON,6908,6916,6924,6932,6940,6948,6956]
const PLATE_ITEMS = [Nodes.PRESSURE_PLATE,6971,6972,6973,6974,6975,6976,6977,6978,6979]
const MATERIALS = [Nodes.STONE,Nodes.PLANKS,6035,6067,6099,6131,6163,Bastions.POLISHED,Nodes.GOLD_BLOCK,Nodes.IRON_BLOCK]
const NAMES = ["Stone","Oak","Spruce","Birch","Jungle","Acacia","Dark oak","Polished blackstone","Light weighted","Heavy weighted"]
const SUPPORTS = [Vector3i.DOWN,Vector3i.UP,Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
static var meshes: Dictionary = {}
static var icons: Dictionary = {}
static var visual_material: ShaderMaterial

static func button_kind(id: int) -> int:
	if id == Nodes.BUTTON: return 0
	if id >= FIRST and id < FIRST+64 and (id-FIRST)%8 < 6 and id != FIRST: return (id-FIRST)/8
	return -1
static func plate_kind(id: int) -> int: return PLATE_ITEMS.find(id)
static func is_button(id: int) -> bool: return button_kind(id) >= 0
static func is_plate(id: int) -> bool: return plate_kind(id) >= 0
static func is_device(id: int) -> bool: return is_button(id) or is_plate(id)
static func kind(id: int) -> int: return button_kind(id) if is_button(id) else plate_kind(id)
static func wooden(id: int) -> bool: return kind(id) in range(1,7)
static func item(id: int) -> int: return BUTTON_ITEMS[button_kind(id)] if is_button(id) else (id if is_plate(id) else 0)
static func material(id: int) -> int: return MATERIALS[maxi(kind(id),0)]
static func title(id: int) -> String: return NAMES[maxi(kind(id),0)]+(" button" if is_button(id) else " pressure plate")
static func items() -> Array: return BUTTON_ITEMS+PLATE_ITEMS
static func blocks() -> Array:
	var result: Array = PLATE_ITEMS.duplicate()
	for button in BUTTON_ITEMS:
		for normal in SUPPORTS: result.append(oriented(button,-normal))
	return result
static func same_family(a: int, b: int) -> bool: return is_device(a) and is_device(b) and item(a) == item(b)
static func support(id: int) -> Vector3i:
	return SUPPORTS[0 if id == Nodes.BUTTON else (id-FIRST)%8] if is_button(id) else Vector3i.DOWN
static func oriented(id: int, normal: Vector3i) -> int:
	if not is_button(id): return item(id)
	var face: int = SUPPORTS.find(-normal)
	return item(id) if face <= 0 else FIRST+button_kind(id)*8+face
static func duration(id: int) -> float: return 1.5 if is_button(id) and wooden(id) else 1.0
static func fuel_time(id: int) -> float: return (5.0 if is_button(id) else 15.0) if wooden(id) else 0.0

static func recipes(inv: Inventory) -> void:
	for id in items():
		# Replace rather than duplicate the legacy stone recipes.
		if inv.recipe_index(id) >= 0: continue
		var ingredient: int = Nodes.GOLD if id == 6978 else (Nodes.IRON if id == 6979 else material(id))
		inv._recipe(title(id),id,1,[ingredient] if is_button(id) else [ingredient,ingredient],1 if is_button(id) else 2)

static func boxes(id: int, saved: Dictionary = {}) -> Array:
	var pressed: bool = bool(saved.get("input_pressed",false)) or int(saved.get("out",0)) > 0
	if is_plate(id): return [AABB(Vector3(1.0/16,0,1.0/16),Vector3(14.0/16,1.0/32 if pressed else 1.0/16,14.0/16))]
	if not is_button(id): return []
	var depth: float = 1.0/16 if pressed else 2.0/16
	match support(id):
		Vector3i.DOWN: return [AABB(Vector3(0.25,0,0.375),Vector3(0.5,depth,0.25))]
		Vector3i.UP: return [AABB(Vector3(0.25,1-depth,0.375),Vector3(0.5,depth,0.25))]
		Vector3i.LEFT: return [AABB(Vector3(0,0.375,0.25),Vector3(depth,0.25,0.5))]
		Vector3i.RIGHT: return [AABB(Vector3(1-depth,0.375,0.25),Vector3(depth,0.25,0.5))]
		Vector3i.FORWARD: return [AABB(Vector3(0.25,0.375,0),Vector3(0.5,0.25,depth))]
		_: return [AABB(Vector3(0.25,0.375,1-depth),Vector3(0.5,0.25,depth))]

static func mesh(out: Array, at: Vector3, id: int, saved: Dictionary = {}) -> void:
	for box in boxes(id,saved): BlockMesher._art_box(out,at+box.get_center(),box.size,Nodes.tile(material(id),0),Nodes.tile(material(id),2))

static func build(id: int, saved: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	var pressed: bool = bool(saved.get("input_pressed",false)) or int(saved.get("out",0)) > 0
	var key: String = str(id)+":"+str(pressed)
	if not meshes.has(key):
		var out: Array = BlockMesher._empty(); mesh(out,Vector3(-0.5,0,-0.5),id,saved)
		var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
		for pair in [[Mesh.ARRAY_VERTEX,0],[Mesh.ARRAY_NORMAL,1],[Mesh.ARRAY_TEX_UV,2],[Mesh.ARRAY_TEX_UV2,3],[Mesh.ARRAY_COLOR,4],[Mesh.ARRAY_INDEX,5]]: arrays[pair[0]] = out[pair[1]]
		var shape := ArrayMesh.new(); shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); meshes[key] = shape
	if visual_material == null:
		visual_material = ShaderMaterial.new(); visual_material.shader = preload("res://shaders/terrain.gdshader")
	visual_material.set_shader_parameter("atlas",Art.atlas_texture)
	var instance := MeshInstance3D.new(); instance.mesh = meshes[key]; instance.material_override = visual_material
	root.add_child(instance)
	return root

static func icon_faces(id: int) -> Array:
	id = item(id)
	if not icons.has(id):
		var out: Array = BlockMesher._empty(); mesh(out,Vector3.ZERO,id); icons[id] = Barriers.project_icon(out)
	return icons[id]

static func button_supported(world: VoxelWorld, at: Vector3i, direction: Vector3i) -> bool:
	var id: int = world.node_at(at)
	# Source stair/slab placement_prevented overrides permit their full faces.
	if BuildingShapes.is_shape(id): return BuildingShapes.supports(world,at,-direction)
	if not Nodes.solid(id) or Nodes.transparent(id): return false
	var geometry: Array = world.collision_boxes(at)
	return geometry.size() == 1 and geometry[0].position.is_equal_approx(Vector3.ZERO) and geometry[0].size.is_equal_approx(Vector3.ONE)

static func supported(world: VoxelWorld, p: Vector3i, id: int, placing: bool = false) -> bool:
	var at: Vector3i = p+support(id)
	# Unloaded support must not cause a saved attachment to drop.
	if not world.loaded_at(Vector3(at)): return not placing
	# Placement has a stricter button rule than the ongoing attached_node check.
	# Both devices remain attached while their supporting node is walkable.
	return button_supported(world,at,support(id)) if placing and is_button(id) else Nodes.solid(world.node_at(at))

static func replaceable(id: int) -> bool:
	return id == Nodes.AIR or SnowCover.is_snow(id) or Nodes.plant(id) or Fire.is_fire(id)

static func try_place(game: Node3D, target: Dictionary) -> bool:
	var held: int = game.inventory.held().id
	if not is_device(held) or target.is_empty(): return false
	if held != item(held): return true
	var at: Vector3i = target.get("replace",target.pos if replaceable(int(target.id)) else target.pos+target.normal)
	if not replaceable(game.world.node_at(at)): return true
	var placed: int = oriented(held,target.normal) if is_button(held) else held
	if not supported(game.world,at,placed,true): return true
	if game.world.set_node(at,placed):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,placed)
	return true

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or not is_button(int(target.get("id",0))): return false
	if Input.is_physical_key_pressed(KEY_CTRL) or (game.touch and is_instance_valid(game.controls) and game.controls.sneak_held): return false
	if game.target_mob() != null: return false
	press(game.world,target.pos)
	return true

static func press(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if not is_button(id): return false
	var saved: Dictionary = world.circuits.state(p)
	if float(saved.get("remaining",0)) > 0: return false # Source on-state has no press callback.
	saved.remaining = duration(id); saved.out = 15; saved.input_pressed = true
	world.circuits.notify_observers(p); world.circuits.refresh(p)
	world.get_parent().sound("place")
	return true

static func registered(world: VoxelWorld, p: Vector3i, id: int) -> void:
	var saved: Dictionary = world.circuits.state(p)
	var direction: Vector3i = support(id)
	# Preserve old wall/ceiling metadata until the column's reconciliation ends.
	# Migrating recursively inside set_node could let its outer write restore 215.
	if id == Nodes.BUTTON and saved.get("support") is Array and saved.support.size() == 3:
		var old_support := Vector3i(int(saved.support[0]),int(saved.support[1]),int(saved.support[2]))
		if SUPPORTS.has(old_support): direction = old_support
	saved.support = [direction.x,direction.y,direction.z]
	var remaining: float = float(saved.get("remaining",duration(id) if int(saved.get("out",0)) > 0 else 0.0))
	saved.remaining = clampf(remaining,0,duration(id)) if is_finite(remaining) else 0.0
	saved.input_pressed = saved.remaining > 0
	saved.out = (15 if saved.input_pressed else 0) if is_button(id) else (clampi(int(saved.get("out",0)),0,15) if saved.input_pressed else 0)

static func migrate_at(world: VoxelWorld, p: Vector3i) -> void:
	if world.node_at(p) != Nodes.BUTTON: return
	var saved: Dictionary = world.circuits.state(p)
	var old_support: Variant = saved.get("support",[])
	if not old_support is Array or old_support.size() != 3: return
	var direction := Vector3i(int(old_support[0]),int(old_support[1]),int(old_support[2]))
	if SUPPORTS.has(direction) and direction != Vector3i.DOWN: world.set_node(p,oriented(Nodes.BUTTON,-direction))

static func break_attached(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if not is_device(id) or not world.set_node(p,Nodes.AIR): return false
	world.get_parent().spawn_drop(Vector3(p)+Vector3.ONE*0.5,item(id),1)
	return true

static func support_changed(world: VoxelWorld, p: Vector3i) -> void:
	if PistonPush.defer_support(world,p): return
	for direction in [Vector3i.ZERO]+SUPPORTS:
		var at: Vector3i = p+direction
		var id: int = world.node_at(at)
		if is_device(id) and not supported(world,at,id): break_attached(world,at)

static func weak_power(id: int, saved: Dictionary, toward: Vector3i) -> int:
	return 0 if is_plate(id) and toward == Vector3i.UP else clampi(int(saved.get("out",0)),0,15)
static func strong_power(id: int, saved: Dictionary, toward: Vector3i) -> int:
	return clampi(int(saved.get("out",0)),0,15) if toward == support(id) else 0
static func count_power(id: int, count: int) -> int:
	if count <= 0: return 0
	# Verified with installed Luanti: assigning n/10 to integer param2 truncates.
	if id == 6979: return mini(count/10,15)
	return mini(count,15) if id == 6978 else 15

static func actor_record(game: Node3D, actor: Node3D) -> Dictionary:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion(): return {}
	var pos: Vector3 = actor.global_position
	var box: AABB; var living: bool = false
	if actor == game.player:
		if game.boats != null and game.boats.ridden() or game.survival != null and is_instance_valid(game.survival.mount): return {}
		living = true; box = AABB(pos-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58))
	elif actor is Creature:
		if actor.kind == "end_crystal" or Boats.is_passenger(actor): return {}
		living = true; box = AABB(pos-Vector3(actor.width,0,actor.width),Vector3(actor.width*2,actor.height,actor.width*2))
	elif actor is ItemDrop:
		if actor.amount <= 0: return {}
		box = AABB(pos-Vector3(0.1,0,0.1),Vector3(0.2,0.2,0.2))
	elif actor is BoatEntity:
		if actor.removed: return {}
		box = AABB(pos-Vector3(0.5,0,0.5),Vector3(1,0.55,1))
	elif actor is PrimedTnt:
		box = AABB(pos,Vector3.ONE); pos += Vector3.ONE*0.5
	elif actor is Arrow:
		var radius: float = 0.25 if actor.stuck else 0.01
		box = AABB(pos-Vector3.ONE*radius,Vector3.ONE*radius*2)
	elif actor is TridentProjectile:
		if actor.returning: return {}
		box = AABB(pos-Vector3.ONE*0.25,Vector3.ONE*0.5)
	elif actor is PotionProjectile:
		if actor.cloud: return {}
		box = AABB(pos-Vector3.ONE*0.1,Vector3.ONE*0.2)
	else: return {} # Thrown eggs/snowballs/pearls and spell clouds are nonphysical in source.
	return {"position":pos,"box":box,"living":living}

# Given plates, actors outside the box around them are left out: a plate reads
# the cells within one node of itself, and a record's cell is at most one node
# from its actor's.
static func entity_index(world: VoxelWorld, plates: Array = []) -> Dictionary:
	var game: Node3D = world.get_parent(); var result: Dictionary = {}
	var actors: Array = [game.player]
	for container in [game.creatures,game.drops,game.entities]:
		if is_instance_valid(container): actors.append_array(container.get_children())
	var low := Vector3i(2147483647,2147483647,2147483647); var high := -low
	for p in plates: low = low.min(p-Vector3i(2,2,2)); high = high.max(p+Vector3i(2,2,2))
	for actor in actors:
		if not actor is Node3D: continue
		if not plates.is_empty() and is_instance_valid(actor):
			var cell := Vector3i(actor.global_position.floor())
			if cell.x < low.x or cell.y < low.y or cell.z < low.z or cell.x > high.x or cell.y > high.y or cell.z > high.z: continue
		var record: Dictionary = actor_record(game,actor)
		if record.is_empty(): continue
		var cell := Vector3i(record.position.floor())
		if not result.has(cell): result[cell] = []
		result[cell].append(record)
	return result

static func touching_count(p: Vector3i, id: int, index: Dictionary) -> int:
	if index.is_empty(): return 0
	var center := Vector3(p)+Vector3.ONE*0.5
	var result: int = 0
	for x in range(-1,2):
		for y in range(-1,2):
			for z in range(-1,2):
				for actor in index.get(p+Vector3i(x,y,z),[]):
					if kind(id) in [0,7] and not actor.living: continue
					if actor.position.distance_squared_to(center) > 1.0: continue
					var box: AABB = actor.box
					if box.position.y <= p.y+1.0/16 and box.position.x < p.x+15.0/16 and box.end.x > p.x+1.0/16 and box.position.z < p.z+15.0/16 and box.end.z > p.z+1.0/16: result += 1
	return result

static func tick(world: VoxelWorld, p: Vector3i, id: int, saved: Dictionary, delta: float, index: Variant = null) -> void:
	var before: int = int(saved.get("out",0)); var was_pressed: bool = bool(saved.get("input_pressed",before > 0))
	saved.remaining = maxf(0,float(saved.get("remaining",0))-delta)
	if is_plate(id):
		var count: int = touching_count(p,id,entity_index(world) if index == null else index)
		if count > 0: saved.remaining = 1.0; saved.out = count_power(id,count)
	elif is_button(id): saved.out = 15 if saved.remaining > 0.00001 else 0
	if saved.remaining <= 0.00001: saved.remaining = 0.0; saved.out = 0
	saved.input_pressed = saved.remaining > 0
	if before != int(saved.get("out",0)) or was_pressed != saved.input_pressed: world.circuits.notify_observers(p)

# Arrows and tridents pass through noncolliding buttons and lodge in their
# supporting block. Detect the source button cell immediately outside that
# block, rather than accepting hits through the back or side of the support.
static func projectile_hit(world: VoxelWorld, origin: Vector3, motion: Vector3) -> bool:
	if motion.length_squared() < 0.000001: return false
	var direction: Vector3 = motion.normalized()
	var hit: Dictionary = world.raycast(origin,direction,motion.length()+0.15)
	if hit.is_empty(): return false
	if is_button(int(hit.id)):
		var id: int = hit.id
		if not wooden(id) or direction.dot(Vector3(support(id))) <= 0.5: return false
		return press(world,hit.pos)
	if not Nodes.solid(int(hit.id)): return false
	var at: Vector3i = hit.pos+hit.normal
	var id: int = world.node_at(at)
	if not is_button(id) or not wooden(id) or at+support(id) != hit.pos: return false
	return press(world,at)

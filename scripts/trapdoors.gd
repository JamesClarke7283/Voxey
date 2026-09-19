class_name Trapdoors
extends RefCounted

# Mineclonia mcl_doors/api_trapdoors.lua and mcl_trees/api.lua, GPL-3.0-or-later.
# Each material reserves sixteen stable states: facing, upper half, then open.
const OAK = 5200
const IRON = 5216
const ITEMS = [5200,5216,5380,5396,5412,5428,5444]
const MATERIALS = [Nodes.PLANKS,Nodes.IRON_BLOCK,6035,6067,6099,6131,6163]
const THICKNESS = 3.0/16.0
static var icons: Dictionary = {}
# Families beyond the original seven reuse the 16-state encoding and the same
# geometry from their own base, so the classic ids never shift.
static var extra_families: Array = []

static func register_family(item_id: int, material_id: int, display_name: String, base: int) -> void:
	for family in extra_families:
		if family.item == item_id: return
	extra_families.append({"item":item_id,"material":material_id,"name":display_name,"base":base})

static func item(id: int) -> int:
	if id >= OAK and id < IRON+16: return OAK+(id-OAK)/16*16
	if id >= 5380 and id < 5460: return 5380+(id-5380)/16*16
	for family in extra_families:
		if id >= int(family.base) and id < int(family.base)+16: return int(family.item)
	return -1
static func is_trapdoor(id: int) -> bool: return item(id) >= 0
static func facing(id: int) -> int: return (id-item(id))%4
static func upper(id: int) -> bool: return (id-item(id))%8 >= 4
static func open(id: int) -> bool: return id-item(id) >= 8
static func material(id: int) -> int:
	var base: int = item(id)
	for family in extra_families:
		if family.item == base: return int(family.material)
	return MATERIALS[ITEMS.find(base)]
static func title(id: int) -> String:
	var base: int = item(id)
	for family in extra_families:
		if family.item == base: return String(family.name)
	return "Iron trapdoor" if base == IRON else WoodTypes.NAMES[WoodTypes.species(material(id))]+" trapdoor"
static func same_family(a: int, b: int) -> bool: return is_trapdoor(a) and is_trapdoor(b) and item(a) == item(b)
static func state_id(base: int, direction: int, top: bool, opened: bool = false) -> int: return item(base)+posmod(direction,4)+(4 if top else 0)+(8 if opened else 0)

static func boxes(id: int) -> Array:
	if open(id): return [Barriers.rotate_box(AABB(Vector3(0,0,1-THICKNESS),Vector3(1,1,THICKNESS)),facing(id))]
	return [AABB(Vector3(0,1-THICKNESS if upper(id) else 0,0),Vector3(1,THICKNESS,1))]

static func visual_boxes(id: int) -> Array:
	# Original openwork artwork; collision and selection follow the source's
	# unbroken 3/16 nodebox, including the holes in its alpha-clipped texture.
	var parts: Array = []
	for x in [0.0,0.4375,0.875]: parts.append(AABB(Vector3(x,0,0),Vector3(0.125,THICKNESS,1)))
	for z in [0.0,0.4375,0.875]:
		for x in [0.125,0.5625]: parts.append(AABB(Vector3(x,0,z),Vector3(0.3125,THICKNESS,0.125)))
	for i in parts.size():
		var box: AABB = parts[i]
		if open(id): box = AABB(Vector3(box.position.x,box.position.z,1-THICKNESS),Vector3(box.size.x,box.size.z,THICKNESS))
		elif upper(id): box.position.y = 1-THICKNESS
		parts[i] = Barriers.rotate_box(box,facing(id))
	return parts

static func mesh(out: Array, at: Vector3, id: int) -> void:
	for box in visual_boxes(id): BlockMesher._art_box(out,at+box.get_center(),box.size,Nodes.tile(material(id),0),Nodes.tile(material(id),2))

static func icon_faces(id: int) -> Array:
	id = item(id)
	if not icons.has(id):
		var out: Array = BlockMesher._empty(); mesh(out,Vector3.ZERO,id)
		icons[id] = Barriers.project_icon(out)
	return icons[id]

static func set_open(world: VoxelWorld, p: Vector3i, value: bool) -> bool:
	var id: int = world.node_at(p)
	if not is_trapdoor(id) or open(id) == value: return false
	var next_id: int = state_id(id,facing(id),upper(id),value)
	if not world.set_node(p,next_id): return false
	resolve_actors(world,p,next_id)
	return true

# Luanti handles collision recovery after swapping a nodebox. Voxey's custom
# movement solver assumes a clear starting position, so recover here for every
# implemented toggle path (hand and redstone), without changing the source swap.
static func resolve_actors(world: VoxelWorld, p: Vector3i, id: int) -> void:
	var game: Node = world.get_parent()
	if game == null or not game.has_method("playing"): return
	var local_box: AABB = boxes(id)[0]
	var plane := AABB(Vector3(p)+local_box.position,local_box.size)
	var riding_boat: bool = game.boats != null and is_instance_valid(game.boats.riding)
	var mounted: bool = game.survival != null and is_instance_valid(game.survival.mount)
	var mount_moved: bool = false
	if is_instance_valid(game.player) and not riding_boat and not mounted:
		resolve_actor(world,p,plane,game.player,0.29,1.8)
	if is_instance_valid(game.creatures):
		for actor in game.creatures.get_children():
			if not actor is Creature or actor.is_queued_for_deletion() or Boats.is_passenger(actor): continue
			if resolve_actor(world,p,plane,actor,actor.width,actor.height) and mounted and actor == game.survival.mount: mount_moved = true
	if game.boats != null:
		for boat in game.boats.active.values():
			if not is_instance_valid(boat) or boat.removed or boat.is_queued_for_deletion(): continue
			if resolve_actor(world,p,plane,boat,0.5,0.55): boat.seat_occupants(); boat.store_record()
	if mount_moved: game.player.position = game.survival.mount.position+Vector3.UP*1.1

static func actor_box(position: Vector3, half_width: float, height: float) -> AABB:
	return AABB(position-Vector3(half_width,-0.002,half_width),Vector3(half_width*2,height-0.004,half_width*2))

static func resolve_actor(world: VoxelWorld, p: Vector3i, plane: AABB, actor: Node3D, half_width: float, height: float) -> bool:
	var body: AABB = actor_box(actor.position,half_width,height)
	if not body.intersects(plane): return false
	var candidates: Array = []
	for axis in 3:
		for amount in [plane.position[axis]-body.end[axis]-0.002,plane.end[axis]-body.position[axis]+0.002]:
			var motion := Vector3.ZERO; motion[axis] = amount
			candidates.append({"motion":motion,"axis":axis,"distance":absf(amount)})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary): return a.distance < b.distance)
	# Six face projections bound the search, and a swept box prevents a short
	# correction from tunnelling through surrounding walls to a clear endpoint.
	for candidate in candidates:
		var destination: Vector3 = actor.position+candidate.motion
		if not world.loaded_at(destination) or world.intersects(destination,half_width,height): continue
		if actor is BoatEntity and actor.blocked(destination): continue
		var swept: AABB = body.merge(actor_box(destination,half_width,height))
		if not clear_correction(world,p,swept): continue
		actor.position = destination
		if actor is BoatEntity: actor.speed = 0; actor.vertical = 0
		else:
			actor.velocity[int(candidate.axis)] = 0
			if int(candidate.axis) == 1 and candidate.motion.y > 0: actor.grounded = true
		return true
	# Fully enclosed actors have no safe correction. Keep the source toggle and
	# their position; do not teleport them through walls or into unloaded space.
	return false

static func clear_correction(world: VoxelWorld, ignored: Vector3i, swept: AABB) -> bool:
	var minimum := Vector3i(swept.position.floor())
	var maximum := Vector3i(swept.end.floor())
	for y in range(minimum.y-1,maximum.y+1):
		for z in range(minimum.z,maximum.z+1):
			for x in range(minimum.x,maximum.x+1):
				var cell := Vector3i(x,y,z)
				if cell == ignored: continue
				for box in world.collision_boxes(cell):
					if swept.intersects(AABB(Vector3(cell)+box.position,box.size)): return false
	return true

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or not is_trapdoor(int(target.id)) or game.target_mob() != null: return false
	if Input.is_physical_key_pressed(KEY_CTRL) or (game.touch and is_instance_valid(game.controls) and game.controls.sneak_held): return false
	# Iron has no source right-click callback; allow normal held-item use.
	if item(target.id) == IRON: return false
	set_open(game.world,target.pos,not open(target.id)); game.sound("place"); game.player.swing = 1
	return true

static func placement_id(base: int, at: Vector3i, normal: Vector3i, point: Vector3, player_pos: Vector3) -> int:
	var direction: Vector3 = Vector3(at)+Vector3.ONE*0.5-player_pos
	var turn: int = (1 if direction.x < 0 else 3) if absf(direction.x)>absf(direction.z) else (0 if direction.z>0 else 2)
	var top: bool = normal == Vector3i.DOWN or normal.y == 0 and point.y-floorf(point.y) > 0.5
	return state_id(base,turn,top)

static func try_place(game: Node3D, target: Dictionary) -> bool:
	var held: int = game.inventory.held().id
	if not is_trapdoor(held) or target.is_empty(): return false
	if held != item(held): return true
	var at: Vector3i = target.get("replace",target.pos+target.normal)
	var previous: int = game.world.node_at(at)
	if previous != Nodes.AIR and not SnowCover.is_snow(previous) and not Fluids.liquid(previous) and not Nodes.plant(previous) and not Fire.is_fire(previous): return true
	var point: Vector3 = target.get("point",Vector3(target.pos)+Vector3.ONE*0.5)
	var id: int = placement_id(held,at,target.normal,point,game.player.position)
	var body := AABB(game.player.position-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58))
	for box in boxes(id):
		if body.intersects(AABB(Vector3(at)+box.position,box.size)): return true
	if game.world.set_node(at,id):
		Copper.placed_wax(game,at,game.inventory.held())
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,id)
	return true

static func climbable(world: VoxelWorld, cell: Vector3i) -> bool:
	var id: int = world.node_at(cell)
	return is_trapdoor(id) and open(id)

static func recipes(inv: Inventory) -> void:
	for id in ITEMS:
		if id == IRON: continue
		var p: int = material(id)
		inv._recipe(title(id),id,2,[p,p,p,p,p,p],3,"table")
	inv._recipe(title(IRON),IRON,1,[Nodes.IRON,Nodes.IRON,Nodes.IRON,Nodes.IRON],2)

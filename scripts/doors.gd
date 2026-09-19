class_name Doors
extends RefCounted

# mcl_doors/api_doors.lua, GPL-3.0-or-later. Keep the old inventory IDs;
# placed nodes encode material, closed facing, mirror, open and top-half state.
const FIRST = 6300
const ITEMS = [549,228,6200,6201,6202,6203,6204]
const MATERIALS = [Nodes.PLANKS,Nodes.IRON_BLOCK,6035,6067,6099,6131,6163]
const NAMES = ["Oak","Iron","Spruce","Birch","Jungle","Acacia","Dark oak"]
const THICKNESS = 3.0/16.0
static var icons: Dictionary = {}

# Families outside the original seven reuse the same 32-state encoding and the
# same geometry, but live at their own base so the classic ids never shift.
# Each entry is {"item":int,"material":int,"name":String,"base":int}.
static var extra_families: Array = []

static func register_family(item_id: int, material_id: int, display_name: String, base: int) -> void:
	for family in extra_families:
		if family.item == item_id: return
	extra_families.append({"item":item_id,"material":material_id,"name":display_name,"base":base})

static func family_of(id: int) -> Dictionary:
	var item_id: int = id if is_item(id) else item(id)
	for family in extra_families:
		if family.item == item_id: return family
	return {}

static func state_base(item_id: int) -> int:
	var family: Dictionary = family_of(item_id)
	if not family.is_empty(): return int(family.base)
	return FIRST+ITEMS.find(item_id)*32

static func is_door(id: int) -> bool:
	if id >= FIRST and id < FIRST+ITEMS.size()*32: return true
	for family in extra_families:
		if id >= int(family.base) and id < int(family.base)+32: return true
	return false
static func is_item(id: int) -> bool:
	if ITEMS.has(id): return true
	for family in extra_families:
		if family.item == id: return true
	return false
static func legacy(id: int) -> bool: return id in [549,550,228,229]
static func index(id: int) -> int:
	var item_id: int = id if is_item(id) else item(id)
	var family: Dictionary = family_of(item_id)
	return extra_families.find(family) + ITEMS.size() if not family.is_empty() else ITEMS.find(item_id)
static func item(id: int) -> int:
	if is_item(id): return id
	for family in extra_families:
		if id >= int(family.base) and id < int(family.base)+32: return int(family.item)
	return ITEMS[(id-FIRST)/32]
static func material(id: int) -> int:
	var family: Dictionary = family_of(id)
	if not family.is_empty(): return int(family.material)
	return MATERIALS[ITEMS.find(id)] if is_item(id) else MATERIALS[(id-FIRST)/32]
static func title(id: int) -> String:
	var family: Dictionary = family_of(id)
	if not family.is_empty(): return String(family.name)
	return NAMES[ITEMS.find(id)]+" door" if is_item(id) else NAMES[(id-FIRST)/32]+" door"
static func iron(id: int) -> bool: return material(id) == Nodes.IRON_BLOCK
static func facing(id: int) -> int: return (id-state_base(item(id)))%4
static func mirrored(id: int) -> bool: return (id-state_base(item(id)))%8 >= 4
static func opened(id: int) -> bool: return (id-state_base(item(id)))%16 >= 8
static func upper(id: int) -> bool: return (id-state_base(item(id)))%32 >= 16
static func wooden(id: int) -> bool: return is_door(id) and not iron(id)
static func state_id(item_id: int, direction: int, mirror: bool = false, open_value: bool = false, top: bool = false) -> int:
	return state_base(item_id)+posmod(direction,4)+(4 if mirror else 0)+(8 if open_value else 0)+(16 if top else 0)
static func same_family(a: int, b: int) -> bool: return is_door(a) and is_door(b) and index(a) == index(b)
static func other(p: Vector3i, id: int) -> Vector3i: return p+(Vector3i.DOWN if upper(id) else Vector3i.UP)
static func rotation(id: int) -> int: return posmod(facing(id)+(1 if mirrored(id) else -1)*(1 if opened(id) else 0),4)

static func boxes(id: int) -> Array:
	return [Barriers.rotate_box(AABB(Vector3.ZERO,Vector3(1,1,THICKNESS)),rotation(id))]

static func visual_boxes(id: int) -> Array:
	var result: Array = [AABB(Vector3.ZERO,Vector3(0.125,1,THICKNESS)),AABB(Vector3(0.875,0,0),Vector3(0.125,1,THICKNESS)),AABB(Vector3(0.125,0,0),Vector3(0.75,0.125,THICKNESS)),AABB(Vector3(0.125,0.875,0),Vector3(0.75,0.125,THICKNESS))]
	if upper(id):
		result.append(AABB(Vector3(0.125,0.4375,0),Vector3(0.75,0.125,THICKNESS)))
		result.append(AABB(Vector3(0.4375,0.125,0),Vector3(0.125,0.75,THICKNESS)))
	else:
		result.append(AABB(Vector3(0.125,0.125,0.03),Vector3(0.75,0.75,THICKNESS-0.06)))
		result.append(AABB(Vector3(0.4375,0.125,0),Vector3(0.125,0.75,THICKNESS)))
	for i in result.size(): result[i] = Barriers.rotate_box(result[i],rotation(id))
	return result

static func mesh(out: Array, at: Vector3, id: int) -> void:
	for box in visual_boxes(id): BlockMesher._art_box(out,at+box.get_center(),box.size,Nodes.tile(material(id),0),Nodes.tile(material(id),2))
	if not upper(id):
		var handle: AABB = Barriers.rotate_box(AABB(Vector3(0.125 if mirrored(id) else 0.79,0.75,-0.025),Vector3(0.085,0.08,THICKNESS+0.05)),rotation(id))
		BlockMesher._art_box(out,at+handle.get_center(),handle.size,Nodes.tile(Nodes.IRON_BLOCK,0),Nodes.tile(Nodes.IRON_BLOCK,0))

static func icon_faces(id: int) -> Array:
	var canonical: int = item(id)
	if not icons.has(canonical):
		var out: Array = BlockMesher._empty()
		for top in [false,true]:
			var state: int = state_id(canonical,0,false,false,top)
			for box in visual_boxes(state):
				var center: Vector3 = box.get_center()*0.5+Vector3(0.25,0.5 if top else 0,0.4)
				BlockMesher._art_box(out,center,box.size*0.5,Nodes.tile(material(id),0),Nodes.tile(material(id),2))
		icons[canonical] = Barriers.project_icon(out)
	return icons[canonical]

static func matching_pair(world: VoxelWorld, p: Vector3i, id: int) -> bool:
	var partner: int = world.node_at(other(p,id))
	return same_family(id,partner) and upper(id) != upper(partner) and facing(id) == facing(partner) and mirrored(id) == mirrored(partner)

static func set_open(world: VoxelWorld, p: Vector3i, value: bool) -> bool:
	var id: int = world.node_at(p)
	if not is_door(id) or opened(id) == value or not matching_pair(world,p,id): return false
	var base: Vector3i = p+Vector3i.DOWN if upper(id) else p
	for top in [false,true]:
		world.set_node(base+(Vector3i.UP if top else Vector3i.ZERO),state_id(item(id),facing(id),mirrored(id),value,top))
	# Reuse bounded actor recovery, but treat the complete two-block panel as
	# one obstacle so resolving one half cannot push an actor into its partner.
	resolve_actors(world,base)
	return true

static func resolve_actors(world: VoxelWorld, base: Vector3i) -> void:
	var game: Node = world.get_parent()
	if game == null or not game.has_method("playing"): return
	var box: AABB = boxes(world.node_at(base))[0]; box.position += Vector3(base); box.size.y = 2
	var actors: Array = game.creatures.get_children()
	if not game.boats.ridden() and not is_instance_valid(game.survival.mount): actors.append(game.player)
	for boat in game.boats.active.values(): actors.append(boat)
	for actor in actors:
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor is Creature and Boats.is_passenger(actor): continue
		var width: float = actor.width if actor is Creature else (0.5 if actor is BoatEntity else 0.29)
		var height: float = actor.height if actor is Creature else (0.55 if actor is BoatEntity else 1.8)
		var body: AABB = Trapdoors.actor_box(actor.position,width,height)
		if not body.intersects(box): continue
		var candidates: Array = []
		for axis in 3:
			for amount in [box.position[axis]-body.end[axis]-0.002,box.end[axis]-body.position[axis]+0.002]:
				var motion := Vector3.ZERO; motion[axis] = amount
				candidates.append({"motion":motion,"axis":axis,"distance":absf(amount)})
		candidates.sort_custom(func(a,b): return a.distance < b.distance)
		for candidate in candidates:
			var destination: Vector3 = actor.position+candidate.motion
			if not world.loaded_at(destination) or world.intersects(destination,width,height): continue
			if actor is BoatEntity and actor.blocked(destination): continue
			var swept: AABB = body.merge(Trapdoors.actor_box(destination,width,height))
			if not clear_correction(world,base,swept): continue
			actor.position = destination
			if actor is BoatEntity: actor.speed = 0; actor.vertical = 0; actor.seat_occupants(); actor.store_record()
			else: actor.velocity[int(candidate.axis)] = 0
			break
	if is_instance_valid(game.survival.mount): game.player.position = game.survival.mount.position+Vector3.UP*1.1

static func clear_correction(world: VoxelWorld, base: Vector3i, swept: AABB) -> bool:
	var minimum := Vector3i(swept.position.floor()); var maximum := Vector3i(swept.end.floor())
	for y in range(minimum.y-1,maximum.y+1):
		for z in range(minimum.z,maximum.z+1):
			for x in range(minimum.x,maximum.x+1):
				var cell := Vector3i(x,y,z)
				if cell == base or cell == base+Vector3i.UP: continue
				for box in world.collision_boxes(cell):
					if swept.intersects(AABB(Vector3(cell)+box.position,box.size)): return false
	return true

static func power(world: VoxelWorld, p: Vector3i) -> void:
	var id: int = world.node_at(p)
	if not is_door(id) or upper(id) or not matching_pair(world,p,id): return
	var top: Vector3i = p+Vector3i.UP
	var lower_state: Dictionary = world.circuits.state(p); var top_state: Dictionary = world.circuits.state(top)
	var level: int = maxi(world.circuits.input_power(p),world.circuits.input_power(top))
	if level != maxi(int(lower_state.get("door_power",0)),int(top_state.get("door_power",0))): set_open(world,p,level > 0)
	lower_state["door_power"] = level; top_state["door_power"] = level

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or game.target_mob() != null: return false
	var p: Vector3i = target.pos
	if legacy(game.world.node_at(p)): migrate_at(game.world,p)
	var id: int = game.world.node_at(p)
	if not wooden(id) or Input.is_physical_key_pressed(KEY_CTRL) or game.touch and is_instance_valid(game.controls) and game.controls.sneak_held: return false
	if set_open(game.world,p,not opened(id)): game.sound("place"); game.player.swing = 1
	return true

static func replaceable(id: int) -> bool: return id == Nodes.AIR or SnowCover.is_snow(id) or Nodes.plant(id) or Fluids.liquid(id) or Fire.is_fire(id)

static func try_place(game: Node3D, target: Dictionary) -> bool:
	var held: int = game.inventory.held().id
	if not is_item(held) or target.is_empty(): return false
	var at: Vector3i = target.pos if replaceable(int(target.id)) else target.pos+target.normal
	if not replaceable(game.world.node_at(at)) or not replaceable(game.world.node_at(at+Vector3i.UP)): return true
	if not game.world.loaded_at(Vector3(at)) or at.y+1 >= game.world.generator.max_y(): return true
	var look: Vector3 = -game.player.camera.global_basis.z
	var source_turn: int = (1 if look.x > 0 else 3) if absf(look.x) > absf(look.z) else (0 if look.z > 0 else 2)
	var turn: int = posmod(-source_turn,4)
	var left: Vector3i = at+Vector3i(source_turn-1 if source_turn%2 == 0 else 0,0,2-source_turn if source_turn%2 != 0 else 0)
	var neighbor: int = game.world.node_at(left)
	var mirror: bool = is_door(neighbor) and item(neighbor) == held
	if mirror: turn = posmod(rotation(neighbor),4)
	var body: AABB = Trapdoors.actor_box(game.player.position,0.29,1.8)
	for top in [false,true]:
		var id: int = state_id(held,turn,mirror,false,top)
		for box in boxes(id):
			if body.intersects(AABB(Vector3(at)+Vector3.UP*(1 if top else 0)+box.position,box.size)): return true
	for top in [false,true]:
		var p: Vector3i = at+(Vector3i.UP if top else Vector3i.ZERO)
		var id: int = state_id(held,turn,mirror,false,top)
		game.world.set_node(p,id); game.api.emit_node_placed(p,id)
	Copper.placed_wax(game,at,game.inventory.held())
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("place"); game.player.swing = 1
	return true

static func break_node(game: Node3D, p: Vector3i, id: int, tool: int, exploded: bool = false) -> bool:
	if not is_door(id): return false
	var partner: Vector3i = other(p,id)
	var paired: bool = matching_pair(game.world,p,id)
	if not game.world.set_node(p,Nodes.AIR): return true
	if paired: game.world.set_node(partner,Nodes.AIR)
	if exploded or game.gamemode != "creative" and Nodes.harvestable(id,tool): game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,item(id),1,0,Copper.drop_metadata(game.world,p))
	game._break_particles(p,id); game.sound("break"); game.progress("gather"); game.api.emit_node_broken(p,id)
	return true

static func migrate_at(world: VoxelWorld, p: Vector3i) -> void:
	var id: int = world.node_at(p)
	if not legacy(id): return
	var metal: bool = id in [228,229]
	var same: Array = [228,229] if metal else [549,550]
	var old_state: Dictionary = world.block_states.get(VoxelWorld.station_key(p),{}).duplicate(true)
	var top: bool = bool(old_state.get("upper",world.node_at(p+Vector3i.DOWN) in same))
	var base: Vector3i = p+Vector3i.DOWN if top else p
	var turn: int = 0
	if old_state.get("dir") is Array and old_state.dir.size() == 3:
		var d: Array = old_state.dir
		# Legacy RedstoneArt faces local -Z and rotates by atan2(-dir.x,-dir.z),
		# so its world front equals dir. Corner-box turns face -Z,+X,+Z,-X.
		# This is different from new source placement, which faces the player.
		turn = (1 if int(d[0]) > 0 else 3) if int(d[0]) != 0 else (2 if int(d[2]) > 0 else 0)
	var open_value: bool = id in [229,550]
	for upper_value in [false,true]:
		var at: Vector3i = base+(Vector3i.UP if upper_value else Vector3i.ZERO)
		if world.node_at(at) not in same: continue
		var metadata: Dictionary = world.block_states.get(VoxelWorld.station_key(at),{}).duplicate(true)
		world.set_node(at,state_id(228 if metal else 549,turn,false,open_value,upper_value))
		metadata["door_power"] = 15 if metadata.get("powered",false) else 0
		world.block_states[VoxelWorld.station_key(at)] = metadata

static func recipes(inv: Inventory) -> void:
	for i in range(2,ITEMS.size()):
		var p: int = MATERIALS[i]
		inv._recipe(title(ITEMS[i]),ITEMS[i],3,[p,p,p,p,p,p],2,"table")

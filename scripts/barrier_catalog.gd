class_name BarrierCatalog
extends RefCounted

# Loaded Mineclonia registrations; rendering and saved state IDs are native.
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/barriers.json"))
static var changing: bool = false
static var group_cache: Dictionary = {}
const SIDES = [Vector3i.RIGHT,Vector3i.BACK,Vector3i.LEFT,Vector3i.FORWARD]

static func is_wall(id: int) -> bool: return data.states.has(str(id))
static func info(id: int) -> Dictionary:
	if is_wall(id): return data.states[str(id)]
	var base: int = Barriers.family(id)
	if base < 0: return {}
	return data.fences.get(str(base+(5 if Barriers.open(id) else 1 if Barriers.is_gate(id) else 0)),{})
static func wall_items() -> Array:
	var result: Array = []
	for row in data.walls.values(): result.append(int(row.id))
	return result
static func wall_for(material: int) -> int:
	for row in data.walls.values():
		if int(row.material) == material: return int(row.id)
	return 0
static func source_name(id: int) -> String: return str(info(id).get("name",""))
static func groups(id: int) -> Dictionary:
	if group_cache.has(id): return group_cache[id]
	var row: Dictionary = info(id)
	if row.is_empty(): row = data.nodes.get(ToolCapabilities.node_name(id),{})
	var values: Variant = row.get("groups",{})
	group_cache[id] = values if values is Dictionary else {}
	return group_cache[id]
static func group(id: int, key: String) -> bool: return int(groups(id).get(key,0)) > 0
static func connects(id: int, other: int) -> bool:
	var row: Dictionary = info(id)
	var rules: Variant = row.get("connects",[])
	if is_wall(id): rules = ["group:wall","group:solid","group:pane"]
	if not rules is Array: return false
	for rule in rules:
		if str(rule).begins_with("group:"):
			if group(other,str(rule).substr(6)): return true
		elif str(rule) == ToolCapabilities.node_name(other): return true
	# A full original extension still presents a solid surface to source fences.
	return not group(other,"wall") and ToolCapabilities.node_name(other).is_empty() and Barriers.full_solid(other)
static func mask(id: int, around: Array) -> int:
	var result: int = 0
	for i in mini(4,around.size()):
		if connects(id,int(around[i])): result |= 1 << i
	return result

static func add_boxes(result: Array, values: Variant) -> void:
	if not values is Array or values.is_empty(): return
	if values[0] is Array:
		for value in values: add_boxes(result,value)
		return
	if values.size() != 6: return
	var a := Vector3(float(values[0]),float(values[1]),float(values[2]))+Vector3.ONE*0.5
	var b := Vector3(float(values[3]),float(values[4]),float(values[5]))+Vector3.ONE*0.5
	result.append(AABB(a.min(b),a.max(b)-a.min(b)))
static func boxes(id: int, bits: int = 0, collision: bool = false, selection: bool = false) -> Array:
	var row: Dictionary = info(id)
	if row.is_empty(): return []
	if collision and row.get("walkable",true) == false: return []
	var definition: Dictionary = row["selection" if selection else "collision" if collision else "box"]
	var result: Array = []
	add_boxes(result,definition.get("fixed",[]))
	if definition.get("type","") == "connected":
		for i in 4:
			if bits & (1<<i): add_boxes(result,definition.get(["connect_right","connect_back","connect_left","connect_front"][i],[]))
	var turns: int = int(row.facing) if is_wall(id) else Barriers.facing(id) if Barriers.is_gate(id) else 0
	if turns:
		for i in result.size(): result[i] = Barriers.rotate_box(result[i],turns)
	return result

static func next_wall(id: int, bits: int, above: int, upper_bits: int) -> int:
	var row: Dictionary = info(id)
	if not is_wall(id): return id
	var pillar: bool = str(row.state).ends_with("pillar")
	var tall: bool = str(row.state).begins_with("tall")
	var top_wall: bool = group(above,"wall")
	var top_pillar: bool = group(above,"wall_pillar")
	var should_pillar: bool = top_pillar or group(above,"torch_ground") or group(above,"pressure_plate") or group(above,"banner") or group(above,"standing_sign") or bits not in [5,10]
	var should_tall: bool = group(above,"solid")
	if top_wall:
		should_tall = (bits & upper_bits) != 0
		if not should_tall and not top_pillar: should_pillar = true
	# The source only writes a new facing when tall/short or pillar/flat changes.
	if pillar == should_pillar and tall == should_tall: return id
	var family: Dictionary = data.walls[row.root]
	var state_index: int = (1 if should_tall else 0) if should_pillar else (4 if should_tall else 2)+(1 if bits == 10 else 0)
	return int(family.states[state_index])

static func update_wall(world: VoxelWorld, p: Vector3i) -> void:
	var id: int = world.node_at(p)
	if not is_wall(id): return
	var around: Array = Barriers.neighbors(world,p)
	var upper: Array = Barriers.neighbors(world,p+Vector3i.UP)
	var next: int = next_wall(id,mask(id,around),int(around[4]),mask(id,upper))
	if next == id: return
	var was_pillar: bool = group(id,"wall_pillar")
	if world.set_node(p,next):
		world.circuits.notify_observers(p)
		if was_pillar or group(next,"wall_pillar"): update_wall(world,p+Vector3i.DOWN)
static func changed(world: VoxelWorld, p: Vector3i, _old: int, id: int) -> void:
	if changing or world.network_replica: return
	changing = true
	if is_wall(id): update_wall(world,p)
	for side in SIDES+[Vector3i.DOWN]: update_wall(world,p+side)
	changing = false
static func loaded(world: VoxelWorld, p: Vector3i) -> void:
	# Canonical IDs in older saves did not encode short/tall/pillar states.
	changed(world,p,world.node_at(p),world.node_at(p))
static func recipes(inv: Inventory) -> void:
	for row in data.recipes:
		inv._recipe(Barriers.title(int(row.id)),int(row.id),int(row.count),row.pattern.map(func(v):return int(v)),int(row.width),"table")
		inv.recipes.back()["source_items"] = row.source_items.duplicate()
	for row in data.walls.values():
		if row.source: continue
		var base: int = int(row.material)
		inv._recipe(Barriers.title(int(row.id)),int(row.id),6,[base,base,base,base,base,base],3,"table")

static func gate_event(id: int, state: int, power: int, event: String) -> Dictionary:
	var toggle: bool = event in ["manual","wind"] or event == "redstone" and (power == 0 if Barriers.open(id) else power != 0)
	return {"id":Barriers.item(id)+Barriers.facing(id)+(0 if Barriers.open(id) else 4) if toggle else id,"state":(0 if state == 1 else 1) if toggle else state}

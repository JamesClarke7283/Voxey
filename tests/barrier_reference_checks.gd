extends SceneTree
var passed: int = 0
var failed: int = 0
var ids: Dictionary = {}
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed < 15: push_error(label)
func id_for(name: String, facing: int = 0) -> int:
	if name.is_empty(): return 0
	if name == "mcl_signs:standing_sign_oak": return Signs.STANDING
	for key in BarrierCatalog.data.states:
		var row: Dictionary = BarrierCatalog.data.states[key]
		if row.name == name and (str(row.state).ends_with("pillar") or int(row.facing) == facing%2): return int(key)
	for key in BarrierCatalog.data.fences:
		var row: Dictionary = BarrierCatalog.data.fences[key]
		if row.name == name: return int(key)+(posmod(4-facing,4) if Barriers.is_gate(int(key)) else 0)
	return FurnaceRules.item_id(name)
func occupancy(boxes: Array) -> PackedByteArray:
	var values := PackedByteArray(); values.resize(6400)
	for box in boxes:
		for y in range(clampi(roundi(box.position.y*16),0,25),clampi(roundi(box.end.y*16),0,25)):
			for z in range(clampi(roundi(box.position.z*16),0,16),clampi(roundi(box.end.z*16),0,16)):
				for x in range(clampi(roundi(box.position.x*16),0,16),clampi(roundi(box.end.x*16),0,16)): values[x+z*16+y*256] = 1
	return values
func raw_boxes(values: Array) -> Array:
	var boxes: Array = []
	for b in values:
		var lo := Vector3(minf(b[0],b[3]),minf(b[1],b[4]),minf(b[2],b[5]))+Vector3.ONE*0.5
		var hi := Vector3(maxf(b[0],b[3]),maxf(b[1],b[4]),maxf(b[2],b[5]))+Vector3.ONE*0.5
		boxes.append(AABB(lo,hi-lo))
	return boxes
func run() -> void:
	var inv := Inventory.new(); Harvesting.initialize()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/barriers_reference.json"))
	var found: int = 0
	for root_name in source.walls:
		var row: Dictionary = BarrierCatalog.data.walls[root_name]; found += 1
		for id_value in row.states:
			var id: int = int(id_value); var info: Dictionary = BarrierCatalog.info(id)
			check(Nodes.exists(id) and Barriers.item(id) == int(row.id),"Wall state registered: "+str(id))
			check(Nodes.placeable(id) == (id == int(row.id)),"Wall inventory visibility: "+str(id))
			check(ToolCapabilities.node_name(id) == info.name,"Wall source identity: "+str(id))
			check(is_equal_approx(Nodes.hardness(id),float(info.hardness)),"Wall hardness: "+str(id))
			check(Enchantments.harvest(id,{"id":Nodes.TOOLS+15,"count":1,"wear":0}) == [[int(row.id),1]],"Wall state canonical drops: "+str(id))
	check(found == 26,"All 26 source wall families are present")
	for value in BarrierCatalog.data.fences:
		var id: int = int(value); var row: Dictionary = BarrierCatalog.data.fences[value]
		check(is_equal_approx(Nodes.hardness(id),float(row.hardness)),"Fence/gate source hardness: "+str(id))
		check(is_equal_approx(Nodes.fuel_time(id),float(row.fuel)),"Fence/gate source fuel: "+str(id))
	for base in Barriers.FENCE_BASES:
		for state in range(9):
			var id: int = base+state
			check(not Doors.is_door(id) and not Trapdoors.is_trapdoor(id) and not BuildingShapes.is_shape(id),"Fence state has no conflicting family: "+str(id))
	for row in source.wall_cases:
		var start: int = id_for(str(row.initial.name),int(row.initial.param2))
		var top: int = id_for(str(row.top))
		check(top != 0 or row.top == "air","Top node binding: "+str(row.top))
		var actual: int = BarrierCatalog.next_wall(start,int(row.mask),top,int(row.upper))
		var expected: int = id_for(str(row.result.name),int(row.result.param2))
		check(actual == expected,"Wall transition "+str(row)+" actual="+str(actual)+" expected="+str(expected))
	for row in source.gate_cases:
		var start: int = id_for(str(row.initial.name),int(row.initial.param2))
		var actual: Dictionary = BarrierCatalog.gate_event(start,int(row.initial.state),int(row.power),str(row.event))
		check(actual.id == id_for(str(row.result.name),int(row.result.param2)) and actual.state == int(row.result.state),"Gate callback "+str(row))
	for row in source.get("geometry",[]):
		var id: int = id_for(str(row.name),int(row.facing))
		# A 4dir wall's second pair of orientations is geometrically equivalent.
		for kind in ["node_box","collision_box","selection_box"]:
			var boxes: Array = Barriers.boxes(id,int(row.mask),kind == "collision_box",kind == "selection_box")
			var expected: Variant = row.boxes[kind]
			if not expected is Array: expected = []
			if kind == "collision_box" and source.fences.get(row.name,{}).get("walkable",true) == false: expected = []
			check(occupancy(boxes) == occupancy(raw_boxes(expected)),"Engine geometry "+str([row.name,row.facing,row.mask,kind]))
	for row in source.get("crafting",[]):
		for i in 9:
			var id: int = id_for(str(row.input[i])); inv.grid[i] = {"id":id,"count":2 if id else 0,"wear":0}
		var actual: Dictionary = inv.take_grid_result("table")
		check(actual.get("id",0) == id_for(str(row.output)) and actual.get("count",0) == int(row.count),"Engine barrier craft: "+str(row.input))
		check(inv.grid.map(func(s):return int(s.count)) == row.after.map(func(v):return int(v)),"Engine craft consumption: "+str(row.input))
	print("BARRIER SOURCE: %d wall cases, %d geometry cases; %d passed, %d failed"%[source.wall_cases.size(),source.get("geometry",[]).size(),passed,failed])
	quit(1 if failed else 0)

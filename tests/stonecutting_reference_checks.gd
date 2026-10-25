extends SceneTree
var passed: int = 0
var failed: int = 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed < 15: push_error(label)
func stack(name: String, count: int) -> Dictionary:
	if name.is_empty(): return Stonecutting.empty()
	var id: int = int(Stonecutting.data.names.get(Stonecutting.canonical(name.trim_suffix("_preserved")),0))
	var result: Dictionary = {"id":id,"count":count,"wear":0}
	if name.ends_with("_preserved"): result.data = {"copper_waxed":true}
	return result
func state(input: String, count: int) -> Dictionary: return {"kind":"stonecutter","slots":[stack(input,count),Stonecutting.empty()]}
func snapshot(s: Dictionary) -> Dictionary:
	return {"input":Stonecutting.source(s.slots[0]),"count":s.slots[0].count,"output":Stonecutting.source(s.slots[1]),"amount":s.slots[1].count}
func run() -> void:
	var inv := Inventory.new()
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/stonecutting_reference.json"))
	for input in reference.recipes:
		check(Stonecutting.choices(stack(input,1)).size() == reference.recipes[input].size(),"All source conversions: "+input)
		for output in reference.recipes[input]:
			var s: Dictionary = state(input,64)
			Stonecutting.select(s,output)
			check(Stonecutting.source(s.slots[1]) == output and int(s.slots[1].count) == int(reference.recipes[input][output]),"Actual source recipe: "+input+" -> "+output)
	for trace in reference.traces:
		var s: Dictionary = state(trace.input,int(trace.count))
		for frame in trace.frames:
			var action: Array = frame.action
			match action[0]:
				"select": Stonecutting.select(s,action[1])
				"fill": Stonecutting.fill(s)
				"take":
					var taken: Dictionary = Stonecutting.take(s,int(action[1]))
					check(taken.count == int(action[2]),"Output withdrawal count")
				"put_callback","open": Stonecutting.refresh(s)
			var expected: Dictionary = frame.state.duplicate(); expected.count = int(expected.count); expected.amount = int(expected.amount)
			check(snapshot(s) == expected,"Source inventory callback "+str(action)+" got "+str(snapshot(s))+" expected "+str(frame.state))
	for row in reference.permissions:
		var index: int = 0 if row.list == "input" else 1
		check((3 if Stonecutting.accepts(index,Nodes.STONE,bool(row.protected)) else 0) == int(row.put),"Source insertion permission")
		if index == 0: check(Stonecutting.allowed_take(state(row.input,4),0,3,bool(row.protected)) == int(row.take),"Source input withdrawal permission")
	check(Stonecutting.choices(stack("mcl_core:dirt",64)).is_empty(),"Non-stonecuttable items have no recipes")
	check(Stonecutting.choices(stack("mcl_pale_oak:resin_brick",64)).is_empty(),"Declared resin wall input is excluded by its missing stonecuttable group")
	check(Stonecutting.choices(stack("mcl_pale_oak:resin_brick_block",64)).is_empty(),"Resin blocks follow the actual source input filter")
	check(Nodes.hardness(VillageContent.STONECUTTER) == float(reference.node.hardness),"Source stonecutter hardness")
	for param in 24:
		var id: int = Stonecutting.placed(param); var row: Dictionary = reference.orientations[str(param)]
		check(Nodes.exists(id) and Nodes.placeable(id) == (param == 0),"All orientation IDs are registered correctly")
		check(not Barriers.is_barrier(id) and not Doors.is_door(id) and not Trapdoors.is_trapdoor(id) and not BuildingShapes.is_shape(id),"Stonecutter orientation owns its node ID")
		for mode in [1,2]: check(Stonecutting.facing(Screwdriver.rotate(id,mode)) == int(row.rotate[mode-1]),"Source screwdriver rotation")
		check(Enchantments.harvest(id,{"id":Nodes.TOOLS+15,"count":1,"wear":0}) == [[VillageContent.STONECUTTER,1]],"Oriented stonecutter drops its inventory item")
		var transformed: Array = []
		for point in [Vector3(0.0625,0.5625,0.5),Vector3(0.9375,0.5625,0.5),Vector3(0.9375,1,0.5),Vector3(0.0625,1,0.5)]: transformed.append(Vector3.ONE*0.5+Stonecutting.basis(id)*(point-Vector3.ONE*0.5))
		var low: Vector3 = transformed[0]; var high: Vector3 = transformed[0]
		for point in transformed: low = low.min(point); high = high.max(point)
		var blade: AABB = Stonecutting.boxes(id,false)[1]
		check(low.is_equal_approx(blade.position) and high.is_equal_approx(blade.end),"Rendered blade matches the actual engine's oriented selection plane")


	print("STONECUTTER SOURCE: %d inputs, %d traces; %d passed, %d failed"%[reference.recipes.size(),reference.traces.size(),passed,failed])
	quit(1 if failed else 0)

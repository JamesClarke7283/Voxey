extends SceneTree

func _init() -> void: call_deferred("run")

func run() -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/mining_reference.json"))
	var failed: int = 0
	var identities: int = 0
	var correct_identities: int = 0
	var matched: int = 0
	for row in reference.nodes:
		for id in row.ids:
			identities += 1
			if ToolCapabilities.node_name(int(id)) != row.name:
				failed += 1
				if failed <= 5: push_error("Changed node mapping: "+str(id)+" expected "+row.name+" got "+ToolCapabilities.node_name(int(id)))
			else: correct_identities += 1
	for section in reference.cases:
		var p: Dictionary = section.input
		for i in reference.nodes.size():
			var name: String = reference.nodes[i].name
			var actual: Dictionary = ToolCapabilities.parameters(name,int(p.id),int(p.efficiency),int(p.unbreaking),p.speed,int(p.initial))
			if not actual.diggable: actual = ToolCapabilities.parameters(name,0,0,0,p.speed)
			var expected: Dictionary = section.results[i]
			if actual.diggable == expected.diggable and is_equal_approx(actual.time,expected.time) and int(actual.wear) == int(expected.wear): matched += 1
			else:
				failed += 1
				if failed <= 5: push_error("Mapped node engine mismatch: "+name+" "+str(p)+" expected "+str(expected)+" got "+str(actual))
	var catalog: Dictionary = {}
	var mapped: int = 0
	for id in Nodes.all_ids():
		if catalog.has(id) or not Nodes.placeable(id): continue
		catalog[id] = true
		if not ToolCapabilities.node_name(id).is_empty(): mapped += 1
		elif MiningNodes.native_reason(id).is_empty():
			failed += 1
			push_error("Unclassified unmapped block: "+str(id)+" "+Nodes.title(id))
	print("MAPPED NODE IDENTITIES: ",correct_identities," / ",identities)
	print("MAPPED NODE ENGINE CASES: ",matched," / ",reference.nodes.size()*reference.cases.size())
	print("CATALOG MINING COVERAGE: ",mapped," / ",catalog.size(),"; ",catalog.size()-mapped," classified native extensions")
	quit(1 if failed else 0)

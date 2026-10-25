extends SceneTree

func _init() -> void: call_deferred("run")

func run() -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/digging_reference.json"))
	var matched: int = 0; var shown: int = 0
	var times: Array = [0,.05,.1,.55,5,299,300,301,1000]
	for row in reference.effects:
		var factors: Dictionary = ToolCapabilities.factors(int(row.haste),int(row.fatigue),int(row.conduit),row.wet)
		var good: bool = is_equal_approx(factors.haste,row.haste_factor) and is_equal_approx(factors.fatigue,row.fatigue_factor) and is_equal_approx(ToolCapabilities.interval(row.base,factors),row.result.full_punch_interval)
		for i in times.size(): good = good and is_equal_approx(ToolCapabilities.dig_time(times[i],factors),row.result.groupcaps.test.times[i])
		if good: matched += 1
		elif shown < 3: shown += 1; push_error("Effect mismatch "+str(row)+" factors="+str(factors))
	var failed: bool = matched != reference.effects.size()
	print("TOOL EFFECT SOURCE CASES: ",matched," / ",reference.effects.size()," matched")
	matched = 0; shown = 0
	for row in reference.digging:
		var factors: Dictionary = ToolCapabilities.factors(int(row.haste),int(row.fatigue),int(row.conduit),row.wet)
		var result: Dictionary = ToolCapabilities.parameters(row.node,int(row.id),int(row.efficiency),int(row.unbreaking),factors,int(row.initial))
		if result.diggable == row.result.diggable and is_equal_approx(result.time,row.result.time) and int(result.wear) == int(row.result.wear): matched += 1
		elif shown < 5: shown += 1; push_error("Dig mismatch "+str(row)+" actual="+str(result))
	failed = failed or matched != reference.digging.size()
	print("DIGGING SOURCE CASES: ",matched," / ",reference.digging.size()," matched")
	var mapped: int = 0; var total: int = 0
	MiningNodes.initialize()
	var seen: Dictionary = {}
	for id in Nodes.all_ids():
		if seen.has(id) or not Nodes.placeable(id): continue
		seen[id] = true
		total += 1
		if not ToolCapabilities.node_name(id).is_empty(): mapped += 1
	print("MAPPED INVENTORY BLOCKS: ",mapped," / ",total," (remaining blocks retain native timing)")
	quit(1 if failed else 0)

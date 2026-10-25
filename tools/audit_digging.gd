extends SceneTree

func _init() -> void:
	Copper.register_families(); WoodTypes.register_families()
	var rows: Array = []
	var seen: Dictionary = {}
	var all_states: bool = OS.get_cmdline_user_args().has("--all-states")
	for id in range(14001) if all_states else Nodes.all_ids():
		if seen.has(id) or (not Nodes.exists(id) if all_states else not Nodes.placeable(id)): continue
		seen[id] = true
		var data: Dictionary = VillageContent.DATA.get(id,{})
		var row: Dictionary = {"id":id,"name":Nodes.title(id),"native_name":data.get("name",Nodes.title(id)),"family":data.get("family",""),"tool":Nodes.preferred_tool(id),"source":ToolCapabilities.node_name(id)}
		row.declared_source = data.get("source_node","")
		row.drop = Nodes.drop(id)
		if row.source.is_empty(): row.requested = MiningNodes.resolve(id)
		if BuildingShapes.is_shape(id): row.material = BuildingShapes.material(id)
		elif Barriers.is_barrier(id): row.material = Barriers.material(id)
		rows.append(row)
	rows.sort_custom(func(a,b): return a.id < b.id)
	var path: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "/tmp/voxey-digging-audit.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	print("BLOCK MAPPING AUDIT: ",rows.size()," unique entries written to ",path)
	quit()

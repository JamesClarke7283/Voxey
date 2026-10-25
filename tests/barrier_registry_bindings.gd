extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var inv := Inventory.new(); Harvesting.initialize()
	var ids: Dictionary = {}; var walls: Array = []; var fences: Array = []; var occupied: Array = []
	for id in Nodes.all_ids()+VillageContent.DATA.keys():
		var name: String = ToolCapabilities.node_name(id)
		if not name.is_empty(): ids[str(id)] = name
	for i in Barriers.WALL_MATERIALS.size(): walls.append({"id":Barriers.WALL_FIRST+i,"material":Barriers.WALL_MATERIALS[i],"name":ToolCapabilities.node_name(Barriers.WALL_FIRST+i)})
	for i in Barriers.FENCE_BASES.size(): fences.append({"id":Barriers.FENCE_BASES[i],"material":Barriers.FENCE_MATERIALS[i],"name":ToolCapabilities.node_name(Barriers.FENCE_BASES[i])})
	for id in range(14800,16384):
		if Nodes.exists(id): occupied.append(id)
	var f := FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
	f.store_string(JSON.stringify({"ids":ids,"walls":walls,"fences":fences,"occupied":occupied})); f.close(); quit()

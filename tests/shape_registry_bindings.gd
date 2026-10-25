extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var inventory := Inventory.new(); Harvesting.initialize()
	var materials: Dictionary = {}; var families: Array = []; var occupied: Array = []
	for id in Nodes.all_ids()+VillageContent.DATA.keys():
		var name: String = ToolCapabilities.node_name(id)
		if not name.is_empty() and not BuildingShapes.is_shape(id): materials[str(id)] = name
	for base in BuildingShapes.MATERIALS+BuildingShapes.extra_list():
		families.append({"base":base,"key":MiningNodes.shape_key(base),"first":BuildingShapes.slab_for(base)})
	for id in range(3000,16384):
		if Nodes.exists(id): occupied.append(id)
	var file := FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
	file.store_string(JSON.stringify({"materials":materials,"families":families,"occupied":occupied})); file.close()
	print("SHAPE BINDINGS: ",materials.size()," materials, ",families.size()," native families")
	quit()

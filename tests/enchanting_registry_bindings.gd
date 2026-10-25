extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var inventory := Inventory.new()
	MiningNodes.initialize()
	var items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/harvest_items.json")).items
	var explicit: Dictionary = {}
	for name in items: explicit[int(items[name])] = name
	for key in ToolCapabilities.source.tools:
		var row: Dictionary = ToolCapabilities.source.tools[key]
		if row.own and not str(row.get("name","")).is_empty(): explicit[int(key)] = str(row.name)
	explicit[VillageContent.ENCHANTED_BOOK] = "mcl_enchanting:book_enchanted"
	for i in 4: explicit[MobArmor.COPPER_HELMET+i] = "mcl_armor:"+["helmet","chestplate","leggings","boots"][i]+"_copper"
	var bindings: Dictionary = {}; var unmapped: Array = []
	var ids: Array = Nodes.all_ids(); ids.append_array(explicit.keys())
	for id in ids:
		var name: String = str(explicit.get(id,ToolCapabilities.node_name(id)))
		if not name.is_empty(): bindings[str(id)] = name
		elif Enchanting.ability(id) != 0: unmapped.append({"id":id,"name":Nodes.title(id)})
	var output: String = OS.get_cmdline_user_args()[0]
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"bindings":bindings,"unmapped":unmapped})); file.close()
	print("ENCHANTMENT BINDINGS: ",bindings.size()," mapped, ",unmapped.size()," unmapped enchantable IDs")
	quit()

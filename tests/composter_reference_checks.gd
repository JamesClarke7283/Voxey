extends SceneTree
var failures: int = 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		if failures <= 14: push_error(message)
func compare(items: Array, source: Array) -> bool:
	for i in items.size():
		if int(items[i].get("id",0)) != int(source[i].id) or int(items[i].get("count",0)) != int(source[i].count): return false
	return true
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/composter_reference.json"))
	var mapped_items: int = 0
	for name in data.items:
		var id: int = Harvesting.item_id(name)
		if id == 0: continue
		var node: String = ToolCapabilities.node_name(id)
		if not node.is_empty() and Harvesting.canonical(node) != Harvesting.canonical(name): continue
		mapped_items += 1
		check(Composters.chance(id) == int(data.items[name]),"Mapped compostability differs: "+str(id)+" "+name+" source="+str(data.items[name])+" native="+str(Composters.chance(id)))
	for row in data.add:
		var state: Dictionary = {"compost":row.start}; var accepted: bool = false; var drops: int = 0
		if not row.auto and int(row.start) == 8: drops = int(Composters.harvest(state))
		else:
			var result: Dictionary = Composters.apply(state,int(row.id),int(row.roll),row.auto)
			accepted = result.accepted; drops = int(result.bone_meal)
		check(accepted == row.accepted and Composters.level(state) == int(row.level) and drops == int(row.drops),"Composter callback differs: "+str(row)+" native "+str(state))
	for row in data.farmers:
		var items: Array = VillagerInventory.clean(row.items); var state: Dictionary = {"compost":int(row.start)}; var rng := EnchantRolls.new(int(row.seed))
		var drops: int = FarmerWork.compost(items,state,rng)
		check(compare(items,row.items_after) and Composters.level(state) == int(row.level) and drops == int(row.drops) and rng.state == int(row.state),"Farmer compost differs: "+str(row)+" native "+str(items))
	for row in data.bread:
		var rows: Array = row.items.duplicate(true)
		for item in rows:
			if item.has("label"): item.data = {"custom_name":item.label}
		var items: Array = VillagerInventory.clean(rows); var overflow: int = FarmerWork.bread(items)
		check(compare(items,row.items_after) and overflow == int(row.drops),"Farmer bread differs: "+str(row)+" native "+str(items))
	for row in data.pickup:
		var items: Array = VillagerInventory.clean(row.items)
		check((VillagerInventory.wanted(row.profession,int(row.id)) and VillagerInventory.space(items,{"id":int(row.id),"count":int(row.count),"wear":0})) == row.accepted,"Villager pickup differs: "+str(row))
	for level in 9:
		var boxes: Array = Composters.boxes({"compost":level})
		for i in 5:
			var source: Array = data.geometry[level][i]; var low := Vector3(source[0]+0.5,source[1]+0.5,source[2]+0.5); var high := Vector3(source[3]+0.5,source[4]+0.5,source[5]+0.5)
			check(boxes[i].position.is_equal_approx(low) and boxes[i].end.is_equal_approx(high),"Composter collision geometry differs")
	print("COMPOSTER MAPPED ITEMS: ",mapped_items)
	print("COMPOSTER SOURCE: %d insertions, %d farmer composts, %d bread crafts, %d pickup cases, 9 geometry states; %d failures"%[data.add.size(),data.farmers.size(),data.bread.size(),data.pickup.size(),failures])
	quit(1 if failures else 0)

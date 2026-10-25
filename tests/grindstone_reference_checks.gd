extends SceneTree
var passed: int = 0
var failed: int = 0
var names: Dictionary = {}
var labels: Dictionary = {}
class FixedRoll extends RefCounted:
	var value: int
	func _init(n: int) -> void: value = n
	func integer(_low: int, _high: int) -> int: return value
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		if failed < 15: push_error(label)
func stack(raw: Variant) -> Dictionary:
	if not raw is Dictionary or str(raw.get("name","")).is_empty(): return GrindstoneRepair.empty()
	var id: int = int(names.get(raw.name,0))
	var result: Dictionary = {"id":id,"count":int(raw.get("count",1)),"wear":0,"data":{"junk":"discard me","pwp":9}}
	if not str(raw.get("label","")).is_empty(): result.data.custom_name = raw.label
	var enchants: Dictionary = {}
	for key in raw.get("enchants",{}): enchants[labels.get(key,key)] = int(raw.enchants[key])
	if not enchants.is_empty(): result.data.enchantments = enchants
	GrindstoneRepair.set_wear(result,int(raw.get("wear",0)))
	return result
func snapshot(slot: Dictionary) -> Dictionary:
	var id: int = int(slot.id); var data: Dictionary = slot.get("data",{})
	var name: String = str(GrindstoneRepair.profile(id).get("name","")) if id != 0 else ""
	if not data.get("enchantments",{}).is_empty() and GrindstoneRepair.tool(id) and not str(GrindstoneRepair.profile(id).get("enchanted","")).is_empty():
		name = str(GrindstoneRepair.profile(id).get("enchanted",name))
	var enchants: Dictionary = {}
	for title in data.get("enchantments",{}): enchants[str(Enchanting.source.definitions.get(title,{}).get("source_key",title))] = int(data.enchantments[title])
	return {"name":name,"count":int(slot.count),"wear":GrindstoneRepair.wear(slot),"label":str(data.get("custom_name","")),"enchants":enchants,"junk":str(data.get("junk","")),"pwp":int(data.get("pwp",0))}
func expected(raw: Dictionary) -> Dictionary:
	var result: Dictionary = raw.duplicate(true)
	result.count = int(result.count); result.wear = int(result.wear); result.pwp = int(result.pwp)
	if result.enchants == null: result.enchants = {}
	for name in result.enchants: result.enchants[name] = int(result.enchants[name])
	return result
func run() -> void:
	var inv := Inventory.new()
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/grindstone_reference.json"))
	for id in ref.profiles:
		var p: Dictionary = ref.profiles[id]
		names[p.name] = int(id)
	for name in Enchanting.source.definitions: labels[Enchanting.source.definitions[name].source_key] = name
	for row in ref.cases:
		var state: Dictionary = {"slots":[stack(row.a),stack(row.b),GrindstoneRepair.empty()]}
		GrindstoneRepair.refresh(state)
		check(snapshot(state.slots[2]) == expected(row.preview),"Source preview: "+str(row.a)+" + "+str(row.b)+" got "+str(snapshot(state.slots[2]))+" expected "+str(row.preview))
		var taken: Dictionary = GrindstoneRepair.take(state,FixedRoll.new(int(row.roll)))
		check(int(taken.xp) == int(row.xp),"Source XP "+str(row.a))
		for i in 3: check(snapshot(state.slots[i]) == expected(row.after[i]),"Source consumed inputs "+str(row.a)+" slot "+str(i))
		GrindstoneRepair.refresh(state)
		check(snapshot(state.slots[2]) == expected(row.reopened),"Source reopened preview "+str(row.a))
	for row in ref.permissions:
		var index: int = 0 if row.list == "input" else 2
		check((3 if GrindstoneRepair.accepts(index,Nodes.DIRT,row.protected) else 0) == int(row.put),"Source insertion permissions")
	for row in ref.placements:
		var d: Dictionary = row.dir; var o: Dictionary = row.offset
		check(GrindstoneRepair.placement(Vector3i(d.x,d.y,d.z),Vector3(o.x,o.y,o.z)) == int(row.param),"Source mounted placement")
	for param in 24:
		var id: int = GrindstoneRepair.placed(param)
		check(GrindstoneRepair.facing(id) == param and Nodes.exists(id),"All 24 grindstone orientations exist")
		check(not Stonecutting.is_cutter(id) and not Barriers.is_barrier(id) and not BuildingShapes.is_shape(id) and not Doors.is_door(id) and not Trapdoors.is_trapdoor(id),"Grindstone IDs do not collide")
		check(Nodes.placeable(id) == (param == 0) and Harvesting.item_for(id) == VillageContent.GRINDSTONE,"Hidden orientations and canonical item")
		for mode in [1,2]: check(GrindstoneRepair.facing(Screwdriver.rotate(id,mode)) == int(ref.orientations[str(param)].rotate[mode-1]),"Source screwdriver rotation")
		check(GrindstoneRepair.boxes(id).size() == 5,"Source collision boxes")
	for wood in WoodTypes.PLANKS:
		for offset in [0,3]:
			inv.grid = []
			for i in 9: inv.grid.append(GrindstoneRepair.empty())
			var recipe: Array = [Nodes.STICK,BuildingShapes.slab_for(Nodes.STONE),Nodes.STICK,wood,0,wood]
			for i in recipe.size():
				if recipe[i] != 0: inv.grid[i+offset] = {"id":recipe[i],"count":1,"wear":0}
			var result: Dictionary = inv.take_grid_result("table")
			check(int(result.get("id",0)) == VillageContent.GRINDSTONE,"Source grindstone recipe accepts any wood in either vertical offset")
	inv.grid = []
	for id in [Nodes.STICK,Nodes.STONE,Nodes.STICK,Nodes.PLANKS,0,Nodes.PLANKS,0,0,0]: inv.grid.append({"id":id,"count":1 if id else 0,"wear":0})
	check(inv.take_grid_result("table").is_empty(),"Old full-stone shortcut recipe is rejected")
	check(Nodes.hardness(VillageContent.GRINDSTONE) == float(ref.node.hardness),"Source grindstone hardness")
	print("GRINDSTONE SOURCE: %d cases; %d passed, %d failed"%[ref.cases.size(),passed,failed])
	quit(1 if failed else 0)

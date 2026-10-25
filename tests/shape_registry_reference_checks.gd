extends SceneTree
var checked: int = 0
var failed: int = 0
var ids: Dictionary = {}
func _init() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checked += 1
	if not value:
		failed += 1
		if failed <= 20: push_error(label)
func id_for(name: String) -> int:
	if name.is_empty(): return 0
	if ids.has(name): return int(ids[name])
	var canonical: String = Harvesting.canonical(name)
	for first in ShapeCatalog.data.families:
		var row: Dictionary = ShapeCatalog.data.families[first]
		for kind in ["slab","stair","top","double"]:
			if Harvesting.canonical(str(row[kind].name)) == canonical:
				ids[name] = int(first)+{"slab":0,"top":1,"double":2,"stair":3}[kind]
				return int(ids[name])
	ids[name] = FurnaceRules.item_id(name)
	return int(ids[name])

func run() -> void:
	var inv := Inventory.new()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/shapes_reference.json"))
	check(ShapeCatalog.data.families.size() == source.families.size(),"Every source family has a native binding")
	for key in source.families:
		var first: int = int(ShapeCatalog.data.by_key.get(key,0))
		check(first > 0 and BuildingShapes.is_shape(first),"Registered family exists: "+key)
		for kind in ["slab","top","double","stair"]:
			var row: Dictionary = source.families[key][kind]
			var id: int = first+{"slab":0,"top":1,"double":2,"stair":3}[kind]
			check(ToolCapabilities.node_name(id) == row.name,"Registered shape name: "+row.name)
			check(is_equal_approx(Nodes.hardness(id),float(row.hardness)),"Registered shape hardness: "+row.name)
			# The source's 7.5-second slab burn is truncated to 7 in the exported JSON.
			var expected_fuel: float = 7.5 if BuildingShapes.half_slab(id) and is_equal_approx(float(row.fuel),7.0) else float(row.fuel)
			check(is_equal_approx(Nodes.fuel_time(id),expected_fuel),"Registered shape fuel: "+row.name)
			var drops: Array = []
			for stack in row.drop:
				var parts: PackedStringArray = str(stack).split(" ")
				drops.append([id_for(parts[0]),int(parts[1]) if parts.size() > 1 else 1])
			check(Enchantments.harvest(id,{"id":Nodes.TOOLS+15,"count":1,"wear":0}) == drops,"Registered shape drops: "+row.name)
			var expected: Array = []
			for name in row.get("cuts",[]) if row.get("cuts") is Array else []: expected.append(id_for(name))
			if kind in ["slab","stair"]: check(BuildingShapes.stonecutter_inputs(BuildingShapes.material(id),kind == "stair") == expected,"Registered stonecutter inputs: "+row.name+" got="+str(BuildingShapes.stonecutter_inputs(BuildingShapes.material(id),kind == "stair"))+" expected="+str(expected))
		check(Nodes.placeable(first) and not Nodes.placeable(first+1) and not Nodes.placeable(first+2) and Nodes.placeable(first+3),"Only base slab and stair are inventory-placeable: "+key)
	for row in source.get("crafting",[]):
		var unmapped: bool = false
		for i in 9:
			var id: int = id_for(str(row.input[i]))
			if id == 0 and not str(row.input[i]).is_empty(): unmapped = true
			inv.grid[i] = {"id":id,"count":2 if id else 0,"wear":0}
		check(not unmapped,"Craft input mapping: "+str(row.input))
		var output: Dictionary = inv.take_grid_result("table")
		check(int(output.get("id",0)) == id_for(str(row.output)) and int(output.get("count",0)) == int(row.count),"Engine craft output: "+str(row.input)+" got="+str(output)+" expected="+str([row.output,row.count]))
		var left: Array = inv.grid.map(func(slot): return int(slot.count))
		check(left == row.after.map(func(v): return int(v)),"Engine craft consumption: "+str(row.input))
	print("SHAPE REGISTRY: %d families, %d craft cases; %d checks, %d failures"%[source.families.size(),source.get("crafting",[]).size(),checked,failed])
	quit(1 if failed else 0)

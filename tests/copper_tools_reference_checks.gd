extends SceneTree

var failed: int = 0
var checked: int = 0

func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failed += 1
		if failed <= 16: push_error(label)

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/copper_tools_reference.json"))
	var inv := Inventory.new()
	for row in source.items:
		var id: int = int(row.id)
		var caps: Dictionary = ToolCapabilities.profile(id).levels[0]
		var melee: Dictionary = MeleeCombat.profile(id)
		check(Nodes.exists(id) and not Nodes.placeable(id) and Nodes.max_stack(id) == int(row.stack),"Copper item registration: "+row.name)
		check(Harvesting.item_id(row.name) == id and ToolCapabilities.profile(id).name == row.name,"Copper source binding: "+row.name)
		# calculate_durability uses next(groupcaps). Lua table iteration can pick
		# any sword group across processes; the saved native profile pins one.
		var lifetimes: Array = row.caps.groupcaps.values().map(func(cap): return int(cap.uses))
		check(int(Durability.uses({"id":id})) in lifetimes,"Copper utility durability uses a registered group: "+row.name)
		check(melee.uses == row.caps.punch_attack_uses and is_equal_approx(melee.interval,row.caps.full_punch_interval) and melee.groups == row.caps.damage_groups,"Copper punch capabilities: "+row.name)
		check(caps.groupcaps.size() == row.caps.groupcaps.size(),"Copper dig groups: "+row.name)
		for group in row.caps.groupcaps:
			var actual: Dictionary = caps.groupcaps.get(group,{})
			check(actual.get("times",[]) == row.caps.groupcaps[group].times and actual.get("uses",0) == row.caps.groupcaps[group].uses and actual.get("maxlevel",-1) == row.caps.groupcaps[group].maxlevel,"Copper dig capability: "+row.name+" "+group)
		check(Anvils.repair_material(id) == Harvesting.item_id(row.repair),"Copper repair material: "+row.name)
		check(Nodes.smelt_result(id) == Harvesting.item_id(row.cooking.item) and row.cooking.count == 1 and CopperTools.DATA[id].cook_time == row.cooking.time,"Copper recycling: "+row.name)
		check(CopperTools.DATA[id].blast_furnace_smeltable == bool(row.groups.blast_furnace_smeltable) and Enchanting.ability(id) == row.groups.enchantability,"Copper item groups: "+row.name)
	for row in source.increments:
		check(ToolCapabilities.action_increment(int(row.id)) == int(row.wear),"Registered action wear: "+row.name)
	for row in source.crafting:
		for i in 9: inv.grid[i] = {"id":int(row.cells[i]),"count":1 if row.cells[i] else 0,"wear":0}
		check(inv.matching_recipe("inventory") == -1,"Copper recipe requires a table: "+str(row.id))
		var crafted: Dictionary = inv.take_grid_result("table")
		check(crafted.get("id",0) == row.id and crafted.get("count",0) == row.count,"Copper shaped recipe: "+str(row))
		for i in 9: check(inv.grid[i].count == row.after[i],"Copper ingredient consumption: "+str(i))
	print("COPPER TOOLS SOURCE: %d items, %d action increments, %d recipes; %d checks, %d failures"%[source.items.size(),source.increments.size(),source.crafting.size(),checked,failed])
	quit(1 if failed else 0)

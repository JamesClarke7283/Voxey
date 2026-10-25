extends SceneTree

var failed: int = 0
var checked: int = 0
var failure_types: Dictionary = {}
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failed += 1
		var category: String = label.get_slice(":",0)
		failure_types[category] = int(failure_types.get(category,0))+1
		if failure_types[category] <= 4: push_error(label)

func native_id(name: String) -> int:
	# The existing river sponge shares the native water-bucket item.
	if name == "mcl_buckets:bucket_river_water": return Nodes.WATER_BUCKET
	return FurnaceRules.item_id(name)

func item(value: Variant) -> Dictionary:
	if value is String:
		var words: PackedStringArray = value.split(" ")
		var count: int = int(words[1]) if words.size() > 1 else (1 if not value.is_empty() else 0)
		if FurnaceRules.registry.items.get(Harvesting.canonical(words[0]),{}).get("tool",false): count = mini(count,1)
		return {"id":native_id(words[0]),"count":count,"wear":0}
	return {"id":native_id(str(value.name)),"count":int(value.count),"wear":int(value.wear)}

func state(device: String, initial: Dictionary) -> Dictionary:
	var slots: Array = []
	for raw in initial.slots: slots.append(item(raw))
	return {"device":native_id(device),"slots":slots,"progress":float(initial.get("progress",0)),"src_item":str(initial.get("input","")),"fuel_time":float(initial.get("used",0)),"fuel_totaltime":float(initial.get("total",0)),"burn":float(initial.get("total",0))-float(initial.get("used",0)),"burn_checkpoint":float(initial.get("total",0))-float(initial.get("used",0)),"xp":int(initial.get("xp",0))}

func same_slots(actual: Array, expected: Array) -> bool:
	for i in 3:
		var target: Dictionary = item(expected[i])
		if int(actual[i].id) != target.id or int(actual[i].count) != target.count or int(actual[i].get("wear",0)) != target.wear: return false
	return true

func run() -> void:
	var inventory := Inventory.new()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/furnace_reference.json"))
	for id in FurnaceRules.registry.bindings:
		var name: String = FurnaceRules.registry.bindings[id]; var profile: Dictionary = FurnaceRules.registry.items[name]
		var actual: Dictionary = FurnaceRules.recipe(int(id))
		check(is_equal_approx(actual.time,profile.cook.time) and (actual.id == 0 if profile.cook.time == 0 else actual.id != 0 and actual.id == native_id(profile.cook.item.name) and actual.count == profile.cook.item.count),"Registered cooking: "+name)
		var expected_fuel: float = 7.5 if BuildingShapes.half_slab(int(id)) and is_equal_approx(float(profile.fuel.time),7.0) else float(profile.fuel.time)
		check(is_equal_approx(Nodes.fuel_time(int(id)),expected_fuel),"Registered fuel: "+name)
		for device in [Nodes.FURNACE,VillageContent.BLAST_FURNACE,VillageContent.SMOKER]:
			var eligible: bool = profile.cook.time > 0 and (device == Nodes.FURNACE or profile.blast if device == VillageContent.BLAST_FURNACE else profile.smoker)
			# Keep the regular-furnace case explicit to avoid ternary precedence.
			if device == Nodes.FURNACE: eligible = profile.cook.time > 0
			check(FurnaceRules.cookable(int(id),device) == eligible,"Registered device gate: "+name+" "+str(device))
	for row in fixture.permissions:
		if int(row.id) == 0: continue # Air is a source node, but not a native inventory item.
		var station: Dictionary = state(row.device,{"slots":["","mcl_core:coal_lump" if row.occupied else "",""]})
		for i in 3:
			var allowed: int = FurnaceRules.allowed_count(station.slots,i,{"id":int(row.id),"count":1 if FurnaceRules.profile(int(row.id)).get("tool",false) else 3,"wear":0})
			check(allowed == row.values[i],"Source insertion rule: "+str(row.id)+" "+str(i)+" got="+str(allowed)+" expected="+str(row.values[i]))
	for row in fixture.timers:
		var station: Dictionary = state(row.device,row.initial); var index: int = 0
		for event in row.steps:
			if event is Array:
				for i in event.size():
					if event[i] is String: station.slots[i] = item(event[i])
			else:
				FurnaceRules.step(station,float(event))
				var frame: Dictionary = row.frames[index]; index += 1
				check(same_slots(station.slots,frame.slots),"Timer inventory: "+row.device+" "+row.label+" frame="+str(index)+" got="+str(station.slots)+" expected="+str(frame.slots))
				check(is_equal_approx(station.progress,frame.progress) and is_equal_approx(station.fuel_time,frame.used) and is_equal_approx(station.fuel_totaltime,frame.total),"Timer arithmetic: "+row.label+" frame="+str(index)+" got="+str([station.progress,station.fuel_time,station.fuel_totaltime])+" expected="+str([frame.progress,frame.used,frame.total]))
				check(station.active == frame.active and station.xp == frame.xp and station.src_item == frame.input,"Timer state: "+row.label+" frame="+str(index))
	for row in fixture.sorters:
		var station: Dictionary = state(row.device,row.initial); var source: Dictionary = item(row.name+" 3")
		var moved: int = FurnaceRules.quick_move(station,source)
		check(moved == row.allowed and same_slots(station.slots,row.slots),"Quick-move sorter: "+row.device+" "+row.name+" got="+str([moved,station.slots])+" expected="+str([row.allowed,row.slots]))
	for row in fixture.clocks:
		var clock: Dictionary = {"last_gametime":row.initial}
		for frame in row.frames:
			var elapsed: float = 0
			if row.reset: FurnaceRules.reset_clock(clock,frame.clock)
			else: elapsed = FurnaceRules.delta_time(clock,0.25,frame.clock)
			check(is_equal_approx(elapsed,frame.elapsed) and is_equal_approx(clock.last_gametime,frame.last),"Furnace game clock: "+str(row.initial)+" reset="+str(row.reset)+" now="+str(frame.clock))
	print("FURNACE SOURCE: %d bindings, %d timer sequences, %d permission rows, %d sorters; %d checks, %d failures"%[FurnaceRules.registry.bindings.size(),fixture.timers.size(),fixture.permissions.size(),fixture.sorters.size(),checked,failed])
	if not failure_types.is_empty(): print(failure_types)
	quit(1 if failed else 0)

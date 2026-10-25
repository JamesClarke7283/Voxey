class_name FurnaceRules
extends RefCounted

# `mcl_furnaces/init.lua`:407 stores one point of experience per smelted item in the
# furnace's own metadata, paid out when the output is withdrawn (`give_xp`, :99-111).
# The source's own comment records that every recipe shares this single count.
const XP_PER_SMELT = 1
static var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/furnaces.json"))
static var reverse_bindings: Dictionary = {}

static func item_id(name: String) -> int:
	var existing: int = Harvesting.item_id(name)
	if existing != 0: return existing
	if reverse_bindings.is_empty():
		for key in registry.bindings:
			var source_item: String = Harvesting.canonical(str(registry.bindings[key]))
			var id: int = int(key)
			if id != 0 and (not reverse_bindings.has(source_item) or id < int(reverse_bindings[source_item])): reverse_bindings[source_item] = id
	return int(reverse_bindings.get(Harvesting.canonical(name),0))

static func source_name(id: int) -> String:
	if id == 0: return ""
	return str(registry.bindings.get(str(id),MiningNodes.node_name(id)))

static func profile(id: int) -> Dictionary:
	var name: String = source_name(id)
	if name.is_empty(): return {}
	return registry.items.get(name,{"cook":{"time":0},"fuel":{"time":0},"blast":false,"smoker":false})

static func recipe(id: int) -> Dictionary:
	var data: Dictionary = profile(id)
	if not data.is_empty():
		var cook: Dictionary = data.cook
		if float(cook.time) <= 0: return {"id":0,"count":0,"time":0.0}
		var output: int = item_id(str(cook.item.name))
		return {"id":output,"count":int(cook.item.count),"time":float(cook.time)}
	var output: int = Nodes.native_smelt_result(id)
	return {"id":output,"count":1 if output else 0,"time":8.0 if output else 0.0}

static func fuel(id: int) -> Dictionary:
	var data: Dictionary = profile(id)
	if not data.is_empty():
		var value: Dictionary = data.fuel
		var native_time: float = Nodes.native_fuel_time(id)
		if float(value.time) > 0.0 and BuildingShapes.half_slab(id) and native_time > 0.0:
			# The JSON exporter truncates the source's 7.5-second slab burn to 7.
			return {"time":native_time,"replacement":item_id(str(value.after.name)) if value.has("after") else 0}
		return {"time":float(value.time),"replacement":item_id(str(value.after.name)) if value.has("after") and float(value.time) > 0 else 0}
	return {"time":Nodes.native_fuel_time(id),"replacement":Nodes.BUCKET if id == Nodes.LAVA_BUCKET else 0}

static func factor(device: int) -> float:
	return 2.0 if device in [VillageContent.BLAST_FURNACE,VillageContent.SMOKER] else 1.0

static func cookable(id: int, device: int = Nodes.FURNACE) -> bool:
	if recipe(id).id == 0: return false
	var data: Dictionary = profile(id)
	if device == VillageContent.BLAST_FURNACE:
		return bool(data.blast) if not data.is_empty() else bool(VillageContent.DATA.get(id,{}).get("blast_furnace_smeltable",false))
	if device == VillageContent.SMOKER: return bool(data.smoker) if not data.is_empty() else Nodes.food(recipe(id).id) > 0
	return true

# Source permits any item in src. Only sorter/quick-move selects a cookable
# input; a blocked output does not prohibit manual insertion.
static func allowed_count(slots: Array, index: int, item: Dictionary) -> int:
	var id: int = int(item.get("id",0)); var count: int = int(item.get("count",0))
	if id == 0: return 0
	if slots.size() != 3: return 0
	if index == 0: return count
	if index != 1: return 0
	var energy: Dictionary = fuel(id)
	if id == Nodes.BUCKET or energy.replacement != 0:
		return 1 if int(slots[1].get("count",0)) == 0 else 0
	return count if energy.time > 0 else 0

# All insertion paths share this rule; extracting items never needs permission.
static func accepts(slots: Array, index: int, id: int) -> bool:
	if id == 0: return true
	return allowed_count(slots,index,{"id":id,"count":1}) > 0

static func room(slot: Dictionary, item: Dictionary) -> int:
	# Luanti's empty list slot accepts an existing overstack intact. This
	# matters for the source sorter, even for normally unstackable buckets.
	if slot.id == 0: return maxi(Nodes.max_stack(int(item.id)),int(item.get("count",1)))
	if slot.id != 0 and (slot.id != item.id or slot.get("wear",0) != item.get("wear",0) or slot.get("data",{}) != item.get("data",{})): return 0
	return maxi(0,Nodes.max_stack(int(item.id))-int(slot.get("count",0)))

static func sorter(station: Dictionary, item: Dictionary) -> int:
	var id: int = int(item.get("id",0)); var device: int = int(station.get("device",Nodes.FURNACE))
	if cookable(id,device):
		if fuel(id).time > 0 and room(station.slots[0],item) < int(item.count): return 1
		return 0
	if fuel(id).time > 0 or id == Nodes.BUCKET and cookable(Sponges.WET,device): return 1
	return -1

static func quick_move(station: Dictionary, item: Dictionary) -> int:
	var index: int = sorter(station,item)
	if index < 0: return 0
	var destination: Dictionary = station.slots[index]
	# The source sorter bypasses the manual replacement-fuel restriction.
	var count: int = mini(int(item.count),room(destination,item))
	if int(item.id) == Nodes.BUCKET: count = 1 if destination.count == 0 else 0
	if count <= 0: return 0
	if destination.id == 0:
		destination.clear(); destination.merge(item.duplicate(true)); destination.count = 0
	destination.count += count; item.count -= count
	if item.count <= 0: item.clear(); item.merge({"id":0,"count":0,"wear":0})
	return count

static func take_one(slot: Dictionary, replacement: int = 0) -> void:
	slot.count -= 1
	if slot.count <= 0:
		slot.clear(); slot.merge({"id":replacement,"count":1 if replacement else 0,"wear":0})

static func burning(station: Dictionary) -> bool:
	if station.has("burn_checkpoint") and is_equal_approx(float(station.get("burn",0)),float(station.burn_checkpoint)):
		return bool(station.get("active",false))
	return float(station.get("burn",0)) > 0

# mcl_furnaces.get_timer_function. Elapsed is the same game-time interval the
# source callback receives, including its factor and first-fuel-tick behavior.
static func step(station: Dictionary, elapsed: float = 1.0) -> int:
	if not is_finite(elapsed): return 0
	var slots: Array = station.slots
	var source: Dictionary = slots[0]; var fuel_slot: Dictionary = slots[1]; var output: Dictionary = slots[2]
	var used: float = float(station.get("fuel_time",0)); var total: float = float(station.get("fuel_totaltime",0))
	var burn: float = float(station.get("burn",0))
	if not station.has("burn_checkpoint") or not is_equal_approx(burn,float(station.burn_checkpoint)):
		used = 0; total = maxf(0,burn)
	var progress: float = float(station.get("progress",0)); var name: String = source_name(int(source.id))
	if name.is_empty() and source.id != 0: name = "native:"+str(source.id)
	if name != str(station.get("src_item",name)): progress = 0
	station.src_item = name
	var active: bool = true; var can_cook: bool = false; var update: bool = true; var produced: int = 0
	var energy: Dictionary = {}; var device: int = int(station.get("device",Nodes.FURNACE))
	while elapsed > 0.00001 and update:
		var interval: float = elapsed*factor(device)
		var cooked: Dictionary = recipe(int(source.id))
		can_cook = int(source.count) > 0 and cookable(int(source.id),device)
		if can_cook: can_cook = room(output,{"id":int(cooked.id),"count":int(cooked.count),"wear":0}) >= int(cooked.count)
		if can_cook: interval = minf(interval,float(cooked.time)-progress)
		active = used < total
		if can_cook and not active:
			energy = fuel(int(fuel_slot.id))
			if int(fuel_slot.count) <= 0 or energy.time <= 0:
				total = 0; progress = 0; update = false
			else:
				take_one(fuel_slot,int(energy.replacement)); used = 0; total = float(energy.time)
				interval = minf(interval,total); active = true
		elif active:
			interval = minf(interval,total-used); used += interval
		if can_cook and active:
			progress += interval
			if progress >= float(cooked.time):
				if output.id == 0: output.clear(); output.merge({"id":int(cooked.id),"count":0,"wear":0})
				output.count += int(cooked.count)
				if int(fuel_slot.id) == Nodes.BUCKET:
					var replacement: int = Sponges.cooking_replacement(int(source.id))
					if replacement != 0: fuel_slot.clear(); fuel_slot.merge({"id":replacement,"count":1,"wear":0})
				take_one(source); progress = 0; station.xp = int(station.get("xp",0))+XP_PER_SMELT; produced += 1
		elapsed -= interval
	if not energy.is_empty() and total > float(energy.time): total = float(energy.time)
	if source.id == 0: progress = 0
	station.fuel_time = used; station.fuel_totaltime = total; station.progress = progress
	station.active = active; station.cookable = can_cook
	station.burn = maxf(0,total-used); station.burn_checkpoint = station.burn
	return produced

static func delta_time(station: Dictionary, elapsed: float, now: float, enabled: bool = true) -> float:
	if not enabled: return elapsed
	var previous: float = float(station.get("last_gametime",0))
	if previous < 1: previous = now-0.1
	elif previous == now: now += 1.0
	station.last_gametime = now
	return now-previous

static func reset_clock(station: Dictionary, now: float) -> void:
	var previous: float = float(station.get("last_gametime",0))
	if previous < 1 or absf(previous-now) <= 1.5: return
	station.last_gametime = now

static func world_step(station: Dictionary, now: float, elapsed: float = 1.0) -> int:
	return step(station,delta_time(station,elapsed,now))

static func status(station: Dictionary) -> String:
	var percent: int = 0; var item: Dictionary = recipe(int(station.slots[0].id))
	if item.time > 0 and bool(station.get("cookable",false)): percent = clampi(floori(float(station.get("progress",0))/float(item.time)*100),0,100)
	return "Smelting  %d%%  ·  Fuel remaining: %ds"%[percent,ceili(float(station.get("burn",0))/factor(int(station.get("device",Nodes.FURNACE))))] if burning(station) else "Add a cookable item and fuel."

static func options(device: int, fuels: bool = false) -> Array:
	var ids: Array = []
	for id in Nodes.all_ids():
		if fuel(id).time > 0 if fuels else cookable(id,device): ids.append(id)
	ids.sort_custom(func(a,b): return Nodes.title(a).naturalnocasecmp_to(Nodes.title(b)) < 0)
	return ids

static func description(id: int, device: int, fuels: bool = false) -> String:
	if fuels: return "%s\nBurns for %.1f seconds\nin this furnace"%[Nodes.title(id),float(fuel(id).time)/factor(device)]
	var cooked: Dictionary = recipe(id)
	return "%s → %s\n%.1f seconds per item"%[Nodes.title(id),Nodes.title(int(cooked.id)),float(cooked.time)/factor(device)]

# `mcl_furnaces.give_xp`: the whole accumulated count is paid out when the output is
# withdrawn, and the store is cleared. `player` picks the source's branch — a player
# taking the output is credited directly, while an automated extraction (a hopper)
# throws the experience at the furnace as orbs.
static func payout(game: Node3D, station: Dictionary, at: Vector3, player: bool = true) -> int:
	var xp: int = take_xp(station)
	if xp <= 0: return 0
	if player: XpOrbs.award(game,xp)
	else: XpOrbs.throw_xp(game,at,xp)
	return xp

static func take_xp(station: Dictionary) -> int:
	var xp: int = maxi(0,int(station.get("xp",0)))
	station.erase("xp")
	return xp

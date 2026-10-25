class_name GrindstoneRepair
extends RefCounted

# mcl_grindstone/init.lua (GPL-3.0-or-later), using its registered tool types,
# exact 0..65535 wear, fresh metadata and three-slot callback lifecycle.
static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/grindstone.json"))
const FIRST = 15400
const LAST = 15422
const BONUS = 1.05
const XP_LOW = 7
const XP_HIGH = 13
static func empty() -> Dictionary: return {"id":0,"count":0,"wear":0}
static func is_grindstone(id: int) -> bool: return id == VillageContent.GRINDSTONE or id >= FIRST and id <= LAST
static func base(id: int) -> int: return VillageContent.GRINDSTONE if is_grindstone(id) else id
static func facing(id: int) -> int: return id-FIRST+1 if id >= FIRST and id <= LAST else 0
static func placed(param: int) -> int: return VillageContent.GRINDSTONE if posmod(param,24) == 0 else FIRST+posmod(param,24)-1
static func rotate(id: int, mode: int) -> int: return placed(int(source.orientations[str(facing(id))].rotate[clampi(mode-1,0,1)]))
static func profile(id: int) -> Dictionary: return source.profiles.get(str(id),{})
static func tool(id: int) -> bool: return bool(profile(id).get("tool",Nodes.durability(id) > 0))
static func compatible(a: Dictionary, b: Dictionary) -> bool:
	var id: int = int(a.get("id",0)); var other: int = int(b.get("id",0))
	return id != 0 and other != 0 and tool(id) and tool(other) and str(profile(id).get("name",str(id))) == str(profile(other).get("name",str(other)))
static func repair_wear(wear1: int, wear2: int, span: int = Durability.SCALE) -> int:
	return clampi(int(float(span)-((span-wear1)+(span-wear2)*BONUS)),0,span)
static func wear(slot: Dictionary) -> int:
	if Nodes.durability(int(slot.get("id",0))) > 0: return Durability.normalized(slot)
	return clampi(int(slot.get("data",{}).get("wear_normalized",0)),0,Durability.SCALE) if tool(int(slot.get("id",0))) else 0
static func set_wear(slot: Dictionary, amount: int) -> void:
	if Nodes.durability(int(slot.id)) > 0: Durability.set_normalized(slot,amount)
	elif tool(int(slot.id)) and amount > 0:
		if not slot.has("data"): slot.data = {}
		slot.data.wear_normalized = clampi(amount,0,Durability.SCALE); slot.data.wear_display = int(slot.wear)
static func fresh(id: int, original: Dictionary, wear: int = -1) -> Dictionary:
	var result: Dictionary = {"id":id,"count":1,"wear":0}
	var label: String = str(original.get("data",{}).get("custom_name",""))
	if not label.is_empty(): result.data = {"custom_name":label}
	if wear >= 0: set_wear(result,wear)
	return result
static func transfer_curses(original: Dictionary, result: Dictionary) -> void:
	for name in original.get("data",{}).get("enchantments",{}):
		if not bool(Enchantments.DATA.get(name,{}).get("curse",false)): continue
		if not result.has("data"): result.data = {}
		if not result.data.has("enchantments"): result.data.enchantments = {}
		result.data.enchantments[name] = int(original.data.enchantments[name])
		if result.id == Nodes.BOOK: result.id = VillageContent.ENCHANTED_BOOK
static func combine(a: Dictionary, b: Dictionary, _rng: Variant = null) -> Dictionary:
	if not compatible(a,b): return {}
	var result: Dictionary = fresh(int(a.id),a,repair_wear(wear(a),wear(b)))
	transfer_curses(a,result); transfer_curses(b,result)
	return result
static func disenchant(input: Dictionary) -> Dictionary:
	var id: int = int(input.get("id",0))
	var result: Dictionary = {}
	if id == VillageContent.ENCHANTED_BOOK: result = fresh(Nodes.BOOK,input)
	elif tool(id) and not input.get("data",{}).get("enchantments",{}).is_empty() and not str(profile(id).get("enchanted","")).is_empty():
		result = fresh(id,input,wear(input))
	if not result.is_empty(): transfer_curses(input,result)
	return result
static func xp_for(slot: Dictionary, rng: Variant = null) -> int:
	var xp: int = 0
	for name in slot.get("data",{}).get("enchantments",{}):
		var level: int = int(slot.data.enchantments[name])
		if level > 0 and not bool(Enchantments.DATA.get(name,{}).get("curse",false)):
			xp += (randi_range(XP_LOW,XP_HIGH) if rng == null else (rng.randi_range(XP_LOW,XP_HIGH) if rng is RandomNumberGenerator else rng.integer(XP_LOW,XP_HIGH)))*level
	return xp
static func station(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.stations.has(key): world.stations[key] = VoxelWorld._new_station("grindstone",3)
	return world.stations[key]
static func refresh(state: Dictionary) -> void:
	var a: Dictionary = state.slots[0]; var b: Dictionary = state.slots[1]
	var result: Dictionary = combine(a,b) if a.id != 0 and b.id != 0 else disenchant(a if a.id != 0 else b)
	state.slots[2] = empty() if result.is_empty() else result
static func accepts(index: int, id: int, protected: bool = false) -> bool: return not protected and (index in [0,1] or id == 0)
static func consume(state: Dictionary, index: int, amount: int) -> void:
	state.slots[index].count = maxi(0,int(state.slots[index].count)-amount)
	if state.slots[index].count == 0: state.slots[index] = empty()
static func after_transfer(state: Dictionary, before: Array, rng: Variant = null) -> int:
	if before[2].id != 0 and int(state.slots[2].count) < int(before[2].count):
		var taken: int = int(before[2].count)-int(state.slots[2].count)
		var amount: int = 1 if before[0].id != 0 and before[1].id != 0 else taken
		var xp: int = 0
		for index in 2:
			if before[index].id != 0:
				xp += xp_for(before[index],rng); consume(state,index,amount)
		# Taking output does not run update_grindstone_slots in the source.
		return xp
	if before[0] != state.slots[0] or before[1] != state.slots[1]: refresh(state)
	return 0
static func take(state: Dictionary, rng: Variant = null) -> Dictionary:
	var before: Array = state.slots.duplicate(true); var output: Dictionary = before[2].duplicate(true)
	state.slots[2] = empty()
	return {"item":output,"xp":after_transfer(state,before,rng)}
static func boxes(id: int) -> Array:
	var result: Array = []
	for raw in source.orientations[str(facing(id))].boxes:
		var low := Vector3(raw[0],raw[1],raw[2])+Vector3.ONE*0.5
		var high := Vector3(raw[3],raw[4],raw[5])+Vector3.ONE*0.5
		result.append(AABB(low,high-low))
	return result
static func mesh(out: Array, p: Vector3, id: int) -> void:
	var shapes: Array = boxes(id)
	for i in shapes.size():
		var shape: AABB = shapes[i]
		var tile: int = Nodes.tile(VillageContent.GRINDSTONE if i == 0 else Nodes.PLANKS,0)
		BlockMesher._art_box(out,p+shape.get_center(),shape.size,tile,tile)
static func placement(direction: Vector3i, offset: Vector3) -> int:
	if direction.z == -1: return 4
	if direction.z == 1: return 10
	if direction.x == -1: return 13
	if direction.x == 1: return 17
	return (0 if absf(offset.z) > absf(offset.x) else 1)+(20 if direction.y == 1 else 0)
static func try_place(game: Node3D, target: Dictionary) -> bool:
	if int(game.inventory.held().id) != VillageContent.GRINDSTONE or target.is_empty(): return false
	var p: Vector3i = target.get("replace",target.pos+target.normal)
	var old: int = game.world.node_at(p)
	if old != 0 and not Fluids.liquid(old) and not Nodes.plant(old): return true
	var id: int = placed(placement(-Vector3i(target.normal),game.player.global_position-Vector3(p)))
	var player := AABB(game.player.position-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58))
	for box in boxes(id):
		if player.intersects(AABB(Vector3(p)+box.position,box.size)): return true
	if game.world.set_node(p,id):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.api.emit_node_placed(p,id); game.sound("place"); game.player.swing = 1
	return true

static func pixel(x: int, y: int, noise: Color) -> Color:
	var radius: float = Vector2(x-7.5,y-7.5).length()
	if radius < 1.6: return Color("65503c")
	if radius < 2.6: return Color("bbb9b0")
	if radius > 6.3 and radius < 7.7: return noise.darkened(0.24)
	if radius > 4.1 and radius < 4.9: return noise.darkened(0.08)
	return noise

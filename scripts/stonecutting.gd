class_name Stonecutting
extends RefCounted

# Registered mcl_stonecutter recipes and its virtual output inventory.
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/stonecutting.json"))
const FIRST = 15300
const BLADE = 15303
const IDS = [524,15302,15301,15300,15304,15305,15306,15307,15308,15309,15310,15311,15312,15313,15314,15315,15316,15317,15318,15319,15320,15321,15322,15323]
static func is_cutter(id: int) -> bool: return id == VillageContent.STONECUTTER or id >= FIRST and id <= 15323 and id != BLADE
static func base(id: int) -> int: return VillageContent.STONECUTTER if is_cutter(id) else id
static func facing(id: int) -> int: return maxi(0,IDS.find(id))
static func placed(direction: int) -> int: return IDS[posmod(direction,24)]
static func rotate(id: int, mode: int) -> int: return placed(int(data.orientations[str(facing(id))].rotate[clampi(mode-1,0,1)]))
static func canonical(name: String) -> String:
	for i in 16:
		if not data.aliases.has(name): break
		name = str(data.aliases[name])
	return name
static func source(slot: Dictionary) -> String:
	if int(slot.get("id",0)) == 0: return ""
	var name: String = canonical(str(data.bindings.get(str(slot.id),FurnaceRules.source_name(int(slot.id)))))
	if Copper.waxed_item(slot): name += "_preserved"
	return name
static func choices(slot: Dictionary) -> Array: return data.recipes.get(source(slot),[])
static func recipe(slot: Dictionary, name: String) -> Dictionary:
	for row in choices(slot):
		if row.name == name: return row
	return {}
static func station(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.stations.has(key): world.stations[key] = VoxelWorld._new_station("stonecutter",2)
	return world.stations[key]
static func empty() -> Dictionary: return {"id":0,"count":0,"wear":0}
static func refresh(state: Dictionary) -> void:
	state.slots[1] = empty(); state.erase("output_name")
static func select(state: Dictionary, name: String) -> void:
	var row: Dictionary = recipe(state.slots[0],name)
	if row.is_empty(): refresh(state); return
	var amount: int = int(row.count)
	if source(state.slots[1]) == name:
		amount = mini(mini(int(state.slots[1].count)+amount,int(state.slots[0].count)*amount),Nodes.max_stack(int(row.id)))
	var output: Dictionary = {"id":int(row.id),"count":amount,"wear":0}
	if row.waxed: output.data = {"copper_waxed":true}
	state.slots[1] = output
static func fill(state: Dictionary) -> void:
	var row: Dictionary = recipe(state.slots[0],source(state.slots[1]))
	if row.is_empty(): return
	state.slots[1].count = mini(int(state.slots[0].count)*int(row.count),Nodes.max_stack(int(row.id)))
static func accepts(index: int, id: int, protected: bool = false) -> bool: return not protected and (index == 0 or id == 0)
static func allowed_take(state: Dictionary, index: int, count: int, protected: bool = false) -> int:
	if protected: return 0
	if index == 0: return count
	var row: Dictionary = recipe(state.slots[0],source(state.slots[1]))
	return mini(int(state.slots[0].count)*int(row.count),Nodes.max_stack(int(row.id))) if not row.is_empty() else 0
static func after_transfer(state: Dictionary, before: Array) -> void:
	if before[1].id != 0 and int(state.slots[1].count) < int(before[1].count):
		var row: Dictionary = recipe(before[0],source(before[1]))
		if not row.is_empty():
			var used: int = ceili(float(int(before[1].count)-int(state.slots[1].count))/int(row.count))
			state.slots[0].count = maxi(0,int(state.slots[0].count)-used)
			if state.slots[0].count == 0: state.slots[0] = empty()
		refresh(state)
	elif before[0] != state.slots[0]: refresh(state)
static func take(state: Dictionary, count: int) -> Dictionary:
	var actual: int = mini(mini(count,int(state.slots[1].count)),allowed_take(state,1,count))
	if actual <= 0: return empty()
	var before: Array = state.slots.duplicate(true)
	var result: Dictionary = state.slots[1].duplicate(true); result.count = actual
	state.slots[1].count -= actual
	after_transfer(state,before)
	return result

static func boxes(id: int, collision: bool = true) -> Array:
	var result: Array = []
	var row: Dictionary = data.orientations[str(facing(id))]
	for raw in row.body if collision else row.selection:
		var a := Vector3(float(raw[0]),float(raw[1]),float(raw[2]))+Vector3.ONE*0.5
		var b := Vector3(float(raw[3]),float(raw[4]),float(raw[5]))+Vector3.ONE*0.5
		result.append(AABB(a.min(b),a.max(b)-a.min(b)))
	return result
static func basis(id: int) -> Basis:
	var row: Dictionary = data.orientations[str(facing(id))]
	var vectors: Array = []
	for key in ["right","up","front"]: vectors.append(Vector3(float(row[key].x),float(row[key].y),float(row[key].z)))
	return Basis(vectors[0],vectors[1],vectors[2])
static func mesh(out: Array, p: Vector3, id: int) -> void:
	var base: AABB = boxes(id)[0]
	BlockMesher._art_box(out,p+base.get_center(),base.size,Nodes.tile(VillageContent.STONECUTTER,0),Nodes.tile(VillageContent.STONECUTTER,2))
	var points: Array = [Vector3(0.0625,0.5625,0.5),Vector3(0.9375,0.5625,0.5),Vector3(0.9375,1,0.5),Vector3(0.0625,1,0.5)]
	var transform: Basis = basis(id)
	for i in points.size(): points[i] = p+Vector3.ONE*0.5+transform*(points[i]-Vector3.ONE*0.5)
	var normal: Vector3 = transform*Vector3.BACK
	BlockMesher._quad(out,points,[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)],normal,Nodes.tile(BLADE,0),Color.WHITE,true)
	points.reverse()
	BlockMesher._quad(out,points,[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)],-normal,Nodes.tile(BLADE,0),Color.WHITE,true)
static func try_place(game: Node3D, target: Dictionary) -> bool:
	if int(game.inventory.held().id) != VillageContent.STONECUTTER or target.is_empty(): return false
	var p: Vector3i = target.get("replace",target.pos+target.normal)
	var previous: int = game.world.node_at(p)
	if previous != 0 and not Fluids.liquid(previous) and not Nodes.plant(previous): return true
	var id: int = placed(posmod(4-Barriers.placement_facing(target.pos+target.normal,game.player.global_position),4))
	var player := AABB(game.player.position-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58))
	if player.intersects(AABB(Vector3(p),Vector3(1,0.5625,1))): return true
	if game.world.set_node(p,id):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.api.emit_node_placed(p,id); game.sound("place"); game.player.swing = 1
	return true

static func blade_pixel(x: int, y: int) -> Color:
	var offset := Vector2((x+0.5)/8.0-1,(y+0.5)/16.0-1)
	var edge: float = 0.92 if int(floor((offset.angle()+PI)*12/PI))%2 == 0 else 1.0
	if offset.length() > edge: return Color.TRANSPARENT
	if offset.length() < 0.15: return Color("585b60")
	return Color("9b9fa5") if offset.length() > 0.8 else Color("c6cbd0")

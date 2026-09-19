class_name PortableStorage
extends RefCounted

# mcl_chests/init.lua: one personal Ender inventory and sixteen portable boxes.
# IDs are permanent save identifiers; color order matches VillageContent dyes.
const ENDER_CHEST = 1180
const SHULKER_BASE = 1181
const SHULKER_PURPLE = SHULKER_BASE+8
const SIZE = 27
const BLOCKS = [1180,1181,1182,1183,1184,1185,1186,1187,1188,1189,1190,1191,1192,1193,1194,1195,1196]
const DATA = {
	1180:{"name":"Ender chest","color":"243d39","block":true,"hardness":22.5,"blast_resistance":3000,"tool":0,"family":"ender_chest"},
	1181:{"name":"White shulker box","color":"e4e4d7","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1182:{"name":"Grey shulker box","color":"626c70","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1183:{"name":"Light grey shulker box","color":"b0b4ac","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1184:{"name":"Black shulker box","color":"333740","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1185:{"name":"Yellow shulker box","color":"edc647","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1186:{"name":"Orange shulker box","color":"e4943e","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1187:{"name":"Red shulker box","color":"b83d41","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1188:{"name":"Magenta shulker box","color":"b94baf","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1189:{"name":"Purple shulker box","color":"824aaa","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1190:{"name":"Blue shulker box","color":"4966ad","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1191:{"name":"Cyan shulker box","color":"378a99","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1192:{"name":"Lime shulker box","color":"8bbe45","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1193:{"name":"Green shulker box","color":"51763e","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1194:{"name":"Pink shulker box","color":"dd8eac","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1195:{"name":"Light blue shulker box","color":"79b4d2","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
	1196:{"name":"Brown shulker box","color":"79563e","block":true,"hardness":2,"blast_resistance":6,"tool":0,"stack":1,"family":"shulker"},
}

static func is_shulker(id: int) -> bool:
	return id >= SHULKER_BASE and id < SHULKER_BASE+16

static func is_storage(id: int) -> bool:
	return id == ENDER_CHEST or is_shulker(id)

static func clean_contents(value: Variant, allow_pouches: bool = true) -> Array:
	var result: Array = []
	for i in SIZE:
		result.append(Inventory.clean_slot(value[i] if value is Array and i < value.size() else {},allow_pouches,false))
	return result

static func new_ender_station(value: Variant = null) -> Dictionary:
	var saved: Array = value.get("slots",[]) if value is Dictionary and value.get("slots") is Array else []
	var result: Dictionary = {"kind":"ender","label":"Your Ender chest","slots":[]}
	for i in SIZE: result.slots.append(Inventory.clean_slot(saved[i] if i < saved.size() else {}))
	return result

static func station_from_item(slot: Dictionary) -> Dictionary:
	var metadata: Dictionary = slot.get("data",{})
	var saved_name: String = str(metadata.get("custom_name","")).left(64)
	var id: int = int(slot.get("id",SHULKER_PURPLE))
	return {"kind":"shulker","label":saved_name if not saved_name.is_empty() else DATA.get(id,DATA[SHULKER_PURPLE]).name,"slots":clean_contents(metadata.get("contents",[])),"item_data":{"custom_name":saved_name} if not saved_name.is_empty() else {}}

static func item_from_station(id: int, station: Dictionary) -> Dictionary:
	var metadata: Dictionary = {"contents":clean_contents(station.get("slots",[]))}
	var saved_name: String = str(station.get("item_data",{}).get("custom_name","")).left(64)
	if not saved_name.is_empty(): metadata["custom_name"] = saved_name
	return {"id":id,"count":1,"wear":0,"data":metadata}

static func has_cargo(slot: Dictionary) -> bool:
	for child in slot.get("data",{}).get("contents",[]):
		if child is Dictionary and int(child.get("id",0)) != 0 and int(child.get("count",0)) > 0: return true
	return false

# Voxey pouches can carry boxes and boxes can carry pouches, but neither may
# smuggle another copy of its own container kind through the other kind.
static func contains_kind(slot: Dictionary, shulker: bool, depth: int = 0) -> bool:
	if depth >= 8: return true
	var id: int = int(slot.get("id",0))
	if shulker and is_shulker(id): return true
	if not shulker and Pouches.is_pouch(id): return true
	var metadata: Variant = slot.get("data",{})
	if metadata is Dictionary and metadata.get("contents") is Array:
		for child in metadata.contents:
			if child is Dictionary and contains_kind(child,shulker,depth+1): return true
	return false

static func accepts(station: Dictionary, slot: Dictionary) -> bool:
	if int(slot.get("id",0)) == 0: return true
	if station.get("kind","") == "shulker": return not contains_kind(slot,true)
	if station.get("kind","") == "pouch": return not contains_kind(slot,false)
	return true

static func station(world: VoxelWorld, pos: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(pos)
	if not world.stations.has(key): world.stations[key] = station_from_item({"id":world.node_at(pos)})
	var result: Dictionary = world.stations[key]
	result["kind"] = "shulker"
	if not result.has("label"): result["label"] = DATA.get(world.node_at(pos),DATA[SHULKER_PURPLE]).name
	return result

static func interact(game: Node3D, pos: Vector3i) -> bool:
	var id: int = game.world.node_at(pos)
	if not is_storage(id): return false
	if id == ENDER_CHEST and not Nodes.transparent(game.world.node_at(pos+Vector3i.UP)):
		game.toast("Clear the space above the Ender chest to open it.")
		return true
	game.hud.return_cursor()
	game.state = "inventory"; game.world.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(game.controls): game.controls.hide_all()
	game.hud.container_page = 0
	game.hud.show_inventory("chest",game.ender_storage if id == ENDER_CHEST else station(game.world,pos))
	return true

# Called after placement succeeds, before the player's ordinary consumption.
static func placed(game: Node3D, pos: Vector3i, slot: Dictionary) -> void:
	if not is_shulker(int(slot.get("id",0))): return
	game.world.stations[VoxelWorld.station_key(pos)] = station_from_item(slot)
	if game.gamemode == "creative" and has_cargo(slot): game.inventory.consume_selected()

# Intercept both ordinary digging and explosions before generic container
# detachment: a box emits one packed item, never its individual cargo stacks.
static func break_node(game: Node3D, pos: Vector3i, id: int, tool: int, exploded: bool = false) -> bool:
	if not is_storage(id): return false
	if id == ENDER_CHEST and exploded: return true
	if game.world.node_at(pos) != id: return true
	var packed: Dictionary = item_from_station(id,station(game.world,pos)) if is_shulker(id) else {}
	if not game.world.set_node(pos,Nodes.AIR): return true
	game.world.stations.erase(VoxelWorld.station_key(pos))
	if is_shulker(id):
		if exploded or game.gamemode != "creative" or has_cargo(packed):
			game.spawn_drop(Vector3(pos)+Vector3.ONE*0.5,id,1,0,packed.data)
	elif game.gamemode != "creative" and Nodes.tool_kind(tool) == 0:
		var silk: bool = Inventory.enchantment(game.inventory.held(),"Silk Touch") > 0
		game.spawn_drop(Vector3(pos)+Vector3.ONE*0.5,ENDER_CHEST if silk else Nodes.OBSIDIAN,1 if silk else 8)
	game.remove_torch(pos)
	game.settle(pos+Vector3i.UP)
	game._break_particles(pos,id)
	game.sound("break")
	game.progress("gather")
	game.api.emit_node_broken(pos,id)
	return true

static func recipes(inv: Inventory) -> void:
	var obsidian: int = Nodes.OBSIDIAN
	inv._recipe("Ender chest",ENDER_CHEST,1,[obsidian,obsidian,obsidian,obsidian,Nodes.ENDER_EYE,obsidian,obsidian,obsidian,obsidian],3,"table")
	inv._recipe("Purple shulker box",SHULKER_PURPLE,1,[Nodes.SHULKER_SHELL,Nodes.CHEST,Nodes.SHULKER_SHELL],1,"table")
	for color in 16:
		inv._shapeless(DATA[SHULKER_BASE+color].name,SHULKER_BASE+color,1,[SHULKER_PURPLE,VillageContent.DYE_WHITE+color])

static func special_recipe(cells: Array) -> Dictionary:
	var inputs: Array = []
	for slot in cells:
		if int(slot.get("id",0)) != 0: inputs.append(int(slot.id))
	if inputs.size() != 2: return {}
	if not is_shulker(inputs[0]): inputs.reverse()
	if not is_shulker(inputs[0]) or inputs[1] < VillageContent.DYE_WHITE or inputs[1] > VillageContent.DYE_BROWN: return {}
	var id: int = SHULKER_BASE+inputs[1]-VillageContent.DYE_WHITE
	return {"name":DATA[id].name,"id":id,"count":1,"pattern":inputs,"width":2,"ingredients":{inputs[0]:1,inputs[1]:1},"station":"hand","shapeless":true,"dynamic":true}

static func output_data(id: int, ingredients: Array) -> Dictionary:
	if not is_shulker(id): return {}
	for ingredient in ingredients:
		if is_shulker(int(ingredient.get("id",0))):
			return item_from_station(id,station_from_item(ingredient)).data
	return {}

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(DATA[id].color)
	if id == ENDER_CHEST:
		if x in [7,8] and y in range(6,11): return Color("c0b765")
		if y in [5,6] or x in [0,15] or y in [0,15]: return base.darkened(0.55)
		if (x*7+y*11)%37 == 0: return Color("8167a4")
		return noise
	if y in [6,7]: return base.darkened(0.55)
	if x in [1,14] or y in [1,14]: return base.darkened(0.22)
	if y == 5 or y == 13: return base.lightened(0.12)
	return noise

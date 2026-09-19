class_name DenseMaterials
extends RefCounted

# Source: Mineclonia mcl_core nodes_base.lua/nodes_misc.lua/functions.lua.
# Textures are original procedural Voxey artwork.
const PACKED_ICE = 7400
const BLUE_ICE = 7401
const BONE = 7402
const BONE_X = 7403
const BONE_Z = 7404
const BONE_END = 7405 # Hidden atlas-only end-grain tile, never an item.
const BLOCKS = [PACKED_ICE,BLUE_ICE,BONE,BONE_X,BONE_Z,BONE_END]
const DATA = {
	7400:{"name":"Packed ice","block":true,"color":"9cbedf","hardness":0.5,"tool":0,"drop":0,"source_node":"mcl_core:packed_ice"},
	7401:{"name":"Blue ice","block":true,"color":"739cde","hardness":2.8,"tool":0,"drop":0,"source_node":"mcl_core:blue_ice"},
	7402:{"name":"Bone block","block":true,"color":"e6e1c9","hardness":2.0,"tool":0,"drop":7402,"source_node":"mcl_core:bone_block","note_material":"stone"},
	7403:{"name":"Bone block","block":true,"color":"e6e1c9","hardness":2.0,"tool":0,"drop":7402,"source_node":"mcl_core:bone_block","note_material":"stone","hidden":true},
	7404:{"name":"Bone block","block":true,"color":"e6e1c9","hardness":2.0,"tool":0,"drop":7402,"source_node":"mcl_core:bone_block","note_material":"stone","hidden":true},
	7405:{"name":"Bone end texture","color":"e6e1c9","hidden":true},
}

static func is_material(id: int) -> bool: return id >= PACKED_ICE and id <= BONE_Z
static func is_bone(id: int) -> bool: return id >= BONE and id <= BONE_Z
static func is_ice(id: int) -> bool: return id in [Nodes.ICE,VillageContent.FROSTED_ICE,PACKED_ICE,BLUE_ICE]
static func item(id: int) -> int: return BONE if is_bone(id) else id
static func axis(id: int) -> int: return 0 if id == BONE_X else (2 if id == BONE_Z else 1)
static func oriented(id: int, normal: Vector3i) -> int:
	if not is_bone(id): return id
	return BONE_X if normal.x != 0 else (BONE_Z if normal.z != 0 else BONE)
static func end_tile(id: int, face: int) -> bool: return is_bone(id) and face/2 == axis(id)
static func slippery(id: int) -> int: return 4 if id == BLUE_ICE else (3 if is_ice(id) else 0)
static func acceleration(id: int, idle: bool = false) -> float:
	# Luanti LocalPlayer::getSlipFactor doubles slipperiness without movement
	# input, making an already moving player coast farther after releasing keys.
	return 35.0/(1+slippery(id)*(2 if idle else 1))

static func recipes(inv: Inventory) -> void:
	inv._recipe("Packed ice",PACKED_ICE,1,[Nodes.ICE,Nodes.ICE,Nodes.ICE,Nodes.ICE,Nodes.ICE,Nodes.ICE,Nodes.ICE,Nodes.ICE,Nodes.ICE],3,"table")
	inv._recipe("Blue ice",BLUE_ICE,1,[PACKED_ICE,PACKED_ICE,PACKED_ICE,PACKED_ICE,PACKED_ICE,PACKED_ICE,PACKED_ICE,PACKED_ICE,PACKED_ICE],3,"table")
	inv._recipe("Bone block",BONE,1,[Nodes.BONE_MEAL,Nodes.BONE_MEAL,Nodes.BONE_MEAL,Nodes.BONE_MEAL,Nodes.BONE_MEAL,Nodes.BONE_MEAL,Nodes.BONE_MEAL,Nodes.BONE_MEAL,Nodes.BONE_MEAL],3,"table")
	inv._recipe("Bone meal from bone block",Nodes.BONE_MEAL,9,[BONE],1)

static func harvest(id: int, slot: Dictionary) -> Array:
	if is_bone(id): return [[BONE,1]] if Nodes.tool_kind(int(slot.get("id",0))) == 0 else []
	if id in [Nodes.ICE,PACKED_ICE,BLUE_ICE] and Nodes.is_tool_id(int(slot.get("id",0))) and Inventory.enchantment(slot,"Silk Touch") > 0: return [[id,1]]
	return []

static func ice_replacement(world: VoxelWorld, p: Vector3i, id: int) -> int:
	# The local source's after_dig callback is unconditional, even with Silk
	# Touch or creative digging. Compressed ice has no such callback.
	if id != Nodes.ICE or world.generator.dimension == "nether": return Nodes.AIR
	var below: Vector3i = p+Vector3i.DOWN
	return Nodes.WATER if world.loaded_at(Vector3(below)) and below.y >= world.generator.min_y() and world.node_at(below) != Nodes.AIR else Nodes.AIR

static func break_ice(game: Node3D, p: Vector3i, id: int, _tool: int) -> bool:
	if id not in [Nodes.ICE,PACKED_ICE,BLUE_ICE]: return false
	if not game.world.set_node(p,ice_replacement(game.world,p,id)): return true
	if game.gamemode != "creative":
		for entry in harvest(id,game.inventory.held()): game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
	var above: Vector3i = p+Vector3i.UP
	var upper: int = game.world.node_at(above)
	if Nodes.plant(upper) or upper == Nodes.TORCH or upper in Nodes.SMALL_CIRCUITS and upper != Nodes.IRON_DOOR_OPEN: game.break_node(above,upper,_tool)
	for direction in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.DOWN,Vector3i.UP,Vector3i.FORWARD,Vector3i.BACK]: game.settle(p+direction)
	game._break_particles(p,id); game.sound("break"); game.progress("gather"); game.api.emit_node_broken(p,id)
	return true

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if id == BONE_END: return end_pixel(x,y,noise)
	if is_bone(id):
		if x in [2,7,12] and posmod(y+x*3,11) < 7: return Color("c9c2a5")
		if x in [3,8,13] and posmod(y+x*3,11) < 7: return Color("eee9d3")
		return noise.lerp(Color("e6e1c9"),0.7)
	var blue: bool = id == BLUE_ICE
	var base := Color("739cde") if blue else Color("9cbedf")
	if posmod(x*3+y*2,23) < 2 or (x+y in [9,22] and x%4 != 0): return base.lightened(0.27)
	if posmod(x*2-y,19) == 0: return base.darkened(0.13)
	return noise.lerp(base,0.72)

static func end_pixel(x: int, y: int, noise: Color) -> Color:
	var ring: int = maxi(absi(x-7),absi(y-7))
	if ring in [3,6] and posmod(x+y*3,5) != 0: return Color("c8c1a3")
	if Vector2(x-7.5,y-7.5).length() < 1.8: return Color("b8b094")
	return noise.lerp(Color("eee9d3"),0.8)

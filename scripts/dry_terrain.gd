class_name DryTerrain
extends RefCounted

# mcl_core/nodes_base.lua, nodes_misc.lua and crafting.lua, GPL-3.0-or-later.
const COARSE_DIRT = 13600
const DEAD_BUSH = 13601
const DATA = {
	13600:{"name":"Coarse dirt","color":"866345","block":true,"hardness":0.5,"tool":2,"blast_resistance":0.5},
	13601:{"name":"Dead bush","color":"9f784f","block":true,"shape":"plant","hardness":0.0,"tool":-1,"flammable":true},
}

static func recipes(inv: Inventory) -> void:
	inv._recipe("Coarse dirt",COARSE_DIRT,4,[Nodes.DIRT,Nodes.GRAVEL,Nodes.GRAVEL,Nodes.DIRT],2)
	inv._recipe("Coarse dirt",COARSE_DIRT,4,[Nodes.GRAVEL,Nodes.DIRT,Nodes.DIRT,Nodes.GRAVEL],2)

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or int(target.id) != COARSE_DIRT: return false
	var kind: int = Nodes.tool_kind(int(game.inventory.held().id))
	if kind not in [2,4]: return false
	var p: Vector3i = target.pos
	if not game.world.loaded_at(Vector3(p+Vector3i.UP)) or game.world.node_at(p+Vector3i.UP) != Nodes.AIR: return true
	if kind == 2 and target.get("normal",Vector3i.UP).y < 0: return true
	if game.world.set_node(p,Nodes.DIRT if kind == 4 else VillageContent.PATH):
		if game.gamemode != "creative": ToolCapabilities.action_wear(game.inventory)
		game.sound("dig"); game.player.swing = 1
	return true

static func changed(world: VoxelWorld, p: Vector3i) -> void:
	if PistonPush.defer_support(world,p): return
	var above: Vector3i = p+Vector3i.UP
	if world.node_at(above) == DEAD_BUSH and not Nodes.solid(world.node_at(p)):
		world.set_node(above,Nodes.AIR)
		for item in harvest({"id":0}): world.get_parent().spawn_drop(Vector3(above)+Vector3.ONE*0.5,item[0],item[1])

static func boxes() -> Array:
	return [AABB(Vector3(3.0/16,0,3.0/16),Vector3(10.0/16,9.0/16,10.0/16))]

static func harvest(slot: Dictionary, rng: RandomNumberGenerator = null) -> Array:
	if int(slot.get("id",0)) == Nodes.SHEARS: return [[DEAD_BUSH,1]]
	if rng == null: rng = RandomNumberGenerator.new(); rng.randomize()
	if rng.randi_range(1,3) == 1: return [[Nodes.STICK,2]]
	if rng.randi_range(1,2) == 1: return [[Nodes.STICK,1]]
	return []

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if id == COARSE_DIRT:
		return noise.lightened(0.23) if (x*7+y*11+x*y)%13 < 3 else noise
	var branch: bool = x in [7,8] and y >= 6
	branch = branch or (y in [6,7] and x in [4,5,6,9,10,11]) or (x in [4,11] and y in [3,4,5,6])
	branch = branch or (y in [10,11] and x in [2,3,4,5,6,9,10,11,12,13]) or (x in [2,13] and y in [8,9])
	return noise if branch else Color.TRANSPARENT

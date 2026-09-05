class_name VoxeyAPI
extends RefCounted

## The modding API surface handed to every mod. One instance per mod; `owner`
## identifies the mod in log lines and hook events. All gameplay access goes
## through the narrow, documented methods below — mods never touch the scene
## tree, the file system, or engine internals directly.

var owner: String = ""
var game: Node3D
const Mods = preload("res://scripts/voxey_mods.gd")

func _init(mod_name: String, game_ref: Node3D) -> void:
	owner = mod_name
	game = game_ref

# ---------------------------------------------------------------- nodes/items

## Register a new voxel node type. Returns the numeric node id, or 0 if the
## name is taken or the custom-node limit (22) is reached.
## Properties: color "#rrggbb", transparent (bool, non-solid), hardness
## (seconds by hand), unobtainable (bool, hidden from catalog).
func register_node(node_name: String, properties: Dictionary = {}) -> int:
	return Nodes.register_node(node_name, properties)

## Register a new inventory item (not placeable). Returns its id, or 0 on
## failure. Properties: color "#rrggbb", food (heal amount 0..20), tool
## (Dictionary with kind 0-4 and tier 0-3 to behave as a tool).
func register_item(item_name: String, properties: Dictionary = {}) -> int:
	return Nodes.register_item(item_name, properties)

# ---------------------------------------------------------------- world

## The node id at a world position, or Nodes.AIR when unloaded.
func get_node(pos: Vector3i) -> int:
	return game.world.node_at(pos)

## Change a node. Returns false when the position is out of range or unloaded.
func set_node(pos: Vector3i, id: int) -> bool:
	if not game.world.set_node(pos,id): return false
	game.settle(pos+Vector3i.UP)
	return true

## Find the first position along a ray whose node matches `wanted`, within
## `reach` nodes of `origin`. Returns Vector3i(999999,999999,999999) if none.
func find_node(origin: Vector3, wanted: int, reach: float = 24.0) -> Vector3i:
	for step in int(reach*2.0):
		var pos := Vector3i((origin+Vector3(step,0,0)).floor())
		for dx in range(-int(reach),int(reach)+1):
			var candidate := pos+Vector3i(0,0,dx)
			for y in range(-int(reach),int(reach)+1):
				var p := candidate+Vector3i(0,y,0)
				if game.world.node_at(p) == wanted: return p
	return Vector3i(999999,999999,999999)

## Every loaded player position (single player for now).
func player_position() -> Vector3:
	return game.player.position

## Teleport the player. Streams the destination in first when far away.
func teleport_player(destination: Vector3) -> void:
	game.teleport(destination)

## Spawn an item pickup at a position.
func spawn_drop(pos: Vector3, id: int, amount: int = 1) -> void:
	game.spawn_drop(pos,id,amount)

## Spawn a creature by kind name; returns null for unknown kinds.
func spawn_creature(kind: String, pos: Vector3) -> Creature:
	return game.spawn_creature(kind,pos)

# ---------------------------------------------------------------- inventory

## Count how many of an item the player carries.
func count_item(id: int) -> int:
	return game.inventory.count_item(id)

## Give items to the player; leftovers become world drops. Returns the count
## actually added to the bag.
func give_item(id: int, amount: int = 1) -> int:
	var rest: int = game.inventory.add_item(id,amount)
	return amount-rest

## Remove items from the player's bag. Returns true when all were taken.
func take_item(id: int, amount: int = 1) -> bool:
	return game.inventory.remove_item(id,amount)

# ---------------------------------------------------------------- presentation

## Show a toast message attributed to this mod.
func toast(message: String) -> void:
	game.toast("[%s] %s" % [owner,message])

## Play a named sound globally ("step", "break", "craft", …).
func sound(kind: String) -> void:
	game.sound(kind)

## Add a chat/console line.
func log_line(message: String) -> void:
	game.console_messages.append("[%s] %s" % [owner,message])
	while game.console_messages.size()>60: game.console_messages.pop_front()

# ---------------------------------------------------------------- hooks

## Subscribe one of this mod's callables to a gameplay hook
## ("on_node_broken", "on_node_placed", "on_player_hurt", "on_player_died",
## "on_creature_killed", "on_world_entered"). Returns false for unknown
## hooks or when the subscriber cap (8 per hook) is reached.
func connect_hook(hook: String, callback: Callable) -> bool:
	return Mods.connect_hook(hook,callback)

# ---------------------------------------------------------------- hook emitters (engine-side)

## Fire the "on_player_hurt" hook. `amount` is post-armor damage.
func emit_player_hurt(amount: float, source: String) -> void:
	Mods.fire("on_player_hurt",[amount,source])

## Fire the "on_node_broken" hook after a node is removed.
func emit_node_broken(pos: Vector3i, id: int) -> void:
	Mods.fire("on_node_broken",[pos,id])

## Fire the "on_node_placed" hook after a node appears.
func emit_node_placed(pos: Vector3i, id: int) -> void:
	Mods.fire("on_node_placed",[pos,id])

## Fire the "on_player_died" hook.
func emit_player_died() -> void:
	Mods.fire("on_player_died",[])
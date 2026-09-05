# Example Voxey mod. See docs/modding/getting-started.md for the full guide.
extends RefCounted

var api: VoxeyAPI
var lantern: int = 0
var berries: int = 0

func _api_ready(a: VoxeyAPI) -> void:
	api = a
	lantern = api.register_node("Copper lantern", {"color": "#c98a3d", "hardness": 1.2})
	berries = api.register_item("Sweet berries", {"color": "#b83a4a", "food": 3})
	api.connect_hook("on_world_entered", _on_world_entered)
	api.connect_hook("on_node_placed", _on_node_placed)
	api.connect_hook("on_player_died", _on_player_died)

func _on_world_entered(world_name: String, _seed: int) -> void:
	api.toast("survival_tweaks active: look for lanterns in the creative catalog.")

func _on_node_placed(pos: Vector3i, id: int) -> void:
	if id == lantern:
		api.sound("place")
		api.log_line("A copper lantern glows warmly at %s." % [pos])

func _on_player_died() -> void:
	api.log_line("The lanterns keep the night at bay without you.")
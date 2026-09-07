class_name PlayerProfiles
extends RefCounted

var path: String
var entries: Dictionary = {}
var active_id: String = ""

func _init(root_path: String) -> void:
	path = root_path.path_join("players.json")
	var saved: Dictionary = WorldStore.read_json(path)
	if saved.get("players") is Dictionary:
		for id in saved.players:
			if id is String and WorldStore.valid_id(id) and saved.players[id] is String: entries[id] = String(saved.players[id]).left(32)
	active_id = str(saved.get("active",""))
	if entries.is_empty(): create("Player")
	elif not entries.has(active_id): active_id = entries.keys()[0]; save()

func save() -> bool:
	return WorldStore.write_json(path,{"active":active_id,"players":entries})

func create(display_name: String) -> String:
	var name_text: String = display_name.strip_edges().left(32)
	if name_text.is_empty(): return ""
	var id: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var previous: String = active_id
	entries[id] = name_text; active_id = id
	if not save(): entries.erase(id); active_id = previous; return ""
	return id

func select(id: String) -> bool:
	if not entries.has(id): return false
	var previous: String = active_id; active_id = id
	if not save(): active_id = previous; return false
	return true

func rename(id: String, display_name: String) -> bool:
	if not entries.has(id) or display_name.strip_edges().is_empty(): return false
	var old: String = entries[id]; entries[id] = display_name.strip_edges().left(32)
	if not save(): entries[id] = old; return false
	return true

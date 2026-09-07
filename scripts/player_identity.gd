class_name PlayerIdentity
extends RefCounted

const OFFLINE = "player"
# The session owns identity; offline play always starts with this stable name.
# A future authenticated multiplayer session can supply its own stable key.
var session_id: String = OFFLINE
var legacy_offline_id: String = ""

func _init(root_path: String) -> void:
	# Read the removed selector's active identity only to preserve saved homes
	# and reputation. Do not create or modify a local profile registry.
	var previous: Dictionary = WorldStore.read_json(root_path.path_join("players.json"))
	var old_id: String = str(previous.get("active",""))
	if previous.get("players") is Dictionary and previous.players.has(old_id): legacy_offline_id = old_id

func migrate_save(value) -> void:
	if legacy_offline_id.is_empty() or legacy_offline_id == OFFLINE: return
	if value is Array:
		for child in value: migrate_save(child)
	elif value is Dictionary:
		for field in ["homes","reputations"]:
			if value.get(field) is Dictionary and value[field].has(legacy_offline_id) and not value[field].has(OFFLINE):
				value[field][OFFLINE] = value[field][legacy_offline_id]
		if value.get("owner","") == legacy_offline_id:
			value.owner = OFFLINE
			if str(value.get("label","")).begins_with("Recovery chest · "): value.label = "Recovery chest · player"
		for child in value.values(): migrate_save(child)

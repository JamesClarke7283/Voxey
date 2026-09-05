class_name WorldStore
extends RefCounted

var root_path: String
var worlds_path: String
var error_message: String = ""

func _init() -> void:
	var override: String = OS.get_environment("VOXEY_DATA_DIR")
	var home: String = home_from_environment(OS.get_name(),{
		"HOME":OS.get_environment("HOME"),"USERPROFILE":OS.get_environment("USERPROFILE"),
		"HOMEDRIVE":OS.get_environment("HOMEDRIVE"),"HOMEPATH":OS.get_environment("HOMEPATH")})
	# Sandboxed mobile/web targets may not expose a home directory. Their writable
	# app directory is the platform equivalent. Desktop always uses ~/.voxey.
	if home.is_empty(): home = OS.get_user_data_dir()
	root_path = override if not override.is_empty() else home.path_join(".voxey")
	worlds_path = root_path.path_join("worlds")
	if DirAccess.make_dir_recursive_absolute(worlds_path) != OK:
		error_message = "Voxey couldn't create its saves folder: "+worlds_path

static func home_from_environment(platform: String, env: Dictionary) -> String:
	if platform == "Windows":
		if not String(env.get("USERPROFILE","")).is_empty(): return String(env.USERPROFILE).replace("\\","/")
		if not String(env.get("HOMEPATH","")).is_empty(): return (String(env.get("HOMEDRIVE",""))+String(env.HOMEPATH)).replace("\\","/")
	return String(env.get("HOME",""))

static func valid_id(id: String) -> bool:
	if id.is_empty() or id.length()>100: return false
	for character in id:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_-": return false
	return true

func world_path(id: String) -> String:
	return worlds_path.path_join(id) if valid_id(id) else ""

func save_path(id: String) -> String:
	var path: String = world_path(id)
	return path.path_join("save.json") if not path.is_empty() else ""

func create_world(display_name: String, seed_value: int, mode: String) -> String:
	var slug: String = ""
	for character in display_name.to_lower().left(32):
		slug += character if character in "abcdefghijklmnopqrstuvwxyz0123456789" else "-"
	slug = slug.strip_edges().trim_prefix("-").trim_suffix("-")
	if slug.is_empty(): slug = "world"
	var id: String = slug+"-"+str(int(Time.get_unix_time_from_system()))+"-"+str(randi()%100000)
	if DirAccess.make_dir_recursive_absolute(world_path(id)) != OK: return ""
	var metadata: Dictionary = {"id":id,"name":display_name.strip_edges().left(64) if not display_name.strip_edges().is_empty() else "New world","seed":seed_value,"mode":mode,"day":1,"updated":int(Time.get_unix_time_from_system())}
	if not write_json(world_path(id).path_join("world.json"),metadata): return ""
	return id

func list_worlds() -> Array:
	var entries: Array = []
	for id in DirAccess.get_directories_at(worlds_path):
		if not valid_id(id): continue
		var path: String = world_path(id)
		var metadata: Dictionary = read_json(path.path_join("world.json"))
		if metadata.is_empty(): continue
		metadata.id = id
		metadata.playable = FileAccess.file_exists(path.path_join("save.json")) or FileAccess.file_exists(path.path_join("save.json.bak"))
		entries.append(metadata)
	entries.sort_custom(func(a: Dictionary,b: Dictionary): return float(a.get("updated",0))>float(b.get("updated",0)))
	return entries

func update_metadata(id: String, display_name: String, seed_value: int, mode: String, day: int) -> void:
	if not valid_id(id): return
	write_json(world_path(id).path_join("world.json"),{"id":id,"name":display_name,"seed":seed_value,"mode":mode,"day":day,"updated":int(Time.get_unix_time_from_system())})

static func read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary: return {}
	return json.data

static func write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	return DirAccess.rename_absolute(path+".tmp",path) == OK

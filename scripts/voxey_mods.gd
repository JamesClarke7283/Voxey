class_name VoxeyMods
extends RefCounted

## Mod loader and hook dispatcher. Mods live in `mods/<mod_name>/mod.json`
## next to the project (or `~/.voxey/mods`), describing themselves as:
##
##   { "name": "my_mod", "version": "1.0.0", "entry": "main.gd" }
##
## The entry script must define `_api_ready(api: VoxeyAPI)`. Mods can also
## subscribe to gameplay hooks: `api.connect_hook("on_node_broken", func)`.
## A mod that fails to load is disabled with an error logged — it never
## prevents the game from starting. Mods cannot touch the file system or the
## scene tree; the API surface is the only bridge.

const HOOKS = ["on_node_broken","on_node_placed","on_player_hurt","on_player_died","on_creature_killed","on_world_entered"]
const ApiScript = preload("res://scripts/voxey_api.gd")

static var loaded: Array = []          # [{name, version, path, api, error}]
static var hooks := {}                 # hook name -> Array of Callables
static var hook_limits := {}           # per-second call guard per hook
static var _fired := {}                # last fire timestamp per hook

static func reset() -> void:
	loaded = []
	hooks = {}
	hook_limits = {}
	_fired = {}

## Discover, load, and initialize every mod. Returns the number loaded.
static func load_all(game_ref: Node3D, roots: Array) -> int:
	reset()
	for root_path in roots:
		if not DirAccess.dir_exists_absolute(root_path): continue
		for dir in DirAccess.get_directories_at(root_path):
			_load_mod(root_path.path_join(dir),dir,game_ref)
	return loaded.size()

static func _load_mod(folder: String, mod_name: String, game_ref: Node3D) -> void:
	var manifest: Dictionary = _read_json(folder.path_join("mod.json"))
	if manifest.is_empty():
		loaded.append({"name":mod_name,"error":"missing or invalid mod.json"})
		return
	var entry: String = String(manifest.get("entry","main.gd"))
	var script_path: String = folder.path_join(entry)
	if not FileAccess.file_exists(script_path):
		loaded.append({"name":String(manifest.get("name",mod_name)),"error":"entry script not found: "+entry})
		return
	var script: GDScript = load(script_path)
	if script == null:
		loaded.append({"name":String(manifest.get("name",mod_name)),"error":"entry script failed to compile"})
		return
	var api: RefCounted = ApiScript.new(String(manifest.get("name",mod_name)),game_ref)
	var instance: RefCounted = script.new()
	if instance == null or not instance.has_method("_api_ready"):
		loaded.append({"name":api.owner,"error":"entry script lacks _api_ready(api)"})
		return
	loaded.append({"name":api.owner,"version":String(manifest.get("version","")),"path":folder,"api":api,"instance":instance})
	instance.call("_api_ready",api)

## Subscribe a callable to a hook. Unknown hooks are rejected with false.
static func connect_hook(hook: String, callback: Callable) -> bool:
	if not hook in HOOKS: return false
	if not hooks.has(hook): hooks[hook] = []
	if hooks[hook].size() >= 8: return false
	hooks[hook].append(callback)
	return true

## Fire a hook with a bounded argument list. Guards: unknown hook, no
## subscribers, and a 5-fire-per-second per-hook flood limit.
static func fire(hook: String, args: Array) -> void:
	if not hooks.has(hook) or hooks[hook].is_empty(): return
	var now: int = Time.get_ticks_msec()
	var stamps: Array = _fired.get(hook,[])
	stamps = stamps.filter(func(t): return now-int(t) < 1000)
	if stamps.size() >= 5: return
	stamps.append(now)
	_fired[hook] = stamps
	for callback in hooks[hook].duplicate():
		callback.callv(args)

static func is_loaded(mod_name: String) -> bool:
	for entry in loaded:
		if entry.name == mod_name and not entry.has("error"): return true
	return false

static func mod_names() -> Array:
	var names: Array = []
	for entry in loaded:
		if not entry.has("error"): names.append(entry.name)
	return names

static func errors() -> Array:
	var problems: Array = []
	for entry in loaded:
		if entry.has("error"): problems.append(entry)
	return problems

static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary: return {}
	return json.data
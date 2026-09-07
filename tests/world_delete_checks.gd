extends RefCounted
static func button(parent: Node, text_value: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == text_value: return child
		var found: Button = button(child,text_value)
		if found != null: return found
	return null
static func run(suite: SceneTree, game: Node3D) -> void:
	var store: WorldStore = game.saves
	var first: String = store.create_world("Delete this world",17,"survival")
	var kept: String = store.create_world("Keep this world",18,"creative")
	var path: String = store.world_path(first)
	WorldStore.write_json(store.save_path(first),{"inventory":[{"id":Nodes.DIAMOND,"count":20}]})
	WorldStore.write_json(store.save_path(first)+".bak",{"backup":true})
	DirAccess.make_dir_recursive_absolute(path.path_join("dimensions/nether"))
	WorldStore.write_json(path.path_join("dimensions/nether/chunk.json"),{"blocks":[1,2,3]})
	WorldStore.write_json(path.path_join(".hidden.json"),{"hidden":true})
	var outside: String = store.root_path.path_join("external-mod-data")
	DirAccess.make_dir_recursive_absolute(outside)
	WorldStore.write_json(outside.path_join("keep.json"),{"keep":true})
	var directory := DirAccess.open(path)
	var linked: bool = directory.create_link(outside,"mod-link") == OK
	WorldStore.write_json(store.root_path.path_join("legacy_imported.json"),{"world":first})
	game.state = "paused"
	suite.check(not game.delete_world(first) and DirAccess.dir_exists_absolute(path),"a running world cannot be deleted")
	game.state = "title"
	game.hud.show_worlds()
	game.hud._world_details({"id":first,"name":"Delete this world","mode":"survival"})
	var delete: Button = button(game.hud.layer,"Delete…")
	suite.check(delete != null,"selected world exposes a Delete button")
	delete.pressed.emit()
	suite.check(game.hud.screen == "delete_world" and DirAccess.dir_exists_absolute(path),"Delete opens confirmation without removing any files")
	var cancel: Button = button(game.hud.layer,"Cancel")
	suite.check(cancel.has_focus(),"confirmation initially focuses Cancel")
	cancel.pressed.emit()
	suite.check(game.hud.screen == "worlds" and DirAccess.dir_exists_absolute(path),"Cancel keeps the world and returns to the list")
	game.hud.show_delete_world({"id":first,"name":"Delete this world"})
	var escape := InputEventKey.new(); escape.physical_keycode = KEY_ESCAPE; escape.pressed = true
	game._input(escape)
	suite.check(game.hud.screen == "worlds" and DirAccess.dir_exists_absolute(path),"Escape cancels world deletion")
	game.active_world_id = first
	game.hud.show_delete_world({"id":first,"name":"Delete this world"})
	button(game.hud.layer,"Delete world").pressed.emit()
	suite.check(not DirAccess.dir_exists_absolute(path) and game.hud.screen == "worlds" and game.active_world_id.is_empty(),"confirmation deletes the selected world, nested dimensions, hidden data and backups")
	suite.check(DirAccess.dir_exists_absolute(store.world_path(kept)),"deleting one world preserves all other worlds")
	if linked: suite.check(FileAccess.file_exists(outside.path_join("keep.json")),"world deletion removes symlinks without following them into external data")
	suite.check(WorldStore.read_json(store.root_path.path_join("legacy_imported.json")).get("deleted",false),"deleting an imported world prevents it from being imported again")
	suite.check(not store.delete_world("../external-mod-data") and FileAccess.file_exists(outside.path_join("keep.json")),"invalid world IDs cannot delete outside the selected world")
	suite.check(not store.delete_world(first),"already deleted worlds fail cleanly")

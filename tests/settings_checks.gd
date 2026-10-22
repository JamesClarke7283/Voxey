extends RefCounted
static func run(t: SceneTree, game: Node3D) -> void:
	var old: Dictionary = game.network.settings_snapshot()
	t.check(GameRules.apply_settings(game,{"name":"Local settings test","gamemode":"creative","difficulty":2,"day_time":0.65,"rules":{"keepInventory":true,"signsEditable":true,"mobGriefing":false}}),"local game settings can be changed without a server")
	t.check(game.gamemode == "creative" and game.difficulty == 2 and game.game_rules.keepInventory and not game.game_rules.mobGriefing,"game settings apply mode, difficulty, and game rules")
	var saved: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	t.check(saved.get("difficulty") == 2 and saved.get("gamerules",{}).get("keepInventory",false),"difficulty and rules persist with the world")
	game.hud.show_world_settings()
	t.check(game.hud.screen == "world_settings","local Escape menu exposes game settings")
	game.hud.show_game(); game.hud.show_player_list(true)
	t.check(game.hud.player_list_open and is_instance_valid(game.hud.player_list_panel),"Tab player list works in local play")
	game.hud.show_player_list(false)
	t.check(not game.hud.player_list_open,"releasing Tab hides the player list")
	GameRules.apply_settings(game,old)

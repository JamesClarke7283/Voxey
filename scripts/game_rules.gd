class_name GameRules
extends RefCounted

const DEFAULTS = {"keepInventory":false,"signsEditable":false,"mobGriefing":true}

static func restore(value: Variant) -> Dictionary:
	var rules: Dictionary = DEFAULTS.duplicate()
	if value is Dictionary:
		for key in DEFAULTS:
			if value.get(key) is bool: rules[key] = value[key]
	return rules

static func command(game: Node, parts: PackedStringArray) -> String:
	if parts.size() == 1: return "Game rules: "+", ".join(DEFAULTS.keys())+". Use /gamerule <rule> [true | false]."
	var key: String = ""
	for name in DEFAULTS:
		if name.to_lower() == parts[1].to_lower(): key = name
	if key.is_empty(): return "Unknown game rule. Available: "+", ".join(DEFAULTS.keys())+"."
	if parts.size() == 2: return "%s = %s"%[key,str(game.game_rules[key])]
	if parts.size() != 3 or parts[2].to_lower() not in ["true","false"]: return "Usage: /gamerule %s [true | false]"%key
	if game.get("network") != null and game.network.client(): return "Only the host can change game rules."
	game.game_rules[key] = parts[2].to_lower() == "true"
	if game.get("network") != null: game.network.publish_settings()
	return "%s set to %s for this world."%[key,str(game.game_rules[key])]

static func apply_settings(game: Node3D, value: Dictionary) -> bool:
	if game.network != null and game.network.client(): return false
	var title: String = str(value.get("name",game.world_name)).strip_edges().left(64)
	if not title.is_empty(): game.world_name = title
	game.gamemode = "creative" if value.get("gamemode",game.gamemode) == "creative" else "survival"
	game.difficulty = clampi(int(value.get("difficulty",game.difficulty)),0,2)
	game.game_rules = restore(value.get("rules",game.game_rules))
	game.day_time = floorf(game.day_time)+clampf(float(value.get("day_time",fposmod(game.day_time,1))),0,0.9999)
	if game.network != null:
		game.network.player_limit = clampi(int(value.get("max_players",game.network.player_limit)),1,VoxeyNetwork.MAX_PLAYERS)
		game.network.publish_settings()
	game.save_game()
	return true

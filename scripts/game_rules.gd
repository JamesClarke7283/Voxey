class_name GameRules
extends RefCounted

const DEFAULTS = {"keepInventory":false}

static func restore(value: Variant) -> Dictionary:
	var rules: Dictionary = DEFAULTS.duplicate()
	if value is Dictionary:
		for key in DEFAULTS:
			if value.get(key) is bool: rules[key] = value[key]
	return rules

static func command(game: Node, parts: PackedStringArray) -> String:
	if parts.size() == 1: return "Game rules: keepInventory. Use /gamerule keepInventory [true | false]."
	var key: String = ""
	for name in DEFAULTS:
		if name.to_lower() == parts[1].to_lower(): key = name
	if key.is_empty(): return "Unknown game rule. Available: keepInventory."
	if parts.size() == 2: return "%s = %s"%[key,str(game.game_rules[key])]
	if parts.size() != 3 or parts[2].to_lower() not in ["true","false"]: return "Usage: /gamerule %s [true | false]"%key
	game.game_rules[key] = parts[2].to_lower() == "true"
	return "%s set to %s for this world."%[key,str(game.game_rules[key])]

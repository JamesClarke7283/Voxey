class_name CommandBlocks
extends RefCounted

# Mineclonia ITEMS/REDSTONE/mcl_commandblock/init.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# The command block is the last missing node of the source's redstone set. Voxey had
# a chat console (`game.gd`'s `execute_command`) but no command-block node, so the
# source's `mcl_commandblock` module had no counterpart.
#
# The source's behaviour, reproduced here:
#
#   * A rising redstone edge runs the command list once. The source keeps two nodes
#     (`commandblock_off` / `commandblock_on`) and swaps between them so the swap itself
#     marks the edge; Voxey keeps one node and tracks the edge through the circuit's own
#     `powered` flag, which is the same state without a swap that would wipe it.
#   * One command per line, top to bottom, without the leading slash.
#   * **Placeholders**: `@c` is the commander, `@p`/`@n` the nearest player, `@f` the
#     farthest, `@r` a random player, and `@@` a literal `@`. The source substitutes a
#     non-printable sentinel for `@@` first so the other substitutions cannot eat it.
#   * The **commander** is the player who placed the block, and the commands run as
#     that player. Here that identity is `game.player_id`. Voxey's console commands
#     already act on the player, so unlike the source's they take no player argument;
#     the player placeholders are still resolved in the source's order for a list that
#     uses them, and `@c` names the commander.
#   * Editing needs Creative mode, and the source also demands the `maphack` privilege;
#     Voxey has a single player and no privilege system, so the Creative gate is the
#     whole condition.

# The single node id. The source's two-node pair exists only to record the pulse;
# `powered` records it here.
const ID = 11602

const DATA = {
	11602:{"name":"Command block","block":true,"color":"9a7c5e","family":"command_block","hardness":-1,"blast_resistance":3600000,"tool":-1,"source_node":"mcl_commandblock:commandblock_off"},
}

static func is_command_block(id: int) -> bool: return id == ID

# The source's sentinel: a non-printable character that stands in for `@@` while the
# other placeholders are replaced.
const SENTINEL = "\u001a"

# `resolve_commands`: replace `@@` with the sentinel, then `@p`/`@n`, `@f`, `@r`, `@c`,
# and finally the sentinel back to a literal `@`.
#
# Voxey is single-player, so every player placeholder resolves to the commander: the
# nearest, farthest and random player are all the one connected player. The substitutions
# are still performed in the source's order so a literal `@@c` cannot be double-substituted.
static func resolve(commands: String, commander: String) -> String:
	var text: String = commands.replace("@@",SENTINEL)
	text = text.replace("@p",commander).replace("@n",commander).replace("@f",commander).replace("@r",commander).replace("@c",commander)
	return text.replace(SENTINEL,"@")

# The command lines the source splits on, dropping the leading slash from each.
static func lines(commands: String) -> Array:
	var result: Array = []
	for line in commands.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty(): continue
		result.append(trimmed.trim_prefix("/"))
	return result

# `check_commands`: a line whose verb is not a known command is rejected, and the source
# names the leading-slash hint. Voxey's console has a fixed verb set, so validation is
# against that set.
const VERBS = ["gamemode","gamerule","help","seed","save","weather","time","sethome","home",
	"spawnpoint","locate","dimension","xp","give","spawn","tp","heal","killmobs","ccb"]

static func validate(commands: String) -> Dictionary:
	for raw in commands.split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty(): continue
		var had_slash: bool = line.begins_with("/")
		var pieces: PackedStringArray = line.trim_prefix("/").split(" ",false)
		var verb: String = pieces[0].to_lower() if not pieces.is_empty() else ""
		if not VERBS.has(verb):
			var hint: String = " Hint: Try to remove the leading slash." if had_slash else ""
			return {"ok":false,"error":"Error: The command \u201c%s\u201d does not exist; your command block has not been changed.%s"%[verb,hint]}
	return {"ok":true,"error":""}

# Run a powered command block's list as its commander. The caller supplies the runner so
# the console stays in the game layer. Returns the lines that ran.
static func trigger(commands: String, commander: String, run: Callable) -> Array:
	var executed: Array = []
	for line in lines(resolve(commands,commander)):
		run.call(("/"+line) if not line.begins_with("/") else line)
		executed.append(line)
	return executed

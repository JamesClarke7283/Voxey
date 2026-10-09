extends RefCounted

# Focused regression for the command block
# (Mineclonia `ITEMS/REDSTONE/mcl_commandblock/init.lua`, GPL-3.0-or-later).
#
# The source's module had two halves: the node's own redstone behaviour, and the command
# layer with its placeholders and its validation. These checks pin both, plus the
# commander rule and the rising-edge trigger.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	var old_gamemode: String = game.gamemode
	var old_position: Vector3 = game.player.position

	# --- the node exists and is registered ------------------------------------
	t.check(CommandBlocks.is_command_block(CommandBlocks.ID),"the command block node exists")
	t.check(VillageContent.DATA.has(CommandBlocks.ID),"the command block is in the node registry")
	t.check(Nodes.lookup("command block") == CommandBlocks.ID,"the command block is looked up by name")
	t.check(Nodes.solid(CommandBlocks.ID),"the command block is a solid cube")
	t.check(RedstoneCircuit.circuit_node(CommandBlocks.ID),"the command block is a redstone circuit node")

	# --- the placeholder substitution (`resolve_commands`) -------------------
	# The source replaces `@@` with a sentinel first, so a literal `@@c` is not eaten by
	# the `@c` rule, then restores it to a single `@`.
	t.check(CommandBlocks.resolve("@c is here","Alice") == "Alice is here","@c resolves to the commander")
	t.check(CommandBlocks.resolve("@@c","Alice") == "@c","@@c is a literal @c, not the commander")
	t.check(CommandBlocks.resolve("@p and @n and @f and @r","Alice") == "Alice and Alice and Alice and Alice","every player placeholder resolves to the sole player")
	t.check(CommandBlocks.resolve("give @n apple","Bob") == "give Bob apple","a placeholder inside an argument resolves")
	t.check(CommandBlocks.resolve("plain text","Alice") == "plain text","text without placeholders is unchanged")

	# --- the line split -------------------------------------------------------
	var split: Array = CommandBlocks.lines("/time day\n/give @n apple 5\n\n  /heal  ")
	t.check(split.size() == 3,"blank lines are dropped from a command list")
	t.check(split[0] == "time day" and split[1] == "give @n apple 5" and split[2] == "heal","each line loses its leading slash")

	# --- validation (`check_commands`) ---------------------------------------
	t.check(CommandBlocks.validate("time day").ok,"a known command validates")
	t.check(CommandBlocks.validate("time day\ngive @n apple 5").ok,"a multi-line list validates")
	var bad: Dictionary = CommandBlocks.validate("frobnicate now")
	t.check(not bad.ok and "frobnicate" in str(bad.error),"an unknown command is rejected by name")
	var slashed: Dictionary = CommandBlocks.validate("/frobnicate")
	t.check(not slashed.ok and "leading slash" in str(slashed.error),"a leading slash is named in the hint")

	# --- the trigger ----------------------------------------------------------
	var ran: Array = []
	var ran_lines: Array = CommandBlocks.trigger("time day\ngive @n apple 5","Alice",func(line: String): ran.append(line))
	t.check(ran_lines.size() == 2 and ran[0] == "/time day" and ran[1] == "/give Alice apple 5","the trigger runs each line as the commander")

	# --- the block in a live world -------------------------------------------
	var at: Vector3i = Vector3i(floori(game.player.position.x)+4,floori(game.player.position.y)+1,floori(game.player.position.z)+4)
	game.world.set_node(at,CommandBlocks.ID)
	game.world.circuits.register(at,CommandBlocks.ID)
	var block_state: Dictionary = game.world.circuits.state(at)
	t.check(game.world.circuits.tracked.has(at),"placing a command block tracks it as a circuit node")

	# Outside Creative mode the list is read-only, which is the source's gate.
	game.gamemode = "survival"
	var rejected: Dictionary = game.write_command_block(at,"time day")
	t.check(not rejected.ok and "Creative" in str(rejected.error),"a survival player cannot edit a command block")
	# In Creative mode it accepts a valid list and refuses an unknown verb.
	game.gamemode = "creative"
	t.check(game.write_command_block(at,"time day").ok,"a creative player can set the command list")
	t.check(block_state.get("commands","") == "time day","the written list is stored on the block")
	t.check(not game.write_command_block(at,"frobnicate").ok,"an invalid list is refused and the stored list kept")
	t.check(block_state.get("commands","") == "time day","a refused write leaves the previous list intact")

	# The commander is the placer; the block runs the list as that player. Driving the
	# circuit's rising edge is what executes it.
	block_state["commands"] = "give apple 1"
	game.inventory.slots[0] = {"id":0,"count":0,"wear":0}
	game.run_command_block(block_state)
	var got_apple: bool = false
	for slot in game.inventory.slots:
		if int(slot.get("id",0)) == Nodes.APPLE: got_apple = true
	t.check(got_apple,"a command block runs its list when triggered")

	# The rising edge alone runs the list: a second run with no edge does not. The
	# circuit's `powered` flag records the edge, so a still-powered block is skipped.
	block_state["commands"] = "give apple 1"
	block_state["powered"] = true
	game.inventory.slots[0] = {"id":0,"count":0,"wear":0}
	game.world.circuits.step(0.1)
	var second: bool = false
	for slot in game.inventory.slots:
		if int(slot.get("id",0)) == Nodes.APPLE: second = true
	t.check(not second,"a command block already powered does not run again on a later step")

	# --- opening the block UI ------------------------------------------------
	t.check(game.open_command_block(at),"using a command block opens its panel")
	t.check(game.state == "command_block","the command block state is set")
	t.check(not game.open_command_block(at+Vector3i(0,10,0)),"using a non-command block does not open the panel")
	game.resume()
	t.check(not game.world.circuits.interact(at+Vector3i(0,10,0)) or game.world.node_at(at+Vector3i(0,10,0)) != CommandBlocks.ID,"interacting with a non-command node is unaffected")

	game.gamemode = old_gamemode
	game.player.position = old_position
	game.world.set_node(at,Nodes.AIR)

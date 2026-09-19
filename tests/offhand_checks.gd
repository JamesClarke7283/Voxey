extends RefCounted

# Focused regression for the second hand (Mineclonia HUD/mcl_offhand).
#
# The offhand is a real slot, not a cosmetic one. Shields, totems and torches
# read it, which is what the source's `get_wielditem` plus offhand fallback
# means. Before this, shields borrowed the head armour slot as a stand-in, so
# wearing a helmet could silently disable a shield.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var player: VoxeyPlayer = game.player
	var inv: Inventory = game.inventory

	# --- the slot exists and is separate from the hotbar -------------------
	player.offhand_slot = {"id":0,"count":0,"wear":0}
	inv.slots[inv.selected] = {"id":0,"count":0,"wear":0}
	t.check(player.offhand_id() == 0,"a fresh second hand is empty")

	# --- a shield in the second hand --------------------------------------
	player.offhand_slot = {"id":VillageContent.SHIELD,"count":1,"wear":0}
	t.check(Shields.is_shield(player.offhand_id()),"a shield can be carried in the second hand")
	t.check(player.carries(VillageContent.SHIELD),"the second hand counts as carrying the item")
	# The shield raises from the second hand, which is the source's own place for
	# it, and no longer depends on the head armour slot.
	game.survival.shield_raised = true
	t.check(Shields.raised(player),"a shield in the second hand raises")
	# Wearing a helmet must not disable it, which is the bug the stand-in caused.
	player.armor_slots[0] = {"id":Nodes.armor_id(3,0),"count":1,"wear":0}
	t.check(Shields.raised(player),"a helmet no longer displaces the shield")
	player.armor_slots[0] = {"id":0,"count":0,"wear":0}
	game.survival.shield_raised = false

	# Shield wear lands on the second hand's copy of the item.
	game.survival.shield_raised = true
	Shields.add_wear(player,20.0)
	t.check(int(player.offhand_slot.wear) > 0,"blocked damage wears the shield where it is held")
	player.offhand_slot = {"id":0,"count":0,"wear":0}
	game.survival.shield_raised = false

	# --- a totem in the second hand ---------------------------------------
	player.offhand_slot = {"id":VillageContent.TOTEM,"count":1,"wear":0}
	t.check(Totems.held(player),"a totem in the second hand counts as carried")
	# A totem carried in the second hand is consumed there, leaving the main hand.
	inv.slots[inv.selected] = {"id":Nodes.TOOLS+3*5+4,"count":1,"wear":0}
	var consumed: String = player.consume_carried(VillageContent.TOTEM)
	t.check(consumed == "offhand","the totem is consumed from the second hand")
	t.check(player.offhand_id() == 0,"the consumed totem leaves the second hand")
	t.check(inv.held().id == Nodes.TOOLS+3*5+4,"consuming the second hand leaves the main hand alone")
	inv.slots[inv.selected] = {"id":0,"count":0,"wear":0}

	# The main hand keeps priority when both hands carry the item.
	inv.slots[inv.selected] = {"id":VillageContent.TOTEM,"count":1,"wear":0}
	player.offhand_slot = {"id":VillageContent.TOTEM,"count":1,"wear":0}
	t.check(player.consume_carried(VillageContent.TOTEM) == "main","the main hand supplies the item first")
	t.check(int(player.offhand_slot.count) == 1,"the second hand is kept when the main hand supplied it")
	inv.slots[inv.selected] = {"id":0,"count":0,"wear":0}
	player.offhand_slot = {"id":0,"count":0,"wear":0}

	# --- the source's offhand placement ------------------------------------
	# Torches are the source's only `offhand_placeable` group.
	t.check(Torches.is_torch(Nodes.TORCH),"a torch is recognised for offhand placement")
	player.offhand_slot = {"id":Nodes.TORCH,"count":3,"wear":0}
	t.check(player.carries(Nodes.TORCH),"a torch in the second hand counts as carried")
	var took: String = player.consume_carried(Nodes.TORCH)
	t.check(took == "offhand","a torch placed from the second hand is consumed there")
	t.check(int(player.offhand_slot.count) == 2,"one torch is taken, not the stack")
	player.offhand_slot = {"id":0,"count":0,"wear":0}

	# --- persistence -------------------------------------------------------
	# The second hand must survive a save and a reload, or a carried shield or
	# totem would vanish with the world.
	player.offhand_slot = {"id":VillageContent.SHIELD,"count":1,"wear":7}
	game.gamemode = "survival"
	var path: String = "user://offhand-check-"+str(OS.get_process_id())+".json"
	t.check(game.save_game(path),"the world saves with a filled second hand")
	var whole_save: Dictionary = game.read_save(path)
	player.offhand_slot = {"id":0,"count":0,"wear":0}
	game.set_process(true); game.load_world_data(whole_save)
	t.check(player.offhand_id() == VillageContent.SHIELD,"the second hand's item survives a save and reload")
	t.check(int(player.offhand_slot.wear) == 7,"the second hand's wear survives too")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	player.offhand_slot = {"id":0,"count":0,"wear":0}

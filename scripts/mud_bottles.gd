class_name MudBottles
extends RefCounted

# mcl_core.bottle_dirt and mcl_potions' dispenser branch: exactly three hosts.
static func host(id: int) -> bool:
	return id in [Nodes.DIRT,DryTerrain.COARSE_DIRT,LushCaveExtra.ROOTED_DIRT]

static func convert(game: Node3D, p: Vector3i, dispensing: bool = false) -> bool:
	if not host(game.world.node_at(p)): return false
	if not game.world.set_node(p,VillageContent.MUD): return true
	# Direct survival use exchanges the held bottle; creative preserves it. A
	# dispenser returns its glass through the dispenser outcome, never the player.
	if not dispensing and game.gamemode != "creative":
		game.inventory.consume_selected()
		game.survival.give(VillageContent.GLASS_BOTTLE,1)
	game.sound("place")
	if not dispensing: game.player.swing = 1
	return true

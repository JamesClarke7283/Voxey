class_name MonsterEggs
extends RefCounted

# Mineclonia ITEMS/mcl_monster_eggs/init.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# An infested block **looks identical to its normal counterpart** and hides a
# silverfish. Breaking one without Silk Touch releases the silverfish; breaking
# one *with* Silk Touch returns the plain block instead. That is the whole
# mechanic, and it is what makes a stronghold's stone treacherous.
#
# The source registers six variants, one per buildable stone block:
#
#   * Infested Stone
#   * Infested Cobblestone
#   * Infested Stone Bricks
#   * Infested Cracked Stone Bricks
#   * Infested Mossy Stone Bricks
#   * Infested Chiseled Stone Bricks
#
# The source also halves the block's hardness and removes its drop, so an
# infested block breaks faster than the real thing and yields nothing but the
# silverfish.
#
# The igloo's basement is generated *from* these: the source's ladder shaft is
# lined with a random mix of ordinary and infested bricks, which is why the
# structure needed this feature first.

# The six infested variants, each beside the plain block it imitates.
const STONE = 1162
const COBBLE = 1163
const BRICKS = 1164
const CRACKED_BRICKS = 1165
const MOSSY_BRICKS = 1166
const CHISELED_BRICKS = 1167
const BLOCKS = [STONE,COBBLE,BRICKS,CRACKED_BRICKS,MOSSY_BRICKS,CHISELED_BRICKS]

# The plain block each infested variant imitates, which is what Silk Touch
# returns and what the infested block looks like.
static func base_block(id: int) -> int:
	match id:
		STONE: return Nodes.STONE
		COBBLE: return Nodes.COBBLE
		BRICKS: return Nodes.BRICKS
		CRACKED_BRICKS: return Masonry.CRACKED_BRICKS
		MOSSY_BRICKS: return Masonry.MOSSY_BRICKS
		CHISELED_BRICKS: return Masonry.CHISELED_BRICKS
	return 0

static func is_infested(id: int) -> bool: return BLOCKS.has(id)

# The infested form of a plain block, or 0 when that block has no infested form.
static func infested_for(base: int) -> int:
	for id in BLOCKS:
		if base_block(id) == base: return id
	return 0

# A constant with literal keys, so `VillageContent.DATA` can reference it without
# a const cycle. An infested block's colour matches the block it imitates, which
# is the point: the source makes them look identical.
const DATA = {
	1162: {"name":"Infested stone","block":true,"color":"7a7a7a","hardness":0.75,"tool":0,"infested":true},
	1163: {"name":"Infested cobblestone","block":true,"color":"808080","hardness":1.0,"tool":0,"infested":true},
	1164: {"name":"Infested stone bricks","block":true,"color":"7a7a76","hardness":0.75,"tool":0,"infested":true},
	1165: {"name":"Infested cracked stone bricks","block":true,"color":"787874","hardness":0.75,"tool":0,"infested":true},
	1166: {"name":"Infested mossy stone bricks","block":true,"color":"6d7a63","hardness":0.75,"tool":0,"infested":true},
	1167: {"name":"Infested chiseled stone bricks","block":true,"color":"7a7a76","hardness":0.75,"tool":0,"infested":true},
}

# --- breaking ----------------------------------------------------------------

# The source's `after_dig_node`: a silverfish appears unless the digger used Silk
# Touch, in which case the plain block is returned instead. Creative releases
# nothing, which the source's `is_creative_enabled` check gives.
static func break_node(game: Node3D, p: Vector3i, id: int) -> bool:
	if not is_infested(id): return false
	var silk: bool = Inventory.enchantment(game.inventory.held(),"Silk Touch") > 0
	if not game.world.set_node(p,Nodes.AIR): return true
	if game.gamemode != "creative":
		if silk:
			# Silk Touch returns the plain block, never the infested one, so an
			# infested block cannot be moved and re-armed.
			var plain: int = base_block(id)
			if plain != 0: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,plain,1)
		else:
			# The silverfish appears where the block was, which is the ambush.
			game.spawn_creature("silverfish",Vector3(p)+Vector3(0.5,0.0,0.5))
	game._break_particles(p,id); game.sound("break"); game.progress("gather"); game.api.emit_node_broken(p,id)
	return true

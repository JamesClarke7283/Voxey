extends RefCounted

# Focused regression for infested blocks (Mineclonia `mcl_monster_eggs`).
#
# An infested block **looks identical to its normal counterpart** and hides a
# silverfish. Breaking one without Silk Touch releases the silverfish; breaking
# one with Silk Touch returns the plain block. The disguise is the whole point:
# a block that looked different would be no trap at all.
#
# The igloo's basement is generated from these, which is why the structure needed
# this feature before it could be built.

static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	world._apply_column(world.generator.generate_column(Vector2i(floori(p.x/16.0),floori(p.z/16.0)),world.edits))
	return world.loaded_at(Vector3(p))

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world

	# --- the six variants exist --------------------------------------------
	# The source registers one infested form per buildable stone block.
	t.check(MonsterEggs.BLOCKS.size() == 6,"the source's six infested variants are registered")
	for id in MonsterEggs.BLOCKS:
		t.check(VillageContent.DATA.has(id),"the infested variant %d is registered" % id)
		t.check(MonsterEggs.is_infested(id),"the variant %d identifies itself" % id)
		t.check(MonsterEggs.base_block(id) != 0,"the variant %d has a plain block it imitates" % id)
	t.check(not MonsterEggs.is_infested(Nodes.STONE),"a plain block is not infested")

	# --- the disguise -------------------------------------------------------
	# The defining property: an infested block must render exactly as the block it
	# hides. Checking the resolved colour covers every render path, including the
	# flat tile path that stone, cobblestone and bricks use.
	for id in MonsterEggs.BLOCKS:
		var base: int = MonsterEggs.base_block(id)
		t.check(Nodes.color(id) == Nodes.color(base),"the infested variant %d wears its base block's colour" % id)
	# And the pair must be reversible, so a spawner can pick the right variant.
	for base in [Nodes.STONE,Nodes.COBBLE,Nodes.BRICKS,Masonry.CRACKED_BRICKS,Masonry.MOSSY_BRICKS,Masonry.CHISELED_BRICKS]:
		t.check(MonsterEggs.infested_for(base) != 0,"the plain block %d has an infested form" % base)
	t.check(MonsterEggs.infested_for(Nodes.SAND) == 0,"a block with no infested form returns none")

	# --- breaking releases a silverfish ------------------------------------
	var at := Vector3i(4,64,4)
	t.check(ensure(game,at),"the test column is loaded")
	world.set_node(at,MonsterEggs.STONE)
	t.check(world.node_at(at) == MonsterEggs.STONE,"an infested block is placed")
	# Without Silk Touch the silverfish appears, which is the ambush.
	game.inventory.slots[game.inventory.selected] = {"id":Nodes.TOOLS+3*5+0,"count":1,"wear":0}
	var creatures_before: int = game.creatures.get_child_count()
	MonsterEggs.break_node(game,at,MonsterEggs.STONE)
	t.check(game.creatures.get_child_count() > creatures_before,"breaking an infested block releases a silverfish")
	t.check(world.node_at(at) == Nodes.AIR,"the infested block is gone")
	# The released creature is really a silverfish.
	var kinds: Dictionary = {}
	for mob in game.creatures.get_children(): kinds[mob.kind] = true
	t.check(kinds.has("silverfish"),"the released creature is a silverfish")
	for mob in game.creatures.get_children(): mob.free()

	# --- Silk Touch returns the plain block ---------------------------------
	# This is what stops a player from carrying a trap home: the infested block
	# itself can never be picked up.
	world.set_node(at,MonsterEggs.MOSSY_BRICKS)
	game.inventory.slots[game.inventory.selected] = {"id":Nodes.TOOLS+3*5+0,"count":1,"wear":0,"data":{"enchantments":{"Silk Touch":1}}}
	var creatures_before_silk: int = game.creatures.get_child_count()
	var drops_before: int = game.drops.get_child_count()
	MonsterEggs.break_node(game,at,MonsterEggs.MOSSY_BRICKS)
	t.check(game.creatures.get_child_count() == creatures_before_silk,"Silk Touch releases no silverfish")
	t.check(game.drops.get_child_count() > drops_before,"Silk Touch drops the plain block")
	var dropped_plain: bool = false
	for drop in game.drops.get_children():
		if drop.item_id == Masonry.MOSSY_BRICKS: dropped_plain = true
	t.check(dropped_plain,"the drop is the plain block, never the infested one")
	for drop in game.drops.get_children(): drop.free()
	game.inventory.slots[game.inventory.selected] = {"id":0,"count":0,"wear":0}

	# --- an infested block cannot be collected -------------------------------
	# The source sets `drop = ""` on every infested variant: breaking one yields the
	# silverfish and nothing else, and only Silk Touch returns the plain block. If
	# the node dropped itself it could be picked up and re-armed, which would make
	# the trap a portable weapon instead of a hazard.
	for id in MonsterEggs.BLOCKS:
		t.check(Nodes.drop(id) == 0,"the infested variant %d drops nothing on an ordinary break" % id)
		t.check(MonsterEggs.base_block(id) != 0,"the infested variant %d still has the plain block Silk Touch returns" % id)

	# --- it is a stone block for the rest of the game ------------------------
	# An infested block is tool-mined and solid, so it behaves like the stone it
	# imitates rather than a special case.
	for id in MonsterEggs.BLOCKS:
		t.check(Nodes.solid(id),"the infested variant %d is solid" % id)
		t.check(Nodes.placeable(id) or VillageContent.DATA[id].get("block",false) == true,"the infested variant %d is placeable" % id)

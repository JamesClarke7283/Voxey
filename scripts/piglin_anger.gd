class_name PiglinAnger
extends RefCounted

# Mineclonia ENTITIES/mobs_mc/piglin.lua (`mobs_mc.enrage_piglins` at :516-530, the
# `register_on_dignode` hook at :533-541, `piglin_loves_item` at :543+) and
# ITEMS/mcl_barrels/init.lua:64 / ITEMS/mcl_chests/init.lua:273, which call the
# same helper when a container is opened. GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# The piglin's defining hazard: it is neutral until provoked, and **opening a
# container or mining a gold-bearing node near one provokes every piglin within
# sixteen nodes**. That is what makes looting a bastion a decision rather than a
# formality, and Voxey had neither trigger.
#
# The source's own rules, reproduced here:
#
#   * `enrage_piglins(player, need_line_of_sight)` scans a 33-node cube around the
#     player and enrages each piglin, optionally gated on line of sight.
#   * Opening a chest, trapped chest or barrel calls it **with** the line-of-sight
#     test; mining a `piglin_protected` node calls it **without**.
#   * `piglin_loves_item` lists what a piglin will not attack you for holding; the
#     anger is per-piglin and persists in the source's mob state.

# `vector.offset(pos, -16, -16, -16)` .. `(16, 16, 16)`.
const RANGE = 16
# The nodes carrying the source's `piglin_protected` group: gold ore, deepslate
# gold ore, nether gold ore and a gilded bastion block.
const PROTECTED = [Nodes.GOLD_ORE,Nodes.DEEP_GOLD_ORE,MinecloniaOres.NETHER_GOLD,Bastions.GILDED]

# Whether breaking this node provokes a nearby piglin.
static func protected_node(id: int) -> bool:
	return id in PROTECTED

# `piglin_loves_item`: the items a piglin accepts instead of attacking. The source
# lists gold ore, nether gold, a light pressure plate, a gold ingot, a bell, a
# clock, a golden carrot, a glistering melon, a golden apple and anything in the
# `golden` group.
static func loves(id: int) -> bool:
	if id in [Nodes.GOLD_ORE,Nodes.DEEP_GOLD_ORE,MinecloniaOres.NETHER_GOLD,Nodes.GOLD,VillageContent.BELL,
		Nodes.CLOCK,VillageContent.GOLDEN_CARROT,VillageContent.GLISTERING_MELON,Nodes.GOLDEN_APPLE,
		Nodes.GOLD_NUGGET,Nodes.GOLD_BLOCK,Nodes.PRESSURE_PLATE]: return true
	return false

# `enrage_piglins`: every piglin within sixteen nodes of the player becomes
# hostile. `line_of_sight` mirrors the source's `target_visible` gate, which the
# container path passes and the dig path does not.
static func enrage(game: Node3D, line_of_sight: bool = false) -> int:
	var origin: Vector3 = game.player.position
	var angered: int = 0
	for mob in game.creatures.get_children():
		if mob.is_queued_for_deletion() or mob.kind != "piglin": continue
		if absf(mob.position.x-origin.x) > RANGE or absf(mob.position.y-origin.y) > RANGE or absf(mob.position.z-origin.z) > RANGE: continue
		if line_of_sight and not mob._sees_player(): continue
		mob.provoked = true
		# A piglin mid-barter is not made angry; the source's `aggressive` reads the
		# barter timer ahead of the provocation flag.
		if mob.has_method("store_record"): mob.store_record()
		angered += 1
	return angered

# The container-open trigger, which the source runs with the sight test.
static func on_container_opened(game: Node3D) -> void:
	enrage(game,true)

# The dig trigger, which the source runs without it.
static func on_protected_broken(game: Node3D, id: int) -> void:
	if protected_node(id): enrage(game,false)

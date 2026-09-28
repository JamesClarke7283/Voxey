class_name FallingDamage
extends RefCounted

# Mineclonia ENTITIES/mcl_falling_nodes/init.lua (`deal_falling_damage` at :9-57,
# `crush_after_fall` at :188, `_mcl_falling_node_alternative` at :70-72) and
# ITEMS/mcl_anvils/init.lua (`damage_anvil_by_falling` at :376-383, the
# `falling_node`/`crush_after_fall` groups at :386). GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# A falling node that lands on an actor hurts it, and an anvil that falls damages
# itself. The source's arithmetic:
#
#   * Damage is `(way - 1) * 2`, where `way` is the rounded distance fallen from
#     the entity's start position, clamped to 0..40.
#   * A helmet of any `combat_armor` material reduces it to three quarters and
#     takes one wear.
#   * The damage reason is `anvil` for an anvil and `falling_node` otherwise.
#   * Anything within radius 1 of the landing point is hit, once per entity, and a
#     dropped item in that radius is destroyed outright.
#
# `crush_after_fall` blocks replace whatever they land on; every other falling
# node refuses to land on a non-replaceable cell and drops as an item instead.

# `damage = math.min(40, math.max(0, damage))`.
const MAX_DAMAGE = 40.0
# The helmet's `damage / 4 * 3`.
const HELMET_FACTOR = 0.75
# `core.objects_inside_radius(pos, 1)`.
const REACH = 1.0

# Whether the falling node is an anvil, which changes the damage reason and adds
# the self-damage ladder.
static func is_anvil(id: int) -> bool:
	return VillageContent.ANVIL == id or id in [11446,11447]

# `crush_after_fall`: the node replaces what it lands on rather than dropping when
# the destination is not buildable-to.
static func crushes(id: int) -> bool:
	return is_anvil(id)

# `_mcl_falling_node_alternative`: a definition that renames itself on becoming a
# falling entity. Suspicious sand and gravel keep their own id in Voxey, so only
# the concrete-powder family and the anvil states need a mapping.
static func alternative(id: int) -> int:
	return id

# `(way - 1) * 2` clamped to 0..40, where `way` is the rounded fall distance.
static func damage_for(distance: float) -> float:
	return clampf((floorf(distance)-1.0)*2.0,0.0,MAX_DAMAGE)

# The helmet's reduction: three quarters of the damage and one point of wear on
# the head slot. Returns the damage after the reduction.
static func helmet_reduction(slot: Dictionary, damage: float) -> float:
	if slot.is_empty() or int(slot.get("id",0)) == 0: return damage
	if not Nodes.is_armor(slot.id) or Nodes.armor_piece(slot.id) != 0: return damage
	return damage*HELMET_FACTOR

# `deal_falling_damage` for one landing: every actor within radius 1 takes the
# scaled damage, the player's helmet absorbs its share, and every dropped item in
# range is destroyed. `start_y` is the entity's rounded start height.
static func land(game: Node3D, at: Vector3, id: int, start_y: float) -> void:
	var damage: float = damage_for(start_y-at.y)
	if damage < 1.0: return
	var reason: String = "anvil" if is_anvil(id) else "falling_node"
	for drop in game.drops.get_children():
		if drop.position.distance_to(at) <= REACH: drop.queue_free()
	if game.player.health > 0 and game.player.position.distance_to(at) <= REACH:
		var reduced: float = helmet_reduction(game.player.armor_slots[0],damage)
		if reduced < damage:
			var helmet: Dictionary = game.player.armor_slots[0]
			helmet.wear += 1
			if helmet.wear >= Nodes.durability(helmet.id):
				game.toast("Your "+Nodes.title(helmet.id).to_lower()+" broke.")
				helmet.id = 0; helmet.count = 0; helmet.wear = 0; helmet.erase("data")
			game.inventory.changed.emit()
		game.player.hurt(reduced,false,Vector3.INF,reason)
	for mob in game.creatures.get_children():
		if mob.is_queued_for_deletion() or mob.health <= 0: continue
		# The source marks each entity once per falling node; a single landing only
		# ever touches a mob once, so the mark is not needed here.
		if mob.position.distance_to(at) > REACH: continue
		mob.hit(damage,Vector3.INF)

# `damage_anvil_by_falling`: past one block of fall, a `5 * distance` percent roll.
static func anvil_self_damage(game: Node3D, p: Vector3i, id: int, distance: float, rng: RandomNumberGenerator = null) -> bool:
	if not is_anvil(id) or not Anvils.falling_damage(int(floorf(distance)),rng): return false
	game.survival.damage_anvil(p)
	return true

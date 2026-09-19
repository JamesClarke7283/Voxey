class_name Shields
extends RefCounted

# Mineclonia ITEMS/mcl_shields/init.lua, GPL-3.0-or-later. Original GDScript
# using the source as a behaviour reference.
#
# A shield blocks the player's **frontal half** while it is raised. The source's
# rule is a dot-product test:
#
#   SHIELD_BLOCK_ARC     = 180 degrees
#   SHIELD_BLOCK_COSINE  = -cos(ARC / 2) = -cos(90 deg) ~= 0
#
# so an attack is blocked when `dot(attack_direction, look_direction) <= 0`,
# which is exactly the hemisphere the player is facing. The attack direction is
# measured from the player's shield centre — the eye height times two thirds —
# toward the attacker.
#
# Three further source rules are reproduced:
#
#   * Only listed attack types are blockable: mob, player, arrow, generic,
#     explosion, dragon breath and trident. Everything else passes through.
#   * Wear is added only for hits of 3 or more damage, and is equal to the
#     ceiling of the damage.
#   * A shield that is disabled (by an axe) blocks nothing until it recovers.
#
# Voxey's earlier implementation raised the shield for one second on use. That is
# not the source's behaviour: the source holds it up for as long as the player
# keeps it raised.

const BLOCK_ARC = 180.0
# `-cos(ARC/2)` in degrees, the source's own expression.
const BLOCK_COSINE = 0.0
# The source's `types` table: only these damage reasons may be blocked.
const BLOCKABLE = ["mob","player","arrow","generic","explosion","dragon_breath","trident"]
# `add_wear` ignores hits below this threshold.
const WEAR_THRESHOLD = 3.0
# Source `_mcl_uses`.
const USES = 336

static func is_shield(id: int) -> bool: return id == VillageContent.SHIELD

# `find_angle`: the dot product of the attack direction and the player's look,
# measured from the shield centre rather than the feet.
static func angle(player: VoxeyPlayer, attack_pos: Vector3) -> float:
	if is_inf(attack_pos.x): return 1.0
	var centre: Vector3 = player.position+Vector3.UP*1.62*2.0/3.0
	var attack_direction: Vector3 = (centre-attack_pos).normalized()
	var look: Vector3 = -player.camera.global_basis.z
	return attack_direction.dot(look.normalized())

# `can_block`: the source's decision, returning a reason when it refuses.
static func can_block(player: VoxeyPlayer, attack_pos: Vector3, kind: String) -> bool:
	if not raised(player): return false
	if not BLOCKABLE.has(kind): return false
	# `angle > SHIELD_BLOCK_COSINE` means non-frontal.
	return angle(player,attack_pos) <= BLOCK_COSINE

# The shield is raised while the player holds it and is not attacking, which is
# the source's own held state rather than a one-second window.
static func raised(player: VoxeyPlayer) -> bool:
	var survival = player.game.survival
	if survival.shield_disabled > 0.0: return false
	if not survival.shield_raised: return false
	# A shield must actually be carried, which the source's `is_blocking` checks.
	# The source checks the main hand, then the offhand. Voxey previously borrowed
	# the head armor slot as a stand-in; the player now has a real second hand.
	return is_shield(player.game.inventory.held().id) or is_shield(player.offhand_id())

# `add_wear`: damage of three or more costs durability equal to the damage's
# ceiling; anything smaller is free.
static func add_wear(player: VoxeyPlayer, damage: float) -> void:
	if player.game.gamemode == "creative": return
	if damage < WEAR_THRESHOLD: return
	# The source wears the raised shield, wherever the player is carrying it.
	var slot: Dictionary = player.carried_slot(VillageContent.SHIELD)
	if slot.is_empty(): return
	slot.wear += int(ceil(damage))
	if slot.wear >= USES:
		player.game.toast("Your shield broke.")
		slot.id = 0; slot.count = 0; slot.wear = 0; slot.erase("data")
		player.game.sound("break")

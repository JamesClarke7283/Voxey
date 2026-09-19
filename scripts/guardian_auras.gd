class_name GuardianAuras
extends RefCounted

# Mineclonia `mobs_mc/guardian.lua` (the thorns response) and
# `guardian_elder.lua` (the mining-fatigue aura), GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# Two guardian behaviours were missing, and they are what make a monument an
# *obstacle* rather than a room full of mobs:
#
#   1. **The elder's mining fatigue.** Every sixty seconds the elder inflicts
#      **mining fatigue level 3 for five minutes** on every player within **fifty
#      blocks**. That is what makes mining through a monument slow, and it is the
#      source's most distinctive guardian rule.
#   2. **The guardian's thorns.** A guardian that is *attacked* in melee deals
#      **two damage back** to its attacker, but only when it is not in `go_pos`
#      movement and the attacker does not bypass the guardian — which is the
#      source's guard against a guardian retaliating while it is pacing.
#
# Neither is part of the laser attack, which Voxey already had; both are separate
# rules the source attaches to the creatures.

# Source `vector.distance(pos, self_pos) <= 50`.
const FATIGUE_RADIUS = 50.0
# Source `self._fatigue_counter = (self._fatigue_counter or 60) + dtime`, and the
# aura fires when the counter passes sixty.
const FATIGUE_INTERVAL = 60.0
# `give_effect_by_level("fatigue", player, 3, 300)`.
const FATIGUE_LEVEL = 3
const FATIGUE_DURATION = 300.0
# Source `deal_damage(source, 2.0, {type = "thorns"})`.
const THORNS_DAMAGE = 2.0

# The effect Voxey uses for fatigue. The source calls it `fatigue`; Voxey's effect
# list has no mining-fatigue entry, so one is registered for it in the catalogue.
const FATIGUE_EFFECT = "fatigue"

# --- the elder's aura --------------------------------------------------------

# Advance an elder's aura timer and, when it fires, fatigue every player within
# fifty blocks. Returns the players affected, which is what the test asserts.
static func aura_step(game: Node3D, elder: Creature, delta: float) -> Array:
	if not Guardians.is_elder(elder.kind): return []
	if float(elder.get_meta("fatigue_counter",0.0)) == 0.0: elder.set_meta("fatigue_counter",FATIGUE_INTERVAL)
	var counter: float = float(elder.get_meta("fatigue_counter",FATIGUE_INTERVAL))+delta
	if counter <= FATIGUE_INTERVAL:
		elder.set_meta("fatigue_counter",counter)
		return []
	# The source subtracts a whole interval rather than resetting, so a slow frame
	# does not lose the difference.
	elder.set_meta("fatigue_counter",counter-FATIGUE_INTERVAL)
	var affected: Array = []
	if game.player.position.distance_to(elder.position) <= FATIGUE_RADIUS:
		PotionEffects.apply(game.player,FATIGUE_EFFECT,FATIGUE_DURATION,FATIGUE_LEVEL)
		affected.append(game.player)
	return affected

# --- the guardian's thorns ---------------------------------------------------

# Whether a guardian retaliates against an attacker, which the source gates on
# the guardian's own movement goal and the attacker's damage flags.
static func retaliates(guardian: Creature, pacing: bool, bypasses: bool) -> bool:
	if not Guardians.is_guardian(guardian.kind): return false
	# The source's guard: a guardian in `go_pos` movement does not retaliate.
	if pacing: return false
	if bypasses: return false
	return true

# Whoever is standing where a blow came from, which is where the retaliation goes.
static func attacker_at(game: Node3D, from: Vector3, exclude: Creature) -> Node3D:
	if game.player.position.distance_to(from) < 1.5: return game.player
	for mob in game.creatures.get_children():
		if mob == exclude or mob.is_queued_for_deletion(): continue
		if mob.position.distance_to(from) < 1.5: return mob
	return null

# Deal the source's thorns damage back to an attacker.
static func thorns(guardian: Creature, attacker: Node3D) -> bool:
	if attacker == null or not is_instance_valid(attacker): return false
	if attacker == guardian: return false
	if attacker is VoxeyPlayer:
		attacker.hurt(THORNS_DAMAGE,true,guardian.position,"thorns")
		return true
	if attacker is Creature:
		attacker.hit(int(THORNS_DAMAGE),guardian.position)
		return true
	return false

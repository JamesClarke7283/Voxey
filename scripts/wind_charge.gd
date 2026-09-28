class_name WindCharge
extends RefCounted

# Mineclonia `ENTITIES/mcl_charges/init.lua` and `wind_charge.lua`. GPL-3.0-or-later.
# Original GDScript using the source as a behaviour reference.
#
# The wind charge is a thrown explosive that **does not break blocks**. Its burst:
#
#   * knocks every object inside a radius of **4** away from the impact — a player
#     gets `normalize(obj - pos) * float_random(1.8, 2.0) / max(1, distance) * 4`,
#     which is why it is far stronger at point-blank range; a mob gets a velocity of
#     `normalize(direction) * radius * 3 + its old velocity + a random ±0.5` on each
#     axis, clamped to a length of 250.
#   * deals **6** damage to a mob and **0** to a player (`get_arrow_damage_func(6)`/
#     `(0)`, both with the `fireball` type), so it is a movement tool rather than a
#     weapon.
#   * explodes after **3 seconds** if it has hit nothing.
#
# Two blocks answer it specially: a bell rings, and a chorus flower is broken —
# a **living** one is destroyed outright, a **dead** one drops a living flower in its
# place. The decorated pot is destroyed for four bricks, which is the pottery
# module's own `pot_effects` path in the source.

# The id. 11601 is the slot after the recovery compass at 11600.
const ID = 11601

const DATA = {
	11601:{"name":"Wind charge","color":"dce8ee","family":"charge","stack":64,
		"source_node":"mcl_charges:wind_charge"},
}

# `_mcl_crafting_output = {single = {output = "mcl_charges:wind_charge 4"}}` on the
# breeze rod: one rod makes four charges.
static func recipe_entries() -> Array:
	return [["Wind charge",ID,4,[VillageContent.BREEZE_ROD]]]
# `RADIUS = 4`.
const RADIUS = 4.0
# `damage_radius = (RADIUS / max(1, RADIUS)) * RADIUS`.
const DAMAGE_RADIUS = 4.0
# `local velocity = 30` on both the place and secondary-use paths.
const SPEED = 30.0
# `local cooldown_time = 1`.
const COOLDOWN = 1.0
# `core.after(3, ...)`: a charge that hits nothing removes itself after three seconds.
const LIFETIME = 3.0
# `get_arrow_damage_func(6, "fireball")` for a mob and `(0, "fireball")` for a player.
const MOB_DAMAGE = 6
# The charge's own collision box: `{-0.1,-0.1,-0.1, 0.1,0.0,0.1}`.
const WIDTH = 0.2

static func exists(id: int) -> bool: return id == ID

# `mcl_charges.wind_burst_velocity(pos1, pos2, old_vel, power)`: a mob's new velocity
# is the direction vector times the power, plus what it already had, plus a random
# half-block jitter on each axis, clamped to 250.
static func burst_velocity(origin: Vector3, at: Vector3, current: Vector3, power: float) -> Vector3:
	if origin.is_equal_approx(at): return current
	var result: Vector3 = (at-origin).normalized()*power
	result += current
	result += Vector3(randf()-0.5,randf()-0.5,randf()-0.5)
	if result.length() > 250.0: result = result.normalized()*250.0
	return result

# `mcl_charges.wind_burst(pos, radius)`: push everything in range away from the burst.
# A player gets the distance-scaled push, a mob or a dropped item the velocity form.
static func burst(game: Node3D, at: Vector3, radius: float = DAMAGE_RADIUS) -> void:
	var player: VoxeyPlayer = game.player
	if player != null and player.position.distance_to(at) <= radius:
		var distance: float = maxf(1.0, player.position.distance_to(at))
		var push: Vector3 = (player.position-at).normalized()*(randf_range(1.8,2.0)/distance*RADIUS)
		player.velocity += push
	for mob in game.creatures.get_children():
		if mob.is_queued_for_deletion() or mob.position.distance_to(at) > radius: continue
		mob.velocity = burst_velocity(at,mob.position,mob.velocity,radius*3.0)
		mob.knock = Vector3.ZERO
	# `luaobj.is_mob or is_builtin_item`: a dropped item is pushed the same way a mob
	# is, which Voxey's drops share a container for.
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.position.distance_to(at) <= radius:
			drop.velocity = burst_velocity(at,drop.position,drop.velocity,radius*3.0)

# `hit_node`: the bursts the source plays, plus the two blocks that answer specially.
# Returns the blocks the burst acted on, so a caller can report them.
static func hits_node(game: Node3D, at: Vector3, cell: Vector3i) -> void:
	game.sound_at("explosion",at,2.5)
	game.puff(at,Color("dce8ee"),18,2.0)
	var id: int = game.world.node_at(cell)
	# `if core.get_item_group(node.name, "bell") >= 1 then mcl_bells.ring_once(pos)`.
	if id == VillageContent.BELL:
		game.villages.ring_bell(cell); return
	# `mcl_end:chorus_flower`: a living flower is destroyed, a dead one is replaced by
	# a living one. Both pop the flower's own particles.
	# `mcl_charges.chorus_flower_effects(pos, radius)` and `pot_effects`: both pop a
	# small burst of particles where the block was.
	var at_block: Vector3 = Vector3(cell)+Vector3.ONE*0.5
	if EndMud.is_living_flower(id):
		game.world.set_node(cell,Nodes.AIR)
		game.spawn_drop(at_block,EndMud.CHORUS_FLOWER)
		game.puff(at_block,Color("8f6f9e"),10,2.0)
	elif EndMud.CHORUS_FLOWER_DEAD == id:
		game.world.set_node(cell,EndMud.CHORUS_FLOWER)
		game.puff(at_block,Color("8f6f9e"),10,2.0)
	# `mcl_pottery_sherds:pot` is destroyed for four bricks.
	elif Decor.is_pot(id):
		game.world.set_node(cell,Nodes.AIR)
		# `core.add_item(pos, {name = "mcl_core:brick"})` four times.
		for i in 4: game.spawn_drop(at_block,Nodes.BRICKS)
		game.puff(at_block,Color("a4695a"),10,2.0)

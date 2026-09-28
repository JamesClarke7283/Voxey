class_name WitherSkulls
extends RefCounted

# Mineclonia ENTITIES/mobs_mc/wither.lua: `ranged_attack` (:425-449), the arrow
# definitions `mobs_mc:wither_skull` (:829-911) and `mobs_mc:wither_skull_strong`
# (:913-930), `spawn_wither_rose` (:817-827) and the charge's own blast (:754-765).
# GPL-3.0-or-later. Original GDScript using the source as a behaviour reference.
#
# The wither's ranged attack was recorded as a gap: Voxey dealt its damage directly,
# with no projectile. The source's rules are:
#
#   * The boss fires a skull whose speed is `velocity = 17`; every **fourth** skull
#     is the strong variant, fired at `velocity = 12`, which is `redirectable`.
#   * A skull's lifetime is 500, and `rotate = 90` turns it in flight.
#   * A direct hit deals **8** damage as `wither_skull` — which `mcl_damage`
#     declares `is_magic` and `is_explosion` — and then explodes with radius **1**.
#     So a hit is both the direct damage and a blast.
#   * On Hard (`difficulty >= 2`) the victim also takes **withering level 2**, for
#     ten seconds on Hard and forty on Normal-and-above (the source's own
#     `difficulty == 2 and 10 or 40`).
#   * A kill heals the shooter **5**.
#   * A victim that survives is knocked along the skull's horizontal heading.
#   * A kill **spawns a wither rose** on the nearest soil within two nodes of the
#     victim, or drops the rose as an item when griefing is off.
#   * The boss's separate charge attack damages everything within **3** nodes for
#     **15**, as `explosion`.
#
# `Withers.gd` owns the boss's phases and the star; this module owns the projectile
# and the two numbers that belong to it.

# Source `skull_def.velocity`.
const SKULL_VELOCITY = 17.0
# Source `strong_skull_def.velocity = 12`.
const STRONG_VELOCITY = 12.0
# Source `skull_def._lifetime = 500` (a Luanti step count; Voxey counts seconds).
const SKULL_LIFETIME = 25.0
# Source `mcl_util.deal_damage(player, 8.0, {type = "wither_skull"})`.
const SKULL_DAMAGE = 8.0
# Source `mcl_explosions.explode(pos, 1, ...)`.
const SKULL_BLAST = 1.0
# Source `WITHER_CHARGE_DAMAGE = 15`.
const CHARGE_DAMAGE = 15.0
# Source `core.objects_inside_radius(self_pos, 3)`.
const CHARGE_RADIUS = 3.0
# Source `shooter:heal_mob(5)`.
const KILL_HEAL = 5.0
# Source's withering: level 2, `difficulty == 2 and 10 or 40` seconds.
const WITHER_LEVEL = 2
const WITHER_HARD = 10.0
const WITHER_OTHER = 40.0
# Source `core.find_node_near(obj:get_pos(), 2, wither_rose_soil)`.
const ROSE_REACH = 2
# Source `wither_rose_soil`: grass, dirt, coarse dirt, netherrack, soul blocks, mud.
const ROSE_SOIL_GROUPS = ["grass_block"]

# `(ws.skulls_fired % 4) == 0`, so the fourth, eighth, twelfth skull is strong.
static func is_strong(fired: int) -> bool:
	return fired > 0 and posmod(fired,4) == 0

static func velocity_for(fired: int) -> float:
	return STRONG_VELOCITY if is_strong(fired) else SKULL_VELOCITY

# `strong_skull_def.redirectable = true`, and the plain skull is not.
static func redirectable(fired: int) -> bool:
	return is_strong(fired)

# The withering a hit applies: none on Easy, ten seconds on Hard, forty otherwise.
static func wither_duration(difficulty: int) -> float:
	if difficulty < 2: return 0.0
	return WITHER_HARD if difficulty >= 3 else WITHER_OTHER

# The soil the source's `wither_rose_soil` covers, in Voxey's ids.
static func rose_soil(id: int) -> bool:
	if id in [Nodes.GRASS,Nodes.DIRT,Nodes.NETHERRACK,Nodes.SOUL_SAND,Campfires.SOUL_SOIL,VillageContent.MUD]: return true
	return false

# `spawn_wither_rose`: look for soil within two nodes, and put the rose in the air
# cell above it. Returns the cell the rose was placed in, or a zero vector when
# there was nowhere to put it.
static func rose_spot(world: VoxelWorld, at: Vector3) -> Vector3i:
	var center := Vector3i(at.floor())
	for radius in range(0,ROSE_REACH+1):
		for dx in range(-radius,radius+1):
			for dz in range(-radius,radius+1):
				for dy in range(-1,2):
					var soil: Vector3i = center+Vector3i(dx,dy,dz)
					if not world.loaded_at(Vector3(soil)): continue
					if not rose_soil(world.node_at(soil)): continue
					var above: Vector3i = soil+Vector3i.UP
					if world.node_at(above) == Nodes.AIR and world.loaded_at(Vector3(above)): return above
	return Vector3i.ZERO

# The whole impact, called by the projectile when it strikes something. `victim` may
# be null for a block hit. Returns whether the strike was lethal to a mob.
static func impact(game: Node3D, victim: Node3D, at: Vector3, heading: Vector3, difficulty: int) -> bool:
	# The source's own order inside `hit_mob` is **withering, then the eight, then the
	# blast**, and it matters: exploding first would kill a weak victim before the
	# withering could land, so a cow would never catch it at all. A block hit still
	# explodes — `hit_node` is only the blast.
	if victim == null or not is_instance_valid(victim) or victim.health <= 0:
		game.explode(at,SKULL_BLAST)
		return false
	var duration: float = wither_duration(difficulty)
	if duration > 0.0: PotionEffects.apply(victim,"withering",duration,WITHER_LEVEL)
	var lethal: bool = false
	var mob: Creature = null
	if victim is VoxeyPlayer:
		# A player takes the eight through `hurt` with the source's own reason, so
		# armor and the totem still apply the way `mcl_damage`'s flags say they do.
		(victim as VoxeyPlayer).hurt(SKULL_DAMAGE,false,at,"wither_skull")
		lethal = (victim as VoxeyPlayer).health <= 0
	else:
		mob = victim
		# `l:projectile_knockback(1, dir)` runs **before** the damage in the source,
		# and it has to here too: `Creature.hit` assigns its own knockback, so an
		# impulse added afterwards would be discarded. The heading is horizontal,
		# which is what the source's `v.y = 0` before normalising produces.
		var flat := Vector3(heading.x,0.0,heading.z)
		if flat.length() > 0.001: mob.knock = flat.normalized()*SKULL_DAMAGE
		mob.hit(SKULL_DAMAGE,at,"wither_skull")
		# The source's own kill test is `l.health - 8 <= 0`, read **after** the damage
		# was dealt — so it subtracts the eight twice and only fires when the victim is
		# already at or below eight health post-hit. That is a quirk, not a reading:
		# ported as written so the heal and the rose land exactly when the source's do.
		lethal = mob.health-SKULL_DAMAGE <= 0.0 or mob.is_queued_for_deletion()
		# `hit` overwrites the knock, so a survivor's impulse is re-applied after it.
		if not lethal: mob.knock = flat.normalized()*SKULL_DAMAGE
	# Then the blast, which is part of the same strike.
	game.explode(at,SKULL_BLAST)
	# A kill leaves a wither rose behind; the shooter's heal is the caller's job,
	# because only the caller knows who fired.
	if lethal:
		var spot: Vector3i = rose_spot(game.world,at)
		if spot != Vector3i.ZERO: game.world.set_node(spot,FlowersExtra.WITHER_ROSE)
	return lethal

# `ranged_attack`: fire one skull. `fired` is the source's running `skulls_fired`, so
# the caller increments it *before* calling, which is what makes the fourth strong.
static func fire(game: Node3D, wielder: Node3D, origin: Vector3, aim: Vector3, fired: int) -> WitherSkull:
	var node := WitherSkull.new()
	node.game = game
	node.shooter = wielder
	node.strong = is_strong(fired)
	node.position = origin
	node.velocity = aim.normalized()*velocity_for(fired)
	game.entities.add_child(node)
	return node

# The boss's own charge: everything within three nodes takes fifteen as an
# explosion, the boss itself excluded.
static func charge(game: Node3D, center: Vector3, wielder: Node3D) -> int:
	var struck: int = 0
	if game.player.health > 0 and game.player != wielder and game.player.position.distance_to(center) <= CHARGE_RADIUS:
		game.player.hurt(CHARGE_DAMAGE,false,center,"explosion"); struck += 1
	for mob in game.creatures.get_children():
		if mob == wielder or mob.is_queued_for_deletion() or mob.health <= 0: continue
		if mob.position.distance_to(center) > CHARGE_RADIUS: continue
		mob.hit(CHARGE_DAMAGE,center,"explosion"); struck += 1
	return struck

class_name XpOrbs
extends RefCounted

# Mineclonia HUD/mcl_experience/{init.lua,orb.lua,bottle.lua} and the collection
# step of ENTITIES/mcl_item_entity/init.lua, GPL-3.0-or-later. Original
# procedural GDScript and artwork using the source as a behaviour reference.
#
# Voxey had every experience *award* already — ores, sculk, mob kills, fishing,
# breeding, trades, the dragon — but every one of them paid straight into
# `game.experience`, so an award was invisible: it could not be seen on the
# ground and could not be lost by dying. This module is the source's orb entity
# and the delivery path it feeds.
#
# Choice of representation. `throw_xp` spawns real `Node3D` orb nodes into
# `game.entities`, but the simulation is centralised in `XpOrbs.update`, which
# the parent registers beside `Copper.update`. The source steps an entity in its
# own `on_step` and integrates its motion inside the engine; doing the
# integration here keeps one deterministic driver for the whole batch, so a
# paused game freezes orbs with everything else and a test can step them without
# a physics tick. Observable behaviour is unchanged: the orbs fly under gravity,
# slide on ice, are magnetised by the player and are freed on arrival or expiry.
#
# Source rules reproduced here, with the quirks they imply:
#
# * **Splitting** (`init.lua:137-156`). `throw_xp` repeatedly draws
#   `min(random(1, min(32767, total - floor(i/2))), total - i)` and stops when the
#   request is covered or after **100 orbs**. The `100` caps the orb *count*, not
#   an orb's size, so a single orb may legitimately be worth 1234, and a request
#   larger than 100 x 32767 is truncated exactly as the source truncates it.
# * **Size ladder** (`orb.lua:1-27`). `xp_to_size` walks `size_to_xp` while
#   `xp > size_to_xp[i][1]`, i.e. it compares against each pair's **lower** field,
#   so a row is selected for `(previous row's lower field, this row's lower
#   field]` and every boundary sits on the table's *lower* value plus one.
#   Ported verbatim, which means bucket 0 (the `-32768..2` row) is unreachable
#   for any real amount and the reachable rows are
#   `<=3, 4..7, 8..17, 18..37, 38..73, 74..149, 150..307, 308..617, 618..1237,
#   1238+` — one row above the table's own `1, 2..6, 7..16, ... 2477+` bounds.
#   The sprite scale is 20..59 units of percent, i.e. 0.20..0.59 blocks.
# * **Age** (`orb.lua:29,84-87`): 300 s, after which the orb is removed.
#   `orb.lua:162-164` sets `static_save = false`, so orbs never persist; an orb
#   whose column is gone is removed exactly as the source removes a node in
#   "ignore" (`orb.lua:93-97`).
# * **Throw** (`orb.lua:182-190` plus `init.lua:144-149`): activation gives
#   `(0,2,0)`, and the throw then overrides it with
#   `(random(-2,2)*random(), random(2,5), random(-2,2)*random())` under the
#   source's downward gravity (`orb.lua:30`, `movement_gravity` 9.81). Note the
#   vertical draw is a plain integer 2..5 while the horizontal draws are scaled
#   by a float in [0,1).
# * **Acquisition** (`mcl_item_entity/init.lua:10,66-86`): every step, an orb
#   that is not yet collected and lies within 7.25 blocks of the player's
#   collect point (feet + 0.8) is marked collected.
# * **Magnet** (`orb.lua:39-80`): while collected and the collector is alive and
#   within 7.25 blocks of the player's feet, its physics are disabled and it is
#   pulled with velocity `direction * (20 - distance)` plus the player's own
#   velocity, awarding its experience on arrival within 0.8 blocks of the
#   collect point. Between 0.8 and 1.0 blocks the source rewrites neither
#   velocity nor acceleration, so the orb coasts on what it accumulated; a pull
#   therefore overshoots into collection rather than stalling, though a magnet
#   that has never accelerated (an orb claimed while already closer than one
#   block) really does sit still there. When the collector is gone, died, or
#   moved out of range the orb clears its collector and regains its physics.
#   The source calls `disable_physics` before reading its own velocity, and that
#   call only zeroes a velocity it has not already zeroed, so the first
#   magnetised frame pulls from a standstill and every later frame keeps its
#   accumulation. Both orderings are kept.
# * **Slide** (`orb.lua:99-137`): with a walkable node 0.25 below and a slippery
#   group value, a moving orb decelerates horizontally with
#   `slip_factor = 4.0 / (slippery + 4)` (`mcl_core`: ice 3, blue ice 4, which is
#   `DenseMaterials.slippery`); an orb that is neither sliding nor moving stops
#   exactly (zero velocity and acceleration), and the acceleration is rewritten
#   only when the moving/slippery state changes.
# * **Delivery** (`init.lua:99-133`): `add_xp` adds to the player's experience
#   and plays `mcl_experience`, or `mcl_experience_level_up` when the level rose.
#   Voxey keeps experience as the float `game.experience` and derives the level
#   from it (`game.xp_level`), so an award is `game.experience += n` — which is
#   also where `Enchantments.mend` consumes part of it, matching the source's
#   `register_on_add_xp` hook. The two sounds are synthesized by the parent, so
#   `game.sound("orb")` / `game.sound("levelup")` are no-ops until their
#   durations are registered (see PARENT WIRING).
#
# PARENT WIRING (not yet applied; every line below belongs to a file this module
# must not edit):
#
# 1. `scripts/voxel_world.gd`, `_process`, inside the `if active:` block
#    beside `Copper.update(self,delta)`:
#        var orb_owner: Node = get_parent()
#        if orb_owner != null and orb_owner.has_method("playing"): XpOrbs.update(orb_owner,delta)
#    (`XpOrbs.update` needs the game, not the world, because awarding reads
#    `game.experience` and `game.player`.) No other registration is needed: orbs
#    live in `game.entities`, so `game._clear_entities()` already drops them on a
#    new world or a dimension change, exactly as the source's `static_save =
#    false` keeps them out of a save.
# 2. `scripts/game.gd`, `_setup_sounds`: add `"orb":0.15,"levelup":0.4` to the
#    `lengths` dictionary and a `match` branch for each, or both sounds stay
#    silent no-ops. Every sound in `lengths` is keyed by the name the module
#    passes to `game.sound`, so `XpOrbs.PICKUP_SOUND` is `"orb"` and
#    `XpOrbs.LEVEL_SOUND` is `"levelup"`. The two branches the other entries use
#    as their template:
#        "orb": value=sin(t*TAU*(1400.0-t*900.0))*0.35; envelope=minf(t*60.0,1.0)*pow(1.0-progress,2.2)
#        "levelup": value=sin(t*TAU*660.0)*0.3+sin(t*TAU*990.0)*0.25; envelope=minf(t*12.0,1.0)*pow(1.0-progress,1.4)
# 3. `scripts/game.gd`, `die()`, before the death UI, mirroring
#    `mcl_experience`'s `register_on_dieplayer` (`init.lua:240-245`): when
#    `game_rules.keepInventory` is false, throw the player's whole balance and
#    then zero it —
#        if not game_rules.keepInventory:
#            XpOrbs.throw_xp(self,player.position+Vector3.UP,floori(experience))
#            experience = 0
#    The whole balance goes in as the request; the source caps a single *draw*,
#    never the total, so nothing is clamped here. Voxey's `die()` currently keeps
#    experience untouched, so this line is the behaviour change the orb entity
#    exists to enable.
# 4. Award sites that the source routes through an orb, each replacing a direct
#    `experience += n` with a throw at the award's position:
#    - `scripts/game.gd` `break_node`: `Sculk.harvest_xp(...)`, the redstone
#      `2`, and the +1 for deep ores (`mcl_item_entity/init.lua:216-219`).
#    - `scripts/creature.gd:1023`, `scripts/expedition_creature.gd:240`,
#      `scripts/farming.gd:198`, `scripts/village_life.gd:167`,
#      `scripts/dungeons.gd:239` (spawner reward), `scripts/fishing.gd:169`
#      (`mods/ENTITIES/mcl_mobs/physics.lua:279`, `breeding.lua:212`,
#      `mcl_mobspawners/init.lua:291`, `villager.lua:402`,
#      `mcl_fishing/init.lua:144`).
#    - `scripts/thrown_item.gd:55-59` and `scripts/village_survival.gd:98` (the
#      thrown/broken bottle): `HUD/mcl_experience/bottle.lua:17` throws
#      `random(3,11)` at the break position.
#    - `scripts/adventure.gd:120` (dragon, `ender_dragon.lua:224-229`),
#      `scripts/alchemy_world.gd:50`, `scripts/achievements.gd:106`
#      (`mcl_achievements/init.lua:23` throws at the player's position).
#    Direct awards that the source does *not* orbify (anvil, enchanting,
#    grindstone-style payments) stay as they are.

# `orb.lua:1-16`. Each pair is {lower, upper} of the source's ladder; the values
# are the row bounds as written, and the ported lookup compares the lower field.
const LADDER: Array = [[-32768,2],[3,6],[7,16],[17,36],[37,72],[73,148],[149,306],[307,616],
	[617,1236],[1237,2476],[2477,32767]]
# `orb.lua:1-2`: the sprite scale is 20..59 percent of a block.
const SIZE_MIN = 20.0
const SIZE_MAX = 59.0
# `orb.lua:29`: max_orb_age.
const MAX_ORB_AGE = 300.0
# `orb.lua:30`: `movement_gravity` defaults to 9.81.
const GRAVITY = -9.81
# `init.lua:140`: `while i < total_xp and j < 100` — an orb-count cap.
const MAX_ORBS = 100
# `init.lua:141`: the largest value a single draw can reach before the
# remaining request clamps it.
const MAX_ORB_VALUE = 32767
# `mcl_item_entity/init.lua:10-12`.
const MAGNET_RANGE = 7.25
const COLLECT_RANGE = 0.8
const COLLECT_HEIGHT = 0.8
# `orb.lua:66-68`: the pull only starts beyond one block and its speed is
# `20 - distance`.
const PULL_RANGE = 1.0
const PULL_SPEED = 20.0
# `orb.lua:113`: `slip_factor = 4.0 / (slippery + 4)`.
const SLIP_BASE = 4.0
# `orb.lua:99-101`: the node consulted is 0.25 below the orb's centre.
const GROUND_OFFSET = 0.25
# `orb.lua:156`: a 0.4-block collision box centred on the orb's position.
const ORB_HALF = 0.2
const ORB_HEIGHT = 0.4
# The parent's synthesized sound keys for `mcl_experience` and
# `mcl_experience_level_up` (`init.lua:118-127`).
const PICKUP_SOUND = "orb"
const LEVEL_SOUND = "levelup"

static var _material: StandardMaterial3D = null
static var _mesh: SphereMesh = null

# --- the ladder -------------------------------------------------------------

# `xp_to_size` (`orb.lua:18-27`) as a bucket index. The source's loop compares
# `xp` against each pair's lower field, so the returned index is one below the
# table's naive row: value 1 lands on index 1, and index 0 (the `-32768..2` row)
# is only reachable for an amount at or below -32768.
static func orb_for(amount: int) -> int:
	var index: int = 0
	var last: int = LADDER.size()-1
	while amount > int(LADDER[index][0]) and index < last:
		index += 1
	return index

# The source's sprite scale for an amount, in blocks (0.20 .. 0.59).
static func size_for(amount: int) -> float:
	return (float(orb_for(amount))/float(LADDER.size()-1)*(SIZE_MAX-SIZE_MIN)+SIZE_MIN)/100.0

# --- splitting --------------------------------------------------------------

# `mcl_experience.throw_xp`'s loop (`init.lua:137-156`): each orb takes
# `min(random(1, min(32767, total - floor(i/2))), total - i)` and the loop stops
# once the request is covered or 100 orbs have been made. A request never splits
# into more than `MAX_ORBS` values, so a request above 100 * 32767 is truncated
# the way the source truncates it.
static func split(amount: int, rng: RandomNumberGenerator) -> Array:
	var amounts: Array = []
	if amount <= 0: return amounts
	var covered: int = 0
	var count: int = 0
	while covered < amount and count < MAX_ORBS:
		var ceiling: int = maxi(1,mini(MAX_ORB_VALUE,amount-int(floori(covered/2.0))))
		var drawn: int = rng.randi_range(1,ceiling)
		var xp: int = mini(drawn,amount-covered)
		covered += xp
		count += 1
		amounts.append(xp)
	return amounts

# --- spawning ---------------------------------------------------------------

# `mcl_experience.throw_xp` (`init.lua:137-156`). The orbs land in
# `game.entities`, and each is given the source's own throw velocity
# (`init.lua:144-149`), which is drawn per orb rather than per throw.
static func throw_xp(game: Node3D, at: Vector3, amount: int) -> void:
	if amount <= 0 or game == null or not is_instance_valid(game): return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for xp in split(amount,rng): spawn(game,at,int(xp),throw_velocity(rng))

# One orb with the value it is worth. `velocity` defaults to the source's
# activation velocity (`orb.lua:187`), which `throw_xp` overrides with its own
# throw draw.
static func spawn(game: Node3D, at: Vector3, amount: int, velocity: Vector3 = Vector3(0,2,0)) -> Orb:
	if amount <= 0 or game == null or not is_instance_valid(game): return null
	var orb := Orb.new()
	orb.game = game
	orb.xp = amount
	orb.position = at
	orb.velocity = velocity
	orb.acceleration = Vector3(0,GRAVITY,0)
	game.entities.add_child(orb)
	return orb

# The source's throw velocity (`init.lua:144-149`): the horizontal components are
# an integer in -2..2 scaled by a float in [0,1), the vertical one is a plain
# integer in 2..5.
static func throw_velocity(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(rng.randi_range(-2,2)*rng.randf(),rng.randi_range(2,5),rng.randi_range(-2,2)*rng.randf())

# Every live orb, in the order the entity group holds them.
static func orbs(game: Node3D) -> Array:
	if game == null or not is_instance_valid(game) or game.entities == null: return []
	return game.entities.get_children().filter(func(entity): return entity is Orb and not entity.is_queued_for_deletion())

static func orb_count(game: Node3D) -> int:
	return orbs(game).size()

# Removes every orb at once. The source has no equivalent — its orbs simply are
# not saved — so this exists for callers that need to drop only orbs rather than
# every entity (the parent's `_clear_entities` already covers a new world or a
# dimension change), and for the regression checks.
static func clear(game: Node3D) -> void:
	for orb in orbs(game): orb.queue_free()

# --- delivery ---------------------------------------------------------------

# `mcl_experience.add_xp` (`init.lua:99-133`): add to the player's experience and
# play the pickup sound, or the level-up sound when the level rose. The setter on
# `game.experience` is the parent's `on_add_xp` hook, so `Enchantments.mend` sees
# the award exactly as it does in the source.
static func award(game: Node3D, amount: int) -> void:
	if amount <= 0 or game == null or not is_instance_valid(game): return
	var before: int = game.xp_level()
	game.experience += float(amount)
	game.sound(LEVEL_SOUND if game.xp_level() != before else PICKUP_SOUND)

# --- simulation -------------------------------------------------------------

# Steps every orb. Registered by the parent in `VoxelWorld._process` (see PARENT
# WIRING), so orbs freeze with the rest of the world when the game is paused.
static func update(game: Node3D, delta: float) -> void:
	if delta <= 0.0 or game == null or not is_instance_valid(game): return
	if game.world == null: return
	for orb in orbs(game): orb.step(delta)

# One experience orb: the source's `mcl_experience:orb` entity (`orb.lua:151-222`).
class Orb extends Node3D:
	var game: Node3D
	var xp: int = 1
	var velocity := Vector3.ZERO
	var acceleration := Vector3.ZERO
	var age: float = 0.0
	# The source's `collected`/`collector` pair, collapsed: this is a
	# single-player game, so the only possible collector is the player.
	var collected: bool = false
	# `orb.lua:168-171`: the entity starts physical and moving.
	var physical_state: bool = true
	var moving_state: bool = true
	var slippery_state: bool = false

	func _ready() -> void:
		var size: float = XpOrbs.size_for(xp)
		var mesh_instance := MeshInstance3D.new()
		if XpOrbs._mesh == null:
			# One sphere serves every orb: the source's sprite is a single image
			# and only its scale differs.
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 8
			sphere.rings = 4
			XpOrbs._mesh = sphere
		mesh_instance.mesh = XpOrbs._mesh
		if XpOrbs._material == null:
			# The source's sprite carries `glow = 14` (`orb.lua:196`), so the orb
			# is lit by its own emission rather than by the world.
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("9ad964")
			material.emission_enabled = true
			material.emission = Color("9ad964")
			material.emission_energy_multiplier = 1.4
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			XpOrbs._material = material
		mesh_instance.material_override = XpOrbs._material
		mesh_instance.scale = Vector3.ONE*size
		add_child(mesh_instance)

	# `orb.lua:201-208`.
	func enable_physics() -> void:
		if not physical_state:
			physical_state = true
			velocity = Vector3.ZERO
			acceleration = Vector3(0,XpOrbs.GRAVITY,0)

	# `orb.lua:210-218`.
	func disable_physics() -> void:
		if physical_state:
			physical_state = false
			velocity = Vector3.ZERO
			acceleration = Vector3.ZERO

	func step(delta: float) -> void:
		var world: VoxelWorld = game.world
		var player: Node3D = game.player
		var alive: bool = is_instance_valid(player) and player.health > 0
		# `mcl_item_entity/init.lua:66-86`: an uncollected orb inside the magnet
		# radius of the player's collect point is claimed.
		if not collected and alive and position.distance_to(player.position+Vector3.UP*XpOrbs.COLLECT_HEIGHT) < XpOrbs.MAGNET_RANGE:
			collected = true
		if collected:
			# `orb.lua:40-79`. The range test uses the collector's feet, while the
			# pull target is 0.8 above them, exactly as the source has it.
			if alive and position.distance_to(player.position) < XpOrbs.MAGNET_RANGE:
				acceleration = Vector3.ZERO
				disable_physics()
				# `orb.lua:62-64`: the source reads its own velocity *after*
				# `disable_physics`, so the first magnetised frame starts at rest.
				var target: Vector3 = player.position+Vector3.UP*XpOrbs.COLLECT_HEIGHT
				var distance: float = position.distance_to(target)
				var direction: Vector3 = (target-position).normalized()
				if distance > XpOrbs.PULL_RANGE:
					var goal: Vector3 = direction*(XpOrbs.PULL_SPEED-distance)
					velocity += (goal-velocity)+player.velocity
				elif distance < XpOrbs.COLLECT_RANGE:
					XpOrbs.award(game,xp)
					queue_free()
					return
				# Between the two, the source changes nothing and lets the orb's
				# existing velocity carry it through, which is why the band is a
				# single frame rather than a stall.
				_advance(world,velocity*delta)
				return
			# The collector vanished, died, or left: the orb regains its physics
			# and continues its own life (`orb.lua:75-78`).
			collected = false
			enable_physics()
		age += delta
		if age > XpOrbs.MAX_ORB_AGE:
			queue_free()
			return
		# `orb.lua:93-97`: the source removes an orb whose node is in "ignore",
		# which is Voxey's unloaded column. Orbs are never persisted.
		if not world.loaded_at(position):
			queue_free()
			return
		if not physical_state:
			return
		# `orb.lua:99-137`: slide on slippery nodes, and rest when still.
		var ground: Vector3i = Vector3i(floori(position.x),floori(position.y-XpOrbs.GROUND_OFFSET),floori(position.z))
		var walkable: bool = Nodes.solid(world.node_at(ground))
		var moving: bool = not walkable or velocity != Vector3.ZERO
		var slippery_node: bool = false
		if walkable:
			var slippery: int = DenseMaterials.slippery(world.node_at(ground))
			slippery_node = slippery != 0
			if slippery_node and (absf(velocity.x) > 0.2 or absf(velocity.z) > 0.2):
				var slip_factor: float = XpOrbs.SLIP_BASE/float(slippery+XpOrbs.SLIP_BASE)
				acceleration = Vector3(-velocity.x*slip_factor,0.0,-velocity.z*slip_factor)
			elif velocity.y == 0.0:
				moving = false
		# The source leaves the acceleration alone until the state changes, which
		# is what lets a slide keep decelerating frame after frame.
		if moving_state != moving or slippery_state != slippery_node:
			moving_state = moving
			slippery_state = slippery_node
			if moving:
				acceleration = Vector3(0,XpOrbs.GRAVITY,0)
			else:
				acceleration = Vector3.ZERO
				velocity = Vector3.ZERO
		_advance(world,velocity*delta+acceleration*delta*delta*0.5)
		velocity += acceleration*delta

	# Luanti integrates a physical entity and resolves its collisions; Voxey has
	# no such pass for entities, so the motion is swept in small steps here. A
	# downward hit snaps the orb onto the node it hit, which is what makes the
	# source's `pos.y - 0.25` lookup find a walkable node and the orb rest.
	func _advance(world: VoxelWorld, motion: Vector3) -> void:
		if motion == Vector3.ZERO: return
		var steps: int = maxi(1,ceili(motion.length()/0.25))
		var step: Vector3 = motion/steps
		for index in steps:
			var feet: Vector3 = position-Vector3.UP*(XpOrbs.ORB_HEIGHT*0.5)
			var horizontal := Vector3(step.x,0.0,step.z)
			if horizontal != Vector3.ZERO:
				if not world.intersects(feet+horizontal,XpOrbs.ORB_HALF,XpOrbs.ORB_HEIGHT):
					position += horizontal
				else:
					velocity.x = 0.0
					velocity.z = 0.0
			if step.y != 0.0:
				if not world.intersects(feet+Vector3.UP*step.y,XpOrbs.ORB_HALF,XpOrbs.ORB_HEIGHT):
					position.y += step.y
				else:
					if step.y < 0.0:
						position.y = float(floori(position.y-XpOrbs.ORB_HEIGHT*0.5+step.y))+1.0+XpOrbs.ORB_HEIGHT*0.5
					velocity.y = 0.0

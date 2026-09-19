class_name ZombieVillagers
extends RefCounted

# Mineclonia ENTITIES/mobs_mc/villager_zombie.lua, GPL-3.0-or-later. Original
# GDScript using the source as a behaviour reference.
#
# A zombie villager is a zombie that can be **cured back into a villager**, which
# is the source's most famous villager mechanic. The rule is precise:
#
#   1. The zombie villager must be suffering **weakness**. Without it, nothing
#      happens — feeding a golden apple to a healthy one does nothing.
#   2. Right-clicking with a **golden apple** consumes the apple, clears the
#      weakness and any strength, and starts a cure timer of **3 to 5 minutes**.
#   3. While curing, the creature **shakes**. When the timer ends it becomes a
#      plain villager, and the player who cured it earns a large trade discount
#      (the source records a major and a minor positive gossip against them).
#
# The igloo's basement is where the source puts a zombie villager beside a real
# one, with the brewing stand needed to make the weakness potion and the golden
# apple — a complete cure puzzle inside a snow hut.
#
# The creature is a zombie variant here rather than a class of its own, because
# everything about it except the cure is the zombie: same health, same speed, same
# daylight burning.

const KIND = "zombie_villager"
# Source `_curing = math.random(3 * 60, 5 * 60)`, in seconds.
const CURE_MIN = 180.0
const CURE_MAX = 300.0
# The source's cure grants a major and a minor positive gossip against the curer.
const MAJOR_GOSSIP = 20
const MINOR_GOSSIP = 25

static func is_zombie_villager(kind: String) -> bool: return kind == KIND

# Whether a cure can start: the source needs an apple *and* active weakness.
static func can_cure(mob: Creature, held: int) -> bool:
	if not is_zombie_villager(mob.kind): return false
	if held != Nodes.GOLDEN_APPLE: return false
	if bool(mob.get_meta("curing",false)): return false
	return PotionEffects.level(mob,"weakness") > 0

# Begin the cure. The source clears weakness *and* strength, spends the apple
# unless the player is in creative, and fixes a cure time of three to five
# minutes.
static func begin(game: Node3D, mob: Creature, rng: RandomNumberGenerator) -> bool:
	if bool(mob.get_meta("curing",false)): return false
	PotionEffects.clear_one(mob,"weakness")
	PotionEffects.clear_one(mob,"strength")
	# Source grants strength at a level scaled by difficulty; the base level is used,
	# which is what the source gives on its easiest setting.
	PotionEffects.apply(mob,"strength",INF,1)
	mob.set_meta("curing",true)
	mob.set_meta("cure_timer",rng.randf_range(CURE_MIN,CURE_MAX))
	mob.set_meta("curer",game.player_id)
	# A curing zombie villager must not despawn, which the source sets explicitly.
	mob.set_meta("persistent",true)
	game.sound_at("zombie",mob.position,0.6)
	return true

# The source's `zombie_types`, which is the set of killers that can infect a
# villager. A zombie villager can itself infect a villager, which is why it is in
# the list.
const INFECTING_KINDS = ["zombie","zombie_villager","husk"]

# Whether a death at `from` should infect rather than bury a villager. The source
# gates this on difficulty and, below the hardest setting, a coin flip:
#
#     difficulty >= 2 and (difficulty > 2 or pr:next(1,2) == 1)
#
# `from` is the position the killing blow came from, so the killer is whoever is
# standing there. A non-zombie killer, or a player kill, never infects.
static func can_infect(game: Node3D, from: Vector3) -> bool:
	if is_inf(from.x): return false
	if game.difficulty < 2: return false
	if game.difficulty <= 2 and randi_range(1,2) != 1: return false
	for mob in game.creatures.get_children():
		if mob is Creature and not mob.is_queued_for_deletion() and mob.kind in INFECTING_KINDS and mob.position.distance_to(from) < 1.5:
			return true
	return false

# Mark a freshly infected zombie villager as carrying `record`, the villager it
# used to be. The source stores this as `_previous_incarnation` and restores it on
# cure, so the villager that comes back is the *same* one - same profession, same
# trades, same home - rather than a stranger with the same name.
static func infect(game: Node3D, mob: Creature, record: Dictionary) -> void:
	mob.set_meta("incarnation",record.duplicate(true))
	mob.set_meta("persistent",true)
	game.puff(mob.center(),Color("6f8f6a"),16)

# Advance an in-progress cure and, when the timer runs out, replace the zombie
# with a villager and grant the curer their discount.
static func update(game: Node3D, mob: Creature, delta: float) -> void:
	if not is_zombie_villager(mob.kind): return
	if not bool(mob.get_meta("curing",false)):
		# The source shakes the creature while it cures, which is its only visual.
		return
	var remaining: float = float(mob.get_meta("cure_timer",0.0))-delta
	mob.set_meta("cure_timer",remaining)
	# The source's shaking is a small periodic offset.
	var shake: float = sin(float(Time.get_ticks_msec())*0.02)*0.06
	mob.position.x += shake
	if remaining > 0.0: return
	# The cure completes: a villager takes the zombie's place.
	var at: Vector3 = mob.position
	var curer: String = String(mob.get_meta("curer",""))
	var incarnation: Dictionary = mob.get_meta("incarnation",{})
	Farming.forget(mob)
	mob.queue_free()
	var villager: Creature = game.spawn_creature("villager",at)
	# An infected villager is restored to the one it was: the source keeps
	# `_previous_incarnation` for exactly this, so the profession, trades and home
	# survive the whole zombie-and-back round trip.
	if villager is VillageMob and not incarnation.is_empty():
		var restored: VillageMob = villager
		var people: Dictionary = game.villages.state().people
		# `spawn_creature` gives a fresh villager a fresh record, which would leave
		# the original still marked dead. The incarnation takes its own key back and
		# the placeholder record is dropped, so the village holds one record for this
		# villager rather than two.
		var original_key: String = str(incarnation.get("key",restored.person_key))
		if original_key != restored.person_key: people.erase(restored.person_key)
		incarnation.dead = false; incarnation.health = 20.0
		incarnation.position = [at.x,at.y,at.z]
		people[original_key] = incarnation
		restored.person_key = original_key
		restored.bind(incarnation)
	if villager != null and not curer.is_empty():
		# The source records a major and a minor positive gossip, which is what
		# makes a cured villager trade cheaply for the player who cured it.
		villager.set_meta("gossip_"+curer,{"major":MAJOR_GOSSIP,"minor":MINOR_GOSSIP})
		game.achievements.award("zombie_doctor")

class_name VillageGolems
extends RefCounted

# Mineclonia `ENTITIES/mobs_mc/villager.lua`: `summon_golem` (:3431-3458),
# `maybe_summon_golem` (:3463-3484), `desires_golem`/`slept_recently_enough_for_golem`
# (:3423-3429) and the two call sites — the panic branch (:3490) and the ordinary
# one (:5901). GPL-3.0-or-later. Original GDScript using the source as a
# behaviour reference.
#
# A village in the reference **grows its own defender**. The rule is:
#
#   * A villager wants a golem only if it has **slept within the last 1200 game
#     seconds** and has **not seen a golem within the last 30**.
#   * A **panicking** villager (one whose village is under attack) asks every five
#     seconds and needs **three** other villagers nearby who also want one; an
#     ordinary villager needs **five**.
#   * The summon searches an 17×11×17 box around the villager for a solid or water
#     cell with a solid block beneath and **twelve** air cells above it (the golem's
#     2×3×2 clearance at half-block offsets), shuffles the candidates, and spawns in
#     the first that fits. A water surface places the golem one node lower.
#   * Every villager who wanted one records the time, which is what the 30-second
#     "seen a golem lately" test then reads.
#
# Voxey already gives each village one golem at generation, but has neither the
# summon nor the sleep record. The sleep half is derived from the day cycle: a
# villager has slept when the village has been through a night since the record was
# written, which is `day_number()`'s own bookkeeping.

# `gmt - self._last_slept_gmt < 1200`: the window in which a villager may request.
const SLEEP_WINDOW = 1200.0
# `gmt - self._last_golem_gmt < 30`: the cooldown after a golem is seen or made.
const GOLEM_COOLDOWN = 30.0
# `self:check_timer("golem_summon", 5.0)`.
const SUMMON_INTERVAL = 5.0
# The panic branch needs three villagers, the ordinary branch five.
const PANIC_REQUESTERS = 3
const CALM_REQUESTERS = 5
# `sense_villagers_requesting_golem` sweeps `pos ± (10,10,10)`, and the count it
# returns **includes the villager doing the asking**, so the thresholds below are
# totals rather than "neighbours besides me".
const REQUEST_BOX = Vector3i(10,10,10)
# `find_nodes_in_area_under_air(pos ± (8,5,8))`.
const SEARCH = Vector3i(8,5,8)
# `required_air = 2*3*2`.
const REQUIRED_AIR = 12

# `desires_golem`: has slept within the window and has not seen a golem recently.
# `slept_at` and `saw_golem_at` are the village clock values the caller tracks, both
# defaulting to "never" as the source's `_last_golem_gmt = 0` does.
static func desires(clock: float, slept_at: float, saw_golem_at: float) -> bool:
	return slept_at > 0.0 and clock-slept_at < SLEEP_WINDOW and clock-saw_golem_at >= GOLEM_COOLDOWN

# `maybe_summon_golem`: the villager's own request. Returns whether a golem was made,
# so the caller can stamp every requester with the time.
static func maybe_summon(game: Node3D, mob: Creature, panicking: bool) -> bool:
	var clock: float = game.day_number()*1200.0+game.day_time*1200.0
	var record: Dictionary = game.villages.record(mob.person_key) if mob is VillageMob else {}
	if record.is_empty() or not desires(clock,float(record.get("slept_at",0.0)),float(record.get("saw_golem_at",0.0))): return false
	var needed: int = PANIC_REQUESTERS if panicking else CALM_REQUESTERS
	# The asking villager counts itself, as the source's sensor does.
	var requesters: Array = [record]
	for other in game.creatures.get_children():
		if other == mob or other.is_queued_for_deletion(): continue
		if not other is VillageMob or other.person_key == mob.person_key: continue
		var offset: Vector3 = other.position-mob.position
		if absf(offset.x) > REQUEST_BOX.x or absf(offset.y) > REQUEST_BOX.y or absf(offset.z) > REQUEST_BOX.z: continue
		var person: Dictionary = game.villages.record(other.person_key)
		if person.is_empty(): continue
		if not desires(clock,float(person.get("slept_at",0.0)),float(person.get("saw_golem_at",0.0))): continue
		requesters.append(person)
	if requesters.size() < needed: return false
	var spot: Vector3 = find_spot(game.world,mob.position)
	if not spot.is_finite(): return false
	var golem: Creature = game.spawn_creature("iron_golem",spot)
	if golem == null: return false
	# The source stamps every requester, which is what makes the 30-second cooldown
	# village-wide rather than per villager.
	for person in requesters: person["saw_golem_at"] = clock
	record["saw_golem_at"] = clock
	return true

# `summon_golem`: shuffle the candidates and take the first with a solid block beneath
# and the golem's clearance above. A water surface places it one node lower.
static func find_spot(world: VoxelWorld, near: Vector3) -> Vector3:
	var center := Vector3i(near.floor())
	var candidates: Array = []
	for dy in range(-SEARCH.y,SEARCH.y+1):
		for dx in range(-SEARCH.x,SEARCH.x+1):
			for dz in range(-SEARCH.z,SEARCH.z+1):
				var cell: Vector3i = center+Vector3i(dx,dy,dz)
				if not world.loaded_at(Vector3(cell)): continue
				var id: int = world.node_at(cell)
				if not (Nodes.solid(id) or Fluids.water(id)): continue
				if not Nodes.solid(world.node_at(cell+Vector3i.DOWN)): continue
				# `required_air = 2*3*2`: the 2x3x2 body space above the cell.
				var air: int = 0
				for ay in range(1,4):
					for ax in [-1,0]:
						for az in [-1,0]:
							if world.node_at(cell+Vector3i(ax,ay,az)) == Nodes.AIR: air += 1
				if air < REQUIRED_AIR: continue
				candidates.append(cell)
	if candidates.is_empty(): return Vector3.INF
	# `table.shuffle(nn)`: the source takes a random candidate, not the nearest.
	var chosen: Vector3i = candidates[randi()%candidates.size()]
	var spot: Vector3 = Vector3(chosen)+Vector3(0.5,1.0,0.5)
	# A water surface places the golem one node lower, as the source's own offset does.
	if Fluids.water(world.node_at(chosen)): spot.y -= 1.0
	return spot

# The per-villager clock the panic and ordinary branches run on. Returns whether a
# golem was summoned, so the caller can report it.
static func step(game: Node3D, mob: Creature, panicking: bool, delta: float) -> bool:
	if not mob is VillageMob: return false
	var record: Dictionary = game.villages.record(mob.person_key)
	if record.is_empty(): return false
	var timer: float = float(record.get("golem_timer",0.0))+delta
	if timer < SUMMON_INTERVAL:
		record["golem_timer"] = timer
		return false
	record["golem_timer"] = 0.0
	return maybe_summon(game,mob,panicking)

# Whether anything hostile is close enough to make the village panic, which is the
# source's `seen_hostile_lately`. The reference checks a mob's own sight; Voxey reads
# the same distance and hostility the rest of its village code uses.
static func hostile_near(game: Node3D, at: Vector3, radius: float = 12.0) -> bool:
	for mob in game.creatures.get_children():
		if mob.is_queued_for_deletion() or mob.health <= 0 or not mob.hostile: continue
		if mob.position.distance_to(at) <= radius: return true
	return false

# `villager.lua`:2565-2573: the gossip a trade triggers, and the **ordinary** golem
# request that fires at the same moment. The source copies the speaker's reputations
# to every villager within ten blocks — which is what makes curing one villager raise
# the whole village's opinion of the player — and then asks for a golem with the
# calm threshold of five.
#
# Voxey already keeps reputations per villager keyed by player, so the copy is the
# same operation. Returns whether a golem was summoned.
static func gossip(game: Node3D, speaker: Dictionary, near: Vector3) -> bool:
	var village_key: String = str(speaker.get("key",""))
	var gossip: Dictionary = speaker.get("reputations",{}).duplicate(true)
	for person in game.villages.state().people.values():
		if person == speaker or not person is Dictionary or person.get("dead",false): continue
		var position: Array = person.get("position",[])
		if position.size() != 3: continue
		var at := Vector3(float(position[0]),float(position[1]),float(position[2]))
		if at.distance_to(near) > GOSSIP_RADIUS: continue
		var other: Dictionary = person.get("reputations",{})
		for player in gossip:
			var heard: int = int(gossip[player])
			# `copy_gossips` does `self_gossip[type] = min(max(value - transfer_decay,
			# self_value), max_value)` — a per-type **magnitude** that only ever grows
			# to the value being repeated. `evaluate_player_reputation` then sums
			# `gossip * rep_multiplier` across types, so a villager's standing is
			# positives minus negatives and hearing good news *does* raise a hostile
			# villager — it simply does not cancel the grudge.
			#
			# Voxey keeps one signed net rather than the source's typed buckets, so the
			# buckets are reconstructed minimally: what is not positive is negative.
			# That reproduces the source's arithmetic exactly for the two types this
			# model covers (`trading` and `minor_negative`), which is what the checks
			# pin.
			var decayed: int = signi(heard)*maxi(absi(heard)-GOSSIP_TRANSFER_DECAY,0)
			var existing: int = int(other.get(player,0))
			var positive: int = maxi(existing,0)
			var negative: int = maxi(-existing,0)
			other[player] = maxi(positive,decayed)-negative if decayed >= 0 else positive-maxi(negative,-decayed)
		person["reputations"] = other
	# The ordinary branch's own request, on the same five-second timer.
	if not village_key.is_empty():
		for mob in game.creatures.get_children():
			if mob is VillageMob and not mob.is_queued_for_deletion() and not mob.hostile and mob.person_key == speaker.get("key",""):
				return step(game,mob,false,SUMMON_INTERVAL)
	return false

# `sense_villagers_requesting_golem`'s ten-block sweep, used for the gossip radius too.
const GOSSIP_RADIUS = 10.0
# `gossip_types`' `transfer_decay` for the two types Voxey's model covers: `trading`
# and `minor_negative` both decay by 20 as the story travels.
const GOSSIP_TRANSFER_DECAY = 20

# `_last_slept_gmt`: stamp every village resident when the village passes a night.
# `VillageLife.update` calls this once per new day, which is the same information the
# source keeps from its bed interactions.
static func mark_slept(game: Node3D, village_key: String) -> void:
	var clock: float = game.day_number()*1200.0+game.day_time*1200.0
	for person in game.villages.state().people.values():
		if not person is Dictionary: continue
		var center: Array = person.get("center",[])
		var key: String = str(person.get("key",""))
		# A resident's key is `<village key>/<profession>`, so the village is the
		# prefix the generator wrote.
		if not village_key.is_empty() and not key.begins_with(village_key): continue
		person["slept_at"] = clock

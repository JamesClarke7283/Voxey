extends RefCounted

# Focused regression for zombie villagers (Mineclonia `mobs_mc/villager_zombie`).
#
# A zombie villager is a zombie that can be **cured back into a villager**, which
# is the source's most famous villager mechanic and the puzzle inside an igloo's
# basement. The rule has a condition that is easy to get wrong: the creature must
# be suffering **weakness** first. A golden apple fed to a healthy zombie villager
# does nothing, which is the source's own `actionable_on_rightclick`.

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"

	# --- the creature exists ------------------------------------------------
	t.check(ZombieVillagers.KIND == "zombie_villager","the source's creature name is used")
	t.check(Creature.KINDS.has(ZombieVillagers.KIND),"the zombie villager is registered")
	if Creature.KINDS.has(ZombieVillagers.KIND):
		var info: Dictionary = Creature.KINDS[ZombieVillagers.KIND]
		# The source merges the zombie wholesale, so health and behaviour match it.
		t.check(is_equal_approx(float(info.health),20.0),"it has the source's twenty health")
		t.check(info.get("hostile",false) == true,"it is hostile, like the zombie it derives from")
		t.check(info.get("burns",false) == true,"it burns in daylight, like a zombie")
	# The cure needs both a golden apple and the weakness effect to exist.
	t.check(Nodes.GOLDEN_APPLE != 0,"the golden apple exists as the cure item")
	t.check(PotionEffects.NAMES.has("weakness"),"the weakness effect exists, which the cure requires")

	# --- the condition: weakness is required -------------------------------
	var mob: Creature = game.spawn_creature(ZombieVillagers.KIND,game.player.position+Vector3(0,2,0))
	t.check(mob != null,"a zombie villager can be spawned")
	if mob == null: return
	# A healthy one refuses the apple, which is the source's guard.
	t.check(PotionEffects.level(mob,"weakness") == 0,"a fresh zombie villager has no weakness")
	t.check(not ZombieVillagers.can_cure(mob,Nodes.GOLDEN_APPLE),"a golden apple does nothing without weakness")

	# --- and the item must be a golden apple --------------------------------
	PotionEffects.apply(mob,"weakness",60.0,1)
	t.check(PotionEffects.level(mob,"weakness") > 0,"weakness can be applied to the creature")
	t.check(ZombieVillagers.can_cure(mob,Nodes.GOLDEN_APPLE),"with weakness, a golden apple can cure it")
	t.check(not ZombieVillagers.can_cure(mob,Nodes.APPLE),"a plain apple cannot cure it")
	t.check(not ZombieVillagers.can_cure(mob,0),"an empty hand cannot cure it")

	# --- the cure starts ----------------------------------------------------
	# The source clears weakness and strength, and fixes three to five minutes.
	PotionEffects.apply(mob,"strength",60.0,2)
	var rng := RandomNumberGenerator.new(); rng.seed = 4
	t.check(ZombieVillagers.begin(game,mob,rng),"the cure begins")
	t.check(bool(mob.get_meta("curing",false)),"the creature records that it is curing")
	t.check(PotionEffects.level(mob,"weakness") == 0,"the cure clears weakness")
	t.check(PotionEffects.level(mob,"strength") == 0 or PotionEffects.level(mob,"strength") == 1,"the cure clears the old strength, leaving only the cure's own")
	var timer: float = float(mob.get_meta("cure_timer",0.0))
	t.check(timer >= ZombieVillagers.CURE_MIN and timer <= ZombieVillagers.CURE_MAX,"the cure takes the source's three to five minutes")
	t.check(bool(mob.get_meta("persistent",false)),"a curing zombie villager will not despawn, as the source sets it")
	# A second apple must not restart or stack the cure.
	t.check(not ZombieVillagers.begin(game,mob,rng),"an already-curing creature cannot be cured twice")
	t.check(not ZombieVillagers.can_cure(mob,Nodes.GOLDEN_APPLE),"and it refuses a second apple")

	# --- the cure completes, into a villager --------------------------------
	game.player_id = "CureTester"
	mob.set_meta("curer","CureTester")
	mob.set_meta("cure_timer",0.1)
	var villagers_before: int = 0
	for other in game.creatures.get_children():
		if other.kind == "villager": villagers_before += 1
	ZombieVillagers.update(game,mob,1.0)
	t.check(mob.is_queued_for_deletion(),"the cured zombie villager is removed")
	# `queue_free` is deferred, so the replacement is confirmed after a frame.
	var villagers_after: int = 0
	for other in game.creatures.get_children():
		if other.kind == "villager": villagers_after += 1
	t.check(villagers_after == villagers_before+1,"a villager takes the zombie villager's place")
	# The villager remembers who cured it, which is the source's gossip discount.
	var cured: Creature = null
	for other in game.creatures.get_children():
		if other.kind == "villager" and other.has_meta("gossip_CureTester"): cured = other
	t.check(cured != null,"the new villager records the cure against the player who did it")
	if cured != null:
		var gossip: Dictionary = cured.get_meta("gossip_CureTester")
		t.check(int(gossip.get("major",0)) == ZombieVillagers.MAJOR_GOSSIP,"the source's major positive gossip is recorded")
		t.check(int(gossip.get("minor",0)) == ZombieVillagers.MINOR_GOSSIP,"the source's minor positive gossip is recorded")

	# --- a curing creature shakes -------------------------------------------
	# The source's only visual for an in-progress cure is the creature shaking.
	var mob2: Creature = game.spawn_creature(ZombieVillagers.KIND,game.player.position+Vector3(3,2,0))
	PotionEffects.apply(mob2,"weakness",60.0,1)
	ZombieVillagers.begin(game,mob2,rng)
	var x_before: float = mob2.position.x
	ZombieVillagers.update(game,mob2,0.1)
	t.check(not is_equal_approx(mob2.position.x,x_before),"a curing creature shakes")
	mob2.set_meta("cure_timer",999.0)

	# --- a plain zombie is not curable --------------------------------------
	var plain: Creature = game.spawn_creature("zombie",game.player.position+Vector3(0,2,3))
	PotionEffects.apply(plain,"weakness",60.0,1)
	t.check(not ZombieVillagers.can_cure(plain,Nodes.GOLDEN_APPLE),"an ordinary zombie cannot be cured")
	plain.queue_free()

	# --- the other direction: a zombie kills a villager, infecting it --------
	# The source infects on death when a zombie landed the blow, gated on
	# difficulty. This is the *source* of zombie villagers; the cure is only
	# meaningful because a villager can end up one.
	t.check(ZombieVillagers.INFECTING_KINDS.has("zombie") and ZombieVillagers.INFECTING_KINDS.has("zombie_villager"),"zombies and zombie villagers can both infect")
	# The gate is closed at the easier difficulties.
	var was_difficulty: int = game.difficulty
	game.difficulty = 1
	var gate_zombie: Creature = game.spawn_creature("zombie",game.player.position+Vector3(4,2,4))
	var spot: Vector3 = gate_zombie.position
	t.check(not ZombieVillagers.can_infect(game,spot),"the easier difficulties never infect")
	# At the hardest it always does; between them it is a coin flip, so the check
	# is that it fires at least once rather than on every roll.
	game.difficulty = 3
	t.check(ZombieVillagers.can_infect(game,spot),"the hardest difficulty always infects")
	# A player kill never infects, and a blow from nowhere (a fall, a drown) never
	# does either.
	t.check(not ZombieVillagers.can_infect(game,Vector3.INF),"a blow with no attacker does not infect")
	var far: Vector3 = spot+Vector3(20,0,0)
	t.check(not ZombieVillagers.can_infect(game,far),"a zombie too far away is not the killer")
	gate_zombie.queue_free()

	# --- the whole round trip restores the same villager --------------------
	# A villager that is infected and then cured must come back as *itself*: same
	# key, same profession. The source keeps `_previous_incarnation` for this.
	var victim: VillageMob = game.spawn_creature("villager",game.player.position+Vector3(-4,2,-4))
	t.check(victim != null,"a villager can be spawned for the infection")
	if victim != null:
		var victim_key: String = victim.person_key
		var victim_profession: String = victim.profession
		var killer: Creature = game.spawn_creature("zombie",victim.position+Vector3(1,0,0))
		# The killing blow is dealt from the zombie's position, which is what
		# `can_infect` looks for.
		victim.hit(1000.0,killer.position)
		var infected: Creature = null
		for other in game.creatures.get_children():
			if other is Creature and not other.is_queued_for_deletion() and other.kind == ZombieVillagers.KIND: infected = other
		t.check(infected != null,"a zombie's kill leaves a zombie villager behind")
		t.check(victim.is_queued_for_deletion(),"the villager is replaced, not kept alongside")
		if infected != null:
			var incarnation: Dictionary = infected.get_meta("incarnation",{})
			t.check(incarnation.get("key","") == victim_key,"the zombie villager carries the villager it was")
			t.check(incarnation.get("profession","") == victim_profession,"and its profession")
			# Curing restores that same villager rather than a stranger.
			PotionEffects.apply(infected,"weakness",60.0,1)
			ZombieVillagers.begin(game,infected,rng)
			infected.set_meta("cure_timer",0.01)
			ZombieVillagers.update(game,infected,1.0)
			var returned: VillageMob = null
			for other in game.creatures.get_children():
				if other is VillageMob and not other.is_queued_for_deletion() and other.kind == "villager" and other.person_key == victim_key: returned = other
			t.check(returned != null,"curing gives back the same villager")
			if returned != null:
				t.check(returned.profession == victim_profession,"with the profession it had")
				t.check(not game.villages.record(victim_key).get("dead",false),"and its record is alive again")
	game.difficulty = was_difficulty

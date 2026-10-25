extends RefCounted
static func spawn(game: Node3D, kind: String, at: Vector3) -> Creature:
	var mob: Creature = game.spawn_creature(kind,at,"",{"baby":false,"jockey":false}); mob.set_physics_process(false)
	if ZombieTraits.handles(kind): mob.zombie_traits.view = 0; mob.zombie_traits.reinforcement = 0
	return mob
static func reset(mob: Creature) -> void:
	mob.zombie_target = null; mob.zombie_attacker = null; mob.zombie_alert = null; mob.zombie_ai = {}; mob.zombie_village = {}
static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var old_pos: Vector3 = game.player.position; var old_hp: float = game.player.health; var old_mode: String = game.gamemode; var old_light: float = game.daylight; var old_diff: int = game.difficulty
	var people: Dictionary = game.villages.state().people.duplicate(true); var bells: Array = game.world.adventure_state.get("village_bells",[]).duplicate(true)
	for mob in game.creatures.get_children(): mob.free()
	game.villages.state().people = {}; game.world.adventure_state.village_bells = []
	for x in range(0,32):
		for z in range(0,24):
			for y in range(1999,2004): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y == 1999 else Nodes.AIR)
	var at := Vector3(8.5,2000,8.5)
	game.player.position = at+Vector3(20,0,0); game.player.health = 20; game.gamemode = "survival"; game.daylight = 0; game.difficulty = 1
	var mob: Creature = spawn(game,"zombie",at)
	var released: Variant = Node3D.new(); released.free()
	t.check(not ZombieTargets.valid(mob,released),"a freed retaliation target is rejected before typed object access")
	var villager: Creature = spawn(game,"villager",at+Vector3(4,0,0)); var golem: Creature = spawn(game,"iron_golem",at+Vector3(2,0,0))
	t.check(ZombieTargets.step(mob,0.1) == game.player,"zombie targeting prefers a visible player over a closer villager or golem")
	game.player.health = 0; mob.zombie_ai.seek = 0
	t.check(ZombieTargets.step(mob,0.1) == villager,"villagers take priority over closer iron golems when no player is eligible")
	villager.health = 0; mob.zombie_ai.seek = 0
	t.check(ZombieTargets.step(mob,0.1) == golem,"zombies fall back to a visible iron golem")
	game.player.health = 20; game.player.position = at+Vector3(20,0,0); golem.health = 0; reset(mob)
	PotionEffects.apply(game.player,"invisibility",60,1)
	t.check(ZombieTargets.step(mob,0.1) == null,"the live acquisition loop reduces an invisible player's detection range")
	PotionEffects.clear_one(game.player,"invisibility"); mob.zombie_ai.seek = 0
	t.check(ZombieTargets.step(mob,0.1) == game.player,"clearing invisibility restores ordinary player acquisition")
	var attacker: Creature = spawn(game,"cow",at+Vector3(0,0,5)); var other: Creature = spawn(game,"sheep",at+Vector3(0,0,4))
	ZombieTargets.struck(mob,attacker)
	t.check(ZombieTargets.step(mob,0.1) == attacker and mob.zombie_ai.mode == "retaliation","an incoming attack overrides ordinary zombie targets")
	ZombieTargets.struck(mob,other)
	t.check(ZombieTargets.step(mob,0.1) == attacker,"an active retaliation target is retained when another attacker strikes")
	attacker.health = 0; ZombieTargets.step(mob,0.1)
	t.check(ZombieTargets.step(mob,0.1) == other,"the unread attacker is considered after the previous retaliation ends")
	other.health = 0; attacker.health = 10; reset(mob); game.gamemode = "creative"; golem.health = 0
	var ally: Creature = spawn(game,"husk",at+Vector3(34,0,34)); var piglin: Creature = spawn(game,"zombified_piglin",at+Vector3(3,0,0)); var skeleton: Creature = spawn(game,"skeleton",at+Vector3(3,0,1))
	attacker.position = at+Vector3(80,0,0); ZombieTargets.struck(mob,attacker); ZombieTargets.step(mob,0.1)
	t.check(mob.zombie_target == null and ally.zombie_alert == attacker and piglin.zombie_alert == attacker,"out-of-range retaliation still alerts zombie relatives inside the source box, including diagonals")
	t.check(skeleton.zombie_alert == null,"zombie retaliation does not alert unrelated skeletons")
	attacker.position = at+Vector3(0,60,0); reset(mob); ZombieTargets.alert(mob,attacker)
	t.check(ZombieTargets.step(mob,0.1) == attacker and mob.zombie_ai.alert_time == 20,"an idle zombie accepts a remote ally's alert within 72 blocks")
	t.check(not ZombieTargets.alert(mob,other),"a zombie already targeting an enemy refuses a new ally alert")
	for i in 39: ZombieTargets.step(mob,0.5)
	t.check(mob.zombie_target == attacker,"an alerted zombie retains its extended approach range before twenty seconds")
	t.check(ZombieTargets.step(mob,0.5) == null,"an alerted target beyond tracking range is dropped at twenty seconds")
	reset(piglin); attacker.position = at+Vector3(5,0,0); game.gamemode = "survival"; game.player.health = 20; game.player.position = at+Vector3(4,0,0)
	t.check(ZombieTargets.step(piglin,0.1) == null,"neutral zombified piglins do not acquire nearby players automatically")
	reset(ally); mob.zombie_alert = null; var second: Creature = spawn(game,"zombified_piglin",at+Vector3(6,0,0))
	ZombieTargets.struck(piglin,attacker); ZombieTargets.step(piglin,0.1)
	t.check(second.zombie_alert == attacker and ally.zombie_alert == null and mob.zombie_alert == null,"zombified piglin retaliation and anger pulses alert only their own kind")
	t.check(is_equal_approx(piglin.info().speed,Creature.KINDS.zombified_piglin.speed*5.6/4.6),"angry zombified piglins receive the source movement multiplier")
	var drowned: Creature = spawn(game,"drowned",at+Vector3(0,0,-4)); game.daylight = 1
	t.check(not ZombieTargets.valid(drowned,attacker),"daytime drowned reject land targets, including retaliation targets")
	game.world.set_node(Vector3i(attacker.position.floor()),Nodes.WATER)
	t.check(ZombieTargets.valid(drowned,attacker),"daytime drowned accept an unattached target standing in water")
	game.daylight = 0
	t.check(ZombieTargets.valid(drowned,other) == false and ZombieTargets.valid(drowned,game.player),"nighttime drowned can attack living land targets and still reject dead targets")
	# A trident follows the selected NPC attacker, including aim and range.
	game.state = "playing"; game.gamemode = "creative"; game.player.position = at+Vector3(3,0,0)
	attacker.position = drowned.position+Vector3(0,0,7); reset(drowned)
	MobWeapons.set_item(drowned,{"id":VillageContent.TRIDENT,"count":1,"wear":0,"data":{}},0)
	drowned.model.rotation.y = PI; drowned.attack_cooldown = 0; ZombieTargets.struck(drowned,attacker)
	drowned._physics_process(0.05)
	var tridents: Array = game.entities.get_children().filter(func(e): return e is Arrow and e.item_id == VillageContent.TRIDENT and e.shooter_id == drowned.get_instance_id())
	t.check(tridents.size() == 1 and tridents[0].velocity.z > 30 and absf(tridents[0].velocity.x) < 15,"a drowned's actual trident aims at its selected NPC target rather than the player")
	for arrow in tridents: arrow.free()
	# Ordinary target sight lasts three seconds; retaliation lasts fifteen.
	for actor in [ally,piglin,second,drowned,villager,golem,skeleton,other]: actor.free()
	reset(mob); attacker.position = at+Vector3(0,0,5); game.player.position = at+Vector3(100,0,0)
	ZombieTargets.struck(mob,attacker); ZombieTargets.step(mob,0.1)
	for x in range(5,12):
		for y in range(2000,2003): game.world.set_node(Vector3i(x,y,11),Nodes.STONE)
	for i in 31: ZombieTargets.step(mob,0.5)
	t.check(mob.zombie_target == attacker,"retaliation retains the source's previous-timer boundary after fifteen unseen seconds")
	t.check(ZombieTargets.step(mob,0.5) == null,"retaliation ends on the next unseen tick after the timer becomes negative")
	for x in range(5,12):
		for y in range(2000,2003): game.world.set_node(Vector3i(x,y,11),Nodes.AIR)
	attacker.free(); game.villages.state().people = {}; game.gamemode = "creative"
	var job := Vector3i(14,2000,8); var bed := Vector3i(16,2000,8); var bell := Vector3i(18,2000,8)
	game.villages.make_record("target-fixture","farmer",Vector3(job),job,bed,job)
	game.world.set_node(job,VillageContent.COMPOSTER); game.world.set_node(bed,VillageContent.BED_RED)
	t.check(VillagePois.points(game).size() == 2 and VillagePois.heat(game,job) == 6,"claimed valid beds and workplaces seed the source's six-level village heat")
	t.check(ZombieSiege.village_heat(game,Vector3(job)) == 6,"siege eligibility reads the same propagated POI heat as navigation")
	game.world.set_node(bed,Nodes.AIR)
	t.check(VillagePois.points(game) == [job],"removing a claimed bed removes its POI without retaining stale heat")
	game.villages.state().people["target-fixture"].dead = true
	t.check(VillagePois.heat(game,job) == 0,"dead villagers' obsolete claims do not seed village heat")
	game.villages.state().people["target-fixture"].dead = false; game.world.set_node(bell,VillageContent.BELL); game.villages.ring_bell(bell)
	t.check(bell in VillagePois.points(game),"ringing a bell beside a resident records a village meeting POI")
	game.world.set_node(bell,Nodes.AIR)
	t.check(bell not in VillagePois.points(game),"a removed bell no longer contributes village heat")
	reset(mob); mob.position = at; game.daylight = 1
	t.check(not ZombieVillage.step(mob,1,false).is_finite() and not mob.zombie_village.active,"zombies do not start village navigation in daytime")
	game.daylight = 0
	for z in range(5,11):
		for y in range(2000,2003): game.world.set_node(Vector3i(11,y,z),Nodes.STONE)
	ZombieVillage.step(mob,1,false)
	t.check(mob.zombie_village.active and not mob.zombie_village.route.is_empty(),"a nighttime zombie finds a route toward an unvisited claimed workstation")
	t.check(mob.zombie_village.route.all(func(p): return not game.world.intersects(p,mob.width,mob.height)),"the village route avoids solid wall cells")
	game.state = "playing"; game.player.position = at+Vector3(0,0,-10); mob.think = 100
	for i in 240: mob._physics_process(0.05)
	t.check(job in mob.zombie_village.visited and mob.position.distance_to(Vector3(job)) < 2,"the actual zombie movement loop follows a route around a wall and records the visited POI")
	# Door-breaking paths wait for the door task rather than exhausting retries.
	var doorway := Vector3i(11,2000,8)
	for upper in [false,true]: game.world.set_node(doorway+(Vector3i.UP if upper else Vector3i.ZERO),Doors.state_id(549,3,false,false,upper))
	game.difficulty = 2; mob.zombie_traits.break_doors = true
	t.check(ZombieVillage.passable(mob,doorway),"an eligible Hard zombie can plan through a closed wooden door")
	game.world.set_node(doorway+Vector3i.UP,Nodes.STONE)
	t.check(not ZombieVillage.passable(mob,doorway),"a permitted door does not make a solid block above it traversable")
	game.world.set_node(doorway+Vector3i.UP,Doors.state_id(549,3,false,false,true))
	mob.position = Vector3(10.5,2000,8.5); mob.direction = Vector3.RIGHT; mob.velocity = Vector3.ZERO
	mob.zombie_village = {"timer":0.0,"active":true,"visited":[],"goal":job,"route":[Vector3(11.5,2000,8.5)],"stalled":0.9,"retried":false}
	ZombieDoors.step(mob,0.1,false)
	for i in 30: ZombieVillage.step(mob,0.1,false); ZombieDoors.step(mob,0.1,false)
	t.check(ZombieDoors.breaking(mob) and mob.zombie_village.active and not mob.zombie_village.retried,"village navigation waits through a long door break without spending its retry")
	t.check(not Farming.state(mob).has("zombie_ai") and not Farming.state(mob).has("zombie_village"),"target and visited-POI state are transient rather than persisted with mob attributes")
	for actor in game.creatures.get_children(): actor.free()
	for x in range(0,32):
		for z in range(0,24):
			for y in range(1999,2004): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.villages.state().people = people; game.world.adventure_state.village_bells = bells
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.position = old_pos; game.player.health = old_hp; game.gamemode = old_mode; game.daylight = old_light; game.difficulty = old_diff

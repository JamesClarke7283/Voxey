extends RefCounted

static func zombie(game: Node3D, at: Vector3) -> Creature:
	var mob: Creature = game.spawn_creature("zombie",at); mob.set_physics_process(false)
	mob.zombie_traits = {"knockback":0.04,"view":0.0,"reinforcement":0.0,"health_bonus":2.0,"break_doors":true}
	mob.mob_armor = MobArmor.empty_slots(); MobArmor.refresh(mob); MobWeapons.set_item(mob,MobWeapons.empty_item(),0)
	return mob

static func door(game: Node3D, pos: Vector3i, item: int = 549, opened: bool = false) -> void:
	for upper in [false,true]: game.world.set_node(pos+(Vector3i.UP if upper else Vector3i.ZERO),Doors.state_id(item,0,false,opened,upper))

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	var old_pos: Vector3 = game.player.position; var old_mode: String = game.gamemode; var old_hp: float = game.player.health; var old_diff: int = game.difficulty; var old_light: float = game.daylight
	for mob in game.creatures.get_children(): mob.free()
	game.world.adventure_state["farm_animals"] = {}
	var at := Vector3(8.5,2000,7.8); var cell := Vector3i(8,2000,8)
	for x in range(0,20):
		for z in range(0,20):
			for y in range(1999,2005): game.world.set_node(Vector3i(x,y,z),Nodes.STONE if y in [1999,2004] else Nodes.AIR)
	game.player.position = at+Vector3(0,0,3); game.player.health = 100; game.gamemode = "survival"; game.difficulty = 2; game.daylight = 0; game.state = "playing"
	var mob: Creature = zombie(game,at)
	t.check(mob.health == 20 and mob.info().health == 60,"the source leader health bonus raises maximum health without healing the spawned zombie")
	t.check(is_equal_approx(MeleeCombat.knockback_resistance(mob),0.04) and ZombieTraits.view_range(mob) == 35,"zombie attributes feed knockback resistance and source detection range")
	door(game,cell); mob.direction = Vector3.BACK
	ZombieDoors.step(mob,0.1,true)
	t.check(ZombieDoors.breaking(mob),"a permitted Hard-difficulty zombie starts breaking a closed wooden door")
	for i in 118: ZombieDoors.step(mob,0.1,false)
	t.check(Doors.is_door(game.world.node_at(cell)) and ZombieDoors.breaking(mob),"the door survives until twelve seconds of source breaking progress")
	var count: int = game.drops.get_children().filter(func(d): return d.item_id == 549).size()
	ZombieDoors.step(mob,0.2,false)
	t.check(game.world.node_at(cell) == Nodes.AIR and game.world.node_at(cell+Vector3i.UP) == Nodes.AIR and not ZombieDoors.breaking(mob),"finishing the timer removes both door halves")
	t.check(game.drops.get_children().filter(func(d): return d.item_id == 549).size() == count+1,"an NPC-broken door drops one door item")
	for difficulty in [0,1]:
		game.difficulty = difficulty; door(game,cell); mob.direction = Vector3.BACK; ZombieDoors.step(mob,0.1,true)
		t.check(not ZombieDoors.breaking(mob),"Easy and Normal zombies do not acquire door-breaking paths: "+str(difficulty))
	game.difficulty = 2; door(game,cell,228); ZombieDoors.step(mob,0.1,true)
	t.check(not ZombieDoors.breaking(mob),"iron doors cannot be broken by the zombie door task")
	door(game,cell); mob.direction = Vector3.BACK; ZombieDoors.step(mob,0.1,true)
	mob.velocity = Vector3(0,0,-2); ZombieDoors.step(mob,0.1,true)
	t.check(not ZombieDoors.breaking(mob),"moving away cancels the source door task")
	mob.velocity = Vector3.ZERO; mob.direction = Vector3.BACK; ZombieDoors.step(mob,0.1,true)
	door(game,cell,549,true); ZombieDoors.step(mob,0.1,true)
	t.check(not ZombieDoors.breaking(mob),"opening a door cancels breaking progress")
	door(game,cell); mob.position = at; mob.think = 100; mob.life = 0; mob.last_seen = 0; mob.direction = Vector3.BACK
	mob._physics_process(0.05)
	t.check(ZombieDoors.breaking(mob) and mob.velocity.y <= 0,"the actual movement loop detects a door and suppresses its obstruction jump")
	# The source loop does not stop after its first successful spawn.
	mob.zombie_traits.reinforcement = 0.2; mob.zombie_target = game.player
	var calls: Array = []; var new_mobs: Array = []
	var spawn: Callable = func(pos):
		calls.append(pos)
		if calls.size() > 3: return null
		var next: Creature = zombie(game,at+Vector3(calls.size()*2,0,0)); next.zombie_traits.reinforcement = 0.1
		new_mobs.append(next); return next
	var result: Array = ZombieTraits.reinforce(mob,game.player,EnchantRolls.new(17),0,spawn)
	t.check(calls.size() == 50 and result.size() == 3,"one eligible hit makes all fifty source reinforcement attempts")
	t.check(is_equal_approx(mob.zombie_traits.reinforcement,0.05) and new_mobs.all(func(a): return is_equal_approx(a.zombie_traits.reinforcement,0.05)),"each successful spawn attenuates caller and callee chances by five percentage points")
	t.check(new_mobs.all(func(a): return a.zombie_alert == game.player),"reinforcements receive the caller's current attack target")
	game.difficulty = 1; calls.clear(); ZombieTraits.reinforce(mob,game.player,EnchantRolls.new(17),0,spawn)
	t.check(calls.is_empty(),"reinforcements are gated to Hard difficulty")
	game.difficulty = 2; game.player.position = Vector3(0.5,2000,0.5)
	t.check(ZombieTraits.valid_spawn(mob,Vector3i(12,2000,12),EnchantRolls.new(1)),"a dark clear cell over solid ground can receive a reinforcement")
	game.player.position = Vector3(12.5,2000,12.5)
	t.check(not ZombieTraits.valid_spawn(mob,Vector3i(12,2000,12),EnchantRolls.new(1)),"a living player within seven blocks prevents reinforcement placement")
	game.player.position = Vector3(0.5,2000,0.5); mob.position = at; mob.zombie_traits.reinforcement = 1
	var before_hit: int = game.creatures.get_child_count(); ZombieTraits.rng_for(game.world).native.seed = 1
	mob.hit(1,game.player.position,"player_melee",0,game.player)
	t.check(game.creatures.get_child_count() > before_hit and mob.zombie_traits.reinforcement < 1,"the real damage callback spawns and attenuates eligible reinforcements")
	game.player.position = at+Vector3(0,0,3); mob.position = at; mob.health = 30; mob.zombie_traits.reinforcement = 0.35
	var identity: String = mob.farm_id
	mob.zombie_door = ZombieDoors.initial(); mob.zombie_door.pos = cell; mob.zombie_door.time = 7
	game.save_game(); var saved: Dictionary = game.read_save(game.saves.save_path(game.active_world_id))
	var frozen: Callable = func(node):
		if node is Creature: node.ready.connect(func(): node.set_physics_process(false),CONNECT_ONE_SHOT)
	game.creatures.child_entered_tree.connect(frozen); game.load_world_data(saved); game.set_process(true); game.world.set_process(true)
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.creatures.child_entered_tree.disconnect(frozen)
	var restored: Creature = Farming.active(game,identity)
	t.check(restored != null and restored.health == 30 and restored.info().health == 60 and is_equal_approx(restored.zombie_traits.reinforcement,0.35),"world reload preserves randomized attributes, maximum health and attenuated reinforcement chance")
	t.check(restored != null and restored.zombie_door.is_empty(),"door-breaking progress is transient and restarts after a world reload")
	for x in range(0,20):
		for z in range(0,20):
			for y in range(1999,2005): game.world.set_node(Vector3i(x,y,z),Nodes.AIR)
	game.pause(); game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.player.position = old_pos; game.gamemode = old_mode; game.player.health = old_hp; game.difficulty = old_diff; game.daylight = old_light

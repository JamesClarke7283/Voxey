class_name Trials
extends RefCounted

# Mineclonia mcl_trial_spawners and mcl_vaults (GPL-3.0-or-later).
# Object references are runtime-only; outstanding enemies and reward queues are
# serialized in the owning block's station, including during column unloading.
const SPAWNER = 12200
const ACTIVE = 12201
const OMINOUS = 12202
const OMINOUS_ACTIVE = 12203
const VAULT = 12204
const VAULT_ON = 12205
const VAULT_EJECT = 12206
const OMINOUS_VAULT = 12207
const OMINOUS_VAULT_ON = 12208
const OMINOUS_VAULT_EJECT = 12209
const KEY = 12210
const OMINOUS_KEY = 12211
const ENCHANTED_APPLE = 12212
const COOLDOWN = 1800.0
const ACTIVATION_RADIUS = 14.0
const CLAIM_LIMIT = 128
const MOBS = ["zombie","husk","spider","slime","silverfish","baby_zombie","cave_spider","stray","skeleton"]
const ARMORED = ["zombie","husk","baby_zombie","stray","skeleton"]
const DATA = {
	12200:{"name":"Trial spawner","block":true,"shape":"trial","color":"a86d46","hardness":50.0,"blast_resistance":50.0,"tool":0,"light":4},
	12201:{"name":"Active trial spawner","block":true,"shape":"trial","color":"eaa254","hardness":50.0,"blast_resistance":50.0,"tool":0,"light":8,"hidden":true},
	12202:{"name":"Ominous trial spawner","block":true,"shape":"trial","color":"398f9c","hardness":50.0,"blast_resistance":50.0,"tool":0,"light":8,"hidden":true},
	12203:{"name":"Active ominous trial spawner","block":true,"shape":"trial","color":"56d9df","hardness":50.0,"blast_resistance":50.0,"tool":0,"light":8,"hidden":true},
	12204:{"name":"Vault","block":true,"shape":"trial","color":"87604b","hardness":50.0,"blast_resistance":50.0,"tool":0},
	12205:{"name":"Active vault","block":true,"shape":"trial","color":"eb9f4e","hardness":50.0,"blast_resistance":50.0,"tool":0,"hidden":true},
	12206:{"name":"Open vault","block":true,"shape":"trial","color":"ffd485","hardness":50.0,"blast_resistance":50.0,"tool":0,"hidden":true},
	12207:{"name":"Ominous vault","block":true,"shape":"trial","color":"326871","hardness":50.0,"blast_resistance":50.0,"tool":0},
	12208:{"name":"Active ominous vault","block":true,"shape":"trial","color":"58c9d5","hardness":50.0,"blast_resistance":50.0,"tool":0,"hidden":true},
	12209:{"name":"Open ominous vault","block":true,"shape":"trial","color":"91f7ee","hardness":50.0,"blast_resistance":50.0,"tool":0,"hidden":true},
	12210:{"name":"Trial key","color":"cb8846"},
	12211:{"name":"Ominous trial key","color":"53c7cf"},
	12212:{"name":"Enchanted golden apple","color":"efb6ff","food":4},
}

static func is_spawner(id: int) -> bool: return id >= SPAWNER and id <= OMINOUS_ACTIVE
static func is_vault(id: int) -> bool: return id >= VAULT and id <= OMINOUS_VAULT_EJECT
static func is_block(id: int) -> bool: return is_spawner(id) or is_vault(id)
static func ominous(id: int) -> bool: return id in [OMINOUS,OMINOUS_ACTIVE,OMINOUS_VAULT,OMINOUS_VAULT_ON,OMINOUS_VAULT_EJECT]
static func active(id: int) -> bool: return id in [ACTIVE,OMINOUS_ACTIVE]
static func vault_base(id: int) -> int: return OMINOUS_VAULT if ominous(id) else VAULT

static func runtime(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("trials"):
		var rng := RandomNumberGenerator.new(); rng.seed = world.seed_value+94251327
		world.set_meta("trials",{"cells":{},"mobs":{},"owners":{},"rng":rng})
	return world.get_meta("trials")

static func orphans(world: VoxelWorld) -> Dictionary:
	if not world.adventure_state.get("trial_orphans") is Dictionary: world.adventure_state.trial_orphans = {}
	return world.adventure_state.trial_orphans

static func forget(world: VoxelWorld, key: String) -> void:
	var state: Dictionary = runtime(world)
	var owner: Variant = state.owners.get(key)
	if owner is Vector3i: world.stations.get(VoxelWorld.station_key(owner),{}).get("mobs",{}).erase(key)
	orphans(world).erase(key)
	state.mobs.erase(key); state.owners.erase(key)

static func station(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	var id: int = world.node_at(p)
	if not world.stations.has(key):
		world.stations[key] = {"kind":"trial" if is_spawner(id) else "vault","slots":[],"mob":"zombie",
			"players":[],"spawned":0,"mobs":{},"serial":0,"spawn_timer":0.0,"cooldown":0.0,
			"timer":0.0,"hazard_timer":0.0,"hazards":[],"rewards":[],"claims":[],"preview":0}
	return world.stations[key]

static func registered(world: VoxelWorld, p: Vector3i) -> void:
	if not is_block(world.node_at(p)) or not world.loaded_at(Vector3(p)) or world.network_replica: return
	var state: Dictionary = runtime(world)
	station(world,p)
	if not state.cells.has(p): state.cells[p] = null

static func changed(world: VoxelWorld, p: Vector3i, old: int, id: int) -> void:
	if is_block(old) and not ((is_spawner(old) and is_spawner(id)) or (is_vault(old) and is_vault(id))):
		if is_spawner(old):
			snapshot(world)
			var records: Dictionary = world.stations.get(VoxelWorld.station_key(p),{}).get("mobs",{})
			for key in records:
				var entry: Dictionary = records[key].duplicate(true)
				entry.orphan = true; entry.owner = [p.x,p.y,p.z]; orphans(world)[key] = entry
				var mob: Variant = runtime(world).mobs.get(key)
				if is_instance_valid(mob): mob.set_meta("trial_orphan",true)
		remove_display(world,p)
		if world.has_meta("trials"): runtime(world).cells.erase(p)
		world.stations.erase(VoxelWorld.station_key(p))
	if is_block(id) and not is_block(old): world.stations.erase(VoxelWorld.station_key(p))
	if is_block(id): registered(world,p)

static func remove_display(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("trials"): return
	var display: Variant = runtime(world).cells.get(p)
	if is_instance_valid(display): display.queue_free()

static func reset(world: VoxelWorld) -> void:
	if not world.has_meta("trials"): return
	for p in runtime(world).cells: remove_display(world,p)
	world.remove_meta("trials")

static func mob_record(mob: Creature) -> Dictionary:
	return {"kind":mob.kind,"position":[mob.position.x,mob.position.y,mob.position.z],"health":mob.health,
		"zombie_traits":ZombieTraits.snapshot(mob),"baby":MobBabies.baby(mob) or mob.get_meta("trial_baby",false),"jockey_vehicle":MobJockeys.vehicle_state(mob),"armor":mob.get_meta("trial_armor",0),
		"gear":mob.get_meta("trial_gear",[]),"weapon":mob.get_meta("trial_weapon",0),"effects":PotionEffects.snapshot(mob),
		"size":mob.slime_size if mob is ExpeditionCreature else 0,"bow":MobBows.snapshot(mob) if MobBows.handles(mob.kind) else {},"mob_armor":MobArmor.snapshot(mob) if MobArmor.handles(mob.kind) else {},"weapon_state":MobWeapons.snapshot(mob) if MobWeapons.handles(mob.kind) else {},"ominous":mob.get_meta("trial_ominous",false)}

static func snapshot(world: VoxelWorld) -> void:
	if not world.has_meta("trials"): return
	var state: Dictionary = runtime(world)
	for key in state.mobs.keys():
		var mob: Variant = state.mobs[key]
		if not is_instance_valid(mob): forget(world,key); continue
		var owner: Vector3i = mob.get_meta("trial_owner")
		if mob.is_queued_for_deletion() or mob.health <= 0: forget(world,key); continue
		if mob.get_meta("trial_orphan",false):
			var entry: Dictionary = mob_record(mob)
			entry.orphan = true; entry.owner = [owner.x,owner.y,owner.z]; orphans(world)[key] = entry
			continue
		var s: Dictionary = world.stations.get(VoxelWorld.station_key(owner),{})
		if s.is_empty(): continue
		s.mobs[key] = mob_record(mob)

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("trials"): return
	snapshot(world)
	var state: Dictionary = runtime(world)
	for p in state.cells.keys():
		if Vector2i(p.x >> 4,p.z >> 4) == column: remove_display(world,p); state.cells.erase(p)
	for key in state.mobs.keys():
		var mob: Variant = state.mobs[key]
		if not is_instance_valid(mob): state.mobs.erase(key); continue
		if Vector2i(floori(mob.position.x/16),floori(mob.position.z/16)) == column:
			state.mobs.erase(key); state.owners.erase(key); mob.queue_free()

static func died(mob: Creature) -> void:
	if not mob.has_meta("trial_key"): return
	var world: VoxelWorld = mob.game.world
	forget(world,str(mob.get_meta("trial_key")))

static func bind(world: VoxelWorld, p: Vector3i, key: String, entry: Dictionary) -> void:
	var game: Node3D = world.get_parent()
	var mob: Creature = game.spawn_creature(entry.kind,VillageLife.vec(entry.position),"",{"baby":bool(entry.get("baby",false)),"jockey":not entry.has("jockey_vehicle") and not entry.has("weapon_state")})
	if mob == null: return
	ZombieTraits.restore(mob,entry.get("zombie_traits",{}))
	mob.set_meta("persistent",true); mob.set_meta("trial_owner",p); mob.set_meta("trial_key",key)
	Farming.forget(mob) # The encounter owns this mob's persistence.
	if MobBows.handles(mob.kind): MobBows.restore(mob,entry.get("bow",{}))
	if MobWeapons.handles(mob.kind):
		if entry.has("weapon_state"): MobWeapons.restore(mob,entry.weapon_state)
		else:
			mob.held_weapon_probability = 0.0
			if int(entry.get("weapon",0)) > 0: MobWeapons.set_item(mob,{"id":int(entry.weapon),"count":1,"wear":0})
			elif entry.get("ominous",false) and MobBows.handles(mob.kind): MobWeapons.set_item(mob,{"id":Nodes.BOW,"count":1,"wear":0})
	mob.set_meta("trial_ominous",bool(entry.get("ominous",false)))
	if MobArmor.handles(mob.kind):
		if entry.has("mob_armor"): MobArmor.restore(mob,entry.mob_armor)
		else:
			for id in entry.get("gear",[]):
				var index: int = Nodes.armor_piece(int(id))
				if index in range(4): mob.mob_armor[index] = {"id":int(id),"count":1,"wear":0}
			MobArmor.refresh(mob)
	if entry.get("orphan",false): mob.set_meta("trial_orphan",true)
	mob.set_meta("trial_baby",entry.get("baby",false)); mob.set_meta("trial_armor",entry.get("armor",0)); mob.set_meta("trial_weapon",entry.get("weapon",0))
	mob.set_meta("trial_gear",entry.get("gear",[]))
	if mob is ExpeditionCreature and int(entry.get("size",0)) > 0: mob.set_slime_size(int(entry.size))
	if entry.get("baby",false) and mob.kind not in MobBabies.KINDS: mob.width *= 0.5; mob.height *= 0.5; mob.model.scale *= 0.5
	mob.health = float(entry.health)
	if entry.get("jockey_vehicle") is Dictionary: MobJockeys.restore_vehicle(mob,entry.jockey_vehicle)
	for gear in entry.get("gear",[]):
		if MobArmor.handles(mob.kind): continue
		var color: Color = Nodes.color(int(gear))
		if Nodes.armor_piece(int(gear)) == 0 and is_instance_valid(mob.head):
			mob._box(Vector3(0,0.34,0),Vector3(0.49,0.14,0.49),color,"",mob.head)
			for side in [-1,1]: mob._box(Vector3(side*0.23,0.19,0),Vector3(0.06,0.25,0.48),color,"",mob.head)
		else: mob._box(Vector3(0,1.09,0.02),Vector3(0.48,0.51,0.3),color)
	if int(entry.get("weapon",0)) > 0 and not mob.arms.is_empty() and not MobWeapons.handles(mob.kind):
		mob._box(Vector3(0,-0.72,-0.12),Vector3(0.07,0.55,0.06),Nodes.color(int(entry.weapon)),"",mob.arms[0])
	for effect in entry.get("effects",{}):
		var info: Dictionary = entry.effects[effect]
		PotionEffects.apply(mob,effect,float(info.duration),int(info.level))
		if effect == "absorption": PotionEffects.restore_absorption(mob,info.get("remaining",4.0*int(info.level)))
	runtime(world).mobs[key] = mob
	runtime(world).owners[key] = p

static func identity(game: Node3D, peer: int = 1) -> String:
	return str(game.player_id) if peer == 1 else str(game.network.peer_identity.get(peer,"peer:"+str(peer)))

static func nearby(world: VoxelWorld, p: Vector3i, radius: float, sight: bool = false) -> Array:
	var game: Node3D = world.get_parent()
	var people: Array = [{"id":identity(game),"position":game.player.position,"node":game.player}]
	if game.network != null and game.network.active():
		for peer in game.network.ready_peers:
			if peer != 1 and game.network.players.has(peer):
				people.append({"id":identity(game,peer),"position":game.network.players[peer].position,"node":null})
	var result: Array = []
	var origin: Vector3 = Vector3(p)+Vector3.ONE*0.5
	for person in people:
		if person.position.distance_to(origin) > radius: continue
		if sight and not visible(world,p,person.position+Vector3.UP*1.5): continue
		result.append(person)
	return result

static func visible(world: VoxelWorld, p: Vector3i, destination: Vector3) -> bool:
	var origin: Vector3 = Vector3(p)+Vector3.ONE*0.5
	var direction: Vector3 = destination-origin
	var hit: Dictionary = world.raycast(origin+direction.normalized()*0.9,direction.normalized(),maxf(0.0,direction.length()-0.9))
	return hit.is_empty() or hit.get("pos") == p

static func limits(s: Dictionary, is_ominous: bool) -> Vector2i:
	var extra: int = maxi(0,s.players.size()-1)
	return Vector2i((6+extra*2)*(2 if is_ominous and s.mob not in ARMORED else 1),2+extra+(1 if is_ominous else 0))

static func spawn_one(world: VoxelWorld, p: Vector3i, s: Dictionary, is_ominous: bool) -> bool:
	var rng: RandomNumberGenerator = runtime(world).rng
	var kind: String = "zombie" if s.mob == "baby_zombie" else str(s.mob)
	var baby: bool = s.mob == "baby_zombie" or MobBabies.roll_kind(kind,rng) != kind
	if kind not in Creature.KINDS: return false
	var info: Dictionary = Creature.KINDS[kind]
	for attempt in 30:
		var direction := Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		var at: Vector3 = Vector3(p)+Vector3.ONE*0.5+direction*rng.randf_range(1,4)
		if not world.loaded_at(at) or not visible(world,p,at): continue
		if world.intersects(at,float(info.width),float(info.height)): continue
		s.serial = maxi(int(s.serial),int(world.adventure_state.get("trial_serial",0)))+1
		world.adventure_state.trial_serial = s.serial
		var key: String = VoxelWorld.station_key(p)+":"+str(s.serial)
		var entry: Dictionary = {"kind":kind,"position":[at.x,at.y,at.z],"health":float(info.health),"baby":baby,"armor":0,"gear":[],"weapon":0,"ominous":is_ominous}
		if is_ominous and s.mob in ARMORED:
			for piece in 2:
				if rng.randf() > 0.5:
					var roll: int = rng.randi_range(0,6)
					var gear: int = Nodes.armor_id(3 if roll == 0 else 1,piece)
					if roll >= 3: gear = VillageContent.CHAIN_HELMET+piece
					entry.gear.append(gear); entry.armor += Nodes.armor_points(gear)
			# The source converts its weapon prototypes back to names: their
			# prototype enchantments are discarded before equipping.
			entry.weapon = Nodes.TOOLS+(18 if rng.randi_range(0,6) == 6 else 13) if s.mob not in ["stray","skeleton"] else 0
		s.mobs[key] = entry; bind(world,p,key,entry)
		s.spawned += 1; s.spawn_timer = 2.0
		world.get_parent().puff(at,Color("59cede") if is_ominous else Color("efa14c"),14,0.5)
		return true
	return false

static func armor_multiplier(mob: Creature, damage: float, reason: String) -> float:
	if not mob.has_meta("trial_armor") or reason in ["magic","environment","freeze","starve","void","lightning"]: return 1.0
	var points: float = float(mob.get_meta("trial_armor",0))
	var toughness: float = 0.0
	for id in mob.get_meta("trial_gear",[]): toughness += Nodes.armor_toughness(id)
	return 1.0-minf(20,maxf(points/5.0,points-damage/(2+toughness/4)))/25.0

static func complete(world: VoxelWorld, p: Vector3i, s: Dictionary, is_ominous: bool) -> void:
	var rng: RandomNumberGenerator = runtime(world).rng
	var keys: bool = rng.randf() <= (0.3 if is_ominous else 0.5)
	for person in s.players:
		if keys: s.rewards.append({"id":OMINOUS_KEY if is_ominous else KEY,"count":1,"wear":0})
		else: s.rewards.append_array(TrialLoot.roll("ominous_spawner" if is_ominous else "standard_spawner",rng))
	s.cooldown = COOLDOWN; s.players = []; s.spawned = 0; s.spawn_timer = 0.0; s.timer = 0.0
	world.set_node(p,OMINOUS if is_ominous else SPAWNER)

static func step_spawner(world: VoxelWorld, p: Vector3i, s: Dictionary, delta: float) -> void:
	var id: int = world.node_at(p)
	var people: Array = nearby(world,p,ACTIVATION_RADIUS,true)
	for person in people:
		if active(id) and person.id not in s.players: s.players.append(person.id)
		if not ominous(id) and person.node != null:
			var omen: int = PotionEffects.level(person.node,"bad_omen")
			if omen > 0:
				PotionEffects.apply(person.node,"trial_omen",900.0*omen)
				PotionEffects.clear_one(person.node,"bad_omen")
			if PotionEffects.level(person.node,"trial_omen") > 0:
				for key in s.mobs.keys():
					var mob: Variant = runtime(world).mobs.get(key)
					if is_instance_valid(mob): mob.queue_free()
					runtime(world).mobs.erase(key)
					runtime(world).owners.erase(key)
				s.mobs.clear(); s.spawned = 0; s.cooldown = 0.0; s.spawn_timer = 0.0
				s.players = people.map(func(a): return a.id)
				world.set_node(p,OMINOUS_ACTIVE); return
	if not active(id):
		s.cooldown = maxf(0.0,float(s.cooldown)-delta)
		if s.cooldown <= 0 and not people.is_empty():
			s.players = people.map(func(a): return a.id)
			# The source reactivates the ordinary node after cooldown. A current
			# Trial Omen transforms that new encounter on the following step.
			world.set_node(p,ACTIVE)
		elif s.cooldown <= 0 and ominous(id): world.set_node(p,SPAWNER)
		return
	var cap: Vector2i = limits(s,ominous(id))
	if s.spawned >= cap.x and s.mobs.is_empty(): complete(world,p,s,ominous(id)); return
	s.spawn_timer = maxf(0,float(s.spawn_timer)-delta)
	if s.spawned < cap.x and s.mobs.size() < cap.y and s.spawn_timer <= 0:
		if not spawn_one(world,p,s,ominous(id)): s.spawn_timer = 1.0
	if ominous(id): step_hazards(world,p,s,delta,people)

static func can_claim(s: Dictionary, player_id: String) -> bool:
	return player_id not in s.claims

static func open_vault(world: VoxelWorld, p: Vector3i, player_id: String, held: Dictionary, creative: bool = false) -> bool:
	var id: int = world.node_at(p)
	if not is_vault(id) or id in [VAULT_EJECT,OMINOUS_VAULT_EJECT]: return false
	var s: Dictionary = station(world,p)
	if not can_claim(s,player_id) or int(held.get("count",0)) <= 0 or int(held.get("id",0)) != (OMINOUS_KEY if ominous(id) else KEY): return false
	# Store the roll and entitlement before consuming the key or displaying loot.
	s.rewards = TrialLoot.roll("ominous_vault" if ominous(id) else "vault",runtime(world).rng)
	s.claims.append(player_id)
	if s.claims.size() > CLAIM_LIMIT: s.claims.pop_front()
	if not creative:
		held.count -= 1
		if held.count == 0: held.id = 0; held.wear = 0; held.erase("data")
	s.timer = 0.0; world.set_node(p,vault_base(id)+2)
	return true

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or not is_block(int(target.id)): return false
	if game.network.client():
		game.network.use_trial.rpc_id(1,target.pos,game.network.inventory_snapshot()); return true
	if is_spawner(target.id):
		var s: Dictionary = station(game.world,target.pos)
		game.toast("%s · %d / %d spawned · %d remaining%s"%[s.mob,s.spawned,limits(s,ominous(target.id)).x,s.mobs.size()," · cooldown %d s"%ceili(s.cooldown) if s.cooldown > 0 else ""])
	else:
		if not open_vault(game.world,target.pos,identity(game),game.inventory.held(),game.gamemode == "creative"):
			game.toast("Already claimed this vault." if not can_claim(station(game.world,target.pos),identity(game)) else "Use an ominous trial key." if ominous(target.id) else "Use a trial key.")
		game.inventory.changed.emit()
	return true

static func step_vault(world: VoxelWorld, p: Vector3i, s: Dictionary, delta: float) -> void:
	var id: int = world.node_at(p)
	if id in [VAULT_EJECT,OMINOUS_VAULT_EJECT]: return
	var on: bool = id in [VAULT_ON,OMINOUS_VAULT_ON]
	var eligible: bool = nearby(world,p,5.0 if on else 3.0).any(func(person): return can_claim(s,person.id))
	var wanted: int = vault_base(id)+(1 if eligible else 0)
	if id != wanted: world.set_node(p,wanted)
	if eligible:
		s.timer -= delta
		if s.timer <= 0:
			s.timer = 2.0
			var preview: Array = TrialLoot.roll("ominous_vault" if ominous(id) else "vault",runtime(world).rng)
			if not preview.is_empty(): s.preview = preview[0].id
	else: s.preview = 0

static func rewards(world: VoxelWorld, p: Vector3i, s: Dictionary, delta: float) -> void:
	var id: int = world.node_at(p)
	if s.rewards.is_empty():
		if id in [VAULT_EJECT,OMINOUS_VAULT_EJECT]: world.set_node(p,vault_base(id)); s.preview = 0
		return
	s.timer -= delta
	if s.timer > 0: return
	var item: Dictionary = s.rewards.pop_front()
	s.timer += 0.5 if is_vault(id) else 2.0
	world.get_parent().spawn_drop(Vector3(p)+Vector3(0.5,1.2,0.5),item.id,item.count,item.get("wear",0),item.get("data",{}))
	if is_vault(id): s.preview = 0 if s.rewards.is_empty() else int(s.rewards[0].id)

static func update(world: VoxelWorld, delta: float) -> void:
	if world.network_replica: return
	if not world.has_meta("trials") and world.adventure_state.get("trial_orphans",{}).is_empty(): return
	var state: Dictionary = runtime(world)
	# A removed entity counts as gone. A deliberately unloaded one was removed
	# from the runtime map first and retains its saved record.
	snapshot(world)
	for key in orphans(world):
		var entry: Dictionary = orphans(world)[key]
		if not state.mobs.has(key) and world.loaded_at(VillageLife.vec(entry.position)):
			bind(world,Vector3i(VillageLife.vec(entry.owner)),key,entry)
	for p in state.cells.keys():
		if not is_block(world.node_at(p)) or not world.loaded_at(Vector3(p)): continue
		var s: Dictionary = station(world,p)
		for key in s.mobs:
			if not state.mobs.has(key) and world.loaded_at(VillageLife.vec(s.mobs[key].position)): bind(world,p,key,s.mobs[key])
		advance_hazards(world,s,delta)
		rewards(world,p,s,delta)
		if is_spawner(world.node_at(p)): step_spawner(world,p,s,delta)
		else: step_vault(world,p,s,delta)
		refresh_display(world,p,s,delta)

static func refresh_display(world: VoxelWorld, p: Vector3i, s: Dictionary, delta: float) -> void:
	var state: Dictionary = runtime(world)
	var id: int = world.node_at(p)
	var preview: int = int(s.preview) if is_vault(id) else -1
	var display: Variant = state.cells[p]
	if not is_instance_valid(display) or display.get_meta("preview",-2) != preview:
		remove_display(world,p)
		if preview > 0:
			var item := MeshInstance3D.new(); item.mesh = ItemArt.mesh(preview); item.material_override = ItemArt.material(preview); item.scale = Vector3.ONE*0.3; display = item
		elif preview < 0: display = Dungeons.doll("zombie" if s.mob == "baby_zombie" else str(s.mob))
		else: state.cells[p] = null; return
		display.set_meta("preview",preview); world.add_child(display); display.position = Vector3(p)+Vector3(0.5,0.25,0.5); state.cells[p] = display
	display.rotation.y += delta*2.0

static func step_hazards(world: VoxelWorld, p: Vector3i, s: Dictionary, delta: float, people: Array) -> void:
	var rng: RandomNumberGenerator = runtime(world).rng
	s.hazard_timer -= delta
	var targets: Array = people.map(func(person): return person.position)
	for key in s.mobs:
		var mob: Variant = runtime(world).mobs.get(key)
		if is_instance_valid(mob) and mob.position.distance_to(Vector3(p)+Vector3.ONE*0.5) <= ACTIVATION_RADIUS: targets.append(mob.position)
	if s.hazard_timer <= 0 and not targets.is_empty():
		s.hazard_timer = 8.0
		var at: Vector3 = targets[rng.randi_range(0,targets.size()-1)]+Vector3.UP*0.5
		var lift: float = rng.randf_range(2,6)
		var hit: Dictionary = world.raycast(at,Vector3.UP,lift)
		at += Vector3.UP*(maxf(0.5,float(hit.distance)-0.3) if not hit.is_empty() else lift)
		s.hazards.append({"position":[at.x,at.y,at.z],"delay":rng.randf_range(3,6),"type":rng.randi_range(0,11)})

static func advance_hazards(world: VoxelWorld, s: Dictionary, delta: float) -> void:
	for hazard in s.hazards.duplicate():
		hazard.delay -= delta
		var at: Vector3 = VillageLife.vec(hazard.position)
		if hazard.delay <= 0: launch_hazard(world.get_parent(),at,int(hazard.type)); s.hazards.erase(hazard)
		else: world.get_parent().puff(at,Color("76deee"),1,0.3)

static func launch_hazard(game: Node3D, at: Vector3, type: int) -> void:
	if type < 7:
		var potion := PotionProjectile.new(); potion.game = game; potion.position = at; potion.velocity = Vector3.DOWN
		potion.item_id = PotionCatalog.find(["wind_charged","oozing","weaving","infestation","strength","swiftness","slow_falling"][type],"lingering")
		game.entities.add_child(potion)
	elif type == 7:
		var shot := ThrownItem.new(); shot.game = game; shot.item_id = WindCharge.ID; shot.position = at; shot.velocity = Vector3.DOWN*15; game.entities.add_child(shot)
	elif type == 8: game.adventure.projectile("blaze",at,Vector3.DOWN*15,null)
	else:
		var arrow := Arrow.new(); arrow.game = game; arrow.position = at; arrow.velocity = Vector3.DOWN*15; arrow.hits_player = true; arrow.shooter_kind = "trial_spawner"
		arrow.item_id = Nodes.ARROW_ITEM if type == 9 else PotionCatalog.find("slowness" if type == 10 else "poison","arrow")
		if type == 10: arrow.potion_data = {"potion_level":5}
		game.entities.add_child(arrow)

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if (x % 5 == 0 or y % 5 == 0): return Nodes.color(id).lightened(0.15)
	return noise.darkened(0.65)

static func mesh(out: Array, p: Vector3, id: int) -> void:
	var tile: int = Nodes.tile(id,0)
	for axis in 3:
		for a in [0.06,0.35,0.65,0.94]:
			for b in [0.06,0.94]:
				var center := Vector3.ONE*0.5; var size := Vector3.ONE*0.09
				center[(axis+1)%3] = a; center[(axis+2)%3] = b; size[axis] = 1.0
				BlockMesher._art_box(out,p+center,size,tile,tile)
	for y in [0.06,0.94]: BlockMesher._art_box(out,p+Vector3(0.5,y,0.5),Vector3(1,0.12,1),tile,tile)
	if is_vault(id):
		BlockMesher._art_box(out,p+Vector3(0.5,0.52,0.04),Vector3(0.34,0.4,0.1),tile,tile)
		BlockMesher._art_box(out,p+Vector3(0.5,0.53,-0.02),Vector3(0.07,0.17,0.03),Nodes.tile(Nodes.COAL,0),Nodes.tile(Nodes.COAL,0))

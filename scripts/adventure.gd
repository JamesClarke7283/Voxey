class_name Adventure
extends RefCounted

var game: Node3D
var clock: float = 0.0
var spawn_clock: float = 0.0
var breath_clouds: Array = []

func _init(owner_game: Node3D) -> void:
	game = owner_game

func projectile(kind: String, origin: Vector3, velocity: Vector3, owner_node: Node = null) -> MagicProjectile:
	var shot := MagicProjectile.new()
	shot.game = game; shot.kind = kind; shot.position = origin; shot.velocity = velocity; shot.source = owner_node
	game.entities.add_child(shot)
	return shot

func throw_item(id: int) -> bool:
	var origin: Vector3 = game.player.camera.global_position-game.player.camera.global_basis.z*0.5
	if id == Nodes.ENDER_PEARL:
		projectile("pearl",origin,-game.player.camera.global_basis.z*20+Vector3.UP*2,game.player).from_player = true
	elif id == Nodes.ENDER_EYE:
		if game.dimension != "overworld": game.toast("Eyes of Ender seek strongholds in the Overworld."); return false
		var stronghold := WorldStructures.nearest_stronghold(game.world.seed_value,game.player.position)
		var toward: Vector3 = Vector3(stronghold)+Vector3.UP*3-origin
		var shot := projectile("eye",origin,Vector3.ZERO,game.player)
		shot.target = origin+toward.normalized()*minf(12,toward.length())
		if Vector2(toward.x,toward.z).length() > 14: shot.target.y = origin.y+4
		# Eyes can be recovered; every fifth survival throw shatters deterministically.
		var throws: int = int(game.world.adventure_state.get("eye_throws",0))+1
		game.world.adventure_state["eye_throws"] = throws
		shot.from_player = game.gamemode != "creative" and throws%5 != 0
		game.toast("Follow the Eye. It descends above the stronghold." if toward.length() > 16 else "The stronghold portal is below you.")
	else: return false
	if game.gamemode != "creative": game.inventory.consume_selected()
	game.sound("arrow")
	return true

func deflect_target() -> bool:
	var origin: Vector3 = game.player.camera.global_position
	var direction: Vector3 = -game.player.camera.global_basis.z
	for shot in game.entities.get_children():
		if not shot is MagicProjectile or shot.kind not in ["ghast","shulker"] or shot.is_queued_for_deletion(): continue
		var along: float = (shot.position-origin).dot(direction)
		if along > 0 and along < 4 and (origin+direction*along).distance_to(shot.position) < 0.75:
			var hit: Dictionary = game.world.raycast(origin,direction,along)
			if hit.is_empty():
				if shot.kind == "shulker": shot.queue_free()
				else: shot.deflect(direction)
				return true
	return false

func update(delta: float) -> void:
	clock += delta
	spawn_clock += delta
	for cloud in breath_clouds.duplicate():
		cloud.life -= delta
		if cloud.life <= 0 or cloud.dimension != game.dimension:
			breath_clouds.erase(cloud); continue
		if game.player.position.distance_to(cloud.position) < 3: game.player.hurt(3,true)
		if fmod(cloud.life,0.2) < delta: game.puff(cloud.position,Color("c575da"),4,1.8)
	if clock >= 0.5:
		clock = 0
		if game.dimension == "end": ensure_end(); city_guards()
		else: restore_placed_crystals()
		if game.dimension == "nether": Bastions.populate(game)
	if spawn_clock > 8:
		spawn_clock = 0
		if game.dimension == "nether": fortress_spawn()

func add_breath(at: Vector3) -> void:
	breath_clouds.append({"position":at,"life":6.0,"dimension":game.dimension})
	game.puff(at,Color("c675d9"),20,2)

func ensure_end() -> void:
	var saved: Dictionary = game.world.adventure_state
	if not saved.has("destroyed_crystals"): saved["destroyed_crystals"] = []
	if not saved.has("placed_crystals"): saved["placed_crystals"] = {}
	var existing: Dictionary = {}
	var dragon: Creature
	for mob in game.creatures.get_children():
		if mob.is_queued_for_deletion(): continue
		if mob.kind == "end_crystal": existing[mob.crystal_key] = true
		if mob.kind == "ender_dragon": dragon = mob
	var towers: Array = WorldStructures.towers()
	if not saved.get("defeated",false):
		for i in towers.size():
			var p: Vector3 = Vector3(towers[i])+Vector3(0.5,1,0.5)
			var key: String = "tower_%d" % i
			if not game.world.loaded_at(p) or key in saved.destroyed_crystals or existing.has(key): continue
			var crystal: Creature = game.spawn_creature("end_crystal",p)
			crystal.crystal_key = key
		if dragon == null and game.world.loaded_at(Vector3(0,65,0)) and Vector2(game.player.position.x,game.player.position.z).length() < 110:
			dragon = game.spawn_creature("ender_dragon",Vector3(0,65,0))
			dragon.health = clampf(float(saved.get("dragon_health",200)),1,200)
			dragon.life = float(saved.get("dragon_phase",0))
	for key in saved.placed_crystals:
		var a: Array = saved.placed_crystals[key]
		var p := Vector3(a[0],a[1],a[2])
		if game.world.loaded_at(p) and not existing.has(key):
			var crystal: Creature = game.spawn_creature("end_crystal",p)
			crystal.crystal_key = key
	if saved.get("defeated",false): open_exit()
	if saved.get("won_before",false): open_gateways()

func crystal_destroyed(crystal: Creature) -> void:
	var saved: Dictionary = game.world.adventure_state
	if crystal.crystal_key.begins_with("tower_"):
		if not saved.has("destroyed_crystals"): saved["destroyed_crystals"] = []
		if crystal.crystal_key not in saved.destroyed_crystals: saved.destroyed_crystals.append(crystal.crystal_key)
	else: saved.get("placed_crystals",{}).erase(crystal.crystal_key)
	for mob in game.creatures.get_children():
		if mob.kind == "ender_dragon" and mob.beam_target == crystal: mob.hit(10,crystal.position)

func dragon_defeated() -> void:
	var first: bool = not game.world.adventure_state.get("won_before",false)
	game.world.adventure_state["defeated"] = true
	game.world.adventure_state["won_before"] = true
	game.world.adventure_state["dragon_health"] = 0
	game.experience += 500 if first else 100
	# `free_the_end` on the first kill and `the_end_again` on a respawn.
	game.achievements.award("free_the_end" if first else "the_end_again")
	open_exit(); open_gateways()
	if first: game.world.set_node(Vector3i(0,49,0),Nodes.DRAGON_EGG)
	game.puff(Vector3(0,50,0),Color("e1c3f3"),80,10)
	game.toast("The dragon has fallen! The return portal is open. Your adventure continues.")
	game.save_game()

func open_exit() -> void:
	if not game.world.loaded_at(Vector3(0,45,0)): return
	for x in range(-2,3):
		for z in range(-2,3):
			if x == 0 and z == 0: continue
			var p := Vector3i(x,45,z)
			if game.world.node_at(p) != Nodes.END_PORTAL: game.world.set_node(p,Nodes.END_PORTAL)

func place_crystal(base: Vector3i) -> bool:
	if game.world.node_at(base) not in [Nodes.OBSIDIAN,Nodes.BEDROCK] or game.world.node_at(base+Vector3i.UP) != Nodes.AIR: return false
	var pos := Vector3(base)+Vector3(0.5,1,0.5)
	for mob in game.creatures.get_children():
		if not mob.is_queued_for_deletion() and mob.kind == "end_crystal" and mob.position.distance_to(pos) < 0.8: return false
	var saved: Dictionary = game.world.adventure_state
	if not saved.has("placed_crystals"): saved["placed_crystals"] = {}
	var key: String = VoxelWorld.station_key(base)
	saved.placed_crystals[key] = [pos.x,pos.y,pos.z]
	var crystal: Creature = game.spawn_creature("end_crystal",pos)
	crystal.crystal_key = key
	if game.dimension == "end" and saved.get("defeated",false):
		var complete: bool = true
		for p in [Vector3i(3,44,0),Vector3i(-3,44,0),Vector3i(0,44,3),Vector3i(0,44,-3)]:
			if not saved.placed_crystals.has(VoxelWorld.station_key(p)): complete = false
		if complete: respawn_dragon()
	return true

func respawn_dragon() -> void:
	var saved: Dictionary = game.world.adventure_state
	for mob in game.creatures.get_children():
		if mob.kind in ["ender_dragon","end_crystal"]: mob.queue_free()
	saved["placed_crystals"] = {}; saved["destroyed_crystals"] = []; saved["dragon_health"] = 200; saved["dragon_phase"] = 0; saved["defeated"] = false
	for p in game.world.edits.keys():
		if game.world.edits[p] == Nodes.END_PORTAL and absi(p.x) <= 3 and absi(p.z) <= 3: game.world.set_node(p,Nodes.AIR)
	# Restore tower blocks and cages, including edited unloaded columns.
	for tower in WorldStructures.towers():
		for x in range(tower.x-3,tower.x+4):
			for z in range(tower.z-3,tower.z+4):
				for y in range(30,tower.y+5):
					var p := Vector3i(x,y,z)
					var id: int = WorldStructures.end_structure_node(p)
					if id >= 0:
						game.world.edits[p] = id
						if game.world.loaded_at(Vector3(p)): game.world.set_node(p,id)
	game.toast("The crystals call the dragon back to the End.")

func fortress_spawn() -> void:
	if game.creatures.get_child_count() >= 16: return
	var near: Vector3 = game.player.position
	var region := Vector2i(floori(near.x/160),floori(near.z/160))
	for x in range(-1,2):
		for z in range(-1,2):
			var p := Vector3i((region.x+x)*160+60,29,(region.y+z)*160+60)
			if Vector3(p).distance_to(near) > 32 or game.world.node_at(p) != Nodes.BLAZE_SPAWNER: continue
			var count: int = 0
			for mob in game.creatures.get_children():
				if mob.kind == "blaze" and mob.position.distance_to(Vector3(p)) < 24: count += 1
			if count >= 4: return
			var pos := Vector3(p)+Vector3(randf_range(-5,5),2,randf_range(-5,5))
			if not game.world.intersects(pos,0.3,1.8): game.spawn_creature("blaze",pos)

func restore_placed_crystals() -> void:
	var saved: Dictionary = game.world.adventure_state.get("placed_crystals",{})
	var existing: Array = []
	for mob in game.creatures.get_children():
		if mob.kind == "end_crystal" and not mob.is_queued_for_deletion(): existing.append(mob.crystal_key)
	for key in saved:
		var a: Array = saved[key]
		var p := Vector3(a[0],a[1],a[2])
		if game.world.loaded_at(p) and key not in existing:
			var crystal: Creature = game.spawn_creature("end_crystal",p); crystal.crystal_key = key

func city_guards() -> void:
	var near: Vector3 = game.player.position
	if Vector2(near.x,near.z).length() < 160: return
	var ix: int = floori((near.x+48)/96.0)*96
	var iz: int = floori((near.z+48)/96.0)*96
	if posmod(ix/96+iz/96,3) != 0: return
	var existing: Array = game.world.adventure_state.get("city_guards",[]).duplicate()
	existing.append_array(game.boats.passenger_keys().keys())
	for entry in Farming.records(game).values():
		if entry is Dictionary and entry.get("kind","") == "shulker" and not str(entry.get("crystal_key","")).is_empty(): existing.append(entry.crystal_key)
	for link in game.leads.leads:
		var sleeper: Dictionary = link.get("sleeping",{})
		if sleeper.get("kind","") == "shulker" and not str(sleeper.get("crystal_key","")).is_empty(): existing.append(sleeper.crystal_key)
	for mob in game.creatures.get_children():
		if mob.kind == "shulker" and not mob.is_queued_for_deletion(): existing.append(mob.crystal_key)
	for offset in [Vector3i(3,43,0),Vector3i(-3,58,2)]:
		var p: Vector3i = Vector3i(ix,0,iz)+offset
		var key: String = VoxelWorld.station_key(p)
		if game.world.loaded_at(Vector3(p)) and key not in existing and not game.world.intersects(Vector3(p)+Vector3(0.5,0,0.5),0.45,1):
			var guard: Creature = game.spawn_creature("shulker",Vector3(p)+Vector3(0.5,0,0.5)); guard.crystal_key = key

func open_gateways() -> void:
	for p in [Vector3i(50,45,4),Vector3i(280,43,0)]:
		for x in range(-1,2):
			for y in range(-1,3):
				var q: Vector3i = p+Vector3i(x,y,0)
				var id: int = Nodes.BEDROCK if x != 0 or y in [-1,2] else Nodes.END_GATEWAY
				_gateway_block(q,id)
		for z in [-1,1]:
			_gateway_block(p+Vector3i(0,-1,z),Nodes.END_STONE)
			for y in 2:
				var q: Vector3i = p+Vector3i(0,y,z)
				_gateway_block(q,Nodes.AIR)

func enter_gateway() -> void:
	if game.dimension != "end" or game.portal_cooldown > 0: return
	var outer: bool = Vector2(game.player.position.x,game.player.position.z).length() < 160
	game.portal_cooldown = 5
	game.teleport(Vector3(280.5,43.01,1.5) if outer else Vector3(50.5,45.01,5.5))
	game.toast("The End highlands await." if outer else "Returned to the central island.")

func _gateway_block(p: Vector3i, id: int) -> void:
	if game.world.loaded_at(Vector3(p)):
		if game.world.node_at(p) != id: game.world.set_node(p,id)
	else:
		# Worker snapshots reconcile these saved edits when the column streams in.
		game.world.edits[p] = id

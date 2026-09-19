class_name NetherResident
extends Creature

var resident_key: String = ""
var barter_time: float = 0.0
var barter_count: int = 0

func ensure_record() -> void:
	if not record().is_empty(): return
	if not game.world.adventure_state.get("nether_residents") is Dictionary: game.world.adventure_state["nether_residents"] = {}
	var people: Dictionary = game.world.adventure_state.nether_residents
	var serial: int = maxi(0,int(game.world.adventure_state.get("nether_resident_serial",0)))
	while true:
		serial += 1
		resident_key = "named_resident:%d"%serial
		if not people.has(resident_key): break
	game.world.adventure_state["nether_resident_serial"] = serial
	people[resident_key] = {"key":resident_key,"kind":kind,"position":[position.x,position.y,position.z],"health":health,"dead":false}
	store_record()

static func active(game: Node3D, key: String) -> NetherResident:
	if key.is_empty(): return null
	for mob in game.creatures.get_children():
		if mob is NetherResident and not mob.is_queued_for_deletion() and mob.resident_key == key: return mob
	return null

static func resolve(game: Node3D, key: String) -> NetherResident:
	var mob: NetherResident = active(game,key)
	if mob != null: return mob
	var entry: Dictionary = game.world.adventure_state.get("nether_residents",{}).get(key,{})
	if entry.is_empty() or entry.get("dead",false) or entry.get("kind","") not in ["piglin","piglin_brute"]: return null
	var location: Dictionary = WorldBounds.clean_location({"dimension":game.dimension,"position":entry.get("position")})
	if location.is_empty() or float(entry.get("health",0)) <= 0: return null
	mob = game.spawn_creature(entry.kind,VillageLife.vec(location.position))
	mob.bind(entry)
	return mob

static func restore_named(game: Node3D) -> void:
	for key in game.world.adventure_state.get("nether_residents",{}):
		var entry: Dictionary = game.world.adventure_state.nether_residents[key]
		if not str(entry.get("custom_name","")).is_empty(): resolve(game,str(key))

func bind(entry: Dictionary) -> void:
	resident_key = entry.key; health = entry.health
	barter_time = entry.get("barter_time",0.0); barter_count = entry.get("barter_count",0)
	provoked = entry.get("provoked",false)
	custom_name = NameTags.bounded(str(entry.get("custom_name","")),30); NameTags.refresh(self)

func record() -> Dictionary:
	return game.world.adventure_state.get("nether_residents",{}).get(resident_key,{})

func store_record() -> void:
	var entry: Dictionary = record()
	if entry.is_empty(): return
	entry.position = [position.x,position.y,position.z]; entry.health = health
	entry.barter_time = barter_time; entry.barter_count = barter_count; entry.provoked = provoked
	entry.custom_name = custom_name

func aggressive() -> bool:
	if barter_time > 0: return false
	if kind == "piglin" and not provoked:
		for piece in game.player.armor_slots:
			if Nodes.is_armor(piece.id) and Nodes.armor_material(piece.id) == 2: return false
	return super.aggressive()

func barter() -> bool:
	if kind != "piglin" or provoked or barter_time > 0: return false
	if game.inventory.held().id != Nodes.GOLD: return false
	if game.gamemode != "creative": game.inventory.consume_selected()
	barter_time = 6.0; store_record()
	game.toast("The piglin examines the gold.")
	return true

func _physics_process(delta: float) -> void:
	if not game.playing(): return
	if game.leads.sleep_if_unloaded(self): return
	if barter_time > 0:
		barter_time = maxf(0,barter_time-delta)
		direction = Vector3.ZERO; animate(delta)
		if barter_time == 0:
			barter_count += 1
			var rng := RandomNumberGenerator.new(); rng.seed = (resident_key+str(barter_count)+str(game.world.seed_value)).hash()
			var reward: Dictionary = PiglinBarter.reward(rng)
			game.spawn_drop(center()+Vector3.UP*0.2,reward.id,reward.count,0,reward.get("data",{}))
		store_record(); return
	super._physics_process(delta)
	store_record()

func die() -> void:
	var entry: Dictionary = record()
	if not entry.is_empty(): entry["dead"] = true
	super.die()

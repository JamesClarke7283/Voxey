class_name NetherResident
extends Creature

var resident_key: String = ""
var barter_time: float = 0.0
var barter_count: int = 0

func bind(entry: Dictionary) -> void:
	resident_key = entry.key; health = entry.health
	barter_time = entry.get("barter_time",0.0); barter_count = entry.get("barter_count",0)
	provoked = entry.get("provoked",false)

func record() -> Dictionary:
	return game.world.adventure_state.get("nether_residents",{}).get(resident_key,{})

func store_record() -> void:
	var entry: Dictionary = record()
	if entry.is_empty(): return
	entry.position = [position.x,position.y,position.z]; entry.health = health
	entry.barter_time = barter_time; entry.barter_count = barter_count; entry.provoked = provoked

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

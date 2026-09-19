class_name Jukeboxes
extends RefCounted

# Source behavior: Mineclonia mcl_jukebox/init.lua. Original procedural art.
# Music files retain their individual licenses; see assets/audio/jukebox/ATTRIBUTION.md.
const ID = 6800
const DISC_13 = 6810
const WAIT = 6811
const BLOCKS = 6812
const FAR = 6813
const CHIRP = 6814
const STRAD = 6815
const MELLOHI = 6816
const MALL = 1107 # Preserve the existing Bastion loot and saved inventory ID.
const HEAR_DISTANCE = 65.0
const DATA = {
	ID:{"name":"Jukebox","block":true,"color":"95623e","hardness":2.0,"tool":1,"blast_resistance":6.0,"flammable":false},
	DISC_13:{"name":"Music disc: 13","family":"disc","color":"d4b953","stack":1},
	WAIT:{"name":"Music disc: Wait","family":"disc","color":"4797c6","stack":1},
	BLOCKS:{"name":"Music disc: Blocks","family":"disc","color":"d97536","stack":1},
	FAR:{"name":"Music disc: Far","family":"disc","color":"9dc861","stack":1},
	CHIRP:{"name":"Music disc: Chirp","family":"disc","color":"c4524b","stack":1},
	STRAD:{"name":"Music disc: Strad","family":"disc","color":"eee2a3","stack":1},
	MELLOHI:{"name":"Music disc: Mellohi","family":"disc","color":"c995c9","stack":1},
}
const RECORDS = {
	DISC_13:{"track":1,"signal":1,"title":"The Evil Sister (Jordach’s Mix)","author":"SoundHelix","license":"CC0"},
	WAIT:{"track":2,"signal":12,"title":"The Energetic Rat (Jordach’s Mix)","author":"SoundHelix","license":"CC0"},
	BLOCKS:{"track":3,"signal":3,"title":"Eastern Feeling","author":"Jordach","license":"CC0"},
	FAR:{"track":4,"signal":5,"title":"Minetest","author":"Jordach","license":"CC0"},
	CHIRP:{"track":5,"signal":4,"title":"Soaring over the sea","author":"mactonite / Darkroom","license":"CC BY 3.0"},
	STRAD:{"track":6,"signal":9,"title":"Winter Feeling","author":"Tom Peter","license":"CC BY-SA 3.0"},
	MELLOHI:{"track":7,"signal":7,"title":"Synthgroove (Jordach’s Mix)","author":"HeroOfTheWinds","license":"CC0"},
	MALL:{"track":8,"signal":6,"title":"The Clueless Frog (Jordach’s Mix)","author":"SoundHelix","license":"CC0"},
}
const CREEPER_RECORDS = [DISC_13,WAIT,BLOCKS,FAR,STRAD,MELLOHI]
# Text embedded in exported resources too, rather than depending on README export.
const CREDITS = "Music: SoundHelix, Jordach and HeroOfTheWinds (CC0, https://creativecommons.org/publicdomain/zero/1.0/), from https://github.com/Jordach/jdukebox/. Soaring over the sea — mactonite (Darkroom), https://ccmixter.org/files/mactonite/65379, CC BY 3.0 https://creativecommons.org/licenses/by/3.0/; includes h2oBeat001 by My Free Mickey, https://ccmixter.org/files/myfreemickey/46437. Winter Feeling — Tom Peter, https://opengameart.org/content/winter-feeling, CC BY-SA 3.0 https://creativecommons.org/licenses/by-sa/3.0/. All audio copied unchanged from Mineclonia mcl_jukebox."

static func is_disc(id: int) -> bool: return RECORDS.has(id)
static func empty() -> Dictionary: return {"id":0,"count":0,"wear":0}
static func stream(id: int) -> AudioStream:
	return load("res://assets/audio/jukebox/mcl_jukebox_track_%d.ogg"%int(RECORDS[id].track)) if is_disc(id) else null

static func recipes(inv: Inventory) -> void:
	var wood: int = Nodes.PLANKS
	inv._recipe("Jukebox",ID,1,[wood,wood,wood,wood,Nodes.DIAMOND,wood,wood,wood,wood],3,"table")

static func special_recipe(grid: Array) -> Dictionary:
	if grid.size() != 9: return {}
	var pattern: Array = []; var ingredients: Dictionary = {}
	for index in 9:
		var id: int = int(grid[index].get("id",0))
		if (index == 4 and id != Nodes.DIAMOND) or (index != 4 and not WoodTypes.is_planks(id)): return {}
		pattern.append(id); ingredients[id] = int(ingredients.get(id,0))+1
	return {"name":"Jukebox","id":ID,"count":1,"pattern":pattern,"width":3,"ingredients":ingredients,"station":"table","dynamic":true}

static func station(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.stations.has(key): world.stations[key] = {"kind":"jukebox","slots":[empty()]}
	var data: Dictionary = world.stations[key]
	var slots: Array = data.get("slots",[]) if data.get("slots",[]) is Array else []
	var record: Dictionary = Inventory.clean_slot(slots[0]) if not slots.is_empty() and slots[0] is Dictionary else empty()
	if not is_disc(int(record.id)): record = empty()
	if record.id != 0: record.count = 1
	data.kind = "jukebox"; data.slots = [record]
	return data

static func players(world: VoxelWorld) -> Dictionary:
	if not world.has_meta("jukebox_players"): world.set_meta("jukebox_players",{})
	return world.get_meta("jukebox_players")

static func stop(world: VoxelWorld, p: Vector3i) -> void:
	if not world.has_meta("jukebox_players"): return
	var active: Dictionary = players(world)
	if not active.has(p): return
	var audio: AudioStreamPlayer3D = active[p]
	active.erase(p)
	if is_instance_valid(audio): audio.stop(); audio.queue_free()

static func reset(world: VoxelWorld) -> void:
	if not world.has_meta("jukebox_players"): return
	for p in players(world).keys(): stop(world,p)
	world.remove_meta("jukebox_players")

static func play(world: VoxelWorld, p: Vector3i, id: int) -> void:
	stop(world,p)
	var game: Node = world.get_parent()
	if game == null or not is_disc(id): return
	var audio := AudioStreamPlayer3D.new()
	audio.name = "JukeboxMusic"
	audio.stream = stream(id); audio.max_distance = HEAR_DISTANCE; audio.unit_size = 16.0
	audio.volume_db = 0.0 if game.audio_enabled else -80.0
	world.add_child(audio); audio.global_position = Vector3(p)+Vector3.ONE*0.5
	players(world)[p] = audio
	audio.play()

# Only currently playing boxes are visited; stored/silent discs need no work.
static func update(world: VoxelWorld, _delta: float) -> void:
	if not world.has_meta("jukebox_players"): return
	var game: Node = world.get_parent()
	for p in players(world).keys():
		var audio: AudioStreamPlayer3D = players(world)[p]
		if not is_instance_valid(audio) or not audio.playing or world.node_at(p) != ID or not world.loaded_at(Vector3(p)) or game == null or not is_instance_valid(game.player):
			stop(world,p); continue
		audio.volume_db = 0.0 if game.audio_enabled else -80.0

static func unload(world: VoxelWorld, column: Vector2i) -> void:
	if not world.has_meta("jukebox_players"): return
	for p in players(world).keys():
		if Vector2i(floori(float(p.x)/16),floori(float(p.z)/16)) == column: stop(world,p)

static func eject(world: VoxelWorld, p: Vector3i) -> bool:
	stop(world,p)
	var data: Dictionary = station(world,p)
	var record: Dictionary = data.slots[0].duplicate(true)
	data.slots[0] = empty()
	if record.id == 0: return false
	var game: Node = world.get_parent()
	if game != null and game.has_method("spawn_drop"):
		var drop: ItemDrop = game.spawn_drop(Vector3(p)+Vector3(0.5,1.1,0.5),record.id,1,record.wear,record.get("data",{}))
		drop.pickup_delay = 0.5
	return true

static func changed(world: VoxelWorld, p: Vector3i, old_id: int, id: int) -> void:
	if old_id != ID or id == ID: return
	eject(world,p)
	world.stations.erase(VoxelWorld.station_key(p))

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or int(target.id) != ID or game.world.node_at(target.pos) != ID: return false
	if game.target_mob() != null or Input.is_physical_key_pressed(KEY_CTRL) or game.touch and is_instance_valid(game.controls) and game.controls.sneak_held: return false
	var data: Dictionary = station(game.world,target.pos)
	if int(data.slots[0].id) != 0:
		eject(game.world,target.pos); game.player.swing = 1; return true
	var held: Dictionary = game.inventory.held()
	if not is_disc(int(held.id)) or int(held.count) <= 0: return true
	data.slots[0] = held.duplicate(true); data.slots[0].count = 1
	# Mineclonia deliberately has no creative bypass for an inserted record.
	game.inventory.consume_selected()
	play(game.world,target.pos,int(data.slots[0].id))
	var record: Dictionary = RECORDS[int(data.slots[0].id)]
	game.toast("Now playing: "+record.title+" — "+record.author+" ("+record.license+")")
	game.player.swing = 1
	return true

static func signal_strength(world: VoxelWorld, p: Vector3i) -> int:
	if world.node_at(p) != ID: return 0
	return int(RECORDS.get(int(station(world,p).slots[0].id),{}).get("signal",0))

# Preserve the source Mellohi probability among all102 weighted entries,
# including currently unavailable horse armor, instead of renormalizing it.
static func stronghold_records(rng: RandomNumberGenerator) -> Array:
	var records: Array = []
	for roll in rng.randi_range(2,3):
		if rng.randi_range(1,102) == 1: records.append({"id":MELLOHI,"count":1,"wear":0})
	return records

static func creeper_disc(rng: RandomNumberGenerator = null) -> int:
	return CREEPER_RECORDS[rng.randi_range(0,CREEPER_RECORDS.size()-1) if rng != null else randi_range(0,CREEPER_RECORDS.size()-1)]

# Called immediately after this arrow's damage. No persistent killer marker can
# leak onto a later player, fire, blast or environmental kill.
static func arrow_killed(mob: Node3D, shooter_kind: String, was_alive: bool) -> void:
	if not was_alive or mob.kind != "creeper" or shooter_kind not in ["skeleton","stray"] or mob.health > 0 or mob.has_meta("jukebox_record_drop"): return
	mob.set_meta("jukebox_record_drop",true)
	mob.game.spawn_drop(mob.position+Vector3.UP,creeper_disc(),1)

static func pixel(_id: int, x: int, y: int, noise: Color) -> Color:
	# Original Voxey cabinet art: framed lattice and dark record slot.
	if x in [0,1,14,15] or y in [0,1,14,15]: return Color("573821")
	if y in [3,4] and x in range(4,12): return Color("242225")
	if y >= 6 and (x+y)%4 == 0: return Color("4f382a")
	return noise.lightened(0.12) if x%4 == 0 else noise

static func draw(img: Image, id: int) -> void:
	var base := Color(DATA.get(id,{"color":"8e61a2"}).color)
	for y in 16:
		for x in 16:
			var radius: float = Vector2(x-7.5,y-7.5).length()
			if radius < 7 and radius > 1:
				var color: Color = base if radius < 3 else Color("303337")
				if radius > 4 and int(radius*2)%3 == 0: color = color.lightened(0.09)
				img.set_pixel(x,y,color)

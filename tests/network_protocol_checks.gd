extends SceneTree

var failures: int = 0

class Circuits extends RefCounted:
	var tracked: Dictionary = {}
	func refresh(_position: Vector3i) -> void: pass

class World extends RefCounted:
	var stations: Dictionary = {}
	var block_states: Dictionary = {}
	var circuits := Circuits.new()
	func station_key(p: Vector3i) -> String: return "%d,%d,%d"%[p.x,p.y,p.z]

class TestGame extends Node3D:
	var world := World.new()
	var day_time: float = 0.0

class Replica extends VoxeyNetwork:
	func client() -> bool: return true

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: print("PASS  "+message)
	else: failures += 1; push_error("FAIL  "+message)

func run() -> void:
	var motion := NetworkMotion.new()
	motion.update(Vector3.ZERO,deg_to_rad(179))
	motion.update(Vector3.RIGHT,deg_to_rad(-179),0.1)
	motion.advance(0.05)
	check(motion.current.x > 0.0 and motion.current.x < 1.0,"remote movement interpolates between received positions")
	check(absf(wrapf(motion.current_yaw-deg_to_rad(179),-PI,PI)) < deg_to_rad(3),"rotation crosses the angle seam by the short path")
	motion.advance(5.0)
	check(motion.current.x <= 1.5,"packet loss cannot cause unbounded extrapolation")
	motion.update(Vector3.RIGHT,0.0,0.1)
	motion.advance(1.0)
	check(motion.current.is_equal_approx(Vector3.RIGHT),"a stopped peer settles at its authoritative position")
	motion.update(Vector3.RIGHT*100,0.0)
	check(motion.current.is_equal_approx(Vector3.RIGHT*100),"teleports snap instead of flying through terrain")
	motion.update(Vector3(NAN,0,0),0.0)
	check(motion.current.is_finite(),"non-finite motion samples do not poison interpolation")
	var slow := NetworkMotion.new()
	var fast := NetworkMotion.new()
	for sample in [slow,fast]:
		sample.reset(Vector3.ZERO)
		sample.update(Vector3.RIGHT,0,0.1)
	for i in 6: slow.advance(1.0/60.0)
	for i in 24: fast.advance(1.0/240.0)
	check(slow.current.is_equal_approx(fast.current),"motion smoothing is independent of render frame rate")
	var sync := NetworkBlockSync.new()
	var column := Vector2i(5,-3)
	var first: int = sync.begin(column,7,0)
	sync.invalidate(column)
	var second: int = sync.begin(column,8,0)
	check(not sync.acknowledge(column,first,7) and sync.sending.has(column),"an old block acknowledgement cannot hide a newer edit")
	check(sync.acknowledge(column,second,8) and not sync.needed(column,8),"acknowledged columns stop resending")
	sync.invalidate(column)
	var expired: int = sync.begin(column,8,0)
	sync.expire(3001)
	var retry: int = sync.begin(column,8,3001)
	check(not sync.acknowledge(column,expired,8) and sync.acknowledge(column,retry,8),"late acknowledgements cannot complete a retried transfer")
	var net := Replica.new()
	var game := TestGame.new()
	net.game = game; net.loaded_announced = true
	var chest: Dictionary = {"slots":[{"id":1,"count":5}]}
	game.world.stations["chest"] = chest
	net.station_sequences["chest"] = 10
	net.world_state({"chest":{"slots":[{"id":1,"count":9}]}},{},[],[],0.5,9)
	check(chest.slots[0].count == 5,"an in-flight world snapshot cannot undo a completed chest transaction")
	net.world_state({"chest":{"slots":[{"id":1,"count":4}]}},{},[],[],0.6,11)
	check(chest.slots[0].count == 4 and is_same(chest,game.world.stations.chest),"new station snapshots preserve the open inventory's reference")
	net.world_state({}, {}, [], [], 0.7,12)
	check(game.world.stations.has("chest"),"absent delta entries do not delete unchanged stations")
	net.world_state({}, {}, ["chest"], [], 0.8,13)
	net.world_state({"chest":{"slots":[]}}, {}, [], [], 0.7,12)
	check(not game.world.stations.has("chest"),"stale snapshots cannot resurrect a removed station")
	game.world.stations["ghost"] = {"slots":[]}
	game.world.block_states["ghost"] = {"on":true}
	net.world_state({}, {}, [], [], 0.9,14,true)
	check(game.world.stations.is_empty() and game.world.block_states.is_empty(),"full checkpoints remove rejected client-only metadata predictions")
	var snapshots: Array = []
	for i in 50:
		snapshots.append({"key":100+i,"at":Vector3(i,2,3),"yaw":0.0,"stack":{"description":"x".repeat(10000)}})
	var batches: Array = VoxeyNetwork.entity_motion_batches(snapshots)
	var total: int = 0
	var bounded: bool = true
	for batch in batches:
		total += batch.size()
		bounded = bounded and var_to_bytes(batch).size() <= 1000
	check(total == 50 and bounded,"large entity populations use motion packets below the MTU without item metadata")
	var roster: Dictionary = {}
	for i in VoxeyNetwork.MAX_PLAYERS: roster[i] = [Vector3.ONE,0.0]
	check(var_to_bytes(roster).size() <= 1200,"a full player roster fits in one motion packet")
	for key in [100,101]:
		net.replicas[key] = Node3D.new()
		net.replica_motion[key] = NetworkMotion.new()
		net.replica_motion[key].reset(Vector3.ZERO)
	net.entity_motion([[100,Vector3.RIGHT,0.0]],12)
	net.entity_motion([[101,Vector3.RIGHT,0.0]],11)
	net.entity_motion([[100,Vector3.LEFT,0.0]],10)
	check(net.replica_motion[100].target == Vector3.RIGHT and net.replica_motion[101].target == Vector3.RIGHT,"reordered motion batches preserve independent entity sequences")
	for entity in net.replicas.values(): entity.free()
	net.free(); game.free()
	print("NETWORK PROTOCOL TESTS: ",failures," failed")
	quit(1 if failures else 0)

extends SceneTree
var failures: int = 0
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-arrow-reference-"+str(OS.get_process_id()))
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures < 8: push_error(message)
func vec(v: Array) -> Vector3: return Vector3(v[0],v[1],v[2])
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/arrow_flight_reference.json"))
	for row in source.drag:
		var velocity: Vector3 = vec(row.initial); var life: float = 0; var clock: float = 0
		for i in row.deltas.size():
			life += row.deltas[i]
			if life <= ArrowFlight.FLIGHT_LIFETIME:
				var state: Dictionary = ArrowFlight.drag(velocity,life,clock); velocity = state.velocity; clock = state.clock
			check(velocity.is_equal_approx(vec(row.steps[i].velocity)) and is_equal_approx(clock,row.steps[i].drag) and (life > ArrowFlight.FLIGHT_LIFETIME) == row.steps[i].removed,"Drag/lifetime differs: "+str(row)+" step="+str(i))
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Arrow source checks","survival")
	while game.state == "loading": await process_frame
	game.set_process(false); game.world.set_process(false); game.player.set_process(false); game.player.set_physics_process(false)
	game.state = "playing"; game.player.position = Vector3(80,1800,80)
	for row in source.liquids:
		var arrow: Arrow = game.spawn_arrow(Vector3(8,1800,8),Vector3(30,4,-5)); arrow.set_physics_process(false)
		for i in row.names.size():
			var id: int = Nodes.WATER if row.names[i] == "mcl_core:water_source" else Nodes.LAVA if row.names[i] == "mcl_core:lava_source" else Fire.FLAME
			arrow.visit_node(Vector3i(0 if row.same else i+1,0,0),id)
			check(arrow.velocity.is_equal_approx(vec(row.stages[i].velocity)) and arrow.flame == row.stages[i].burning,"Liquid/fire traversal differs "+str(row))
		arrow.free()
	var at := Vector3(8,1800,8)
	for row in source.stuck:
		var arrow: Arrow = game.spawn_arrow(at,Vector3(30,4,-5)); arrow.set_physics_process(false); arrow.critical = true; arrow.piercing = 3
		game.world.set_node(Vector3i(at),Nodes.STONE)
		arrow.embed(at+Vector3(0.5,0,0),Vector3i(at),arrow.velocity)
		check(arrow.position.is_equal_approx(at+vec(row.initial.position)) and arrow.velocity == Vector3.ZERO and not arrow.critical and arrow.piercing == 0,"Embedding differs "+str(row))
		game.world.set_node(Vector3i(at),Nodes.AIR if row.support == "air" else Nodes.WATER if row.support == "mcl_core:water_source" else Nodes.STONE)
		arrow._physics_process(row.dt)
		check(arrow.is_queued_for_deletion() == row.after.removed and arrow.stuck == row.after.stuck,"Stuck state differs "+str(row))
		if not arrow.is_queued_for_deletion():
			var remaining: float = (ArrowFlight.STUCK_LIFETIME if arrow.stuck else ArrowFlight.FLIGHT_LIFETIME)-arrow.life
			check(is_equal_approx(remaining,120-row.after.life),"Stuck lifetime differs "+str(row))
		arrow.free()
	for row in source.pickup:
		for drop in game.drops.get_children(): drop.free()
		var arrow: Arrow = game.spawn_arrow(at,Vector3(30,0,0)); arrow.set_physics_process(false)
		arrow.item_id = Nodes.ARROW_ITEM if row.name == "mcl_bows:arrow" else VillageContent.POISON_ARROW
		arrow.potion_data = {"custom_name":"Named arrow"}; arrow.recoverable = row.collectable
		arrow.embed(at+Vector3(0.5,0,0),Vector3i(at),arrow.velocity)
		game.player.position = arrow.position; game.gamemode = "creative" if row.creative else "survival"
		arrow._physics_process(0.25)
		check(arrow.is_queued_for_deletion() == row.after.removed,"Pickup removal differs "+str(row))
		var has_drop: bool = row.get("dropped") is Dictionary
		check((game.drops.get_child_count() > 0) == has_drop,"Pickup spawn differs "+str(row))
		if has_drop:
			var drop: ItemDrop = game.drops.get_child(0)
			check(drop.item_id == arrow.item_id and drop.amount == 1 and drop.data.custom_name == "Named arrow" and drop.velocity == Vector3.ZERO,"Pickup item metadata differs "+str(row))
		arrow.free()
	print("ARROW FLIGHT SOURCE: %d drag sequences, %d liquid sequences, %d embedded states, %d pickups; %d failures"%[source.drag.size(),source.liquids.size(),source.stuck.size(),source.pickup.size(),failures])
	game.queue_free(); for i in 4: await process_frame
	quit(1 if failures else 0)

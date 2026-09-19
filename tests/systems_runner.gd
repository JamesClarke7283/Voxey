extends SceneTree

var passed: int = 0
var failed: int = 0

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-systems-tests-"+str(OS.get_process_id()))
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition: passed += 1; print("PASS  "+message)
	else: failed += 1; push_error("FAIL  "+message)

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Systems checks","survival")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	check(game.state == "playing","systems regression world loads")
	if game.state != "playing": game.queue_free(); quit(1); return
	game.pause()
	game.set_process(false); game.world.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	load("res://tests/composter_checks.gd").run(self,game)
	load("res://tests/hunger_checks.gd").run(self,game)
	load("res://tests/swimming_checks.gd").run(self,game)
	load("res://tests/shearing_checks.gd").run(self,game)
	load("res://tests/storage_checks.gd").run(self,game)
	load("res://tests/cauldron_checks.gd").run(self,game)
	print("SYSTEMS TESTS: %d passed, %d failed"%[passed,failed])
	game.queue_free()
	for i in 4: await process_frame
	quit(1 if failed else 0)

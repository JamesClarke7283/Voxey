extends SceneTree
var passed: int = 0
var failed: int = 0
func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-village-check-worlds")
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	if condition: passed += 1; print("PASS  "+message)
	else: failed += 1; print("FAIL  "+message)
func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.touch = true; game.audio_enabled = false; game.world.radius = 2
	game.start_new("8675309","Village checks","creative")
	while game.state == "loading": await process_frame
	game.pause()
	await load("res://tests/village_checks.gd").run(self,game)
	print("VILLAGE TESTS: %d passed, %d failed"%[passed,failed])
	game.queue_free()
	for i in 4: await process_frame
	quit(1 if failed else 0)

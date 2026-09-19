extends SceneTree

var passed: int = 0
var failed: int = 0

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR","/tmp/voxey-lifecycle-tests-"+str(OS.get_process_id()))
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition: passed += 1; print("PASS  "+message)
	else: failed += 1; push_error("FAIL  "+message)

func run() -> void:
	var game: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.audio_enabled = false; game.touch = true; game.world.radius = 2
	game.start_new("8675309","Survival lifecycle checks","survival")
	var deadline: int = Time.get_ticks_msec()+60000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await process_frame
	check(game.state == "playing","survival lifecycle regression world loads")
	if game.state != "playing": game.queue_free(); quit(1); return
	game.pause()
	game.set_process(false); game.world.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	var checks: PackedStringArray = OS.get_cmdline_user_args()
	if checks.is_empty():
		checks = PackedStringArray(["name_tag","fishing","campfire","farming","barrier","sensors","pasture","light_emission","trapdoor","throwing","snow_cover","concrete","candle","glass_color","raw_ore","nether_block","anvil","concrete_piston","zombie_siege","wandering_trader","painting","raid_mob","crimson_plant","pale_oak","copper_decor","bookshelf","maps","boats","food_feature","sign","door","wood","wood_crafting","input_device","note_block","dense_material","jukebox","dungeon","fruit_crop","beehive","amethyst","spyglass","piston","farmland","crop_farming","golem","copper","weather","sponge","decor","rail","corridor","firework","head","scaffold","dial","conduit","treasure","coral","pickle","seagrass","kelp","shield","banner","beacon","totem","guardian","wither","ruin","shipwreck","temple","offhand","aquatic","magma","portal","trapped_chest","jungle","outpost","monster_egg","zombie_villager","igloo","witch_hut","ocean_temple","woodland_cabin","guardian_aura","lantern","dripstone","ice_spike","bamboo","powder_snow","lush_cave"])
	for group in checks: await load("res://tests/"+group+"_checks.gd").run(self,game)
	print("LIFECYCLE TESTS: %d passed, %d failed"%[passed,failed])
	game.queue_free()
	for i in 4: await process_frame
	quit(1 if failed else 0)

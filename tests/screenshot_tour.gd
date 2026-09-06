extends SceneTree

# Visual smoke test: builds a throwaway world and saves screenshots of the
# crack overlay, creatures, the armor inventory, and a large chest.
# Run with tests/screenshots.sh; images land in /tmp/voxey-shots.
var game
var shots: String = "/tmp/voxey-shots"

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR",OS.get_cache_dir().path_join("voxey-tour-"+str(OS.get_process_id())))
	DirAccess.make_dir_recursive_absolute(shots)
	call_deferred("run")

func snap(name_value: String) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png(shots.path_join(name_value+".png"))
	print("SHOT "+name_value)

func settle_frames(count: int) -> void:
	for i in count: await process_frame

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.world.radius=3
	var timeout: int=Time.get_ticks_msec()+30000
	while not game.world.area_ready(game.world.target) and Time.get_ticks_msec()<timeout: await process_frame
	game.start_new("8675309","Tour","creative")
	timeout=Time.get_ticks_msec()+30000
	while game.state=="loading" and Time.get_ticks_msec()<timeout: await process_frame
	await settle_frames(20)
	# Stage: player on flat ground facing -Z with a clear view.
	var player=game.player
	var base := Vector3i(player.position.floor())
	for x in range(-4,5):
		for z in range(-9,3):
			for y in range(-1,8): game.world.set_node(base+Vector3i(x,y,z),Nodes.AIR if y>=0 else Nodes.GRASS)
	player.position=Vector3(base.x+0.5,base.y+0.01,base.z+0.5)
	player.rotation.y=0
	player.camera.rotation.x=-0.05
	player.set_process(false)
	player.set_physics_process(false)
	game.set_gamemode("survival")
	player.armor_slots[0]={"id":Nodes.armor_id(1,0),"count":1,"wear":0}
	player.armor_slots[1]={"id":Nodes.armor_id(3,1),"count":1,"wear":10}
	player.armor_slots[3]={"id":Nodes.armor_id(0,3),"count":1,"wear":2}
	player.health=14; player.hunger=17
	game.inventory.slots[0]={"id":Nodes.TOOLS+10,"count":1,"wear":30}
	game.inventory.slots[1]={"id":Nodes.STONE,"count":12,"wear":0}
	game.inventory.slots[2]={"id":Nodes.TNT,"count":3,"wear":0}
	game.inventory.slots[3]={"id":Nodes.armor_id(2,2),"count":1,"wear":0}
	game.inventory.slots[4]={"id":Nodes.BONE_MEAL,"count":9,"wear":0}
	game.inventory.selected=0
	player._make_hand(Nodes.TOOLS+10)
	# Crack overlay on a stone node straight ahead at eye level.
	var block := base+Vector3i(0,1,-3)
	game.world.set_node(block,Nodes.STONE)
	game.world.set_node(block+Vector3i.DOWN,Nodes.COBBLE)
	game.world.set_node(block+Vector3i(1,0,0),Nodes.SAND)
	game.world.set_node(block+Vector3i(1,-1,0),Nodes.DIRT)
	game.world.set_node(block+Vector3i(-1,-1,0),Nodes.TNT)
	await settle_frames(30)
	player.cracks.visible=true
	player.cracks.position=Vector3(block)+Vector3.ONE*0.5
	player.crack_material.albedo_texture=player.crack_textures[5]
	player.selection.visible=true
	player.selection.position=Vector3(block)
	player.target={"pos":block,"normal":Vector3i.BACK,"id":Nodes.STONE,"distance":3.0}
	player.mining=0.6
	game.dig_particles(block,Nodes.STONE,Vector3i.BACK)
	await snap("01_crack_overlay")
	player.crack_material.albedo_texture=player.crack_textures[8]
	await snap("02_crack_final_stage")
	# All crack stages as a strip for review.
	var strip := Image.create(9*34,34,false,Image.FORMAT_RGBA8)
	strip.fill(Color("8a8c88"))
	for stage in 9: strip.blend_rect(Art.crack_texture(stage).get_image(),Rect2i(0,0,32,32),Vector2i(stage*34+1,1))
	strip.resize(9*34*4,34*4,Image.INTERPOLATE_NEAREST)
	strip.save_png(shots.path_join("03_crack_stages.png"))
	player.cracks.visible=false
	player.selection.visible=false
	# Creatures in a line.
	game.world.set_node(block,Nodes.AIR)
	game.world.set_node(block+Vector3i.DOWN,Nodes.AIR)
	game.world.set_node(block+Vector3i(1,0,0),Nodes.AIR)
	game.world.set_node(block+Vector3i(1,-1,0),Nodes.AIR)
	game.world.set_node(block+Vector3i(-1,-1,0),Nodes.AIR)
	var kinds: Array=["sheep","cow","pig","chicken","zombie","skeleton","spider","creeper"]
	for i in kinds.size():
		var mob=game.spawn_creature(kinds[i],Vector3(base.x-3.5+i,base.y,base.z-5.5 if i%2==0 else base.z-4.0))
		mob.set_physics_process(false)
		mob.model.rotation.y=PI
	var arrow := Arrow.new()
	arrow.game=game; arrow.position=Vector3(base.x+1.5,base.y+1.4,base.z-2.5); arrow.velocity=Vector3(0,0,3)
	game.entities.add_child(arrow)
	arrow.set_physics_process(false)
	for id in [Nodes.STONE,Nodes.SAPLING,Nodes.LOG]:
		game.spawn_drop(Vector3(base.x-1.0+float([Nodes.STONE,Nodes.SAPLING,Nodes.LOG].find(id)),base.y+0.3,base.z-2.0),id,3)
	await settle_frames(20)
	for drop in game.drops.get_children(): drop.set_physics_process(false)
	await snap("04_creatures")
	# Inventory with the armor column.
	game.open_inventory("hand")
	await snap("05_inventory_armor")
	# Large chest.
	var chest_a := base+Vector3i(3,0,-2)
	var chest_b := chest_a+Vector3i(1,0,0)
	game.world.set_node(chest_a,Nodes.CHEST)
	game.world.set_node(chest_b,Nodes.CHEST)
	var large: Dictionary=game.world.get_station(chest_a,"chest")
	large.slots[0]={"id":Nodes.DIAMOND,"count":7,"wear":0}
	large.slots[1]={"id":Nodes.LEATHER,"count":4,"wear":0}
	large.slots[27]={"id":Nodes.GUNPOWDER,"count":12,"wear":0}
	large.slots[53]={"id":Nodes.armor_id(2,0),"count":1,"wear":0}
	game.open_inventory("chest",chest_b)
	await snap("06_large_chest")
	game.hud.show_console("/spawn ")
	await snap("07_console")
	# Beds from both ends: catch culled side faces and holes in the floor.
	game.pause()
	game.hud.visible = false
	player.hand.visible = false
	for container in [game.creatures,game.drops,game.entities]:
		for child in container.get_children(): child.free()
	game.world.set_node(base+Vector3i(-2,0,-3),Nodes.BED_FOOT)
	game.world.set_node(base+Vector3i(-2,0,-4),Nodes.BED_HEAD)
	game.world.set_node(base+Vector3i(0,0,-3),Nodes.BED_FOOT)
	game.world.set_node(base+Vector3i(1,0,-3),Nodes.BED_HEAD)
	game.world.set_node(base+Vector3i(2,0,-3),Nodes.PLANKS)
	player.position = Vector3(base)+Vector3(0.5,1.0,0.5)
	player.camera.look_at(Vector3(base)+Vector3(0,0.25,-3.0))
	await settle_frames(30)
	await snap("10_beds_front")
	player.position = Vector3(base)+Vector3(0.5,1.0,-6.5)
	player.camera.look_at(Vector3(base)+Vector3(0,0.25,-3.0))
	await snap("11_beds_back")
	print("TOUR DONE")
	game.queue_free()
	await process_frame
	quit(0)

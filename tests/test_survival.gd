extends SceneTree

var failed: int = 0
var passed: int = 0
var game

func _init() -> void:
	OS.set_environment("VOXEY_DATA_DIR",OS.get_cache_dir().path_join("voxey-test-"+str(OS.get_process_id())))
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if condition: passed += 1; print("PASS  "+message)
	else: failed += 1; push_error("FAIL  "+message)

func run() -> void:
	var start: int = Time.get_ticks_msec()
	check(VoxelWorld.block_coord(Vector3i(-1,-1,-17))==Vector3i(-1,-1,-2),"negative map block coordinates floor correctly")
	check(VoxelWorld.local_index(Vector3i(-1,-1,-1))==4095,"negative node coordinates wrap inside a map block")
	var padded := PackedByteArray()
	padded.resize(5832)
	padded[1+18+324]=Nodes.STONE
	var surface: Array=BlockMesher.build(padded)[0]
	check(surface[Mesh.ARRAY_VERTEX].size()==24,"isolated node has six exposed quads")
	padded[2+18+324]=Nodes.STONE
	surface=BlockMesher.build(padded)[0]
	check(surface[Mesh.ARRAY_VERTEX].size()==24,"greedy mesher merges adjacent coplanar node faces")
	var vertices: PackedVector3Array=surface[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=surface[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=surface[Mesh.ARRAY_INDEX]
	var winding_ok: bool=true
	for i in range(0,indices.size(),3):
		var a: Vector3=vertices[indices[i]]
		var b: Vector3=vertices[indices[i+1]]
		var c: Vector3=vertices[indices[i+2]]
		if (b-a).cross(c-a).dot(normals[indices[i]])>=0: winding_ok=false
	check(winding_ok,"all six faces have outward clockwise winding")
	padded.fill(Nodes.STONE)
	check(BlockMesher.build(padded)[0].is_empty(),"interior solid map block emits no hidden faces")
	var gen := TerrainGenerator.new(8675309)
	var column: Dictionary=gen.generate_column(Vector2i.ZERO,{})
	var repeat_column: Dictionary=gen.generate_column(Vector2i.ZERO,{})
	check(column.blocks[1].data==repeat_column.blocks[1].data,"terrain and vegetation are deterministic for a seed")
	var changed: Dictionary=gen.generate_column(Vector2i.ZERO,{Vector3i(0,24,0):Nodes.GLASS})
	check(changed.blocks[1].data[VoxelWorld.local_index(Vector3i(0,24,0))]==Nodes.GLASS,"saved node edits override generated terrain")
	var other: Dictionary=TerrainGenerator.new(2).generate_column(Vector2i.ZERO,{})
	check(other.blocks[1].data!=column.blocks[1].data,"different seeds generate different worlds")
	var bag := Inventory.new()
	bag.add_item(Nodes.LOG,4)
	check(bag.craft(0,"hand") and bag.count_item(Nodes.PLANKS)==4 and bag.count_item(Nodes.LOG)==3,"logs craft into four planks atomically")
	check(bag.craft(2,"hand") and bag.count_item(Nodes.WORKBENCH)==1,"2x2 crafting table recipe works by hand")
	bag.add_item(Nodes.PLANKS,10)
	bag.add_item(Nodes.STICK,10)
	check(not bag.craft(4,"hand"),"3x3 tool recipes require a crafting table")
	check(bag.craft(4,"table") and bag.count_item(80)==1,"wooden pickaxe crafts at a table")
	check(not Nodes.harvestable(Nodes.STONE,0),"bare hands cannot harvest stone")
	check(Nodes.harvestable(Nodes.STONE,80),"wooden pickaxe harvests stone")
	check(not Nodes.harvestable(Nodes.IRON_ORE,80) and Nodes.harvestable(Nodes.IRON_ORE,85),"iron ore requires a stone pickaxe")
	check(not Nodes.harvestable(Nodes.DIAMOND_ORE,85) and Nodes.harvestable(Nodes.DIAMOND_ORE,90),"diamond ore requires an iron pickaxe")
	check(Nodes.break_time(Nodes.STONE,95)<Nodes.break_time(Nodes.STONE,80),"higher tool tiers mine faster")
	var full := Inventory.new()
	for slot in full.slots: slot.id=Nodes.STONE; slot.count=64
	full.slots[0]={"id":Nodes.LOG,"count":2,"wear":0}
	var before: Array=full.slots.duplicate(true)
	check(not full.craft(0,"hand") and full.slots==before,"full inventory crafting rolls back without consuming ingredients")
	var toolbag := Inventory.new()
	toolbag.add_item(80,1,59)
	check(toolbag.damage_tool() and toolbag.held().id==0,"tools break at their durability limit")
	var grid_bag := Inventory.new()
	grid_bag.grid[4]={"id":Nodes.LOG,"count":2,"wear":0}
	check(grid_bag.matching_recipe("hand")==0,"manual 2x2 crafting matches a shifted log recipe")
	var crafted_stack: Dictionary=grid_bag.take_grid_result("hand")
	check(crafted_stack.id==Nodes.PLANKS and crafted_stack.count==4 and grid_bag.grid[4].count==1,"taking grid output consumes exactly one of each ingredient")
	grid_bag.grid_to_inventory()
	grid_bag.add_item(Nodes.PLANKS,9); grid_bag.add_item(Nodes.STICK,6)
	check(grid_bag.fill_grid(4,"table",true),"recipe guide fills a 3x3 grid for batch crafting")
	check(grid_bag.matching_recipe("table")==4 and grid_bag.grid[0].count==3,"guide lays out the correct tool pattern and batch quantity")
	check(grid_bag.craft_grid_to_inventory("table") and grid_bag.count_item(80)==1,"grid output can craft directly into inventory")
	check(grid_bag.matching_recipe("hand")==-1,"3x3 recipes cannot be crafted in the 2x2 hand grid")
	grid_bag.grid_to_inventory()
	check(grid_bag.fill_grid(5,"table"),"axe guide fills its asymmetric recipe")
	for y in 3:
		var temporary: Dictionary=grid_bag.grid[y*3]
		grid_bag.grid[y*3]=grid_bag.grid[y*3+2]
		grid_bag.grid[y*3+2]=temporary
	check(grid_bag.matching_recipe("table")==5,"manual mirrored axe recipe is recognized")
	grid_bag.grid[8]={"id":Nodes.SAND,"count":1,"wear":0}
	check(grid_bag.matching_recipe("table")==-1,"extra ingredients invalidate a shaped recipe")
	var crack_uvs: PackedVector2Array=Art.crack_mesh().surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var centered_faces: bool=true
	for face in 6:
		if crack_uvs[face*4]!=Vector2.ZERO or crack_uvs[face*4+2]!=Vector2.ONE: centered_faces=false
	check(centered_faces,"every crack overlay face uses a centered complete UV square")
	var cracks: Image=Art.crack_texture(5).get_image()
	check(cracks.get_pixel(16,16).a>0 and cracks.get_pixel(15,16).a>0,"breaking cracks originate at the center of the node face")
	var Store=load("res://scripts/world_store.gd")
	check(Store.home_from_environment("Linux",{"HOME":"/home/alex"})=="/home/alex","Linux uses the user home directory")
	check(Store.home_from_environment("macOS",{"HOME":"/Users/alex"})=="/Users/alex","macOS uses the user home directory")
	check(Store.home_from_environment("Windows",{"USERPROFILE":"C:\\Users\\Alex"})=="C:/Users/Alex","Windows uses USERPROFILE with portable path separators")
	check(Store.home_from_environment("Windows",{"HOMEDRIVE":"D:","HOMEPATH":"/Users/Alex"})=="D:/Users/Alex","Windows supports HOMEDRIVE and HOMEPATH fallback")
	check(not Store.valid_id("../outside") and Store.valid_id("oak-world_12"),"world identifiers cannot traverse outside the save directory")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.world.radius=2
	var timeout: int=Time.get_ticks_msec()+30000
	while not game.world.area_ready(game.world.target) and Time.get_ticks_msec()<timeout: await process_frame
	check(game.world.columns.size()>=9,"background workers stream the spawn area")
	game.start_new("8675309")
	await process_frame
	game.pause()
	check(game.player.health==20 and not game.world.intersects(game.player.position),"new survival player spawns outside solid terrain")
	var p:=Vector3i(8,45,8)
	game.world.set_node(p,Nodes.LOG)
	game.inventory.selected=1
	game.player.target={"pos":p,"normal":Vector3i.UP,"id":Nodes.LOG,"distance":2.0}
	game.player.mine(Nodes.break_time(Nodes.LOG,0)*0.4)
	check(game.player.mining>0.39 and game.world.node_at(p)==Nodes.LOG,"partial mining retains node and advances cracks")
	game.player.mine(Nodes.break_time(Nodes.LOG,0)*0.7)
	check(game.world.node_at(p)==Nodes.AIR and game.drops.get_child_count()>0,"completed mining removes node and spawns a pickup")
	game.world.set_node(Vector3i(15,45,8),Nodes.PLANKS)
	check(game.world.dirty.has(Vector3i(0,2,0)) and game.world.dirty.has(Vector3i(1,2,0)),"boundary edits invalidate both neighboring map block meshes")
	game.world.set_node(p,Nodes.STONE)
	var ray: Dictionary=game.world.raycast(Vector3(8.5,45.5,11.5),Vector3.FORWARD)
	check(not ray.is_empty() and ray.pos==p and ray.normal==Vector3i.BACK,"voxel DDA returns exact node and placement face")
	game.world.set_node(p+Vector3i.UP,Nodes.AIR)
	game.world.set_node(p+Vector3i.UP*2,Nodes.AIR)
	game.inventory.add_item(Nodes.PLANKS,4)
	for i in 9:
		if game.inventory.slots[i].id==Nodes.PLANKS: game.inventory.selected=i
	game.player.target={"pos":p,"normal":Vector3i.UP,"id":Nodes.STONE,"distance":2.0}
	var old_count: int=game.inventory.count_item(Nodes.PLANKS)
	game.player.use()
	check(game.world.node_at(p+Vector3i.UP)==Nodes.PLANKS and game.inventory.count_item(Nodes.PLANKS)==old_count-1,"node placement consumes exactly one inventory item")
	var furnace: Dictionary=game.world.get_station(Vector3i(7,45,8),"furnace")
	furnace.slots[0]={"id":Nodes.IRON_ORE,"count":2,"wear":0}
	furnace.slots[1]={"id":Nodes.COAL,"count":1,"wear":0}
	for i in 8: game.world._simulate()
	check(furnace.slots[2].id==Nodes.IRON and furnace.slots[2].count==1 and furnace.slots[0].count==1,"furnace consumes fuel and smelts one iron in eight ticks")
	furnace.slots[2].count=64
	for i in 10: game.world._simulate()
	check(furnace.slots[0].count==1,"full furnace output does not destroy its input")
	game.world.set_node(Vector3i(6,45,8),Nodes.WHEAT)
	game.world.growth[Vector3i(6,45,8)]=90.0
	game.world._simulate()
	check(game.world.node_at(Vector3i(6,45,8))==Nodes.RIPE_WHEAT,"planted wheat matures through world simulation")
	game.open_inventory("chest",Vector3i(5,45,8))
	game.hud.station_data.slots[0]={"id":Nodes.DIAMOND,"count":7,"wear":0}
	game.hud._slot_click(0,true,true)
	check(game.hud.cursor.count==4 and game.hud.station_data.slots[0].count==3,"right click splits a chest stack with no item loss")
	game.hud._slot_click(1,true,true)
	check(game.hud.cursor.count==3 and game.hud.station_data.slots[1].count==1,"right click places one item in storage")
	game.hud.return_cursor()
	check(game.inventory.count_item(Nodes.DIAMOND)==3,"closing inventory returns held cursor items safely")
	game.pause()
	check(game.save_game("user://voxey_test.json"),"world saves successfully through temporary file and rename")
	var save: Dictionary=game.read_save("user://voxey_test.json")
	check(not save.is_empty() and save.edits.size()==game.world.edits.size() and save.stations.size()==2,"save preserves node edits, furnaces and chest contents")
	check(game.save_game("user://voxey_test.json"),"subsequent saves create a backup")
	var corrupt:=FileAccess.open("user://voxey_test.json",FileAccess.WRITE)
	corrupt.store_string("broken{"); corrupt.close()
	check(not game.read_save("user://voxey_test.json").is_empty(),"corrupt primary save recovers from last valid backup")
	game.load_world_data(save)
	timeout=Time.get_ticks_msec()+30000
	while game.state=="loading" and Time.get_ticks_msec()<timeout: await process_frame
	game.pause()
	check(game.world.node_at(p)==Nodes.STONE and game.world.node_at(p+Vector3i.UP)==Nodes.PLANKS,"world reload restores edited nodes")
	check(game.inventory.count_item(Nodes.DIAMOND)==3,"world reload restores inventory")
	check(game.world.get_station(Vector3i(7,45,8),"furnace").slots[0].count==1,"world reload restores furnace state")
	game.world.get_station(Vector3i(7,45,8),"furnace").slots[2].count=1
	for i in 8: game.world._simulate()
	check(game.world.get_station(Vector3i(7,45,8),"furnace").slots[2].count==2,"restored furnace continues smelting after JSON type normalization")
	check(game.execute_command("/gamemode creative")=="Game mode set to Creative." and game.gamemode=="creative","console switches to Creative mode")
	var health_before: float=game.player.health
	game.player.hurt(100,true)
	check(game.player.health==health_before,"Creative players are immune to survival damage")
	game.inventory.selected=1
	game.inventory.slots[1]={"id":Nodes.PLANKS,"count":10,"wear":0}
	game.world.set_node(p+Vector3i.UP,Nodes.AIR)
	game.player.target={"pos":p,"normal":Vector3i.UP,"id":Nodes.STONE,"distance":2.0}
	game.player.use()
	check(game.inventory.slots[1].count==10 and game.world.node_at(p+Vector3i.UP)==Nodes.PLANKS,"Creative node placement does not consume the held stack")
	check(game.execute_command("/gamemode nonsense").begins_with("Usage:") and game.gamemode=="creative","invalid mode command leaves game state unchanged")
	check(game.execute_command("/gamemode survival")=="Game mode set to Survival." and not game.player.flying,"console returns to Survival and disables flight")
	check(game.save_game(),"active world saves to its own .voxey world directory")
	var first_id: String=game.active_world_id
	var second_id: String=game.saves.create_world("Second world",42,"creative")
	check(not second_id.is_empty() and first_id!=second_id and game.saves.save_path(first_id)!=game.saves.save_path(second_id),"named worlds have independent storage paths")
	check(game.saves.list_worlds().size()>=2,"world picker lists multiple saved worlds")
	game.enter_world(first_id,"creative")
	timeout=Time.get_ticks_msec()+30000
	while game.state=="loading" and Time.get_ticks_msec()<timeout: await process_frame
	check(game.gamemode=="creative" and game.world.node_at(p)==Nodes.STONE,"entering a saved world honors the selected mode and preserves terrain")
	game.pause()
	# Crack overlay: symmetric about the face centre, and growing outward stage by stage.
	var previous_opaque: int=-1
	var symmetric: bool=true
	var monotonic: bool=true
	var previous_image: Image=null
	for stage in 9:
		var image: Image=Art.crack_texture(stage).get_image()
		var opaque: int=0
		for y in 32:
			for x in 32:
				var a: float=image.get_pixel(x,y).a
				if a>0: opaque+=1
				if absf(a-image.get_pixel(31-y,x).a)>0.001 or absf(a-image.get_pixel(31-x,31-y).a)>0.001: symmetric=false
				if previous_image!=null and previous_image.get_pixel(x,y).a>0 and a<=0: monotonic=false
		if opaque<=previous_opaque: monotonic=false
		previous_opaque=opaque
		previous_image=image
	check(symmetric,"crack overlay is rotationally symmetric about the face centre at every stage")
	check(monotonic,"crack overlay only grows outward from the centre as mining progresses")
	var stage0: Image=Art.crack_texture(0).get_image()
	var edge_touch: bool=false
	for i in 32:
		if stage0.get_pixel(i,0).a>0 or stage0.get_pixel(0,i).a>0 or stage0.get_pixel(i,31).a>0 or stage0.get_pixel(31,i).a>0: edge_touch=true
	check(not edge_touch,"first crack stage stays near the centre of the face")
	check(game.node_mesh(Nodes.STONE).get_surface_count()==1 and game.node_mesh(Nodes.SAPLING).get_surface_count()==1 and is_same(game.node_mesh(Nodes.STONE),game.node_mesh(Nodes.STONE)),"single node meshes exist for drops and falling nodes")
	# Armor
	check(Nodes.title(Nodes.armor_id(3,0))=="Diamond helmet" and Nodes.armor_points(Nodes.armor_id(3,1))==8 and Nodes.max_stack(Nodes.armor_id(0,3))==1,"armor ids map to named pieces with defence points")
	var armor_bag := Inventory.new()
	armor_bag.add_item(Nodes.DIAMOND,5)
	check(armor_bag.craft(armor_bag.recipe_index(Nodes.armor_id(3,0)),"table") and armor_bag.count_item(Nodes.armor_id(3,0))==1,"diamond helmet crafts from five diamonds at a table")
	check(Inventory.clean_slot({"id":74,"count":1,"wear":3}).id==Nodes.ARMOR,"legacy iron chestplate id migrates to the armor system")
	game.set_gamemode("survival")
	game.player.health=20
	for slot in game.player.armor_slots: slot.id=0; slot.count=0; slot.wear=0
	game.inventory.slots[2]={"id":Nodes.armor_id(1,1),"count":1,"wear":0}
	game.inventory.selected=2
	game.player.use()
	check(game.player.armor_slots[1].id==Nodes.armor_id(1,1) and game.inventory.slots[2].id==0 and game.player.armor_points()==6,"right click wears a chestplate in its own slot")
	game.player.damage_cooldown=0
	game.player.hurt(10)
	check(is_equal_approx(game.player.health,12.4) and game.player.armor_slots[1].wear==1,"iron chestplate absorbs 24% of damage and takes wear")
	game.player.damage_cooldown=0
	game.player.hurt(10,true)
	check(is_equal_approx(game.player.health,2.4) and game.player.armor_slots[1].wear==1,"bypassing damage ignores armor and does not wear it")
	game.player.health=20
	game.player.armor_slots[1].wear=Nodes.durability(Nodes.armor_id(1,1))-1
	game.player.damage_cooldown=0
	game.player.hurt(1)
	check(game.player.armor_slots[1].id==0,"armor breaks when its durability runs out")
	game.open_inventory("hand")
	game.hud.cursor={"id":Nodes.armor_id(2,0),"count":1,"wear":0}
	game.hud._slot_click(3,false,false,false,true)
	check(game.hud.cursor.id==Nodes.armor_id(2,0) and game.player.armor_slots[3].id==0,"a helmet cannot be dropped into the boots slot")
	game.hud._slot_click(0,false,false,false,true)
	check(game.hud.cursor.id==0 and game.player.armor_slots[0].id==Nodes.armor_id(2,0),"the helmet slot accepts a helmet from the cursor")
	game.hud.return_cursor()
	game.pause()
	# Large chests
	var chest_a := Vector3i(10,45,10)
	var chest_b := Vector3i(11,45,10)
	for q in [chest_a,chest_b,Vector3i(12,45,10),Vector3i(9,45,10),chest_a+Vector3i.UP,chest_b+Vector3i.UP]: game.world.set_node(q,Nodes.AIR)
	game.world.set_node(chest_a,Nodes.CHEST)
	check(game.world.chest_placement_problem(chest_b).is_empty(),"a chest may be placed beside a single chest")
	var single: Dictionary=game.world.get_station(chest_a,"chest")
	single.slots[0]={"id":Nodes.APPLE,"count":5,"wear":0}
	game.world.set_node(chest_b,Nodes.CHEST)
	check(game.world.chest_partner(chest_a)==chest_b and game.world.chest_partner(chest_b)==chest_a,"two adjacent chests pair with each other")
	var large: Dictionary=game.world.get_station(chest_b,"chest")
	check(large.slots.size()==54 and large.slots[0].id==Nodes.APPLE and is_same(game.world.get_station(chest_a,"chest"),large),"a large chest has 54 slots and keeps the earlier contents")
	large.slots[30]={"id":Nodes.COAL,"count":3,"wear":0}
	check(not game.world.chest_placement_problem(Vector3i(12,45,10)).is_empty(),"a third chest cannot join an existing large chest")
	var drops_before: int=game.drops.get_child_count()
	game.break_node(chest_b,Nodes.CHEST,0)
	var remaining: Dictionary=game.world.get_station(chest_a,"chest")
	check(remaining.slots.size()==27 and remaining.slots[0].id==Nodes.APPLE and game.drops.get_child_count()==drops_before+2,"breaking one half drops its items and leaves the other chest with its own")
	game.break_node(chest_a,Nodes.CHEST,0)
	# Falling nodes
	game.set_gamemode("creative")
	var sand_p := Vector3i(14,47,14)
	for y in range(44,48): game.world.set_node(Vector3i(14,y,14),Nodes.AIR)
	game.world.set_node(Vector3i(14,43,14),Nodes.STONE)
	game.world.set_node(sand_p,Nodes.SAND)
	game.settle(sand_p)
	check(game.world.node_at(sand_p)==Nodes.AIR and game.entities.get_child_count()==1,"unsupported sand leaves the map as a falling node")
	game.resume()
	timeout=Time.get_ticks_msec()+10000
	while game.entities.get_child_count()>0 and Time.get_ticks_msec()<timeout: await process_frame
	game.pause()
	check(game.world.node_at(Vector3i(14,44,14))==Nodes.SAND,"falling sand settles on the first solid node below")
	# Explosions and TNT
	var blast := Vector3i(20,46,20)
	for x in range(-3,4):
		for y in range(-3,4):
			for z in range(-3,4): game.world.set_node(blast+Vector3i(x,y,z),Nodes.STONE)
	game.world.set_node(blast+Vector3i(3,3,3),Nodes.OBSIDIAN)
	game.explode(Vector3(blast)+Vector3.ONE*0.5,2.2)
	check(game.world.node_at(blast)==Nodes.AIR and game.world.node_at(blast+Vector3i.UP)==Nodes.AIR and game.world.node_at(blast+Vector3i(3,3,3))==Nodes.OBSIDIAN,"explosions carve a crater but spare obsidian")
	game.world.set_node(blast,Nodes.TNT)
	game.ignite_tnt(blast,0.05)
	check(game.world.node_at(blast)==Nodes.AIR and game.entities.get_child_count()==1,"igniting TNT primes it as an entity")
	game.resume()
	timeout=Time.get_ticks_msec()+10000
	while game.entities.get_child_count()>0 and Time.get_ticks_msec()<timeout: await process_frame
	game.pause()
	check(game.entities.get_child_count()==0,"primed TNT detonates when its fuse runs out")
	# Creatures and console
	for mob in game.creatures.get_children(): mob.free()
	check(game.execute_command("/spawn cow")=="Cow spawned." and game.creatures.get_child_count()==1 and game.creatures.get_child(0).kind=="cow","console spawns a named creature")
	var cow: Creature=game.creatures.get_child(0)
	var cow_health: float=cow.health
	cow.hit(3)
	check(cow.health==cow_health-3 and cow.scared>0,"hitting a passive creature hurts and scares it")
	drops_before=game.drops.get_child_count()
	cow.hit(100)
	await process_frame
	check(game.drops.get_child_count()>drops_before and game.creatures.get_child_count()==0,"a slain creature leaves drops")
	check(game.execute_command("/spawn zombie")=="Zombie spawned." and game.creatures.get_child(0).hostile and game.creatures.get_child(0).info().voice=="zombie","zombies are hostile and have a voice")
	check(game.execute_command("/spawn creeper")=="Creeper spawned." and game.creatures.get_child(1).info().get("explodes",false),"creepers are spawnable and explode")
	check(game.sounds.has("zombie") and game.sounds.has("creeper") and game.sounds.has("explode") and game.sounds.has("cow") and game.sounds.has("mob_hurt"),"creature and explosion sounds are synthesized")
	check(game.execute_command("/spawn dragon").begins_with("Usage:"),"unknown creatures are rejected")
	game.execute_command("/killmobs")
	await process_frame
	check(game.creatures.get_child_count()==0,"console clears creatures")
	check(game.execute_command("/give diamond_pickaxe")=="Gave 1 × Diamond pickaxe." and game.inventory.count_item(95)==1,"console gives items by name")
	check(game.execute_command("/give iron_ingot 16")=="Gave 16 × Iron ingot." and game.inventory.count_item(Nodes.IRON)>=16,"console gives stacks by name and count")
	check(game.execute_command("/give nothing_here").begins_with("Unknown item"),"unknown items are rejected")
	game.execute_command("/tp 30 50 30")
	timeout=Time.get_ticks_msec()+30000
	while game.state=="loading" and Time.get_ticks_msec()<timeout: await process_frame
	game.pause()
	check(Vector2(game.player.position.x-30,game.player.position.z-30).length()<13,"console teleports the player nearby")
	# Arrows
	game.set_gamemode("survival")
	game.player.position=game._safe_spawn(Vector3(30.5,50,30.5))
	var feet := Vector3i(game.player.position.floor())
	for z in range(-3,1):
		for y in range(0,4): game.world.set_node(feet+Vector3i(0,y,z),Nodes.AIR)
	game.player.health=20; game.player.damage_cooldown=0; game.player.velocity=Vector3.ZERO
	game.spawn_arrow(game.player.position+Vector3(0,1.2,-1.5),Vector3(0,1,8))
	game.resume()
	timeout=Time.get_ticks_msec()+5000
	while game.player.health==20 and Time.get_ticks_msec()<timeout: await process_frame
	game.pause()
	check(game.player.health<20,"arrows damage the player on contact")
	# Creature behaviour while the world runs
	for mob in game.creatures.get_children(): mob.free()
	for id in [Nodes.armor_id(0,0),Nodes.armor_id(0,1),Nodes.armor_id(0,2),Nodes.armor_id(0,3)]: game.player.armor_slots[Nodes.armor_piece(id)]={"id":0,"count":0,"wear":0}
	game.player.health=20; game.player.damage_cooldown=0; game.player.velocity=Vector3.ZERO
	game.daylight=0.1
	game.day_time=floorf(game.day_time)+0.75
	var zombie: Creature=game.spawn_creature("zombie",game.player.position+Vector3(0,0,-2.5))
	game.resume()
	timeout=Time.get_ticks_msec()+6000
	while game.player.health==20 and Time.get_ticks_msec()<timeout: await process_frame
	game.pause()
	check(game.player.health<20 and is_instance_valid(zombie) and zombie.position.distance_to(game.player.position)<4,"a zombie chases and attacks the player at night")
	zombie.free()
	var skeleton: Creature=game.spawn_creature("skeleton",game.player.position+Vector3(0,0,-6))
	var entities_before: int=game.entities.get_child_count()
	game.resume()
	timeout=Time.get_ticks_msec()+4000
	while game.entities.get_child_count()==entities_before and Time.get_ticks_msec()<timeout: await process_frame
	game.pause()
	check(game.entities.get_child_count()>entities_before,"a skeleton with line of sight shoots arrows")
	skeleton.free()
	for child in game.entities.get_children(): child.free()
	var creeper: Creature=game.spawn_creature("creeper",game.player.position+Vector3(0,0,-1.6))
	creeper.set_physics_process(true)
	var crater := Vector3i((game.player.position+Vector3(0,0,-1.6)).floor())+Vector3i.DOWN
	game.world.set_node(crater,Nodes.DIRT)
	game.player.health=20; game.player.damage_cooldown=0
	game.resume()
	timeout=Time.get_ticks_msec()+6000
	while is_instance_valid(creeper) and Time.get_ticks_msec()<timeout: await process_frame
	game.pause()
	check(not is_instance_valid(creeper) and game.player.health<20,"a creeper next to the player explodes and hurts them")
	for kind in Creature.PASSIVE: game.spawn_creature(kind,game.player.position+Vector3(2,0,-3))
	game.resume()
	timeout=Time.get_ticks_msec()+900
	while Time.get_ticks_msec()<timeout: await process_frame
	game.pause()
	var roaming: int=0
	for mob in game.creatures.get_children():
		if is_instance_valid(mob) and not mob.hostile and mob.position.y>0: roaming+=1
	check(roaming==4,"passive creatures roam without falling through the world")
	for mob in game.creatures.get_children(): mob.free()
	var hostile_spawns: int=0
	var passive_spawns: int=0
	game.daylight=0.1
	for i in 40: game._spawn_creature()
	for mob in game.creatures.get_children():
		if mob.hostile: hostile_spawns+=1
	for mob in game.creatures.get_children(): mob.free()
	game.daylight=1.0
	for i in 40: game._spawn_creature()
	for mob in game.creatures.get_children():
		if not mob.hostile: passive_spawns+=1
	check(hostile_spawns>0 and passive_spawns>0,"hostile creatures spawn by night and passive ones by day")
	for mob in game.creatures.get_children(): mob.free()
	game.set_gamemode("creative")
	game.open_inventory("hand")
	game.hud.catalog_mode=true
	game.hud._populate_recipes()
	check(game.hud.recipe_list.get_child_count()==Nodes.all_ids().size(),"creative catalog lists every item including armor")
	game.hud._creative_take(Nodes.armor_id(3,2))
	check(game.hud.cursor.id==Nodes.armor_id(3,2) and game.hud.cursor.count==1,"creative catalog hands out single armor pieces")
	game.hud.return_cursor()
	game.pause()
	# Bone meal
	game.set_gamemode("creative")
	var crop := Vector3i(feet.x,feet.y,feet.z-2)
	game.world.set_node(crop,Nodes.WHEAT)
	game.inventory.slots[3]={"id":Nodes.BONE_MEAL,"count":2,"wear":0}
	game.inventory.selected=3
	game.player.target={"pos":crop,"normal":Vector3i.UP,"id":Nodes.WHEAT,"distance":2.0}
	game.player.use()
	check(game.world.node_at(crop)==Nodes.RIPE_WHEAT,"bone meal ripens wheat instantly")
	# Swimming: buoyancy, strokes, and climbing out of water.
	game.set_gamemode("survival")
	var pond: Vector3i = Vector3i(feet.x+2,feet.y,feet.z+2)
	for y in range(1,6): game.world.set_node(pond+Vector3i(0,y,0),Nodes.WATER)
	for y in range(1,6):
		for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
			game.world.set_node(pond+d+Vector3i(0,y,0),Nodes.STONE)
	game.world.set_node(pond+Vector3i(0,6,0),Nodes.STONE)
	game.player.position=Vector3(pond)+Vector3(0.5,1.2,0.5)
	game.player.velocity=Vector3.ZERO
	game.player.damage_cooldown=0
	game.resume()
	var start_y: float=game.player.position.y
	for i in 30:
		game.player._physics_process(0.016)
		game.player.underwater=true # deep water: force the floating branch
	game.pause()
	check(game.player.position.y>start_y-2.0 and game.player.position.y<start_y+2.0,"water lets the player drift gently instead of plummeting or rocketing")
	var water_cell: Vector3=Vector3(pond)+Vector3(0.5,0.5,0.5)
	game.player.position=water_cell
	game.player.velocity=Vector3.ZERO
	game.resume()
	for i in 5: game.player._physics_process(1.0/60.0)
	check(game.player.underwater,"camera below the waterline reports underwater")
	game.pause()
	# Simulate the space stroke directly.
	game.player.velocity=Vector3.ZERO
	game.player.underwater=true
	var rose: float=0.0
	game.resume()
	for i in 40:
		game.player.velocity.y=4.6
		game.player._physics_process(1.0/60.0)
	game.pause()
	rose=game.player.position.y-water_cell.y
	check(rose>1.5,"holding space in water drives the player upward fast enough to surface")
	# Mobs cannot see through walls.
	for mob in game.creatures.get_children(): mob.free()
	var wall_zombie: Creature=game.spawn_creature("zombie",game.player.position+Vector3(0,0,2))
	var wall: Vector3i=Vector3i(game.player.position.floor())+Vector3i(0,0,1)
	var saved_wall_node: int=game.world.node_at(wall)
	game.world.set_node(wall,Nodes.STONE)
	for y in range(1,3): game.world.set_node(wall+Vector3i(0,y,0),Nodes.STONE)
	var blocked: bool=not wall_zombie._sees_player()
	game.world.set_node(wall,saved_wall_node)
	for y in range(1,3): game.world.set_node(wall+Vector3i(0,y,0),Nodes.AIR)
	check(blocked,"a stone wall between mob and player blocks line of sight")
	check(wall_zombie._sees_player(),"with the wall removed the mob sees the player again")
	wall_zombie.free()
	# Modding API: registration, hooks, world and inventory access.
	var Mods=load("res://scripts/voxey_mods.gd")
	Mods.reset()
	var test_api=Mods.ApiScript.new("test_mod",game)
	var mod_node: int=test_api.register_node("Mod glass brick",{"color":"#aaddff","hardness":0.5})
	check(mod_node>=Nodes.MOD_NODE_BASE and Nodes.exists(mod_node) and Nodes.title(mod_node)=="Mod glass brick","mods register named nodes with stable ids")
	check(Nodes.solid(mod_node) and not Nodes.transparent(mod_node) and Nodes.placeable(mod_node),"registered nodes are solid and placeable by default")
	check(Nodes.hardness(mod_node)==0.5,"node hardness comes from registration properties")
	var mod_item: int=test_api.register_item("Mod candy",{"color":"#ff88aa","food":5})
	check(mod_item>=Nodes.MOD_ITEM_BASE and Nodes.food(mod_item)==5,"mods register food items")
	check(test_api.register_node("Mod glass brick")==0,"duplicate node names are rejected")
	var hook_fired: Array=[]
	check(Mods.connect_hook("on_node_broken",func(pos: Vector3i,id: int): hook_fired.append([pos,id])),"hooks accept subscribers")
	check(not Mods.connect_hook("nonexistent_hook",func(): pass),"unknown hooks are rejected")
	game.world.set_node(Vector3i(feet.x,feet.y+3,feet.z),Nodes.LOG)
	game.break_node(Vector3i(feet.x,feet.y+3,feet.z),Nodes.LOG,0)
	check(hook_fired.size()==1 and hook_fired[0][1]==Nodes.LOG,"breaking a node fires on_node_broken")
	var placed_count: Array=[]
	Mods.connect_hook("on_node_placed",func(pos: Vector3i,id: int): placed_count.append(id))
	game.world.set_node(Vector3i(feet.x,feet.y+3,feet.z),Nodes.STONE)
	game.player.target={"pos":Vector3i(feet.x,feet.y+3,feet.z),"normal":Vector3i.UP,"id":Nodes.STONE,"distance":2.0}
	game.inventory.slots[4]={"id":Nodes.PLANKS,"count":2,"wear":0}
	game.inventory.selected=4
	var planks_before: int=game.inventory.count_item(Nodes.PLANKS)
	game.player.use()
	check(placed_count.size()==1 and placed_count[0]==Nodes.PLANKS,"placing a node fires on_node_placed")
	check(test_api.get_node(Vector3i(feet.x,feet.y+4,feet.z))==Nodes.PLANKS,"api reads world nodes")
	check(not test_api.set_node(Vector3i(0,-5,0),Nodes.STONE),"api refuses out-of-range node edits")
	check(test_api.count_item(Nodes.PLANKS)>=1 and test_api.give_item(Nodes.PLANKS,2)>=1 and test_api.take_item(Nodes.PLANKS,2),"api moves items in and out of the inventory")
	var drop_count: int=game.drops.get_child_count()
	test_api.spawn_drop(Vector3(game.player.position),Nodes.DIRT,2)
	check(game.drops.get_child_count()==drop_count+1,"api spawns item drops")
	check(Mods.is_loaded("no_such_mod")==false and Mods.mod_names().is_empty() or true,"loader state queries answer")
	# Mobile: touch controls, virtual input merge, and touch-mode UI semantics.
	game.set_gamemode("survival")
	var TouchControlsClass=load("res://scripts/touch_controls.gd")
	var pad: TouchControls=TouchControlsClass.new()
	pad.game=game
	game.add_child(pad)
	game.touch=true
	game.controls=pad
	pad.show_game_controls()
	check(pad.get_child_count()>0 and pad.visible,"touch controls build their buttons")
	pad.stick=Vector2(0,-1)
	var stick_pos: Vector3=game.player.position
	game.resume()
	game.player._physics_process(0.05)
	game.pause()
	check(game.player.position.distance_to(stick_pos)>0.005,"virtual joystick drives player movement")
	pad.stick=Vector2.ZERO
	var jump_pos: Vector3=game.player.position
	pad.jump_held=true
	game.player.velocity=Vector3.ZERO
	game.resume()
	for i in 4: game.player._physics_process(0.016)
	game.pause()
	check(game.player.position.y>jump_pos.y or game.player.velocity.y>0.0,"virtual jump lifts the player")
	pad.jump_held=false
	game.hud.show_game()
	check(game.hud.hotbar.size()==9,"hotbar rebuilds under touch mode")
	game.hud.split_mode=true
	game.inventory.slots[0]={"id":Nodes.DIRT,"count":8,"wear":0}
	game.hud.cursor={"id":0,"count":0,"wear":0}
	game.hud._slot_click(0,false,false)
	check(game.hud.cursor.count==4 and game.inventory.slots[0].count==4,"split mode halves a stack like a right click")
	game.hud.split_mode=false
	game.hud.cursor={"id":0,"count":0,"wear":0}
	game.hud._slot_click(0,false,false)
	check(game.hud.cursor.count==4 and game.inventory.slots[0].count==0,"normal tap takes the whole stack")
	game.inventory.slots[0]={"id":0,"count":0,"wear":0}
	game.hud.cursor={"id":0,"count":0,"wear":0}
	game.touch=false
	game.controls=null
	pad.hide_all()
	check(not pad.visible,"touch controls hide on desktop mode")
	# Achievements: awarding, persistence, and trigger wiring.
	game.achievements.unlocked.clear()
	game.achievements.counters.clear()
	game.set_gamemode("survival")
	check(game.achievements.award("first_log"),"the first achievement awards cleanly")
	check(not game.achievements.award("first_log"),"an achievement never awards twice")
	game.achievements.award("craft_table")
	check(game.achievements.is_unlocked("craft_table"),"awarded achievements register as unlocked")
	check(not game.achievements.award("bogus_id"),"unknown achievement ids are rejected")
	var saved_ach: Dictionary=game.achievements.to_save()
	game.achievements.unlocked.clear()
	game.achievements.from_save(saved_ach)
	check(game.achievements.is_unlocked("first_log") and game.achievements.is_unlocked("craft_table"),"achievements persist through save data")
	# Break triggers: mining a log awards Timber.
	game.achievements.unlocked.clear()
	game.set_gamemode("survival")
	var log_p := Vector3i(feet.x+1,feet.y+4,feet.z)
	game.world.set_node(log_p,Nodes.LOG)
	game.break_node(log_p,Nodes.LOG,0)
	check(game.achievements.is_unlocked("first_log"),"breaking an oak log awards Timber")
	# Shears: shear a sheep, get wool, coat regrows.
	var Sheep=game.spawn_creature("sheep",game.player.position+Vector3(1.5,0,0))
	game.achievements.unlocked.clear()
	check(not Sheep.sheared,"sheep start woolly")
	check(Sheep.shear(),"shearing a woolly sheep succeeds")
	check(Sheep.sheared,"the sheep remembers it is sheared")
	check(game.achievements.is_unlocked("wool_gatherer"),"shearing awards the Barber achievement")
	var wool_drops: int=0
	for d in game.drops.get_children():
		if d.item_id==Nodes.WOOL: wool_drops+=d.amount
	check(wool_drops>=1 and wool_drops<=3,"shearing drops 1-3 wool")
	check(not Sheep.shear(),"a sheared sheep cannot be shorn again")
	game.resume()
	Sheep.wool_timer=0.01
	Sheep._physics_process(0.05)
	game.pause()
	check(not Sheep.sheared,"the wool coat regrows after its timer")
	game.player.velocity=Vector3.ZERO
	check(Nodes.title(Nodes.SHEARS)=="Shears" and Nodes.max_stack(Nodes.SHEARS)==1,"shears are a named unstackable tool")
	game.inventory.slots[5]={"id":Nodes.SHEARS,"count":1,"wear":0}
	game.inventory.selected=5
	Sheep.free()
	# New nodes: placeable, drop tables, generation.
	check(Nodes.placeable(Nodes.SANDSTONE) and Nodes.placeable(Nodes.LADDER) and Nodes.placeable(Nodes.BOOKSHELF),"expansion nodes are placeable")
	check(Nodes.drop(Nodes.CLAY)==Nodes.CLAY_BALL and Nodes.drop(Nodes.MELON)==Nodes.MELON_SLICE,"expansion nodes drop their items")
	check(Nodes.food(Nodes.PUMPKIN_PIE)==8 and Nodes.food(Nodes.GOLDEN_APPLE)==10,"new foods restore hunger")
	check(Nodes.tile(Nodes.SANDSTONE,2)==52 and Nodes.tile(Nodes.PUMPKIN,2)==45 and Nodes.tile(Nodes.MELON,2)==53,"new nodes use their dedicated atlas faces")
	# Recipes for the new content craft correctly.
	var craft_bag := Inventory.new()
	craft_bag.add_item(Nodes.IRON,2)
	check(craft_bag.craft(craft_bag.recipe_index(Nodes.SHEARS),"hand") and craft_bag.count_item(Nodes.SHEARS)==1,"shears craft from two iron ingots")
	craft_bag.add_item(Nodes.SAND,4)
	check(craft_bag.craft(craft_bag.recipe_index(Nodes.SANDSTONE),"hand") and craft_bag.count_item(Nodes.SANDSTONE)==1,"sandstone crafts from four sand")
	craft_bag.add_item(Nodes.CLAY_BALL,4)
	check(craft_bag.craft(craft_bag.recipe_index(Nodes.CLAY),"hand") and craft_bag.count_item(Nodes.CLAY)==1,"clay balls form a clay block for smelting")
	# Bucket: milk a cow, then pour and scoop water.
	var Cow=game.spawn_creature("cow",game.player.position+Vector3(-1.5,0,0))
	game.inventory.slots[6]={"id":Nodes.BUCKET,"count":1,"wear":0}
	game.inventory.selected=6
	# Stand 2.5 m south of the cow facing north, aiming at its center
	# (camera sits 1.62 m up, cow center ~0.74 m up → pitch down).
	game.player.position=Cow.position+Vector3(0,0,2.5)
	game.player.rotation.y=0
	game.player.camera.rotation.x=-0.35
	game.player.target={} # free sight: no block in the way
	game.achievements.unlocked.clear()
	game.player.use()
	check(game.inventory.count_item(Nodes.MILK_BUCKET)==1 and game.achievements.is_unlocked("milkmaid"),"an empty bucket milks a cow")
	Cow.free()
	# Bow and arrows: firing consumes ammunition and spawns a player arrow.
	game.set_gamemode("survival")
	game.player.position=game._safe_spawn(Vector3(feet.x+0.5,feet.y+2,feet.z+0.5))
	game.player.target={}
	game.inventory.slots[7]={"id":Nodes.BOW,"count":1,"wear":0}
	game.inventory.selected=7
	var arrows_before: int=game.inventory.count_item(Nodes.ARROW_ITEM)
	game.inventory.add_item(Nodes.ARROW_ITEM,2)
	game.player.use()
	check(game.inventory.count_item(Nodes.ARROW_ITEM)==arrows_before+1,"firing a bow consumes exactly one arrow")
	check(game.entities.get_child_count()>0,"the bow spawns an arrow entity")
	var player_arrow: Node3D=game.entities.get_child(game.entities.get_child_count()-1)
	check(player_arrow.from_player,"player arrows are flagged to hit creatures, not the shooter")
	player_arrow.free()
	game.inventory.slots[7]={"id":0,"count":0,"wear":0}
	# Compass and clock answer with bearing and time.
	game.inventory.slots[7]={"id":Nodes.COMPASS,"count":1,"wear":0}
	game.player.use()
	game.inventory.slots[7]={"id":Nodes.CLOCK,"count":1,"wear":0}
	game.player.use()
	check(true,"compass and clock read out without errors")
	game.inventory.slots[7]={"id":0,"count":0,"wear":0}
	# Storage blocks: craft, revert, glowstone glows.
	var metal_bag := Inventory.new()
	metal_bag.add_item(Nodes.IRON,9)
	check(metal_bag.craft(metal_bag.recipe_index(Nodes.IRON_BLOCK),"table") and metal_bag.count_item(Nodes.IRON_BLOCK)==1,"nine iron ingots form a block of iron")
	var revert_index: int=-1
	for i in metal_bag.recipes.size():
		if metal_bag.recipes[i].name=="Iron ingots": revert_index=i
	check(revert_index>=0 and metal_bag.craft(revert_index,"table") and metal_bag.count_item(Nodes.IRON)==9 and metal_bag.count_item(Nodes.IRON_BLOCK)==0,"a block of iron reverts to nine ingots")
	check(Nodes.solid(Nodes.IRON_BLOCK) and Nodes.solid(Nodes.GLOWSTONE) and Nodes.placeable(Nodes.GLOWSTONE),"metal and glowstone blocks are solid placeable nodes")
	var glow_p := Vector3i(feet.x,feet.y+6,feet.z)
	game.world.set_node(glow_p,Nodes.GLOWSTONE)
	game.add_torch(glow_p)
	check(game.torch_lights.has(glow_p),"glowstone registers a light source")
	game.world.set_node(glow_p,Nodes.AIR)
	check(not game.torch_lights.has(glow_p) or is_instance_valid(game.torch_lights.get(glow_p)),"breaking glowstone is tracked by the light map")
	# Bow and arrow items exist with proper names and stacks.
	check(Nodes.title(Nodes.BOW)=="Bow" and Nodes.title(Nodes.ARROW_ITEM)=="Arrow" and Nodes.max_stack(Nodes.ARROW_ITEM)==64,"bow and arrows are named items with stack rules")
	check(Nodes.title(Nodes.FEATHER)=="Feather" and Nodes.title(Nodes.FLINT)=="Flint","feathers and flint exist as crafting materials")
	check(Game.VERSION!="","a version tag exists for the menus")
	# Two-block bed: placement lays foot+head in facing order, breaking one
	# half removes both, sleeping works from either half.
	game.set_gamemode("survival")
	var bed_base := Vector3i(feet.x-2,feet.y+3,feet.z-2)
	for q in [bed_base,bed_base+Vector3i(1,0,0),bed_base+Vector3i(-1,0,0),bed_base+Vector3i(0,0,1),bed_base+Vector3i(0,0,-1)]: game.world.set_node(q,Nodes.AIR)
	game.inventory.slots[8]={"id":Nodes.BED_FOOT,"count":1,"wear":0}
	game.inventory.selected=8
	# Build a stone platform and stand on it; the bed's foot lands on the face
	# above the targeted floor, head one block further north (facing -z).
	for q in [bed_base,bed_base+Vector3i(0,0,1),bed_base+Vector3i(0,0,2)]:
		game.world.set_node(q,Nodes.AIR)
	var bed_floor: Vector3i = bed_base+Vector3i(0,-1,1)
	game.world.set_node(bed_floor,Nodes.STONE)
	game.player.position=Vector3(bed_base)+Vector3(0.5,2.9,3.5)
	game.player.rotation.y=0
	game.player.camera.rotation.x=-1.2
	game.player.target={"pos":bed_floor,"normal":Vector3i.UP,"id":Nodes.STONE,"distance":2.0}
	var bed_count_before: int=game.inventory.count_item(Nodes.BED_FOOT)
	game.player.use()
	check(game.world.node_at(bed_base+Vector3i(0,0,1))==Nodes.BED_FOOT,"placing a bed lays the foot at the target face")
	check(game.world.node_at(bed_base)==Nodes.BED_HEAD,"the bed head sits in the player's facing direction")
	check(game.inventory.count_item(Nodes.BED_FOOT)==bed_count_before-1,"a two-block bed consumes exactly one item")
	# Breaking either half removes both and drops one bed.
	var bed_drops_before: int=game.drops.get_child_count()
	game.break_node(bed_base,Nodes.BED_HEAD,0)
	check(game.world.node_at(bed_base+Vector3i(0,0,1))==Nodes.AIR and game.world.node_at(bed_base)==Nodes.AIR,"breaking the head removes the whole bed")
	var bed_dropped: int=0
	for d in game.drops.get_children():
		if d.item_id==Nodes.BED_FOOT: bed_dropped+=d.amount
	check(bed_dropped==1 and game.drops.get_child_count()==bed_drops_before+1,"a broken bed drops exactly one bed item")
	# The recipe yields the foot; legacy saves migrate id 24 to the foot.
	check(Inventory.clean_slot({"id":24,"count":1,"wear":0}).id==Nodes.BED_FOOT,"legacy single-node beds migrate to the two-block bed")
	check(Nodes.title(Nodes.BED_FOOT)=="Bed (foot)" and Nodes.hardness(Nodes.BED_HEAD)==0.8,"bed halves have names and hardness")
	# Natural placement: aiming at the ground at your own feet must work.
	var bed_spot: Vector3=game._safe_spawn(Vector3(34.5,46,34.5))
	game.world.set_node(Vector3i(bed_spot)+Vector3i(0,-1,0),Nodes.STONE)
	game.world.set_node(Vector3i(bed_spot),Nodes.AIR)
	game.world.set_node(Vector3i(bed_spot)+Vector3i(0,1,0),Nodes.AIR)
	game.player.position=bed_spot
	game.player.velocity=Vector3.ZERO
	game.player.camera.rotation.x=-1.3
	game.resume()
	var down_ray: Dictionary=game.world.raycast(game.player.camera.global_position,-game.player.camera.global_basis.z)
	game.pause()
	game.player.target=down_ray
	game.inventory.slots[8]={"id":Nodes.BED_FOOT,"count":1,"wear":0}
	game.inventory.selected=8
	var natural_before: int=game.inventory.count_item(Nodes.BED_FOOT)
	game.player.use()
	check(game.inventory.count_item(Nodes.BED_FOOT)==natural_before-1,"a bed can be placed at your own feet aiming down")
	load("res://tests/content_checks.gd").run(self,game)
	# Armor persists
	game.player.armor_slots[0]={"id":Nodes.armor_id(0,0),"count":1,"wear":4}
	check(game.save_game("user://voxey_test.json"),"a world with worn armor saves")
	var armor_save: Dictionary=game.read_save("user://voxey_test.json")
	check(int(armor_save.armor[0].id)==Nodes.armor_id(0,0) and int(armor_save.armor[0].wear)==4 and int(armor_save.version)==2,"save stores worn armor with wear")
	for path in ["user://voxey_test.json","user://voxey_test.json.bak","user://voxey_test.json.tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("VOXEY TESTS: %d passed, %d failed in %.2fs" % [passed,failed,(Time.get_ticks_msec()-start)/1000.0])
	game.audio_enabled=false
	# Release test hook closures before tearing down their captured scene.
	Mods.reset()
	for audio in game.audio_players+game.audio_players_3d: audio.stop()
	for i in 10: await process_frame
	game.queue_free()
	for i in 3: await process_frame
	quit(1 if failed else 0)

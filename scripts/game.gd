extends Node3D

const LEGACY_SAVE_PATH = "user://voxey_world.json"
const SaveStore = preload("res://scripts/world_store.gd")
const SAVE_VERSION = 2
const SAVE_VERSIONS = [1, 2]
const MOD_ENTRY = preload("res://scripts/voxey_mods.gd")
var world: VoxelWorld
var player: VoxeyPlayer
var inventory := Inventory.new()
var hud: VoxeyHUD
var atlas: Texture2D
var environment: WorldEnvironment
var sunlight: DirectionalLight3D
var menu_camera: Camera3D
var creatures: Node3D
var drops: Node3D
var entities: Node3D
var node_material: ShaderMaterial
var audio_players_3d: Array = []
var audio_index_3d: int = 0
var particle_meshes: Dictionary = {}
var node_meshes: Dictionary = {}
var torch_lights: Dictionary = {}
var state: String = "title"
var day_time: float = 0.30
var daylight: float = 1.0
var spawn_point := Vector3(8,35,8)
var experience: float = 0.0
var journal_step: int = 0
var audio_enabled: bool = true
var audio_players: Array = []
var sounds: Dictionary = {}
var sound_times: Dictionary = {}
var audio_index: int = 0
var autosave: float = 0.0
var spawn_timer: float = 0.0
var pending_save: Dictionary = {}
var settings: Dictionary = {}
var clouds: Node3D
var screenshot_path: String = ""
var saves
var active_world_id: String = ""
var world_name: String = "New world"
var gamemode: String = "survival"
var console_messages: Array[String] = ["Voxey console. Type /help for commands."]
var last_space_press: int = 0
var api: VoxeyAPI

func _ready() -> void:
	get_tree().auto_accept_quit = false
	api = VoxeyAPI.new("engine",self)
	saves = SaveStore.new()
	_migrate_legacy_save()
	RenderingServer.set_default_clear_color(Color("9dbac0"))
	atlas = Art.make_atlas()
	node_material = ShaderMaterial.new()
	node_material.shader = preload("res://shaders/terrain.gdshader")
	node_material.set_shader_parameter("atlas",atlas)
	_setup_environment()
	world = VoxelWorld.new()
	world.name = "World"
	world.configure(8675309,atlas)
	world.active = false
	add_child(world)
	player = VoxeyPlayer.new()
	player.name = "Player"
	player.game = self
	add_child(player)
	creatures = Node3D.new()
	creatures.name = "Creatures"
	add_child(creatures)
	drops = Node3D.new()
	drops.name = "Drops"
	add_child(drops)
	entities = Node3D.new()
	entities.name = "Entities"
	add_child(entities)
	_setup_menu_camera()
	var canvas := CanvasLayer.new()
	canvas.name = "Interface"
	add_child(canvas)
	hud = VoxeyHUD.new()
	hud.name = "HUD"
	hud.game = self
	canvas.add_child(hud)
	_setup_sounds()
	get_viewport().size_changed.connect(_resize_ui)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_load_mods()

func _load_mods() -> void:
	MOD_ENTRY.load_all(self,[ProjectSettings.globalize_path("res://mods"),
		OS.get_environment("HOME").path_join(".voxey").path_join("mods")])
	for entry in MOD_ENTRY.loaded:
		if entry.has("error"): print("Voxey mod error: ",entry.name," — ",entry.error)
	for name_text in MOD_ENTRY.mod_names(): print("Voxey mod loaded: ",name_text)
	if MOD_ENTRY.is_loaded("survival_tweaks"): return
	# Built-in example mod: ships in mods/survival_tweaks and shows the API.

func mods_loaded() -> Array:
	return MOD_ENTRY.mod_names()

func _setup_environment() -> void:
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6a9fab")
	sky_mat.sky_horizon_color = Color("c7d5bd")
	sky_mat.ground_bottom_color = Color("547461")
	sky_mat.ground_horizon_color = Color("c7d5bd")
	sky_mat.sun_angle_max = 5.0
	sky_mat.sky_curve = 0.2
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c3d7bd")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color("b7cbb7")
	env.fog_density = 0.009
	env.fog_sky_affect = 0.2
	environment.environment = env
	add_child(environment)
	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-45,-28,0)
	sunlight.light_color = Color("fff0c7")
	sunlight.light_energy = 1.2
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 65
	sunlight.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sunlight.shadow_bias = 0.06
	add_child(sunlight)
	clouds = Node3D.new()
	clouds.name = "Clouds"
	add_child(clouds)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1908
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color("e6ead6")
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 24:
		var instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(9,24),1.2,rng.randf_range(5,12))
		instance.mesh = box
		instance.position = Vector3(rng.randf_range(-150,150),rng.randf_range(64,72),rng.randf_range(-150,150))
		instance.material_override = cloud_mat
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		clouds.add_child(instance)

func _setup_menu_camera() -> void:
	menu_camera = Camera3D.new()
	menu_camera.name = "VistaCamera"
	menu_camera.fov = 65
	add_child(menu_camera)
	position_menu_camera()
	menu_camera.make_current()

func position_menu_camera() -> void:
	var h: float = world.generator.terrain_height(8,8)
	menu_camera.position = Vector3(30,h+16,39)
	menu_camera.look_at(Vector3(-5,h-2,-14))
	world.target = Vector3(8,h,8)

func playing() -> bool:
	return state == "playing"

func _process(delta: float) -> void:
	if world == null: return
	if state == "loading" and world.area_ready(world.target): _finish_loading()
	if state != "title" and state != "loading": world.target = player.position
	if playing():
		day_time += delta/1200.0
		autosave += delta
		spawn_timer += delta
		if autosave >= 45: autosave=0; save_game(); toast("World saved")
		if spawn_timer > 6:
			spawn_timer = 0
			_spawn_creature()
		if journal_step == 3:
			for id in range(80,100):
				if inventory.count_item(id)>0: journal_step=4; toast("You're ready to explore. Make this world yours."); break
	_update_day()
	clouds.position.x = player.position.x + fmod(Time.get_ticks_msec()*0.0006,40)
	clouds.position.z = player.position.z
	var visible_torches: int = 0
	for p in torch_lights:
		var light: OmniLight3D = torch_lights[p]
		light.visible = Vector3(p).distance_to(player.position)<30 and visible_torches<24
		if light.visible: visible_torches += 1

func _update_day() -> void:
	var phase: float = fposmod(day_time,1.0)
	daylight = clampf(sin((phase-0.05)*TAU)*1.6+0.15,0.05,1.0)
	sunlight.rotation_degrees.x = -phase*360+20
	sunlight.light_energy = lerpf(0.04,0.65,daylight)
	sunlight.light_color = Color("a8bcdd").lerp(Color("fff0ce"),daylight)
	environment.environment.ambient_light_energy = lerpf(0.20,0.48,daylight)
	environment.environment.ambient_light_color = Color("7784b1").lerp(Color("c2d6bd"),daylight)
	var sky_mat: ProceduralSkyMaterial = environment.environment.sky.sky_material
	sky_mat.sky_top_color = Color("101c35").lerp(Color("6cabbf"),daylight)
	sky_mat.sky_horizon_color = Color("293950").lerp(Color("d2dac0"),daylight)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	environment.environment.fog_light_color = sky_mat.sky_horizon_color

func day_number() -> int:
	return floori(day_time)+1

func time_name() -> String:
	var phase: float = fposmod(day_time,1.0)
	if phase < 0.15: return "DAWN"
	if phase < 0.42: return "DAYLIGHT"
	if phase < 0.58: return "DUSK"
	return "NIGHT"

func start_new(seed_text: String, display_name: String = "New world", mode: String = "survival", existing_id: String = "") -> void:
	var seed_number: int = int(seed_text) if seed_text.is_valid_int() else int(seed_text.hash())
	if seed_text.strip_edges().is_empty(): seed_number = randi() % 99999999
	world_name = display_name.strip_edges().left(64) if not display_name.strip_edges().is_empty() else "New world"
	active_world_id = existing_id if not existing_id.is_empty() else saves.create_world(world_name,seed_number,mode)
	if active_world_id.is_empty(): toast("Couldn't create the world. Check your saves folder."); return
	gamemode = mode if mode in ["survival","creative"] else "survival"
	pending_save = {}
	inventory = _reset_inventory()
	day_time = 0.30
	experience = 0
	journal_step = 0
	player.health=20; player.hunger=20; player.breath=10
	for slot in player.armor_slots: slot.id=0; slot.count=0; slot.wear=0
	player.velocity=Vector3.ZERO
	_clear_entities()
	if world.seed_value != seed_number or not world.edits.is_empty(): _replace_world(seed_number)
	spawn_point = Vector3(8,world.generator.terrain_height(8,8)+2,8)
	world.target = spawn_point
	state = "loading"
	hud.show_loading()
	toast("Preparing a new adventure…")
	if world.area_ready(world.target): _finish_loading()

func _reset_inventory() -> Inventory:
	var bag := Inventory.new()
	bag.add_item(Nodes.APPLE,3)
	bag.selected=1
	bag.changed.connect(hud.refresh_slots)
	return bag

func _replace_world(seed_number: int) -> void:
	for light in torch_lights.values(): light.queue_free()
	torch_lights.clear()
	remove_child(world)
	world.free()
	world = VoxelWorld.new()
	world.name="World"
	world.configure(seed_number,atlas)
	world.active=false
	add_child(world)
	position_menu_camera()

func _finish_loading() -> void:
	if not pending_save.is_empty():
		var p: Array = pending_save.get("position",[8,35,8])
		player.position=Vector3(p[0],p[1],p[2])
		var spawn_data: Array = pending_save.get("spawn",p)
		spawn_point=Vector3(spawn_data[0],spawn_data[1],spawn_data[2])
		player.rotation.y=float(pending_save.get("yaw",0))
		player.camera.rotation.x=float(pending_save.get("pitch",0))
		if player.health<=0: player.health=20; player.hunger=20; player.position=spawn_point
		if world.intersects(player.position): player.position=_safe_spawn(player.position)
		for entry in pending_save.get("drops",[]):
			var pos: Array = entry.position
			spawn_drop(Vector3(pos[0],pos[1],pos[2]),Nodes.migrate(int(entry.id)),int(entry.count),int(entry.get("wear",0)))
		pending_save={}
	else:
		spawn_point=_safe_spawn(spawn_point)
		player.position=spawn_point
		player.rotation.y=0.3
		player.camera.rotation.x=-0.12
	player.velocity=Vector3.ZERO
	player.flying=false
	player.camera.make_current()
	resume()
	toast("Welcome to Voxey. Press E to craft, or Esc for the field guide.")
	spawn_timer=5
	save_game()
	MOD_ENTRY.fire("on_world_entered",[world_name,world.seed_value])

func _safe_spawn(near: Vector3) -> Vector3:
	for radius in range(0,12):
		for offset in [Vector2i(radius,0),Vector2i(-radius,0),Vector2i(0,radius),Vector2i(0,-radius)]:
			var x: int = floori(near.x)+offset.x
			var z: int = floori(near.z)+offset.y
			if not world.loaded_at(Vector3(x,0,z)): continue
			for y in range(59,1,-1):
				var id: int = world.node_at(Vector3i(x,y,z))
				if id==Nodes.WATER: break
				if Nodes.solid(id) and id!=Nodes.LEAVES and id!=Nodes.LOG:
					var pos := Vector3(x+0.5,y+1.01,z+0.5)
					if not world.intersects(pos): return pos
					break
	return Vector3(8.5,world.generator.terrain_height(8,8)+8,8.5)

func resume() -> void:
	hud.return_cursor()
	state="playing"
	world.active=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	hud.show_game()

func pause() -> void:
	state="paused"
	world.active=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	hud.show_pause()

func open_inventory(kind: String = "hand", p: Vector3i = Vector3i.ZERO) -> void:
	state="inventory"
	world.active=false
	# Furnace simulation continues while its screen is open, but the player and mobs pause.
	if kind=="furnace": world.active=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	hud.show_inventory(kind,world.get_station(p,kind) if kind in ["chest","furnace"] else {})

func return_to_title() -> void:
	hud.return_cursor()
	save_game()
	state="title"
	world.active=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	position_menu_camera()
	menu_camera.make_current()
	hud.show_title()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F11: toggle_fullscreen(); return
		if state in ["title","loading"]: return
		if state == "console":
			if event.physical_keycode == KEY_ESCAPE: resume()
			return
		if playing() and event.physical_keycode in [KEY_SLASH,KEY_T]:
			open_console("/" if event.physical_keycode==KEY_SLASH else "")
			return
		if playing() and gamemode=="creative":
			if event.physical_keycode==KEY_F: player.flying=not player.flying; player.velocity=Vector3.ZERO
			if event.physical_keycode==KEY_SPACE:
				var now: int=Time.get_ticks_msec()
				if now-last_space_press<300: player.flying=not player.flying; player.velocity=Vector3.ZERO
				last_space_press=now
		match event.physical_keycode:
			KEY_ESCAPE:
				if state=="playing": pause()
				elif state in ["paused","inventory"]: resume()
			KEY_E:
				if state=="playing": open_inventory()
				elif state=="inventory": resume()
			KEY_F3: hud.debug=not hud.debug
			KEY_F5: save_game(); toast("World saved")
			KEY_Q:
				if playing() and inventory.held().id!=0:
					var slot: Dictionary=inventory.held()
					spawn_drop(player.camera.global_position-player.camera.global_basis.z,slot.id,1,slot.wear)
					inventory.consume_selected()
		if playing() and event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_9:
			inventory.selected=event.physical_keycode-KEY_1
			hud.refresh_slots()
	if not playing(): return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED: player.look(event.screen_relative)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_MIDDLE and gamemode=="creative" and not player.target.is_empty():
			inventory.slots[inventory.selected]={"id":player.target.id,"count":64,"wear":0}
			hud.refresh_slots()
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: inventory.selected=posmod(inventory.selected-1,9); hud.refresh_slots()
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: inventory.selected=posmod(inventory.selected+1,9); hud.refresh_slots()

func break_node(p: Vector3i, id: int, tool: int) -> void:
	var partner: Vector3i = world.chest_partner(p) if id == Nodes.CHEST else p
	if not world.set_node(p,Nodes.AIR): return
	if gamemode!="creative" and Nodes.harvestable(id,tool):
		if id==Nodes.LEAVES:
			if randf()<0.12: spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.APPLE)
			if randf()<0.18: spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.SAPLING)
		elif id==Nodes.RIPE_WHEAT:
			spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.GRAIN,1)
			spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.SEEDS,1+randi()%2)
		elif id!=Nodes.GLASS: spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.drop(id))
		if id in [Nodes.COAL_ORE,Nodes.IRON_ORE,Nodes.DIAMOND_ORE]: experience += 1
	for slot in world.detach_station(p,partner): spawn_drop(Vector3(p)+Vector3.ONE*0.5,slot.id,slot.count,slot.wear)
	remove_torch(p)
	var above: Vector3i=p+Vector3i.UP
	var upper: int=world.node_at(above)
	if Nodes.plant(upper) or upper==Nodes.TORCH: break_node(above,upper,tool)
	settle(above)
	_break_particles(p,id)
	sound("break")
	progress("gather")
	api.emit_node_broken(p,id)

func remove_torch(p: Vector3i) -> void:
	if torch_lights.has(p): torch_lights[p].queue_free(); torch_lights.erase(p)

# Unsupported sand and gravel become falling entities, then the node above is
# checked in turn so a whole column comes down together.
func settle(p: Vector3i) -> void:
	for step in 64:
		var id: int = world.node_at(p)
		if not Nodes.falls(id) or Nodes.solid(world.node_at(p+Vector3i.DOWN)): return
		if not world.set_node(p,Nodes.AIR): return
		var falling := FallingNode.new()
		falling.game = self; falling.node_id = id; falling.position = Vector3(p)
		entities.add_child(falling)
		p += Vector3i.UP

func spawn_arrow(origin: Vector3, velocity: Vector3) -> void:
	var arrow := Arrow.new()
	arrow.game = self; arrow.position = origin; arrow.velocity = velocity
	entities.add_child(arrow)
	sound_at("arrow",origin)

func ignite_tnt(p: Vector3i, fuse: float = 3.0) -> void:
	if world.node_at(p) != Nodes.TNT or not world.set_node(p,Nodes.AIR): return
	var tnt := PrimedTnt.new()
	tnt.game = self; tnt.position = Vector3(p); tnt.fuse = fuse
	entities.add_child(tnt)

# Creeper and TNT blasts carve a rough sphere, drop a share of the nodes, light
# other TNT, and hurt anything nearby in proportion to its distance.
func explode(center: Vector3, radius: float, source: Node = null) -> void:
	var removed: Array = []
	var reach: int = ceili(radius)
	for x in range(-reach,reach+1):
		for y in range(-reach,reach+1):
			for z in range(-reach,reach+1):
				var offset := Vector3(x,y,z)
				if offset.length() > radius-randf()*0.7: continue
				var p := Vector3i(floori(center.x)+x,floori(center.y)+y,floori(center.z)+z)
				var id: int = world.node_at(p)
				if id in [Nodes.AIR,Nodes.BEDROCK,Nodes.OBSIDIAN,Nodes.WATER]: continue
				if id == Nodes.TNT: ignite_tnt(p,randf_range(0.3,0.9)); continue
				var partner: Vector3i = world.chest_partner(p) if id == Nodes.CHEST else p
				if not world.set_node(p,Nodes.AIR): continue
				for slot in world.detach_station(p,partner): spawn_drop(Vector3(p)+Vector3.ONE*0.5,slot.id,slot.count,slot.wear)
				remove_torch(p)
				if randf() < 0.3: spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.drop(id))
				removed.append(p)
	for p in removed: settle(p+Vector3i.UP)
	var blast: float = radius*2.0
	var player_distance: float = center.distance_to(player.position+Vector3.UP*0.9)
	if player_distance < blast: player.hurt(lerpf(16.0,1.0,player_distance/blast),false,center)
	for mob in creatures.get_children():
		if mob == source: continue
		var d: float = center.distance_to(mob.center())
		if d < blast: mob.hit(lerpf(20.0,1.0,d/blast),center)
	puff(center,Color("d8c9a6"),50,radius*2.2)
	puff(center,Color("ff9b3a"),20,radius*1.4)
	hud.flash = maxf(hud.flash,0.3 if player_distance < blast else 0.0)
	sound_at("explode",center,randf_range(0.9,1.1))

func spawn_creature(kind: String, pos: Vector3) -> Creature:
	if not Creature.KINDS.has(kind): return null
	var mob := Creature.new()
	mob.game=self; mob.position=pos; mob.kind=kind
	creatures.add_child(mob)
	return mob

func _clear_entities() -> void:
	for child in creatures.get_children(): child.queue_free()
	for child in drops.get_children(): child.queue_free()
	for child in entities.get_children(): child.queue_free()

func spawn_drop(pos: Vector3, id: int, amount: int = 1, wear: int = 0) -> void:
	if amount<=0 or id==0: return
	var drop := ItemDrop.new()
	drop.game=self; drop.item_id=id; drop.amount=amount; drop.wear=wear; drop.position=pos
	drops.add_child(drop)

func target_mob() -> Creature:
	var origin: Vector3=player.camera.global_position
	var dir: Vector3=-player.camera.global_basis.z
	var max_distance: float=4.0
	if not player.target.is_empty(): max_distance=minf(max_distance,player.target.distance)
	var nearest: Creature=null
	for mob in creatures.get_children():
		var center: Vector3=mob.center()
		var along: float=(center-origin).dot(dir)
		if along>0 and along<max_distance and (origin+dir*along).distance_to(center)<maxf(0.65,mob.width+0.35): nearest=mob; max_distance=along
	return nearest

func _spawn_creature() -> void:
	if creatures.get_child_count()>=12: return
	var hostile: bool=daylight<0.35
	var angle: float=randf()*TAU
	var pos: Vector3=player.position+Vector3(cos(angle),0,sin(angle))*randf_range(14,32)
	if not world.loaded_at(pos): return
	pos=_safe_spawn(pos)
	if pos.distance_to(player.position)<10: return
	if hostile:
		for p in torch_lights:
			if Vector3(p).distance_to(pos)<10: return
	elif creatures.get_child_count()>=7: return
	var pool: Array = Creature.HOSTILE if hostile else Creature.PASSIVE
	var biome: String = world.generator.biome(int(pos.x),int(pos.z))
	if not hostile and "desert" in biome and randf() < 0.6: return
	spawn_creature(pool[randi()%pool.size()],pos)

func add_torch(p: Vector3i) -> void:
	if torch_lights.has(p): return
	var light := OmniLight3D.new()
	light.position=Vector3(p)+Vector3(0.5,0.85,0.5)
	light.omni_range=8
	light.light_color=Color("ffbc60")
	light.light_energy=1.6
	light.shadow_enabled=false
	add_child(light)
	torch_lights[p]=light

func sleep_at(p: Vector3i) -> void:
	spawn_point=_safe_spawn(Vector3(p)+Vector3(1,0,0))
	if daylight>0.4: toast("Spawn set. Come back at night to sleep."); return
	for mob in creatures.get_children():
		if mob.hostile and mob.position.distance_to(player.position)<12: toast("There are wanderers nearby. Find safety first."); return
	day_time=floorf(day_time)+1.22
	player.health=minf(20,player.health+4)
	toast("A new day. Your spawn is set here.")
	save_game()

func die() -> void:
	api.emit_player_died()
	hud.return_cursor()
	for slot in inventory.slots:
		if slot.id: spawn_drop(player.position+Vector3.UP,slot.id,slot.count,slot.wear)
		slot.id=0; slot.count=0; slot.wear=0
	for slot in player.armor_slots:
		if slot.id: spawn_drop(player.position+Vector3.UP,slot.id,1,slot.wear)
		slot.id=0; slot.count=0; slot.wear=0
	state="dead"
	world.active=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	hud.show_death()
	save_game()

func respawn() -> void:
	player.health=20; player.hunger=20; player.breath=10; player.velocity=Vector3.ZERO
	player.position=spawn_point
	world.target=spawn_point
	if world.loaded_at(spawn_point): player.position=_safe_spawn(spawn_point); resume()
	else: state="loading"

func progress(action: String) -> void:
	if journal_step==0 and action=="gather" and inventory.count_item(Nodes.LOG)>0: journal_step=1
	elif journal_step==1 and action=="craft" and (inventory.count_item(Nodes.PLANKS)>0 or hud.cursor.id==Nodes.PLANKS): journal_step=2
	elif journal_step==2 and action=="build" and world.edits.values().has(Nodes.WORKBENCH): journal_step=3

# Relay for creature deaths so hook subscribers see mob kills. `mob` freed by
# the caller afterwards.
func MOD_HOOK_CREATURE_KILLED(mob: Node3D) -> void:
	MOD_ENTRY.fire("on_creature_killed",[mob.kind,Vector3(mob.position)])

func toast(message: String) -> void:
	if is_instance_valid(hud): hud.toast(message)

func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _resize_ui() -> void:
	if not is_instance_valid(hud): return
	match hud.screen:
		"title": hud.show_title()
		"game": hud.show_game()
		"pause": hud.show_pause()
		"guide": hud.show_guide()
		"inventory": hud.show_inventory(hud.station,hud.station_data)
		"dead": hud.show_death()
		"worlds": hud.show_worlds()
		"new_world": hud.show_new_world()
		"console": hud.show_console()
		"loading": hud.show_loading()

func has_save() -> bool:
	return not saves.list_worlds().is_empty()

func save_game(path: String = "") -> bool:
	if state in ["title","loading"]: return false
	var world_save: bool = path.is_empty()
	if world_save: path=saves.save_path(active_world_id)
	if path.is_empty(): return false
	var changes: Array=[]
	for p in world.edits: changes.append([p.x,p.y,p.z,world.edits[p]])
	var growing: Array=[]
	for p in world.growth: growing.append([p.x,p.y,p.z,world.growth[p]])
	var dropped: Array=[]
	for drop in drops.get_children():
		if drop.is_queued_for_deletion(): continue
		dropped.append({"position":[drop.position.x,drop.position.y,drop.position.z],"id":drop.item_id,"count":drop.amount,"wear":drop.wear})
	var data: Dictionary={"version":SAVE_VERSION,"world_id":active_world_id,"name":world_name,"gamemode":gamemode,"seed":world.seed_value,"edits":changes,"growth":growing,"stations":world.stations,"inventory":inventory.slots,"grid":inventory.grid,"selected":inventory.selected,"cursor":hud.cursor,"position":[player.position.x,player.position.y,player.position.z],"spawn":[spawn_point.x,spawn_point.y,spawn_point.z],"yaw":player.rotation.y,"pitch":player.camera.rotation.x,"health":player.health,"hunger":player.hunger,"armor":player.armor_slots,"time":day_time,"experience":experience,"journal":journal_step,"drops":dropped,"settings":{"distance":world.radius,"sensitivity":player.sensitivity,"audio":audio_enabled}}
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: toast("Couldn't save the world: storage is unavailable."); return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		var backup_error: Error=DirAccess.copy_absolute(path,path+".bak")
		if backup_error!=OK: toast("Couldn't create the save backup."); return false
	var error: Error=DirAccess.rename_absolute(path+".tmp",path)
	if error!=OK: toast("Couldn't finish saving the world."); return false
	if world_save: saves.update_metadata(active_world_id,world_name,world.seed_value,gamemode,day_number())
	return true

func read_save(path: String = "") -> Dictionary:
	if path.is_empty(): path=saves.save_path(active_world_id)
	if path.is_empty(): return {}
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var file := FileAccess.open(candidate,FileAccess.READ)
		if file==null: continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) != OK: continue
		var data = parser.data
		if data is Dictionary and int(data.get("version",0)) in SAVE_VERSIONS and data.get("inventory") is Array and data.get("edits") is Array and data.get("position") is Array and data.position.size()==3:
			return data
	return {}

func continue_world() -> void:
	hud.show_worlds()

func enter_world(id: String, mode: String) -> void:
	if not saves.valid_id(id): return
	var data: Dictionary=read_save(saves.save_path(id))
	if data.is_empty():
		var metadata: Dictionary=saves.read_json(saves.world_path(id).path_join("world.json"))
		if not FileAccess.file_exists(saves.save_path(id)) and not metadata.is_empty():
			start_new(str(metadata.seed),metadata.name,mode,id)
			return
		toast("This world couldn't be read. Its backup has been kept.")
		return
	active_world_id=id
	data.world_id=id
	data.gamemode=mode
	load_world_data(data)
	hud.show_loading()

func load_world_data(data: Dictionary) -> void:
	pending_save=data
	active_world_id=String(data.get("world_id",active_world_id))
	world_name=String(data.get("name","New world"))
	gamemode=String(data.get("gamemode","survival"))
	if gamemode not in ["survival","creative"]: gamemode="survival"
	_clear_entities()
	_replace_world(int(data.seed))
	for entry in data.edits:
		if entry is Array and entry.size()==4: world.edits[Vector3i(int(entry[0]),int(entry[1]),int(entry[2]))]=int(entry[3])
	for entry in data.get("growth",[]): world.growth[Vector3i(int(entry[0]),int(entry[1]),int(entry[2]))]=float(entry[3])
	world.stations=data.get("stations",{}).duplicate(true)
	for station_state in world.stations.values():
		for i in station_state.slots.size(): station_state.slots[i]=Inventory.clean_slot(station_state.slots[i])
	inventory.restore(data.inventory)
	for i in 9:
		inventory.grid[i]=Inventory.clean_slot(data.get("grid",[])[i] if i<data.get("grid",[]).size() else {})
	inventory.selected=clampi(int(data.get("selected",0)),0,8)
	hud.cursor = Inventory.clean_slot(data.get("cursor",{}))
	player.health=clampf(float(data.get("health",20)),0,20)
	player.hunger=clampf(float(data.get("hunger",20)),0,20)
	var saved_armor = data.get("armor",[])
	for i in 4: player.armor_slots[i]={"id":0,"count":0,"wear":0}
	if saved_armor is Array:
		for i in mini(4,saved_armor.size()):
			var piece: Dictionary=Inventory.clean_slot(saved_armor[i])
			if Nodes.is_armor(piece.id) and Nodes.armor_piece(piece.id)==i: player.armor_slots[i]=piece
	elif int(saved_armor)>0: player.armor_slots[1]={"id":Nodes.ARMOR,"count":1,"wear":0}
	player.breath=10
	day_time=float(data.get("time",0.3))
	experience=float(data.get("experience",0))
	journal_step=int(data.get("journal",0))
	var preferences: Dictionary=data.get("settings",{})
	world.radius=clampi(int(preferences.get("distance",4)),2,6)
	player.sensitivity=clampf(float(preferences.get("sensitivity",0.0022)),0.0006,0.005)
	audio_enabled=bool(preferences.get("audio",true))
	var load_position: Array=data.get("spawn",data.position) if player.health<=0 else data.position
	world.target=Vector3(load_position[0],load_position[1],load_position[2])
	for p in world.edits:
		if world.edits[p]==Nodes.TORCH: add_torch(p)
	state="loading"
	world.active=false

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if state not in ["title","loading"]: save_game()
		get_tree().quit()

func _setup_sounds() -> void:
	for i in 8:
		var audio := AudioStreamPlayer.new()
		audio.volume_db=-19
		add_child(audio)
		audio_players.append(audio)
	for i in 10:
		var audio := AudioStreamPlayer3D.new()
		audio.volume_db=-8
		audio.unit_size=7.0
		audio.max_distance=48.0
		audio.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(audio)
		audio_players_3d.append(audio)
	# Every effect is synthesized at startup: no audio assets ship with the game.
	var rng := RandomNumberGenerator.new()
	rng.seed=71
	var lengths: Dictionary = {"step":0.07,"dig":0.07,"break":0.16,"place":0.07,"pickup":0.07,"craft":0.16,"hurt":0.16,"eat":0.07,"click":0.07,"equip":0.16,
		"zombie":1.1,"cow":0.85,"sheep":0.65,"pig":0.28,"chicken":0.42,"skeleton":0.5,"spider":0.55,"creeper":1.5,"explode":1.3,"mob_hurt":0.22,"arrow":0.2,"thud":0.18}
	for kind in lengths:
		var duration: float = lengths[kind]
		var sample := AudioStreamWAV.new()
		sample.format=AudioStreamWAV.FORMAT_16_BITS
		sample.mix_rate=22050
		var data := PackedByteArray()
		var length: int=int(22050*duration)
		data.resize(length*2)
		var filtered: float=0
		var rumble: float=0
		var previous_noise: float=0
		for i in length:
			var t: float=float(i)/22050
			var progress: float=float(i)/length
			var envelope: float=pow(1.0-progress,2)
			var noise: float=rng.randf_range(-1,1)
			filtered=filtered*0.7+noise*0.3
			rumble=rumble*0.96+noise*0.04
			var bright: float=noise-previous_noise
			previous_noise=noise
			var value: float=filtered
			match kind:
				"pickup","craft","click": value=sin(t*TAU*(900 if kind=="pickup" else 620))*0.5
				"equip": value=sin(t*TAU*(520 if t<0.07 else 780))*0.5; envelope=pow(1.0-fmod(t,0.07)/0.07,1.5)*0.8
				"hurt": value=sin(t*TAU*(140-t*300))*0.3+filtered*0.5
				"step": value=filtered*0.6+sin(t*TAU*95)*0.2
				"zombie":
					# A low, wavering groan: detuned saw plus growl modulation.
					var f: float=105.0+22.0*sin(t*3.6)-t*18.0
					var phase: float=fposmod(t*f,1.0)
					value=((phase*2.0-1.0)*0.42+sin(t*TAU*f*2.0)*0.2)*(0.7+0.3*sin(t*TAU*21.0))+filtered*0.3
					envelope=minf(t*9.0,1.0)*pow(1.0-progress,0.9)
				"cow":
					var f: float=125.0-t*35.0+4.0*sin(t*TAU*5.0)
					var phase: float=fposmod(t*f,1.0)
					value=(phase*2.0-1.0)*0.4+sin(t*TAU*f*3.0)*0.15+filtered*0.1
					envelope=minf(t*12.0,1.0)*pow(1.0-progress,1.2)
				"sheep":
					var f: float=310.0+35.0*sin(t*TAU*9.0)
					var phase: float=fposmod(t*f,1.0)
					value=(phase*2.0-1.0)*0.38+sin(t*TAU*f*2.0)*0.12
					envelope=minf(t*20.0,1.0)*pow(1.0-progress,1.3)
				"pig":
					var f: float=260.0-t*400.0
					var phase: float=fposmod(t*f,1.0)
					value=filtered*0.55+(phase*2.0-1.0)*0.35
					envelope=minf(t*40.0,1.0)*pow(1.0-progress,1.8)
				"chicken":
					var local: float=fmod(t,0.14)
					value=sin(t*TAU*(900.0+local*2600.0))*0.45
					envelope=pow(1.0-local/0.14,1.6)*(1.0 if int(t/0.14)<3 else 0.0)
				"skeleton":
					var local: float=fmod(t,0.055)
					value=bright*0.8
					envelope=pow(1.0-local/0.055,5)*(1.0-progress*0.5)
				"spider":
					value=bright*0.6*(0.6+0.4*sin(t*TAU*32.0))
					envelope=minf(t*25.0,1.0)*pow(1.0-progress,1.1)
				"creeper":
					value=bright*0.5+filtered*0.2
					envelope=0.25+progress*0.75
				"explode":
					value=rumble*3.0+sin(t*TAU*48.0)*0.35*(1.0-progress)
					if t<0.04: value=noise*0.9
					envelope=pow(1.0-progress,1.4)
				"mob_hurt": value=sin(t*TAU*(230.0-t*500.0))*0.4+filtered*0.4
				"arrow": value=bright*0.7; envelope=minf(t*60.0,1.0)*pow(1.0-progress,2.5)
				"thud": value=sin(t*TAU*70.0)*0.6+filtered*0.3; envelope=pow(1.0-progress,2.5)
			data.encode_s16(i*2,int(clampf(value*envelope,-1.0,1.0)*26000))
		sample.data=data
		sounds[kind]=sample

func sound(kind: String) -> void:
	if not audio_enabled or not sounds.has(kind): return
	var now: int=Time.get_ticks_msec()
	if now-int(sound_times.get(kind,0))<50: return
	sound_times[kind]=now
	var audio: AudioStreamPlayer=audio_players[audio_index]
	audio_index=(audio_index+1)%audio_players.size()
	audio.stream=sounds[kind]
	audio.pitch_scale=randf_range(0.91,1.09)
	audio.play()

# Positional sound for creatures, explosions, and landing nodes.
func sound_at(kind: String, pos: Vector3, pitch: float = 1.0) -> void:
	if not audio_enabled or not sounds.has(kind) or state in ["title","loading"]: return
	var audio: AudioStreamPlayer3D=audio_players_3d[audio_index_3d]
	audio_index_3d=(audio_index_3d+1)%audio_players_3d.size()
	audio.global_position=pos
	audio.stream=sounds[kind]
	audio.pitch_scale=pitch
	audio.play()

func node_mesh(id: int) -> ArrayMesh:
	if not node_meshes.has(id): node_meshes[id] = Art.build_node_mesh(id)
	return node_meshes[id]

func _particle_mesh(id: int) -> Mesh:
	if not particle_meshes.has(id):
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE*0.07
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Nodes.color(id)
		cube.material = mat
		particle_meshes[id] = cube
	return particle_meshes[id]

func _emit(pos: Vector3, mesh: Mesh, amount: int, lifetime: float, speed_min: float, speed_max: float, direction: Vector3 = Vector3.UP, spread: float = 100.0) -> void:
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = direction
	particles.spread = spread
	particles.initial_velocity_min = speed_min
	particles.initial_velocity_max = speed_max
	particles.gravity = Vector3(0,-12,0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	particles.mesh = mesh
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(lifetime+0.2).timeout.connect(particles.queue_free)

func _break_particles(p: Vector3i, id: int) -> void:
	_emit(Vector3(p)+Vector3.ONE*0.5,_particle_mesh(id),10,0.45,1.0,3.0)

# Chips that fly off the face being dug, while digging continues.
func dig_particles(p: Vector3i, id: int, normal: Vector3i) -> void:
	_emit(Vector3(p)+Vector3.ONE*0.5+Vector3(normal)*0.52,_particle_mesh(id),3,0.35,0.8,2.2,Vector3(normal) if normal != Vector3i.ZERO else Vector3.UP,55.0)

func puff(pos: Vector3, color: Color, amount: int = 10, speed: float = 3.0) -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE*0.09
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	cube.material = mat
	_emit(pos,cube,amount,0.6,speed*0.4,speed)

func performance_snapshot() -> Dictionary:
	return {"fps":Engine.get_frames_per_second(),"map_blocks":world.blocks.size(),"columns":world.columns.size(),"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),"generation_jobs":world.jobs.size(),"remesh_jobs":world.remesh_jobs.size()}

func _migrate_legacy_save() -> void:
	var marker: String = saves.root_path.path_join("legacy_imported.json")
	if not FileAccess.file_exists(LEGACY_SAVE_PATH): return
	var imported: Dictionary = saves.read_json(marker)
	var id: String = String(imported.get("world",""))
	if not id.is_empty():
		# An older playtest may still have been saving while the new build was
		# installed. Import its latest progress, but never overwrite a newer native save.
		if FileAccess.get_modified_time(LEGACY_SAVE_PATH)<=FileAccess.get_modified_time(saves.save_path(id)): return
	var data: Dictionary = read_save(LEGACY_SAVE_PATH)
	if data.is_empty(): return
	if id.is_empty(): id = saves.create_world("My first world",int(data.seed),"survival")
	if id.is_empty(): return
	data.world_id=id; data.name="My first world"; data.gamemode="survival"
	if FileAccess.file_exists(saves.save_path(id)): DirAccess.copy_absolute(saves.save_path(id),saves.save_path(id)+".bak")
	if saves.write_json(saves.save_path(id),data):
		saves.write_json(marker,{"world":id})
		saves.update_metadata(id,"My first world",int(data.seed),"survival",floori(float(data.get("time",0.3)))+1)

func set_gamemode(mode: String) -> bool:
	if mode not in ["survival","creative"]: return false
	gamemode=mode
	player.flying=false
	player.velocity=Vector3.ZERO
	player.mining=0
	if mode=="creative": player.health=20; player.hunger=20; player.breath=10
	toast("Game mode set to "+mode.capitalize()+".")
	return true

func open_console(initial: String = "/") -> void:
	state="console"
	world.active=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	hud.show_console(initial)

func execute_command(command: String) -> String:
	var parts: PackedStringArray=command.strip_edges().trim_prefix("/").split(" ",false)
	var response: String=""
	if parts.is_empty(): return ""
	match parts[0].to_lower():
		"gamemode":
			if parts.size()!=2 or not set_gamemode(parts[1].to_lower()): response="Usage: /gamemode survival | creative"
			else: response="Game mode set to "+gamemode.capitalize()+"."
		"help": response="/gamemode survival | creative  ·  /time day | night  ·  /seed  ·  /save  ·  /spawnpoint\n/give <item> [count]  ·  /spawn <creature>  ·  /tp <x> <y> <z>  ·  /heal  ·  /killmobs\nCreative: F or double Space toggles flight. Space rises; Shift descends."
		"seed": response="World seed: "+str(world.seed_value)
		"save": response="World saved to "+saves.save_path(active_world_id) if save_game() else "The world could not be saved."
		"time":
			if parts.size()!=2 or parts[1] not in ["day","night"]: response="Usage: /time day | night"
			else:
				day_time=floorf(day_time)+(0.3 if parts[1]=="day" else 0.7)
				response="Time set to "+parts[1]+"."
		"spawnpoint": spawn_point=player.position; response="Spawn point set."
		"give":
			var id: int=Nodes.lookup(parts[1]) if parts.size()>=2 else 0
			if parts.size()<2: response="Usage: /give <item> [count]   e.g. /give diamond_pickaxe or /give iron_ingot 16"
			elif id==0: response="Unknown item: "+parts[1]
			else:
				var amount: int=clampi(int(parts[2]),1,64) if parts.size()>2 and parts[2].is_valid_int() else 1
				var rest: int=inventory.add_item(id,amount)
				if rest>0: spawn_drop(player.position+Vector3.UP,id,rest)
				response="Gave %d × %s." % [amount,Nodes.title(id)]
		"spawn":
			var kind: String=parts[1].to_lower() if parts.size()>=2 else ""
			if not Creature.KINDS.has(kind): response="Usage: /spawn "+" | ".join(Creature.KINDS.keys())
			else:
				var ahead: Vector3=player.position-player.camera.global_basis.z*Vector3(1,0,1)*4.0
				spawn_creature(kind,_safe_spawn(ahead))
				response=kind.capitalize()+" spawned."
		"tp":
			if parts.size()!=4 or not (parts[1].is_valid_float() and parts[2].is_valid_float() and parts[3].is_valid_float()): response="Usage: /tp <x> <y> <z>"
			else:
				teleport(Vector3(float(parts[1]),float(parts[2]),float(parts[3])))
				response="Teleported to %s %s %s." % [parts[1],parts[2],parts[3]]
		"heal": player.health=20; player.hunger=20; player.breath=10; response="Health and hunger restored."
		"killmobs":
			var removed: int=creatures.get_child_count()
			for mob in creatures.get_children(): mob.queue_free()
			response="Removed %d creatures." % removed
		_: response="Unknown command. Type /help for available commands."
	console_messages.append("> "+command)
	console_messages.append(response)
	while console_messages.size()>60: console_messages.pop_front()
	return response

func teleport(destination: Vector3) -> void:
	player.velocity=Vector3.ZERO
	if world.loaded_at(destination):
		player.position=_safe_spawn(destination) if world.intersects(destination) else destination
		world.target=player.position
		return
	# Far destinations stream in first, then use the normal arrival checks.
	pending_save={"position":[destination.x,destination.y,destination.z],"spawn":[spawn_point.x,spawn_point.y,spawn_point.z],"yaw":player.rotation.y,"pitch":player.camera.rotation.x,"drops":[]}
	world.target=destination
	state="loading"
	hud.show_loading()

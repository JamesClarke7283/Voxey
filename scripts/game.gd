extends Node3D

const LEGACY_SAVE_PATH = "user://voxey_world.json"
const SaveStore = preload("res://scripts/world_store.gd")
const SAVE_VERSION = 3
const SAVE_VERSIONS = [1,2,3]
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
var cave_sample_position := Vector3i(99999,99999,99999)
var cave_sample_revision: int = -1
var cave_sample_world: int = 0
var cave_shelter: float = 0
var identity: PlayerIdentity
var player_homes: Dictionary = {}
var ender_storage: Dictionary = PortableStorage.new_ender_station()
var player_id: String:
	get: return identity.session_id if identity != null else PlayerIdentity.OFFLINE
var spawn_point := Vector3(8,35,8)
var experience: float = 0.0:
	set(value):
		if value > experience and is_instance_valid(player) and inventory != null and state in ["playing","trading","workstation","console"]: value = experience+Enchantments.mend(self,value-experience)
		experience = value
var dimension: String = "overworld"
var leads: LeadManager
var maps: ExplorationMaps
var boats: Boats
var rails: Minecarts
var villages: VillageLife
var survival: VillageSurvival
var adventure: Adventure
var dimension_states: Dictionary = {}
# The autosave serializes on a worker, so a large world never stalls play. It
# holds a detached copy of the state; every other save, world switch and
# deletion waits for it first so two writers never touch the same files.
var save_task: int = -1
var save_status: Dictionary = {}
# Shader variants compile the first time something is drawn with them, which
# stalled play for 200-1200 ms on a Mesa/Intel driver when the first creature
# or dropped item came into view. One of each common kind is drawn while the
# loading screen covers the view instead.
var shader_warmup: Node3D = null
# Godot frees a material's compiled shader with the last material using it, so
# the warm-up materials are kept for the whole session.
static var warm_materials: Array = []
# Each creature kind builds its textures and meshes on first use, 10-30 ms.
# The loading screen builds them ahead, a few kinds per frame, once per session.
static var creature_art_queue: Array = []
static var creature_art_started: bool = false
var portal_cooldown: float = 0.0
var portal_time: float = 0.0
var journal_step: int = 0
var audio_enabled: bool = true
var audio_players: Array = []
var sounds: Dictionary = {}
var sound_times: Dictionary = {}
var audio_index: int = 0
var autosave: float = 0.0
var spawn_timer: float = 0.0
var achievement_timer: float = 0.0
var pending_save: Dictionary = {}
var settings: Dictionary = {}
var clouds: Node3D
var screenshot_path: String = ""
var saves
var active_world_id: String = ""
var world_name: String = "New world"
var gamemode: String = "survival"
# Difficulty 0..2, which the source scales boss health and damage by.
var difficulty: int = 1
var game_rules: Dictionary = GameRules.DEFAULTS.duplicate()
var console_messages: Array[String] = ["Voxey console. Type /help for commands."]
var last_space_press: int = 0
var api: VoxeyAPI
var touch: bool = false
var controls: TouchControls
var achievements: VoxeyAchievements

func _ready() -> void:
	get_tree().auto_accept_quit = false
	# After a slow frame the engine replays missed physics ticks, up to eight by
	# default; with many mobs those ticks made the next frame slow as well. Four
	# keeps one hitch from cascading, at the cost of briefly slower game time.
	Engine.max_physics_steps_per_frame = 4
	adventure = Adventure.new(self)
	leads = LeadManager.new(self)
	boats = Boats.new(self)
	rails = Minecarts.new(self)
	maps = ExplorationMaps.new(self)
	villages = VillageLife.new(self)
	survival = VillageSurvival.new(self)
	api = VoxeyAPI.new("engine",self)
	achievements = VoxeyAchievements.new(self)
	saves = SaveStore.new()
	identity = PlayerIdentity.new(saves.root_path)
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
	# Touch devices (phones/tablets) get on-screen controls and never capture
	# the pointer. Desktop touch monitors keep the mouse workflow.
	touch = DisplayServer.get_name() in ["Android","iOS"] or DisplayServer.is_touchscreen_available()
	if touch:
		controls = TouchControls.new()
		controls.name = "TouchControls"
		controls.game = self
		add_child(controls)
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
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
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
	# One mesh for the whole layer, so the clouds cost one draw call.
	var layer := SurfaceTool.new()
	for i in 24:
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(9,24),1.2,rng.randf_range(5,12))
		layer.append_from(box,0,Transform3D(Basis(),Vector3(rng.randf_range(-150,150),rng.randf_range(64,72),rng.randf_range(-150,150))))
	var instance := MeshInstance3D.new()
	instance.mesh = layer.commit()
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
	if save_task >= 0 and WorkerThreadPool.is_task_completed(save_task): finish_background_save()
	if world == null: return
	Jukeboxes.update(world,delta)
	maps.update()
	if state == "loading" and not is_instance_valid(shader_warmup): _warm_shaders()
	if state == "loading": _warm_creature_art()
	if state == "loading" and world.area_ready(world.target): _finish_loading()
	if state != "loading" and is_instance_valid(shader_warmup): shader_warmup.queue_free(); shader_warmup = null
	if state != "title" and state != "loading": world.target = player.position
	if playing():
		Dungeons.update(world,delta)
		boats.update(delta)
		Farming.update_world(self,delta)
		Golems.update(self,delta)
		adventure.update(delta)
		villages.update(delta)
		survival.update(delta)
		leads.update(delta)
		portal_cooldown = maxf(0,portal_cooldown-delta)
		var portal_node: int = world.node_at(Vector3i(player.position.floor()))
		if portal_cooldown <= 0 and portal_node == Nodes.END_GATEWAY:
			adventure.enter_gateway(); return
		if portal_cooldown <= 0 and (portal_node == Nodes.END_PORTAL or world.node_at(Vector3i((player.position+Vector3.UP*0.3).floor())) == Nodes.END_PORTAL):
			travel_dimension("overworld" if dimension == "end" else "end",dimension == "end")
			return
		if portal_cooldown <= 0 and world.node_at(Vector3i(player.position.floor())) == Nodes.NETHER_PORTAL:
			portal_time += delta
			if portal_time >= 1.0:
				travel_dimension("overworld" if dimension == "nether" else "nether")
				return
		else: portal_time = 0.0
		day_time += delta/1200.0
		# Clock and compass dials advance their spin tick, exactly as the
		# source's globalstep does.
		Dials.tick(delta)
		ItemArt.dial_game = self
		autosave += delta
		spawn_timer += delta
		# The wandering trader's own globalstep. Its twenty-minute cadence lives in the
		# module's 60-second counter, so this is per frame, unlike the six-second
		# natural-spawn cadence above.
		WanderingTraders.update(self,delta)
		if autosave >= 45: autosave=0; save_game("",true); toast("World saved")
		if spawn_timer > 6:
			spawn_timer = 0
			_spawn_creature()
		if journal_step == 3:
			for id in range(80,100):
				if inventory.count_item(id)>0: journal_step=4; toast("You're ready to explore. Make this world yours."); break
		achievement_timer += delta
		if achievement_timer >= 1.0:
			achievement_timer = 0.0; _check_achievements()
	_update_day()
	clouds.position.x = player.position.x + fmod(Time.get_ticks_msec()*0.0006,40)
	clouds.position.z = player.position.z
	var visible_torches: int = 0
	for p in torch_lights:
		var light: OmniLight3D = torch_lights[p]
		light.visible = Vector3(p).distance_to(player.position)<30 and visible_torches<24
		if light.visible: visible_torches += 1

func _update_day() -> void:
	environment.environment.ambient_light_sky_contribution = 1.0
	environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	clouds.visible = dimension == "overworld"
	environment.environment.background_mode = Environment.BG_COLOR if dimension != "overworld" else Environment.BG_SKY
	# Depth fog is opaque at the view distance. Columns stream in no nearer than
	# that, so terrain that is still loading stays hidden behind the haze.
	var view: float = world.radius*16.0
	environment.environment.fog_depth_end = view*(0.7 if dimension == "nether" else 1.0)
	environment.environment.fog_depth_begin = view*(0.1 if dimension == "nether" else (0.6 if dimension == "end" else 0.45))
	if dimension == "end":
		daylight = 0.1
		sunlight.light_energy = 0.3
		environment.environment.background_color = Color("141020")
		var end_sky: ProceduralSkyMaterial = environment.environment.sky.sky_material
		end_sky.sky_top_color = Color("141020"); end_sky.sky_horizon_color = Color("252033")
		end_sky.ground_horizon_color = Color("252033"); end_sky.ground_bottom_color = Color("141020")
		sunlight.light_color = Color("cbbddb")
		environment.environment.fog_light_color = Color("252032")
		environment.environment.ambient_light_color = Color("c5b7d7")
		environment.environment.ambient_light_energy = 0.6
		return
	if dimension == "nether":
		daylight = 0.1
		sunlight.light_energy = 0.05
		environment.environment.background_color = Color("351619")
		var nether_sky: ProceduralSkyMaterial = environment.environment.sky.sky_material
		nether_sky.sky_top_color = Color("291115")
		nether_sky.sky_horizon_color = Color("58282b")
		nether_sky.ground_horizon_color = Color("58282b")
		nether_sky.ground_bottom_color = Color("291115")
		environment.environment.fog_light_color = Color("58282b")
		environment.environment.ambient_light_color = Color("dc8b70")
		environment.environment.ambient_light_energy = 0.65
		return
	var phase: float = fposmod(day_time,1.0)
	daylight = clampf(sin((phase-0.05)*TAU)*1.6+0.15,0.05,1.0)
	sunlight.rotation_degrees.x = -phase*360+20
	sunlight.light_energy = lerpf(0.04,0.65,daylight)
	sunlight.light_color = Color("a8bcdd").lerp(Color("fff0ce"),daylight)
	environment.environment.ambient_light_energy = lerpf(0.20,0.48,daylight)
	environment.environment.ambient_light_color = Color("7784b1").lerp(Color("c2d6bd"),daylight)
	var sky_mat: ProceduralSkyMaterial = environment.environment.sky.sky_material
	sky_mat.ground_bottom_color = Color("547461")
	sky_mat.sky_top_color = Color("101c35").lerp(Color("6cabbf"),daylight)
	sky_mat.sky_horizon_color = Color("293950").lerp(Color("d2dac0"),daylight)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	environment.environment.fog_light_color = sky_mat.sky_horizon_color
	if state not in ["title","loading"]:
		var sample_position := Vector3i(player.position.floor())
		if sample_position != cave_sample_position or cave_sample_revision != world.sky_revision or cave_sample_world != world.get_instance_id():
			cave_sample_position = sample_position; cave_sample_revision = world.sky_revision; cave_sample_world = world.get_instance_id()
			cave_shelter = CaveLight.shelter(world,Vector3(sample_position)+Vector3(0.5,0.5,0.5))
		var underground: float = cave_shelter
		sunlight.light_energy *= 1.0-underground
		environment.environment.ambient_light_color = environment.environment.ambient_light_color.lerp(Color("9499a0"),underground)
		environment.environment.ambient_light_sky_contribution = 1.0-underground
		environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED if underground >= 1.0 else Environment.REFLECTION_SOURCE_SKY
		environment.environment.ambient_light_energy = lerpf(environment.environment.ambient_light_energy,0.06,underground)
		environment.environment.fog_light_color = sky_mat.sky_horizon_color.lerp(Color("141b20"),underground)
		if survival.weather() != "clear":
			sunlight.light_energy *= 0.55
			sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color("495c6c"),0.6)
			sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(Color("6b7d85"),0.65)
		if underground >= 1.0:
			# Assign constants directly; no sun color, sky reflection or dusk fog
			# enters a sheltered cave. Torches supply their own local lighting.
			sunlight.light_energy = 0.0
			environment.environment.ambient_light_energy = 0.06
			environment.environment.ambient_light_color = Color("9499a0")
			environment.environment.fog_light_color = Color("141b20")
		if survival.effects.has("night_vision"): environment.environment.ambient_light_energy = 0.8

func day_number() -> int:
	return floori(day_time)+1

# Survival milestones and per-event achievements, checked every second of play.
func _check_achievements() -> void:
	if gamemode!="survival": return
	if day_number()>=5: achievements.award("survivor")
	if player.position.y<8.0: achievements.award("deep")
	var worn: int = 0
	for slot in player.armor_slots:
		if Nodes.is_armor(slot.id) and Nodes.armor_material(slot.id)==3: worn += 1
	if worn==4: achievements.award("diamond_gear")

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
	maps.reset()
	gamemode = mode if mode in ["survival","creative"] else "survival"
	pending_save = {}
	dimension = "overworld"
	dimension_states.clear()
	player_homes.clear()
	ender_storage = PortableStorage.new_ender_station()
	game_rules = GameRules.DEFAULTS.duplicate()
	portal_cooldown = 0
	inventory = _reset_inventory()
	day_time = 0.30
	experience = 0
	journal_step = 0
	player.health=20; Hunger.reset(player); player.breath=10
	PotionEffects.clear(player)
	if player.has_meta("potion_death_done"): player.remove_meta("potion_death_done")
	player.offhand_slot={"id":0,"count":0,"wear":0}
	for slot in player.armor_slots: slot.id=0; slot.count=0; slot.wear=0; slot.erase("data")
	player.velocity=Vector3.ZERO
	_clear_entities()
	_replace_world(seed_number)
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
	finish_background_save()
	var previous_radius: int = world.radius
	for light in torch_lights.values(): light.queue_free()
	torch_lights.clear()
	remove_child(world)
	world.free()
	world = VoxelWorld.new()
	world.name="World"
	world.configure(seed_number,atlas,dimension)
	world.radius = previous_radius
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
		if player.health<=0:
			player.health=20; Hunger.reset(player)
			if dimension != "overworld":
				# Restore persisted drops before taking the player home.
				pending_save["respawn_overworld"] = true
			else: player.position=spawn_point
		if world.intersects(player.position): player.position=_safe_spawn(player.position)
		for entry in pending_save.get("drops",[]):
			var pos: Array = entry.position
			var restored_drop := spawn_drop(Vector3(pos[0],pos[1],pos[2]),Nodes.migrate(int(entry.id)),int(entry.count),int(entry.get("wear",0)),Inventory.clean_slot(entry).get("data",{}),float(entry.get("age",0)))
			if restored_drop != null: restored_drop.pickup_delay = float(entry.get("pickup_delay",0.6))
		for entry in pending_save.get("arrows",[]):
			var pos: Array = entry.position
			var shot := spawn_arrow(Vector3(pos[0],pos[1],pos[2]),Vector3.ZERO)
			shot.stuck = true; shot.life = float(entry.get("life",0)); shot.item_id = int(entry.get("id",Nodes.ARROW_ITEM)); shot.recoverable = entry.get("recoverable",true)
			var rot: Array = entry.get("rotation",[0,0,0])
			shot.rotation = Vector3(rot[0],rot[1],rot[2])
		AlchemyWorld.restore(self)
		NetherResident.restore_named(self)
		if pending_save.has("animals"): survival.restore_animals(pending_save.animals)
		Farming.update_world(self)
		Golems.restore(self)
		WanderingTraders.restore(self)
		if pending_save.has("leads"): leads.restore(pending_save.leads)
		if pending_save.get("respawn_overworld",false):
			travel_dimension("overworld",true)
			return
		if pending_save.get("arrival_portal",false): _arrival_portal()
		if pending_save.get("arrival_end",false):
			for x in range(49,54):
				for z in range(-2,3):
					_arrival_set_node(Vector3i(x,44,z),Nodes.OBSIDIAN)
					for y in range(45,49): _arrival_set_node(Vector3i(x,y,z),Nodes.AIR)
			player.position = Vector3(51.5,45.01,0.5)
			if world.intersects(player.position): player.position = _safe_spawn(player.position)
		pending_save={}
	else:
		spawn_point=_safe_spawn(spawn_point)
		player.position=spawn_point
		player.rotation.y=0.3
		player.camera.rotation.x=-0.12
	for p in world.edits:
		if Torches.is_torch(world.edits[p]) or world.edits[p] in [Nodes.GLOWSTONE,Nodes.SHROOMLIGHT]: add_torch(p)
	player.velocity=Vector3.ZERO
	player.flying=false
	boats.restore()
	Minecarts.restore(self,world.adventure_state.get("carts",{}))
	player.camera.make_current()
	resume()
	toast("Welcome to Voxey. Tap the bag button to craft, or pause for the field guide." if touch else "Welcome to Voxey. Press E to craft, or Esc for the field guide.")
	spawn_timer=5
	save_game()
	MOD_ENTRY.fire("on_world_entered",[world_name,world.seed_value])

func _safe_spawn(near: Vector3) -> Vector3:
	if near.y >= world.generator.terrain_ceiling():
		var sky_floor: Vector3 = world.cave_spawn(near,16)
		if not is_inf(sky_floor.x): return sky_floor
	if near.y < 0:
		for radius in range(0,12):
			for offset in [Vector3(radius,0,0),Vector3(-radius,0,0),Vector3(0,0,radius),Vector3(0,0,-radius)]:
				var cave_pos: Vector3 = world.cave_spawn(near+offset,16)
				if not is_inf(cave_pos.x): return cave_pos
	for radius in range(0,12):
		for offset in [Vector2i(radius,0),Vector2i(-radius,0),Vector2i(0,radius),Vector2i(0,-radius)]:
			var x: int = floori(near.x)+offset.x
			var z: int = floori(near.z)+offset.y
			if not world.loaded_at(Vector3(x,0,z)): continue
			for y in range(mini(floori(near.y)+16,world.generator.terrain_ceiling()-1),world.generator.min_y(),-1):
				var id: int = world.node_at(Vector3i(x,y,z))
				if Fluids.liquid(id): break
				if Nodes.solid(id) and not WoodTypes.is_leaves(id) and not WoodTypes.is_log(id):
					var pos := Vector3(x+0.5,y+1.01,z+0.5)
					if not world.intersects(pos): return pos
					if dimension != "nether": break
	return Vector3(8.5,world.generator.terrain_height(8,8)+8,8.5)

func resume() -> void:
	if state == "sign" and has_meta("sign_editor"): remove_meta("sign_editor")
	hud.return_cursor()
	state="playing"
	world.active=true
	if touch:
		if is_instance_valid(controls): controls.show_game_controls()
	else:
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
	if kind in ["furnace","brewing"]: world.active=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(controls): controls.hide_all()
	hud.show_inventory(kind,world.get_station(p,kind) if kind in ["chest","furnace","brewing"] else {})

func return_to_title() -> void:
	hud.return_cursor()
	save_game()
	state="title"
	world.active=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(controls): controls.hide_all()
	position_menu_camera()
	menu_camera.make_current()
	hud.show_title()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F11: toggle_fullscreen(); return
		if state in ["title","loading"]: return
		if state in ["book","enchanting","trading","workstation","map","sign"]:
			if event.physical_keycode == KEY_ESCAPE: resume()
			return
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
				elif state == "inventory": close_inventory()
				elif state == "paused": resume()
			KEY_E:
				if state=="playing": open_inventory()
				elif state=="inventory": resume()
			KEY_F3: hud.debug=not hud.debug
			KEY_F5: save_game(); toast("World saved")
			KEY_Q:
				if playing(): drop_stack(inventory.held(),1)
		if playing() and event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_9:
			inventory.selected=event.physical_keycode-KEY_1
			hud.refresh_slots()
	if not playing(): return
	# Touch look: any drag outside the virtual controls turns the camera.
	if touch and event is InputEventScreenDrag:
		if is_instance_valid(controls) and event.index == controls._stick_touch: return
		player.look(event.relative*1.6)
		return
	if not touch and event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED: player.look(event.screen_relative)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_MIDDLE and gamemode=="creative" and not player.target.is_empty():
			var picked: int = Nodes.pick_item(player.target.id)
			inventory.slots[inventory.selected]={"id":picked,"count":Nodes.max_stack(picked),"wear":0}
			hud.refresh_slots()
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: inventory.selected=posmod(inventory.selected-1,9); hud.refresh_slots()
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: inventory.selected=posmod(inventory.selected+1,9); hud.refresh_slots()

func break_node(p: Vector3i, id: int, tool: int) -> void:
	# Seagrass is a rooted node: digging it restores its surface block, and only
	# shears yield the item, as the source's `_mcl_shears_drop` requires.
	if Kelp.break_node(self,p,id,tool): return
	if Seagrass.break_node(self,p,id,tool): return
	if DenseMaterials.break_ice(self,p,id,tool): return
	if Beehives.break_node(self,p,id,tool): return
	if Doors.break_node(self,p,id,tool): return
	if Decor.break_node(self,p,id,tool): return
	if Archaeology.break_node(self,p,id,tool): return
	# An infested block releases a silverfish unless Silk Touch was used.
	if MonsterEggs.break_node(self,p,id): return
	if Sponges.break_node(self,p,id,tool): return
	if Campfires.break_node(self,p,id,tool): return
	if id == Bookshelves.ID:
		# The source's own `after_dig_node` drops the shelf's contents.
		if not world.set_node(p,Nodes.AIR): return
		if gamemode != "creative":
			for entry in Bookshelves.contents(world,p): spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry.id,entry.count,entry.get("wear",0),entry.get("data",{}))
			spawn_drop(Vector3(p)+Vector3.ONE*0.5,Bookshelves.ID)
		_break_particles(p,id); sound("break"); progress("gather"); api.emit_node_broken(p,id)
		return
	if Candles.break_node(self,p,id,tool): return
	if PortableStorage.break_node(self,p,id,tool): return
	if survival.break_special(p,id,tool): return
	var partner: Vector3i = world.chest_partner(p) if id == Nodes.CHEST else p
	if id in [Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN]:
		var other: Vector3i = p+(Vector3i.DOWN if world.circuits.state(p).get("upper",false) else Vector3i.UP)
		if world.node_at(other) in [Nodes.IRON_DOOR,Nodes.IRON_DOOR_OPEN]: world.set_node(other,Nodes.AIR)
	# A bed breaks as a whole: removing one half takes the other with it.
	if id == Nodes.BED_FOOT or id == Nodes.BED_HEAD:
		var other: Vector3i = _bed_partner(p,id)
		if other != p and world.node_at(other) in [Nodes.BED_FOOT,Nodes.BED_HEAD]:
			world.set_node(other,Nodes.AIR)
	if not world.set_node(p,Nodes.AIR): return
	if id == Nodes.SUGAR_CANE:
		var above: Vector3i = p+Vector3i.UP
		while world.node_at(above) == Nodes.SUGAR_CANE:
			world.set_node(above,Nodes.AIR)
			if gamemode != "creative": spawn_drop(Vector3(above)+Vector3.ONE*0.5,Nodes.SUGAR_CANE)
			above += Vector3i.UP
		# The remaining stalk resumes growing even when harvested from wild cane.
		if world.node_at(p+Vector3i.DOWN) == Nodes.SUGAR_CANE: world.growth[p+Vector3i.DOWN] = 0.0
	if gamemode!="creative" and Nodes.harvestable(id,tool):
		var enchanted_drops: Array = Enchantments.harvest(id,inventory.held())
		# A sculk break is its own contract: nothing by hand, the vein to shears,
		# sculk and the catalyst to Silk Touch, and stored experience on the break.
		if Sculk.is_sculk(id):
			for entry in Sculk.harvest(id,inventory.held()): spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
			experience += Sculk.harvest_xp(world,p,id,inventory.held())
		elif CropFarming.is_crop(id) or FruitCrops.harvestable(id) or Amethyst.is_amethyst(id):
			for entry in enchanted_drops: spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
		elif WoodTypes.is_leaves(id):
			# An empty source leaf result means no drop, never the generic fallback.
			for entry in WoodTypes.harvest(id,inventory.held()): spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
		elif not enchanted_drops.is_empty():
			for entry in enchanted_drops: spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
		elif VillageContent.shape(id) == "crop":
			for crop_drop in VillageContent.crop_drops(id): spawn_drop(Vector3(p)+Vector3.ONE*0.5,crop_drop[0],crop_drop[1])
		elif id==Nodes.GRAVEL and randf()<0.25:
			spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.FLINT)
		elif HugeMushrooms.is_huge(id):
			# The source's mushroom-block drop is the *small* mushroom, one or two of
			# them, and Silk Touch is what preserves the block itself. So breaking a
			# huge mushroom yields mushrooms to eat or plant, not building material.
			var silk: bool = Inventory.enchantment(inventory.held(),"Silk Touch") > 0
			if silk: spawn_drop(Vector3(p)+Vector3.ONE*0.5,id,1)
			# Source rarity 9 twice, i.e. one or two mushrooms.
			else: spawn_drop(Vector3(p)+Vector3.ONE*0.5,HugeMushrooms.species_of(id),1 if randf() < 0.5 else 2)
		elif FoodFeatures.is_tall_grass(id):
			# The source's seed drop is one in eight, not a certainty, so breaking
			# a tuft usually yields nothing.
			if randf() < 1.0/8.0: spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.SEEDS)
		elif id in [Nodes.LAPIS_ORE,Nodes.DEEP_LAPIS_ORE]: spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.LAPIS,randi_range(4,9))
		elif id in [Nodes.REDSTONE_ORE,Nodes.DEEP_REDSTONE_ORE]:
			spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.REDSTONE_WIRE,randi_range(4,5)); experience += 2
		elif id == Nodes.CLAY: spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.CLAY_BALL,4)
		elif id == Nodes.SNOW_BLOCK: spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.SNOW_BALL_ALIAS,4)
		elif SeaPickles.is_pickle(id):
			# A pickle drops one item per size, as the source's count says.
			spawn_drop(Vector3(p)+Vector3.ONE*0.5,id,SeaPickles.size(id))
		elif Corals.is_coral(id):
			# Silk Touch preserves living coral; otherwise the dead form drops,
			# which `Nodes.drop` already returns.
			var silk: bool = Inventory.enchantment(inventory.held(),"Silk Touch") > 0
			spawn_drop(Vector3(p)+Vector3.ONE*0.5,id if silk else Corals.dead_form(id),1)
		elif RawOres.harvest(id,inventory.held()).size() > 0:
			# Copper ore rolls its source count (two to five, widened by Fortune)
			# rather than dropping a single raw item.
			for entry in RawOres.harvest(id,inventory.held()): spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
		elif id!=Nodes.GLASS: spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.drop(id),1,0,Copper.drop_metadata(world,p))
		if Inventory.enchantment(inventory.held(),"Silk Touch") == 0 and (Nodes.DEEP_ORES.has(id) or id in [Nodes.COAL_ORE,Nodes.IRON_ORE,Nodes.DIAMOND_ORE,Nodes.LAPIS_ORE,Nodes.NETHER_QUARTZ_ORE]): experience += 1
		if WoodTypes.is_log(id): achievements.award("first_log")
		if id in [Netherite.ANCIENT_DEBRIS]: achievements.award("hidden_in_the_depths")
		if id == Nodes.OBSIDIAN: achievements.award("obsidian_challenge")
		if id == Bastions.CRYING_OBSIDIAN: achievements.award("who_is_cutting_onions")
		if id==Nodes.STONE: achievements.award("mine_stone")
		if id in [Nodes.DIAMOND_ORE,Nodes.DEEP_DIAMOND_ORE]: achievements.award("diamonds")
		if id == Nodes.DRAGON_EGG: achievements.award("the_next_generation")
	for slot in world.detach_station(p,partner): spawn_drop(Vector3(p)+Vector3.ONE*0.5,slot.id,slot.count,slot.wear,slot.get("data",{}))
	remove_torch(p)
	var above: Vector3i=p+Vector3i.UP
	var upper: int=world.node_at(above)
	if Nodes.plant(upper) or upper==Nodes.TORCH or upper in Nodes.SMALL_CIRCUITS and upper != Nodes.IRON_DOOR_OPEN: break_node(above,upper,tool)
	settle(above)
	_break_particles(p,id)
	sound("break")
	progress("gather")
	api.emit_node_broken(p,id)

func remove_torch(p: Vector3i) -> void:
	if torch_lights.has(p): torch_lights[p].queue_free(); torch_lights.erase(p)

# The other half of a bed: scan the four horizontal neighbours for the
# complementary half. Returns p when no partner is found.
func _bed_partner(p: Vector3i, id: int) -> Vector3i:
	var wanted: int = Nodes.BED_HEAD if id == Nodes.BED_FOOT else Nodes.BED_FOOT
	for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		if world.node_at(p+d) == wanted: return p+d
	return p

# Unsupported sand and gravel become falling entities, then the node above is
# checked in turn so a whole column comes down together.
func settle(p: Vector3i) -> void:
	for step in world.generator.max_y()-world.generator.min_y():
		var id: int = world.node_at(p)
		if not Nodes.falls(id) or Nodes.solid(world.node_at(p+Vector3i.DOWN)): return
		if not world.set_node(p,Nodes.AIR): return
		var falling := FallingNode.new()
		falling.game = self; falling.node_id = id; falling.position = Vector3(p)
		entities.add_child(falling)
		p += Vector3i.UP

func spawn_arrow(origin: Vector3, velocity: Vector3) -> Arrow:
	var arrow := Arrow.new()
	arrow.game = self; arrow.position = origin; arrow.velocity = velocity; arrow.launch_point = origin
	entities.add_child(arrow)
	sound_at("arrow",origin)
	return arrow

func ignite_tnt(p: Vector3i, fuse: float = 3.0) -> void:
	if world.node_at(p) != Nodes.TNT or not world.set_node(p,Nodes.AIR): return
	var tnt := PrimedTnt.new()
	tnt.game = self; tnt.position = Vector3(p); tnt.fuse = fuse
	entities.add_child(tnt)

# Creeper and TNT blasts carve a rough sphere, drop a share of the nodes, light
# other TNT, and hurt anything nearby in proportion to its distance.
func explode(center: Vector3, radius: float, source: Node = null, fire: bool = false) -> void:
	var removed: Array = []
	# The source's `info.fire`: when set, one destroyed node in three becomes fire
	# rather than air, which is what makes a Nether bed or a respawn anchor scorch the
	# ground around it. It is off by default, so an ordinary blast leaves no flames.
	var ignited: Array = []
	var reach: int = ceili(radius)
	for x in range(-reach,reach+1):
		for y in range(-reach,reach+1):
			for z in range(-reach,reach+1):
				var offset := Vector3(x,y,z)
				if offset.length() > radius-randf()*0.7: continue
				var p := Vector3i(floori(center.x)+x,floori(center.y)+y,floori(center.z)+z)
				var id: int = world.node_at(p)
				if Fluids.liquid(id) or id in [Nodes.AIR,Nodes.BEDROCK,Nodes.OBSIDIAN,Nodes.WATER,Nodes.LAVA,Nodes.END_FRAME,Nodes.END_FRAME_EYE,Nodes.END_PORTAL,Nodes.END_GATEWAY,Nodes.NETHER_PORTAL]: continue
				if VillageContent.DATA.get(id,{}).get("blast_resistance",0) >= 1200: continue
				if PortableStorage.break_node(self,p,id,0,true): continue
				if Beehives.break_node(self,p,id,0,true): continue
				if Campfires.break_node(self,p,id,0,true): continue
				if Doors.break_node(self,p,id,0,true): continue
				if id == Nodes.TNT: ignite_tnt(p,randf_range(0.3,0.9)); continue
				if id in [Nodes.BED_FOOT,Nodes.BED_HEAD]:
					# Remove the whole bed, drop one item, count one node.
					var other: Vector3i = _bed_partner(p,id)
					if other != p and world.node_at(other) in [Nodes.BED_FOOT,Nodes.BED_HEAD]: world.set_node(other,Nodes.AIR)
				var partner: Vector3i = world.chest_partner(p) if id == Nodes.CHEST else p
				if not world.set_node(p,Nodes.AIR): continue
				for slot in world.detach_station(p,partner): spawn_drop(Vector3(p)+Vector3.ONE*0.5,slot.id,slot.count,slot.wear,slot.get("data",{}))
				remove_torch(p)
				if randf() < 0.3:
					if Amethyst.is_crystal(id):
						for entry in Amethyst.environment_drops(id): spawn_drop(Vector3(p)+Vector3.ONE*0.5,entry[0],entry[1])
					else: spawn_drop(Vector3(p)+Vector3.ONE*0.5,Nodes.drop(id),SnowCover.layers(id)+1 if SnowCover.is_snow(id) else (4 if id == Nodes.SNOW_BLOCK else 1))
				removed.append(p)
				if fire and id != Nodes.AIR: ignited.append(p)
	for p in ignited:
		# One in three, and only where the cell is now empty, so a flame never
		# replaces a block that survived.
		if randf() < 1.0/3.0 and world.node_at(p) == Nodes.AIR: Fire.ignite(world,p)
	for p in removed: settle(p+Vector3i.UP)
	var blast: float = radius*2.0
	var player_distance: float = center.distance_to(player.position+Vector3.UP*0.9)
	if player_distance < blast: player.hurt(lerpf(16.0,1.0,player_distance/blast),false,center,"explosion")
	for mob in creatures.get_children():
		if mob == source or mob.is_queued_for_deletion(): continue
		var d: float = center.distance_to(mob.center())
		if d < blast:
			# A charged creeper's blast is the only explosion that yields heads.
			mob.hit(lerpf(20.0,1.0,d/blast),center,"charged_explosion" if source is Creature and source.charged else "")
	boats.explode(center,radius)
	puff(center,Color("d8c9a6"),50,radius*2.2)
	puff(center,Color("ff9b3a"),20,radius*1.4)
	hud.flash = maxf(hud.flash,0.3 if player_distance < blast else 0.0)
	sound_at("explode",center,randf_range(0.9,1.1))

func _warm_creature_art() -> void:
	if not creature_art_started:
		creature_art_started = true
		creature_art_queue = Creature.KINDS.keys()+Creature.ALCHEMY_KINDS+["rabbit","horse","villager","iron_golem"]
	var started: int = Time.get_ticks_usec()
	while not creature_art_queue.is_empty() and Time.get_ticks_usec()-started < 8000:
		var kind: String = creature_art_queue.pop_back()
		var mob: Creature = _creature_class(kind)
		mob.game = self; mob.kind = kind
		mob.model = Node3D.new(); mob.add_child(mob.model)
		mob._build_model(); mob.merge_parts()
		mob.free()

# The script class that plays a creature kind, as spawn_creature chooses it.
static func _creature_class(kind: String) -> Creature:
	if kind in Creature.ALCHEMY_KINDS: return AlchemyCreature.new()
	if kind in ["rabbit","horse"]: return RuralAnimal.new()
	if kind in ["villager","iron_golem"]: return VillageMob.new()
	if kind in ["ghast","blaze","slime","enderman","end_crystal","ender_dragon","shulker"]: return ExpeditionCreature.new()
	if kind in ["piglin","piglin_brute"]: return NetherResident.new()
	return Creature.new()

func spawn_creature(kind: String, pos: Vector3, farm_key: String = "") -> Creature:
	if kind == "snow_golem": return Golems.spawn(self,kind,pos)
	if kind in Creature.ALCHEMY_KINDS:
		var mob := AlchemyCreature.new(); mob.game = self; mob.kind = kind; mob.position = pos; creatures.add_child(mob); return mob
	if kind in ["rabbit","horse"]:
		var animal := RuralAnimal.new(); animal.game = self; animal.kind = kind; animal.position = pos; animal.farm_id = farm_key; creatures.add_child(animal); return animal
	if kind == "wandering_trader":
		# The trader brings its own llama escort, so the escort is never spawned
		# standalone; `spawn` builds the pair.
		return WanderingTraders.spawn(self,pos)
	if kind == "trader_llama":
		var llama: Creature = WanderingTraders.LlamaMob.new()
		llama.game = self; llama.kind = kind; llama.position = pos
		creatures.add_child(llama)
		return llama
	if kind in ["villager","iron_golem"]:
		var settler := VillageMob.new(); settler.game = self; settler.kind = kind; settler.position = pos
		creatures.add_child(settler); villages.manual(settler); return settler
	if not Creature.KINDS.has(kind): return null
	var mob: Creature = ExpeditionCreature.new() if kind in ["ghast","blaze","slime","enderman","end_crystal","ender_dragon","shulker"] else (NetherResident.new() if kind in ["piglin","piglin_brute"] else Creature.new())
	mob.game=self; mob.position=pos; mob.kind=kind; mob.farm_id=farm_key
	creatures.add_child(mob)
	return mob

func _clear_entities() -> void:
	if rails != null: rails.reset()
	if boats != null: boats.reset()
	if survival != null: survival.reset()
	if leads != null: leads.clear()
	for child in creatures.get_children(): child.queue_free()
	for child in drops.get_children(): child.queue_free()
	for child in entities.get_children(): child.queue_free()

func spawn_drop(pos: Vector3, id: int, amount: int = 1, wear: int = 0, metadata: Dictionary = {}, age: float = 0.0) -> ItemDrop:
	if amount<=0 or id==0: return null
	var drop := ItemDrop.new()
	drop.data=metadata.duplicate(true); drop.age=age
	drop.game=self; drop.item_id=id; drop.amount=amount; drop.wear=wear; drop.position=pos
	drops.add_child(drop)
	return drop

func target_mob() -> Creature:
	var origin: Vector3=player.camera.global_position
	var dir: Vector3=-player.camera.global_basis.z
	var max_distance: float=4.0
	if not player.target.is_empty(): max_distance=minf(max_distance,player.target.distance)
	var nearest: Creature=null
	for mob in creatures.get_children():
		if mob.is_queued_for_deletion(): continue
		var center: Vector3=mob.center()
		var along: float=(center-origin).dot(dir)
		if along>0 and along<max_distance and (origin+dir*along).distance_to(center)<maxf(0.65,mob.width+0.35): nearest=mob; max_distance=along
	return nearest

func _spawn_creature() -> void:
	# The cap counts mobs that are *near the player*, not every mob alive. A distant
	# mob neither loads nor simulates, so counting it would let a few stray
	# non-despawnable piglins — which `can_despawn = false` keeps forever — block all
	# natural spawning permanently.
	var normal_count: int = 0
	for mob in creatures.get_children():
		if mob.kind in ["end_crystal","ender_dragon","villager","iron_golem"]: continue
		if mob.position.distance_to(player.position) > 128: continue
		normal_count += 1
	if normal_count >= 12: return
	if dimension == "nether" and randf() < 0.3:
		var pos: Vector3 = player.position+Vector3(randf_range(-28,28),randf_range(8,16),randf_range(-28,28))
		if world.loaded_at(pos) and not world.intersects(pos,1.6,4): spawn_creature("ghast",pos)
		return
	var underground: bool = dimension == "overworld" and player.position.y < world.generator.terrain_height(floori(player.position.x),floori(player.position.z))-6
	var hostile: bool=daylight<0.35 or underground or dimension != "overworld"
	var angle: float=randf()*TAU
	var pos: Vector3=player.position+Vector3(cos(angle),0,sin(angle))*randf_range(14,32)
	if not world.loaded_at(pos): return
	pos = world.cave_spawn(pos) if underground or dimension == "nether" else _safe_spawn(pos)
	if is_inf(pos.x): return
	if pos.distance_to(player.position)<10: return
	if SlimeSpawns.try_spawn(self,pos): return
	if dimension == "overworld":
		if not underground and randf() < 0.035: spawn_creature("pillager",pos); return
		if not underground and daylight < 0.3 and day_number() >= 3 and randf() < 0.12: spawn_creature("phantom",pos+Vector3.UP*10); return
		if underground and randf() < 0.12: spawn_creature("breeze" if pos.y < -40 else "silverfish",pos); return
		if not underground and pos.y <= TerrainGenerator.SEA+3 and randf() < 0.2: spawn_creature("turtle",pos); return
		# Guardians live in open ocean: a submerged spawn cell away from shore.
		if not underground and randf() < 0.10:
			var depth: int = TerrainGenerator.SEA-pos.y
			if depth >= 6 and Fluids.water(world.node_at(Vector3i(pos.floor()))):
				spawn_creature("guardian_elder" if randf() < 0.08 else "guardian",pos)
				return
		# Fish and squid live in shallow and deep water alike, so any submerged
		# cell will do. The source's own `spawn_in_water` rule is the check here.
		if not underground and randf() < 0.14:
			if Fluids.water(world.node_at(Vector3i(pos.floor()))) and Fluids.water(world.node_at(Vector3i(pos.floor())+Vector3i.UP)):
				spawn_creature(AquaticMobs.pick(randi()),pos)
				return
	if hostile:
		for p in torch_lights:
			if Vector3(p).distance_to(pos)<10: return
	elif normal_count>=7: return
	var pool: Array = ["enderman"] if dimension == "end" else (["piglin","magma_cube","enderman","wither_skeleton","blaze"] if dimension == "nether" else (Creature.HOSTILE if hostile else Creature.PASSIVE))
	var biome: String = world.generator.biome(int(pos.x),int(pos.z))
	if not hostile and "desert" in biome and randf() < 0.6: return
	spawn_creature(pool[randi()%pool.size()],pos)

func add_torch(p: Vector3i) -> void:
	if torch_lights.has(p): return
	var light := OmniLight3D.new()
	light.position=Torches.flame_position(p,world.edits.get(p,world.node_at(p)))
	# Glowstone glows a touch wider and cooler than a torch flame.
	var glow: bool = world.node_at(p)==Nodes.GLOWSTONE
	light.omni_range=10 if glow else 8
	light.light_color=Color("e8dba0") if glow else Color("ffbc60")
	light.light_energy=1.1 if glow else 0.8
	light.shadow_enabled=false
	add_child(light)
	torch_lights[p]=light

func sleep_at(p: Vector3i) -> void:
	if dimension != "overworld":
		# The source's own rule: a bed in the Nether or the End **explodes**, taking
		# both halves with it and setting fires. Voxey used to refuse with a message,
		# which is the safe outcome but not the source's — and it removed the reason
		# the rule exists, since the explosion is what punishes trying it.
		var id: int = world.node_at(p)
		if VillageContent.is_bed(id):
			var other: Vector3i = _bed_partner(p,id)
			if other != p and VillageContent.is_bed(world.node_at(other)): world.set_node(other,Nodes.AIR)
			world.set_node(p,Nodes.AIR)
			explode(Vector3(p)+Vector3.ONE*0.5,5.0,null,true)
			toast("The bed explodes violently.")
			return
		toast("Beds only set your spawn in the Overworld.")
		return
	spawn_point=_safe_spawn(Vector3(p)+Vector3(1,0,0))
	if gamemode != "creative": achievements.award("sweet_dreams")
	if daylight>0.4: toast("Spawn set. Come back at night to sleep."); return
	for mob in creatures.get_children():
		if mob.hostile and mob.position.distance_to(player.position)<12: toast("There are wanderers nearby. Find safety first."); return
	day_time=floorf(day_time)+1.22
	player.health=minf(20,player.health+4)
	toast("A new day. Your spawn is set here.")
	save_game()

func die() -> void:
	if state == "dead": return
	# `mcl_sculk` spreads from a catalyst near where the player died, and stores
	# experience in the new blocks. It is the module's only driver.
	Sculk.handle_death(world,Vector3i(player.position.floor()),Sculk.death_rng(world))
	boats.dismount(false)
	Fishing.cancel(survival)
	PotionEffects.died(player)
	api.emit_player_died()
	if not game_rules.keepInventory: DeathRecovery.leave(self)
	if is_instance_valid(controls): controls.hide_all()
	state="dead"
	world.active=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	hud.show_death()
	save_game()

func respawn() -> void:
	PotionEffects.clear(player)
	if player.has_meta("potion_death_done"): player.remove_meta("potion_death_done")
	player.health=20; Hunger.reset(player); player.breath=10; player.velocity=Vector3.ZERO
	if dimension != "overworld":
		travel_dimension("overworld",true)
		return
	player.position=spawn_point
	world.target=spawn_point
	if world.loaded_at(spawn_point): player.position=_safe_spawn(spawn_point); resume()
	else: state="loading"

func progress(action: String) -> void:
	var has_log: bool = inventory.slots.any(func(slot): return slot.count > 0 and WoodTypes.is_log(slot.id))
	var has_planks: bool = inventory.slots.any(func(slot): return slot.count > 0 and WoodTypes.is_planks(slot.id)) or (hud.cursor.count > 0 and WoodTypes.is_planks(hud.cursor.id))
	if journal_step==0 and action=="gather" and has_log: journal_step=1
	elif journal_step==1 and action=="craft" and has_planks: journal_step=2
	elif journal_step==2 and action=="build" and world.edits.values().has(Nodes.WORKBENCH): journal_step=3
	# Craft-based achievements key off what the player now holds.
	if action=="craft":
		if has_planks: achievements.award("craft_planks")
		if inventory.count_item(Nodes.FURNACE)>0: achievements.award("hot_topic")
		if inventory.count_item(VillageContent.CAKE)>0: achievements.award("the_lie")
		if inventory.count_item(Nodes.BOOKSHELF)>0: achievements.award("librarian")
		if _holds_tool_kind(3): achievements.award("time_to_strike")
		if _holds_tool_kind(4): achievements.award("time_to_farm")
		if inventory.count_item(Nodes.TOOLS+5)>0: achievements.award("getting_an_upgrade")
		if inventory.count_item(Nodes.BREAD)>0: achievements.award("baker")
		if inventory.count_item(Nodes.TOOLS)>0 or inventory.count_item(Nodes.TOOLS+4)>0 or _holds_tool_kind(0): achievements.award("first_pickaxe")
		_holds_smelted_iron()
	if action=="build":
		if world.edits.values().has(Nodes.WORKBENCH): achievements.award("craft_table")
		if world.edits.values().has(Nodes.BOOKSHELF): achievements.award("bookworm")

# Relay for creature deaths so hook subscribers see mob kills. `mob` freed by
# the caller afterwards.
func MOD_HOOK_CREATURE_KILLED(mob: Node3D) -> void:
	MOD_ENTRY.fire("on_creature_killed",[mob.kind,Vector3(mob.position)])

func _holds_tool_kind(kind: int) -> bool:
	for slot in inventory.slots:
		if Nodes.is_tool_id(slot.id) and Nodes.tool_kind(slot.id)==kind: return true
	return false

func _holds_smelted_iron() -> void:
	if inventory.count_item(Nodes.IRON)>0:
		achievements.award("iron_age"); achievements.award("acquire_hardware")

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
		"achievements": hud.show_achievements()
		"inventory": hud.show_inventory(hud.station,hud.station_data)
		"dead": hud.show_death()
		"worlds": hud.show_worlds()
		"delete_world": hud.show_delete_world(hud.delete_world_entry)
		"new_world": hud.show_new_world()
		"console": hud.show_console()
		"loading": hud.show_loading()
		"workstation": survival.show_station(survival.workstation_pos,survival.workstation_id)
		"map": survival.show_map()
		"sign": Signs.reflow(self)
		"book": hud.show_book(hud.book_index)
		"enchanting": hud.show_enchanting(hud.enchanting_pos)
		"trading": hud.show_trading(villages.trading_key)
	if touch and state=="playing" and is_instance_valid(controls): controls.show_game_controls()

func has_save() -> bool:
	return not saves.list_worlds().is_empty()

func save_game(path: String = "", background: bool = false) -> bool:
	if state in ["title","loading"]: return false
	finish_background_save()
	var world_save: bool = path.is_empty()
	if world_save: path=saves.save_path(active_world_id)
	if path.is_empty(): return false
	inventory.sync_pouches()
	var snapshot: Dictionary = dimension_snapshot(background)
	var dimensions: Dictionary = dimension_states
	if background:
		# The live states are replaced whole, never edited, so a shallow copy
		# detaches them. The current dimension's edits are filled in by the worker.
		dimensions = dimension_states.duplicate()
		dimensions[dimension] = snapshot
	else: dimension_states[dimension] = snapshot
	var data: Dictionary={"version":SAVE_VERSION,"world_id":active_world_id,"name":world_name,"gamemode":gamemode,"seed":world.seed_value,"edits":snapshot.get("edits",[]),"growth":snapshot.growth,"stations":snapshot.stations,"block_states":snapshot.block_states,"adventure":snapshot.adventure,"inventory":inventory.slots.slice(0,Inventory.BASE_SLOTS),"pouches":inventory.pouch_slots,"grid":inventory.grid,"selected":inventory.selected,"cursor":hud.cursor,"position":[player.position.x,player.position.y,player.position.z],"spawn":[spawn_point.x,spawn_point.y,spawn_point.z],"homes":player_homes.duplicate(true),"gamerules":game_rules.duplicate(),"yaw":player.rotation.y,"pitch":player.camera.rotation.x,"health":player.health,"hunger":player.hunger,"nutrition":Hunger.snapshot(player),"ender_storage":ender_storage.duplicate(true),"effects":survival.effect_snapshot(),"armor":player.armor_slots,"offhand":player.offhand_slot,"time":day_time,"experience":experience,"journal":journal_step,"drops":snapshot.drops,"arrows":snapshot.arrows,"leads":snapshot.leads,"animals":snapshot.animals,"dimension":dimension,"dimensions":dimensions,"achievements":achievements.to_save(),"settings":{"distance":world.radius,"sensitivity":player.sensitivity,"audio":audio_enabled}}
	data["maps"] = maps.snapshot()
	if background:
		var keys: Array = snapshot.edit_keys
		var values: Array = snapshot.edit_values
		snapshot.erase("edit_keys"); snapshot.erase("edit_values")
		data.erase("edits"); data.erase("dimensions")
		var frozen: Dictionary = data.duplicate(true)
		frozen["dimensions"] = dimensions
		var current: String = dimension
		var status: Dictionary = {"error":"","path":path,"world_save":world_save,"id":active_world_id,"name":world_name,"seed":world.seed_value,"mode":gamemode,"day":day_number()}
		save_status = status
		save_task = WorkerThreadPool.add_task(func():
			var changes: Array = edit_records(keys,values)
			frozen["edits"] = changes
			frozen.dimensions[current]["edits"] = changes
			status.error = write_save(frozen,path),false,"Save world")
		return true
	var error: String = write_save(data,path)
	if not error.is_empty(): toast(error); return false
	if world_save: saves.update_metadata(active_world_id,world_name,world.seed_value,gamemode,day_number())
	return true

# Writes a save next to its previous version, keeping that as the backup. It
# touches only its own arguments, so the autosave worker can run it.
static func write_save(data: Dictionary, path: String) -> String:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return "Couldn't save the world: storage is unavailable."
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		var backup_error: Error=DirAccess.copy_absolute(path,path+".bak")
		if backup_error!=OK: return "Couldn't create the save backup."
	var error: Error=DirAccess.rename_absolute(path+".tmp",path)
	if error!=OK: return "Couldn't finish saving the world."
	return ""

static func edit_records(keys: Array, values: Array) -> Array:
	var changes: Array = []
	changes.resize(keys.size())
	for i in keys.size():
		var p: Vector3i = keys[i]
		changes[i] = [p.x,p.y,p.z,values[i]]
	return changes

# Waits for an autosave still being written, then reports its outcome.
func finish_background_save() -> void:
	if save_task < 0: return
	WorkerThreadPool.wait_for_task_completion(save_task)
	save_task = -1
	var status: Dictionary = save_status
	save_status = {}
	if not String(status.error).is_empty(): toast(status.error); return
	if status.world_save and not String(status.id).is_empty(): saves.update_metadata(status.id,status.name,status.seed,status.mode,status.day)

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

func delete_world(id: String) -> bool:
	if state != "title": toast("Return to the title screen before deleting a world."); return false
	finish_background_save()
	if not saves.delete_world(id): toast(saves.error_message); return false
	if active_world_id == id:
		active_world_id = ""; pending_save.clear()
	toast("World deleted.")
	return true

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

func _clean_station_storage() -> void:
	for station_state in world.stations.values():
		if station_state.get("kind","") == "shulker":
			station_state.slots = PortableStorage.clean_contents(station_state.get("slots",[]))
		else:
			for i in station_state.get("slots",[]).size(): station_state.slots[i] = Inventory.clean_slot(station_state.slots[i])

func load_world_data(data: Dictionary) -> void:
	identity.migrate_save(data)
	if int(data.get("version",2)) < 3:
		Netherite.migrate_wear(data)
		data["version"] = 3
	game_rules = GameRules.restore(data.get("gamerules",{}))
	pending_save=data
	active_world_id=String(data.get("world_id",active_world_id))
	world_name=String(data.get("name","New world"))
	gamemode=String(data.get("gamemode","survival"))
	if gamemode not in ["survival","creative"]: gamemode="survival"
	dimension = String(data.get("dimension","overworld"))
	if dimension not in ["overworld","nether","end"]: dimension = "overworld"
	dimension_states = data.get("dimensions",{}).duplicate(true)
	player_homes.clear()
	if data.get("homes") is Dictionary:
		for id in data.homes:
			var location: Dictionary = clean_home(data.homes[id])
			if id is String and not location.is_empty(): player_homes[id] = location
	# A legacy single home belongs only to the importing player.
	if not data.has("homes"):
		var legacy_home: Dictionary = clean_home(data.get("home",{}))
		if not legacy_home.is_empty(): player_homes[player_id] = legacy_home
	portal_cooldown = 4.0
	_clear_entities()
	_replace_world(int(data.seed))
	for entry in data.edits:
		if entry is Array and entry.size()==4: world.edits[Vector3i(int(entry[0]),int(entry[1]),int(entry[2]))]=int(entry[3])
	for entry in data.get("growth",[]): world.growth[Vector3i(int(entry[0]),int(entry[1]),int(entry[2]))]=float(entry[3])
	world.stations=data.get("stations",{}).duplicate(true)
	world.block_states=data.get("block_states",dimension_states.get(dimension,{}).get("block_states",{})).duplicate(true)
	world.adventure_state=data.get("adventure",dimension_states.get(dimension,{}).get("adventure",{})).duplicate(true)
	maps.restore(data.get("maps",{}))
	_clean_station_storage()
	inventory.restore(data.inventory,data.get("pouches",[]))
	for i in 9:
		inventory.grid[i]=Inventory.clean_slot(data.get("grid",[])[i] if i<data.get("grid",[]).size() else {})
	inventory.selected=clampi(int(data.get("selected",0)),0,8)
	hud.cursor = Inventory.clean_slot(data.get("cursor",{}))
	player.health=clampf(float(data.get("health",20)),0,20)
	player.hunger=clampf(float(data.get("hunger",20)),0,20)
	Hunger.restore(player,data.get("nutrition",{}))
	ender_storage = PortableStorage.new_ender_station(data.get("ender_storage",{}))
	survival.restore_effects(data.get("effects",{}))
	var saved_armor = data.get("armor",[])
	player.offhand_slot={"id":0,"count":0,"wear":0}
	var saved_offhand = data.get("offhand",null)
	if saved_offhand is Dictionary: player.offhand_slot = saved_offhand
	for i in 4: player.armor_slots[i]={"id":0,"count":0,"wear":0}
	if saved_armor is Array:
		for i in mini(4,saved_armor.size()):
			var piece: Dictionary=Inventory.clean_slot(saved_armor[i])
			if Nodes.is_armor(piece.id) and Nodes.armor_piece(piece.id)==i: player.armor_slots[i]=piece
	elif int(saved_armor)>0: player.armor_slots[1]={"id":Nodes.ARMOR,"count":1,"wear":0}
	player.breath=10
	achievements.from_save(data.get("achievements",{}))
	day_time=float(data.get("time",0.3))
	experience=float(data.get("experience",0))
	journal_step=int(data.get("journal",0))
	var preferences: Dictionary=data.get("settings",{})
	world.radius=clampi(int(preferences.get("distance",4)),2,6)
	player.sensitivity=clampf(float(preferences.get("sensitivity",0.0022)),0.0006,0.005)
	audio_enabled=bool(preferences.get("audio",true))
	var load_position: Array=data.get("spawn",data.position) if player.health<=0 and dimension == "overworld" else data.position
	world.target=Vector3(load_position[0],load_position[1],load_position[2])
	for p in world.edits:
		if Torches.is_torch(world.edits[p]) or world.edits[p] == Nodes.GLOWSTONE: add_torch(p)
	state="loading"
	world.active=false

func _exit_tree() -> void:
	finish_background_save()

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
		"zombie":1.1,"cow":0.85,"sheep":0.65,"pig":0.28,"chicken":0.42,"skeleton":0.5,"spider":0.55,"creeper":1.5,"explode":1.3,"mob_hurt":0.22,"arrow":0.2,"thud":0.18,
		# These were referenced by match branches below but had no entry here, so
		# their synthesized samples were never built and every play of them was a
		# silent no-op. A duration is what actually creates the sample.
		"totem":0.5,"wither":1.0,"wither_shoot":0.4,"crit":0.14,"piston_extend":0.35,"piston_retract":0.35,
		# These call sites existed without a length entry, so their samples were
		# never built and every play was a silent no-op.
		"drip":0.25,"fuse":1.6,"rocket":1.2,"splash":0.3,"portal":0.6,"guardian":0.5}
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
				"totem": value=sin(t*TAU*520.0)*0.35+sin(t*TAU*780.0)*0.2; envelope=minf(t*40.0,1.0)*pow(1.0-progress,1.5)
				"wither": value=sin(t*TAU*(80.0-t*40.0))*0.5+rumble*2.0; envelope=minf(t*8.0,1.0)*pow(1.0-progress,1.2)
				"wither_shoot": value=sin(t*TAU*300.0)*0.3+rumble*1.5; envelope=minf(t*30.0,1.0)*pow(1.0-progress,2.0)
				"arrow": value=bright*0.7; envelope=minf(t*60.0,1.0)*pow(1.0-progress,2.5)
				# `mcl_criticals_hit`: a short bright crack for a falling critical.
				"crit": value=bright*0.9+sin(t*TAU*1400.0)*0.25; envelope=minf(t*90.0,1.0)*pow(1.0-progress,2.0)
				# Piston extend and retract: a mechanical thunk with a small pitch
				# difference so the two directions are distinguishable.
				"piston_extend": value=sin(t*TAU*(150.0-t*60.0))*0.4+rumble*1.6; envelope=minf(t*40.0,1.0)*pow(1.0-progress,1.6)
				"piston_retract": value=sin(t*TAU*(190.0-t*80.0))*0.38+rumble*1.3; envelope=minf(t*40.0,1.0)*pow(1.0-progress,1.6)
				"drip": value=sin(t*TAU*(1200.0-t*900.0))*0.4; envelope=minf(t*80.0,1.0)*pow(1.0-progress,2.4)
				"fuse": value=filtered*0.5+sin(t*TAU*180.0)*0.15; envelope=minf(t*10.0,1.0)
				"rocket": value=filtered*0.6+sin(t*TAU*(420.0+t*260.0))*0.25; envelope=minf(t*8.0,1.0)*pow(1.0-progress,1.2)
				"splash": value=bright*0.8+sin(t*TAU*300.0)*0.2; envelope=minf(t*50.0,1.0)*pow(1.0-progress,1.6)
				"portal": value=sin(t*TAU*(200.0+t*120.0))*0.35+rumble*1.2; envelope=minf(t*6.0,1.0)*pow(1.0-progress,1.1)
				"guardian": value=sin(t*TAU*(90.0-t*30.0))*0.45+filtered*0.3; envelope=minf(t*14.0,1.0)*pow(1.0-progress,1.3)
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

func _warm_shaders() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or world.material == null: return
	shader_warmup = Node3D.new()
	shader_warmup.name = "ShaderWarmup"
	shader_warmup.position = Vector3(0,-0.4,-3)
	camera.add_child(shader_warmup)
	var add := func(mesh: Mesh, material: Material, offset: Vector3) -> void:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh; instance.material_override = material; instance.position = offset; instance.scale = Vector3.ONE*0.3
		shader_warmup.add_child(instance)
	# Terrain and translucent surfaces, in the map block vertex format.
	var padded := PackedInt32Array(); padded.resize(5832)
	padded[1+18+324] = Nodes.WATER; padded[2+18+324] = Nodes.STONE
	var surfaces: Array = BlockMesher.build(padded,true)
	for i in 2:
		if surfaces[i].is_empty(): continue
		var block := ArrayMesh.new(); block.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surfaces[i])
		add.call(block,world.material if i == 0 else world.water_material,Vector3(-1.2,0,0))
	# Dropped nodes and items, and creature-style textured cuboids.
	add.call(node_mesh(Nodes.STONE),node_material,Vector3(-0.6,0,0))
	add.call(ItemArt.mesh(Nodes.STICK),ItemArt.material(Nodes.STICK),Vector3(0,0,0))
	if warm_materials.is_empty():
		var skin := StandardMaterial3D.new(); skin.albedo_texture = CreatureArt.texture("fur",Color.WHITE); skin.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		var glow := skin.duplicate(); glow.emission_enabled = true; glow.emission = Color.WHITE
		var clear := skin.duplicate(); clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var overlay := StandardMaterial3D.new(); overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var plain := StandardMaterial3D.new(); plain.albedo_color = Color.WHITE
		warm_materials = [skin,glow,clear,overlay,plain]
	for index in warm_materials.size():
		add.call(CreatureArt.cuboid(Vector3.ONE*0.5),warm_materials[index],Vector3(0.6+0.6*(index/3),0.4*(index%3)-0.4,0))
	# Particle bursts render through instanced meshes.
	var particles := CPUParticles3D.new()
	particles.amount = 1; particles.lifetime = 5.0; particles.mesh = _particle_mesh(Nodes.STONE)
	shader_warmup.add_child(particles)
	var label := Label3D.new(); label.text = "Voxey"; label.position = Vector3(0,0.5,0)
	shader_warmup.add_child(label)

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
	return {"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"fps":Engine.get_frames_per_second(),"map_blocks":world.blocks.size(),"columns":world.columns.size(),"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),"generation_jobs":world.jobs.size(),"remesh_jobs":world.remesh_jobs.size()}

func _migrate_legacy_save() -> void:
	var marker: String = saves.root_path.path_join("legacy_imported.json")
	if not FileAccess.file_exists(LEGACY_SAVE_PATH): return
	var imported: Dictionary = saves.read_json(marker)
	if imported.get("deleted",false): return
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
	if mode=="creative": player.health=20; Hunger.reset(player); player.breath=10
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
		"help": response="/gamemode survival | creative  ·  /time day | night  ·  /seed  ·  /save  ·  /spawnpoint\n/give <item> [count]  ·  /spawn <creature>  ·  /tp <x> <y> <z>  ·  /heal  ·  /killmobs\n/dimension overworld | nether | end  ·  /xp <points>  ·  /locate village | stronghold | fortress | bastion | end_city\n/sethome  ·  /home  ·  /weather clear | rain | thunder\n/gamerule keepInventory [true | false]\nCreative: F or double Space toggles flight. Space rises; Shift descends."
		"gamerule": response = GameRules.command(self,parts)
		"seed": response="World seed: "+str(world.seed_value)
		"save": response="World saved to "+saves.save_path(active_world_id) if save_game() else "The world could not be saved."
		"weather":
			if parts.size() != 2 or parts[1] not in ["clear","rain","thunder"]: response = "Usage: /weather clear | rain | thunder"
			else:
				Weather.change(world,parts[1])
				response = "Weather set to "+parts[1]+"."
		"time":
			if parts.size()!=2 or parts[1] not in ["day","night"]: response="Usage: /time day | night"
			else:
				day_time=floorf(day_time)+(0.3 if parts[1]=="day" else 0.7)
				response="Time set to "+parts[1]+"."
		"sethome":
			if parts.size() != 1: response = "Usage: /sethome"
			else:
				player_homes[player_id] = {"dimension":dimension,"position":[player.position.x,player.position.y,player.position.z],"yaw":player.rotation.y,"pitch":player.camera.rotation.x}
				response = "Home set in "+dimension.capitalize()+" at "+str(player.position.round())+". Use /home to return."
				save_game()
		"home":
			if parts.size() != 1: response = "Usage: /home"
			else: response = teleport_home()
		"spawnpoint":
			if dimension != "overworld": response="Set your spawn in the Overworld."
			else: spawn_point=player.position; response="Spawn point set."
		"locate":
			if parts.size() < 2: response = "Usage: /locate village | stronghold | fortress | bastion | end_city"
			elif parts[1] == "village": response = "Village: "+str(VillageGenerator.nearest(TerrainGenerator.new(world.seed_value),player.position).center+Vector3i(4,1,4))+" in the Overworld."
			elif parts[1] == "stronghold": response = "Stronghold: "+str(WorldStructures.nearest_stronghold(world.seed_value,player.position))
			elif parts[1] == "bastion":
				var bastion: Dictionary = Bastions.nearest(TerrainGenerator.new(world.seed_value,"nether"),player.position)
				response = "Nether bastion: "+str(bastion.center) if not bastion.is_empty() else "No bastion found inside the world boundary."
			elif parts[1] == "fortress": response = "Nether fortress: "+str(Vector3i(roundi((player.position.x-60)/160)*160+60,29,roundi((player.position.z-60)/160)*160+60))
			elif parts[1] == "end_city": response = "End city: (288, 43, 0) in the End highlands."
			else: response = "Unknown structure."
		"dimension":
			if parts.size() != 2 or parts[1] not in ["overworld","nether","end"]: response="Usage: /dimension overworld | nether | end"
			else: travel_dimension(parts[1]); response="Entering "+parts[1].capitalize()+"."
		"xp":
			if parts.size() != 2 or not parts[1].is_valid_int(): response="Usage: /xp <points>"
			else: experience=maxf(0,experience+int(parts[1])); response="XP level %d" % xp_level()
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
			elif not WorldBounds.contains(Vector3(float(parts[1]),float(parts[2]),float(parts[3])),dimension): response="That position is outside this dimension’s world bounds."
			else:
				teleport(Vector3(float(parts[1]),float(parts[2]),float(parts[3])))
				response="Teleported to %s %s %s." % [parts[1],parts[2],parts[3]]
		"heal": player.health=20; Hunger.reset(player); player.breath=10; response="Health and hunger restored."
		"killmobs":
			var removed: int=creatures.get_child_count()
			for mob in creatures.get_children(): Farming.forget(mob); mob.queue_free()
			response="Removed %d creatures." % removed
		_: response="Unknown command. Type /help for available commands."
	console_messages.append("> "+command)
	console_messages.append(response)
	while console_messages.size()>60: console_messages.pop_front()
	return response

func teleport(destination: Vector3) -> void:
	boats.dismount(false)
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

# `deferred` leaves the edit list to the caller as `edit_keys`/`edit_values`;
# the autosave converts them on its worker instead of the main thread.
func dimension_snapshot(deferred: bool = false) -> Dictionary:
	boats.snapshot()
	rails.snapshot()
	Farming.snapshot(self)
	for mob in creatures.get_children():
		if mob is NetherResident and not mob.is_queued_for_deletion(): mob.store_record()
	villages.snapshot()
	AlchemyWorld.snapshot(self)
	Golems.snapshot(self)
	for mob in creatures.get_children():
		if mob.kind == "ender_dragon" and not mob.is_queued_for_deletion():
			world.adventure_state["dragon_health"] = mob.health
			world.adventure_state["dragon_phase"] = mob.life
	var growing: Array = []
	for p in world.growth: growing.append([p.x,p.y,p.z,world.growth[p]])
	var dropped: Array = []
	for drop in drops.get_children():
		if not drop.is_queued_for_deletion(): dropped.append({"position":[drop.position.x,drop.position.y,drop.position.z],"id":drop.item_id,"count":drop.amount,"wear":drop.wear,"data":drop.data.duplicate(true),"age":drop.age,"pickup_delay":drop.pickup_delay})
	var arrows: Array = []
	for entity in entities.get_children():
		if entity is TridentProjectile and entity.consumed and not entity.is_queued_for_deletion(): dropped.append({"position":[entity.position.x,entity.position.y,entity.position.z],"id":entity.stack.id,"count":1,"wear":entity.stack.wear,"data":entity.stack.get("data",{}).duplicate(true),"age":0})
		if entity is Arrow and entity.stuck and not entity.is_queued_for_deletion():
			arrows.append({"position":[entity.position.x,entity.position.y,entity.position.z],"rotation":[entity.rotation.x,entity.rotation.y,entity.rotation.z],"life":entity.life,"id":entity.item_id,"recoverable":entity.recoverable})
	var snapshot: Dictionary = {"animals":survival.animal_snapshot(),"leads":leads.snapshot(),"growth":growing,"stations":world.stations.duplicate(true),"block_states":world.block_states.duplicate(true),"adventure":world.adventure_state.duplicate(true),"drops":dropped,"arrows":arrows,"position":[player.position.x,player.position.y,player.position.z]}
	if deferred:
		snapshot["edit_keys"] = world.edits.keys()
		snapshot["edit_values"] = world.edits.values()
	else: snapshot["edits"] = edit_records(world.edits.keys(),world.edits.values())
	return snapshot

func travel_dimension(destination: String, respawning: bool = false) -> void:
	var retained_effects: Dictionary = survival.effect_snapshot()
	if destination == dimension or destination not in ["overworld","nether","end"]: return
	boats.dismount(false)
	hud.return_cursor()
	dimension_states[dimension] = dimension_snapshot()
	var arrival: Vector3 = player.position*Vector3(0.125,1,0.125) if destination == "nether" else player.position*Vector3(8,1,8)
	var end_travel: bool = destination == "end" or dimension == "end"
	if destination == "end": arrival = Vector3(51.5,45.01,0.5)
	if respawning or (end_travel and destination == "overworld"): arrival = spawn_point
	arrival = WorldBounds.clamp_arrival(arrival,destination)
	var seed_number: int = world.seed_value
	var render_radius: int = world.radius
	dimension = destination
	# The source awards entering each realm, and its "The End?" is the end portal
	# specifically rather than an end gateway.
	if not respawning and gamemode != "creative":
		if destination == "nether": achievements.award("the_nether"); achievements.award("we_need_to_go_deeper")
		elif destination == "end": achievements.award("the_end")
	_clear_entities()
	_replace_world(seed_number)
	world.radius = render_radius
	var saved: Dictionary = dimension_states.get(destination,{})
	for entry in saved.get("edits",[]): world.edits[Vector3i(entry[0],entry[1],entry[2])] = int(entry[3])
	for entry in saved.get("growth",[]): world.growth[Vector3i(entry[0],entry[1],entry[2])] = float(entry[3])
	world.stations = saved.get("stations",{}).duplicate(true)
	_clean_station_storage()
	world.block_states = saved.get("block_states",{}).duplicate(true)
	world.adventure_state = saved.get("adventure",{}).duplicate(true)
	arrival.y = world.generator.terrain_height(int(arrival.x),int(arrival.z))+1.01 if not respawning and not end_travel else arrival.y
	survival.restore_effects(retained_effects)
	pending_save = {"position":[arrival.x,arrival.y,arrival.z],"spawn":[spawn_point.x,spawn_point.y,spawn_point.z],"yaw":player.rotation.y,"pitch":player.camera.rotation.x,"animals":saved.get("animals",[]),"leads":saved.get("leads",[]),"drops":saved.get("drops",[]),"arrows":saved.get("arrows",[]),"arrival_portal":not respawning and not end_travel,"arrival_end":destination == "end"}
	world.target = arrival
	player.velocity = Vector3.ZERO
	player.gliding = false; player.levitation = 0
	portal_time = 0.0
	portal_cooldown = 4.0
	state = "loading"
	hud.show_loading()

func _arrival_set_node(p: Vector3i, id: int) -> void:
	# Returning to a dimension must not erase recovery chests or stored items.
	var existing: int = world.node_at(p)
	if existing not in RedstoneCircuit.CONTAINERS and not PortableStorage.is_storage(existing) and not Campfires.is_campfire(existing) and existing not in [VillageContent.COMPOSTER,VillageContent.CAULDRON]: world.set_node(p,id)

func _arrival_portal() -> void:
	# Reuse a nearby portal so returning travel does not carve up existing builds.
	var closest := Vector3.INF
	var distance: float = 32.0
	for p in world.edits:
		if world.edits[p] != Nodes.NETHER_PORTAL or not world.loaded_at(Vector3(p)): continue
		if world.node_at(p+Vector3i.DOWN) != Nodes.OBSIDIAN: continue
		var point: Vector3 = Vector3(p)+Vector3(0.5,0.01,0.5)
		if point.distance_to(player.position) < distance:
			distance = point.distance_to(player.position); closest = point
	if not is_inf(closest.x): player.position = closest; return
	var base := Vector3i(floori(player.position.x),clampi(floori(player.position.y),15,42),floori(player.position.z))
	for x in range(-2,4):
		for z in range(-2,3):
			_arrival_set_node(base+Vector3i(x,-1,z),Nodes.OBSIDIAN)
			for y in range(0,4): _arrival_set_node(base+Vector3i(x,y,z),Nodes.AIR)
	for x in range(-1,3):
		for y in range(-1,4):
			_arrival_set_node(base+Vector3i(x,y,0),Nodes.OBSIDIAN if x in [-1,2] or y in [-1,3] else Nodes.AIR)
	world.ignite_portal(base)
	player.position = Vector3(base)+Vector3(0.5,0.01,0.5)
	if world.intersects(player.position): player.position = _safe_spawn(player.position)

func xp_level() -> int:
	var level: int = 0
	var remaining: float = experience
	while remaining >= 7+level*2:
		remaining -= 7+level*2
		level += 1
	return level

func xp_progress() -> float:
	var level: int = xp_level()
	return (experience-float(level*level+6*level))/(7+2*level)

func bookshelf_power(p: Vector3i) -> int:
	var count: int = 0
	for x in range(-2,3):
		for z in range(-2,3):
			if maxi(absi(x),absi(z)) != 2: continue
			for y in 2:
				var gap := Vector3i(roundi(x*0.5),y,roundi(z*0.5))
				if world.node_at(p+Vector3i(x,y,z)) == Nodes.BOOKSHELF and world.node_at(p+gap) == Nodes.AIR: count += 1
	return mini(15,count)

func enchant_item(index: int, tier: int, p: Vector3i, selected_enchantment: String = "") -> bool:
	if index < 0 or index >= inventory.slots.size() or tier < 1 or tier > 3 or world.node_at(p) != Nodes.ENCHANTING_TABLE: return false
	var slot: Dictionary = inventory.slots[index]
	var options: Array = Enchantments.choices(slot.id,true)
	if options.is_empty(): return false
	var kind: String = selected_enchantment
	if kind.is_empty():
		kind = "Sharpness" if Nodes.tool_kind(slot.id) == 3 else ("Efficiency" if Nodes.is_tool_id(slot.id) else ("Protection" if Nodes.is_armor(slot.id) else ("Power" if slot.id == Nodes.BOW else options[0])))
	if not options.has(kind): return false
	if not slot.get("data",{}).get("enchantments",{}).is_empty(): toast("This item is already enchanted."); return false
	var shelves: int = bookshelf_power(p)
	var required: int = [1,10,30][tier-1]
	if shelves < [0,5,15][tier-1]: toast("More bookshelves are needed, with an air gap around the table."); return false
	if gamemode != "creative":
		if xp_level() < required or inventory.count_item(Nodes.LAPIS) < tier: toast("You need level %d and %d lapis lazuli." % [required,tier]); return false
		if slot.id == Nodes.BOOK and slot.count > 1:
			var trial := Inventory.new(); trial.slots = inventory.slots.duplicate(true)
			trial.remove_item(Nodes.LAPIS,tier)
			trial.slots[index].id = VillageContent.ENCHANTED_BOOK; trial.slots[index].count = 1
			if trial.add_item(Nodes.BOOK,slot.count-1) > 0: toast("Make room for the enchanted book first."); return false
		var level: int = xp_level()
		inventory.remove_item(Nodes.LAPIS,tier)
		experience -= float(level*level+6*level-(level-tier)*(level-tier)-6*(level-tier))
	var enchantments: Dictionary = {kind:mini(tier,Enchantments.DATA[kind].max)}
	if Enchantments.accepts(slot.id,"Unbreaking") and kind != "Unbreaking": enchantments["Unbreaking"] = tier
	if slot.id == Nodes.BOOK:
		if slot.count > 1:
			var plain_count: int = slot.count-1
			slot.id = VillageContent.ENCHANTED_BOOK; slot.count = 1
			var remaining: int = inventory.add_item(Nodes.BOOK,plain_count)
			# Split the enchanted book from the plain stack, dropping overflow.
			if remaining > 0: spawn_drop(player.position+Vector3.UP,Nodes.BOOK,remaining)
		slot.id = VillageContent.ENCHANTED_BOOK; slot.count = 1
	if not slot.has("data"): slot.data = {}
	slot.data.enchantments = enchantments
	inventory.changed.emit()
	sound("craft")
	achievements.award("enchanter")
	toast("%s %d · Unbreaking %d" % [kind,tier,tier])
	return true

func open_enchanting(p: Vector3i) -> void:
	state = "enchanting"; world.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(controls): controls.hide_all()
	hud.show_enchanting(p)

func open_book() -> void:
	if inventory.held().id not in [Nodes.WRITABLE_BOOK,Nodes.WRITTEN_BOOK]: return
	state = "book"; world.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(controls): controls.hide_all()
	hud.show_book(inventory.selected)

# All manual drops use the same metadata-preserving transaction and throw.
func drop_stack(slot: Dictionary, amount: int = 1) -> bool:
	if slot.get("id",0) == 0 or amount <= 0: return false
	var count: int = mini(amount,int(slot.count))
	var forward: Vector3 = -player.camera.global_basis.z
	var origin: Vector3 = player.position+Vector3.UP*1.2
	var ahead: Vector3 = origin+forward*0.4
	if not world.intersects(ahead,0.1,0.2): origin = ahead
	var drop := spawn_drop(origin,int(slot.id),count,int(slot.wear),slot.get("data",{}))
	if drop == null: return false
	drop.velocity = forward*5.0+Vector3.UP*1.5
	drop.pickup_delay = 1.5
	slot.count -= count
	if slot.count == 0: slot.clear(); slot.merge({"id":0,"count":0,"wear":0})
	inventory.changed.emit()
	return true

func close_inventory() -> void:
	TrappedChests.closed(self)
	if hud.cursor.id != 0 and hud.pointer_outside_inventory(): hud.drop_cursor(false)
	resume()

func _input(event: InputEvent) -> void:
	if state == "sign" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		Signs.cancel(self); get_viewport().set_input_as_handled(); return
	if state == "title" and hud.screen == "delete_world" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		hud.show_worlds(); get_viewport().set_input_as_handled(); return
	if state != "inventory": return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			close_inventory()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_Q:
			var focused: Control = get_viewport().gui_get_focus_owner()
			if focused is LineEdit or focused is TextEdit: return
			hud.drop_hovered_one()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and hud.cursor.id != 0 and hud.pointer_outside_inventory():
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			hud.drop_cursor(event.button_index == MOUSE_BUTTON_RIGHT)
			get_viewport().set_input_as_handled()

static func clean_home(value: Variant) -> Dictionary:
	return WorldBounds.clean_location(value)

func teleport_home() -> String:
	var home_location: Dictionary = player_homes.get(player_id,{})
	if home_location.is_empty(): return "No home set yet. Stand where you want to live and use /sethome."
	var destination: Vector3 = VillageLife.vec(home_location.position)
	if home_location.dimension != dimension:
		travel_dimension(home_location.dimension)
		pending_save.position = home_location.position.duplicate()
		pending_save.arrival_portal = false; pending_save.arrival_end = false
		pending_save.yaw = home_location.yaw; pending_save.pitch = home_location.pitch
		world.target = destination
	else:
		teleport(destination)
		if state == "loading": pending_save.yaw = home_location.yaw; pending_save.pitch = home_location.pitch
		else: player.rotation.y = home_location.yaw; player.camera.rotation.x = home_location.pitch
	portal_cooldown = 4.0
	return "Returning home."

class_name VoxeyPlayer
extends Node3D

var game: Node3D
var camera: Camera3D
var velocity := Vector3.ZERO
var grounded: bool = false
var health: float = 20.0
var hunger: float = 20.0
var saturation: float = Hunger.INITIAL_SATURATION
var exhaustion: float = 0.0
var food_timer: float = 0.0
var sprint_distance: float = 0.0
# `mcl_criticals` reads the sprint state at attack time, and `mcl_sprint` in the
# source is a standing property rather than a per-move local.
var sprinting: bool = false
var swim_distance: float = 0.0
var breath: float = 10.0
var armor_slots: Array = []
# Whether the player is sneaking, which several source rules consult.
var crouching: bool = false
# Mineclonia HUD/mcl_offhand: a second hand, separate from the hotbar. Shields,
# totems, maps and placeable items read it when the main hand cannot serve.
var offhand_slot: Dictionary = {}
var sensitivity: float = 0.0022
var target: Dictionary = {}
var mining: float = 0.0
var mining_pos := Vector3i(99999,99999,99999)
var mining_tool: int = -1
var selection_cube: Mesh
var cracks_cube: Mesh
var selection: MeshInstance3D
var cracks: MeshInstance3D
var crack_material: StandardMaterial3D
var crack_textures: Array = []
var crack_stage: int = -1
var dig_timer: float = 0.0
var use_cooldown: float = 0.0
var use_latched: bool = false
var eating: Dictionary = {}
var damage_cooldown: float = 0.0
# The void's own timer. The source damages in discrete ticks rather than per frame,
# so falling in costs a fixed amount per interval until the player climbs out.
var void_clock: float = 0.0
# Source `VOID_DAMAGE` / `VOID_DAMAGE_FREQ`: four health every half second.
const VOID_DAMAGE = 4.0
const VOID_INTERVAL = 0.5
var riptide_time: float = 0.0
var survival_timer: float = 0.0
var walked: float = 0.0
var bob: float = 0.0
var hand: Node3D
var hand_id: int = -1
var swing: float = 0.0
var underwater: bool = false
var flying: bool = false
var gliding: bool = false
# Firework-rocket boost remaining, in seconds (source `elytra.rocketing`).
var rocketing: float = 0.0
var scoping: bool = false
var spyglass_held: bool = false
var spyglass_blocked: bool = false
var levitation: float = 0
var flight_wear: float = 0

func _init() -> void:
	for i in 4: armor_slots.append({"id":0,"count":0,"wear":0})
	offhand_slot = {"id":0,"count":0,"wear":0}

func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position.y = 1.62
	camera.fov = 78
	camera.near = 0.04
	camera.far = 180
	add_child(camera)
	hand = Node3D.new()
	camera.add_child(hand)
	hand.position = Vector3(0.42,-0.36,-0.65)
	selection = MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for axis in 3:
		for a in 2:
			for b in 2:
				var p := Vector3(-0.003,-0.003,-0.003)
				p[(axis+1)%3] += a*1.006
				p[(axis+2)%3] += b*1.006
				var q: Vector3 = p
				q[axis] += 1.006
				mesh.surface_add_vertex(p)
				mesh.surface_add_vertex(q)
	mesh.surface_end()
	selection.mesh = mesh
	selection_cube = mesh
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.08,0.13,0.10,0.65)
	selection.material_override = line_mat
	game.add_child.call_deferred(selection)
	cracks = MeshInstance3D.new()
	cracks.mesh = Art.crack_mesh()
	cracks_cube = cracks.mesh
	crack_material = StandardMaterial3D.new()
	crack_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crack_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crack_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cracks.material_override = crack_material
	cracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child.call_deferred(cracks)
	for i in 9: crack_textures.append(Art.crack_texture(i))

func look(relative: Vector2) -> void:
	rotation.y -= relative.x * sensitivity
	camera.rotation.x = clampf(camera.rotation.x-relative.y*sensitivity,-1.54,1.54)

# Total defence points across every worn piece. Each point absorbs 4% of damage.
func armor_points() -> int:
	var total: int = 0
	for slot in armor_slots: total += Nodes.armor_points(slot.id)
	return total

func armor_toughness() -> float:
	var total: float = 0
	for slot in armor_slots: total += Nodes.armor_toughness(slot.id)
	return total

func _physics_process(delta: float) -> void:
	if game == null or not game.playing(): return
	# The void is *below* the loaded world, so this has to come before the guard
	# that bails out over unloaded terrain - otherwise the branch below never runs.
	#
	# The source deals the void's rate rather than a killing blow: four health every
	# half second (`VOID_DAMAGE`/`VOID_DAMAGE_FREQ` in `mcl_void_damage`), which
	# gives a player who falls in a couple of seconds to climb back out.
	if position.y < game.world.generator.min_y()-5:
		void_clock += delta
		if void_clock >= VOID_INTERVAL:
			void_clock = 0.0
			hurt(VOID_DAMAGE,true,Vector3.INF,"void")
		return
	void_clock = 0.0
	if not game.world.loaded_at(position): return
	damage_cooldown = maxf(0,damage_cooldown-delta)
	levitation = maxf(0,levitation-delta)
	use_cooldown = maxf(0,use_cooldown-delta)
	var pad: TouchControls = game.controls if game.touch else null
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): direction.z -= 1
	if Input.is_physical_key_pressed(KEY_S): direction.z += 1
	if Input.is_physical_key_pressed(KEY_A): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D): direction.x += 1
	if pad != null and pad.stick.length() > 0.12: direction += Vector3(pad.stick.x,0,pad.stick.y)
	Hunger.update(self,delta)
	# Source `register_globalstep_slow`: a magma block burns whoever stands on it.
	Magma.step(game)
	# And powder snow freezes whoever is inside it, which the source runs on the
	# same slow step.
	var freeze: float = PowderSnow.step(game.world,self)
	if freeze > 0.0: hurt(freeze,true,Vector3.INF,"freeze")
	if game.boats.ridden(): game.boats.drive(delta,direction); return
	if is_instance_valid(game.survival.mount): game.survival.ride_step(delta,direction); return
	var crouch: bool = Input.is_physical_key_pressed(KEY_CTRL) or (pad != null and pad.sneak_held)
	# Stored so other systems can read the stance, which the source's `sneak` control does.
	crouching = crouch
	# Keep swimming until the feet clear the real liquid surface. A waist-height
	# sample used to switch to land gravity while still half a block underwater.
	var wet: bool = Fluids.contains(game.world,position+Vector3.UP*0.05,Nodes.WATER)
	var descend: bool = wet and (Input.is_physical_key_pressed(KEY_SHIFT) or crouch)
	var sprint: bool = Input.is_physical_key_pressed(KEY_SHIFT) and not wet and hunger > 5 and not crouch
	var speed: float = 7.0 if sprint else (2.1 if crouch else 4.5)
	if not eating.is_empty(): speed = minf(speed,2.1)
	var moving: bool = direction.length() > 0.1
	# `mcl_sprint` in the source is a standing property, and `mcl_criticals` reads it
	# at attack time: sprinting is a held Shift with real movement intent.
	sprinting = sprint and moving
	camera.fov = Spyglass.FOV if scoping else lerpf(camera.fov,86.0 if sprint and moving and not flying else 78.0,delta*7)
	if game.gamemode=="creative" and flying:
		direction=basis*direction.normalized()
		if Input.is_physical_key_pressed(KEY_SPACE) or (pad != null and pad.jump_held): direction.y+=1
		if Input.is_physical_key_pressed(KEY_SHIFT) or (pad != null and pad.sneak_held): direction.y-=1
		velocity=direction*12.0
		_move(velocity*delta,false)
		camera.position.y=1.62
		underwater=Fluids.contains(game.world,camera.global_position,Nodes.WATER)
		return
	underwater = Fluids.contains(game.world,camera.global_position,Nodes.WATER)
	speed *= PotionEffects.speed(self)
	if wet: speed *= lerpf(0.55,1.0,minf(3,Enchantments.worn(self,"Depth Strider"))/3.0)
	if game.world.node_at(Vector3i((position-Vector3.UP*0.1).floor())) == Nodes.SOUL_SAND: speed *= 1.0+Enchantments.worn(self,"Soul Speed")*0.12 if Enchantments.worn(self,"Soul Speed") > 0 else 0.5
	# Ladders: holding forward (or jump) against a ladder climbs; sneaking holds still.
	var body_cell: Vector3i = Vector3i(position.floor())
	var on_ladder: bool = game.world.node_at(body_cell) == Nodes.LADDER or game.world.node_at(body_cell+Vector3i.UP) == Nodes.LADDER or Scaffolding.climbable(game.world,body_cell) or Scaffolding.climbable(game.world,body_cell+Vector3i.UP) or Trapdoors.climbable(game.world,body_cell) or Trapdoors.climbable(game.world,body_cell+Vector3i.UP) or LushCaves.climbable(game.world,body_cell) or LushCaves.climbable(game.world,body_cell+Vector3i.UP) or CrimsonPlants.is_vine(game.world.node_at(body_cell)) or CrimsonPlants.is_vine(game.world.node_at(body_cell+Vector3i.UP))
	direction = basis * direction.normalized()
	riptide_time = maxf(0,riptide_time-delta)
	if not gliding and riptide_time <= 0:
		var acceleration: float = DenseMaterials.acceleration(game.world.node_at(Vector3i((position-Vector3.UP*0.1).floor())),direction.length_squared() == 0) if grounded and not wet and not on_ladder else 35.0
		velocity.x = move_toward(velocity.x,direction.x*speed,delta*acceleration)
		velocity.z = move_toward(velocity.z,direction.z*speed,delta*acceleration)
	if levitation > 0:
		velocity.y = move_toward(velocity.y,3.0,delta*10)
	elif on_ladder:
		velocity.y = 0.0
		var climb: float = 0.0
		if Input.is_physical_key_pressed(KEY_SPACE) or (pad != null and pad.jump_held) or (direction.length() > 0.2 and camera.rotation.x > -0.7):
			climb = 3.6
		elif pad != null and pad.sneak_held:
			climb = 0.0
		elif crouch:
			climb = 0.0
		elif direction.length() > 0.2:
			climb = -3.2 if camera.rotation.x < -0.7 else 0.0
		velocity.y = climb
	elif wet:
		_swim(delta,Input.is_physical_key_pressed(KEY_SPACE) or (pad != null and pad.jump_held),descend,direction)
	else:
		if not gliding:
			velocity.y -= 24.0*delta
			velocity.y = maxf(velocity.y,-1.6 if PotionEffects.level(self,"slow_falling") else -45.0)
		if Input.is_physical_key_pressed(KEY_SPACE) or (pad != null and pad.jump_held):
			if grounded:
				velocity.y = 8.2+PotionEffects.level(self,"leaping")*2.6
				grounded = false
				Hunger.exhaust(self,Hunger.SPRINT_JUMP if sprint else Hunger.JUMP)
	var glide_input: bool = Input.is_physical_key_pressed(KEY_SPACE) or (pad != null and pad.jump_held)
	gliding = update_glide(delta,glide_input,wet or on_ladder)
	if gliding: game.achievements.award("sky_is_the_limit")
	var old_pos: Vector3 = position
	_move(velocity*delta,crouch,on_ladder)
	var distance: float = Vector2(position.x-old_pos.x,position.z-old_pos.z).length()
	Hunger.move(self,position-old_pos,sprint,wet)
	walked += distance
	if distance > 0.001 and grounded:
		bob += distance*2.5
		if walked > 2.4:
			walked = 0
			game.sound("step")
	camera.position.y = lerpf(camera.position.y,(1.35 if crouch else 1.62)+sin(bob*2)*0.025 if grounded else 1.62,delta*12)
	survival_timer += delta
	if game.gamemode=="creative":
		health=20; hunger=20; breath=10
		return
	if survival_timer >= 1.0:
		survival_timer = 0.0
		if underwater and not game.survival.effects.has("water_breathing"):
			breath = maxf(0,breath-1.0/(1+Enchantments.worn(self,"Respiration")))
			if breath <= 0: hurt(2,true)
		else: breath = minf(10,breath+3)
		var feet: Vector3i = Vector3i(position.floor())
		if not game.survival.effects.has("fire_resistance") and (Fluids.contains(game.world,position+Vector3.UP*0.1,Nodes.LAVA) or Fluids.contains(game.world,position+Vector3.UP,Nodes.LAVA)): hurt(4,true,Vector3.INF,"fire")
		for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
			if game.world.node_at(feet+d) == Nodes.CACTUS: hurt(1)
		if Fire.is_fire(game.world.node_at(feet)) or Fire.is_fire(game.world.node_at(feet+Vector3i.UP)):
			if not game.survival.effects.has("fire_resistance"): PotionEffects.apply(self,"burning",8); hurt(1,true,Vector3.INF,"fire")

func _swim(delta: float, rise: bool, dive: bool, direction: Vector3) -> void:
	velocity.y = maxf(-2.2,velocity.y-3.2*delta)
	# Descend wins if both controls are held, so buoyancy and ascent never fight it.
	if dive:
		velocity.y = -2.4
	elif rise:
		# Preserve a shore-jump impulse across the last few submerged frames.
		velocity.y = maxf(velocity.y,4.6)
	elif underwater and not grounded:
		velocity.y = maxf(velocity.y,0.4)
	if dive or not rise or underwater or direction.length_squared() < 0.01: return
	var horizontal: Vector3 = Vector3(direction.x,0,direction.z).normalized()
	var ahead: Vector3 = position+horizontal*0.6
	# A bank blocks horizontal movement at foot level. Test the space ABOVE
	# that bank, instead of demanding that the bank itself be passable.
	if not game.world.intersects(ahead): return
	var cell := Vector3i((position+Vector3.UP*0.05).floor())
	var surface: float = float(cell.y)
	for height in 3:
		var p: Vector3i = cell+Vector3i.UP*height
		if not Fluids.contains(game.world,Vector3(p)+Vector3(0.5,0.01,0.5),Nodes.WATER): break
		var id: int = game.world.node_at(p)
		surface = p.y+(1.0 if id == VillageContent.KELP_PLANT else Fluids.height(id))
	if surface-position.y > 0.65: return
	var exit: Vector3 = Vector3(ahead.x,surface+1.01,ahead.z)
	# Full player-sized probes keep low ceilings and taller walls impassable;
	# the normal swept collision mover still resolves the jump itself.
	if game.world.intersects(exit) or game.world.intersects(Vector3(position.x,exit.y,position.z)): return
	velocity.y = maxf(velocity.y,8.2)

func _move(motion: Vector3, crouch: bool, on_ladder: bool = false) -> void:
	var steps: int = maxi(1,ceili(motion.length()/0.2))
	var part: Vector3 = motion/steps
	grounded = false
	for step in steps:
		for axis in [0,2,1]:
			if absf(part[axis]) < 0.000001: continue
			var next: Vector3 = position
			next[axis] += part[axis]
			if crouch and axis != 1 and game.world.intersects(position-Vector3.UP*0.06) and not game.world.intersects(next-Vector3.UP*0.1): continue
			if not game.world.intersects(next): position = next; continue
			# A half-block rise is walkable; full-height obstacles still need a jump.
			if axis != 1 and not crouch and not flying and velocity.y <= 0 and game.world.intersects(position-Vector3.UP*0.06):
				var raised: Vector3 = next+Vector3.UP*0.501
				if not game.world.intersects(position+Vector3.UP*0.501) and not game.world.intersects(raised):
					var low_y: float = next.y; var high_y: float = raised.y
					for iteration in 10:
						var mid_y: float = (low_y+high_y)*0.5
						if game.world.intersects(Vector3(next.x,mid_y,next.z)): low_y = mid_y
						else: high_y = mid_y
					next.y = high_y; position = next; grounded = true; continue
			# Resolve to the surface without tunnelling, even at low frame rates.
			var low: float = 0.0
			var high: float = 1.0
			for iteration in 8:
				var mid: float = (low+high)*0.5
				var probe: Vector3 = position
				probe[axis] += part[axis]*mid
				if game.world.intersects(probe): high = mid
				else: low = mid
			position[axis] += part[axis]*low
			if axis == 1 and part.y < 0:
				grounded = true
				if velocity.y < -12 and not on_ladder:
					hurt(floorf((-velocity.y-11)*0.9)*Beehives.fall_multiplier(game.world.node_at(Vector3i((position-Vector3.UP*0.035).floor()))),true,Vector3.INF,"fall")
					game.achievements.award("sniper_hurt")
			velocity[axis] = 0.0
			part[axis] = 0.0
	if game.world.intersects(position-Vector3.UP*0.035): grounded = true

func _process(delta: float) -> void:
	if game == null: return
	if is_instance_valid(selection): selection.visible = false
	if is_instance_valid(cracks): cracks.visible = false
	if not game.playing(): Spyglass.reset(self); mining = 0; eating.clear(); return
	var nausea: float = 0.035*sin(Time.get_ticks_msec()*0.002) if PotionEffects.level(self,"nausea") > 0 else 0.0
	camera.rotation.z = lerpf(camera.rotation.z,nausea,minf(1,delta*4))
	target = game.world.raycast(camera.global_position,-camera.global_basis.z,5.0,Boats.is_boat(game.inventory.held().id) or game.inventory.held().id in [Nodes.BUCKET,VillageContent.GLASS_BOTTLE,VillageContent.FISHING_ROD,VillageContent.BOAT_OAK,VillageContent.BOAT_ACACIA,VillageContent.BOAT_SPRUCE,VillageContent.BOAT_DARK_OAK,VillageContent.BOAT_BIRCH,VillageContent.KELP,VillageContent.LILY_PAD])
	if not target.is_empty():
		selection.visible = true
		selection.position = Vector3(target.pos)
		if RedstoneInputs.is_device(target.id) or BuildingShapes.is_shape(target.id) or Barriers.is_barrier(target.id) or RedstoneSensors.is_detector(target.id) or Trapdoors.is_trapdoor(target.id) or SnowCover.is_snow(target.id) or Doors.is_door(target.id) or FoodFeatures.is_cake(target.id) or Signs.is_sign(target.id) or CropFarming.is_crop(target.id) or Farmland.is_soil(target.id) or FruitCrops.is_stem(target.id) or Amethyst.is_crystal(target.id):
			var geometry: Dictionary
			if Amethyst.is_crystal(target.id): geometry = Barriers.box_visuals(Amethyst.boxes(target.id),"amethyst:"+str(target.id))
			elif CropFarming.is_crop(target.id): geometry = Barriers.box_visuals(CropFarming.boxes(target.id),"crop:"+str(target.id))
			elif Farmland.is_soil(target.id): geometry = Barriers.box_visuals(Farmland.boxes(target.id),"farmland:"+str(target.id))
			elif FruitCrops.is_stem(target.id): geometry = Barriers.box_visuals(FruitCrops.boxes(target.id),"stem:"+str(target.id))
			elif RedstoneInputs.is_device(target.id): geometry = Barriers.box_visuals(RedstoneInputs.boxes(target.id,game.world.circuits.state(target.pos)),"redstone_input:"+str(target.id)+":"+str(game.world.circuits.state(target.pos).get("input_pressed",false)))
			elif FoodFeatures.is_cake(target.id): geometry = Barriers.box_visuals(FoodFeatures.boxes(target.id),"cake:"+str(target.id))
			elif Doors.is_door(target.id): geometry = Barriers.box_visuals(Doors.boxes(target.id),"door:"+str(target.id))
			elif Signs.is_sign(target.id): geometry = Barriers.box_visuals(Signs.boxes(target.id),"sign:"+str(target.id))
			elif SnowCover.is_snow(target.id): geometry = Barriers.box_visuals(SnowCover.boxes(target.id,false),"snow:"+str(target.id))
			elif Trapdoors.is_trapdoor(target.id): geometry = Barriers.box_visuals(Trapdoors.boxes(target.id),"trapdoor:"+str(target.id))
			elif RedstoneSensors.is_detector(target.id): geometry = Barriers.box_visuals(RedstoneSensors.boxes(target.id),"daylight_detector")
			elif Barriers.is_barrier(target.id): geometry = Barriers.visuals(game.world,target.pos)
			else: geometry = BuildingShapes.visuals(BuildingShapes.world_mask(game.world,target.pos))
			selection.mesh = geometry.outline; cracks.mesh = geometry.cracks
		else: selection.mesh = selection_cube; cracks.mesh = cracks_cube
	var held: int = game.inventory.held().id
	if held != hand_id: _make_hand(held)
	swing = maxf(0,swing-delta*5)
	hand.rotation = Vector3(-0.15-sin(swing*PI)*0.6,0.25,-0.12-sin(swing*PI)*0.4)
	hand.position.y = -0.36+sin(bob)*0.012
	var pad: TouchControls = game.controls if game.touch else null
	var mine_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or (pad != null and pad.mine_held)
	var use_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or (pad != null and pad.use_pressed)
	var use_held: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or (pad != null and pad.use_held)
	if pad != null: pad.use_pressed = false
	var spyglass_use: bool = Spyglass.update(self,use_held,Input.is_physical_key_pressed(KEY_Z))
	if not game.playing(): return
	if not eating.is_empty():
		Eating.update(self,delta,use_held and not mine_pressed)
		mining = 0
		return
	if mine_pressed and use_cooldown <= 0 and game.boats.punch_target():
		use_cooldown = 0.45; swing = 1; return
	if mine_pressed and use_cooldown <= 0 and Paintings.punch_target(game):
		use_cooldown = 0.3; return
	if mine_pressed and use_cooldown <= 0 and game.adventure.deflect_target():
		use_cooldown = 0.4; swing = 1; return
	if mine_pressed:
		var mob = game.target_mob()
		if mob != null:
			mining = 0
			if use_cooldown <= 0:
				# Shears shear sheep instead of hurting them; other tools attack.
				if held == Nodes.SHEARS and mob.kind == "sheep":
					_shear_sheep(mob)
				else:
					Golems.attacked(mob,self)
					# `mcl_criticals`: a hit delivered while falling is a critical, worth
					# `damage + random(0, floor(damage * 1.5 + 2))`, with its own particles
					# and sound. A hit delivered while sprinting is not a critical: it adds
					# the hitter's velocity to the target instead.
					var damage: float = Enchantments.melee(self,mob)
					if sprinting and velocity.length() > 0.1:
						# `Creature` rebuilds its velocity from `knock` every physics step,
						# so a direct `velocity` write is overwritten before it is used.
						# The source's `obj:add_velocity(hitter:get_velocity())` maps onto
						# `knock`, which is decayed and folded in each step.
						mob.knock += velocity
					elif velocity.y < 0 and damage > 0:
						damage += randi_range(0,floori(damage*1.5+2))
						game.puff(mob.center(),Color("bc7a57"),15,0.6)
						game.sound_at("crit",mob.center())
					mob.hit(damage,position)
					Hunger.exhaust(self,Hunger.ATTACK)
					mob.knock *= 1+Inventory.enchantment(game.inventory.held(),"Knockback")*0.6
					if game.gamemode!="creative" and held != Nodes.SHEARS: game.inventory.damage_tool()
				use_cooldown = 0.45
				swing = 1
		elif not target.is_empty():
			mine(delta)
	else:
		mining = 0.0
		mining_pos = Vector3i(99999,99999,99999)
	if not use_pressed: use_latched = false
	var circuit_click: bool = Throwables.supports(held) or not target.is_empty() and (RedstoneInputs.is_button(target.id) or target.id in [NoteBlocks.ID,Jukeboxes.ID,Nodes.LEVER,Nodes.REPEATER,Nodes.COMPARATOR])
	if not spyglass_use and (use_pressed or use_held and Nodes.food(held) > 0) and use_cooldown <= 0 and (not circuit_click or not use_latched):
		use_latched = true
		use_cooldown = 0.25
		use()

func mine(delta: float) -> void:
	var held: int = game.inventory.held().id
	if target.pos != mining_pos or held != mining_tool:
		mining = 0
		mining_pos = target.pos
		mining_tool = held
		dig_timer = 0
		NoteBlocks.punch(game,target)
	var duration: float = 0.12 if game.gamemode=="creative" else Nodes.break_time(target.id,held)
	if game.gamemode != "creative" and Nodes.tool_kind(held) == Nodes.preferred_tool(target.id): duration /= 1.0+Inventory.enchantment(game.inventory.held(),"Efficiency")*0.4
	if underwater and Enchantments.worn(self,"Aqua Affinity") == 0: duration *= 5.0
	# An elder guardian's mining fatigue slows every block, which is the source's
	# own reason for the aura.
	duration *= PotionEffects.mining_speed(self)
	if is_inf(duration): return
	mining += delta/duration
	swing = 0.5+0.5*sin(Time.get_ticks_msec()*0.02)
	cracks.visible = true
	cracks.position = Vector3(target.pos)+(Vector3.ZERO if RedstoneInputs.is_device(target.id) or BuildingShapes.is_shape(target.id) or Barriers.is_barrier(target.id) or RedstoneSensors.is_detector(target.id) or Trapdoors.is_trapdoor(target.id) or SnowCover.is_snow(target.id) or Doors.is_door(target.id) or FoodFeatures.is_cake(target.id) or Signs.is_sign(target.id) or CropFarming.is_crop(target.id) or Farmland.is_soil(target.id) or FruitCrops.is_stem(target.id) or Amethyst.is_crystal(target.id) else Vector3.ONE*0.5)
	var stage: int = clampi(int(mining*9),0,8)
	if stage != crack_stage:
		crack_stage = stage
		crack_material.albedo_texture = crack_textures[stage]
		game.sound("dig")
	# Chips fly off the struck face for as long as digging continues, as in Luanti.
	dig_timer -= delta
	if dig_timer <= 0:
		dig_timer = 0.11
		game.dig_particles(target.pos,target.id,target.normal)
	if mining >= 1.0:
		game.break_node(target.pos,target.id,held)
		if game.world.node_at(target.pos) != target.id: Hunger.exhaust(self,Hunger.DIG)
		mining = 0.0
		crack_stage = -1
		if game.gamemode!="creative": game.inventory.damage_tool()

# Mineclonia `mcl_offhand.get_offhand`: the second hand's contents. Shields,
# totems and placeable items consult it when the main hand cannot serve, which is
# what the source's `get_wielditem` plus offhand fallback means.
func offhand() -> Dictionary:
	return offhand_slot

func offhand_id() -> int:
	return int(offhand_slot.id)

# Whether the item is carried in either hand, which is the source's check for a
# totem and for a raised shield.
func carries(id: int) -> bool:
	return game.inventory.held().id == id or offhand_id() == id

# Consume one from whichever hand carries the item, main hand first. Returns the
# hand that supplied it, or "" when neither did.
func consume_carried(id: int) -> String:
	if game.inventory.held().id == id:
		game.inventory.consume_selected()
		return "main"
	if offhand_id() == id:
		offhand_slot.count -= 1
		if int(offhand_slot.count) <= 0:
			offhand_slot = {"id":0,"count":0,"wear":0}
		return "offhand"
	return ""

# The slot a carried item lives in, so wear can be applied where it is held.
func carried_slot(id: int) -> Dictionary:
	if game.inventory.held().id == id: return game.inventory.held()
	if offhand_id() == id: return offhand_slot
	return {}

func equip_armor(slot: Dictionary) -> bool:
	if not Nodes.is_armor(slot.id): return false
	var piece: int = Nodes.armor_piece(slot.id)
	if game.gamemode != "creative" and Inventory.enchantment(armor_slots[piece],"Curse of Binding") > 0: game.toast("Curse of Binding prevents replacing this armor."); return false
	var previous: Dictionary = armor_slots[piece].duplicate()
	armor_slots[piece] = slot.duplicate(true)
	armor_slots[piece].count = 1
	if int(slot.count) > 1:
		slot.count -= 1
		if int(previous.count) > 0:
			var overflow: int = game.inventory.add_item(previous.id,previous.count,previous.wear,previous.get("data",{}))
			if overflow > 0: game.spawn_drop(position+Vector3.UP,previous.id,overflow,previous.wear,previous.get("data",{}))
	else:
		Inventory.copy_data(slot,previous)
		slot.id = previous.id; slot.count = previous.count; slot.wear = previous.wear
	game.inventory.changed.emit()
	game.sound("equip")
	game.toast("%s equipped  ·  %d armor points" % [Nodes.title(armor_slots[piece].id),armor_points()])
	return true

func _shear_sheep(sheep: Creature) -> void:
	if not sheep.shear(): return
	swing = 1
	use_cooldown = 0.6
	if game.gamemode != "creative": game.inventory.damage_tool()

func use() -> void:
	var held: int = game.inventory.held().id
	# Mineclonia shears are a use/right-click action on the aimed sheep. Handle
	# the animal before a block behind it, including already-sheared sheep.
	if held == Nodes.SHEARS:
		var sheep: Creature = game.target_mob()
		if sheep != null and sheep.kind == "sheep":
			_shear_sheep(sheep)
			return
	# A golden apple cures a zombie villager that is suffering weakness, which is
	# the source's own condition: a healthy one is unaffected.
	var cure_target: Creature = game.target_mob()
	if cure_target != null and ZombieVillagers.can_cure(cure_target,held):
		if ZombieVillagers.begin(game,cure_target,RandomNumberGenerator.new()):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.sound("place"); swing = 1
			return
	if Candles.use(game,target): return
	if game.boats.use(): return
	if RedstoneInputs.use(game,target): return
	if NoteBlocks.use(game,target): return
	if Jukeboxes.use(game,target): return
	if Fireworks.use(game,game.inventory.held().id): return
	if Beacons.use(game,target): return
	if game.rails != null and game.rails.use(game,target): return
	if Decor.use(game,target): return
	if Archaeology.brush(game,target): return
	if Copper.use_axe(game,target): return
	if Copper.use_honeycomb(game,target): return
	if Beehives.use(game,target): return
	if RedstoneSensors.use(game,target): return
	if Trapdoors.use(game,target): return
	if Doors.use(game,target): return
	if Signs.use(game,target): return
	if FoodFeatures.use(game,target): return
	if Barriers.use(game,target): return
	if WoodTypes.use(game,target): return
	if Campfires.use(game,target): return
	if Fire.use(game,target): return
	if game.survival.use(): return
	if held == Nodes.ENDER_EYE and not target.is_empty() and target.id == Nodes.END_FRAME:
		if WorldStructures.fill_eye(game.world,target.pos):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.sound("place"); swing = 1
		return
	if held in [Nodes.ENDER_PEARL,Nodes.ENDER_EYE]:
		if game.adventure.throw_item(held): swing = 1; use_cooldown = 0.6
		return
	if held == Nodes.END_CRYSTAL and not target.is_empty():
		if game.adventure.place_crystal(target.pos):
			if game.gamemode != "creative": game.inventory.consume_selected()
			swing = 1
		return
	if held in [Nodes.WRITABLE_BOOK,Nodes.WRITTEN_BOOK]: game.open_book(); return
	if Hunger.can_eat(self,held):
		Eating.start(self)
		return
	if Nodes.is_armor(held) and held != FruitCrops.CARVED:
		equip_armor(game.inventory.held())
		return
	# Milking: an empty bucket on a cow becomes a milk bucket.
	if held == Nodes.BUCKET:
		var cow = game.target_mob()
		if cow != null and cow.kind == "cow" and cow.growth_remaining <= 0:
			game.inventory.consume_selected()
			game.inventory.add_item(Nodes.MILK_BUCKET,1)
			game.sound("eat")
			game.toast("Fresh milk.")
			swing = 1
			game.achievements.award("milkmaid")
			return
	# An empty bucket on water scoops a water bucket.
	if held == Nodes.BUCKET and not target.is_empty() and game.world.node_at(target.pos) in [Nodes.WATER,Nodes.LAVA]:
		game.inventory.consume_selected()
		game.inventory.add_item(Nodes.LAVA_BUCKET if target.id == Nodes.LAVA else Nodes.WATER_BUCKET,1)
		if target.id == Nodes.LAVA: game.achievements.award("hot_stuff")
		game.world.set_node(target.pos,Nodes.AIR)
		game.sound("dig")
		swing = 1
		return
	# Compass points home; clock reads the day and hour.
	if held == Nodes.COMPASS:
		game.toast(Lodestones.describe(game,game.inventory.held()))
		swing = 0.5
		return
	if held == Nodes.CLOCK:
		game.toast("Day %d  ·  %s  ·  %d%% through the day." % [game.day_number(),game.time_name(),int(fposmod(game.day_time,1.0)*100)])
		swing = 0.5
		return
	# The bow fires an arrow where you look if you have ammunition.
	if held == Nodes.BOW:
		var ammunition: int = game.survival.ammunition()
		if ammunition != 0 or game.gamemode=="creative":
			var infinite: bool = ammunition == Nodes.ARROW_ITEM and Inventory.enchantment(game.inventory.held(),"Infinity") > 0
			if game.gamemode!="creative" and not infinite: game.inventory.remove_item(ammunition,1)
			var origin: Vector3 = camera.global_position-camera.global_basis.z*0.4
			var velocity_value: Vector3 = -camera.global_basis.z*26.0+Vector3.UP*2.2
			var shot: Arrow = game.spawn_arrow(origin,velocity_value)
			if shot != null:
				shot.from_player = true
				shot.item_id = ammunition if ammunition != 0 else Nodes.ARROW_ITEM
				shot.damage += Inventory.enchantment(game.inventory.held(),"Power")*2.0
				shot.recoverable = not infinite and game.gamemode != "creative"
				shot.flame = Inventory.enchantment(game.inventory.held(),"Flame") > 0
				shot.punch = Inventory.enchantment(game.inventory.held(),"Punch")
			if game.gamemode!="creative": game.inventory.damage_tool()
			game.sound("arrow")
			swing = 1
		else:
			game.toast("You need arrows. Craft them from flint, sticks, and feathers.")
		return
	if target.is_empty():
		if Spyglass.request(self): return
		if game.maps.use(): return
		Throwables.use(game)
		return
	var p: Vector3i = target.pos
	var id: int = target.id
	# Bone meal grows a sugar cane stalk, which is the source's `grow_reeds`. The
	# source's rule has a twist: if the cane has lost its water it is *removed* and
	# dropped instead of grown, so bone meal cleans up stranded cane.
	if held == Nodes.BONE_MEAL and id == Nodes.SUGAR_CANE:
		var bottom: Vector3i = p
		while game.world.node_at(bottom+Vector3i.DOWN) == Nodes.SUGAR_CANE: bottom += Vector3i.DOWN
		var cane_top: Vector3i = p
		while game.world.node_at(cane_top+Vector3i.UP) == Nodes.SUGAR_CANE: cane_top += Vector3i.UP
		if not game.world.can_plant_cane(bottom):
			# No water within reach: the source removes the cane rather than
			# growing it, and returns false so no particle is played.
			game.world.set_node(bottom,Nodes.AIR)
			if game.gamemode != "creative": game.spawn_drop(Vector3(bottom)+Vector3.ONE*0.5,Nodes.SUGAR_CANE)
			game.settle(bottom+Vector3i.UP)
			return
		var wanted: int = mini(2,3-(cane_top.y-bottom.y+1))
		for i in range(1,wanted+1):
			var grow_at: Vector3i = cane_top+Vector3i.UP*i
			if game.world.node_at(grow_at) != Nodes.AIR: break
			game.world.set_node(grow_at,Nodes.SUGAR_CANE)
		if wanted > 0 and game.gamemode != "creative": game.inventory.consume_selected()
		if wanted > 0:
			game.puff(Vector3(p)+Vector3.ONE*0.5+Vector3.UP,Color("b8e07a"),8)
			game.sound("place"); swing = 1
		return
	# Bone meal grows one bamboo segment, which is the source's `mcl_bamboo.grow`.
	if held == Nodes.BONE_MEAL and Bamboo.is_bamboo(id):
		var bamboo_rng := RandomNumberGenerator.new()
		bamboo_rng.seed = game.world.generator.hash_at(p.x,p.y,p.z)
		if Bamboo.grow(game.world,game.world.generator,p,func(q: Vector3i) -> int: return Pasture.light(game.world,q,14),bamboo_rng):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.puff(Vector3(p)+Vector3.ONE*0.5+Vector3.UP,Color("b8e07a"),8)
			game.sound("place"); swing = 1
		return
	# `mcl_crimson`: bone meal on a nether fungus grows its huge form on the source's
	# 40% roll, and on a vine grows one to three more blocks downward.
	if held == Nodes.BONE_MEAL and CrimsonPlants.is_fungus(id):
		if CrimsonPlants.bone_meal_fungus(game.world,p,RandomNumberGenerator.new()):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.puff(Vector3(p)+Vector3.ONE*0.5,Color("b8e07a"),8)
			game.sound("place"); swing = 1; game.settle(p+Vector3i.UP)
		return
	if held == Nodes.BONE_MEAL and PaleOak.is_hanging_moss(id):
		if PaleOak.grow_hanging_moss(game.world,p):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.puff(Vector3(p)+Vector3.ONE*0.5,Color("b8e07a"),8)
			game.sound("place"); swing = 1
		return
	if held == Nodes.BONE_MEAL and PaleOak.is_pale_moss(id):
		if PaleOak.bone_meal_moss(game.world,p,RandomNumberGenerator.new()):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.puff(Vector3(p)+Vector3i.UP*0.5+Vector3.ONE*0.5,Color("b8e07a"),8)
			game.sound("place"); swing = 1
		return
	if held == Nodes.BONE_MEAL and CrimsonPlants.is_vine(id):
		var top: Vector3i = p
		while CrimsonPlants.is_vine(game.world.node_at(top+Vector3i.UP)): top += Vector3i.UP
		if CrimsonPlants.grow(game.world,top,id,RandomNumberGenerator.new()) > 0:
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.puff(Vector3(p)+Vector3.ONE*0.5,Color("b8e07a"),8)
			game.sound("place"); swing = 1
		return
	# Bone meal on a small mushroom grows a **huge** mushroom, which is the source's
	# own rule: a 40% roll, the right soil, and enough room. Most attempts do nothing,
	# which is why the source's own roll is kept rather than a guaranteed growth.
	if held == Nodes.BONE_MEAL and id in [Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM]:
		if HugeMushrooms.grow(game.world,p,id,RandomNumberGenerator.new()):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.puff(Vector3(p)+Vector3.ONE*0.5,Color("b8e07a"),8)
			game.sound("place"); swing = 1
			game.settle(p+Vector3i.UP)
		return
	# Bone meal ripens a cocoa pod one stage, which is the source's `mcl_cocoas.grow`.
	# Only the two unripe stages respond; a ripe pod is left alone.
	if held == Nodes.BONE_MEAL and id == VillageContent.COCOA_POD:
		if game.world.set_node(p,VillageContent.RIPE_COCOA_POD):
			if game.gamemode != "creative": game.inventory.consume_selected()
			game.puff(Vector3(p)+Vector3.ONE*0.5,Color("b8e07a"),8)
			game.sound("place"); swing = 1
		return
	# Bone meal on a grass block carpets the ground around it with tall grass and
	# flowers, which is the source's `bone_meal_grass`. It used to grow exactly one
	# flower on the block itself, which is neither the source's area nor its mix.
	if held == Nodes.BONE_MEAL and id == Nodes.GRASS and game.world.node_at(p+Vector3i.UP) == Nodes.AIR:
		if FoodFeatures.bone_meal_grass(game,p):
			if game.gamemode!="creative": game.inventory.consume_selected()
			game.puff(Vector3(p)+Vector3.ONE*0.5+Vector3.UP,Color("b8e07a"),8)
			game.sound("place")
			swing = 1
		return
	if not Input.is_physical_key_pressed(KEY_CTRL):
		if game.world.circuits.interact(p): return
		if id == Nodes.ENCHANTING_TABLE: game.open_enchanting(p); return
		if held == Nodes.FLINT_AND_STEEL and id == Nodes.OBSIDIAN:
			if game.world.ignite_portal(p+target.normal): game.sound("place")
			else: game.toast("Build a 4 × 5 obsidian frame with a 2 × 3 opening.")
			return
		if id in [Nodes.WORKBENCH,Nodes.FURNACE,Nodes.CHEST]:
			game.open_inventory({Nodes.WORKBENCH:"table",Nodes.FURNACE:"furnace",Nodes.CHEST:"chest"}[id],p)
			return
		if id in [Nodes.BED_FOOT,Nodes.BED_HEAD,Nodes.BED]:
			game.sleep_at(p)
			return
		if id == Nodes.TNT:
			game.ignite_tnt(p)
			swing = 1
			return
	if Spyglass.request(self): return
	# Bone meal on a sea pickle grows it and spreads it, as the source does.
	if held == Nodes.BONE_MEAL and SeaPickles.is_pickle(id):
		SeaPickles.bone_meal(game.world,p,Corals._rng(game.world))
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.puff(Vector3(p)+Vector3.ONE*0.5,Color("b8e07a"),8); game.sound("place"); swing = 1
		return
	if SeaPickles.place(game,target,held): return
	if FruitCrops.use(game,target): return
	if game.maps.use(): return
	if Throwables.use(game): return
	if held == Nodes.BONE_MEAL and FoodFeatures.flower(id):
		if FoodFeatures.bone_meal(game,p) and game.gamemode != "creative": game.inventory.consume_selected()
		return
	# A crop accepts bone meal and a seed is planted from the hand, which the crop
	# system owns. Without this call neither interaction is reachable.
	if CropFarming.use(game,target): return
	if Farmland.use(game,target): return
	# Pouring: a water bucket fills the targeted face with a water node.
	if held in [Nodes.WATER_BUCKET,Nodes.LAVA_BUCKET] and not target.is_empty():
		if held == Nodes.WATER_BUCKET and game.dimension == "nether": game.toast("Water evaporates in the Nether."); return
		var liquid: int = Nodes.WATER if held == Nodes.WATER_BUCKET else Nodes.LAVA
		var pour: Vector3i = SnowCover.placement(game.world,target).pos
		if (SnowCover.replaceable(game.world.node_at(pour)) or Fluids.flowing(game.world.node_at(pour))) and game.world.set_node(pour,liquid):
			if game.gamemode!="creative":
				game.inventory.consume_selected()
				game.inventory.add_item(Nodes.BUCKET,1)
			game.sound("place")
			swing = 1
			game.api.emit_node_placed(pour,liquid)
			return
	# A bucket scoops powder snow, which is how the block is carried.
	if held == Nodes.BUCKET and not target.is_empty() and PowderSnow.scoop(game,target.pos): return
	if EndMud.place(game,target,held): return
	if Candles.place(game,target,held): return
	if FoodFeatures.try_place(game,target): return
	if Amethyst.try_place(game,target): return
	if Doors.try_place(game,target): return
	if SnowCover.try_place(game,target): return
	var place_target: Dictionary = target
	if SnowCover.is_snow(target.id):
		place_target = target.duplicate(); place_target["replace"] = target.pos
	if game.rails != null and Minecarts.place(game,place_target,held): return
	if Kelp.place(game,place_target,game.inventory.held().id): return
	if Seagrass.place(game,place_target,game.inventory.held().id): return
	if SeaPickles.place(game,place_target,game.inventory.held().id): return
	if Corals.place(game,place_target,game.inventory.held().id): return
	if Scaffolding.place(game,place_target,game.inventory.held().id): return
	if Withers.try_place_skull(game,place_target.get("replace",place_target.pos+place_target.get("normal",Vector3i.UP)),game.inventory.held().id): return
	if Heads.try_place(game,place_target): return
	if Rails.try_place(game,place_target): return
	if Paintings.place(game,place_target,held): return
	if Decor.try_place(game,place_target): return
	if Archaeology.try_place(game,place_target): return
	if Sponges.place(game,place_target): return
	if Sponges.place_wet(game,place_target): return
	if Copper.try_place(game,place_target): return
	if Trapdoors.try_place(game,place_target): return
	if Signs.try_place(game,place_target): return
	if RedstoneInputs.try_place(game,place_target): return
	if Barriers.try_place(game,place_target): return
	if BuildingShapes.try_place(game,place_target): return
	# The source's `mcl_offhand.place`: a torch in the second hand is placed when the
	# main hand cannot, which is the only `offhand_placeable` group in the game.
	var place_id: int = held
	var from_offhand: bool = false
	if not Nodes.placeable(place_id) and Torches.is_torch(offhand_id()):
		place_id = offhand_id()
		from_offhand = true
		held = place_id
	if not Nodes.placeable(place_id) and not (game.gamemode=="creative" and place_id in [Nodes.WATER,Nodes.LAVA,Nodes.BEDROCK]): return
	if place_id == Nodes.WATER and game.dimension == "nether": game.toast("Water evaporates in the Nether."); return
	var destination: Vector3i = place_target.get("replace",p+target.normal)
	var soil_id: int = game.world.node_at(destination+Vector3i.DOWN) if SnowCover.is_snow(id) else id
	if place_id == Nodes.TORCH:
		place_id = Torches.placed(target.normal)
		if place_id == 0 or not BuildingShapes.supports(game.world,destination-target.normal,target.normal): return
	if WoodTypes.is_sapling(place_id) and not WoodTypes.soil(soil_id): return
	if FoodFeatures.flower(place_id) and not FoodFeatures.flower_supported(game.world,destination): return
	if place_id == Nodes.SUGAR_CANE and not game.world.can_plant_cane(destination):
		game.toast("Plant sugar cane on dirt, grass or sand beside water.")
		return
	if place_id in [Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM] and (target.normal != Vector3i.UP or soil_id not in [Nodes.DIRT,Nodes.GRASS,Nodes.MOSSY_COBBLE]): return
	# `mcl_crimson`'s `place_fungus`: a fungus needs its own nylium.
	if CrimsonPlants.is_fungus(place_id) and not CrimsonPlants.placement_ok(game.world,destination,place_id):
		game.toast("That fungus needs its own nylium underneath.")
		return
	if not SnowCover.is_snow(game.world.node_at(destination)) and (Nodes.solid(game.world.node_at(destination)) or Barriers.is_barrier(game.world.node_at(destination))): return
	if place_id == Nodes.CHEST:
		var reason: String = game.world.chest_placement_problem(destination)
		if not reason.is_empty(): game.toast(reason); return
	var node_box := AABB(Vector3(destination),Vector3.ONE)
	var player_box := AABB(position-Vector3(0.3,0,0.3),Vector3(0.6,1.8,0.6))
	# Bed halves are half-height and meant to be placed at your feet — like
	# Mineclonia, overlap with the player is allowed (you step up onto them).
	if Nodes.solid(place_id) and place_id not in [Nodes.BED_FOOT,Nodes.BED_HEAD] and node_box.intersects(player_box): return
	# A bed needs room for its second half, laid in the player's facing direction.
	if place_id in [Nodes.BED_FOOT,Nodes.BED_HEAD]:
		var look: Vector3 = basis*Vector3.FORWARD
		var facing: Vector3i = Vector3i(0,0,1) if absf(look.z) >= absf(look.x) else Vector3i(1,0,0)
		facing = Vector3i(signi(int(signf(look.x))),0,0) if facing.x != 0 else Vector3i(0,0,signi(int(signf(look.z))))
		var foot: Vector3i = destination
		var head: Vector3i = destination+facing
		if place_id == Nodes.BED_HEAD:
			head = destination
			foot = destination-facing
		if not SnowCover.is_snow(game.world.node_at(head)) and (Nodes.solid(game.world.node_at(head)) or Barriers.is_barrier(game.world.node_at(head)) or game.world.node_at(head) in [Nodes.BED_FOOT,Nodes.BED_HEAD]):
			game.toast("The bed needs two free blocks.")
			return
		var head_box := AABB(Vector3(head),Vector3.ONE)
		if head_box.intersects(player_box): return
		if not game.world.set_node(foot,Nodes.BED_FOOT): return
		if not game.world.set_node(head,Nodes.BED_HEAD):
			game.world.set_node(foot,Nodes.AIR)
			return
		if game.gamemode!="creative": game.inventory.consume_selected()
		game.sound("place")
		swing = 1
		game.settle(foot+Vector3i.UP)
		game.progress("build")
		game.api.emit_node_placed(foot,Nodes.BED_FOOT)
		game.api.emit_node_placed(head,Nodes.BED_HEAD)
		return
	var support: Vector3i = -target.normal if place_id in [Nodes.REDSTONE_TORCH,Nodes.LEVER,Nodes.BUTTON] else Vector3i.DOWN
	if place_id in Nodes.SMALL_CIRCUITS and place_id != Nodes.IRON_DOOR_OPEN and not BuildingShapes.supports(game.world,destination+support,-support):
		game.toast("Place this component on a solid block."); return
	if place_id == Nodes.IRON_DOOR and not SnowCover.replaceable(game.world.node_at(destination+Vector3i.UP)): return
	place_id = WoodTypes.oriented(place_id,target.normal)
	place_id = DenseMaterials.oriented(place_id,target.normal)
	place_id = Beehives.oriented(place_id,rotation.y)
	place_id = CopperDecor.oriented(place_id,target.normal,rotation.y)
	if game.world.set_node(destination,place_id):
		if WoodTypes.is_leaves(place_id): WoodTypes.mark_placed(game.world,destination)
		PortableStorage.placed(game,destination,game.inventory.held())
		Copper.placed_wax(game,destination,game.inventory.held())
		if RedstoneCircuit.circuit_node(place_id):
			var forward: Vector3 = -camera.global_basis.z
			var axis: int = 0 if absf(forward.x) > absf(forward.z) else 2
			if place_id in [Nodes.PISTON,Nodes.STICKY_PISTON,Nodes.DISPENSER,Nodes.DROPPER,Nodes.OBSERVER] and absf(forward.y) > 0.75: axis = 1
			var d := Vector3i.ZERO; d[axis] = int(signf(forward[axis]))
			if place_id == Nodes.HOPPER: d = -target.normal
			game.world.circuits.configure(destination,d,support)
			if place_id == Nodes.IRON_DOOR:
				game.world.set_node(destination+Vector3i.UP,Nodes.IRON_DOOR)
				game.world.circuits.configure(destination+Vector3i.UP,d)
				game.world.circuits.state(destination+Vector3i.UP)["upper"] = true
		if game.gamemode!="creative":
			# A torch placed from the second hand is consumed there, not from the
			# main hand, which is the source's own hand handling.
			if from_offhand: consume_carried(place_id)
			else: game.inventory.consume_selected()
		game.sound("place")
		swing = 1
		if Torches.is_torch(place_id) or place_id == Nodes.GLOWSTONE: game.add_torch(destination)
		if place_id == Nodes.CHEST and game.world.chest_partner(destination) != destination: game.toast("The chests join into one large chest.")
		game.settle(destination)
		game.progress("build")
		game.api.emit_node_placed(destination,place_id)

# Damage passes through worn armor unless it bypasses it (drowning, starving,
# falling). Every piece worn takes wear from a hit. A source position knocks
# the player away from the attacker.
func hurt(amount: float, bypass_armor: bool = false, source: Vector3 = Vector3.INF, cause: String = "generic") -> void:
	if damage_cooldown > 0 or health <= 0: return
	if not bypass_armor and game.survival.blocks_damage(source,cause): return
	# A totem of undying turns lethal damage into one health, which the source
	# does in a damage modifier ahead of the hit landing. It applies in creative
	# too, where the source saves the player but does not consume the totem.
	if not bypass_armor and Totems.intercept(self,amount,cause): return
	if game.gamemode=="creative": return
	var toughness: float = armor_toughness()
	var reduction: float = 0.0 if bypass_armor else minf(20,maxf(armor_points()/5.0,armor_points()-amount/(2+toughness/4)))/25
	var uses: int = maxi(1,floori(amount/4))
	if cause not in ["void","starve"]: amount *= PotionEffects.resistance(self)*Enchantments.protection(self,cause)
	PotionEffects.damaged(self)
	var damage: float = amount*(1.0-reduction)
	if cause not in ["void","starve"]: damage = PotionEffects.absorb(self,damage)
	health = maxf(0,health-damage)
	if damage > 0: Hunger.exhaust(self,Hunger.DAMAGE)
	if not bypass_armor:
		for slot in armor_slots:
			if Nodes.armor_points(slot.id) == 0: continue
			if randf() < float(Inventory.enchantment(slot,"Unbreaking"))/(Inventory.enchantment(slot,"Unbreaking")+1.0): continue
			slot.wear += uses
			if slot.wear >= Nodes.durability(slot.id):
				game.toast("Your "+Nodes.title(slot.id).to_lower()+" broke.")
				slot.id = 0; slot.count = 0; slot.wear = 0; slot.erase("data")
				game.sound("break")
		game.inventory.changed.emit()
	if not is_inf(source.x):
		var thorns: int = Enchantments.worn(self,"Thorns")
		if thorns > 0 and randf() < minf(1.0,thorns*0.15):
			for mob in game.creatures.get_children():
				if not mob.is_queued_for_deletion() and mob.position.distance_to(source) < 0.8: mob.hit(randi_range(1,4),position); break
		var away: Vector3 = ((position-source)*Vector3(1,0,1)).normalized()
		velocity.x += away.x*5.5
		velocity.z += away.z*5.5
		velocity.y = maxf(velocity.y,4.0)
	damage_cooldown = 0.65
	game.hud.flash = 0.45
	game.sound("hurt")
	game.api.emit_player_hurt(damage,"" if is_inf(source.x) else str(source.round()))
	if health <= 0: game.die()

func _make_hand(id: int) -> void:
	hand_id = id
	for child in hand.get_children(): child.queue_free()
	if RedstoneInputs.is_device(id) or id in Nodes.CIRCUIT_NODES:
		var model: Node3D = RedstoneInputs.build(id) if RedstoneInputs.is_device(id) else RedstoneArt.build(id)
		model.scale = Vector3.ONE*0.28
		model.position = Vector3(0,-0.14,0)
		hand.add_child(model)
	elif Nodes.placeable(id):
		# The held node is a miniature of the real one, using the terrain atlas.
		var instance := MeshInstance3D.new()
		instance.mesh = game.node_mesh(id)
		instance.material_override = game.world.water_material if id in [Amethyst.TINTED_GLASS,Beehives.HONEY_BLOCK] else game.node_material
		instance.scale = Vector3.ONE*0.28
		instance.position = Vector3(-0.14,-0.14,-0.14)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hand.add_child(instance)
	elif id != 0:
		var instance := MeshInstance3D.new()
		instance.mesh = ItemArt.mesh(id)
		instance.material_override = ItemArt.material(id)
		instance.scale = Vector3.ONE*(0.55 if Nodes.is_tool_id(id) else 0.38)
		instance.rotation.y = -0.35
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hand.add_child(instance)
	else:
		_add_hand_box(Vector3(0,-0.17,0.15),Vector3(0.19,0.46,0.19),Color("c29470"))
		_add_hand_box(Vector3(0,-0.34,0.15),Vector3(0.2,0.2,0.2),Color("526d58"))

func _add_hand_box(pos: Vector3, size_value: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	instance.mesh = mesh
	instance.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand.add_child(instance)

func update_glide(delta: float, jump_held: bool, blocked: bool = false) -> bool:
	var wings: Dictionary = armor_slots[1]
	if wings.id != Nodes.ELYTRA or wings.wear >= Nodes.durability(Nodes.ELYTRA)-1 or grounded or blocked or levitation > 0: return false
	if not gliding and not (jump_held and velocity.y < -2): return false
	# A firework rocket overrides the normal glide curve entirely, as the source
	# applies its boost on top of the wings already being deployed.
	if rocketing > 0.0:
		Fireworks.boost(self,delta)
		flight_wear += delta
		if flight_wear >= 2 and game.gamemode != "creative": wings.wear += 1; flight_wear = 0
		return true
	var forward: Vector3 = -camera.global_basis.z
	var speed: float = 16-clampf(camera.rotation.x,-1,1)*5
	velocity.x = lerpf(velocity.x,forward.x*speed,clampf(delta*2.5,0,1))
	velocity.z = lerpf(velocity.z,forward.z*speed,clampf(delta*2.5,0,1))
	velocity.y = lerpf(velocity.y,clampf(-2.3+camera.rotation.x*5,-12,-0.65),clampf(delta*4,0,1))
	flight_wear += delta
	if flight_wear >= 2 and game.gamemode != "creative": wings.wear += 1; flight_wear = 0
	return true

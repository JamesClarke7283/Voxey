class_name VoxeyPlayer
extends Node3D

var game: Node3D
var camera: Camera3D
var velocity := Vector3.ZERO
var grounded: bool = false
var health: float = 20.0
var hunger: float = 20.0
var breath: float = 10.0
var armor_slots: Array = []
var sensitivity: float = 0.0022
var target: Dictionary = {}
var mining: float = 0.0
var mining_pos := Vector3i(99999,99999,99999)
var mining_tool: int = -1
var selection: MeshInstance3D
var cracks: MeshInstance3D
var crack_material: StandardMaterial3D
var crack_textures: Array = []
var crack_stage: int = -1
var dig_timer: float = 0.0
var use_cooldown: float = 0.0
var damage_cooldown: float = 0.0
var survival_timer: float = 0.0
var walked: float = 0.0
var bob: float = 0.0
var hand: Node3D
var hand_id: int = -1
var swing: float = 0.0
var underwater: bool = false
var flying: bool = false

func _init() -> void:
	for i in 4: armor_slots.append({"id":0,"count":0,"wear":0})

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
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.08,0.13,0.10,0.65)
	selection.material_override = line_mat
	game.add_child.call_deferred(selection)
	cracks = MeshInstance3D.new()
	cracks.mesh = Art.crack_mesh()
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

func _physics_process(delta: float) -> void:
	if game == null or not game.playing(): return
	if not game.world.loaded_at(position): return
	damage_cooldown = maxf(0,damage_cooldown-delta)
	use_cooldown = maxf(0,use_cooldown-delta)
	var pad: TouchControls = game.controls if game.touch else null
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): direction.z -= 1
	if Input.is_physical_key_pressed(KEY_S): direction.z += 1
	if Input.is_physical_key_pressed(KEY_A): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D): direction.x += 1
	if pad != null and pad.stick.length() > 0.12: direction += Vector3(pad.stick.x,0,pad.stick.y)
	var crouch: bool = Input.is_physical_key_pressed(KEY_CTRL) or (pad != null and pad.sneak_held)
	var sprint: bool = Input.is_physical_key_pressed(KEY_SHIFT) and hunger > 5 and not crouch
	var speed: float = 7.0 if sprint else (2.1 if crouch else 4.5)
	var moving: bool = direction.length() > 0.1
	camera.fov = lerpf(camera.fov,86.0 if sprint and moving and not flying else 78.0,delta*7)
	if game.gamemode=="creative" and flying:
		direction=basis*direction.normalized()
		if Input.is_physical_key_pressed(KEY_SPACE) or (pad != null and pad.jump_held): direction.y+=1
		if Input.is_physical_key_pressed(KEY_SHIFT) or (pad != null and pad.sneak_held): direction.y-=1
		velocity=direction*12.0
		_move(velocity*delta,false)
		camera.position.y=1.62
		underwater=game.world.node_at(Vector3i(camera.global_position.floor()))==Nodes.WATER
		return
	var wet: bool = game.world.node_at(Vector3i((position+Vector3.UP*0.5).floor())) == Nodes.WATER
	underwater = game.world.node_at(Vector3i(camera.global_position.floor())) == Nodes.WATER
	if wet: speed *= 0.55
	direction = basis * direction.normalized()
	velocity.x = move_toward(velocity.x,direction.x*speed,delta*35)
	velocity.z = move_toward(velocity.z,direction.z*speed,delta*35)
	# Water: mild sinking drift, strong swim stroke toward where you look, and a
	# surface kick so you pop up onto the shore instead of bobbing below it.
	if wet:
		velocity.y -= 3.2*delta
		velocity.y = maxf(velocity.y,-2.2)
		if Input.is_physical_key_pressed(KEY_SPACE) or (pad != null and pad.jump_held):
			velocity.y = 4.2 if not underwater else 4.6
		elif underwater and not grounded:
			velocity.y = maxf(velocity.y,0.4) # gentle buoyancy while floating
		# Kicking into open air above the waterline vaults the ledge.
		var facing: Vector3 = (basis * Vector3.FORWARD)
		if velocity.y > 1.0 and not Nodes.solid(game.world.node_at(Vector3i((position+Vector3.UP*1.9).floor()))):
			var ahead: Vector3i = Vector3i((position+facing*0.45).floor())
			if not game.world.intersects(position+facing*0.9,0.29,1.4) and game.world.node_at(ahead+Vector3i.UP) != Nodes.WATER:
				velocity.y = maxf(velocity.y,6.4)
	else:
		velocity.y -= 24.0*delta
		velocity.y = maxf(velocity.y,-45.0)
		if Input.is_physical_key_pressed(KEY_SPACE) or (pad != null and pad.jump_held):
			if grounded:
				velocity.y = 8.2
				grounded = false
				hunger -= 0.015
	var old_pos: Vector3 = position
	_move(velocity*delta,crouch)
	var distance: float = Vector2(position.x-old_pos.x,position.z-old_pos.z).length()
	walked += distance
	if distance > 0.001 and grounded:
		bob += distance*2.5
		if walked > 2.4:
			walked = 0
			game.sound("step")
		if game.gamemode!="creative": hunger = maxf(0,hunger-distance*(0.009 if sprint else 0.003))
	camera.position.y = lerpf(camera.position.y,(1.35 if crouch else 1.62)+sin(bob*2)*0.025 if grounded else 1.62,delta*12)
	survival_timer += delta
	if game.gamemode=="creative":
		health=20; hunger=20; breath=10
		return
	if survival_timer >= 1.0:
		survival_timer = 0.0
		hunger = maxf(0,hunger-0.008)
		if underwater:
			breath = maxf(0,breath-1)
			if breath <= 0: hurt(2,true)
		else: breath = minf(10,breath+3)
		if hunger >= 16 and health < 20: health = minf(20,health+0.5); hunger -= 0.2
		if hunger <= 0 and health > 1: hurt(1,true)
		var feet: Vector3i = Vector3i(position.floor())
		for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
			if game.world.node_at(feet+d) == Nodes.CACTUS: hurt(1)
		if position.y < -5: hurt(20,true)

func _move(motion: Vector3, crouch: bool) -> void:
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
				if velocity.y < -12: hurt(floorf((-velocity.y-11)*0.9),true)
			velocity[axis] = 0.0
			part[axis] = 0.0
	if game.world.intersects(position-Vector3.UP*0.035): grounded = true

func _process(delta: float) -> void:
	if game == null: return
	if is_instance_valid(selection): selection.visible = false
	if is_instance_valid(cracks): cracks.visible = false
	if not game.playing(): mining = 0; return
	target = game.world.raycast(camera.global_position,-camera.global_basis.z)
	if not target.is_empty():
		selection.visible = true
		selection.position = Vector3(target.pos)
	var held: int = game.inventory.held().id
	if held != hand_id: _make_hand(held)
	swing = maxf(0,swing-delta*5)
	hand.rotation = Vector3(-0.15-sin(swing*PI)*0.6,0.25,-0.12-sin(swing*PI)*0.4)
	hand.position.y = -0.36+sin(bob)*0.012
	var pad: TouchControls = game.controls if game.touch else null
	var mine_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or (pad != null and pad.mine_held)
	var use_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or (pad != null and pad.use_pressed)
	if pad != null: pad.use_pressed = false
	if mine_pressed:
		var mob = game.target_mob()
		if mob != null:
			mining = 0
			if use_cooldown <= 0:
				mob.hit(2+(Nodes.tool_tier(held)+1)*(2 if Nodes.tool_kind(held)==3 else 1),position)
				if game.gamemode!="creative": game.inventory.damage_tool()
				use_cooldown = 0.45
				swing = 1
		elif not target.is_empty():
			mine(delta)
	else:
		mining = 0.0
		mining_pos = Vector3i(99999,99999,99999)
	if use_pressed and use_cooldown <= 0:
		use_cooldown = 0.25
		use()

func mine(delta: float) -> void:
	var held: int = game.inventory.held().id
	if target.pos != mining_pos or held != mining_tool:
		mining = 0
		mining_pos = target.pos
		mining_tool = held
		dig_timer = 0
	var duration: float = 0.12 if game.gamemode=="creative" else Nodes.break_time(target.id,held)
	if is_inf(duration): return
	mining += delta/duration
	swing = 0.5+0.5*sin(Time.get_ticks_msec()*0.02)
	cracks.visible = true
	cracks.position = Vector3(target.pos)+Vector3.ONE*0.5
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
		mining = 0.0
		crack_stage = -1
		if game.gamemode!="creative": game.inventory.damage_tool()

func equip_armor(slot: Dictionary) -> bool:
	if not Nodes.is_armor(slot.id): return false
	var piece: int = Nodes.armor_piece(slot.id)
	var previous: Dictionary = armor_slots[piece].duplicate()
	armor_slots[piece] = {"id":slot.id,"count":1,"wear":slot.wear}
	slot.id = previous.id; slot.count = previous.count; slot.wear = previous.wear
	game.inventory.changed.emit()
	game.sound("equip")
	game.toast("%s equipped  ·  %d%% damage protection" % [Nodes.title(armor_slots[piece].id),armor_points()*4])
	return true

func use() -> void:
	var held: int = game.inventory.held().id
	if Nodes.food(held) > 0 and hunger < 20:
		hunger = minf(20,hunger+Nodes.food(held))
		game.inventory.consume_selected()
		game.sound("eat")
		game.toast("A good meal. Hunger restored.")
		swing = 1
		return
	if Nodes.is_armor(held):
		equip_armor(game.inventory.held())
		return
	if target.is_empty(): return
	var p: Vector3i = target.pos
	var id: int = target.id
	if not Input.is_physical_key_pressed(KEY_CTRL):
		if id in [Nodes.WORKBENCH,Nodes.FURNACE,Nodes.CHEST]:
			game.open_inventory({Nodes.WORKBENCH:"table",Nodes.FURNACE:"furnace",Nodes.CHEST:"chest"}[id],p)
			return
		if id == Nodes.BED:
			game.sleep_at(p)
			return
		if id == Nodes.TNT:
			game.ignite_tnt(p)
			swing = 1
			return
	if held == Nodes.BONE_MEAL and id in [Nodes.WHEAT,Nodes.SAPLING]:
		if id == Nodes.WHEAT: game.world.set_node(p,Nodes.RIPE_WHEAT)
		else: game.world.grow_tree(p)
		if game.gamemode!="creative": game.inventory.consume_selected()
		game.puff(Vector3(p)+Vector3.ONE*0.5,Color("b8e07a"),8)
		game.sound("place")
		swing = 1
		return
	if Nodes.tool_kind(held) == 4 and id in [Nodes.GRASS,Nodes.DIRT] and game.world.node_at(p+Vector3i.UP) == Nodes.AIR:
		game.world.set_node(p,Nodes.FARMLAND)
		if game.gamemode!="creative": game.inventory.damage_tool()
		game.sound("dig")
		return
	var place_id: int = Nodes.WHEAT if held == Nodes.SEEDS else held
	if not Nodes.placeable(place_id) and not (game.gamemode=="creative" and place_id in [Nodes.WATER,Nodes.BEDROCK]): return
	var destination: Vector3i = p+target.normal
	if held == Nodes.SEEDS and id != Nodes.FARMLAND:
		game.toast("Use a hoe to till dirt before planting seeds.")
		return
	if place_id == Nodes.SAPLING and id not in [Nodes.DIRT,Nodes.GRASS]: return
	if Nodes.solid(game.world.node_at(destination)): return
	if place_id == Nodes.CHEST:
		var reason: String = game.world.chest_placement_problem(destination)
		if not reason.is_empty(): game.toast(reason); return
	var node_box := AABB(Vector3(destination),Vector3.ONE)
	var player_box := AABB(position-Vector3(0.3,0,0.3),Vector3(0.6,1.8,0.6))
	if Nodes.solid(place_id) and node_box.intersects(player_box): return
	if game.world.set_node(destination,place_id):
		if game.gamemode!="creative": game.inventory.consume_selected()
		game.sound("place")
		swing = 1
		if place_id == Nodes.TORCH: game.add_torch(destination)
		if place_id == Nodes.CHEST and game.world.chest_partner(destination) != destination: game.toast("The chests join into one large chest.")
		game.settle(destination)
		game.progress("build")
		game.api.emit_node_placed(destination,place_id)

# Damage passes through worn armor unless it bypasses it (drowning, starving,
# falling). Every piece worn takes wear from a hit. A source position knocks
# the player away from the attacker.
func hurt(amount: float, bypass_armor: bool = false, source: Vector3 = Vector3.INF) -> void:
	if game.gamemode=="creative" or damage_cooldown > 0 or health <= 0: return
	var reduction: float = 0.0 if bypass_armor else minf(0.8,armor_points()*0.04)
	health = maxf(0,health-amount*(1.0-reduction))
	if not bypass_armor:
		for slot in armor_slots:
			if slot.id == 0: continue
			slot.wear += 1
			if slot.wear >= Nodes.durability(slot.id):
				game.toast("Your "+Nodes.title(slot.id).to_lower()+" broke.")
				slot.id = 0; slot.count = 0; slot.wear = 0
				game.sound("break")
		game.inventory.changed.emit()
	if not is_inf(source.x):
		var away: Vector3 = ((position-source)*Vector3(1,0,1)).normalized()
		velocity.x += away.x*5.5
		velocity.z += away.z*5.5
		velocity.y = maxf(velocity.y,4.0)
	damage_cooldown = 0.65
	game.hud.flash = 0.45
	game.sound("hurt")
	game.api.emit_player_hurt(amount*(1.0-reduction),"" if is_inf(source.x) else str(source.round()))
	if health <= 0: game.die()

func _make_hand(id: int) -> void:
	hand_id = id
	for child in hand.get_children(): child.queue_free()
	if Nodes.is_tool_id(id):
		_add_hand_box(Vector3(0,-0.05,0),Vector3(0.06,0.52,0.06),Color("987343"))
		var kind: int = Nodes.tool_kind(id)
		if kind == 0: _add_hand_box(Vector3(0,0.22,0),Vector3(0.4,0.07,0.08),Nodes.color(id)); _add_hand_box(Vector3(-0.17,0.14,0),Vector3(0.07,0.16,0.08),Nodes.color(id))
		elif kind == 3: _add_hand_box(Vector3(0,0.25,0),Vector3(0.10,0.45,0.07),Nodes.color(id)); _add_hand_box(Vector3(0,0.02,0),Vector3(0.22,0.05,0.08),Nodes.color(id))
		else: _add_hand_box(Vector3(0.03,0.2,0),Vector3(0.21,0.23,0.08),Nodes.color(id))
	elif Nodes.is_armor(id):
		_add_hand_box(Vector3.ZERO,Vector3(0.26,0.22,0.12),Nodes.color(id))
	elif Nodes.placeable(id):
		# The held node is a miniature of the real one, using the terrain atlas.
		var instance := MeshInstance3D.new()
		instance.mesh = game.node_mesh(id)
		instance.material_override = game.node_material
		instance.scale = Vector3.ONE*0.28
		instance.position = Vector3(-0.14,-0.14,-0.14)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hand.add_child(instance)
	elif id != 0:
		_add_hand_box(Vector3.ZERO,Vector3(0.22,0.24,0.08),Nodes.color(id))
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

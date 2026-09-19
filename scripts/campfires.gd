class_name Campfires
extends RefCounted

# Adapted from Mineclonia mcl_campfires/{api,register}.lua. See the source
# comparison and GPL attribution in docs/campfires-source.md.
const LIT = VillageContent.CAMPFIRE
const UNLIT = 1220
const SOUL_LIT = 1221
const SOUL_UNLIT = 1222
const SOUL_SOIL = 1223
const VERSION = 1
const COOK_TIME = 30.0
const HEIGHT = 0.45
const SPOTS = [Vector3(0.25,0.46,0.25),Vector3(0.75,0.46,0.25),Vector3(0.75,0.46,0.75),Vector3(0.25,0.46,0.75)]
const SIDES = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]
const FOOD = {
	Nodes.RAW_MEAT:Nodes.COOKED_MEAT,
	VillageContent.RAW_BEEF:VillageContent.COOKED_BEEF,
	VillageContent.RAW_PORKCHOP:VillageContent.COOKED_PORKCHOP,
	VillageContent.RAW_CHICKEN:VillageContent.COOKED_CHICKEN,
	VillageContent.RAW_MUTTON:VillageContent.COOKED_MUTTON,
	VillageContent.RAW_RABBIT:VillageContent.COOKED_RABBIT,
	VillageContent.RAW_COD:VillageContent.COOKED_COD,
	VillageContent.RAW_SALMON:VillageContent.COOKED_SALMON,
	VillageContent.POTATO:VillageContent.BAKED_POTATO,
	VillageContent.KELP:VillageContent.DRIED_KELP,
}

static func is_campfire(id: int) -> bool: return id in [LIT,UNLIT,SOUL_LIT,SOUL_UNLIT]
static func lit(id: int) -> bool: return id in [LIT,SOUL_LIT]
static func soul(id: int) -> bool: return id in [SOUL_LIT,SOUL_UNLIT]
static func item(id: int) -> int: return SOUL_LIT if soul(id) else LIT
static func unlit(id: int) -> int: return SOUL_UNLIT if soul(id) else UNLIT
static func cookable(id: int) -> bool: return FOOD.has(id)
static func light_level(id: int) -> int: return (10 if soul(id) else 14) if lit(id) else 0
static func damage(id: int) -> int: return (4 if soul(id) else 2) if lit(id) else 0
static func boxes(_id: int) -> Array: return [AABB(Vector3.ZERO,Vector3(1,HEIGHT,1))]
static func empty() -> Dictionary: return {"id":0,"count":0,"wear":0}

static func definitions() -> Dictionary:
	var result: Dictionary = {}
	for id in [LIT,UNLIT,SOUL_LIT,SOUL_UNLIT]:
		result[id] = {"name":("Soul campfire" if soul(id) else "Campfire")+(" (unlit)" if not lit(id) else ""),"block":true,"shape":"campfire","color":"609fa9" if soul(id) else "a46636","hardness":2,"tool":1,"blast_resistance":2,"hidden":not lit(id)}
	result[SOUL_SOIL] = {"name":"Soul soil","block":true,"color":"554236","hardness":0.5,"tool":2,"blast_resistance":0.5}
	return result

static func recipes(inv: Inventory) -> void:
	for log_id in [Nodes.LOG,Nodes.CRIMSON_STEM,Nodes.WARPED_STEM]:
		for fuel in [Nodes.COAL,Nodes.CHARCOAL]:
			if log_id == Nodes.LOG and fuel == Nodes.COAL and inv.recipe_index(LIT) >= 0: continue
			inv._recipe("Campfire",LIT,1,[0,Nodes.STICK,0,Nodes.STICK,fuel,Nodes.STICK,log_id,log_id,log_id],3,"table")
		for soil in [Nodes.SOUL_SAND,SOUL_SOIL]:
			inv._recipe("Soul campfire",SOUL_LIT,1,[0,Nodes.STICK,0,Nodes.STICK,soil,Nodes.STICK,log_id,log_id,log_id],3,"table")

# Mineclonia's group:tree accepts mixed logs, including Nether stems. Keep
# the recipe book's ordinary-log examples while matching actual grid inputs.
static func special_recipe(grid: Array) -> Dictionary:
	if grid.size() != 9: return {}
	var pattern: Array = []
	for stack in grid: pattern.append(int(stack.get("id",0)))
	if pattern[0] != 0 or pattern[2] != 0 or pattern[1] != Nodes.STICK or pattern[3] != Nodes.STICK or pattern[5] != Nodes.STICK: return {}
	for index in [6,7,8]:
		if not WoodTypes.is_log(pattern[index]) and pattern[index] not in [Nodes.CRIMSON_STEM,Nodes.WARPED_STEM]: return {}
	var id: int = 0
	if pattern[4] in [Nodes.COAL,Nodes.CHARCOAL]: id = LIT
	elif pattern[4] in [Nodes.SOUL_SAND,SOUL_SOIL]: id = SOUL_LIT
	else: return {}
	var ingredients: Dictionary = {}
	for ingredient in pattern:
		if ingredient != 0: ingredients[ingredient] = int(ingredients.get(ingredient,0))+1
	return {"name":"Soul campfire" if soul(id) else "Campfire","id":id,"count":1,"pattern":pattern,"width":3,"ingredients":ingredients,"station":"table","dynamic":true}

# Legacy campfires were 3-slot furnaces. Queue every old stack for return;
# never silently reinterpret old fuel or cooked output as an occupied food spot.
# The return queue itself is saved, so a migration before unloading is safe.
static func migrate(state: Dictionary) -> void:
	if int(state.get("campfire_version",0)) == VERSION:
		# JSON saves restore numbers as floats. Reestablish the integer item
		# contract before any item registry/dictionary lookup, retaining data.
		for stack in state.slots: _normalize_stack(stack)
		for stack in state.get("returns",[]): _normalize_stack(stack)
		for index in 4: state.cook[index] = maxf(0,float(state.cook[index]))
		state.damage_clock = maxf(0,float(state.get("damage_clock",0)))
		state.smoke_clock = maxf(0,float(state.get("smoke_clock",0)))
		return
	var returns: Array = state.get("returns",[]).duplicate(true) if state.get("returns",[]) is Array else []
	for stack in state.get("slots",[]):
		if stack is Dictionary and int(stack.get("id",0)) != 0 and int(stack.get("count",0)) > 0: returns.append(stack.duplicate(true))
	state.clear()
	state.merge({"kind":"campfire","campfire_version":VERSION,"slots":[empty(),empty(),empty(),empty()],"cook":[0.0,0.0,0.0,0.0],"returns":returns,"damage_clock":0.0,"smoke_clock":0.0})
	for stack in state.returns: _normalize_stack(stack)

static func _normalize_stack(stack: Dictionary) -> void:
	stack.id = int(stack.get("id",0))
	stack.count = maxi(0,int(stack.get("count",0)))
	stack.wear = maxi(0,int(stack.get("wear",0)))

static func station(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var key: String = VoxelWorld.station_key(p)
	if not world.stations.has(key): world.stations[key] = {}
	var result: Dictionary = world.stations[key]
	migrate(result)
	return result

static func add(state: Dictionary, held: Dictionary, creative: bool = false) -> bool:
	migrate(state)
	if not cookable(int(held.get("id",0))) or int(held.get("count",0)) <= 0: return false
	for index in 4:
		if state.slots[index].id != 0: continue
		state.slots[index] = held.duplicate(true)
		state.slots[index].count = 1
		state.cook[index] = 0.0
		if not creative:
			held.count -= 1
			if held.count <= 0: held.clear(); held.merge(empty())
		return true
	return false

# Source food entities use their own clock, including after the fire is
# smothered. Completion happens on the first tick strictly past cook time.
static func step(state: Dictionary, delta: float) -> Array:
	migrate(state)
	var completed: Array = []
	for index in 4:
		var stack: Dictionary = state.slots[index]
		if stack.id == 0: continue
		state.cook[index] = maxf(0,float(state.cook[index]))+maxf(0,delta)
		if state.cook[index] <= COOK_TIME or not cookable(stack.id): continue
		completed.append({"id":FOOD[int(stack.id)],"count":1,"wear":0,"spot":index})
		state.slots[index] = empty(); state.cook[index] = 0.0
	return completed

static func _drop(world: VoxelWorld, p: Vector3i, stack: Dictionary, spot: int = -1) -> void:
	if int(stack.get("id",0)) == 0 or int(stack.get("count",0)) <= 0: return
	var offset: Vector3 = Vector3(0.5,0.65,0.5) if spot < 0 else SPOTS[spot]+Vector3.UP*0.16
	var drop: ItemDrop = world.get_parent().spawn_drop(Vector3(p)+offset,stack.id,stack.count,int(stack.get("wear",0)),stack.get("data",{}))
	drop.velocity = Vector3((offset.x-0.5)*1.2,2.5,(offset.z-0.5)*1.2)
	drop.pickup_delay = 0.5

static func _return_pending(world: VoxelWorld, p: Vector3i, state: Dictionary) -> void:
	var returns: Array = state.get("returns",[]).duplicate(true)
	state["returns"] = []
	for stack in returns: _drop(world,p,stack)

static func _remove_station(world: VoxelWorld, p: Vector3i) -> void:
	var key: String = VoxelWorld.station_key(p)
	if not world.stations.has(key): return
	var state: Dictionary = world.stations[key]
	migrate(state)
	var drops: Array = state.returns.duplicate(true)
	for stack in state.slots:
		if stack.id != 0 and stack.count > 0: drops.append(stack.duplicate(true))
	world.stations.erase(key)
	for stack in drops: _drop(world,p,stack)

# Invoke after set_node has assigned the new node. Both lit/unlit state changes
# preserve the same four slots; replacing either state returns its contents.
static func changed(world: VoxelWorld, p: Vector3i, old_id: int, new_id: int) -> void:
	if is_campfire(old_id) and not is_campfire(new_id): _remove_station(world,p)
	elif is_campfire(new_id): station(world,p)

static func ignite(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if not is_campfire(id) or lit(id): return false
	station(world,p)
	if not world.set_node(p,item(id)): return false
	world.get_parent().survival.refresh_displays()
	return true

static func smother(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	if not lit(id): return false
	station(world,p)
	if not world.set_node(p,unlit(id)): return false
	world.get_parent().survival.refresh_displays()
	return true

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or not is_campfire(int(target.get("id",0))): return false
	if Input.is_physical_key_pressed(KEY_CTRL) or (game.touch and is_instance_valid(game.controls) and game.controls.sneak_held): return false
	if game.target_mob() != null: return false
	var p: Vector3i = target.pos
	var id: int = game.world.node_at(p)
	var held: Dictionary = game.inventory.held()
	var state: Dictionary = station(game.world,p)
	_return_pending(game.world,p,state)
	if held.id in [Nodes.FLINT_AND_STEEL,PiglinBarter.FIRE_CHARGE]:
		if ignite(game.world,p):
			if game.gamemode != "creative":
				if held.id == PiglinBarter.FIRE_CHARGE: game.inventory.consume_selected()
				else: game.inventory.damage_tool()
			game.sound("place")
		return true
	if lit(id) and Nodes.tool_kind(held.id) == 2:
		if smother(game.world,p):
			if game.gamemode != "creative": game.inventory.damage_tool()
			game.sound("place")
		return true
	if lit(id) and cookable(held.id):
		if add(state,held,game.gamemode == "creative"):
			game.inventory.changed.emit(); game.sound("place"); game.survival.refresh_displays()
		else: game.toast("All four campfire cooking spots are occupied.")
		return true
	# Other items retain normal placement/eating rather than opening a furnace UI.
	return false

static func break_node(game: Node3D, p: Vector3i, id: int, _tool: int = 0, blast: bool = false) -> bool:
	if not is_campfire(id): return false
	if not game.world.set_node(p,Nodes.AIR): return true
	_remove_station(game.world,p) # Also supports callers without a changed hook.
	if not blast:
		if game.gamemode == "creative":
			if game.inventory.count_item(item(id)) == 0 and game.inventory.capacity(item(id)) > 0: game.inventory.add_item(item(id))
		elif Inventory.enchantment(game.inventory.held(),"Silk Touch") > 0 and game.inventory.held().id != VillageContent.ENCHANTED_BOOK:
			_drop(game.world,p,{"id":item(id),"count":1,"wear":0})
		else: _drop(game.world,p,{"id":SOUL_SOIL if soul(id) else Nodes.CHARCOAL,"count":1 if soul(id) else 2,"wear":0})
	game.remove_torch(p)
	game._break_particles(p,id); game.sound("break")
	game.api.emit_node_broken(p,id)
	game.survival.refresh_displays()
	return true

static func smoke_lifetime(world: VoxelWorld, p: Vector3i) -> float:
	return 11.5 if world.node_at(p+Vector3i.DOWN) == Nodes.HAY_BALE else 7.25

static func touching(position: Vector3, p: Vector3i, width: float = 0.29) -> bool:
	return position.y >= p.y-0.1 and position.y <= p.y+HEIGHT+0.08 and position.x+width > p.x and position.x-width < p.x+1 and position.z+width > p.z and position.z-width < p.z+1

static func contact(world: VoxelWorld, p: Vector3i, id: int) -> void:
	if not lit(id): return
	var game: Node3D = world.get_parent()
	var player: VoxeyPlayer = game.player
	if game.gamemode != "creative" and touching(player.position,p) and PotionEffects.level(player,"fire_resistance") == 0:
		player.hurt(damage(id),true,Vector3.INF,"fire")
	for creature in game.creatures.get_children():
		if not creature is Creature or creature.is_queued_for_deletion() or creature.kind in ["blaze","ghast","magma_cube"]: continue
		if touching(creature.position,p,creature.width) and PotionEffects.level(creature,"fire_resistance") == 0: creature.hit(damage(id))

static func update(world: VoxelWorld, delta: float) -> void:
	if delta <= 0: return
	var game: Node3D = world.get_parent()
	for key in world.stations.keys():
		var state: Dictionary = world.stations[key]
		if state.get("kind","") != "campfire" and not (state.get("kind","") == "furnace" and int(state.get("device",0)) == LIT): continue
		var xyz: PackedStringArray = key.split(",")
		if xyz.size() != 3: continue
		var p := Vector3i(int(xyz[0]),int(xyz[1]),int(xyz[2]))
		if not world.loaded_at(Vector3(p)): continue
		var id: int = world.node_at(p)
		if not is_campfire(id):
			_remove_station(world,p)
			continue
		migrate(state); _return_pending(world,p,state)
		var cooked: Array = step(state,delta)
		for stack in cooked: _drop(world,p,stack,int(stack.spot))
		if not cooked.is_empty(): game.survival.refresh_displays()
		if not lit(id): continue
		state.damage_clock = float(state.get("damage_clock",0))+delta
		if state.damage_clock >= 1.0:
			state.damage_clock = fmod(state.damage_clock,1.0); contact(world,p,id)
		state.smoke_clock = float(state.get("smoke_clock",0))+delta
		if state.smoke_clock >= 1.5:
			state.smoke_clock = fmod(state.smoke_clock,1.5)
			if game.player.position.distance_to(Vector3(p)) <= 75:
				var smoke := CampfireSmoke.new()
				smoke.game = game; smoke.dimension = world.dimension
				smoke.max_age = smoke_lifetime(world,p)
				smoke.position = Vector3(p)+Vector3(0.5+randf_range(-0.1,0.1),0.8,0.5+randf_range(-0.1,0.1))
				game.entities.add_child(smoke)

# Splash water affects the hit fire and four horizontal neighbors. Lingering
# water covers its horizontal radius. No rain/adjacent-water rule is invented.
static func water_splash(world: VoxelWorld, position: Vector3, radius: float = -1) -> int:
	var center := Vector3i(position.floor())
	if not lit(world.node_at(center)) and lit(world.node_at(center+Vector3i.DOWN)): center += Vector3i.DOWN
	var points: Array = [center]
	if radius < 0:
		for side in SIDES: points.append(center+side)
	else:
		points.clear()
		for x in range(-ceili(radius),ceili(radius)+1):
			for z in range(-ceili(radius),ceili(radius)+1): points.append(center+Vector3i(x,0,z))
	var changed_count: int = 0
	for p in points:
		if smother(world,p): changed_count += 1
	return changed_count

static func display_model(game: Node3D, p: Vector3i, state: Dictionary) -> Node3D:
	var model := Node3D.new()
	model.position = Vector3(p)
	var id: int = game.world.node_at(p)
	migrate(state)
	for index in 4:
		var food: Dictionary = state.slots[index]
		if food.id == 0: continue
		var mesh := MeshInstance3D.new()
		mesh.mesh = ItemArt.mesh(food.id); mesh.material_override = ItemArt.material(food.id)
		mesh.scale = Vector3.ONE*0.25; mesh.rotation.x = -PI/2
		mesh.position = SPOTS[index]+Vector3.UP*0.03
		model.add_child(mesh)
	if lit(id):
		var light := OmniLight3D.new()
		light.position = Vector3(0.5,0.8,0.5)
		light.light_color = Color("70cde0") if soul(id) else Color("ffb769")
		light.light_energy = 0.6 if soul(id) else 0.85
		light.omni_range = 4.5 if soul(id) else 6.0
		model.add_child(light)
	return model

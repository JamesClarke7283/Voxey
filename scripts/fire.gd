class_name Fire
extends RefCounted
const FLAME = 1117
const ETERNAL = 1118
const SIDES = [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.UP,Vector3i.DOWN,Vector3i.FORWARD,Vector3i.BACK]

static func is_fire(id: int) -> bool: return id in [FLAME,ETERNAL]

static func flammable(id: int) -> bool:
	if BuildingShapes.is_shape(id): return flammable(BuildingShapes.material(id))
	if VillageContent.DATA.get(id,{}).has("flammable"): return bool(VillageContent.DATA[id].flammable)
	return id in [Nodes.TNT,Nodes.COAL_BLOCK,Nodes.LOG,Nodes.PLANKS,Nodes.LEAVES,Nodes.WOOL,Nodes.BOOKSHELF,Nodes.HAY_BALE,Nodes.CHEST,Nodes.WORKBENCH,Nodes.SAPLING,Nodes.WHEAT,Nodes.RIPE_WHEAT,Nodes.VINE] or VillageContent.DATA.get(id,{}).get("family","") in ["wool","carpet","banner"]

static func track(world: VoxelWorld, p: Vector3i) -> void:
	var id: int = world.node_at(p)
	if is_fire(id) or Fluids.lava(id) and not nearby_fuel(world,p).is_empty(): world.hazards[p] = id
	else: world.hazards.erase(p)

static func nearby_fuel(world: VoxelWorld, p: Vector3i) -> Array:
	var fuel: Array = []
	for side in SIDES:
		if flammable(world.node_at(p+side)): fuel.append(p+side)
	return fuel

static func ignite(world: VoxelWorld, p: Vector3i) -> bool:
	if world.node_at(p) != Nodes.AIR: return false
	if world.ignite_portal(p): return true
	var support: int = world.node_at(p+Vector3i.DOWN)
	if not Nodes.solid(support) and nearby_fuel(world,p).is_empty(): return false
	return world.set_node(p,ETERNAL if support == Nodes.NETHERRACK or support == Nodes.BEDROCK and world.dimension == "end" else FLAME)

static func use(game: Node3D, target: Dictionary) -> bool:
	var held: int = game.inventory.held().id
	if held not in [Nodes.FLINT_AND_STEEL,PiglinBarter.FIRE_CHARGE] or target.is_empty(): return false
	var ignited: bool = false
	if target.id == Nodes.TNT: game.ignite_tnt(target.pos); ignited = true
	else: ignited = ignite(game.world,target.pos+target.normal)
	if ignited and game.gamemode != "creative":
		if held == PiglinBarter.FIRE_CHARGE: game.inventory.consume_selected()
		else: game.inventory.damage_tool()
	if ignited: game.sound("place")
	return true

# Active-second clocks preserve Mineclonia's fire ABM intervals/chances.
static func update(world: VoxelWorld) -> void:
	var ticks: int = int(world.adventure_state.get("fire_clock",0))+1
	world.adventure_state["fire_clock"] = ticks
	for p in world.hazards.keys():
		var id: int = world.node_at(p)
		if not Fluids.lava(id) and not is_fire(id): world.hazards.erase(p); continue
		if Fluids.lava(id):
			if ticks%15 == 0 and randi_range(1,9) == 1:
				for y in [1,2]:
					var q: Vector3i = p+Vector3i(randi_range(-y,y),y,randi_range(-y,y))
					if not nearby_fuel(world,q).is_empty(): ignite(world,q); break
			continue
		var wet: bool = false
		for side in SIDES:
			if Fluids.water(world.node_at(p+side)): wet = true
		if id == FLAME and world.dimension == "overworld" and world.adventure_state.get("weather","clear") != "clear" and world.open_sky(p): wet = true
		if wet: world.set_node(p,Nodes.AIR); continue
		var fuel: Array = nearby_fuel(world,p)
		if ticks%7 == 0:
			if fuel.is_empty() and id == FLAME and randi_range(1,3) == 1: world.set_node(p,Nodes.AIR); continue
			if not fuel.is_empty() and randi_range(1,12) == 1:
				var q: Vector3i = p+Vector3i(randi_range(-1,1),randi_range(-1,4),randi_range(-1,1))
				if not nearby_fuel(world,q).is_empty(): ignite(world,q)
		if ticks%5 == 0 and not fuel.is_empty() and randi_range(1,18) == 1:
			var q: Vector3i = fuel[randi_range(0,fuel.size()-1)]
			if world.node_at(q) == Nodes.TNT: world.get_parent().ignite_tnt(q)
			else:
				# Burn storage through its normal break path so metadata is retained.
				if world.stations.has(world.station_key(q)): world.get_parent().break_node(q,world.node_at(q),0)
				world.set_node(q,Nodes.AIR); ignite(world,q)

class_name FoodFeatures
extends RefCounted

# Local Mineclonia mcl_cake, mcl_sus_stew, mcl_flowers and mcl_end.
const CAKE = VillageContent.CAKE
const SLICE_BASE = 5600 # One through six remaining slices; whole cake keeps 779.
const POPPY = 5610
const DANDELION = 5611
const OXEYE_DAISY = 5612
# Tall grass, which the source's bone meal grows on a grass block. It is the most
# common result of that interaction by a wide margin: ninety percent of the plants
# the source scatters are tall grass and only ten percent are flowers.
const TALL_GRASS = 5613
const DATA = {
	POPPY:{"name":"Poppy","block":true,"shape":"plant","color":"d84b4b","hardness":0.0,"flammable":true},
	DANDELION:{"name":"Dandelion","block":true,"shape":"plant","color":"efc642","hardness":0.0,"flammable":true},
	OXEYE_DAISY:{"name":"Oxeye daisy","block":true,"shape":"plant","color":"eee5d2","hardness":0.0,"flammable":true},
	TALL_GRASS:{"name":"Tall grass","block":true,"shape":"plant","color":"6fa03c","hardness":0.0,"flammable":true,"compostability":30,"seeds":true},
}
const FLOWERS = {POPPY:"night_vision",DANDELION:"saturation",OXEYE_DAISY:"regeneration"}
# Keep the source metadata vocabulary, including legacy imported stew effects.
const STEW_EFFECTS = {"night_vision":5.0,"saturation":0.5,"regeneration":8.0,"weakness":9.0,"fire_resistance":4.0,"blindness":8.0,"withering":8.0,"poison":12.0,"leaping":6.0}
static var icons: Dictionary = {}

# A candled cake (`mcl_candles:candle_cake`) is still a cake: it is eaten slice by
# slice and drawn as a whole cake, with the candles on top.
static func is_cake(id: int) -> bool: return id == CAKE or id >= SLICE_BASE and id < SLICE_BASE+6 or Candles.is_cake(id)
static func slices(id: int) -> int: return 7 if id == CAKE or Candles.is_cake(id) else (id-SLICE_BASE+1 if is_cake(id) else 0)
static func cake_id(count: int) -> int: return CAKE if count == 7 else (SLICE_BASE+count-1 if count > 0 else Nodes.AIR)
static func title(id: int) -> String: return "Cake" if id == CAKE else "Cake (%d slices)"%slices(id)
# The ten flower species added by `FlowersExtra` are flowers in every sense the
# rest of the game means, so they join the same registry.
static func flower(id: int) -> bool: return FLOWERS.has(id) or FlowersExtra.is_flower(id)
# Tall grass is a plant like a flower, but not a flower: it has no stew effect and
# no dye. The distinction matters because the source scatters both from one roll.
static func is_tall_grass(id: int) -> bool: return id == TALL_GRASS
# The small plants behave like tall grass for support and decoration.
static func is_extra_plant(id: int) -> bool: return FlowersExtra.is_plant(id)
static func plantlike(id: int) -> bool: return flower(id) or is_tall_grass(id)
static func natural_flower(sample: int) -> int: return [POPPY,POPPY,DANDELION,OXEYE_DAISY][posmod(sample,4)]

static func flower_pixel(id: int, x: int, y: int) -> Color:
	var dx: int = x-7; var dy: int = y-5
	var petals: bool = absi(dx)+absi(dy) <= (5 if id == OXEYE_DAISY else 4)
	if id == POPPY: petals = x in range(3,12) and y in range(2,8) and not (x in [3,11] and y in [2,7])
	if petals:
		if dx*dx+dy*dy < 3: return Color("624d32") if id == POPPY else Color("e5b63c")
		return Color(DATA[id].color).lightened(0.12 if (x+y)%3 == 0 else 0)
	if x in [7,8] and y in range(7,16) or y in [11,12] and x in [5,6,9,10]: return Color("548448")
	return Color.TRANSPARENT

static func draw_flower(img: Image, id: int) -> void:
	for y in 16:
		for x in 16: img.set_pixel(x,y,flower_pixel(id,x,y))

# Tall grass is a tuft of blades rather than a bloom: several vertical strokes of
# differing height, so it reads as grass and not as a flower missing its petals.
static func tall_grass_pixel(x: int, y: int) -> Color:
	var base: Color = Color(DATA[TALL_GRASS].color)
	# Each blade has its own x, height and lean, so the tuft looks uneven.
	for blade in [[5,9,-1],[7,12,0],[9,10,1],[11,7,1],[3,6,-1],[13,8,0]]:
		var bx: int = blade[0]; var top: int = 15-blade[1]
		var lean: int = (15-y)/4*blade[2]
		if x == bx+lean and y >= top: return base.darkened(0.12 if (x+y)%4 == 0 else 0.0)
	return Color.TRANSPARENT

static func draw_tall_grass(img: Image) -> void:
	for y in 16:
		for x in 16: img.set_pixel(x,y,tall_grass_pixel(x,y))

static func boxes(id: int) -> Array:
	return [AABB(Vector3(0.0625,0,0.0625),Vector3(slices(id)*0.125,0.5,0.875))] if is_cake(id) else []

static func mesh(out: Array, at: Vector3, id: int) -> void:
	if not is_cake(id): return
	# A candled cake draws its cake body first, then the candle standing in it.
	if Candles.is_cake(id): Candles.candles_on(out,at,id)
	var width: float = slices(id)*0.125
	# Original Voxey geometric art: sponge, cream, icing and inset berries.
	for band in [[0.0,0.19,VillageContent.WOOL_BROWN],[0.19,0.08,Nodes.WOOL],[0.27,0.14,VillageContent.WOOL_BROWN],[0.41,0.09,Nodes.WOOL]]:
		BlockMesher._art_box(out,at+Vector3(0.0625+width*0.5,band[0]+band[1]*0.5,0.5),Vector3(width,band[1],0.875),Nodes.tile(band[2],0),Nodes.tile(band[2],0))
	for x in slices(id):
		for z in [0.24,0.50,0.76]:
			BlockMesher._art_box(out,at+Vector3(0.125+x*0.125,0.496,z),Vector3(0.055,0.008,0.065),Nodes.tile(VillageContent.WOOL_RED,0),Nodes.tile(VillageContent.WOOL_RED,0))

static func icon_faces(id: int) -> Array:
	if not icons.has(id):
		var out: Array = BlockMesher._empty(); mesh(out,Vector3.ZERO,id)
		icons[id] = Barriers.project_icon(out)
	return icons[id]

static func supported(world: VoxelWorld, at: Vector3i) -> bool:
	return world.loaded_at(Vector3(at+Vector3i.DOWN)) and Nodes.solid(world.node_at(at+Vector3i.DOWN))

static func changed(world: VoxelWorld, p: Vector3i) -> void:
	if PistonPush.defer_support(world,p): return
	for at in [p,p+Vector3i.UP]:
		var id: int = world.node_at(at)
		if not world.loaded_at(Vector3(at)): continue
		if is_cake(id) and not supported(world,at): world.set_node(at,Nodes.AIR)
		elif (flower(id) or is_tall_grass(id)) and not Farmland.is_soil(world.node_at(at+Vector3i.DOWN)) and world.node_at(at+Vector3i.DOWN) not in [Nodes.DIRT,Nodes.GRASS]:
			if world.set_node(at,Nodes.AIR):
				var game: Node = world.get_parent()
				if game != null and game.has_method("spawn_drop"): game.spawn_drop(Vector3(at)+Vector3.ONE*0.5,id,1)

static func use(game: Node3D, target: Dictionary) -> bool:
	if target.is_empty() or not is_cake(int(target.id)): return false
	if game.target_mob() != null or Input.is_physical_key_pressed(KEY_CTRL) or game.touch and is_instance_valid(game.controls) and game.controls.sneak_held: return false
	var id: int = game.world.node_at(target.pos)
	if not is_cake(id): return true
	if game.player.hunger >= 20 and game.gamemode != "creative": return true
	if game.world.set_node(target.pos,cake_id(slices(id)-1)):
		Hunger.restore_food(game.player,2,0.4)
		game.sound("eat"); game.player.swing = 1
	return true

static func try_place(game: Node3D, target: Dictionary) -> bool:
	var held: Dictionary = game.inventory.held()
	if not is_cake(int(held.id)): return false
	if held.id != CAKE or held.count <= 0 or target.is_empty(): return true
	var at: Vector3i = SnowCover.placement(game.world,target).pos
	if not SnowCover.replaceable(game.world.node_at(at)) or not supported(game.world,at): return true
	var body := AABB(game.player.position-Vector3(0.29,0,0.29),Vector3(0.58,1.8,0.58))
	for box in boxes(CAKE):
		if body.intersects(AABB(Vector3(at)+box.position,box.size)): return true
	if game.world.set_node(at,CAKE):
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("place"); game.player.swing = 1; game.api.emit_node_placed(at,CAKE)
	return true

static func flower_supported(world: VoxelWorld, p: Vector3i) -> bool:
	if not Farmland.is_soil(world.node_at(p+Vector3i.DOWN)) and world.node_at(p+Vector3i.DOWN) not in [Nodes.DIRT,Nodes.GRASS]: return false
	# The source accepts artificial light eight, or unobstructed daytime sky.
	if Pasture.block_light(world,p,8) >= 8: return true
	if world.dimension != "overworld" or not world.loaded_at(Vector3(p)): return false
	RedstoneSensors.natural_light(world,p) # Prepare the shared geometry cache.
	return RedstoneSensors._natural_light(world,p,14) >= 14

static func bone_meal(game: Node3D, p: Vector3i, rng: RandomNumberGenerator = null) -> bool:
	var id: int = game.world.node_at(p)
	if not flower(id): return false
	var placed: bool = false
	# Source scans grass under air within +/-3 XZ and +/-2 Y, then 20% each.
	for x in range(p.x-3,p.x+4):
		for z in range(p.z-3,p.z+4):
			for y in range(p.y-2,p.y+3):
				var soil := Vector3i(x,y,z)
				if not game.world.loaded_at(Vector3(soil)) or game.world.node_at(soil) != Nodes.GRASS or game.world.node_at(soil+Vector3i.UP) != Nodes.AIR: continue
				var roll: int = rng.randi_range(1,100) if rng != null else randi_range(1,100)
				if roll <= 20: placed = game.world.set_node(soil+Vector3i.UP,id) or placed
	return placed

# Bone meal on a **grass block**, which is the source's `mcl_core.bone_meal_grass`.
# This is a different rule from the flower spread above: it scans a 15x15 area and
# grows a mix of tall grass and flowers, where the flower rule only spreads the one
# flower it was used on.
#
# The source's own numbers:
#
#   * a 15x15 area (i in -7..7, j in -7..7) over three heights,
#   * a density test `90 / ((|i| + |j|) / 2)`, so the growth thins out from the
#     centre and a far corner is far less likely than the block underfoot,
#   * then 90% tall grass and 10% a flower.
static func bone_meal_grass(game: Node3D, p: Vector3i, rng: RandomNumberGenerator = null) -> bool:
	var placed: bool = false
	for i in range(-7,8):
		for j in range(-7,8):
			for y in range(0,3):
				var at := p+Vector3i(i,y,j)
				if game.world.node_at(at) != Nodes.AIR: continue
				if game.world.node_at(at+Vector3i.DOWN) != Nodes.GRASS: continue
				if not game.world.loaded_at(Vector3(at)): continue
				# `(|i| + |j|) / 2` is zero underfoot, so guard the division.
				var distance: float = (absi(i)+absi(j))/2.0
				var density: float = 90.0 if distance < 1.0 else 90.0/distance
				var roll: int = rng.randi_range(1,100) if rng != null else randi_range(1,100)
				if roll > int(density): continue
				var pick: int = rng.randi_range(1,100) if rng != null else randi_range(1,100)
				var growth: int = TALL_GRASS if pick <= 90 else natural_flower(pick)
				placed = game.world.set_node(at,growth) or placed
	return placed

static func recipes(inv: Inventory) -> void:
	for id in FLOWERS:
		inv._shapeless("Suspicious stew ("+DATA[id].name.to_lower()+")",VillageContent.SUSPICIOUS_STEW,1,[Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,Nodes.BOWL,id])
		var dye: int = {POPPY:VillageContent.DYE_RED,DANDELION:VillageContent.DYE_YELLOW,OXEYE_DAISY:VillageContent.DYE_SILVER}[id]
		inv._recipe(Nodes.title(dye),dye,1,[id],1)
	# The added species use their own source dye colours and stew effects, which
	# `FlowersExtra` carries from the reference.
	for id in FlowersExtra.FLOWERS:
		inv._shapeless("Suspicious stew ("+VillageContent.DATA[id].name.to_lower()+")",VillageContent.SUSPICIOUS_STEW,1,[Nodes.RED_MUSHROOM,Nodes.BROWN_MUSHROOM,Nodes.BOWL,id])
		inv._recipe(Nodes.title(FlowersExtra.dye_of(id)),FlowersExtra.dye_of(id),1,[id],1)

static func clean_stew_data(raw: Dictionary) -> Dictionary:
	var effect: String = str(raw.get("effect",""))
	if effect == "jump": effect = "leaping"
	return {"effect":effect} if STEW_EFFECTS.has(effect) else {}

static func craft_data(ingredients: Array) -> Dictionary:
	for ingredient in ingredients:
		if not ingredient is Dictionary: continue
		var id: int = int(ingredient.get("id",0))
		if FLOWERS.has(id): return {"effect":FLOWERS[id]}
		if FlowersExtra.is_flower(id): return {"effect":FlowersExtra.stew_effect(id)}
	return {}

static func on_eat(player: VoxeyPlayer, id: int, data: Dictionary) -> void:
	if id == Nodes.CHORUS_FRUIT:
		var destination: Vector3 = chorus_destination(player.game.world,player.position)
		if destination.is_finite():
			player.game.survival.mount = null
			player.game.teleport(destination); player.game.sound("portal")
	elif id == VillageContent.SUSPICIOUS_STEW:
		var clean: Dictionary = clean_stew_data(data)
		if clean.has("effect"): PotionEffects.apply(player,clean.effect,STEW_EFFECTS[clean.effect])

static func chorus_safe(world: VoxelWorld, p: Vector3i) -> bool:
	var id: int = world.node_at(p)
	return world.loaded_at(Vector3(p)) and not Nodes.solid(id) and not Fluids.liquid(id) and not Fluids.contains(world,Vector3(p)+Vector3.ONE*0.5,Nodes.WATER) and not Fire.is_fire(id) and not Campfires.lit(id)

static func chorus_attempt(world: VoxelWorld, start: Vector3i) -> Vector3:
	for down in 17:
		var ground: Vector3i = start+Vector3i.DOWN*down
		if not world.loaded_at(Vector3(ground)) or not WorldBounds.horizontal(ground) or ground.y < world.generator.min_y() or ground.y+2 >= world.generator.max_y(): return Vector3.INF
		if world.dimension == "nether" and ground.y >= TerrainGenerator.NETHER_HEIGHT-1: return Vector3.INF
		var id: int = world.node_at(ground)
		if not Nodes.solid(id): continue
		# Source scan cache must contain two safe spaces above the first ground.
		if down < 2 or id == Nodes.CACTUS or Campfires.lit(id): return Vector3.INF
		var feet: Vector3i = ground+Vector3i.UP
		if not chorus_safe(world,feet) or not chorus_safe(world,feet+Vector3i.UP): return Vector3.INF
		for side in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
			if world.node_at(feet+side) == Nodes.CACTUS: return Vector3.INF
		var at: Vector3 = Vector3(feet)+Vector3(0.5,0,0.5)
		return Vector3.INF if world.intersects(at) else at
	return Vector3.INF

static func chorus_destination(world: VoxelWorld, origin: Vector3, rng: RandomNumberGenerator = null) -> Vector3:
	if world.dimension == "nether" and origin.y >= TerrainGenerator.NETHER_HEIGHT: return Vector3.INF
	var center := Vector3i(roundi(origin.x-0.5),ceili(origin.y),roundi(origin.z-0.5))
	for attempt in 16:
		var start: Vector3i = center
		for axis in 3: start[axis] += rng.randi_range(-8,8) if rng != null else randi_range(-8,8)
		var at: Vector3 = chorus_attempt(world,start)
		if at.is_finite(): return at
	return Vector3.INF

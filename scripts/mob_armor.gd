class_name MobArmor
extends RefCounted

const COPPER_HELMET = 11568
const KINDS = ["zombie","husk","drowned","zombie_villager","skeleton","stray","wither_skeleton"]
const GENERATED = ["zombie","husk","zombie_villager","skeleton","stray"]

static func handles(kind: String) -> bool: return kind in KINDS
static func copper(id: int) -> bool: return id >= COPPER_HELMET and id < COPPER_HELMET+4

static func empty_slots() -> Array:
	return [{"id":0,"count":0,"wear":0},{"id":0,"count":0,"wear":0},{"id":0,"count":0,"wear":0},{"id":0,"count":0,"wear":0}]

static func rng_for(world: VoxelWorld) -> EnchantRolls:
	if not world.has_meta("mob_armor_rng"):
		var native := RandomNumberGenerator.new(); native.seed = world.seed_value+18377
		world.set_meta("mob_armor_rng",EnchantRolls.new(1,native))
	return world.get_meta("mob_armor_rng")

static func material_item(level: int, piece: int) -> int:
	match level:
		1: return Nodes.armor_id(0,piece)
		2: return COPPER_HELMET+piece
		3: return Nodes.armor_id(2,piece)
		4: return VillageContent.CHAIN_HELMET+piece
		5: return Nodes.armor_id(1,piece)
		6: return Nodes.armor_id(3,piece)
	return 0

# mcl_mobs:generate_default_equipment's armor branch. The source never sets
# armor_generated true, so its stop roll is tested at every slot.
static func generate(factor: float, difficulty: int, rng: EnchantRolls) -> Dictionary:
	var result: Dictionary = {"slots":empty_slots(),"drops":[0.0,0.0,0.0,0.0]}
	if rng.unit() >= factor*0.15: return result
	var level: int = rng.integer(1,3)
	for i in 3:
		if rng.unit() < 0.095: level += 1
	for piece in 4:
		if rng.integer(1,10 if difficulty == 3 else 4) == 1: break
		var item: Dictionary = {"id":material_item(level,piece),"count":1,"wear":0}
		if rng.unit() < factor*0.5:
			var enchanted: Dictionary = Enchanting.generate_reliable(item,floorf(5+factor*rng.integer(1,18)),rng)
			if not enchanted.is_empty(): item.data = {"enchantments":enchanted.enchantments}
		result.slots[piece] = item; result.drops[piece] = 0.085
	return result

static func initialize(mob: Creature) -> void:
	if mob.mob_armor_ready or not handles(mob.kind): return
	mob.mob_armor_ready = true; mob.mob_armor = empty_slots(); mob.mob_armor_drops = [0.0,0.0,0.0,0.0]
	var rng: EnchantRolls = rng_for(mob.game.world)
	var factor: float = RegionalDifficulty.special(mob.game,mob.position)
	mob.mob_armor_pickup = rng.unit() < 0.55*factor
	if mob.kind in GENERATED:
		var equipment: Dictionary = generate(factor,RegionalDifficulty.source_level(mob.game.difficulty),rng)
		mob.mob_armor = equipment.slots; mob.mob_armor_drops = equipment.drops
	var date: Dictionary = Time.get_date_dict_from_system()
	halloween(mob,date.month == 10 and date.day == 31,rng)

static func halloween(mob: Creature, today: bool, rng: EnchantRolls) -> void:
	if today and mob.mob_armor[0].id == 0 and rng.unit() < 0.25:
		mob.mob_armor[0] = {"id":FruitCrops.JACK if rng.unit() < 0.1 else FruitCrops.CARVED,"count":1,"wear":0}

static func better(candidate: Dictionary, current: Dictionary) -> bool:
	if int(current.get("id",0)) == 0: return true
	if Inventory.enchantment(current,"Curse of Binding") > 0: return false
	if Nodes.armor_points(current.id) < Nodes.armor_points(candidate.id): return true
	if Nodes.armor_toughness(current.id) < Nodes.armor_toughness(candidate.id): return true
	if Durability.uses(current) < Durability.uses(candidate): return true
	return current.get("data",{}).get("enchantments",{}).is_empty() and not candidate.get("data",{}).get("enchantments",{}).is_empty()

static func piece(id: int) -> int:
	if id == FruitCrops.CARVED or Heads.is_head(id): return 0
	return Nodes.armor_piece(id) if Nodes.is_armor(id) and id != Nodes.ELYTRA else -1

static func equip(mob: Creature, item: Dictionary, dispenser: bool = false, sample: float = -1) -> bool:
	if not handles(mob.kind): return false
	initialize(mob)
	var index: int = piece(int(item.get("id",0)))
	if index < 0 or index > 3 or not dispenser and not mob.mob_armor_pickup: return false
	var old: Dictionary = mob.mob_armor[index]
	if dispenser and old.id != 0 or not dispenser and not better(item,old): return false
	if old.id != 0:
		var roll: float = rng_for(mob.game.world).unit() if sample < 0 else sample
		if maxf(0,roll-0.1) < float(mob.mob_armor_drops[index]):
			mob.game.spawn_drop(mob.center(),old.id,1,int(old.wear),old.get("data",{}))
	mob.mob_armor[index] = Inventory.clean_slot(item); mob.mob_armor[index].count = 1
	mob.mob_armor_drops[index] = 2.0; mob.set_meta("persistent",true)
	refresh(mob); Farming.remember(mob)
	return true

static func pickup(mob: Creature) -> void:
	if not mob.mob_armor_pickup: return
	for drop in mob.game.drops.get_children():
		if not drop is ItemDrop or drop.is_queued_for_deletion() or drop.age < 1.0 or drop.position.distance_to(mob.position) > 1.95: continue
		if equip(mob,{"id":drop.item_id,"count":1,"wear":drop.wear,"data":drop.data}):
			drop.amount -= 1
			if drop.amount <= 0: drop.queue_free()

static func dropped(item: Dictionary, probability: float, looting: int, rng: EnchantRolls, sample: float = -1, uses: float = -1) -> Dictionary:
	if probability <= 0 or item.get("id",0) == 0: return {}
	if (rng.unit() if sample < 0 else sample) > probability+looting*0.01 or Inventory.enchantment(item,"Curse of Vanishing") > 0: return {}
	var result: Dictionary = item.duplicate(true)
	if uses < 0: uses = Durability.uses(result)
	if probability <= 1 and uses > 0:
		var first: int = rng.integer(0,maxi(0,floori(uses)-4))
		Durability.set_normalized(result,Durability.normalized(result)+floori(65535.0/uses*rng.integer(0,first)))
	return result if result.id != 0 else {}

static func die(mob: Creature, minimum_probability: float = 0) -> void:
	for index in 4:
		if float(mob.mob_armor_drops[index]) < minimum_probability: continue
		var item: Dictionary = dropped(mob.mob_armor[index],mob.mob_armor_drops[index],int(mob.get_meta("looting",0)),rng_for(mob.game.world))
		if not item.is_empty(): mob.game.spawn_drop(mob.center(),item.id,1,int(item.wear),item.get("data",{}))

static func absorb(mob: Creature, damage: float, cause: String, attacker: Node3D, breach: int = 0) -> float:
	var reflect: Callable = func(amount: int) -> bool:
		if not is_instance_valid(attacker) or attacker == mob: return false
		if attacker is Creature: attacker.hit(amount,mob.position,"thorns",0,mob)
		elif attacker is VoxeyPlayer: attacker.hurt(amount,false,mob.position,"thorns",mob)
		else: return false
		return is_instance_valid(attacker) and not attacker.is_queued_for_deletion()
	var result: Dictionary = ArmorEffects.resolve(mob.mob_armor,damage,ArmorEffects.flags(cause),cause,is_instance_valid(attacker) and (attacker is Creature or attacker is VoxeyPlayer),rng_for(mob.game.world),[0,1,2,3],reflect,breach,attacker == mob)
	if not result.broken.is_empty(): refresh(mob)
	return result.damage

static func sunlight_wear(slots: Array, gate: bool, wear_gate: bool) -> bool:
	if not gate: return false
	if slots[0].id == 0: return true
	if wear_gate: Durability.use(slots[0])
	return false

static func sunlight(mob: Creature, delta: float) -> void:
	if not mob.info().get("burns",false) or mob.game.dimension != "overworld" or mob.game.daylight < 0.8: return
	var eye: Vector3i = Vector3i((mob.position+Vector3.UP*1.74).floor())
	if not mob.game.world.open_sky(eye) or Weather.exposed_to_rain(mob.game.world,eye) or Fluids.water(mob.game.world.node_at(eye)) or Fluids.water(mob.game.world.node_at(Vector3i(mob.position.floor()))): return
	var rng: EnchantRolls = rng_for(mob.game.world)
	# The reference passes (dtime, 30) into scale_chance(frequency, dtime).
	var gate: bool = rng.integer(1,maxi(2,floori(delta*(0.05/30.0)+0.5))) == 1
	var before: int = mob.mob_armor[0].id
	if sunlight_wear(mob.mob_armor,gate,gate and before != 0 and rng.integer(1,2) == 1): PotionEffects.apply(mob,"burning",10.0)
	if before != mob.mob_armor[0].id: refresh(mob)

static func box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> void:
	var model := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = size; model.mesh = mesh; model.position = position
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = 0.65
	model.material_override = material; parent.add_child(model)

static func refresh(mob: Creature) -> void:
	if mob.model == null: return
	for old in mob.mob_armor_models:
		if is_instance_valid(old): old.queue_free()
	mob.mob_armor_models = []
	for index in 4:
		var item: Dictionary = mob.mob_armor[index]
		if item.id == 0: continue
		var color: Color = Nodes.color(item.id)
		var parent: Node3D = mob.head if index == 0 and mob.head != null else mob.model
		var root := Node3D.new(); root.name = "Armor"+str(index); parent.add_child(root); mob.mob_armor_models.append(root)
		if index == 0:
			if item.id in [FruitCrops.CARVED,FruitCrops.JACK] or Heads.is_head(item.id):
				var pumpkin := MeshInstance3D.new(); pumpkin.mesh = mob.game.node_mesh(item.id); pumpkin.material_override = mob.game.node_material
				pumpkin.scale = Vector3.ONE*0.52; pumpkin.position = Vector3(-0.26,-0.07,-0.26); root.add_child(pumpkin)
			else:
				box(root,Vector3(0,0.34,0),Vector3(0.46,0.12,0.44),color)
				for side in [-1,1]: box(root,Vector3(side*0.215,0.18,0.015),Vector3(0.05,0.26,0.41),color)
				box(root,Vector3(0,0.18,0.2),Vector3(0.4,0.27,0.05),color)
		elif index == 1:
			box(root,Vector3(0,1.06,0),Vector3(0.5,0.54,0.34),color)
			for arm in mob.arms:
				var pad := Node3D.new(); arm.add_child(pad); mob.mob_armor_models.append(pad)
				box(pad,Vector3(0,-0.09,0),Vector3(0.23,0.24,0.25),color)
		else:
			if index == 2: box(root,Vector3(0,0.77,0),Vector3(0.39,0.15,0.29),color)
			for leg in mob.legs:
				var cover := Node3D.new(); leg.add_child(cover); mob.mob_armor_models.append(cover)
				box(cover,Vector3(0,-0.3 if index == 2 else -0.63,0),Vector3(0.22,0.48,0.25) if index == 2 else Vector3(0.24,0.24,0.32),color)

static func snapshot(mob: Creature) -> Dictionary:
	return {"slots":mob.mob_armor.duplicate(true),"drops":mob.mob_armor_drops.duplicate(),"pickup":mob.mob_armor_pickup}

static func restore(mob: Creature, data: Dictionary) -> void:
	initialize(mob)
	if data.get("slots") is Array and data.slots.size() == 4:
		mob.mob_armor = []
		for item in data.slots: mob.mob_armor.append(Inventory.clean_slot(item))
	if data.get("drops") is Array and data.drops.size() == 4:
		mob.mob_armor_drops = data.drops.map(func(value): return clampf(float(value),0,2))
	mob.mob_armor_pickup = bool(data.get("pickup",mob.mob_armor_pickup)); refresh(mob)

static func recipes(inv: Inventory) -> void:
	var m: int = Nodes.COPPER
	var patterns: Array = [[m,m,m,m,0,m,0,0,0],[m,0,m,m,m,m,m,m,m],[m,m,m,m,0,m,m,0,m],[m,0,m,m,0,m,0,0,0]]
	for index in 4: inv._recipe(Nodes.title(COPPER_HELMET+index),COPPER_HELMET+index,1,patterns[index],3,"table")

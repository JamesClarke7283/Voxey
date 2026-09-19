class_name Hunger
extends RefCounted

# Mineclonia mcl_hunger uses exhaustion units 1000 times Minecraft's units.
const INITIAL_SATURATION = 5.0
const EXHAUST_LEVEL = 4000.0
const DIG = 5.0
const JUMP = 50.0
const SPRINT_JUMP = 200.0
const ATTACK = 100.0
const SWIM = 10.0
const SPRINT = 100.0
const DAMAGE = 100.0
const REGEN = 6000.0

static func reset(player: VoxeyPlayer) -> void:
	player.hunger = 20.0
	player.saturation = INITIAL_SATURATION
	player.exhaustion = 0.0
	player.food_timer = 0.0
	player.sprint_distance = 0.0
	player.swim_distance = 0.0
	player.eating.clear()

static func snapshot(player: VoxeyPlayer) -> Dictionary:
	return {"saturation":player.saturation,"exhaustion":player.exhaustion}

static func restore(player: VoxeyPlayer, value: Variant) -> void:
	var saved: Dictionary = value if value is Dictionary else {}
	player.saturation = _number(saved.get("saturation"),INITIAL_SATURATION,player.hunger)
	player.exhaustion = _number(saved.get("exhaustion"),0.0,EXHAUST_LEVEL)
	player.food_timer = 0.0
	player.sprint_distance = 0.0
	player.swim_distance = 0.0
	player.eating.clear()

static func _number(value: Variant, fallback: float, maximum: float) -> float:
	if not (value is int or value is float) or not is_finite(float(value)): return clampf(fallback,0,maximum)
	return clampf(float(value),0,maximum)

static func exhaust(player: VoxeyPlayer, amount: float) -> void:
	if player.game.gamemode == "creative" or not is_finite(amount) or amount <= 0: return
	# Source api.lua caps each increase and resets exhaustion at the threshold;
	# even a 6000-unit regeneration event consumes one saturation step.
	player.exhaustion = minf(EXHAUST_LEVEL,player.exhaustion+amount)
	if player.exhaustion < EXHAUST_LEVEL: return
	player.exhaustion = 0.0
	if player.saturation > 0:
		player.saturation = maxf(0,player.saturation-1.5)
	else:
		player.hunger = maxf(0,player.hunger-1)

static func move(player: VoxeyPlayer, displacement: Vector3, sprinting: bool, swimming: bool) -> void:
	if player.game.gamemode == "creative": return
	if sprinting:
		player.sprint_distance += Vector2(displacement.x,displacement.z).length()
		var whole: int = floori(player.sprint_distance)
		if whole > 0:
			player.sprint_distance -= whole
			exhaust(player,SPRINT*whole)
	if swimming:
		player.swim_distance += displacement.length()
		var whole: int = floori(player.swim_distance)
		if whole > 0:
			player.swim_distance -= whole
			exhaust(player,SWIM*whole)

static func can_eat(player: VoxeyPlayer, id: int) -> bool:
	if FoodFeatures.is_cake(id): return false
	if Nodes.food(id) <= 0: return false
	return player.hunger < 20 or player.game.gamemode == "creative" or id in [Nodes.GOLDEN_APPLE,Nodes.CHORUS_FRUIT,VillageContent.SUSPICIOUS_STEW,Beehives.BOTTLE] or bool(Nodes.custom_items.get(id,{}).get("can_eat_when_full",false))

static func food_saturation(id: int) -> float:
	if id in [Beehives.BOTTLE,CropFarming.POISONOUS_POTATO]: return 1.2
	if Nodes.custom_items.has(id): return _number(Nodes.custom_items[id].get("saturation"),0.0,20.0)
	return {
		Nodes.APPLE:2.4,Nodes.RAW_MEAT:1.8,Nodes.COOKED_MEAT:12.8,Nodes.BREAD:6.0,
		Nodes.ROTTEN_FLESH:0.8,Nodes.PUMPKIN_PIE:4.8,Nodes.MELON_SLICE:1.2,
		Nodes.GOLDEN_APPLE:9.6,Nodes.MUSHROOM_STEW:7.2,Nodes.CHORUS_FRUIT:2.4,
		VillageContent.CARROT:3.6,VillageContent.POTATO:0.6,VillageContent.BAKED_POTATO:6.0,
		VillageContent.BEETROOT:1.2,VillageContent.SWEET_BERRY:0.4,VillageContent.GOLDEN_CARROT:14.4,
		VillageContent.COOKIE:0.4,VillageContent.SUSPICIOUS_STEW:7.2,VillageContent.BEETROOT_SOUP:7.2,
		VillageContent.RAW_COD:0.4,VillageContent.COOKED_COD:6.0,VillageContent.RAW_SALMON:0.4,VillageContent.COOKED_SALMON:9.6,
		VillageContent.TROPICAL_FISH:0.2,VillageContent.PUFFERFISH:0.2,
		VillageContent.RAW_BEEF:1.8,VillageContent.COOKED_BEEF:12.8,VillageContent.RAW_PORKCHOP:1.8,VillageContent.COOKED_PORKCHOP:12.8,
		VillageContent.RAW_CHICKEN:1.2,VillageContent.COOKED_CHICKEN:7.2,VillageContent.RAW_MUTTON:1.2,VillageContent.COOKED_MUTTON:9.6,
		VillageContent.RAW_RABBIT:1.8,VillageContent.COOKED_RABBIT:6.0,VillageContent.RABBIT_STEW:12.0,
		VillageContent.DRIED_KELP:0.6,VillageContent.SPIDER_EYE:3.2
	}.get(id,0.0)

static func eat(player: VoxeyPlayer, id: int) -> void:
	restore_food(player,Nodes.food(id),food_saturation(id))

static func restore_food(player: VoxeyPlayer, food: float, saturation: float) -> void:
	# mcl_hunger/hunger.lua saturates before restoring food, so the old hunger
	# value is the saturation ceiling for this meal.
	player.saturation = clampf(player.saturation+saturation,0,player.hunger)
	player.hunger = minf(20,player.hunger+food)

static func update(player: VoxeyPlayer, delta: float) -> void:
	if player.game.gamemode == "creative" or player.health <= 0: return
	player.food_timer += delta
	if player.food_timer >= 4.0:
		player.food_timer = 0.0
		if player.hunger >= 18 and player.health < 20:
			player.health = minf(20,player.health+1)
			exhaust(player,REGEN)
		elif player.hunger <= 0 and player.health > 1:
			player.hurt(minf(1,player.health-1),true,Vector3.INF,"starve")
	elif player.food_timer >= 0.5 and player.hunger >= 20 and player.saturation > 0 and player.health < 20:
		player.food_timer = 0.0
		player.health = minf(20,player.health+1)
		exhaust(player,REGEN)

class_name Eating
extends RefCounted

# mcl_hunger/holdeat.lua; dried kelp overrides the normal delay in mcl_ocean.
const DURATION = 1.61
static func duration(id: int) -> float:
	return 0.8 if id == VillageContent.DRIED_KELP else DURATION

static func start(player: VoxeyPlayer) -> void:
	var held: Dictionary = player.game.inventory.held()
	if not player.eating.is_empty() or held.count <= 0 or not Hunger.can_eat(player,held.id): return
	player.eating = {"id":held.id,"slot":player.game.inventory.selected,"data":held.get("data",{}).duplicate(true),"elapsed":0.0,"sound":0.0}

static func update(player: VoxeyPlayer, delta: float, held_down: bool) -> void:
	if player.eating.is_empty(): return
	var game: Node = player.game
	var held: Dictionary = game.inventory.held()
	var progress: Dictionary = player.eating
	if not game.playing() or not held_down or game.inventory.selected != progress.slot or held.id != progress.id or held.count <= 0 or held.get("data",{}) != progress.data or not Hunger.can_eat(player,held.id):
		player.eating.clear(); return
	progress.elapsed += delta; progress.sound += delta
	if progress.sound >= 0.2:
		progress.sound = fmod(progress.sound,0.2); game.sound("eat")
	player.hand.position.y = -0.19+sin(progress.elapsed*24)*0.025
	player.hand.rotation.x = -0.7+sin(progress.elapsed*24)*0.1
	if progress.elapsed < duration(held.id): return
	var id: int = held.id
	var data: Dictionary = held.get("data",{}).duplicate(true)
	player.eating.clear()
	Hunger.eat(player,id)
	food_effects(player,id)
	FoodFeatures.on_eat(player,id,data)
	if game.gamemode != "creative":
		game.inventory.consume_selected()
		if id == Beehives.BOTTLE:
			var remaining: int = game.inventory.add_item(VillageContent.GLASS_BOTTLE,1)
			if remaining: game.spawn_drop(player.position+Vector3.UP,VillageContent.GLASS_BOTTLE,remaining)
		if id in [Nodes.MUSHROOM_STEW,VillageContent.RABBIT_STEW,VillageContent.SUSPICIOUS_STEW,VillageContent.BEETROOT_SOUP]:
			var remaining: int = game.inventory.add_item(Nodes.BOWL,1)
			if remaining: game.spawn_drop(player.position+Vector3.UP,Nodes.BOWL,remaining)
	game.sound("eat")
	player.use_cooldown = 0

static func food_effects(player: VoxeyPlayer, id: int, chance: float = -1.0) -> void:
	# The optional sample makes food-poisoning probabilities deterministic in tests.
	var roll: float = randf() if chance < 0 else chance
	CropFarming.on_eat(player,id,roll)
	if id == Nodes.ROTTEN_FLESH and roll < 0.8 or id == VillageContent.RAW_CHICKEN and roll < 0.3:
		PotionEffects.apply(player,"hunger",30)
	elif id == VillageContent.PUFFERFISH:
		PotionEffects.apply(player,"hunger",15,3)
		PotionEffects.apply(player,"poison",60,3)
		PotionEffects.apply(player,"nausea",15,2)
	elif id == VillageContent.SPIDER_EYE:
		PotionEffects.apply(player,"poison",5)
	elif id == Nodes.GOLDEN_APPLE:
		PotionEffects.apply(player,"absorption",120)
		PotionEffects.apply(player,"regeneration",5,2)

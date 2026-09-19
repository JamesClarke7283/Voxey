extends RefCounted

static func run(suite: SceneTree, game: Node3D) -> void:
	var player: VoxeyPlayer = game.player
	var old_mode: String = game.gamemode
	var old_state: String = game.state
	var old_health: float = player.health
	var old_hunger: float = player.hunger
	var old_nutrition: Dictionary = Hunger.snapshot(player)
	var old_effects: Dictionary = game.survival.effect_snapshot()
	var old_inventory: Array = game.inventory.slots.duplicate(true)
	var old_selected: int = game.inventory.selected
	var old_armor: Array = player.armor_slots.duplicate(true)
	game.gamemode = "survival"; game.state = "playing"
	PotionEffects.clear(player)
	for slot in player.armor_slots: slot.id = 0; slot.count = 0; slot.wear = 0; slot.erase("data")
	Hunger.reset(player); player.health = 20
	suite.check(player.hunger == 20 and player.saturation == 5 and player.exhaustion == 0,"new nutrition starts at twenty food, five saturation and zero exhaustion")
	Hunger.update(player,60)
	Hunger.move(player,Vector3(100,0,0),false,false)
	suite.check(player.hunger == 20 and player.saturation == 5 and player.exhaustion == 0,"standing and ordinary walking do not drain food")
	Hunger.exhaust(player,3999)
	suite.check(player.saturation == 5 and player.exhaustion == 3999,"exhaustion below the source threshold preserves saturation")
	Hunger.exhaust(player,1)
	suite.check(player.saturation == 3.5 and player.hunger == 20 and player.exhaustion == 0,"four thousand exhaustion consumes one and a half saturation before hunger")
	player.saturation = 0.25; Hunger.exhaust(player,6000)
	suite.check(player.saturation == 0 and player.hunger == 20 and player.exhaustion == 0,"large regeneration exhaustion events clamp and clear exactly as source api.lua")
	Hunger.exhaust(player,4000)
	suite.check(player.hunger == 19,"exhaustion drains one food only once saturation has run out")
	Hunger.reset(player)
	Hunger.move(player,Vector3(0.4,0,0),true,false)
	Hunger.move(player,Vector3(0.6,0,0),true,false)
	suite.check(player.exhaustion == 100 and is_zero_approx(player.sprint_distance),"sprinting accumulates actual movement and charges each complete meter")
	Hunger.move(player,Vector3(0,2,0),false,true)
	suite.check(player.exhaustion == 120,"vertical swimming also contributes source swimming exhaustion")
	Hunger.exhaust(player,Hunger.JUMP); Hunger.exhaust(player,Hunger.SPRINT_JUMP); Hunger.exhaust(player,Hunger.ATTACK); Hunger.exhaust(player,Hunger.DIG)
	suite.check(player.exhaustion == 475,"jumping, sprint jumping, attacks and digging use distinct source costs")
	game.gamemode = "creative"
	Hunger.exhaust(player,4000); Hunger.move(player,Vector3(40,0,0),true,true)
	suite.check(player.exhaustion == 475 and player.saturation == 5,"creative activity never spends hunger or saturation")
	game.gamemode = "survival"
	Hunger.reset(player); player.health = 15
	Hunger.update(player,0.49)
	suite.check(player.health == 15,"saturation regeneration waits half a second")
	Hunger.update(player,0.02)
	suite.check(player.health == 16 and player.saturation == 3.5,"full food with saturation heals one HP and incurs source regeneration exhaustion")
	player.saturation = 0; player.hunger = 18; player.food_timer = 0
	Hunger.update(player,3.99)
	suite.check(player.health == 16,"ordinary high-food regeneration waits four seconds")
	Hunger.update(player,0.02)
	suite.check(player.health == 17 and player.hunger == 17,"slow regeneration starts at eighteen food and costs exhaustion")
	Hunger.update(player,4.1)
	suite.check(player.health == 17,"seventeen food does not enable natural regeneration")
	player.hunger = 0; player.health = 3; player.food_timer = 0; player.damage_cooldown = 0
	Hunger.update(player,3.99)
	suite.check(player.health == 3,"starvation waits four seconds instead of damaging every second")
	PotionEffects.apply(player,"resistance",20,5); PotionEffects.apply(player,"absorption",20)
	Hunger.update(player,0.02)
	suite.check(player.health == 2 and PotionEffects.absorption(player) == 4,"starvation bypasses armor, resistance and absorption")
	PotionEffects.clear(player); player.health = 1.25; player.damage_cooldown = 0
	Hunger.update(player,4.1)
	suite.check(player.health == 1,"normal starvation never passes the one-health floor, including fractional health")
	player.damage_cooldown = 0; Hunger.update(player,4.1)
	suite.check(player.health == 1,"normal starvation cannot kill")
	player.health = 20; Hunger.reset(player)
	Hunger.restore(player,{"saturation":2.25,"exhaustion":3820})
	suite.check(Hunger.snapshot(player) == {"saturation":2.25,"exhaustion":3820.0},"nutrition snapshot preserves fractional saturation and exhaustion")
	player.hunger = 2; Hunger.restore(player,{"saturation":99,"exhaustion":-1})
	suite.check(player.saturation == 2 and player.exhaustion == 0,"loaded nutrition clamps saturation to hunger and rejects negative exhaustion")
	player.hunger = 20; Hunger.restore(player,{"saturation":"bad","exhaustion":INF})
	suite.check(player.saturation == 5 and player.exhaustion == 0,"malformed nutrition cannot poison survival calculations")
	Hunger.restore(player,null)
	suite.check(player.saturation == 5 and player.exhaustion == 0,"legacy worlds without nutrition load with source initial values")
	suite.check(Nodes.food(Nodes.BREAD) == 5 and Nodes.food(Nodes.ROTTEN_FLESH) == 4 and Nodes.food(Nodes.GOLDEN_APPLE) == 4 and Nodes.food(Nodes.RAW_MEAT) == 3,"mapped foods use source food values")
	suite.check(is_equal_approx(Hunger.food_saturation(VillageContent.GOLDEN_CARROT),14.4) and is_equal_approx(Hunger.food_saturation(VillageContent.COOKED_MUTTON),9.6) and is_equal_approx(Hunger.food_saturation(VillageContent.COOKIE),0.4),"foods have their own source saturation values")
	player.hunger = 1; player.saturation = 0
	Hunger.eat(player,Nodes.BREAD)
	suite.check(player.hunger == 6 and player.saturation == 1,"eating observes source's pre-meal hunger ceiling for saturation")
	game.inventory.restore([]); game.inventory.selected = 0; game.inventory.add_item(Nodes.APPLE,2)
	Hunger.reset(player)
	Eating.start(player)
	suite.check(player.eating.is_empty(),"ordinary foods cannot be eaten when full")
	player.hunger = 10; player.saturation = 0
	Eating.start(player); Eating.update(player,0.8,true); Eating.update(player,0.1,false)
	suite.check(player.saturation == 0 and player.hunger == 10 and game.inventory.count_item(Nodes.APPLE) == 2,"cancelled meals do not grant saturation or consume food")
	Eating.start(player); Eating.update(player,1.62,true)
	suite.check(player.hunger == 14 and is_equal_approx(player.saturation,2.4) and game.inventory.count_item(Nodes.APPLE) == 1,"a finished meal grants food and saturation and consumes exactly one item")
	game.inventory.restore([]); game.inventory.add_item(Nodes.GOLDEN_APPLE,1); Hunger.reset(player)
	Eating.start(player); Eating.update(player,1.62,true)
	suite.check(game.inventory.count_item(Nodes.GOLDEN_APPLE) == 0 and PotionEffects.level(player,"regeneration") == 2 and PotionEffects.absorption(player) == 4,"golden apples can be eaten when full and grant regeneration II plus four absorption HP")
	player.damage_cooldown = 0; player.hurt(3,true)
	suite.check(player.health == 20 and PotionEffects.absorption(player) == 1,"golden absorption takes damage before real health")
	var saved_effects: Dictionary = game.survival.effect_snapshot()
	game.survival.restore_effects(saved_effects)
	suite.check(PotionEffects.absorption(player) == 1,"saving effects preserves remaining absorption instead of refilling it")
	player.damage_cooldown = 0; player.hurt(3,true)
	suite.check(player.health == 18 and PotionEffects.absorption(player) == 0,"damage exceeding absorption carries over to health")
	PotionEffects.clear(player); player.health = 20
	Eating.food_effects(player,Nodes.ROTTEN_FLESH,0.79)
	suite.check(PotionEffects.level(player,"hunger") == 1 and game.survival.effects.hunger == 30,"rotten flesh has the source eighty-percent hunger-effect threshold")
	Hunger.reset(player); PotionEffects.update(player,1)
	suite.check(player.exhaustion == 100,"hunger status contributes one hundred exhaustion per level each second")
	PotionEffects.clear(player); Eating.food_effects(player,Nodes.ROTTEN_FLESH,0.8)
	suite.check(PotionEffects.level(player,"hunger") == 0,"the remaining rotten-flesh outcomes avoid food poisoning")
	Eating.food_effects(player,VillageContent.RAW_CHICKEN,0.29)
	suite.check(PotionEffects.level(player,"hunger") == 1,"raw chicken can cause thirty seconds of hunger")
	PotionEffects.clear(player); Eating.food_effects(player,VillageContent.RAW_CHICKEN,0.3)
	suite.check(PotionEffects.level(player,"hunger") == 0,"raw-chicken poisoning probability is thirty percent")
	Eating.food_effects(player,VillageContent.PUFFERFISH,1)
	suite.check(PotionEffects.level(player,"poison") == 3 and PotionEffects.level(player,"hunger") == 3 and PotionEffects.level(player,"nausea") == 2,"pufferfish always applies source poison III, hunger III and nausea II")
	PotionEffects.clear(player); Eating.food_effects(player,VillageContent.SPIDER_EYE,1)
	suite.check(PotionEffects.level(player,"poison") == 1 and game.survival.effects.poison == 5,"spider eyes cause five seconds of poison")
	PotionEffects.apply(player,"absorption",1); PotionEffects.update(player,1.01)
	suite.check(PotionEffects.absorption(player) == 0,"expired absorption removes unused bonus health")
	PotionEffects.apply(player,"hunger",30); PotionEffects.apply(player,"absorption",120); PotionEffects.clear(player)
	suite.check(PotionEffects.level(player,"hunger") == 0 and PotionEffects.absorption(player) == 0,"milk-style clearing removes food poisoning and absorption")
	Hunger.reset(player); player.saturation = 2.75; player.exhaustion = 3540
	game.save_game("user://hunger_check.json")
	var save: Dictionary = game.read_save("user://hunger_check.json")
	suite.check(save.get("nutrition",{}) == Hunger.snapshot(player),"world saves include the current nutrition state")
	for suffix in ["",".bak",".tmp"]:
		var path: String = "user://hunger_check.json"+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	game.inventory.slots = old_inventory; game.inventory.selected = old_selected
	player.armor_slots = old_armor; player.health = old_health; player.hunger = old_hunger
	Hunger.restore(player,old_nutrition); game.survival.restore_effects(old_effects)
	player.damage_cooldown = 0; game.gamemode = old_mode; game.state = old_state

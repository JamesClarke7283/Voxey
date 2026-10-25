extends RefCounted

static func item(id: int, normalized: int = 0, enchants: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"id":id,"count":1,"wear":0,"data":{"enchantments":enchants.duplicate(true)}}
	Durability.set_normalized(result,normalized)
	return result

static func reset(player: VoxeyPlayer) -> void:
	player.damage_cooldown = 0; player.health = 20
	PotionEffects.clear(player)
	for i in 4: player.armor_slots[i] = {"id":0,"count":0,"wear":0}
	player.offhand_slot = {"id":0,"count":0,"wear":0}

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	var old_slots: Array = game.inventory.slots.slice(0,Inventory.BASE_SLOTS).duplicate(true)
	var old_pouches: Array = game.inventory.pouch_slots.duplicate(true)
	var old_armor: Array = game.player.armor_slots.duplicate(true); var old_offhand: Dictionary = game.player.offhand_slot.duplicate(true)
	var old_xp: float = game.experience; var old_health: float = game.player.health; var old_mode: String = game.gamemode
	var game_player: VoxeyPlayer = game.player; var home: Vector3 = game_player.position
	game.gamemode = "survival"; game.inventory.restore([]); reset(game_player)
	var seen: Dictionary = {}; var isolated: bool = true
	for seed_value in range(1,37):
		var slots: Array = [item(95,30000,{"Mending":1}),item(112,30000,{"Mending":1}),item(113,30000,{"Mending":1}),item(114,30000,{"Mending":1}),item(115,30000,{"Mending":1}),item(813,30000,{"Mending":1})]
		Durability.mend(slots,1,EnchantRolls.new(seed_value))
		var changed: int = 0
		for i in slots.size():
			if Durability.normalized(slots[i]) != 30000: changed += 1; seen[i] = true
		isolated = isolated and changed == 1
	t.check(isolated and seen.size() == 6,"Mending chooses exactly one item and can reach both hands and all four armor slots")
	var candidates: Array = [item(95,1,{"Mending":1}),item(112,30000,{"Mending":1})]
	var returned: float = Durability.mend(candidates,2,EnchantRolls.new(1))
	t.check(returned == 2 and Durability.normalized(candidates[0]) == 0 and Durability.normalized(candidates[1]) == 30000,"a nearly repaired choice returns rounded leftover XP without repairing a second item")
	game_player.offhand_slot = item(813,10000,{"Mending":1}); game.experience = 0; game.state = "playing"
	game.experience += 3; game.state = "paused"
	t.check(Durability.normalized(game_player.offhand_slot) < 10000 and game.experience == 0,"a live XP award can repair the offhand item through the actual experience setter")
	var armor: Dictionary = item(112,30000,{"Unbreaking":3})
	Durability.use(armor)
	t.check(Durability.normalized(armor) == 30126,"armor Unbreaking uses the source 0.6 plus 0.4 formula with deterministic fractional wear")
	var cleaned: Dictionary = Inventory.clean_slot(JSON.parse_string(JSON.stringify(armor)))
	t.check(Durability.normalized(cleaned) == 30126,"normalized wear survives JSON and inventory validation without rounding loss")
	cleaned.wear += 2
	t.check(Durability.normalized(cleaned) == floori(float(cleaned.wear)*65535/Nodes.durability(cleaned.id)),"direct legacy wear changes invalidate an outdated normalized-wear checkpoint")
	reset(game_player); game_player.armor_slots[1] = item(105)
	PotionEffects.apply(game_player,"resistance",30,1)
	game_player.hurt(5,false,Vector3.INF,"mob")
	t.check(is_equal_approx(game_player.health,16.64),"Resistance is applied before damage-dependent armor reduction")
	reset(game_player); game_player.armor_slots[1] = item(105)
	game_player.hurt(5,false,Vector3.INF,"generic")
	t.check(game_player.health == 15 and game_player.armor_slots[1].wear == 0,"source generic damage bypasses physical armor and its wear")
	reset(game_player); game_player.armor_slots[1] = item(105)
	game_player.hurt(5,true,Vector3.INF,"hot_floor")
	t.check(game_player.health > 15 and game_player.armor_slots[1].wear > 0,"hot-floor fire uses source armor flags even for a legacy bypass-armor caller")
	reset(game_player); game_player.armor_slots[1] = item(105,20000,{"Unbreaking":2})
	PotionEffects.apply(game_player,"fire_resistance",30,1)
	game_player.hurt(10,false,Vector3.INF,"lava")
	t.check(game_player.health == 20 and Durability.normalized(game_player.armor_slots[1]) == 20000,"fire resistance stops the hit before armor wears")
	PotionEffects.clear(game_player); PotionEffects.apply(game_player,"resistance",30,5)
	game_player.hurt(10,false,Vector3.INF,"mob")
	t.check(game_player.health == 20 and Durability.normalized(game_player.armor_slots[1]) == 20000,"zero damage from Resistance stops before armor wear")
	reset(game_player)
	for i in 4: game_player.armor_slots[i] = item(Netherite.ARMOR+i)
	game_player.offhand_slot = {"id":Totems.ID,"count":1,"wear":0}; game_player.health = 5
	game_player.hurt(6,false,Vector3.INF,"mob")
	t.check(game_player.health > 0 and game_player.offhand_slot.id == Totems.ID,"armor prevents a nonlethal hit from consuming the held totem")
	reset(game_player); game_player.offhand_slot = {"id":Totems.ID,"count":1,"wear":0}; game_player.health = 5
	PotionEffects.apply(game_player,"absorption",30,2)
	game_player.hurt(7,false,Vector3.INF,"mob")
	t.check(game_player.health == 5 and game_player.offhand_slot.id == Totems.ID and PotionEffects.absorption(game_player) == 1,"absorption is spent before deciding whether a totem is necessary")
	reset(game_player); game_player.offhand_slot = {"id":Totems.ID,"count":1,"wear":0}; game_player.health = 1
	game_player.hurt(2,true,Vector3.INF,"drown")
	t.check(game_player.health == 1 and game_player.offhand_slot.id == 0,"a held totem now intercepts lethal drowning despite its armor-bypass flag")
	reset(game_player); game_player.offhand_slot = {"id":Totems.ID,"count":1,"wear":0}
	PotionEffects.apply(game_player,"resistance",30,5); game_player.damage_cooldown = 1
	game_player.hurt(2,true,Vector3.INF,"void")
	t.check(game_player.health == 18 and game_player.offhand_slot.id == Totems.ID,"void damage bypasses invulnerability and magic while leaving a nonlethal totem untouched")
	reset(game_player); game_player.offhand_slot = {"id":0,"count":0,"wear":0}
	var cow: Creature = game.spawn_creature("cow",game_player.position+Vector3(2,0,0)); cow.set_physics_process(false); cow.health = 100
	game_player.armor_slots[1] = item(113,0,{"Thorns":3})
	for attempt in 64:
		game_player.health = 20; game_player.damage_cooldown = 0
		Durability.set_normalized(game_player.armor_slots[1],0)
		game_player.hurt(1,false,cow.position,"mob",cow)
		if cow.health < 100: break
	t.check(cow.health < 100 and 100-cow.health <= 4,"a real attacking creature receives the source bounded Thorns retaliation")
	var ordinary: Dictionary = item(113); Durability.use(ordinary)
	t.check(Durability.normalized(game_player.armor_slots[1]) > Durability.normalized(ordinary),"successful Thorns adds two uses to one participating armor piece")
	cow.queue_free()
	var guardian: Creature = game.spawn_creature("guardian",game_player.position+Vector3(2,0,0)); guardian.set_physics_process(false); guardian.health = 100
	for attempt in 64:
		game_player.health = 20; game_player.damage_cooldown = 0
		game_player.hurt(1,false,guardian.position,"mob",guardian)
		if guardian.health < 100: break
	t.check(guardian.health < 100 and game_player.health > 19,"armor Thorns does not trigger a guardian's own Thorns recursively")
	guardian.queue_free(); reset(game_player)
	var pouch: Dictionary = {"id":Pouches.SINGLE,"count":1,"wear":0}
	Pouches.contents(pouch)[0] = armor.duplicate(true)
	game.inventory.restore([], [pouch]); game_player.armor_slots[0] = armor.duplicate(true)
	game_player.position = home
	t.check(game.save_game("user://defensive-enchantments.json"),"fractional armor wear saves to disk")
	var stop_spawn: Callable = func(node):
		if node is Creature: node.ready.connect(func(): node.set_physics_process(false),CONNECT_ONE_SHOT)
	game.creatures.child_entered_tree.connect(stop_spawn)
	game.set_process(true); game.load_world_data(game.read_save("user://defensive-enchantments.json"))
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.creatures.child_entered_tree.disconnect(stop_spawn)
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	var worn: int = Durability.normalized(game.player.armor_slots[0]); var stored: int = Durability.normalized(Pouches.contents(game.inventory.pouch_slots[0])[0])
	t.check(worn == 30126 and stored == 30126,"real reload preserves exact normalized wear on equipped and stored armor (%d / %d)"%[worn,stored])
	game.inventory.restore(old_slots,old_pouches); game.player.armor_slots = old_armor; game.player.offhand_slot = old_offhand
	game.experience = old_xp; game.player.health = old_health; game.gamemode = old_mode
	for path in ["user://defensive-enchantments.json","user://defensive-enchantments.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

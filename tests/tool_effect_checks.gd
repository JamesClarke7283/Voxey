extends RefCounted

static func equip(game: Node3D, id: int, enchantments: Dictionary = {}) -> void:
	game.inventory.slots[game.inventory.selected] = {"id":id,"count":1,"wear":0,"data":{"enchantments":enchantments.duplicate()}}
	game.player.mining_tool = -1

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false)
	var old_inventory: Array = game.inventory.slots.duplicate(true)
	var old_position: Vector3 = game.player.position; var old_mode: String = game.gamemode
	game.gamemode = "survival"; PotionEffects.clear(game.player)
	equip(game,95)
	var normal: float = ToolCapabilities.mining(Nodes.STONE,game.inventory.held(),game.player).time
	t.check(is_equal_approx(normal,0.3),"a diamond pick uses the real source stone digging time")
	PotionEffects.apply(game.player,"haste",16,1)
	var faster: float = ToolCapabilities.mining(Nodes.STONE,game.inventory.held(),game.player).time
	t.check(PotionEffects.level(game.player,"haste") == 1 and is_equal_approx(faster,0.25),"Haste I is a live effect and speeds the held pick's source capabilities")
	t.check(is_equal_approx(ToolCapabilities.attack_interval(game.inventory.held(),game.player),float(ToolCapabilities.profile(95).levels[0].full_punch_interval)*0.9),"Haste I changes a mining tool's attack recharge by the source ten percent")
	var cleaned: Dictionary = Inventory.clean_slot(JSON.parse_string(JSON.stringify(game.inventory.held())))
	t.check(cleaned.data.has("item_speed") and is_equal_approx(cleaned.data.item_speed.haste,0.2),"the item's cached speed factors survive inventory validation")
	game.gamemode = "creative"
	t.check(is_equal_approx(ToolCapabilities.attack_interval(game.inventory.held(),game.player),float(ToolCapabilities.profile(95).levels[0].full_punch_interval)),"changing to creative clears the carried tool's survival speed override")
	game.gamemode = "survival"; ToolCapabilities.refresh(game.player)
	t.check(is_equal_approx(ToolCapabilities.mining(Nodes.STONE,game.inventory.held(),game.player).time,0.25),"returning to survival refreshes the still-active Haste effect")
	PotionEffects.clear(game.player); PotionEffects.apply(game.player,"fatigue",30,3)
	t.check(is_equal_approx(ToolCapabilities.mining(Nodes.STONE,game.inventory.held(),game.player).time,15),"Fatigue III uses the source rational factor of 0.02")
	PotionEffects.apply(game.player,"fatigue",30,4)
	t.check(ToolCapabilities.mining(Nodes.STONE,game.inventory.held(),game.player).time == 300,"Fatigue IV reaches the reference's 300-second mining cap")
	PotionEffects.clear(game.player); equip(game,98); PotionEffects.apply(game.player,"haste",20,2)
	t.check(is_equal_approx(ToolCapabilities.attack_interval(game.inventory.held(),game.player),0.625),"a sword does not gain a speed override because the source does not mark swords as tool=1")
	equip(game,95); game.player.melee_elapsed = 0.2
	var cow: Creature = game.spawn_creature("cow",game.player.position+Vector3(0,0,2)); cow.set_physics_process(false); cow.health = 100
	game.player.velocity = Vector3.ZERO; game.player.sprinting = false
	var first: Dictionary = MeleeCombat.attack(game.player,cow,EnchantRolls.new(1))
	game.player.melee_elapsed = 0.2; var second: Dictionary = MeleeCombat.attack(game.player,cow,EnchantRolls.new(1))
	t.check(second.damage > first.damage,"switching to a tool refreshes its cache for the next punch, matching the source callback order")
	cow.free()
	PotionEffects.clear(game.player); equip(game,80,{"Unbreaking":3}); ToolCapabilities.refresh(game.player)
	t.check(is_equal_approx(ToolCapabilities.mining(Nodes.STONE,game.inventory.held(),game.player).time,0.75),"Unbreaking-only tools retain the source's efficiency-zero groupcap regeneration")
	ToolCapabilities.wear(game.inventory,Nodes.STONE)
	t.check(Durability.normalized(game.inventory.held()) == 273,"digging Unbreaking uses exact deterministic engine wear")
	PotionEffects.clear(game.player); equip(game,95)
	var p: Vector3i = Vector3i(game.player.position.floor())+Vector3i(0,3,0)
	game.world.set_node(p,Nodes.STONE)
	game.player.target = {"pos":p,"id":Nodes.STONE,"normal":Vector3i.UP}
	game.player.underwater = true
	game.player.mine(0.15)
	t.check(game.world.node_at(p) == Nodes.STONE,"partial source-duration mining leaves the target in place")
	game.player.mine(0.16)
	t.check(game.world.node_at(p) == Nodes.AIR and Durability.normalized(game.inventory.held()) == 41,"finishing a real underwater dig uses the source time and wear without an invented fivefold penalty")
	game.player.underwater = false
	equip(game,98)
	t.check(is_equal_approx(ToolCapabilities.mining(Nodes.STONE,game.inventory.held(),game.player).time,7.5),"an unsuitable sword falls back to the source hand capabilities")
	ToolCapabilities.wear(game.inventory,Nodes.STONE)
	t.check(Durability.normalized(game.inventory.held()) == 0,"hand-fallback digging does not wear the unsuitable sword")
	equip(game,1113); ToolCapabilities.wear(game.inventory,Nodes.LEAVES)
	t.check(Durability.normalized(game.inventory.held()) == 4096,"instant leaf digging retains the engine's 65536-based wear rounding")
	# A real beacon provides a survival route to Haste and the amplified mode.
	var beacon: Vector3i = p+Vector3i(0,6,0)
	for depth in range(1,5):
		for x in range(-depth,depth+1):
			for z in range(-depth,depth+1): game.world.set_node(beacon+Vector3i(x,-depth,z),Nodes.IRON_BLOCK)
	game.world.set_node(beacon,Beacons.ID); Beacons.registered(game.world,beacon,Beacons.ID)
	game.player.position = Vector3(beacon)+Vector3(0.5,1,0.5); equip(game,95)
	var state: Dictionary = Beacons.station(game.world,beacon); state.effect = "haste"
	PotionEffects.clear(game.player); Beacons.update(game.world,1)
	t.check(PotionEffects.level(game.player,"haste") == 1,"a powered beacon actually grants its selected Haste effect")
	game.player.crouching = true; Beacons.use(game,{"pos":beacon}); game.player.crouching = false
	PotionEffects.clear(game.player); Beacons.update(game.world,1)
	t.check(PotionEffects.level(game.player,"haste") == 2 and PotionEffects.level(game.player,"regeneration") == 0,"sneak-use selects the source's amplified primary effect without secondary regeneration")
	game.world.set_node(beacon+Vector3i(4,-4,4),Nodes.AIR)
	PotionEffects.clear(game.player); Beacons.update(game.world,1)
	t.check(PotionEffects.level(game.player,"haste") == 0,"an amplified effect stops being granted when the fourth pyramid layer is incomplete")
	game.world.set_node(beacon+Vector3i(4,-4,4),Nodes.IRON_BLOCK); Beacons.update(game.world,1)
	var water: Vector3i = Vector3i(game.player.position.floor())
	game.world.set_node(water,Nodes.WATER); PotionEffects.apply(game.player,"conduit_power",17,1)
	ToolCapabilities.refresh(game.player)
	var combined: Dictionary = ToolCapabilities.speeds(game.inventory.held(),game.player)
	t.check(is_equal_approx(combined.haste,0.68),"Haste II and active Conduit Power combine multiplicatively in water")
	game.world.set_node(water,Nodes.AIR); ToolCapabilities.refresh(game.player)
	t.check(is_equal_approx(ToolCapabilities.speeds(game.inventory.held(),game.player).haste,0.4),"Conduit Power contributes no speed bonus on dry land")
	t.check(game.save_game("user://tool-effects.json"),"active Haste and amplified beacon state save to disk")
	var saved: Dictionary = game.read_save("user://tool-effects.json")
	game.set_process(true); game.load_world_data(saved)
	var deadline: int = Time.get_ticks_msec()+90000
	while game.state == "loading" and Time.get_ticks_msec() < deadline: await t.process_frame
	game.pause(); game.set_process(false); game.world.set_process(false)
	t.check(PotionEffects.level(game.player,"haste") == 2 and int(Beacons.station(game.world,beacon).get("effect_level",0)) == 2,"real reload restores Haste potency and the amplified beacon selection")
	PotionEffects.update(game.player,20)
	t.check(PotionEffects.level(game.player,"haste") == 0 and not game.inventory.held().get("data",{}).has("item_speed"),"expiry clears the speed override from carried tools")
	for depth in range(1,5):
		for x in range(-depth,depth+1):
			for z in range(-depth,depth+1): game.world.set_node(beacon+Vector3i(x,-depth,z),Nodes.AIR)
	game.world.set_node(beacon,Nodes.AIR); Beacons.reset(game.world)
	game.inventory.slots = old_inventory; game.player.position = old_position; game.gamemode = old_mode
	game.player.crouching = false; PotionEffects.clear(game.player)
	for path in ["user://tool-effects.json","user://tool-effects.json.bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

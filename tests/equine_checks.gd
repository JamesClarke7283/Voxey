extends RefCounted

# Focused regression for the horse family: per-horse statistics and coats,
# temper taming, food, saddle, armour and chests, charged jumps, breeding with
# mules, the skeleton trap, persistence and dungeon armour. Reference:
# mobs_mc/horse.lua, mcl_lightning/init.lua, mcl_dungeons/init.lua.

static func spawned(kind: String, game: Node3D, pos: Vector3) -> Creature:
	var mob: Creature = game.spawn_creature(kind,pos)
	if mob != null: mob.set_physics_process(false)
	return mob

static func hold(game: Node3D, id: int, count: int = 1) -> void:
	game.inventory.slots[game.inventory.selected] = {"id":id,"count":count,"wear":0}

static func run(suite: Object, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var old_slots: Array = game.inventory.slots.duplicate(true)
	var old_selected: int = game.inventory.selected
	var old_position: Vector3 = game.player.position
	var old_mode: String = game.gamemode
	game.gamemode = "survival"
	game.inventory.selected = 0
	game.survival.mount = null
	for mob in game.creatures.get_children(): mob.free()
	var arena := Vector3i(8,170,8)
	for x in range(-14,15):
		for z in range(-14,15):
			world.set_node(arena+Vector3i(x,-1,z),Nodes.GRASS)
			for y in range(0,5): world.set_node(arena+Vector3i(x,y,z),Nodes.AIR)
	game.player.position = Vector3(arena)+Vector3(0.5,0,6.5)

	# --- registry and statistics ------------------------------------------------------
	for kind in Equines.KINDS: suite.check(Creature.KINDS.has(kind),"the %s is a registered creature" % kind)
	suite.check(not Creature.PASSIVE.has("horse"),"horses no longer spawn from the generic animal pool")
	suite.check(Creature.KINDS["horse"].drops == [[Nodes.LEATHER,0,2]],"a horse drops the source's zero to two leather")
	suite.check(PotionEffects.UNDEAD.has("skeleton_horse") and PotionEffects.UNDEAD.has("zombie_horse"),"skeleton and zombie horses are undead")
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	var low_hp: float = 99.0; var high_hp: float = 0.0
	var low_speed: float = 99.0; var high_speed: float = 0.0
	var low_jump: float = 99.0; var high_jump: float = 0.0
	for i in 3000:
		var hp: float = Equines.roll_health(rng); low_hp = minf(low_hp,hp); high_hp = maxf(high_hp,hp)
		var sp: float = Equines.roll_speed(rng); low_speed = minf(low_speed,sp); high_speed = maxf(high_speed,sp)
		var jp: float = Equines.roll_jump(rng); low_jump = minf(low_jump,jp); high_jump = maxf(high_jump,jp)
	suite.check(low_hp >= 15.0 and high_hp <= 32.0 and high_hp - low_hp > 12.0,"health rolls 15 + 0-8 + 0-9")
	suite.check(low_speed >= 2.25 and high_speed <= 6.75,"speed lies in the source's 2.25-6.75")
	suite.check(low_jump >= 8.0 and high_jump <= 20.0,"jump strength lies in the source's 8-20")
	suite.check(is_equal_approx(Equines.jump_from(0,0,0),8.0) and is_equal_approx(Equines.jump_from(1,1,1),20.0) and is_equal_approx(Equines.speed_from(1,1,1),6.75),"the statistic formulas match the source at their extremes")
	var horse: Creature = spawned("horse",game,Vector3(arena)+Vector3(0.5,0,0.5))
	suite.check(horse is RuralAnimal and horse.head != null,"a horse spawns as a rideable animal")
	suite.check(horse.has_meta("max_health") and is_equal_approx(horse.health,Equines.max_health(horse)),"a new horse starts at its own rolled health")
	suite.check(Equines.BASES.has(str(horse.get_meta("horse_base",""))) and Equines.MARKINGS.has(str(horse.get_meta("horse_markings","x"))),"it has one of the seven coats and five markings")
	var donkey: Creature = spawned("donkey",game,Vector3(arena)+Vector3(4.5,0,0.5))
	suite.check(is_equal_approx(Equines.speed(donkey),3.5) and is_equal_approx(Equines.jump(donkey),10.0),"a donkey's speed and jump are fixed at 3.5 and 10")
	# The child blend stays inside its range and near the parents.
	var mids: float = 0.0
	for i in 2000:
		var v: float = Equines.child_value(10.0,10.0,0.0,20.0,rng)
		if v < 0.0 or v > 20.0: suite.check(false,"a blended value stays in range"); break
		mids += v
	suite.check(absf(mids/2000.0-13.0) < 1.0,"identical parents give foals around their value plus a small spread")
	suite.check(Equines.child_value(19.0,19.5,0.0,20.0,RandomNumberGenerator.new()) <= 20.0,"a blend past the top reflects back inside")

	# --- taming ------------------------------------------------------------------------
	suite.check(not Equines.tamed(horse),"a wild horse is untamed")
	hold(game,Nodes.GRAIN,10)
	suite.check(Equines.use(game,horse) and Equines.temper(horse) == 3 and game.inventory.held().count == 9,"wheat adds three temper and is eaten")
	hold(game,Nodes.BREAD,1)
	Equines.use(game,horse)
	suite.check(game.survival.mount == null,"an untamed horse refuses a rider holding anything")
	hold(game,0,0)
	Equines.use(game,horse)
	suite.check(game.survival.mount == horse,"an empty hand mounts it to start taming")
	# Force the evaluation: a roll at temper + 1 succeeds.
	var tame_rng := RandomNumberGenerator.new(); tame_rng.seed = 1
	var outcome: String = ""
	var bucks: int = 0
	for i in 5000:
		if game.survival.mount != horse: game.survival.mount = horse; bucks += 1
		outcome = Equines.evaluate(game,horse,0.05,tame_rng)
		if outcome == "tamed": break
	suite.check(outcome == "tamed" and Equines.tamed(horse) and str(horse.get_meta("owner","")) == game.player_id,"riding it eventually tames it to the rider")
	suite.check(bucks > 0 or Equines.temper(horse) >= 3,"failed evaluations throw the rider and add temper")
	var stubborn: Creature = spawned("horse",game,Vector3(arena)+Vector3(-4.5,0,0.5))
	game.survival.mount = stubborn
	var thrown: bool = false
	var buck_rng := RandomNumberGenerator.new(); buck_rng.seed = 77
	for i in 4000:
		var result: String = Equines.evaluate(game,stubborn,0.05,buck_rng)
		if result == "bucked": thrown = true; break
		if result == "tamed": game.survival.mount = stubborn; stubborn.trust = 0
	suite.check(thrown and game.survival.mount == null and Equines.temper(stubborn) >= 5,"a failed evaluation throws the rider and adds five temper")
	game.survival.mount = null
	stubborn.free()

	# --- food, saddle, armour and shears ---------------------------------------------------
	horse.health = 10.0
	hold(game,Nodes.GOLDEN_APPLE,2)
	Equines.use(game,horse)
	suite.check(is_equal_approx(horse.health,minf(20.0,Equines.max_health(horse))) and horse.love_time > 0.0,"a golden apple heals ten and puts a tamed horse in love")
	horse.love_time = 0.0
	hold(game,Nodes.SADDLE,1)
	Equines.use(game,horse)
	suite.check(horse.saddled and game.inventory.held().count == 0,"a saddle goes on a tamed horse")
	hold(game,Equines.DIAMOND_ARMOR,1)
	Equines.use(game,horse)
	suite.check(Equines.armor_id(horse) == Equines.DIAMOND_ARMOR and is_equal_approx(Equines.armor_factor(horse),0.56),"diamond horse armour lets 56 percent of a blow through")
	var before_hit: float = horse.health
	horse.hit(10.0,game.player.position+Vector3(0,0,3))
	suite.check(is_equal_approx(before_hit-horse.health,5.6),"a ten-point blow on diamond-armoured horse lands as 5.6")
	horse.hurt_flash = 0.0
	hold(game,Equines.IRON_ARMOR,1)
	Equines.use(game,horse)
	suite.check(Equines.armor_id(horse) == Equines.DIAMOND_ARMOR and game.inventory.held().count == 1,"a second armour does not replace the first")
	hold(game,Nodes.SHEARS,1)
	Equines.use(game,horse)
	suite.check(Equines.armor_id(horse) == 0 and horse.saddled,"shears take the armour back first")
	Equines.use(game,horse)
	suite.check(not horse.saddled,"then the saddle")
	suite.check(is_equal_approx(Equines.armor_factor(horse),1.0),"a bare horse takes full damage")
	suite.check(Equines.ARMOR[VillageContent.LEATHER_HORSE_ARMOR] == 88 and Equines.ARMOR[Equines.COPPER_ARMOR] == 86 and Equines.ARMOR[Equines.IRON_ARMOR] == 85 and Equines.ARMOR[Equines.GOLD_ARMOR] == 60,"the armour table matches the source")
	hold(game,Equines.IRON_ARMOR,1)
	suite.check(not Equines.equip_armor(donkey,Equines.IRON_ARMOR),"donkeys wear no horse armour")

	# --- the donkey's chest -----------------------------------------------------------------
	hold(game,Nodes.CHEST,1)
	Equines.use(game,donkey)
	suite.check(not donkey.has_meta("equine_chest"),"an untamed donkey takes no chest")
	donkey.trust = Equines.TAMED_TRUST
	hold(game,Nodes.CHEST,1)
	Equines.use(game,donkey)
	suite.check(Equines.chest(donkey).size() == 15 and game.inventory.held().count == 0,"a tamed donkey takes a chest of fifteen slots")
	Equines.chest(donkey)[3] = {"id":Nodes.COBBLE,"count":12,"wear":0}

	# --- riding: the charged jump --------------------------------------------------------------
	suite.check(is_equal_approx(Equines.jump_scale(0.5),1.0) and is_equal_approx(Equines.jump_scale(0.55),1.0),"a charge of ten or eleven ticks gives a full jump")
	suite.check(Equines.jump_scale(0.1) < Equines.jump_scale(0.3) and Equines.jump_scale(0.3) < 0.9,"a shorter charge jumps less")
	suite.check(Equines.jump_scale(2.0) < 0.9,"holding too long weakens the jump again")
	suite.check(Equines.ride_speed(horse) > 3.0 and Equines.jump_velocity(horse) > 5.0,"a horse rides at its own speed and jumps by its own strength")

	# --- breeding -------------------------------------------------------------------------------
	suite.check(Equines.mate_kind("horse","horse") == "horse" and Equines.mate_kind("donkey","donkey") == "donkey" and Equines.mate_kind("horse","donkey") == "mule" and Equines.mate_kind("mule","mule") == "","horse and donkey make a mule; mules never breed")
	var foal: Node3D = Equines.make_foal(game,horse,donkey,RandomNumberGenerator.new())
	suite.check(foal != null and foal.kind == "mule" and foal.growth_remaining > 0.0,"a horse and a donkey have a mule foal")
	if foal != null: foal.free()
	var mare: Creature = spawned("horse",game,Vector3(arena)+Vector3(1.5,0,1.5))
	mare.trust = Equines.TAMED_TRUST
	horse.love_time = Equines.LOVE_TIME; mare.love_time = Equines.LOVE_TIME
	horse.breed_cooldown = 0.0; mare.breed_cooldown = 0.0
	var born: Node3D = null
	for i in 10:
		born = Equines.breed_step(game,horse,0.5)
		if born == null: born = Equines.breed_step(game,mare,0.5)
		if born != null: break
	suite.check(born != null and born.kind == "horse" and born.has_meta("speed") and Equines.BASES.has(str(born.get_meta("horse_base",""))),"two tamed horses in love have a foal with blended statistics and an inherited coat")
	if born != null: born.free()
	suite.check(horse.breed_cooldown > 0.0 and mare.breed_cooldown > 0.0,"both parents rest after breeding")
	mare.free()

	# --- persistence -----------------------------------------------------------------------------
	horse.equip_saddle()
	Equines.equip_armor(horse,Equines.GOLD_ARMOR)
	var record: Dictionary = JSON.parse_string(JSON.stringify(Equines.snapshot(horse)))
	var copy: Creature = spawned("horse",game,Vector3(arena)+Vector3(-6.5,0,-6.5))
	copy.trust = Equines.TAMED_TRUST
	Equines.restore(copy,record)
	suite.check(is_equal_approx(Equines.max_health(copy),Equines.max_health(horse)) and is_equal_approx(Equines.speed(copy),Equines.speed(horse)) and is_equal_approx(Equines.jump(copy),Equines.jump(horse)),"a horse's statistics survive a save")
	suite.check(copy.get_meta("horse_base") == horse.get_meta("horse_base") and copy.get_meta("horse_markings") == horse.get_meta("horse_markings"),"its coat survives a save")
	suite.check(Equines.armor_id(copy) == Equines.GOLD_ARMOR,"its armour survives a save")
	var chest_record: Dictionary = JSON.parse_string(JSON.stringify(Equines.snapshot(donkey)))
	var donkey_copy: Creature = spawned("donkey",game,Vector3(arena)+Vector3(-6.5,0,6.5))
	Equines.restore(donkey_copy,chest_record)
	suite.check(Equines.chest(donkey_copy).size() == 15 and int(Equines.chest(donkey_copy)[3].count) == 12,"a donkey's chest and its contents survive a save")
	var real: Dictionary = {}
	for entry in game.survival.animal_snapshot():
		if entry.kind == "donkey": real = entry
	suite.check(not real.is_empty() and real.get("equine",{}).get("chest") is Array,"the world's animal snapshot carries the equine record")
	Equines.restore(donkey_copy,{"max_health":"lots","speed":-4,"base":"plaid","armor":999,"temper":10000})
	suite.check(Equines.temper(donkey_copy) == Equines.MAX_TEMPER,"a damaged record is clamped rather than trusted")
	# Death drops the chest, its contents and the armour.
	for child in game.drops.get_children(): child.free()
	# The saddle is saved beside the equine record, so it is put back by hand here.
	copy.equip_saddle()
	copy.die()
	var dropped: Dictionary = {}
	for drop in game.drops.get_children(): dropped[drop.item_id] = true
	suite.check(dropped.has(Equines.GOLD_ARMOR) and dropped.has(Nodes.SADDLE),"a dying horse drops its armour and saddle")
	for child in game.drops.get_children(): child.free()
	donkey.die()
	var chest_drops: Dictionary = {}
	for drop in game.drops.get_children(): chest_drops[drop.item_id] = int(chest_drops.get(drop.item_id,0))+drop.amount
	suite.check(chest_drops.has(Nodes.CHEST) and int(chest_drops.get(Nodes.COBBLE,0)) == 12,"a dying donkey drops its chest and everything in it")
	for child in game.drops.get_children(): child.free()
	donkey_copy.free()

	# --- the skeleton trap -----------------------------------------------------------------------
	suite.check(Equines.trap_roll(1.5,0.01) and not Equines.trap_roll(1.5,0.02),"a trap spawns at regional difficulty × 1%")
	var trap: Creature = spawned("skeleton_horse",game,Vector3(arena)+Vector3(10.5,0,10.5))
	trap.set_meta("trap_age",0.0)
	game.player.position = Vector3(arena)+Vector3(-12.5,0,-12.5)
	suite.check(Equines.trap_step(game,trap,1.0).is_empty() and Equines.is_trap(trap),"a trap waits while no player is within ten")
	game.player.position = trap.position+Vector3(4,0,0)
	var riders: Array = Equines.trap_step(game,trap,1.0)
	suite.check(riders.size() == 4 and Equines.tamed(trap) and not Equines.is_trap(trap),"a player within ten springs it: four tamed skeleton horses, each with a rider")
	var skeleton_horses: int = 0
	for mob in game.creatures.get_children():
		if mob.kind == "skeleton_horse" and not mob.is_queued_for_deletion(): skeleton_horses += 1
	suite.check(skeleton_horses == 4,"the trap brings three more skeleton horses")
	var old_trap: Creature = spawned("skeleton_horse",game,Vector3(arena)+Vector3(-10.5,0,10.5))
	old_trap.set_meta("trap_age",899.0)
	game.player.position = Vector3(arena)+Vector3(12.5,0,-12.5)
	Equines.trap_step(game,old_trap,2.0)
	suite.check(old_trap.is_queued_for_deletion(),"an unsprung trap leaves after 900 seconds")
	hold(game,Nodes.GRAIN,1)
	var untamed_skeleton: Creature = spawned("skeleton_horse",game,Vector3(arena)+Vector3(-10.5,0,-10.5))
	suite.check(not Equines.feed(game,untamed_skeleton,Nodes.GRAIN),"skeleton horses eat nothing")

	# --- spawning and loot ---------------------------------------------------------------------------
	suite.check(Equines.spawn_share("Oakwood meadow") > 0.0 and Equines.spawn_share("Sunwash desert") == 0.0,"horse herds spawn only in the meadow")
	var herd: Array = Equines.spawn_herd(game,Vector3(arena)+Vector3(0.5,0,-8.5),RandomNumberGenerator.new())
	suite.check(herd.size() >= 1 and herd.size() <= 6,"a herd is one donkey or two to six horses (%d)" % herd.size())
	var armour_ids: Array = [Equines.COPPER_ARMOR,Equines.IRON_ARMOR,Equines.GOLD_ARMOR,Equines.DIAMOND_ARMOR]
	var loot_weights: Dictionary = {}
	for entry in Dungeons.TREASURE:
		if armour_ids.has(entry[0]): loot_weights[entry[0]] = entry[1]
	suite.check(loot_weights == {Equines.COPPER_ARMOR:15,Equines.IRON_ARMOR:15,Equines.GOLD_ARMOR:10,Equines.DIAMOND_ARMOR:5},"dungeon chests carry horse armour at the source's weights")
	for id in armour_ids: suite.check(VillageContent.DATA.has(id),"%s is a registered item" % Nodes.title(id))

	for mob in game.creatures.get_children(): mob.free()
	game.survival.mount = null
	game.inventory.slots = old_slots; game.inventory.selected = old_selected
	game.player.position = old_position
	game.gamemode = old_mode

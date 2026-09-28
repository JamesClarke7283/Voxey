extends RefCounted

# Focused regression for the husk, the drowned and the stray, their conversions,
# the zombie/skeleton drop tables, the generic `dealt_effect` hook and the regional
# difficulty they read. Reference: mobs_mc/{zombie,drowned,skeleton+stray}.lua,
# mcl_mobs/{physics,combat}.lua and mcl_worlds/init.lua.

static func spawned(kind: String, game: Node3D, pos: Vector3) -> Creature:
	var mob: Creature = game.spawn_creature(kind,pos)
	if mob != null: mob.set_physics_process(false)
	return mob

static func run(suite: Object, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var old_difficulty: int = game.difficulty
	var old_time: float = game.day_time
	var old_effects: Dictionary = game.survival.effect_snapshot()
	var old_health: float = game.player.health
	var old_position: Vector3 = game.player.position
	game.gamemode = "survival"
	for mob in game.creatures.get_children(): mob.free()

	# --- registry -----------------------------------------------------------
	for kind in UndeadVariants.KINDS:
		suite.check(Creature.KINDS.has(kind),"the %s is a registered creature" % kind)
	var zombie: Dictionary = Creature.KINDS["zombie"]
	var husk: Dictionary = Creature.KINDS["husk"]
	var drowned: Dictionary = Creature.KINDS["drowned"]
	var skeleton: Dictionary = Creature.KINDS["skeleton"]
	var stray: Dictionary = Creature.KINDS["stray"]
	suite.check(is_equal_approx(husk.health,zombie.health) and husk.damage == zombie.damage and husk.xp == zombie.xp,"a husk inherits the zombie's health, damage and experience through `table.merge`")
	suite.check(zombie.get("burns",false) and not husk.get("burns",false),"a husk is not `ignited_by_sunlight`, where a zombie is")
	suite.check(drowned.get("burns",false),"a drowned inherits the zombie's sunlight burning")
	suite.check(drowned.get("swims",false) and not drowned.get("floats",true),"a drowned swims rather than bobbing to the surface")
	suite.check(is_equal_approx(stray.health,skeleton.health) and stray.get("ranged",false) and stray.get("burns",false),"a stray inherits the skeleton's health, bow and sunlight burning")
	suite.check(not skeleton.get("can_freeze",true) and not stray.get("can_freeze",true),"skeletons and strays carry the source's `_can_freeze = false`")
	suite.check(husk.armor == zombie.armor and drowned.armor == zombie.armor and stray.armor == skeleton.armor,"the variants keep their base mob's undead armour groups")
	for kind in ["husk","drowned","stray"]:
		suite.check(PotionEffects.UNDEAD.has(kind),"the %s is undead, so healing harms it" % kind)
		suite.check(UndeadVariants.rolls_drops(kind),"the %s's drops are rolled by the variant module" % kind)
	suite.check(Heads.mob_head("husk") < 0 and Heads.mob_head("stray") < 0,"only the zombie and skeleton themselves carry a mob head, as the source's husk and stray tables omit it")

	# --- spawning substitution --------------------------------------------------
	var husk_share: float = 80.0/99.0
	suite.check(UndeadVariants.biome_variant("zombie","Sunwash desert",true,husk_share-0.001) == "husk","an outdoor desert zombie roll below 80/99 becomes a husk")
	suite.check(UndeadVariants.biome_variant("zombie","Sunwash desert",true,husk_share+0.001) == "zombie","the remaining 19/99 stay zombies, as the desert zombie spawner's weight is 19")
	suite.check(UndeadVariants.biome_variant("zombie","Sunwash desert",false,0.0) == "zombie","an indoor desert cell never spawns a husk, since the husk spawner requires open sky")
	suite.check(UndeadVariants.biome_variant("zombie","Oakwood meadow",true,0.0) == "zombie","a husk never spawns outside the desert")
	suite.check(UndeadVariants.biome_variant("skeleton","Frostpine highlands",true,0.799) == "stray","an outdoor cold-biome skeleton roll below 0.8 becomes a stray")
	suite.check(UndeadVariants.biome_variant("skeleton","Frostpine highlands",true,0.8) == "skeleton","one in five cold-biome skeletons stays a skeleton")
	suite.check(UndeadVariants.biome_variant("skeleton","Frostpine highlands",false,0.0) == "skeleton","a stray needs open sky")
	suite.check(UndeadVariants.biome_variant("skeleton","Sunwash desert",true,0.0) == "skeleton","a stray never spawns outside the cold biome")
	var hits: int = 0
	var roll_rng := RandomNumberGenerator.new(); roll_rng.seed = 4242
	for i in 2000:
		if UndeadVariants.biome_variant("zombie","Sunwash desert",true,roll_rng.randf()) == "husk": hits += 1
	suite.check(absf(float(hits)/2000.0-husk_share) < 0.04,"the husk share over two thousand rolls matches 80/99 (%d)" % hits)

	# The drowned's ocean test, on a built water column well below sea level.
	var sea: int = TerrainGenerator.SEA
	var column := Vector3i(3,sea-20,3)
	for y in range(column.y-1,sea+1):
		world.set_node(Vector3i(column.x,y,column.z),Nodes.WATER if y >= column.y else Nodes.STONE)
	suite.check(UndeadVariants.drowned_cell_allowed(world,Vector3i(column.x,sea-10,column.z),sea,1),"a deep ocean cell with the one-in-six draw spawns a drowned")
	suite.check(not UndeadVariants.drowned_cell_allowed(world,Vector3i(column.x,sea-10,column.z),sea,2),"the other five draws do not")
	suite.check(not UndeadVariants.drowned_cell_allowed(world,Vector3i(column.x,sea-5,column.z),sea,1),"a cell only five below sea level is too shallow, as the source requires `y < -5`")
	suite.check(not UndeadVariants.drowned_cell_allowed(world,Vector3i(column.x,column.y-1,column.z),sea,1),"a stone cell never spawns a drowned")
	var found: int = 0
	var cell_rng := RandomNumberGenerator.new(); cell_rng.seed = 99
	for i in 600:
		var cell: Vector3i = UndeadVariants.drowned_cell(world,Vector3(column.x+0.5,sea,column.z+0.5),cell_rng)
		if cell != Vector3i.MAX:
			found += 1
			if cell.y >= sea-5 or not Fluids.water(world.node_at(cell)): suite.check(false,"a picked drowned cell is deep water"); break
	suite.check(found > 50 and found < 170,"about one in six picks in a deep column spawns a drowned (%d of 600)" % found)

	# --- equipment ------------------------------------------------------------------
	var armed: int = 0; var tridents: int = 0; var shells: int = 0
	var equip_rng := RandomNumberGenerator.new(); equip_rng.seed = 7
	for i in 4000:
		var dummy := Node3D.new()
		UndeadVariants.equip_drowned(dummy,equip_rng)
		if UndeadVariants.wield(dummy) != 0: armed += 1
		if UndeadVariants.wield(dummy) == VillageContent.TRIDENT: tridents += 1
		if UndeadVariants.offhand(dummy) == VillageContent.NAUTILUS_SHELL: shells += 1
		dummy.free()
	suite.check(absf(float(armed)/4000.0-0.1) < 0.02,"one drowned in ten is armed (%d of 4000)" % armed)
	suite.check(armed > 0 and absf(float(tridents)/float(armed)-10.0/16.0) < 0.08,"ten armed drowned in sixteen carry a trident (%d of %d)" % [tridents,armed])
	suite.check(absf(float(shells)/4000.0-0.03) < 0.01,"three drowned in a hundred hold a nautilus shell (%d of 4000)" % shells)

	# --- drops --------------------------------------------------------------------
	var drop_rng := RandomNumberGenerator.new(); drop_rng.seed = 11
	var totals: Dictionary = {}
	for i in 12000:
		for entry in UndeadVariants.roll_drops("zombie",drop_rng,0):
			totals[entry[0]] = int(totals.get(entry[0],0))+int(entry[1])
	suite.check(absf(float(totals.get(Nodes.IRON,0))/12000.0-1.0/120.0) < 0.004,"a zombie drops iron at the source's 1 in 120 (%d of 12000)" % totals.get(Nodes.IRON,0))
	suite.check(totals.get(VillageContent.CARROT,0) > 50 and totals.get(VillageContent.POTATO,0) > 50,"a zombie also drops carrots and potatoes at 1 in 120")
	suite.check(absf(float(totals.get(Nodes.ROTTEN_FLESH,0))/12000.0-1.0) < 0.05,"a zombie drops an average of one rotten flesh (0-2)")
	var looted: int = 0
	for i in 12000:
		for entry in UndeadVariants.roll_drops("zombie",drop_rng,3):
			if entry[0] == Nodes.IRON: looted += int(entry[1])
	suite.check(absf(float(looted)/12000.0-(1.0/120.0+0.01)) < 0.005,"Looting III raises the rare iron chance by 0.01/3 per level (%d of 12000)" % looted)
	var husk_ids: Dictionary = {}
	for i in 3000:
		for entry in UndeadVariants.roll_drops("husk",drop_rng,0): husk_ids[entry[0]] = true
	suite.check(husk_ids.has(Nodes.ROTTEN_FLESH) and husk_ids.has(Nodes.IRON) and not husk_ids.has(Heads.mob_head("zombie")),"a husk drops `drops_common`: flesh and the rare items, never a head")
	var copper: int = 0
	for i in 10000:
		for entry in UndeadVariants.roll_drops("drowned",drop_rng,0):
			if entry[0] == Nodes.COPPER: copper += int(entry[1])
			if not entry[0] in [Nodes.ROTTEN_FLESH,Nodes.COPPER]: suite.check(false,"a bare drowned drops only flesh and copper")
	suite.check(absf(float(copper)/10000.0-0.11) < 0.012,"a drowned drops a copper ingot at the source's 11 in 100 (%d of 10000)" % copper)
	var stray_ids: Dictionary = {}
	var arrows_seen: int = 0
	for i in 3000:
		for entry in UndeadVariants.roll_drops("stray",drop_rng,0):
			stray_ids[entry[0]] = true
			if entry[0] == Nodes.ARROW_ITEM: arrows_seen += int(entry[1])
	suite.check(stray_ids.has(Nodes.ARROW_ITEM) and stray_ids.has(Nodes.BONE),"a stray drops arrows and bones, like the skeleton")
	suite.check(not stray_ids.has(VillageContent.SLOWNESS_ARROW),"a stray never drops a slowness arrow: the source's `table.insert` returns nil, so the entry is lost")
	suite.check(absf(float(arrows_seen)/3000.0-1.0) < 0.08,"a skeleton-family mob drops an average of one arrow (0-2)")
	var carrier := Node3D.new()
	carrier.set_meta("offhand",VillageContent.NAUTILUS_SHELL)
	var shell_drops: Array = UndeadVariants.roll_drops("drowned",drop_rng,0,carrier)
	suite.check(shell_drops.any(func(e): return e[0] == VillageContent.NAUTILUS_SHELL),"a drowned's nautilus shell always drops, since it is set with probability one")
	carrier.set_meta("wield",VillageContent.TRIDENT)
	var trident_drops: int = 0
	for i in 4000:
		for entry in UndeadVariants.roll_drops("drowned",drop_rng,0,carrier):
			if entry[0] == VillageContent.TRIDENT: trident_drops += 1
	carrier.free()
	suite.check(absf(float(trident_drops)/4000.0-0.085) < 0.015,"a drowned's trident drops at the source's 8.5 percent (%d of 4000)" % trident_drops)
	suite.check(UndeadVariants.roll_entry(drop_rng,0.0,1,1,0,false) == 0,"a zero-chance entry never drops")
	suite.check(UndeadVariants.roll_entry(drop_rng,1.0,2,2,0,true) == 2,"a certain entry drops its fixed count")

	# --- the stray's arrow and the drowned's trident ------------------------------
	suite.check(UndeadVariants.arrow_item("stray") == VillageContent.SLOWNESS_ARROW,"a stray fires `mcl_potions:slowness_arrow`")
	suite.check(UndeadVariants.arrow_item("skeleton") == Nodes.ARROW_ITEM,"a skeleton fires plain arrows")
	var base: Vector3 = Vector3(8.5,170.0,8.5)
	for x in range(-6,7):
		for z in range(-6,7):
			world.set_node(Vector3i(8+x,169,8+z),Nodes.STONE)
			for y in range(170,176): world.set_node(Vector3i(8+x,y,8+z),Nodes.AIR)
	var thrower: Creature = spawned("drowned",game,base)
	thrower.set_meta("wield",VillageContent.TRIDENT)
	suite.check(UndeadVariants.throws_trident(thrower),"a trident-armed drowned is a ranged attacker")
	var plain: Creature = spawned("drowned",game,base+Vector3(2,0,0))
	if plain.has_meta("wield"): plain.remove_meta("wield")
	suite.check(not UndeadVariants.throws_trident(plain),"an unarmed drowned is a melee attacker")
	var spear: Node3D = UndeadVariants.throw_trident(game,thrower,base+Vector3(0,1,-6))
	suite.check(spear is Arrow and spear.item_id == VillageContent.TRIDENT and not spear.recoverable,"a thrown trident is a projectile that cannot be picked up")
	suite.check(is_equal_approx(spear.velocity.length(),UndeadVariants.TRIDENT_SPEED),"the trident leaves at the source's fifty nodes per second")
	suite.check(is_equal_approx(spear.player_damage,8.0),"a thrown trident deals the source's eight")
	spear.free()
	var aim_rng := RandomNumberGenerator.new(); aim_rng.seed = 5
	var widest: float = 0.0
	for i in 200:
		widest = maxf(widest,UndeadVariants.trident_velocity(Vector3.FORWARD,2,aim_rng).normalized().angle_to(Vector3.FORWARD))
	suite.check(widest < deg_to_rad(2.5),"on hard the spread is `14 - 3 * 4` = two degrees")
	# By day a drowned only targets a player who is in water.
	game.daylight = 0.9
	game.player.position = base
	suite.check(not UndeadVariants.drowned_targets_player(game),"by day a drowned ignores a player on dry land")
	world.set_node(Vector3i(base.floor()),Nodes.WATER)
	suite.check(UndeadVariants.drowned_targets_player(game),"by day a drowned targets a player standing in water")
	world.set_node(Vector3i(base.floor()),Nodes.AIR)
	game.daylight = 0.1
	suite.check(UndeadVariants.drowned_targets_player(game),"by night a drowned targets a player anywhere")

	# --- conversions ----------------------------------------------------------------
	var step: Array = UndeadVariants.step_submerged(0.0,false,1.0)
	suite.check(step[0] == 0.0 and not step[1] and not step[2],"a surfaced zombie's clock stays at zero")
	step = UndeadVariants.step_submerged(29.5,true,1.0)
	suite.check(is_equal_approx(step[0],30.5) and step[1] and not step[2],"past thirty seconds under water the zombie shakes")
	step = UndeadVariants.step_submerged(35.0,false,1.0)
	suite.check(is_equal_approx(step[0],36.0),"past thirty seconds surfacing no longer resets the clock")
	step = UndeadVariants.step_submerged(20.0,false,1.0)
	suite.check(step[0] == 0.0,"before thirty seconds surfacing resets the clock")
	step = UndeadVariants.step_submerged(44.9,true,0.2)
	suite.check(step[2],"past forty-five seconds the zombie converts")
	step = UndeadVariants.step_frozen(6.9,true,0.2)
	suite.check(step[1] and not step[2],"after seven seconds in powder snow a skeleton shakes")
	step = UndeadVariants.step_frozen(21.9,true,0.2)
	suite.check(step[2],"after twenty-two seconds it becomes a stray")
	step = UndeadVariants.step_frozen(21.9,false,0.2)
	suite.check(step[0] == 0.0 and not step[2],"leaving the snow resets the skeleton's clock at any point")
	suite.check(UndeadVariants.CONVERT_TO["zombie"] == "drowned" and UndeadVariants.CONVERT_TO["husk"] == "zombie" and not UndeadVariants.CONVERT_TO.has("drowned"),"zombies drown into drowned, husks into zombies, and drowned never convert")

	# A real zombie held under water converts, keeping its name.
	for y in range(170,174): world.set_node(Vector3i(8,y,8),Nodes.WATER)
	var diver: Creature = spawned("zombie",game,Vector3(8.5,170.0,8.5))
	diver.custom_name = "Bubbles"
	diver.set_meta("persistent",true)
	var successor: Node3D = null
	for i in 47:
		successor = UndeadVariants.conversion_step(game,diver,1.0)
		if successor != null: break
	suite.check(successor != null and successor.kind == "drowned","a zombie kept under water for over forty-five seconds becomes a drowned")
	if successor != null:
		suite.check(successor.custom_name == "Bubbles" and successor.has_meta("persistent"),"the drowned keeps the zombie's nametag and persistence, as `replace_with` passes them")
		suite.check(diver.is_queued_for_deletion(),"the zombie itself is removed")
		successor.free()
	for y in range(170,174): world.set_node(Vector3i(8,y,8),Nodes.AIR)
	# A husk under water becomes a zombie.
	for y in range(170,174): world.set_node(Vector3i(10,y,8),Nodes.WATER)
	var sandy: Creature = spawned("husk",game,Vector3(10.5,170.0,8.5))
	var husk_next: Node3D = null
	for i in 47:
		husk_next = UndeadVariants.conversion_step(game,sandy,1.0)
		if husk_next != null: break
	suite.check(husk_next != null and husk_next.kind == "zombie","a drowning husk becomes a zombie, the source's `_convert_to`")
	if husk_next != null: husk_next.free()
	for y in range(170,174): world.set_node(Vector3i(10,y,8),Nodes.AIR)
	# A skeleton in powder snow becomes a stray.
	world.set_node(Vector3i(6,170,8),PowderSnow.ID)
	world.set_node(Vector3i(6,171,8),PowderSnow.ID)
	var chilled: Creature = spawned("skeleton",game,Vector3(6.5,170.0,8.5))
	var chilled_next: Node3D = null
	for i in 24:
		chilled_next = UndeadVariants.conversion_step(game,chilled,1.0)
		if chilled_next != null: break
	suite.check(chilled_next != null and chilled_next.kind == "stray","a skeleton kept in powder snow for twenty-two seconds becomes a stray")
	if chilled_next != null: chilled_next.free()
	world.set_node(Vector3i(6,170,8),Nodes.AIR)
	world.set_node(Vector3i(6,171,8),Nodes.AIR)
	var dry: Creature = spawned("zombie",game,Vector3(12.5,170.0,8.5))
	var dry_next: Node3D = null
	for i in 60: dry_next = UndeadVariants.conversion_step(game,dry,1.0)
	suite.check(dry_next == null and not dry.is_queued_for_deletion(),"a zombie on dry land never converts")

	# --- regional difficulty and the husk's hunger ----------------------------------
	suite.check(RegionalDifficulty.compute(0,0.0,100,0.5,1.0) == 0.0,"peaceful has no regional difficulty")
	suite.check(is_equal_approx(RegionalDifficulty.compute(2,0.0,0,0.0,1.0),1.5),"a new normal world starts at 0.75 * 2")
	suite.check(is_equal_approx(RegionalDifficulty.compute(3,0.0,0,0.0,1.0),2.25),"a new hard world starts at 0.75 * 3")
	suite.check(is_equal_approx(RegionalDifficulty.compute(1,0.0,0,0.0,1.0),0.75),"a new easy world starts at 0.75")
	# Day 10 at midnight on normal under a full moon with no inhabited time.
	var daytime: float = (10.0*24000.0+0.0-72000.0)/5760000.0
	suite.check(is_equal_approx(RegionalDifficulty.compute(2,0.0,10,0.0,1.0),(0.75+daytime+daytime)*2.0),"the day factor counts from the third day and the moon caps the chunk term")
	suite.check(is_equal_approx(RegionalDifficulty.compute(3,1e9,200,0.0,1.0),(0.75+0.25+1.0+0.25)*3.0),"a sixty-three-day world with a fully inhabited chunk reaches the hard maximum")
	suite.check(is_equal_approx(RegionalDifficulty.compute(3,1e9,200,0.0,0.0),(0.75+0.25+1.0)*3.0),"a new moon adds nothing to the chunk term")
	suite.check(RegionalDifficulty.special_from(1.9) == 0.0 and is_equal_approx(RegionalDifficulty.special_from(3.0),0.5) and RegionalDifficulty.special_from(4.5) == 1.0,"the special difficulty ramps from two to four")
	suite.check(RegionalDifficulty.source_level(0) == 1 and RegionalDifficulty.source_level(2) == 3,"Voxey's easy to hard map onto the source's levels one to three")
	suite.check(RegionalDifficulty.chunk_key("overworld",Vector3(15.4,0,-0.6)) == "overworld_0,-1" and RegionalDifficulty.chunk_key("overworld",Vector3(15.6,0,0)) == "overworld_1,0","chunks round to the nearest node before flooring, as `round_trunc` does")
	var old_table: Dictionary = RegionalDifficulty.snapshot(game)
	RegionalDifficulty.restore(game,{})
	game.player.position = Vector3(3.0,170.0,3.0)
	RegionalDifficulty.tick(game,5.0)
	RegionalDifficulty.tick(game,2.5)
	suite.check(is_equal_approx(RegionalDifficulty.inhabited_time(game,Vector3(9.0,50.0,9.0)),7.5),"time spent in a chunk accumulates for the whole column")
	suite.check(RegionalDifficulty.inhabited_time(game,Vector3(40.0,50.0,9.0)) == 0.0,"another chunk is unaffected")
	var saved: Dictionary = RegionalDifficulty.snapshot(game)
	RegionalDifficulty.restore(game,{"overworld_9,9":"junk","overworld_1,1":-4})
	suite.check(RegionalDifficulty.snapshot(game).is_empty(),"malformed or negative inhabited times are discarded on load")
	RegionalDifficulty.restore(game,saved)
	suite.check(is_equal_approx(RegionalDifficulty.inhabited_time(game,Vector3(9.0,50.0,9.0)),7.5),"inhabited time survives a snapshot and restore")
	suite.check(is_equal_approx(UndeadVariants.husk_hunger_duration(1.5),10.5),"a husk's seven seconds of hunger scale with the regional difficulty")
	game.difficulty = 1
	game.day_time = 0.3
	PotionEffects.clear(game.player)
	var biter: Creature = spawned("husk",game,game.player.position+Vector3(1,0,0))
	Creature.deal_effect(game,biter,game.player)
	suite.check(PotionEffects.level(game.player,"hunger") == 1,"a husk's landed hit gives its victim hunger")
	PotionEffects.clear(game.player)
	var rotter: Creature = spawned("zombie",game,game.player.position+Vector3(1,0,0))
	Creature.deal_effect(game,rotter,game.player)
	suite.check(PotionEffects.level(game.player,"hunger") == 0,"a zombie's hit carries no effect")
	var cave: Creature = spawned("cave_spider",game,game.player.position+Vector3(-1,0,0))
	Creature.deal_effect(game,cave,game.player)
	suite.check(PotionEffects.level(game.player,"poison") == 1,"a cave spider's landed hit now poisons through the same hook")
	PotionEffects.clear(game.player)
	RegionalDifficulty.restore(game,old_table)

	# --- sunlight --------------------------------------------------------------------
	var swimmer: Creature = spawned("drowned",game,Vector3(14.5,170.0,8.5))
	world.set_node(Vector3i(14,170,8),Nodes.WATER)
	world.set_node(Vector3i(14,171,8),Nodes.WATER)
	game.daylight = 1.0
	var before: float = swimmer.health
	swimmer.weather_step(1.0)
	suite.check(is_equal_approx(swimmer.health,before),"a sun-burning mob standing in water does not burn")
	world.set_node(Vector3i(14,170,8),Nodes.AIR)
	world.set_node(Vector3i(14,171,8),Nodes.AIR)

	# --- models -----------------------------------------------------------------------
	for kind in UndeadVariants.KINDS:
		var body: Creature = spawned(kind,game,Vector3(8.5,170.0,12.5))
		suite.check(body != null and body.head != null and body.legs.size() == 2,"the %s builds a biped body with a head" % kind)
		if body != null: body.free()
	var armed_body: Creature = game.spawn_creature("drowned",Vector3(8.5,170.0,12.5))
	armed_body.set_physics_process(false)
	armed_body.set_meta("wield",VillageContent.TRIDENT)
	UndeadVariants.refresh_held(armed_body)
	var held: int = 0
	for child in armed_body.arms[1].get_children():
		if child.has_meta("held") and not child.is_queued_for_deletion(): held += 1
	suite.check(held == 4,"a trident-armed drowned visibly holds its trident")
	armed_body.free()

	for mob in game.creatures.get_children(): mob.free()
	game.difficulty = old_difficulty
	game.day_time = old_time
	game.survival.restore_effects(old_effects)
	game.player.health = old_health
	game.player.position = old_position

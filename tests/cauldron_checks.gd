extends RefCounted

static func equip(inv: Inventory, id: int, count: int = 1) -> void:
	inv.restore([]); inv.selected = 0
	inv.slots[0] = {"id":id,"count":count,"wear":0}

static func run(t: SceneTree, game: Node3D = null) -> void:
	var inv := Inventory.new()
	var station: Dictionary = {"kind":"cauldron","water":2,"slots":[]}
	t.check(Cauldrons.level(station) == 2 and Cauldrons.liquid(station) == "water","legacy cauldron levels remain ordinary water without a liquid field")
	var result: Dictionary
	for n in 3:
		if n == 0: station = {"kind":"cauldron"}
		equip(inv,VillageContent.WATER_BOTTLE)
		result = Cauldrons.transact(inv,station)
		t.check(result.changed and Cauldrons.level(station) == n+1 and inv.held().id == VillageContent.GLASS_BOTTLE,"pouring water bottle %d fills one level and replaces the held bottle"%(n+1))
	equip(inv,VillageContent.WATER_BOTTLE)
	result = Cauldrons.transact(inv,station)
	t.check(not result.changed and inv.held().id == VillageContent.WATER_BOTTLE and Cauldrons.level(station) == 3,"a full cauldron refuses surplus water without destroying the bottle")
	for n in 3:
		equip(inv,VillageContent.GLASS_BOTTLE)
		result = Cauldrons.transact(inv,station)
		t.check(result.changed and Cauldrons.level(station) == 2-n and inv.held().id == VillageContent.WATER_BOTTLE,"bottling water portion %d removes exactly one level"%(n+1))
	equip(inv,VillageContent.GLASS_BOTTLE)
	t.check(not Cauldrons.transact(inv,station).changed and inv.held().id == VillageContent.GLASS_BOTTLE,"an empty cauldron cannot fill a bottle")
	for bucket in [Nodes.WATER_BUCKET,Nodes.LAVA_BUCKET]:
		station = {"kind":"cauldron"}; equip(inv,bucket)
		inv.held()["data"] = {"custom_name":"Traveller's bucket"}
		result = Cauldrons.transact(inv,station)
		t.check(result.changed and Cauldrons.level(station) == 3 and inv.held().id == Nodes.BUCKET and inv.held().data.custom_name == "Traveller's bucket","bucket %d fills the cauldron and preserves metadata on the returned container"%bucket)
		result = Cauldrons.transact(inv,station)
		t.check(result.changed and Cauldrons.level(station) == 0 and inv.held().id == bucket and inv.held().data.custom_name == "Traveller's bucket","empty bucket retrieves full cauldron %d without changing its liquid"%bucket)
	station = {"kind":"cauldron","water":2}; equip(inv,Nodes.BUCKET)
	t.check(not Cauldrons.transact(inv,station).changed and inv.held().id == Nodes.BUCKET and Cauldrons.level(station) == 2,"an empty bucket cannot collect a partly filled cauldron")
	equip(inv,Nodes.WATER_BUCKET); result = Cauldrons.transact(inv,station)
	t.check(result.changed and Cauldrons.level(station) == 3 and inv.held().id == Nodes.BUCKET,"a matching bucket tops up a partly filled cauldron")
	for pair in [["water",Nodes.LAVA_BUCKET],["lava",Nodes.WATER_BUCKET],["lava",VillageContent.WATER_BOTTLE],["lava",VillageContent.GLASS_BOTTLE]]:
		station = {"kind":"cauldron","water":2,"liquid":pair[0]}; equip(inv,pair[1])
		var before: Dictionary = station.duplicate(true)
		result = Cauldrons.transact(inv,station)
		t.check(not result.changed and station == before and inv.held().id == pair[1],"cauldron rejects incompatible liquid or lava bottling (%s, %d)"%[pair[0],pair[1]])
	station = {"kind":"cauldron","water":3}; equip(inv,Nodes.BUCKET,2)
	for i in range(1,inv.slots.size()): inv.slots[i] = {"id":Nodes.STONE,"count":64,"wear":0}
	result = Cauldrons.transact(inv,station)
	t.check(result.changed and Cauldrons.level(station) == 0 and inv.held().count == 1 and result.drops == [{"id":Nodes.WATER_BUCKET,"count":1,"wear":0}],"full inventory returns bucket overflow as one world-drop stack without deleting it")
	station = {"kind":"cauldron","water":3}; equip(inv,Nodes.BUCKET)
	for i in range(1,inv.slots.size()): inv.slots[i] = {"id":Nodes.STONE,"count":64,"wear":0}
	result = Cauldrons.transact(inv,station)
	t.check(result.changed and result.drops.is_empty() and inv.held().id == Nodes.WATER_BUCKET,"single-container exchange uses the selected slot even with a full inventory")
	station = {"kind":"cauldron","water":3}; equip(inv,VillageContent.GLASS_BOTTLE,3)
	result = Cauldrons.transact(inv,station)
	t.check(inv.held().id == VillageContent.GLASS_BOTTLE and inv.held().count == 2 and inv.count_item(VillageContent.WATER_BOTTLE) == 1 and Cauldrons.level(station) == 2,"a stacked glass bottle consumes one and adds exactly one water bottle")
	for bucket in [Nodes.WATER_BUCKET,Nodes.LAVA_BUCKET]:
		station = {"kind":"cauldron"}; equip(inv,bucket)
		result = Cauldrons.transact(inv,station,true)
		t.check(result.changed and inv.held().id == bucket and inv.count_item(Nodes.BUCKET) == 0,"creative bucket %d fills without taking or returning items"%bucket)
		equip(inv,Nodes.BUCKET); result = Cauldrons.transact(inv,station,true)
		t.check(result.changed and Cauldrons.level(station) == 0 and inv.held().id == Nodes.BUCKET and inv.count_item(bucket) == 0,"creative empty bucket clears liquid %d without giving a filled bucket"%bucket)
	station = {"kind":"cauldron"}; equip(inv,VillageContent.WATER_BOTTLE)
	Cauldrons.transact(inv,station,true); Cauldrons.transact(inv,station,true)
	t.check(inv.count_item(VillageContent.WATER_BOTTLE) == 1 and inv.count_item(VillageContent.GLASS_BOTTLE) == 1 and Cauldrons.level(station) == 2,"creative water bottles preserve input and give an empty bottle only once")
	equip(inv,VillageContent.GLASS_BOTTLE)
	Cauldrons.transact(inv,station,true); Cauldrons.transact(inv,station,true)
	t.check(inv.count_item(VillageContent.GLASS_BOTTLE) == 1 and inv.count_item(VillageContent.WATER_BOTTLE) == 2 and Cauldrons.level(station) == 0,"creative glass bottles preserve input and receive each extracted portion")
	station = {"kind":"cauldron","water":3,"liquid":"lava","slots":[]}
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(station))
	t.check(Cauldrons.level(roundtrip) == 3 and Cauldrons.liquid(roundtrip) == "lava","cauldron liquid and level survive JSON save serialization")
	for n in range(4):
		Cauldrons.set_contents(station,n)
		t.check(Cauldrons.level(station) == n,"comparator-ready cauldron fill signal is %d"%n)
	var malformed: Array = [{"water":-1},{"water":7},{"water":"invalid"},{"water":INF}]
	t.check(Cauldrons.level(malformed[0]) == 0 and Cauldrons.level(malformed[1]) == 3 and Cauldrons.level(malformed[2]) == 0 and Cauldrons.level(malformed[3]) == 0,"invalid or out-of-range saved fill values normalize safely")
	var recipe: Dictionary = inv.recipes[inv.recipe_index(VillageContent.CAULDRON)]
	t.check(recipe.ingredients == {Nodes.IRON:7} and recipe.width == 3,"cauldron survival recipe uses the source's seven iron ingots")
	_washing_checks(t)
	_rain_checks(t)
	# Optional integration checks run when called by a gameplay suite.
	if game == null: return
	var p := Vector3i(8,164,8)
	game.world.set_node(p,VillageContent.CAULDRON)
	inv = game.inventory; game.inventory.selected = 0; game.gamemode = "survival"
	equip(inv,VillageContent.WATER_BOTTLE)
	game.player.target = {"pos":p,"id":VillageContent.CAULDRON,"normal":Vector3i.UP,"distance":2.0}
	game.survival.use()
	var stored: Dictionary = game.world.get_station(p,"cauldron")
	t.check(Cauldrons.level(stored) == 1 and inv.held().id == VillageContent.GLASS_BOTTLE,"using a water bottle on a cauldron pours before generic potion handling")
	t.check(game.world.circuits.container_signal(p) == 1,"the redstone comparator reads the real cauldron level")
	game.world.set_node(p+Vector3i.RIGHT,Nodes.COMPARATOR)
	game.world.circuits.configure(p+Vector3i.RIGHT,Vector3i.RIGHT)
	game.world.circuits.step(0.1)
	t.check(game.world.circuits.state(p+Vector3i.RIGHT).get("out",0) == 1,"a live comparator transmits cauldron fill through the circuit")
	game.world.set_node(p,Nodes.AIR); game.world.set_node(p,VillageContent.CAULDRON)
	t.check(Cauldrons.level(game.world.get_station(p,"cauldron")) == 0,"breaking and replacing a cauldron cannot restore its removed liquid")
	_live_checks(t,game,p)

static func _washing_checks(t: SceneTree) -> void:
	var inv := Inventory.new()
	var metadata: Dictionary = {"custom_name":"Cargo","contents":[{"id":Nodes.DIAMOND,"count":7,"wear":0},{"id":Nodes.BOW,"count":1,"wear":9,"data":{"enchantments":{"Power":3}}}]}
	for color in range(16):
		var id: int = PortableStorage.SHULKER_BASE+color
		if id == PortableStorage.SHULKER_PURPLE: continue
		equip(inv,id); inv.held()["data"] = metadata.duplicate(true)
		var state: Dictionary = {"kind":"cauldron","water":3}
		var result: Dictionary = Cauldrons.transact(inv,state)
		t.check(result.changed and inv.held().id == PortableStorage.SHULKER_PURPLE and inv.held().data == metadata and Cauldrons.level(state) == 2,"washing shulker color %d consumes one portion and preserves all cargo and metadata"%color)
	for pair in [[0,""],[3,"lava"]]:
		equip(inv,PortableStorage.SHULKER_BASE); inv.held()["data"] = metadata.duplicate(true)
		var state: Dictionary = {"kind":"cauldron","water":pair[0],"liquid":pair[1]}
		t.check(not Cauldrons.transact(inv,state).changed and inv.held().id == PortableStorage.SHULKER_BASE and inv.held().data == metadata,"an empty or lava cauldron cannot wash a colored shulker")
	equip(inv,PortableStorage.SHULKER_PURPLE)
	var state: Dictionary = {"kind":"cauldron","water":3}
	t.check(not Cauldrons.transact(inv,state).changed and Cauldrons.level(state) == 3,"a canonical purple shulker does not waste cauldron water")
	equip(inv,PortableStorage.SHULKER_BASE); inv.held()["data"] = metadata.duplicate(true)
	for i in range(1,inv.slots.size()): inv.slots[i] = {"id":Nodes.STONE,"count":64,"wear":0}
	var result: Dictionary = Cauldrons.transact(inv,state,true)
	t.check(result.changed and result.drops.is_empty() and inv.held().id == PortableStorage.SHULKER_PURPLE and inv.held().count == 1 and inv.held().data == metadata and Cauldrons.level(state) == 2,"creative washing transforms the original box in a full inventory without duplication")

static func _rain_checks(t: SceneTree) -> void:
	t.check(Cauldrons.rainy_biome("Oakwood meadow") and Cauldrons.rainy_biome("Swamp") and not Cauldrons.rainy_biome("Sunwash desert") and not Cauldrons.rainy_biome("Frostpine highlands"),"existing temperate, dry and snowy biomes determine rain eligibility without introducing weather")
	var state: Dictionary = {"kind":"cauldron"}
	t.check(not Cauldrons.rain_step(state,55.9,true) and Cauldrons.level(state) == 0,"rain waits the source's fifty-six-second interval")
	t.check(Cauldrons.rain_step(state,0.1,true) and Cauldrons.level(state) == 1,"exposed rain adds exactly one water portion at fifty-six seconds")
	state = JSON.parse_string(JSON.stringify(state))
	Cauldrons.rain_step(state,28,true)
	state = JSON.parse_string(JSON.stringify(state))
	t.check(Cauldrons.rain_step(state,28,true) and Cauldrons.level(state) == 2,"partial rain progress survives saved station serialization")
	Cauldrons.rain_step(state,56,true)
	t.check(not Cauldrons.rain_step(state,56,true) and Cauldrons.level(state) == 3,"rain stops at a full cauldron")
	for material in ["water","lava"]:
		state = {"kind":"cauldron","water":2,"liquid":material}
		t.check(not Cauldrons.rain_step(state,56,false) and Cauldrons.level(state) == 2,"ineligible weather leaves "+material+" cauldrons unchanged")
	state = {"kind":"cauldron","water":2,"liquid":"lava"}
	t.check(not Cauldrons.rain_step(state,56,true) and Cauldrons.liquid(state) == "lava" and Cauldrons.level(state) == 2,"rain cannot dilute a lava cauldron")
	state = {"kind":"cauldron","rain_clock":"invalid"}
	t.check(Cauldrons.rain_step(state,56,true) and Cauldrons.level(state) == 1,"invalid saved rain timers normalize safely")

static func _live_checks(t: SceneTree, game: Node3D, p: Vector3i) -> void:
	var previous_position: Vector3 = game.player.position
	var previous_mode: String = game.gamemode
	var previous_weather: Variant = game.world.adventure_state.get("weather")
	var previous_effects: Dictionary = PotionEffects.snapshot(game.player)
	var previous_health: float = game.player.health
	var previous_nutrition: Dictionary = Hunger.snapshot(game.player)
	var previous_damage_cooldown: float = game.player.damage_cooldown
	var previous_armor: Array = game.player.armor_slots.duplicate(true)
	var stored: Dictionary = game.world.get_station(p,"cauldron")
	game.gamemode = "survival"; game.player.health = 20
	PotionEffects.clear(game.player)
	game.player.position = Vector3(p)+Vector3(0.5,0.314,0.5)
	Cauldrons.set_contents(stored,3)
	t.check(not game.world.intersects(game.player.position) and game.world.intersects(Vector3(p)+Vector3(0.5,0.29,0.5)) and game.world.intersects(Vector3(p)+Vector3(0.1,0.314,0.5)),"real collision permits entering the hollow basin but keeps its floor and walls solid")
	PotionEffects.apply(game.player,"burning",12); game.player.set_meta("effectclock_burning",0.9)
	t.check(Cauldrons.contact(game,p,stored) and PotionEffects.level(game.player,"burning") == 0 and not game.player.has_meta("effectclock_burning") and Cauldrons.level(stored) == 2,"water contact extinguishes the player and spends one portion without residual burn damage")
	t.check(not Cauldrons.contact(game,p,stored) and Cauldrons.level(stored) == 2,"remaining in water while not burning spends no further portions")
	PotionEffects.apply(game.player,"burning",12)
	game.player.position = Vector3(p)+Vector3(0.5,1.0,0.5)
	t.check(not Cauldrons.contact(game,p,stored) and PotionEffects.level(game.player,"burning") > 0 and Cauldrons.level(stored) == 2,"standing on the rim does not consume water or extinguish through iron")
	game.player.position = Vector3(p)+Vector3(1.1,0.314,0.5)
	t.check(not Cauldrons.contact(game,p,stored) and PotionEffects.level(game.player,"burning") > 0,"standing beside the outside wall cannot touch cauldron liquid")
	PotionEffects.clear(game.player)
	Cauldrons.set_contents(stored,3)
	game.player.position = Vector3(p)+Vector3(0.5,0.314,0.5)
	PotionEffects.apply(game.player,"burning",12); game.world.set_meta("cauldron_contact_clock",0.0)
	Cauldrons.update(game.world,0.49)
	t.check(PotionEffects.level(game.player,"burning") > 0 and Cauldrons.level(stored) == 3,"cauldron contact respects the source half-second interval")
	Cauldrons.update(game.world,0.01)
	t.check(PotionEffects.level(game.player,"burning") == 0 and Cauldrons.level(stored) == 2,"the real cauldron update extinguishes when its half-second interval elapses")
	game.player.position = Vector3(p)+Vector3(1.1,0.314,0.5)
	var pig: Creature = game.spawn_creature("pig",Vector3(p)+Vector3(0.5,0.314,0.5)); pig.set_physics_process(false)
	PotionEffects.apply(pig,"burning",8)
	t.check(Cauldrons.contact(game,p,stored) and PotionEffects.level(pig,"burning") == 0 and Cauldrons.level(stored) == 1,"water contact extinguishes a burning creature with exactly one portion")
	game.player.position = Vector3(p)+Vector3(0.5,0.314,0.5)
	PotionEffects.apply(game.player,"burning",8); PotionEffects.apply(pig,"burning",8)
	Cauldrons.contact(game,p,stored)
	t.check(Cauldrons.level(stored) == 0 and PotionEffects.level(game.player,"burning") == 0 and PotionEffects.level(pig,"burning") > 0,"one remaining water portion extinguishes only one of two burning actors")
	PotionEffects.clear(pig)
	Cauldrons.set_contents(stored,3,"lava")
	game.player.position = Vector3(p)+Vector3(0.5,0.314,0.5)
	for i in 4: game.player.armor_slots[i] = {"id":0,"count":0,"wear":0}
	Cauldrons.contact(game,p,stored)
	t.check(game.survival.effects.get("burning",0) == 5 and float(pig.get_meta("effect_burning",0)) == 5 and Cauldrons.level(stored) == 3,"lava ignites player and creature for five seconds without consuming its fill")
	game.player.damage_cooldown = 0; PotionEffects.update(game.player,1.1)
	t.check(game.player.health < 20,"cauldron ignition causes real continuing burn damage")
	PotionEffects.clear(game.player); game.player.health = 20
	PotionEffects.apply(game.player,"fire_resistance",20)
	Cauldrons.contact(game,p,stored); game.player.damage_cooldown = 0; PotionEffects.update(game.player,1.1)
	t.check(game.player.health == 20,"fire resistance prevents lava-cauldron burn damage")
	PotionEffects.clear(game.player)
	game.player.armor_slots[0] = {"id":Nodes.armor_id(0,0),"count":1,"wear":0,"data":{"enchantments":{"Fire Protection":4}}}
	Cauldrons.contact(game,p,stored)
	t.check(game.survival.effects.get("burning",0) == 2,"highest equipped Fire Protection shortens five-second ignition using source duration reduction")
	PotionEffects.clear(game.player); game.gamemode = "creative"
	Cauldrons.contact(game,p,stored)
	t.check(PotionEffects.level(game.player,"burning") == 0,"creative players are not ignited by lava cauldrons")
	Farming.forget(pig); pig.free()
	var blaze: Creature = game.spawn_creature("blaze",Vector3(p)+Vector3(0.5,0.314,0.5)); blaze.set_physics_process(false)
	Cauldrons.contact(game,p,stored)
	t.check(PotionEffects.level(blaze,"burning") == 0,"fireproof creatures are not harmed by lava cauldron ignition")
	blaze.free()
	game.player.position = previous_position
	# An existing loaded temperate coordinate makes weather tests independent
	# of whether the fixed integration fixture happens to be snowy or dry.
	var rainy: Vector3i = p
	for x in range(-16,32):
		for z in range(-16,32):
			var candidate := Vector3i(x,p.y,z)
			if game.world.loaded_at(Vector3(candidate)) and game.world.generator.biome(x,z) not in ["Sunwash desert","Frostpine highlands"]: rainy = candidate; break
	game.world.set_node(rainy,VillageContent.CAULDRON); game.world.set_node(rainy+Vector3i.UP,Nodes.AIR)
	t.check(game.world.stations.has(VoxelWorld.station_key(rainy)),"newly placed cauldrons register for rainfall before any player interaction")
	stored = game.world.get_station(rainy,"cauldron"); Cauldrons.set_contents(stored,0)
	game.world.adventure_state.weather = "rain"
	t.check(Cauldrons.rain_eligible(game.world,rainy),"authoritative rain and exposed temperate sky qualify for filling")
	stored.rain_clock = 55.5; Cauldrons.update(game.world,0.5)
	t.check(Cauldrons.level(stored) == 1,"the live cauldron update fills an exposed newly placed cauldron")
	game.world.stations[VoxelWorld.station_key(rainy)] = JSON.parse_string(JSON.stringify({"kind":"cauldron","water":2,"slots":[],"rain_clock":55.5}))
	stored = Cauldrons.station(game.world,rainy)
	Cauldrons.update(game.world,0.5)
	t.check(Cauldrons.level(stored) == 3 and Cauldrons.liquid(stored) == "water","loading and registering a nonempty legacy cauldron preserves its water and continues rainfall")

	# --- snowfall fills a cauldron with powder snow --------------------------
	# The source's own ABM fills with powder snow where it is snowing and with water
	# where it is raining, on the same interval, so a cold biome needs both the
	# collection gate and the material choice.
	t.check(Cauldrons.MATERIALS.has("powder_snow"),"powder snow is a cauldron material")
	t.check(Cauldrons.collecting_biome("Frostpine highlands") and not Cauldrons.collecting_biome("Sunwash desert"),"a snowy biome collects precipitation while an arid one does not")
	# A powder-snow level round-trips instead of being coerced to water.
	var snow_station: Dictionary = {"kind":"cauldron"}
	Cauldrons.set_contents(snow_station,2,"powder_snow")
	t.check(Cauldrons.level(snow_station) == 2 and Cauldrons.liquid(snow_station) == "powder_snow","a powder-snow cauldron reports its own material rather than defaulting to water")
	var snow_roundtrip: Dictionary = JSON.parse_string(JSON.stringify(snow_station))
	t.check(Cauldrons.liquid(snow_roundtrip) == "powder_snow","powder snow survives save serialization")
	# A real cold column chooses powder snow, and a temperate one chooses water.
	var cold_column := Vector3i(0,0,0)
	var warm_column := Vector3i(0,0,0)
	for x in range(-50,51):
		for z in range(-50,51):
			if not game.world.loaded_at(Vector3(x,200,z)): continue
			var top := Vector3i(x,200,z)
			if cold_column == Vector3i.ZERO and game.world.generator.biome(x,z) == "Frostpine highlands": cold_column = top
			elif warm_column == Vector3i.ZERO and Cauldrons.collecting_biome(game.world.generator.biome(x,z)) and game.world.generator.biome(x,z) != "Frostpine highlands": warm_column = top
	if cold_column != Vector3i.ZERO:
		game.world.set_node(cold_column,Nodes.AIR)
		if Weather.has_snow(game.world,cold_column):
			t.check(Cauldrons.precipitation_material(game.world,cold_column) == "powder_snow","an exposed cold column collects powder snow")
	if warm_column != Vector3i.ZERO:
		game.world.set_node(warm_column,Nodes.AIR)
		var warm_material: String = Cauldrons.precipitation_material(game.world,warm_column)
		t.check(warm_material == "water" or not Weather.has_snow(game.world,warm_column),"a temperate column collects water rather than powder snow")
	# A bucket of powder snow fills the cauldron, and an empty bucket scoops it back.
	var snow_inv := Inventory.new(); snow_inv.slots.resize(36)
	for i in snow_inv.slots.size(): snow_inv.slots[i] = {"id":0,"count":0,"wear":0}
	snow_inv.selected = 0; snow_inv.slots[0] = {"id":PowderSnow.BUCKET,"count":1,"wear":0}
	var snow_fill: Dictionary = {"kind":"cauldron"}
	var fill_result: Dictionary = Cauldrons.transact(snow_inv,snow_fill,false)
	t.check(fill_result.changed and Cauldrons.liquid(snow_fill) == "powder_snow" and Cauldrons.level(snow_fill) == 3,"a powder-snow bucket fills the cauldron with powder snow")
	snow_inv.slots[0] = {"id":Nodes.BUCKET,"count":1,"wear":0}
	var scoop_result: Dictionary = Cauldrons.transact(snow_inv,snow_fill,false)
	t.check(scoop_result.changed and Cauldrons.level(snow_fill) == 0 and snow_inv.held().id == PowderSnow.BUCKET,"an empty bucket scoops powder snow back out of a full cauldron")
	game.world.adventure_state.weather = "thunder"
	t.check(Cauldrons.rain_eligible(game.world,rainy),"authoritative thunderstorms also fill exposed cauldrons")
	game.world.set_node(rainy+Vector3i.UP,Nodes.STONE)
	t.check(not Cauldrons.rain_eligible(game.world,rainy),"a roof immediately above the rim blocks rainfall")
	game.world.set_node(rainy+Vector3i.UP,Nodes.AIR); game.world.adventure_state.weather = "clear"
	t.check(not Cauldrons.rain_eligible(game.world,rainy),"clear weather cannot fill a cauldron")
	game.world.adventure_state.weather = "rain"
	var previous_dimension: String = game.world.dimension
	game.world.dimension = "nether"
	t.check(not Cauldrons.rain_eligible(game.world,rainy),"other dimensions cannot collect overworld rainfall")
	game.world.dimension = previous_dimension
	game.player.position = previous_position; game.player.health = previous_health; game.player.armor_slots = previous_armor
	Hunger.restore(game.player,previous_nutrition); game.player.damage_cooldown = previous_damage_cooldown
	game.survival.restore_effects(previous_effects); game.gamemode = previous_mode
	if previous_weather == null: game.world.adventure_state.erase("weather")
	else: game.world.adventure_state.weather = previous_weather

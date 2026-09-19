class_name Farming
extends RefCounted

# mcl_mobs/breeding.lua stores age/love in 20 Hz ticks; Voxey uses seconds.
const LOVE_TIME = 15.0
const BREED_TIME = 3.5
const COOLDOWN = 300.0
const GROW_TIME = 1200.0
const COLOR_MIXES = {"blue+green":"cyan","black+white":"grey","blue+white":"light_blue","green+white":"lime","pink+purple":"magenta","red+yellow":"orange","red+white":"pink","blue+red":"purple","grey+white":"silver"}
const FOODS = {
	"cow":[Nodes.GRAIN],"sheep":[Nodes.GRAIN],
	"pig":[VillageContent.CARROT,VillageContent.POTATO,VillageContent.BEETROOT],
	"chicken":[Nodes.SEEDS,VillageContent.BEETROOT_SEEDS,FruitCrops.PUMPKIN_SEEDS,FruitCrops.MELON_SEEDS],
	"rabbit":[VillageContent.CARROT,VillageContent.GOLDEN_CARROT]
}

static func supports(kind: String) -> bool: return FOODS.has(kind)

static func saved_kind(kind: String, custom_name: String) -> bool:
	return supports(kind) or not custom_name.is_empty() and kind not in ["horse","ender_dragon","end_crystal","villager","iron_golem","snow_golem","piglin","piglin_brute","silverfish","turtle","phantom","breeze","pillager"] and Creature.KINDS.has(kind)

static func managed(mob: Creature) -> bool:
	if supports(mob.kind): return true
	return not mob.custom_name.is_empty() and mob.kind not in ["horse","ender_dragon","end_crystal","snow_golem"] and not (mob is VillageMob or mob is NetherResident or mob is AlchemyCreature)

static func records(game: Node3D) -> Dictionary:
	if not game.world.adventure_state.get("farm_animals") is Dictionary: game.world.adventure_state["farm_animals"] = {}
	return game.world.adventure_state.farm_animals

static func register(mob: Creature) -> void:
	if not managed(mob): return
	if mob.farm_id.is_empty():
		var serial: int = int(number(mob.game.world.adventure_state.get("farm_serial",0),0,2147483646))
		while true:
			serial += 1
			mob.farm_id = "animal_%d"%serial
			if not records(mob.game).has(mob.farm_id): break
		mob.game.world.adventure_state["farm_serial"] = serial
	remember(mob)

static func state(mob: Creature) -> Dictionary:
	return {"kind":mob.kind,"farm_id":mob.farm_id,"position":[mob.position.x,mob.position.y,mob.position.z],"yaw":mob.model.rotation.y,
		"health":mob.health,"custom_name":mob.custom_name,"growth":mob.growth_remaining,"love":mob.love_time,"cooldown":mob.breed_cooldown,
		"sheared":mob.sheared,"sheep_color":mob.sheep_color,"grazing":mob.grazing,"graze_consumed":mob.graze_consumed,"wool_timer":mob.wool_timer,"egg_timer":mob.egg_timer,"effects":PotionEffects.snapshot(mob),
		"slime_size":mob.slime_size if mob is ExpeditionCreature and mob.kind == "slime" else 0,"crystal_key":mob.crystal_key if mob is ExpeditionCreature else ""}

static func remember(mob: Creature) -> void:
	if not managed(mob) or mob.is_queued_for_deletion() or mob.health <= 0: return
	if mob.farm_id.is_empty(): register(mob); return
	records(mob.game)[mob.farm_id] = state(mob)

static func snapshot(game: Node3D) -> void:
	for mob in game.creatures.get_children(): remember(mob)

static func forget(mob: Creature) -> void:
	if not mob.farm_id.is_empty(): records(mob.game).erase(mob.farm_id)

static func active(game: Node3D, key: String) -> Creature:
	if key.is_empty(): return null
	for mob in game.creatures.get_children():
		if not mob.is_queued_for_deletion() and mob.farm_id == key: return mob
	return null

static func number(value: Variant, fallback: float, high: float) -> float:
	if not (value is int or value is float) or not is_finite(float(value)): return fallback
	return clampf(float(value),0,high)

static func restore_state(mob: Creature, entry: Dictionary) -> void:
	if mob is ExpeditionCreature:
		mob.crystal_key = str(entry.get("crystal_key",""))
		if mob.kind == "slime": mob.set_slime_size(clampi(int(number(entry.get("slime_size"),2,4)),1,4))
	mob.health = number(entry.get("health"),mob.info().health,mob.info().health)
	mob.custom_name = NameTags.bounded(str(entry.get("custom_name","")),30)
	mob.growth_remaining = number(entry.get("growth"),0,GROW_TIME) if supports(mob.kind) else 0
	mob.love_time = number(entry.get("love"),0,LOVE_TIME) if supports(mob.kind) else 0
	mob.breed_cooldown = number(entry.get("cooldown"),0,COOLDOWN) if supports(mob.kind) else 0
	if mob.growth_remaining > 0: mob.love_time = 0; mob.breed_cooldown = 0
	mob.sheared = bool(entry.get("sheared",false)) and mob.kind == "sheep"
	mob.wool_timer = number(entry.get("wool_timer"),100,160)
	mob.egg_timer = number(entry.get("egg_timer"),randi_range(300,600),600)
	restore_coat(mob,entry)
	var yaw: Variant = entry.get("yaw",0)
	mob.model.rotation.y = float(yaw) if (yaw is float or yaw is int) and is_finite(float(yaw)) else 0.0
	var effects: Variant = entry.get("effects",{})
	if effects is Dictionary:
		for effect in effects:
			if not effects[effect] is Dictionary: continue
			PotionEffects.apply(mob,str(effect),number(effects[effect].get("duration"),0,6000),int(number(effects[effect].get("level"),1,6)))
			if effect == "absorption": PotionEffects.restore_absorption(mob,effects[effect].get("remaining",0))
	if supports(mob.kind): resize(mob)
	for part in mob.wool_parts: part.visible = not mob.sheared
	NameTags.refresh(mob)

static func resolve(game: Node3D, key: String) -> Creature:
	var mob: Creature = active(game,key)
	if mob != null: return mob
	var saved: Variant = records(game).get(key)
	if not saved is Dictionary or not saved_kind(str(saved.get("kind","")),str(saved.get("custom_name",""))): return null
	var location: Dictionary = WorldBounds.clean_location({"dimension":game.dimension,"position":saved.get("position")})
	if location.is_empty() or number(saved.get("health"),1,10000) <= 0: records(game).erase(key); return null
	var entry: Dictionary = saved.duplicate(true)
	mob = game.spawn_creature(entry.kind,VillageLife.vec(location.position),key)
	if mob == null: return null
	restore_state(mob,entry)
	remember(mob)
	return mob

static func update_world(game: Node3D, delta: float = 1.0) -> void:
	var timer: float = float(game.world.get_meta("farm_restore_timer",0))+delta
	if timer < 0.5: game.world.set_meta("farm_restore_timer",timer); return
	game.world.set_meta("farm_restore_timer",0.0)
	for key in records(game).keys():
		if active(game,str(key)) != null: continue
		var entry: Variant = records(game)[key]
		if not entry is Dictionary or not entry.get("position") is Array or entry.position.size() != 3: continue
		var location: Dictionary = WorldBounds.clean_location({"dimension":game.dimension,"position":entry.position})
		if location.is_empty(): continue
		var p: Vector3 = VillageLife.vec(location.position)
		if p.distance_to(game.player.position) < 80 and game.world.loaded_at(p): resolve(game,str(key))

static func sleep_if_unloaded(mob: Creature) -> bool:
	if not managed(mob): return false
	if mob.game.world.loaded_at(mob.position) and mob.position.distance_to(mob.game.player.position) <= 90: return false
	remember(mob)
	mob.game.leads.hibernate(mob)
	mob.queue_free()
	return true

static func use(game: Node3D, mob: Creature) -> bool:
	if mob == null or not supports(mob.kind) or mob.is_queued_for_deletion() or mob.health <= 0: return false
	var held: Dictionary = game.inventory.held()
	if held.count <= 0: return false
	if mob.kind == "sheep" and VillageContent.DATA.get(held.id,{}).get("family","") == "dye":
		if mob.sheared: game.toast("Sheep need wool before they can be dyed."); return true
		set_color(mob,str(VillageContent.DATA[held.id].dye))
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.sound("place"); remember(mob)
		return true
	if held.id not in FOODS[mob.kind]: return false
	var consumed: bool = false
	if mob.health < mob.info().health:
		mob.health = minf(mob.info().health,mob.health+4); consumed = true
	elif mob.growth_remaining > 0:
		mob.growth_remaining *= 0.9; consumed = true
	elif mob.breed_cooldown <= 0 and mob.love_time <= 0:
		mob.love_time = LOVE_TIME; consumed = true
	if consumed:
		if game.gamemode != "creative": game.inventory.consume_selected()
		game.puff(mob.center(),Color("ef7c8f"),6,1.2)
		game.sound("eat"); remember(mob)
	else: game.toast("This animal is not hungry right now.")
	return true

static func resize(mob: Creature) -> void:
	var small: bool = mob.growth_remaining > 0
	mob.width = mob.info().width*(0.5 if small else 1.0)
	mob.height = mob.info().height*(0.5 if small else 1.0)
	CreatureArt.farm_age(mob,small)
	NameTags.refresh(mob)

static func visible(a: Creature, b: Creature) -> bool:
	var offset: Vector3 = b.center()-a.center()
	if offset.length() < 0.01: return true
	return a.game.world.raycast(a.center(),offset.normalized(),offset.length()).is_empty()

static func tick(mob: Creature, delta: float) -> void:
	if not supports(mob.kind) or mob.health <= 0: return
	if mob.growth_remaining > 0:
		mob.growth_remaining = maxf(0,mob.growth_remaining-delta)
		if mob.growth_remaining == 0:
			if mob.game.world.intersects(mob.position,mob.info().width,mob.info().height): mob.growth_remaining = 0.01
			else: resize(mob)
	mob.breed_cooldown = maxf(0,mob.breed_cooldown-delta)
	if mob.love_time > 0 and floorf(mob.love_time) != floorf(maxf(0,mob.love_time-delta)):
		mob.game.puff(mob.center()+Vector3.UP*0.2,Color("ef7c8f"),2,0.8)
	mob.love_time = maxf(0,mob.love_time-delta)
	if mob.growth_remaining > 0 or mob.love_time <= 0 or mob.breed_cooldown > 0:
		mob.farm_mate = ""; mob.mate_time = 0; return
	var mate: Creature = active(mob.game,mob.farm_mate)
	if mate == null or mate.kind != mob.kind or mate.love_time <= 0 or mate.growth_remaining > 0:
		mob.farm_mate = ""; mob.mate_time = 0; mate = null
		for other in mob.game.creatures.get_children():
			if other == mob or other.is_queued_for_deletion() or other.kind != mob.kind or other.health <= 0 or other.growth_remaining > 0 or other.love_time <= 0 or other.breed_cooldown > 0 or not other.farm_mate.is_empty(): continue
			if mob.position.distance_to(other.position) <= 8 and absf(mob.position.y-other.position.y) <= 4 and visible(mob,other):
				mob.farm_mate = other.farm_id; other.farm_mate = mob.farm_id; other.mate_time = 0; mate = other; break
	if mate == null or mate.farm_mate != mob.farm_id: return
	# Only one parent advances the shared encounter, preventing two births.
	if mob.farm_id > mate.farm_id: return
	mob.mate_time += delta; mate.mate_time = mob.mate_time
	if mob.mate_time <= BREED_TIME: return
	if mob.position.distance_to(mate.position) >= 3 or not visible(mob,mate):
		mob.farm_mate = ""; mate.farm_mate = ""; mob.mate_time = 0; mate.mate_time = 0; return
	for parent in [mob,mate]:
		parent.love_time = 0; parent.breed_cooldown = COOLDOWN; parent.farm_mate = ""; parent.mate_time = 0
	var child: Creature = mob.game.spawn_creature(mob.kind,mob.position)
	child.growth_remaining = GROW_TIME; resize(child)
	if mob.kind == "sheep": set_color(child,offspring_color(mob.sheep_color,mate.sheep_color))
	mob.game.experience += randi_range(1,7)
	mob.game.achievements.award("parrots_and_bats")
	mob.game.puff(child.center(),Color("ef7c8f"),12,1.5)
	remember(mob); remember(mate); remember(child)

static func direction(mob: Creature) -> Vector3:
	if not supports(mob.kind) or mob.scared > 0: return Vector3.INF
	var mate: Creature = active(mob.game,mob.farm_mate)
	if mate != null:
		return Vector3.ZERO if mob.position.distance_to(mate.position) < 1.5 else ((mate.position-mob.position)*Vector3(1,0,1)).normalized()
	var game: Node3D = mob.game
	var distance: float = mob.position.distance_to(game.player.position)
	if game.inventory.held().id in FOODS[mob.kind] and game.inventory.held().count > 0 and distance < 10 and mob._sees_player():
		return Vector3.ZERO if distance < 2 else ((game.player.position-mob.position)*Vector3(1,0,1)).normalized()
	if mob.growth_remaining > 0:
		var closest: Creature
		var nearest: float = 9
		for other in game.creatures.get_children():
			if other == mob or other.kind != mob.kind or other.growth_remaining > 0 or other.is_queued_for_deletion(): continue
			var gap: float = mob.position.distance_to(other.position)
			if gap < nearest and visible(mob,other): nearest = gap; closest = other
		if closest != null and nearest > 3: return ((closest.position-mob.position)*Vector3(1,0,1)).normalized()
	return Vector3.INF

# mcl_dyes' two-input recipes are the sheep color inheritance rules.
static func offspring_color(first: String, second: String) -> String:
	var pair: Array = [first,second]; pair.sort()
	return str(COLOR_MIXES.get("+".join(pair),pair[randi_range(0,1)]))

static func natural_color(roll: int) -> String:
	if roll <= 81836: return "white"
	if roll <= 86836: return "silver"
	if roll <= 91836: return "grey"
	if roll <= 96836: return "black"
	if roll <= 99836: return "brown"
	return "pink"

static func wool_item(color: String) -> int:
	for id in range(VillageContent.WOOL_WHITE,VillageContent.WOOL_BROWN+1):
		if VillageContent.DATA[id].dye == color: return Nodes.migrate(id)
	return Nodes.WOOL

static func set_color(mob: Creature, color: String) -> void:
	if mob.kind != "sheep": return
	mob.sheep_color = str(VillageContent.DATA.get(wool_item(color),{}).get("dye","white"))
	CreatureArt.sheep_coat(mob)

static func initialize(mob: Creature) -> void:
	if mob.kind == "sheep": set_color(mob,natural_color(randi_range(0,100000)))
	if mob.kind == "chicken": mob.egg_timer = randi_range(300,600)

static func restore_coat(mob: Creature, entry: Dictionary) -> void:
	if mob.kind != "sheep": return
	mob.grazing = number(entry.get("grazing"),0,2)
	mob.graze_consumed = bool(entry.get("graze_consumed",false))
	set_color(mob,str(entry.get("sheep_color","white")))

static func grass_below(mob: Creature) -> Vector3i:
	return Vector3i(floori(mob.position.x),floori(mob.position.y+0.5)-1,floori(mob.position.z))

static func begin_graze(mob: Creature) -> bool:
	if mob.kind != "sheep" or not Pasture.is_grass(mob.game.world.node_at(grass_below(mob))): return false
	mob.grazing = 2.0; mob.graze_consumed = false; mob.direction = Vector3.ZERO
	return true

static func graze_chance(child: bool, delta: float) -> int:
	return maxi(2,floori((50.0 if child else 1000.0)*0.05/maxf(delta,0.001)+0.5))

static func graze(mob: Creature, delta: float, idle: bool) -> bool:
	if mob.kind != "sheep": return false
	if not idle:
		mob.grazing = 0; mob.graze_consumed = false
		return false
	if mob.grazing <= 0:
		if randi_range(1,graze_chance(mob.growth_remaining > 0,delta)) == 1: return begin_graze(mob)
		return false
	mob.grazing = maxf(0,mob.grazing-delta)
	if mob.grazing <= 0.4 and not mob.graze_consumed:
		mob.graze_consumed = true
		var floor_pos: Vector3i = grass_below(mob)
		if Pasture.is_grass(mob.game.world.node_at(floor_pos)) and mob.game.world.set_node(floor_pos,Nodes.DIRT):
			if mob.growth_remaining > 0:
				mob.growth_remaining = maxf(0,mob.growth_remaining-60)
				if mob.growth_remaining == 0:
					if mob.game.world.intersects(mob.position,mob.info().width,mob.info().height): mob.growth_remaining = 0.01
					else: resize(mob)
			mob.sheared = false; mob.wool_timer = 0
			CreatureArt.sheep_coat(mob)
			mob.game.sound_at("dig",mob.position)
			mob.game.puff(Vector3(floor_pos)+Vector3(0.5,1.1,0.5),Color("69964a"),4,0.5)
			remember(mob)
	return mob.grazing > 0

class_name MobWeapons
extends RefCounted

const KINDS = ["zombie","husk","drowned","zombie_villager","skeleton","stray","wither_skeleton"]
const GENERATED = ["zombie","husk","zombie_villager"]
static var item_tags: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/mob_weapon_items.json"))

static func handles(kind: String) -> bool: return kind in KINDS

static func attack_mode(kind: String, id: int) -> String:
	if kind in ["skeleton","stray","wither_skeleton"] and id == Nodes.BOW: return "bowshoot"
	if kind == "drowned" and id == VillageContent.TRIDENT: return "ranged"
	return "melee"

static func empty_item() -> Dictionary: return {"id":0,"count":0,"wear":0}

static func get_item(mob: Creature) -> Dictionary:
	return mob.bow_weapon if MobBows.handles(mob.kind) else mob.held_weapon

static func generate(factor: float, difficulty: int, rng: EnchantRolls) -> Dictionary:
	if rng.integer(1,20 if difficulty == 3 else 100) != 1: return empty_item()
	var item: Dictionary = {"id":Nodes.TOOLS+(13 if rng.integer(1,3) == 1 else 12),"count":1,"wear":0}
	if rng.unit() < 0.25*factor:
		var enchanted: Dictionary = Enchanting.generate_reliable(item,floorf(5+factor*rng.integer(1,18)),rng)
		if not enchanted.is_empty(): item.data = {"enchantments":enchanted.enchantments}
	return item

static func initialize(mob: Creature) -> void:
	if mob.held_weapon_ready or not handles(mob.kind): return
	if mob.kind in ["skeleton","stray"]: MobBows.initialize(mob)
	elif mob.kind == "wither_skeleton": mob.bow_weapon = {"id":Nodes.TOOLS+8,"count":1,"wear":0}
	elif mob.kind == "drowned": mob.held_weapon = {"id":UndeadVariants.wield(mob),"count":1 if UndeadVariants.wield(mob) != 0 else 0,"wear":0}
	else: mob.held_weapon = generate(RegionalDifficulty.special(mob.game,mob.position),RegionalDifficulty.source_level(mob.game.difficulty),MobArmor.rng_for(mob.game.world))
	mob.held_weapon_ready = true; mob.held_weapon_probability = 0.085

static func caps(item: Dictionary, base_damage: float = 0) -> Dictionary:
	if int(item.get("id",0)) == 0: return {"groups":{"fleshy":base_damage},"interval":1.0}
	var profile: Dictionary = MeleeCombat.profile(int(item.id))
	var groups: Dictionary = profile.groups.duplicate() if profile.groups is Dictionary else {}
	if profile.get("custom",true):
		groups.fleshy = floori(float(groups.get("fleshy",0))+0.5*Inventory.enchantment(item,"Sharpness"))
		groups.undead = floori(float(groups.get("undead",0))+2.5*Inventory.enchantment(item,"Smite"))
		groups.arthropod = floori(float(groups.get("arthropod",0))+2.5*Inventory.enchantment(item,"Bane of Arthropods"))
	groups.fleshy = maxf(float(groups.get("fleshy",1))-1,0)+base_damage
	return {"groups":groups,"interval":PackedFloat32Array([profile.interval])[0]}

static func sword(id: int) -> bool: return item_tags.get(str(id),{}).get("sword",Nodes.is_tool_id(id) and Nodes.tool_kind(id) == 3)

static func tool_or_weapon(id: int) -> bool:
	var tags: Dictionary = item_tags.get(str(id),{})
	return tags.get("tool",false) or tags.get("weapon",false) or Nodes.is_tool_id(id)

static func selection_uses(item: Dictionary) -> float:
	var values: Array = item_tags.get(str(int(item.get("id",0))),{}).get("uses",[])
	var level: int = Inventory.enchantment(item,"Unbreaking")
	return float(values[level]) if level >= 0 and level < values.size() else Durability.uses(item)

static func better(candidate: Dictionary, current: Dictionary, drowned: bool = false) -> bool:
	var old: int = int(current.get("id",0)); var incoming: int = int(candidate.get("id",0))
	if drowned:
		if old in [VillageContent.NAUTILUS_SHELL,VillageContent.TRIDENT]: return false
		if incoming == VillageContent.TRIDENT: return true
	if old == 0: return true
	if sword(incoming) and not sword(old): return true
	if not tool_or_weapon(incoming): return false
	if not tool_or_weapon(old): return true
	if float(caps(candidate).groups.get("fleshy",0)) > float(caps(current).groups.get("fleshy",0)): return true
	# The checkout compares the incoming item's durability to the held item's
	# in this order: a less durable tool can replace a more durable one.
	if selection_uses(candidate) < selection_uses(current): return true
	return current.get("data",{}).get("enchantments",{}).is_empty() and not candidate.get("data",{}).get("enchantments",{}).is_empty()

static func set_item(mob: Creature, item: Dictionary, probability: float = 0.085, reset_attack: bool = true) -> void:
	if MobBows.handles(mob.kind):
		mob.bow_weapon = Inventory.clean_slot(item)
		if reset_attack: MobBows.stop(mob)
	else: mob.held_weapon = Inventory.clean_slot(item)
	mob.held_weapon_ready = true; mob.held_weapon_probability = probability
	if mob.kind == "drowned": mob.set_meta("wield",int(get_item(mob).id))
	refresh(mob)

static func drop_item(mob: Creature, rng: EnchantRolls, sample: float = -1) -> Dictionary:
	return dropped(get_item(mob),mob.held_weapon_probability,int(mob.get_meta("looting",0)),rng,sample)

static func dropped(item: Dictionary, probability: float, looting: int, rng: EnchantRolls, sample: float = -1) -> Dictionary:
	return MobArmor.dropped(item,probability,looting,rng,sample,selection_uses(item))

static func drop(mob: Creature, minimum: float = 0) -> void:
	if mob.held_weapon_probability >= minimum:
		var rng: EnchantRolls = EnchantRolls.new(1,MobBows.rng_for(mob.game.world)) if MobBows.handles(mob.kind) else MobArmor.rng_for(mob.game.world)
		var item: Dictionary = drop_item(mob,rng)
		if not item.is_empty(): mob.game.spawn_drop(mob.center(),item.id,int(item.count),int(item.wear),item.get("data",{}))
	set_item(mob,empty_item())

static func equip(mob: Creature, item: Dictionary) -> bool:
	if not handles(mob.kind) or not mob.mob_armor_pickup or not better(item,get_item(mob),mob.kind == "drowned"): return false
	drop(mob); set_item(mob,item,2.0)
	# The source marks armor pickups persistent, but not weapon pickups.
	Farming.remember(mob)
	return true

static func pickup(mob: Creature) -> void:
	if not mob.mob_armor_pickup: return
	for item in mob.game.drops.get_children():
		if not item is ItemDrop or item.is_queued_for_deletion() or item.age < 1 or mob.position.distance_to(item.position) > 1.95: continue
		if Nodes.is_armor(item.item_id) or MobArmor.piece(item.item_id) >= 0: continue
		if equip(mob,{"id":item.item_id,"count":item.amount,"wear":item.wear,"data":item.data}): item.queue_free()

static func player_scale(amount: float, source_difficulty: int) -> float:
	if source_difficulty == 0: return 0.0
	if source_difficulty == 1: return minf(amount/2.0+1.0,amount)
	return amount*1.5 if source_difficulty == 3 else amount

static func damage_plan(item: Dictionary, base: float, armor: Dictionary, factor: float = 1.0, mob_target: bool = true, source_difficulty: int = 2) -> Dictionary:
	var properties: Dictionary = caps(item,base)
	var amount: float = 0
	for group in properties.groups:
		amount += float(properties.groups[group])*float(armor.get(group,0))/100.0
	amount *= clampf(1.0/properties.interval,0,1)
	# Player difficulty scaling runs before potion modifiers; mobs apply the
	# attacker's potion factor in both on_punch and the later damage modifier.
	amount = amount*factor*factor if mob_target else player_scale(amount,source_difficulty)*factor
	return {"damage":amount,"burning":4*Inventory.enchantment(item,"Fire Aspect"),"bane":Inventory.enchantment(item,"Bane of Arthropods"),"knockback":float(properties.groups.get("knockback",1.35))+Inventory.enchantment(item,"Knockback")}

static func attack(mob: Creature, target: Node3D) -> void:
	var weapon: Dictionary = get_item(mob)
	var armor: Dictionary = MeleeCombat.armor_groups(target) if target is Creature else {"fleshy":100}
	var plan: Dictionary = damage_plan(weapon,float(mob.info().damage),armor,PotionEffects.melee(mob),target is Creature,RegionalDifficulty.source_level(mob.game.difficulty))
	if plan.burning > 0: PotionEffects.apply(target,"burning",plan.burning)
	if plan.bane > 0 and float(armor.get("arthropod",0)) > 0:
		PotionEffects.apply(target,"slowness",1+MobArmor.rng_for(mob.game.world).unit()*plan.bane/2.0,4)
	var velocity_before: Vector3 = target.velocity
	var health_before: float = target.health
	if target is Creature:
		target.hit(plan.damage,mob.position,"mob_melee",0,mob)
		if not target.is_queued_for_deletion():
			target.velocity = MeleeCombat.knockback(velocity_before,plan.knockback*0.5,MeleeCombat.knockback_resistance(target),target.grounded,target.position-mob.position)
			target.knock = Vector3(target.velocity.x,0,target.velocity.z)
	else: target.hurt(plan.damage,false,mob.position,"mob",mob)
	if mob.kind in ["zombie","husk","drowned","zombie_villager"] and weapon.id == 0 and PotionEffects.level(mob,"burning") > 0:
		var difficulty: float = RegionalDifficulty.regional(mob.game,mob.position)
		if MobArmor.rng_for(mob.game.world).unit() < difficulty*0.3: PotionEffects.apply(target,"burning",difficulty*2)
	Creature.deal_effect(mob.game,mob,target)
	if target is VoxeyPlayer and target.health < health_before: Wolves.record_player_hurt(mob.game,mob)

static func refresh(mob: Creature) -> void:
	if mob.model == null or mob.arms.is_empty(): return
	var item: Dictionary = get_item(mob)
	var bow: bool = MobBows.handles(mob.kind) and item.id == Nodes.BOW
	if bow and mob.bow_hand == null: MobBows.build_weapon(mob)
	if bow: MobBows.pose(mob)
	if mob.bow_model != null: mob.bow_model.visible = bow
	if mob.held_weapon_model == null:
		mob.held_weapon_model = MeshInstance3D.new(); mob.arms[0].add_child(mob.held_weapon_model)
		mob.held_weapon_model.position = Vector3(0,-0.54,-0.06); mob.held_weapon_model.scale = Vector3.ONE*0.6
		mob.held_weapon_model.rotation = Vector3(0,0,-0.25)
	mob.held_weapon_model.visible = not bow and item.id != 0
	if item.id != 0 and not bow:
		mob.held_weapon_model.mesh = ItemArt.mesh(item.id); mob.held_weapon_model.material_override = ItemArt.material(item.id)
	if mob.kind == "drowned": UndeadVariants.refresh_held(mob)

static func snapshot(mob: Creature) -> Dictionary:
	return {"item":get_item(mob).duplicate(true),"probability":mob.held_weapon_probability,"offhand":int(mob.get_meta("offhand",0))}

static func restore(mob: Creature, data: Dictionary) -> void:
	initialize(mob)
	if data.get("item") is Dictionary: set_item(mob,data.item,clampf(float(data.get("probability",0.085)),0,2),false)
	if data.has("offhand"):
		if int(data.offhand) == 0: mob.remove_meta("offhand")
		else: mob.set_meta("offhand",int(data.offhand))

class_name MeleeCombat
extends RefCounted

# mcl_mobs/combat.lua, mcl_criticals and mcl_tools/mace.lua. The returned
# damage has already passed through the target's intrinsic damage groups.
static var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/melee.json"))
static var profiles: Dictionary = reference.profiles

static func profile(id: int) -> Dictionary:
	if profiles.has(str(id)): return profiles[str(id)]
	var native: Dictionary = VillageContent.DATA.get(id,{})
	if native.has("attack_damage"):
		return {"groups":{"fleshy":native.attack_damage},"interval":1.0,"uses":maxi(0,Nodes.durability(id)-1)}
	return profiles["0"]

static func armor_groups(mob: Creature) -> Dictionary:
	var armor: Variant = mob.info().get("armor",100)
	return {"fleshy":armor} if armor is int or armor is float else armor.duplicate()

static func knockback_resistance(mob: Creature) -> float:
	return clampf(float(reference.resistances.get(mob.kind,mob.info().get("knockback_resistance",0)))+ZombieTraits.knockback_resistance(mob),0,1)

static func knockback(velocity: Vector3, factor: float, resistance: float, standing: bool, direction: Vector3) -> Vector3:
	factor *= 1.0-minf(1.0,resistance)
	if factor <= 0.00001: return Vector3.ZERO
	var push: Vector3 = Vector3(direction.x,0,direction.z).normalized()*factor
	return Vector3((velocity.x/2+push.x*20)*0.546,minf(8,velocity.y/2+factor*10) if standing else velocity.y,(velocity.z/2+push.z*20)*0.546)

static func resolve(slot: Dictionary, armor: Dictionary, state: Dictionary, rng: EnchantRolls = null) -> Dictionary:
	var id: int = int(slot.get("id",0))
	var enchants: Dictionary = slot.get("data",{}).get("enchantments",{}) if id > 0 else {}
	var caps: Dictionary = profile(id)
	var player_velocity: Vector3 = state.get("velocity",Vector3.ZERO)
	var target_velocity: Vector3 = state.get("target_velocity",Vector3.ZERO)
	var stamp: int = int(state.get("last_mace",0))
	var result: Dictionary = {"accepted":true,"damage":0.0,"burning":0.0,"slowness":0.0,"critical":false,"broken":false,"player_velocity":player_velocity,"target_velocity":target_velocity,"mace_stamp":stamp,"breach":0}
	var elapsed: float = float(state.get("elapsed",3.0))
	var interval: float = float(state.get("interval",caps.interval))
	var groups: Dictionary = caps.groups.duplicate() if caps.groups is Dictionary else {}
	var attack_uses: float = float(caps.uses)*(1+int(enchants.get("Unbreaking",0)))
	if id == VillageContent.MACE:
		stamp = maxi(0,stamp); result.mace_stamp = stamp
		if int(state.get("time",0))-stamp < 1.6:
			result.accepted = false; return result
		result.mace_stamp = int(state.get("time",0))
		var blocks: float = -absf(player_velocity.y)*player_velocity.y/40.0
		if blocks > 1:
			player_velocity.y = 0
			if float(state.get("distance",2)) < 3: player_velocity.y = 8*int(enchants.get("Wind Burst",0))
		var smash: float = 0
		if blocks > 1.5: smash += int(enchants.get("Density",0))*blocks/2
		if blocks > 8: smash += 23+blocks
		elif blocks > 3: smash += blocks*2+18
		elif blocks > 1.5: smash += blocks*4+9
		elif blocks > 0: smash += 9
		else: smash += 6
		groups = {"fleshy":floori(smash)}; interval = 1.6; elapsed = 1.6; attack_uses = 0
	elif caps.get("custom",true):
		groups["fleshy"] = floori(float(groups.get("fleshy",0))+0.5*int(enchants.get("Sharpness",0)))
		groups["undead"] = floori(float(groups.get("undead",0))+2.5*int(enchants.get("Smite",0)))
		groups["arthropod"] = floori(float(groups.get("arthropod",0))+2.5*int(enchants.get("Bane of Arthropods",0)))
	# Both ObjectRef:punch and ItemStack capabilities pass through engine f32
	# intervals and integer damage groups before the Lua callback sees them.
	interval = PackedFloat32Array([interval])[0]; elapsed = PackedFloat32Array([elapsed])[0]
	var damage: float = 0
	for group in groups: damage += float(groups[group])*clampf(elapsed/interval,0,1)*float(armor.get(group,0))/100.0
	var factor: float = float(state.get("strength",1))*float(state.get("weakness",1))
	damage *= factor
	result.burning = 4*int(enchants.get("Fire Aspect",0))
	var bane: int = int(enchants.get("Bane of Arthropods",0))
	if float(armor.get("arthropod",0)) > 0 and bane > 0:
		result.slowness = 1+(rng.unit() if rng != null else randf())*bane/2.0
	# Normal punch wear happens before modifiers and knockback. A broken weapon
	# therefore no longer contributes its Knockback enchantment to this hit.
	if not state.get("creative",false) and attack_uses > 0:
		Durability.set_normalized(slot,Durability.normalized(slot)+floori(65535/attack_uses))
		result.broken = int(slot.id) == 0
	result.looting = Inventory.enchantment(slot,"Looting")
	if state.get("sprinting",false) and player_velocity.y >= 0:
		target_velocity += player_velocity
	elif player_velocity.y < 0 and damage > 0:
		damage += rng.integer(0,floori(damage*1.5+2)) if rng != null else randi_range(0,floori(damage*1.5+2))
		result.critical = true
	# The checkout applies strength/weakness both in on_punch and its registered
	# damage modifier. Retain that behavior, including its critical-roll bounds.
	result.damage = damage*factor
	if id == VillageContent.MACE: result.breach = int(enchants.get("Breach",0))
	if elapsed >= 0.5:
		var level: int = int(enchants.get("Knockback",0)) if int(slot.id) > 0 else 0
		var kb: float = float(groups.get("knockback",1.35))+level
		target_velocity = knockback(target_velocity,kb*0.5,float(state.get("resistance",0)),bool(state.get("standing",true)),state.get("direction",Vector3.FORWARD))
	if id == VillageContent.MACE and not state.get("creative",false):
		Durability.set_normalized(slot,Durability.normalized(slot)+131)
		result.broken = int(slot.id) == 0
	result.player_velocity = player_velocity; result.target_velocity = target_velocity
	return result

static func attack(player: VoxeyPlayer, mob: Creature, rng: EnchantRolls = null) -> Dictionary:
	var slot: Dictionary = player.game.inventory.held()
	var state: Dictionary = {"elapsed":player.melee_elapsed,"time":floori(player.combat_time),"last_mace":player.mace_stamp,
		"velocity":player.velocity,"target_velocity":mob.velocity,"sprinting":player.sprinting,"creative":player.game.gamemode == "creative",
		"strength":1+0.3*PotionEffects.level(player,"strength"),"weakness":maxf(0,1-0.2*PotionEffects.level(player,"weakness")),
		"distance":player.position.distance_to(mob.position),"direction":mob.position-player.position,"standing":mob.grounded,
		"resistance":knockback_resistance(mob)}
	state.interval = ToolCapabilities.attack_interval(slot,player)
	ToolCapabilities.refresh(player)
	var old_id: int = int(slot.id)
	var sweep: int = Inventory.enchantment(slot,"Sweeping Edge")
	var result: Dictionary = resolve(slot,armor_groups(mob),state,rng)
	player.mace_stamp = result.mace_stamp
	if not result.accepted: return result
	player.melee_elapsed = 0; player.mace_stamp = result.mace_stamp; player.velocity = result.player_velocity
	if result.burning > 0: PotionEffects.apply(mob,"burning",result.burning)
	if result.slowness > 0: PotionEffects.apply(mob,"slowness",result.slowness,4)
	mob.set_meta("looting",result.looting)
	if result.critical:
		player.game.puff(mob.center(),Color("bc7a57"),15,0.6); player.game.sound_at("crit",mob.center())
	Golems.attacked(mob,player)
	mob.hit(result.damage,player.position,"player_melee",result.breach,player)
	# Retain the existing saved-item Sweeping Edge extension. This enchantment
	# is disabled in the reference and cannot appear in source-generated offers.
	if sweep > 0:
		for other in player.game.creatures.get_children():
			if other != mob and not other.is_queued_for_deletion() and other.position.distance_to(mob.position) < 1.5:
				other.hit(result.damage*sweep/(sweep+1.0),player.position,"player_melee",0,player)
	if not mob.is_queued_for_deletion():
		mob.knock = Vector3(result.target_velocity.x,0,result.target_velocity.z); mob.velocity = result.target_velocity
		mob.set_meta("player_struck",true); Wolves.record_player_struck(player.game,mob)
	Hunger.exhaust(player,Hunger.ATTACK)
	player.game.inventory.changed.emit()
	if result.broken: player.game.toast("Your "+Nodes.title(old_id).to_lower()+" broke."); player.game.sound("break")
	return result

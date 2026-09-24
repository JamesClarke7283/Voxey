class_name PotionEffects
extends RefCounted

const NAMES = ["poison","regeneration","strength","weakness","water_breathing","fire_resistance","invisibility","night_vision","swiftness","slowness","leaping","withering","slow_falling","resistance","luck","bad_luck","bad_omen","infested","oozing","weaving","wind_charged","burning","hero_of_village","hunger","saturation","absorption","nausea","conduit_power","dolphins_grace","turtle_master","fatigue"]
const UNDEAD = ["zombie","skeleton","phantom"]

static func level(target: Node3D, effect: String) -> int:
	var active: bool = target.game.survival.effects.has(effect) if target is VoxeyPlayer else target.has_meta("effect_"+effect)
	return int(target.get_meta("potency_"+effect,1)) if active else 0

static func apply(target: Node3D, effect: String, duration: float, potency: int = 1, scale: float = 1.0) -> void:
	if target.is_queued_for_deletion() or target.health <= 0: return
	var player: bool = target is VoxeyPlayer
	var undead: bool = not player and target.kind in UNDEAD
	if effect in ["healing","harming"]:
		var healing: bool = (effect == "healing") != undead
		var amount: float = (4 if effect == "healing" else 6)*potency*scale
		if healing: target.health = minf(20 if player else target.info().health,target.health+amount)
		elif player: target.hurt(amount,true)
		# Harming damage is magic, which the source writes to health directly rather
		# than routing through a damage group, so it is not armor-scaled.
		else: target.hit(amount,Vector3.INF,"magic")
		return
	if not NAMES.has(effect) or duration <= 0: return
	# A fire-resistant mob never catches light, which is the source's
	# `_fire_resistant`: a blaze cannot be set alight by a blaze's own fireball.
	if not player and effect == "burning" and Fire.resistant(target.kind): return
	if not player and ((effect in ["poison","regeneration"] and undead) or (effect in ["poison","infested"] and target.kind in ["spider","silverfish"]) or (effect == "oozing" and target.kind == "slime")): return
	var previous: int = level(target,effect)
	var remaining: float = float(target.game.survival.effects.get(effect,0)) if player else float(target.get_meta("effect_"+effect,0))
	if effect == "absorption": target.set_meta("absorption_health",maxf(absorption(target),4.0*potency))
	if previous > potency or previous == potency and remaining >= duration: return
	target.set_meta("potency_"+effect,potency)
	if player: target.game.survival.effects[effect] = duration
	else: target.set_meta("effect_"+effect,duration)
	if effect == "invisibility" and not player: target.model.visible = false

static func apply_item(target: Node3D, id: int, scale: float = 1.0) -> void:
	if PotionCatalog.ITEMS.get(id,{}).get("potion","") == "water":
		if target is SnowGolem: target.environmental_damage(1)
		if target is VoxeyPlayer: target.game.survival.effects.erase("burning")
		elif target.has_meta("effect_burning"): target.remove_meta("effect_burning")
	for effect in PotionCatalog.effects(id): apply(target,effect.effect,effect.duration*scale,effect.level,scale)

static func clear(target: Node3D) -> void:
	if target is VoxeyPlayer: target.game.survival.effects.clear()
	if target.has_meta("absorption_health"): target.remove_meta("absorption_health")
	for effect in NAMES:
		for prefix in ["effect_","potency_","effectclock_"]:
			if target.has_meta(prefix+effect): target.remove_meta(prefix+effect)
	if target is Creature: target.model.visible = true

# Remove one effect, which the source's zombie-villager cure needs: it clears
# weakness and strength and nothing else, so a cure must not strip a creature's
# other effects.
static func clear_one(target: Node3D, effect: String) -> void:
	if target is VoxeyPlayer: target.game.survival.effects.erase(effect)
	for prefix in ["effect_","potency_","effectclock_"]:
		if target.has_meta(prefix+effect): target.remove_meta(prefix+effect)

static func update(target: Node3D, delta: float) -> void:
	if target.is_queued_for_deletion() or target.health <= 0: return
	var player: bool = target is VoxeyPlayer
	# Every creature is updated each frame; most carry no effect at all.
	if not player and not _has_effect(target): return
	for effect in NAMES:
		var potency: int = level(target,effect)
		if potency <= 0: continue
		var remaining: float = float(target.game.survival.effects[effect]) if player else float(target.get_meta("effect_"+effect))
		if effect == "hunger" and player: Hunger.exhaust(target,100.0*potency*minf(delta,remaining))
		if effect == "saturation" and player:
			var amount: float = potency*minf(delta,remaining)
			target.hunger = minf(20,target.hunger+amount)
			target.saturation = minf(target.hunger,target.saturation+amount)
		remaining -= delta
		if remaining <= 0:
			if player: target.game.survival.effects.erase(effect)
			else: target.remove_meta("effect_"+effect)
			for prefix in ["potency_","effectclock_"]:
				if target.has_meta(prefix+effect): target.remove_meta(prefix+effect)
			if effect == "invisibility" and not player: target.model.visible = true
			if effect == "absorption" and target.has_meta("absorption_health"): target.remove_meta("absorption_health")
			continue
		if player: target.game.survival.effects[effect] = remaining
		else: target.set_meta("effect_"+effect,remaining)
		if effect not in ["poison","regeneration","withering","burning"]: continue
		if effect == "burning" and (level(target,"fire_resistance") > 0 or Fluids.water(target.game.world.node_at(Vector3i(target.position.floor())))): continue
		var interval: float = {"poison":1.25,"regeneration":2.5,"withering":2.0,"burning":1.0}[effect]/pow(2.0,potency-1)
		var timer: float = float(target.get_meta("effectclock_"+effect,0))+delta
		while timer >= interval and target.health > 0 and not target.is_queued_for_deletion():
			timer -= interval
			if effect == "regeneration": target.health = minf(20 if player else target.info().health,target.health+1)
			elif effect == "poison":
				var poison_damage: float = absorb(target,minf(1,maxf(0,target.health-1)))
				target.health -= poison_damage
				if player and poison_damage > 0: Hunger.exhaust(target,Hunger.DAMAGE)
			elif player: target.hurt(1,true,Vector3.INF,"fire" if effect == "burning" else "generic")
			else: target.hit(1)
		target.set_meta("effectclock_"+effect,timer)
	if level(target,"slow_falling") > 0: target.velocity.y = maxf(target.velocity.y,-1.6)

static func _has_effect(target: Node3D) -> bool:
	for meta in target.get_meta_list():
		if String(meta).begins_with("effect_"): return true
	return false

static func damaged(target: Node3D) -> void:
	if level(target,"infested") > 0 and randf() < 0.05:
		for i in randi_range(1,3): target.game.spawn_creature("silverfish",target.position+Vector3(randf_range(-0.5,0.5),0,randf_range(-0.5,0.5)))

static func died(target: Node3D) -> void:
	if target.has_meta("potion_death_done"): return
	target.set_meta("potion_death_done",true)
	if level(target,"oozing") > 0:
		for i in 2:
			var slime: Creature = target.game.spawn_creature("slime",target.position+Vector3(i-0.5,0,0))
			slime.set_slime_size(2)
	if level(target,"weaving") > 0:
		for i in randi_range(2,3):
			var p: Vector3i = Vector3i(target.position.floor())+Vector3i(i-1,0,0)
			if target.game.world.node_at(p) == Nodes.AIR: target.game.world.set_node(p,VillageContent.COBWEB)
	if level(target,"wind_charged") > 0:
		for entity in target.game.creatures.get_children()+[target.game.player]:
			var away: Vector3 = entity.position-target.position
			if entity != target and away.length() < 6: entity.velocity += (away.normalized()+Vector3.UP)*12
		target.game.puff(target.position+Vector3.UP,Color("ccdce7"),35,3)

# The elder guardian's mining fatigue, as a multiplier on block-breaking time. The
# source's level 3 makes mining substantially slower, which is the whole point of
# the elder's aura: it turns a monument into a grind rather than a fight.
static func mining_speed(target: Node3D) -> float:
	var fatigue: int = level(target,"fatigue")
	return 1.0 if fatigue <= 0 else 1.0+fatigue*1.0

static func speed(target: Node3D) -> float:
	var result: float = (1.0+level(target,"swiftness")*0.2)*maxf(0.1,1.0-level(target,"slowness")*0.15)
	if target.game.world.node_at(Vector3i(target.position.floor())) == VillageContent.COBWEB: result *= 0.5 if level(target,"weaving") else 0.15
	return result

static func melee(target: Node3D) -> float:
	return (1.0+0.3*level(target,"strength"))*maxf(0.0,1.0-0.2*level(target,"weakness"))

static func resistance(target: Node3D) -> float:
	return maxf(0,1.0-0.2*level(target,"resistance"))

static func snapshot(target: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for name in NAMES:
		var potency: int = level(target,name)
		if potency <= 0: continue
		var duration: float = target.game.survival.effects[name] if target is VoxeyPlayer else float(target.get_meta("effect_"+name,0))
		result[name] = {"duration":duration,"level":potency}
		if name == "absorption": result[name]["remaining"] = absorption(target)
	return result

static func absorption(target: Node3D) -> float:
	return float(target.get_meta("absorption_health",0.0))

static func absorb(target: Node3D, amount: float) -> float:
	var shield: float = absorption(target)
	if shield <= 0: return amount
	target.set_meta("absorption_health",maxf(0,shield-amount))
	return maxf(0,amount-shield)

static func restore_absorption(target: Node3D, value: Variant) -> void:
	var maximum: float = 4.0*level(target,"absorption")
	var saved: float = float(value) if value is float or value is int else maximum
	target.set_meta("absorption_health",clampf(saved,0,maximum) if is_finite(saved) else maximum)

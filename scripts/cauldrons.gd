class_name Cauldrons
extends RefCounted

const RAIN_INTERVAL = 56.0
const CONTACT_INTERVAL = 0.5

# Source rules: Mineclonia mods/ITEMS/mcl_cauldrons/init.lua and
# mods/HUD/mcl_inventory/init.lua. See docs/cauldrons-source.md for attribution.
# Keep the legacy "water" level field; "liquid" distinguishes new lava fills.
static func level(station: Dictionary) -> int:
	var value: Variant = station.get("water",0)
	if not (value is int or value is float): return 0
	if value is float and not is_finite(value): return 0
	return clampi(int(value),0,3)

# The materials a cauldron can hold. Powder snow is the source's third: a cauldron
# left out in a snowfall collects it, and a bucket then scoops it back out.
const MATERIALS = ["water","lava","powder_snow"]

static func liquid(station: Dictionary) -> String:
	if level(station) == 0: return ""
	var value: String = str(station.get("liquid","water"))
	return value if value in MATERIALS else "water"

static func set_contents(station: Dictionary, amount: int, material: String = "water") -> void:
	station["kind"] = "cauldron"
	station["water"] = clampi(amount,0,3)
	station["liquid"] = material if amount > 0 and material in MATERIALS else ""

static func station(world: VoxelWorld, p: Vector3i) -> Dictionary:
	var result: Dictionary = world.get_station(p,"cauldron")
	set_contents(result,level(result),liquid(result))
	return result

static func description(station: Dictionary) -> String:
	if level(station) == 0: return "Empty cauldron. Add water bottles, a water bucket or a lava bucket."
	return "%s cauldron: %d / 3. %s"%[liquid(station).capitalize(),level(station),"Use an empty bucket to collect it." if level(station) == 3 else "A bucket needs a full cauldron."]

# Applies one complete transaction before notifying inventory listeners. Any
# overflow is returned as a real stack for the caller to place in the world.
static func transact(inventory: Inventory, station: Dictionary, creative: bool = false) -> Dictionary:
	var result: Dictionary = {"changed":false,"drops":[],"message":description(station)}
	if inventory.selected < 0 or inventory.selected >= inventory.slots.size(): return result
	var held: Dictionary = inventory.held()
	if int(held.get("count",0)) <= 0: return result
	var item: int = int(held.get("id",0))
	var amount: int = level(station)
	var material: String = liquid(station)
	if PortableStorage.is_shulker(item) and item != PortableStorage.SHULKER_PURPLE:
		if amount == 0 or material != "water": return result
		# Source set_name changes only the shell: every cargo slot, enchantment,
		# custom name and supported metadata value remains on the same item.
		held.id = PortableStorage.SHULKER_PURPLE
		set_contents(station,amount-1,"water")
		inventory.changed.emit()
		result.changed = true; result.message = "Shulker box washed clean. "+description(station)
		return result
	var output: int = 0
	var creative_behavior: String = "nothing"
	var preserve_bucket_data: bool = false
	if item in [Nodes.WATER_BUCKET,Nodes.LAVA_BUCKET]:
		var incoming: String = "water" if item == Nodes.WATER_BUCKET else "lava"
		if amount == 3 or (amount > 0 and material != incoming): return result
		amount = 3; material = incoming; output = Nodes.BUCKET; preserve_bucket_data = true
	elif item == Nodes.BUCKET:
		if amount != 3: return result
		output = Nodes.LAVA_BUCKET if material == "lava" else (PowderSnow.BUCKET if material == "powder_snow" else Nodes.WATER_BUCKET)
		amount = 0; preserve_bucket_data = true
	elif item == PowderSnow.BUCKET:
		# A full bucket of powder snow fills the cauldron with it, which is the
		# source's own bucket handler for the third material.
		if amount == 3 or (amount > 0 and material != "powder_snow"): return result
		amount = 3; material = "powder_snow"; output = Nodes.BUCKET; preserve_bucket_data = true
	elif item == VillageContent.WATER_BOTTLE:
		if amount == 3 or (amount > 0 and material != "water"): return result
		amount += 1; material = "water"; output = VillageContent.GLASS_BOTTLE
		creative_behavior = "give_new"
	elif item == VillageContent.GLASS_BOTTLE:
		if amount == 0 or material != "water": return result
		amount -= 1; output = VillageContent.WATER_BOTTLE; creative_behavior = "give"
	else: return result
	var slots: Array = inventory.slots.duplicate(true)
	var selected: Dictionary = slots[inventory.selected]
	var reward: Dictionary = {"id":output,"count":1,"wear":0}
	if not creative:
		if selected.count == 1:
			if preserve_bucket_data:
				reward = selected.duplicate(true); reward.id = output
			slots[inventory.selected] = reward
		else:
			selected.count -= 1
			if not _insert(slots,reward): result.drops.append(reward)
	elif creative_behavior == "give" or (creative_behavior == "give_new" and not _contains(slots,reward)):
		if not _insert(slots,reward): result.drops.append(reward)
	set_contents(station,amount,material)
	inventory.slots = slots
	inventory.changed.emit()
	result.changed = true
	result.message = description(station)
	return result

static func _contains(slots: Array, item: Dictionary) -> bool:
	for slot in slots:
		if slot.id == item.id and slot.count > 0 and slot.wear == item.wear and slot.get("data",{}) == item.get("data",{}): return true
	return false

static func _insert(slots: Array, item: Dictionary) -> bool:
	for pass_index in 2:
		for slot in slots:
			if (pass_index == 0 and slot.id == item.id and slot.wear == item.wear and slot.get("data",{}) == item.get("data",{}) and slot.count < Nodes.max_stack(item.id)) or (pass_index == 1 and slot.id == 0):
				slot.id = item.id; slot.wear = item.wear; slot.count += 1
				Inventory.copy_data(slot,item)
				return true
	return false

# Call before generic drink handling; water bottles must pour on a cauldron.
# The caller handles the sneak bypass, as with other block interactions.
static func use(game: Node, p: Vector3i) -> bool:
	if game.world.node_at(p) != VillageContent.CAULDRON: return false
	var station: Dictionary = game.world.get_station(p,"cauldron")
	var result: Dictionary = transact(game.inventory,station,game.gamemode == "creative")
	for stack in result.drops:
		game.spawn_drop(Vector3(p)+Vector3(0.5,1.05,0.5),stack.id,stack.count,stack.wear,stack.get("data",{}))
	if result.changed:
		game.sound("place")
		game.survival.refresh_displays()
	game.toast(result.message)
	return true

# Collision uses the source's empty basin at every liquid level. Coordinates
# are translated from Mineclonia's centered nodes into Voxey's node corners.
static func boxes() -> Array:
	var result: Array = [
		AABB(Vector3(0,0.3125,0),Vector3(0.125,0.6875,1)),
		AABB(Vector3(0.875,0.3125,0),Vector3(0.125,0.6875,1)),
		AABB(Vector3(0.125,0.3125,0),Vector3(0.75,0.6875,0.125)),
		AABB(Vector3(0.125,0.3125,0.875),Vector3(0.75,0.6875,0.125)),
		AABB(Vector3(0,0.1875,0),Vector3(1,0.125,1)),
	]
	for x in [0.0,0.875]:
		for z in [0.0,0.75]: result.append(AABB(Vector3(x,0,z),Vector3(0.125,0.1875,0.25)))
	for x in [0.125,0.75]:
		for z in [0.0,0.875]: result.append(AABB(Vector3(x,0,z),Vector3(0.125,0.1875,0.125)))
	return result

static func surface_height(station: Dictionary) -> float:
	return 0.5625+(level(station)-1)*0.1875

static func touching(position: Vector3, p: Vector3i, station: Dictionary) -> bool:
	if level(station) == 0: return false
	var local: Vector3 = position-Vector3(p)
	# Feet must enter the hollow basin. Standing on the rim or beside the
	# outside wall cannot extinguish or ignite an actor through solid iron.
	return local.x > 0.125 and local.x < 0.875 and local.z > 0.125 and local.z < 0.875 and local.y >= 0.1875 and local.y <= surface_height(station)+0.02

static func extinguish(target: Node3D) -> bool:
	if PotionEffects.level(target,"burning") == 0: return false
	if target is VoxeyPlayer: target.game.survival.effects.erase("burning")
	for prefix in ["effect_","potency_","effectclock_"]:
		if target.has_meta(prefix+"burning"): target.remove_meta(prefix+"burning")
	return true

static func ignite(target: Node3D) -> void:
	if target is VoxeyPlayer and target.game.gamemode == "creative": return
	if target is Creature and target.kind in ["blaze","ghast","ender_dragon","end_crystal"]: return
	var duration: float = 5.0
	if target is VoxeyPlayer:
		var protection: int = 0
		for piece in target.armor_slots: protection = maxi(protection,Inventory.enchantment(piece,"Fire Protection"))
		duration -= floorf(duration*protection*0.15)
	PotionEffects.apply(target,"burning",duration)

static func contact(game: Node3D, p: Vector3i, station: Dictionary) -> bool:
	var changed: bool = false
	for target in [game.player]+game.creatures.get_children():
		if not (target is VoxeyPlayer or target is Creature) or target.is_queued_for_deletion() or target.health <= 0: continue
		if not touching(target.position,p,station): continue
		if liquid(station) == "lava": ignite(target)
		elif liquid(station) == "water" and extinguish(target):
			set_contents(station,level(station)-1,"water")
			changed = true
	return changed

static func rainy_biome(biome: String) -> bool:
	return biome not in ["Sunwash desert","Frostpine highlands"]

# A cauldron collects from *any* precipitation, so the biome test is the source's
# broader one: not arid. The snowy biome is excluded from `rainy_biome` because it
# receives snow rather than rain, but it still fills the cauldron — with powder snow.
static func collecting_biome(biome: String) -> bool:
	return biome != "Sunwash desert"

static func rain_eligible(world: VoxelWorld, p: Vector3i) -> bool:
	if world.dimension != "overworld" or not world.loaded_at(Vector3(p)): return false
	var game: Node3D = world.get_parent()
	if game.survival.weather() not in ["rain","thunder"]: return false
	# Reuse the current weather, biome and sky definitions. The biome names
	# identify Voxey's existing dry/snow climates; no new weather is generated.
	if not collecting_biome(world.generator.biome(p.x,p.z)): return false
	return not Nodes.solid(world.node_at(p+Vector3i.UP)) and world.open_sky(p)

static func _rain_clock(station: Dictionary) -> float:
	var previous: Variant = station.get("rain_clock",0.0)
	return maxf(0,float(previous)) if (previous is float or previous is int) and is_finite(float(previous)) else 0.0

# What falling weather puts in a cauldron. The source has one ABM for both cases:
# it fills with **powder snow** where it is snowing and with water where it is
# raining, on the same fifty-six second interval.
static func precipitation_material(world: VoxelWorld, p: Vector3i) -> String:
	return "powder_snow" if Weather.has_snow(world,p) else "water"

static func rain_step(station: Dictionary, delta: float, eligible: bool, material: String = "water") -> bool:
	var clock: float = _rain_clock(station)+maxf(0,delta)
	station["rain_clock"] = fmod(clock,RAIN_INTERVAL)
	if clock < RAIN_INTERVAL or not eligible or level(station) == 3 or liquid(station) == "lava": return false
	# A cauldron holding one liquid does not start collecting the other, so a water
	# cauldron in a snowfall stays water until it is emptied.
	if level(station) > 0 and liquid(station) != material: return false
	set_contents(station,level(station)+1,material)
	return true

static func update(world: VoxelWorld, delta: float) -> void:
	if delta <= 0 or not is_finite(delta): return
	var game: Node3D = world.get_parent()
	var elapsed: float = float(world.get_meta("cauldron_contact_clock",0.0))+delta
	var check_contact: bool = elapsed >= CONTACT_INTERVAL
	world.set_meta("cauldron_contact_clock",fmod(elapsed,CONTACT_INTERVAL))
	var changed: bool = false
	for key in world.stations.keys():
		var station: Dictionary = world.stations[key]
		if station.get("kind","") != "cauldron": continue
		var xyz: PackedStringArray = key.split(",")
		if xyz.size() != 3: continue
		var p := Vector3i(int(xyz[0]),int(xyz[1]),int(xyz[2]))
		if not world.loaded_at(Vector3(p)) or world.node_at(p) != VillageContent.CAULDRON: continue
		var precipitation: bool = _rain_clock(station)+delta >= RAIN_INTERVAL and rain_eligible(world,p)
		if rain_step(station,delta,precipitation,precipitation_material(world,p)): changed = true
		if check_contact and contact(game,p,station): changed = true
	if changed: game.survival.refresh_displays()

# Dynamic liquid surface; source heights are 1/16, 4/16 and 7/16 above
# the node center. The rim stays visible and the level is readable in-world.
static func fill_model(station: Dictionary) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	if level(station) == 0: return model
	var box := BoxMesh.new(); box.size = Vector3(0.7,0.035,0.7)
	model.mesh = box
	model.position = Vector3(0.5,surface_height(station)-0.0175,0.5)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e87220") if liquid(station) == "lava" else Color("467ecc")
	if liquid(station) == "lava":
		material.emission_enabled = true; material.emission = Color("e87220"); material.emission_energy_multiplier = 0.6
	model.material_override = material
	return model

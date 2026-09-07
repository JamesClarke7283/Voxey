class_name Enchantments
extends RefCounted

# Mineclonia enchantment definition data (GPL-3.0); see docs/licenses.
# Aqua Affinity and Sweeping Edge also implement the source's disabled definitions.
const DATA = {
	"Bane of Arthropods":{"max":5,"primary":["sword","mace"],"secondary":["axe"],"incompatible":["Smite","Sharpness","Density","Breach"],"treasure":false,"curse":false,"weight":5,"power":[[5,25],[13,33],[21,41],[29,49],[37,57]]},
	"Channeling":{"max":1,"primary":["trident"],"secondary":[],"incompatible":["Riptide"],"treasure":false,"curse":false,"weight":1,"power":[[25,50]]},
	"Curse of Vanishing":{"max":1,"primary":[],"secondary":["armor_head","armor_torso","armor_legs","armor_feet","tool","weapon","trident"],"incompatible":[],"treasure":true,"curse":true,"weight":1,"power":[[25,50]]},
	"Depth Strider":{"max":3,"primary":[],"secondary":["armor_feet"],"incompatible":["Frost Walker"],"treasure":false,"curse":false,"weight":2,"power":[[10,25],[20,35],[30,45]]},
	"Efficiency":{"max":5,"primary":["pickaxe","shovel","axe","hoe"],"secondary":["shears"],"incompatible":[],"treasure":false,"curse":false,"weight":10,"power":[[1,61],[11,71],[21,81],[31,91],[41,101]]},
	"Fire Aspect":{"max":2,"primary":["sword","mace"],"secondary":[],"incompatible":[],"treasure":false,"curse":false,"weight":2,"power":[[10,61],[30,71]]},
	"Flame":{"max":1,"primary":["bow"],"secondary":[],"incompatible":[],"treasure":false,"curse":false,"weight":2,"power":[[20,50]]},
	"Fortune":{"max":3,"primary":["pickaxe","shovel","axe","hoe"],"secondary":[],"incompatible":["Silk Touch"],"treasure":false,"curse":false,"weight":2,"power":[[15,61],[24,71],[33,81]]},
	"Frost Walker":{"max":2,"primary":[],"secondary":["armor_feet"],"incompatible":["Depth Strider"],"treasure":true,"curse":false,"weight":2,"power":[[10,25],[20,35]]},
	"Impaling":{"max":5,"primary":["trident"],"secondary":[],"incompatible":[],"treasure":false,"curse":false,"weight":2,"power":[[1,21],[9,29],[17,37],[25,45],[33,53]]},
	"Infinity":{"max":1,"primary":["bow"],"secondary":[],"incompatible":["Mending"],"treasure":false,"curse":false,"weight":1,"power":[[20,50]]},
	"Knockback":{"max":2,"primary":["sword"],"secondary":[],"incompatible":[],"treasure":false,"curse":false,"weight":5,"power":[[5,61],[25,71]]},
	"Looting":{"max":3,"primary":["sword"],"secondary":[],"incompatible":[],"treasure":false,"curse":false,"weight":2,"power":[[15,61],[24,71],[33,81]]},
	"Loyalty":{"max":3,"primary":["trident"],"secondary":[],"incompatible":["Riptide"],"treasure":false,"curse":false,"weight":5,"power":[[12,50],[19,50],[26,50]]},
	"Luck of the Sea":{"max":3,"primary":["fishing_rod"],"secondary":[],"incompatible":[],"treasure":false,"curse":false,"weight":2,"power":[[15,61],[24,71],[33,81]]},
	"Lure":{"max":3,"primary":["fishing_rod"],"secondary":[],"incompatible":[],"treasure":false,"curse":false,"weight":2,"power":[[15,61],[24,71],[33,81]]},
	"Mending":{"max":1,"primary":[],"secondary":["armor_head","armor_torso","armor_legs","armor_feet","tool","weapon","trident"],"incompatible":["Infinity"],"treasure":true,"curse":false,"weight":2,"power":[[25,75]]},
	"Multishot":{"max":1,"primary":["crossbow"],"secondary":[],"incompatible":["Piercing"],"treasure":false,"curse":false,"weight":2,"power":[[20,50]]},
	"Piercing":{"max":4,"primary":["crossbow"],"secondary":[],"incompatible":["Multishot"],"treasure":false,"curse":false,"weight":10,"power":[[1,50],[11,50],[21,50],[31,50]]},
	"Power":{"max":5,"primary":["bow"],"secondary":[],"incompatible":[],"treasure":false,"curse":false,"weight":10,"power":[[1,16],[11,26],[21,36],[31,46],[41,56]]},
	"Punch":{"max":2,"primary":[],"secondary":["bow"],"incompatible":[],"treasure":false,"curse":false,"weight":2,"power":[[12,37],[32,57]]},
	"Quick Charge":{"max":3,"primary":["crossbow"],"secondary":[],"incompatible":[],"treasure":false,"curse":false,"weight":5,"power":[[12,50],[32,50],[52,50]]},
	"Respiration":{"max":3,"primary":["armor_head"],"secondary":[],"incompatible":[],"treasure":false,"curse":false,"weight":2,"power":[[10,40],[20,50],[30,60]]},
	"Riptide":{"max":3,"primary":["trident"],"secondary":[],"incompatible":["Channeling","Loyalty"],"treasure":false,"curse":false,"weight":2,"power":[[17,50],[24,50],[31,50]]},
	"Sharpness":{"max":5,"primary":["sword"],"secondary":["axe"],"incompatible":["Bane of Arthropods","Smite"],"treasure":false,"curse":false,"weight":5,"power":[[1,21],[12,32],[23,43],[34,54],[45,65]]},
	"Silk Touch":{"max":1,"primary":["pickaxe","shovel","axe","hoe"],"secondary":["shears"],"incompatible":["Fortune"],"treasure":false,"curse":false,"weight":1,"power":[[15,61]]},
	"Smite":{"max":5,"primary":["sword","mace"],"secondary":["axe"],"incompatible":["Bane of Arthropods","Sharpness","Density","Breach"],"treasure":false,"curse":false,"weight":5,"power":[[5,25],[13,33],[21,41],[29,49],[37,57]]},
	"Soul Speed":{"max":3,"primary":[],"secondary":["armor_feet"],"incompatible":["Frost Walker"],"treasure":true,"curse":false,"weight":2,"power":[[10,25],[20,35],[30,45]]},
	"Unbreaking":{"max":3,"primary":["armor_head","armor_torso","armor_legs","armor_feet","pickaxe","shovel","axe","hoe","sword","fishing_rod","bow","crossbow","trident","mace"],"secondary":["tool"],"incompatible":[],"treasure":false,"curse":false,"weight":5,"power":[[5,61],[13,71],[21,81]]},
	"Density":{"max":5,"primary":["mace"],"secondary":["mace"],"incompatible":["Breach","Bane of Arthropods","Smite"],"treasure":true,"curse":false,"weight":2,"power":[[10,25],[20,35],[30,45],[40,55],[50,65]]},
	"Breach":{"max":4,"primary":["mace"],"secondary":["mace"],"incompatible":["Density","Bane of Arthropods","Smite"],"treasure":true,"curse":false,"weight":2,"power":[[10,25],[20,35],[30,45],[40,55]]},
	"Wind Burst":{"max":3,"primary":["mace"],"secondary":["mace"],"incompatible":[],"treasure":true,"curse":false,"weight":2,"power":[[10,25],[20,35],[30,45]]},
	"Projectile Protection":{"max":4,"primary":["combat_armor"],"secondary":[],"incompatible":["Blast Protection","Fire Protection","Protection"],"treasure":false,"curse":false,"weight":5,"power":[[1,16],[11,26],[21,36],[31,46],[41,56]]},
	"Blast Protection":{"max":4,"primary":["combat_armor"],"secondary":[],"incompatible":["Fire Protection","Protection","Projectile Protection"],"treasure":false,"curse":false,"weight":2,"power":[[5,13],[13,21],[21,29],[29,37]]},
	"Fire Protection":{"max":4,"primary":["combat_armor"],"secondary":[],"incompatible":["Blast Protection","Protection","Projectile Protection"],"treasure":false,"curse":false,"weight":5,"power":[[5,13],[13,21],[21,29],[29,37]]},
	"Protection":{"max":4,"primary":["combat_armor"],"secondary":[],"incompatible":["Blast Protection","Fire Protection","Projectile Protection"],"treasure":false,"curse":false,"weight":5,"power":[[1,12],[12,23],[23,34],[34,45]]},
	"Feather Falling":{"max":4,"primary":["combat_armor_feet"],"secondary":[],"incompatible":[],"treasure":false,"curse":false,"weight":5,"power":[[5,11],[11,17],[17,23],[23,29]]},
	"Curse of Binding":{"max":1,"primary":[],"secondary":["armor_head","armor_torso","armor_legs","armor_feet"],"incompatible":[],"treasure":true,"curse":true,"weight":1,"power":[[25,50]]},
	"Thorns":{"max":3,"primary":["combat_armor_chestplate"],"secondary":["combat_armor"],"incompatible":[],"treasure":false,"curse":false,"weight":1,"power":[[10,61],[30,71],[50,81]]},
	"Aqua Affinity":{"max":1,"primary":["armor_head"],"secondary":[],"incompatible":[],"treasure":false,"curse":false,"weight":2,"power":[[1,41]]},
	"Sweeping Edge":{"max":3,"primary":["sword"],"secondary":[],"incompatible":[],"treasure":false,"curse":false,"weight":2,"power":[[5,20],[14,29],[23,38]]},
}

static func tags(id: int) -> Array:
	var result: Array = []
	if Nodes.durability(id) > 0: result.append("tool")
	if Nodes.is_tool_id(id): result.append(["pickaxe","axe","shovel","sword","hoe"][Nodes.tool_kind(id)])
	if Nodes.is_armor(id):
		result.append(["armor_head","armor_torso","armor_legs","armor_feet"][Nodes.armor_piece(id)])
		if id != Nodes.ELYTRA:
			result.append("combat_armor")
			result.append(["combat_armor_head","combat_armor_chestplate","combat_armor_legs","combat_armor_feet"][Nodes.armor_piece(id)])
	for pair in [[Nodes.BOW,"bow"],[VillageContent.CROSSBOW,"crossbow"],[VillageContent.FISHING_ROD,"fishing_rod"],[Nodes.SHEARS,"shears"],[VillageContent.TRIDENT,"trident"],[VillageContent.MACE,"mace"]]:
		if id == pair[0]: result.append(pair[1])
	if result.has("sword") or id in [Nodes.BOW,VillageContent.CROSSBOW,VillageContent.TRIDENT,VillageContent.MACE]: result.append("weapon")
	return result

static func accepts(id: int, name: String, table: bool = false) -> bool:
	if not DATA.has(name): return false
	var def: Dictionary = DATA[name]
	if table and def.treasure: return false
	if id in [Nodes.BOOK,VillageContent.ENCHANTED_BOOK]: return true
	var groups: Array = tags(id)
	for tag in def.primary+(def.secondary if not table else []):
		if groups.has(tag): return true
	return false

static func compatible(current: Dictionary, name: String) -> bool:
	if not DATA.has(name): return false
	for other in current:
		if other != name and DATA.has(other) and (DATA[name].incompatible.has(other) or DATA[other].incompatible.has(name)): return false
	return true

static func choices(id: int, table: bool = false) -> Array:
	var result: Array = []
	for name in DATA:
		if accepts(id,name,table): result.append(name)
	return result

static func clean(id: int, raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for name in raw:
		if accepts(id,name) and compatible(result,name) and int(raw[name]) > 0: result[name] = clampi(int(raw[name]),1,DATA[name].max)
	return result

static func combine(id: int, current: Dictionary, addition: Dictionary) -> Dictionary:
	var result: Dictionary = current.duplicate()
	for name in addition:
		if not accepts(id,name) or not compatible(result,name): continue
		var old: int = int(result.get(name,0)); var incoming: int = clampi(int(addition[name]),1,DATA[name].max)
		result[name] = mini(DATA[name].max,old+1) if old == incoming else maxi(old,incoming)
	return result

static func random_book(rng: RandomNumberGenerator) -> Dictionary:
	var names: Array = DATA.keys()
	var name: String = names[rng.randi_range(0,names.size()-1)]
	return {"enchantments":{name:rng.randi_range(1,DATA[name].max)}}

static func worn(player: VoxeyPlayer, name: String) -> int:
	var total: int = 0
	for slot in player.armor_slots: total += Inventory.enchantment(slot,name)
	return total

static func protection(player: VoxeyPlayer, cause: String) -> float:
	if cause == "void": return 1.0
	var points: int = worn(player,"Protection")
	if cause == "fall": points += 3*worn(player,"Feather Falling")
	if cause == "fire": points += 2*worn(player,"Fire Protection")
	if cause == "explosion": points += 2*worn(player,"Blast Protection")
	if cause == "projectile": points += 2*worn(player,"Projectile Protection")
	return 1.0-minf(20,points)*0.04

static func melee(player: VoxeyPlayer, mob: Creature) -> float:
	var slot: Dictionary = player.game.inventory.held()
	var damage: float = 2+(Nodes.tool_tier(slot.id)+1)*(2 if Nodes.tool_kind(slot.id)==3 else 1)
	if slot.id == VillageContent.TRIDENT: damage = 9
	if slot.id == VillageContent.MACE:
		var fall: float = maxf(0,-player.velocity.y-8)/4
		damage = 6+fall*(3+0.5*Inventory.enchantment(slot,"Density"))
		if fall > 0:
			player.velocity.y = 9+Inventory.enchantment(slot,"Wind Burst")*5
			player.damage_cooldown = maxf(player.damage_cooldown,0.4)
		# Armored shulkers and golems lose part of their protection to Breach.
		if mob.kind in ["shulker","iron_golem"]: damage *= 1+Inventory.enchantment(slot,"Breach")*0.15
	damage += Inventory.enchantment(slot,"Sharpness")*1.5
	if mob.kind in PotionEffects.UNDEAD: damage += Inventory.enchantment(slot,"Smite")*2.5
	if mob.kind in ["spider","silverfish","endermite"]:
		var bane: int = Inventory.enchantment(slot,"Bane of Arthropods")
		damage += bane*2.5
		if bane: PotionEffects.apply(mob,"slowness",randf_range(1,1+0.5*bane),4)
	if Inventory.enchantment(slot,"Fire Aspect"): PotionEffects.apply(mob,"burning",4*Inventory.enchantment(slot,"Fire Aspect"))
	mob.set_meta("looting",Inventory.enchantment(slot,"Looting"))
	var knockback: int = Inventory.enchantment(slot,"Knockback")
	if knockback: mob.knock += (mob.position-player.position).normalized()*knockback*3
	var sweep: int = Inventory.enchantment(slot,"Sweeping Edge")
	if sweep:
		for other in player.game.creatures.get_children():
			if other != mob and not other.is_queued_for_deletion() and other.position.distance_to(mob.position) < 1.5: other.hit(damage*sweep/(sweep+1.0),player.position)
	return damage*PotionEffects.melee(player)

static func mend(game: Node3D, amount: float) -> float:
	var remaining: float = amount
	for slot in game.player.armor_slots+[game.inventory.held()]:
		if remaining <= 0: break
		if slot.wear > 0 and Inventory.enchantment(slot,"Mending") > 0:
			var repaired: int = mini(slot.wear,floori(remaining*2))
			slot.wear -= repaired; remaining -= repaired*0.5
	return remaining

static func harvest(id: int, slot: Dictionary) -> Array:
	var silk: int = Inventory.enchantment(slot,"Silk Touch")
	var ores: Array = [Nodes.COAL_ORE,Nodes.DIAMOND_ORE,Nodes.LAPIS_ORE,Nodes.REDSTONE_ORE,Nodes.NETHER_QUARTZ_ORE,VillageContent.EMERALD_ORE,VillageContent.DEEP_EMERALD_ORE]+Nodes.DEEP_ORES.keys()
	if silk and (ores.has(id) or id in [Nodes.STONE,Nodes.DEEPSLATE,Nodes.GRASS,Nodes.GLASS,Nodes.ICE,Nodes.LEAVES,Nodes.BOOKSHELF,VillageContent.COBWEB]): return [[id,1]]
	var fortune: int = Inventory.enchantment(slot,"Fortune")
	if fortune > 0:
		if id == Nodes.GRAVEL: return [[Nodes.FLINT if fortune >= 3 or randf() < 0.1*(fortune+1) else Nodes.GRAVEL,1]]
		if ores.has(id):
			var count: int = randi_range(4,9) if id in [Nodes.LAPIS_ORE,Nodes.DEEP_LAPIS_ORE] else (randi_range(4,5) if id in [Nodes.REDSTONE_ORE,Nodes.DEEP_REDSTONE_ORE] else 1)
			return [[Nodes.drop(id),count*maxi(1,randi_range(0,fortune+1))]]
	return []

static func frost_step(game: Node3D, delta: float) -> void:
	var frozen: Dictionary = game.world.adventure_state.get("frosted_ice",{})
	for key in frozen.keys():
		frozen[key] -= delta
		if frozen[key] <= 0:
			var parts: PackedStringArray = key.split(","); var p := Vector3i(int(parts[0]),int(parts[1]),int(parts[2]))
			if game.world.node_at(p) == VillageContent.FROSTED_ICE: game.world.set_node(p,Nodes.WATER)
			frozen.erase(key)
	var frost: int = worn(game.player,"Frost Walker")
	if frost > 0 and game.player.grounded:
		var center := Vector3i((game.player.position-Vector3.UP*0.15).floor())
		for x in range(-frost-2,frost+3):
			for z in range(-frost-2,frost+3):
				var p: Vector3i = center+Vector3i(x,0,z)
				if Vector2(x,z).length() > frost+2: continue
				if game.world.node_at(p) == Nodes.WATER and game.world.node_at(p+Vector3i.UP) == Nodes.AIR:
					game.world.set_node(p,VillageContent.FROSTED_ICE); frozen[VoxelWorld.station_key(p)] = randf_range(3,5)
	if not frozen.is_empty() or game.world.adventure_state.has("frosted_ice"): game.world.adventure_state["frosted_ice"] = frozen

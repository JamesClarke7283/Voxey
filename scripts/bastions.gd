class_name Bastions
extends RefCounted

const POLISHED = 1100
const BRICKS = 1101
const CHISELED = 1102
const GILDED = 1103
const CRYING_OBSIDIAN = 1104
const LODESTONE = 1105
const PIGLIN_PATTERN = 1106
const MALL_DISC = 1107
const RIB_TRIM = 1108
const SNOUT_TRIM = 1109
const GOLD_TOOLS = 1110
const CHESTS = [Vector3i(-6,1,-6),Vector3i(6,8,6),Vector3i(0,15,0)]
# mcl_nether_fortresses/init.lua nether_bulwark chest groups, in source order.
# Entries: item, weight, minimum amount, maximum amount, enchanted.
const TREASURE = [
	[GILDED,1,8,12,false],[Nodes.IRON,1,4,9,false],[Nodes.GOLD,1,4,9,false],
	[CRYING_OBSIDIAN,1,3,8,false],[VillageContent.CROSSBOW,1,1,1,true],
	[Nodes.GOLD_BLOCK,1,1,1,false],[GOLD_TOOLS+3,1,1,1,false],
	[MALL_DISC,5,1,1,false],[PIGLIN_PATTERN,9,1,1,false],
	[GOLD_TOOLS+1,1,1,1,true],[Nodes.ARMOR_BASE+8,1,1,1,true],
	[Nodes.ARMOR_BASE+9,1,1,1,true],[Nodes.ARMOR_BASE+10,1,1,1,true],
	[Nodes.ARMOR_BASE+11,1,1,1,true],[Netherite.TEMPLATE,8,1,1,false],
	[Netherite.ANCIENT_DEBRIS,12,1,1,false],[Netherite.SCRAP,4,1,1,false]]
const SUPPLIES = [[Nodes.ARROW_ITEM,4,5,17,false],[Nodes.STRING,4,1,6,false],[Nodes.IRON_NUGGET,1,2,6,false],[Nodes.GOLD_NUGGET,1,2,6,false],[Nodes.LEATHER,1,1,3,false]]
const SPECIAL = [[LODESTONE,1,1,1,false],[RIB_TRIM,1,1,1,false],[SNOUT_TRIM,1,1,1,false]]

static func site(gen: TerrainGenerator, region: Vector2i) -> Dictionary:
	if gen.hash_at(region.x,17291,region.y)%25 != 0: return {}
	var center := Vector3i(region.x*80+8,0,region.y*80+8)
	if not WorldBounds.horizontal(center) or gen.biome(center.x,center.z) == "Basalt deltas": return {}
	center.y = maxi(15,gen.terrain_height(center.x,center.z))
	return {"center":center,"key":"bastion:%d:%d"%[region.x,region.y]}

static func nearest(gen: TerrainGenerator, near: Vector3) -> Dictionary:
	var region := Vector2i(floori((near.x+32)/80.0),floori((near.z+32)/80.0))
	var best: Dictionary = {}; var distance: float = INF
	for radius in range(65):
		for x in range(-radius,radius+1):
			for z in range(-radius,radius+1):
				if maxi(absi(x),absi(z)) != radius: continue
				var candidate: Dictionary = site(gen,region+Vector2i(x,z))
				if candidate.is_empty(): continue
				var d: float = Vector2(candidate.center.x-near.x,candidate.center.z-near.z).length()
				if d < distance: distance = d; best = candidate
		if not best.is_empty() and radius*80 > distance+120: break
	return best

static func at(gen: TerrainGenerator, p: Vector3i) -> Dictionary:
	var s: Dictionary = site(gen,Vector2i(floori((p.x+32)/80.0),floori((p.z+32)/80.0)))
	if s.is_empty(): return {}
	var q: Vector3i = p-s.center
	return s if absi(q.x) <= 10 and absi(q.z) <= 10 and q.y in range(0,25) else {}

static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array) -> void:
	var base := Vector2i(coord.x*16-1,coord.y*16-1)
	for z in 18:
		for x in 18:
			var p := Vector3i(base.x+x,0,base.y+z)
			var s: Dictionary = site(gen,Vector2i(floori((p.x+32)/80.0),floori((p.z+32)/80.0)))
			if s.is_empty() or absi(p.x-s.center.x) > 10 or absi(p.z-s.center.z) > 10: continue
			for y in range(s.center.y,s.center.y+25):
				p.y = y
				data[x+z*18+y*324] = node(p-s.center,gen.hash_at(p.x,p.y,p.z))

static func node(q: Vector3i, seed_value: int) -> int:
	if CHESTS.has(q): return Nodes.CHEST
	# Voxey layout: source-sized blackstone bulwark with three accessible levels.
	# Full source schematic variants remain tracked separately in the parity ledger.
	if q.y == 0: return GILDED if seed_value%23 == 0 else BRICKS
	if q.x == -8 and q.z == 0 and q.y in range(1,23): return Nodes.LADDER
	if q.x == -9 and q.z == 0: return POLISHED
	if absi(q.x) == 10 or absi(q.z) == 10:
		if q.z == 10 and absi(q.x) <= 2 and q.y in range(1,5): return Nodes.AIR
		if q.y%7 in [3,4] and absi(q.x)%5 != 0 and absi(q.z)%5 != 0: return Nodes.AIR
		return CHISELED if q.y%7 == 0 else BRICKS
	if q.y in [7,14,21]: return BRICKS
	if q.y in [1,2] and absi(q.x) <= 2 and absi(q.z) <= 2: return Nodes.GOLD_BLOCK
	if q.y in [5,12,19] and absi(q.x) == 8 and absi(q.z) == 8: return Nodes.SHROOMLIGHT
	return Nodes.AIR

static func roll(rng: RandomNumberGenerator, entries: Array) -> Dictionary:
	var total: int = 0
	for entry in entries: total += entry[1]
	var selection: int = rng.randi_range(1,total)
	for entry in entries:
		selection -= entry[1]
		if selection > 0: continue
		var stack: Dictionary = {"id":entry[0],"count":rng.randi_range(entry[2],entry[3]),"wear":0}
		if entry[4]:
			var choices: Array = Enchantments.choices(entry[0])
			if not choices.is_empty():
				var enchant: String = choices[rng.randi_range(0,choices.size()-1)]
				stack["data"] = {"enchantments":{enchant:rng.randi_range(1,Enchantments.DATA[enchant].max)}}
		return stack
	return {}

static func fill(station: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value
	var slots: Array = range(station.slots.size())
	for i in range(slots.size()-1,0,-1):
		var other: int = rng.randi_range(0,i); var old: int = slots[i]; slots[i] = slots[other]; slots[other] = old
	var index: int = 0
	for group in [[TREASURE,1,2],[SUPPLIES,2,4],[SPECIAL,1,1]]:
		for count in rng.randi_range(group[1],group[2]):
			station.slots[slots[index]] = roll(rng,group[0]); index += 1
	station["label"] = "Bastion treasure"

static func recipes(inv: Inventory) -> void:
	for result in [POLISHED,BRICKS,CHISELED]:
		var ingredient: int = {POLISHED:MinecloniaOres.BLACKSTONE,BRICKS:POLISHED,CHISELED:POLISHED}[result]
		inv._recipe(Nodes.title(result),result,4,[ingredient,ingredient,ingredient,ingredient],2)
	inv._recipe("Lodestone",LODESTONE,1,[VillageContent.CHISELED_BRICKS,VillageContent.CHISELED_BRICKS,VillageContent.CHISELED_BRICKS,VillageContent.CHISELED_BRICKS,Netherite.INGOT,VillageContent.CHISELED_BRICKS,VillageContent.CHISELED_BRICKS,VillageContent.CHISELED_BRICKS,VillageContent.CHISELED_BRICKS],3,"table")
	inv._recipe("Fire charges",PiglinBarter.FIRE_CHARGE,3,[Nodes.COAL,Nodes.BLAZE_POWDER,Nodes.GUNPOWDER],3)
	inv.recipes.back()["shapeless"] = true
	var gold: int = Nodes.GOLD; var stick: int = Nodes.STICK
	var patterns: Array = [[gold,gold,gold,0,stick,0,0,stick,0],[gold,gold,0,gold,stick,0,0,stick,0],[0,gold,0,0,stick,0,0,stick,0],[0,gold,0,0,gold,0,0,stick,0],[gold,gold,0,0,stick,0,0,stick,0]]
	for kind in 5: inv._recipe(Nodes.title(GOLD_TOOLS+kind),GOLD_TOOLS+kind,1,patterns[kind],3,"table")

static func populate(game: Node3D) -> void:
	if not game.world.adventure_state.has("nether_residents"): game.world.adventure_state["nether_residents"] = {}
	var people: Dictionary = game.world.adventure_state.nether_residents
	var closest: Dictionary = nearest(game.world.generator,game.player.position)
	if not closest.is_empty() and Vector3(closest.center).distance_to(game.player.position) < 85:
		for i in 4:
			var key: String = closest.key+"/"+str(i)
			if people.has(key): continue
			var p: Vector3 = Vector3(closest.center)+[Vector3(5.5,1.01,-5.5),Vector3(-5.5,8.01,5.5),Vector3(4.5,15.01,-4.5),Vector3(-4.5,15.01,-4.5)][i]
			people[key] = {"key":key,"kind":"piglin_brute" if i == 3 else "piglin","position":[p.x,p.y,p.z],"health":50.0 if i == 3 else 16.0,"dead":false}
	var existing: Dictionary = {}
	for mob in game.creatures.get_children():
		if mob is NetherResident and not mob.is_queued_for_deletion(): existing[mob.resident_key] = true
	for key in people:
		var entry: Dictionary = people[key]
		if existing.has(key) or entry.dead: continue
		var pos: Vector3 = VillageLife.vec(entry.position)
		if pos.distance_to(game.player.position) > 75 or not game.world.loaded_at(pos) or game.world.intersects(pos): continue
		var mob: NetherResident = game.spawn_creature(entry.kind,pos)
		mob.bind(entry)

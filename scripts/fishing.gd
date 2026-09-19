class_name Fishing
extends RefCounted

# Exact loot entries from Mineclonia mcl_fishing/init.lua, including its
# intentional duplicate string junk entry (the source's tripwire-hook TODO).
const NAME_TAG = 1200
const NAUTILUS_SHELL = 1201
const ITEMS = {
	1200:{"name":"Name tag","color":"d2bb83","family":"name_tag"},
	1201:{"name":"Nautilus shell","color":"dba673","family":"nautilus_shell"},
}
const BITE_WINDOW = 0.8
const MAX_DISTANCE = 33.0
const FISH = [
	{"id":VillageContent.RAW_COD,"weight":60}, {"id":VillageContent.RAW_SALMON,"weight":25},
	{"id":VillageContent.TROPICAL_FISH,"weight":2}, {"id":VillageContent.PUFFERFISH,"weight":13},
]
const JUNK = [
	{"id":Nodes.BOWL,"weight":10}, {"id":VillageContent.FISHING_ROD,"weight":2,"wear_min":6554,"wear_max":65535},
	{"id":Nodes.LEATHER,"weight":10}, {"id":Nodes.ARMOR_BASE+3,"weight":10,"wear_min":6554,"wear_max":65535},
	{"id":Nodes.ROTTEN_FLESH,"weight":10}, {"id":Nodes.STICK,"weight":5}, {"id":Nodes.STRING,"weight":5},
	{"id":VillageContent.WATER_BOTTLE,"weight":10}, {"id":Nodes.BONE,"weight":10},
	{"id":VillageContent.INK_SAC,"weight":1,"count":10}, {"id":Nodes.STRING,"weight":10},
]
const TREASURE = [
	{"id":Nodes.BOW,"weight":1,"wear_min":49144,"wear_max":65535,"enchanted":true},
	{"id":VillageContent.ENCHANTED_BOOK,"weight":1,"enchanted":true},
	{"id":VillageContent.FISHING_ROD,"weight":1,"wear_min":49144,"wear_max":65535,"enchanted":true},
	{"id":NAME_TAG,"weight":1}, {"id":Nodes.SADDLE,"weight":1},
	{"id":VillageContent.LILY_PAD,"weight":1}, {"id":NAUTILUS_SHELL,"weight":1},
]

static func category(luck: int, roll: int) -> String:
	var index: int = clampi(luck,0,3)
	var fish: float = [85.0,84.8,84.7,84.5][index]
	var junk: float = [10.0,8.1,6.1,4.2][index]
	# The source compares its integer 1..100 roll to fractional thresholds.
	if roll <= fish: return "fish"
	return "junk" if roll <= fish+junk else "treasure"

static func select_entry(entries: Array, roll: int) -> Dictionary:
	for entry in entries:
		roll -= int(entry.get("weight",1))
		if roll <= 0: return entry
	return {}

static func total_weight(entries: Array) -> int:
	var total: int = 0
	for entry in entries: total += int(entry.get("weight",1))
	return total

static func wait_time(lure: int, raining: bool, rng: RandomNumberGenerator) -> float:
	var reduced: int = clampi(lure,0,3)*5
	return rng.randi_range(maxi(0,5-reduced),30-reduced)*(0.75 if raining else 1.0)

static func enchant_candidates(id: int, current: Dictionary) -> Array:
	var candidates: Array = []
	var book: bool = id == VillageContent.ENCHANTED_BOOK
	for name in Enchantments.DATA:
		# These two treasure enchants are not tradable in the source, and the
		# final two are only disabled definitions in this reference checkout.
		if name in ["Soul Speed","Wind Burst","Aqua Affinity","Sweeping Edge"] or current.has(name): continue
		var definition: Dictionary = Enchantments.DATA[name]
		if not Enchantments.accepts(id,name) or (not book and not Enchantments.compatible(current,name)): continue
		var primary: bool = book and not definition.treasure
		for tag in Enchantments.tags(id):
			if definition.primary.has(tag): primary = true
		if primary or definition.treasure: candidates.append({"name":name,"weight":definition.weight})
	return candidates

# mcl_enchanting/engine.lua's level-30 treasure rolls. Books keep selecting
# at successively halved powers; rods and bows also use the bonus cutoff.
static func treasure_enchantments(id: int, rng: RandomNumberGenerator) -> Dictionary:
	for attempt in 256:
		var power: int = maxi(1,floori(31.0+31.0*(rng.randf()+rng.randf()-1.0)*0.15+0.5))
		var result: Dictionary = {}
		while power > 0:
			var candidates: Array = enchant_candidates(id,result)
			if candidates.is_empty(): break
			var chosen: Dictionary = select_entry(candidates,rng.randi_range(1,total_weight(candidates)))
			var definition: Dictionary = Enchantments.DATA[chosen.name]
			var potency: int = 0
			for i in range(int(definition.max)-1,-1,-1):
				if power >= definition.power[i][0] and power <= definition.power[i][1]: potency = i+1; break
			if potency == 0 and result.is_empty(): break
			if potency > 0: result[chosen.name] = potency
			if id != VillageContent.ENCHANTED_BOOK and rng.randf() >= (power+1)/50.0: break
			power /= 2
		if not result.is_empty(): return result
	# Defensive fallback for a modded enchantment catalog with no valid powers.
	return {}

static func stack_from_entry(entry: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var id: int = entry.id
	var stack: Dictionary = {"id":id,"count":entry.get("count",1),"wear":0}
	if entry.has("wear_min"):
		# mcl_loot quantizes normalized wear to ten units, never 65535. Keep
		# even almost-broken rewards usable in Voxey's discrete use counters.
		var normalized: int = rng.randi_range(int(entry.wear_min)/10,int(entry.wear_max)/10)*10
		stack.wear = mini(Nodes.durability(id)-1,floori(normalized/65535.0*Nodes.durability(id)))
	if entry.get("enchanted",false): stack["data"] = {"enchantments":treasure_enchantments(id,rng)}
	return stack

static func catch_result(rng: RandomNumberGenerator, luck: int) -> Dictionary:
	var kind: String = category(luck,rng.randi_range(1,100))
	var entries: Array = {"fish":FISH,"junk":JUNK,"treasure":TREASURE}[kind]
	var entry: Dictionary = select_entry(entries,rng.randi_range(1,total_weight(entries)))
	return {"category":kind,"stack":stack_from_entry(entry,rng),"experience":rng.randi_range(1,6)}

static func cancel(survival: RefCounted) -> void:
	if is_instance_valid(survival.bobber): survival.bobber.queue_free()
	survival.bobber = null
	survival.fishing = 0.0; survival.fishing_bite = 0.0
	survival.fishing_state.clear()

static func source_position(survival: RefCounted) -> Vector3i:
	var coordinates: Array = survival.fishing_state.get("water",[0,0,0])
	return Vector3i(coordinates[0],coordinates[1],coordinates[2])

static func _schedule(survival: RefCounted, rng: RandomNumberGenerator) -> void:
	var game: Node3D = survival.game
	var lure: int = Inventory.enchantment(game.inventory.held(),"Lure")
	var rain: bool = survival.weather() in ["rain","thunder"] and game.world.open_sky(source_position(survival))
	survival.fishing = 0.0; survival.fishing_bite = wait_time(lure,rain,rng)
	survival.fishing_state["bubbling"] = false

static func update(survival: RefCounted, delta: float) -> void:
	if not is_instance_valid(survival.bobber): return
	var game: Node3D = survival.game
	if game.player.health <= 0 or game.inventory.held().id != VillageContent.FISHING_ROD or survival.bobber.position.distance_to(game.player.position) > MAX_DISTANCE:
		cancel(survival); return
	var water: Vector3i = source_position(survival)
	if not game.world.loaded_at(Vector3(water)): cancel(survival); return
	# Source-water cells alone advance the fishing clock. Flowing water or a
	# drained pool cannot generate catches from an old bite timer.
	if game.world.node_at(water) != Nodes.WATER:
		survival.fishing_state["bubbling"] = false
		return
	if survival.fishing_bite <= 0:
		var retry_rng := RandomNumberGenerator.new(); retry_rng.randomize()
		_schedule(survival,retry_rng)
		return
	survival.fishing += maxf(0,delta)
	var biting: bool = survival.fishing >= survival.fishing_bite and survival.fishing < survival.fishing_bite+BITE_WINDOW
	var anchor: Vector3 = Vector3(water)+Vector3(0.5,0.98,0.5)
	survival.bobber.position = anchor+Vector3.UP*(-0.18 if biting else sin(survival.fishing*8)*0.025)
	if biting:
		if not survival.fishing_state.get("bubbling",false): game.sound("splash")
		game.puff(survival.bobber.position,Color("a2d3d9"),1,0.5)
	survival.fishing_state["bubbling"] = biting
	if survival.fishing >= survival.fishing_bite+BITE_WINDOW:
		var rng := RandomNumberGenerator.new(); rng.randomize()
		_schedule(survival,rng)

static func reel(survival: RefCounted, rng: RandomNumberGenerator) -> Dictionary:
	var game: Node3D = survival.game
	if not is_instance_valid(survival.bobber) or game.inventory.held().id != VillageContent.FISHING_ROD: cancel(survival); return {}
	if survival.bobber.position.distance_to(game.player.position) > MAX_DISTANCE or game.player.health <= 0: cancel(survival); return {}
	var node: int = game.world.node_at(source_position(survival))
	var result: Dictionary = {}
	var uses: int = 0
	if node == Nodes.WATER and survival.fishing_bite > 0 and survival.fishing >= survival.fishing_bite and survival.fishing < survival.fishing_bite+BITE_WINDOW:
		result = catch_result(rng,Inventory.enchantment(game.inventory.held(),"Luck of the Sea"))
		var stack: Dictionary = result.stack
		var overflow: int = stack.count
		if game.inventory.capacity(stack.id,stack.wear,stack.get("data",{})) >= stack.count:
			overflow = game.inventory.add_item(stack.id,stack.count,stack.wear,stack.get("data",{}))
		if overflow > 0: game.spawn_drop(game.player.position+Vector3.UP,stack.id,overflow,stack.wear,stack.get("data",{}))
		game.experience += result.experience
		if result.category == "fish": game.achievements.award("fishy_business")
		uses = 1
		game.toast("Caught %s%s!"%[Nodes.title(stack.id).to_lower()," × %d"%stack.count if stack.count > 1 else ""])
	elif Nodes.solid(node): uses = 2; game.toast("The bobber snagged on land.")
	else: game.toast("No catch. Reel in during the bobber's splash.")
	if game.gamemode != "creative":
		for i in uses:
			if game.inventory.held().id != VillageContent.FISHING_ROD: break
			if game.inventory.damage_tool(): break
	cancel(survival); game.sound("click")
	return result

static func use(survival: RefCounted, target: Dictionary) -> void:
	var rng := RandomNumberGenerator.new(); rng.randomize()
	if is_instance_valid(survival.bobber): reel(survival,rng); return
	var game: Node3D = survival.game
	if game.inventory.held().id != VillageContent.FISHING_ROD: return
	if target.is_empty() or not target.has("pos") or game.world.node_at(target.pos) != Nodes.WATER:
		game.toast("Cast into still water. Reel in when the bobber dips and splashes."); return
	var water: Vector3i = target.pos
	var anchor: Vector3 = Vector3(water)+Vector3(0.5,0.98,0.5)
	if anchor.distance_to(game.player.position) > MAX_DISTANCE or not game.world.loaded_at(anchor) or Nodes.solid(game.world.node_at(water+Vector3i.UP)):
		game.toast("The fishing line needs a clear water surface within reach."); return
	survival.bobber = MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = Vector3(0.15,0.18,0.15); survival.bobber.mesh = mesh
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("e87664"); survival.bobber.material_override = mat
	survival.bobber.position = anchor; game.entities.add_child(survival.bobber)
	survival.fishing_state = {"water":[water.x,water.y,water.z]}
	_schedule(survival,rng)
	game.toast("Line cast. Watch for a dip and splash, then reel in quickly.")

static func recipes(inv: Inventory) -> void:
	for nugget in [Nodes.IRON_NUGGET,Nodes.GOLD_NUGGET]:
		inv._recipe("Name tag",NAME_TAG,1,[0,nugget,Nodes.PAPER,0],2)

static func draw(img: Image, id: int, base: Color) -> void:
	if id == NAME_TAG:
		ItemArt._polygon(img,[[2,6],[7,2],[14,9],[9,14]],base)
		ItemArt._line(img,Vector2(5,5),Vector2(10,10),base.darkened(0.28))
		img.fill_rect(Rect2i(4,5,2,2),Color("544b3d"))
	else:
		ItemArt._polygon(img,[[4,2],[10,2],[14,6],[14,11],[11,14],[5,13],[2,10],[2,5]],base)
		ItemArt._line(img,Vector2(4,5),Vector2(9,3),base.lightened(0.35),2)
		for pair in [[Vector2(11,5),Vector2(12,10)],[Vector2(12,10),Vector2(6,11)],[Vector2(6,11),Vector2(5,7)],[Vector2(5,7),Vector2(9,6)],[Vector2(9,6),Vector2(9,9)]]:
			ItemArt._line(img,pair[0],pair[1],Color("946447"))

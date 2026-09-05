class_name VoxeyAchievements
extends RefCounted

## Achievement tracking. Each achievement has an id, title, description, and
## an optional goal with a persisted progress counter. `award` fires a toast,
## a fanfare, and saves to the world file. Progress-based achievements count
## distinct milestones (e.g. tools crafted) and award when the goal is hit.

const DEFINITIONS = [
	{"id":"first_log","title":"Timber!","description":"Gather your first oak log.","goal":0},
	{"id":"craft_planks","title":"Joiner","description":"Craft oak planks.","goal":0},
	{"id":"craft_table","title":"Workshop","description":"Place a crafting table.","goal":0},
	{"id":"first_pickaxe","title":"Rock Bottom","description":"Craft a wooden pickaxe.","goal":0},
	{"id":"mine_stone","title":"Stonework","description":"Mine cobblestone.","goal":0},
	{"id":"iron_age","title":"The Iron Age","description":"Smelt an iron ingot.","goal":0},
	{"id":"diamonds","title":"Shinies!","description":"Harvest a diamond.","goal":0},
	{"id":"kill_zombie","title":"Grave Robber","description":"Defeat a zombie at night.","goal":0},
	{"id":"survivor","title":"Survivor","description":"Survive 5 days in one world.","goal":0},
	{"id":"wool_gatherer","title":"Barber","description":"Shear a sheep with shears.","goal":0},
	{"id":"milkmaid","title":"Milkmaid","description":"Milk a cow with a bucket.","goal":0},
	{"id":"baker","title":"Baker","description":"Bake bread.","goal":0},
	{"id":"diamond_gear","title":"Fully Equipped","description":"Wear a full set of diamond armor.","goal":0},
	{"id":"deep","title":"Spelunker","description":"Descend below Y 8.","goal":0},
	{"id":"sniper_hurt","title":"Ouch.","description":"Take fall damage.","goal":0},
	{"id":"bookworm","title":"Bookworm","description":"Craft a bookshelf.","goal":0},
]

var game: Node3D
var unlocked := {}            # id -> true
var counters := {}            # id -> progress for goal-based achievements

func _init(game_ref: Node3D) -> void:
	game = game_ref

func is_unlocked(id: String) -> bool:
	return unlocked.has(id)

func count(id: String) -> int:
	return int(counters.get(id,0))

## Unlock an achievement. No-op in creative mode for progression awards and
## when already unlocked. Returns true on the unlocking call.
func award(id: String) -> bool:
	if unlocked.has(id): return false
	if game.gamemode == "creative" and id != "wool_gatherer" and id != "milkmaid": return false
	var definition: Dictionary = _definition(id)
	if definition.is_empty(): return false
	unlocked[id] = true
	counters[id] = 1
	game.toast("Achievement: %s — %s" % [definition.title,definition.description])
	game.sound("equip")
	game.experience += 2
	return true

## Record progress toward a goal-based achievement. Awards at the goal.
func progress(id: String, amount: int = 1) -> bool:
	var definition: Dictionary = _definition(id)
	if definition.is_empty() or unlocked.has(id): return false
	if int(definition.goal) <= 0: return award(id)
	var value: int = int(counters.get(id,0))+amount
	counters[id] = value
	if value >= int(definition.goal): return award(id)
	return false

func _definition(id: String) -> Dictionary:
	for definition in DEFINITIONS:
		if definition.id == id: return definition
	return {}

## Persistence: compact two lists in the world save.
func to_save() -> Dictionary:
	return {"unlocked":unlocked.keys(),"counters":counters}

func from_save(data: Dictionary) -> void:
	unlocked.clear()
	counters.clear()
	if not data is Dictionary: return
	for id in data.get("unlocked",[]):
		if _definition(String(id)).id == String(id): unlocked[String(id)] = true
	var counters_data: Dictionary = data.get("counters",{})
	if counters_data is Dictionary:
		for id in counters_data:
			if _definition(String(id)).id == String(id): counters[String(id)] = int(counters_data[id])
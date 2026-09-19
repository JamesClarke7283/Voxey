class_name VoxeyAchievements
extends RefCounted

## Achievement tracking. Each achievement has an id, title, description, and
## an optional goal with a persisted progress counter. `award` fires a toast,
## a fanfare, and saves to the world file. Progress-based achievements count
## distinct milestones (e.g. tools crafted) and award when the goal is hit.

const DEFINITIONS = [
	{"id":"bee_our_guest","title":"Bee Our Guest","description":"Collect honey with a bottle while a campfire smokes the hive.","goal":0,"xp":0},
	{"id":"total_beelocation","title":"Total Beelocation","description":"Use Silk Touch to recover a bee nest.","goal":0,"xp":0},
	{"id":"bullseye","title":"Bullseye","description":"Hit a target bullseye from at least 30 blocks away.","goal":0,"xp":0},
	{"id":"first_log","title":"Timber!","description":"Gather your first oak log.","goal":0},
	{"id":"craft_planks","title":"Joiner","description":"Craft oak planks.","goal":0},
	{"id":"craft_table","title":"Workshop","description":"Place a crafting table.","goal":0},
	{"id":"withering_heights","title":"Withering Heights","description":"Summon the wither.","goal":0},
	{"id":"post_mortal","title":"Postmortal","description":"Use a totem of undying to cheat death.","goal":0},
	{"id":"zombie_doctor","title":"Zombie Doctor","description":"Cure a zombie villager with a golden apple and weakness.","goal":0},
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
	{"id":"fishy_business","title":"Fishy Business","description":"Catch a fish with a fishing rod.","goal":0,"xp":0},
	{"id":"parrots_and_bats","title":"The Parrots and the Bats","description":"Breed two animals.","goal":0,"xp":0},
	# The source award set's remaining reachable titles, each triggered by a system
	# Voxey already runs. `reward_xp` is carried through as the existing `xp` field.
	{"id":"hero_of_the_village","title":"Hero of the Village","description":"Successfully defend a village from a raid.","goal":0,"xp":100},
	{"id":"serious_dedication","title":"Serious Dedication","description":"Use a Netherite ingot to upgrade a diamond tool or armor.","goal":0,"xp":0},
	{"id":"enchanter","title":"Enchanter","description":"Enchant an item at an enchanting table.","goal":0,"xp":0},
	{"id":"local_brewery","title":"Local Brewery","description":"Brew a potion.","goal":0,"xp":0},
	{"id":"what_a_deal","title":"What A Deal!","description":"Trade with a villager.","goal":0,"xp":0},
	{"id":"wax_on","title":"Wax On","description":"Apply honeycomb to a copper block.","goal":0,"xp":0},
	{"id":"wax_off","title":"Wax Off","description":"Scrape the wax off a copper block with an axe.","goal":0,"xp":0},
	{"id":"country_lode","title":"Country Lode, Take Me Home","description":"Use a compass on a lodestone.","goal":0,"xp":0},
	{"id":"sweet_dreams","title":"Sweet Dreams","description":"Sleep in a bed to set your spawn.","goal":0,"xp":0},
	{"id":"sky_is_the_limit","title":"Sky's the Limit","description":"Glide with an elytra.","goal":0,"xp":0},
	{"id":"the_next_generation","title":"The Next Generation","description":"Pick up a dragon egg.","goal":0,"xp":0},
	{"id":"free_the_end","title":"Free the End","description":"Defeat the Ender Dragon.","goal":0,"xp":0},
	{"id":"the_end_again","title":"The End... Again...","description":"Respawn the Ender Dragon.","goal":0,"xp":0},
	{"id":"we_need_to_go_deeper","title":"We Need to Go Deeper","description":"Build and enter a Nether portal.","goal":0,"xp":0},
	{"id":"the_nether","title":"The Nether","description":"Enter the Nether.","goal":0,"xp":0},
	{"id":"the_end","title":"The End?","description":"Enter the End through an end portal.","goal":0,"xp":0},
	{"id":"hidden_in_the_depths","title":"Hidden in the Depths","description":"Mine ancient debris.","goal":0,"xp":0},
	{"id":"into_fire","title":"Into Fire","description":"Collect a blaze rod.","goal":0,"xp":0},
	{"id":"cow_tipper","title":"Cow Tipper","description":"Collect leather from a cow.","goal":0,"xp":0},
	{"id":"delicious_fish","title":"Delicious Fish","description":"Cook a fish.","goal":0,"xp":0},
	{"id":"hot_topic","title":"Hot Topic","description":"Build a furnace.","goal":0,"xp":0},
	{"id":"acquire_hardware","title":"Acquire Hardware","description":"Smelt an iron ingot.","goal":0,"xp":0},
	{"id":"time_to_strike","title":"Time to Strike!","description":"Craft a sword.","goal":0,"xp":0},
	{"id":"time_to_farm","title":"Time to Farm!","description":"Craft a hoe.","goal":0,"xp":0},
	{"id":"getting_an_upgrade","title":"Getting an Upgrade","description":"Craft a stone pickaxe.","goal":0,"xp":0},
	{"id":"the_lie","title":"The Lie","description":"Bake a cake.","goal":0,"xp":0},
	{"id":"librarian","title":"Librarian","description":"Craft a bookshelf.","goal":0,"xp":0},
	{"id":"bring_home_the_beacon","title":"Bring Home the Beacon","description":"Activate a beacon.","goal":0,"xp":0},
	{"id":"beaconator","title":"Beaconator","description":"Build a maximum-level beacon and choose a second effect.","goal":0,"xp":0},
	{"id":"monster_hunter","title":"Monster Hunter","description":"Defeat a hostile creature.","goal":0,"xp":0},
	{"id":"a_throwaway_joke","title":"A Throwaway Joke","description":"Throw a trident at a creature and hit it.","goal":0,"xp":0},
	{"id":"return_to_sender","title":"Return to Sender","description":"Deflect a ghast fireball and slay a ghast.","goal":0,"xp":50},
	{"id":"crafting_a_new_look","title":"Crafting a New Look","description":"Apply an armor trim at a smithing table.","goal":0,"xp":0},
	{"id":"smithing_with_style","title":"Smithing with Style","description":"Apply eight different armor trims.","goal":8,"xp":0},
	{"id":"obsidian_challenge","title":"Ice Bucket Challenge","description":"Obtain a block of obsidian.","goal":0,"xp":0},
	{"id":"hot_stuff","title":"Hot Stuff","description":"Fill a bucket with lava.","goal":0,"xp":0},
	{"id":"sniper_duel","title":"Sniper Duel","description":"Kill a skeleton with an arrow from at least 50 blocks away.","goal":0,"xp":50},
	{"id":"who_is_cutting_onions","title":"Who is Cutting Onions?","description":"Obtain a crying obsidian block.","goal":0,"xp":0},
]

var game: Node3D
var unlocked := {}            # id -> true
var counters := {}            # id -> progress for goal-based achievements
var distinct := {}            # id -> {key: true} for distinct-key goals

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
	# The source awards experience only where an achievement declares `reward_xp`, and
	# only five of its achievements do. Paying a default of two meant an ordinary kill
	# could pay twice — once for the mob's own `xp_min` and again for the achievement
	# the kill unlocked.
	var reward: int = int(definition.get("xp",0))
	if reward > 0: game.experience += reward
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

# Goal counters that count **distinct keys** rather than occurrences, which is what
# the source's `smithing_with_style` needs: eight different trims, not eight
# applications. The seen set is stored alongside the existing counter.
func track_distinct(id: String, key: String) -> bool:
	var definition: Dictionary = _definition(id)
	if definition.is_empty() or unlocked.has(id) or key.is_empty(): return false
	var seen: Dictionary = distinct.get(id,{})
	if seen.has(key): return false
	seen[key] = true
	distinct[id] = seen
	var value: int = seen.size()
	counters[id] = value
	if int(definition.goal) > 0 and value >= int(definition.goal): return award(id)
	return false

func _definition(id: String) -> Dictionary:
	for definition in DEFINITIONS:
		if definition.id == id: return definition
	return {}

## Persistence: compact two lists in the world save.
func to_save() -> Dictionary:
	return {"unlocked":unlocked.keys(),"counters":counters,"distinct":distinct}

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
	# Distinct-key goals keep their seen set, so a reload does not re-count trims.
	distinct.clear()
	var distinct_data: Dictionary = data.get("distinct",{})
	if distinct_data is Dictionary:
		for id in distinct_data:
			if _definition(String(id)).id != String(id): continue
			var seen: Dictionary = {}
			for key in distinct_data[id]: seen[String(key)] = true
			distinct[String(id)] = seen

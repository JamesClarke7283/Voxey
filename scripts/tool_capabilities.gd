class_name ToolCapabilities
extends RefCounted

# Real registered Mineclonia groupcaps and Luanti digging groups. Effect formulas
# follow mcl_potions/functions.lua, including its rational Fatigue progression.
static var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/digging.json"))
const CORE = {
	0:"air",1:"mcl_core:dirt_with_grass",2:"mcl_core:dirt",3:"mcl_core:stone",4:"mcl_core:sand",5:"mcl_core:water_source",
	6:"mcl_trees:tree_oak",7:"mcl_trees:leaves_oak",8:"mcl_trees:wood_oak",9:"mcl_core:cobble",
	10:"mcl_core:stone_with_coal",11:"mcl_core:stone_with_iron",12:"mcl_core:stone_with_diamond",14:"mcl_core:cactus",
	15:"mcl_crafting_table:crafting_table",16:"mcl_furnaces:furnace",17:"mcl_chests:chest_small",18:"mcl_torches:torch",
	19:"mcl_core:glass",20:"mcl_core:stonebrick",21:"mcl_farming:soil",23:"mcl_trees:sapling_oak",25:"mcl_core:obsidian",
	26:"mcl_core:gravel",28:"mcl_core:bedrock",30:"mcl_core:sandstone",31:"mcl_core:sandstonecarved",
	34:"mcl_core:stone_with_gold",35:"mcl_copper:stone_with_copper",36:"mcl_raw_ores:raw_gold_block",
	37:"mcl_copper:block",38:"mcl_raw_ores:raw_iron_block",39:"mcl_core:diamondblock",40:"mcl_tnt:tnt",
	Nodes.IRON_BLOCK:"mcl_core:ironblock",Nodes.ICE:"mcl_core:ice",Nodes.SNOW_BLOCK:"mcl_core:snowblock",
	Nodes.CLAY:"mcl_core:clay",Nodes.BOOKSHELF:"mcl_books:bookshelf",Nodes.LADDER:"mcl_core:ladder",
	Nodes.NETHERRACK:"mcl_nether:netherrack",Nodes.SOUL_SAND:"mcl_nether:soul_sand",Nodes.GLOWSTONE:"mcl_nether:glowstone",
	Nodes.NETHER_BRICKS:"mcl_nether:nether_brick",Nodes.NETHER_QUARTZ_ORE:"mcl_nether:quartz_ore",
	Nodes.ENCHANTING_TABLE:"mcl_enchanting:table",Nodes.LAPIS_ORE:"mcl_core:stone_with_lapis",
	Nodes.DEEPSLATE:"mcl_deepslate:deepslate",Nodes.REDSTONE_ORE:"mcl_core:stone_with_redstone",
	Nodes.END_STONE:"mcl_end:end_stone",Nodes.END_BRICKS:"mcl_end:end_bricks",Nodes.PURPUR:"mcl_end:purpur_block",
}

static func f32(value: float) -> float: return PackedFloat32Array([value])[0]

static func factors(haste: int, fatigue: int, conduit: int = 0, wet: bool = false) -> Dictionary:
	var h: float = (1+0.2*haste)*(1+(0.2*conduit if wet else 0))-1
	var f: float = maxf(0,(0.3-0.09)*2/fatigue+2*0.09-0.3) if fatigue > 0 else 1
	return {"haste":h,"fatigue":f}

static func interval(base: float, speeds: Dictionary) -> float:
	var h: int = roundi(5*float(speeds.get("haste",0)))
	var f: int = roundi(0.42/(float(speeds.get("fatigue",1))+0.12))
	return minf(base*(1+0.1*(-h+f)),10)

static func dig_time(base: float, speeds: Dictionary) -> float:
	var fatigue: float = float(speeds.get("fatigue",1))
	if fatigue == 0: return maxf(300,base)
	var adjusted: float = base/(1+float(speeds.get("haste",0)))/fatigue
	return minf(300,adjusted) if base < 300 else adjusted

static func profile(id: int) -> Dictionary:
	return source.tools.get(str(id),source.tools["0"])

static func active(player: VoxeyPlayer) -> Dictionary:
	var wet: bool = Fluids.water(player.game.world.node_at(Vector3i(player.position.floor())))
	return factors(PotionEffects.level(player,"haste"),PotionEffects.level(player,"fatigue"),PotionEffects.level(player,"conduit_power"),wet)

static func refresh(player: VoxeyPlayer) -> void:
	synchronize_mode(player)
	if player.game.gamemode == "creative": return
	var slot: Dictionary = player.game.inventory.held()
	if not profile(int(slot.id)).tool: return
	var speeds: Dictionary = active(player)
	if not slot.has("data"): slot.data = {}
	if speeds.haste == 0 and speeds.fatigue == 1: slot.data.erase("item_speed")
	else: slot.data.item_speed = speeds.duplicate()
	if slot.data.is_empty(): slot.erase("data")
	player.set_meta("hand_speed",speeds)

static func reset(player: VoxeyPlayer, active_hand: bool = true) -> void:
	if player.game == null or player.game.inventory == null: return
	for slot in player.game.inventory.slots+player.armor_slots+[player.offhand_slot]:
		if slot.get("data") is Dictionary:
			slot.data.erase("item_speed")
			if slot.data.is_empty(): slot.erase("data")
	player.set_meta("hand_speed",active(player) if active_hand else {})
	player.set_meta("speed_mode",player.game.gamemode)

static func synchronize_mode(player: VoxeyPlayer) -> void:
	if str(player.get_meta("speed_mode","")) != player.game.gamemode: reset(player,false)

static func speeds(slot: Dictionary, player: VoxeyPlayer = null) -> Dictionary:
	if player != null: synchronize_mode(player)
	var id: int = int(slot.get("id",0))
	if id != 0 and source.tools.has(str(id)) and profile(id).own:
		return slot.get("data",{}).get("item_speed",{})
	return player.get_meta("hand_speed",{}) if player != null else {}

static func attack_interval(slot: Dictionary, player: VoxeyPlayer) -> float:
	var p: Dictionary = profile(int(slot.get("id",0)))
	var base: float = p.levels[0].full_punch_interval
	# The callback supplies this interval even when effects changed the mace's
	# displayed capabilities. Swords/tridents also lack the source tool=1 group.
	return interval(base,speeds(slot,player))

static func node_name(id: int) -> String:
	return MiningNodes.node_name(id)

static func parameters(name: String, id: int, efficiency: int = 0, unbreaking: int = 0, speed: Dictionary = {}, wear: int = 0) -> Dictionary:
	var result: Dictionary = {"diggable":false,"time":0.0,"wear":0}
	if not source.nodes.has(name): return result
	var node: Dictionary = source.nodes[name]
	if not node.diggable: return result
	var groups: Dictionary = node.groups if node.groups is Dictionary else {}
	var p: Dictionary = profile(id)
	var selected: Dictionary = p.get("enchanted_zero",p.levels[0]) if efficiency == 0 and unbreaking > 0 else p.levels[clampi(efficiency,0,5)]
	var caps: Dictionary = selected.groupcaps if selected.groupcaps is Dictionary else {}
	var immediate: int = int(groups.get("dig_immediate",0))
	if immediate >= 2: return {"diggable":true,"time":0.0 if immediate == 3 else 0.5,"wear":0}
	for group in caps:
		var level: int = int(groups.get(group,0))
		var cap: Dictionary = caps[group]
		if level <= 0 or not cap.times is Array or level > cap.times.size(): continue
		var difference: int = int(cap.maxlevel)-int(groups.get("level",0))
		if difference < 0: continue
		var time: float = f32(dig_time(float(cap.times[level-1]),speed))
		var uses: int = int(float(cap.get("exact_uses",cap.uses))*(unbreaking+1)) if unbreaking > 0 else int(cap.uses)
		if difference > 1: time /= difference
		if not result.diggable or time < float(result.time):
			result = {"diggable":true,"time":time,"wear":Durability.next_wear(wear,int(uses*pow(3,difference)))-wear if uses > 0 else 0}
	return result

static func mining(id: int, slot: Dictionary, player: VoxeyPlayer = null) -> Dictionary:
	var name: String = node_name(id)
	if not name.is_empty():
		var result: Dictionary = parameters(name,int(slot.id),Inventory.enchantment(slot,"Efficiency"),Inventory.enchantment(slot,"Unbreaking"),speeds(slot,player),Durability.normalized(slot))
		if result.diggable: return result
		var hand: Dictionary = parameters(name,0,0,0,player.get_meta("hand_speed",{}) if player != null else {})
		return hand
	# Unmapped original blocks keep their existing base timing until their own
	# source registration is mapped. Effects still use the source transformation.
	var time: float = Nodes.break_time(id,int(slot.id))
	if Nodes.tool_kind(int(slot.id)) == Nodes.preferred_tool(id): time /= 1+0.4*Inventory.enchantment(slot,"Efficiency")
	return {"diggable":is_finite(Nodes.hardness(id)),"time":dig_time(time,speeds(slot,player)),"wear":-1}

static func wear(inventory: Inventory, id: int) -> void:
	var slot: Dictionary = inventory.held()
	var result: Dictionary = mining(id,slot)
	if int(result.wear) < 0: inventory.damage_tool(); return
	if int(result.wear) > 0: Durability.set_normalized(slot,Durability.normalized(slot)+int(result.wear))
	inventory.changed.emit()

# mcl_tools.on_tool_place uses the unmodified diggroup lifetime, including
# for enchanted tools. This is separate from mining and normal item-use wear.
static func action_increment(id: int) -> int:
	var kind: int = Nodes.tool_kind(id)
	if kind < 0 or kind >= 5: return 0
	var prefix: String = ["pickaxey","axey","shovely","swordy","hoey"][kind]
	var caps: Dictionary = profile(id).levels[0].groupcaps
	# Swords also have bamboo/cobweb groups with a separate lifetime. The
	# callback asks for the primary diggroup, never those special targets.
	for key in [prefix+"_dig",prefix+"_dig_default"]:
		if caps.has(key):
			var uses: float = float(caps[key].get("exact_uses",caps[key].get("uses",0)))
			if uses > 0: return ceili(65535.0/uses)
	return 0

static func action_wear(inventory: Inventory) -> void:
	var slot: Dictionary = inventory.held(); var increment: int = action_increment(int(slot.id))
	if increment <= 0: inventory.damage_tool(); return
	Durability.set_normalized(slot,Durability.normalized(slot)+increment)
	inventory.changed.emit()

static func same_mining_item(left: Dictionary, right: Dictionary) -> bool:
	# A potion may expire while a host is acknowledging the dig. That changes
	# the cached capabilities, not the tool that must receive the wear.
	var a: Dictionary = left.duplicate(true); var b: Dictionary = right.duplicate(true)
	for slot in [a,b]:
		if slot.get("data") is Dictionary:
			slot.data.erase("item_speed")
			if slot.data.is_empty(): slot.erase("data")
	return a == b

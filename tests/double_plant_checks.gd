extends RefCounted

# Focused double-grass/double-fern checks. These use registered harvesting, real
# world edits, the game break path, dispenser dispatch, and lush-moss consumers.
const Y = 3180

static func plot(game: Node3D, base: Vector3i) -> void:
	for x in range(-2,3):
		for z in range(-2,3):
			for y in range(-1,5): game.world.set_node(base+Vector3i(x,y,z),Nodes.AIR)
			game.world.set_node(base+Vector3i(x,-1,z),Nodes.GRASS)

static func held(game: Node3D, id: int, data: Dictionary = {}) -> void:
	var slot: Dictionary = {"id":id,"count":1,"wear":0}
	if not data.is_empty(): slot.data = data
	game.inventory.restore([slot]); game.inventory.selected = 0

static func drops_of(game: Node3D, id: int) -> int:
	var count: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and drop.item_id == id and not drop.is_queued_for_deletion(): count += drop.amount
	return count

static func target(p: Vector3i, id: int) -> Dictionary:
	return {"pos":p,"id":id,"normal":Vector3i.UP,"distance":2.0,"point":Vector3(p)+Vector3(0.5,0.5,0.5)}

static func enchanted(id: int, name: String, level: int) -> Dictionary:
	return {"id":id,"count":1,"wear":0,"data":{"enchantments":{name:level}}}

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.state = "playing"; game.gamemode = "survival"; game.daylight = 0.0
	var world: VoxelWorld = game.world
	var base := Vector3i(8,Y,8)
	plot(game,base)

	# IDs extend the pair family without adding herbs to the original flower set.
	t.check(LargePlants.BOTTOMS == [11418,11420,11422,11424],"the original four-flower terrain and recipe selection stays unchanged")
	t.check(LargePlants.DOUBLE_GRASS == 11426 and LargePlants.DOUBLE_GRASS+1 == 11427 and LargePlants.DOUBLE_FERN == 11428 and LargePlants.DOUBLE_FERN+1 == 11429,"double grass and double fern keep their allocated bottom/top ids")
	for id in LargePlants.HERB_BOTTOMS:
		t.check(LargePlants.is_bottom(id) and LargePlants.is_top(id+1) and LargePlants.bottom(id+1) == id and LargePlants.top(id) == id+1,"herb bottom/top mapping is bidirectional")
		t.check(Nodes.exists(id) and Nodes.exists(id+1) and Nodes.placeable(id) and not Nodes.placeable(id+1),"only a herb bottom is an inventory item")
		t.check(LargePlants.dye_of(id) == 0 and Composters.chance(id) == 50 and Composters.chance(id+1) == 0,"herbs have no flower dye and only bottoms compost at fifty percent")
		t.check(LargePlants.DATA[id].source_node in ["mcl_flowers:double_grass","mcl_flowers:double_fern"],"the registered source name remains save-compatible")

	# Ordinary drops are the source one-in-eight wheat-seed table on either half.
	var rng := RandomNumberGenerator.new()
	for id in LargePlants.HERB_BOTTOMS:
		var empty: bool = false; var seeded: bool = false; var matching: bool = true
		for trial in 64:
			rng.seed = trial
			var lower: Array = LargePlants.harvest(id,{"id":0},EnchantRolls.new(1,rng))
			rng.seed = trial
			var upper: Array = LargePlants.harvest(id+1,{"id":0},EnchantRolls.new(1,rng))
			if lower != upper: matching = false
			if lower.is_empty(): empty = true
			elif lower == [[Nodes.SEEDS,1]]: seeded = true
		t.check(empty and seeded and matching,"ordinary herb breaks roll one seed in eight identically on either half")
		t.check(LargePlants.harvest(id,{"id":Nodes.SHEARS}) == [[LargePlants.small_form(id),2]] and LargePlants.harvest(id+1,{"id":Nodes.SHEARS}) == [[LargePlants.small_form(id),2]],"shears yield exactly two small items on either herb half")
		var silk_valid: bool = true; var silk_empty: bool = false; var silk_seed: bool = false
		for trial in 64:
			rng.seed = trial
			var drops: Array = LargePlants.harvest(id,enchanted(0,"Silk Touch",1),EnchantRolls.new(1,rng))
			if drops.is_empty(): silk_empty = true
			elif drops == [[Nodes.SEEDS,1]]: silk_seed = true
			else: silk_valid = false
		t.check(silk_valid and silk_empty and silk_seed,"Silk Touch has no plant override and leaves the ordinary seed table intact")
	t.check(LargePlants.harvest(LargePlants.PEONY+1,{"id":0}) == [[LargePlants.PEONY,1]],"existing large flowers still drop their own bottom item from the top")

	# Fortune retains the one-eighth success chance but overwrites a successful
	# roll with one seed times discrete_uniform(1, 1 + 2 * level).
	for level in range(1,4):
		var success: bool = false; var failure: bool = false; var valid: bool = true
		for trial in 128:
			rng.seed = trial
			var drops: Array = LargePlants.harvest(LargePlants.DOUBLE_GRASS,enchanted(0,"Fortune",level),EnchantRolls.new(1,rng))
			if drops.is_empty(): failure = true; continue
			success = true
			if drops.size() != 1 or drops[0][0] != Nodes.SEEDS or drops[0][1] < 1 or drops[0][1] > 1+level*2: valid = false
		t.check(success and failure and valid,"Fortune %d replaces rather than duplicates the seed roll and widens its count" % level)

	# Placement checks both buildable cells before the generic player path writes.
	world.set_node(base+Vector3i.LEFT,Nodes.TORCH)
	t.check(LargePlants.can_place(world,base),"artificial light eight and two buildable cells permit placement")
	held(game,LargePlants.DOUBLE_GRASS)
	t.check(LargePlants.place(game,base) and world.node_at(base) == LargePlants.DOUBLE_GRASS and world.node_at(base+Vector3i.UP) == LargePlants.DOUBLE_GRASS+1,"held double grass places a complete pair")
	plot(game,base); world.set_node(base+Vector3i.LEFT,Nodes.TORCH); world.set_node(base+Vector3i.UP,Nodes.STONE)
	t.check(not LargePlants.can_place(world,base) and not LargePlants.place(game,base) and world.node_at(base) == Nodes.AIR,"a solid upper cell rejects placement without half-forming")
	world.set_node(base,FoodFeatures.TALL_GRASS); world.set_node(base+Vector3i.UP,LargePlants.PEONY+1)
	t.check(not LargePlants.buildable_to(LargePlants.PEONY+1) and not LargePlants.can_place(world,base),"another large-plant half is not buildable_to merely because it is plantlike")
	plot(game,base); world.set_node(base+Vector3i.LEFT,Nodes.TORCH); world.set_node(base+Vector3i.DOWN,Nodes.STONE)
	t.check(not LargePlants.can_place(world,base),"the source soil_flower gate still applies")

	# Small-plant callbacks convert in place, and blocked conversion still consumes.
	plot(game,base)
	for pair in [[FoodFeatures.TALL_GRASS,LargePlants.DOUBLE_GRASS],[FlowersExtra.FERN,LargePlants.DOUBLE_FERN]]:
		world.set_node(base,pair[0]); world.set_node(base+Vector3i.UP,Nodes.AIR)
		var grown: Dictionary = LargePlants.bone_meal(world,base)
		t.check(grown.consume and grown.grew and world.node_at(base) == pair[1] and world.node_at(base+Vector3i.UP) == pair[1]+1,"bone meal converts the small plant into its matching two-high form")
		world.set_node(base,pair[0]); world.set_node(base+Vector3i.UP,Nodes.STONE)
		grown = LargePlants.bone_meal(world,base)
		t.check(grown.consume and not grown.grew and world.node_at(base) == pair[0],"a blocked small-plant callback returns nil: consume without growth")
		world.set_node(base+Vector3i.UP,Nodes.AIR)
	world.set_node(base,LargePlants.PEONY); world.set_node(base+Vector3i.UP,LargePlants.PEONY+1)
	var flower_callback: Dictionary = LargePlants.bone_meal(world,base)
	t.check(flower_callback.consume and flower_callback.get("duplicate",0) == LargePlants.PEONY,"the four existing flowers retain their one-item bone-meal callback")
	held(game,Nodes.BONE_MEAL)
	var flower_drops: int = drops_of(game,LargePlants.PEONY)
	game.player.target = target(base,LargePlants.PEONY); game.player.use()
	t.check(game.inventory.count_item(Nodes.BONE_MEAL) == 0 and drops_of(game,LargePlants.PEONY) == flower_drops+1,"the player dispatcher still duplicates an existing large flower once")
	plot(game,base); world.set_node(base,LargePlants.DOUBLE_GRASS); world.set_node(base+Vector3i.UP,LargePlants.DOUBLE_GRASS+1)
	held(game,Nodes.BONE_MEAL)
	var herb_drops: int = drops_of(game,LargePlants.DOUBLE_GRASS); var small_drops: int = drops_of(game,FoodFeatures.TALL_GRASS)
	game.player.target = target(base,LargePlants.DOUBLE_GRASS); game.player.use()
	t.check(game.inventory.count_item(Nodes.BONE_MEAL) == 1 and drops_of(game,LargePlants.DOUBLE_GRASS) == herb_drops and drops_of(game,FoodFeatures.TALL_GRASS) == small_drops,"double grass does not inherit the large-flower bone-meal duplicate callback")

	# Real game breaking uses shears once even when the clicked half is the top.
	for pair in [[LargePlants.DOUBLE_GRASS,FoodFeatures.TALL_GRASS],[LargePlants.DOUBLE_FERN,FlowersExtra.FERN]]:
		plot(game,base); world.set_node(base,pair[0]); world.set_node(base+Vector3i.UP,pair[0]+1)
		held(game,Nodes.SHEARS)
		var before: int = drops_of(game,pair[1])
		game.break_node(base+Vector3i.UP,pair[0]+1,Nodes.SHEARS)
		t.check(world.node_at(base) == Nodes.AIR and world.node_at(base+Vector3i.UP) == Nodes.AIR and drops_of(game,pair[1]) == before+2,"breaking the top with shears removes the pair and drops two small items once")

	# Live after_destruct and supported_node paths run through ordinary world edits.
	plot(game,base); world.set_node(base,LargePlants.PEONY); world.set_node(base+Vector3i.UP,LargePlants.PEONY+1)
	world.set_node(base+Vector3i.UP,Nodes.AIR)
	t.check(world.node_at(base) == Nodes.AIR,"replacing a top removes its matching bottom through changed/partner")
	plot(game,base); world.set_node(base,LargePlants.PEONY); world.set_node(base+Vector3i.UP,LargePlants.PEONY+1)
	flower_drops = drops_of(game,LargePlants.PEONY)
	world.set_node(base+Vector3i.DOWN,Nodes.AIR)
	t.check(world.node_at(base) == Nodes.AIR and world.node_at(base+Vector3i.UP) == Nodes.AIR and drops_of(game,LargePlants.PEONY) == flower_drops+1,"live support removal digs the pair with one ordinary drop")

	# Dispenser dispatch uses callback consumption, not only successful growth.
	plot(game,base); world.set_node(base,FoodFeatures.TALL_GRASS)
	var dispensed: Dictionary = Dispensers.dispense(game,base+Vector3i.LEFT,Vector3i.RIGHT,{"id":Nodes.BONE_MEAL,"count":1})
	t.check(dispensed.consume and world.node_at(base) == LargePlants.DOUBLE_GRASS and world.node_at(base+Vector3i.UP) == LargePlants.DOUBLE_GRASS+1,"a bone-meal dispenser grows short grass through the same callback")
	plot(game,base); world.set_node(base,FoodFeatures.TALL_GRASS); world.set_node(base+Vector3i.UP,Nodes.STONE)
	dispensed = Dispensers.dispense(game,base+Vector3i.LEFT,Vector3i.RIGHT,{"id":Nodes.BONE_MEAL,"count":1})
	t.check(dispensed.consume and world.node_at(base) == FoodFeatures.TALL_GRASS,"the dispenser also honors nil-callback consumption when conversion is blocked")
	plot(game,base); world.set_node(base,LargePlants.PEONY); world.set_node(base+Vector3i.UP,LargePlants.PEONY+1)
	flower_drops = drops_of(game,LargePlants.PEONY)
	dispensed = Dispensers.dispense(game,base+Vector3i.LEFT,Vector3i.RIGHT,{"id":Nodes.BONE_MEAL,"count":1})
	t.check(dispensed.consume and drops_of(game,LargePlants.PEONY) == flower_drops+1,"a dispenser preserves the existing large-flower duplication callback")
	plot(game,base); world.set_node(base,LargePlants.DOUBLE_FERN); world.set_node(base+Vector3i.UP,LargePlants.DOUBLE_FERN+1)
	herb_drops = drops_of(game,LargePlants.DOUBLE_FERN)
	dispensed = Dispensers.dispense(game,base+Vector3i.LEFT,Vector3i.RIGHT,{"id":Nodes.BONE_MEAL,"count":1})
	t.check(not dispensed.consume and drops_of(game,LargePlants.DOUBLE_FERN) == herb_drops,"a dispenser does not give double fern the large-flower callback")

	# The moss helper has the source's two-high attempt and short-grass fallback.
	plot(game,base)
	t.check(LargePlants.place_moss_vegetation(world,base,LargePlants.DOUBLE_GRASS) and world.node_at(base+Vector3i.UP) == LargePlants.DOUBLE_GRASS+1,"moss vegetation places double grass when its second cell is buildable")
	plot(game,base); world.set_node(base+Vector3i.UP,Nodes.STONE)
	t.check(LargePlants.place_moss_vegetation(world,base,LargePlants.DOUBLE_GRASS) and world.node_at(base) == FoodFeatures.TALL_GRASS and world.node_at(base+Vector3i.UP) == Nodes.STONE,"moss vegetation falls back to short grass without erasing the obstruction")

	# Exercise the actual lush-moss consumer in both directions with one fixed
	# random stream that chooses vegetation and the double-grass table row.
	var moss_seed: int = -1
	for trial in 1000:
		rng.seed = trial
		if rng.randf() < 0.6 and AzaleaTrees.moss_vegetation(rng) == LargePlants.DOUBLE_GRASS: moss_seed = trial; break
	t.check(moss_seed >= 0,"the lush moss vegetation table now exposes its double-grass row")
	plot(game,base); world.set_node(base,Nodes.DIRT); rng.seed = moss_seed
	t.check(AzaleaTrees.moss_cell(world,base,rng) and world.node_at(base+Vector3i.UP) == LargePlants.DOUBLE_GRASS and world.node_at(base+Vector3i.UP*2) == LargePlants.DOUBLE_GRASS+1,"lush moss grows a real two-cell double-grass plant")
	plot(game,base); world.set_node(base,Nodes.DIRT); world.set_node(base+Vector3i.UP*2,Nodes.STONE); rng.seed = moss_seed
	t.check(AzaleaTrees.moss_cell(world,base,rng) and world.node_at(base+Vector3i.UP) == FoodFeatures.TALL_GRASS and world.node_at(base+Vector3i.UP*2) == Nodes.STONE,"the live lush-moss consumer uses the source short-grass fallback")

	# Both procedural halves contain art; no nonexistent GIMP bloom is required.
	for id in LargePlants.HERB_BOTTOMS:
		var drawn: Array = [false,false]
		for half in 2:
			for y in 16:
				for x in 16:
					if LargePlants.pixel(id+half,x,y,Color.WHITE).a > 0.0: drawn[half] = true
		t.check(drawn[0] and drawn[1],"double herb %d has nonempty procedural bottom and top art" % id)

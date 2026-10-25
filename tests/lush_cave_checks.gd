extends RefCounted

# Survival regression for Mineclonia mcl_lush_caves. These checks deliberately use
# Player.use, Dispensers.dispense and VoxelWorld.set_node rather than treating the
# lifecycle helpers as a disconnected model.

static func held(game: Node3D, id: int, count: int = 1) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0,"data":{}}
	game.player.eating.clear(); game.player.use_cooldown = 0; game.player.use_latched = false

static func point(game: Node3D, p: Vector3i, normal: Vector3i = Vector3i.BACK) -> void:
	game.player.target = {"pos":p,"id":game.world.node_at(p),"normal":normal,"point":Vector3(p)+Vector3.ONE*0.5,"distance":2.0}

static func drops(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if drop is ItemDrop and not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func ensure(game: Node3D, p: Vector3i) -> bool:
	var world: VoxelWorld = game.world
	if world.loaded_at(Vector3(p)): return true
	world._apply_column(world.generator.generate_column(Vector2i(floori(p.x/16.0),floori(p.z/16.0)),world.edits))
	return world.loaded_at(Vector3(p))

static func clear(world: VoxelWorld) -> void:
	for y in range(60,73): world.set_node(Vector3i(4,y,4),Nodes.AIR)

static func tower(world: VoxelWorld) -> void:
	clear(world)
	world.set_node(Vector3i(4,69,4),Nodes.STONE)
	for y in [68,67,66]: world.set_node(Vector3i(4,y,4),LushCaves.CAVE_VINES)

static func growth_seed(lit: bool) -> int:
	var rng := RandomNumberGenerator.new()
	for value in range(1,10000):
		rng.seed = value
		if rng.randi_range(1,LushCaves.CHANCE) != 1: continue
		if (rng.randf() <= LushCaves.BERRY_CHANCE) == lit: return value
	return 1

static func berry_seed(lit: bool) -> int:
	var rng := RandomNumberGenerator.new()
	for value in range(1,1000):
		rng.seed = value
		if (rng.randf() <= LushCaves.BERRY_CHANCE) == lit: return value
	return 1

static func run(t: SceneTree, game: Node3D) -> void:
	game.pause(); game.set_process(false); game.world.set_process(false); game.world.active = false
	game.player.set_process(false); game.player.set_physics_process(false)
	game.gamemode = "survival"
	var world: VoxelWorld = game.world
	var at := Vector3i(4,64,4)
	t.check(ensure(game,at),"the lush-cave test column is loaded")

	# Registration preserves ids while carrying the source's actual acquisition,
	# nutrition, mining and compost rules.
	for id in LushCaves.BLOCKS:
		t.check(VillageContent.DATA.has(id),"lush cave block %d is registered" % id)
		t.check(Art.build_node_mesh(id).get_surface_count() > 0,"lush cave block %d renders geometry" % id)
	t.check(VillageContent.DATA.has(LushCaves.GLOW_BERRY),"the glow berry craftitem is registered")
	t.check(Nodes.drop(LushCaves.CAVE_VINES) == 0 and Nodes.drop(LushCaves.CAVE_VINES_LIT) == LushCaves.GLOW_BERRY,"unlit vines drop nothing and lit vines drop one berry item")
	t.check(not Nodes.placeable(LushCaves.CAVE_VINES) and not Nodes.placeable(LushCaves.CAVE_VINES_LIT),"neither internal vine node is directly placeable")
	t.check(Nodes.placeable(LushCaves.MOSS),"the ordinary moss block remains placeable")
	t.check(is_equal_approx(float(VillageContent.DATA[LushCaves.MOSS].hardness),0.1) and Nodes.preferred_tool(LushCaves.MOSS) == 4,"moss has source hardness 0.1 and hoe preference")
	t.check(Composters.chance(LushCaves.MOSS) == 65 and Composters.chance(LushCaves.GLOW_BERRY) == 50,"moss and glow berries use source compost percentages")
	t.check(Nodes.food(LushCaves.GLOW_BERRY) == 2 and is_equal_approx(Hunger.food_saturation(LushCaves.GLOW_BERRY),1.2),"glow berries restore two food and 1.2 saturation")
	var icon: Image = ItemArt.texture(LushCaves.GLOW_BERRY).get_image()
	var icon_pixels: int = 0
	for x in 16:
		for y in 16:
			if icon.get_pixel(x,y).a > 0: icon_pixels += 1
	t.check(icon_pixels > 12,"the glow berry craftitem has original visible inventory art")

	# The two forms remain transparent, climbable strands; only the lit form emits.
	t.check(Nodes.plant(LushCaves.CAVE_VINES) and not VillageContent.special(LushCaves.CAVE_VINES),"cave vines reach the plant mesher")
	t.check(not Nodes.solid(LushCaves.CAVE_VINES) and Nodes.transparent(LushCaves.CAVE_VINES),"cave vines neither block movement nor sight")
	t.check(Nodes.tile(LushCaves.CAVE_VINES,0) != 136,"cave vines have their own atlas tile")
	tower(world)
	for p in [Vector3i(4,68,4),Vector3i(4,67,4)]:
		t.check(LushCaves.climbable(world,p),"an unlit cave vine is climbable")
	world.set_node(Vector3i(4,68,4),LushCaves.CAVE_VINES_LIT)
	t.check(LushCaves.climbable(world,Vector3i(4,68,4)) and Pasture.emission(world,Vector3i(4,68,4)) == 14,"a lit vine climbs and emits source light 14")
	world.set_node(Vector3i(4,68,4),LushCaves.CAVE_VINES)
	t.check(Pasture.emission(world,Vector3i(4,68,4)) == 0,"an unlit vine emits nothing")

	# Bone meal lights the clicked node, not the lowest tip, and preserves age.
	LushCaves.set_age(world,Vector3i(4,68,4),9)
	held(game,Nodes.BONE_MEAL,2); point(game,Vector3i(4,68,4)); game.player.use()
	t.check(world.node_at(Vector3i(4,68,4)) == LushCaves.CAVE_VINES_LIT,"real bone-meal use ripens the clicked vine node")
	t.check(world.node_at(Vector3i(4,67,4)) == LushCaves.CAVE_VINES and world.node_at(Vector3i(4,66,4)) == LushCaves.CAVE_VINES,"bone meal does not redirect ripening to the tip or another segment")
	t.check(LushCaves.age(world,Vector3i(4,68,4)) == 9 and game.inventory.held().count == 1,"bone meal preserves saved age and consumes one item")

	# Lit right-click spawns exactly one item entity and reverts only that cell.
	held(game,Nodes.AIR); var before: int = drops(game,LushCaves.GLOW_BERRY)
	point(game,Vector3i(4,68,4)); game.player.use()
	t.check(drops(game,LushCaves.GLOW_BERRY) == before+1,"real lit-vine right-click spawns one glow berry")
	t.check(world.node_at(Vector3i(4,68,4)) == LushCaves.CAVE_VINES and LushCaves.age(world,Vector3i(4,68,4)) == 9,"harvest reverts the clicked node and keeps its age")
	point(game,Vector3i(4,68,4)); game.player.use()
	t.check(world.node_at(Vector3i(4,66,4)) == LushCaves.CAVE_VINES and drops(game,LushCaves.GLOW_BERRY) == before+1,"an unlit vine cannot be harvested twice")

	# Dispensers call the same clicked-node bone-meal callback.
	world.set_node(Vector3i(4,65,4),Nodes.STONE); world.set_node(at,LushCaves.CAVE_VINES)
	var outcome: Dictionary = Dispensers.dispense(game,Vector3i(4,63,4),Vector3i.UP,{"id":Nodes.BONE_MEAL,"count":2,"wear":0})
	t.check(outcome.get("applied",false) and outcome.get("consume",false) and world.node_at(at) == LushCaves.CAVE_VINES_LIT,"dispenser bone meal ripens its actual target and consumes")

	# Shears affect only the lowest unlit tip and use durability only on success.
	tower(world); held(game,Nodes.SHEARS); point(game,Vector3i(4,68,4)); game.player.use()
	t.check(LushCaves.age(world,Vector3i(4,68,4)) == 0 and game.inventory.held().wear == 0,"shears do not age or wear on a non-tip segment")
	point(game,Vector3i(4,66,4)); game.player.use()
	t.check(LushCaves.age(world,Vector3i(4,66,4)) == 25 and game.inventory.held().wear == 1,"shears set the lowest unlit tip to age 25 and wear once")
	var stopped_rng := RandomNumberGenerator.new(); stopped_rng.seed = 1
	t.check(not LushCaves.grow_tip(world,Vector3i(4,66,4),stopped_rng),"an age-25 tip cannot grow")

	# Berry planting is an underside action and takes precedence over eating.
	clear(world); world.set_node(Vector3i(4,69,4),Nodes.STONE); world.set_node(Vector3i(4,68,4),Nodes.STONE)
	LushCaves.runtime(world).rng.seed = berry_seed(false)
	held(game,LushCaves.GLOW_BERRY,2); game.player.hunger = 10; point(game,Vector3i(4,68,4),Vector3i.DOWN); game.player.use()
	t.check(world.node_at(Vector3i(4,68,4)) == Nodes.STONE and world.node_at(Vector3i(4,67,4)) == LushCaves.CAVE_VINES,"source core.place_node(under) leaves solid support unchanged and creates the vine below")
	t.check(game.inventory.held().count == 1 and game.player.eating.is_empty() and game.player.hunger == 10,"successful berry planting consumes one berry without starting eating")
	world.set_node(Vector3i(4,68,4),LushCaves.CAVE_VINES); LushCaves.set_age(world,Vector3i(4,68,4),7); world.set_node(Vector3i(4,67,4),Nodes.AIR)
	LushCaves.runtime(world).rng.seed = berry_seed(true)
	held(game,LushCaves.GLOW_BERRY,2); point(game,Vector3i(4,68,4),Vector3i.DOWN); game.player.use()
	t.check(world.node_at(Vector3i(4,67,4)) == LushCaves.CAVE_VINES_LIT and LushCaves.age(world,Vector3i(4,67,4)) == 8,"extending an unlit vine increments age and applies the 11% lit-new-tip roll")
	t.check(LushCaves.age(world,Vector3i(4,68,4)) == 7 and game.inventory.held().count == 1,"planting ages only the new tip and consumes one berry")
	world.set_node(Vector3i(4,67,4),Nodes.STONE); held(game,LushCaves.GLOW_BERRY,2); point(game,Vector3i(4,68,4),Vector3i.DOWN); game.player.use()
	t.check(world.node_at(Vector3i(4,67,4)) == Nodes.STONE and game.inventory.held().count == 2 and game.player.eating.is_empty(),"occupied space rejects planting without consumption or eating")
	point(game,Vector3i(4,68,4),Vector3i.UP); game.player.use()
	t.check(game.inventory.held().count == 2 and game.player.eating.is_empty(),"a non-underside berry click cannot fall through to eating")

	# One loaded ABM cycle applies interval, chance, downward growth, age and lit roll.
	clear(world); world.set_node(Vector3i(4,69,4),Nodes.STONE); world.set_node(Vector3i(4,68,4),LushCaves.CAVE_VINES)
	LushCaves.reset(world); LushCaves.registered(world,Vector3i(4,68,4),LushCaves.CAVE_VINES)
	LushCaves.set_age(world,Vector3i(4,68,4),4); world.adventure_state[LushCaves.ELAPSED_KEY] = 0.0
	game.state = "playing"
	var growth_rng := RandomNumberGenerator.new(); growth_rng.seed = growth_seed(true)
	LushCaves.update(world,179.9,growth_rng)
	t.check(world.node_at(Vector3i(4,67,4)) == Nodes.AIR and is_equal_approx(float(world.adventure_state[LushCaves.ELAPSED_KEY]),179.9),"passive growth waits for the source 180-second interval")
	LushCaves.update(world,0.1,growth_rng)
	t.check(world.node_at(Vector3i(4,67,4)) == LushCaves.CAVE_VINES_LIT and LushCaves.age(world,Vector3i(4,67,4)) == 5,"a successful one-in-five cycle grows a possibly lit new tip at age + 1")
	t.check(LushCaves.age(world,Vector3i(4,68,4)) == 4,"passive growth does not age the old tip")
	t.check(not LushCaves.grow_tip(world,Vector3i(4,68,4),growth_rng),"only the lowest tip can grow downward")
	world.set_node(Vector3i(4,66,4),Nodes.STONE); LushCaves.set_age(world,Vector3i(4,67,4),3)
	t.check(not LushCaves.grow_tip(world,Vector3i(4,67,4),growth_rng) and LushCaves.age(world,Vector3i(4,67,4)) == 3,"occupied space prevents passive growth without changing age")

	# Unload drops only the runtime index; persistent nodes and ages reload with it.
	var column := Vector2i(floori(4.0/16.0),floori(4.0/16.0))
	world._unload(column)
	t.check(not LushCaves.tracks(world,Vector3i(4,68,4)),"unloading a column removes its vine runtime registrations")
	LushCaves.update(world,180,growth_rng)
	t.check(not world.loaded_at(Vector3i(4,68,4)) and LushCaves.runtime(world).jobs.is_empty(),"an unloaded column cannot queue growth work")
	t.check(ensure(game,Vector3i(4,68,4)) and LushCaves.tracks(world,Vector3i(4,68,4)),"reloading a saved column re-registers its vines")
	t.check(LushCaves.age(world,Vector3i(4,68,4)) == 4,"column unload/reload preserves vine age")

	# Support loss uses the real world change path and each form's source drop.
	clear(world); world.set_node(Vector3i(4,69,4),Nodes.STONE); world.set_node(Vector3i(4,68,4),LushCaves.CAVE_VINES_LIT)
	world.set_node(Vector3i(4,69,4),Nodes.WATER)
	t.check(world.node_at(Vector3i(4,68,4)) == LushCaves.CAVE_VINES_LIT,"mcl_attached keeps a vine below a non-solid non-air node")
	before = drops(game,LushCaves.GLOW_BERRY); world.set_node(Vector3i(4,69,4),Nodes.AIR)
	t.check(world.node_at(Vector3i(4,68,4)) == Nodes.AIR and drops(game,LushCaves.GLOW_BERRY) == before+1,"removing support removes a lit vine and drops its berry")
	world.set_node(Vector3i(4,69,4),Nodes.STONE); world.set_node(Vector3i(4,68,4),LushCaves.CAVE_VINES)
	before = drops(game,LushCaves.GLOW_BERRY); world.set_node(Vector3i(4,69,4),Nodes.AIR)
	t.check(world.node_at(Vector3i(4,68,4)) == Nodes.AIR and drops(game,LushCaves.GLOW_BERRY) == before,"removing an unlit vine's support drops nothing")

	# Save/load exercises the actual persisted block_states and fractional ABM clock.
	world.set_node(Vector3i(4,69,4),Nodes.STONE); world.set_node(Vector3i(4,68,4),LushCaves.CAVE_VINES_LIT)
	LushCaves.set_age(world,Vector3i(4,68,4),17); world.adventure_state[LushCaves.ELAPSED_KEY] = 42.5
	t.check(game.save_game("user://lush-cave-check.json"),"the vine persistence fixture saves")
	var saved: Dictionary = game.read_save("user://lush-cave-check.json")
	game.set_process(true); game.load_world_data(saved); world = game.world
	while game.state == "loading": await t.process_frame
	game.pause(); game.set_process(false); world.set_process(false); world.active = false; world = game.world
	t.check(ensure(game,Vector3i(4,68,4)),"the saved vine column reloads")
	t.check(LushCaves.age(world,Vector3i(4,68,4)) == 17 and world.node_at(Vector3i(4,68,4)) == LushCaves.CAVE_VINES_LIT,"save/load restores node form and saved age")
	var restored_elapsed: float = float(world.adventure_state.get(LushCaves.ELAPSED_KEY,0.0))
	t.check(restored_elapsed >= 42.5 and restored_elapsed < 42.6 and LushCaves.tracks(world,Vector3i(4,68,4)),"save/load restores and resumes passive time and loaded-column tracking; elapsed="+str(restored_elapsed)+" tracks="+str(LushCaves.tracks(world,Vector3i(4,68,4))))
	LushCaves.reset(world)
	t.check(not world.has_meta("lush_cave_vines"),"world reset discards only transient vine runtime state")

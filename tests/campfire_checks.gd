extends RefCounted

static func held(game: Node3D, id: int, count: int = 1, data: Dictionary = {}) -> void:
	game.inventory.restore([]); game.inventory.selected = 0
	game.inventory.slots[0] = {"id":id,"count":count,"wear":0}
	if not data.is_empty(): game.inventory.slots[0].data = data.duplicate(true)

static func drop_count(game: Node3D, id: int) -> int:
	var total: int = 0
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == id: total += drop.amount
	return total

static func clear_drops(game: Node3D) -> void:
	for drop in game.drops.get_children(): drop.queue_free()

static func run(t: SceneTree, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var old_position: Vector3 = game.player.position
	var old_mode: String = game.gamemode
	var old_health: float = game.player.health
	var old_armor: Array = game.player.armor_slots.duplicate(true)
	var old_effects: Dictionary = game.survival.effect_snapshot()
	var old_state: String = game.state
	var old_target: Dictionary = game.player.target
	var old_touch: bool = game.touch
	var temporary_controls: bool = not is_instance_valid(game.controls)
	if temporary_controls:
		game.controls = TouchControls.new(); game.controls.game = game; game.add_child(game.controls)
	var old_sneak: bool = game.controls.sneak_held
	game.touch = true
	var p := Vector3i(8,170,8)
	var target: Dictionary = {"pos":p,"id":Campfires.LIT,"normal":Vector3i.UP,"distance":4.0}
	game.gamemode = "survival"; game.player.position = Vector3(6,175,6)
	for x in range(5,13):
		for z in range(5,13):
			for y in range(169,175): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	world.set_node(p+Vector3i.DOWN,Nodes.STONE)
	world.set_node(p,Campfires.LIT)
	var state: Dictionary = Campfires.station(world,p)
	t.check(state.kind == "campfire" and state.slots.size() == 4 and state.cook == [0.0,0.0,0.0,0.0],"placing a campfire creates four independent food positions")
	t.check(Campfires.cookable(VillageContent.RAW_COD) and Campfires.cookable(VillageContent.KELP) and Campfires.cookable(VillageContent.POTATO) and not Campfires.cookable(Nodes.IRON_ORE) and not Campfires.cookable(Nodes.LOG) and not Campfires.cookable(VillageContent.PUFFERFISH),"campfire eligibility follows source food groups instead of arbitrary furnace inputs")
	held(game,VillageContent.RAW_BEEF,3,{"custom_name":"Packed lunch"})
	game.player.target = target; game.state = "playing"
	var animal: Creature = game.spawn_creature("cow",Vector3.ZERO)
	animal.position = game.player.camera.global_position-game.player.camera.global_basis.z*2-Vector3.UP*animal.height*0.55
	t.check(game.target_mob() == animal and not Campfires.use(game,target) and game.inventory.held().count == 3,"an animal in front of a campfire retains interaction priority")
	animal.queue_free()
	game.controls.sneak_held = true
	t.check(not Campfires.use(game,target) and game.inventory.held().count == 3,"touch sneak bypasses campfire interactions without consuming food")
	game.controls.sneak_held = false
	game.player.use()
	t.check(state.slots[0].id == VillageContent.RAW_BEEF and state.slots[0].count == 1 and game.inventory.held().count == 2 and game.player.eating.is_empty() and game.state == "playing","right-click food enters a cooking spot before eating and opens no furnace UI")
	Campfires.update(world,10)
	held(game,VillageContent.POTATO,4)
	for index in 3: Campfires.use(game,target)
	t.check(state.slots[1].id == VillageContent.POTATO and state.slots[3].id == VillageContent.POTATO and game.inventory.held().count == 1 and state.cook[0] == 10 and state.cook[1] == 0,"later foods keep their own independent cooking clocks")
	Campfires.use(game,target)
	t.check(game.inventory.held().count == 1,"a full campfire preserves additional raw food")
	clear_drops(game)
	Campfires.update(world,20)
	t.check(drop_count(game,VillageContent.COOKED_BEEF) == 0,"source cooking does not finish at the strict 30-second boundary")
	Campfires.update(world,0.01)
	t.check(drop_count(game,VillageContent.COOKED_BEEF) == 1 and state.slots[0].id == 0 and state.slots[1].id == VillageContent.POTATO,"a completed food ejects once while later foods keep cooking")
	Campfires.update(world,10)
	t.check(drop_count(game,VillageContent.BAKED_POTATO) == 3 and state.slots.all(func(slot): return slot.id == 0),"all three later food slots eject their own cooked result")
	Campfires.update(world,60)
	t.check(drop_count(game,VillageContent.COOKED_BEEF) == 1 and drop_count(game,VillageContent.BAKED_POTATO) == 3,"empty cooking spots cannot duplicate completed food")
	held(game,Nodes.IRON_ORE)
	t.check(not Campfires.use(game,target) and state.slots.all(func(slot): return slot.id == 0) and game.inventory.held().id == Nodes.IRON_ORE,"uncookable inputs are not consumed or converted")
	t.check(world.circuits.container(p).is_empty() and not world.circuits.movable(p),"campfires expose no furnace/hopper inventory and cannot be moved by pistons")
	t.check(world.intersects(Vector3(p)+Vector3(0.5,0.3,0.5)) and not world.intersects(Vector3(p)+Vector3(0.5,0.451,0.5)),"campfire collision uses the source's 0.45-block height")
	var hit: Dictionary = world.raycast(Vector3(p)+Vector3(0.5,2,0.5),Vector3.DOWN,3)
	t.check(not hit.is_empty() and hit.id == Campfires.LIT and is_equal_approx(hit.point.y,p.y+0.45),"campfire targeting follows the low collision shape")
	clear_drops(game); held(game,VillageContent.RAW_CHICKEN)
	Campfires.use(game,target); Campfires.update(world,8)
	held(game,Nodes.TOOLS+2)
	t.check(Campfires.use(game,target) and world.node_at(p) == Campfires.UNLIT and game.inventory.held().wear == 1 and state.slots[0].id == VillageContent.RAW_CHICKEN,"a shovel smothers the fire with one tool use and retains cooking food")
	var smothered_display: Node3D = game.survival.displays[VoxelWorld.station_key(p)]
	t.check(smothered_display.get_children().all(func(child): return not child is OmniLight3D),"smothering removes the campfire's display light immediately")
	Campfires.update(world,23)
	t.check(drop_count(game,VillageContent.COOKED_CHICKEN) == 1,"existing food keeps its independent source timer after smothering")
	held(game,VillageContent.RAW_COD); target.id = Campfires.UNLIT
	t.check(not Campfires.use(game,target) and game.inventory.held().id == VillageContent.RAW_COD,"unlit campfires do not accept new food")
	held(game,Nodes.FLINT_AND_STEEL)
	t.check(Campfires.use(game,target) and world.node_at(p) == Campfires.LIT and game.inventory.held().wear == 1,"flint and steel reignites a smothered fire with one use")
	Campfires.smother(world,p); held(game,PiglinBarter.FIRE_CHARGE,2)
	t.check(Campfires.use(game,target) and world.node_at(p) == Campfires.LIT and game.inventory.held().count == 1,"a fire charge reignites the fire and consumes one charge")
	game.gamemode = "creative"; target.id = Campfires.LIT; held(game,VillageContent.RAW_COD)
	Campfires.use(game,target)
	t.check(game.inventory.held().count == 1 and state.slots[0].id == VillageContent.RAW_COD,"creative cooking preserves the held food")
	held(game,Nodes.TOOLS+2); Campfires.use(game,target)
	t.check(game.inventory.held().wear == 0 and world.node_at(p) == Campfires.UNLIT,"creative shovel smothering does not wear the tool")
	game.gamemode = "survival"; world.set_node(p,Nodes.AIR)
	clear_drops(game); world.set_node(p,Campfires.SOUL_LIT); target.id = Campfires.SOUL_LIT
	t.check(Campfires.damage(Campfires.LIT) == 2 and Campfires.damage(Campfires.SOUL_LIT) == 4 and Campfires.damage(Campfires.SOUL_UNLIT) == 0,"ordinary and soul campfires retain source contact damage rates")
	game.player.position = Vector3(p)+Vector3(0.5,0.451,0.5)
	game.player.health = 20; game.player.damage_cooldown = 0; PotionEffects.clear(game.player)
	for index in 4: game.player.armor_slots[index] = Campfires.empty()
	Campfires.contact(world,p,Campfires.SOUL_LIT)
	t.check(game.player.health == 16,"standing on a soul campfire deals four fire damage")
	game.player.damage_cooldown = 0; PotionEffects.apply(game.player,"fire_resistance",30)
	Campfires.contact(world,p,Campfires.SOUL_LIT)
	t.check(game.player.health == 16,"fire resistance protects against campfire contact")
	PotionEffects.clear(game.player); game.player.position += Vector3.UP; game.player.damage_cooldown = 0
	Campfires.contact(world,p,Campfires.SOUL_LIT)
	t.check(game.player.health == 16,"a player above the flame's contact box takes no damage")
	game.player.position = Vector3(6,175,6)
	Campfires.smother(world,p)
	t.check(world.node_at(p) == Campfires.SOUL_UNLIT and Campfires.ignite(world,p) and world.node_at(p) == Campfires.SOUL_LIT,"smothering and reigniting preserve the soul-fire family")
	for offset in [Vector3i.ZERO,Vector3i.RIGHT,Vector3i.LEFT,Vector3i.BACK,Vector3i.FORWARD,Vector3i(1,0,1)]: world.set_node(p+offset,Campfires.LIT)
	t.check(Campfires.water_splash(world,Vector3(p)+Vector3(0.5,0.7,0.5)) == 5 and world.node_at(p+Vector3i(1,0,1)) == Campfires.LIT,"splash water smothers its center and four horizontal neighbors, not diagonals")
	t.check(Campfires.water_splash(world,Vector3(p)+Vector3(0.5,0.7,0.5),1) == 1,"lingering water also reaches campfires within its horizontal area")
	world.set_node(p,Campfires.LIT)
	t.check(Campfires.smoke_lifetime(world,p) == 7.25,"ordinary smoke uses the source's 7.25-second maximum lifetime")
	world.set_node(p+Vector3i.DOWN,Nodes.HAY_BALE)
	t.check(Campfires.smoke_lifetime(world,p) == 11.5,"hay beneath a signal fire extends smoke to 11.5 seconds")
	var ordinary: Node3D = Campfires.display_model(game,p,Campfires.station(world,p))
	world.set_node(p,Campfires.SOUL_LIT)
	var soul: Node3D = Campfires.display_model(game,p,Campfires.station(world,p))
	var normal_light: OmniLight3D = ordinary.get_child(ordinary.get_child_count()-1)
	var soul_light: OmniLight3D = soul.get_child(soul.get_child_count()-1)
	t.check(ordinary.position == Vector3(p) and normal_light.light_energy > soul_light.light_energy and normal_light.omni_range > soul_light.omni_range,"normal and soul campfires display lights at the block with distinct source brightness")
	ordinary.free(); soul.free()
	clear_drops(game); world.set_node(p,Campfires.LIT)
	world.stations[VoxelWorld.station_key(p)] = {"kind":"furnace","device":Campfires.LIT,"slots":[{"id":VillageContent.RAW_BEEF,"count":12,"wear":3,"data":{"custom_name":"Old lunch"}},{"id":Nodes.COAL,"count":6,"wear":0},{"id":VillageContent.COOKED_BEEF,"count":9,"wear":0}],"burn":1000000.0,"progress":7.5}
	state = Campfires.station(world,p)
	t.check(state.kind == "campfire" and state.slots.size() == 4 and state.returns.size() == 3,"legacy campfire furnace inventory migrates into a persisted item-return queue")
	state = JSON.parse_string(JSON.stringify(state)); world.stations[VoxelWorld.station_key(p)] = state
	Campfires.update(world,0.1); Campfires.update(world,0.1)
	t.check(drop_count(game,VillageContent.RAW_BEEF) == 12 and drop_count(game,Nodes.COAL) == 6 and drop_count(game,VillageContent.COOKED_BEEF) == 9 and state.returns.is_empty(),"legacy input, fuel and output stacks survive serialization and return exactly once")
	var named_return: bool = false
	for drop in game.drops.get_children():
		if not drop.is_queued_for_deletion() and drop.item_id == VillageContent.RAW_BEEF and drop.wear == 3 and drop.data.get("custom_name","") == "Old lunch": named_return = true
	t.check(named_return,"legacy returned food retains its name, wear and metadata")
	clear_drops(game); held(game,VillageContent.RAW_RABBIT); target.id = Campfires.LIT
	Campfires.use(game,target); Campfires.update(world,7)
	state = JSON.parse_string(JSON.stringify(Campfires.station(world,p))); world.stations[VoxelWorld.station_key(p)] = state
	Campfires.station(world,p)
	t.check(typeof(state.slots[0].id) == TYPE_INT and typeof(state.slots[0].count) == TYPE_INT and typeof(state.slots[0].wear) == TYPE_INT and typeof(state.cook[0]) == TYPE_FLOAT,"loading campfire state normalizes JSON numbers before item lookups")
	var column := Vector2i(floori(p.x/16.0),floori(p.z/16.0)); var column_state: Variant = world.columns[column]
	world.columns.erase(column); Campfires.update(world,100)
	t.check(state.cook[0] == 7 and state.slots[0].id == VillageContent.RAW_RABBIT,"saved cooking progress remains paused while its column is unloaded")
	world.columns[column] = column_state; Campfires.update(world,24)
	t.check(drop_count(game,VillageContent.COOKED_RABBIT) == 1,"loaded cooking resumes its persisted independent timer")
	for id in [Campfires.LIT,Campfires.UNLIT,Campfires.SOUL_LIT,Campfires.SOUL_UNLIT]:
		clear_drops(game); world.set_node(p,id); held(game,Nodes.TOOLS+1)
		var raw: Dictionary = {"id":VillageContent.RAW_COD,"count":1,"wear":0}
		Campfires.add(Campfires.station(world,p),raw)
		Campfires.break_node(game,p,id,Nodes.TOOLS+1)
		t.check(world.node_at(p) == Nodes.AIR and drop_count(game,VillageContent.RAW_COD) == 1 and drop_count(game,Campfires.SOUL_SOIL if Campfires.soul(id) else Nodes.CHARCOAL) == (1 if Campfires.soul(id) else 2),"breaking campfire state %d returns raw food and its source material drop"%id)
	clear_drops(game); world.set_node(p,Campfires.SOUL_UNLIT)
	held(game,Nodes.TOOLS+16,1,{"enchantments":{"Silk Touch":1}})
	Campfires.break_node(game,p,Campfires.SOUL_UNLIT,Nodes.TOOLS+16)
	t.check(drop_count(game,Campfires.SOUL_LIT) == 1 and drop_count(game,Campfires.SOUL_SOIL) == 0,"Silk Touch preserves a soul campfire as its usable lit inventory item")
	clear_drops(game); world.set_node(p,Campfires.LIT)
	var raw: Dictionary = {"id":VillageContent.RAW_BEEF,"count":1,"wear":0}
	Campfires.add(Campfires.station(world,p),raw)
	Campfires.break_node(game,p,Campfires.LIT,0,true)
	t.check(drop_count(game,VillageContent.RAW_BEEF) == 1 and drop_count(game,Nodes.CHARCOAL) == 0,"explosions recover cooking food without inventing a source node drop")
	clear_drops(game); game.gamemode = "creative"; held(game,0,0); world.set_node(p,Campfires.UNLIT)
	Campfires.break_node(game,p,Campfires.UNLIT)
	world.set_node(p,Campfires.LIT); Campfires.break_node(game,p,Campfires.LIT)
	t.check(game.inventory.count_item(Campfires.LIT) == 1 and drop_count(game,Nodes.CHARCOAL) == 0,"creative breaking supplies a missing campfire once without material drops")
	game.gamemode = "survival"
	var inv := Inventory.new(); var coal: bool = false; var charcoal: bool = false; var sand: bool = false; var soil: bool = false
	for recipe in inv.recipes:
		if recipe.id == Campfires.LIT:
			coal = coal or recipe.ingredients.get(Nodes.COAL,0) == 1
			charcoal = charcoal or recipe.ingredients.get(Nodes.CHARCOAL,0) == 1
		if recipe.id == Campfires.SOUL_LIT:
			sand = sand or recipe.ingredients.get(Nodes.SOUL_SAND,0) == 1
			soil = soil or recipe.ingredients.get(Campfires.SOUL_SOIL,0) == 1
	t.check(coal and charcoal and sand and soil,"survival recipes accept coal/charcoal and soul sand/soil with logs and sticks")
	for fuel in [Nodes.CHARCOAL,Campfires.SOUL_SOIL]:
		var pattern: Array = [0,Nodes.STICK,0,Nodes.STICK,fuel,Nodes.STICK,Nodes.LOG,Nodes.CRIMSON_STEM,Nodes.WARPED_STEM]
		for index in 9: inv.grid[index] = {"id":pattern[index],"count":1 if pattern[index] != 0 else 0,"wear":0}
		var mixed: Dictionary = inv.take_grid_result("table")
		t.check(mixed.get("id",0) == (Campfires.LIT if fuel == Nodes.CHARCOAL else Campfires.SOUL_LIT) and inv.grid.all(func(slot): return slot.id == 0),"campfire crafting consumes mixed ordinary and Nether logs with fuel %d"%fuel)
	for offset in [Vector3i.ZERO,Vector3i.RIGHT,Vector3i.LEFT,Vector3i.BACK,Vector3i.FORWARD,Vector3i(1,0,1)]: world.set_node(p+offset,Nodes.AIR)
	for species in 6:
		for fuel in [Nodes.COAL,Campfires.SOUL_SOIL]:
			var logs: Array = [WoodTypes.log_id(species),WoodTypes.base(species)+4,WoodTypes.base(species)+6]
			var pattern: Array = [0,Nodes.STICK,0,Nodes.STICK,fuel,Nodes.STICK,logs[0],logs[1],logs[2]]
			for index in 9: inv.grid[index] = {"id":pattern[index],"count":1 if pattern[index] else 0,"wear":0}
			var result: Dictionary = inv.take_grid_result("table")
			t.check(result.get("id",0) == (Campfires.LIT if fuel == Nodes.COAL else Campfires.SOUL_LIT) and inv.grid.all(func(slot): return slot.id == 0),"campfire tree group consumes logs, stripped logs and stripped bark for species %d fuel %d"%[species,fuel])
	for wrong in [WoodTypes.PLANKS[1],WoodTypes.LEAVES[1],WoodTypes.SAPLINGS[1]]:
		var pattern: Array = [0,Nodes.STICK,0,Nodes.STICK,Nodes.COAL,Nodes.STICK,wrong,wrong,wrong]
		for index in 9: inv.grid[index] = {"id":pattern[index],"count":1 if pattern[index] else 0,"wear":0}
		t.check(Campfires.special_recipe(inv.grid).is_empty(),"campfire tree group rejects non-log wood item "+str(wrong))
	game.player.position = old_position; game.player.health = old_health; game.player.damage_cooldown = 0
	game.player.armor_slots = old_armor
	game.gamemode = old_mode; game.state = old_state; game.player.target = old_target
	game.controls.sneak_held = old_sneak
	if temporary_controls: game.controls.queue_free(); game.controls = null
	game.touch = old_touch
	game.survival.restore_effects(old_effects)

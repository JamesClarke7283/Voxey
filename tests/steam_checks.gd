extends RefCounted

static func stack(id: int, count: int = 1) -> Dictionary: return {"id":id,"count":count,"wear":0}

static func run(t: SceneTree, game: Node3D) -> void:
	var world: VoxelWorld = game.world
	var p := Vector3i(4,804,4)
	game.player.position = Vector3(15,804,15)
	for x in range(-1,30):
		for z in range(-3,15):
			for y in range(801,810): world.set_node(Vector3i(x,y,z),Nodes.AIR)
	for id in SteamMachines.DATA.keys()+AntiqueArms.DATA.keys():
		t.check(Nodes.exists(id) and Nodes.title(id) == (SteamMachines.DATA if SteamMachines.DATA.has(id) else AntiqueArms.DATA)[id].name,"registered item: "+Nodes.title(id))
	var inv := Inventory.new()
	for id in SteamMachines.BLOCKS+[AntiqueArms.MUSKET,AntiqueArms.PISTOL,AntiqueArms.BLUNDERBUSS,AntiqueArms.BAYONET,AntiqueArms.SHOT]:
		t.check(inv.recipe_index(id) >= 0,"crafting recipe: "+Nodes.title(id))
	inv.add_item(Nodes.IRON,6)
	t.check(inv.craft(inv.recipe_index(SteamMachines.PIPE),"table") and inv.count_item(SteamMachines.PIPE) == 8,"six iron ingots craft eight pipes")
	for pair in [[Nodes.IRON_ORE,Nodes.DEEP_IRON_ORE],[Nodes.GOLD_ORE,Nodes.DEEP_GOLD_ORE],[Nodes.COPPER_ORE,Nodes.DEEP_COPPER_ORE],[Nodes.DIAMOND_ORE,Nodes.DEEP_DIAMOND_ORE],[VillageContent.EMERALD_ORE,VillageContent.DEEP_EMERALD_ORE]]:
		t.check(SteamMachines.grind(pair[0]) == SteamMachines.grind(pair[1]),"deep ore grinding: "+Nodes.title(pair[0]))
	t.check(SteamMachines.grind(Nodes.IRON).is_empty() and SteamMachines.grind(SteamMachines.IRON_POWDER).is_empty(),"ingots and powder cannot be ground repeatedly")
	for id in range(SteamMachines.IRON_POWDER,SteamMachines.EMERALD_POWDER+1):
		t.check(Nodes.smelt_result(id) != 0,"powder smelts into resource: "+Nodes.title(id))
	world.set_node(p,SteamMachines.GENERATOR)
	world.set_node(p+Vector3i.RIGHT,SteamMachines.BELLOWS)
	world.circuits.configure(p+Vector3i.RIGHT,Vector3i.RIGHT)
	world.set_node(p+Vector3i.RIGHT*2,SteamMachines.PIPE)
	world.set_node(p+Vector3i.RIGHT*3,SteamMachines.GRINDER)
	var boiler: Dictionary = SteamMachines.station(world,p)
	var grinder: Dictionary = SteamMachines.station(world,p+Vector3i.RIGHT*3)
	boiler.slots[0] = stack(Nodes.COAL,2); grinder.slots[0] = stack(RawOres.RAW_IRON,2)
	for i in 50: world.circuits.update(0.1)
	t.check(grinder.slots[2].count == 0 and boiler.steam > 0,"coal makes steam but idle bellows do not supply grinder")
	t.check(boiler.slots[0].count == 1,"generator consumes one coal for its burn period")
	world.set_node(p+Vector3i.RIGHT+Vector3i.BACK,Nodes.REDSTONE_BLOCK)
	for i in 40: world.circuits.update(0.1)
	t.check(grinder.slots[2].id == SteamMachines.IRON_POWDER and grinder.slots[2].count == 4 and grinder.slots[0].count == 1,"powered bellows feed grinder and produce exactly four powders per raw ore")
	var burned: float = grinder.progress
	world.set_node(p+Vector3i.RIGHT*2,Nodes.AIR)
	for i in 20: world.circuits.update(0.1)
	t.check(is_equal_approx(grinder.progress,burned),"breaking the pipe stops work immediately")
	world.set_node(p+Vector3i.RIGHT*2,SteamMachines.PIPE)
	world.set_node(p+Vector3i.RIGHT*2+Vector3i.BACK,SteamMachines.FURNACE)
	var furnace: Dictionary = SteamMachines.station(world,p+Vector3i.RIGHT*2+Vector3i.BACK)
	furnace.slots[0] = stack(SteamMachines.IRON_POWDER,4)
	for i in 160: world.circuits.update(0.1)
	t.check(furnace.slots[2].id == Nodes.IRON and furnace.slots[2].count == 4 and furnace.slots[1].count == 0,"steam furnace smelts four powders into four ingots with no local fuel")
	boiler.steam = 5.0
	t.check(not SteamMachines.draw_steam(world,[p],6) and boiler.steam == 5,"insufficient steam is not partially consumed")
	t.check(SteamMachines.draw_steam(world,[p],3) and boiler.steam == 2,"steam draw conserves shared supply")
	grinder.slots[0] = stack(RawOres.RAW_IRON); grinder.slots[2] = stack(SteamMachines.IRON_POWDER,62)
	boiler.steam = 20.0
	SteamMachines.process_machine(world,p+Vector3i.RIGHT*3,[p],4)
	t.check(grinder.slots[0].count == 1 and grinder.slots[2].count == 62 and boiler.steam == 20,"output capacity blocks a whole batch without consuming ore or steam")
	t.check(SteamMachines.accepts(boiler,0,Nodes.COAL) and not SteamMachines.accepts(boiler,0,Nodes.PLANKS) and not SteamMachines.accepts(grinder,2,RawOres.RAW_IRON),"machine slots reject wrong fuel and output insertion")
	# Workstation screen and quick transfer use the same validation.
	game.inventory = Inventory.new(); game.inventory.add_item(Nodes.COAL,2)
	game.open_inventory("steam",p)
	t.check(game.world.active and game.hud.station_ui.size() == 1,"generator screen shows its coal slot and keeps machinery running")
	game.hud.shift_mode = true; game.hud._slot_click(0,false,false); game.hud.shift_mode = false
	t.check(boiler.slots[0].count == 3,"quick transfer inserts coal into generator")
	game.open_inventory("steam",p+Vector3i.RIGHT*3)
	t.check(game.hud.station_indices == [0,2],"grinder screen exposes input and output only")
	# Hopper automation cannot insert into output or steal unprocessed ore.
	var hopper: Vector3i = p+Vector3i.RIGHT*3+Vector3i.UP
	world.set_node(hopper,Nodes.HOPPER); world.circuits.configure(hopper,Vector3i.DOWN)
	world.get_station(hopper,"chest").slots[0] = stack(RawOres.RAW_GOLD)
	grinder.slots[0] = stack(0,0)
	t.check(world.circuits.hopper(hopper) and grinder.slots[0].id == RawOres.RAW_GOLD,"hopper inserts raw ore into grinder")
	var out_hopper: Vector3i = p+Vector3i.RIGHT*3+Vector3i.DOWN
	world.set_node(out_hopper,Nodes.HOPPER)
	t.check(world.circuits.hopper(out_hopper) and grinder.slots[0].count == 1,"hopper below extracts powder without stealing unprocessed ore")
	# A 20-frame vehicle exceeds the ordinary piston limit and carries a chest.
	var engine := Vector3i(2,804,10)
	world.set_node(engine,SteamMachines.ENGINE); world.circuits.configure(engine,Vector3i.RIGHT)
	for x in 20: world.set_node(engine+Vector3i(x,0,1),SteamMachines.FRAME)
	var cargo: Vector3i = engine+Vector3i(3,1,1)
	world.set_node(cargo,Nodes.CHEST)
	world.set_node(cargo+Vector3i.RIGHT,Nodes.CHEST)
	world.get_station(cargo,"chest").slots[0] = stack(Nodes.DIAMOND,17)
	world.get_station(cargo,"chest").slots[27] = stack(Nodes.GOLD,23)
	world.set_node(engine+Vector3i(6,1,1),Nodes.PLANKS)
	game.player.position = Vector3(engine+Vector3i(6,2,1))+Vector3(0.5,0,0.5)
	var before: Vector3 = game.player.position
	var plan: Dictionary = SteamMachines.plan_vehicle(world,engine,Vector3i.RIGHT)
	t.check(plan.get("nodes",[]).size() == 24,"frame engine plans an assembly larger than twelve blocks")
	boiler.steam = 100
	t.check(SteamMachines.move_vehicle(world,engine,[p]),"steam moves a large frame vehicle")
	t.check(world.get_station(cargo+Vector3i.RIGHT,"chest").slots[0].count == 17 and not world.stations.has(VoxelWorld.station_key(cargo)),"vehicle carries chest contents exactly once")
	t.check(world.get_station(cargo+Vector3i.RIGHT,"chest").slots[27].count == 23,"vehicle carries both halves of double chest storage")
	t.check(game.player.position == before+Vector3.RIGHT and not world.intersects(game.player.position),"vehicle carries its passenger safely")
	engine += Vector3i.RIGHT
	world.set_node(engine+Vector3i(20,0,1),Nodes.OBSIDIAN)
	var steam_before: float = boiler.steam
	t.check(not SteamMachines.move_vehicle(world,engine,[p]) and boiler.steam == steam_before and world.node_at(engine) == SteamMachines.ENGINE,"blocked vehicle leaves blocks and steam unchanged")
	# A complete generator/bellows/engine circuit travels with the vehicle.
	var auto_base := Vector3i(4,816,4)
	for x in 6:
		for z in 3: world.set_node(auto_base+Vector3i(x,0,z),SteamMachines.FRAME)
	for entry in [[0,SteamMachines.GENERATOR],[1,SteamMachines.BELLOWS],[2,SteamMachines.PIPE],[3,SteamMachines.PIPE],[4,SteamMachines.ENGINE]]:
		world.set_node(auto_base+Vector3i(entry[0],1,1),entry[1])
	world.circuits.configure(auto_base+Vector3i(1,1,1),Vector3i.RIGHT)
	world.circuits.configure(auto_base+Vector3i(4,1,1),Vector3i.RIGHT)
	world.set_node(auto_base+Vector3i(1,1,0),Nodes.REDSTONE_BLOCK)
	world.set_node(auto_base+Vector3i(4,1,0),Nodes.REDSTONE_BLOCK)
	SteamMachines.station(world,auto_base+Vector3i(0,1,1)).slots[0] = stack(Nodes.COAL,4)
	game.player.position = Vector3(15,825,15)
	for i in 17: world.circuits.update(0.1)
	t.check(world.node_at(auto_base+Vector3i(6,1,1)) == SteamMachines.ENGINE and world.node_at(auto_base+Vector3i(2,1,1)) == SteamMachines.GENERATOR,"self-powered vehicle moves twice with its boiler, pipes and redstone")
	var auto_boiler: Dictionary = SteamMachines.station(world,auto_base+Vector3i(2,1,1))
	t.check(not auto_boiler.is_empty() and auto_boiler.slots[0].count == 3 and auto_boiler.burn > 38,"moving generator keeps its fuel and burn progress")
	world.set_node(auto_base+Vector3i(6,1,0),Nodes.AIR)
	for i in 16: world.circuits.update(0.1)
	t.check(world.node_at(auto_base+Vector3i(6,1,1)) == SteamMachines.ENGINE,"removing engine redstone power stops a running vehicle")
	# Save roundtrip preserves boiler contents and weapon reload metadata.
	var restored: Dictionary = JSON.parse_string(JSON.stringify(boiler))
	t.check(is_equal_approx(restored.steam,boiler.steam) and restored.slots[0].count == boiler.slots[0].count,"steam and fuel state survive JSON serialization")
	game.inventory = Inventory.new(); game.inventory.slots[0] = stack(AntiqueArms.MUSKET)
	game.inventory.add_item(AntiqueArms.SHOT,4); game.inventory.add_item(Nodes.GUNPOWDER,4)
	game.gamemode = "survival"; game.state = "playing"
	var bullets: int = game.entities.get_child_count()
	AntiqueArms.fire(game)
	t.check(game.entities.get_child_count() == bullets+1 and game.inventory.count_item(AntiqueArms.SHOT) == 3 and game.inventory.count_item(Nodes.GUNPOWDER) == 3,"musket fires and consumes one shot and one powder")
	AntiqueArms.fire(game)
	t.check(game.entities.get_child_count() == bullets+1,"reload blocks repeat firing")
	var clean: Dictionary = Inventory.clean_slot(JSON.parse_string(JSON.stringify(game.inventory.held())))
	t.check(clean.data.reload_remaining == 3.0,"weapon reload survives save cleanup")
	AntiqueArms.update(game,3.0); AntiqueArms.fire(game)
	t.check(game.entities.get_child_count() == bullets+2 and game.inventory.held().wear == 2,"reloaded musket fires and wears down")
	game.inventory.slots[0] = stack(AntiqueArms.BLUNDERBUSS)
	AntiqueArms.fire(game)
	t.check(game.entities.get_child_count() == bullets+9,"blunderbuss fires seven pellets for one load")
	game.inventory.remove_item(Nodes.GUNPOWDER,game.inventory.count_item(Nodes.GUNPOWDER))
	game.inventory.slots[0] = stack(AntiqueArms.PISTOL)
	AntiqueArms.fire(game)
	t.check(game.entities.get_child_count() == bullets+9,"pistol refuses firing without gunpowder")
	# Breaking a loaded machine returns its inventory using the existing container path.
	var drop_before: int = game.drops.get_child_count()
	game.break_node(p,SteamMachines.GENERATOR,Nodes.TOOLS+10)
	t.check(game.drops.get_child_count() > drop_before and not world.stations.has(VoxelWorld.station_key(p)),"breaking generator drops fuel and removes station")

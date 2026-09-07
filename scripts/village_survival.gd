class_name VillageSurvival
extends RefCounted

var game: Node3D
var displays: Dictionary = {}
var effects: Dictionary = {}
var effect_tick: float = 0.0
var fishing: float = 0.0
var fishing_bite: float = 0.0
var bobber: MeshInstance3D
var mount: RuralAnimal
var boat: Node3D
var boat_id: int = 0
var boat_was_flying: bool = false
var shield_time: float = 0.0
var open_pouch_index: int = -1
var open_equipped_pouch: int = -1
var workstation_pos := Vector3i.ZERO
var workstation_id: int = 0

func _init(owner_game: Node3D) -> void:
	game = owner_game

func reset() -> void:
	if is_instance_valid(bobber): bobber.queue_free()
	if is_instance_valid(boat): boat.queue_free()
	displays.clear()
	bobber = null; boat = null; mount = null; fishing = 0; effects.clear(); shield_time = 0

func update(delta: float) -> void:
	shield_time = maxf(0,shield_time-delta)
	var held_slot: Dictionary = game.inventory.held()
	if held_slot.get("data",{}).has("charge"): held_slot.data.charge = maxf(0,float(held_slot.data.charge)-delta)
	Enchantments.frost_step(game,delta)
	AlchemyWorld.update(game,delta)
	if is_instance_valid(bobber):
		fishing += delta
		bobber.position.y += sin(fishing*8)*delta*0.025
		if fishing >= fishing_bite and fishing < fishing_bite+2:
			game.puff(bobber.position,Color("a2d3d9"),1,0.5)
		if fishing >= fishing_bite+3: fishing = 0; fishing_bite = randf_range(5,14)
		if bobber.position.distance_to(game.player.position) > 30 or game.inventory.held().id != VillageContent.FISHING_ROD: bobber.queue_free(); bobber = null
	PotionEffects.update(game.player,delta)
	for mob in game.creatures.get_children(): PotionEffects.update(mob,delta)
	effect_tick += delta
	if effect_tick >= 2.0:
		effect_tick = 0; refresh_displays(); DeathRecovery.retry(game)
	if is_instance_valid(boat):
		var p: Vector3 = game.player.position
		if Input.is_physical_key_pressed(KEY_CTRL) or (game.world.node_at(Vector3i((p-Vector3.UP*0.4).floor())) != Nodes.WATER and game.world.node_at(Vector3i(p.floor())) != Nodes.WATER):
			game.player.flying = boat_was_flying
			game.spawn_drop(p+Vector3.UP,boat_id); boat.queue_free(); boat = null; boat_id = 0
		else:
			game.player.velocity.y = maxf(game.player.velocity.y,0)
			var water: Vector3i = Vector3i((p-Vector3.UP*0.4).floor())
			if game.world.node_at(water) == Nodes.WATER: game.player.position.y = water.y+1.05
			boat.position = p; boat.rotation.y = game.player.rotation.y

func use() -> bool:
	var held: int = game.inventory.held().id
	var target: Dictionary = game.player.target
	var mob: Creature = game.target_mob()
	if held == Nodes.COMPASS and not target.is_empty() and target.id == Bastions.LODESTONE: return Lodestones.bind(game,target.pos)
	if mob is NetherResident and held == Nodes.GOLD:
		if not mob.barter(): game.toast("This piglin will not barter right now.")
		return true
	if Pouches.is_pouch(held): open_pouch(game.inventory.selected); return true
	if mob != null and (held == VillageContent.LEAD or held == 0 and game.leads.attached(mob)):
		if game.leads.attached(mob): game.leads.detach(mob)
		else: game.leads.attach(mob)
		return true
	if mob is RuralAnimal and mob.kind == "horse":
		if held in [Nodes.GRAIN,VillageContent.CARROT,Nodes.APPLE]:
			mob.trust = mini(3,mob.trust+1); _consume(); game.puff(mob.center(),Color("de8b8f"),10); game.toast("Horse tamed." if mob.trust >= 3 else "The horse is learning to trust you."); return true
		if held == Nodes.SADDLE and not mob.saddled:
			if mob.trust < 3: game.toast("Feed this horse three times to tame it first."); return true
			mob.equip_saddle(); _consume(); return true
		if held == VillageContent.LEATHER_HORSE_ARMOR and not mob.horse_armor:
			mob.equip_horse_armor(); _consume(); return true
		if mob.saddled:
			mount = mob; game.toast("Mounted. Move to ride, Space to jump, Ctrl to dismount."); return true
	if mob is VillageMob:
		if mob.kind == "villager":
			if Input.is_physical_key_pressed(KEY_CTRL) and game.villages.feed(mob): return true
			game.villages.open(mob); return true
		if mob.kind == "iron_golem" and held == Nodes.IRON:
			mob.health = minf(100,mob.health+25); _consume(); game.puff(mob.center(),Color("7cbd72"),10); return true
	if held == VillageContent.TRIDENT:
		var slot: Dictionary = game.inventory.held()
		var riptide: int = Inventory.enchantment(slot,"Riptide")
		if riptide > 0:
			if game.player.underwater or game.world.node_at(Vector3i(game.player.position.floor())) == Nodes.WATER or (weather() != "clear" and game.world.open_sky(Vector3i(game.player.position.floor()))):
				game.player.velocity = -game.player.camera.global_basis.z*(15+riptide*6); game.player.velocity.y = maxf(7,game.player.velocity.y)
				game.player.riptide_time = 0.7; game.inventory.damage_tool()
			else: game.toast("Riptide needs water or rain.")
			return true
		var spear := TridentProjectile.new(); spear.game = game; spear.stack = slot.duplicate(true)
		if game.gamemode != "creative" and randf() >= float(Inventory.enchantment(slot,"Unbreaking"))/(Inventory.enchantment(slot,"Unbreaking")+1.0): spear.stack.wear += 1
		spear.stack.count = 1; spear.consumed = game.gamemode != "creative" and spear.stack.wear < Nodes.durability(slot.id)
		spear.position = game.player.camera.global_position-game.player.camera.global_basis.z*0.5; spear.velocity = -game.player.camera.global_basis.z*30+Vector3.UP
		_consume(); game.entities.add_child(spear); return true
	if held == VillageContent.FISHING_ROD: fish(target); return true
	if held == VillageContent.SHIELD: shield_time = 1.0; game.toast("Shield raised."); return true
	if held == VillageContent.XP_BOTTLE:
		_consume(); game.experience += randi_range(3,11); game.puff(game.player.position+Vector3.UP,Color("9ad964"),15); return true
	if PotionCatalog.is_bottle(held):
		if PotionCatalog.ITEMS[held].form == "drink":
			PotionEffects.apply_item(game.player,held); _consume()
			if PotionCatalog.ITEMS[held].potion != "ominous": give(VillageContent.GLASS_BOTTLE,1)
			game.toast(PotionCatalog.description(held))
		else:
			var projectile := PotionProjectile.new(); projectile.game = game; projectile.item_id = held
			projectile.position = game.player.camera.global_position-game.player.camera.global_basis.z*0.5
			projectile.velocity = -game.player.camera.global_basis.z*14+Vector3.UP*2
			game.entities.add_child(projectile); _consume()
		return true
	if held == Nodes.MILK_BUCKET: PotionEffects.clear(game.player)
	if held == VillageContent.GLASS_BOTTLE:
		for cloud in game.adventure.breath_clouds:
			if cloud.dimension == game.dimension and cloud.position.distance_to(game.player.position) < 5:
				_consume(); give(VillageContent.DRAGON_BREATH,1); cloud.life = maxf(0,cloud.life-1); game.toast("Collected dragon breath."); return true
		for entity in game.entities.get_children():
			if entity is MagicProjectile and entity.kind == "breath" and entity.position.distance_to(game.player.position) < 6:
				_consume(); give(VillageContent.DRAGON_BREATH,1); entity.queue_free(); game.toast("Collected dragon breath."); return true
	if held in [VillageContent.EMPTY_MAP,VillageContent.FILLED_MAP]:
		if held == VillageContent.EMPTY_MAP: _consume(); give(VillageContent.FILLED_MAP,1)
		show_map(); return true
	if VillageContent.DATA.get(held,{}).get("family","") == "boat":
		if not target.is_empty() and target.id == Nodes.WATER: launch_boat(held,target.pos)
		else: game.toast("Place your boat on water.")
		return true
	if held == VillageContent.CROSSBOW: fire_crossbow(); return true
	if target.is_empty(): return false
	var p: Vector3i = target.pos; var id: int = target.id
	if held == VillageContent.GLASS_BOTTLE and id == Nodes.WATER:
		_consume(); give(VillageContent.WATER_BOTTLE,1); return true
	if held == VillageContent.COD_BUCKET and target.normal == Vector3i.UP:
		if game.world.set_node(p+Vector3i.UP,Nodes.WATER): _consume(); give(Nodes.BUCKET,1); game.spawn_drop(Vector3(p)+Vector3.UP*1.4,VillageContent.RAW_COD,1)
		return true
	if held == VillageContent.COCOA_BEANS and id == Nodes.LOG and target.normal != Vector3i.UP and game.world.node_at(p+target.normal) == Nodes.AIR:
		game.world.set_node(p+target.normal,VillageContent.COCOA_POD); _consume(); return true
	if held == VillageContent.KELP and id == Nodes.WATER and game.world.node_at(p+Vector3i.DOWN) != Nodes.AIR:
		game.world.set_node(p,VillageContent.KELP_PLANT); _consume(); return true
	if held == VillageContent.LILY_PAD and id == Nodes.WATER and game.world.node_at(p+Vector3i.UP) == Nodes.AIR:
		game.world.set_node(p+Vector3i.UP,held); _consume(); return true
	if VillageContent.CROPS.has(held):
		var soil: int = Nodes.SOUL_SAND if held == VillageContent.NETHER_WART_ITEM else (Nodes.GRASS if held == VillageContent.SWEET_BERRY else Nodes.FARMLAND)
		if target.normal == Vector3i.UP and (id == soil or held == VillageContent.SWEET_BERRY and id == Nodes.DIRT) and game.world.node_at(p+Vector3i.UP) == Nodes.AIR:
			if game.world.set_node(p+Vector3i.UP,VillageContent.CROPS[held]): _consume(); game.sound("place")
		elif Nodes.food(held) > 0 and game.player.hunger < 20: return false
		else: game.toast("Plant this on "+Nodes.title(soil).to_lower()+".")
		return true
	if held == Nodes.BONE_MEAL and VillageContent.shape(id) == "crop" and VillageContent.DATA[id].stage < 3:
		if VillageContent.crop_seed(id) != VillageContent.NETHER_WART_ITEM: game.world.set_node(p,id+3-int(VillageContent.DATA[id].stage)); _consume()
		return true
	if id == VillageContent.ITEM_FRAME:
		frame_item(p); return true
	if held == VillageContent.GLOBE_PATTERN and VillageContent.DATA.get(id,{}).get("family","") == "banner":
		game.world.get_station(p,"banner")["globe"] = true; refresh_displays(); game.toast("Globe pattern applied."); return true
	if not Input.is_physical_key_pressed(KEY_CTRL):
		if id == VillageContent.BELL: game.villages.ring_bell(p); return true
		if VillageContent.is_bed(id): game.sleep_at(p); return true
		if id in [VillageContent.WOODEN_DOOR,VillageContent.WOODEN_DOOR_OPEN]: toggle_door(p); return true
		if id == VillageContent.BREWING_STAND: game.open_inventory("brewing",p); return true
		if id in [VillageContent.BARREL,VillageContent.RECOVERY_CHEST]: game.open_inventory("chest",p); return true
		if id in [VillageContent.SMOKER,VillageContent.BLAST_FURNACE,VillageContent.CAMPFIRE]:
			var station: Dictionary = game.world.get_station(p,"furnace"); station.device = id
			if id == VillageContent.CAMPFIRE: station.burn = 1000000.0
			game.open_inventory("furnace",p); return true
		if id == VillageContent.COMPOSTER:
			var station: Dictionary = game.world.get_station(p,"composter")
			if int(station.get("compost",0)) >= 7: give(Nodes.BONE_MEAL,1); station.compost = 0; game.toast("Collected bone meal.")
			elif held in [Nodes.SEEDS,Nodes.GRAIN,Nodes.SAPLING,Nodes.LEAVES,Nodes.APPLE,Nodes.BREAD,VillageContent.CARROT,VillageContent.POTATO,VillageContent.BEETROOT,VillageContent.BEETROOT_SEEDS,VillageContent.KELP]:
				station.compost = int(station.get("compost",0))+1; _consume(); game.toast("Compost %d / 7"%int(station.compost))
			else: game.toast("Add seven crops, seeds, leaves or saplings, then collect bone meal.")
			return true
		if id == VillageContent.CAULDRON:
			var station: Dictionary = game.world.get_station(p,"cauldron")
			if held == Nodes.WATER_BUCKET: station.water = 3; _consume(); give(Nodes.BUCKET,1)
			elif held == VillageContent.GLASS_BOTTLE and int(station.get("water",0)) > 0: station.water -= 1; _consume(); give(VillageContent.WATER_BOTTLE,1)
			else: game.toast("Fill the cauldron with a water bucket, then bottle up to three portions.")
			return true
		if id in [VillageContent.ANVIL,VillageContent.GRINDSTONE,VillageContent.SMITHING_TABLE,VillageContent.BREWING_STAND,VillageContent.LOOM,VillageContent.STONECUTTER,VillageContent.CARTOGRAPHY_TABLE,VillageContent.FLETCHING_TABLE,VillageContent.LECTERN]:
			show_station(p,id); return true
	if VillageContent.is_bed(held) and held not in [Nodes.BED_FOOT,Nodes.BED_HEAD]:
		var place: Vector3i = p+target.normal
		var facing: Vector3i = game.world.circuits.player_facing() if game.world.circuits.has_method("player_facing") else Vector3i.FORWARD
		var look: Vector3 = -game.player.global_basis.z
		facing = Vector3i(signi(int(signf(look.x))),0,0) if absf(look.x) > absf(look.z) else Vector3i(0,0,signi(int(signf(look.z))))
		if game.world.node_at(place) == Nodes.AIR and game.world.node_at(place+facing) == Nodes.AIR:
			game.world.set_node(place,VillageContent.bed_foot(held)); game.world.set_node(place+facing,VillageContent.bed_head(held)); _consume()
		else: game.toast("A bed needs two free blocks.")
		return true
	if held == VillageContent.WOODEN_DOOR:
		var place: Vector3i = p+target.normal
		if game.world.node_at(place) == Nodes.AIR and game.world.node_at(place+Vector3i.UP) == Nodes.AIR:
			game.world.set_node(place,held); game.world.set_node(place+Vector3i.UP,held)
			game.world.block_states[VoxelWorld.station_key(place)] = {"upper":false}; game.world.block_states[VoxelWorld.station_key(place+Vector3i.UP)] = {"upper":true}; _consume()
		return true
	return false

func _consume() -> void:
	if game.gamemode != "creative": game.inventory.consume_selected()

func give(id: int, amount: int, data: Dictionary = {}) -> void:
	var rest: int = game.inventory.add_item(id,amount,0,data)
	if rest > 0: game.spawn_drop(game.player.position+Vector3.UP,id,rest,0,data)

func break_special(p: Vector3i, id: int, _tool: int) -> bool:
	var station: Dictionary = game.world.stations.get(VoxelWorld.station_key(p),{})
	if station.has("book"):
		game.spawn_drop(Vector3(p)+Vector3.UP,Nodes.WRITTEN_BOOK,1,0,station.book); station.erase("book")
	if VillageContent.is_bed(id) and id not in [Nodes.BED_FOOT,Nodes.BED_HEAD]:
		var other_id: int = VillageContent.bed_head(id) if id == VillageContent.bed_foot(id) else VillageContent.bed_foot(id)
		for d in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
			if game.world.node_at(p+d) == other_id: game.world.set_node(p+d,Nodes.AIR); break
		game.world.set_node(p,Nodes.AIR)
		if game.gamemode != "creative": game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,VillageContent.bed_foot(id))
		return true
	if id in [VillageContent.WOODEN_DOOR,VillageContent.WOODEN_DOOR_OPEN]:
		var upper: bool = game.world.block_states.get(VoxelWorld.station_key(p),{}).get("upper",game.world.node_at(p+Vector3i.DOWN) == id)
		var other: Vector3i = p+(Vector3i.DOWN if upper else Vector3i.UP)
		if game.world.node_at(other) in [VillageContent.WOODEN_DOOR,VillageContent.WOODEN_DOOR_OPEN]: game.world.set_node(other,Nodes.AIR)
		game.world.set_node(p,Nodes.AIR)
		if game.gamemode != "creative": game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,VillageContent.WOODEN_DOOR)
		return true
	return false

func toggle_door(p: Vector3i) -> void:
	var id: int = game.world.node_at(p)
	var upper: bool = game.world.block_states.get(VoxelWorld.station_key(p),{}).get("upper",game.world.node_at(p+Vector3i.DOWN) == id)
	var other: Vector3i = p+(Vector3i.DOWN if upper else Vector3i.UP)
	game.world.block_states[VoxelWorld.station_key(p)] = {"upper":upper}
	game.world.block_states[VoxelWorld.station_key(other)] = {"upper":not upper}
	var next: int = VillageContent.WOODEN_DOOR_OPEN if id == VillageContent.WOODEN_DOOR else VillageContent.WOODEN_DOOR
	game.world.set_node(p,next)
	if game.world.node_at(other) == id: game.world.set_node(other,next)
	game.sound("place")

func fish(target: Dictionary) -> void:
	if is_instance_valid(bobber):
		if fishing >= fishing_bite and fishing <= fishing_bite+2:
			var roll: int = randi_range(0,99)
			var caught: int = VillageContent.RAW_COD if roll < 55 else (VillageContent.RAW_SALMON if roll < 80 else (VillageContent.PUFFERFISH if roll < 90 else (VillageContent.TROPICAL_FISH if roll < 95 else VillageContent.INK_SAC)))
			var luck: int = Inventory.enchantment(game.inventory.held(),"Luck of the Sea")+PotionEffects.level(game.player,"luck")-PotionEffects.level(game.player,"bad_luck")
			if randf() < clampf(0.02+0.025*luck,0,0.25):
				var rng := RandomNumberGenerator.new(); rng.randomize(); give(VillageContent.ENCHANTED_BOOK,1,Enchantments.random_book(rng))
			else: give(caught,1)
			game.experience += 2; game.toast("Caught "+Nodes.title(caught).to_lower()+"!")
		else: game.toast("The fish got away. Reel in when bubbles appear.")
		bobber.queue_free(); bobber = null; game.inventory.damage_tool(); return
	if target.is_empty() or target.id != Nodes.WATER: game.toast("Cast into water. Use again when the bobber bubbles."); return
	bobber = MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = Vector3(0.15,0.18,0.15); bobber.mesh = mesh
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("e87664"); bobber.material_override = mat
	bobber.position = Vector3(target.pos)+Vector3(0.5,1.02,0.5); game.entities.add_child(bobber)
	fishing = 0.0; fishing_bite = maxf(1,randf_range(5,14)-Inventory.enchantment(game.inventory.held(),"Lure")*2); game.toast("Line cast. Watch for bubbles, then use the rod again.")

func fire_crossbow() -> void:
	var held: Dictionary = game.inventory.held()
	var loaded: int = int(held.get("data",{}).get("loaded_arrow",0))
	if loaded == 0:
		for slot in game.inventory.slots:
			if slot.id == Nodes.ARROW_ITEM or VillageContent.DATA.get(slot.id,{}).get("family","") == "arrow": loaded = slot.id; break
		if loaded == 0 and game.gamemode == "creative": loaded = Nodes.ARROW_ITEM
		if loaded == 0: game.toast("You need an arrow to load the crossbow."); return
		if game.gamemode != "creative": game.inventory.remove_item(loaded,1)
		if not held.has("data"): held.data = {}
		held.data.loaded_arrow = loaded; held.data.charge = maxf(0.1,1.25-0.25*Inventory.enchantment(held,"Quick Charge")); game.inventory.changed.emit(); game.toast("Crossbow loaded. Use again to fire."); return
	if float(held.data.get("charge",0)) > 0: game.toast("Crossbow charging…"); return
	var multishot: bool = Inventory.enchantment(held,"Multishot") > 0
	for i in (3 if multishot else 1):
		var direction: Vector3 = (-game.player.camera.global_basis.z).rotated(Vector3.UP,deg_to_rad([0,-10,10][i]))
		var shot: Arrow = game.spawn_arrow(game.player.camera.global_position+direction*0.5,direction*35+Vector3.UP)
		shot.from_player = true; shot.damage = 9; shot.item_id = loaded; shot.piercing = Inventory.enchantment(held,"Piercing"); shot.recoverable = i == 0 and game.gamemode != "creative"
	held.data.erase("charge")
	held.data.erase("loaded_arrow")
	if held.data.is_empty(): held.erase("data")
	if game.gamemode != "creative": game.inventory.damage_tool()
	game.sound("arrow")

func blocks_damage(source: Vector3) -> bool:
	if shield_time <= 0 or game.inventory.held().id != VillageContent.SHIELD or is_inf(source.x): return false
	if (-game.player.global_basis.z).dot((source-game.player.position).normalized()) < 0.1: return false
	game.inventory.damage_tool(); game.sound("thud"); return true

func apply_effect(target: Node3D, effect: String, duration: float = 15.0) -> void:
	PotionEffects.apply(target,effect,duration)

func launch_boat(id: int, p: Vector3i) -> void:
	if is_instance_valid(boat): return
	boat = Node3D.new(); game.entities.add_child(boat); boat_id = id; boat_was_flying = game.player.flying
	for piece in [ [Vector3(0,-0.1,0),Vector3(1.3,0.2,1.8)], [Vector3(-0.67,0.1,0),Vector3(0.13,0.4,1.8)], [Vector3(0.67,0.1,0),Vector3(0.13,0.4,1.8)], [Vector3(0,0.1,-0.9),Vector3(1.3,0.4,0.13)], [Vector3(0,0.1,0.9),Vector3(1.3,0.4,0.13)]]:
		var mesh := MeshInstance3D.new(); var box := BoxMesh.new(); box.size = piece[1]; mesh.mesh = box; mesh.position = piece[0]
		var mat := StandardMaterial3D.new(); mat.albedo_color = Nodes.color(id); mesh.material_override = mat; boat.add_child(mesh)
	game.player.position = Vector3(p)+Vector3(0.5,1,0.5); _consume(); game.toast("Boat launched. Move to paddle; Ctrl to leave.")

func show_map() -> void:
	game.state = "map"; game.world.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.hud._clear(); game.hud.screen = "map"; game.hud._dim()
	var panel: Panel = game.hud._fitted_panel(Vector2(620,600))
	game.hud._label(panel,"EXPLORER'S MAP",Vector2(24,18),24,game.hud.ACCENT)
	var img := Image.create(96,96,false,Image.FORMAT_RGB8)
	var origin: Vector3 = game.player.position
	for y in 96:
		for x in 96:
			var wx: int = floori(origin.x)+(x-48)*4; var wz: int = floori(origin.z)+(y-48)*4
			var h: int = game.world.generator.terrain_height(wx,wz)
			var color: Color = Color("678bab") if h <= TerrainGenerator.SEA else (Color("d3bb85") if "desert" in game.world.generator.biome(wx,wz) else Color("719068"))
			img.set_pixel(x,y,color.lightened((h-25)*0.009))
	var village: Dictionary = VillageGenerator.nearest(game.world.generator,origin)
	var dot := Vector2i(roundi((village.center.x-origin.x)/4)+48,roundi((village.center.z-origin.z)/4)+48)
	if dot.x in range(2,94) and dot.y in range(2,94): img.fill_rect(Rect2i(dot-Vector2i.ONE,Vector2i(3,3)),Color("d4a25e"))
	img.fill_rect(Rect2i(47,47,3,3),Color("f4eee0"))
	var map := TextureRect.new(); map.texture = ImageTexture.create_from_image(img); map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; map.position = Vector2(80,64); map.size = Vector2(460,460); panel.add_child(map)
	game.hud._label(panel,"North ↑  ·  White: you  ·  Gold: village  ·  Scale: 4 blocks / pixel",Vector2(32,533),14,game.hud.MUTED)
	game.hud._button(panel,"Done",Rect2(24,561,572,30),game.resume)

func exchange(cost: Array, id: int, count: int = 1) -> bool:
	var trial := Inventory.new(); trial.slots = game.inventory.slots.duplicate(true)
	for payment in cost:
		if not trial.remove_item(payment[0],payment[1]): game.toast("Need %d %s."%[payment[1],Nodes.title(payment[0]).to_lower()]); return false
	if trial.add_item(id,count) > 0: game.toast("Make room in your inventory first."); return false
	game.inventory.slots = trial.slots; game.inventory.changed.emit(); game.sound("place"); return true

func show_station(p: Vector3i, id: int) -> void:
	workstation_pos = p; workstation_id = id
	game.state = "workstation"; game.world.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.hud._clear(); game.hud.screen = "workstation"; game.hud._dim()
	var panel: Panel = game.hud._fitted_panel(Vector2(750,560))
	game.hud._label(panel,Nodes.title(id).to_upper(),Vector2(26,18),26,game.hud.ACCENT)
	var scroll := ScrollContainer.new(); scroll.position = Vector2(24,67); scroll.size = Vector2(704,404); panel.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",7); scroll.add_child(list)
	var actions: Array = []
	if id in [VillageContent.ANVIL,VillageContent.GRINDSTONE,VillageContent.SMITHING_TABLE]:
		for i in game.inventory.slots.size():
			var slot: Dictionary = game.inventory.slots[i]
			if Nodes.durability(slot.id) <= 0 and slot.id != VillageContent.ENCHANTED_BOOK: continue
			var index: int = i
			if id == VillageContent.SMITHING_TABLE and Netherite.upgrade_id(slot.id) != 0:
				actions.append([Nodes.title(slot.id)+" → Netherite · 1 ingot + 1 template",func():
					if not Netherite.upgrade(game.inventory,index): game.toast("Bring one netherite ingot and one upgrade template.")
					else: game.sound("equip")
					show_station(p,id)])
			var description: String = "Remove enchantments, recover XP" if id == VillageContent.GRINDSTONE else ("Apply first compatible enchanted book · 1 XP level" if id == VillageContent.ANVIL else "Repair 25% · 1 matching material")
			actions.append([Nodes.title(slot.id)+" — "+description,func(): equipment_work(index,id); show_station(p,id)])
	elif id == VillageContent.STONECUTTER:
		for pair in [[Nodes.STONE,Nodes.BRICKS],[Nodes.BRICKS,VillageContent.CHISELED_BRICKS],[VillageContent.GRANITE,VillageContent.POLISHED_GRANITE],[VillageContent.DIORITE,VillageContent.POLISHED_DIORITE],[VillageContent.ANDESITE,VillageContent.POLISHED_ANDESITE],[VillageContent.QUARTZ_BLOCK,VillageContent.QUARTZ_PILLAR],[Nodes.DEEPSLATE,Nodes.POLISHED_DEEPSLATE]]:
			var input: int = pair[0]; var output: int = pair[1]
			actions.append(["1 "+Nodes.title(input)+" → 1 "+Nodes.title(output),func(): exchange([[input,1]],output)])
		for base in BuildingShapes.MATERIALS:
			for source in BuildingShapes.stonecutter_inputs(base):
				var input: int = source
				var slab: int = BuildingShapes.slab_for(base); var stair: int = BuildingShapes.stair_for(base)
				actions.append([BuildingShapes.title(slab)+" × 2 · 1 "+Nodes.title(input),func(): exchange([[input,1]],slab,2)])
				actions.append([BuildingShapes.title(stair)+" · 1 "+Nodes.title(input),func(): exchange([[input,1]],stair)])
		var masonry: Dictionary = Masonry.cuts()
		for output_id in masonry:
			for source_id in masonry[output_id]:
				var input: int = source_id; var output: int = output_id
				actions.append(["1 "+Nodes.title(input)+" → 1 "+Nodes.title(output),func(): exchange([[input,1]],output)])

	elif id == VillageContent.LOOM:
		for dye in VillageContent.DATA:
			if VillageContent.DATA[dye].get("family","") != "dye": continue
			var dye_id: int = dye; var color_name: String = VillageContent.DATA[dye].dye
			var banner_id: int = 0
			for node in VillageContent.BLOCKS:
				if VillageContent.DATA[node].get("family","") == "banner" and VillageContent.DATA[node].dye == color_name: banner_id = node
			var output: int = banner_id
			actions.append([color_name.replace("_"," ").capitalize()+" banner · 6 wool + stick + dye",func(): exchange([[Nodes.WOOL,6],[Nodes.STICK,1],[dye_id,1]],output)])
	elif id == VillageContent.CARTOGRAPHY_TABLE:
		actions.append(["Create map · 8 paper + compass",func(): exchange([[Nodes.PAPER,8],[Nodes.COMPASS,1]],VillageContent.EMPTY_MAP)])
		actions.append(["Copy a map · map + empty map → 2 maps",func(): exchange([[VillageContent.FILLED_MAP,1],[VillageContent.EMPTY_MAP,1]],VillageContent.FILLED_MAP,2)])
		actions.append(["View the terrain map",show_map])
	elif id == VillageContent.FLETCHING_TABLE:
		actions.append(["4 arrows · flint + stick + feather",func(): exchange([[Nodes.FLINT,1],[Nodes.STICK,1],[Nodes.FEATHER,1]],Nodes.ARROW_ITEM,4)])
		for arrow_id in VillageContent.DATA:
			if VillageContent.DATA[arrow_id].get("family","") != "arrow": continue
			var output: int = arrow_id
			var effect: String = VillageContent.DATA[arrow_id].effect
			for potion_id in VillageContent.DATA:
				if VillageContent.DATA[potion_id].get("family","") == "potion" and VillageContent.DATA[potion_id].effect == effect:
					var potion: int = potion_id
					actions.append(["8 "+Nodes.title(output)+" · 8 arrows + potion",func(): exchange([[Nodes.ARROW_ITEM,8],[potion,1]],output,8)])
	elif id == VillageContent.LECTERN:
		var station: Dictionary = game.world.get_station(p,"lectern")
		if station.has("book"):
			var text := Label.new(); text.text = str(station.book.get("title","Book"))+"\n\n"+str(station.book.get("text","")); text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; text.custom_minimum_size.x = 650; list.add_child(text)
			actions.append(["Take book",func():
				if game.inventory.capacity(Nodes.WRITTEN_BOOK,0,station.book) >= 1: give(Nodes.WRITTEN_BOOK,1,station.book); station.erase("book"); show_station(p,id)])
		else:
			actions.append(["Place a signed book from your inventory",func():
				for slot in game.inventory.slots:
					if slot.id == Nodes.WRITTEN_BOOK:
						station.book = slot.get("data",{}).duplicate(true); slot.clear(); slot.merge({"id":0,"count":0,"wear":0}); game.inventory.changed.emit(); show_station(p,id); return
				game.toast("Write and sign a book first." )])
	for action in actions:
		var button := Button.new(); button.text = action[0]; button.custom_minimum_size = Vector2(680,48); button.pressed.connect(action[1]); list.add_child(button)
	if actions.is_empty(): game.hud._label(panel,"Bring tools, armor or books to use this workstation.",Vector2(28,100),16,game.hud.MUTED)
	game.hud._button(panel,"Done",Rect2(24,496,704,40),game.resume)

func equipment_work(index: int, device: int) -> bool:
	var slot: Dictionary = game.inventory.slots[index]
	if slot.id == 0: return false
	if device == VillageContent.GRINDSTONE:
		if slot.get("data",{}).get("enchantments",{}).is_empty(): game.toast("This item has no enchantments."); return false
		var kept: Dictionary = {}
		for enchant in slot.data.enchantments:
			if Enchantments.DATA.get(enchant,{}).get("curse",false): kept[enchant] = slot.data.enchantments[enchant]
		if kept == slot.data.enchantments: game.toast("Curses cannot be removed by a grindstone."); return false
		if kept.is_empty(): slot.data.erase("enchantments")
		else: slot.data.enchantments = kept
		if slot.id == VillageContent.ENCHANTED_BOOK and kept.is_empty(): slot.id = Nodes.BOOK
		if slot.data.is_empty(): slot.erase("data")
		game.experience += 3; game.inventory.changed.emit(); return true
	if device == VillageContent.SMITHING_TABLE:
		if slot.wear <= 0: game.toast("This item needs no repair."); return false
		var material: int = Nodes.DIAMOND if Nodes.tool_tier(slot.id) == 3 or Nodes.is_armor(slot.id) and Nodes.armor_material(slot.id) == 3 else (Nodes.LEATHER if Nodes.is_armor(slot.id) and Nodes.armor_material(slot.id) == 0 else Nodes.IRON)
		if Nodes.tool_tier(slot.id) == 0: material = Nodes.PLANKS
		if Nodes.tool_tier(slot.id) == 1: material = Nodes.COBBLE
		material = VillageContent.DATA.get(slot.id,{}).get("repair_material",material)
		if not game.inventory.remove_item(material,1): game.toast("Repair needs "+Nodes.title(material)+"."); return false
		slot.wear = maxi(0,int(slot.wear)-ceili(Nodes.durability(slot.id)*0.25)); game.inventory.changed.emit(); return true
	for book_index in game.inventory.slots.size():
		if book_index == index: continue
		var book: Dictionary = game.inventory.slots[book_index]
		if book.id != VillageContent.ENCHANTED_BOOK: continue
		var enchants: Dictionary = book.get("data",{}).get("enchantments",{})
		var current: Dictionary = slot.get("data",{}).get("enchantments",{})
		var combined: Dictionary = Enchantments.combine(slot.id,current,enchants)
		if combined == current: continue
		if game.xp_level() < 1 and game.gamemode != "creative": game.toast("Applying a book costs one XP level."); return false
		if not slot.has("data"): slot.data = {}
		slot.data.enchantments = combined
		book.clear(); book.merge({"id":0,"count":0,"wear":0})
		game.experience = maxf(0,game.experience-(7+2*(game.xp_level()-1))); game.inventory.changed.emit(); return true
	game.toast("Bring a compatible enchanted book."); return false

func ammunition() -> int:
	for slot in game.inventory.slots:
		if slot.id == Nodes.ARROW_ITEM or VillageContent.DATA.get(slot.id,{}).get("family","") == "arrow": return slot.id
	return 0

func ride_step(delta: float, input: Vector3) -> void:
	if not is_instance_valid(mount): mount = null; return
	var horse: RuralAnimal = mount
	if Input.is_physical_key_pressed(KEY_CTRL):
		game.player.position = horse.position+Vector3(1,0.1,0); mount = null; return
	var direction: Vector3 = game.player.global_basis*input.normalized()
	horse.velocity.x = direction.x*8; horse.velocity.z = direction.z*8
	horse.velocity.y -= 22*delta
	if Input.is_physical_key_pressed(KEY_SPACE) and game.world.intersects(horse.position-Vector3.UP*0.05,horse.width,horse.height): horse.velocity.y = 9.5
	for axis in [0,2,1]:
		var next: Vector3 = horse.position; next[axis] += horse.velocity[axis]*delta
		if not game.world.intersects(next,horse.width,horse.height): horse.position = next
		elif axis == 1: horse.velocity.y = 0
	horse.model.rotation.y = game.player.rotation.y
	game.player.position = horse.position+Vector3.UP*1.1
	game.player.velocity = Vector3.ZERO

func frame_item(p: Vector3i) -> void:
	var station: Dictionary = game.world.get_station(p,"frame")
	var stored: Dictionary = station.slots[0]
	if stored.id != 0:
		if game.inventory.capacity(stored.id,stored.wear,stored.get("data",{})) < int(stored.count): game.toast("Make room before taking this item."); return
		game.inventory.add_item(stored.id,stored.count,stored.wear,stored.get("data",{}))
		stored.clear(); stored.merge({"id":0,"count":0,"wear":0})
	elif game.inventory.held().id != 0:
		station.slots[0] = game.inventory.held().duplicate(true); station.slots[0].count = 1; _consume()
	refresh_displays()

func refresh_displays() -> void:
	for node in displays.values():
		if is_instance_valid(node): node.queue_free()
	displays.clear()
	for key in game.world.stations:
		var station: Dictionary = game.world.stations[key]
		if station.get("kind","") not in ["frame","banner"]: continue
		var xyz: PackedStringArray = key.split(",")
		if xyz.size() != 3: continue
		var p := Vector3i(int(xyz[0]),int(xyz[1]),int(xyz[2]))
		if not game.world.loaded_at(Vector3(p)) or Vector3(p).distance_to(game.player.position) > 70: continue
		var mesh := MeshInstance3D.new()
		if station.kind == "frame" and station.slots[0].id != 0 and game.world.node_at(p) == VillageContent.ITEM_FRAME:
			var id: int = station.slots[0].id
			mesh.mesh = game.node_mesh(id) if Nodes.placeable(id) else ItemArt.mesh(id)
			mesh.material_override = game.node_material if Nodes.placeable(id) else ItemArt.material(id)
			mesh.scale = Vector3.ONE*0.4; mesh.position = Vector3(p)+Vector3(0.5,0.5,-0.02)
			if Nodes.placeable(id): mesh.position -= Vector3.ONE*0.2
		elif station.kind == "banner" and station.get("globe",false) and VillageContent.DATA.get(game.world.node_at(p),{}).get("family","") == "banner":
			var sphere := SphereMesh.new(); sphere.radius = 0.16; sphere.height = 0.32; mesh.mesh = sphere
			var mat := StandardMaterial3D.new(); mat.albedo_color = Color("d7cf82"); mesh.material_override = mat; mesh.position = Vector3(p)+Vector3(0.5,0.72,0.43)
		else: mesh.free(); continue
		game.entities.add_child(mesh); displays[key] = mesh

func animal_snapshot() -> Array:
	var result: Array = []
	for animal in game.creatures.get_children():
		if animal is RuralAnimal and not animal.is_queued_for_deletion() and not game.leads.attached(animal):
			result.append({"kind":animal.kind,"position":[animal.position.x,animal.position.y,animal.position.z],"health":animal.health,"trust":animal.trust,"saddled":animal.saddled,"horse_armor":animal.horse_armor})
	return result

func restore_animals(saved: Array) -> void:
	for entry in saved:
		if entry.get("kind","") not in ["rabbit","horse"]: continue
		var animal: Creature = game.spawn_creature(entry.kind,VillageLife.vec(entry.position))
		animal.health = entry.get("health",animal.health); animal.trust = entry.get("trust",0)
		if entry.get("saddled",false): animal.equip_saddle()
		if entry.get("horse_armor",false): animal.equip_horse_armor()

func restore_effects(value: Variant) -> void:
	PotionEffects.clear(game.player)
	if not value is Dictionary: return
	for effect in value:
		var duration: float = float(value[effect].get("duration",0)) if value[effect] is Dictionary else float(value[effect])
		var potency: int = int(value[effect].get("level",1)) if value[effect] is Dictionary else 1
		if effect in PotionEffects.NAMES and is_finite(duration) and duration > 0: PotionEffects.apply(game.player,effect,minf(6000,duration),clampi(potency,1,6))

func effect_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for effect in effects: result[effect] = {"duration":effects[effect],"level":PotionEffects.level(game.player,effect)}
	return result

func open_pouch(index: int, equipped: bool = false) -> void:
	var source: Array = game.inventory.pouch_slots if equipped else game.inventory.slots
	if index < 0 or index >= source.size() or not Pouches.is_pouch(source[index].id): return
	game.hud.return_cursor()
	game.inventory.sync_pouches()
	var pouch: Dictionary = source[index]
	open_pouch_index = -1 if equipped else index
	open_equipped_pouch = index if equipped else -1
	game.hud.container_page = 0
	game.state = "inventory"; game.world.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(game.controls): game.controls.hide_all()
	game.hud.show_inventory("chest",{"kind":"pouch","label":Nodes.title(pouch.id)+" · %d slots"%Pouches.size_of(pouch.id),"slots":Pouches.contents(pouch),"equipped":index if equipped else -1})

func weather() -> String:
	if game.dimension != "overworld": return "clear"
	return game.world.adventure_state.get("weather",["clear","clear","rain","clear","thunder"][game.day_number()%5])

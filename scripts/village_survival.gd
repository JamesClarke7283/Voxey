class_name VillageSurvival
extends RefCounted

var game: Node3D
var displays: Dictionary = {}
var effects: Dictionary = {}
var effect_tick: float = 0.0
var fishing: float = 0.0
var fishing_bite: float = 0.0
var fishing_state: Dictionary = {}
var bobber: MeshInstance3D
var mount: RuralAnimal
# The source holds a shield up while the player keeps it raised, so this is a
# held state rather than a timed window. `shield_disabled` covers an axe hit.
var shield_raised: bool = false
var shield_disabled: float = 0.0
var open_pouch_index: int = -1
var open_equipped_pouch: int = -1
var workstation_pos := Vector3i.ZERO
var workstation_id: int = 0

func _init(owner_game: Node3D) -> void:
	game = owner_game

func reset() -> void:
	Fishing.cancel(self)
	displays.clear()
	bobber = null; mount = null; fishing = 0; effects.clear(); shield_raised = false; shield_disabled = 0.0

func update(delta: float) -> void:
	shield_disabled = maxf(0,shield_disabled-delta)
	# A shield is raised while the player holds it with sneak, which is the
	# source's own held state.
	shield_raised = game.inventory.held().id == VillageContent.SHIELD and (Input.is_physical_key_pressed(KEY_CTRL) or (game.touch and is_instance_valid(game.controls) and game.controls.sneak_held))
	var held_slot: Dictionary = game.inventory.held()
	if held_slot.get("data",{}).has("charge"): held_slot.data.charge = maxf(0,float(held_slot.data.charge)-delta)
	Enchantments.frost_step(game,delta)
	AlchemyWorld.update(game,delta)
	Fishing.update(self,delta)
	PotionEffects.update(game.player,delta)
	for mob in game.creatures.get_children(): PotionEffects.update(mob,delta)
	effect_tick += delta
	if effect_tick >= 2.0:
		effect_tick = 0; refresh_displays(); DeathRecovery.retry(game)

func use() -> bool:
	var held: int = game.inventory.held().id
	var target: Dictionary = game.player.target
	var mob: Creature = game.target_mob()
	if NameTags.use(game,mob): return true
	if Golems.use(game,mob): return true
	if Farming.use(game,mob): return true
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
			if game.boats.ridden(): game.toast("Leave the boat before mounting a horse."); return true
			mount = mob; game.toast("Mounted. Move to ride, Space to jump, Ctrl to dismount."); return true
	if mob is VillageMob:
		# A wandering trader opens the same trading panel as a villager.
		if mob.kind == "villager" or mob.kind == "wandering_trader":
			if mob.kind == "villager" and Input.is_physical_key_pressed(KEY_CTRL) and game.villages.feed(mob): return true
			game.villages.open(mob); return true
	if held == VillageContent.TRIDENT:
		var slot: Dictionary = game.inventory.held()
		var riptide: int = Inventory.enchantment(slot,"Riptide")
		if riptide > 0:
			if game.player.underwater or Fluids.water(game.world.node_at(Vector3i(game.player.position.floor()))) or (weather() != "clear" and game.world.open_sky(Vector3i(game.player.position.floor()))):
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
	if held == VillageContent.SHIELD:
		# The source raises the shield while sneak is held; use only tells the
		# player how, since the state is read from the sneak key each step.
		game.toast("Hold Ctrl with a shield to block attacks from the front.")
		return true
	if held == VillageContent.XP_BOTTLE:
		_consume(); game.experience += randi_range(3,11); game.puff(game.player.position+Vector3.UP,Color("9ad964"),15); return true
	if not target.is_empty() and target.id == VillageContent.CAULDRON and not Input.is_physical_key_pressed(KEY_CTRL):
		return Cauldrons.use(game,target.pos)
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
	if held == VillageContent.CROSSBOW: fire_crossbow(); return true
	if target.is_empty(): return false
	var p: Vector3i = target.pos; var id: int = target.id
	if held == VillageContent.GLASS_BOTTLE and Fluids.water(id):
		_consume(); give(VillageContent.WATER_BOTTLE,1); return true
	if held == VillageContent.COD_BUCKET and target.normal == Vector3i.UP:
		var at: Vector3i = SnowCover.placement(game.world,target).pos
		if game.world.set_node(at,Nodes.WATER): _consume(); give(Nodes.BUCKET,1); game.spawn_drop(Vector3(at)+Vector3.UP*0.4,VillageContent.RAW_COD,1)
		return true
	if held == VillageContent.COCOA_BEANS and WoodTypes.canonical(id) == WoodTypes.log_id(3) and target.normal.y == 0 and game.world.node_at(p+target.normal) == Nodes.AIR:
		game.world.set_node(p+target.normal,VillageContent.COCOA_POD); _consume(); return true
	if held == VillageContent.KELP and id == Nodes.WATER and game.world.node_at(p+Vector3i.DOWN) != Nodes.AIR:
		game.world.set_node(p,VillageContent.KELP_PLANT); _consume(); return true
	if held == VillageContent.LILY_PAD and id == Nodes.WATER and game.world.node_at(p+Vector3i.UP) == Nodes.AIR:
		game.world.set_node(p+Vector3i.UP,held); _consume(); return true
	if CropFarming.use(game,target): return true
	if VillageContent.CROPS.has(held) and not CropFarming.is_crop(VillageContent.CROPS[held]):
		var soil: int = Nodes.SOUL_SAND if held == VillageContent.NETHER_WART_ITEM else (Nodes.GRASS if held == VillageContent.SWEET_BERRY else Nodes.FARMLAND)
		var placement: Dictionary = SnowCover.placement(game.world,target)
		if target.normal == Vector3i.UP and (placement.support_id == soil or held == VillageContent.SWEET_BERRY and placement.support_id == Nodes.DIRT) and SnowCover.replaceable(game.world.node_at(placement.pos)):
			if game.world.set_node(placement.pos,VillageContent.CROPS[held]): _consume(); game.sound("place")
		elif Nodes.food(held) > 0 and game.player.hunger < 20: return false
		else: game.toast("Plant this on "+Nodes.title(soil).to_lower()+".")
		return true
	# Bone meal advances a crop-like node one stage. The arithmetic is by *id*, so
	# the node's own stage layout decides the result, and a node whose ids are not
	# laid out as three consecutive stages must not be advanced this way.
	#
	# Cocoa is exactly that case: its pod ids jump to a cobweb, so the old
	# `id+3-stage` turned a pod into a cobweb. Cocoa has its own ripening path
	# (the `RIPE_COCOA_POD` id) and is excluded here.
	if held == Nodes.BONE_MEAL and not CropFarming.is_crop(id) and id != VillageContent.COCOA_POD and VillageContent.shape(id) == "crop" and VillageContent.DATA[id].stage < 3:
		var advanced: int = id+3-int(VillageContent.DATA[id].stage)
		# Only advance when the destination is really a later stage of the same
		# crop, so a table that is not three-wide cannot silently produce anything.
		if VillageContent.DATA.get(advanced,{}).get("crop","") == VillageContent.DATA[id].get("crop","") and VillageContent.crop_seed(id) != VillageContent.NETHER_WART_ITEM:
			game.world.set_node(p,advanced); _consume()
		return true
	if id == VillageContent.ITEM_FRAME:
		frame_item(p); return true
	# Emblazoning a banner with a dye appends a layer, and a banner used on an
	# emblazoned banner combines their layers, as the source's rules say.
	if VillageContent.DATA.get(id,{}).get("family","") == "banner":
		if Banners.is_banner(held):
			var other: Dictionary = {"id":held,"count":1,"wear":int(game.inventory.held().get("wear",0)),"data":game.inventory.held().get("data",{}).duplicate(true)}
			var station: Dictionary = game.world.get_station(p,"banner")
			var current: Dictionary = {"id":id,"count":1,"data":station.get("layers",[])}
			if Banners.combine(current,other):
				station["layers"] = Banners.layers(current)
				refresh_displays(); if game.gamemode != "creative": _consume()
				game.toast("Banners combined."); return true
			game.toast("That banner is already emblazoned the same way."); return true
		var as_dye: int = Banners.dye_color(held)
		if as_dye >= 0:
			var station2: Dictionary = game.world.get_station(p,"banner")
			var banner_slot: Dictionary = {"id":id,"count":1,"data":station2.get("layers",[])}
			if Banners.emblazon(banner_slot,Banners.pending_pattern(held),as_dye):
				station2["layers"] = Banners.layers(banner_slot)
				refresh_displays(); if game.gamemode != "creative": _consume()
				game.toast("Pattern applied."); return true
			game.toast("That banner already carries its maximum of patterns."); return true
	if not Input.is_physical_key_pressed(KEY_CTRL):
		if PortableStorage.interact(game,p): return true
		if id == VillageContent.BELL: game.villages.ring_bell(p); return true
		if VillageContent.is_bed(id): game.sleep_at(p); return true
		if id in [VillageContent.WOODEN_DOOR,VillageContent.WOODEN_DOOR_OPEN]: toggle_door(p); return true
		if id == VillageContent.BREWING_STAND: game.open_inventory("brewing",p); return true
		if id in [VillageContent.BARREL,VillageContent.RECOVERY_CHEST]: game.open_inventory("chest",p); return true
		if TrappedChests.is_trapped(id):
			# Its signal lasts as long as the screen is open, so the close path must
			# know which chest it was.
			TrappedChests.remember(game,p)
			TrappedChests.open(game,p); return true
		if id in [VillageContent.SMOKER,VillageContent.BLAST_FURNACE]:
			var station: Dictionary = game.world.get_station(p,"furnace"); station.device = id
			game.open_inventory("furnace",p); return true
		if id == VillageContent.COMPOSTER: Composters.interact(game,p); return true
		if id == Bookshelves.ID:
			# The source's right-click puts a book into, or takes one out of, the slot
			# under the pointer, chosen from where on the face the click landed.
			var hit: Vector3 = target.get("point",Vector3(p)+Vector3.ONE*0.5)-Vector3(p)
			var index: int = Bookshelves.slot_at(hit,game.world.circuits.facing(p)) if game.world.circuits.has_method("facing") else Bookshelves.slot_at(hit,0)
			var offered: Dictionary = game.inventory.held()
			if offered.id != 0 and Bookshelves.is_book(offered.id):
				if Bookshelves.insert(game.world,p,index,offered): _consume()
			else:
				var taken: Dictionary = Bookshelves.take(game.world,p,index)
				if not taken.is_empty():
					var rest: int = game.inventory.add_item(taken.id,1,taken.get("wear",0),taken.get("data",{}))
					if rest > 0: game.spawn_drop(Vector3(p)+Vector3.ONE*0.5,taken.id,rest,taken.get("wear",0),taken.get("data",{}))
			game.sound("place"); return true
		if id in [VillageContent.ANVIL,VillageContent.GRINDSTONE,VillageContent.SMITHING_TABLE,VillageContent.BREWING_STAND,VillageContent.LOOM,VillageContent.STONECUTTER,VillageContent.CARTOGRAPHY_TABLE,VillageContent.FLETCHING_TABLE,VillageContent.LECTERN]:
			show_station(p,id); return true
	# A glowstone block charges a respawn anchor; using a charged one sets the spawn in
	# the Nether or explodes outside it, which is the source's own asymmetry.
	if RespawnAnchors.is_anchor(id):
		if held == Nodes.GLOWSTONE:
			if RespawnAnchors.charge_up(game.world,p): _consume()
			return true
		return RespawnAnchors.use(game,p)
	if VillageContent.is_bed(held) and held not in [Nodes.BED_FOOT,Nodes.BED_HEAD]:
		var place: Vector3i = SnowCover.placement(game.world,target).pos
		var facing: Vector3i = game.world.circuits.player_facing() if game.world.circuits.has_method("player_facing") else Vector3i.FORWARD
		var look: Vector3 = -game.player.global_basis.z
		facing = Vector3i(signi(int(signf(look.x))),0,0) if absf(look.x) > absf(look.z) else Vector3i(0,0,signi(int(signf(look.z))))
		if SnowCover.replaceable(game.world.node_at(place)) and SnowCover.replaceable(game.world.node_at(place+facing)):
			game.world.set_node(place,VillageContent.bed_foot(held)); game.world.set_node(place+facing,VillageContent.bed_head(held)); _consume()
		else: game.toast("A bed needs two free blocks.")
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
	if Doors.legacy(game.world.node_at(p)): Doors.migrate_at(game.world,p)
	if Doors.is_door(game.world.node_at(p)):
		Doors.set_open(game.world,p,not Doors.opened(game.world.node_at(p))); return
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
	Fishing.use(self,target)

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

func blocks_damage(source: Vector3, kind: String = "generic") -> bool:
	if not Shields.can_block(game.player,source,kind): return false
	Shields.add_wear(game.player,3.0)
	game.sound("thud"); return true

func apply_effect(target: Node3D, effect: String, duration: float = 15.0) -> void:
	PotionEffects.apply(target,effect,duration)

func show_map() -> void:
	game.maps.show_map()

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
	if id == VillageContent.ANVIL: NameTags.editor(game,list)
	if id in [VillageContent.ANVIL,VillageContent.GRINDSTONE,VillageContent.SMITHING_TABLE]:
		for i in game.inventory.slots.size():
			var slot: Dictionary = game.inventory.slots[i]
			if Nodes.durability(slot.id) <= 0 and slot.id != VillageContent.ENCHANTED_BOOK: continue
			var index: int = i
			if id == VillageContent.SMITHING_TABLE and Netherite.upgrade_id(slot.id) != 0:
				actions.append([Nodes.title(slot.id)+" → Netherite · 1 ingot + 1 template",func():
					if not Netherite.upgrade(game.inventory,index): game.toast("Bring one netherite ingot and one upgrade template.")
					else: game.achievements.award("serious_dedication"); game.sound("equip")
					show_station(p,id)])
			var description: String = "Remove enchantments, recover XP" if id == VillageContent.GRINDSTONE else ("Apply first compatible enchanted book · 1 XP level" if id == VillageContent.ANVIL else "Repair 25% · 1 matching material")
			actions.append([Nodes.title(slot.id)+" — "+description,func(): equipment_work(index,id); show_station(p,id)])
	elif id == VillageContent.STONECUTTER:
		for pair in [[Nodes.STONE,Nodes.BRICKS],[Nodes.BRICKS,VillageContent.CHISELED_BRICKS],[VillageContent.GRANITE,VillageContent.POLISHED_GRANITE],[VillageContent.DIORITE,VillageContent.POLISHED_DIORITE],[VillageContent.ANDESITE,VillageContent.POLISHED_ANDESITE],[VillageContent.QUARTZ_BLOCK,VillageContent.QUARTZ_PILLAR],[Nodes.DEEPSLATE,Nodes.POLISHED_DEEPSLATE]]:
			var input: int = pair[0]; var output: int = pair[1]
			actions.append(["1 "+Nodes.title(input)+" → 1 "+Nodes.title(output),func(): exchange([[input,1]],output)])
		# The source's own chiseled forms that are not stairs or slabs.
		for pair in [[PaleOak.RESIN_BRICK_BLOCK,PaleOak.CHISELED_RESIN_BRICK]]:
			var cin: int = pair[0]; var cout: int = pair[1]
			actions.append(["1 "+Nodes.title(cin)+" → 1 "+Nodes.title(cout),func(): exchange([[cin,1]],cout)])
		for base in BuildingShapes.MATERIALS+BuildingShapes.EXTRA_MATERIALS:
			for source in BuildingShapes.stonecutter_inputs(base):
				var input: int = source
				var slab: int = BuildingShapes.slab_for(base); var stair: int = BuildingShapes.stair_for(base)
				actions.append([BuildingShapes.title(slab)+" × 2 · 1 "+Nodes.title(input),func(): exchange([[input,1]],slab,2)])
				actions.append([BuildingShapes.title(stair)+" · 1 "+Nodes.title(input),func(): exchange([[input,1]],stair)])
		for i in Barriers.WALL_MATERIALS.size():
			for source in Barriers.stonecutter_inputs(Barriers.WALL_MATERIALS[i]):
				var input: int = source; var output: int = Barriers.WALL_FIRST+i
				actions.append([Nodes.title(output)+" · 1 "+Nodes.title(input),func(): exchange([[input,1]],output)])
		var masonry: Dictionary = Masonry.cuts()
		for magma_id in Magma.BLOCKS: masonry[magma_id] = true
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
		for i in game.inventory.slots.size():
			var slot: Dictionary = game.inventory.slots[i]
			if slot.id != VillageContent.FILLED_MAP: continue
			var index: int = i
			var data: Dictionary = slot.get("data",{})
			var identity: String = str(data.get("map",{}).get("id",""))
			var title: String = "Map #"+identity if not identity.is_empty() else "Unsaved map · slot "+str(i+1)
			if not str(data.get("custom_name","")).is_empty(): title += " · "+str(data.custom_name)
			actions.append(["Copy "+title+" · 1 empty map",func():
				if game.maps.copy_map(index): show_station(p,id)])
			actions.append(["View "+title,func(): game.maps.show_map(game.inventory.slots[index])])
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
	if actions.is_empty() and id != VillageContent.ANVIL: game.hud._label(panel,"Bring tools, armor or books to use this workstation.",Vector2(28,100),16,game.hud.MUTED)
	game.hud._button(panel,"Done",Rect2(24,496,704,40),game.resume)

# `mcl_anvils.damage_anvil_by_using`: the anvil is damaged by **taking the result**,
# not by opening the menu, so the roll runs only after a successful operation.
func equipment_work(index: int, device: int) -> bool:
	var worked: bool = _equipment_work(index,device)
	if worked and device == VillageContent.ANVIL: _damage_anvil()
	return worked

func _damage_anvil() -> void:
	var level: int = [VillageContent.ANVIL,11446,11447].find(game.world.node_at(workstation_pos))
	if level < 0: return
	var next: int = Anvils.use_damage(level)
	if next < 0: return
	if next >= Anvils.MAX_DAMAGE:
		if game.world.set_node(workstation_pos,Nodes.AIR):
			game.sound("break"); game.toast("The anvil breaks apart.")
			if game.gamemode != "creative": game.spawn_drop(Vector3(workstation_pos)+Vector3.ONE*0.5,VillageContent.ANVIL,1)
		game.resume(); return
	game.world.set_node(workstation_pos,[VillageContent.ANVIL,11446,11447][next])
	game.sound("dig")

func _equipment_work(index: int, device: int) -> bool:
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
		# `mcl_smithing_table`: a template plus a trim material trims a piece of
		# armor, and re-applying the same overlay and material is refused.
		if ArmorTrims.trimmable(slot.id):
			for template_index in game.inventory.slots.size():
				var template: Dictionary = game.inventory.slots[template_index]
				if template_index == index or not ArmorTrims.is_template(template.id): continue
				for material_index in game.inventory.slots.size():
					var material: Dictionary = game.inventory.slots[material_index]
					if material_index in [index,template_index] or not ArmorTrims.is_material(material.id): continue
					if not ArmorTrims.apply(slot,template.id,material.id):
						game.toast("That armor already carries this trim."); return false
					# The source consumes all three inputs (`take_item` on the item,
					# the mineral and the template), so one template trims once.
					material.count -= 1
					if material.count <= 0: material.clear(); material.merge({"id":0,"count":0,"wear":0})
					template.count -= 1
					if template.count <= 0: template.clear(); template.merge({"id":0,"count":0,"wear":0})
					game.inventory.changed.emit()
					game.toast("Trim applied: "+ArmorTrims.title(template.id).replace(" armor trim template","")+".")
					game.achievements.award("crafting_a_new_look")
					# `smithing_with_style` counts **distinct** trims, so the overlay key
					# is what advances the counter rather than the application count.
					game.achievements.track_distinct("smithing_with_style",ArmorTrims.key(template.id))
					return true
		if slot.wear <= 0: game.toast("This item needs no repair."); return false
		var material: int = Anvils.repair_material(slot.id)
		material = VillageContent.DATA.get(slot.id,{}).get("repair_material",material)
		if material == 0 or game.inventory.count_item(material) <= 0:
			game.toast("Repair needs "+Nodes.title(material)+"."); return false
		# `mcl_anvils`: up to four materials are consumed for 25/50/75/100%, and
		# each repair adds one to the prior-work penalty.
		var plan: Dictionary = Anvils.material_repair(slot,game.inventory.count_item(material),material)
		if plan.is_empty(): game.toast("That material does not repair this item."); return false
		game.inventory.remove_item(material,int(plan.materials))
		slot.wear = int(plan.wear)
		Anvils.add_pwp(slot)
		game.inventory.changed.emit(); return true
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
		# `mcl_anvils`: the cost is the enchanting level requirement plus the
		# prior-work penalty on *both* inputs, and the result takes max(p1,p2)+1.
		var cost: int = 2+Anvils.pwp_cost(slot)+Anvils.pwp_cost(book)
		if game.experience < cost and game.gamemode != "creative":
			game.toast("This needs %d experience points." % cost); return false
		Anvils.combine_pwp(slot,book)
		book.clear(); book.merge({"id":0,"count":0,"wear":0})
		game.experience = maxf(0,game.experience-cost); game.inventory.changed.emit(); return true
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
	if stored.id == VillageContent.FILLED_MAP: game.maps.ensure(stored)
	if game.inventory.held().id == VillageContent.FILLED_MAP: game.maps.ensure(game.inventory.held())
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
	for key in Paintings.records(game.world):
		var entry: Dictionary = Paintings.records(game.world)[key]
		var anchor: Vector3i = Paintings.anchor_of(key)
		if not game.world.loaded_at(Vector3(anchor)) or Vector3(anchor).distance_to(game.player.position) > 70: continue
		var model: MeshInstance3D = Paintings.display_model(game,anchor,entry)
		game.entities.add_child(model); displays["paint:"+key] = model
	for key in game.world.stations:
		var station: Dictionary = game.world.stations[key]
		if station.get("kind","") not in ["frame","banner","composter","cauldron","campfire","sign"]: continue
		var xyz: PackedStringArray = key.split(",")
		if xyz.size() != 3: continue
		var p := Vector3i(int(xyz[0]),int(xyz[1]),int(xyz[2]))
		if not game.world.loaded_at(Vector3(p)) or Vector3(p).distance_to(game.player.position) > 70: continue
		if station.kind == "sign" and Signs.is_sign(game.world.node_at(p)):
			var sign_model: Node3D = Signs.display_model(game,p,Signs.station(game.world,p))
			game.entities.add_child(sign_model); displays[key] = sign_model
			continue
		if station.kind == "campfire" and Campfires.is_campfire(game.world.node_at(p)):
			var campfire: Node3D = Campfires.display_model(game,p,station)
			game.entities.add_child(campfire); displays[key] = campfire
			continue
		var mesh := MeshInstance3D.new()
		if station.kind == "composter" and game.world.node_at(p) == VillageContent.COMPOSTER:
			mesh.free(); mesh = Composters.fill_model(station); mesh.position += Vector3(p)
		elif station.kind == "cauldron" and game.world.node_at(p) == VillageContent.CAULDRON:
			mesh.free(); mesh = Cauldrons.fill_model(station); mesh.position += Vector3(p)
		elif station.kind == "frame" and station.slots[0].id != 0 and game.world.node_at(p) == VillageContent.ITEM_FRAME:
			var id: int = station.slots[0].id
			if id == VillageContent.FILLED_MAP:
				mesh.free(); mesh = game.maps.frame_model(station.slots[0]); mesh.position = Vector3(p)+Vector3(0.5,0.5,-0.025)
			else:
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
		if animal is RuralAnimal and animal.kind == "horse" and not animal.is_queued_for_deletion() and not game.leads.attached(animal) and not Boats.is_passenger(animal):
			result.append({"kind":animal.kind,"position":[animal.position.x,animal.position.y,animal.position.z],"health":animal.health,"custom_name":animal.custom_name,"trust":animal.trust,"saddled":animal.saddled,"horse_armor":animal.horse_armor})
	return result

func restore_animals(saved: Array) -> void:
	for entry in saved:
		if entry.get("kind","") not in ["rabbit","horse"]: continue
		var animal: Creature = game.spawn_creature(entry.kind,VillageLife.vec(entry.position))
		animal.health = entry.get("health",animal.health); animal.trust = entry.get("trust",0)
		animal.custom_name = NameTags.bounded(str(entry.get("custom_name","")),30); NameTags.refresh(animal)
		if entry.get("saddled",false): animal.equip_saddle()
		if entry.get("horse_armor",false): animal.equip_horse_armor()

func restore_effects(value: Variant) -> void:
	PotionEffects.clear(game.player)
	if not value is Dictionary: return
	for effect in value:
		var duration: float = float(value[effect].get("duration",0)) if value[effect] is Dictionary else float(value[effect])
		var potency: int = int(value[effect].get("level",1)) if value[effect] is Dictionary else 1
		if effect in PotionEffects.NAMES and is_finite(duration) and duration > 0:
			PotionEffects.apply(game.player,effect,minf(6000,duration),clampi(potency,1,6))
			if effect == "absorption" and value[effect] is Dictionary: PotionEffects.restore_absorption(game.player,value[effect].get("remaining",4.0*potency))

func effect_snapshot() -> Dictionary:
	return PotionEffects.snapshot(game.player)

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
	return Weather.weather(game.world)

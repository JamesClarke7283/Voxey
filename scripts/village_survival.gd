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

func update_shield(delta: float) -> void:
	shield_disabled = maxf(0,shield_disabled-delta)
	# A shield is raised while the player holds it with sneak, which is the
	# source's own held state.
	shield_raised = (Shields.is_shield(int(game.inventory.held().id)) or Shields.is_shield(game.player.offhand_id())) and (Input.is_physical_key_pressed(KEY_CTRL) or (game.touch and is_instance_valid(game.controls) and game.controls.sneak_held))

func update(delta: float) -> void:
	update_shield(delta)
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
	# `mcl_buckets`' capture: a water bucket right-clicked on a fish scoops it up
	# alive, carrying its name into the bucket's metadata.
	# The axolotl's bucket keeps its colour as well as its name.
	if Axolotls.capture(game,mob):
		game.achievements.award("cutest_predator")
		return true
	if FishBuckets.capture(game,mob):
		game.achievements.award("tactical_fishing")
		return true
	# `dolphin:on_rightclick`: a fish sends it looking for treasure.
	if mob != null and Dolphins.is_dolphin(mob.kind) and Dolphins.feed(game,mob): return true
	if Golems.use(game,mob): return true
	if mob != null and Cats.is_cat(mob.kind) and Cats.use(game,mob): return true
	if mob != null and Parrots.is_parrot(mob.kind) and Parrots.use(game,mob): return true
	if Farming.use(game,mob): return true
	if MooshroomStew.use(game,mob): return true
	if held == Nodes.COMPASS and not target.is_empty() and target.id == Bastions.LODESTONE: return Lodestones.bind(game,target.pos)
	if mob is NetherResident and held == Nodes.GOLD:
		if not mob.barter(): game.toast("This piglin will not barter right now.")
		return true
	if Pouches.is_pouch(held): open_pouch(game.inventory.selected); return true
	if mob != null and (held == VillageContent.LEAD or held == 0 and game.leads.attached(mob)):
		if game.leads.attached(mob): game.leads.detach(mob)
		else: game.leads.attach(mob)
		return true
	# The horse family's taming, food, saddle, armour, chest and mounting
	# (`Equines.use`). Riding one already mounted dismounts.
	if mob is RuralAnimal and Equines.is_equine(mob.kind):
		if mob == mount: mount = null; game.toast("Dismounted."); return true
		return Equines.use(game,mob)
	if mob is RuralAnimal and mob.kind in ["pig",Striders.KIND] and PigRiding.mountable(mob):
		# `pig.lua`:206-227 — the driver's own click with a steering item starts the
		# boost and wears the stick; without one the click falls through to detach.
		if mob == mount and PigRiding.use_stick(game): return true
		if held == Nodes.SADDLE and not mob.saddled:
			PigRiding.equip_saddle(mob); _consume(); return true
		if held == Nodes.SHEARS and mob.saddled:
			# `pig.lua`:191-204: the saddle drops beside the pig and the shears take
			# the source's own `shearsy` wear.
			PigRiding.unsaddle(mob); game.spawn_drop(mob.position,Nodes.SADDLE)
			if game.gamemode != "creative": game.inventory.damage_tool()
			return true
		if mob == mount: mount = null; game.toast("Dismounted."); return true
		if PigRiding.can_mount(mob,held):
			if game.boats.ridden(): game.toast("Leave the boat before mounting a pig."); return true
			mount = mob; game.toast("Mounted. Look where you want to go, Ctrl to dismount."); return true
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
		_consume(); XpOrbs.throw_xp(game,game.player.position+Vector3.UP,randi_range(3,11)); game.puff(game.player.position+Vector3.UP,Color("9ad964"),15); return true
	if not target.is_empty() and target.id == VillageContent.CAULDRON and not Input.is_physical_key_pressed(KEY_CTRL):
		# `mcl_armor`/`mcl_banners`: washing a dyed leather piece or stripping a
		# banner's top layer runs **before** the liquid transaction, or a held piece
		# of armour would be treated as a bottle or bucket instead. The station is
		# fetched here so the wash can spend one level.
		var cauldron: Dictionary = Cauldrons.station(game.world,target.pos)
		if CauldronWash.wash(game,target.pos,cauldron,game.inventory.held()):
			game.inventory.changed.emit()
			game.toast("Washed clean.")
			return true
		return Cauldrons.use(game,target.pos)
	# `mcl_core.bottle_dirt`: only the pointed host converts. Direct creative use
	# preserves the water bottle and creates no empty glass bottle.
	if held == VillageContent.WATER_BOTTLE and not target.is_empty() and MudBottles.convert(game,target.pos): return true
	if PotionCatalog.is_bottle(held):
		if PotionCatalog.ITEMS[held].form == "drink":
			PotionEffects.apply_item(game.player,held,1.0,game.inventory.held().get("data",{})); _consume()
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
	if target.is_empty(): return false
	var p: Vector3i = target.pos; var id: int = target.id
	if held == VillageContent.GLASS_BOTTLE and Fluids.water(id):
		_consume(); give(VillageContent.WATER_BOTTLE,1); return true
	# `mcl_buckets`' fish buckets: using one against a replaceable cell releases the
	# **live** fish it carries and returns an empty bucket. The old path placed water
	# and dropped a raw cod item, so a bucketed fish could never be released alive.
	if FishBuckets.is_fish_bucket(held) and FishBuckets.place(game,target): return true
	if CocoaCrops.use(game,target): return true
	if held == VillageContent.KELP and id == Nodes.WATER and game.world.node_at(p+Vector3i.DOWN) != Nodes.AIR:
		game.world.set_node(p,VillageContent.KELP_PLANT); _consume(); return true
	if held == VillageContent.LILY_PAD and id == Nodes.WATER and game.world.node_at(p+Vector3i.UP) == Nodes.AIR:
		game.world.set_node(p+Vector3i.UP,held); _consume(); return true
	if SweetBerryCrops.use(game,target): return true
	if CropFarming.use(game,target): return true
	if NetherWartCrops.use(game,target): return true
	# `mcl_itemframes`: a glow ink sac clicked onto a frame changes its form rather
	# than being placed, so this test precedes the take path. `GlowInk.apply` refuses
	# anything that is not a frame or a sign, and a sign never reaches here because
	# `Signs.use` already returned.
	if GlowInk.is_glow_ink(held) and GlowInk.apply(game,{"id":id,"pos":p,"distance":0.0}): return true
	if id == VillageContent.ITEM_FRAME:
		frame_item(p); return true
	if not Input.is_physical_key_pressed(KEY_CTRL):
		if PortableStorage.interact(game,p): return true
		if id == VillageContent.BELL: game.villages.ring_bell(p); return true
		if VillageContent.is_bed(id): game.sleep_at(p); return true
		if id in [VillageContent.WOODEN_DOOR,VillageContent.WOODEN_DOOR_OPEN]: toggle_door(p); return true
		if id == VillageContent.BREWING_STAND: game.open_inventory("brewing",p); return true
		if id in [VillageContent.BARREL,VillageContent.RECOVERY_CHEST]: PiglinAnger.on_container_opened(game); game.open_inventory("chest",p); return true
		# `mcl_books`: a plain bookshelf is a 27-slot container, opened like a chest.
		if id == Nodes.BOOKSHELF: game.open_inventory("chest",p); return true
		if TrappedChests.is_trapped(id):
			# Its signal lasts as long as the screen is open, so the close path must
			# know which chest it was.
			TrappedChests.remember(game,p)
			TrappedChests.open(game,p); return true
		if id in [VillageContent.SMOKER,VillageContent.BLAST_FURNACE]:
			var station: Dictionary = game.world.get_station(p,"furnace"); station.device = id
			game.open_inventory("furnace",p); return true
		if id == VillageContent.COMPOSTER: Composters.interact(game,p); return true
		if id == VillageContent.SMITHING_TABLE: game.open_inventory("smithing",p); return true
		if GrindstoneRepair.is_grindstone(id): game.open_inventory("grindstone",p); return true
		if Stonecutting.is_cutter(id): game.open_inventory("stonecutter",p); return true
		if Bookshelves.use(game,target): return true
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
	# Kept for callers that request use; loaded crossbows fire through Attack.
	CrossbowUse.begin(game.player)

func blocks_damage(source: Vector3, kind: String = "generic", damage: float = 3.0) -> bool:
	if not Shields.can_block(game.player,source,kind): return false
	Shields.add_wear(game.player,damage)
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

# `mcl_lectern`: the text of the lectern's current page, sliced from the book body.
# The source keeps a real `pages` array; Voxey stores one string, so the slice is
# `256` characters per page, which is the same size the source's reader shows.
static func _lectern_page(station: Dictionary) -> String:
	var body: String = str(station.book.get("text",""))
	if int(station.get("pages",1)) <= 1: return body
	var page: int = clampi(int(station.get("page",1)),1,int(station.pages))
	var per: int = maxi(1,ceili(body.length()/float(station.pages)))
	return body.substr((page-1)*per,per)

func show_station(p: Vector3i, id: int) -> void:
	if id == VillageContent.SMITHING_TABLE: game.open_inventory("smithing",p); return
	if GrindstoneRepair.is_grindstone(id): game.open_inventory("grindstone",p); return
	if Stonecutting.is_cutter(id): game.open_inventory("stonecutter",p); return
	if id == VillageContent.LOOM: Banners.show_loom(game,p); return
	if id in [VillageContent.ANVIL,11446,11447]: AnvilWorkbench.show(game,p); return
	workstation_pos = p; workstation_id = id
	game.state = "workstation"; game.world.active = false; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.hud._clear(); game.hud.screen = "workstation"; game.hud._dim()
	var panel: Panel = game.hud._fitted_panel(Vector2(750,560))
	game.hud._label(panel,Nodes.title(id).to_upper(),Vector2(26,18),26,game.hud.ACCENT)
	var scroll := ScrollContainer.new(); scroll.position = Vector2(24,67); scroll.size = Vector2(704,404); panel.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",7); scroll.add_child(list)
	var actions: Array = []
	if id == VillageContent.CARTOGRAPHY_TABLE:
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
			# `mcl_lectern`: the book is split into pages and the comparator reads the
			# page number (`measure_lectern`). Pages are derived from the text, since
			# Voxey stores a written book's body as one string.
			if not station.has("pages"):
				# A written book may carry its own page split; otherwise split the text
				# into pages of roughly 256 characters.
				var book: Dictionary = station.book
				station.pages = maxi(1,int(book.get("pages",0))) if int(book.get("pages",0)) > 0 else maxi(1,ceili(str(book.get("text","")).length()/256.0))
				station.page = 1
			var page_text := Label.new(); page_text.text = str(station.book.get("title","Book"))+"\n\n"+_lectern_page(station); page_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; page_text.custom_minimum_size.x = 650; list.add_child(page_text)
			var nav := Label.new(); nav.text = "Page %d / %d"%[int(station.page),int(station.pages)]; list.add_child(nav)
			if int(station.pages) > 1:
				actions.append(["Previous page",func(): station.page = maxi(1,int(station.page)-1); show_station(p,id)])
				actions.append(["Next page",func(): station.page = mini(int(station.pages),int(station.page)+1); show_station(p,id)])
			actions.append(["Take book",func():
				if game.inventory.capacity(Nodes.WRITTEN_BOOK,0,station.book) >= 1: give(Nodes.WRITTEN_BOOK,1,station.book); station.erase("book"); station.erase("pages"); station.erase("page"); show_station(p,id)])
		else:
			actions.append(["Place a signed book from your inventory",func():
				for slot in game.inventory.slots:
					if slot.id == Nodes.WRITTEN_BOOK:
						station.book = slot.get("data",{}).duplicate(true); station.erase("pages"); station.erase("page"); slot.clear(); slot.merge({"id":0,"count":0,"wear":0}); game.inventory.changed.emit(); show_station(p,id); return
				game.toast("Write and sign a book first." )])
	for action in actions:
		var button := Button.new(); button.text = action[0]; button.custom_minimum_size = Vector2(680,48); button.pressed.connect(action[1]); list.add_child(button)
	if actions.is_empty() and id != VillageContent.ANVIL: game.hud._label(panel,"Bring tools, armor or books to use this workstation.",Vector2(28,100),16,game.hud.MUTED)
	game.hud._button(panel,"Done",Rect2(24,496,704,40),game.resume)

# `mcl_anvils.damage_anvil_by_using`: the anvil is damaged by **taking the result**,
# not by opening the menu, so the roll runs only after a successful operation.
func equipment_work(index: int, device: int) -> bool:
	return _equipment_work(index,device)

func _damage_anvil() -> void:
	damage_anvil(workstation_pos)

# `mcl_anvils.damage_anvil`: one level per call, and the third destroys the anvil
# and returns it as a drop. Split out of the workstation path so a falling anvil
# can damage itself through `FallingDamage.anvil_self_damage`.
func damage_anvil(p: Vector3i) -> bool:
	var level: int = [VillageContent.ANVIL,11446,11447].find(game.world.node_at(p))
	if level < 0: return false
	var next: int = Anvils.use_damage(level)
	if next < 0: return false
	if next >= Anvils.MAX_DAMAGE:
		if game.world.set_node(p,Nodes.AIR):
			game.sound("break"); game.toast("The anvil breaks apart.")
		if game.state == "workstation": game.resume()
		return true
	game.world.set_node(p,[VillageContent.ANVIL,11446,11447][next])
	game.sound("dig")
	return false

func _equipment_work(index: int, device: int) -> bool:
	if index < 0 or index >= game.inventory.slots.size(): return false
	var slot: Dictionary = game.inventory.slots[index]
	if slot.id == 0: return false
	if device != VillageContent.ANVIL: return false
	# Legacy scripted callers may still request an automatic book operation. The
	# actual workstation uses explicit inputs and the same pure source plan.
	for other in game.inventory.slots.size():
		if other == index: continue
		var preview: Dictionary = Anvils.plan(slot,game.inventory.slots[other])
		if preview.is_empty(): continue
		return AnvilWorkbench.use(game,workstation_pos,index,other)
	game.toast("Choose compatible inputs at the anvil."); return false

func ammunition() -> int:
	for slot in game.inventory.slots:
		if slot.id == Nodes.ARROW_ITEM or VillageContent.DATA.get(slot.id,{}).get("family","") == "arrow": return slot.id
	return 0

func ride_step(delta: float, input: Vector3) -> void:
	if not is_instance_valid(mount): mount = null; return
	# `mcl_mobs`' `mount.lua`: a pig is driven by its rider's gaze rather than by the
	# movement input, and holding a carrot on a stick adds the source's timed boost.
	if mount.kind in ["pig",Striders.KIND]:
		if Input.is_physical_key_pressed(KEY_CTRL):
			game.player.position = mount.position+Vector3(1,0.1,0); mount = null; return
		PigRiding.steer(game,mount,delta,-game.player.camera.global_basis.z)
		game.player.position = mount.position+Vector3.UP*1.1
		game.player.velocity = Vector3.ZERO
		return
	var horse: RuralAnimal = mount
	if Input.is_physical_key_pressed(KEY_CTRL):
		game.player.position = horse.position+Vector3(1,0.1,0); mount = null; return
	# `horse:should_drive`: only a tamed, saddled horse answers the reins. An
	# untamed one wanders while it decides whether to throw its rider.
	var drivable: bool = not Equines.is_equine(horse.kind) or Equines.drivable(horse)
	var direction: Vector3 = game.player.global_basis*input.normalized() if drivable else horse.direction
	var top: float = Equines.ride_speed(horse) if Equines.is_equine(horse.kind) else 8.0
	if not drivable: top = float(horse.info().speed)
	horse.velocity.x = direction.x*top; horse.velocity.z = direction.z*top
	horse.velocity.y -= 22*delta
	var on_ground: bool = game.world.intersects(horse.position-Vector3.UP*0.05,horse.width,horse.height)
	if drivable and Equines.is_equine(horse.kind):
		# `post_apply_driver_input`: holding jump charges it, and letting go on the
		# ground leaps by the charged share of this horse's own jump strength.
		if Input.is_physical_key_pressed(KEY_SPACE): horse.set_meta("jump_charge",float(horse.get_meta("jump_charge",0.0))+delta)
		elif float(horse.get_meta("jump_charge",0.0)) > 0.0:
			if on_ground: horse.velocity.y = Equines.jump_scale(float(horse.get_meta("jump_charge")))*Equines.jump_velocity(horse)
			horse.set_meta("jump_charge",0.0)
	elif Input.is_physical_key_pressed(KEY_SPACE) and on_ground: horse.velocity.y = 9.5
	for axis in [0,2,1]:
		var next: Vector3 = horse.position; next[axis] += horse.velocity[axis]*delta
		if not game.world.intersects(next,horse.width,horse.height): horse.position = next
		elif axis == 1: horse.velocity.y = 0
	if drivable: horse.model.rotation.y = game.player.rotation.y
	elif direction.length() > 0.1: horse.model.rotation.y = atan2(-direction.x,-direction.z)
	game.player.position = horse.position+Vector3.UP*1.1
	game.player.velocity = Vector3.ZERO

func frame_item(p: Vector3i) -> void:
	# `mcl_itemframes/init.lua`:130-135 — a filled frame turns its item rather than
	# handing it over, and the source is explicit that the rotation wins. Voxey's
	# existing click takes the item out, which is the more useful default, so the turn
	# is on sneak instead; breaking the frame still returns both the frame and its
	# contents either way.
	if Signs.sneaking(game) and Frames.rotate(game,p): return
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
		if station.get("kind","") not in ["frame","banner","bookshelf","composter","cauldron","campfire","sign"]: continue
		var xyz: PackedStringArray = key.split(",")
		if xyz.size() != 3: continue
		var p := Vector3i(int(xyz[0]),int(xyz[1]),int(xyz[2]))
		if not game.world.loaded_at(Vector3(p)) or Vector3(p).distance_to(game.player.position) > 70: continue
		if station.kind == "sign" and Signs.is_any(game.world.node_at(p)):
			var sign_model: Node3D = Signs.display_model(game,p,Signs.station(game.world,p))
			game.entities.add_child(sign_model); displays[key] = sign_model
			continue
		if station.kind == "campfire" and Campfires.is_campfire(game.world.node_at(p)):
			var campfire: Node3D = Campfires.display_model(game,p,station)
			game.entities.add_child(campfire); displays[key] = campfire
			continue
		if station.kind == "bookshelf" and game.world.node_at(p) == Bookshelves.ID:
			var shelf: Node3D = Bookshelves.display_model(game.world,p)
			game.entities.add_child(shelf); displays[key] = shelf
			continue
		if station.kind == "banner" and Banners.is_banner(game.world.node_at(p)):
			var banner_model: Node3D = Banners.display_model(game.world,p)
			game.entities.add_child(banner_model); displays[key] = banner_model
			continue
		var mesh := MeshInstance3D.new()
		if station.kind == "composter" and game.world.node_at(p) == VillageContent.COMPOSTER:
			mesh.free(); mesh = Composters.fill_model(station); mesh.position += Vector3(p)
		elif station.kind == "cauldron" and game.world.node_at(p) == VillageContent.CAULDRON:
			mesh.free(); mesh = Cauldrons.fill_model(station); mesh.position += Vector3(p)
		elif station.kind == "frame" and station.slots[0].id != 0 and game.world.node_at(p) == VillageContent.ITEM_FRAME:
			# `mcl_itemframes/init.lua`: the framed item is a spinning entity whose
			# rotation is saved state, and a glow-ink form is self-lit.
			var frame_state: Dictionary = Frames.station(game.world,p)
			var id: int = station.slots[0].id
			if id == VillageContent.FILLED_MAP:
				mesh.free(); mesh = game.maps.frame_model(station.slots[0]); mesh.position = Vector3(p)+Vector3(0.5,0.5,-0.025)
			elif Shields.is_shield(id):
				mesh.free(); mesh = Shields.model(station.slots[0]); mesh.scale = Vector3.ONE*0.7; mesh.position = Vector3(p)+Vector3(0.5,0.5,-0.02)
			elif Banners.is_banner(id):
				var cloth := QuadMesh.new(); cloth.size = Vector2(0.65,0.65); mesh.mesh = cloth
				var material := StandardMaterial3D.new(); material.albedo_texture = Banners.texture(station.slots[0])
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; material.cull_mode = BaseMaterial3D.CULL_DISABLED; material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mesh.material_override = material; mesh.position = Vector3(p)+Vector3(0.5,0.5,-0.02)
			else:
				mesh.mesh = game.node_mesh(id) if Nodes.placeable(id) else ItemArt.mesh(id,3 if CrossbowUse.loaded_form(station.slots[0]) else -1)
				mesh.material_override = game.node_material if Nodes.placeable(id) else ItemArt.material(id,3 if CrossbowUse.loaded_form(station.slots[0]) else -1)
				mesh.scale = Vector3.ONE*0.4; mesh.position = Vector3(p)+Vector3(0.5,0.5,-0.02)
				if Nodes.placeable(id): mesh.position -= Vector3.ONE*0.2
			Frames.apply_display(mesh,id,frame_state)
		else: mesh.free(); continue
		game.entities.add_child(mesh); displays[key] = mesh

func animal_snapshot() -> Array:
	var result: Array = []
	for animal in game.creatures.get_children():
		if animal is RuralAnimal and Equines.is_equine(animal.kind) and not animal.is_queued_for_deletion() and not game.leads.attached(animal) and not Boats.is_passenger(animal):
			result.append({"kind":animal.kind,"position":[animal.position.x,animal.position.y,animal.position.z],"health":animal.health,"custom_name":animal.custom_name,"trust":animal.trust,"saddled":animal.saddled,"horse_armor":animal.horse_armor,"equine":Equines.snapshot(animal)})
	return result

func restore_animals(saved: Array) -> void:
	for entry in saved:
		if entry.get("kind","") != "rabbit" and not Equines.is_equine(str(entry.get("kind",""))): continue
		var animal: Creature = game.spawn_creature(entry.kind,VillageLife.vec(entry.position))
		animal.trust = entry.get("trust",0)
		if Equines.is_equine(animal.kind): Equines.restore(animal,entry.get("equine",{}))
		animal.health = entry.get("health",animal.health)
		animal.custom_name = NameTags.bounded(str(entry.get("custom_name","")),30); NameTags.refresh(animal)
		if entry.get("saddled",false): animal.equip_saddle()
		if entry.get("horse_armor",false) and not (entry.get("equine",{}) is Dictionary and int(entry.get("equine",{}).get("armor",0)) != 0): animal.equip_horse_armor()

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

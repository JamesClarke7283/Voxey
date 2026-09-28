extends RefCounted

# Leather dyeing and cauldron washing regression checks.
# Sources: ITEMS/mcl_armor/leather.lua (calculate_color :18, colorize :26,
# wash :51, shapeless dye recipe :107) and ITEMS/mcl_banners/init.lua (:480).

static func run(suite: Object, game: Node3D) -> void:
	# --- membership ----------------------------------------------------------
	for piece in 4:
		var id: int = Nodes.armor_id(0,piece)
		suite.check(CauldronWash.is_leather_armor(id),"leather piece %d is leather armour"%piece)
	suite.check(not CauldronWash.is_leather_armor(Nodes.armor_id(1,1)),"iron armour is not leather")
	suite.check(not CauldronWash.is_leather_armor(Nodes.ELYTRA),"the elytra is not leather armour")
	suite.check(not CauldronWash.is_leather_armor(Nodes.STICK) and not CauldronWash.is_leather_armor(0),"ordinary items and the empty slot are not leather armour")

	# --- the dye colour comes from the dye block -----------------------------
	# The source reads `mcl_dyes.colors[name].rgb`; Voxey reuses the dye block's
	# own colour, which is the same channel data.
	var red: Color = CauldronWash.dye_color_for(VillageContent.DYE_RED)
	suite.check(red.r8 == 184 and red.g8 == 61 and red.b8 == 65,"a dye's tint is its block colour (Nodes.color)")
	suite.check(CauldronWash.dye_color_for(Nodes.STICK) == Color.BLACK and CauldronWash.dye_color_for(Nodes.IRON) == Color.BLACK,"only a dye entry has a dye colour")

	# --- the first dye is exact, the second is averaged ----------------------
	# leather.lua:30-31 stores the colour as it is when the piece has none.
	var chest: Dictionary = {"id":Nodes.armor_id(0,1),"count":1,"wear":12}
	suite.check(CauldronWash.color_of(chest) == Color.BLACK and not CauldronWash.has_tint(chest),"untinted leather reports black and no tint")
	CauldronWash.tint(chest,red)
	suite.check(CauldronWash.color_of(chest) == Color("b83d41") and int(chest.data.color) == 0xb83d41,"the first dye is stored exactly as its own colour")
	suite.check(CauldronWash.has_tint(chest),"a dyed piece reports a tint")

	# leather.lua:18-24: av(a,b) = (a+b)/2 on each channel, and the byte is the
	# truncated quotient when the colourstring is rebuilt (leather.lua:31,40).
	# Red b8,3d,41 with white e4,e4,d7:
	#   r (184+228)/2 = 206.0 -> 206
	#   g  (61+228)/2 = 144.5 -> 144
	#   b  (65+215)/2 = 140.0 -> 140
	var averaged: int = (206<<16)|(144<<8)|140
	CauldronWash.tint(chest,CauldronWash.dye_color_for(VillageContent.DYE_WHITE))
	suite.check(int(chest.data.color) == averaged,"a second dye averages the stored colour channel-wise")
	suite.check(CauldronWash.color_of(chest) == Color8(206,144,140),"the averaged colour reads back through Color8")
	# The source returns early when the incoming colour equals the stored one
	# (leather.lua:34); the average of an equal pair is that colour anyway.
	var before: int = int(chest.data.color)
	CauldronWash.tint(chest,CauldronWash.color_of(chest))
	suite.check(int(chest.data.color) == before,"re-dyeing with the stored colour leaves it unchanged")
	suite.check(chest.wear == 12,"dyeing does not touch the piece's wear")
	var ingot: Dictionary = {"id":Nodes.IRON,"count":1}
	CauldronWash.tint(ingot,red)
	suite.check(not ingot.has("data"),"tinting a non-leather item writes nothing")
	# A saved slot whose `data` is not a dictionary must not break the read paths.
	var malformed: Dictionary = {"id":Nodes.armor_id(0,0),"count":1,"data":"not a dictionary"}
	suite.check(CauldronWash.color_of(malformed) == Color.BLACK and not CauldronWash.has_tint(malformed),"a slot with malformed metadata reads as untinted")
	CauldronWash.tint(malformed,red)
	suite.check(int(malformed.get("data",{}).get("color",-1)) == 0xb83d41,"tinting replaces malformed metadata with the dye colour")

	# --- the shapeless recipe -------------------------------------------------
	# leather.lua:126-146: exactly one leather piece and exactly one dye.
	# Blue is 49,66,ad, so averaging it with the stored 206,144,140 gives:
	#   r (206+73)/2  = 139.5 -> 139
	#   g (144+102)/2 = 123.0 -> 123
	#   b (140+173)/2 = 156.5 -> 156
	var crafted: Dictionary = CauldronWash.apply_craft([chest,{"id":VillageContent.DYE_BLUE,"count":1}])
	suite.check(crafted.get("id",0) == Nodes.armor_id(0,1) and crafted.get("count",0) == 1,"the craft returns the same leather piece")
	suite.check(int(crafted.get("data",{}).get("color",-1)) == ((139<<16)|(123<<8)|156),"the craft averages the dye with the piece's existing colour")
	var fresh: Dictionary = CauldronWash.apply_craft([{"id":Nodes.armor_id(0,3),"count":1,"wear":4},{"id":VillageContent.DYE_RED,"count":1}])
	suite.check(int(fresh.get("data",{}).get("color",-1)) == 0xb83d41 and fresh.wear == 4,"a fresh piece takes the dye exactly and keeps its wear")
	suite.check(CauldronWash.apply_craft([{"id":Nodes.armor_id(0,1),"count":1},{"id":Nodes.armor_id(0,2),"count":1}]).is_empty(),"two leather pieces are refused")
	suite.check(CauldronWash.apply_craft([{"id":Nodes.armor_id(0,1),"count":1},{"id":VillageContent.DYE_RED,"count":1},{"id":VillageContent.DYE_BLUE,"count":1}]).is_empty(),"two dyes are refused")
	suite.check(CauldronWash.apply_craft([{"id":Nodes.armor_id(0,1),"count":1},{"id":Nodes.IRON,"count":1}]).is_empty(),"a non-dye second item is refused")
	var entries: Array = CauldronWash.recipe_entries()
	suite.check(entries.size() == 64,"four leather pieces with sixteen dyes give sixty-four shapeless entries")
	var found_pair: bool = false
	for entry in entries:
		if entry[1] == Nodes.armor_id(0,0) and entry[3] == [Nodes.armor_id(0,0),VillageContent.DYE_WHITE]: found_pair = true
	suite.check(found_pair and entries[0][2] == 1 and (entries[0][3] as Array).size() == 2,"each entry is a one-piece shapeless recipe of the piece plus one dye")

	# --- the tint survives a save --------------------------------------------
	var saved: Dictionary = {"id":Nodes.armor_id(0,1),"count":1,"wear":12,"data":{"color":averaged,"custom_name":"Old tunic"}}
	var cleaned: Dictionary = Inventory.clean_slot(saved)
	suite.check(int(cleaned.get("data",{}).get("color",-1)) == averaged,"clean_slot keeps the armour tint")
	suite.check(str(cleaned.get("data",{}).get("custom_name","")) == "Old tunic","clean_slot keeps the rest of the metadata beside it")
	var round_trip: Dictionary = Inventory.clean_slot(JSON.parse_string(JSON.stringify(cleaned)))
	suite.check(int(round_trip.get("data",{}).get("color",-1)) == averaged,"the tint survives a JSON save round trip")
	suite.check(CauldronWash.color_of(round_trip) == CauldronWash.color_of(cleaned),"the reloaded colour matches the stored one")
	suite.check(int(Inventory.clean_slot({"id":Nodes.armor_id(0,1),"count":1,"data":{"color":-5}}).data.color) == 0,"a negative saved tint is clamped to black")

	# --- the live cauldron ----------------------------------------------------
	var p := Vector3i(floori(game.player.position.x),game.world.generator.terrain_ceiling()+6,floori(game.player.position.z))
	var key: String = VoxelWorld.station_key(p)
	game.world.set_node(p,Nodes.AIR)
	suite.check(game.world.loaded_at(Vector3(p)) and game.world.node_at(p) == Nodes.AIR,"the wash cell is a loaded, empty cell above the terrain")
	var had_station: bool = game.world.stations.has(key)
	var old_station: Variant = game.world.stations.get(key)

	suite.check(game.world.set_node(p,VillageContent.CAULDRON) and game.world.node_at(p) == VillageContent.CAULDRON,"a cauldron is placed on the wash cell")
	var station: Dictionary = game.world.get_station(p,"cauldron")
	Cauldrons.set_contents(station,3,"water")
	suite.check(Cauldrons.level(station) == 3 and Cauldrons.liquid(station) == "water","the station starts full of water")

	var washed: Dictionary = {"id":Nodes.armor_id(0,1),"count":1,"wear":0}
	CauldronWash.tint(washed,CauldronWash.dye_color_for(VillageContent.DYE_RED))
	suite.check(CauldronWash.can_wash(washed.id,washed) and CauldronWash.wash(game,p,station,washed),"washing a dyed chestplate acts")
	# leather.lua:51-57 clears the colour and leaves the item itself behind.
	suite.check(Cauldrons.level(station) == 2 and Cauldrons.liquid(station) == "water","washing spends exactly one water level")
	suite.check(not CauldronWash.has_tint(washed) and CauldronWash.color_of(washed) == Color.BLACK,"washing clears the piece's dye")
	suite.check(washed.id == Nodes.armor_id(0,1) and washed.count == 1,"the washed piece is the same item, not a replacement")
	suite.check(not CauldronWash.can_wash(washed.id,washed) and not CauldronWash.wash(game,p,station,washed),"washing clean leather is refused")
	suite.check(Cauldrons.level(station) == 2,"the refused wash spends no further water")
	suite.check(not CauldronWash.wash(game,p,station,{"id":Nodes.armor_id(1,1),"count":1}) and Cauldrons.level(station) == 2,"washing iron armour spends no water")
	CauldronWash.tint(washed,CauldronWash.dye_color_for(VillageContent.DYE_RED))
	suite.check(CauldronWash.wash(game,p,station,washed) and Cauldrons.level(station) == 1,"a second wash takes the cauldron to one level")

	# --- the banner's topmost layer ------------------------------------------
	# mcl_banners/init.lua:486 removes the last layer, which is the newest one.
	var banner: Dictionary = {"id":VillageContent.BANNER_FIRST,"count":1}
	suite.check(Banners.emblazon(banner,"border",0) and Banners.emblazon(banner,"circle",3),"a banner carries two emblazoned layers")
	suite.check(CauldronWash.can_wash(banner.id,banner),"an emblazoned banner can be washed")
	Cauldrons.set_contents(station,3,"water")
	suite.check(CauldronWash.wash(game,p,station,banner) and Cauldrons.level(station) == 2,"washing a banner spends one water level")
	var layers: Array = Banners.layers(banner)
	suite.check(layers.size() == 1 and str(layers[0].get("pattern","")) == "border" and int(layers[0].get("color",-1)) == 0,"only the banner's topmost layer was removed")
	suite.check(CauldronWash.wash(game,p,station,banner) and Banners.layers(banner).is_empty() and Cauldrons.level(station) == 1,"a second wash removes the remaining layer")
	suite.check(not CauldronWash.can_wash(banner.id,banner),"a plain banner has nothing to wash")
	suite.check(not CauldronWash.wash(game,p,station,banner) and Cauldrons.level(station) == 1,"washing a plain banner spends no water")

	# --- an unusable cauldron -------------------------------------------------
	Cauldrons.set_contents(station,0,"water")
	CauldronWash.tint(washed,CauldronWash.dye_color_for(VillageContent.DYE_RED))
	suite.check(not CauldronWash.wash(game,p,station,washed) and CauldronWash.has_tint(washed),"an empty cauldron washes nothing")
	Cauldrons.set_contents(station,3,"lava")
	suite.check(not CauldronWash.wash(game,p,station,washed) and Cauldrons.level(station) == 3,"a lava cauldron does not wash")
	Cauldrons.set_contents(station,3,"water")
	game.world.set_node(p,Nodes.AIR)
	suite.check(not CauldronWash.wash(game,p,station,washed) and Cauldrons.level(station) == 3,"a removed cauldron cannot spend its stale station's water")

	# --- restore --------------------------------------------------------------
	if had_station: game.world.stations[key] = old_station
	else: game.world.stations.erase(key)
	suite.check(game.world.node_at(p) == Nodes.AIR and not game.world.stations.has(key),"the wash cell and its station are restored")

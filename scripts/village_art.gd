class_name VillageArt
extends RefCounted

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if Beacons.is_beacon(id) or Beacons.is_beam(id): return Beacons.pixel(id,x,y,noise)
	if Seagrass.is_seagrass(id): return Seagrass.pixel(id,x,y,noise)
	if SeaPickles.is_pickle(id): return SeaPickles.pixel(id,x,y,noise)
	if Corals.is_coral(id): return Corals.pixel(id,x,y,noise)
	if Conduits.is_ocean(id): return Conduits.pixel(id,x,y,noise)
	if Scaffolding.is_scaffolding(id): return Scaffolding.pixel(id,x,y,noise)
	if Heads.is_any(id): return Heads.pixel(id,x,y,noise)
	if Rails.DATA.has(id): return Rails.pixel(id,x,y,noise)
	if Archaeology.DATA.has(id): return Archaeology.pixel(id,x,y,noise)
	if Decor.is_pot(id) or Decor.is_stand(id): return Decor.pixel(id,x,y,noise)
	if Sponges.is_sponge(id): return Sponges.pixel(id,x,y,noise)
	if id == Nodes.COPPER_NODE or Copper.DATA.has(id): return Copper.pixel(id,x,y,noise)
	if Beehives.DATA.has(id): return Beehives.pixel(id,x,y,noise)
	if Amethyst.is_amethyst(id): return Amethyst.pixel(id,x,y,noise)
	if Farmland.is_soil(id): return Farmland.pixel(id,x,y,noise)
	if CropFarming.is_crop(id): return CropFarming.pixel(id,x,y,noise)
	if FruitCrops.DATA.has(id): return FruitCrops.pixel(id,x,y,noise)
	if id in DenseMaterials.BLOCKS: return DenseMaterials.pixel(id,x,y,noise)
	if Concrete.is_concrete_family(id): return Concrete.pixel(id,x,y,noise)
	if Candles.is_candle(id): return Candles.pixel(id,x,y,noise)
	# The candled cake draws its candles over the cake texture, like the mesh does.
	if Candles.is_cake(id): return Candles.pixel(id,x,y,noise)
	if id >= NetherBlocks.RED_NETHER_BRICKS and id <= NetherBlocks.SOUL_FIRE: return NetherBlocks.pixel(id,x,y,noise)
	if GlassColors.is_stained(id): return GlassColors.pixel(id,x,y,noise)
	if id >= EndMud.PURPUR_PILLAR and id <= EndMud.MUD_BRICKS: return EndMud.pixel(id,x,y,noise)
	if id >= FlowersExtra.TULIP_ORANGE and id <= FlowersExtra.PINK_PETALS: return FlowersExtra.pixel(id,x,y,noise)
	if id >= Sculk.SCULK and id <= Sculk.CATALYST: return Sculk.pixel(id,x,y,noise)
	if id >= NetherBlocks.RED_NETHER_BRICKS and id <= NetherBlocks.SOUL_FIRE: return NetherBlocks.pixel(id,x,y,noise)
	if id in RawOres.BLOCKS: return RawOres.pixel(id,x,y,noise)
	if id >= LushCaveExtra.ROOTED_DIRT and id <= LushCaveExtra.DRIPLEAF_BIG_TIPPED_FULL: return LushCaveExtra.pixel(id,x,y,noise)
	if id >= CrimsonPlants.CRIMSON_FUNGUS and id <= CrimsonPlants.WARPED_WART_BLOCK: return CrimsonPlants.pixel(id,x,y,noise)
	if id >= PaleOak.RESIN_BLOCK and id <= PaleOak.EYEBLOSSOM_OPEN: return PaleOak.pixel(id,x,y,noise)
	if id >= CopperDecor.LANTERN_FLOOR and id <= CopperDecor.BARS+CopperDecor.STAGES-1: return CopperDecor.pixel(id,x,y,noise)
	if id == Bookshelves.ID: return Bookshelves.pixel(id,x,y,noise)
	if id == Dungeons.SPAWNER: return Dungeons.pixel(id,x,y,noise)
	if id == Jukeboxes.ID: return Jukeboxes.pixel(id,x,y,noise)
	if id == NoteBlocks.ID: return NoteBlocks.pixel(id,x,y,noise)
	if RespawnAnchors.is_anchor(id): return RespawnAnchors.pixel(id,x,y)
	if HugeMushrooms.is_huge(id): return HugeMushrooms.pixel(id,x,y)
	if FoodFeatures.flower(id): return FoodFeatures.flower_pixel(id,x,y)
	if FoodFeatures.is_tall_grass(id): return FoodFeatures.tall_grass_pixel(x,y)
	if RedstoneSensors.is_device(id): return RedstoneSensors.pixel(id,x,y,noise)
	if PortableStorage.is_storage(id): return PortableStorage.pixel(id,x,y,noise)
	if id in Masonry.BLOCKS: return Masonry.pixel(id,x,y,noise)
	if Magma.is_magma(id): return Magma.pixel(id,x,y,noise)
	if TrappedChests.is_trapped(id): return TrappedChests.pixel(id,x,y,noise)
	# An infested block must be indistinguishable from the block it hides, which is
	# the source's whole point. Only the masonry variants (cracked, mossy and
	# chiseled bricks) have a per-pixel pattern here; stone, cobblestone and plain
	# bricks are rendered as a noisy base colour by `art.gd`, so returning coloured
	# noise is what matches them. Returning a pattern for those would make an
	# infested stone visibly different from a real one.
	if MonsterEggs.is_infested(id):
		var disguise: int = MonsterEggs.base_block(id)
		return Masonry.pixel(disguise,x,y,noise) if disguise in Masonry.BLOCKS else noise
	var d: Dictionary = VillageContent.DATA[id]
	var base := Color(d.color)
	var shape: String = d.get("shape","cube")
	if Fire.is_fire(id):
		return Color("ffe87a") if y > 10 and x in range(4,12) else (Color("ef8a30") if y > (x*7)%11 else Color.TRANSPARENT)
	if id == VillageContent.COBWEB:
		var web: bool = x == y or x+y == 15 or x in [7,8] or y in [7,8] or maxi(absi(x-7),absi(y-7)) in [3,6]
		return Color("d9e2d7") if web else Color.TRANSPARENT
	if id == VillageContent.LILY_PAD: return Color.TRANSPARENT if (x < 4 and y < 4) or Vector2(x-7.5,y-7.5).length() > 7.5 else noise
	if id == VillageContent.SWAMP_GRASS: return noise.darkened(0.07) if y%5 == 0 else noise
	if shape == "crop":
		var stem: bool = y >= 13-int(d.stage)*3 and (x%5 == 2 or ((x+y)%7 < 2 and y > 5))
		if not stem: return Color.TRANSPARENT
		return base if d.stage == 3 and y > 11 else Color("609143")
	if id in [Bastions.BRICKS,Bastions.POLISHED]:
		return base.darkened(0.45) if y%8 == 0 or posmod(x+(8 if y/8%2 else 0),16) == 0 else noise
	if id == Bastions.CHISELED:
		return base.darkened(0.5) if maxi(absi(x-7),absi(y-7)) in [4,6] else noise
	if id in [Bastions.GILDED,MinecloniaOres.NETHER_GOLD]:
		return Color("e2b74d") if (x/2*7+y/2*11)%13 < 3 else noise.darkened(0.22)
	if id == Bastions.CRYING_OBSIDIAN:
		return Color("a773ce") if x%5 == 0 and y%7 in [3,4,5] else noise.darkened(0.23)
	if id == Bastions.LODESTONE:
		return base.darkened(0.45) if x in [1,14] or y in [1,14] or maxi(absi(x-7),absi(y-7)) in [2,4] else noise
	if id == Netherite.ANCIENT_DEBRIS:
		var ring: int = maxi(absi(x-7),absi(y-7))
		return Color("b38b79") if ring%4 == 1 else (Color("453835") if ring%4 == 0 else noise)
	if id == Netherite.BLOCK:
		return base.lightened(0.2) if x in [1,14] or y in [1,14] else (base.darkened(0.25) if x in [0,15] or y in [0,15,7,8] else noise)
	if id == VillageContent.RECOVERY_CHEST:
		if x in [0,1,14,15] or y in [0,1,6,7,14,15]: return Color("4c4c44")
		if (x in range(5,11) and y in [9,10]) or (x in [4,5,10,11] and y in [8,11]): return Color("e6ddbd")
		return noise.darkened(0.12) if x%4 == 0 else noise
	if id in [VillageContent.EMERALD_ORE,VillageContent.DEEP_EMERALD_ORE]:
		return Color("49d590") if (x/2*7+y/2*11)%13 < 3 else noise.darkened(0.22)
	if id == VillageContent.EMERALD_BLOCK:
		return base.lightened(0.28) if x in [1,2,13,14] or y in [1,2,13,14] else noise
	if d.get("family","") in ["wool","carpet"]: return noise.lightened(0.07) if (x+y)%3 == 0 else noise
	if d.get("family","") == "glazed": return base.lightened(0.3) if (absi(x-7)+absi(y-7))%7 < 3 else base.darkened(0.2)
	if shape in ["bed","bed_head"]: return Color("eee6d7") if shape == "bed_head" and y < 6 else base
	if shape == "banner": return base.lightened(0.18) if x%5 == 0 else noise
	if id in VillageContent.JOBS:
		if x < 2 or x > 13 or y < 2 or y > 13: return base.darkened(0.35)
		if id in [VillageContent.BLAST_FURNACE,VillageContent.SMOKER]: return Color("302d2a") if x in range(3,13) and y in range(6,13) else noise
		if id == VillageContent.CARTOGRAPHY_TABLE: return Color("ccd5b1") if x in range(3,13) and y in range(3,12) else noise
		if id == VillageContent.FLETCHING_TABLE and (x-y)%6 == 0: return Color("eee7d3")
		if id == VillageContent.SMITHING_TABLE and y < 5: return Color("514f50")
		return base.darkened(0.18) if y%5 == 0 else noise
	if id in [VillageContent.LANTERN,VillageContent.RED_CANDLE,VillageContent.YELLOW_CANDLE]:
		return Color("ffe5a3") if x in range(3,13) and y in range(3,13) else Color("70594b")
	# A soul lantern is the same shape with a cold teal flame, which is what tells
	# the two apart at a glance.
	if id in [1177,1178,1179,1204,1205,1206]: return LushCaves.pixel(id,x,y,noise)
	if PowderSnow.is_powder_snow(id) or PowderSnow.is_bucket(id): return PowderSnow.pixel(id,x,y,noise)
	if Bamboo.is_bamboo(id): return Bamboo.pixel(id,x,y,noise)
	if Lanterns.is_soul_lantern(id):
		return Color("7fd6c8") if x in range(3,13) and y in range(3,13) else Color("4a4a52")
	# A chain is a narrow column of links down the middle of the tile.
	if Lanterns.is_chain(id):
		var link: bool = x in range(6,10) and (y%4 < 3)
		return Color("b0b0b8") if link else Color(0,0,0,0)
	if id == VillageContent.GLASS_PANE: return Color("b9dcd88a") if x in [0,15] or y in [0,15] or x == y else Color("b9dcd818")
	if id == VillageContent.PAINTING: return Color("edce76") if (x-10)*(x-10)+(y-4)*(y-4) < 7 else (Color("406d6b") if y > 8+int(sin(x)*2) else Color("8ebec1"))
	if id == VillageContent.QUARTZ_PILLAR: return base.darkened(0.15) if x%4 == 0 else noise
	return noise

static func mesh(out: Array, p: Vector3, id: int) -> void:
	if Decor.is_pot(id) or Decor.is_stand(id): Decor.mesh(out,p,id); return
	if id == Archaeology.POT: Archaeology.mesh(out,p,id); return
	if Farmland.is_soil(id): Farmland.mesh(out,p,id); return
	if Amethyst.is_crystal(id): Amethyst.mesh(out,p,id); return
	# A candle stack renders one column per candle, so the count is visible.
	if id in Candles.BLOCKS: _candles(out,p,id); return
	if FruitCrops.is_stem(id) or FruitCrops.is_pumpkin_head(id): FruitCrops.mesh(out,p,id); return
	if id == Dungeons.SPAWNER: Dungeons.mesh(out,p); return
	var tile: int = Nodes.tile(id,0)
	var shape: String = VillageContent.shape(id)
	match shape:
		"bed","bed_head": _box(out,p,Vector3(0.5,0.27,0.5),Vector3(1,0.54,1),tile)
		"carpet": _box(out,p,Vector3(0.5,0.03,0.5),Vector3(1,0.06,1),tile)
		"banner":
			_box(out,p,Vector3(0.5,0.55,0.5),Vector3(0.06,1.1,0.06),Nodes.tile(Nodes.LOG,0))
			_box(out,p,Vector3(0.5,0.72,0.47),Vector3(0.72,0.75,0.04),tile)
		"bell":
			_box(out,p,Vector3(0.5,0.85,0.5),Vector3(0.95,0.12,0.15),Nodes.tile(Nodes.LOG,0))
			_box(out,p,Vector3(0.5,0.47,0.5),Vector3(0.5,0.6,0.5),tile)
			_box(out,p,Vector3(0.5,0.2,0.5),Vector3(0.66,0.12,0.66),tile)
		"lectern":
			_box(out,p,Vector3(0.5,0.1,0.5),Vector3(0.9,0.2,0.9),tile)
			_box(out,p,Vector3(0.5,0.5,0.5),Vector3(0.25,0.7,0.25),tile)
			_box(out,p,Vector3(0.5,0.9,0.5),Vector3(0.9,0.15,0.8),tile)
		"composter":
			_box(out,p,Vector3(0.5,0.03125,0.5),Vector3(1,0.0625,1),tile)
			for x in [0.0625,0.9375]: _box(out,p,Vector3(x,0.5,0.5),Vector3(0.125,1,1),tile)
			for z in [0.0625,0.9375]: _box(out,p,Vector3(0.5,0.5,z),Vector3(0.75,1,0.125),tile)
		"cauldron":
			for box in Cauldrons.boxes(): _box(out,p,box.get_center(),box.size,tile)
		# `lantern` also covers the two legacy candle ids 547/548, which are not
		# part of the count-and-colour candle family and so are not handled above.
		"lantern","candle":
			_box(out,p,Vector3(0.5,0.3,0.5),Vector3(0.35,0.5,0.35),tile)
			_box(out,p,Vector3(0.5,0.6,0.5),Vector3(0.13,0.15,0.13),tile)
		"bamboo":
			# A stalk is a narrow ribbed column, so it must not render as a cube.
			_box(out,p,Vector3(0.5,0.5,0.5),Vector3(0.22,1.0,0.22),tile)
		"chain":
			# A chain is a narrow column of links down the tile's centre, not a
			# cube. Without this branch it would render as a full block.
			_box(out,p,Vector3(0.5,0.5,0.5),Vector3(0.125,1.0,0.125),tile)
		"brewing":
			_box(out,p,Vector3(0.5,0.08,0.5),Vector3(0.8,0.16,0.8),Nodes.tile(Nodes.COBBLE,0))
			_box(out,p,Vector3(0.5,0.5,0.5),Vector3(0.15,0.8,0.15),tile)
			for x in [0.2,0.8]: _box(out,p,Vector3(x,0.3,0.5),Vector3(0.17,0.3,0.17),Nodes.tile(Nodes.GLASS,0))
		"grindstone","stonecutter","anvil":
			_box(out,p,Vector3(0.5,0.17,0.5),Vector3(0.8,0.34,0.65),tile)
			_box(out,p,Vector3(0.5,0.55,0.5),Vector3(0.4,0.45,0.4),tile)
			_box(out,p,Vector3(0.5,0.8,0.5),Vector3(0.9,0.25,0.7),tile)
		"campfire":
			for x in [0.22,0.78]: _box(out,p,Vector3(x,0.15,0.5),Vector3(0.25,0.3,0.9),Nodes.tile(Nodes.LOG,0))
			for z in [0.22,0.78]: _box(out,p,Vector3(0.5,0.32,z),Vector3(0.9,0.2,0.25),Nodes.tile(Nodes.LOG,0))
			if Campfires.lit(id): _box(out,p,Vector3(0.5,0.28,0.5),Vector3(0.45,0.3,0.45),tile if Campfires.soul(id) else Nodes.tile(Nodes.LAVA,0))
		"frame","painting","pane","door": _box(out,p,Vector3(0.5,0.5,0.1),Vector3(0.95,1,0.12),tile)
		"door_open": _box(out,p,Vector3(0.1,0.5,0.5),Vector3(0.12,1,0.95),tile)

static func _box(out: Array, p: Vector3, offset: Vector3, size: Vector3, tile: int) -> void:
	BlockMesher._art_box(out,p+offset,size,tile,tile)

# A candle stack: one narrow column per candle in the count, standing on the
# source's own four footprints. The caller has already decided the block is a
# candle, so the count comes straight from the id.
static func _candles(out: Array, p: Vector3, id: int) -> void:
	var tile: int = Nodes.tile(id,0)
	var count: int = Candles.count_of(id)
	for spot in Candles.SPOTS[count-1]:
		# Body from y 0.0 to 0.375, with the flame above it when lit.
		_box(out,p,Vector3(spot.x,0.1875,spot.y),Vector3(0.125,0.375,0.125),tile)
		if Candles.is_lit(id): _box(out,p,Vector3(spot.x,0.4375,spot.y),Vector3(0.09,0.125,0.09),tile)

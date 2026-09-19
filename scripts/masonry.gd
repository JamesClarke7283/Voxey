class_name Masonry
extends RefCounted

const DEEP_TILES = 1150
const CRACKED_DEEP_BRICKS = 1151
const CRACKED_DEEP_TILES = 1152
const CHISELED_DEEP = 1153
const POLISHED_TUFF = 1154
const TUFF_BRICKS = 1155
const CHISELED_TUFF = 1156
const CHISELED_TUFF_BRICKS = 1157
# Mineclonia `mcl_core:stonebrick{carved,cracked,mossy}`. These are the source's
# own stone brick variants; the cracked and mossy ones are what the ruined portal
# processors and several structures ask for.
const CHISELED_BRICKS = 1159
const CRACKED_BRICKS = 1160
const MOSSY_BRICKS = 1161
const BLOCKS = [1150,1151,1152,1153,1154,1155,1156,1157,1159,1160,1161]
# The variants that are shaped like a brick course rather than a tile.
const BRICK_COURSE = [CRACKED_BRICKS,MOSSY_BRICKS,CHISELED_BRICKS]

# Source `mcl_core:stonebrick { square2 = stonebrick 4 }`, so a chiseled block is
# made from the plain bricks, and cracked bricks come out of a furnace. Mossy
# bricks need moss, which Voxey has no item for, so that route is recorded rather
# than invented.
static func recipes(inv: Inventory) -> void:
	inv._recipe("Chiseled stone bricks",CHISELED_BRICKS,1,[Nodes.BRICKS,Nodes.BRICKS,Nodes.BRICKS,Nodes.BRICKS],2)
	for pair in [[Nodes.DEEPSLATE_BRICKS,DEEP_TILES],[MinecloniaOres.TUFF,POLISHED_TUFF],[POLISHED_TUFF,TUFF_BRICKS]]:
		var base: int = pair[0]
		inv._recipe(Nodes.title(pair[1]),pair[1],4,[base,base,base,base],2)
	for pair in [[Nodes.COBBLED_DEEPSLATE,CHISELED_DEEP],[POLISHED_TUFF,CHISELED_TUFF],[TUFF_BRICKS,CHISELED_TUFF_BRICKS]]:
		var slab: int = BuildingShapes.slab_for(pair[0])
		inv._recipe(Nodes.title(pair[1]),pair[1],1,[slab,slab],1)

static func cuts() -> Dictionary:
	return {
		Nodes.COBBLED_DEEPSLATE:[Nodes.DEEPSLATE],
		Nodes.POLISHED_DEEPSLATE:[Nodes.COBBLED_DEEPSLATE,Nodes.DEEPSLATE],
		Nodes.DEEPSLATE_BRICKS:[Nodes.COBBLED_DEEPSLATE,Nodes.POLISHED_DEEPSLATE,Nodes.DEEPSLATE],
		DEEP_TILES:[Nodes.COBBLED_DEEPSLATE,Nodes.POLISHED_DEEPSLATE,Nodes.DEEPSLATE_BRICKS,Nodes.DEEPSLATE],
		CHISELED_DEEP:[Nodes.COBBLED_DEEPSLATE,Nodes.DEEPSLATE],
		POLISHED_TUFF:[MinecloniaOres.TUFF], TUFF_BRICKS:[MinecloniaOres.TUFF,POLISHED_TUFF],
		CHISELED_TUFF:[MinecloniaOres.TUFF], CHISELED_TUFF_BRICKS:[MinecloniaOres.TUFF,POLISHED_TUFF,TUFF_BRICKS],
	}

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var base := Color(VillageContent.DATA[id].color)
	if id in [DEEP_TILES,CRACKED_DEEP_TILES,CRACKED_DEEP_BRICKS,TUFF_BRICKS]:
		var height: int = 4 if id in [DEEP_TILES,CRACKED_DEEP_TILES] else 8
		if y%height == 0 or posmod(x+(4 if y/height%2 else 0),8) == 0: return base.darkened(0.4)
		if id in [CRACKED_DEEP_BRICKS,CRACKED_DEEP_TILES] and (x == y/2+3 or x == 14-y/3): return base.darkened(0.55)
		return noise.lightened(0.05) if y%height == 1 else noise
	if id == POLISHED_TUFF:
		return base.darkened(0.28) if x in [0,15] or y in [0,15] else (base.lightened(0.08) if x == 1 or y == 1 else noise)
	if id in BRICK_COURSE:
		# A running bond: four-pixel courses, staggered every other row, which is
		# the shape the source's stone brick textures share.
		if y%4 == 0 or posmod(x+(4 if y/4%2 else 0),8) == 0: return base.darkened(0.4)
		if id == CRACKED_BRICKS and (x == y/2+2 or x == 15-y/3): return base.darkened(0.55)
		if id == MOSSY_BRICKS and (x+y*3)%7 < 2: return Color("5d7a4a").darkened(0.06*float((x+y)%3))
		if id == CHISELED_BRICKS and maxi(absi(x-7),absi(y-7)) <= 4 and absi(x-7) != absi(y-7): return base.darkened(0.28)
		return noise.lightened(0.05) if y%4 == 1 else noise
	var ring: int = maxi(absi(x-7),absi(y-7))
	if id == CHISELED_TUFF_BRICKS:
		return base.darkened(0.4) if y in [1,5,10,14] or x in [2,13] and y in range(5,11) or (x+y)%4 == 0 and y not in range(5,11) else noise
	return base.darkened(0.5) if ring in [3,6] or id == CHISELED_DEEP and y in [6,7] and x in [5,9] else noise

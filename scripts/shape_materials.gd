class_name ShapeMaterials
extends RefCounted

const LAPIS_BLOCK = 13700
const CUT_SANDSTONE = 13701
const RED_SAND = 13702
const RED_SANDSTONE = 13703
const CUT_RED_SANDSTONE = 13704
const CHISELED_RED_SANDSTONE = 13705
const SMOOTH_RED_SANDSTONE = 13706
const SMOOTH_SLAB_SIDE = 13720
const BLOCKS = [13700,13701,13702,13703,13704,13705,13706]
const DATA = {
	13700:{"name":"Block of lapis lazuli","block":true,"color":"3454af","hardness":3.0,"blast_resistance":3.0,"tool":0,"source_node":"mcl_core:lapisblock"},
	13701:{"name":"Cut sandstone","block":true,"color":"d7c58e","hardness":0.8,"blast_resistance":0.8,"tool":0,"source_node":"mcl_core:sandstonesmooth"},
	13702:{"name":"Red sand","block":true,"color":"b86c3b","hardness":0.5,"blast_resistance":0.5,"tool":2,"source_node":"mcl_core:redsand"},
	13703:{"name":"Red sandstone","block":true,"color":"bd7746","hardness":0.8,"blast_resistance":0.8,"tool":0,"source_node":"mcl_core:redsandstone"},
	13704:{"name":"Cut red sandstone","block":true,"color":"c8814c","hardness":0.8,"blast_resistance":0.8,"tool":0,"source_node":"mcl_core:redsandstonesmooth"},
	13705:{"name":"Chiseled red sandstone","block":true,"color":"b97041","hardness":0.8,"blast_resistance":0.8,"tool":0,"source_node":"mcl_core:redsandstonecarved"},
	13706:{"name":"Smooth red sandstone","block":true,"color":"c88250","hardness":0.8,"blast_resistance":0.8,"tool":0,"source_node":"mcl_core:redsandstonesmooth2"},
	13720:{"name":"Smooth stone slab edge","color":"989c98","hidden":true},
}

static func recipes(inv: Inventory) -> void:
	inv._recipe("Block of lapis lazuli",LAPIS_BLOCK,1,[Nodes.LAPIS,Nodes.LAPIS,Nodes.LAPIS,Nodes.LAPIS,Nodes.LAPIS,Nodes.LAPIS,Nodes.LAPIS,Nodes.LAPIS,Nodes.LAPIS],3,"table")
	inv._recipe("Lapis lazuli",Nodes.LAPIS,9,[LAPIS_BLOCK],1)
	for pair in [[Nodes.SANDSTONE,CUT_SANDSTONE,4],[RED_SAND,RED_SANDSTONE,1],[RED_SANDSTONE,CUT_RED_SANDSTONE,4]]:
		inv._recipe(Nodes.title(pair[1]),pair[1],pair[2],[pair[0],pair[0],pair[0],pair[0]],2)
	inv._recipe("Chiseled red sandstone",CHISELED_RED_SANDSTONE,1,[BuildingShapes.slab_for(RED_SANDSTONE),BuildingShapes.slab_for(RED_SANDSTONE)],1)
	inv._recipe("Chiseled sandstone",Nodes.SANDSTONE_BRICK,1,[BuildingShapes.slab_for(Nodes.SANDSTONE),BuildingShapes.slab_for(Nodes.SANDSTONE)],1)
	inv._recipe("Chiseled stone bricks",Masonry.CHISELED_BRICKS,1,[BuildingShapes.slab_for(Nodes.BRICKS),BuildingShapes.slab_for(Nodes.BRICKS)],1)

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var color := Color(DATA[id].color)
	if id == SMOOTH_SLAB_SIDE:
		return color.darkened(0.28) if y in [0,7,8,15] else color.lightened(0.12) if y in [1,9] else noise
	if id == LAPIS_BLOCK:
		if (x*3+y*5)%17 < 3: return color.lightened(0.18)
		return noise.darkened(0.06) if (x+y)%7 == 0 else noise
	if id in [CUT_SANDSTONE,CUT_RED_SANDSTONE]:
		return color.darkened(0.2) if y in [0,7,15] or x == (8 if y < 8 else 0) else noise
	if id == CHISELED_RED_SANDSTONE:
		var rim: int = maxi(absi(x-7),absi(y-7))
		return color.darkened(0.25) if rim in [4,7] or y in [6,7] and x in range(5,10) else noise
	if id == RED_SANDSTONE: return color.darkened(0.18) if y in [0,7,15] and x%5 != 0 else noise
	return noise

static func cuts() -> Dictionary:
	return {CUT_SANDSTONE:[Nodes.SANDSTONE],CUT_RED_SANDSTONE:[RED_SANDSTONE],CHISELED_RED_SANDSTONE:[RED_SANDSTONE],SMOOTH_RED_SANDSTONE:[RED_SANDSTONE],Masonry.SMOOTH_SANDSTONE:[Nodes.SANDSTONE],Nodes.SANDSTONE_BRICK:[Nodes.SANDSTONE]}

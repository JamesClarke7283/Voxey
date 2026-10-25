class_name CopperTools
extends RefCounted

# Mineclonia mcl_tools/register.lua and mcl_farming/hoes.lua, GPL-3.0-or-later.
# The legacy native tier enumerates harvest classes; copper shares stone's
# fallback class. Real mining uses its distinct source level-3 capabilities.
const FIRST = 11592
const IDS = [11592,11593,11594,11595,11596]
const NAMES = ["mcl_tools:pick_copper","mcl_tools:axe_copper","mcl_tools:shovel_copper","mcl_tools:sword_copper","mcl_farming:hoe_copper"]
const DATA = {
	11592:{"name":"Copper pickaxe","color":"c27c55","stack":1,"tool_kind":0,"tier":1,"speed":5.0,"source_level":3,"durability":191,"repair_material":77,"smelt":11306,"cook_time":10.0,"blast_furnace_smeltable":true},
	11593:{"name":"Copper axe","color":"c27c55","stack":1,"tool_kind":1,"tier":1,"speed":5.0,"source_level":3,"durability":191,"repair_material":77,"smelt":11306,"cook_time":10.0,"blast_furnace_smeltable":true},
	11594:{"name":"Copper shovel","color":"c27c55","stack":1,"tool_kind":2,"tier":1,"speed":5.0,"source_level":3,"durability":191,"repair_material":77,"smelt":11306,"cook_time":10.0,"blast_furnace_smeltable":true},
	11595:{"name":"Copper sword","color":"c27c55","stack":1,"tool_kind":3,"tier":1,"speed":5.0,"source_level":3,"durability":191,"repair_material":77,"smelt":11306,"cook_time":10.0,"blast_furnace_smeltable":true},
	11596:{"name":"Copper hoe","color":"c27c55","stack":1,"tool_kind":4,"tier":1,"speed":5.0,"source_level":3,"durability":191,"repair_material":77,"smelt":11306,"cook_time":10.0,"blast_furnace_smeltable":true},
}
static func has(id: int) -> bool: return id >= FIRST and id < FIRST+5
static func recipes(inv: Inventory) -> void:
	var m: int = Nodes.COPPER; var s: int = Nodes.STICK
	var patterns: Array = [[m,m,m,0,s,0,0,s,0],[m,m,0,m,s,0,0,s,0],[m,0,0,s,0,0,s,0,0],[m,0,0,m,0,0,s,0,0],[m,m,0,s,0,0,s,0,0]]
	for i in 5: inv._recipe(Nodes.title(FIRST+i),FIRST+i,1,patterns[i],3,"table")

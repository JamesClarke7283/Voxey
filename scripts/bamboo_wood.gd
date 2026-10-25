class_name BambooWood
extends RefCounted

# Mineclonia mcl_bamboo/{init,nodes,recipes}.lua and mcl_trees/api.lua.
# GPL-3.0-or-later behavior reference; all textures and meshes are original.
# Bamboo is processed from stalks. It has neither saplings/leaves nor bark wood.
const SPECIES = 11
const BLOCK = 13200
const PLANKS = 13203
const STRIPPED = 13204
const MOSAIC = 13521
const DOOR = 13400
const DOOR_BASE = 13401
const TRAPDOOR = 13440
const SIGN = 13460
const HANGING = 13480
const FENCE = 13500
const PLATE = 13520
const RAFT = 13522
const CHEST_RAFT = 13523
const LOG_IDS = [13200,13204,13208,13209,13210,13211]
const TEXTURES = [13200,13203,13204,13216,13217]
const WOOD_DATA = {
	13200:{"name":"Block of bamboo","block":true,"family":"wood_log","hardness":2.0,"tool":1,"blast_resistance":3.0,"drop":13200},
	13203:{"name":"Bamboo planks","block":true,"family":"wood_planks","hardness":2.0,"tool":1,"blast_resistance":3.0,"drop":13203},
	13204:{"name":"Block of stripped bamboo","block":true,"family":"wood_stripped_log","hardness":2.0,"tool":1,"blast_resistance":3.0,"drop":13204},
	13208:{"name":"Block of bamboo","block":true,"family":"wood_log","hardness":2.0,"tool":1,"blast_resistance":3.0,"drop":13200,"hidden":true},
	13209:{"name":"Block of bamboo","block":true,"family":"wood_log","hardness":2.0,"tool":1,"blast_resistance":3.0,"drop":13200,"hidden":true},
	13210:{"name":"Block of stripped bamboo","block":true,"family":"wood_stripped_log","hardness":2.0,"tool":1,"blast_resistance":3.0,"drop":13204,"hidden":true},
	13211:{"name":"Block of stripped bamboo","block":true,"family":"wood_stripped_log","hardness":2.0,"tool":1,"blast_resistance":3.0,"drop":13204,"hidden":true},
}
const DATA = {
	13400:{"name":"Bamboo door","color":"d2ba62","hardness":3.0,"tool":1,"stack":64},
	13521:{"name":"Bamboo mosaic","color":"cabb72","block":true,"hardness":2.0,"tool":1,"blast_resistance":3.0,"fuel":15,"flammable":true},
	13522:{"name":"Bamboo raft","color":"cbbb70","stack":1,"family":"boat"},
	13523:{"name":"Bamboo chest raft","color":"cbbb70","stack":1,"family":"chest_boat"},
}

static func is_log(id: int) -> bool: return id in LOG_IDS
static func is_raft(id: int) -> bool: return id in [RAFT,CHEST_RAFT]
static func raw(id: int) -> bool: return id in [BLOCK,BLOCK+8,BLOCK+9]

static func register_families() -> void:
	Doors.register_family(DOOR,PLANKS,"Bamboo door",DOOR_BASE)
	Trapdoors.register_family(TRAPDOOR,PLANKS,"Bamboo trapdoor",TRAPDOOR)
	Signs.register_base(SIGN,SPECIES)
	Signs.register_hanging(HANGING,HANGING)
	Barriers.register_family(FENCE,PLANKS)
	RedstoneInputs.register_material("Bamboo",PLANKS,PLATE)

static func recipes(inv: Inventory) -> void:
	var stalk: int = Bamboo.BAMBOO_ITEM
	inv._recipe("Block of bamboo",BLOCK,1,[stalk,stalk,stalk,stalk,stalk,stalk,stalk,stalk,stalk],3,"table")
	for id in [BLOCK,STRIPPED]: inv._recipe("Bamboo planks",PLANKS,2,[id],1)
	var slab: int = BuildingShapes.slab_for(PLANKS)
	inv._recipe("Bamboo mosaic",MOSAIC,1,[slab,slab],1)
	inv._recipe("Bamboo door",DOOR,3,[PLANKS,PLANKS,PLANKS,PLANKS,PLANKS,PLANKS],2,"table")
	inv._recipe("Bamboo trapdoor",TRAPDOOR,2,[PLANKS,PLANKS,PLANKS,PLANKS,PLANKS,PLANKS],3,"table")

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	if id == MOSAIC:
		var horizontal: bool = (x/8+y/8)%2 == 0
		var cross: int = y if horizontal else x
		var along: int = x if horizontal else y
		if cross%4 == 0 or along%8 == 0: return Color("8c793d")
		return noise.lightened(0.07) if cross%4 == 1 else noise
	var offset: int = posmod(id-BLOCK,32)
	var stripped: bool = offset in [4,10,11,17]
	var dark := Color("9e8442") if stripped else Color("596639")
	if offset in [16,17]:
		var p := Vector2(posmod(x,5)-2,posmod(y,5)-2)
		return dark if p.length() > 1.5 else Color("e3d792")
	if offset == 3:
		if y%4 == 0 or (x+(y/4)*7)%16 == 0: return Color("8d773d")
		return noise.lightened(0.1) if y%4 == 1 else noise
	if x%5 == 0 or y%8 == 0: return dark
	if x%5 == 1: return noise.lightened(0.13)
	return noise

static func raft_hull() -> AABB:
	# The source's asymmetric raft collisionbox; ordinary boats use a unit box.
	return AABB(Vector3(-0.25,0,-0.55),Vector3(0.5,0.3,1.25))

static func raft_mesh(parent: Node3D, color: Color) -> void:
	for i in 6:
		var pole := MeshInstance3D.new()
		var shape := CylinderMesh.new(); shape.top_radius = 0.105; shape.bottom_radius = 0.105; shape.height = 1.45; shape.radial_segments = 8
		var material := StandardMaterial3D.new(); material.albedo_color = color.lightened(0.05*(i%2)); material.roughness = 1.0
		pole.mesh = shape; pole.material_override = material; pole.position = Vector3((i-2.5)*0.21,0.14,0.05); pole.rotation.x = PI/2.0
		parent.add_child(pole)
	for z in [-0.4,0.4]: BoatArt.box(parent,Vector3(0,0.21,z),Vector3(1.3,0.035,0.055),Color("827144"))

static func draw_raft(img: Image, color: Color) -> void:
	for i in 5:
		var x: float = 2+i*2.1
		ItemArt._line(img,Vector2(x,5-i*0.25),Vector2(x+3,12-i*0.25),color.darkened(0.06*(i%2)),2)
	ItemArt._line(img,Vector2(2,7),Vector2(12,5),Color("837445"),1)
	ItemArt._line(img,Vector2(4,11),Vector2(14,9),Color("837445"),1)

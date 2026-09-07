class_name VillageArt
extends RefCounted

static func pixel(id: int, x: int, y: int, noise: Color) -> Color:
	var d: Dictionary = VillageContent.DATA[id]
	var base := Color(d.color)
	var shape: String = d.get("shape","cube")
	if id == VillageContent.COBWEB:
		var web: bool = x == y or x+y == 15 or x in [7,8] or y in [7,8] or maxi(absi(x-7),absi(y-7)) in [3,6]
		return Color("d9e2d7") if web else Color.TRANSPARENT
	if id == VillageContent.LILY_PAD: return Color.TRANSPARENT if (x < 4 and y < 4) or Vector2(x-7.5,y-7.5).length() > 7.5 else noise
	if id == VillageContent.SWAMP_GRASS: return noise.darkened(0.07) if y%5 == 0 else noise
	if shape == "crop":
		var stem: bool = y >= 13-int(d.stage)*3 and (x%5 == 2 or ((x+y)%7 < 2 and y > 5))
		if not stem: return Color.TRANSPARENT
		return base if d.stage == 3 and y > 11 else Color("609143")
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
	if id == VillageContent.GLASS_PANE: return Color("b9dcd88a") if x in [0,15] or y in [0,15] or x == y else Color("b9dcd818")
	if id == VillageContent.PAINTING: return Color("edce76") if (x-10)*(x-10)+(y-4)*(y-4) < 7 else (Color("406d6b") if y > 8+int(sin(x)*2) else Color("8ebec1"))
	if id == VillageContent.QUARTZ_PILLAR: return base.darkened(0.15) if x%4 == 0 else noise
	return noise

static func mesh(out: Array, p: Vector3, id: int) -> void:
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
		"cauldron":
			_box(out,p,Vector3(0.5,0.15,0.5),Vector3(0.95,0.3,0.95),tile)
			for x in [0.07,0.93]: _box(out,p,Vector3(x,0.6,0.5),Vector3(0.14,0.8,0.95),tile)
			for z in [0.07,0.93]: _box(out,p,Vector3(0.5,0.6,z),Vector3(0.8,0.8,0.14),tile)
		"lantern","candle":
			_box(out,p,Vector3(0.5,0.3,0.5),Vector3(0.35,0.5,0.35),tile)
			_box(out,p,Vector3(0.5,0.6,0.5),Vector3(0.13,0.15,0.13),tile)
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
			_box(out,p,Vector3(0.5,0.3,0.5),Vector3(0.5,0.3,0.5),Nodes.tile(Nodes.LAVA,0))
		"frame","painting","pane","door": _box(out,p,Vector3(0.5,0.5,0.1),Vector3(0.95,1,0.12),tile)
		"door_open": _box(out,p,Vector3(0.1,0.5,0.5),Vector3(0.12,1,0.95),tile)

static func _box(out: Array, p: Vector3, offset: Vector3, size: Vector3, tile: int) -> void:
	BlockMesher._art_box(out,p+offset,size,tile,tile)

class_name VillageGenerator
extends RefCounted

const SPACING = 320
const HOMES = [Vector2i(-24,-19),Vector2i(-12,-19),Vector2i(0,-19),Vector2i(12,-19),Vector2i(24,-19),Vector2i(-24,15),Vector2i(-12,15),Vector2i(0,15),Vector2i(12,15),Vector2i(24,15),Vector2i(-24,32),Vector2i(0,32),Vector2i(24,32)]

static func settlement(gen: TerrainGenerator, region: Vector2i) -> Dictionary:
	var x: int = region.x*SPACING+96+gen.hash_at(region.x,411,region.y)%128
	var z: int = region.y*SPACING+96+gen.hash_at(region.x,413,region.y)%128
	# A dry, level village pad joins the surrounding land with a gentle shoulder.
	var y: int = clampi(gen.terrain_height(x,z),25,43)
	return {"center":Vector3i(x,y,z),"key":"%d:%d"%[region.x,region.y],"biome":gen.biome(x,z)}

static func nearest(gen: TerrainGenerator, near: Vector3) -> Dictionary:
	var region := Vector2i(floori(near.x/SPACING),floori(near.z/SPACING))
	var best: Dictionary = {}; var distance: float = INF
	for dz in range(-1,2):
		for dx in range(-1,2):
			var village: Dictionary = settlement(gen,region+Vector2i(dx,dz))
			var d: float = Vector3(village.center).distance_squared_to(near)
			if d < distance: distance = d; best = village
	return best

static func job(village: Dictionary, index: int) -> Vector3i:
	var h: Vector2i = HOMES[index]
	return village.center+Vector3i(h.x-2,1,h.y+1)

static func bed(village: Dictionary, index: int) -> Vector3i:
	var h: Vector2i = HOMES[index]
	return village.center+Vector3i(h.x+2,1,h.y+1)

static func overlay(gen: TerrainGenerator, coord: Vector2i, data: PackedInt32Array) -> void:
	var village: Dictionary = settlement(gen,Vector2i(floori(coord.x*16.0/SPACING),floori(coord.y*16.0/SPACING)))
	var center: Vector3i = village.center
	if absf(coord.x*16+8-center.x) > 57 or absf(coord.y*16+8-center.z) > 61: return
	for z in 18:
		for x in 18:
			var wx: int = coord.x*16+x-1; var wz: int = coord.y*16+z-1
			var q := Vector2i(wx-center.x,wz-center.z)
			if absi(q.x) > 42 or q.y < -36 or q.y > 47: continue
			var edge: float = maxf(absf(q.x)/42.0,maxf(-q.y/36.0,q.y/47.0))
			var base_y: int = center.y if edge < 0.82 else roundi(lerpf(center.y,gen.terrain_height(wx,wz),clampf((edge-0.82)/0.18,0,1)))
			for y in range(maxi(1,mini(base_y,gen.terrain_height(wx,wz))-7),64):
				var id: int = Nodes.AIR
				if y < base_y: id = Nodes.DIRT if y > base_y-4 else Nodes.STONE
				elif y == base_y: id = Nodes.SAND if "desert" in village.biome else (Nodes.SNOW if "Frost" in village.biome else Nodes.GRASS)
				if edge < 0.82:
					var placed: int = structure_node(Vector3i(q.x,y-center.y,q.y),village)
					if placed >= 0: id = placed
				data[x+z*18+y*324] = id

static func structure_node(p: Vector3i, village: Dictionary) -> int:
	var desert: bool = "desert" in village.biome
	var wall: int = Nodes.SANDSTONE if desert else Nodes.PLANKS
	var roof: int = Nodes.SANDSTONE_BRICK if desert else Nodes.COBBLE
	if p.y == 0 and (absi(p.x) <= 1 or p.z in range(-25,-21) or p.z in range(8,12) or p.z in range(25,29)):
		return VillageContent.PATH
	# Roofed well and gathering bell.
	if absi(p.x) <= 2 and absi(p.z) <= 2:
		if p.y == 0: return Nodes.WATER if absi(p.x) <= 1 and absi(p.z) <= 1 else Nodes.COBBLE
		if p.y == 4: return roof
		if p.y in range(1,4) and absi(p.x) == 2 and absi(p.z) == 2: return Nodes.LOG
	if p == Vector3i(4,1,0): return VillageContent.BELL
	# Irrigated fields contain all four Overworld crops.
	if absi(p.x) in range(8,23) and p.z in range(-10,3):
		if p.y == 0: return Nodes.WATER if absi(p.x)%7 == 0 else Nodes.FARMLAND
		if p.y == 1 and absi(p.x)%7 != 0:
			return [Nodes.RIPE_WHEAT,VillageContent.CARROTS_3,VillageContent.POTATOES_3,VillageContent.BEETROOTS_3][posmod(p.z,4)]
	for i in HOMES.size():
		var h: Vector2i = HOMES[i]
		var q := p-Vector3i(h.x,0,h.y)
		if absi(q.x) > 4 or absi(q.z) > 4: continue
		if q.y == 0 and absi(q.x) <= 3 and absi(q.z) <= 3: return roof
		if q.y in range(1,5) and absi(q.x) <= 3 and absi(q.z) <= 3:
			if absi(q.x) == 3 or absi(q.z) == 3:
				if q.x == 0 and q.z == -3 and q.y < 3: return VillageContent.WOODEN_DOOR
				if q.y in [2,3] and (q.x == 0 or q.z == 0): return Nodes.GLASS
				return Nodes.LOG if absi(q.x) == 3 and absi(q.z) == 3 and not desert else wall
			if q == Vector3i(-2,1,1): return VillageContent.JOBS[i]
			if q == Vector3i(2,1,1): return Nodes.BED_FOOT
			if q == Vector3i(2,1,2): return Nodes.BED_HEAD
			if q == Vector3i(-2,1,-1): return Nodes.CHEST
			if q == Vector3i(-2,2,2) and i == 4: return Nodes.BOOKSHELF
			if q == Vector3i(0,3,2): return VillageContent.LANTERN
			return Nodes.AIR
		if q.y in range(5,8) and absi(q.x) <= 4-(q.y-5) and absi(q.z) <= 4: return roof
	if p.y == 1 and p.x in [-30,30] and p.z in [-23,10,27]: return Nodes.LOG
	if p.y == 2 and p.x in [-30,30] and p.z in [-23,10,27]: return VillageContent.LANTERN
	return -1

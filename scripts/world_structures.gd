class_name WorldStructures
extends RefCounted

# All coordinates derive from seed and region, including neighboring mesh halos.
static func stronghold(seed_value: int, region: Vector2i) -> Vector3i:
	var h: int = absi((region.x*73428767) ^ (region.y*912931) ^ seed_value)
	return Vector3i(region.x*512+96+h%320,-32,region.y*512+96+(h/331)%320)

static func nearest_stronghold(seed_value: int, near: Vector3) -> Vector3i:
	var region := Vector2i(floori(near.x/512.0),floori(near.z/512.0))
	var best := Vector3i.ZERO
	var distance: float = INF
	for x in range(-1,2):
		for z in range(-1,2):
			var p := stronghold(seed_value,region+Vector2i(x,z))
			var d: float = Vector2(p.x-near.x,p.z-near.z).length_squared()
			if d < distance: distance = d; best = p
	return best

static func stronghold_node(p: Vector3i, center: Vector3i) -> int:
	var q := p-center
	if q.y < 0 or q.y > 9 or q.x < -24 or q.x > 10 or absi(q.z) > 11: return -1
	var room: bool = (absi(q.x) <= 10 and absi(q.z) <= 11) or (q.x <= -12 and absi(q.z) <= 8)
	var corridor: bool = q.x in range(-13,-8) and absi(q.z) <= 2 and q.y <= 4
	if not room and not corridor: return -1
	if q.y == 0 or q.y == 9: return Nodes.BRICKS
	if corridor: return Nodes.BRICKS if absi(q.z) == 2 or q.y == 4 else Nodes.AIR
	var wall: bool = absi(q.x) == 10 or absi(q.z) == 11 or q.x in [-24,-12] or (q.x < -12 and absi(q.z) == 8)
	if wall: return Nodes.MOSSY_BRICKS if posmod(p.x+p.z*3+p.y,5) == 0 else Nodes.BRICKS
	if q.x < -12:
		if q.y in [1,2,3,5,6] and (q.x in [-23,-14] or absi(q.z) == 7): return Nodes.BOOKSHELF
		if q == Vector3i(-19,1,5): return Nodes.CHEST
		if q.y == 5 and q.x == -18 and absi(q.z) == 4: return Nodes.GLOWSTONE
		return Nodes.AIR
	# A raised twelve-frame portal, with a lava moat and a safe approach.
	if q.y == 1 and absi(q.x) <= 4 and absi(q.z) <= 4: return Nodes.LAVA
	if q.y == 2 and absi(q.x) <= 3 and absi(q.z) <= 3: return Nodes.BRICKS
	if q.y == 3 and ((absi(q.x) == 2 and absi(q.z) <= 1) or (absi(q.z) == 2 and absi(q.x) <= 1)): return Nodes.END_FRAME
	if q.y in [1,2] and q.x in [-1,0,1] and q.z in [5,6,7]: return Nodes.BRICKS
	if q.y == 1 and q.x == 7 and q.z == 7: return Nodes.CHEST
	if q.y == 3 and absi(q.x) == 8 and absi(q.z) == 8: return Nodes.GLOWSTONE
	if q.y in [2,3,4] and absi(q.x) == 7 and q.z == -8: return Nodes.IRON_BARS
	return Nodes.AIR

static func fortress_node(p: Vector3i) -> int:
	var q := Vector3i(posmod(p.x,160)-60,p.y,posmod(p.z,160)-60)
	if absi(q.x) > 28 or absi(q.z) > 28 or q.y > 41: return -1
	var crossing: bool = absi(q.x) <= 3 or absi(q.z) <= 3
	var tower: bool = absi(q.x) <= 9 and absi(q.z) <= 9
	if not crossing and not tower: return -1
	if q.y == 28 and q.x in range(-7,-3) and q.z in range(4,8): return Nodes.SOUL_SAND
	if q.y == 29 and q.x in range(-7,-3) and q.z in range(4,8): return VillageContent.NETHER_WART_3
	if q.y in [27,28]: return Nodes.NETHER_BRICKS
	if q.y < 27:
		if absi(q.x) in [8,9] and absi(q.z) in [8,9]: return Nodes.NETHER_BRICKS
		return -1
	if tower:
		if q == Vector3i(0,29,0): return Nodes.BLAZE_SPAWNER
		if q == Vector3i(6,29,6): return Nodes.CHEST
		if q.y == 38: return Nodes.NETHER_BRICKS
		if q.y >= 39: return -1
		if absi(q.x) == 9 or absi(q.z) == 9:
			if (absi(q.x) <= 2 or absi(q.z) <= 2) and q.y < 33: return Nodes.AIR
			return Nodes.NETHER_BRICKS if q.y != 34 else Nodes.IRON_BARS
		return Nodes.AIR
	if q.y <= 30 and (absi(q.x) == 3 or absi(q.z) == 3): return Nodes.NETHER_BRICKS
	return Nodes.AIR if q.y < 34 else -1

static func towers() -> Array:
	var result: Array = []
	for i in 10:
		var angle: float = TAU*i/10.0
		result.append(Vector3i(roundi(cos(angle)*35),58+(i*7)%28,roundi(sin(angle)*35)))
	return result

static func end_node(x: int, y: int, z: int, noise: FastNoiseLite) -> int:
	var r: float = Vector2(x,z).length()
	if r < 64:
		var top: float = 43+noise.get_noise_2d(x,z)*5
		var bottom: float = 15+pow(r/64.0,3)*28
		if y <= top and y >= bottom: return Nodes.END_STONE
	# Separated outer islands with chorus groves and purpur city towers.
	if r > 160:
		var ix: int = floori((x+48)/96.0)*96
		var iz: int = floori((z+48)/96.0)*96
		var local_r: float = Vector2(x-ix,z-iz).length()
		var top: int = 43+int(noise.get_noise_2d(x,z)*7)
		if posmod(ix/96+iz/96,3) == 0 and absi(x-ix) <= 5 and absi(z-iz) <= 5 and y >= 42 and y <= 65:
			if x == ix-3 and z == iz-3 and y > 42: return Nodes.LADDER
			if x == ix-4 and z == iz-3: return Nodes.PURPUR
			if y in [42,49,57,65]: return Nodes.PURPUR
			if absi(x-ix) == 5 or absi(z-iz) == 5:
				if absi(x-ix) <= 1 and y < 47: return Nodes.AIR
				return Nodes.END_ROD if y%7 in [2,3] else Nodes.PURPUR
			if x == ix+3 and z == iz+3 and y == 58: return Nodes.CHEST
			return Nodes.AIR
		if local_r < 30 and y <= top and y >= 23+local_r*0.45: return Nodes.END_STONE
		if local_r < 23 and posmod(x,9) == 3 and posmod(z,9) == 3 and y > top and y <= top+4: return Nodes.CHORUS_PLANT
	return Nodes.AIR

static func end_structure_node(p: Vector3i) -> int:
	for tower in towers():
		var d := Vector2(p.x-tower.x,p.z-tower.z)
		var radius: int = 2 if tower.y < 70 else 3
		if d.length_squared() <= radius*radius and p.y >= 30 and p.y <= tower.y: return Nodes.BEDROCK if p.y == tower.y and d == Vector2.ZERO else Nodes.OBSIDIAN
		# Two towers have cages that must be mined or shot through.
		if tower.y >= 80 and absi(p.x-tower.x) <= 2 and absi(p.z-tower.z) <= 2 and p.y > tower.y and p.y <= tower.y+4:
			if absi(p.x-tower.x) == 2 or absi(p.z-tower.z) == 2 or p.y == tower.y+4: return Nodes.IRON_BARS
	if absi(p.x) <= 3 and absi(p.z) <= 3 and p.y == 44: return Nodes.BEDROCK
	if p.x == 0 and p.z == 0 and p.y in range(45,49): return Nodes.BEDROCK
	if p.x in range(49,54) and p.z in range(-2,3) and p.y == 44: return Nodes.OBSIDIAN
	if p.x in range(49,54) and p.z in range(-2,3) and p.y in range(45,49): return Nodes.AIR
	return -1

static func frame_positions(center: Vector3i) -> Array:
	var result: Array = []
	for d in range(-1,2):
		for side in [-2,2]:
			result.append(center+Vector3i(d,0,side))
			result.append(center+Vector3i(side,0,d))
	return result

static func fill_eye(world: VoxelWorld, p: Vector3i) -> bool:
	if world.node_at(p) != Nodes.END_FRAME: return false
	world.set_node(p,Nodes.END_FRAME_EYE)
	for dx in range(-2,3):
		for dz in range(-2,3):
			var center := p+Vector3i(dx,0,dz)
			var complete: bool = true
			for frame in frame_positions(center):
				if world.node_at(frame) != Nodes.END_FRAME_EYE: complete = false; break
			if not complete: continue
			for x in range(-1,2):
				for z in range(-1,2): world.set_node(center+Vector3i(x,0,z),Nodes.END_PORTAL)
			return true
	return true
